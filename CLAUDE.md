# CLAUDE.md — conventions for AppForge v5

**Read this before editing anything.** Every rule here exists because
breaking it has caused a real bug on this project.

---

## Source of truth — where to edit

| You want to change… | Edit this | NOT this |
|---|---|---|
| Shell code that applies to every app (services, screens, widgets, WebView behaviour) | `flutter_shell/lib/` or `flutter_shell/android/` | anything under `~/Desktop/builds/` |
| Per-app metadata (id, package, URL, version) | `apps/<app>/app.yaml` + the matching file under `apps/<app>/overrides/` | the copy inside `~/Desktop/builds/<app>/` |
| Admin panel UI or API | `admin_panel/` | — |
| Database schema | a new numbered file in `admin_panel/supabase/migrations/` | never edit an already-applied migration |

**`~/Desktop/builds/<app>/` is GENERATED.** It's reconstituted from
`flutter_shell/` + `apps/<app>/overrides/` by `scripts/sync-app.sh`.
Any edit you make there will be overwritten on the next sync. This
has bitten us — previous sessions edited the build dir, the change
didn't make it into git, and the fix vanished on the next sync.

If something in the build dir needs to change:
1. If it's app-specific → add/edit it under `apps/<app>/overrides/`
2. If it applies to every app → edit `flutter_shell/`
3. Then `scripts/sync-app.sh <app>` to propagate.

---

## Building a release

Always go through the scripts:

```bash
./scripts/bump-version.sh <app> patch|minor|major   # updates yaml + pubspec + gradle together
./scripts/release.sh <app>                          # sync → build → copy to out/ with canonical name
```

Do NOT:
- Run `flutter build` directly in `~/Desktop/builds/<app>/` unless you're iterating locally and will discard the output
- Hand-copy AABs out of `build/app/outputs/` — `release.sh` does this with the right name
- Bump `versionCode` in one file and forget the other two (`app.yaml`, `pubspec.yaml`, `android/app/build.gradle` must all match) — `bump-version.sh` keeps them in sync

Canonical artifact names: `<app>-v<version_name>-code<version_code>.{aab,apk}`
Canonical output path:    `~/Desktop/builds/<app>/out/`

---

## API contract parity

The shell (`flutter_shell/lib/core/models/remote_config_model.dart`)
and the admin API (`admin_panel/app/api/config/[appId]/route.ts`) must
agree on every field name and type in the `/api/config/:appId` JSON
response. When adding a remote-config flag:

1. Author a migration with the new column + a sensible default.
2. Add the column to `admin_panel/lib/supabase/types.ts` and to the
   API route's response shape (with a `??` fallback so pre-migration
   rows don't break).
3. Add a field to the Dart model + an accessor in
   `services/remote_config_service.dart`.
4. Mirror the default on the Dart side so an old admin panel paired
   with a new shell still works.

`docs/API_CONTRACT.md` is the single source of truth for the shape.
Update it whenever the contract changes.

---

## Supabase migrations

Claude does NOT have the Supabase service-role key on this machine
(only `.env.local.example` is committed). When you author a migration:

- Commit the SQL file to `admin_panel/supabase/migrations/`
- Surface the SQL in your reply so the human can paste it into the
  Supabase dashboard SQL Editor
- Use `add column if not exists` and provide defaults so it's safe to
  re-run and safe to land before the admin-panel code that reads the
  column

Do not attempt to run migrations via any "smart" discovery of secrets.

---

## Git hygiene

- Only one live branch: `main`. Push directly.
- Never commit `key.properties`, keystore files, service-account JSON,
  or `.env.local`.
- `.gitignore` already covers `~/Desktop/builds/`, `node_modules`,
  `build/`, `.dart_tool/`, and the usual Flutter/Gradle cruft. If you
  find yourself staging anything from those paths, stop.
- Only commit when the user asks. Never amend — always a new commit.
- `~/Desktop/builds/` is not a git repo. Don't try to commit inside it.

---

## Known project-specific gotchas

- **Android WebView User-Agent.** The default Android WebView UA has
  a `"; wv"` marker that causes Razorpay and similar gateways to hide
  UPI intent options. `webview_screen.dart:_prepareUserAgent()` strips
  it. If you touch that file, preserve that logic or UPI payments
  break silently.
- **Host allowlist is permissive by default.** `_isAllowedHost()` only
  enforces the list when the admin sets a non-empty
  `extra_allowed_hosts`. Do not flip this default — 3-D Secure bank
  redirects need to stay in-WebView.
- **Cold-start speed.** `RemoteConfigService.initialize()` swaps in
  the cached config synchronously and refreshes over the network in
  the background. Do not re-await the fetch on the boot path.
- **Kotlin plugin pin.** Android tooling is on Kotlin 2.2.10 because
  `in_app_update` 4.2.5 requires it. Don't downgrade without checking
  that plugin.
- **NDK warning.** `jni` asks for NDK 28.2 while the project uses 27.0.
  Backward compatible; ignore unless the build actually fails.

---

## When in doubt

- Read `docs/ARCHITECTURE.md` first.
- Follow the existing file layout — don't invent new top-level dirs.
- Ask before restructuring anything.
