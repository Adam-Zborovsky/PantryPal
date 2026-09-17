import { Prisma } from '@prisma/client';
import { formatDecimal, parseUnit } from '../recipes/units';
import { DemandEntry } from './demand';

export type IngredientProfileSnapshot = {
  profileStatus: 'PENDING' | 'READY' | 'FAILED';
  shoppingUnit: string | null;
  unitEstimates: Prisma.JsonValue;
  packageSizes: Prisma.JsonValue;
};

export type ShoppingEstimate = {
  approximate: true;
  amount: string;
  unit: string;
  buy: { count: number; size: string; unit: string } | null;
  crossesDimension: boolean;
  /** True when an exact amount already at home was subtracted. */
  remainderApplied: boolean;
};

const decimalPattern = /^\d+(?:\.\d+)?$/;

function readEstimates(value: Prisma.JsonValue) {
  const estimates = new Map<string, Prisma.Decimal>();
  if (!value || typeof value !== 'object' || Array.isArray(value))
    return estimates;
  for (const [unit, amount] of Object.entries(value)) {
    if (typeof amount === 'string' && decimalPattern.test(amount))
      estimates.set(unit, new Prisma.Decimal(amount));
  }
  return estimates;
}

function readPackages(value: Prisma.JsonValue) {
  if (!Array.isArray(value)) return [];
  return value
    .filter(
      (size): size is string =>
        typeof size === 'string' && decimalPattern.test(size),
    )
    .map((size) => new Prisma.Decimal(size))
    .filter((size) => size.gt(0))
    .sort((left, right) => left.comparedTo(right));
}

export function estimateShopping(
  demand: DemandEntry[],
  profile: IngredientProfileSnapshot | null,
  alreadyHave?: Prisma.Decimal,
): ShoppingEstimate | null {
  if (!profile || profile.profileStatus !== 'READY' || !profile.shoppingUnit)
    return null;
  if (!demand.length) return null;
  const shopping = parseUnit(profile.shoppingUnit);
  const estimates = readEstimates(profile.unitEstimates);
  let total = new Prisma.Decimal(0);
  let crossesDimension = false;
  for (const entry of demand) {
    if (
      entry.dimension === shopping.dimension &&
      entry.unit === shopping.baseUnit
    ) {
      total = total.plus(entry.max);
      continue;
    }
    const factor = estimates.get(entry.unit);
    if (!factor) return null;
    total = total.plus(new Prisma.Decimal(entry.max).mul(factor));
    crossesDimension = true;
  }
  if (alreadyHave) total = Prisma.Decimal.max(total.minus(alreadyHave), 0);
  const packages = readPackages(profile.packageSizes);
  let buy: ShoppingEstimate['buy'] = null;
  if (packages.length && total.gt(0)) {
    const fitting = packages.find((size) => size.gte(total));
    const size = fitting ?? packages[packages.length - 1];
    buy = {
      count: fitting ? 1 : total.div(size).ceil().toNumber(),
      size: formatDecimal(size),
      unit: shopping.baseUnit,
    };
  }
  return {
    approximate: true,
    amount: formatDecimal(total),
    unit: shopping.baseUnit,
    buy,
    crossesDimension,
    remainderApplied: alreadyHave !== undefined,
  };
}
