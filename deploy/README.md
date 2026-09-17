# PantryPal production Docker scaffold

This is a reviewable deployment candidate following the same deployment rules and conventions established in Zest.

## Architecture

- `pantrypal-frontend` builds the Flutter web app and serves it with Nginx.
- Nginx proxies `/v1/`, `/socket.io/`, `/health`, and `/docs` to `pantrypal-api` over `pantrypal-internal`, supporting WebSocket upgrade for realtime sync.
- `pantrypal-api` runs the committed Prisma migrations on startup, connects to `pantrypal-db`, `pantrypal-redis`, and `pantrypal-minio`.
- `pantrypal-worker` runs background processing (BullMQ recipe imports, ingredient profiles, archive catchup) using `ffmpeg`/`ffprobe` and connects to `pantrypal-db`, `pantrypal-redis`, and `pantrypal-minio`.
- Only `pantrypal-frontend` joins the external `adam-cloud` network. No service publishes a host port.
- The frontend receives its public HTTPS API base during Docker build through the ignored production environment file (`API_BASE_URL`). Native APK builds need the same value supplied manually as `--dart-define=API_BASE_URL=...`.

## Local configuration

```sh
cd deploy
cp .env.example .env
chmod 600 .env
```

Edit `.env` locally. Never commit it. Its real public host, provider keys, and database passwords are intentionally absent from this repository. Docker Compose loads this exact filename automatically for both build arguments and runtime service configuration.

Validate the Compose model without starting it:

```sh
docker compose config
```

Build and start the stack with the standard Compose command:

```sh
docker compose up -d --build
```

## Operator tasks

Generate initial beta invite token:

```sh
docker compose exec pantrypal-api node dist/cli.js beta-invite
```

Reset operator password:

```sh
docker compose exec pantrypal-api node dist/cli.js reset-password <email> <new-password-min-12>
```

## Deployment prerequisites still requiring an explicit decision

1. Verify a tested backup and restore procedure for `pantrypal_postgres_data`, `pantrypal_redis_data`, and `pantrypal_minio_data`.
2. Decide the public hostname and add its Cloudflare Tunnel ingress rule to `pantrypal-frontend:80` on `adam-cloud`.
3. Build an APK with the same public HTTPS base URL (`--dart-define=API_BASE_URL=https://<public-host>/v1`); do not compile secrets into the APK.
4. Mount Firebase service account credentials (`GOOGLE_APPLICATION_CREDENTIALS`) outside the repository if FCM push notifications are enabled.
