import { Prisma } from '@prisma/client';
import { DemandEntry } from './demand';
import {
  estimateShopping,
  IngredientProfileSnapshot,
} from './shopping-estimate';

const flour: IngredientProfileSnapshot = {
  profileStatus: 'READY',
  shoppingUnit: 'g',
  unitEstimates: { ml: '0.53' },
  packageSizes: ['500', '1000'],
};
const g = (max: string): DemandEntry => ({
  dimension: 'MASS',
  unit: 'g',
  min: max,
  max,
});
const ml = (max: string): DemandEntry => ({
  dimension: 'VOLUME',
  unit: 'ml',
  min: max,
  max,
});

describe('estimateShopping', () => {
  it('converts same-dimension demand exactly without the cross-dimension flag', () => {
    expect(estimateShopping([g('300')], flour)).toEqual({
      approximate: true,
      amount: '300',
      unit: 'g',
      buy: { count: 1, size: '500', unit: 'g' },
      crossesDimension: false,
      remainderApplied: false,
    });
  });

  it('uses unit estimates across dimensions', () => {
    expect(estimateShopping([g('300'), ml('480')], flour)).toMatchObject({
      amount: '554.4',
      buy: { count: 1, size: '1000', unit: 'g' },
      crossesDimension: true,
    });
  });

  it('returns null when any entry cannot be converted', () => {
    expect(
      estimateShopping(
        [g('300'), { dimension: 'COUNT', unit: 'pinch', min: '1', max: '1' }],
        flour,
      ),
    ).toBeNull();
  });

  it('returns null without a ready profile or demand', () => {
    expect(estimateShopping([g('1')], null)).toBeNull();
    expect(
      estimateShopping([g('1')], { ...flour, profileStatus: 'PENDING' }),
    ).toBeNull();
    expect(estimateShopping([], flour)).toBeNull();
  });

  it('buys several of the largest package when none is big enough', () => {
    expect(estimateShopping([g('2300')], flour)?.buy).toEqual({
      count: 3,
      size: '1000',
      unit: 'g',
    });
  });

  it('has no buy suggestion without package sizes', () => {
    expect(
      estimateShopping([g('300')], { ...flour, packageSizes: null })?.buy,
    ).toBeNull();
  });

  it('subtracts an exact amount already at home and clamps at zero', () => {
    expect(
      estimateShopping([g('800')], flour, new Prisma.Decimal(500)),
    ).toMatchObject({
      amount: '300',
      buy: { count: 1, size: '500', unit: 'g' },
      remainderApplied: true,
    });
    expect(
      estimateShopping([g('300')], flour, new Prisma.Decimal(500)),
    ).toMatchObject({
      amount: '0',
      buy: null,
      remainderApplied: true,
    });
  });

  it('estimates count shopping units', () => {
    const garlic: IngredientProfileSnapshot = {
      profileStatus: 'READY',
      shoppingUnit: 'head',
      unitEstimates: { clove: '0.1' },
      packageSizes: ['1'],
    };
    expect(
      estimateShopping(
        [{ dimension: 'COUNT', unit: 'clove', min: '4', max: '4' }],
        garlic,
      ),
    ).toMatchObject({
      amount: '0.4',
      unit: 'head',
      buy: { count: 1, size: '1', unit: 'head' },
    });
  });
});
