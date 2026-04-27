#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# sync-app.sh <app>
#
# Reconstructs the per-app build directory by:
#   1. rsync-ing `flutter_shell/` → `<build_dir>/`  (shell = template)
#   2. overlaying `apps/<app>/overrides/` on top     (app-specific)
#
# Run this before every release (or whenever you touch flutter_shell/
# or apps/<app>/overrides/). After it finishes, you can `cd` into the
# build dir and `flutter build appbundle` as normal — or call
# `scripts/release.sh <app>` which does both.
#
# IMPORTANT: the build dir is REGENERABLE. Do not edit files there
# directly — edits will be overwritten on the next sync. Edit either
# `flutter_shell/` (shell-wide change) or `apps/<app>/overrides/`
# (app-specific) and re-sync.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  echo "usage: scripts/sync-app.sh <app-name>   # e.g. maximoney" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/$APP"
OVERRIDES="$APP_DIR/overrides"
SHELL_DIR="$ROOT/flutter_shell"

if [[ ! -d "$APP_DIR" ]]; then
  echo "error: no app found at $APP_DIR" >&2; exit 1
fi
if [[ ! -f "$APP_DIR/app.yaml" ]]; then
  echo "error: missing $APP_DIR/app.yaml" >&2; exit 1
fi

# Read build_dir from app.yaml (tilde-expand)
BUILD_DIR=$(awk -F': *' '$1=="build_dir"{print $2; exit}' "$APP_DIR/app.yaml")
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"

if [[ -z "$BUILD_DIR" ]]; then
  echo "error: build_dir not set in app.yaml" >&2; exit 1
fi

echo "▶ sync $APP"
echo "  shell:     $SHELL_DIR"
echo "  overrides: $OVERRIDES"
echo "  → build:   $BUILD_DIR"

mkdir -p "$BUILD_DIR"

# Shell → build. Preserve out/ (release artifacts), build/ (Gradle/Xcode
# caches), .dart_tool/ (pub cache), local.properties (SDK path),
# key.properties (signing secrets), and the Android/iOS intermediates that
# Gradle / Xcode / Flutter regenerate themselves.
rsync -a --delete \
  --exclude 'out/' \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude '.flutter-plugins*' \
  --exclude '.DS_Store' \
  --exclude 'android/local.properties' \
  --exclude 'android/key.properties' \
  --exclude 'android/.gradle/' \
  --exclude 'android/app/src/main/kotlin/com/template/' \
  --exclude 'ios/Flutter/Generated.xcconfig' \
  --exclude 'ios/Flutter/flutter_export_environment.sh' \
  --exclude 'ios/Pods/' \
  --exclude 'ios/Podfile.lock' \
  --exclude 'ios/.symlinks/' \
  --exclude 'ios/Runner.xcworkspace/xcuserdata/' \
  --exclude 'ios/Runner.xcodeproj/xcuserdata/' \
  --exclude 'ios/Flutter/App.xcconfig.example' \
  --exclude 'Gemfile.lock' \
  --exclude 'fastlane/report.xml' \
  --exclude 'fastlane/test_output/' \
  --exclude 'fastlane/.env.default' \
  "$SHELL_DIR/" "$BUILD_DIR/"

# Overrides on top. No --delete — overrides add/replace, never remove.
if [[ -d "$OVERRIDES" ]]; then
  rsync -a "$OVERRIDES/" "$BUILD_DIR/"
fi

echo "✓ sync complete"
