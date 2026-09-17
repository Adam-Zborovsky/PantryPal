# Trip Assignment, 3-Week Plan Strip, and Recipe View — Spec + Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Meals can always be attached to a shopping trip; the Plan day strip swipes across three weeks; recipes opened from the Recipes tab show a compact, layered-collapsible view with inline edits and trip/meal actions, while imports keep the existing review screen.

**Tech Stack:** NestJS 11 + Prisma 6 (apps/api), Flutter + Riverpod (apps/client), Jest, flutter_test.

**Spec:** this document (sections 1–3 are the spec; section 5 is the plan).

## 1. Problem (verified 2026-09-17 against local data)

- Automatic trip assignment (`CookingService.shoppingTripId`, `apps/api/src/cooking/cooking.service.ts:360`) runs only when a meal is created, choosing the latest CONFIRMED trip with `scheduledFor <= cookingDate`.
- `TripsService.recalculateAutomaticAssignments` (`trips.service.ts:572`) only re-evaluates meals already on the trip whose date changed; `confirm` never adopts unassigned meals.
- There is no endpoint or UI to attach an existing meal to a trip, although `context/PANTRYPAL_PROJECT_PLAN.md` §9.2 requires "Allow any member to override or clear it" and "Manual assignments are never silently moved".
- Observed: trip confirmed for 2026-09-19 after its date was edited; meal "Creamy Garlic Lemon Pasta" (cook 2026-09-21) stays unassigned; "Creamy Garlic Pasta" (cook 2026-09-17) can never auto-assign.
- The Plan strip (`plan_page.dart` `_DateStrip`) shows only 7 days from today.
- Recipes tab tiles open `RecipeReviewPage`, a full form of input fields.

## 2. Decisions (approved by user)

1. **Adopt on confirm.** When a trip is confirmed, SCHEDULED meals with `shoppingTripId = null`, `assignmentMode = AUTOMATIC`, and a `cookingDate >= trip.scheduledFor` are attached to it if it is the latest CONFIRMED trip (counting this trip as confirmed) with `scheduledFor <= cookingDate`. Adoption happens inside `confirm`'s transaction before items are aggregated, and upserts `TripRecipeAssignment` (AUTOMATIC).
2. **Manual assignment endpoint.** `PATCH /households/:householdId/cooking/:cookingInstanceId` body `{ shoppingTripId: string | null }`. Setting a trip requires a PROPOSED/CONFIRMED/IN_PROGRESS trip in the household (404 otherwise); the meal must be SCHEDULED (409 otherwise). Result: `shoppingTripId` updated, `assignmentMode = MANUAL` (also when clearing, so automatic rules never re-adopt it), `revision` incremented, `TripRecipeAssignment` removed from the old trip and upserted (MANUAL) for the new one, `refreshDemand` run for the old and new trip ids (it no-ops for non-active trips), activity `cooking.trip_changed` recorded the same way other cooking actions are recorded (realtime `cooking.changed` follows the existing activity path). Response: the presented cooking instance (same shape as list items). Servings changes are out of scope (would require re-scaling the snapshot).
3. **Late trip warning.** Pickers list all open trips (PROPOSED/CONFIRMED/IN_PROGRESS). A trip dated after the meal's cooking date shows "After this meal" in amber and can still be chosen.
4. **Plan strip.** 21 days starting today, shown as 3 swipeable pages of 7 (`PageView`), with a label above: "This week", "Next week", "In 2 weeks", and page dots. Selecting a day works as today; swiping does not change the selected day. Keyboard/a11y: each page keeps the existing `Semantics` cells; add previous/next icon buttons beside the label for non-swipe users.
5. **Recipe view** (new `RecipeDetailPage`) opened from Recipes tab tiles; the import card and any "review" flow keep `RecipeReviewPage`.
6. **Design path:** composed skills — DESIGN.md tokens; better-layout (space-based grouping, stable action zone, visible disclosure cues); flutter-animations (expand/collapse with ease-out, honouring `MediaQuery.disableAnimationsOf`); better-writing (labels).

## 3. Recipe view spec

Data: `sessionRepository.recipeReview(recipeId)` (existing GET) and `saveRecipeReview` (existing PUT, creates a new version; 409 → "This recipe changed elsewhere. Refresh to see the latest version.").

Layout (single scroll, max width 760 like Plan):
1. **Header** (not a card): title (Fraunces headline), line "Serves N" (or "Servings not set"), readiness `StickerChip` using `humanStatusLabel(readiness)` and the existing readiness colours (green for SHOPPING_READY/COOK_READY, amber otherwise).
2. **Action zone** directly under the header, always visible without scrolling on a phone: two buttons in a wrapping row — primary `FilledButton` "Add to shopping trip", secondary `OutlinedButton` "Plan a meal". 12px gap; they wrap on narrow widths.
3. **Ingredients section** — one card, collapsible (expanded by default), header row "Ingredients" + count + chevron. Rows inside are separated by `line` hairlines (no nested cards, no per-row leading icons). Each row collapsed: amount + unit (tabular figures) then name, and preparation note in muted text if present; a trailing chevron indicates it expands. Expanded row reveals edit fields: Amount (min), Up to (max, optional), Unit, Name, Note, and a "Add to shopping list" switch (`includeInShopping`). Only one ingredient expanded at a time is NOT required; multiple may be open.
4. **Steps section** — one card, collapsible (expanded by default), header "Steps" + count. Each step collapsed shows its number and the first line (ellipsis); expanding shows the full text and a multiline edit field.
5. **Unsaved changes bar** — when any field differs from the loaded recipe, a sticky bottom bar (inside safe area) shows "Unsaved changes" + "Discard" (text button) + "Save" (filled). Saving calls `saveRecipeReview`, shows "Recipe saved." and reloads; the bar disappears. Navigating back with unsaved changes asks "Discard your changes?" (Keep editing / Discard).
6. **Add to shopping trip sheet**: trip picker (radio list of open trips from `shoppingTrips()`, label = formatted scheduled date or "Unscheduled trip" + status), servings field (defaults to the recipe's original servings or 2, positive decimal validation), button "Add to trip". Calls `createCookingInstance(recipeId, targetServings, shoppingTripId)` with no cooking date. No open trips → message "No open shopping trips. Create one in Shop." Blocks with "Set the recipe's servings before adding it to a trip." when original servings is empty (API requires it).
7. **Plan a meal sheet**: date picker limited to today…today+20 (matches the Plan strip), servings field, button "Add meal"; calls `createCookingInstance` with the cooking date at 18:00 local (same as Plan page). Same servings guard as above.
8. States: loading spinner; load error with "Try again"; empty ingredients/steps text "No ingredients yet." / "No steps yet.".
9. Motion: section and row expand/collapse via `AnimatedSize`/`AnimatedCrossFade` (≈200ms, `Curves.easeOutCubic`), chevron rotation; zero duration when `MediaQuery.disableAnimationsOf(context)` is true.

## 4. Global Constraints

- **No git commits** (user rule). Leave changes uncommitted.
- Never run `contract:check`/`contract:generate`/`client:generate`, `prisma migrate`/`db push`, dev servers, or real Gemini calls. No schema changes are needed.
- Format only files you touched (`npx prettier --write <files>`, `E:/flutter/bin/dart.bat format <files>`); never whole directories. Run `flutter analyze` after formatting.
- Lint touched API source files clean (`npx eslint <files>`).
- DESIGN.md: cream canvas, white cards with 2px ink border, one card tier (no nested cards), `line` hairlines inside cards, status stickers for state, Fraunces headings / Work Sans body, tabular figures for amounts, ease-out motion only, butter primary buttons as themed, no raw enums in UI, curly apostrophe `’` in copy.
- API commands from `apps/api`; client commands from `apps/client` with `E:/flutter/bin/flutter.bat`.

## 5. Tasks

### Task 1 (API): adopt meals on confirm + manual trip assignment endpoint
**Files:** `apps/api/src/trips/trips.service.ts` (+spec), `apps/api/src/cooking/cooking.service.ts`, `cooking.controller.ts`, `cooking.dto.ts` (+`cooking.service.spec.ts`).
**Produces:** `PATCH /households/:householdId/cooking/:cookingInstanceId` with `UpdateCookingTripDto { shoppingTripId: string | null }` (`@ValidateIf(o => o.shoppingTripId !== null) @IsString() @IsNotEmpty()`, `@ApiProperty({ nullable: true, type: String })`); `CookingService.assignTrip(accountId, householdId, cookingInstanceId, shoppingTripId | null)` returning the presented instance.
- [ ] Tests first (trips.service.spec.ts): `confirm` adopts an unassigned AUTOMATIC SCHEDULED meal dated on/after the trip; does not adopt MANUAL meals, meals dated before the trip, or meals for which another CONFIRMED trip is later but still `<= cookingDate`; adopted meals are included in the aggregated items and get a `TripRecipeAssignment` upsert.
- [ ] Tests first (cooking.service.spec.ts): assign sets trip + MANUAL + revision increment, deletes old assignment, upserts new, calls `refreshDemand` for old and new trip ids; clearing sets null + MANUAL and refreshes only the old trip; non-open trip → NotFoundException; non-SCHEDULED meal → ConflictException; unknown meal → NotFoundException.
- [ ] Implement; keep existing behaviour and tests passing. Follow the existing `CookingService` patterns for membership checks, activity recording, and presentation. Check how `CookingService` reaches `TripsService` today (`this.trips?.refreshDemand`) and reuse it.
- [ ] Verify: `npx jest` (whole suite), `npx tsc --noEmit -p tsconfig.json 2>&1 | grep -E "^src"` (only the 3 pre-existing errors), eslint on touched source files.

### Task 2 (client): meal trip picker + 3-week swipeable strip
**Files:** `apps/client/lib/features/planning/plan_page.dart`, `apps/client/lib/features/auth/session_repository.dart` (add method), new `apps/client/lib/features/shared/trip_picker.dart`, tests `apps/client/test/plan_strip_test.dart`, `apps/client/test/trip_picker_test.dart`.
**Consumes:** Task 1 endpoint. **Produces:** `SessionRepository.assignCookingTrip({required String cookingInstanceId, required String? shoppingTripId}) → Future<void>` (PATCH `/cooking/:id`); reusable `TripPicker` widget: `TripPicker({required List<HouseholdCollectionItem> trips, required String? selectedTripId, required DateTime? mealDate, required ValueChanged<String?> onChanged, bool allowNone = false})` rendering radio options with the formatted date/"Unscheduled trip", status label, and the amber "After this meal" note when trip date > meal date (compare calendar dates); plus pure `bool tripIsAfterMeal(DateTime? tripDate, DateTime? mealDate)`.
- [ ] Tests first: `tripIsAfterMeal` cases (same day → false, later day → true, nulls → false); TripPicker shows "After this meal" only for later trips and reports selection; plan strip shows 7 day cells initially with label "This week", swiping (or tapping next) shows "Next week" and the 8th day, 3 pages max, selecting a day on page 2 updates the day heading.
- [ ] Meal detail sheet: replace the static "Shopping trip" row with the current trip (formatted) or "Needs a shopping trip", plus a "Change trip" action opening a sheet with `TripPicker` (`allowNone: true` → "No shopping trip") and "Save"; on success invalidate `planProvider` and `householdCollectionProvider('Shop')`, snackbar "Shopping trip updated."; errors → "Could not update the shopping trip. Try again.". Only for SCHEDULED meals.
- [ ] Plan strip: 21 days, `PageView` of 3 pages × 7 cells (reuse `_DateCell`), header row with week label, previous/next `IconButton`s (tooltips "Previous week"/"Next week", disabled at ends) and page dots; keep `_selectedDay` as index 0–20.
- [ ] Verify: `flutter test`, `flutter analyze` clean after formatting touched files.

### Task 3 (client): RecipeDetailPage + Recipes tab navigation
**Files:** new `apps/client/lib/features/recipes/recipe_detail_page.dart` (split sheets into `recipe_actions.dart` if the page exceeds ~500 lines), `apps/client/lib/features/home/app_shell.dart` (Recipes tile opens `RecipeDetailPage`; import card still opens `RecipeReviewPage`), tests `apps/client/test/recipe_detail_page_test.dart`.
**Consumes:** `TripPicker`, `tripIsAfterMeal` (Task 2), existing `recipeReview`, `saveRecipeReview`, `shoppingTrips`, `createCookingInstance`, `humanStatusLabel`, `StickerChip`, `PantryPalTheme`.
- [ ] Tests first (fake `SessionRepository` subclass like `test/recipe_review_page_test.dart`): renders title, readiness sticker, both action buttons above the Ingredients section; ingredients collapsed rows show "2 cups" and the name without TextFields; tapping a row reveals its edit fields; collapsing the Ingredients section hides rows; editing a field shows the "Unsaved changes" bar and Save calls `saveRecipeReview` with the edited value then hides the bar; Discard restores; Add to shopping trip sheet lists trips and calls `createCookingInstance` with the chosen trip id and no cooking date; servings guard message when original servings empty.
- [ ] Implement per spec §3 using the composed design skills listed in §2.6 (load `better-layout`, `flutter-animations`, `better-writing` via the Skill tool if available).
- [ ] Recipes tab: tile opens `RecipeDetailPage`; on return invalidate `householdCollectionProvider('Recipes')` if a save happened (page pops with `true` when changes were saved at least once, otherwise false).
- [ ] Verify: `flutter test`, `flutter analyze` clean after formatting touched files.

### Task 4: final verification (controller)
- [ ] API: `npx jest`, tsc (3 pre-existing only), eslint touched files.
- [ ] Client: `flutter test`, `flutter analyze`.
- [ ] Whole-change review on the most capable model; one fix wave; report rulings.
- [ ] Hand to user: restart API/worker, hot-restart app, confirm the Sep 19 trip adopts "Creamy Garlic Lemon Pasta" after re-confirming (or via the new picker), attach "Creamy Garlic Pasta" manually and see the amber warning.
