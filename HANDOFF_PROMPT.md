# 🤖 HANDOFF PROMPT — Paste this verbatim as your first message to Claude Code

You are taking over a multi-session build that was started in Claude.ai. The project is **AppForge v5** — a white-label mobile app platform for managing 20-30+ Flutter apps from a single admin panel.

## Your first action

**Read these files in this exact order, then summarize your understanding back to me before doing anything else:**

1. `docs/ARCHITECTURE.md` — system design overview
2. `docs/PHASE_STATUS.md` — what's done, what's not
3. `docs/API_CONTRACT.md` — the Flutter ↔ Backend JSON contract
4. `docs/BUGS_FIXED.md` — 9 bugs already caught and fixed; don't reintroduce them
5. `docs/PHASE_4_SPEC.md` — exact spec for the Flutter shell you're building
6. `admin_panel/supabase/migrations/001_initial_schema.sql` — database schema
7. `admin_panel/lib/supabase/types.ts` — TypeScript types (especially `RemoteConfigResponse`)
8. `admin_panel/app/api/config/[appId]/route.ts` — the endpoint Flutter will hit
9. `admin_panel/app/api/generator/[appId]/route.ts` — how Flutter ZIPs get generated

Then glance at the file tree of `admin_panel/` to see what else exists — don't read every file, just understand the structure.

## After you've read those files, respond with:

1. **One paragraph summary** of what the project does
2. **Your understanding of what's done** (admin_panel is complete) vs **what's pending** (Flutter shell)
3. **Confirmation** that you will:
   - NOT rebuild the admin_panel (it's done, bugs fixed)
   - NOT change the API contract
   - NOT re-add Firebase Remote Config or Firebase Analytics
   - Keep the splash screen
   - Use ONE shared Firebase project for FCM
4. **Any questions** before you start Phase 4

## About the owner

Nevaid Aggarwal — non-technical founder in Delhi, India. Mac Mini M-series. Goal: ship 20-30+ white-label Flutter apps, each wrapping a different website in a native shell with push notifications, biometric auth, force updates, etc.

His existing keystore (from Maximoney): `~/Desktop/maximoney-keystore.jks`
- password: `Maximoney@2024`
- alias: `maximoney`
- SHA-256: `53:93:9B:E7:5C:5C:E8:26:44:B3:DB:1E:C4:A7:5B:19:91:F8:AC:A2:4A:DF:ED:D5:E6:BE:E2:E6:1A:E9:CF:3C`

He will:
- Share credentials (Hetzner, domain, Supabase, Firebase, GitHub PAT) when you're ready
- ONLY test the final production APK after the backend is deployed (no intermediate testing)

## Phase 4 — Your main task

Build the complete Flutter shell (~35 files) per `docs/PHASE_4_SPEC.md`. This includes:

- `lib/app_config.dart` — per-app constants
- `lib/core/` — models, API client, offline cache, errors
- `lib/services/` — 10 services (remote_config REWRITTEN, biometric NEW, analytics NEW, etc.)
- `lib/screens/` — 6 screens (splash, bootstrap, webview, error screens)
- `lib/widgets/` — 2 widgets (WhatsApp button, update banner)
- `android/` — gradle, manifest, kotlin MainActivity
- `ios/` — AppDelegate.swift
- `pubspec.yaml`

## Phase 5 — After Phase 4 is approved

Deployment. You'll:
1. Ask Nevaid for credentials (Hetzner, domain, Supabase, Firebase, GitHub)
2. SSH into Hetzner, install Coolify
3. Push admin_panel/ to GitHub, connect to Coolify, deploy
4. Run Supabase migration
5. Test `/api/config/<test-app-id>` returns valid JSON
6. Generate first app's Flutter ZIP
7. Build signed APK locally on Nevaid's Mac
8. Nevaid installs on phone and tests end-to-end

## Workflow rules for this project

1. **Approval gates** — before each major step (start Phase 4, deploy, build APK), confirm with Nevaid
2. **Incremental** — build one service at a time, run `flutter analyze` between each, catch errors early
3. **No mysterious edits** — explain what you're changing and why
4. **Use the file tools liberally** — read before you write, verify after you write
5. **Track progress** — update `docs/PHASE_STATUS.md` as you complete things
6. **Defensive coding** — null checks, try/catch on all API calls, offline fallbacks

## How to start

Right now, just:
1. Read the 9 files listed above
2. Respond with your summary + questions
3. Wait for Nevaid to approve before writing any code

Go.
