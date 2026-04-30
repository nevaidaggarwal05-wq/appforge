#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# doctor.sh <app-slug>
#
# Audits per-app readiness for shipping. Prints a categorised
# checklist (Code → Android assets → Android signing → Android
# publishing → iOS assets → iOS signing → iOS publishing → Hosting)
# with ✓ for ready, ⚠ for missing-but-not-fatal, ✗ for blocker.
#
# Exit code:
#   0 — Android-shippable (no ✗ in Android section)
#   1 — Android-blocked (at least one ✗ in Android section)
#
# iOS warnings never fail the exit — iOS may legitimately not be
# shipping yet (pre-$99 Apple Developer enrolment).
#
# Example:
#   scripts/doctor.sh maximoney
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "usage: scripts/doctor.sh <app-slug>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/$SLUG"
YAML="$APP_DIR/app.yaml"
OVR="$APP_DIR/overrides"

if [[ ! -f "$YAML" ]]; then
  echo "✗ apps/$SLUG/app.yaml not found — run scripts/new-app.sh $SLUG first" >&2
  exit 1
fi

# Pretty output. Falls back gracefully on terminals without color.
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
  BOLD=$(tput bold);     RESET=$(tput sgr0)
else
  GREEN=""; YELLOW=""; RED=""; BOLD=""; RESET=""
fi

ANDROID_BLOCKER=0  # any ✗ in Android section flips this
IOS_NOT_READY=0    # any ✗ in iOS section flips this (informational only)

ok()    { printf '  %s✓%s %s\n'  "$GREEN"  "$RESET" "$1"; }
warn()  { printf '  %s⚠%s %s\n'  "$YELLOW" "$RESET" "$1"; }
fail()  { printf '  %s✗%s %s\n'  "$RED"    "$RESET" "$1"; }
section() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"; }

# ── tiny YAML reader ─────────────────────────────────────────────
read_yaml() {
  awk -v k="$1" '
    $0 ~ "^"k":[[:space:]]" || $0 ~ "^"k":$" {
      sub("^"k":[[:space:]]*","")
      sub(/[[:space:]]+$/,"")
      print
      exit
    }
  ' "$YAML"
}

PACKAGE=$(read_yaml package)
KEYSTORE_PATH=$(read_yaml keystore_path)
KEYSTORE_ALIAS=$(read_yaml keystore_alias)
KEYSTORE_SHA256=$(read_yaml keystore_sha256)
ADMOB_ANDROID=$(read_yaml admob_app_id_android)
ADMOB_IOS=$(read_yaml admob_app_id_ios)
APPFORGE_ID=$(read_yaml appforge_app_id)
FIREBASE_AAID=$(read_yaml firebase_android_app_id)
BUILD_DIR=$(read_yaml build_dir)
WEBVIEW_URL=$(read_yaml webview_url)

# ~ expansion
KEYSTORE_PATH="${KEYSTORE_PATH/#\~/$HOME}"
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"

WEBVIEW_HOST="${WEBVIEW_URL#http://}"
WEBVIEW_HOST="${WEBVIEW_HOST#https://}"
WEBVIEW_HOST="${WEBVIEW_HOST%%/*}"

printf '%sDoctor: %s%s  (%s)\n' "$BOLD" "$SLUG" "$RESET" "$PACKAGE"

# ── 1. Code-side ──────────────────────────────────────────────────
section "Code"

if [[ -f "$OVR/lib/app_config.dart" ]]; then ok "lib/app_config.dart present"; else fail "lib/app_config.dart missing — run scripts/new-app.sh $SLUG"; ANDROID_BLOCKER=1; fi
if [[ -f "$OVR/pubspec.yaml" ]];           then ok "pubspec.yaml present";       else fail "pubspec.yaml missing";       ANDROID_BLOCKER=1; fi

# Version drift check
APPYAML_VC=$(read_yaml version_code)
PUBSPEC_V=$(grep -E "^version:" "$OVR/pubspec.yaml" 2>/dev/null | awk '{print $2}')
GRADLE_VC=$(grep -E "^[[:space:]]*versionCode " "$OVR/android/app/build.gradle" 2>/dev/null | awk '{print $2}')
PUBSPEC_VC="${PUBSPEC_V##*+}"
if [[ -n "$APPYAML_VC" && "$APPYAML_VC" == "$PUBSPEC_VC" && "$APPYAML_VC" == "$GRADLE_VC" ]]; then
  ok "version_code in sync ($APPYAML_VC) across app.yaml + pubspec + build.gradle"
else
  fail "version_code drift: app.yaml=$APPYAML_VC pubspec=$PUBSPEC_VC build.gradle=$GRADLE_VC — run scripts/bump-version.sh"
  ANDROID_BLOCKER=1
fi

# ── 2. Android assets ─────────────────────────────────────────────
section "Android assets"

if [[ -f "$OVR/android/app/google-services.json" ]]; then
  ok "google-services.json present"
else
  fail "google-services.json missing — download from Firebase Console → drop at $OVR/android/app/google-services.json"
  ANDROID_BLOCKER=1
fi

ICON_BUCKETS=(mdpi hdpi xhdpi xxhdpi xxxhdpi)
ICONS_FOUND=0
for d in "${ICON_BUCKETS[@]}"; do
  [[ -f "$OVR/android/app/src/main/res/mipmap-$d/ic_launcher.png" ]] && ICONS_FOUND=$((ICONS_FOUND+1))
done
if [[ $ICONS_FOUND -eq 5 ]]; then
  ok "launcher icons (all 5 dpi buckets)"
elif [[ $ICONS_FOUND -gt 0 ]]; then
  warn "launcher icons partial ($ICONS_FOUND/5 buckets) — Android Asset Studio fills all 5"
else
  warn "launcher icons missing — apps will use the default Flutter icon"
fi

# AdMob real vs test
if [[ "$ADMOB_ANDROID" == ca-app-pub-3940256099942544* ]]; then
  warn "admob_app_id_android still using Google's TEST ID — fine for dev, swap before public release"
elif [[ -z "$ADMOB_ANDROID" || "$ADMOB_ANDROID" == REPLACE* ]]; then
  fail "admob_app_id_android missing in app.yaml"
  ANDROID_BLOCKER=1
else
  ok "admob_app_id_android is a real production ID"
fi

# ── 3. Android signing ────────────────────────────────────────────
section "Android signing"

if [[ -f "$KEYSTORE_PATH" ]]; then
  ok "keystore file at $KEYSTORE_PATH"

  # Verify SHA256 matches if keytool available
  if command -v keytool >/dev/null 2>&1; then
    REAL_SHA=$(keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEYSTORE_ALIAS" -storepass:env STOREPASS 2>/dev/null | grep -E "^[[:space:]]*SHA256:" | awk '{print $2}')
    if [[ -z "$REAL_SHA" ]]; then
      # Try without password — keytool may prompt; we just skip silently
      warn "keystore SHA256 verify skipped (keytool needs storepass — set STOREPASS env to verify)"
    elif [[ "${REAL_SHA^^}" == "${KEYSTORE_SHA256^^}" ]]; then
      ok "keystore SHA256 in app.yaml matches the actual keystore"
    else
      fail "keystore SHA256 in app.yaml does NOT match the actual keystore — assetlinks will fail Play verification"
      ANDROID_BLOCKER=1
    fi
  fi
else
  fail "keystore not found at $KEYSTORE_PATH — generate with keytool (see NEW_APP_GUIDE step 4)"
  ANDROID_BLOCKER=1
fi

if [[ -z "$KEYSTORE_SHA256" || "$KEYSTORE_SHA256" == REPLACE* ]]; then
  fail "keystore_sha256 not set in app.yaml — run keytool -list -v + paste fingerprint"
  ANDROID_BLOCKER=1
else
  ok "keystore_sha256 set in app.yaml"
fi

KEY_PROPS="$BUILD_DIR/android/key.properties"
if [[ -f "$KEY_PROPS" ]]; then
  ok "key.properties present at $KEY_PROPS (never committed; survives sync)"
else
  fail "key.properties missing at $KEY_PROPS — release builds will be unsigned/fail (see NEW_APP_GUIDE step 4)"
  ANDROID_BLOCKER=1
fi

# ── 4. Android publishing (Fastlane) ──────────────────────────────
section "Android publishing"

ENV_DEFAULT="$OVR/fastlane/.env.default"
if [[ -f "$ENV_DEFAULT" ]]; then
  ok "fastlane/.env.default present"

  # Source it in a subshell to read paths
  PLAY_JSON=$(awk -F= '/^PLAY_SERVICE_ACCOUNT_JSON=/{print $2}' "$ENV_DEFAULT" | tr -d '"' | tr -d "'")
  PLAY_JSON="${PLAY_JSON/#\~/$HOME}"
  if [[ -n "$PLAY_JSON" && -f "$PLAY_JSON" ]]; then
    ok "Play Console service account JSON found at $PLAY_JSON"
  else
    fail "Play Console service account JSON not found at $PLAY_JSON — fastlane upload will fail (see NEW_APP_GUIDE step 8)"
    ANDROID_BLOCKER=1
  fi
else
  fail "fastlane/.env.default missing — run scripts/new-app.sh $SLUG to regenerate"
  ANDROID_BLOCKER=1
fi

# ── 5. iOS assets ─────────────────────────────────────────────────
section "iOS assets"

if [[ -f "$OVR/ios/Runner/GoogleService-Info.plist" ]]; then
  ok "GoogleService-Info.plist present"
else
  fail "GoogleService-Info.plist missing — download from Firebase Console → $OVR/ios/Runner/"
  IOS_NOT_READY=1
fi

if [[ -d "$OVR/ios/Runner/Assets.xcassets/AppIcon.appiconset" ]] && [[ -n "$(ls "$OVR/ios/Runner/Assets.xcassets/AppIcon.appiconset" 2>/dev/null)" ]]; then
  ok "iOS app icons present (Assets.xcassets/AppIcon.appiconset)"
else
  fail "iOS app icons missing — generate at appicon.co + drop into $OVR/ios/Runner/Assets.xcassets/AppIcon.appiconset/"
  IOS_NOT_READY=1
fi

if [[ -f "$OVR/ios/Flutter/App.xcconfig" ]]; then
  ok "ios/Flutter/App.xcconfig present (xcconfig-driven bundle ID)"
else
  fail "App.xcconfig missing — run scripts/new-app.sh $SLUG"
  IOS_NOT_READY=1
fi

if [[ "$ADMOB_IOS" == ca-app-pub-3940256099942544* ]]; then
  warn "admob_app_id_ios still using Google's TEST ID — swap before public release"
elif [[ -z "$ADMOB_IOS" || "$ADMOB_IOS" == REPLACE* ]]; then
  fail "admob_app_id_ios missing in app.yaml"
  IOS_NOT_READY=1
else
  ok "admob_app_id_ios is a real production ID"
fi

# ── 6. iOS publishing (Fastlane) ──────────────────────────────────
section "iOS publishing"

if [[ -f "$ENV_DEFAULT" ]]; then
  ASC_KEY=$(awk -F= '/^ASC_KEY_PATH=/{print $2}' "$ENV_DEFAULT" | tr -d '"' | tr -d "'")
  ASC_KEY="${ASC_KEY/#\~/$HOME}"
  ASC_KEY_ID=$(awk -F= '/^ASC_KEY_ID=/{print $2}' "$ENV_DEFAULT" | tr -d '"' | tr -d "'")
  ASC_ISSUER=$(awk -F= '/^ASC_ISSUER_ID=/{print $2}' "$ENV_DEFAULT" | tr -d '"' | tr -d "'")

  if [[ -n "$ASC_KEY" && -f "$ASC_KEY" ]]; then
    ok "App Store Connect API key (.p8) at $ASC_KEY"
  else
    fail "ASC API key (.p8) not found at $ASC_KEY — needs Apple Developer enrolment (\$99/yr)"
    IOS_NOT_READY=1
  fi
  if [[ -n "$ASC_KEY_ID" && "$ASC_KEY_ID" != REPLACE* ]]; then
    ok "ASC_KEY_ID set"
  else
    fail "ASC_KEY_ID not set in fastlane/.env.default"
    IOS_NOT_READY=1
  fi
  if [[ -n "$ASC_ISSUER" && "$ASC_ISSUER" != REPLACE* ]]; then
    ok "ASC_ISSUER_ID set"
  else
    fail "ASC_ISSUER_ID not set in fastlane/.env.default"
    IOS_NOT_READY=1
  fi
fi

# ── 7. Hosting ────────────────────────────────────────────────────
section "Hosting (well-known files on $WEBVIEW_HOST)"

ASSETLINKS="$OVR/docs/hosting/assetlinks_TEMPLATE.json"
if [[ -f "$ASSETLINKS" ]]; then
  if grep -q "REPLACE_WITH" "$ASSETLINKS"; then
    fail "assetlinks_TEMPLATE.json has placeholders — re-run scripts/new-app.sh $SLUG to bake real values"
    ANDROID_BLOCKER=1
  else
    ok "assetlinks_TEMPLATE.json populated (still need to host at https://$WEBVIEW_HOST/.well-known/assetlinks.json)"
  fi

  # Live host check (best-effort, 5s timeout, non-fatal)
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS --max-time 5 "https://$WEBVIEW_HOST/.well-known/assetlinks.json" >/dev/null 2>&1; then
      ok "assetlinks.json reachable at https://$WEBVIEW_HOST/.well-known/assetlinks.json"
    else
      warn "assetlinks.json not yet hosted at https://$WEBVIEW_HOST/.well-known/ — App Links won't auto-verify"
    fi
  fi
fi

AASA="$OVR/docs/hosting/apple-app-site-association_TEMPLATE.json"
if [[ -f "$AASA" ]]; then
  if grep -q "REPLACE_WITH_TEAM_ID" "$AASA"; then
    warn "apple-app-site-association still has REPLACE_WITH_TEAM_ID — fill in after Apple Developer enrolment"
    IOS_NOT_READY=1
  else
    ok "apple-app-site-association populated"
  fi

  if command -v curl >/dev/null 2>&1; then
    if curl -fsS --max-time 5 "https://$WEBVIEW_HOST/.well-known/apple-app-site-association" >/dev/null 2>&1; then
      ok "apple-app-site-association reachable at https://$WEBVIEW_HOST/.well-known/"
    else
      warn "apple-app-site-association not yet hosted — Universal Links won't verify"
    fi
  fi
fi

# ── Summary ──────────────────────────────────────────────────────
echo
if [[ $ANDROID_BLOCKER -eq 0 ]]; then
  printf "%s✓ Android shippable.%s  Run: scripts/ship.sh %s patch  (or scripts/release.sh %s for AAB only)\n" "$GREEN" "$RESET" "$SLUG" "$SLUG"
else
  printf "%s✗ Android NOT shippable.%s  Fix the ✗ items above first.\n" "$RED" "$RESET"
fi

if [[ $IOS_NOT_READY -eq 0 ]]; then
  printf "%s✓ iOS shippable.%s     Run: scripts/ship.sh %s patch both\n" "$GREEN" "$RESET" "$SLUG"
else
  printf "%s⚠ iOS not yet shippable%s — items above need attention (typically blocked on Apple Developer enrolment).\n" "$YELLOW" "$RESET"
fi
echo

exit $ANDROID_BLOCKER
