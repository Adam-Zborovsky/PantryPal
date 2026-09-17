import { Prisma } from '@prisma/client';
import {
  formatDecimal,
  normalizeIngredientName,
  parseUnit,
  UNIT_ALIASES,
} from './units';

describe('parseUnit', () => {
  it.each([
    ['g', 'MASS', 'g', '1', 'g'],
    ['Grams', 'MASS', 'g', '1', 'g'],
    ['kg', 'MASS', 'g', '1000', 'kg'],
    ['mg', 'MASS', 'g', '0.001', 'mg'],
    ['oz', 'MASS', 'g', '28.349523125', 'oz'],
    ['lbs', 'MASS', 'g', '453.59237', 'lb'],
    ['ml', 'VOLUME', 'ml', '1', 'ml'],
    ['L', 'VOLUME', 'ml', '1000', 'l'],
    ['tsp.', 'VOLUME', 'ml', '5', 'tsp'],
    ['Tablespoons', 'VOLUME', 'ml', '15', 'tbsp'],
    ['cups', 'VOLUME', 'ml', '240', 'cup'],
    ['fl oz', 'VOLUME', 'ml', '29.5735', 'fl oz'],
    ['pint', 'VOLUME', 'ml', '473.176', 'pint'],
    ['quarts', 'VOLUME', 'ml', '946.353', 'quart'],
    ['gallon', 'VOLUME', 'ml', '3785.41', 'gallon'],
  ])('parses %s', (input, dimension, baseUnit, factor, token) => {
    const parsed = parseUnit(input);
    expect(parsed).toMatchObject({ dimension, baseUnit, token });
    expect(parsed.factor.toString()).toBe(factor);
  });

  it.each([
    ['kgs', 'MASS', 'g', '1000', 'kg'],
    ['tbsps', 'VOLUME', 'ml', '15', 'tbsp'],
    ['mls', 'VOLUME', 'ml', '1', 'ml'],
    ['Ozs', 'MASS', 'g', '28.349523125', 'oz'],
  ])(
    'parses plural abbreviation %s through the singular alias',
    (input, dimension, baseUnit, factor, token) => {
      const parsed = parseUnit(input);
      expect(parsed).toMatchObject({ dimension, baseUnit, token });
      expect(parsed.factor.toString()).toBe(factor);
    },
  );

  it('treats single-letter T and t case-sensitively', () => {
    expect(parseUnit('T')).toMatchObject({ token: 'tbsp', baseUnit: 'ml' });
    expect(parseUnit('T').factor.toString()).toBe('15');
    expect(parseUnit('t')).toMatchObject({ token: 'tsp', baseUnit: 'ml' });
    expect(parseUnit('t').factor.toString()).toBe('5');
  });

  it.each([
    ['cloves', 'clove'],
    ['Cans', 'can'],
    ['leaves', 'leaf'],
    ['pinches', 'pinch'],
    ['sprigs', 'sprig'],
    ['glass', 'glass'],
  ])('keeps %s as a singular count unit', (input, token) => {
    expect(parseUnit(input)).toMatchObject({
      dimension: 'COUNT',
      baseUnit: token,
      token,
    });
    expect(parseUnit(input).factor.toString()).toBe('1');
  });

  it.each([null, undefined, '', '   '])('treats %p as a piece', (input) => {
    expect(parseUnit(input)).toMatchObject({
      dimension: 'COUNT',
      baseUnit: 'piece',
      token: 'piece',
    });
  });

  it('never maps an unknown unit to mass or volume', () => {
    expect(parseUnit('handful').dimension).toBe('COUNT');
  });

  it('exposes every alias through parseUnit', () => {
    for (const alias of UNIT_ALIASES) {
      expect(parseUnit(alias.alias)).toMatchObject({
        dimension: alias.dimension,
        token: alias.token,
      });
    }
  });
});

describe('normalizeIngredientName', () => {
  it.each([
    ['  Olive   Oil ', 'olive oil'],
    ['Tomatoes', 'tomato'],
    ['Cherry Tomatoes', 'cherry tomato'],
    ['Berries', 'berry'],
    ['Eggs', 'egg'],
    ['Hummus', 'hummus'],
    ['Garlic Cloves', 'garlic clove'],
  ])('normalizes %p to %p', (input, expected) => {
    expect(normalizeIngredientName(input)).toBe(expected);
  });
});

describe('formatDecimal', () => {
  it.each([
    ['200', '200'],
    ['480.000', '480'],
    ['1.500', '1.5'],
    ['1.8750000001', '1.875'],
    ['0', '0'],
  ])('formats %s as %s', (input, expected) => {
    expect(formatDecimal(new Prisma.Decimal(input))).toBe(expected);
  });
});
