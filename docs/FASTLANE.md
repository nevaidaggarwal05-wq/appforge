# Fastlane — automated Play Store + TestFlight uploads

Fastlane is wired into the AppForge shell as a first-class part of
the release workflow. After the one-time per-machine + per-app setup
below, shipping a new version is:

```bash
scripts/ship.sh maximoney patch          # bump → commit → upload to both stores
```

That's the goal: once setup is done, you never touch Play Console or
App Store Connect for a routine release — just bump, commit, ship.

---

## How it's wired

| Layer | What lives there |
|---|---|
| `flutter_shell/Gemfile` | Pins fastlane version. Gets `bundle install`-ed in the per-app build dir. |
| `flutter_shell/fastlane/Fastfile` | Generic lanes (`android beta`, `ios beta`, `promote`, `doctor`). No per-app values — reads from env. |
| `flutter_shell/fastlane/Appfile` | Generic placeholders. Real values come from the per-app overlay. |
| `apps/<slug>/overrides/fastlane/Appfile` | Per-app `package_name` (Android) + `app_identifier` (iOS). |
| `apps/<slug>/overrides/fastlane/.env.default` | Per-app credential paths. **NEVER commit real keys here, only paths.** |
| `scripts/fastlane.sh` | Wrapper that syncs, sources env, and runs the lane in the build dir. |
| `scripts/ship.sh` | Meta-script: bump → commit → fastlane beta. |

The credentials themselves live in `~/Desktop/` (outside the git
repo) so they never accidentally get committed.

---

## One-time per-machine setup

```bash
# Ruby (macOS ships with one, but rbenv/asdf preferred for control)
gem install bundler

# Fastlane gem — installed into the build dir's vendor on first run.
# scripts/fastlane.sh runs `bundle install` automatically the first
# time, but you can do it now to verify:
cd ~/Desktop/builds/maximoney    # or whatever your first app is
bundle install
```

That's it. From here on, `scripts/fastlane.sh` and `scripts/ship.sh`
handle invocation.

---

## One-time per-app setup — Android

You'll do this once per Google Play Console app. The output is a
service-account JSON file the script reads on every upload.

### 1. Make sure the app exists in Play Console

Create the app entry in [Play Console](https://play.google.com/console)
manually the first time — Fastlane uploads builds, but it doesn't
create the app entry, the listing copy, or the screenshots. (You can
automate those later with `fastlane supply init`, but for the first
release just do it by hand.)

### 2. Upload a manual AAB to the Internal Testing track

Play Console requires at least one manually-uploaded build before the
API will accept uploads. Use the AAB from `scripts/release.sh maximoney`
for this initial upload.

### 3. Create the service account

1. [Google Cloud Console → Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
   under the project linked to your Play Console
2. **Create Service Account** → name it `appforge-publisher`
3. Skip the "grant access" step (we grant via Play Console, not IAM)
4. Open the new service account → **Keys** → **Add Key** → **JSON** →
   download. Save it to `~/Desktop/<app>-play-service-account.json`.

### 4. Grant the service account Play Console access

1. [Play Console → Users and permissions](https://play.google.com/console/u/0/developers/users-and-permissions)
2. **Invite new user** → paste the service-account email
   (`appforge-publisher@<project>.iam.gserviceaccount.com`)
3. **App permissions** → add the app(s) it should manage
4. **Account permissions** → grant:
   - View app information and download bulk reports
   - Manage production releases
   - Manage testing track releases
   - Manage store presence (only if you'll use `supply` for metadata)
5. Wait ~5 minutes for permissions to propagate.

### 5. Verify

```bash
scripts/fastlane.sh maximoney android doctor
```

Should print `Android ready ✓`.

### 6. Ship

```bash
scripts/ship.sh maximoney patch android
```

That bumps the version, commits, builds the AAB, and uploads to
Internal Testing. Promote to Production manually for the first few
releases (so you sanity-check the staged rollout), or:

```bash
scripts/fastlane.sh maximoney android promote rollout:0.1
```

---

## One-time per-app setup — iOS

**Requires the $99/yr Apple Developer enrollment.** Without it, the
iOS lanes hard-fail and `ship.sh` auto-skips iOS.

### 1. Apple Developer + App Store Connect setup

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/)
   ($99/yr, ~24-48h to approve)
2. In [App Store Connect](https://appstoreconnect.apple.com), create
   the app entry with bundle ID `com.maximoney.credit` (must match
   `apps/maximoney/overrides/fastlane/Appfile` and
   `apps/maximoney/overrides/ios/Flutter/App.xcconfig`)

### 2. Generate an App Store Connect API key (one key, all apps)

A single API key works for every app under your Apple Developer team
— you don't need a per-app key.

1. App Store Connect → **Users and Access** → **Integrations** → **Keys**
2. **Generate API Key** → name `AppForge`, access **App Manager**
3. Download the `.p8` file (one-time download — Apple won't show it
   again). Save to `~/Desktop/asc-api-key.p8`.
4. Note the **Key ID** (10-char string) and **Issuer ID** (UUID at
   top of the page).

### 3. Fill in the env file

Edit `apps/maximoney/overrides/fastlane/.env.default`:

```bash
ASC_KEY_PATH=~/Desktop/asc-api-key.p8
ASC_KEY_ID=ABCDE12345
ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000
```

These three values are what fastlane needs to authenticate to App
Store Connect.

### 4. Sign the app in Xcode

Even with API automation, the first build needs a signing identity
on this machine:

1. Open `~/Desktop/builds/maximoney/ios/Runner.xcworkspace` in Xcode
2. **Signing & Capabilities** → **Team** → pick your team
3. Toggle **Automatically manage signing** on
4. Run **Product → Archive** once to verify it builds

### 5. Verify

```bash
scripts/fastlane.sh maximoney ios doctor
```

### 6. Ship

```bash
scripts/ship.sh maximoney patch ios       # iOS only
# or
scripts/ship.sh maximoney patch both      # both stores
```

---

## When to use which lane

| Situation | Command |
|---|---|
| Routine release, both stores | `scripts/ship.sh <app>` |
| Hotfix, Android only | `scripts/ship.sh <app> patch android` |
| Major version, both | `scripts/ship.sh <app> major both` |
| Promote internal → production (10%) | `scripts/fastlane.sh <app> android promote rollout:0.1` |
| Increase rollout to 50% | `scripts/fastlane.sh <app> android promote rollout:0.5` |
| Submit TestFlight build for review | `scripts/fastlane.sh <app> ios promote` |
| Build locally, no upload | `scripts/fastlane.sh <app> android build` |
| Sanity-check creds | `scripts/fastlane.sh <app> doctor doctor` |

---

## What we deliberately skipped

- **`match` for iOS code-signing.** It's the right answer once you
  have a team or multiple machines, but for a solo dev with one Mac
  the App Store Connect API key + Xcode automatic signing is simpler
  and equally automated. Add `match` when you onboard a second engineer.
- **`supply init` for Play Store metadata.** The store listing
  (description, screenshots) is currently hand-managed in Play
  Console. Move it to fastlane when you're tired of editing the
  listing per-app for 20 apps — `supply` reads `fastlane/metadata/android/`.
- **`deliver init` for App Store metadata.** Same as above, iOS side.
- **Slack / discord notifications on release.** Add later via fastlane's
  `slack` action — costs nothing, useful once you're not the only one
  caring whether a build went through.
- **Crashlytics dSYM upload (iOS).** Firebase Crashlytics auto-uploads
  dSYMs in most cases now; if you start seeing un-symbolicated crashes,
  add the `upload_symbols_to_crashlytics` action to the `ios beta` lane.
