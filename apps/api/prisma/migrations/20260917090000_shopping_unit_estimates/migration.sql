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
    WHEN regexp_replace(trim(COALESCE(s."unit", '')), '\.$', '') IN ('T', 't') THEN regexp_replace(trim(s."unit"), '\.$', '')
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
