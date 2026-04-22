# AppForge v5

White-label mobile-app platform. One admin panel drives N Android apps
that are thin Flutter WebView shells over a website of your choosing.
Remote config controls theming, features, splash, push, updates, etc.,
so most changes ship without a new Play Store release.

---

## Repository layout

```
handoff/
├── README.md                       ← this file
├── CLAUDE.md                       ← conventions that Claude Code must follow
│
├── admin_panel/                    ← Next.js 14 admin + /api/config/:appId
│   ├── app/                        ← routes (dashboard + API)
│   ├── lib/supabase/               ← DB client + types
│   ├── supabase/migrations/        ← schema (003 is the current head)
│   └── CLAUDE.md                   ← admin-panel specific notes
│
├── flutter_shell/                  ← generic Flutter WebView shell (template)
│   ├── lib/                        ← app_config.dart, services, screens, widgets
│   ├── android/                    ← shell defaults; per-app bits live under apps/
│   ├── ios/                        ← (iOS not shipped yet)
│   ├── l10n.yaml + lib/l10n/       ← English + Hindi ARB files
│   └── CLAUDE.md                   ← shell-specific notes
│
├── apps/                           ← per-app configuration (first-class)
│   └── maximoney/
│       ├── app.yaml                ← single source of truth: id, package, version
│       └── overrides/              ← files that replace shell defaults at build time
│           ├── lib/app_config.dart
│           ├── pubspec.yaml
│           ├── android/app/build.gradle
│           ├── android/app/src/main/AndroidManifest.xml
│           ├── android/app/src/main/res/values/{strings,colors}.xml
│           ├── android/app/src/main/kotlin/<pkg>/MainActivity.kt
│           ├── android/settings.gradle
│           └── docs/hosting/assetlinks_TEMPLATE.json
│
├── scripts/                        ← build automation — always go through these
│   ├── sync-app.sh   <app>         ← shell + overrides → ~/Desktop/builds/<app>/
│   ├── bump-version.sh <app> <bump>← patch/minor/major; updates yaml + pubspec + gradle
│   └── release.sh    <app>         ← sync → clean → build aab+apk → copy to out/
│
├── docs/                           ← architecture, API contract, audits
└── .gitignore
```

Artifacts live **outside** the repo at `~/Desktop/builds/<app>/` and are
regenerable at any time from `flutter_shell/` + `apps/<app>/overrides/`.
Never edit files under `~/Desktop/builds/<app>/` directly — they will be
overwritten by the next `sync-app.sh`.

---

## Releasing a new version (the only supported path)

```bash
cd ~/Desktop/handoff

# 1. Make your code change.
#    Shell-wide change         → edit flutter_shell/
#    App-specific change       → edit apps/<app>/overrides/

# 2. Bump the version (optional — only if shipping).
./scripts/bump-version.sh maximoney patch    # or minor / major

# 3. Commit everything so the git ref in BUILD_INFO.md is meaningful.
git add -A && git commit -m "…"  && git push

# 4. Build signed AAB + APK.
./scripts/release.sh maximoney

# Artifacts appear in ~/Desktop/builds/maximoney/out/
#   maximoney-v<name>-code<code>.aab   → upload to Play Console
#   maximoney-v<name>-code<code>.apk   → side-load for testing
#   BUILD_INFO.md                      → auto-appended with git ref
```

The scripts are idempotent — safe to re-run.

---

## Deployments

- **Admin panel:** Coolify on Hetzner, deployed from `admin_panel/` on
  every push to `main`. Env vars (Supabase service-role key, Firebase
  service-account JSON) live in Coolify, not in this repo.
- **Supabase:** schema migrations under `admin_panel/supabase/migrations/`.
  Claude does not have the service-role key locally — when a new
  migration is authored, the human applies it via the Supabase dashboard
  SQL Editor.
- **Flutter apps:** built locally via `scripts/release.sh`, uploaded to
  Play Console by hand.

---

## Quick links

- `docs/ARCHITECTURE.md` — system design
- `docs/API_CONTRACT.md` — `/api/config/:appId` JSON schema (critical for shell/admin parity)
- `docs/PHASE_STATUS.md` — what's done vs pending
- `docs/FEATURE_AUDIT_v1.1.1.md` — P0/P1/P2 feature audit that drove the v2 expansion
- `CLAUDE.md` — rules of the road for any Claude session working on this repo
