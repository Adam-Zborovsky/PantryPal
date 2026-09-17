# Shopping Unit Estimates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One shopping line per ingredient with exact per-dimension totals, plus an AI-profile-based "≈ amount · buy n × pack" suggestion and a tap-to-expand breakdown.

**Architecture:** Deterministic unit parsing (`units.ts`) builds exact `demand` JSON on `ShoppingItem`. A new `ingredients` Nest module creates global `CanonicalIngredient` rows and profiles them once via a BullMQ job that calls Gemini. Trip responses compute the estimate at read time with a pure function; pantry logic only ever uses exact conversions. The Flutter trip and shop screens share one formatting helper and one breakdown widget.

**Tech Stack:** NestJS 11, Prisma 6 (PostgreSQL 17), BullMQ, Jest 30 / ts-jest; Flutter (Riverpod, flutter_test).

**Spec:** `docs/superpowers/specs/2026-09-16-shopping-unit-estimates-design.md` — read it before starting any task.

## Global Constraints

- **No git commits.** The user's global rule forbids commits unless explicitly asked. Every task ends with "leave changes uncommitted".
- **Do not run** `prisma migrate dev`, `prisma migrate reset`, `prisma db push`, dev servers, or watchers. Migrations are applied only in Task 2 Step 8 by the orchestrator after user approval.
- API commands run from `apps/api`. Client commands run from `apps/client` using `E:/flutter/bin/flutter.bat` / `E:/flutter/bin/dart.bat`.
- Format only files you touched: `npx prettier --write <files>` (API), `E:/flutter/bin/dart.bat format <files>` (client). Never format whole directories.
- Lint touched API source files with `npx eslint <files>`; they must be clean. Pre-existing spec-file lint errors elsewhere are out of scope.
- AI-derived conversions are estimate-only: never used in `demand`, never used in pantry status logic, always displayed with `≈`.
- Any unconvertible demand entry ⇒ no estimate (never a partial total).
- Decimal math in the API uses `Prisma.Decimal`; never JS floating point for stored values.
- UI copy uses the curly apostrophe `’` (project convention) and DESIGN.md voice; no raw enums in UI.
- Gemini model comes from `GEMINI_MODEL` (default `gemini-3.6-flash`); do not send `temperature`.

## File Map

**API — create**
- `apps/api/src/recipes/units.ts` — `parseUnit`, `normalizeIngredientName`, `formatDecimal`, alias tables.
- `apps/api/src/recipes/units.spec.ts`
- `apps/api/src/recipes/migration-unit-aliases.spec.ts` — migration alias table stays in sync with `units.ts`.
- `apps/api/prisma/migrations/20260917090000_shopping_unit_estimates/migration.sql`
- `apps/api/src/trips/demand.ts` — `DemandEntry`, `addQuantity`, `readDemand`, `demandIncreased`, `reassessPantry`, `exactKnown`.
- `apps/api/src/trips/demand.spec.ts`
- `apps/api/src/trips/shopping-estimate.ts` — `estimateShopping`.
- `apps/api/src/trips/shopping-estimate.spec.ts`
- `apps/api/src/ingredients/ingredients.module.ts`
- `apps/api/src/ingredients/ingredient-profile-queue.service.ts`
- `apps/api/src/ingredients/ingredient-profile.generator.ts`
- `apps/api/src/ingredients/ingredient-profile.generator.spec.ts`
- `apps/api/src/ingredients/ingredient-profile.service.ts`
- `apps/api/src/ingredients/ingredient-profile.service.spec.ts`
- `apps/api/src/recipes/recipes.service.spec.ts`

**API — modify**
- `apps/api/src/recipes/quantity.service.ts` (format bug, remove `compatible`), `quantity.service.spec.ts`
- `apps/api/prisma/schema.prisma`
- `apps/api/src/recipes/recipes.service.ts`, `recipes.module.ts`
- `apps/api/src/trips/trips.service.ts`, `trips.module.ts`, `trips.service.spec.ts`
- `apps/api/src/worker.ts`

**Client — create**
- `apps/client/lib/features/trips/shopping_amounts.dart`
- `apps/client/lib/features/trips/shopping_item_breakdown.dart`
- `apps/client/test/shopping_amounts_test.dart`
- `apps/client/test/shopping_item_breakdown_test.dart`

**Client — modify**
- `apps/client/lib/features/trips/trip_detail_page.dart`
- `apps/client/lib/features/trips/shop_page.dart`

## Task Order and Dependencies

1 → 2 → 3 → 4 → 5 → 6 (API chain). Task 7 (client) depends only on the response shape in spec §7.4 and may run in parallel with Tasks 3–6. Task 8 is the final verification.

After Task 2 runs `prisma generate`, `trips.service.ts` and `trips.service.spec.ts` will not compile until Task 6. Tasks 3–5 run only their own spec files.

---

### Task 1: Unit parsing and the scaling format bug

**Files:**
- Create: `apps/api/src/recipes/units.ts`
- Create: `apps/api/src/recipes/units.spec.ts`
- Modify: `apps/api/src/recipes/quantity.service.ts`
- Modify: `apps/api/src/recipes/quantity.service.spec.ts`

**Interfaces:**
- Produces:
  - `type Dimension = 'MASS' | 'VOLUME' | 'COUNT'`
  - `type ParsedUnit = { dimension: Dimension; baseUnit: string; factor: Prisma.Decimal; token: string }`
  - `parseUnit(unit: string | null | undefined): ParsedUnit`
  - `normalizeIngredientName(name: string): string`
  - `formatDecimal(value: Prisma.Decimal): string`
  - `UNIT_ALIASES: ReadonlyArray<{ alias: string; token: string; dimension: 'MASS' | 'VOLUME'; factor: string }>`
  - `CASE_SENSITIVE_UNIT_ALIASES: ReadonlyArray<{ alias: 'T' | 't'; token: 'tbsp' | 'tsp'; dimension: 'VOLUME'; factor: string }>`
- `QuantityService.compatible` is removed.

- [ ] **Step 1: Write the failing unit tests**

`apps/api/src/recipes/units.spec.ts`:
```ts
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
```

Append to `apps/api/src/recipes/quantity.service.spec.ts` inside the `describe` block, and delete the existing `it('never merges incompatible dimensions', …)` test:
```ts
  it('keeps trailing zeros of whole-number results', () => {
    expect(
      service.scale(
        { min: '100', max: '250', unit: 'g', originalText: '100–250 g' },
        '2',
        '4',
      ),
    ).toMatchObject({ min: '200', max: '500' });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest src/recipes/units.spec.ts src/recipes/quantity.service.spec.ts`
Expected: `units.spec.ts` fails with "Cannot find module './units'"; the quantity test fails with `Expected "200", Received "2"`.

- [ ] **Step 3: Implement `units.ts`**

`apps/api/src/recipes/units.ts`:
```ts
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
  ...family(['tbsp', 'tbs', 'tablespoon', 'tablespoons'], 'tbsp', 'VOLUME', '15'),
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
  const alias = exact ?? aliasIndex.get(key);
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
```

- [ ] **Step 4: Fix `QuantityService`**

In `apps/api/src/recipes/quantity.service.ts`: delete the `compatible(...)` method; replace the `format` method body so it delegates to `formatDecimal`; add `import { formatDecimal } from './units';`.
```ts
  private format(value: Decimal) {
    return formatDecimal(value);
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx jest src/recipes src/cooking`
Expected: PASS (all suites in both folders).

- [ ] **Step 6: Format and lint**

Run: `npx prettier --write src/recipes/units.ts src/recipes/units.spec.ts src/recipes/quantity.service.ts src/recipes/quantity.service.spec.ts && npx eslint src/recipes/units.ts src/recipes/quantity.service.ts`
Expected: no lint errors. Leave changes uncommitted.

---

### Task 2: Schema, migration, and alias-sync test

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/20260917090000_shopping_unit_estimates/migration.sql`
- Create: `apps/api/src/recipes/migration-unit-aliases.spec.ts`

**Interfaces:**
- Consumes: `UNIT_ALIASES`, `CASE_SENSITIVE_UNIT_ALIASES` from Task 1.
- Produces (Prisma client types): enum `IngredientProfileStatus`; `CanonicalIngredient.{profileStatus, shoppingUnit, unitEstimates, packageSizes, profileModel, profiledAt, updatedAt}`; `ShoppingItem.{demand: Json, unmeasured: boolean}`; `ShoppingItem.quantityMin/quantityMax/unit` removed.

**Precondition (orchestrator):** the user has stopped the running API (`npm run start:dev`) and worker, otherwise `prisma generate` fails on Windows with `EPERM` on the locked query engine.

- [ ] **Step 1: Write the failing alias-sync test**

`apps/api/src/recipes/migration-unit-aliases.spec.ts`:
```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx jest src/recipes/migration-unit-aliases.spec.ts`
Expected: FAIL with `ENOENT` (migration file missing).

- [ ] **Step 3: Update `schema.prisma`**

Add the enum (next to the other enums):
```prisma
enum IngredientProfileStatus {
  PENDING
  READY
  FAILED
}
```
Replace `model CanonicalIngredient` with:
```prisma
model CanonicalIngredient {
  id                 String                  @id @default(cuid())
  canonicalName      String                  @unique
  dimension          String?
  profileStatus      IngredientProfileStatus @default(PENDING)
  shoppingUnit       String?
  unitEstimates      Json?
  packageSizes       Json?
  profileModel       String?
  profiledAt         DateTime?
  createdAt          DateTime                @default(now())
  updatedAt          DateTime                @updatedAt
}
```
In `model ShoppingItem`, delete the `quantityMin`, `quantityMax`, and `unit` lines and add:
```prisma
  demand               Json               @default("[]")
  unmeasured           Boolean            @default(false)
```

- [ ] **Step 4: Write the migration**

`apps/api/prisma/migrations/20260917090000_shopping_unit_estimates/migration.sql`:
```sql
-- CreateEnum
CREATE TYPE "IngredientProfileStatus" AS ENUM ('PENDING', 'READY', 'FAILED');

-- AlterTable
ALTER TABLE "CanonicalIngredient"
  ADD COLUMN "profileStatus" "IngredientProfileStatus" NOT NULL DEFAULT 'PENDING',
  ADD COLUMN "shoppingUnit" TEXT,
  ADD COLUMN "unitEstimates" JSONB,
  ADD COLUMN "packageSizes" JSONB,
  ADD COLUMN "profileModel" TEXT,
  ADD COLUMN "profiledAt" TIMESTAMP(3),
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "CanonicalIngredient" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "ShoppingItem"
  ADD COLUMN "demand" JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN "unmeasured" BOOLEAN NOT NULL DEFAULT false;

-- Backfill exact demand from the legacy single quantity. Snapshot of units.ts aliases;
-- src/recipes/migration-unit-aliases.spec.ts keeps this list in sync.
CREATE TEMP TABLE "_unit_alias" ("alias" TEXT PRIMARY KEY, "dimension" TEXT NOT NULL, "factor" NUMERIC NOT NULL);
INSERT INTO "_unit_alias" ("alias", "dimension", "factor") VALUES
  ('g', 'MASS', 1), ('gram', 'MASS', 1), ('grams', 'MASS', 1),
  ('kg', 'MASS', 1000), ('kilogram', 'MASS', 1000), ('kilograms', 'MASS', 1000),
  ('mg', 'MASS', 0.001), ('milligram', 'MASS', 0.001), ('milligrams', 'MASS', 0.001),
  ('oz', 'MASS', 28.349523125), ('ounce', 'MASS', 28.349523125), ('ounces', 'MASS', 28.349523125),
  ('lb', 'MASS', 453.59237), ('lbs', 'MASS', 453.59237), ('pound', 'MASS', 453.59237), ('pounds', 'MASS', 453.59237),
  ('ml', 'VOLUME', 1), ('milliliter', 'VOLUME', 1), ('milliliters', 'VOLUME', 1), ('millilitre', 'VOLUME', 1), ('millilitres', 'VOLUME', 1),
  ('l', 'VOLUME', 1000), ('liter', 'VOLUME', 1000), ('liters', 'VOLUME', 1000), ('litre', 'VOLUME', 1000), ('litres', 'VOLUME', 1000),
  ('tsp', 'VOLUME', 5), ('teaspoon', 'VOLUME', 5), ('teaspoons', 'VOLUME', 5),
  ('tbsp', 'VOLUME', 15), ('tbs', 'VOLUME', 15), ('tablespoon', 'VOLUME', 15), ('tablespoons', 'VOLUME', 15),
  ('cup', 'VOLUME', 240), ('cups', 'VOLUME', 240),
  ('fl oz', 'VOLUME', 29.5735), ('fluid ounce', 'VOLUME', 29.5735), ('fluid ounces', 'VOLUME', 29.5735),
  ('pint', 'VOLUME', 473.176), ('pints', 'VOLUME', 473.176),
  ('quart', 'VOLUME', 946.353), ('quarts', 'VOLUME', 946.353),
  ('gallon', 'VOLUME', 3785.41), ('gallons', 'VOLUME', 3785.41),
  ('T', 'VOLUME', 15), ('t', 'VOLUME', 5);

UPDATE "ShoppingItem" AS si
SET
  "unmeasured" = si."quantityMin" IS NULL,
  "demand" = CASE
    WHEN si."quantityMin" IS NULL THEN '[]'::jsonb
    ELSE jsonb_build_array(jsonb_build_object(
      'dimension', COALESCE(m."dimension", 'COUNT'),
      'unit', CASE
        WHEN m."dimension" = 'MASS' THEN 'g'
        WHEN m."dimension" = 'VOLUME' THEN 'ml'
        ELSE COALESCE(NULLIF(lower(trim(si."unit")), ''), 'piece')
      END,
      'min', trim_scale(si."quantityMin" * COALESCE(m."factor", 1))::text,
      'max', trim_scale(COALESCE(si."quantityMax", si."quantityMin") * COALESCE(m."factor", 1))::text
    ))
  END
FROM (
  SELECT s."id", ua."dimension", ua."factor"
  FROM "ShoppingItem" s
  LEFT JOIN "_unit_alias" ua ON ua."alias" = CASE
    WHEN trim(s."unit") IN ('T', 't') THEN trim(s."unit")
    ELSE lower(regexp_replace(trim(COALESCE(s."unit", '')), '\.$', ''))
  END
) AS m
WHERE m."id" = si."id";

DROP TABLE "_unit_alias";

-- AlterTable
ALTER TABLE "ShoppingItem"
  DROP COLUMN "quantityMin",
  DROP COLUMN "quantityMax",
  DROP COLUMN "unit";
```

- [ ] **Step 5: Run the alias test and validate the schema**

Run: `npx jest src/recipes/migration-unit-aliases.spec.ts && npx prisma validate && npx prisma generate`
Expected: test PASS; "The schema at prisma/schema.prisma is valid"; client generated. (`trips.service.ts` now has type errors until Task 6 — expected.)

- [ ] **Step 6: Dry-run the backfill against sample rows (no persistent change)**

Write `C:/Users/Adam/AppData/Local/Temp/pp-migration-dryrun.sql`:
```sql
BEGIN;
INSERT INTO "ShoppingItem" ("id","householdId","shoppingTripId","displayName","quantityMin","quantityMax","unit","status","revision","createdAt","updatedAt") VALUES
  ('dry-1','h','t','Flour',2,NULL,'cups','NEED_TO_BUY',1,now(),now()),
  ('dry-2','h','t','Butter',1.5,2,'Tbsp.','NEED_TO_BUY',1,now(),now()),
  ('dry-3','h','t','Garlic',4,NULL,'cloves','NEED_TO_BUY',1,now(),now()),
  ('dry-4','h','t','Salt',NULL,NULL,NULL,'NEED_TO_BUY',1,now(),now()),
  ('dry-5','h','t','Sugar',1,NULL,'T','NEED_TO_BUY',1,now(),now());
\i /tmp/migration.sql
SELECT "displayName", "demand", "unmeasured" FROM "ShoppingItem" WHERE "id" LIKE 'dry-%' ORDER BY "id";
ROLLBACK;
```
Run:
```bash
docker cp prisma/migrations/20260917090000_shopping_unit_estimates/migration.sql pantrypal-postgres:/tmp/migration.sql
docker cp C:/Users/Adam/AppData/Local/Temp/pp-migration-dryrun.sql pantrypal-postgres:/tmp/dryrun.sql
docker exec pantrypal-postgres psql -U pantrypal -d pantrypal -v ON_ERROR_STOP=1 -f /tmp/dryrun.sql
```
Expected rows:
- Flour → `[{"dimension":"VOLUME","unit":"ml","min":"480","max":"480"}]`, false
- Butter → `[{"dimension":"VOLUME","unit":"ml","min":"22.5","max":"30"}]`, false
- Garlic → `[{"dimension":"COUNT","unit":"cloves","min":"4","max":"4"}]`, false
- Salt → `[]`, true
- Sugar → `[{"dimension":"VOLUME","unit":"ml","min":"15","max":"15"}]`, false

Then confirm nothing persisted: `docker exec pantrypal-postgres psql -U pantrypal -d pantrypal -At -c "select count(*) from \"ShoppingItem\" where id like 'dry-%'; select column_name from information_schema.columns where table_name='ShoppingItem' and column_name='demand';"` → `0` and no `demand` row.

- [ ] **Step 7: Format**

Run: `npx prettier --write src/recipes/migration-unit-aliases.spec.ts`. Leave changes uncommitted.

- [ ] **Step 8 (orchestrator only, after user approval): Back up and apply**

```bash
docker exec pantrypal-postgres pg_dump -U pantrypal -d pantrypal > C:/Users/Adam/AppData/Local/Temp/pantrypal-before-shopping-units.sql
npx prisma migrate deploy
npx prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --script
```
Expected: migrate deploy applies `20260917090000_shopping_unit_estimates` (and any earlier unapplied local migrations); the diff prints an empty migration (`-- This is an empty migration.`).

---

### Task 3: Exact demand and shopping estimate (pure)

**Files:**
- Create: `apps/api/src/trips/demand.ts`, `apps/api/src/trips/demand.spec.ts`
- Create: `apps/api/src/trips/shopping-estimate.ts`, `apps/api/src/trips/shopping-estimate.spec.ts`

**Interfaces:**
- Consumes: `parseUnit`, `formatDecimal`, `Dimension` (Task 1).
- Produces:
  - `type DemandEntry = { dimension: Dimension; unit: string; min: string; max: string }`
  - `type QuantityInput = { quantityMin: string | null; quantityMax: string | null; unit: string | null }`
  - `addQuantity(demand: DemandEntry[], quantity: QuantityInput): DemandEntry[]`
  - `readDemand(value: Prisma.JsonValue | null | undefined): DemandEntry[]`
  - `demandIncreased(previous: DemandEntry[], current: DemandEntry[]): boolean`
  - `exactKnown(knownQuantity: string, unit: string | null, entry: DemandEntry): Prisma.Decimal | null`
  - `reassessPantry(current: DemandEntry[], assessment: { knownQuantity: string | null; unit: string | null; demandAtConfirmation: DemandEntry[] }): 'CONFIRMED_AT_HOME' | 'PARTIALLY_AVAILABLE' | 'CHECK_AGAIN'`
  - `type IngredientProfileSnapshot = { profileStatus: 'PENDING' | 'READY' | 'FAILED'; shoppingUnit: string | null; unitEstimates: Prisma.JsonValue; packageSizes: Prisma.JsonValue }`
  - `type ShoppingEstimate = { approximate: true; amount: string; unit: string; buy: { count: number; size: string; unit: string } | null; crossesDimension: boolean }`
  - `estimateShopping(demand: DemandEntry[], profile: IngredientProfileSnapshot | null, alreadyHave?: Prisma.Decimal): ShoppingEstimate | null`

- [ ] **Step 1: Write failing tests**

`apps/api/src/trips/demand.spec.ts`:
```ts
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
    let demand = addQuantity([], { quantityMin: '2', quantityMax: null, unit: 'tbsp' });
    demand = addQuantity(demand, { quantityMin: '60', quantityMax: null, unit: 'ml' });
    expect(demand).toEqual([ml('90')]);
  });

  it('keeps grams and cups as separate entries', () => {
    let demand = addQuantity([], { quantityMin: '300', quantityMax: null, unit: 'g' });
    demand = addQuantity(demand, { quantityMin: '2', quantityMax: null, unit: 'cups' });
    expect(demand).toEqual([
      { dimension: 'MASS', unit: 'g', min: '300', max: '300' },
      ml('480'),
    ]);
  });

  it('keeps different count units apart', () => {
    let demand = addQuantity([], { quantityMin: '4', quantityMax: null, unit: 'cloves' });
    demand = addQuantity(demand, { quantityMin: '1', quantityMax: null, unit: 'head' });
    expect(demand.map((entry) => entry.unit)).toEqual(['clove', 'head']);
  });

  it('adds ranges at both ends', () => {
    let demand = addQuantity([], { quantityMin: '1', quantityMax: '2', unit: 'cup' });
    demand = addQuantity(demand, { quantityMin: '100', quantityMax: null, unit: 'ml' });
    expect(demand).toEqual([ml('340', '580')]);
  });

  it('ignores unquantified amounts', () => {
    expect(addQuantity([ml('5')], { quantityMin: null, quantityMax: null, unit: 'tsp' })).toEqual([ml('5')]);
  });
});

describe('readDemand', () => {
  it('reads the stored array and drops malformed entries', () => {
    expect(readDemand([ml('5'), { dimension: 'MASS', unit: 'g', min: 'x', max: '1' }, 'nope'])).toEqual([ml('5')]);
  });

  it('converts the legacy single-quantity shape', () => {
    expect(readDemand({ quantityMin: '1', quantityMax: null, unit: 'cups' })).toEqual([ml('240')]);
  });

  it('returns an empty demand for null', () => {
    expect(readDemand(null)).toEqual([]);
  });
});

describe('demandIncreased', () => {
  it('detects growth and new entries only', () => {
    expect(demandIncreased([ml('240')], [ml('480')])).toBe(true);
    expect(demandIncreased([ml('240')], [ml('240'), { dimension: 'MASS', unit: 'g', min: '5', max: '5' }])).toBe(true);
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
    expect(reassessPantry([ml('240')], at(null, null))).toBe('CONFIRMED_AT_HOME');
  });

  it('confirms when an exact known amount still covers demand', () => {
    expect(reassessPantry([ml('480')], at('1', 'l'))).toBe('CONFIRMED_AT_HOME');
  });

  it('is partial when an exact known amount covers only part', () => {
    expect(reassessPantry([ml('480')], at('1', 'cup'))).toBe('PARTIALLY_AVAILABLE');
  });

  it('asks to check again without a known amount', () => {
    expect(reassessPantry([ml('480')], at(null, null))).toBe('CHECK_AGAIN');
  });

  it('asks to check again across dimensions or multiple entries', () => {
    expect(reassessPantry([ml('480')], at('500', 'g'))).toBe('CHECK_AGAIN');
    expect(
      reassessPantry([ml('480'), { dimension: 'MASS', unit: 'g', min: '1', max: '1' }], at('2', 'l')),
    ).toBe('CHECK_AGAIN');
  });
});

describe('Prisma.Decimal usage', () => {
  it('does not use floating point for exact sums', () => {
    const demand = addQuantity(addQuantity([], { quantityMin: '0.1', quantityMax: null, unit: 'ml' }), {
      quantityMin: '0.2',
      quantityMax: null,
      unit: 'ml',
    });
    expect(new Prisma.Decimal(demand[0].min).equals('0.3')).toBe(true);
  });
});
```

`apps/api/src/trips/shopping-estimate.spec.ts`:
```ts
import { Prisma } from '@prisma/client';
import { DemandEntry } from './demand';
import { estimateShopping, IngredientProfileSnapshot } from './shopping-estimate';

const flour: IngredientProfileSnapshot = {
  profileStatus: 'READY',
  shoppingUnit: 'g',
  unitEstimates: { ml: '0.53' },
  packageSizes: ['500', '1000'],
};
const g = (max: string): DemandEntry => ({ dimension: 'MASS', unit: 'g', min: max, max });
const ml = (max: string): DemandEntry => ({ dimension: 'VOLUME', unit: 'ml', min: max, max });

describe('estimateShopping', () => {
  it('converts same-dimension demand exactly without the cross-dimension flag', () => {
    expect(estimateShopping([g('300')], flour)).toEqual({
      approximate: true,
      amount: '300',
      unit: 'g',
      buy: { count: 1, size: '500', unit: 'g' },
      crossesDimension: false,
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
      estimateShopping([g('300'), { dimension: 'COUNT', unit: 'pinch', min: '1', max: '1' }], flour),
    ).toBeNull();
  });

  it('returns null without a ready profile or demand', () => {
    expect(estimateShopping([g('1')], null)).toBeNull();
    expect(estimateShopping([g('1')], { ...flour, profileStatus: 'PENDING' })).toBeNull();
    expect(estimateShopping([], flour)).toBeNull();
  });

  it('buys several of the largest package when none is big enough', () => {
    expect(estimateShopping([g('2300')], flour)?.buy).toEqual({ count: 3, size: '1000', unit: 'g' });
  });

  it('has no buy suggestion without package sizes', () => {
    expect(estimateShopping([g('300')], { ...flour, packageSizes: null })?.buy).toBeNull();
  });

  it('subtracts an exact amount already at home and clamps at zero', () => {
    expect(estimateShopping([g('800')], flour, new Prisma.Decimal(500))).toMatchObject({
      amount: '300',
      buy: { count: 1, size: '500', unit: 'g' },
    });
    expect(estimateShopping([g('300')], flour, new Prisma.Decimal(500))).toMatchObject({
      amount: '0',
      buy: null,
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
      estimateShopping([{ dimension: 'COUNT', unit: 'clove', min: '4', max: '4' }], garlic),
    ).toMatchObject({ amount: '0.4', unit: 'head', buy: { count: 1, size: '1', unit: 'head' } });
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx jest src/trips/demand.spec.ts src/trips/shopping-estimate.spec.ts`
Expected: FAIL, "Cannot find module './demand'" / "'./shopping-estimate'".

- [ ] **Step 3: Implement `demand.ts`**

```ts
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
  if (quantity.quantityMin == null || !decimalPattern.test(quantity.quantityMin))
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
        candidate.dimension === entry.dimension && candidate.unit === entry.unit,
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
  const known = exactKnown(assessment.knownQuantity, assessment.unit, current[0]);
  if (!known) return 'CHECK_AGAIN';
  return known.gte(current[0].max) ? 'CONFIRMED_AT_HOME' : 'PARTIALLY_AVAILABLE';
}
```

- [ ] **Step 4: Implement `shopping-estimate.ts`**

```ts
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
      (size): size is string => typeof size === 'string' && decimalPattern.test(size),
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
    if (entry.dimension === shopping.dimension && entry.unit === shopping.baseUnit) {
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
  };
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx jest src/trips/demand.spec.ts src/trips/shopping-estimate.spec.ts`
Expected: PASS.

- [ ] **Step 6: Format and lint**

Run: `npx prettier --write src/trips/demand.ts src/trips/demand.spec.ts src/trips/shopping-estimate.ts src/trips/shopping-estimate.spec.ts && npx eslint src/trips/demand.ts src/trips/shopping-estimate.ts`
Expected: clean. Leave uncommitted.

---

### Task 4: Ingredients module (profile resolution, queue, Gemini generator, worker)

**Files:**
- Create: `apps/api/src/ingredients/ingredients.module.ts`
- Create: `apps/api/src/ingredients/ingredient-profile-queue.service.ts`
- Create: `apps/api/src/ingredients/ingredient-profile.generator.ts`, `ingredient-profile.generator.spec.ts`
- Create: `apps/api/src/ingredients/ingredient-profile.service.ts`, `ingredient-profile.service.spec.ts`
- Modify: `apps/api/src/worker.ts`

**Interfaces:**
- Consumes: `parseUnit`, `normalizeIngredientName`, `formatDecimal`, `Dimension` (Task 1); Prisma types from Task 2.
- Produces:
  - `IngredientsModule` exporting `IngredientProfileService`.
  - `IngredientProfileService.resolveIngredients(names: string[], client?: Prisma.TransactionClient): Promise<Map<string, string>>` — key: normalized name, value: `CanonicalIngredient.id`.
  - `IngredientProfileService.requestProfiles(canonicalIngredientIds: string[]): Promise<void>` — never throws.
  - `IngredientProfileService.processBatch(jobId: string, canonicalIngredientIds: string[], finalAttempt: boolean): Promise<void>`
  - `IngredientProfileService.isEnabled(): boolean`
  - `ingredientProfileQueueName = 'ingredient-profiles'`, `type IngredientProfileJob = { canonicalIngredientIds: string[] }`

- [ ] **Step 1: Write failing generator tests**

`apps/api/src/ingredients/ingredient-profile.generator.spec.ts`:
```ts
import { ConfigService } from '@nestjs/config';
import {
  IngredientProfileGenerator,
  IngredientProfileProviderError,
} from './ingredient-profile.generator';

const config = (values: Record<string, string | undefined>) =>
  ({ get: (key: string) => values[key] }) as unknown as ConfigService;

describe('IngredientProfileGenerator.validate', () => {
  const generator = new IngredientProfileGenerator(config({}));

  it('keeps valid profiles and converts estimate units to base units', () => {
    const result = generator.validate(['flour', 'garlic'], {
      ingredients: [
        {
          name: 'Flour',
          dimension: 'MASS',
          shoppingUnit: 'g',
          unitEstimates: [
            { unit: 'cup', amount: 125 },
            { unit: 'oz', amount: 28 },
          ],
          packageSizes: [1000, 500, 500],
        },
        {
          name: 'garlic',
          dimension: 'COUNT',
          shoppingUnit: 'heads',
          unitEstimates: [{ unit: 'cloves', amount: 0.1 }],
          packageSizes: [1],
        },
      ],
    });
    expect(result.rejected).toEqual([]);
    expect(result.profiles).toEqual([
      {
        name: 'flour',
        dimension: 'MASS',
        shoppingUnit: 'g',
        unitEstimates: { ml: '0.520833' },
        packageSizes: ['500', '1000'],
      },
      {
        name: 'garlic',
        dimension: 'COUNT',
        shoppingUnit: 'head',
        unitEstimates: { clove: '0.1' },
        packageSizes: ['1'],
      },
    ]);
  });

  it('drops invalid numbers individually', () => {
    const result = generator.validate(['olive oil'], {
      ingredients: [
        {
          name: 'olive oil',
          dimension: 'VOLUME',
          shoppingUnit: 'ml',
          unitEstimates: [
            { unit: 'g', amount: -1 },
            { unit: 'tbsp', amount: 15 },
          ],
          packageSizes: [0, 500, 'big'],
        },
      ],
    });
    expect(result.profiles[0]).toMatchObject({ unitEstimates: {}, packageSizes: ['500'] });
  });

  it('rejects a shopping unit that does not match the dimension and reports missing names', () => {
    const result = generator.validate(['salt', 'pepper'], {
      ingredients: [{ name: 'salt', dimension: 'MASS', shoppingUnit: 'ml', unitEstimates: [], packageSizes: [] }],
    });
    expect(result.profiles).toEqual([]);
    expect(result.rejected).toEqual([
      { name: 'salt', reason: 'shopping unit does not match dimension' },
      { name: 'pepper', reason: 'missing from response' },
    ]);
  });
});

describe('IngredientProfileGenerator.generate', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });
  const generator = new IngredientProfileGenerator(
    config({ GEMINI_API_KEY: 'key', GEMINI_MODEL: 'gemini-3.6-flash' }),
  );
  const respond = (status: number, body: unknown) => {
    global.fetch = jest
      .fn<Promise<Response>, []>()
      .mockResolvedValue(new Response(JSON.stringify(body), { status }));
  };

  it('marks 429 and 5xx as retryable', async () => {
    respond(503, { error: { message: 'busy' } });
    await expect(generator.generate(['flour'])).rejects.toMatchObject({ retryable: true });
    respond(429, {});
    await expect(generator.generate(['flour'])).rejects.toBeInstanceOf(IngredientProfileProviderError);
  });

  it('marks other 4xx as final and keeps the provider message', async () => {
    respond(404, { error: { message: 'model gone' } });
    await expect(generator.generate(['flour'])).rejects.toMatchObject({
      retryable: false,
      message: 'Ingredient profile provider returned HTTP 404: model gone',
    });
  });

  it('parses the structured response', async () => {
    respond(200, {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  ingredients: [
                    { name: 'flour', dimension: 'MASS', shoppingUnit: 'g', unitEstimates: [], packageSizes: [1000] },
                  ],
                }),
              },
            ],
          },
        },
      ],
    });
    await expect(generator.generate(['flour'])).resolves.toMatchObject({
      profiles: [{ name: 'flour', packageSizes: ['1000'] }],
    });
  });
});
```

- [ ] **Step 2: Write failing service tests**

`apps/api/src/ingredients/ingredient-profile.service.spec.ts`:
```ts
import { Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  IngredientProfileGenerator,
  IngredientProfileProviderError,
} from './ingredient-profile.generator';
import { IngredientProfileQueueService } from './ingredient-profile-queue.service';
import { IngredientProfileService } from './ingredient-profile.service';

describe('IngredientProfileService', () => {
  let prisma: {
    canonicalIngredient: {
      upsert: jest.Mock;
      findMany: jest.Mock;
      updateMany: jest.Mock;
      update: jest.Mock;
    };
  };
  let queue: { enqueue: jest.Mock };
  let generator: { isEnabled: jest.Mock; model: jest.Mock; generate: jest.Mock };
  let service: IngredientProfileService;

  beforeEach(() => {
    prisma = {
      canonicalIngredient: {
        upsert: jest.fn(({ where }: { where: { canonicalName: string } }) =>
          Promise.resolve({ id: `ci-${where.canonicalName}` }),
        ),
        findMany: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    queue = { enqueue: jest.fn().mockResolvedValue(undefined) };
    generator = {
      isEnabled: jest.fn().mockReturnValue(true),
      model: jest.fn().mockReturnValue('gemini-3.6-flash'),
      generate: jest.fn(),
    };
    service = new IngredientProfileService(
      prisma as unknown as PrismaService,
      queue as unknown as IngredientProfileQueueService,
      generator as unknown as IngredientProfileGenerator,
    );
    jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    jest.spyOn(Logger.prototype, 'log').mockImplementation();
  });
  afterEach(() => jest.restoreAllMocks());

  it('resolves normalized unique names to canonical ids', async () => {
    const result = await service.resolveIngredients(['Tomatoes', 'tomato', ' ']);
    expect([...result.entries()]).toEqual([['tomato', 'ci-tomato']]);
    expect(prisma.canonicalIngredient.upsert).toHaveBeenCalledTimes(1);
  });

  it('enqueues only pending or failed rows and resets failed ones', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([{ id: 'a' }]);
    await service.requestProfiles(['a', 'b']);
    expect(prisma.canonicalIngredient.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['a', 'b'] }, profileStatus: { in: ['PENDING', 'FAILED'] } },
      select: { id: true },
    });
    expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['a'] }, profileStatus: 'FAILED' },
      data: { profileStatus: 'PENDING' },
    });
    expect(queue.enqueue).toHaveBeenCalledWith(['a']);
  });

  it('does nothing when profiles are disabled', async () => {
    generator.isEnabled.mockReturnValue(false);
    await service.requestProfiles(['a']);
    expect(queue.enqueue).not.toHaveBeenCalled();
  });

  it('never throws when enqueueing fails', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([{ id: 'a' }]);
    queue.enqueue.mockRejectedValue(new Error('redis down'));
    await expect(service.requestProfiles(['a'])).resolves.toBeUndefined();
  });

  it('stores ready profiles and fails rejected names', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'ci-flour', canonicalName: 'flour' },
      { id: 'ci-salt', canonicalName: 'salt' },
    ]);
    generator.generate.mockResolvedValue({
      profiles: [
        { name: 'flour', dimension: 'MASS', shoppingUnit: 'g', unitEstimates: { ml: '0.53' }, packageSizes: ['1000'] },
      ],
      rejected: [{ name: 'salt', reason: 'missing from response' }],
    });
    await service.processBatch('job-1', ['ci-flour', 'ci-salt'], false);
    expect(prisma.canonicalIngredient.update).toHaveBeenCalledWith({
      where: { id: 'ci-flour' },
      data: expect.objectContaining({
        profileStatus: 'READY',
        dimension: 'MASS',
        shoppingUnit: 'g',
        unitEstimates: { ml: '0.53' },
        packageSizes: ['1000'],
        profileModel: 'gemini-3.6-flash',
      }),
    });
    expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['ci-salt'] } },
      data: { profileStatus: 'FAILED' },
    });
  });

  it('skips work when no requested row is still pending', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([]);
    await service.processBatch('job-1', ['x'], false);
    expect(generator.generate).not.toHaveBeenCalled();
  });

  it('rethrows retryable errors before the final attempt', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([{ id: 'a', canonicalName: 'flour' }]);
    generator.generate.mockRejectedValue(new IngredientProfileProviderError(true, 'HTTP 503'));
    await expect(service.processBatch('job-1', ['a'], false)).rejects.toThrow('HTTP 503');
  });

  it('fails rows on the final attempt or a non-retryable error', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([{ id: 'a', canonicalName: 'flour' }]);
    generator.generate.mockRejectedValue(new IngredientProfileProviderError(false, 'HTTP 404'));
    await service.processBatch('job-1', ['a'], false);
    expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['a'] } },
      data: { profileStatus: 'FAILED' },
    });
  });
});
```

- [ ] **Step 3: Run to verify failure**

Run: `npx jest src/ingredients`
Expected: FAIL, modules not found.

- [ ] **Step 4: Implement the queue service**

`apps/api/src/ingredients/ingredient-profile-queue.service.ts`:
```ts
import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';

export const ingredientProfileQueueName = 'ingredient-profiles';
export type IngredientProfileJob = { canonicalIngredientIds: string[] };

@Injectable()
export class IngredientProfileQueueService implements OnModuleDestroy {
  private queue?: Queue<IngredientProfileJob>;

  enqueue(canonicalIngredientIds: string[]) {
    if (process.env.NODE_ENV === 'test' || !canonicalIngredientIds.length)
      return Promise.resolve();
    return this.getQueue().add(
      'profile-ingredients',
      { canonicalIngredientIds },
      {
        attempts: 3,
        backoff: { type: 'exponential', delay: 5_000 },
        removeOnComplete: 100,
        removeOnFail: 500,
      },
    );
  }

  onModuleDestroy() {
    return this.queue?.close();
  }

  private getQueue() {
    return (this.queue ??= new Queue<IngredientProfileJob>(
      ingredientProfileQueueName,
      {
        connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
      },
    ));
  }
}
```

- [ ] **Step 5: Implement the generator**

`apps/api/src/ingredients/ingredient-profile.generator.ts`:
```ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { Dimension, formatDecimal, parseUnit } from '../recipes/units';

export class IngredientProfileProviderError extends Error {
  constructor(
    readonly retryable: boolean,
    message: string,
  ) {
    super(message);
  }
}

export type GeneratedProfile = {
  name: string;
  dimension: Dimension;
  shoppingUnit: string;
  unitEstimates: Record<string, string>;
  packageSizes: string[];
};

export type GenerationResult = {
  profiles: GeneratedProfile[];
  rejected: Array<{ name: string; reason: string }>;
};

const profileSchema = {
  type: 'object',
  properties: {
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          dimension: { type: 'string', enum: ['MASS', 'VOLUME', 'COUNT'] },
          shoppingUnit: { type: 'string' },
          unitEstimates: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                unit: { type: 'string' },
                amount: { type: 'number' },
              },
              required: ['unit', 'amount'],
            },
          },
          packageSizes: { type: 'array', items: { type: 'number' } },
        },
        required: [
          'name',
          'dimension',
          'shoppingUnit',
          'unitEstimates',
          'packageSizes',
        ],
      },
    },
  },
  required: ['ingredients'],
};

const validNumber = (value: unknown): value is number =>
  typeof value === 'number' &&
  Number.isFinite(value) &&
  value > 0 &&
  value < 1_000_000;

@Injectable()
export class IngredientProfileGenerator {
  constructor(private readonly config: ConfigService) {}

  isEnabled() {
    return !!this.config.get<string>('GEMINI_API_KEY')?.trim();
  }

  model() {
    return this.config.get<string>('GEMINI_MODEL') ?? 'gemini-3.6-flash';
  }

  async generate(names: string[]): Promise<GenerationResult> {
    const apiKey = this.config.get<string>('GEMINI_API_KEY')?.trim();
    if (!apiKey)
      throw new IngredientProfileProviderError(false, 'GEMINI_API_KEY is not set.');
    let response: Response;
    try {
      response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(this.model())}:generateContent`,
        {
          method: 'POST',
          signal: AbortSignal.timeout(60_000),
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
          body: JSON.stringify({
            contents: [{ parts: [{ text: this.prompt(names) }] }],
            generationConfig: {
              responseMimeType: 'application/json',
              responseJsonSchema: profileSchema,
            },
          }),
        },
      );
    } catch (error) {
      throw new IngredientProfileProviderError(
        true,
        `Ingredient profile request failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
    if (!response.ok) {
      const reason = await this.providerMessage(response);
      const message = reason
        ? `Ingredient profile provider returned HTTP ${response.status}: ${reason}`
        : `Ingredient profile provider returned HTTP ${response.status}.`;
      throw new IngredientProfileProviderError(
        response.status === 429 || response.status >= 500,
        message,
      );
    }
    const payload = (await response.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = payload.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? '')
      .join('');
    try {
      return this.validate(names, JSON.parse(text ?? '') as unknown);
    } catch {
      throw new IngredientProfileProviderError(
        false,
        'Ingredient profile provider returned invalid JSON.',
      );
    }
  }

  validate(requested: string[], raw: unknown): GenerationResult {
    const wanted = new Set(requested);
    const seen = new Set<string>();
    const profiles: GeneratedProfile[] = [];
    const rejected: GenerationResult['rejected'] = [];
    const entries =
      raw && typeof raw === 'object' && Array.isArray((raw as { ingredients?: unknown }).ingredients)
        ? ((raw as { ingredients: unknown[] }).ingredients)
        : [];
    for (const item of entries) {
      if (!item || typeof item !== 'object') continue;
      const entry = item as Record<string, unknown>;
      const name =
        typeof entry.name === 'string' ? entry.name.trim().toLocaleLowerCase() : '';
      if (!wanted.has(name) || seen.has(name)) continue;
      seen.add(name);
      const dimension = entry.dimension;
      if (dimension !== 'MASS' && dimension !== 'VOLUME' && dimension !== 'COUNT') {
        rejected.push({ name, reason: 'invalid dimension' });
        continue;
      }
      const rawUnit = typeof entry.shoppingUnit === 'string' ? entry.shoppingUnit.trim() : '';
      const shopping = parseUnit(rawUnit);
      const unitMatches =
        dimension === 'MASS'
          ? rawUnit === 'g'
          : dimension === 'VOLUME'
            ? rawUnit === 'ml'
            : rawUnit !== '' && shopping.dimension === 'COUNT';
      if (!unitMatches) {
        rejected.push({ name, reason: 'shopping unit does not match dimension' });
        continue;
      }
      const unitEstimates: Record<string, string> = {};
      for (const estimate of Array.isArray(entry.unitEstimates) ? entry.unitEstimates : []) {
        if (!estimate || typeof estimate !== 'object') continue;
        const { unit, amount } = estimate as { unit?: unknown; amount?: unknown };
        if (typeof unit !== 'string' || !unit.trim() || !validNumber(amount)) continue;
        const parsed = parseUnit(unit);
        if (parsed.dimension === dimension && parsed.baseUnit === shopping.baseUnit) continue;
        unitEstimates[parsed.baseUnit] = formatDecimal(
          new Prisma.Decimal(amount).div(parsed.factor),
        );
      }
      const packageSizes = [
        ...new Set(
          (Array.isArray(entry.packageSizes) ? entry.packageSizes : [])
            .filter(validNumber)
            .sort((left, right) => left - right)
            .map((size) => formatDecimal(new Prisma.Decimal(size))),
        ),
      ];
      profiles.push({
        name,
        dimension,
        shoppingUnit: shopping.baseUnit,
        unitEstimates,
        packageSizes,
      });
    }
    for (const name of requested)
      if (!seen.has(name)) rejected.push({ name, reason: 'missing from response' });
    return { profiles, rejected };
  }

  private prompt(names: string[]) {
    return [
      'For each grocery ingredient below, describe how a home cook in a metric country buys it at a supermarket.',
      'Use the ingredient name exactly as given.',
      'dimension: MASS if normally sold by weight, VOLUME if sold by volume, COUNT if sold as whole items.',
      'shoppingUnit: "g" for MASS, "ml" for VOLUME, or a singular noun such as head, bunch, can or piece for COUNT.',
      'unitEstimates: for g, ml, and any count unit recipes commonly use for this ingredient (for example clove, slice, can), give how much of shoppingUnit one of that unit typically equals. Omit any you are not confident about.',
      'packageSizes: common retail package sizes, expressed in shoppingUnit.',
      '',
      'Ingredients:',
      ...names.map((name) => `- ${name}`),
    ].join('\n');
  }

  private async providerMessage(response: Response) {
    try {
      const payload = (await response.json()) as { error?: { message?: unknown } };
      const message = payload.error?.message;
      return typeof message === 'string' ? message.slice(0, 300) : undefined;
    } catch {
      return undefined;
    }
  }
}
```
Note on `validate`: estimate amounts are "shoppingUnit per 1 given unit"; dividing by `parsed.factor` converts to "per 1 base unit" (e.g. 125 g per cup ÷ 240 = 0.520833 g per ml). Count units have factor 1.

- [ ] **Step 6: Implement the service**

`apps/api/src/ingredients/ingredient-profile.service.ts`:
```ts
import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeIngredientName } from '../recipes/units';
import {
  IngredientProfileGenerator,
  IngredientProfileProviderError,
} from './ingredient-profile.generator';
import { IngredientProfileQueueService } from './ingredient-profile-queue.service';

@Injectable()
export class IngredientProfileService {
  private readonly logger = new Logger(IngredientProfileService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly queue: IngredientProfileQueueService,
    private readonly generator: IngredientProfileGenerator,
  ) {}

  isEnabled() {
    return this.generator.isEnabled();
  }

  async resolveIngredients(
    names: string[],
    client: Prisma.TransactionClient = this.prisma,
  ) {
    const resolved = new Map<string, string>();
    const canonicalNames = [
      ...new Set(names.map(normalizeIngredientName).filter(Boolean)),
    ];
    for (const canonicalName of canonicalNames) {
      const row = await client.canonicalIngredient.upsert({
        where: { canonicalName },
        create: { canonicalName },
        update: {},
        select: { id: true },
      });
      resolved.set(canonicalName, row.id);
    }
    return resolved;
  }

  async requestProfiles(canonicalIngredientIds: string[]) {
    if (!canonicalIngredientIds.length || !this.generator.isEnabled()) return;
    try {
      const rows = await this.prisma.canonicalIngredient.findMany({
        where: {
          id: { in: canonicalIngredientIds },
          profileStatus: { in: ['PENDING', 'FAILED'] },
        },
        select: { id: true },
      });
      if (!rows.length) return;
      const ids = rows.map((row) => row.id);
      await this.prisma.canonicalIngredient.updateMany({
        where: { id: { in: ids }, profileStatus: 'FAILED' },
        data: { profileStatus: 'PENDING' },
      });
      await this.queue.enqueue(ids);
    } catch (error) {
      this.logger.warn(
        `Could not request ingredient profiles: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }

  async processBatch(
    jobId: string,
    canonicalIngredientIds: string[],
    finalAttempt: boolean,
  ) {
    const rows = await this.prisma.canonicalIngredient.findMany({
      where: { id: { in: canonicalIngredientIds }, profileStatus: 'PENDING' },
      select: { id: true, canonicalName: true },
    });
    if (!rows.length) return;
    let result;
    try {
      result = await this.generator.generate(rows.map((row) => row.canonicalName));
    } catch (error) {
      const retryable =
        error instanceof IngredientProfileProviderError && error.retryable;
      if (retryable && !finalAttempt) throw error;
      await this.prisma.canonicalIngredient.updateMany({
        where: { id: { in: rows.map((row) => row.id) } },
        data: { profileStatus: 'FAILED' },
      });
      this.logger.warn(
        `Ingredient profile batch ${jobId} failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      return;
    }
    const idByName = new Map(rows.map((row) => [row.canonicalName, row.id]));
    for (const profile of result.profiles) {
      const id = idByName.get(profile.name);
      if (!id) continue;
      await this.prisma.canonicalIngredient.update({
        where: { id },
        data: {
          profileStatus: 'READY',
          dimension: profile.dimension,
          shoppingUnit: profile.shoppingUnit,
          unitEstimates: profile.unitEstimates,
          packageSizes: profile.packageSizes,
          profileModel: this.generator.model(),
          profiledAt: new Date(),
        },
      });
    }
    const failedIds = result.rejected
      .map((entry) => idByName.get(entry.name))
      .filter((id): id is string => !!id);
    if (failedIds.length)
      await this.prisma.canonicalIngredient.updateMany({
        where: { id: { in: failedIds } },
        data: { profileStatus: 'FAILED' },
      });
    const reasons = result.rejected
      .map((entry) => `${entry.name}: ${entry.reason}`)
      .join(', ');
    this.logger.log(
      `Ingredient profile batch ${jobId} ready: ${result.profiles.length}, failed: ${result.rejected.length}${reasons ? ` [${reasons}]` : ''}`,
    );
  }
}
```

- [ ] **Step 7: Module and worker**

`apps/api/src/ingredients/ingredients.module.ts`:
```ts
import { Module } from '@nestjs/common';
import { IngredientProfileGenerator } from './ingredient-profile.generator';
import { IngredientProfileQueueService } from './ingredient-profile-queue.service';
import { IngredientProfileService } from './ingredient-profile.service';

@Module({
  providers: [
    IngredientProfileGenerator,
    IngredientProfileQueueService,
    IngredientProfileService,
  ],
  exports: [IngredientProfileService],
})
export class IngredientsModule {}
```

In `apps/api/src/worker.ts`, add imports:
```ts
import { IngredientProfileService } from './ingredients/ingredient-profile.service';
import {
  IngredientProfileJob,
  ingredientProfileQueueName,
} from './ingredients/ingredient-profile-queue.service';
```
and after the existing import `worker.on('failed', …)` block, before `archivePastCooking` is defined, add:
```ts
  const profiles = app.get(IngredientProfileService);
  if (!profiles.isEnabled())
    logger.log('Ingredient profiles disabled: GEMINI_API_KEY is not set.');
  const profileWorker = new Worker<IngredientProfileJob>(
    ingredientProfileQueueName,
    async (job) =>
      profiles.processBatch(
        job.id ?? 'unknown',
        job.data.canonicalIngredientIds,
        job.attemptsMade + 1 >= (job.opts.attempts ?? 1),
      ),
    {
      connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
      concurrency: 1,
    },
  );
  profileWorker.on('error', (error) =>
    logger.error(`Ingredient profile queue error: ${error.message}`),
  );
```
(`IngredientsModule` becomes reachable from `AppModule` through `RecipesModule`/`TripsModule` in Tasks 5–6; `app.get` resolves it without strict mode.)

- [ ] **Step 8: Run tests**

Run: `npx jest src/ingredients`
Expected: PASS. If the `0.520833` expectation differs only by `formatDecimal` rounding, check the division: `125 / 240 = 0.5208333…` → 6 dp → `0.520833`.

- [ ] **Step 9: Format and lint**

Run: `npx prettier --write src/ingredients src/worker.ts && npx eslint src/ingredients/ingredients.module.ts src/ingredients/ingredient-profile-queue.service.ts src/ingredients/ingredient-profile.generator.ts src/ingredients/ingredient-profile.service.ts src/worker.ts`
Expected: clean (`prettier --write src/ingredients` is allowed: the folder is new and fully owned by this task). Leave uncommitted.

---

### Task 5: Link recipe ingredients and request profiles on review save

**Files:**
- Modify: `apps/api/src/recipes/recipes.service.ts`
- Modify: `apps/api/src/recipes/recipes.module.ts`
- Create: `apps/api/src/recipes/recipes.service.spec.ts`

**Interfaces:**
- Consumes: `IngredientProfileService.resolveIngredients`, `.requestProfiles` (Task 4); `parseUnit`, `normalizeIngredientName` (Task 1).
- Produces: `RecipesService` constructor gains a 4th parameter `ingredients: IngredientProfileService`.

- [ ] **Step 1: Write the failing test**

`apps/api/src/recipes/recipes.service.spec.ts`:
```ts
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
        findFirst: jest.fn().mockResolvedValue({ id: 'recipe-1', currentVersionId: 'v1', revision: 1 }),
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
      recipeInstruction: { createMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    const prisma = {
      $transaction: jest.fn(async (callback: (client: typeof tx) => Promise<unknown>) => {
        const result = await callback(tx);
        order.push('commit');
        return result;
      }),
      account: { findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }) },
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
        return Promise.resolve();
      }),
    };
    const service = new RecipesService(
      prisma as unknown as PrismaService,
      { requireActiveMembership: jest.fn() } as unknown as HouseholdAccessService,
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
        { name: 'Carrots', quantityMin: '2', originalUnit: null, classification: 'REQUIRED', includeInShopping: true },
        { name: 'Olive oil', quantityMin: '2', originalUnit: 'Tbsp', classification: 'REQUIRED', includeInShopping: true },
      ],
    } as never);

    expect(ingredients.resolveIngredients).toHaveBeenCalledWith(['Carrots', 'Olive oil']);
    expect(tx.recipeIngredient.createMany).toHaveBeenCalledWith({
      data: [
        expect.objectContaining({ name: 'Carrots', canonicalIngredientId: 'ci-carrot', normalizedUnit: null }),
        expect.objectContaining({ name: 'Olive oil', canonicalIngredientId: 'ci-oil', normalizedUnit: 'tbsp' }),
      ],
    });
    expect(ingredients.requestProfiles).toHaveBeenCalledWith(['ci-carrot', 'ci-oil']);
    expect(order).toEqual(['createMany', 'commit', 'requestProfiles']);
  });
});
```
If `saveReview` reads additional fields from the mocked objects (check `changedFields`, `readiness`, `review`), extend the mocks rather than changing production code.

- [ ] **Step 2: Run to verify failure**

Run: `npx jest src/recipes/recipes.service.spec.ts`
Expected: FAIL — `resolveIngredients` not called / createMany data lacks `canonicalIngredientId`.

- [ ] **Step 3: Implement**

In `recipes.service.ts`:
- Add imports:
```ts
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { normalizeIngredientName, parseUnit } from './units';
```
- Constructor: add `private readonly ingredients: IngredientProfileService,` as the 4th parameter.
- In `saveReview`, directly after `this.assertDecimalInput(input);` add:
```ts
    const canonicalIds = await this.ingredients.resolveIngredients(
      input.ingredients.map((item) => item.name),
    );
```
- In the `tx.recipeIngredient.createMany` data mapper, add two properties:
```ts
          canonicalIngredientId:
            canonicalIds.get(normalizeIngredientName(item.name)) ?? null,
          normalizedUnit: item.originalUnit
            ? parseUnit(item.originalUnit).token
            : null,
```
- Directly after the `$transaction` call resolves (before `account` lookup), add:
```ts
    await this.ingredients.requestProfiles([...new Set(canonicalIds.values())]);
```

In `recipes.module.ts`: add `import { IngredientsModule } from '../ingredients/ingredients.module';` and include `IngredientsModule` in `imports`.

- [ ] **Step 4: Run tests**

Run: `npx jest src/recipes`
Expected: PASS.

- [ ] **Step 5: Format and lint**

Run: `npx prettier --write src/recipes/recipes.service.ts src/recipes/recipes.module.ts src/recipes/recipes.service.spec.ts && npx eslint src/recipes/recipes.service.ts src/recipes/recipes.module.ts`
Expected: clean. Leave uncommitted.

---

### Task 6: Trips — aggregation, rebuild, pantry, and item presentation

**Files:**
- Modify: `apps/api/src/trips/trips.service.ts`
- Modify: `apps/api/src/trips/trips.module.ts`
- Modify: `apps/api/src/trips/trips.service.spec.ts`

**Interfaces:**
- Consumes: `normalizeIngredientName`, `parseUnit` (Task 1); `addQuantity`, `readDemand`, `reassessPantry`, `exactKnown`, `DemandEntry` (Task 3); `estimateShopping`, `IngredientProfileSnapshot` (Task 3); `IngredientProfileService.resolveIngredients`, `.requestProfiles` (Task 4).
- Produces: `TripsService` constructor gains 5th parameter `ingredients: IngredientProfileService`. Trip detail items and `updateItem` responses use the spec §7.4 shape.

- [ ] **Step 1: Update and add failing tests**

In `trips.service.spec.ts`:
1. Add `import { IngredientProfileService } from '../ingredients/ingredient-profile.service';`.
2. Add a helper at the top of the `describe`:
```ts
  const ingredientsStub = () =>
    ({
      resolveIngredients: jest.fn((names: string[]) =>
        Promise.resolve(new Map(names.map((name) => [name, `ci-${name}`]))),
      ),
      requestProfiles: jest.fn().mockResolvedValue(undefined),
    }) as unknown as IngredientProfileService;
```
3. Pass `ingredientsStub()` as the 5th constructor argument in both existing tests.
4. In the existing pantry test, replace legacy item fields: `findMany` item becomes `{ id: itemId, displayName: 'Cheese', demand: [{ dimension: 'VOLUME', unit: 'ml', min: '240', max: '240' }], unmeasured: false, status: ShoppingItemStatus.CONFIRMED_AT_HOME }`; the first `update` resolved value becomes `{ id: itemId, displayName: 'Cheese', demand: [{ dimension: 'VOLUME', unit: 'ml', min: '480', max: '480' }], unmeasured: false, status: ShoppingItemStatus.CONFIRMED_AT_HOME }`. Keep `demandAtConfirmation` in the legacy shape (it exercises `readDemand`'s legacy path). Expected outcome is unchanged (`CHECK_AGAIN`).
5. Add these tests:
```ts
  const refreshHarness = (
    scaledIngredients: Array<Record<string, unknown>>,
    existing: Array<Record<string, unknown>> = [],
  ) => {
    const tx = {
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({ id: 'trip-1', status: TripStatus.CONFIRMED }),
      },
      cookingInstance: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'cooking-1', recipeSnapshot: { title: 'Pancakes' }, scaledIngredients },
        ]),
      },
      shoppingItem: {
        findMany: jest.fn().mockResolvedValue(existing),
        update: jest.fn((args: { where: { id: string }; data: Record<string, unknown> }) =>
          Promise.resolve({ id: args.where.id, ...args.data, status: args.data.status ?? ShoppingItemStatus.NEED_TO_BUY }),
        ),
        create: jest.fn((args: { data: Record<string, unknown> }) =>
          Promise.resolve({ id: 'new-item', ...args.data }),
        ),
        deleteMany: jest.fn(),
      },
      shoppingItemContribution: { deleteMany: jest.fn(), createMany: jest.fn() },
      pantryAssessment: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)),
      account: { findUniqueOrThrow: jest.fn().mockResolvedValue({ displayName: 'Ada' }) },
    };
    const ingredients = ingredientsStub();
    const service = new TripsService(
      prisma as unknown as PrismaService,
      { requireActiveMembership: jest.fn() } as unknown as HouseholdAccessService,
      { record: jest.fn() } as unknown as ActivityService,
      { notifyHouseholdExcept: jest.fn() } as unknown as NotificationsService,
      ingredients,
    );
    return { tx, service, ingredients };
  };

  it('merges the same ingredient across units into one exact demand', async () => {
    const { tx, service, ingredients } = refreshHarness([
      { name: 'Olive oil', quantityMin: '2', quantityMax: null, unit: 'tbsp', includeInShopping: true },
      { name: 'olive oil', quantityMin: '60', quantityMax: null, unit: 'ml', includeInShopping: true },
      { name: 'Flour', quantityMin: '300', quantityMax: null, unit: 'g', includeInShopping: true },
      { name: 'Flour', quantityMin: '2', quantityMax: null, unit: 'cups', includeInShopping: true },
      { name: 'Salt', quantityMin: null, quantityMax: null, unit: null, includeInShopping: true },
    ]);
    await service.refreshDemand('account-1', 'household-1', 'trip-1');
    const created = tx.shoppingItem.create.mock.calls.map(([args]) => args.data);
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
      expect.objectContaining({ displayName: 'Salt', demand: [], unmeasured: true }),
    ]);
    expect(ingredients.requestProfiles).toHaveBeenCalledWith(['ci-olive oil', 'ci-flour', 'ci-salt']);
  });

  it('merges legacy lines with different statuses into one item that needs a pantry check', async () => {
    const { tx, service } = refreshHarness(
      [{ name: 'Flour', quantityMin: '300', quantityMax: null, unit: 'g', includeInShopping: true }],
      [
        { id: 'old-g', displayName: 'Flour', demand: [], unmeasured: false, status: ShoppingItemStatus.PURCHASED },
        { id: 'old-cup', displayName: 'flour', demand: [], unmeasured: false, status: ShoppingItemStatus.NEED_TO_BUY },
      ],
    );
    await expect(service.refreshDemand('account-1', 'household-1', 'trip-1')).resolves.toEqual([
      { id: 'old-g', displayName: 'Flour' },
    ]);
    expect(tx.shoppingItem.deleteMany).toHaveBeenCalledWith({
      where: { householdId: 'household-1', id: { in: ['old-cup'] } },
    });
    expect(tx.shoppingItem.update).toHaveBeenCalledWith({
      where: { id: 'old-g' },
      data: expect.objectContaining({ status: ShoppingItemStatus.CHECK_AGAIN }),
    });
  });

  it('presents exact demand with a read-time estimate in trip detail', async () => {
    const prisma = {
      shoppingTrip: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'trip-1', status: TripStatus.CONFIRMED, scheduledFor: null, revision: 1,
          createdByAccountId: 'account-1', createdAt: new Date(0), updatedAt: new Date(0),
        }),
      },
      shoppingItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'item-1', displayName: 'Flour', canonicalIngredientId: 'ci-flour',
            demand: [{ dimension: 'MASS', unit: 'g', min: '300', max: '300' }, { dimension: 'VOLUME', unit: 'ml', min: '480', max: '480' }],
            unmeasured: false, status: ShoppingItemStatus.NEED_TO_BUY, revision: 2,
          },
        ]),
      },
      shoppingItemContribution: {
        findMany: jest.fn().mockResolvedValue([
          { shoppingItemId: 'item-1', cookingInstanceId: 'cooking-1', recipeTitle: 'Pancakes', quantityMin: new Prisma.Decimal('2'), quantityMax: null, unit: 'cups' },
        ]),
      },
      pantryAssessment: { findMany: jest.fn().mockResolvedValue([]) },
      canonicalIngredient: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'ci-flour', profileStatus: 'READY', shoppingUnit: 'g', unitEstimates: { ml: '0.53' }, packageSizes: ['500', '1000'] },
        ]),
      },
    };
    const service = new TripsService(
      prisma as unknown as PrismaService,
      { requireActiveMembership: jest.fn() } as unknown as HouseholdAccessService,
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
          approximate: true, amount: '554.4', unit: 'g',
          buy: { count: 1, size: '1000', unit: 'g' }, crossesDimension: true,
        },
        profileStatus: 'READY',
        contributions: [
          { cookingInstanceId: 'cooking-1', recipeTitle: 'Pancakes', quantityMin: '2', quantityMax: null, unit: 'cups' },
        ],
      },
    ]);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `npx jest src/trips/trips.service.spec.ts`
Expected: FAIL (compile errors on removed fields / constructor arity, then assertion failures).

- [ ] **Step 3: Implement in `trips.service.ts`**

Imports to add:
```ts
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { normalizeIngredientName, parseUnit } from '../recipes/units';
import {
  addQuantity,
  DemandEntry,
  exactKnown,
  readDemand,
  reassessPantry,
} from './demand';
import { estimateShopping, IngredientProfileSnapshot } from './shopping-estimate';
```

Replace the `AggregatedItem` type:
```ts
type AggregatedItem = {
  key: string;
  name: string;
  demand: DemandEntry[];
  unmeasured: boolean;
  contributions: Array<{
    cookingInstanceId: string;
    recipeTitle: string;
    quantityMin: string | null;
    quantityMax: string | null;
    unit: string | null;
  }>;
};
```

Constructor: add `private readonly ingredients: IngredientProfileService,` as 5th parameter. `trips.module.ts`: import `IngredientsModule` and add it to `imports`.

Replace `aggregate`:
```ts
  private aggregate(
    instances: Array<{
      id: string;
      recipeSnapshot: Prisma.JsonValue;
      scaledIngredients: Prisma.JsonValue;
    }>,
  ) {
    const grouped = new Map<string, AggregatedItem>();
    for (const instance of instances) {
      const title = this.recipeTitle(instance.recipeSnapshot);
      for (const ingredient of this.ingredients(instance.scaledIngredients)) {
        if (!ingredient.includeInShopping) continue;
        const key = normalizeIngredientName(ingredient.name);
        if (!key) continue;
        const item = grouped.get(key) ?? {
          key,
          name: ingredient.name.trim(),
          demand: [],
          unmeasured: false,
          contributions: [],
        };
        if (ingredient.quantityMin == null) item.unmeasured = true;
        else item.demand = addQuantity(item.demand, ingredient);
        item.contributions.push({
          cookingInstanceId: instance.id,
          recipeTitle: title,
          quantityMin: ingredient.quantityMin,
          quantityMax: ingredient.quantityMax,
          unit: ingredient.unit,
        });
        grouped.set(key, item);
      }
    }
    return [...grouped.values()];
  }
```
Note: the private method `ingredients(value)` (snapshot parser) now collides with the injected `ingredients` service field. Rename the private method to `snapshotIngredients` and update its call site.

In `confirm`, inside the transaction after `const items = this.aggregate(instances);` add `const canonical = await this.ingredients.resolveIngredients(items.map((item) => item.key), tx);`. Replace the `shoppingItem.create` data with:
```ts
          data: {
            householdId,
            shoppingTripId: trip.id,
            displayName: item.name,
            canonicalIngredientId: canonical.get(item.key) ?? null,
            demand: item.demand as Prisma.InputJsonValue,
            unmeasured: item.unmeasured,
            status: ShoppingItemStatus.NEED_TO_BUY,
          },
```
Change the transaction to return `{ trip: updatedTrip, canonicalIds: [...new Set(canonical.values())] }` (assign the existing `tx.shoppingTrip.update(...)` result to `updatedTrip`), destructure it as `const { trip, canonicalIds } = await this.prisma.$transaction(...)`, and immediately after the transaction add `await this.ingredients.requestProfiles(canonicalIds);`.

In `refreshDemand`, replace everything from `const aggregate = this.aggregate(instances);` through the end of the `for (const item of aggregate)` loop with:
```ts
      const aggregate = this.aggregate(instances);
      const canonical = await this.ingredients.resolveIngredients(
        aggregate.map((item) => item.key),
        tx,
      );
      canonicalIds.push(...new Set(canonical.values()));
      const existing = await tx.shoppingItem.findMany({
        where: { householdId, shoppingTripId: trip.id },
      });
      const existingByKey = new Map<string, typeof existing>();
      for (const row of existing) {
        const key = normalizeIngredientName(row.displayName);
        existingByKey.set(key, [...(existingByKey.get(key) ?? []), row]);
      }
      const currentKeys = new Set(aggregate.map((item) => item.key));
      const removed = [
        ...existing.filter(
          (row) => !currentKeys.has(normalizeIngredientName(row.displayName)),
        ),
        ...[...existingByKey.entries()]
          .filter(([key]) => currentKeys.has(key))
          .flatMap(([, rows]) => rows.slice(1)),
      ];
      if (removed.length) {
        await tx.shoppingItemContribution.deleteMany({
          where: {
            householdId,
            shoppingItemId: { in: removed.map((item) => item.id) },
          },
        });
        await tx.shoppingItem.deleteMany({
          where: { householdId, id: { in: removed.map((item) => item.id) } },
        });
      }

      const invalidated: Array<{ id: string; displayName: string }> = [];
      for (const item of aggregate) {
        const priorRows = existingByKey.get(item.key) ?? [];
        const prior = priorRows[0];
        const statusesDiffer =
          new Set(priorRows.map((row) => row.status)).size > 1;
        const data = {
          displayName: item.name,
          canonicalIngredientId: canonical.get(item.key) ?? null,
          demand: item.demand as Prisma.InputJsonValue,
          unmeasured: item.unmeasured,
        };
        const saved = prior
          ? await tx.shoppingItem.update({
              where: { id: prior.id },
              data: {
                ...data,
                ...(statusesDiffer
                  ? { status: ShoppingItemStatus.CHECK_AGAIN }
                  : {}),
                revision: { increment: 1 },
              },
            })
          : await tx.shoppingItem.create({
              data: {
                householdId,
                shoppingTripId: trip.id,
                ...data,
                status: ShoppingItemStatus.NEED_TO_BUY,
              },
            });
        await tx.shoppingItemContribution.deleteMany({
          where: { householdId, shoppingItemId: saved.id },
        });
        if (item.contributions.length) {
          await tx.shoppingItemContribution.createMany({
            data: item.contributions.map((contribution) => ({
              householdId,
              shoppingItemId: saved.id,
              cookingInstanceId: contribution.cookingInstanceId,
              recipeTitle: contribution.recipeTitle,
              quantityMin: contribution.quantityMin
                ? new Prisma.Decimal(contribution.quantityMin)
                : null,
              quantityMax: contribution.quantityMax
                ? new Prisma.Decimal(contribution.quantityMax)
                : null,
              unit: contribution.unit,
            })),
          });
        }
        if (!prior) continue;
        if (statusesDiffer) {
          invalidated.push({ id: saved.id, displayName: saved.displayName });
          continue;
        }
        const assessment = await tx.pantryAssessment.findFirst({
          where: { householdId, shoppingItemId: saved.id },
          orderBy: { createdAt: 'desc' },
        });
        if (assessment?.status !== ShoppingItemStatus.CONFIRMED_AT_HOME)
          continue;
        const nextStatus = reassessPantry(item.demand, {
          knownQuantity: assessment.knownQuantity?.toString() ?? null,
          unit: assessment.unit,
          demandAtConfirmation: readDemand(assessment.demandAtConfirmation),
        });
        if (nextStatus === saved.status) continue;
        await tx.shoppingItem.update({
          where: { id: saved.id },
          data: { status: nextStatus, revision: { increment: 1 } },
        });
        invalidated.push({ id: saved.id, displayName: saved.displayName });
      }
      return invalidated;
```
Declare `const canonicalIds: string[] = [];` before the `$transaction` call, and after the transaction (before the notification loop) add `await this.ingredients.requestProfiles(canonicalIds);`.

In `updateItem`: replace `unit: input.unit?.trim() || item.unit,` with `unit: input.unit?.trim() || this.singleDemandUnit(item.demand),` and replace the `demandAtConfirmation` object with `demandAtConfirmation: readDemand(item.demand) as Prisma.InputJsonValue,`. Replace the method's final `return { … }` with:
```ts
    const [presented] = await this.presentItems(householdId, [item]);
    return presented;
```

Replace the `items: items.map(...)` block in `detail` (and delete its local `contributions` query) with `items: await this.presentItems(householdId, items),`.

Add these private methods and delete `sum`, `itemKey`, `reassessedStatus`, `demandQuantity`, `sameUnit`:
```ts
  private singleDemandUnit(value: Prisma.JsonValue) {
    const demand = readDemand(value);
    return demand.length === 1 ? demand[0].unit : null;
  }

  private async presentItems(
    householdId: string,
    items: Array<{
      id: string;
      displayName: string;
      canonicalIngredientId: string | null;
      demand: Prisma.JsonValue;
      unmeasured: boolean;
      status: ShoppingItemStatus;
      revision: number;
    }>,
  ) {
    const itemIds = items.map((item) => item.id);
    const contributions = await this.prisma.shoppingItemContribution.findMany({
      where: { householdId, shoppingItemId: { in: itemIds } },
      orderBy: { createdAt: 'asc' },
    });
    const partialIds = items
      .filter((item) => item.status === ShoppingItemStatus.PARTIALLY_AVAILABLE)
      .map((item) => item.id);
    const assessments = partialIds.length
      ? await this.prisma.pantryAssessment.findMany({
          where: { householdId, shoppingItemId: { in: partialIds } },
          orderBy: { createdAt: 'desc' },
        })
      : [];
    const canonicalIds = [
      ...new Set(
        items
          .map((item) => item.canonicalIngredientId)
          .filter((id): id is string => !!id),
      ),
    ];
    const profiles = canonicalIds.length
      ? await this.prisma.canonicalIngredient.findMany({
          where: { id: { in: canonicalIds } },
        })
      : [];
    const profileById = new Map(profiles.map((profile) => [profile.id, profile]));
    return items.map((item) => {
      const demand = readDemand(item.demand);
      const profile = item.canonicalIngredientId
        ? profileById.get(item.canonicalIngredientId)
        : undefined;
      const snapshot: IngredientProfileSnapshot | null = profile
        ? {
            profileStatus: profile.profileStatus,
            shoppingUnit: profile.shoppingUnit,
            unitEstimates: profile.unitEstimates,
            packageSizes: profile.packageSizes,
          }
        : null;
      const assessment = assessments.find(
        (candidate) => candidate.shoppingItemId === item.id,
      );
      let alreadyHave: Prisma.Decimal | undefined;
      if (
        assessment?.knownQuantity &&
        demand.length === 1 &&
        snapshot?.shoppingUnit
      ) {
        const shopping = parseUnit(snapshot.shoppingUnit);
        if (
          shopping.dimension === demand[0].dimension &&
          shopping.baseUnit === demand[0].unit
        )
          alreadyHave =
            exactKnown(
              assessment.knownQuantity.toString(),
              assessment.unit,
              demand[0],
            ) ?? undefined;
      }
      return {
        id: item.id,
        displayName: item.displayName,
        status: item.status,
        revision: item.revision,
        demand,
        unmeasured: item.unmeasured,
        estimate: estimateShopping(demand, snapshot, alreadyHave),
        profileStatus: profile?.profileStatus ?? null,
        contributions: contributions
          .filter((contribution) => contribution.shoppingItemId === item.id)
          .map((contribution) => ({
            cookingInstanceId: contribution.cookingInstanceId,
            recipeTitle: contribution.recipeTitle,
            quantityMin: contribution.quantityMin?.toString() ?? null,
            quantityMax: contribution.quantityMax?.toString() ?? null,
            unit: contribution.unit,
          })),
      };
    });
  }
```
Also extend the `snapshotIngredients` guard so a non-null `quantityMin` must be a decimal string: add `&& ((item as SnapshotIngredient).quantityMin === null || /^\d+(?:\.\d+)?$/.test(String((item as SnapshotIngredient).quantityMin)))`.

- [ ] **Step 4: Run tests**

Run: `npx jest src/trips`
Expected: PASS. If a mock lacks a Prisma method the new code calls, add it to the mock (do not change behaviour to fit a mock).

- [ ] **Step 5: Full API check**

Run: `npx tsc --noEmit -p tsconfig.json 2>&1 | grep -E "^src" ; npx jest`
Expected: `tsc` shows only the 3 pre-existing errors in `src/auth/auth.service.spec.ts` and `src/imports/source-url.service.spec.ts`; all Jest suites pass.

- [ ] **Step 6: Format and lint**

Run: `npx prettier --write src/trips/trips.service.ts src/trips/trips.module.ts src/trips/trips.service.spec.ts && npx eslint src/trips/trips.service.ts src/trips/trips.module.ts`
Expected: clean. Leave uncommitted.

---

### Task 7: Client — shared amounts formatting and breakdown on both shopping screens

**Files:**
- Create: `apps/client/lib/features/trips/shopping_amounts.dart`
- Create: `apps/client/lib/features/trips/shopping_item_breakdown.dart`
- Create: `apps/client/test/shopping_amounts_test.dart`
- Create: `apps/client/test/shopping_item_breakdown_test.dart`
- Modify: `apps/client/lib/features/trips/trip_detail_page.dart` (`_ShoppingItemTile`, delete `_quantity`)
- Modify: `apps/client/lib/features/trips/shop_page.dart` (`_ShoppingItemRow`, delete `_quantity`)

**Interfaces:**
- Consumes: item JSON shape from spec §7.4 via `HouseholdCollectionItem.values`.
- Produces:
  - `class DemandAmount { String dimension; String unit; double min; double max; }`
  - `class ShoppingEstimateView { double amount; String unit; int? buyCount; double? buySize; bool crossesDimension; }`
  - `List<DemandAmount> demandFrom(Map<String, Object?> item)`
  - `ShoppingEstimateView? estimateFrom(Map<String, Object?> item)`
  - `String formatAmount(double amount, String unit)`
  - `String formatRange(double min, double max, String unit)`
  - `double roundEstimate(double amount)`
  - `String exactSummary(List<DemandAmount> demand, {required bool unmeasured})`
  - `String estimateSummary(ShoppingEstimateView estimate, {required String status})`
  - `String shoppingItemSummary(Map<String, Object?> item)`
  - `String contributionAmount(Map<Object?, Object?> contribution)`
  - `String? crossDimensionNote(ShoppingEstimateView estimate, String displayName)`
  - `class ShoppingItemBreakdown extends StatelessWidget { const ShoppingItemBreakdown({super.key, required this.item}); final HouseholdCollectionItem item; }`

- [ ] **Step 1: Write failing tests**

`apps/client/test/shopping_amounts_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/trips/shopping_amounts.dart';

void main() {
  group('formatAmount', () {
    test('switches to kg and L at 1000 and trims zeros', () {
      expect(formatAmount(300, 'g'), '300 g');
      expect(formatAmount(1200, 'g'), '1.2 kg');
      expect(formatAmount(1000, 'ml'), '1 L');
      expect(formatAmount(22.5, 'ml'), '22.5 ml');
    });

    test('pluralizes count units', () {
      expect(formatAmount(1, 'head'), '1 head');
      expect(formatAmount(4, 'clove'), '4 cloves');
      expect(formatAmount(2, 'pinch'), '2 pinches');
      expect(formatAmount(0.4, 'head'), '0.4 heads');
    });
  });

  test('formatRange shows both ends only when they differ', () {
    expect(formatRange(200, 200, 'g'), '200 g');
    expect(formatRange(200, 300, 'g'), '200–300 g');
    expect(formatRange(800, 1200, 'g'), '0.8–1.2 kg');
  });

  test('roundEstimate uses size bands', () {
    expect(roundEstimate(0.42), 0.4);
    expect(roundEstimate(23), 25);
    expect(roundEstimate(554.4), 550);
    expect(roundEstimate(1180), 1200);
  });

  group('summaries', () {
    final flour = <String, Object?>{
      'status': 'NEED_TO_BUY',
      'unmeasured': false,
      'demand': [
        {'dimension': 'MASS', 'unit': 'g', 'min': '300', 'max': '300'},
        {'dimension': 'VOLUME', 'unit': 'ml', 'min': '480', 'max': '480'},
      ],
      'estimate': {
        'approximate': true,
        'amount': '554.4',
        'unit': 'g',
        'buy': {'count': 1, 'size': '1000', 'unit': 'g'},
        'crossesDimension': true,
      },
    };

    test('prefers the estimate when present', () {
      expect(shoppingItemSummary(flour), '≈ 550 g · buy 1 × 1 kg');
    });

    test('falls back to exact amounts', () {
      expect(
        shoppingItemSummary({...flour, 'estimate': null}),
        '300 g + 480 ml',
      );
    });

    test('mentions unmeasured amounts', () {
      expect(
        exactSummary(const [], unmeasured: true),
        'Some to taste',
      );
      expect(
        shoppingItemSummary({...flour, 'estimate': null, 'unmeasured': true}),
        '300 g + 480 ml + some to taste',
      );
    });

    test('says what is still needed for partial availability', () {
      expect(
        shoppingItemSummary({...flour, 'status': 'PARTIALLY_AVAILABLE'}),
        'Still need ≈ 550 g · buy 1 × 1 kg',
      );
    });

    test('omits the buy suggestion when there is none', () {
      final estimate = estimateFrom({
        'estimate': {'amount': '80', 'unit': 'g', 'buy': null, 'crossesDimension': false},
      })!;
      expect(estimateSummary(estimate, status: 'NEED_TO_BUY'), '≈ 80 g');
    });
  });

  test('contributionAmount formats original units', () {
    expect(
      contributionAmount({'quantityMin': '2', 'quantityMax': null, 'unit': 'cups'}),
      '2 cups',
    );
    expect(
      contributionAmount({'quantityMin': '1', 'quantityMax': '2', 'unit': 'tbsp'}),
      '1–2 tbsp',
    );
    expect(
      contributionAmount({'quantityMin': null, 'quantityMax': null, 'unit': null}),
      'To taste',
    );
  });

  test('crossDimensionNote only appears for cross-dimension estimates', () {
    final cross = estimateFrom({
      'estimate': {'amount': '554.4', 'unit': 'g', 'buy': null, 'crossesDimension': true},
    })!;
    final exact = estimateFrom({
      'estimate': {'amount': '90', 'unit': 'ml', 'buy': null, 'crossesDimension': false},
    })!;
    expect(
      crossDimensionNote(cross, 'Flour'),
      'Estimate uses a typical weight for flour, so check the pack.',
    );
    expect(crossDimensionNote(exact, 'Olive oil'), isNull);
  });
}
```

`apps/client/test/shopping_item_breakdown_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/trips/shopping_item_breakdown.dart';

void main() {
  testWidgets('shows exact amounts, per-recipe originals, and the estimate note', (
    tester,
  ) async {
    final item = HouseholdCollectionItem({
      'displayName': 'Flour',
      'status': 'NEED_TO_BUY',
      'unmeasured': false,
      'demand': [
        {'dimension': 'MASS', 'unit': 'g', 'min': '300', 'max': '300'},
        {'dimension': 'VOLUME', 'unit': 'ml', 'min': '480', 'max': '480'},
      ],
      'estimate': {
        'amount': '554.4',
        'unit': 'g',
        'buy': {'count': 1, 'size': '1000', 'unit': 'g'},
        'crossesDimension': true,
      },
      'contributions': [
        {'recipeTitle': 'Pancakes', 'quantityMin': '2', 'quantityMax': null, 'unit': 'cups'},
        {'recipeTitle': 'Bread', 'quantityMin': '300', 'quantityMax': null, 'unit': 'g'},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ShoppingItemBreakdown(item: item))),
    );

    expect(find.text('Exact amounts'), findsOneWidget);
    expect(find.text('300 g + 480 ml'), findsOneWidget);
    expect(find.text('Pancakes'), findsOneWidget);
    expect(find.text('2 cups'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('300 g'), findsOneWidget);
    expect(
      find.text('Estimate uses a typical weight for flour, so check the pack.'),
      findsOneWidget,
    );
  });

  testWidgets('explains a missing contribution list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShoppingItemBreakdown(
            item: HouseholdCollectionItem({'demand': [], 'unmeasured': true}),
          ),
        ),
      ),
    );
    expect(find.text('No recipe contribution recorded.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `E:/flutter/bin/flutter.bat test test/shopping_amounts_test.dart test/shopping_item_breakdown_test.dart`
Expected: compilation failure (files missing).

- [ ] **Step 3: Implement `shopping_amounts.dart`**

```dart
/// Display formatting for shopping item amounts. Stored values stay exact on
/// the server; doubles here are for presentation only.
library;

class DemandAmount {
  const DemandAmount({
    required this.dimension,
    required this.unit,
    required this.min,
    required this.max,
  });

  final String dimension;
  final String unit;
  final double min;
  final double max;
}

class ShoppingEstimateView {
  const ShoppingEstimateView({
    required this.amount,
    required this.unit,
    required this.buyCount,
    required this.buySize,
    required this.crossesDimension,
  });

  final double amount;
  final String unit;
  final int? buyCount;
  final double? buySize;
  final bool crossesDimension;
}

double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}');

List<DemandAmount> demandFrom(Map<String, Object?> item) {
  final raw = item['demand'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw.whereType<Map>())
      if (_number(entry['min']) case final min?)
        if (_number(entry['max']) case final max?)
          DemandAmount(
            dimension: '${entry['dimension'] ?? 'COUNT'}',
            unit: '${entry['unit'] ?? 'piece'}',
            min: min,
            max: max,
          ),
  ];
}

ShoppingEstimateView? estimateFrom(Map<String, Object?> item) {
  final raw = item['estimate'];
  if (raw is! Map) return null;
  final amount = _number(raw['amount']);
  final unit = raw['unit'];
  if (amount == null || unit is! String) return null;
  final buy = raw['buy'];
  return ShoppingEstimateView(
    amount: amount,
    unit: unit,
    buyCount: buy is Map ? _number(buy['count'])?.round() : null,
    buySize: buy is Map ? _number(buy['size']) : null,
    crossesDimension: raw['crossesDimension'] == true,
  );
}

String _trim(double value, int decimals) {
  final fixed = value.toStringAsFixed(decimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

String _pluralUnit(String unit, double amount) {
  if (amount == 1 || unit.endsWith('s')) return unit;
  if (RegExp(r'(ch|sh|x)$').hasMatch(unit)) return '${unit}es';
  return '${unit}s';
}

({double factor, String unit, int decimals}) _scale(double max, String unit) {
  if (unit == 'g' && max >= 1000) return (factor: 1000, unit: 'kg', decimals: 2);
  if (unit == 'ml' && max >= 1000) return (factor: 1000, unit: 'L', decimals: 2);
  return (factor: 1, unit: unit, decimals: 1);
}

String formatAmount(double amount, String unit) => formatRange(amount, amount, unit);

String formatRange(double min, double max, String unit) {
  final scale = _scale(max, unit);
  final low = _trim(min / scale.factor, scale.decimals);
  final high = _trim(max / scale.factor, scale.decimals);
  final metric = unit == 'g' || unit == 'ml';
  final label = metric ? scale.unit : _pluralUnit(scale.unit, max);
  return low == high ? '$high $label' : '$low–$high $label';
}

double roundEstimate(double amount) {
  if (amount < 10) return (amount * 10).round() / 10;
  if (amount < 100) return (amount / 5).round() * 5;
  if (amount < 1000) return (amount / 10).round() * 10;
  return (amount / 50).round() * 50;
}

String exactSummary(List<DemandAmount> demand, {required bool unmeasured}) {
  if (demand.isEmpty) return unmeasured ? 'Some to taste' : '';
  final amounts = demand.map((entry) => formatRange(entry.min, entry.max, entry.unit));
  return [...amounts, if (unmeasured) 'some to taste'].join(' + ');
}

String estimateSummary(ShoppingEstimateView estimate, {required String status}) {
  final prefix = status == 'PARTIALLY_AVAILABLE' ? 'Still need ≈ ' : '≈ ';
  final amount = '$prefix${formatAmount(roundEstimate(estimate.amount), estimate.unit)}';
  final count = estimate.buyCount;
  final size = estimate.buySize;
  if (count == null || size == null) return amount;
  return '$amount · buy $count × ${formatAmount(size, estimate.unit)}';
}

String shoppingItemSummary(Map<String, Object?> item) {
  final estimate = estimateFrom(item);
  if (estimate != null) {
    return estimateSummary(estimate, status: '${item['status'] ?? ''}');
  }
  return exactSummary(demandFrom(item), unmeasured: item['unmeasured'] == true);
}

String contributionAmount(Map<Object?, Object?> contribution) {
  final min = _number(contribution['quantityMin']);
  if (min == null) return 'To taste';
  final max = _number(contribution['quantityMax']) ?? min;
  final unit = contribution['unit'];
  final low = _trim(min, 3);
  final high = _trim(max, 3);
  final amount = low == high ? high : '$low–$high';
  return unit is String && unit.trim().isNotEmpty ? '$amount ${unit.trim()}' : amount;
}

String? crossDimensionNote(ShoppingEstimateView estimate, String displayName) {
  if (!estimate.crossesDimension) return null;
  final kind = switch (estimate.unit) {
    'g' => 'weight',
    'ml' => 'volume',
    _ => 'size',
  };
  return 'Estimate uses a typical $kind for ${displayName.toLowerCase()}, so check the pack.';
}
```

- [ ] **Step 4: Implement `shopping_item_breakdown.dart`**

```dart
import 'package:flutter/material.dart';

import '../auth/session_repository.dart';
import 'shopping_amounts.dart';

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Expanded content for a shopping item: exact totals, each recipe's original
/// amount, and a note when the estimate relies on typical conversions.
class ShoppingItemBreakdown extends StatelessWidget {
  const ShoppingItemBreakdown({super.key, required this.item});

  final HouseholdCollectionItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final exact = exactSummary(
      demandFrom(item.values),
      unmeasured: item.values['unmeasured'] == true,
    );
    final contributions = (item.values['contributions'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final estimate = estimateFrom(item.values);
    final note = estimate == null
        ? null
        : crossDimensionNote(estimate, item.string('displayName') ?? 'this item');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exact.isNotEmpty) ...[
          Text('Exact amounts', style: textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(exact, style: _tabular),
          const SizedBox(height: 12),
        ],
        if (contributions.isEmpty)
          const Text('No recipe contribution recorded.')
        else
          for (final contribution in contributions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text('${contribution['recipeTitle'] ?? 'Recipe'}')),
                  const SizedBox(width: 12),
                  Text(contributionAmount(contribution), style: _tabular),
                ],
              ),
            ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}
```
`FontFeature` is exported by `package:flutter/material.dart` (via `dart:ui` re-export in painting). If the analyzer reports it undefined, add `import 'dart:ui' show FontFeature;`.

- [ ] **Step 5: Wire both rows**

In `trip_detail_page.dart` `_ShoppingItemTile.build`:
- Delete the `contributions`/`recipes` locals.
- Subtitle becomes:
```dart
      subtitle: Text(
        [
          shoppingItemSummary(item.values),
          if (status != 'NEED_TO_BUY') presentation.label,
        ].where((part) => part.isNotEmpty).join(' · '),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
```
- `children` becomes:
```dart
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: ShoppingItemBreakdown(item: item),
        ),
      ],
```
- Add imports `import 'shopping_amounts.dart';` and `import 'shopping_item_breakdown.dart';`; delete the top-level `_quantity` function.

In `shop_page.dart` `_ShoppingItemRow.build`: apply the same subtitle change; delete the `contributions` local; `children` becomes the same `Padding` with `EdgeInsets.fromLTRB(56, 0, 24, 20)` wrapping `ShoppingItemBreakdown(item: item)`; add the same two imports; delete the top-level `_quantity` function.

- [ ] **Step 6: Run tests and analyzer**

Run: `E:/flutter/bin/flutter.bat test && E:/flutter/bin/flutter.bat analyze`
Expected: all tests pass; "No issues found!".

- [ ] **Step 7: Format touched files only**

Run: `E:/flutter/bin/dart.bat format lib/features/trips/shopping_amounts.dart lib/features/trips/shopping_item_breakdown.dart lib/features/trips/trip_detail_page.dart lib/features/trips/shop_page.dart test/shopping_amounts_test.dart test/shopping_item_breakdown_test.dart`
Then re-run `E:/flutter/bin/flutter.bat test test/shopping_amounts_test.dart test/shopping_item_breakdown_test.dart` → PASS. Leave uncommitted.

---

### Task 8: Final verification (orchestrator)

**Files:** none created.

- [ ] **Step 1: API suite, types, lint, contract**

Run from `apps/api`:
```bash
npx jest
npx tsc --noEmit -p tsconfig.json 2>&1 | grep -E "^src"
npx eslint src/recipes/units.ts src/recipes/quantity.service.ts src/recipes/recipes.service.ts src/recipes/recipes.module.ts src/trips/demand.ts src/trips/shopping-estimate.ts src/trips/trips.service.ts src/trips/trips.module.ts src/ingredients src/worker.ts
npm run contract:check
```
Expected: all suites pass; only the 3 pre-existing `tsc` errors (auth.service.spec, source-url.service.spec); eslint clean; contract check passes.

- [ ] **Step 2: Client suite**

Run from `apps/client`: `E:/flutter/bin/flutter.bat test && E:/flutter/bin/flutter.bat analyze`
Expected: all pass; no issues.

- [ ] **Step 3: DESIGN.md check**

Confirm in the diff of `trip_detail_page.dart` and `shop_page.dart`: no new colors, no new containers/cards, no raw enums, tabular figures on amounts, curly apostrophes in any new copy.

- [ ] **Step 4: Spec coverage walk**

Tick each spec section against the implementation: §5 (schema), §6.1–6.4, §7.1–7.4, §8, §9, §10 rows, §11 tests. Report any gap to the user.

- [ ] **Step 5: Hand to user for manual (billed) check**

User restarts API (`npm run start:dev`) and worker (`npm run start:worker`), then: save a recipe with flour in cups, olive oil in tbsp, garlic cloves → worker logs `Ingredient profile batch … ready: …`; plan it plus a recipe using flour in grams into a trip; confirm the trip; open it → one Flour line with `≈ … · buy …`, expanded breakdown shows both recipes' original amounts.
