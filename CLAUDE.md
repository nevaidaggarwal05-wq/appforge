# CLAUDE.md — conventions for AppForge v5

**Read this before editing anything.** Every rule here exists because
breaking it has caused a real bug on this project.

---

## Source of truth — where to edit

| You want to change… | Edit this | NOT this |
|---|---|---|
| Shell code that applies to every app (services, screens, widgets, WebView behaviour) | `flutter_shell/lib/`, `flutter_shell/android/`, or `flutter_shell/ios/` | anything under `~/Desktop/builds/` |
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

Two paths:

**Local-only builds** (when iterating, or when you want to upload by hand):
```bash
./scripts/bump-version.sh <app> patch|minor|major   # bump app.yaml + pubspec + gradle in sync
./scripts/release.sh <app>                          # Android: sync → build AAB → copy to out/
./scripts/release-ios.sh <app>                      # iOS:     sync → pod install → build IPA
```

**Auto-publish via Fastlane** (the normal path once creds are set up — see `docs/FASTLANE.md`):
```bash
./scripts/ship.sh <app>                             # bump → commit → upload AAB to Internal Testing + IPA to TestFlight
./scripts/fastlane.sh <app> android promote rollout:0.1   # internal → production at 10%
./scripts/fastlane.sh <app> ios promote                   # submit latest TestFlight build for App Store review
```

`ship.sh` auto-skips iOS if the App Store Connect API key file isn't present, so it works fine pre-Apple-Dev-enrollment — Android still ships.

Do NOT:
- Run `flutter build` directly in `~/Desktop/builds/<app>/` unless you're iterating locally and will discard the output
- Hand-copy AABs / IPAs out of `build/...` — the release scripts do this with the right name
- Bump `versionCode` in one file and forget the other two — `bump-version.sh` keeps `app.yaml`, `pubspec.yaml`, and `android/app/build.gradle` in sync. iOS reads its version from `pubspec.yaml` automatically (no separate Info.plist edit), so bumping pubspec covers both platforms
- Commit credentials. The per-app `.env.default` under `apps/<app>/overrides/fastlane/` only contains *paths* to credentials; the actual JSON / .p8 files live in `~/Desktop/` and are never tracked

Canonical artifact names: `<app>-v<version_name>-code<version_code>.{aab,apk,ipa}`
Canonical output path:    `~/Desktop/builds/<app>/out/`

### iOS specifics

- iOS scaffolding lives at `flutter_shell/ios/`. The Xcode project, Info.plist, Podfile, AppDelegate, and SceneDelegate are all in the shell — per-app overrides go under `apps/<slug>/overrides/ios/`.
- Min iOS deployment target: **14.0** (set in `Podfile` + `Runner.xcodeproj/project.pbxproj`). Don't drop below this without checking Firebase/AdMob SDK requirements.
- **Bundle ID is xcconfig-driven.** `Runner.xcodeproj` references `$(APP_BUNDLE_IDENTIFIER)`. Each app provides its real bundle ID via `apps/<slug>/overrides/ios/Flutter/App.xcconfig`. The shell ships an `App.xcconfig.example` showing the contract.
- **Per-app Info.plist override is whole-file replacement.** rsync's overlay copies the file wholesale — there is no key-merge. So per-app overrides must contain every key, not just the differences. Maximoney's lives at `apps/maximoney/overrides/ios/Runner/Info.plist`.
- **Apple Developer enrolment ($99/yr) is required to ship.** Without it, `release-ios.sh` falls back to producing an unsigned `.app` for build-pipeline verification only — it cannot be uploaded to TestFlight or the App Store.
- **No first-party iOS in-app-update API.** Forced upgrades on iOS go through `force_update_screen.dart` (admin-driven `force_update_version`). The Play Store In-App Update flow in `splash_screen.dart` is gated to `Platform.isAndroid`.

### Fastlane

- The shell ships a generic `Fastfile` at `flutter_shell/fastlane/Fastfile` with lanes that read per-app values from env vars — never hardcode an app name in there.
- Per-app `Appfile` + `.env.default` go under `apps/<slug>/overrides/fastlane/`. `.env.default` contains *paths* to credentials, not the credentials themselves.
- A single App Store Connect API key works for all apps under one Apple Developer team — don't create per-app keys.
- Don't add `match` for iOS code-signing yet (single-dev setup, ASC API key + Xcode automatic signing handles it). Revisit when onboarding a second engineer.
- `Gemfile.lock` lives in the build dir only and is excluded from sync — don't try to commit it from `~/Desktop/builds/`.

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
- **Predictive back gesture is enabled.** Android 14+ shows the new
  back-swipe preview animation because `enableOnBackInvokedCallback="true"`
  is set in the manifest. The Dart side already uses `PopScope`, which
  is compatible with the new `OnBackInvokedCallback` API. Don't disable.
- **AdMob App ID is build-time, banner unit ID is runtime.** Google's
  MobileAds SDK reads the App ID from AndroidManifest meta-data /
  iOS Info.plist `GADApplicationIdentifier` at SDK init, before any
  Dart runs — it cannot be admin-panel-driven. Banner unit ID is read
  on every config refresh and IS admin-panel-driven. The shell manifest
  uses the Gradle placeholder `${admobAppId}`; each app sets it via
  `manifestPlaceholders.admobAppId` in its `build.gradle` override.
- **iOS screenshot prevention is universal, Android is config-driven.**
  iOS hides the window on `applicationWillResignActive` regardless of
  the `screenshot_block` admin flag (universal app-switcher hiding is
  conventional iOS behavior). Android applies FLAG_SECURE only when
  the admin flag is true. Don't try to make these symmetric.

---

## When in doubt

- Read `docs/ARCHITECTURE.md` first.
- Follow the existing file layout — don't invent new top-level dirs.
- Ask before restructuring anything.
