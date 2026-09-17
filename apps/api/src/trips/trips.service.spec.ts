import { Prisma, ShoppingItemStatus, TripStatus } from '@prisma/client';
import { ActivityService } from '../activity/activity.service';
import { HouseholdAccessService } from '../households/household-access.service';
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { TripsService } from './trips.service';

describe('TripsService', () => {
  const ingredientMocks = (order: string[] = []) => ({
    resolveIngredients: jest.fn((...args: unknown[]) => {
      const [names] = args as [string[]];
      return Promise.resolve(
        new Map(names.map((name) => [name, `ci-${name}`])),
      );
    }),
    requestProfiles: jest.fn((ids: string[]) => {
      order.push(`requestProfiles:${ids.length}`);
      // Never settles: the service must not await profile requests.
      return new Promise<void>(() => undefined);
    }),
  });
  const ingredientsStub = () =>
    ingredientMocks() as unknown as IngredientProfileService;

  it('returns a confirmed trip to proposal when its shopping date changes', async () => {
    const householdId = 'household-1';
    const tripId = 'trip-1';
    const previousDate = new Date('2026-08-20T10:00:00.000Z');
    const nextDate = new Date('2026-08-21T10:00:00.000Z');
    const prisma = {
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({
          id: tripId,
          scheduledFor: previousDate,
          status: TripStatus.CONFIRMED,
        }),
        update: jest.fn().mockResolvedValue({
          id: tripId,
          scheduledFor: nextDate,
          status: TripStatus.PROPOSED,
          revision: 3,
          createdByAccountId: 'account-1',
          createdAt: previousDate,
          updatedAt: nextDate,
        }),
      },
      cookingInstance: { findMany: jest.fn().mockResolvedValue([]) },
      tripRecipeAssignment: { deleteMany: jest.fn(), upsert: jest.fn() },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const notifications = {
      notifyHouseholdExcept: jest.fn().mockResolvedValue({ count: 1 }),
    };
    const service = new TripsService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      {
        record: jest.fn().mockResolvedValue(undefined),
      } as unknown as ActivityService,
      notifications as unknown as NotificationsService,
      ingredientsStub(),
    );

    await expect(
      service.update('account-1', householdId, tripId, {
        scheduledFor: nextDate.toISOString(),
      }),
    ).resolves.toMatchObject({ status: TripStatus.PROPOSED, revision: 3 });
    expect(prisma.shoppingTrip.update).toHaveBeenCalledWith({
      where: { id: tripId },
      data: {
        scheduledFor: nextDate,
        status: TripStatus.PROPOSED,
        revision: { increment: 1 },
      },
    });
    expect(notifications.notifyHouseholdExcept).toHaveBeenCalledWith(
      expect.objectContaining({
        dedupeKey: 'trip-date-changed:trip-1:3',
        deepLink: `/households/${householdId}/trips/${tripId}`,
      }),
    );
  });

  type FakeTrip = {
    id: string;
    householdId: string;
    scheduledFor: Date | null;
    status: TripStatus;
    revision: number;
    createdByAccountId: string;
    createdAt: Date;
    updatedAt: Date;
  };
  type FakeMeal = {
    id: string;
    householdId: string;
    shoppingTripId: string | null;
    assignmentMode: 'AUTOMATIC' | 'MANUAL';
    status: string;
    cookingDate: Date | null;
    revision: number;
    recipeSnapshot: Prisma.JsonValue;
    scaledIngredients: Prisma.JsonValue;
  };

  // Evaluates the subset of Prisma where-clauses the assignment rules use.
  const matches = (row: object, where: object): boolean =>
    Object.entries(where).every(([key, condition]) => {
      if (key === 'OR')
        return (condition as object[]).some((part) => matches(row, part));
      const value = (row as Record<string, unknown>)[key];
      if (condition === null || typeof condition !== 'object')
        return value === condition;
      if (condition instanceof Date)
        return value instanceof Date && value.getTime() === condition.getTime();
      const ops = condition as {
        in?: unknown[];
        not?: unknown;
        gte?: Date;
        lte?: Date;
      };
      if (ops.in && !ops.in.includes(value)) return false;
      if ('not' in ops && value === ops.not) return false;
      if (ops.gte && !(value instanceof Date && value >= ops.gte)) return false;
      if (ops.lte && !(value instanceof Date && value <= ops.lte)) return false;
      return true;
    });

  const assignmentHarness = (trips: FakeTrip[], meals: FakeMeal[]) => {
    const assignments: Array<{
      shoppingTripId: string;
      cookingInstanceId: string;
      assignmentMode: string;
    }> = [];
    for (const meal of meals) {
      if (meal.shoppingTripId)
        assignments.push({
          shoppingTripId: meal.shoppingTripId,
          cookingInstanceId: meal.id,
          assignmentMode: meal.assignmentMode,
        });
    }
    const client = {
      shoppingTrip: {
        findFirst: jest.fn((args: { where: object }) => {
          const found = trips
            .filter((trip) => matches(trip, args.where))
            .sort(
              (a, b) =>
                (b.scheduledFor?.getTime() ?? 0) -
                (a.scheduledFor?.getTime() ?? 0),
            );
          return Promise.resolve(found[0] ? { ...found[0] } : null);
        }),
        findMany: jest.fn((args: { where: object }) =>
          Promise.resolve(
            trips
              .filter((trip) => matches(trip, args.where))
              .map((trip) => ({ ...trip })),
          ),
        ),
        update: jest.fn(
          (args: { where: { id: string }; data: { status: TripStatus } }) => {
            const trip = trips.find((row) => row.id === args.where.id)!;
            trip.status = args.data.status;
            trip.revision += 1;
            return Promise.resolve({ ...trip });
          },
        ),
      },
      cookingInstance: {
        findMany: jest.fn((args: { where: object }) =>
          Promise.resolve(
            meals
              .filter((meal) => matches(meal, args.where))
              .map((meal) => ({ ...meal })),
          ),
        ),
        update: jest.fn(
          (args: {
            where: { id: string };
            data: { shoppingTripId: string | null };
          }) => {
            const meal = meals.find((row) => row.id === args.where.id)!;
            meal.shoppingTripId = args.data.shoppingTripId;
            meal.revision += 1;
            return Promise.resolve({ ...meal });
          },
        ),
        updateMany: jest.fn(
          (args: { where: object; data: { shoppingTripId: string } }) => {
            const hit = meals.filter((meal) => matches(meal, args.where));
            for (const meal of hit) {
              meal.shoppingTripId = args.data.shoppingTripId;
              meal.revision += 1;
            }
            return Promise.resolve({ count: hit.length });
          },
        ),
      },
      tripRecipeAssignment: {
        deleteMany: jest.fn(
          (args: {
            where: { shoppingTripId: string; cookingInstanceId: string };
          }) => {
            const index = assignments.findIndex(
              (row) =>
                row.shoppingTripId === args.where.shoppingTripId &&
                row.cookingInstanceId === args.where.cookingInstanceId,
            );
            if (index >= 0) assignments.splice(index, 1);
            return Promise.resolve({ count: index >= 0 ? 1 : 0 });
          },
        ),
        upsert: jest.fn(
          (args: {
            create: {
              shoppingTripId: string;
              cookingInstanceId: string;
              assignmentMode: string;
            };
          }) => {
            assignments.push({
              shoppingTripId: args.create.shoppingTripId,
              cookingInstanceId: args.create.cookingInstanceId,
              assignmentMode: args.create.assignmentMode,
            });
            return Promise.resolve(undefined);
          },
        ),
      },
      shoppingItem: {
        deleteMany: jest.fn(),
        create: jest.fn((args: { data: { displayName: string } }) =>
          Promise.resolve({ id: `item-${args.data.displayName}` }),
        ),
      },
      shoppingItemContribution: { createMany: jest.fn() },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const order: string[] = [];
    const prisma = {
      ...client,
      $transaction: jest.fn(
        async (callback: (tx: typeof client) => Promise<unknown>) => {
          const result = await callback(client);
          order.push('commit');
          return result;
        },
      ),
    };
    const activity = {
      record: jest.fn((...args: unknown[]) => {
        order.push(`activity:${String(args[4])}:${String(args[3])}`);
        return Promise.resolve(undefined);
      }),
    };
    const service = new TripsService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      activity as unknown as ActivityService,
      {
        notifyHouseholdExcept: jest.fn().mockResolvedValue({ count: 1 }),
      } as unknown as NotificationsService,
      ingredientsStub(),
    );
    const refreshDemand = jest
      .spyOn(service, 'refreshDemand')
      .mockImplementation((_account, _household, tripId) => {
        order.push(`refresh:${tripId}`);
        return Promise.resolve([]);
      });
    const recalculatedActivities = () =>
      activity.record.mock.calls.filter(
        (call) => call[4] === 'cooking.assignment_recalculated',
      );
    return {
      client,
      service,
      activity,
      refreshDemand,
      assignments,
      order,
      recalculatedActivities,
    };
  };

  const fakeTrip = (
    id: string,
    scheduledFor: string,
    status: TripStatus,
    createdAt = '2026-09-01T00:00:00.000Z',
  ): FakeTrip => ({
    id,
    householdId: 'household-1',
    scheduledFor: new Date(scheduledFor),
    status,
    revision: 1,
    createdByAccountId: 'account-1',
    createdAt: new Date(createdAt),
    updatedAt: new Date(createdAt),
  });
  const fakeMeal = (
    id: string,
    cookingDate: string,
    shoppingTripId: string | null,
    assignmentMode: 'AUTOMATIC' | 'MANUAL' = 'AUTOMATIC',
  ): FakeMeal => ({
    id,
    householdId: 'household-1',
    shoppingTripId,
    assignmentMode,
    status: 'SCHEDULED',
    cookingDate: new Date(cookingDate),
    revision: 1,
    recipeSnapshot: { title: id },
    scaledIngredients: [
      {
        name: `${id} ingredient`,
        quantityMin: '1',
        quantityMax: null,
        unit: 'g',
        includeInShopping: true,
      },
    ],
  });
  const actor = { accountId: 'account-1', displayName: 'Ada' };

  it('adopts unassigned automatic meals on/after the trip date when confirming, skipping shadowed and manual meals', async () => {
    const trips = [
      fakeTrip('trip-1', '2026-09-19T00:00:00.000Z', TripStatus.PROPOSED),
      fakeTrip('trip-later', '2026-09-20T10:00:00.000Z', TripStatus.CONFIRMED),
    ];
    const meals = [
      fakeMeal('cooking-adopted', '2026-09-19T18:00:00.000Z', null),
      fakeMeal('cooking-shadowed', '2026-09-21T18:00:00.000Z', null),
      fakeMeal('cooking-before', '2026-09-18T18:00:00.000Z', null),
      fakeMeal('cooking-manual', '2026-09-19T19:00:00.000Z', null, 'MANUAL'),
    ];
    const { client, service, activity, assignments, recalculatedActivities } =
      assignmentHarness(trips, meals);

    await service.confirm('account-1', 'household-1', 'trip-1');

    expect(meals.map((meal) => [meal.id, meal.shoppingTripId])).toEqual([
      ['cooking-adopted', 'trip-1'],
      ['cooking-shadowed', null],
      ['cooking-before', null],
      ['cooking-manual', null],
    ]);
    expect(assignments).toEqual([
      {
        shoppingTripId: 'trip-1',
        cookingInstanceId: 'cooking-adopted',
        assignmentMode: 'AUTOMATIC',
      },
    ]);
    expect(activity.record).toHaveBeenCalledWith(
      'household-1',
      actor,
      'shopping_trip',
      'cooking-adopted',
      'cooking.assignment_recalculated',
      { previousShoppingTripId: null, shoppingTripId: 'trip-1', revision: 2 },
    );
    expect(recalculatedActivities()).toHaveLength(1);
    const createdItems = client.shoppingItem.create.mock.calls.map(
      ([args]) => args.data.displayName,
    );
    expect(createdItems).toEqual(['cooking-adopted ingredient']);
  });

  it('takes a meal back from an earlier confirmed trip when confirming and refreshes that trip after commit', async () => {
    const trips = [
      fakeTrip('trip-early', '2026-09-15T10:00:00.000Z', TripStatus.CONFIRMED),
      fakeTrip('trip-1', '2026-09-19T10:00:00.000Z', TripStatus.PROPOSED),
    ];
    const meals = [
      fakeMeal('cooking-moved', '2026-09-21T18:00:00.000Z', 'trip-early'),
      fakeMeal('cooking-stays', '2026-09-17T18:00:00.000Z', 'trip-early'),
      fakeMeal(
        'cooking-manual',
        '2026-09-21T19:00:00.000Z',
        'trip-early',
        'MANUAL',
      ),
    ];
    const { service, activity, refreshDemand, assignments, order } =
      assignmentHarness(trips, meals);

    await service.confirm('account-1', 'household-1', 'trip-1');

    expect(meals.map((meal) => [meal.id, meal.shoppingTripId])).toEqual([
      ['cooking-moved', 'trip-1'],
      ['cooking-stays', 'trip-early'],
      ['cooking-manual', 'trip-early'],
    ]);
    expect(assignments).toContainEqual({
      shoppingTripId: 'trip-1',
      cookingInstanceId: 'cooking-moved',
      assignmentMode: 'AUTOMATIC',
    });
    expect(assignments).not.toContainEqual(
      expect.objectContaining({
        shoppingTripId: 'trip-early',
        cookingInstanceId: 'cooking-moved',
      }),
    );
    expect(activity.record).toHaveBeenCalledWith(
      'household-1',
      actor,
      'shopping_trip',
      'cooking-moved',
      'cooking.assignment_recalculated',
      {
        previousShoppingTripId: 'trip-early',
        shoppingTripId: 'trip-1',
        revision: 2,
      },
    );
    expect(refreshDemand).toHaveBeenCalledTimes(1);
    expect(refreshDemand).toHaveBeenCalledWith(
      'account-1',
      'household-1',
      'trip-early',
    );
    expect(order.indexOf('commit')).toBeLessThan(
      order.indexOf('refresh:trip-early'),
    );
    expect(order.indexOf('refresh:trip-early')).toBeLessThan(
      order.indexOf('activity:cooking.assignment_recalculated:cooking-moved'),
    );
  });

  it('never takes a meal from an in-progress trip when confirming', async () => {
    const trips = [
      fakeTrip(
        'trip-shopping',
        '2026-09-15T10:00:00.000Z',
        TripStatus.IN_PROGRESS,
      ),
      fakeTrip('trip-1', '2026-09-19T10:00:00.000Z', TripStatus.PROPOSED),
    ];
    const meals = [
      fakeMeal('cooking-busy', '2026-09-21T18:00:00.000Z', 'trip-shopping'),
    ];
    const { service, refreshDemand, recalculatedActivities } =
      assignmentHarness(trips, meals);

    await service.confirm('account-1', 'household-1', 'trip-1');

    expect(meals[0].shoppingTripId).toBe('trip-shopping');
    expect(refreshDemand).not.toHaveBeenCalled();
    expect(recalculatedActivities()).toHaveLength(0);
  });

  it('breaks same-date ties in favour of the most recently created confirmed trip', async () => {
    const trips = [
      fakeTrip(
        'trip-newer',
        '2026-09-19T10:00:00.000Z',
        TripStatus.CONFIRMED,
        '2026-09-10T00:00:00.000Z',
      ),
      fakeTrip(
        'trip-1',
        '2026-09-19T10:00:00.000Z',
        TripStatus.PROPOSED,
        '2026-09-01T00:00:00.000Z',
      ),
    ];
    const meals = [fakeMeal('cooking-1', '2026-09-21T18:00:00.000Z', null)];
    const { service } = assignmentHarness(trips, meals);

    await service.confirm('account-1', 'household-1', 'trip-1');

    expect(meals[0].shoppingTripId).toBeNull();
  });

  it('skips a meal whose assignment changed before the guarded update', async () => {
    const trips = [
      fakeTrip('trip-1', '2026-09-19T10:00:00.000Z', TripStatus.PROPOSED),
    ];
    const meals = [fakeMeal('cooking-1', '2026-09-21T18:00:00.000Z', null)];
    const { client, service, assignments, recalculatedActivities } =
      assignmentHarness(trips, meals);
    client.cookingInstance.updateMany.mockImplementationOnce(() => {
      // A member picked a trip manually between the read and the write.
      meals[0].assignmentMode = 'MANUAL';
      return Promise.resolve({ count: 0 });
    });

    await service.confirm('account-1', 'household-1', 'trip-1');

    expect(client.cookingInstance.updateMany).toHaveBeenCalledWith({
      where: {
        id: 'cooking-1',
        householdId: 'household-1',
        status: 'SCHEDULED',
        assignmentMode: 'AUTOMATIC',
        shoppingTripId: null,
      },
      data: { shoppingTripId: 'trip-1', revision: { increment: 1 } },
    });
    expect(assignments).toEqual([]);
    expect(recalculatedActivities()).toHaveLength(0);
  });

  it('moves automatic meals off a confirmed trip when it is cancelled', async () => {
    const trips = [
      fakeTrip('trip-early', '2026-09-15T10:00:00.000Z', TripStatus.CONFIRMED),
      fakeTrip('trip-1', '2026-09-19T10:00:00.000Z', TripStatus.CONFIRMED),
    ];
    const meals = [
      fakeMeal('cooking-auto', '2026-09-21T18:00:00.000Z', 'trip-1'),
      fakeMeal(
        'cooking-manual',
        '2026-09-21T19:00:00.000Z',
        'trip-1',
        'MANUAL',
      ),
    ];
    const { service, activity, refreshDemand, assignments } = assignmentHarness(
      trips,
      meals,
    );

    await expect(
      service.cancel('account-1', 'household-1', 'trip-1'),
    ).resolves.toMatchObject({ status: TripStatus.CANCELLED });

    expect(meals.map((meal) => [meal.id, meal.shoppingTripId])).toEqual([
      ['cooking-auto', 'trip-early'],
      ['cooking-manual', 'trip-1'],
    ]);
    expect(assignments).toContainEqual({
      shoppingTripId: 'trip-early',
      cookingInstanceId: 'cooking-auto',
      assignmentMode: 'AUTOMATIC',
    });
    expect(activity.record).toHaveBeenCalledWith(
      'household-1',
      actor,
      'shopping_trip',
      'trip-1',
      'trip.cancelled',
      {},
    );
    expect(activity.record).toHaveBeenCalledWith(
      'household-1',
      actor,
      'shopping_trip',
      'cooking-auto',
      'cooking.assignment_recalculated',
      {
        previousShoppingTripId: 'trip-1',
        shoppingTripId: 'trip-early',
        revision: 2,
      },
    );
    expect(refreshDemand).toHaveBeenCalledWith(
      'account-1',
      'household-1',
      'trip-early',
    );
  });

  it('does not recalculate meals when a proposed trip is cancelled', async () => {
    const trips = [
      fakeTrip('trip-early', '2026-09-15T10:00:00.000Z', TripStatus.CONFIRMED),
      fakeTrip('trip-1', '2026-09-19T10:00:00.000Z', TripStatus.PROPOSED),
    ];
    const meals = [fakeMeal('cooking-1', '2026-09-21T18:00:00.000Z', 'trip-1')];
    const { client, service, refreshDemand, recalculatedActivities } =
      assignmentHarness(trips, meals);

    await service.cancel('account-1', 'household-1', 'trip-1');

    expect(client.cookingInstance.findMany).not.toHaveBeenCalled();
    expect(meals[0].shoppingTripId).toBe('trip-1');
    expect(refreshDemand).not.toHaveBeenCalled();
    expect(recalculatedActivities()).toHaveLength(0);
  });

  it('marks an unquantified pantry confirmation for recheck after demand increases', async () => {
    const householdId = 'household-1';
    const tripId = 'trip-1';
    const itemId = 'item-1';
    const tx = {
      shoppingTrip: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: tripId, status: TripStatus.CONFIRMED }),
      },
      cookingInstance: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'cooking-1',
            recipeSnapshot: { title: 'Baked pasta' },
            scaledIngredients: [
              {
                name: 'Cheese',
                quantityMin: '2',
                quantityMax: null,
                unit: 'cups',
                includeInShopping: true,
              },
            ],
          },
        ]),
      },
      shoppingItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: itemId,
            displayName: 'Cheese',
            demand: [
              { dimension: 'VOLUME', unit: 'ml', min: '240', max: '240' },
            ],
            unmeasured: false,
            status: ShoppingItemStatus.CONFIRMED_AT_HOME,
          },
        ]),
        update: jest
          .fn()
          .mockResolvedValueOnce({
            id: itemId,
            displayName: 'Cheese',
            demand: [
              { dimension: 'VOLUME', unit: 'ml', min: '480', max: '480' },
            ],
            unmeasured: false,
            status: ShoppingItemStatus.CONFIRMED_AT_HOME,
          })
          .mockResolvedValueOnce({ id: itemId }),
        create: jest.fn(),
        deleteMany: jest.fn(),
      },
      shoppingItemContribution: {
        deleteMany: jest.fn(),
        createMany: jest.fn(),
      },
      pantryAssessment: {
        findFirst: jest.fn().mockResolvedValue({
          status: ShoppingItemStatus.CONFIRMED_AT_HOME,
          knownQuantity: null,
          unit: 'cups',
          demandAtConfirmation: {
            quantityMin: '1',
            quantityMax: null,
            unit: 'cups',
          },
        }),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(tx)),
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const activity = { record: jest.fn().mockResolvedValue(undefined) };
    const notifications = {
      notifyHouseholdExcept: jest.fn().mockResolvedValue({ count: 1 }),
    };
    const service = new TripsService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      activity as unknown as ActivityService,
      notifications as unknown as NotificationsService,
      ingredientsStub(),
    );

    await expect(
      service.refreshDemand('account-1', householdId, tripId),
    ).resolves.toEqual([{ id: itemId, displayName: 'Cheese' }]);
    expect(tx.shoppingItem.update).toHaveBeenLastCalledWith({
      where: { id: itemId },
      data: {
        status: ShoppingItemStatus.CHECK_AGAIN,
        revision: { increment: 1 },
      },
    });
    expect(notifications.notifyHouseholdExcept).toHaveBeenCalledWith(
      expect.objectContaining({
        dedupeKey: `pantry-recheck:${itemId}`,
        deepLink: `/households/${householdId}/trips/${tripId}`,
      }),
    );
  });

  const refreshHarness = (
    scaledIngredients: Array<Record<string, unknown>>,
    existing: Array<Record<string, unknown>> = [],
  ) => {
    const tx = {
      shoppingTrip: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: 'trip-1', status: TripStatus.CONFIRMED }),
      },
      cookingInstance: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'cooking-1',
            recipeSnapshot: { title: 'Pancakes' },
            scaledIngredients,
          },
        ]),
      },
      shoppingItem: {
        findMany: jest.fn().mockResolvedValue(existing),
        update: jest.fn(
          (args: { where: { id: string }; data: Record<string, unknown> }) =>
            Promise.resolve({
              id: args.where.id,
              ...args.data,
              status: args.data.status ?? ShoppingItemStatus.NEED_TO_BUY,
            }),
        ),
        create: jest.fn((args: { data: Record<string, unknown> }) =>
          Promise.resolve({ id: 'new-item', ...args.data }),
        ),
        deleteMany: jest.fn(),
      },
      shoppingItemContribution: {
        deleteMany: jest.fn(),
        createMany: jest.fn(),
      },
      pantryAssessment: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const order: string[] = [];
    const prisma = {
      $transaction: jest.fn(
        async (callback: (client: typeof tx) => Promise<unknown>) => {
          const result = await callback(tx);
          order.push('commit');
          return result;
        },
      ),
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }),
      },
    };
    const ingredients = ingredientMocks(order);
    const service = new TripsService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      { record: jest.fn() } as unknown as ActivityService,
      { notifyHouseholdExcept: jest.fn() } as unknown as NotificationsService,
      ingredients as unknown as IngredientProfileService,
    );
    return { tx, service, ingredients, order };
  };

  it('merges the same ingredient across units into one exact demand', async () => {
    const { tx, service, ingredients, order } = refreshHarness([
      {
        name: 'Olive oil',
        quantityMin: '2',
        quantityMax: null,
        unit: 'tbsp',
        includeInShopping: true,
      },
      {
        name: 'olive oil',
        quantityMin: '60',
        quantityMax: null,
        unit: 'ml',
        includeInShopping: true,
      },
      {
        name: 'Flour',
        quantityMin: '300',
        quantityMax: null,
        unit: 'g',
        includeInShopping: true,
      },
      {
        name: 'Flour',
        quantityMin: '2',
        quantityMax: null,
        unit: 'cups',
        includeInShopping: true,
      },
      {
        name: 'Salt',
        quantityMin: null,
        quantityMax: null,
        unit: null,
        includeInShopping: true,
      },
    ]);
    await service.refreshDemand('account-1', 'household-1', 'trip-1');
    const created = tx.shoppingItem.create.mock.calls.map(
      ([args]) => args.data,
    );
    expect(created).toEqual([
      expect.objectContaining({
        displayName: 'Olive oil',
        canonicalIngredientId: 'ci-olive oil',
        demand: [{ dimension: 'VOLUME', unit: 'ml', min: '90', max: '90' }],
        unmeasured: false,
      }),
      expect.objectContaining({
        displayName: 'Flour',
        demand: [
          { dimension: 'MASS', unit: 'g', min: '300', max: '300' },
          { dimension: 'VOLUME', unit: 'ml', min: '480', max: '480' },
        ],
      }),
      expect.objectContaining({
        displayName: 'Salt',
        demand: [],
        unmeasured: true,
      }),
    ]);
    expect(ingredients.resolveIngredients).toHaveBeenCalledWith([
      'olive oil',
      'flour',
      'salt',
    ]);
    expect(ingredients.resolveIngredients.mock.calls[0]).toHaveLength(1);
    expect(tx.shoppingItem.findMany).toHaveBeenCalledWith({
      where: { householdId: 'household-1', shoppingTripId: 'trip-1' },
      orderBy: { createdAt: 'asc' },
    });
    expect(ingredients.requestProfiles).toHaveBeenCalledWith([
      'ci-olive oil',
      'ci-flour',
      'ci-salt',
    ]);
    expect(order).toEqual(['commit', 'requestProfiles:3']);
  });

  it('merges legacy lines with different statuses into one item that needs a pantry check', async () => {
    const { tx, service } = refreshHarness(
      [
        {
          name: 'Flour',
          quantityMin: '300',
          quantityMax: null,
          unit: 'g',
          includeInShopping: true,
        },
      ],
      [
        {
          id: 'old-g',
          displayName: 'Flour',
          demand: [],
          unmeasured: false,
          status: ShoppingItemStatus.PURCHASED,
        },
        {
          id: 'old-cup',
          displayName: 'flour',
          demand: [],
          unmeasured: false,
          status: ShoppingItemStatus.NEED_TO_BUY,
        },
      ],
    );
    await expect(
      service.refreshDemand('account-1', 'household-1', 'trip-1'),
    ).resolves.toEqual([{ id: 'old-g', displayName: 'Flour' }]);
    expect(tx.shoppingItem.deleteMany).toHaveBeenCalledWith({
      where: { householdId: 'household-1', id: { in: ['old-cup'] } },
    });
    const oldUpdates = tx.shoppingItem.update.mock.calls
      .map(([args]) => args)
      .filter((args) => args.where.id === 'old-g');
    expect(oldUpdates.map((args) => args.data.status)).toContain(
      ShoppingItemStatus.CHECK_AGAIN,
    );
  });

  it('presents exact demand with a read-time estimate in trip detail', async () => {
    const prisma = {
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'trip-1',
          status: TripStatus.CONFIRMED,
          scheduledFor: null,
          revision: 1,
          createdByAccountId: 'account-1',
          createdAt: new Date(0),
          updatedAt: new Date(0),
        }),
      },
      shoppingItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'item-1',
            displayName: 'Flour',
            canonicalIngredientId: 'ci-flour',
            demand: [
              { dimension: 'MASS', unit: 'g', min: '300', max: '300' },
              { dimension: 'VOLUME', unit: 'ml', min: '480', max: '480' },
            ],
            unmeasured: false,
            status: ShoppingItemStatus.NEED_TO_BUY,
            revision: 2,
          },
        ]),
      },
      shoppingItemContribution: {
        findMany: jest.fn().mockResolvedValue([
          {
            shoppingItemId: 'item-1',
            cookingInstanceId: 'cooking-1',
            recipeTitle: 'Pancakes',
            quantityMin: new Prisma.Decimal('2'),
            quantityMax: null,
            unit: 'cups',
          },
        ]),
      },
      pantryAssessment: { findMany: jest.fn().mockResolvedValue([]) },
      canonicalIngredient: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'ci-flour',
            profileStatus: 'READY',
            shoppingUnit: 'g',
            unitEstimates: { ml: '0.53' },
            packageSizes: ['500', '1000'],
          },
        ]),
      },
    };
    const service = new TripsService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      { record: jest.fn() } as unknown as ActivityService,
      { notifyHouseholdExcept: jest.fn() } as unknown as NotificationsService,
      ingredientsStub(),
    );
    const detail = await service.detail('account-1', 'household-1', 'trip-1');
    expect(detail.items).toEqual([
      {
        id: 'item-1',
        displayName: 'Flour',
        status: ShoppingItemStatus.NEED_TO_BUY,
        revision: 2,
        demand: [
          { dimension: 'MASS', unit: 'g', min: '300', max: '300' },
          { dimension: 'VOLUME', unit: 'ml', min: '480', max: '480' },
        ],
        unmeasured: false,
        estimate: {
          approximate: true,
          amount: '554.4',
          unit: 'g',
          buy: { count: 1, size: '1000', unit: 'g' },
          crossesDimension: true,
          remainderApplied: false,
        },
        profileStatus: 'READY',
        contributions: [
          {
            cookingInstanceId: 'cooking-1',
            recipeTitle: 'Pancakes',
            quantityMin: '2',
            quantityMax: null,
            unit: 'cups',
          },
        ],
      },
    ]);
  });

  const partialDetailService = (assessment: {
    knownQuantity: Prisma.Decimal;
    unit: string;
  }) => {
    const prisma = {
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'trip-1',
          status: TripStatus.CONFIRMED,
          scheduledFor: null,
          revision: 1,
          createdByAccountId: 'account-1',
          createdAt: new Date(0),
          updatedAt: new Date(0),
        }),
      },
      shoppingItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'item-1',
            displayName: 'Flour',
            canonicalIngredientId: 'ci-flour',
            demand: [{ dimension: 'MASS', unit: 'g', min: '800', max: '800' }],
            unmeasured: false,
            status: ShoppingItemStatus.PARTIALLY_AVAILABLE,
            revision: 2,
          },
        ]),
      },
      shoppingItemContribution: { findMany: jest.fn().mockResolvedValue([]) },
      pantryAssessment: {
        findMany: jest.fn().mockResolvedValue([
          {
            shoppingItemId: 'item-1',
            status: ShoppingItemStatus.PARTIALLY_AVAILABLE,
            ...assessment,
          },
        ]),
      },
      canonicalIngredient: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'ci-flour',
            profileStatus: 'READY',
            shoppingUnit: 'g',
            unitEstimates: { ml: '0.53' },
            packageSizes: ['500', '1000'],
          },
        ]),
      },
    };
    return new TripsService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      { record: jest.fn() } as unknown as ActivityService,
      { notifyHouseholdExcept: jest.fn() } as unknown as NotificationsService,
      ingredientsStub(),
    );
  };

  it('subtracts an exact same-unit amount at home for a partially available item', async () => {
    const service = partialDetailService({
      knownQuantity: new Prisma.Decimal('500'),
      unit: 'g',
    });
    const detail = await service.detail('account-1', 'household-1', 'trip-1');
    expect(detail.items[0].estimate).toEqual({
      approximate: true,
      amount: '300',
      unit: 'g',
      buy: { count: 1, size: '500', unit: 'g' },
      crossesDimension: false,
      remainderApplied: true,
    });
  });

  it('keeps the full estimate when the amount at home is in another dimension', async () => {
    const service = partialDetailService({
      knownQuantity: new Prisma.Decimal('2'),
      unit: 'cups',
    });
    const detail = await service.detail('account-1', 'household-1', 'trip-1');
    expect(detail.items[0].estimate).toEqual({
      approximate: true,
      amount: '800',
      unit: 'g',
      buy: { count: 1, size: '1000', unit: 'g' },
      crossesDimension: false,
      remainderApplied: false,
    });
  });
});
