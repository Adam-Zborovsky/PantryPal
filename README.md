# PantryPal

PantryPal is an invite-only household recipe planner for Android and responsive web/PWA. It turns recipe links and shared media into reviewable recipes, scalable plans, coordinated trips, pantry checks, and an immutable cooking archive.

## Current foundation

The repository contains the Flutter Material 3 shell, visual system, NestJS operational baseline, validated Prisma data contract, generated OpenAPI contract, and CI checks. Identity, import, planning, shopping, archive, and push domain workflows are implemented in subsequent phases.

## Prerequisites

- Node 26 and npm
- Flutter 3.44.4 at `E:/flutter` (use the absolute executable or add `E:/flutter/bin` only to the active shell)
- Java (only if an OpenAPI generator is later added)
- FFmpeg and FFprobe
- Operator-supplied local PostgreSQL (5432), Redis (6379), and MinIO (9000/9001). Docker Desktop must be running for those containers.

No Dockerfiles, Compose files, proxy configuration, or deployment automation belong in this repository phase.

## First-time setup

1. Copy `.env.example` to `.env` and fill the non-empty secret/provider values.
2. Start the local PostgreSQL, Redis, and MinIO containers supplied by the operator.
3. Install the pinned optional social media tools with `powershell -ExecutionPolicy Bypass -File scripts/setup-media-tools.ps1`.
4. Install dependencies: `npm ci` in `apps/api`, and `E:/flutter/bin/flutter.bat pub get` in `apps/client`.
5. Create/apply database migrations once services are running: `npx prisma migrate dev` in `apps/api`.

## Development commands

| Surface | Command |
|---|---|
| API | `npm run start:dev` from `apps/api` |
| Worker | `npm run start:worker` from `apps/api` |
| Flutter web | `E:/flutter/bin/flutter.bat run -d chrome` from `apps/client` |
| Flutter Android | `E:/flutter/bin/flutter.bat run` from `apps/client` |
| API tests | `npm test -- --runInBand` from `apps/api` |
| API E2E tests | `npm run test:e2e -- --runInBand` from `apps/api` |
| Client tests | `E:/flutter/bin/flutter.bat test` from `apps/client` |
| Contract generation | `npm run contract:generate` from `apps/api` |
| Dart client regeneration | `npm run client:generate` from `apps/api` |
| Contract drift check | `npm run contract:check` from `apps/api` |

## Architecture

- `apps/client`: Flutter Android and responsive PWA client using Material 3, Riverpod, GoRouter, Dio, immutable DTO tooling, and semantic themes.
- `apps/api`: NestJS API and separately started worker, Prisma/PostgreSQL contract, BullMQ/Redis, S3-compatible MinIO, and versioned REST/OpenAPI.
- `contracts`: committed generated OpenAPI and documented realtime events. The matching generated Dart Dio client lives in `apps/client/lib/generated/openapi` and is regenerated from the contract, never hand-authored.
- `design-system`: source-of-truth system and design skill record.

The eventual VPS topology will place static Flutter web hosting, API, worker, PostgreSQL, Redis, MinIO/object storage, reverse proxy/TLS, metrics, log retention, and persistent backups on separately managed deployment infrastructure. Health checks are `/v1/live`, `/v1/ready`, and `/v1/metrics`. Back up PostgreSQL and retained MinIO covers/evidence, rotate secrets, and run media TTL cleanup.

## Provider and platform policy

Gemini defaults to `gemini-2.5-flash` but is accessed through a configurable provider abstraction. YouTube credentials are optional. Instagram/TikTok downloads are best effort, disabled by default, and never use household cookies; paste, screenshots, uploads, and manual entry remain available. Live provider smoke tests require explicit credentials and are not represented as successful by mock tests.

## Operator work

Create an operator invite with `npm run cli -- beta-invite [expiry-days]` from `apps/api`; the token is shown once and stored only as a hash. Reset a password and revoke all active sessions with `npm run cli -- reset-password <email> <new-password-min-12>`.
