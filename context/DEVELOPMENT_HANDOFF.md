# PantryPal development handoff

## Current point

The worktree contains uncommitted work spanning the completed Phase 1 foundation through the backend portions of Phases 3–5. The latest committed baseline is:

```text
ce56927 feat: show import job status on home
```

Do **not** discard, reset, or overwrite the existing dirty worktree. Inspect and preserve it; it contains the implementation described below, generated API contract/client updates, and a new Prisma migration.

Docker is now available and the local PostgreSQL, Redis, and MinIO containers are running:

```text
pantrypal-postgres  localhost:5432
pantrypal-redis     localhost:6379
pantrypal-minio     localhost:9000
```

The API default port is `3001`. The Flutter client defaults are aligned with it.

## What is implemented

### Recipe imports and analysis

- Public webpage imports run through the queue/worker and persist source, evidence, draft recipe data, and import-job status.
- Pasted-text imports are supported end-to-end. A deterministic parser extracts labelled title, servings, ingredients, and method.
- `GEMINI_API_KEY` enables `GeminiRecipeAnalysisProvider`, using Gemini structured JSON output. `GEMINI_MODEL` is optional and defaults to `gemini-2.5-flash`.
- Without a Gemini key, analysis falls back safely to the deterministic provider.
- YouTube URL support canonicalizes `youtu.be`, watch, shorts, and embed forms; it uses oEmbed for public metadata and maps unavailable/private/removed sources to actionable errors. With `YOUTUBE_MEDIA_DOWNLOAD_ENABLED=true`, the backend—not the device—temporarily acquires the canonical public YouTube media, extracts mono 16 kHz FLAC audio for Gemini analysis, and falls back to sampled video frames only if audio does not yield ingredients. The temporary directory and Gemini file are deleted in cleanup.
- Public Instagram Reels and TikTok video links can use the same temporary backend-only acquisition path as YouTube when `SOCIAL_MEDIA_DOWNLOAD_ENABLED=true`. They are best-effort, require the pinned project-local `yt-dlp` installation, never use social-account cookies, and retain paste-caption/screenshot recovery when unavailable. Instagram image/carousel acquisition remains deliberately unsupported; use a screenshot instead.
- Import input supports up to 200,000 characters for pasted text.

### Uploaded screenshots and media storage

- A household-scoped MinIO/S3 upload boundary is implemented under imports:

  ```text
  POST /v1/households/:householdId/imports/media-assets/upload-url
  POST /v1/households/:householdId/imports/media-assets/:assetId/complete
  ```

- The API validates allowed MIME types and declared size, creates a temporary `UPLOAD_PENDING` `MediaAsset`, and returns a 15-minute signed PUT URL. Completion verifies object size and MIME with `HeadObject` before marking the asset `READY`.
- Assets are bound to exactly one same-household import, expire after 60 minutes unless retained, and are swept periodically. Failed/expired assets are marked `EXPIRED` and their objects are deleted on a best-effort basis.
- Screenshot/image imports are now end-to-end: Flutter picks JPEG, PNG, WebP, or HEIC images up to 10 MB, uploads them directly to MinIO with progress, completes verification, and creates an image import job. The worker reads the verified object and supplies inline image evidence to Gemini structured analysis.
- The public API accepts no device-side audio or video uploads. A video recipe import always begins with a user-supplied public link; when backend acquisition is enabled and appropriate for the source, the worker stores the media only in an isolated temporary directory, validates it with FFprobe, extracts mono 16 kHz FLAC, analyzes that audio with Gemini, and deletes both temporary local and Gemini files in cleanup. Sampled frames are a fallback for silent videos or audio analyses that yield no ingredients.
- Browser direct uploads are live-tested against the local MinIO origin policy for `http://localhost:3000`.

### Security and reliability

- URL validation blocks private, loopback, link-local, and otherwise non-public resolved IP addresses before imports are queued.
- The worker revalidates source DNS immediately before fetching, reducing SSRF exposure. A future hardening opportunity is DNS-pinned outbound HTTP to close the small validation-to-request rebinding window.
- Queue and processing error handling report structured recovery states, including metadata-only sources.
- Realtime Redis adapter initialization is guarded for Jest/test runtime.

### Recipe review

- `ImportJob` now optionally links to its persisted `recipeId` via migration `20260816112000_link_import_recipe`.
- Recipe review API is implemented:

  ```text
  GET /v1/households/:householdId/recipes/:recipeId/review
  PUT /v1/households/:householdId/recipes/:recipeId/review
  ```

- Review saving uses immutable recipe versions and optimistic concurrency through an expected revision. It preserves source evidence, reports extraction/manual/missing field completeness, calculates readiness, and records activity.
- Flutter includes a responsive recipe-review page. Users can edit title, servings/yield, ingredients, classification, shopping inclusion, instructions, and source evidence before saving.
- The import UI has a Link/Text selector and a multiline text form. Ready-for-review import jobs expose a Review action in the app shell.

### Planning, shopping, archive, and notifications

- Cooking instances preserve immutable recipe and scaled-ingredient snapshots, support Quick Cook, scheduled cooking, automatic latest-confirmed-trip suggestion, cook-transfer consent, mark-cooked, and Cook again.
- Shopping trips support proposal, confirmation/aggregation, start, completion, cancellation, item states, and contribution rows.
- Adding cooking demand to a confirmed or in-progress trip refreshes its aggregation. An unquantified Confirmed-at-home pantry assessment becomes Check again when demand grows; an insufficient exact compatible amount becomes Partially available. This has a focused regression test.
- The archive catch-up worker runs at startup and every 15 minutes. Archive listing and Cook again APIs exist.
- The in-app notification domain supports inbox/read state and deduplicated records. It now emits for cook-transfer requests/resolutions, shopping-trip confirmation, and pantry rechecks. Android FCM registration is wired end-to-end: the Android client initializes from `android/app/google-services.json`, asks only after an explicit inbox action, and binds its FCM token to the authenticated account. The API delivers Android FCM notifications only when `FIREBASE_MESSAGING_ENABLED=true` and Application Default Credentials are configured; invalid FCM tokens are removed automatically. Browser push remains unimplemented.
- The Flutter Plan, Shop, Archive, and activity-inbox screens are implemented against the API. Plan can create a scheduled meal from the household recipe library; Shop supports trip lifecycle, item status, and date changes; Archive supports Cook again; the inbox exposes refresh, recoverable failures, per-notification read progress, and explicit read/unread semantics.
- Realtime is end-to-end for active Flutter sessions. The client authenticates to `/v1/realtime`, subscribes only to its active household, reconnects automatically, and authoritatively refetches Plan, Shop/trip detail, Archive, and inbox data after relevant domain events. The API payload includes event summaries so shopping-item and pantry events can refresh the affected trip detail.

### Contract and generated client

- OpenAPI generation now deep-scans `AppModule`, so the checked-in contract includes actual activity, recipes, health, metrics, and system routes.
- The generated Flutter client includes the activity and recipe APIs and review DTOs.
- Do not manually edit generated API client files; regenerate them from the API contract.

## Important files

```text
apps/api/prisma/schema.prisma
apps/api/prisma/migrations/20260816112000_link_import_recipe/migration.sql
apps/api/prisma/migrations/20260816130000_media_asset_upload_state/migration.sql
apps/api/src/imports/
apps/api/src/recipes/recipes.controller.ts
apps/api/src/recipes/recipes.dto.ts
apps/api/src/recipes/recipes.service.ts
apps/api/src/recipes/recipes.module.ts
apps/client/lib/features/auth/session_repository.dart
apps/client/lib/features/home/app_shell.dart
apps/client/lib/features/recipes/recipe_review_page.dart
apps/client/lib/generated/openapi/
contracts/openapi.json
```

The imports folder has broad formatting diffs because previously uncommitted source was formatted while implementing the new features. Preserve those changes rather than reverting them selectively.

## Verification already completed

Run API commands from `apps/api` unless stated otherwise.

```powershell
npm run build
npm test -- --runInBand
npm run test:e2e -- --runInBand
```

Latest results:

- API build passed.
- API unit tests now pass: 14 suites, 37 tests.
- API E2E tests pass: 1 suite, 4 tests, against the local Docker services. Coverage includes recipe listing, cooking/trip aggregation, date-change invalidation, archive/Cook again, cook-transfer acceptance using two real authenticated accounts, notification privacy/read state, and cross-household denial.
- `flutter test` passed and `flutter analyze` has no findings.
- Flutter web and Android release builds passed after realtime integration. The Android artifact is `apps/client/build/app/outputs/flutter-apk/app-release.apk` (54.0 MB). Flutter's WebAssembly dry run reports a `socket_io_common` JS-interop incompatibility, so the current web release targets JavaScript rather than Wasm.
- Prisma schema validation passed when `DATABASE_URL` was supplied.
- `git diff --check` passed.
- `npm run contract:generate` and `npm run client:generate` completed successfully.

`npm run contract:check` currently fails only because it intentionally asserts a clean git diff after regeneration; it should not be expected to pass while these uncommitted contract/client changes are present.

No live Gemini or YouTube provider smoke test was performed because no API key/live credentials were used. Google documents direct public-YouTube video input for Gemini as a preview capability; verify current provider limits and behavior before treating it as production-ready.

## Database note

The `ImportJob.recipeId` and `MediaAsset` upload-state migrations have been applied to the local development database. For a fresh local database, set `DATABASE_URL` and run from `apps/api`:

```powershell
npx prisma migrate deploy
```

Then rerun the E2E suite. Do not apply it to any shared or production database without the normal migration process.

## Project status

- **Phase 0:** Complete.
- **Phase 1:** Implemented and verified, but still uncommitted in the current worktree.
- **Phase 2:** Functional for public webpages, pasted text, deterministic/Gemini analysis, backend-only public YouTube/TikTok/Instagram-Reel media acquisition, queue processing, evidence persistence, signed temporary screenshot storage, and audio-first video analysis with sampled-frame fallback. Device-side audio/video uploads are not accepted. Social media remains best-effort and requires the pinned local yt-dlp tool, public media, and a live provider smoke test.
- **Phase 3:** Complete: recipe review/versioning, scaling, cooking, trip suggestion, Quick Cook/transfer workflows, and the Flutter review/import and planning surfaces are implemented.
- **Phase 4:** Complete: trip lifecycle, aggregation, contributions, pantry states/recheck invalidation, realtime API fan-out, Flutter shopping, and acceptance coverage are implemented.
- **Phase 5:** Complete for the in-app experience and Android FCM integration. Push delivery is safely configuration-gated pending a deployment service-account credential. Notification preferences, browser push, and navigable deep links remain product work.

## Recommended next work

1. First inspect `git status` and the complete diff. Keep all existing changes together, including generated OpenAPI/Flutter files and the Prisma migration. Create coherent commits only after confirming the intended grouping.
2. Prepare a clean commit series when authorized; the worktree is intentionally still dirty and must not be reset.
3. Add a Firebase service-account key to the deployment secret store, mount it outside the repository, set `GOOGLE_APPLICATION_CREDENTIALS` to that path, and set `FIREBASE_MESSAGING_ENABLED=true`. Android FCM token registration and delivery are already implemented; browser push is not.
4. Implement notification preferences and navigable deep links after their product behavior is specified.
5. Run the real-device checklist in `context/HANDS_ON_TEST_CHECKLIST.md` using owned/authorized public TikTok and Instagram Reel URLs. Record provider-specific failures as compatibility issues; do not add cookies or bypasses.

## Non-negotiable implementation constraints

- Preserve tenant isolation on every household-scoped read and write.
- Keep money/quantity calculations Decimal-safe; do not introduce JavaScript floating-point arithmetic for persisted quantities or costs.
- Do not add Dockerfiles or Compose configuration; local infrastructure already exists.
- Preserve API-first development: update the OpenAPI contract and regenerate the Flutter client whenever routes/DTOs change.
- Continue rebuilding reference designs as Flutter UI; do not introduce a web runtime as the product client.
- Do not treat social-network URLs as freely fetchable media. Respect provider access, user privacy, and recovery UX.
- Treat signed upload URLs as short-lived secrets. Do not persist them, log them, or return storage keys to clients unnecessarily.
- Do not overwrite unrelated dirty-worktree changes or use destructive git commands.
