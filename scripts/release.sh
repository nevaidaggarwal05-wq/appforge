#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# release.sh <app>
#
# Full release pipeline:
#   1. scripts/sync-app.sh <app>         (shell + overrides → build dir)
#   2. flutter clean && flutter pub get
#   3. flutter build appbundle --release
#   4. flutter build apk --release
#   5. Copy artifacts to <out_dir>/<app>-v<name>-code<code>.{aab,apk}
#   6. Refresh <out_dir>/BUILD_INFO.md with the current release summary
#
# Run AFTER you've:
#   • bumped version_code + version_name in apps/<app>/app.yaml
#   • matched them in apps/<app>/overrides/pubspec.yaml + android/app/build.gradle
#   • committed your code changes (so git log is the release changelog)
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  echo "usage: scripts/release.sh <app-name>   # e.g. maximoney" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/$APP"

# Pull values from app.yaml
read_yaml() {
  awk -F': *' -v k="$1" '$1==k{sub(/^[ \t]+/,"",$2); print $2; exit}' "$APP_DIR/app.yaml"
}
BUILD_DIR=$(read_yaml build_dir);   BUILD_DIR="${BUILD_DIR/#\~/$HOME}"
OUT_DIR=$(read_yaml   out_dir);     OUT_DIR="${OUT_DIR/#\~/$HOME}"
VNAME=$(read_yaml     version_name)
VCODE=$(read_yaml     version_code)

echo "▶ release $APP v$VNAME (code $VCODE)"

# 1. Sync
"$ROOT/scripts/sync-app.sh" "$APP"

# 2-4. Build
cd "$BUILD_DIR"
flutter clean >/dev/null
flutter pub get
flutter build appbundle --release
flutter build apk       --release

# 5. Copy to out/ with canonical names
mkdir -p "$OUT_DIR"
AAB_SRC="$BUILD_DIR/build/app/outputs/bundle/release/app-release.aab"
APK_SRC="$BUILD_DIR/build/app/outputs/apk/release/app-release.apk"
AAB_DST="$OUT_DIR/${APP}-v${VNAME}-code${VCODE}.aab"
APK_DST="$OUT_DIR/${APP}-v${VNAME}-code${VCODE}.apk"

cp "$AAB_SRC" "$AAB_DST"
cp "$APK_SRC" "$APK_DST"

# 6. Refresh BUILD_INFO.md pointer — do NOT overwrite the hand-written
#    changelog; append a single "Latest build" block at the top.
INFO="$OUT_DIR/BUILD_INFO.md"
if [[ ! -f "$INFO" ]]; then
  echo "# $APP — build log" > "$INFO"
fi
{
  echo "## Latest build — v$VNAME (code $VCODE) — $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "- \`$(basename "$AAB_DST")\` — upload to Play Console"
  echo "- \`$(basename "$APK_DST")\` — side-load for testing"
  echo
  echo "Git ref: $(cd "$ROOT" && git rev-parse --short HEAD) ($(cd "$ROOT" && git log -1 --pretty=%s))"
  echo
  cat "$INFO"
} > "$INFO.tmp" && mv "$INFO.tmp" "$INFO"

echo "✓ release complete"
echo "  AAB: $AAB_DST"
echo "  APK: $APK_DST"
