# Phase Status

_Last updated when handed off from Claude.ai → Claude Code._

---

## ✅ Phase 1 — Planning (DONE)

- Architecture defined
- Config schema locked
- Tables designed
- File structure planned

## ✅ Phase 2 — Supabase Schema + Backend Core (DONE)

**24 files. ~890 lines of TypeScript + 197 lines of SQL.**

### Database
- [x] `supabase/migrations/001_initial_schema.sql` — 5 tables (apps, fcm_tokens, notifications, analytics_events, app_crashes), indexes, RLS policies, updated_at trigger

### Shared libraries
- [x] `lib/utils.ts` — cn, slugify, slugifyOrFallback, isValidHex
- [x] `lib/supabase/types.ts` — all row types + RemoteConfigResponse
- [x] `lib/supabase/server.ts` — server + admin clients
- [x] `lib/supabase/client.ts` — browser client
- [x] `lib/fcm/admin.ts` — Firebase Admin SDK singleton
- [x] `lib/fcm/send.ts` — FCM send with 4 target modes

### Middleware
- [x] `middleware.ts` — public route allow list + auth redirect

### API routes (all 9)
- [x] `GET /api/config/[appId]` — Flutter hits this (PUBLIC)
- [x] `POST /api/apps/[id]/analytics-event` — custom events (PUBLIC)
- [x] `POST /api/apps/[id]/crash` — crash reports (PUBLIC)
- [x] `GET /api/apps` — list apps (ADMIN)
- [x] `POST /api/apps` — create app (ADMIN, Zod validated)
- [x] `GET /api/apps/[id]` — fetch single (ADMIN + ownership)
- [x] `PATCH /api/apps/[id]` — update (ADMIN + ownership)
- [x] `DELETE /api/apps/[id]` — delete (ADMIN + ownership)
- [x] `POST /api/notifications/send` — FCM send (ADMIN, Zod validated, ownership check)
- [x] `GET /api/generator/[appId]` — Flutter ZIP (stub — Phase 4 populates template files)
- [x] `GET /api/auth/callback` — Supabase OTP callback
- [x] `POST /api/auth/signout` — signout (returns 303 redirect)

### Config files
- [x] package.json, tsconfig.json, next.config.mjs
- [x] tailwind.config.ts, postcss.config.mjs
- [x] .env.local.example, .gitignore

## ✅ Phase 3 — Admin Panel UI (DONE)

**21 new files. ~1,800 lines of TypeScript/React.**

### Root
- [x] `app/layout.tsx` — HTML shell + Toaster
- [x] `app/globals.css` — Tailwind + CSS vars + utility classes
- [x] `app/page.tsx` — redirects to /apps

### Auth
- [x] `app/(auth)/layout.tsx`
- [x] `app/(auth)/login/page.tsx` — 2-stage OTP flow

### Dashboard
- [x] `app/(dashboard)/layout.tsx` — sidebar nav
- [x] `app/(dashboard)/apps/page.tsx` — list
- [x] `app/(dashboard)/apps/new/page.tsx` + `NewAppForm.tsx` — create form
- [x] `app/(dashboard)/apps/[id]/page.tsx` — redirect to config
- [x] `app/(dashboard)/apps/[id]/AppHeader.tsx` — tabs: Config / Notifications / Analytics
- [x] `app/(dashboard)/apps/[id]/config/page.tsx` + `ConfigForm.tsx` ⭐ — 28-field editor
- [x] `app/(dashboard)/apps/[id]/notifications/page.tsx` + `NotificationComposer.tsx`
- [x] `app/(dashboard)/apps/[id]/analytics/page.tsx` — stats + top events + crashes
- [x] `app/(dashboard)/notifications/page.tsx` — cross-app hub

### UI primitives
- [x] `components/ui/Button.tsx`
- [x] `components/ui/Card.tsx`
- [x] `components/ui/Field.tsx`
- [x] `components/ui/Switch.tsx`

## ✅ Bug audit — 9 bugs found and fixed (see BUGS_FIXED.md)

All applied to the code already. Don't reintroduce them.

---

## ✅ Phase 4 — Flutter Shell (DONE)

**41 files written** at `flutter_shell/`. All spec items checked off, plus a
few integration extras (top-level `android/build.gradle`, `res/values/strings.xml`
+ `styles.xml`) so the template compiles standalone.

### Checklist

- [x] `pubspec.yaml` (deps: dio, local_auth, flutter_local_notifications; NO firebase_remote_config, NO firebase_analytics)
- [x] `.gitignore`
- [x] `lib/app_config.dart`
- [x] `lib/firebase_options.dart` (placeholder — empty-string stub with REPLACE markers; filled by `flutterfire configure`)
- [x] `lib/main.dart`
- [x] `lib/utils/logger.dart`
- [x] `lib/utils/color_utils.dart`
- [x] `lib/core/errors/app_exceptions.dart`
- [x] `lib/core/models/remote_config_model.dart`
- [x] `lib/core/api/api_client.dart`
- [x] `lib/core/api/config_api.dart`
- [x] `lib/core/storage/cache_service.dart`
- [x] `lib/services/remote_config_service.dart` (REWRITTEN — no Firebase RC)
- [x] `lib/services/notification_service.dart` (with flutter_local_notifications for FG display)
- [x] `lib/services/biometric_service.dart` (NEW — real local_auth)
- [x] `lib/services/analytics_service.dart` (NEW — custom events)
- [x] `lib/services/haptic_service.dart`
- [x] `lib/services/session_service.dart`
- [x] `lib/services/rating_service.dart`
- [x] `lib/services/device_info_service.dart`
- [x] `lib/services/network_quality_service.dart`
- [x] `lib/services/security_service.dart`
- [x] `lib/screens/splash_screen.dart`
- [x] `lib/screens/bootstrap_screen.dart`
- [x] `lib/screens/webview_screen.dart` (JS bridge for haptic/biometric/share/openUPI/track)
- [x] `lib/screens/no_internet_screen.dart`
- [x] `lib/screens/force_update_screen.dart`
- [x] `lib/screens/root_detected_screen.dart`
- [x] `lib/widgets/whatsapp_share_button.dart`
- [x] `lib/widgets/in_app_update_banner.dart`
- [x] `android/build.gradle` (top-level)
- [x] `android/app/build.gradle`
- [x] `android/settings.gradle`
- [x] `android/gradle/wrapper/gradle-wrapper.properties`
- [x] `android/key.properties.template` (committed; `key.properties` is gitignored)
- [x] `android/app/src/main/AndroidManifest.xml`
- [x] `android/app/src/main/res/xml/file_paths.xml`
- [x] `android/app/src/main/res/values/strings.xml`
- [x] `android/app/src/main/res/values/styles.xml`
- [x] `android/app/src/main/kotlin/com/template/app_template/MainActivity.kt` (with FLAG_SECURE)
- [x] `ios/Runner/AppDelegate.swift`
- [x] `flutter_shell/docs/hosting/assetlinks_TEMPLATE.json`

### Generator wire-up (DONE)

- [x] `admin_panel/lib/generator/template.ts` — walks `flutter_shell/` from disk, excludes build artefacts + secrets, applies per-app substitutions
- [x] `admin_panel/app/api/generator/[appId]/route.ts` — bundles the full tree + injects generated `lib/app_config.dart`, `README.md`, `.appforge-app-id`

**Per-app substitutions the generator applies:**

| File | Replaces |
| --- | --- |
| `android/app/build.gradle` | `namespace`, `applicationId`, `versionCode`, `versionName` |
| `android/app/src/main/AndroidManifest.xml` | AdMob `APPLICATION_ID`, App Links `android:host` |
| `android/app/src/main/res/values/strings.xml` | `app_name` |
| `android/app/src/main/kotlin/com/template/app_template/MainActivity.kt` | package declaration **+ file moved** to `kotlin/<new/pkg/path>/` |
| `docs/hosting/assetlinks_TEMPLATE.json` | `package_name`, `sha256_fingerprint` if present |

**Resolution:** `FLUTTER_SHELL_PATH` env var, or `../flutter_shell` from `process.cwd()`.

**COOLIFY DEPLOYMENT CAVEAT:** the admin_panel container must include the `flutter_shell/` directory at a sibling path to the Next.js app, OR `FLUTTER_SHELL_PATH` must be set. If using the default Nixpacks build, add a post-install step to copy `flutter_shell/` into the image, OR switch to a Dockerfile that `COPY`s the full repo.

### Still pending (Phase 5)

- [ ] Run `flutterfire configure` against the shared Firebase project
- [ ] End-to-end test: create app in admin → download ZIP → `flutter pub get` → `flutter build apk --release`
- [ ] Verify substitutions work on a real-world package name like `com.maximoney.credit`

## ⏳ Phase 5 — Deployment (NOT STARTED)

- [ ] Push admin_panel/ to GitHub
- [ ] SSH into Hetzner
- [ ] Install Coolify
- [ ] Deploy admin_panel via Coolify
- [ ] Run Supabase migration
- [ ] Configure domain + SSL
- [ ] Set env vars in Coolify
- [ ] Test `/api/config/<test-id>` endpoint
- [ ] Create first app in admin panel
- [ ] Download Flutter ZIP
- [ ] Build signed APK locally
- [ ] Install on Nevaid's phone
- [ ] End-to-end test
