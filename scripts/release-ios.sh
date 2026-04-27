#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# release-ios.sh <app>
#
# iOS counterpart to release.sh. Calls sync → pod install → build IPA,
# then drops the artifact in <build_dir>/out/ with a canonical name.
#
# Prereqs:
#   • macOS with Xcode + CocoaPods installed (`gem install cocoapods`)
#   • Apple Developer account ($99/yr) — required for signed/distributable
#     IPAs. Without it, `flutter build ios --no-codesign` produces an
#     unsigned .app useful only for verifying the build pipeline.
#
# This script tries the SIGNED build first; if no signing identity is
# configured, falls back to unsigned and emits a clear warning.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  echo "usage: scripts/release-ios.sh <app-name>   # e.g. maximoney" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/$APP"
YAML="$APP_DIR/app.yaml"

if [[ ! -f "$YAML" ]]; then
  echo "error: missing $YAML" >&2; exit 1
fi

# Read build_dir + version from app.yaml
BUILD_DIR=$(awk -F': *' '$1=="build_dir"{print $2; exit}' "$YAML")
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"
VNAME=$(awk -F': *' '$1=="version_name"{print $2; exit}' "$YAML")
VCODE=$(awk -F': *' '$1=="version_code"{print $2; exit}' "$YAML")

if [[ -z "$BUILD_DIR" || -z "$VNAME" || -z "$VCODE" ]]; then
  echo "error: build_dir / version_name / version_code missing in $YAML" >&2
  exit 1
fi

OUT_DIR="$BUILD_DIR/out"
mkdir -p "$OUT_DIR"

echo "▶ syncing $APP"
"$ROOT/scripts/sync-app.sh" "$APP"

echo "▶ pod install"
( cd "$BUILD_DIR/ios" && pod install --repo-update )

echo "▶ flutter build ios"
cd "$BUILD_DIR"

# Try a signed release build first. If signing isn't configured (no team,
# no provisioning profile), fall back to unsigned with a loud warning so
# you don't accidentally believe you have a TestFlight-ready artifact.
if flutter build ipa --release 2>/dev/null; then
  IPA_SRC="$BUILD_DIR/build/ios/ipa"
  IPA_NAME=$(ls "$IPA_SRC"/*.ipa 2>/dev/null | head -1 || true)
  if [[ -z "$IPA_NAME" ]]; then
    echo "error: flutter build ipa succeeded but produced no .ipa" >&2; exit 1
  fi
  CANON="$OUT_DIR/${APP}-v${VNAME}-code${VCODE}.ipa"
  cp "$IPA_NAME" "$CANON"
  echo "✓ signed IPA → $CANON"
else
  echo "⚠ signed build failed (likely no Apple Developer signing config)."
  echo "⚠ Falling back to unsigned .app for build-pipeline verification only."
  echo "⚠ This artifact CANNOT be distributed to TestFlight or the App Store."
  flutter build ios --release --no-codesign
  APP_SRC="$BUILD_DIR/build/ios/iphoneos/Runner.app"
  if [[ ! -d "$APP_SRC" ]]; then
    echo "error: no Runner.app produced — iOS build broken" >&2; exit 1
  fi
  CANON="$OUT_DIR/${APP}-v${VNAME}-code${VCODE}-unsigned.app"
  rm -rf "$CANON"
  cp -R "$APP_SRC" "$CANON"
  echo "✓ unsigned .app → $CANON"
fi
