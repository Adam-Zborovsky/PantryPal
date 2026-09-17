import { Prisma } from '@prisma/client';
import { Dimension, formatDecimal, parseUnit } from '../recipes/units';

export type DemandEntry = {
  dimension: Dimension;
  unit: string;
  min: string;
  max: string;
};

export type QuantityInput = {
  quantityMin: string | null;
  quantityMax: string | null;
  unit: string | null;
};

const decimalPattern = /^\d+(?:\.\d+)?$/;

export function addQuantity(
  demand: DemandEntry[],
  quantity: QuantityInput,
): DemandEntry[] {
  if (
    quantity.quantityMin == null ||
    !decimalPattern.test(quantity.quantityMin)
  )
    return demand;
  const parsed = parseUnit(quantity.unit);
  const max =
    quantity.quantityMax != null && decimalPattern.test(quantity.quantityMax)
      ? quantity.quantityMax
      : quantity.quantityMin;
  const addMin = new Prisma.Decimal(quantity.quantityMin).mul(parsed.factor);
  const addMax = new Prisma.Decimal(max).mul(parsed.factor);
  const index = demand.findIndex(
    (entry) =>
      entry.dimension === parsed.dimension && entry.unit === parsed.baseUnit,
  );
  if (index === -1)
    return [
      ...demand,
      {
        dimension: parsed.dimension,
        unit: parsed.baseUnit,
        min: formatDecimal(addMin),
        max: formatDecimal(addMax),
      },
    ];
  return demand.map((entry, position) =>
    position !== index
      ? entry
      : {
          ...entry,
          min: formatDecimal(new Prisma.Decimal(entry.min).plus(addMin)),
          max: formatDecimal(new Prisma.Decimal(entry.max).plus(addMax)),
        },
  );
}

function isDemandEntry(value: unknown): value is DemandEntry {
  if (!value || typeof value !== 'object') return false;
  const entry = value as Record<string, unknown>;
  return (
    (entry.dimension === 'MASS' ||
      entry.dimension === 'VOLUME' ||
      entry.dimension === 'COUNT') &&
    typeof entry.unit === 'string' &&
    typeof entry.min === 'string' &&
    decimalPattern.test(entry.min) &&
    typeof entry.max === 'string' &&
    decimalPattern.test(entry.max)
  );
}

export function readDemand(
  value: Prisma.JsonValue | null | undefined,
): DemandEntry[] {
  if (Array.isArray(value)) return value.filter(isDemandEntry);
  if (!value || typeof value !== 'object') return [];
  const legacy = value as Record<string, unknown>;
  const text = (field: unknown) => (typeof field === 'string' ? field : null);
  return addQuantity([], {
    quantityMin: text(legacy.quantityMin),
    quantityMax: text(legacy.quantityMax),
    unit: text(legacy.unit),
  });
}

export function demandIncreased(
  previous: DemandEntry[],
  current: DemandEntry[],
) {
  return current.some((entry) => {
    const prior = previous.find(
      (candidate) =>
        candidate.dimension === entry.dimension &&
        candidate.unit === entry.unit,
    );
    return !prior || new Prisma.Decimal(entry.max).gt(prior.max);
  });
}

/** Known pantry amount in the entry's base unit, or null when not exactly comparable. */
export function exactKnown(
  knownQuantity: string,
  unit: string | null,
  entry: DemandEntry,
) {
  if (!decimalPattern.test(knownQuantity)) return null;
  const parsed = parseUnit(unit);
  if (parsed.dimension !== entry.dimension || parsed.baseUnit !== entry.unit)
    return null;
  return new Prisma.Decimal(knownQuantity).mul(parsed.factor);
}

export function reassessPantry(
  current: DemandEntry[],
  assessment: {
    knownQuantity: string | null;
    unit: string | null;
    demandAtConfirmation: DemandEntry[];
  },
): 'CONFIRMED_AT_HOME' | 'PARTIALLY_AVAILABLE' | 'CHECK_AGAIN' {
  if (!demandIncreased(assessment.demandAtConfirmation, current))
    return 'CONFIRMED_AT_HOME';
  if (assessment.knownQuantity == null || current.length !== 1)
    return 'CHECK_AGAIN';
  const known = exactKnown(
    assessment.knownQuantity,
    assessment.unit,
    current[0],
  );
  if (!known) return 'CHECK_AGAIN';
  return known.gte(current[0].max)
    ? 'CONFIRMED_AT_HOME'
    : 'PARTIALLY_AVAILABLE';
}
