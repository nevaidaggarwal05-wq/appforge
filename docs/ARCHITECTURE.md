# AppForge v5 — Architecture

## The Core Idea

One admin panel. Many white-label mobile apps. Changes propagate instantly.

```
┌─────────────────────────────┐
│  Admin Panel (Next.js 14)   │
│  admin.yourdomain.com       │  ← Nevaid controls all apps here
└────────────┬────────────────┘
             │
     ┌───────┴────────┐
     │                │
     ▼                ▼
┌─────────┐     ┌──────────────┐
│Supabase │     │ONE Firebase  │
│Postgres │     │project (FCM) │
└────▲────┘     └──────▲───────┘
     │                 │
     │ GET config      │ push delivery
     │                 │
┌────┴─────────────────┴─────┐
│ Flutter apps (20-30+)      │
│ • Unique appId per binary  │
│ • Same shared Firebase     │
│ • Topic: app_<uuid>        │
└────────────────────────────┘
```

## What replaced Firebase Remote Config

`GET /api/config/:appId` returns a JSON with app_url, theme, splash, feature flags, force_update. Flutter fetches this on every app open, caches locally (offline-first). See `docs/API_CONTRACT.md` for exact shape.

## What replaced Firebase Analytics

`POST /api/apps/:id/analytics-event` — Flutter apps send custom events (page_view, button_click, etc.) to our Supabase. Admin panel has a dashboard at `/apps/:id/analytics`.

## What STAYS on Firebase (one shared project)

- **FCM** — Android/iOS push delivery infrastructure. No alternative.
- **Crashlytics** — free, best-in-class crash reports. Optional but kept.

Apps isolated via topic subscription: `app_<uuid-with-underscores>`. Sending to that topic only reaches that app's users.

## Data flow: App open

1. User opens Flutter app
2. Splash screen shows (branded, ~2s)
3. In parallel:
   - `GET /api/config/<appId>` → fetches remote config
   - Device info gathered (platform, model, OS version)
   - FCM token registered via query params
   - Root detection check
   - Connectivity check
4. Bootstrap routes based on results:
   - Rooted device + root_block enabled → RootDetectedScreen
   - No internet → NoInternetScreen
   - App buildNumber < force_update.min_version_code → ForceUpdateScreen
   - Otherwise → WebViewScreen with `config.app_url`

## Data flow: Notification send

1. Nevaid types title + body at `/apps/<id>/notifications` in admin panel
2. `POST /api/notifications/send` → Firebase Admin SDK
3. FCM delivers to topic `app_<uuid>` (all devices with that app installed)
4. Flutter `FirebaseMessaging.onMessage` handler shows local notification
5. User taps → `data.url` opens in WebView

## Data flow: Config change

1. Nevaid edits config at `/apps/<id>/config` in admin panel
2. `PATCH /api/apps/<id>` updates Supabase row
3. CDN cache invalidates after 60s (max-age header on config endpoint)
4. Next `GET /api/config/<appId>` returns new values
5. Flutter caches new config, uses on next app open

## Scale characteristics

- **Storage** — Each app is one row. 100 apps = 100 rows. Supabase free tier handles millions.
- **Bandwidth** — Config response is ~2KB. 10,000 daily users × 100 apps × 1 open/day = 20MB/day. Free tier handles this.
- **FCM** — unlimited on Firebase Spark (free tier).
- **CPU** — Next.js server rarely does heavy work. Hetzner CX32 handles 100+ apps easily.

## Cost (all 100 apps)

- Hetzner CX32 (4 vCPU, 8GB RAM): $8.29/mo
- Domain: ~$1/mo amortized
- Supabase Free tier: $0 (up to 50k monthly active users)
- Firebase Spark: $0
- **Total: ~$10/mo** for 100 apps

## Security

- Admin routes protected by middleware (requires Supabase auth)
- RLS policies on all tables (owner can only see own apps)
- Zod validation on all write endpoints
- Public endpoints (`/api/config/*`, `/api/apps/*/analytics-event`, `/api/apps/*/crash`) use service_role key intentionally (Flutter has no user context, only app_id)
- All API routes have explicit auth checks (defense in depth, not just RLS)
- OWN explicit ownership check via `requireOwnership()` helper in `/api/apps/[id]/route.ts`
