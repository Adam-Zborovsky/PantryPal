import { Prisma } from '@prisma/client';

export type Dimension = 'MASS' | 'VOLUME' | 'COUNT';

export type ParsedUnit = {
  dimension: Dimension;
  baseUnit: string;
  factor: Prisma.Decimal;
  token: string;
};

type Alias = {
  alias: string;
  token: string;
  dimension: 'MASS' | 'VOLUME';
  factor: string;
};

const family = (
  aliases: string[],
  token: string,
  dimension: 'MASS' | 'VOLUME',
  factor: string,
): Alias[] => aliases.map((alias) => ({ alias, token, dimension, factor }));

/** Lowercase unit aliases with their exact factor to the base unit (g or ml). */
export const UNIT_ALIASES: ReadonlyArray<Alias> = [
  ...family(['g', 'gram', 'grams'], 'g', 'MASS', '1'),
  ...family(['kg', 'kilogram', 'kilograms'], 'kg', 'MASS', '1000'),
  ...family(['mg', 'milligram', 'milligrams'], 'mg', 'MASS', '0.001'),
  ...family(['oz', 'ounce', 'ounces'], 'oz', 'MASS', '28.349523125'),
  ...family(['lb', 'lbs', 'pound', 'pounds'], 'lb', 'MASS', '453.59237'),
  ...family(
    ['ml', 'milliliter', 'milliliters', 'millilitre', 'millilitres'],
    'ml',
    'VOLUME',
    '1',
  ),
  ...family(['l', 'liter', 'liters', 'litre', 'litres'], 'l', 'VOLUME', '1000'),
  ...family(['tsp', 'teaspoon', 'teaspoons'], 'tsp', 'VOLUME', '5'),
  ...family(
    ['tbsp', 'tbs', 'tablespoon', 'tablespoons'],
    'tbsp',
    'VOLUME',
    '15',
  ),
  ...family(['cup', 'cups'], 'cup', 'VOLUME', '240'),
  ...family(
    ['fl oz', 'fluid ounce', 'fluid ounces'],
    'fl oz',
    'VOLUME',
    '29.5735',
  ),
  ...family(['pint', 'pints'], 'pint', 'VOLUME', '473.176'),
  ...family(['quart', 'quarts'], 'quart', 'VOLUME', '946.353'),
  ...family(['gallon', 'gallons'], 'gallon', 'VOLUME', '3785.41'),
];

export const CASE_SENSITIVE_UNIT_ALIASES = [
  { alias: 'T', token: 'tbsp', dimension: 'VOLUME', factor: '15' },
  { alias: 't', token: 'tsp', dimension: 'VOLUME', factor: '5' },
] as const;

const aliasIndex = new Map<string, Alias>(
  UNIT_ALIASES.map((alias) => [alias.alias, alias]),
);
const caseSensitiveIndex = new Map<string, Alias>(
  CASE_SENSITIVE_UNIT_ALIASES.map((alias) => [alias.alias, { ...alias }]),
);

const irregularSingulars = new Map([
  ['leaves', 'leaf'],
  ['halves', 'half'],
  ['loaves', 'loaf'],
]);

function singularWord(word: string) {
  const irregular = irregularSingulars.get(word);
  if (irregular) return irregular;
  if (word.length > 4 && word.endsWith('ies')) return `${word.slice(0, -3)}y`;
  if (/(ch|sh|x)es$/.test(word)) return word.slice(0, -2);
  if (word.endsWith('oes')) return word.slice(0, -2);
  if (word.length > 3 && word.endsWith('s') && !/(ss|us)$/.test(word))
    return word.slice(0, -1);
  return word;
}

function singularizeLastWord(phrase: string) {
  const words = phrase.split(' ');
  const last = words.pop() ?? '';
  return [...words, singularWord(last)].join(' ');
}

export function parseUnit(unit: string | null | undefined): ParsedUnit {
  const trimmed = (unit ?? '').trim().replace(/\.$/, '');
  const exact = caseSensitiveIndex.get(trimmed);
  const key = trimmed.toLocaleLowerCase().replace(/\s+/g, ' ');
  // Plural abbreviations (kgs, tbsps, mls) fall back to their singular alias.
  const alias =
    exact ??
    aliasIndex.get(key) ??
    (key.endsWith('s') ? aliasIndex.get(key.slice(0, -1)) : undefined);
  if (alias) {
    return {
      dimension: alias.dimension,
      baseUnit: alias.dimension === 'MASS' ? 'g' : 'ml',
      factor: new Prisma.Decimal(alias.factor),
      token: alias.token,
    };
  }
  const token = key ? singularizeLastWord(key) : 'piece';
  return {
    dimension: 'COUNT',
    baseUnit: token,
    factor: new Prisma.Decimal(1),
    token,
  };
}

export function normalizeIngredientName(name: string) {
  const collapsed = name.trim().replace(/\s+/g, ' ').toLocaleLowerCase();
  return collapsed ? singularizeLastWord(collapsed) : '';
}

export function formatDecimal(value: Prisma.Decimal) {
  return value
    .toDecimalPlaces(6)
    .toFixed()
    .replace(/(\.\d*?)0+$/, '$1')
    .replace(/\.$/, '');
}
