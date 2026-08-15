# PantryPal Development Kickoff Prompt

Copy everything below this line into a brand-new development-agent session whose working directory is the PantryPal repository root.

---

You are the primary development agent for PantryPal. Build the complete invite-only MVP described in context/PANTRYPAL_PROJECT_PLAN.md.

This is an implementation assignment, not a request for another high-level proposal. Work autonomously through verified phases and do not stop after scaffolding.

## First actions

1. Read context/PANTRYPAL_PROJECT_PLAN.md completely before editing anything.
2. Inspect the repository, environment, installed tools, and any applicable AGENTS.md instructions.
3. Treat the project plan as the source of truth. Do not silently replace decisions with preferred defaults.
4. Create a concrete implementation checklist and keep at most one item in progress.
5. Inspect existing changes before editing and preserve user-owned work.
6. Establish a clean baseline with Git status and document any pre-existing files.

If an external credential is missing, implement and test the full adapter through mocks/fixtures, document the credential, and continue with all work that does not require the live secret. Ask the user only when a genuine blocking decision or external action cannot be safely inferred.

## Non-negotiable product decisions

- Product name: PantryPal.
- Release: invite-only beta.
- Client: one Flutter application targeting Android APK and responsive installable web/PWA.
- Server: NestJS TypeScript.
- Data and jobs: PostgreSQL, Prisma, Redis, BullMQ, and MinIO.
- AI: configurable provider abstraction with gemini-2.5-flash as the default.
- Import sources: recipe webpages, YouTube, Instagram, TikTok, pasted text, screenshots/images, uploaded audio, and uploaded video.
- Instagram/TikTok acquisition: official public metadata first; feature-flagged yt-dlp primary media adapter and gallery-dl carousel fallback.
- Analysis: deterministic parsing first, text second, audio third, sampled visuals fourth, compressed video-only escalation last.
- Household model: no roles and equal shared-content permissions.
- Identity: unique email/password accounts with non-unique display names.
- A user can belong to multiple households.
- Registration: operator beta invites for new households; household codes for joins.
- No outbound email, email verification, or self-service password reset in the beta.
- Shared changes are attributed by member and timestamp.
- The scheduler is the confirmed cook; a transfer is not effective until the target accepts.
- Shopping dates use Proposed and Confirmed states.
- Pantry checks become Check again when later demand invalidates an earlier unquantified confirmation.
- Scheduled cooking is assumed cooked after its date passes and moves into the visual archive.
- Notifications: in-app inbox, Android FCM, and VAPID Web Push.
- Language: English.
- Measurements: metric-first while preserving original wording.
- Online connection is required for the MVP.

Do not add user roles, Expo, React Native, Firebase as the primary database, email-based password recovery, or exact continuous pantry inventory.

## Repository target

Use this structure unless existing repository facts require a narrowly documented adjustment:

- apps/client — Flutter Android and web/PWA.
- apps/api — NestJS API, worker, Prisma, tests, and admin CLI.
- contracts — generated OpenAPI and realtime event documentation.
- context — approved project plan and this prompt.
- design-system — design source of truth and evaluation records.
- scripts — development/verification helpers that are not deployment manifests.

Generate OpenAPI from NestJS DTOs and generate the Dart API client from that contract. Commit generated artifacts and add a drift check.

## Environment facts

Planning verified:

- Flutter 3.44.4 and Dart 3.12.2 at E:/flutter.
- Flutter is not currently on PATH.
- Android SDK at E:/Sdk.
- Some Android SDK licenses may still need acceptance.
- Chrome, Android build tools, Node, npm, Docker clients, FFmpeg, and FFprobe are installed.
- Docker Desktop was not running at the end of planning.
- yt-dlp and gallery-dl were not installed.

For a PowerShell session, add E:/flutter/bin to that session's PATH or call Flutter by absolute path. Do not change permanent machine settings without a clear need.

Create a project-local ignored Python virtual environment for pinned yt-dlp and gallery-dl. Record pins in a small requirements file. Never commit the environment directory.

The user will run PostgreSQL, Redis, and MinIO as local containers. Application code should run directly with npm and Flutter commands.

Expected configurable defaults:

- PostgreSQL on localhost:5432.
- Redis on localhost:6379.
- MinIO API on localhost:9000.
- MinIO console on localhost:9001.

If the services are not running, finish work that can use unit tests and mocks, then give the user exact service prerequisites. Do not invent a different persistence stack.

## Docker boundary

Do not create:

- Dockerfile or files named Dockerfile.*
- docker-compose.yml, compose.yml, or variants.
- Reverse-proxy configuration.
- VPS provisioning scripts.
- TLS/deployment automation.

The final deployment will be Docker-based on the user's VPS, but it is a later phase. Document the expected topology, environment variables, health checks, persistence, and backup requirements only.

## Mandatory skills workflow

The user explicitly requires every available design-related skill to be used.

Before implementing the UI:

1. Enumerate all available skills and identify every design, brand, UI, UX, accessibility, motion, animation, icon, image, banner, presentation, 2D, 3D, WebGL, WebXR, and frontend-quality skill.
2. Read each selected skill's SKILL.md completely before using it.
3. Create design-system/SKILL_USAGE.md with columns:
   - Skill
   - Why it applies or what perspective it contributes
   - Action taken
   - Decision or rejection produced
   - Artifact or screen affected
4. Invoke every design-related skill at least once for an appropriate expert pass.
5. A stack-incompatible or specialist skill still contributes an applicability assessment or critique. Record why its technique should not become a PantryPal runtime dependency.
6. Do not add unrelated 3D, WebXR, animation, banner, or presentation features merely to demonstrate a skill.
7. User intent and the PantryPal plan override generic skill recommendations.

At minimum, the workflow must cover:

- Brand positioning and provisional app icon.
- Semantic design tokens.
- UI/UX system generation for a playful family planning/shopping app.
- Flutter-responsive implementation guidance.
- Frontend distinctiveness and anti-slop review.
- Accessibility and touch interaction.
- Motion principles and reduced motion.
- Icon consistency.
- Archive imagery and fallback assets.
- Quantitative design evaluation before acceptance.

Persist the final system in design-system/MASTER.md. Page-specific files may override the master only when a documented product reason exists.

Use the fixed direction from the plan:

- Playful family, adult-friendly.
- Cream background, terracotta identity, green primary action, accessible produce accents.
- Baloo 2 headings and Nunito Sans body.
- Flat rounded surfaces, vector icons, light and dark themes.
- Restrained 150-250 ms motion.
- No emoji as structural icons.
- No visual status communicated only by color.

## Engineering standards

### Flutter

- Use Material 3 with semantic tokens.
- Use Riverpod for application state and dependency injection.
- Use GoRouter for navigation and deep links.
- Use Dio for HTTP and session refresh.
- Use Freezed/json_serializable for immutable DTOs.
- Use the generated OpenAPI client rather than duplicating request shapes.
- Use flutter_secure_storage for Android refresh credentials.
- Keep web refresh credentials in secure HttpOnly cookies.
- Support Android notification permission and FCM.
- Implement Web Push through a service-worker bridge.
- Use Flutter Semantics and test keyboard access on web.
- Preserve state and scroll position across predictable back navigation.
- Provide explicit empty, loading, partial, offline, permission, and error states.

### NestJS

- Organize by domain modules rather than technical grab-bag folders.
- Use Prisma migrations and transactions.
- Run API and worker as separate processes from the same project.
- Use BullMQ for import, archive, cleanup, and notification jobs.
- Use Socket.IO plus Redis adapter for realtime events.
- Use MinIO through an S3-compatible storage interface.
- Generate OpenAPI from DTO validation.
- Use structured logs with correlation, import-job, account, and household identifiers.
- Expose liveness, readiness, and Prometheus-compatible metrics.

### Authentication and tenancy

- Hash passwords with Argon2id.
- Require at least 12 characters.
- Use 15-minute access tokens and rotating 30-day refresh sessions.
- Store only refresh-token hashes.
- Use secure HttpOnly SameSite cookies and CSRF protection on web.
- Use secure Android storage.
- Enforce exact-origin CORS.
- Every household-owned query and mutation must require active membership and householdId.
- Test cross-household access at service and API layers.
- Implement optimistic concurrency revisions for shared editable records.

### Media safety

- Canonicalize URLs and prevent SSRF, including redirects and DNS rebinding.
- Reject private, loopback, link-local, metadata-service, file, and non-HTTP(S) targets.
- Enforce duration, byte, redirect, timeout, and concurrency limits.
- Invoke FFmpeg, FFprobe, yt-dlp, and gallery-dl with spawn argument arrays, never shell-composed strings.
- Verify MIME and codecs before analysis.
- Use unpredictable per-job temporary directories.
- Clean temporary local media and remote Gemini files in finally blocks.
- Add a periodic TTL sweeper.
- Never store household social-media cookies.
- Never retain raw social video/audio after analysis.

## Required domain model

Implement the minimum entities listed in the project plan:

- Account, Session, BetaInvite.
- Household, HouseholdMembership, HouseholdInviteCode.
- ActivityEvent.
- Recipe, RecipeVersion, RecipeSource.
- CanonicalIngredient, IngredientAlias, RecipeIngredient, RecipeInstruction.
- ImportJob, ExtractionEvidence, MediaAsset.
- CookingInstance, CookAssignmentTransfer.
- ShoppingTrip, TripRecipeAssignment, ShoppingItem, ShoppingItemContribution.
- PantryAssessment.
- Notification, PushSubscription.

Use immutable recipe/cooking snapshots for history. Use decimals for quantities and ranges. Preserve original units/text beside normalized values.

## Required server interfaces

Implement versioned REST groups under /v1:

- auth
- households
- members
- imports
- recipes
- cooking
- trips
- pantry
- archive
- activity
- notifications

Implement and document realtime events:

- import.progress
- import.ready
- import.failed
- household.activity.created
- recipe.changed
- cooking.changed
- cook_assignment.requested
- cook_assignment.resolved
- trip.changed
- shopping_item.changed
- pantry.recheck_required
- notification.created

Events carry household ID, entity ID, actor summary, revision, and timestamp. Clients refetch after revision gaps.

## Recipe-import implementation order

Build ingestion behind platform adapters:

1. Input validation and URL canonicalization.
2. Webpage JSON-LD and deterministic recipe parsing.
3. Official/public metadata probes.
4. Text/caption/comment extraction.
5. Gemini structured text analysis.
6. Optional temporary media acquisition.
7. FFmpeg mono 16 kHz audio extraction.
8. Gemini audio analysis.
9. Visual escalation when completeness is below 75%, required amounts are absent, or visual dependence is detected.
10. Sample up to 16 scene/text/end frames.
11. Use compressed video-only analysis only within configured bounds.
12. Validate the versioned output schema.
13. Persist evidence and draft recipe.
14. Select/store a finished-dish archive cover when possible.
15. Delete temporary and remote media.

Implement the exact user-facing error taxonomy from the plan. Never collapse known causes into Something went wrong.

## Quantity, readiness, and shopping rules

- Preserve amount ranges and original wording.
- Scale target/original servings with decimal arithmetic.
- Use metric-first normalization.
- Convert only compatible dimensions.
- Do not perform unverified density conversion.
- Merge only canonical-equivalent ingredients with compatible units.
- Expose contribution breakdowns.
- Optional/flexible/staple/garnish missing amounts do not fail extraction.
- Inferred values require manual confirmation.
- A recipe can be saved as a draft.
- Missing required values cannot silently enter shopping totals.
- Reevaluate pantry status whenever trip demand changes.
- An unquantified Enough confirmation becomes Check again after increased demand.
- Exact confirmed availability remains valid only if it still covers total demand.

## Cook, trip, and archive state machines

Implement state transitions as explicit domain services with unit tests.

Cook transfer:

- Current cook remains confirmed while transfer is pending.
- Target acceptance atomically transfers responsibility.
- Decline preserves current cook.
- Leaving a household resolves future assignments safely and visibly.

Trip:

- Proposed to Confirmed to In progress to Completed.
- Confirmed date edits return to Proposed.
- Manual recipe-trip assignments are not silently overwritten.

Archive:

- Scheduled date earlier than household today becomes archived/assumed cooked.
- Worker startup performs catch-up.
- Mark cooked now archives immediately.
- Historical recipe, quantities, servings, cook, trip, source, and cover remain immutable.
- Cook again creates a new instance.

## Notifications

Build one notification-domain service that creates the in-app record first, then fans out to configured channels.

Required push events:

- Cook assignment request.
- Cook assignment accepted or declined.
- Shopping date confirmed or changed.
- Upcoming confirmed shopping trip.
- Pantry recheck caused by added demand.

Use FCM for Android and VAPID Web Push for browsers. Use deduplication keys, avoid notifying the actor for routine actions, use safe payload text, and deep-link to the affected entity.

## Execution phases and gates

### Phase 0: Foundation and design

- Scaffold apps/client and apps/api.
- Configure linting, formatting, tests, migrations, OpenAPI generation, and CI.
- Complete the mandatory skills workflow.
- Produce design-system artifacts and provisional brand/icon.
- Build app shell and responsive navigation.

Gate:

- Flutter and server baseline tests pass.
- Android debug build and Flutter web build pass.
- Design source of truth exists.

### Phase 1: Identity and households

- Accounts, sessions, beta invites, household codes, multiple households, switching, activity, operator reset, and tenancy tests.

Gate:

- Two accounts can collaborate in one household.
- One account can switch households.
- Cross-household access tests fail closed.

### Phase 2: Import engine

- Jobs, adapters, deterministic parsing, Gemini provider, audio/visual pipeline, evidence, completeness, cancellation, cleanup, and errors.

Gate:

- Fixtures cover every source and failure class.
- Temporary-media cleanup passes success and failure tests.
- Review UI reconnects to job progress.

### Phase 3: Recipes and planning

- Versioned recipes, review, classifications, scaling, Quick Cook, cooking dates, automatic/manual trip assignment, and cook handoff.

Gate:

- Scaling and readiness tests pass.
- Transfer cannot complete without acceptance.

### Phase 4: Shopping and pantry

- Trip lifecycle, aggregation, contributions, availability, partial amounts, recheck, purchase, ignore, and realtime list.

Gate:

- The cheese/new-demand recheck scenario passes.
- Concurrent client updates converge without silent overwrite.

### Phase 5: Archive and notifications

- Archive jobs, calendar collage, cover fallback, day details, Cook again, activity inbox, FCM, and Web Push.

Gate:

- Historical snapshots remain unchanged after recipe edits.
- Notification records and channel sends are deduplicated.

### Phase 6: Hardening

- Accessibility, themes, responsiveness, security, performance, metrics, documentation, release builds, and complete E2E acceptance.

Gate:

- All automated tests pass.
- Design evaluation and accessibility audits pass.
- Release-mode APK and production web builds pass.

## Testing obligations

Do not treat manual clicking as the only verification.

Implement:

- Server unit and integration tests.
- Adapter fixture tests with live smoke tests optional and credential-gated.
- Security tests for tenancy, auth, SSRF, redirect, MIME, size, and command injection.
- Cleanup tests for success, error, cancel, timeout, and worker recovery.
- Flutter unit, provider, widget, golden, semantics, and navigation tests.
- End-to-end tests for the complete household/import/scale/plan/shop/archive flow.
- Contract drift validation.

Run the narrow relevant suite after each change and the full suite at milestone gates.

## Quality expectations

- Do not use placeholder business logic in a completed milestone.
- Do not claim live integration success when only mocks ran.
- Do not hard-code secrets, URLs, household IDs, model names, or platform responses.
- Do not invent ingredient quantities.
- Do not hide errors in logs while showing generic UI.
- Do not bypass server authorization because the UI hides an action.
- Do not rewrite archived snapshots.
- Do not add runtime libraries solely because a design skill mentioned them.
- Prefer clear domain names and small cohesive modules.
- Keep generated code separate from authored code.
- Maintain migrations and fixtures as the schema evolves.

## Documentation to deliver

- Root README with setup, architecture summary, commands, and local service prerequisites.
- .env.example with every required variable but no values/secrets.
- API/worker/client development commands.
- OpenAPI generation and Dart-client regeneration instructions.
- Media tool setup and feature-flag explanation.
- Provider limitations and platform-policy warnings.
- Operator CLI usage for beta invites and password resets.
- Testing commands and live-smoke-test flags.
- Later VPS topology and backup/health requirements, without Docker artifacts.

## Definition of done

Do not finish merely because the app launches. Finish when:

- All MVP behaviors in context/PANTRYPAL_PROJECT_PLAN.md exist.
- Android and web/PWA builds pass.
- Server and worker run against PostgreSQL, Redis, and MinIO.
- Required tests and contract checks pass.
- The full acceptance journey passes.
- Known external-credential omissions are explicitly documented.
- The user receives a concise handoff listing what was built, how it was verified, remaining credential-dependent checks, and exact local run commands.

Begin by reading the plan and inspecting the environment. Then implement Phase 0 and continue phase by phase until the full MVP is complete or a genuine external blocker remains.
