#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# ship.sh <app> [patch|minor|major] [android|ios|both]
#
# One-shot pipeline for a publish-and-go release:
#   1. bump-version.sh <app> <bump>
#   2. git commit the version bump  (skipped if --no-commit)
#   3. fastlane.sh <app> android beta   (if android or both)
#   4. fastlane.sh <app> ios     beta   (if ios or both, and creds exist)
#
# Defaults: patch bump, both platforms.
# Skips iOS if ASC_KEY_PATH file isn't present (so this works fine
# pre-Apple-Dev-enrollment — Android still ships).
#
# Examples:
#   scripts/ship.sh maximoney                    # patch bump → both stores' beta
#   scripts/ship.sh maximoney minor android      # minor bump → Internal Testing only
#   scripts/ship.sh maximoney patch both --no-commit
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

APP="${1:-}"
BUMP="${2:-patch}"
PLATFORMS="${3:-both}"
COMMIT=1

# Crude flag parsing — anything starting with -- after positional args
for arg in "$@"; do
  case "$arg" in
    --no-commit) COMMIT=0 ;;
  esac
done

if [[ -z "$APP" ]]; then
  cat >&2 <<'EOF'
usage: scripts/ship.sh <app> [patch|minor|major] [android|ios|both] [--no-commit]

Examples:
  scripts/ship.sh maximoney                    # patch bump, both platforms
  scripts/ship.sh maximoney minor android      # minor bump, Android only
  scripts/ship.sh maximoney patch both --no-commit
EOF
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/$APP"

if [[ ! -d "$APP_DIR" ]]; then
  echo "error: no app at $APP_DIR" >&2; exit 1
fi

# 1. Bump version
echo "▶ ship: bumping version ($BUMP)"
"$ROOT/scripts/bump-version.sh" "$APP" "$BUMP"

NEW_VNAME=$(awk -F': *' '$1=="version_name"{print $2; exit}' "$APP_DIR/app.yaml")
NEW_VCODE=$(awk -F': *' '$1=="version_code"{print $2; exit}' "$APP_DIR/app.yaml")

# 2. Commit
if [[ "$COMMIT" == 1 ]]; then
  cd "$ROOT"
  if git diff --quiet "apps/$APP/app.yaml" "apps/$APP/overrides/pubspec.yaml" "apps/$APP/overrides/android/app/build.gradle"; then
    echo "▶ ship: nothing to commit (version files unchanged)"
  else
    git add "apps/$APP/app.yaml" "apps/$APP/overrides/pubspec.yaml" "apps/$APP/overrides/android/app/build.gradle"
    git commit -m "$APP: v$NEW_VNAME (code $NEW_VCODE)"
    echo "▶ ship: committed version bump"
  fi
fi

# 3 & 4. Fastlane beta uploads
do_android=0; do_ios=0
case "$PLATFORMS" in
  android) do_android=1 ;;
  ios)     do_ios=1 ;;
  both)    do_android=1; do_ios=1 ;;
  *) echo "error: platforms must be android|ios|both" >&2; exit 2 ;;
esac

if [[ "$do_android" == 1 ]]; then
  echo "▶ ship: android beta"
  "$ROOT/scripts/fastlane.sh" "$APP" android beta
fi

if [[ "$do_ios" == 1 ]]; then
  # Auto-skip if iOS creds aren't ready — works pre-Apple-Dev-enrollment.
  ENV_FILE="$APP_DIR/overrides/fastlane/.env.default"
  KEY_PATH=""
  if [[ -f "$ENV_FILE" ]]; then
    KEY_PATH=$(awk -F'=' '$1=="ASC_KEY_PATH"{print $2; exit}' "$ENV_FILE")
    KEY_PATH="${KEY_PATH/#\~/$HOME}"
  fi
  if [[ -z "$KEY_PATH" || ! -f "$KEY_PATH" ]]; then
    echo "▶ ship: skipping iOS (ASC_KEY_PATH not set or file missing — Apple Dev account not configured yet)"
  else
    echo "▶ ship: ios beta"
    "$ROOT/scripts/fastlane.sh" "$APP" ios beta
  fi
fi

echo "✓ ship complete: $APP v$NEW_VNAME (code $NEW_VCODE)"
