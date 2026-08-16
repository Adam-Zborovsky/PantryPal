# PantryPal agent handoff

## Current point

Phase 1 implementation has been completed in code and should be committed with
the current worktree. The latest completed commit before this checkpoint is
`ce56927 feat: show import job status on home`.

New uncommitted Phase 1 files/edits:

- `apps/api/src/realtime/realtime.gateway.ts`: Socket.IO now uses Redis adapter
  when `REDIS_URL` is present; tests deliberately skip adapter connection.
- `apps/api/src/activity/activity.controller.ts`: authenticated household activity
  feed at `GET /v1/households/:householdId/activity?limit=50`.
- `apps/api/src/activity/activity.service.ts`: tenant-checked activity listing.
- `apps/api/src/activity/activity.module.ts`: controller and AuthModule import.
- `apps/api/src/households/*`: household join, invite-code rotation, and leave
  now record/publish activity events with the authenticated actor.
- `apps/api/src/imports/import-queue.service.ts`: Queue creation is lazy and
  disabled for Jest, preventing Redis handles in E2E module construction.

## Verification state

`npm run build` and `npm test -- --runInBand` passed after the Phase 1 work.
The API E2E test initially exposed a missing AuthModule import in ActivityModule;
that is fixed. Its final rerun could not connect to PostgreSQL because Docker
Desktop has stopped: the Docker named pipe
`//./pipe/dockerDesktopLinuxEngine` is missing and `localhost:5432` is down.

Once Docker is running again, run from `apps/api`:

```powershell
npm run test:e2e -- --runInBand
npm run contract:generate
npm run client:generate
```

Then inspect `git diff --check`, commit the Phase 1 code, and ensure contract
changes are included if the activity route is intentionally public.

## Local processes

An API watch process and worker process were started earlier. Docker is now
offline, so restart Docker services before relying on either. Check ports and
processes rather than assuming they are healthy. The API’s default actual port
is `3001`; Flutter defaults/docs were aligned to it.

## Project status

- Phase 0: complete.
- Phase 1: code complete at this checkpoint; service-backed E2E rerun pending
  Docker availability.
- Phase 2: queue/worker/public URL parser/evidence/draft persistence and initial
  Flutter import/status UX implemented; review-edit UI and hardening remain.
- Phases 3–6: not complete. Decimal scaling exists; recipes/planning/trips/pantry
  archive/notifications/hardening require continued implementation.

## Important constraints

- Use `apply_patch` for edits; do not reset or delete unrelated work.
- Do not add Dockerfiles or Compose files.
- Preserve household membership checks and Decimal arithmetic.
- Continue using Stitch as a reference generator; download HTML when the server
  exposes it and rebuild in Flutter with local design skills, not generated web
  runtime code.
