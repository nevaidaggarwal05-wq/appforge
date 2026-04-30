# Adding a new app to AppForge

End-to-end checklist for taking a webapp from "I have a URL" to "shipping
to Play Store + TestFlight." Designed so you can work down the list
linearly and never have to context-switch back.

There are two flows:

- **Single app**: scaffold one app interactively. Best when you're
  setting up the very first one or want to think carefully.
- **Batch**: scaffold N apps from a CSV. Best when you have ≥3 apps
  to onboard and want to set them all up before doing the per-app
  console work.

---

## Single-app flow

```bash
# 1. Bootstrap a starter app.yaml
scripts/new-app.sh cashloop                # writes apps/cashloop/app.yaml
                                            # with sane placeholders

# 2. Edit apps/cashloop/app.yaml
#    Fill at least: display, package, webview_url, theme_color, accent_color.
#    Externally-issued IDs (appforge_app_id, firebase_android_app_id,
#    admob_app_id_*, keystore_sha256) can stay as placeholders for now.

# 3. Render the overrides from the YAML
scripts/new-app.sh cashloop                # idempotent regen

# 4. Sync into the build dir
scripts/sync-app.sh cashloop

# 5. Verify Android compiles (won't run yet — needs google-services.json)
cd ~/Desktop/builds/cashloop && flutter pub get
```

The remaining steps (Firebase, AdMob, keystore, admin panel, Play /
App Store entries) are below. Each one feeds a value back into
`apps/cashloop/app.yaml`. After every edit, re-run
`scripts/new-app.sh cashloop && scripts/sync-app.sh cashloop` to
propagate.

---

## Batch flow (3+ apps)

```bash
# 1. Copy the template, open it in Numbers / Excel / Google Sheets
cp docs/new-apps-template.csv ~/Desktop/my-apps.csv
open ~/Desktop/my-apps.csv

# 2. Add a row per app. Required columns: slug, display, package,
#    webview_url. Optional columns can stay blank — defaults apply.

# 3. Run the batch
scripts/batch-new-apps.sh ~/Desktop/my-apps.csv
```

This writes `apps/<slug>/app.yaml` for each row and runs `new-app.sh`
on each. From here the per-app external steps below apply to each.

---

## Per-app external setup

You only do these once per app. Everything below ends with a value
that gets pasted into `apps/<slug>/app.yaml` — then re-run
`scripts/new-app.sh <slug>` to bake it into the overrides.

### 1. Admin panel — create the app row

1. Open the admin panel (`https://flutteradmin.valuecreateventures.top` or
   whatever `appforge_api_base_url` is set to)
2. Apps → New app → fill in display, URL, theme/accent colors
3. Save. Copy the row's UUID from the URL bar (e.g. `…/apps/24984694-…/edit`)
4. Paste the UUID into `apps/<slug>/app.yaml` as `appforge_app_id`

### 2. Firebase — Android + iOS apps

One Firebase **project** can hold many apps. Reuse `appforge-push` for
all of them (the project name is set in `app.yaml` as `firebase_project`).

**Android side:**
1. [Firebase Console](https://console.firebase.google.com) → `appforge-push` → Add App → Android
2. Package name = the `package` from `app.yaml` (e.g. `com.cashloop.app`)
3. Download `google-services.json`, place at
   `apps/<slug>/overrides/android/app/google-services.json`
4. Copy the **App ID** (looks like `1:767214826244:android:HEXHEX`) into
   `app.yaml` as `firebase_android_app_id`

**iOS side** (only if you'll ship to App Store):
1. Same project → Add App → iOS
2. Bundle ID = same as the Android `package` (we use one ID for both)
3. Download `GoogleService-Info.plist`, place at
   `apps/<slug>/overrides/ios/Runner/GoogleService-Info.plist`

### 3. AdMob — App ID per platform

Per Google's policy each platform needs its own AdMob app entry.

1. [AdMob console](https://apps.admob.com) → Apps → Add App
2. Pick "Yes, my app is published" if it is, else "No"
3. Platform: Android. Save → copy the `ca-app-pub-XXX~YYY` App ID.
4. Repeat for iOS — same display name, separate App ID.
5. Paste into `app.yaml`:
   - `admob_app_id_android: ca-app-pub-…~…`
   - `admob_app_id_ios:     ca-app-pub-…~…`
6. Also enter the Android App ID in the admin panel (App config → AdMob
   → "AdMob App ID") so the live config and the built APK stay aligned.

> Until you have real IDs, the templates use Google's official **test**
> placeholders. Keeping those in is fine for development — your test
> ads won't generate revenue, but won't get your account banned either.

### 4. Android keystore

```bash
keytool -genkey -v \
  -keystore ~/Desktop/<slug>-keystore.jks \
  -alias <slug> \
  -keyalg RSA -keysize 2048 -validity 10000
```

It'll prompt for a store password, key password, and your name/org.
**Save these in your password manager** — losing them means you can
never push an update for that package name. There is no recovery.

Get the SHA-256 fingerprint:
```bash
keytool -list -v -keystore ~/Desktop/<slug>-keystore.jks -alias <slug> | grep SHA256
```

Paste the colon-separated hex string into `app.yaml` as
`keystore_sha256`.

You also need a `key.properties` next to the keystore — only kept on
your machine, never committed:
```bash
cat > ~/Desktop/builds/<slug>/android/key.properties <<EOF
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=<slug>
storeFile=/Users/<you>/Desktop/<slug>-keystore.jks
EOF
```
(`scripts/sync-app.sh` excludes `key.properties` from rsync, so this
file survives every sync.)

### 5. Launcher icons + adaptive icon foreground

5 dpi buckets to fill. The fastest path is the
[Android Asset Studio launcher generator](https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html).
Drop the resulting `mipmap-*/ic_launcher.png` files into
`apps/<slug>/overrides/android/app/src/main/res/`.

For the adaptive icon (Android 8+ circular/squircle/teardrop), use the
[Adaptive Icon generator](https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html)'s
foreground export → `drawable-*/ic_launcher_foreground.png`.

Background color comes from `colors.xml` `ic_launcher_background`
(currently `#FFFFFF`). Edit the override colors.xml if you want a
different bg.

### 6. iOS app icons

iOS wants 18 sizes inside `Assets.xcassets/AppIcon.appiconset/`. Use
[appicon.co](https://www.appicon.co), upload your 1024×1024, download
the iOS bundle, copy the contents into
`apps/<slug>/overrides/ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

### 7. App Links / Universal Links

The OAuth and "open this URL in the app" UX rely on the system
verifying that the app is the legitimate handler of the domain.

**Android** — host an `assetlinks.json` at
`https://<webview_host>/.well-known/assetlinks.json`. The scaffolder
already wrote a templated copy at
`apps/<slug>/overrides/docs/hosting/assetlinks_TEMPLATE.json` with the
right package + SHA256. Upload that file to your domain's well-known
path. (Use [the verifier](https://developers.google.com/digital-asset-links/tools/generator)
to confirm.)

**iOS** — host an `apple-app-site-association` (no extension) at
`https://<webview_host>/.well-known/apple-app-site-association`. Format:
```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "<TEAM_ID>.<package>",
      "paths": ["*"]
    }]
  }
}
```
The `<TEAM_ID>` shows up in App Store Connect → Membership → Team ID.

### 8. Play Console — app entry + Fastlane service account

Set up once per app (and once per machine for the service account).

1. [Play Console](https://play.google.com/console) → Create App
2. Fill in name, language, free/paid, content rating
3. Upload a manual first AAB to Internal Testing
   (`scripts/release.sh <slug>` produces the AAB at
   `~/Desktop/builds/<slug>/out/<slug>-v…aab`)
4. Service account for fastlane upload — see `docs/FASTLANE.md` § Android.
   Save the JSON to `~/Desktop/<slug>-play-service-account.json`
   (the path is what the `.env.default` already points at).

### 9. App Store Connect (after $99 enrollment)

See `docs/FASTLANE.md` § iOS. Once-per-app: create the app entry with
the matching bundle ID. Once-per-team (not per-app): generate the App
Store Connect API key.

---

## Sanity-check before each ship

```bash
scripts/doctor.sh <slug>
```

Runs through every per-app prerequisite (code health, Android assets,
signing, fastlane creds, iOS assets, hosting) and tells you exactly
what's still missing with `✓` / `⚠` / `✗` markers. Exits 0 when Android
can ship, non-zero otherwise. iOS warnings never fail the exit — they're
informational since iOS often legitimately lags behind Apple enrolment.
Live-checks the `https://<webview_host>/.well-known/` endpoints with
curl too — catches "I uploaded the file but the web server didn't pick
it up" issues.

## After everything's wired

```bash
scripts/new-app.sh <slug>          # final regen with all real IDs
scripts/sync-app.sh <slug>         # propagate
scripts/doctor.sh <slug>           # confirm green
scripts/ship.sh <slug> patch       # bump → commit → upload to Internal + TestFlight
```

For routine releases after the first one, only the last command is
needed. The new-app script is idempotent and can be re-run any time
you change a value in `app.yaml`.

---

## What the scaffolder does NOT do (yet)

- **Doesn't talk to the admin panel API** to create the app row. You
  click that in the admin UI, paste the UUID back. Trying to automate
  it would couple us to the admin panel auth flow — not worth it for
  now.
- **Doesn't create Firebase apps via Firebase CLI.** Same reason —
  could be added when we have ≥10 apps, currently the manual click
  is faster than wiring `firebase apps:create`.
- **Doesn't generate launcher icons.** The web tools above are quick
  enough; automating iconography for 20 brands is a separate project.
- **Doesn't create AdMob apps.** No public API.
- **Doesn't generate the keystore.** Refused on purpose — the keystore
  + passwords need to be in your control, not in a script that could
  end up logging them anywhere.

These are the parts where humans-in-loop is the right answer. The
scaffolder takes care of the dozen or so files that DO have a single
correct shape.
