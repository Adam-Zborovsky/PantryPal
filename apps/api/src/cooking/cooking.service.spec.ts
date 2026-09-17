import { ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma, RecipeReadiness, TripStatus } from '@prisma/client';
import { ActivityService } from '../activity/activity.service';
import { HouseholdAccessService } from '../households/household-access.service';
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { QuantityService } from '../recipes/quantity.service';
import { TripsService } from '../trips/trips.service';
import { CookingService } from './cooking.service';

describe('CookingService', () => {
  const householdId = 'household-1';
  const accountId = 'account-1';
  const now = new Date('2026-08-16T12:00:00.000Z');

  it('creates a scaled cooking instance and suggests the latest confirmed trip', async () => {
    const prisma = {
      recipe: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'recipe-1',
          householdId,
          currentVersionId: 'version-1',
        }),
      },
      recipeVersion: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'version-1',
          recipeId: 'recipe-1',
          version: 2,
          title: 'Tomato soup',
          originalServings: new Prisma.Decimal('2'),
          readiness: RecipeReadiness.SHOPPING_READY,
        }),
      },
      recipeIngredient: {
        findMany: jest.fn().mockResolvedValue([
          {
            name: 'tomatoes',
            quantityMin: new Prisma.Decimal('3'),
            quantityMax: null,
            originalUnit: 'each',
            originalText: '3 tomatoes',
            classification: 'REQUIRED',
            includeInShopping: true,
          },
        ]),
      },
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({ id: 'trip-1' }),
      },
      cookingInstance: {
        create: jest.fn().mockResolvedValue({
          id: 'cooking-1',
          recipeId: 'recipe-1',
          recipeVersionId: 'version-1',
          recipeSnapshot: { title: 'Tomato soup' },
          scaledIngredients: [{ name: 'tomatoes', quantityMin: '6' }],
          targetServings: new Prisma.Decimal('4'),
          cookingDate: new Date('2026-08-20T18:00:00.000Z'),
          shoppingTripId: 'trip-1',
          assignmentMode: 'AUTOMATIC',
          confirmedCookAccountId: accountId,
          pendingCookAccountId: null,
          status: 'SCHEDULED',
          revision: 1,
          createdAt: now,
          updatedAt: now,
        }),
      },
      tripRecipeAssignment: { upsert: jest.fn().mockResolvedValue(undefined) },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const access = {
      requireActiveMembership: jest.fn().mockResolvedValue(undefined),
    };
    const activity = { record: jest.fn().mockResolvedValue(undefined) };
    const service = new CookingService(
      prisma as unknown as PrismaService,
      access as unknown as HouseholdAccessService,
      new QuantityService(),
      activity as unknown as ActivityService,
    );

    const result = await service.create(accountId, householdId, {
      recipeId: 'recipe-1',
      targetServings: '4',
      cookingDate: '2026-08-20T18:00:00.000Z',
    });

    expect(prisma.shoppingTrip.findFirst).toHaveBeenCalledWith({
      where: {
        householdId,
        status: TripStatus.CONFIRMED,
        scheduledFor: { lte: new Date('2026-08-20T18:00:00.000Z') },
      },
      orderBy: { scheduledFor: 'desc' },
    });
    expect(prisma.cookingInstance.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          shoppingTripId: 'trip-1',
          targetServings: new Prisma.Decimal('4'),
          scaledIngredients: expect.arrayContaining([
            expect.objectContaining({ name: 'tomatoes', quantityMin: '6' }),
          ]),
        }),
      }),
    );
    expect(prisma.tripRecipeAssignment.upsert).toHaveBeenCalledWith({
      where: {
        shoppingTripId_cookingInstanceId: {
          shoppingTripId: 'trip-1',
          cookingInstanceId: 'cooking-1',
        },
      },
      create: {
        householdId,
        shoppingTripId: 'trip-1',
        cookingInstanceId: 'cooking-1',
        assignmentMode: 'AUTOMATIC',
      },
      update: { assignmentMode: 'AUTOMATIC' },
    });
    expect(result).toMatchObject({
      id: 'cooking-1',
      targetServings: '4',
      shoppingTripId: 'trip-1',
    });
    expect(activity.record).toHaveBeenCalledWith(
      householdId,
      { accountId, displayName: 'Ada' },
      'cooking_instance',
      'cooking-1',
      'cooking.created',
      expect.objectContaining({ shoppingTripId: 'trip-1' }),
    );
  });

  it('keeps Quick Cook unassigned when no cooking date is supplied', async () => {
    const prisma = {
      recipe: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: 'recipe-1', currentVersionId: 'version-1' }),
      },
      recipeVersion: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'version-1',
          recipeId: 'recipe-1',
          version: 1,
          title: 'Soup',
          originalServings: new Prisma.Decimal('2'),
          readiness: RecipeReadiness.COOK_READY,
        }),
      },
      recipeIngredient: { findMany: jest.fn().mockResolvedValue([]) },
      shoppingTrip: { findFirst: jest.fn() },
      cookingInstance: {
        create: jest.fn().mockResolvedValue({
          id: 'cooking-1',
          recipeId: 'recipe-1',
          recipeVersionId: 'version-1',
          recipeSnapshot: {},
          scaledIngredients: [],
          targetServings: new Prisma.Decimal('2'),
          cookingDate: null,
          shoppingTripId: null,
          assignmentMode: 'AUTOMATIC',
          confirmedCookAccountId: accountId,
          pendingCookAccountId: null,
          status: 'SCHEDULED',
          revision: 1,
          createdAt: now,
          updatedAt: now,
        }),
      },
      tripRecipeAssignment: { upsert: jest.fn() },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const service = new CookingService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      new QuantityService(),
      { record: jest.fn() } as unknown as ActivityService,
    );

    await service.create(accountId, householdId, {
      recipeId: 'recipe-1',
      targetServings: '2',
    });

    expect(prisma.shoppingTrip.findFirst).not.toHaveBeenCalled();
    expect(prisma.cookingInstance.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          cookingDate: null,
          shoppingTripId: null,
        }),
      }),
    );
  });

  it('saves an explicitly chosen trip as manual so a trip date edit never moves it', async () => {
    type StoredMeal = {
      id: string;
      householdId: string;
      shoppingTripId: string | null;
      assignmentMode: string;
      status: string;
      cookingDate: Date | null;
    };
    const stored: StoredMeal[] = [];
    const cookingPrisma = {
      recipe: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: 'recipe-1', currentVersionId: 'version-1' }),
      },
      recipeVersion: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'version-1',
          recipeId: 'recipe-1',
          version: 1,
          title: 'Soup',
          originalServings: new Prisma.Decimal('2'),
          readiness: RecipeReadiness.COOK_READY,
        }),
      },
      recipeIngredient: { findMany: jest.fn().mockResolvedValue([]) },
      shoppingTrip: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: 'trip-1', status: TripStatus.CONFIRMED }),
      },
      cookingInstance: {
        create: jest.fn((args: { data: Record<string, unknown> }) => {
          const meal = {
            id: 'cooking-1',
            householdId,
            shoppingTripId: args.data.shoppingTripId as string | null,
            assignmentMode: args.data.assignmentMode as string,
            status: 'SCHEDULED',
            cookingDate: args.data.cookingDate as Date | null,
          };
          stored.push(meal);
          return Promise.resolve({
            ...meal,
            recipeId: 'recipe-1',
            recipeVersionId: 'version-1',
            recipeSnapshot: {},
            scaledIngredients: [],
            targetServings: new Prisma.Decimal('2'),
            confirmedCookAccountId: accountId,
            pendingCookAccountId: null,
            revision: 1,
            createdAt: now,
            updatedAt: now,
          });
        }),
      },
      tripRecipeAssignment: { upsert: jest.fn().mockResolvedValue(undefined) },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const cooking = new CookingService(
      cookingPrisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      new QuantityService(),
      { record: jest.fn() } as unknown as ActivityService,
    );

    await cooking.create(accountId, householdId, {
      recipeId: 'recipe-1',
      targetServings: '2',
      cookingDate: '2026-08-21T18:00:00.000Z',
      shoppingTripId: 'trip-1',
    });

    expect(cookingPrisma.cookingInstance.create.mock.calls[0][0].data).toEqual(
      expect.objectContaining({
        shoppingTripId: 'trip-1',
        assignmentMode: 'MANUAL',
      }),
    );
    const [[upsertArgs]] = cookingPrisma.tripRecipeAssignment.upsert.mock
      .calls as Array<[{ create: { assignmentMode: string } }]>;
    expect(upsertArgs.create.assignmentMode).toBe('MANUAL');

    const tripDate = new Date('2026-08-20T10:00:00.000Z');
    const tripsPrisma = {
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'trip-1',
          scheduledFor: tripDate,
          status: TripStatus.CONFIRMED,
        }),
        update: jest.fn().mockResolvedValue({
          id: 'trip-1',
          scheduledFor: new Date('2026-08-22T10:00:00.000Z'),
          status: TripStatus.PROPOSED,
          revision: 2,
          createdByAccountId: accountId,
          createdAt: now,
          updatedAt: now,
        }),
      },
      cookingInstance: {
        findMany: jest.fn((args: { where: Partial<StoredMeal> }) =>
          Promise.resolve(
            stored.filter((meal) =>
              Object.entries(args.where).every(
                ([key, value]) => meal[key as keyof StoredMeal] === value,
              ),
            ),
          ),
        ),
        update: jest.fn(),
      },
      tripRecipeAssignment: { deleteMany: jest.fn(), upsert: jest.fn() },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const trips = new TripsService(
      tripsPrisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      { record: jest.fn() } as unknown as ActivityService,
      {
        notifyHouseholdExcept: jest.fn(),
      } as unknown as NotificationsService,
      {} as IngredientProfileService,
    );

    await trips.update(accountId, householdId, 'trip-1', {
      scheduledFor: '2026-08-22T10:00:00.000Z',
    });

    expect(tripsPrisma.cookingInstance.findMany).toHaveBeenCalled();
    expect(tripsPrisma.cookingInstance.update).not.toHaveBeenCalled();
    expect(tripsPrisma.tripRecipeAssignment.deleteMany).not.toHaveBeenCalled();
    expect(stored[0]).toMatchObject({
      shoppingTripId: 'trip-1',
      assignmentMode: 'MANUAL',
    });
  });

  it('creates a pending transfer without changing the confirmed cook', async () => {
    const transaction = {
      cookingInstance: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'cooking-1',
          confirmedCookAccountId: accountId,
          pendingCookAccountId: null,
        }),
        update: jest.fn().mockResolvedValue(undefined),
      },
      cookAssignmentTransfer: {
        create: jest.fn().mockResolvedValue({
          id: 'transfer-1',
          cookingInstanceId: 'cooking-1',
          fromAccountId: accountId,
          targetAccountId: 'account-2',
          status: 'PENDING',
          createdAt: now,
        }),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(transaction)),
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const access = {
      requireActiveMembership: jest.fn().mockResolvedValue(undefined),
    };
    const activity = { record: jest.fn().mockResolvedValue(undefined) };
    const service = new CookingService(
      prisma as unknown as PrismaService,
      access as unknown as HouseholdAccessService,
      new QuantityService(),
      activity as unknown as ActivityService,
    );

    const result = await service.requestTransfer(
      accountId,
      householdId,
      'cooking-1',
      { targetAccountId: 'account-2' },
    );

    expect(access.requireActiveMembership).toHaveBeenCalledWith(
      'account-2',
      householdId,
    );
    expect(transaction.cookAssignmentTransfer.create).toHaveBeenCalledWith({
      data: {
        householdId,
        cookingInstanceId: 'cooking-1',
        fromAccountId: accountId,
        targetAccountId: 'account-2',
      },
    });
    expect(transaction.cookingInstance.update).toHaveBeenCalledWith({
      where: { id: 'cooking-1' },
      data: {
        pendingCookAccountId: 'account-2',
        revision: { increment: 1 },
      },
    });
    expect(result).toMatchObject({ id: 'transfer-1', status: 'PENDING' });
  });

  describe('assignTrip', () => {
    const cookingInstanceId = 'cooking-1';

    const baseInstance = (overrides: Record<string, unknown> = {}) => ({
      id: cookingInstanceId,
      recipeId: 'recipe-1',
      recipeVersionId: 'version-1',
      recipeSnapshot: {},
      scaledIngredients: [],
      targetServings: new Prisma.Decimal('2'),
      cookingDate: null,
      shoppingTripId: 'trip-old',
      assignmentMode: 'AUTOMATIC',
      confirmedCookAccountId: accountId,
      pendingCookAccountId: null,
      status: 'SCHEDULED',
      revision: 1,
      createdAt: now,
      updatedAt: now,
      ...overrides,
    });

    const buildService = (
      prisma: unknown,
      trips?: unknown,
      activity: unknown = { record: jest.fn().mockResolvedValue(undefined) },
    ) =>
      new CookingService(
        prisma as PrismaService,
        {
          requireActiveMembership: jest.fn().mockResolvedValue(undefined),
        } as unknown as HouseholdAccessService,
        new QuantityService(),
        activity as ActivityService,
        trips as TripsService | undefined,
      );

    const withTransaction = <T extends Record<string, unknown>>(client: T) => {
      const order: string[] = [];
      const prisma = {
        ...client,
        $transaction: jest.fn(async (callback: (tx: T) => Promise<unknown>) => {
          order.push('begin');
          const result = await callback(client);
          order.push('commit');
          return result;
        }),
      };
      return { prisma, order };
    };

    it('assigns a meal to a new trip, marks it manual, and refreshes both trips', async () => {
      const { prisma, order } = withTransaction({
        shoppingTrip: {
          findFirst: jest.fn().mockResolvedValue({
            id: 'trip-new',
            status: TripStatus.CONFIRMED,
          }),
        },
        cookingInstance: {
          findFirst: jest.fn().mockResolvedValue(baseInstance()),
          update: jest.fn().mockResolvedValue(
            baseInstance({
              shoppingTripId: 'trip-new',
              assignmentMode: 'MANUAL',
              revision: 2,
            }),
          ),
        },
        tripRecipeAssignment: {
          deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
          upsert: jest.fn().mockResolvedValue(undefined),
        },
        account: {
          findUniqueOrThrow: jest
            .fn()
            .mockResolvedValue({ displayName: 'Ada' }),
        },
      });
      const trips = {
        refreshDemand: jest.fn((_account: string, _household: string, id) => {
          order.push(`refresh:${id}`);
          return Promise.resolve([]);
        }),
      };
      const activity = {
        record: jest.fn(() => {
          order.push('activity');
          return Promise.resolve(undefined);
        }),
      };
      prisma.cookingInstance.update.mockImplementation(() => {
        order.push('update');
        return Promise.resolve(
          baseInstance({
            shoppingTripId: 'trip-new',
            assignmentMode: 'MANUAL',
            revision: 2,
          }),
        );
      });
      prisma.tripRecipeAssignment.upsert.mockImplementation(() => {
        order.push('upsert');
        return Promise.resolve(undefined);
      });
      const service = buildService(prisma, trips, activity);

      const result = await service.assignTrip(
        accountId,
        householdId,
        cookingInstanceId,
        'trip-new',
      );

      expect(order).toEqual([
        'begin',
        'update',
        'upsert',
        'commit',
        'refresh:trip-old',
        'refresh:trip-new',
        'activity',
      ]);

      expect(prisma.cookingInstance.update).toHaveBeenCalledWith({
        where: { id: cookingInstanceId },
        data: {
          shoppingTripId: 'trip-new',
          assignmentMode: 'MANUAL',
          revision: { increment: 1 },
        },
      });
      expect(prisma.tripRecipeAssignment.deleteMany).toHaveBeenCalledWith({
        where: {
          householdId,
          shoppingTripId: 'trip-old',
          cookingInstanceId,
        },
      });
      expect(prisma.tripRecipeAssignment.upsert).toHaveBeenCalledWith({
        where: {
          shoppingTripId_cookingInstanceId: {
            shoppingTripId: 'trip-new',
            cookingInstanceId,
          },
        },
        create: {
          householdId,
          shoppingTripId: 'trip-new',
          cookingInstanceId,
          assignmentMode: 'MANUAL',
        },
        update: { assignmentMode: 'MANUAL' },
      });
      expect(trips.refreshDemand).toHaveBeenCalledWith(
        accountId,
        householdId,
        'trip-old',
      );
      expect(trips.refreshDemand).toHaveBeenCalledWith(
        accountId,
        householdId,
        'trip-new',
      );
      expect(trips.refreshDemand).toHaveBeenCalledTimes(2);
      expect(result).toMatchObject({
        id: cookingInstanceId,
        shoppingTripId: 'trip-new',
        assignmentMode: 'MANUAL',
      });
    });

    it('clears a trip assignment, marks it manual, and refreshes only the old trip', async () => {
      const { prisma } = withTransaction({
        cookingInstance: {
          findFirst: jest.fn().mockResolvedValue(baseInstance()),
          update: jest.fn().mockResolvedValue(
            baseInstance({
              shoppingTripId: null,
              assignmentMode: 'MANUAL',
              revision: 2,
            }),
          ),
        },
        tripRecipeAssignment: {
          deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
          upsert: jest.fn(),
        },
        account: {
          findUniqueOrThrow: jest
            .fn()
            .mockResolvedValue({ displayName: 'Ada' }),
        },
      });
      const trips = { refreshDemand: jest.fn().mockResolvedValue(undefined) };
      const service = buildService(prisma, trips);

      const result = await service.assignTrip(
        accountId,
        householdId,
        cookingInstanceId,
        null,
      );

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);

      expect(prisma.cookingInstance.update).toHaveBeenCalledWith({
        where: { id: cookingInstanceId },
        data: {
          shoppingTripId: null,
          assignmentMode: 'MANUAL',
          revision: { increment: 1 },
        },
      });
      expect(prisma.tripRecipeAssignment.deleteMany).toHaveBeenCalledWith({
        where: {
          householdId,
          shoppingTripId: 'trip-old',
          cookingInstanceId,
        },
      });
      expect(prisma.tripRecipeAssignment.upsert).not.toHaveBeenCalled();
      expect(trips.refreshDemand).toHaveBeenCalledWith(
        accountId,
        householdId,
        'trip-old',
      );
      expect(trips.refreshDemand).toHaveBeenCalledTimes(1);
      expect(result).toMatchObject({
        id: cookingInstanceId,
        shoppingTripId: null,
        assignmentMode: 'MANUAL',
      });
    });

    it('rejects assignment to a trip that is not open in the household', async () => {
      const prisma = {
        shoppingTrip: { findFirst: jest.fn().mockResolvedValue(null) },
        cookingInstance: { findFirst: jest.fn(), update: jest.fn() },
        tripRecipeAssignment: { deleteMany: jest.fn(), upsert: jest.fn() },
        account: { findUniqueOrThrow: jest.fn() },
      };
      const trips = { refreshDemand: jest.fn() };
      const service = buildService(prisma, trips);

      await expect(
        service.assignTrip(
          accountId,
          householdId,
          cookingInstanceId,
          'trip-closed',
        ),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.cookingInstance.findFirst).not.toHaveBeenCalled();
    });

    it('rejects assignment when the meal is not scheduled', async () => {
      const prisma = {
        shoppingTrip: {
          findFirst: jest.fn().mockResolvedValue({
            id: 'trip-new',
            status: TripStatus.CONFIRMED,
          }),
        },
        cookingInstance: {
          findFirst: jest
            .fn()
            .mockResolvedValue(baseInstance({ status: 'ARCHIVED' })),
          update: jest.fn(),
        },
        tripRecipeAssignment: { deleteMany: jest.fn(), upsert: jest.fn() },
        account: { findUniqueOrThrow: jest.fn() },
      };
      const trips = { refreshDemand: jest.fn() };
      const service = buildService(prisma, trips);

      await expect(
        service.assignTrip(
          accountId,
          householdId,
          cookingInstanceId,
          'trip-new',
        ),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma.cookingInstance.update).not.toHaveBeenCalled();
    });

    it('rejects assignment for an unknown cooking instance', async () => {
      const prisma = {
        cookingInstance: {
          findFirst: jest.fn().mockResolvedValue(null),
          update: jest.fn(),
        },
        tripRecipeAssignment: { deleteMany: jest.fn(), upsert: jest.fn() },
        account: { findUniqueOrThrow: jest.fn() },
      };
      const trips = { refreshDemand: jest.fn() };
      const service = buildService(prisma, trips);

      await expect(
        service.assignTrip(accountId, householdId, cookingInstanceId, null),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
