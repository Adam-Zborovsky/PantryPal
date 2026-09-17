# PantryPal hands-on beta checklist

## Setup completed locally

- Docker PostgreSQL, Redis, and MinIO are running.
- `.media-tools-venv` is ignored and contains pinned `yt-dlp`.
- `.env` enables `SOCIAL_MEDIA_DOWNLOAD_ENABLED=true` and points `YT_DLP_PATH` at that environment.
- FFmpeg and FFprobe are available on this workstation.

## Before a real-device session

1. Set a valid `GEMINI_API_KEY` in the untracked root `.env`. Without it, text imports still work through deterministic parsing, but audio/video recipe extraction is not a useful end-to-end test.
2. Start the API and worker in separate terminals from `apps/api`. Do not use a social URL until both show that they are ready.
3. For a physical Android phone, expose the API to the phone using a LAN-reachable or tunneled HTTPS API origin. `localhost:3001` on the phone does not refer to this workstation. Rebuild the Android client with that API origin before installing it.
4. Use only public, non-login-required TikTok videos and Instagram Reels that the tester owns or has permission to process. Do not supply account cookies to PantryPal.

## Import acceptance path

1. Sign in, select a household, and open Import.
2. Paste a public TikTok video link. Confirm the job moves through Acquiring media, Analyzing audio, and either Ready for review or a precise recovery error.
3. Review the draft. Check title, source attribution, ingredients, quantities, instructions, and evidence. Correct uncertain fields and save.
4. Repeat with a public Instagram Reel.
5. Exercise recovery with a private/deleted link and an Instagram image/carousel. Expected result: no crash, no retained local media, and a useful caption/screenshot/manual fallback.
6. Confirm a successful recipe can be Quick Cooked, scheduled, added to a shopping trip, marked purchased, and later appears in Archive. Repeat with a second household account to verify realtime updates and notification behavior.

## What to capture for a failed import

- The exact public URL (only if it is safe to share).
- Import-job error title/code and approximate time.
- API and worker log excerpts with credentials and signed URLs redacted.
- Whether the source was a TikTok video, Instagram Reel, or Instagram post/carousel.

## Known boundary

The implemented social path is best-effort video acquisition through yt-dlp. It intentionally does not support private/login-only media, browser cookies, arbitrary Instagram image/carousel extraction, or official creator-account connection. Those are separate product integrations, not prerequisites for the public-link beta path.
