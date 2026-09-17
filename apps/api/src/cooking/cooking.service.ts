import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { Prisma, TransferStatus, TripStatus } from '@prisma/client';
import { ActivityService } from '../activity/activity.service';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';
import { QuantityService } from '../recipes/quantity.service';
import { TripsService } from '../trips/trips.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  CreateCookingInstanceDto,
  CookAgainDto,
  RequestCookTransferDto,
  ResolveCookTransferDto,
} from './cooking.dto';

@Injectable()
export class CookingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
    private readonly quantities: QuantityService,
    private readonly activity: ActivityService,
    @Optional() private readonly trips?: TripsService,
    @Optional() private readonly notifications?: NotificationsService,
  ) {}

  async create(
    accountId: string,
    householdId: string,
    input: CreateCookingInstanceDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const cookingDate = input.cookingDate ? new Date(input.cookingDate) : null;
    if (cookingDate && Number.isNaN(cookingDate.getTime())) {
      throw new BadRequestException(
        'Cooking date must be a valid ISO 8601 value.',
      );
    }
    const recipe = await this.prisma.recipe.findFirst({
      where: { id: input.recipeId, householdId, deletedAt: null },
    });
    if (!recipe?.currentVersionId)
      throw new NotFoundException('Recipe not found in this household.');
    const [version, ingredients] = await Promise.all([
      this.prisma.recipeVersion.findFirst({
        where: {
          id: recipe.currentVersionId,
          householdId,
          recipeId: recipe.id,
        },
      }),
      this.prisma.recipeIngredient.findMany({
        where: { householdId, recipeVersionId: recipe.currentVersionId },
        orderBy: { sortOrder: 'asc' },
      }),
    ]);
    if (!version)
      throw new NotFoundException(
        'Recipe version not found in this household.',
      );
    if (!version.originalServings?.gt(0)) {
      throw new BadRequestException(
        'This recipe needs a numeric original serving yield before it can be scaled.',
      );
    }
    // An explicitly chosen trip is a manual choice: automatic rules never move it.
    const assignmentMode =
      input.assignmentMode ?? (input.shoppingTripId ? 'MANUAL' : 'AUTOMATIC');
    const shoppingTripId = await this.shoppingTripId(
      householdId,
      cookingDate,
      input.shoppingTripId,
      assignmentMode,
    );
    const targetServings = this.positiveDecimal(input.targetServings);
    const scaledIngredients = ingredients.map((ingredient) => {
      const scaled = this.quantities.scale(
        {
          min: ingredient.quantityMin?.toString() ?? null,
          max: ingredient.quantityMax?.toString() ?? null,
          unit: ingredient.originalUnit,
          originalText: ingredient.originalText,
        },
        version.originalServings!.toString(),
        targetServings,
      );
      return {
        name: ingredient.name,
        quantityMin: scaled.min,
        quantityMax: scaled.max,
        unit: scaled.unit,
        originalText: ingredient.originalText,
        classification: ingredient.classification,
        includeInShopping: ingredient.includeInShopping,
      };
    });
    const instance = await this.prisma.cookingInstance.create({
      data: {
        householdId,
        recipeId: recipe.id,
        recipeVersionId: version.id,
        recipeSnapshot: {
          title: version.title,
          version: version.version,
          originalServings: version.originalServings.toString(),
          readiness: version.readiness,
        },
        scaledIngredients,
        targetServings: new Prisma.Decimal(targetServings),
        cookingDate,
        shoppingTripId,
        assignmentMode,
        confirmedCookAccountId: accountId,
      },
    });
    if (shoppingTripId) {
      await this.prisma.tripRecipeAssignment.upsert({
        where: {
          shoppingTripId_cookingInstanceId: {
            shoppingTripId,
            cookingInstanceId: instance.id,
          },
        },
        create: {
          householdId,
          shoppingTripId,
          cookingInstanceId: instance.id,
          assignmentMode,
        },
        update: { assignmentMode },
      });
    }
    const account = await this.prisma.account.findUniqueOrThrow({
      where: { id: accountId },
      select: { displayName: true },
    });
    await this.activity.record(
      householdId,
      { accountId, displayName: account.displayName },
      'cooking_instance',
      instance.id,
      'cooking.created',
      {
        recipeId: recipe.id,
        cookingDate: cookingDate?.toISOString() ?? null,
        shoppingTripId,
        assignmentMode,
      },
    );
    if (shoppingTripId) {
      await this.trips?.refreshDemand(accountId, householdId, shoppingTripId);
    }
    return this.present(instance);
  }

  async list(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instances = await this.prisma.cookingInstance.findMany({
      where: { householdId },
      orderBy: [{ cookingDate: 'asc' }, { createdAt: 'desc' }],
    });
    return instances.map((instance) => this.present(instance));
  }

  async requestTransfer(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
    input: RequestCookTransferDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    await this.access.requireActiveMembership(
      input.targetAccountId,
      householdId,
    );
    const transfer = await this.prisma.$transaction(async (tx) => {
      const instance = await tx.cookingInstance.findFirst({
        where: { id: cookingInstanceId, householdId, status: 'SCHEDULED' },
      });
      if (!instance)
        throw new NotFoundException(
          'Scheduled cooking instance not found in this household.',
        );
      if (instance.confirmedCookAccountId === input.targetAccountId) {
        throw new BadRequestException(
          'That member is already the confirmed cook.',
        );
      }
      if (instance.pendingCookAccountId) {
        throw new ConflictException(
          'A cook transfer is already awaiting a response.',
        );
      }
      const transfer = await tx.cookAssignmentTransfer.create({
        data: {
          householdId,
          cookingInstanceId: instance.id,
          fromAccountId: instance.confirmedCookAccountId,
          targetAccountId: input.targetAccountId,
        },
      });
      await tx.cookingInstance.update({
        where: { id: instance.id },
        data: {
          pendingCookAccountId: input.targetAccountId,
          revision: { increment: 1 },
        },
      });
      return transfer;
    });
    await this.recordActivity(
      accountId,
      householdId,
      'cook_assignment.requested',
      cookingInstanceId,
      { targetAccountId: input.targetAccountId },
    );
    await this.notifications?.notifyAccount({
      householdId,
      accountId: input.targetAccountId,
      dedupeKey: `cook-transfer-request:${transfer.id}`,
      title: 'Cook handoff requested',
      body: 'A household member asked you to take responsibility for a meal.',
      deepLink: `/households/${householdId}/cooking/${cookingInstanceId}`,
    });
    return {
      id: transfer.id,
      cookingInstanceId: transfer.cookingInstanceId,
      fromAccountId: transfer.fromAccountId,
      targetAccountId: transfer.targetAccountId,
      status: transfer.status,
      createdAt: transfer.createdAt.toISOString(),
    };
  }

  async resolveTransfer(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
    input: ResolveCookTransferDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instance = await this.prisma.$transaction(async (tx) => {
      const transfer = await tx.cookAssignmentTransfer.findFirst({
        where: {
          householdId,
          cookingInstanceId,
          targetAccountId: accountId,
          status: TransferStatus.PENDING,
        },
        orderBy: { createdAt: 'desc' },
      });
      if (!transfer)
        throw new NotFoundException(
          'No pending cook transfer is awaiting your response.',
        );
      const instance = await tx.cookingInstance.findFirst({
        where: { id: cookingInstanceId, householdId, status: 'SCHEDULED' },
      });
      if (!instance || instance.pendingCookAccountId !== accountId) {
        throw new ConflictException('This cook transfer is no longer current.');
      }
      await tx.cookAssignmentTransfer.update({
        where: { id: transfer.id },
        data: {
          status: input.accept
            ? TransferStatus.ACCEPTED
            : TransferStatus.DECLINED,
          resolvedAt: new Date(),
        },
      });
      return tx.cookingInstance.update({
        where: { id: instance.id },
        data: {
          confirmedCookAccountId: input.accept
            ? accountId
            : instance.confirmedCookAccountId,
          pendingCookAccountId: null,
          revision: { increment: 1 },
        },
      });
    });
    await this.recordActivity(
      accountId,
      householdId,
      input.accept ? 'cook_assignment.accepted' : 'cook_assignment.declined',
      cookingInstanceId,
      {},
    );
    await this.notifications?.notifyHouseholdExcept({
      householdId,
      actorAccountId: accountId,
      dedupeKey: `cook-transfer-resolved:${cookingInstanceId}:${instance.revision}`,
      title: 'Cook handoff updated',
      body: input.accept
        ? 'A cook handoff was accepted.'
        : 'A cook handoff was declined.',
      deepLink: `/households/${householdId}/cooking/${cookingInstanceId}`,
    });
    return this.present(instance);
  }

  async markCooked(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instance = await this.prisma.cookingInstance.findFirst({
      where: { id: cookingInstanceId, householdId, status: 'SCHEDULED' },
    });
    if (!instance)
      throw new NotFoundException(
        'Scheduled cooking instance not found in this household.',
      );
    const archived = await this.prisma.cookingInstance.update({
      where: { id: instance.id },
      data: {
        status: 'ARCHIVED',
        archivedAt: new Date(),
        revision: { increment: 1 },
      },
    });
    await this.recordActivity(
      accountId,
      householdId,
      'cooking.archived',
      archived.id,
      {},
    );
    return this.present(archived);
  }

  async cookAgain(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
    input: CookAgainDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instance = await this.prisma.cookingInstance.findFirst({
      where: { id: cookingInstanceId, householdId, status: 'ARCHIVED' },
    });
    if (!instance)
      throw new NotFoundException(
        'Archived cooking instance not found in this household.',
      );
    return this.create(accountId, householdId, {
      recipeId: instance.recipeId,
      targetServings:
        input.targetServings ?? instance.targetServings.toString(),
      cookingDate: input.cookingDate,
    });
  }

  async assignTrip(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
    shoppingTripId: string | null,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    if (shoppingTripId) {
      const trip = await this.prisma.shoppingTrip.findFirst({
        where: {
          id: shoppingTripId,
          householdId,
          status: {
            in: [
              TripStatus.PROPOSED,
              TripStatus.CONFIRMED,
              TripStatus.IN_PROGRESS,
            ],
          },
        },
      });
      if (!trip)
        throw new NotFoundException(
          'Shopping trip not found in this household.',
        );
    }
    const instance = await this.prisma.cookingInstance.findFirst({
      where: { id: cookingInstanceId, householdId },
    });
    if (!instance)
      throw new NotFoundException(
        'Cooking instance not found in this household.',
      );
    if (instance.status !== 'SCHEDULED')
      throw new ConflictException(
        'Only scheduled meals can be reassigned to a shopping trip.',
      );
    const previousTripId = instance.shoppingTripId;
    const updated = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.cookingInstance.update({
        where: { id: instance.id },
        data: {
          shoppingTripId,
          assignmentMode: 'MANUAL',
          revision: { increment: 1 },
        },
      });
      if (previousTripId) {
        await tx.tripRecipeAssignment.deleteMany({
          where: {
            householdId,
            shoppingTripId: previousTripId,
            cookingInstanceId: instance.id,
          },
        });
      }
      if (shoppingTripId) {
        await tx.tripRecipeAssignment.upsert({
          where: {
            shoppingTripId_cookingInstanceId: {
              shoppingTripId,
              cookingInstanceId: instance.id,
            },
          },
          create: {
            householdId,
            shoppingTripId,
            cookingInstanceId: instance.id,
            assignmentMode: 'MANUAL',
          },
          update: { assignmentMode: 'MANUAL' },
        });
      }
      return updated;
    });
    const tripIdsToRefresh = new Set<string>();
    if (previousTripId) tripIdsToRefresh.add(previousTripId);
    if (shoppingTripId) tripIdsToRefresh.add(shoppingTripId);
    for (const id of tripIdsToRefresh) {
      await this.trips?.refreshDemand(accountId, householdId, id);
    }
    // Recorded after demand refresh so realtime clients reload settled trips.
    await this.recordActivity(
      accountId,
      householdId,
      'cooking.trip_changed',
      instance.id,
      { previousShoppingTripId: previousTripId, shoppingTripId },
    );
    return this.present(updated);
  }

  private async shoppingTripId(
    householdId: string,
    cookingDate: Date | null,
    requestedTripId: string | undefined,
    assignmentMode: 'AUTOMATIC' | 'MANUAL',
  ) {
    if (requestedTripId) {
      const trip = await this.prisma.shoppingTrip.findFirst({
        where: {
          id: requestedTripId,
          householdId,
          status: {
            in: [
              TripStatus.PROPOSED,
              TripStatus.CONFIRMED,
              TripStatus.IN_PROGRESS,
            ],
          },
        },
      });
      if (!trip)
        throw new NotFoundException(
          'Shopping trip not found in this household.',
        );
      return trip.id;
    }
    if (assignmentMode === 'MANUAL' || !cookingDate) return null;
    const suggested = await this.prisma.shoppingTrip.findFirst({
      where: {
        householdId,
        status: TripStatus.CONFIRMED,
        scheduledFor: { lte: cookingDate },
      },
      orderBy: { scheduledFor: 'desc' },
    });
    return suggested?.id ?? null;
  }

  private positiveDecimal(value: string) {
    if (!/^\d+(?:\.\d+)?$/.test(value) || !new Prisma.Decimal(value).gt(0)) {
      throw new BadRequestException(
        'Target servings must be a positive decimal value.',
      );
    }
    return value;
  }

  private async recordActivity(
    accountId: string,
    householdId: string,
    action: string,
    entityId: string,
    summary: Record<string, unknown>,
  ) {
    const account = await this.prisma.account.findUniqueOrThrow({
      where: { id: accountId },
      select: { displayName: true },
    });
    await this.activity.record(
      householdId,
      { accountId, displayName: account.displayName },
      'cooking_instance',
      entityId,
      action,
      summary,
    );
  }

  private present(instance: {
    id: string;
    recipeId: string;
    recipeVersionId: string;
    recipeSnapshot: Prisma.JsonValue;
    scaledIngredients: Prisma.JsonValue;
    targetServings: Prisma.Decimal;
    cookingDate: Date | null;
    shoppingTripId: string | null;
    assignmentMode: string;
    confirmedCookAccountId: string;
    pendingCookAccountId: string | null;
    status: string;
    revision: number;
    createdAt: Date;
    updatedAt: Date;
  }) {
    return {
      id: instance.id,
      recipeId: instance.recipeId,
      recipeVersionId: instance.recipeVersionId,
      recipeSnapshot: instance.recipeSnapshot,
      scaledIngredients: instance.scaledIngredients,
      targetServings: instance.targetServings.toString(),
      cookingDate: instance.cookingDate?.toISOString() ?? null,
      shoppingTripId: instance.shoppingTripId,
      assignmentMode: instance.assignmentMode,
      confirmedCookAccountId: instance.confirmedCookAccountId,
      pendingCookAccountId: instance.pendingCookAccountId,
      status: instance.status,
      revision: instance.revision,
      createdAt: instance.createdAt.toISOString(),
      updatedAt: instance.updatedAt.toISOString(),
    };
  }
}
