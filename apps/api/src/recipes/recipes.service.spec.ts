import { Prisma } from '@prisma/client';
import { ActivityService } from '../activity/activity.service';
import { HouseholdAccessService } from '../households/household-access.service';
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { PrismaService } from '../prisma/prisma.service';
import { RecipesService } from './recipes.service';

describe('RecipesService.saveReview', () => {
  it('links ingredients to canonical rows, stores normalized units, and requests profiles after commit', async () => {
    const order: string[] = [];
    const tx = {
      recipe: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'recipe-1',
          currentVersionId: 'v1',
          revision: 1,
        }),
        update: jest.fn().mockResolvedValue({ id: 'recipe-1' }),
      },
      recipeVersion: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'v1',
          version: 1,
          title: 'Soup',
          originalServings: new Prisma.Decimal('2'),
          snapshot: {},
        }),
        create: jest.fn().mockResolvedValue({ id: 'v2' }),
      },
      recipeIngredient: {
        findMany: jest.fn().mockResolvedValue([]),
        createMany: jest.fn(() => {
          order.push('createMany');
          return Promise.resolve({ count: 2 });
        }),
      },
      recipeInstruction: {
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
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
    const ingredients = {
      resolveIngredients: jest.fn().mockResolvedValue(
        new Map([
          ['carrot', 'ci-carrot'],
          ['olive oil', 'ci-oil'],
        ]),
      ),
      requestProfiles: jest.fn(() => {
        order.push('requestProfiles');
        // Never settles: saving must not wait for profile requests.
        return new Promise<void>(() => undefined);
      }),
    };
    const service = new RecipesService(
      prisma as unknown as PrismaService,
      {
        requireActiveMembership: jest.fn(),
      } as unknown as HouseholdAccessService,
      { record: jest.fn() } as unknown as ActivityService,
      ingredients as unknown as IngredientProfileService,
    );
    jest.spyOn(service, 'review').mockResolvedValue({} as never);

    await service.saveReview('account-1', 'household-1', 'recipe-1', {
      title: 'Soup',
      originalServings: '2',
      expectedRevision: '1',
      instructions: ['Simmer.'],
      ingredients: [
        {
          name: 'Carrots',
          quantityMin: '2',
          originalUnit: null,
          classification: 'REQUIRED',
          includeInShopping: true,
        },
        {
          name: 'Olive oil',
          quantityMin: '2',
          originalUnit: 'Tbsp',
          classification: 'REQUIRED',
          includeInShopping: true,
        },
        {
          name: 'Salt',
          quantityMin: null,
          originalUnit: '   ',
          classification: 'PANTRY_STAPLE',
          includeInShopping: true,
        },
      ],
    } as never);

    expect(ingredients.resolveIngredients).toHaveBeenCalledWith([
      'Carrots',
      'Olive oil',
      'Salt',
    ]);
    expect(tx.recipeIngredient.createMany).toHaveBeenCalledWith({
      data: [
        expect.objectContaining({
          name: 'Carrots',
          canonicalIngredientId: 'ci-carrot',
          normalizedUnit: null,
        }),
        expect.objectContaining({
          name: 'Olive oil',
          canonicalIngredientId: 'ci-oil',
          normalizedUnit: 'tbsp',
        }),
        expect.objectContaining({
          name: 'Salt',
          normalizedUnit: null,
        }),
      ],
    });
    expect(ingredients.requestProfiles).toHaveBeenCalledWith([
      'ci-carrot',
      'ci-oil',
    ]);
    expect(order).toEqual(['createMany', 'commit', 'requestProfiles']);
  });
});
