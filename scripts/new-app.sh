#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# new-app.sh <slug>
#
# Scaffolds (or REGENERATES) every text override under
# apps/<slug>/overrides/ from apps/<slug>/app.yaml.
#
# Two modes:
#
#   1. FIRST RUN (no apps/<slug>/app.yaml exists):
#      Writes a starter app.yaml from the template. You then edit it
#      with real values and re-run this script.
#
#   2. REGEN RUN (app.yaml exists):
#      Reads app.yaml, renders every template under
#      scripts/templates/new-app/ with substitutions, writes the
#      results into apps/<slug>/overrides/. Idempotent — safe to
#      run repeatedly. Existing binary assets (launcher icons,
#      google-services.json) are left untouched.
#
# After running, do `scripts/sync-app.sh <slug>` to propagate to the
# build dir. See docs/NEW_APP_GUIDE.md for the full per-app onboarding
# checklist (Firebase, AdMob, Play Console, App Store Connect).
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "usage: scripts/new-app.sh <slug>     # e.g. cashloop, paywise" >&2
  exit 2
fi

# Slug-format guard. Lowercase letters, digits, underscore — must
# start with a letter (Android applicationId rules later down the
# line). Catches "MaxiMoney" / "12cashloop" / "cash-loop" early.
if ! [[ "$SLUG" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "error: slug must be lowercase letters/digits/underscore, starting with a letter" >&2
  echo "       got: '$SLUG'" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPL_DIR="$ROOT/scripts/templates/new-app"
APP_DIR="$ROOT/apps/$SLUG"
YAML="$APP_DIR/app.yaml"

if [[ ! -d "$TMPL_DIR" ]]; then
  echo "error: template dir missing at $TMPL_DIR" >&2; exit 1
fi

# ── Mode 1: bootstrap a fresh app.yaml ───────────────────────────
if [[ ! -f "$YAML" ]]; then
  mkdir -p "$APP_DIR"
  # Render the app.yaml template with sensible defaults so it parses
  # cleanly even before the user fills in the externally-issued IDs.
  DEFAULT_PACKAGE="com.${SLUG}.app"
  sed \
    -e "s|{{SLUG}}|$SLUG|g" \
    -e "s|{{DISPLAY_NAME}}|$SLUG|g" \
    -e "s|{{PACKAGE}}|$DEFAULT_PACKAGE|g" \
    -e "s|{{WEBVIEW_URL}}|https://example.com|g" \
    -e "s|{{OAUTH_SCHEME}}|$SLUG|g" \
    -e "s|{{THEME_COLOR}}|#1A1A2E|g" \
    -e "s|{{ACCENT_COLOR}}|#E94560|g" \
    -e "s|{{SHARE_MESSAGE}}|Check out $SLUG|g" \
    -e "s|{{APPFORGE_API_BASE_URL}}|https://flutteradmin.valuecreateventures.top|g" \
    -e "s|{{APPFORGE_APP_ID}}|00000000-0000-0000-0000-000000000000|g" \
    -e "s|{{FIREBASE_PROJECT}}|appforge-push|g" \
    -e "s|{{FIREBASE_ANDROID_APP_ID}}|REPLACE_AFTER_FIREBASE_SETUP|g" \
    -e "s|{{ADMOB_APP_ID_ANDROID}}|ca-app-pub-3940256099942544~3347511713|g" \
    -e "s|{{ADMOB_APP_ID_IOS}}|ca-app-pub-3940256099942544~1458002511|g" \
    -e "s|{{KEYSTORE_PATH}}|~/Desktop/${SLUG}-keystore.jks|g" \
    -e "s|{{KEYSTORE_ALIAS}}|$SLUG|g" \
    -e "s|{{KEYSTORE_SHA256}}|REPLACE_AFTER_KEYSTORE_GENERATED|g" \
    -e "s|{{BUILD_DIR}}|~/Desktop/builds/$SLUG|g" \
    -e "s|{{OUT_DIR}}|~/Desktop/builds/$SLUG/out|g" \
    -e "s|{{VERSION_NAME}}|1.0.0|g" \
    -e "s|{{VERSION_CODE}}|1|g" \
    "$TMPL_DIR/app.yaml.tmpl" > "$YAML"

  cat <<EOF
✓ Created starter $YAML

Next:
  1. Edit $YAML with real values (display name, webview URL, brand colors).
  2. Run scripts/new-app.sh $SLUG again to scaffold the overrides.
  3. See docs/NEW_APP_GUIDE.md for the checklist of external setup
     (Firebase, AdMob, keystore, admin panel) and what IDs to fill in.
EOF
  exit 0
fi

# ── Mode 2: render overrides from existing app.yaml ──────────────
echo "▶ regenerating overrides for $SLUG from $YAML"

# Read every value we need. Anything we look up below MUST exist in
# the YAML — fail loudly if not, since silent defaults at this stage
# bake placeholders into Android manifests.
read_yaml() {
  local key="$1"
  # Match "key:" at start of line, strip the key and following whitespace,
  # print whatever's left (preserves URLs / values with colons).
  local val
  val=$(awk -v k="$key" '
    $0 ~ "^"k":[[:space:]]" || $0 ~ "^"k":$" {
      sub("^"k":[[:space:]]*","")
      sub(/[[:space:]]+$/,"")
      print
      exit
    }
  ' "$YAML")
  if [[ -z "$val" ]]; then
    echo "error: $YAML missing required key: $key" >&2
    exit 1
  fi
  printf '%s' "$val"
}

DISPLAY_NAME=$(read_yaml display)
PACKAGE=$(read_yaml package)
WEBVIEW_URL=$(read_yaml webview_url)
OAUTH_SCHEME=$(read_yaml oauth_scheme)
THEME_COLOR=$(read_yaml theme_color)
ACCENT_COLOR=$(read_yaml accent_color)
SHARE_MESSAGE=$(read_yaml share_message)
APPFORGE_API_BASE_URL=$(read_yaml appforge_api_base_url)
APPFORGE_APP_ID=$(read_yaml appforge_app_id)
FIREBASE_PROJECT=$(read_yaml firebase_project)
FIREBASE_ANDROID_APP_ID=$(read_yaml firebase_android_app_id)
ADMOB_APP_ID_ANDROID=$(read_yaml admob_app_id_android)
ADMOB_APP_ID_IOS=$(read_yaml admob_app_id_ios)
KEYSTORE_PATH=$(read_yaml keystore_path)
KEYSTORE_ALIAS=$(read_yaml keystore_alias)
KEYSTORE_SHA256=$(read_yaml keystore_sha256)
BUILD_DIR=$(read_yaml build_dir)
OUT_DIR=$(read_yaml out_dir)
VERSION_NAME=$(read_yaml version_name)
VERSION_CODE=$(read_yaml version_code)

# Derived
WEBVIEW_HOST="${WEBVIEW_URL#http://}"
WEBVIEW_HOST="${WEBVIEW_HOST#https://}"
WEBVIEW_HOST="${WEBVIEW_HOST%%/*}"
PACKAGE_PATH=$(printf '%s' "$PACKAGE" | tr '.' '/')
# flutter_native_splash takes a hex string; if user provided a non-hex
# theme color we fall back to white so the splash plugin doesn't choke.
THEME_COLOR_OR_WHITE="$THEME_COLOR"
if ! [[ "$THEME_COLOR_OR_WHITE" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
  THEME_COLOR_OR_WHITE="#FFFFFF"
fi

# Render one template into a destination, doing all the substitutions.
render() {
  local tmpl="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  sed \
    -e "s|{{SLUG}}|$SLUG|g" \
    -e "s|{{DISPLAY_NAME}}|$DISPLAY_NAME|g" \
    -e "s|{{PACKAGE}}|$PACKAGE|g" \
    -e "s|{{PACKAGE_PATH}}|$PACKAGE_PATH|g" \
    -e "s|{{WEBVIEW_URL}}|$WEBVIEW_URL|g" \
    -e "s|{{WEBVIEW_HOST}}|$WEBVIEW_HOST|g" \
    -e "s|{{OAUTH_SCHEME}}|$OAUTH_SCHEME|g" \
    -e "s|{{THEME_COLOR}}|$THEME_COLOR|g" \
    -e "s|{{THEME_COLOR_OR_WHITE}}|$THEME_COLOR_OR_WHITE|g" \
    -e "s|{{ACCENT_COLOR}}|$ACCENT_COLOR|g" \
    -e "s|{{SHARE_MESSAGE}}|$SHARE_MESSAGE|g" \
    -e "s|{{APPFORGE_API_BASE_URL}}|$APPFORGE_API_BASE_URL|g" \
    -e "s|{{APPFORGE_APP_ID}}|$APPFORGE_APP_ID|g" \
    -e "s|{{FIREBASE_PROJECT}}|$FIREBASE_PROJECT|g" \
    -e "s|{{FIREBASE_ANDROID_APP_ID}}|$FIREBASE_ANDROID_APP_ID|g" \
    -e "s|{{ADMOB_APP_ID_ANDROID}}|$ADMOB_APP_ID_ANDROID|g" \
    -e "s|{{ADMOB_APP_ID_IOS}}|$ADMOB_APP_ID_IOS|g" \
    -e "s|{{KEYSTORE_PATH}}|$KEYSTORE_PATH|g" \
    -e "s|{{KEYSTORE_ALIAS}}|$KEYSTORE_ALIAS|g" \
    -e "s|{{KEYSTORE_SHA256}}|$KEYSTORE_SHA256|g" \
    -e "s|{{BUILD_DIR}}|$BUILD_DIR|g" \
    -e "s|{{OUT_DIR}}|$OUT_DIR|g" \
    -e "s|{{VERSION_NAME}}|$VERSION_NAME|g" \
    -e "s|{{VERSION_CODE}}|$VERSION_CODE|g" \
    "$tmpl" > "$dst"
}

OVR="$APP_DIR/overrides"
mkdir -p "$OVR"

# Per-template destinations. The MainActivity.kt path is special — it
# lands at android/app/src/main/kotlin/<package_path>/MainActivity.kt.
render "$TMPL_DIR/overrides/lib/app_config.dart.tmpl"                       "$OVR/lib/app_config.dart"
render "$TMPL_DIR/overrides/pubspec.yaml.tmpl"                              "$OVR/pubspec.yaml"
render "$TMPL_DIR/overrides/android/settings.gradle.tmpl"                   "$OVR/android/settings.gradle"
render "$TMPL_DIR/overrides/android/app/build.gradle.tmpl"                  "$OVR/android/app/build.gradle"
render "$TMPL_DIR/overrides/android/app/src/main/AndroidManifest.xml.tmpl"  "$OVR/android/app/src/main/AndroidManifest.xml"
render "$TMPL_DIR/overrides/android/app/src/main/res/values/strings.xml.tmpl" "$OVR/android/app/src/main/res/values/strings.xml"
render "$TMPL_DIR/overrides/android/app/src/main/res/values/colors.xml.tmpl"  "$OVR/android/app/src/main/res/values/colors.xml"
render "$TMPL_DIR/overrides/android/app/src/main/kotlin/MainActivity.kt.tmpl" "$OVR/android/app/src/main/kotlin/$PACKAGE_PATH/MainActivity.kt"
render "$TMPL_DIR/overrides/ios/Flutter/App.xcconfig.tmpl"                  "$OVR/ios/Flutter/App.xcconfig"
render "$TMPL_DIR/overrides/ios/Runner/Info.plist.tmpl"                     "$OVR/ios/Runner/Info.plist"
render "$TMPL_DIR/overrides/fastlane/Appfile.tmpl"                          "$OVR/fastlane/Appfile"
render "$TMPL_DIR/overrides/fastlane/.env.default.tmpl"                     "$OVR/fastlane/.env.default"
render "$TMPL_DIR/overrides/docs/hosting/assetlinks_TEMPLATE.json.tmpl"     "$OVR/docs/hosting/assetlinks_TEMPLATE.json"
render "$TMPL_DIR/overrides/docs/hosting/apple-app-site-association_TEMPLATE.json.tmpl" "$OVR/docs/hosting/apple-app-site-association_TEMPLATE.json"

cat <<EOF
✓ Regenerated $(find "$OVR" -name '*.dart' -o -name '*.yaml' -o -name '*.gradle' -o -name '*.xml' -o -name '*.kt' -o -name '*.plist' -o -name '*.xcconfig' -o -name 'Appfile' -o -name '.env.default' -o -name '*.json' 2>/dev/null | wc -l | tr -d ' ') override file(s) under $OVR/

Still TODO for $SLUG (binary assets + external IDs):
  • $OVR/android/app/google-services.json       — download from Firebase Console
  • $OVR/ios/Runner/GoogleService-Info.plist    — download from Firebase Console
  • Launcher icons (5 dpi buckets):              $OVR/android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png
  • Adaptive icon foreground:                    $OVR/android/app/src/main/res/drawable-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png
  • iOS app icons:                               $OVR/ios/Runner/Assets.xcassets/AppIcon.appiconset/
  • Keystore at $KEYSTORE_PATH (run keytool — see docs/NEW_APP_GUIDE.md)
  • Once keystore exists, fill keystore_sha256 in $YAML and re-run this script

Then:
  scripts/sync-app.sh $SLUG
  scripts/release.sh $SLUG          # produces a local AAB to verify
EOF
