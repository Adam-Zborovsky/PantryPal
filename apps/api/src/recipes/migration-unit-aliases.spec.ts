import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { CASE_SENSITIVE_UNIT_ALIASES, UNIT_ALIASES } from './units';

describe('shopping unit estimates migration', () => {
  it('embeds exactly the unit aliases from units.ts', () => {
    const sql = readFileSync(
      join(
        __dirname,
        '../../prisma/migrations/20260917090000_shopping_unit_estimates/migration.sql',
      ),
      'utf8',
    );
    const rows = [
      ...sql.matchAll(/\('([^']+)', '(MASS|VOLUME)', ([0-9.]+)\)/g),
    ].map(([, alias, dimension, factor]) => `${alias}|${dimension}|${factor}`);
    const expected = [...UNIT_ALIASES, ...CASE_SENSITIVE_UNIT_ALIASES].map(
      (alias) => `${alias.alias}|${alias.dimension}|${alias.factor}`,
    );
    expect(rows.sort()).toEqual(expected.sort());
  });
});
