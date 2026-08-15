# PantryPal implementation handoff

Updated 2026-08-16 (Asia/Jerusalem). Continue implementing the invite-only MVP
from `context/DEVELOPMENT_KICKOFF_PROMPT.md` and `PANTRYPAL_PROJECT_PLAN.md`.
The user asked for autonomous progress; defer genuine product decisions until
the last responsible moment. Do not add Dockerfiles or Compose files.

## Status

The MVP is not complete. Foundation, auth/households, realtime/activity
foundation, import foundation, deterministic recipe analysis, decimal scaling,
and the first Flutter identity slice are implemented. The latest committed
checkpoint is `59a57f4 feat: add deterministic recipe analysis provider`.

Uncommitted work is a cohesive Flutter/Stitch checkpoint. Review it with
`git status --short` and `git diff`, validate it, then commit it before moving
on. Files include:

- `apps/client/lib/app.dart`: tokenized Flutter theme and auth gate.
- `apps/client/lib/features/auth/auth_page.dart`: sign-in, registration/beta
  invite, validation/error handling, and household-code entry surface.
- `apps/client/lib/features/home/app_shell.dart`: responsive app shell and home
  empty state.
- `apps/client/lib/main.dart`, client analysis exclusions, and widget smoke test.
- `design-system/STITCH.md` and an updated `SKILL_USAGE.md`.
- this handoff file.

Validation passed after this work, from `apps/client`:

```powershell
E:\flutter\bin\flutter.bat analyze
E:\flutter\bin\flutter.bat test
E:\flutter\bin\flutter.bat build web
```

API build/unit tests also passed after the current last commit, from `apps/api`:

```powershell
npm run build
npm test -- --runInBand
```

Run `npm run test:e2e -- --runInBand` before handoff/merge and rerun Android
debug build after the client checkpoint. Always run API npm scripts from
`apps/api`, not repo root.

## Local services

Docker containers were started directly with named persistent volumes:

- `pantrypal-postgres`: Postgres 16, port 5432, database/user/password
  `pantrypal`.
- `pantrypal-redis`: Redis 7, port 6379.
- `pantrypal-minio`: ports 9000/9001, credentials `pantrypal` /
  `pantrypal-development-secret`.

Root `.env` is ignored and contains local connection/JWT values. The first
Prisma migration is applied. Use `docker ps` to confirm service state.

## Stitch/design

User set `STITCH_API_KEY`; Stitch works.

- Project: `projects/17784570670142129014` (private PantryPal MVP)
- DESIGN.md screen: `projects/17784570670142129014/screens/8513252392855706849`
- Generated sign-in session: `3795495774214573504`, Gemini 3.1 Pro mobile.
- Details: `design-system/STITCH.md`.

`create_design_system_from_design_md` responds `Request contains an invalid
argument` even when given the UploadDesignMd result; this appears to be a Stitch
connector mismatch. `generate_screen_from_text` succeeded and inferred the
PantryPal design system. Use Stitch for real remaining screens and record
sessions/screens in `design-system/STITCH.md`; translate designs to Flutter,
never embed generated web HTML.

Design source: cream `#FFFBEB`, terracotta `#9A3412`, green `#059669`, ink
`#0F172A`, Baloo 2 display, Nunito Sans body, outlined flat rounded surfaces,
48px targets, sparse kitchen motif. No gradients, glass, shadows, emoji, or
generic metric dashboards.

## Important limitations/next steps

1. Frontend auth UI posts valid Dio requests (`API_BASE_URL`, default
   `http://localhost:3000/v1`; Android emulator needs `http://10.0.2.2:3000/v1`)
   but does not yet persist Android refresh tokens, attach access tokens, refresh
   sessions, or actually join a household. Build a typed API/session client with
   `flutter_secure_storage` next.
2. OpenAPI response schemas need explicit response DTOs. Add a local-path
   dependency for the nested generated Dart package only after it is made
   consumable. Root analyzer excludes `lib/generated/**` in the meantime.
3. `src/openapi/generate.ts` includes only Auth and Households modules. Add
   Imports and each new public module, regenerate contract/client, and update
   contract checks.
4. Wire `ActivityService` to mutations, add activity endpoint, and configure
   Redis Socket.IO adapter.
5. Build actual import worker/queue, SSRF redirect/DNS defense, provider/source
   acquisition/evidence/review persistence/UI. Do not fake unsupported media or
   transcription success.
6. Complete recipe CRUD/versioning/review/scaling/timers and cooking
   scheduling/transfers, then trips/pantry/archive/notifications.
7. Fix CI: `.github/workflows/verify.yml` needs Postgres service and dummy JWT
   environment for API E2E; finish accessibility/performance/runbooks/docs.

## Current backend

Auth uses beta invite registration, Argon2id, 15-minute JWT access and rotating
30-day refresh sessions. Web uses cookies/CSRF and Android gets refresh token.
Household membership checks are enforced. Realtime subscription works, without
Redis adapter. Import URL/parser and deterministic analysis foundation exist.
`QuantityService` uses Decimal (never use floats). Recipes, cooking, shopping,
pantry, archive, notifications, and hardening are incomplete.

## Working rules

- Use `apply_patch` for local edits.
- Preserve unrelated work; never reset/checkout/delete it.
- Do not create Docker configuration artifacts.
- Preserve household tenant isolation and membership checks.
- Keep amount math Decimal end-to-end.
