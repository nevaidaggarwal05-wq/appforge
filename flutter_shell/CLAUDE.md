# flutter_shell/CLAUDE.md

Generic Flutter WebView shell. Do NOT build from this directory
directly. Builds happen in `~/Desktop/builds/<app>/`, assembled by
`scripts/sync-app.sh <app>` from this shell plus
`apps/<app>/overrides/`.

## What belongs here

- Anything that should apply to every white-label app:
  services, screens, widgets, JS bridge, WebView config, i18n, the
  remote-config model, the core models.
- Shell-level defaults for Android (manifest, strings, colors) that
  the overrides layer can replace per app.

## What does NOT belong here

- App-specific IDs, package names, URLs, signing config, launcher
  icons, splash assets. Those go under `apps/<app>/overrides/`.
- Anything in `build/`, `.dart_tool/`, `android/.gradle/` — those are
  generated and ignored by git.

## If you're fixing a bug

- Fix it here if the bug exists in shell logic (every app is affected).
- Fix it under `apps/<app>/overrides/` only if the bug is
  configuration/branding-specific to that app.
- After fixing, run `scripts/sync-app.sh <app>` so the build dir
  reflects the change before you `flutter run`.

## Remote-config round-trip

If you're adding a new RemoteConfig field:

1. Add the field + default to `lib/core/models/remote_config_model.dart`.
2. Add a typed accessor to `lib/services/remote_config_service.dart`.
3. Mirror it in the admin-panel API route + Supabase migration.
4. Update `docs/API_CONTRACT.md` in the repo root.

The Dart side must have a safe fallback so an old admin paired with
a new shell (or vice versa) still boots.
