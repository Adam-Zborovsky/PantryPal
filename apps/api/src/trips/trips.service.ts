import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, ShoppingItemStatus, TripStatus } from '@prisma/client';
import { ActivityService } from '../activity/activity.service';
import { HouseholdAccessService } from '../households/household-access.service';
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeIngredientName, parseUnit } from '../recipes/units';
import {
  addQuantity,
  DemandEntry,
  exactKnown,
  readDemand,
  reassessPantry,
} from './demand';
import {
  estimateShopping,
  IngredientProfileSnapshot,
} from './shopping-estimate';
import {
  CreateShoppingTripDto,
  UpdateShoppingItemDto,
  UpdateShoppingTripDto,
} from './trips.dto';

type SnapshotIngredient = {
  name: string;
  quantityMin: string | null;
  quantityMax: string | null;
  unit: string | null;
  includeInShopping: boolean;
};
type AggregatedItem = {
  key: string;
  name: string;
  demand: DemandEntry[];
  unmeasured: boolean;
  contributions: Array<{
    cookingInstanceId: string;
    recipeTitle: string;
    quantityMin: string | null;
    quantityMax: string | null;
    unit: string | null;
  }>;
};

@Injectable()
export class TripsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
    private readonly activity: ActivityService,
    private readonly notifications: NotificationsService,
    private readonly ingredients: IngredientProfileService,
  ) {}

  async create(
    accountId: string,
    householdId: string,
    input: CreateShoppingTripDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const scheduledFor = input.scheduledFor
      ? new Date(input.scheduledFor)
      : null;
    if (scheduledFor && Number.isNaN(scheduledFor.getTime()))
      throw new BadRequestException(
        'Shopping date must be a valid ISO 8601 value.',
      );
    const trip = await this.prisma.shoppingTrip.create({
      data: { householdId, scheduledFor, createdByAccountId: accountId },
    });
    await this.record(accountId, householdId, trip.id, 'trip.created', {
      scheduledFor: scheduledFor?.toISOString() ?? null,
    });
    return this.present(trip);
  }

  async list(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const trips = await this.prisma.shoppingTrip.findMany({
      where: { householdId },
      orderBy: [{ scheduledFor: 'asc' }, { createdAt: 'desc' }],
    });
    return trips.map((trip) => this.present(trip));
  }

  async detail(accountId: string, householdId: string, tripId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const trip = await this.prisma.shoppingTrip.findFirst({
      where: { id: tripId, householdId },
    });
    if (!trip) {
      throw new NotFoundException('Shopping trip not found in this household.');
    }
    const items = await this.prisma.shoppingItem.findMany({
      where: { householdId, shoppingTripId: trip.id },
      orderBy: { displayName: 'asc' },
    });
    return {
      ...this.present(trip),
      items: await this.presentItems(householdId, items),
    };
  }

  async update(
    accountId: string,
    householdId: string,
    tripId: string,
    input: UpdateShoppingTripDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const scheduledFor = new Date(input.scheduledFor);
    if (Number.isNaN(scheduledFor.getTime())) {
      throw new BadRequestException(
        'Shopping date must be a valid ISO 8601 value.',
      );
    }
    const trip = await this.prisma.shoppingTrip.findFirst({
      where: { id: tripId, householdId },
    });
    if (!trip) {
      throw new NotFoundException('Shopping trip not found in this household.');
    }
    const dateChanged = trip.scheduledFor?.getTime() !== scheduledFor.getTime();
    const updated = await this.prisma.shoppingTrip.update({
      where: { id: trip.id },
      data: {
        scheduledFor,
        status:
          dateChanged && trip.status === TripStatus.CONFIRMED
            ? TripStatus.PROPOSED
            : trip.status,
        revision: { increment: 1 },
      },
    });
    const recalculated =
      dateChanged && trip.status === TripStatus.CONFIRMED
        ? await this.recalculateAutomaticAssignments(householdId, trip.id)
        : [];
    await this.record(accountId, householdId, updated.id, 'trip.updated', {
      scheduledFor: updated.scheduledFor?.toISOString() ?? null,
      status: updated.status,
      revision: updated.revision,
      recalculatedCookingInstanceIds: recalculated.map(
        (assignment) => assignment.cookingInstanceId,
      ),
    });
    await this.announceRecalculated(
      accountId,
      householdId,
      trip.id,
      recalculated,
    );
    if (dateChanged && trip.status === TripStatus.CONFIRMED) {
      await this.notifications.notifyHouseholdExcept({
        householdId,
        actorAccountId: accountId,
        dedupeKey: `trip-date-changed:${updated.id}:${updated.revision}`,
        title: 'Shopping date changed',
        body: 'The shopping date changed and needs confirmation again.',
        deepLink: `/households/${householdId}/trips/${updated.id}`,
      });
    }
    return this.present(updated);
  }

  async confirm(accountId: string, householdId: string, tripId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const { trip, canonicalIds, adopted } = await this.prisma.$transaction(
      async (tx) => {
        const trip = await tx.shoppingTrip.findFirst({
          where: { id: tripId, householdId },
        });
        if (!trip)
          throw new NotFoundException(
            'Shopping trip not found in this household.',
          );
        if (trip.status !== TripStatus.PROPOSED)
          throw new ConflictException(
            'Only proposed shopping trips can be confirmed.',
          );
        const adopted = trip.scheduledFor
          ? await this.adoptEligibleMeals(tx, householdId, trip)
          : [];
        const instances = await tx.cookingInstance.findMany({
          where: { householdId, shoppingTripId: trip.id, status: 'SCHEDULED' },
        });
        const items = this.aggregate(instances);
        // Resolved on the shared client, outside this household transaction.
        const canonical = await this.ingredients.resolveIngredients(
          items.map((item) => item.key),
        );
        await tx.shoppingItem.deleteMany({
          where: { householdId, shoppingTripId: trip.id },
        });
        for (const item of items) {
          const created = await tx.shoppingItem.create({
            data: {
              householdId,
              shoppingTripId: trip.id,
              displayName: item.name,
              canonicalIngredientId: canonical.get(item.key) ?? null,
              demand: item.demand,
              unmeasured: item.unmeasured,
              status: ShoppingItemStatus.NEED_TO_BUY,
            },
          });
          if (item.contributions.length)
            await tx.shoppingItemContribution.createMany({
              data: item.contributions.map((contribution) => ({
                householdId,
                shoppingItemId: created.id,
                cookingInstanceId: contribution.cookingInstanceId,
                recipeTitle: contribution.recipeTitle,
                quantityMin: contribution.quantityMin
                  ? new Prisma.Decimal(contribution.quantityMin)
                  : null,
                quantityMax: contribution.quantityMax
                  ? new Prisma.Decimal(contribution.quantityMax)
                  : null,
                unit: contribution.unit,
              })),
            });
        }
        const updatedTrip = await tx.shoppingTrip.update({
          where: { id: trip.id },
          data: { status: TripStatus.CONFIRMED, revision: { increment: 1 } },
        });
        return {
          trip: updatedTrip,
          canonicalIds: [...new Set(canonical.values())],
          adopted,
        };
      },
    );
    void this.ingredients.requestProfiles(canonicalIds);
    await this.record(accountId, householdId, trip.id, 'trip.confirmed', {});
    // Trips that lost meals are refreshed before the per-meal events announce the move.
    for (const previousTripId of new Set(
      adopted
        .map((meal) => meal.previousShoppingTripId)
        .filter((id): id is string => id !== null),
    )) {
      await this.refreshDemand(accountId, householdId, previousTripId);
    }
    for (const meal of adopted) {
      await this.record(
        accountId,
        householdId,
        meal.cookingInstanceId,
        'cooking.assignment_recalculated',
        {
          previousShoppingTripId: meal.previousShoppingTripId,
          shoppingTripId: meal.shoppingTripId,
          revision: meal.revision,
        },
      );
    }
    await this.notifications.notifyHouseholdExcept({
      householdId,
      actorAccountId: accountId,
      dedupeKey: `trip-confirmed:${trip.id}:${trip.revision}`,
      title: 'Shopping date confirmed',
      body: trip.scheduledFor
        ? `Shopping is confirmed for ${trip.scheduledFor.toLocaleDateString()}.`
        : 'A shopping trip was confirmed.',
      deepLink: `/households/${householdId}/trips/${trip.id}`,
    });
    return this.present(trip);
  }

  async updateItem(
    accountId: string,
    householdId: string,
    tripId: string,
    itemId: string,
    input: UpdateShoppingItemDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    if (
      input.knownQuantity &&
      (!/^\d+(?:\.\d+)?$/.test(input.knownQuantity) ||
        !new Prisma.Decimal(input.knownQuantity).gt(0))
    )
      throw new BadRequestException(
        'Known quantity must be a positive decimal value.',
      );
    const item = await this.prisma.$transaction(async (tx) => {
      const item = await tx.shoppingItem.findFirst({
        where: { id: itemId, householdId, shoppingTripId: tripId },
      });
      if (!item)
        throw new NotFoundException(
          'Shopping item not found in this household trip.',
        );
      const updated = await tx.shoppingItem.update({
        where: { id: item.id },
        data: { status: input.status, revision: { increment: 1 } },
      });
      if (
        input.status === ShoppingItemStatus.CONFIRMED_AT_HOME ||
        input.status === ShoppingItemStatus.PARTIALLY_AVAILABLE
      )
        await tx.pantryAssessment.create({
          data: {
            householdId,
            shoppingItemId: item.id,
            status: input.status,
            confirmedByAccountId: accountId,
            knownQuantity: input.knownQuantity
              ? new Prisma.Decimal(input.knownQuantity)
              : null,
            unit: input.unit?.trim() || this.singleDemandUnit(item.demand),
            demandAtConfirmation: readDemand(item.demand),
          },
        });
      return updated;
    });
    await this.record(
      accountId,
      householdId,
      item.id,
      'shopping_item.changed',
      { tripId, status: item.status },
    );
    const [presented] = await this.presentItems(householdId, [item]);
    return presented;
  }

  async refreshDemand(accountId: string, householdId: string, tripId: string) {
    const canonicalIds: string[] = [];
    const invalidated = await this.prisma.$transaction(async (tx) => {
      const trip = await tx.shoppingTrip.findFirst({
        where: { id: tripId, householdId },
      });
      const activeStatuses: TripStatus[] = [
        TripStatus.CONFIRMED,
        TripStatus.IN_PROGRESS,
      ];
      if (!trip || !activeStatuses.includes(trip.status)) {
        return [];
      }
      const instances = await tx.cookingInstance.findMany({
        where: { householdId, shoppingTripId: trip.id, status: 'SCHEDULED' },
      });
      const aggregate = this.aggregate(instances);
      // Resolved on the shared client, outside this household transaction.
      const canonical = await this.ingredients.resolveIngredients(
        aggregate.map((item) => item.key),
      );
      canonicalIds.push(...new Set(canonical.values()));
      const existing = await tx.shoppingItem.findMany({
        where: { householdId, shoppingTripId: trip.id },
        orderBy: { createdAt: 'asc' },
      });
      const existingByKey = new Map<string, typeof existing>();
      for (const row of existing) {
        const key = normalizeIngredientName(row.displayName);
        existingByKey.set(key, [...(existingByKey.get(key) ?? []), row]);
      }
      const currentKeys = new Set(aggregate.map((item) => item.key));
      const removed = [
        ...existing.filter(
          (row) => !currentKeys.has(normalizeIngredientName(row.displayName)),
        ),
        ...[...existingByKey.entries()]
          .filter(([key]) => currentKeys.has(key))
          .flatMap(([, rows]) => rows.slice(1)),
      ];
      if (removed.length) {
        await tx.shoppingItemContribution.deleteMany({
          where: {
            householdId,
            shoppingItemId: { in: removed.map((item) => item.id) },
          },
        });
        await tx.shoppingItem.deleteMany({
          where: { householdId, id: { in: removed.map((item) => item.id) } },
        });
      }

      const invalidated: Array<{ id: string; displayName: string }> = [];
      for (const item of aggregate) {
        const priorRows = existingByKey.get(item.key) ?? [];
        const prior = priorRows[0];
        const statusesDiffer =
          new Set(priorRows.map((row) => row.status)).size > 1;
        const data = {
          displayName: item.name,
          canonicalIngredientId: canonical.get(item.key) ?? null,
          demand: item.demand as Prisma.InputJsonValue,
          unmeasured: item.unmeasured,
        };
        const saved = prior
          ? await tx.shoppingItem.update({
              where: { id: prior.id },
              data: {
                ...data,
                ...(statusesDiffer
                  ? { status: ShoppingItemStatus.CHECK_AGAIN }
                  : {}),
                revision: { increment: 1 },
              },
            })
          : await tx.shoppingItem.create({
              data: {
                householdId,
                shoppingTripId: trip.id,
                ...data,
                status: ShoppingItemStatus.NEED_TO_BUY,
              },
            });
        await tx.shoppingItemContribution.deleteMany({
          where: { householdId, shoppingItemId: saved.id },
        });
        if (item.contributions.length) {
          await tx.shoppingItemContribution.createMany({
            data: item.contributions.map((contribution) => ({
              householdId,
              shoppingItemId: saved.id,
              cookingInstanceId: contribution.cookingInstanceId,
              recipeTitle: contribution.recipeTitle,
              quantityMin: contribution.quantityMin
                ? new Prisma.Decimal(contribution.quantityMin)
                : null,
              quantityMax: contribution.quantityMax
                ? new Prisma.Decimal(contribution.quantityMax)
                : null,
              unit: contribution.unit,
            })),
          });
        }
        if (!prior) continue;
        if (statusesDiffer) {
          invalidated.push({ id: saved.id, displayName: saved.displayName });
          continue;
        }
        const assessment = await tx.pantryAssessment.findFirst({
          where: { householdId, shoppingItemId: saved.id },
          orderBy: { createdAt: 'desc' },
        });
        if (assessment?.status !== ShoppingItemStatus.CONFIRMED_AT_HOME)
          continue;
        const nextStatus = reassessPantry(item.demand, {
          knownQuantity: assessment.knownQuantity?.toString() ?? null,
          unit: assessment.unit,
          demandAtConfirmation: readDemand(assessment.demandAtConfirmation),
        });
        if (nextStatus === saved.status) continue;
        await tx.shoppingItem.update({
          where: { id: saved.id },
          data: { status: nextStatus, revision: { increment: 1 } },
        });
        invalidated.push({ id: saved.id, displayName: saved.displayName });
      }
      return invalidated;
    });
    void this.ingredients.requestProfiles(canonicalIds);
    for (const item of invalidated) {
      await this.record(
        accountId,
        householdId,
        item.id,
        'pantry.recheck_required',
        {
          tripId,
          displayName: item.displayName,
        },
      );
      await this.notifications.notifyHouseholdExcept({
        householdId,
        actorAccountId: accountId,
        dedupeKey: `pantry-recheck:${item.id}`,
        title: 'Pantry check needs another look',
        body: `${item.displayName} has more planned demand.`,
        deepLink: `/households/${householdId}/trips/${tripId}`,
      });
    }
    return invalidated;
  }

  start(accountId: string, householdId: string, tripId: string) {
    return this.transition(
      accountId,
      householdId,
      tripId,
      [TripStatus.CONFIRMED],
      TripStatus.IN_PROGRESS,
      'trip.started',
    );
  }
  complete(accountId: string, householdId: string, tripId: string) {
    return this.transition(
      accountId,
      householdId,
      tripId,
      [TripStatus.IN_PROGRESS],
      TripStatus.COMPLETED,
      'trip.completed',
    );
  }
  async cancel(accountId: string, householdId: string, tripId: string) {
    const { previousStatus, updated } = await this.applyTransition(
      accountId,
      householdId,
      tripId,
      [TripStatus.PROPOSED, TripStatus.CONFIRMED],
      TripStatus.CANCELLED,
      'trip.cancelled',
    );
    if (previousStatus === TripStatus.CONFIRMED) {
      // A cancelled trip no longer counts as confirmed: its automatic meals move on.
      const recalculated = await this.recalculateAutomaticAssignments(
        householdId,
        updated.id,
      );
      await this.announceRecalculated(
        accountId,
        householdId,
        updated.id,
        recalculated,
      );
    }
    return this.present(updated);
  }

  private async transition(
    accountId: string,
    householdId: string,
    tripId: string,
    from: TripStatus[],
    to: TripStatus,
    action: string,
  ) {
    const { updated } = await this.applyTransition(
      accountId,
      householdId,
      tripId,
      from,
      to,
      action,
    );
    return this.present(updated);
  }

  private async applyTransition(
    accountId: string,
    householdId: string,
    tripId: string,
    from: TripStatus[],
    to: TripStatus,
    action: string,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const trip = await this.prisma.shoppingTrip.findFirst({
      where: { id: tripId, householdId },
    });
    if (!trip)
      throw new NotFoundException('Shopping trip not found in this household.');
    if (!from.includes(trip.status))
      throw new ConflictException(
        `Shopping trip cannot transition from ${trip.status}.`,
      );
    const updated = await this.prisma.shoppingTrip.update({
      where: { id: trip.id },
      data: { status: to, revision: { increment: 1 } },
    });
    await this.record(accountId, householdId, updated.id, action, {});
    return { previousStatus: trip.status, updated };
  }

  private async announceRecalculated(
    accountId: string,
    householdId: string,
    previousShoppingTripId: string,
    recalculated: Array<{
      cookingInstanceId: string;
      shoppingTripId: string | null;
      revision: number;
    }>,
  ) {
    // Replacement trips are refreshed before the per-meal events announce the move.
    for (const shoppingTripId of new Set(
      recalculated
        .map((assignment) => assignment.shoppingTripId)
        .filter((id): id is string => id !== null),
    )) {
      await this.refreshDemand(accountId, householdId, shoppingTripId);
    }
    for (const assignment of recalculated) {
      await this.record(
        accountId,
        householdId,
        assignment.cookingInstanceId,
        'cooking.assignment_recalculated',
        {
          previousShoppingTripId,
          shoppingTripId: assignment.shoppingTripId,
          revision: assignment.revision,
        },
      );
    }
  }

  private aggregate(
    instances: Array<{
      id: string;
      recipeSnapshot: Prisma.JsonValue;
      scaledIngredients: Prisma.JsonValue;
    }>,
  ) {
    const grouped = new Map<string, AggregatedItem>();
    for (const instance of instances) {
      const title = this.recipeTitle(instance.recipeSnapshot);
      for (const ingredient of this.snapshotIngredients(
        instance.scaledIngredients,
      )) {
        if (!ingredient.includeInShopping) continue;
        const key = normalizeIngredientName(ingredient.name);
        if (!key) continue;
        const item = grouped.get(key) ?? {
          key,
          name: ingredient.name.trim(),
          demand: [],
          unmeasured: false,
          contributions: [],
        };
        if (ingredient.quantityMin == null) item.unmeasured = true;
        else item.demand = addQuantity(item.demand, ingredient);
        item.contributions.push({
          cookingInstanceId: instance.id,
          recipeTitle: title,
          quantityMin: ingredient.quantityMin,
          quantityMax: ingredient.quantityMax,
          unit: ingredient.unit,
        });
        grouped.set(key, item);
      }
    }
    return [...grouped.values()];
  }

  private async adoptEligibleMeals(
    tx: Prisma.TransactionClient,
    householdId: string,
    trip: { id: string; scheduledFor: Date | null },
  ) {
    const tripDate = trip.scheduledFor;
    if (!tripDate) return [];
    // Latest confirmed trip on or before a date wins; ties go to the newest trip.
    const confirmedTrips = (
      await tx.shoppingTrip.findMany({
        where: {
          householdId,
          scheduledFor: { not: null },
          OR: [{ status: TripStatus.CONFIRMED }, { id: trip.id }],
        },
      })
    ).sort(
      (a, b) =>
        (b.scheduledFor?.getTime() ?? 0) - (a.scheduledFor?.getTime() ?? 0) ||
        b.createdAt.getTime() - a.createdAt.getTime(),
    );
    const earlierConfirmedTripIds = confirmedTrips
      .filter(
        (candidate) =>
          candidate.id !== trip.id &&
          candidate.status === TripStatus.CONFIRMED &&
          candidate.scheduledFor! < tripDate,
      )
      .map((candidate) => candidate.id);
    const candidates = await tx.cookingInstance.findMany({
      where: {
        householdId,
        assignmentMode: 'AUTOMATIC',
        status: 'SCHEDULED',
        cookingDate: { gte: tripDate },
        OR: [
          { shoppingTripId: null },
          ...(earlierConfirmedTripIds.length
            ? [{ shoppingTripId: { in: earlierConfirmedTripIds } }]
            : []),
        ],
      },
    });
    const adopted: Array<{
      cookingInstanceId: string;
      shoppingTripId: string;
      previousShoppingTripId: string | null;
      revision: number;
    }> = [];
    for (const candidate of candidates) {
      const cookingDate = candidate.cookingDate;
      if (!cookingDate) continue;
      const latest = confirmedTrips.find(
        (confirmed) => confirmed.scheduledFor! <= cookingDate,
      );
      if (latest?.id !== trip.id) continue;
      const { count } = await tx.cookingInstance.updateMany({
        where: {
          id: candidate.id,
          householdId,
          status: 'SCHEDULED',
          assignmentMode: 'AUTOMATIC',
          shoppingTripId: candidate.shoppingTripId,
        },
        data: { shoppingTripId: trip.id, revision: { increment: 1 } },
      });
      if (count === 0) continue;
      if (candidate.shoppingTripId) {
        await tx.tripRecipeAssignment.deleteMany({
          where: {
            householdId,
            shoppingTripId: candidate.shoppingTripId,
            cookingInstanceId: candidate.id,
          },
        });
      }
      await tx.tripRecipeAssignment.upsert({
        where: {
          shoppingTripId_cookingInstanceId: {
            shoppingTripId: trip.id,
            cookingInstanceId: candidate.id,
          },
        },
        create: {
          householdId,
          shoppingTripId: trip.id,
          cookingInstanceId: candidate.id,
          assignmentMode: 'AUTOMATIC',
        },
        update: { assignmentMode: 'AUTOMATIC' },
      });
      adopted.push({
        cookingInstanceId: candidate.id,
        shoppingTripId: trip.id,
        previousShoppingTripId: candidate.shoppingTripId,
        revision: candidate.revision + 1,
      });
    }
    return adopted;
  }

  private async recalculateAutomaticAssignments(
    householdId: string,
    previousShoppingTripId: string,
  ) {
    const instances = await this.prisma.cookingInstance.findMany({
      where: {
        householdId,
        shoppingTripId: previousShoppingTripId,
        assignmentMode: 'AUTOMATIC',
        status: 'SCHEDULED',
      },
    });
    const recalculated: Array<{
      cookingInstanceId: string;
      shoppingTripId: string | null;
      revision: number;
    }> = [];
    for (const instance of instances) {
      const replacement = instance.cookingDate
        ? await this.prisma.shoppingTrip.findFirst({
            where: {
              householdId,
              id: { not: previousShoppingTripId },
              status: TripStatus.CONFIRMED,
              scheduledFor: { lte: instance.cookingDate },
            },
            orderBy: { scheduledFor: 'desc' },
          })
        : null;
      const updated = await this.prisma.cookingInstance.update({
        where: { id: instance.id },
        data: {
          shoppingTripId: replacement?.id ?? null,
          revision: { increment: 1 },
        },
      });
      await this.prisma.tripRecipeAssignment.deleteMany({
        where: {
          householdId,
          shoppingTripId: previousShoppingTripId,
          cookingInstanceId: instance.id,
        },
      });
      if (replacement) {
        await this.prisma.tripRecipeAssignment.upsert({
          where: {
            shoppingTripId_cookingInstanceId: {
              shoppingTripId: replacement.id,
              cookingInstanceId: instance.id,
            },
          },
          create: {
            householdId,
            shoppingTripId: replacement.id,
            cookingInstanceId: instance.id,
            assignmentMode: 'AUTOMATIC',
          },
          update: { assignmentMode: 'AUTOMATIC' },
        });
      }
      recalculated.push({
        cookingInstanceId: instance.id,
        shoppingTripId: replacement?.id ?? null,
        revision: updated.revision,
      });
    }
    return recalculated;
  }

  private snapshotIngredients(value: Prisma.JsonValue): SnapshotIngredient[] {
    if (!Array.isArray(value)) return [];
    return value.filter(
      (item): item is SnapshotIngredient =>
        !!item &&
        typeof item === 'object' &&
        typeof (item as SnapshotIngredient).name === 'string' &&
        typeof (item as SnapshotIngredient).includeInShopping === 'boolean' &&
        ((item as SnapshotIngredient).quantityMin === null ||
          /^\d+(?:\.\d+)?$/.test(
            String((item as SnapshotIngredient).quantityMin),
          )),
    );
  }
  private recipeTitle(value: Prisma.JsonValue) {
    return value &&
      typeof value === 'object' &&
      !Array.isArray(value) &&
      typeof (value as Record<string, unknown>).title === 'string'
      ? (value as Record<string, string>).title
      : 'Untitled recipe';
  }
  private singleDemandUnit(value: Prisma.JsonValue) {
    const demand = readDemand(value);
    return demand.length === 1 ? demand[0].unit : null;
  }

  private async presentItems(
    householdId: string,
    items: Array<{
      id: string;
      displayName: string;
      canonicalIngredientId: string | null;
      demand: Prisma.JsonValue;
      unmeasured: boolean;
      status: ShoppingItemStatus;
      revision: number;
    }>,
  ) {
    const itemIds = items.map((item) => item.id);
    const contributions = await this.prisma.shoppingItemContribution.findMany({
      where: { householdId, shoppingItemId: { in: itemIds } },
      orderBy: { createdAt: 'asc' },
    });
    const partialIds = items
      .filter((item) => item.status === ShoppingItemStatus.PARTIALLY_AVAILABLE)
      .map((item) => item.id);
    const assessments = partialIds.length
      ? await this.prisma.pantryAssessment.findMany({
          where: { householdId, shoppingItemId: { in: partialIds } },
          orderBy: { createdAt: 'desc' },
        })
      : [];
    const canonicalIds = [
      ...new Set(
        items
          .map((item) => item.canonicalIngredientId)
          .filter((id): id is string => !!id),
      ),
    ];
    const profiles = canonicalIds.length
      ? await this.prisma.canonicalIngredient.findMany({
          where: { id: { in: canonicalIds } },
        })
      : [];
    const profileById = new Map(
      profiles.map((profile) => [profile.id, profile]),
    );
    return items.map((item) => {
      const demand = readDemand(item.demand);
      const profile = item.canonicalIngredientId
        ? profileById.get(item.canonicalIngredientId)
        : undefined;
      const snapshot: IngredientProfileSnapshot | null = profile
        ? {
            profileStatus: profile.profileStatus,
            shoppingUnit: profile.shoppingUnit,
            unitEstimates: profile.unitEstimates,
            packageSizes: profile.packageSizes,
          }
        : null;
      const assessment = assessments.find(
        (candidate) => candidate.shoppingItemId === item.id,
      );
      let alreadyHave: Prisma.Decimal | undefined;
      if (
        assessment?.knownQuantity &&
        demand.length === 1 &&
        snapshot?.shoppingUnit
      ) {
        const shopping = parseUnit(snapshot.shoppingUnit);
        if (
          shopping.dimension === demand[0].dimension &&
          shopping.baseUnit === demand[0].unit
        )
          alreadyHave =
            exactKnown(
              assessment.knownQuantity.toString(),
              assessment.unit,
              demand[0],
            ) ?? undefined;
      }
      return {
        id: item.id,
        displayName: item.displayName,
        status: item.status,
        revision: item.revision,
        demand,
        unmeasured: item.unmeasured,
        estimate: estimateShopping(demand, snapshot, alreadyHave),
        profileStatus: profile?.profileStatus ?? null,
        contributions: contributions
          .filter((contribution) => contribution.shoppingItemId === item.id)
          .map((contribution) => ({
            cookingInstanceId: contribution.cookingInstanceId,
            recipeTitle: contribution.recipeTitle,
            quantityMin: contribution.quantityMin?.toString() ?? null,
            quantityMax: contribution.quantityMax?.toString() ?? null,
            unit: contribution.unit,
          })),
      };
    });
  }
  private async record(
    accountId: string,
    householdId: string,
    entityId: string,
    action: string,
    summary: Record<string, unknown>,
  ) {
    const account = await this.prisma.account.findUniqueOrThrow({
      where: { id: accountId },
      select: { displayName: true },
    });
    return this.activity.record(
      householdId,
      { accountId, displayName: account.displayName },
      'shopping_trip',
      entityId,
      action,
      summary,
    );
  }
  private present(trip: {
    id: string;
    scheduledFor: Date | null;
    status: string;
    revision: number;
    createdByAccountId: string;
    createdAt: Date;
    updatedAt: Date;
  }) {
    return {
      id: trip.id,
      scheduledFor: trip.scheduledFor?.toISOString() ?? null,
      status: trip.status,
      revision: trip.revision,
      createdByAccountId: trip.createdByAccountId,
      createdAt: trip.createdAt.toISOString(),
      updatedAt: trip.updatedAt.toISOString(),
    };
  }
}
