import { Prisma } from '@prisma/client';
import {
  addQuantity,
  DemandEntry,
  demandIncreased,
  readDemand,
  reassessPantry,
} from './demand';

const ml = (min: string, max = min): DemandEntry => ({
  dimension: 'VOLUME',
  unit: 'ml',
  min,
  max,
});

describe('addQuantity', () => {
  it('merges tablespoons and millilitres exactly', () => {
    let demand = addQuantity([], {
      quantityMin: '2',
      quantityMax: null,
      unit: 'tbsp',
    });
    demand = addQuantity(demand, {
      quantityMin: '60',
      quantityMax: null,
      unit: 'ml',
    });
    expect(demand).toEqual([ml('90')]);
  });

  it('keeps grams and cups as separate entries', () => {
    let demand = addQuantity([], {
      quantityMin: '300',
      quantityMax: null,
      unit: 'g',
    });
    demand = addQuantity(demand, {
      quantityMin: '2',
      quantityMax: null,
      unit: 'cups',
    });
    expect(demand).toEqual([
      { dimension: 'MASS', unit: 'g', min: '300', max: '300' },
      ml('480'),
    ]);
  });

  it('keeps different count units apart', () => {
    let demand = addQuantity([], {
      quantityMin: '4',
      quantityMax: null,
      unit: 'cloves',
    });
    demand = addQuantity(demand, {
      quantityMin: '1',
      quantityMax: null,
      unit: 'head',
    });
    expect(demand.map((entry) => entry.unit)).toEqual(['clove', 'head']);
  });

  it('adds ranges at both ends', () => {
    let demand = addQuantity([], {
      quantityMin: '1',
      quantityMax: '2',
      unit: 'cup',
    });
    demand = addQuantity(demand, {
      quantityMin: '100',
      quantityMax: null,
      unit: 'ml',
    });
    expect(demand).toEqual([ml('340', '580')]);
  });

  it('ignores unquantified amounts', () => {
    expect(
      addQuantity([ml('5')], {
        quantityMin: null,
        quantityMax: null,
        unit: 'tsp',
      }),
    ).toEqual([ml('5')]);
  });
});

describe('readDemand', () => {
  it('reads the stored array and drops malformed entries', () => {
    expect(
      readDemand([
        ml('5'),
        { dimension: 'MASS', unit: 'g', min: 'x', max: '1' },
        'nope',
      ]),
    ).toEqual([ml('5')]);
  });

  it('converts the legacy single-quantity shape', () => {
    expect(
      readDemand({ quantityMin: '1', quantityMax: null, unit: 'cups' }),
    ).toEqual([ml('240')]);
  });

  it('returns an empty demand for null', () => {
    expect(readDemand(null)).toEqual([]);
  });
});

describe('demandIncreased', () => {
  it('detects growth and new entries only', () => {
    expect(demandIncreased([ml('240')], [ml('480')])).toBe(true);
    expect(
      demandIncreased(
        [ml('240')],
        [ml('240'), { dimension: 'MASS', unit: 'g', min: '5', max: '5' }],
      ),
    ).toBe(true);
    expect(demandIncreased([ml('480')], [ml('240')])).toBe(false);
  });
});

describe('reassessPantry', () => {
  const at = (knownQuantity: string | null, unit: string | null) => ({
    knownQuantity,
    unit,
    demandAtConfirmation: [ml('240')],
  });

  it('stays confirmed when demand did not increase', () => {
    expect(reassessPantry([ml('240')], at(null, null))).toBe(
      'CONFIRMED_AT_HOME',
    );
  });

  it('confirms when an exact known amount still covers demand', () => {
    expect(reassessPantry([ml('480')], at('1', 'l'))).toBe('CONFIRMED_AT_HOME');
  });

  it('is partial when an exact known amount covers only part', () => {
    expect(reassessPantry([ml('480')], at('1', 'cup'))).toBe(
      'PARTIALLY_AVAILABLE',
    );
  });

  it('asks to check again without a known amount', () => {
    expect(reassessPantry([ml('480')], at(null, null))).toBe('CHECK_AGAIN');
  });

  it('asks to check again across dimensions or multiple entries', () => {
    expect(reassessPantry([ml('480')], at('500', 'g'))).toBe('CHECK_AGAIN');
    expect(
      reassessPantry(
        [ml('480'), { dimension: 'MASS', unit: 'g', min: '1', max: '1' }],
        at('2', 'l'),
      ),
    ).toBe('CHECK_AGAIN');
  });
});

describe('Prisma.Decimal usage', () => {
  it('does not use floating point for exact sums', () => {
    const demand = addQuantity(
      addQuantity([], { quantityMin: '0.1', quantityMax: null, unit: 'ml' }),
      {
        quantityMin: '0.2',
        quantityMax: null,
        unit: 'ml',
      },
    );
    expect(new Prisma.Decimal(demand[0].min).equals('0.3')).toBe(true);
  });
});
