# Shopping unit estimates — design

- **Date:** 2026-09-16
- **Status:** Approved in conversation (option B, option 1); awaiting written-spec review
- **Scope:** API (`apps/api`), Flutter client trip screen (`apps/client`), one Prisma migration

## 1. Problem

Shopping items are grouped by ingredient name **plus exact unit text** (`TripsService.aggregate`, key `name|unit`). The same ingredient in different units becomes separate lines ("olive oil · 2 tbsp", "olive oil · 60 ml"), with no conversion and no guidance on what to buy. `CanonicalIngredient`, `IngredientAlias`, and `RecipeIngredient.normalizedUnit` exist in the schema but are never read or written. `QuantityService.compatible` and `TripsService.sameUnit` compare unit strings literally.

Additionally, `TripsService.sum` returns `null` when either side is `null`, so one unquantified contribution ("salt to taste") erases the whole total for that item.

`QuantityService.format` strips trailing zeros from whole numbers (`/\.?(0+)$/`), so scaling 100 g from 2 to 4 servings stores `"2"` instead of `"200"`. Verified 2026-09-17; no stored cooking instances exist yet, so no data repair is needed. Fixed as part of this work.

## 2. Goals

1. One shopping line per ingredient per trip, with one status.
2. Exact totals merged within a measurement dimension (tbsp + ml → ml; g + kg → g).
3. An approximate store-buying suggestion per item ("≈ 550 g · buy 1 × 1 kg"), derived from a per-ingredient profile generated once by Gemini.
4. Tapping an item shows exact totals and each recipe's original amount.

## 3. Non-goals

- Merging distinct ingredient names or varieties ("olive oil" vs "extra virgin olive oil"). Project plan §8 requires an explicit user merge; that feature is out of scope. `IngredientAlias` stays unused.
- User editing of ingredient profiles.
- Realtime push of newly completed profiles to open trip screens.
- Changing the leading status icon on shopping rows (pre-existing DESIGN.md mismatch).

## 4. Governing rules (from `context/PANTRYPAL_PROJECT_PLAN.md` §8, §10.2)

- **Estimate-only AI data.** AI-provided conversions (volume↔mass, count↔anything) are used **only** for the buying suggestion, always rendered with `≈`. They never alter stored demand, never merge exact totals, and are never used by pantry logic. This preserves "do not convert volume to mass without a verified ingredient-specific density rule".
- **No invented amounts.** Any demand entry that cannot be converted means no estimate at all — never a partial total.
- Semantic count units (clove, can, bunch, head, piece…) never merge with each other exactly.
- Original recipe amounts remain visible per contribution.

## 5. Data model

### 5.1 `CanonicalIngredient` (global, not household-scoped)

One row per normalized ingredient name. `canonicalName` holds the normalized name (§6.2).

| Column | Type | Notes |
|---|---|---|
| `dimension` | existing `String?` | Now populated: `MASS` \| `VOLUME` \| `COUNT` (shopping dimension) |
| `profileStatus` | new enum `IngredientProfileStatus` | `PENDING` (default) \| `READY` \| `FAILED` |
| `shoppingUnit` | new `String?` | `g` for MASS, `ml` for VOLUME, a singular count noun for COUNT (e.g. `head`, `piece`) |
| `unitEstimates` | new `Json?` | Object: key = base unit (`g`, `ml`) or count unit; value = decimal string, amount of `shoppingUnit` per 1 key unit. E.g. flour `{"ml":"0.53"}`, garlic `{"clove":"0.1","g":"0.02"}` |
| `packageSizes` | new `Json?` | Array of decimal strings in `shoppingUnit`, ascending, e.g. `["500","1000"]` |
| `profileModel` | new `String?` | Model id that produced the profile |
| `profiledAt` | new `DateTime?` | |
| `updatedAt` | new `DateTime @updatedAt` | |

### 5.2 `RecipeIngredient`

On review save, populate the existing `canonicalIngredientId` and `normalizedUnit` (the parsed unit token from §6.1, or `null` when no unit).

### 5.3 `ShoppingItem`

- `canonicalIngredientId` (existing) becomes always set by aggregation (nullable column retained for migrated rows).
- **Add** `demand Json` (default `[]`): array of exact demand entries:
  ```json
  [{"dimension":"MASS","unit":"g","min":"300","max":"300"},
   {"dimension":"VOLUME","unit":"ml","min":"480","max":"480"},
   {"dimension":"COUNT","unit":"clove","min":"4","max":"4"}]
  ```
  At most one MASS entry (unit `g`), one VOLUME entry (unit `ml`), and one COUNT entry per distinct count unit. `min`/`max` are decimal strings; `max` equals `min` for exact amounts.
- **Add** `unmeasured Boolean @default(false)`: at least one contribution had no quantity.
- **Remove** `quantityMin`, `quantityMax`, `unit` (after backfill, §9).

### 5.4 Unchanged

- `ShoppingItemContribution` keeps each recipe's original `quantityMin`/`quantityMax`/`unit`.
- `PantryAssessment.demandAtConfirmation` (already `Json`) stores the §5.3 `demand` array going forward. `knownQuantity` and `unit` columns unchanged.

## 6. Server components

### 6.1 Unit parsing — deterministic (`apps/api/src/recipes/units.ts`)

Pure functions (no Nest provider, avoiding a recipes↔ingredients module cycle).

`parseUnit(unit: string | null | undefined): { dimension: 'MASS' | 'VOLUME' | 'COUNT'; baseUnit: string; factor: Prisma.Decimal; token: string }`, plus `formatDecimal(value)` (6 dp, fractional trailing zeros trimmed) shared by `QuantityService`.

- Trim; single-letter tokens are case-sensitive (`T` → `tbsp`, `t` → `tsp`); all else lowercased, trailing period removed.
- MASS (base `g`): `g`/`gram`/`grams` 1; `kg`/`kilogram(s)` 1000; `mg` 0.001; `oz`/`ounce(s)` 28.349523125; `lb`/`lbs`/`pound(s)` 453.59237.
- VOLUME (base `ml`): `ml`/`milliliter(s)`/`millilitre(s)` 1; `l`/`liter(s)`/`litre(s)` 1000; `tsp`/`teaspoon(s)` 5; `tbsp`/`tablespoon(s)` 15; `cup(s)` 240; `fl oz`/`fluid ounce(s)` 29.5735; `pint(s)` 473.176; `quart(s)` 946.353; `gallon(s)` 3785.41.
- A token matching no alias is retried with one trailing `s` removed before falling back to COUNT (`kgs` → `kg`, `tbsps` → `tbsp`, `mls` → `ml`).
- COUNT: any other token, singularized by simple rules (`cloves`→`clove`, `leaves`→`leaf`, `tomatoes`→`tomato`); `null`/empty → `piece`, factor 1. Unknown tokens are never mapped to mass or volume.
- Replaces `QuantityService.compatible` (removed) and `TripsService.sameUnit`.

### 6.2 Ingredient name normalization

`normalizeIngredientName(name)`: trim, collapse internal whitespace, lowercase, singularize the final word with the same rules as §6.1. Used for `CanonicalIngredient.canonicalName` lookup/creation and shopping item grouping.

### 6.3 `IngredientProfileService` (`apps/api/src/ingredients/`)

**Resolve** (`resolveIngredients(names)`): normalize (§6.2), dedupe, drop empty names and sort; then `createMany({ skipDuplicates: true })` followed by `findMany` by `canonicalName` on the shared (non-transactional) Prisma client, never inside a household transaction, so concurrent households never wait on each other's locks. An orphan row left by a later rolled-back transaction is harmless.

**Enqueue** (`requestProfiles(canonicalIds)`), called without awaiting (it never throws; failures are only logged) after the `RecipesService.saveReview` transaction commits and after the `TripsService.confirm` / `refreshDemand` transactions commit:
- If `GEMINI_API_KEY` is absent, return without enqueueing.
- Collect rows with status `PENDING`, or `FAILED` with `updatedAt` older than 24 hours (`FAILED_RETRY_COOLDOWN_MS`); only those FAILED rows are reset to PENDING.
- Enqueue one job per chunk of at most 25 ids on BullMQ queue `ingredient-profiles` with data `{ canonicalIngredientIds }` (retry: 3 attempts, exponential backoff). `jobId` is `profiles-<sorted ids joined by ','>` (a SHA-1 hex digest of that string when longer than 200 characters; BullMQ rejects custom ids containing `:`), with `removeOnComplete`/`removeOnFail` true, so an identical batch is not queued twice while pending.

**Process** (worker, `worker.ts` registers a second `Worker`):
- Load the job's rows still `PENDING`; exit if none (idempotent).
- One Gemini `generateContent` call (model `GEMINI_MODEL`, same request pattern as `GeminiRecipeAnalysisProvider`, `responseMimeType: application/json`, `responseJsonSchema`). The names are passed as a JSON array introduced as data to describe, not instructions to follow. The prompt asks for shoppingUnit `piece` for COUNT items sold whole (head, bunch, can etc. only when that is how the item is sold) and always a `piece` unit estimate meaning one whole item as recipes count it (e.g. "2 onions"). Response: array of `{ name, dimension, shoppingUnit, unitEstimates: [{unit, amount}], packageSizes: [number] }`.
- **Validation per entry:** `name`, normalized with §6.2, matches a requested row; `dimension` ∈ MASS/VOLUME/COUNT; `shoppingUnit` is `g` for MASS, `ml` for VOLUME, a non-empty word for COUNT; every estimate amount and package size is a finite positive number < 1,000,000; estimate `unit` parses via `UnitService` (MASS/VOLUME estimate keys are stored under their base unit with the amount divided by the parse factor). Invalid estimates/package sizes are dropped individually; an invalid `dimension`/`shoppingUnit` rejects the entry.
- Valid entries → `READY` with fields populated. Requested rows with no valid entry → `FAILED`.
- **HTTP handling:** 429, 5xx, timeouts → throw (BullMQ retries); after final attempt rows become `FAILED`. Other 4xx → rows `FAILED` immediately, no retry, provider error message logged.
- Log: `Ingredient profile batch <jobId> ready: <n>, failed: <m> [<name>: <reason>, …]`.

### 6.4 Shopping estimate — pure (`apps/api/src/trips/shopping-estimate.ts`)

`estimateShopping(demand, profile | null, alreadyHave?): { approximate: true; amount: string; unit: string; buy: { count: number; size: string; unit: string } | null; crossesDimension: boolean; remainderApplied: boolean } | null`

- Returns `null` if profile is missing or not `READY`, or `demand` is empty.
- For each entry: same dimension as profile and (for COUNT) same unit → convert exactly to `shoppingUnit`; otherwise look up `unitEstimates[entry.unit]`. Any unconvertible entry → `null`.
- Amount uses entry `max`. Sum → `amount` (6 dp, trailing zeros trimmed). `crossesDimension` is true when any entry used `unitEstimates`.
- `buy`: smallest package ≥ amount → `{count: 1}`; else `ceil(amount / largest)` × largest; `null` when no package sizes.
- Accepts an optional `alreadyHave` exact amount in the shopping unit (partial availability, §7.3) that is subtracted before package selection; negative results clamp to zero. `remainderApplied` is true only when `alreadyHave` was provided.

## 7. Behaviour

### 7.1 Aggregation (`TripsService.aggregate`, used by `confirm` and `refreshDemand`)

- Group key: canonical ingredient id (via §6.2 name normalization).
- Per contribution with a quantity: parse unit (§6.1), convert `min` and `max ?? min` to base unit, add into the matching demand entry (`min` sums mins, `max` sums maxes).
- Contribution with `quantityMin` null → no demand change; item `unmeasured = true`. (Replaces the current null-propagating `sum`.)
- Contributions keep original amounts/units.

### 7.2 Rebuild (`refreshDemand`)

- Match existing items by normalized `displayName` (§6.2). Aggregation always sets `displayName` from a contribution name, so its normalization equals the canonical name; this covers migrated rows without `canonicalIngredientId` too. Additional rows sharing a key are deleted (with their contributions) after their statuses are compared.
- Status carries over as today. When several existing items map to one new item and their statuses differ → `CHECK_AGAIN`.

### 7.3 Pantry assessment (`updateItem`, `reassessedStatus`)

- `knownQuantity` + `unit` parsed with `UnitService`; `demandAtConfirmation` stores the item's `demand` array. Legacy `{quantityMin, quantityMax, unit}` objects are read by converting them to a one-entry demand.
- **Demand increased** = any entry's `max` grew, or a (dimension, unit) entry appeared that was not present.
- Not increased → `CONFIRMED_AT_HOME` (unchanged rule).
- Increased → compare exactly: if `demand` has exactly one entry and the known quantity has the same dimension (and same count unit for COUNT): known ≥ demand `max` → `CONFIRMED_AT_HOME`; known < demand → `PARTIALLY_AVAILABLE`. All other cases (no known quantity, multiple entries, dimension mismatch) → `CHECK_AGAIN`.
- For `PARTIALLY_AVAILABLE` items, the response estimate passes the exact known amount as `alreadyHave` when it converts exactly to the profile's `shoppingUnit`; otherwise the estimate covers full demand.

### 7.4 Trip detail and item update responses

Per item:
```json
{
  "id": "…", "displayName": "Flour", "status": "NEED_TO_BUY", "revision": 3,
  "demand": [{"dimension":"MASS","unit":"g","min":"300","max":"300"},
             {"dimension":"VOLUME","unit":"ml","min":"480","max":"480"}],
  "unmeasured": false,
  "estimate": {"approximate": true, "amount": "554.4", "unit": "g",
               "buy": {"count": 1, "size": "1000", "unit": "g"},
               "crossesDimension": true, "remainderApplied": false},
  "profileStatus": "READY",
  "contributions": [{"cookingInstanceId":"…","recipeTitle":"Pancakes",
                     "quantityMin":"2","quantityMax":null,"unit":"cup"}]
}
```
- `quantityMin`, `quantityMax`, `unit` are removed from the item object.
- Estimates are computed at read time; nothing is persisted.
- `profileStatus` is `null` when the item has no canonical ingredient.
- No new realtime event.

## 8. Client (`apps/client/lib/features/trips/`)

Both item rows — `_ShoppingItemTile` in `trip_detail_page.dart` and `_ShoppingItemRow` in `shop_page.dart` — use the shared helpers below; both lose their local `_quantity()`.

### 8.1 `shopping_amounts.dart` (pure)

- `formatAmount(decimalString, unit)`: `g` ≥ 1000 → `kg`; `ml` ≥ 1000 → `L`; trims trailing zeros; max 2 decimals for kg/L.
- `roundEstimate(amount, unit)`: for `g`/`ml` only: < 10 → 1 decimal; < 100 → nearest 5; < 1000 → nearest 10; ≥ 1000 → nearest 50 (before kg/L formatting). Count units always round to 1 decimal (`≈ 12 pieces` stays 12).
- `exactSummary(demand, unmeasured)`: entries joined with ` + `, then ` + some to taste` when `unmeasured` (alone: `Some to taste`).
- `estimateSummary(estimate, status)`: `≈ <rounded> · buy <n> × <size>`; prefix `Still need ` only for `PARTIALLY_AVAILABLE` when `estimate.remainderApplied` is true (otherwise the estimate covers full demand and shows plain `≈`); omits `· buy …` when `buy` is null.

### 8.2 Shared row content (`shopping_item_breakdown.dart`, used by `_ShoppingItemTile` and `_ShoppingItemRow`)

- Collapsed subtitle: `estimateSummary` when `estimate` present, else `exactSummary`; non-default status label appended as today.
- Expanded content, in order: "Exact amounts" + `exactSummary`; one line per contribution: recipe title + original amount/unit; when `estimate.crossesDimension`, a note chosen by the estimate unit's dimension — MASS: "Estimate uses a typical weight for <ingredient>, so check the pack."; VOLUME: "Estimate uses a typical volume for <ingredient>, so check the pack."; COUNT: "Estimate uses a typical size for <ingredient>, so check the pack." `<ingredient>` is the item's display name in lowercase.
- Amount text uses tabular figures (`FontFeature.tabularFigures()`).
- Remove `_quantity()` and all reads of item `quantityMin`/`quantityMax`/`unit`.
- No new colors or components (DESIGN.md).

## 9. Migration

Single Prisma migration:
1. Create enum `IngredientProfileStatus`; add §5.1 columns; add `ShoppingItem.demand` (`jsonb` default `'[]'`) and `unmeasured`.
2. SQL backfill for every `ShoppingItem`:
   - `quantityMin` null → `demand = '[]'`, `unmeasured = true`.
   - Recognized unit (lowercased/trimmed match against the §6.1 alias list, embedded in the migration as a `VALUES` table) → one entry with converted base-unit `min`/`max`. The embedded list is a one-time snapshot of §6.1; a test asserts it matches `UnitService` at migration time. Single-letter `T`/`t` are matched case-sensitively as in §6.1.
   - Unrecognized or null unit → one COUNT entry with the lowercased original unit (or `piece`), values unconverted.
3. Drop `ShoppingItem.quantityMin`, `quantityMax`, `unit`.

Completed and cancelled trips keep converted history. Active trips merge same-ingredient lines on their next `refreshDemand` (§7.2).

## 10. Error handling

| Case | Behaviour |
|---|---|
| No `GEMINI_API_KEY` | No jobs; profiles stay `PENDING`; exact amounts only. Worker logs `Ingredient profiles disabled: GEMINI_API_KEY is not set.` once at startup. |
| Gemini 429 / 5xx / timeout | Retry ×3 with backoff; then rows `FAILED`; re-enqueued on a later recipe save or trip confirm/rebuild once the 24-hour cooldown (by `updatedAt`) has passed. |
| Gemini other 4xx | Rows `FAILED` immediately; provider message logged; same 24-hour re-request cooldown. |
| Invalid AI entry | Dropped per field or per entry (§6.3); unmatched rows `FAILED` (same 24-hour cooldown). |
| Queue / Redis unavailable | Profile request logged as a warning; the save, confirm or rebuild still succeeds. Worker logs failed profile batches. |
| Unrecognized recipe unit | Own COUNT unit; never mapped to mass/volume. |
| Unconvertible demand entry | `estimate: null`; exact amounts shown. |
| Merge of differing statuses | `CHECK_AGAIN`. |
| Profile completes while list is open | Visible on next load. |

## 11. Testing

**API (Jest)**
- `unit.service.spec.ts`: every alias; `T` vs `t`; factors; singularization; unknown → COUNT; null → `piece`.
- Name normalization: whitespace, case, plural final word.
- `trips.service.spec.ts` aggregation: tbsp + ml merge; g + cup → two entries; clove vs head separate; ranges; unmeasured flag; unmeasured no longer nulls totals; differing statuses → `CHECK_AGAIN`.
- Pantry reassessment: not increased; increased + covered; increased + partial; multi-entry → `CHECK_AGAIN`; dimension mismatch → `CHECK_AGAIN`; legacy `demandAtConfirmation` shape.
- `shopping-estimate.service.spec.ts`: exact path; estimate path with `crossesDimension`; any unconvertible entry → null; not-READY → null; single/multi package; no packages; `alreadyHave` subtraction and clamp.
- `ingredient-profile.service.spec.ts` (mocked fetch): validation drops; PENDING-only guard; 4xx vs 429 handling; no-key behaviour; partial batch success.
- Migration backfill: SQL run against local Postgres test rows (recognized, unrecognized, null unit, null quantity).
- `npm run contract:check` passes. The trip detail response stays untyped in OpenAPI, so no contract regeneration is expected; if the check reports drift, regenerate and commit alongside the change.

**Client (flutter_test)**
- `shopping_amounts_test.dart`: rounding bands; kg/L switching; `Some to taste` variants; `Still need` prefix; missing `buy`.
- Widget test for the item row: estimate collapsed; exact + per-recipe lines expanded; cross-dimension note shown only when flagged.

**Manual (billed, not automated)**
- Save a recipe with flour in cups, olive oil in tbsp, and garlic cloves; confirm the worker logs a READY batch; plan it into a trip alongside a recipe using flour in grams; verify one flour line with `≈` estimate and correct breakdown.
