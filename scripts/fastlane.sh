#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# fastlane.sh <app> <platform> <lane> [extra args...]
#
# Wrapper that sets up the per-app environment and runs fastlane in
# the build dir. Does NOT bump versions or sync — call those first
# (or use the meta-script `scripts/ship.sh` once it lands).
#
# Examples:
#   scripts/fastlane.sh maximoney android beta
#   scripts/fastlane.sh maximoney android promote rollout:0.1
#   scripts/fastlane.sh maximoney ios beta
#   scripts/fastlane.sh maximoney android doctor   # check credentials
#
# Prereqs (one-time per machine):
#   gem install bundler
#   cd ~/Desktop/builds/<app> && bundle install
#
# Prereqs (one-time per app — see docs/FASTLANE.md):
#   • Google Play service-account JSON at the path in .env.default
#   • (iOS) App Store Connect API .p8 key at the path in .env.default
#   • (iOS) ASC_KEY_ID + ASC_ISSUER_ID exported, or set in .env.default
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

APP="${1:-}"
PLATFORM="${2:-}"
LANE="${3:-}"

if [[ -z "$APP" || -z "$PLATFORM" || -z "$LANE" ]]; then
  cat >&2 <<EOF
usage: scripts/fastlane.sh <app> <platform> <lane> [args...]

Platforms: android | ios
Common lanes:
  android build           — local AAB, no upload
  android beta            — upload AAB to Internal Testing
  android promote         — promote internal → production (default 10%)
  ios     build           — local IPA, no upload
  ios     beta            — upload IPA to TestFlight
  ios     promote         — submit latest TestFlight build for review
  doctor                  — check credentials  (no platform needed)

Examples:
  scripts/fastlane.sh maximoney android beta
  scripts/fastlane.sh maximoney android promote rollout:0.25
  scripts/fastlane.sh maximoney doctor doctor
EOF
  exit 2
fi
shift 3
EXTRA=("$@")

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/$APP"
YAML="$APP_DIR/app.yaml"

if [[ ! -f "$YAML" ]]; then
  echo "error: missing $YAML" >&2; exit 1
fi

BUILD_DIR=$(awk -F': *' '$1=="build_dir"{print $2; exit}' "$YAML")
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "error: build dir $BUILD_DIR doesn't exist — run scripts/sync-app.sh $APP first" >&2
  exit 1
fi

# Sync first so any shell or override changes propagate before we ship.
echo "▶ syncing $APP (so build dir matches source of truth)"
"$ROOT/scripts/sync-app.sh" "$APP" >/dev/null

cd "$BUILD_DIR"

# One-time bundler setup per machine. Cheap if already installed.
if [[ ! -f "Gemfile.lock" ]]; then
  echo "▶ first-time bundle install (this takes a minute)"
  bundle install
fi

# Source per-app .env.default so env vars are visible to fastlane
ENV_FILE="$BUILD_DIR/fastlane/.env.default"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
  # Expand ~ in paths after sourcing
  [[ -n "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]] && export PLAY_SERVICE_ACCOUNT_JSON="${PLAY_SERVICE_ACCOUNT_JSON/#\~/$HOME}"
  [[ -n "${ASC_KEY_PATH:-}" ]]              && export ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
fi

# Cross-platform `doctor` lane — invoke without a platform.
if [[ "$PLATFORM" == "doctor" || "$LANE" == "doctor" ]]; then
  exec bundle exec fastlane doctor
fi

echo "▶ fastlane $PLATFORM $LANE ${EXTRA[*]:-}"
exec bundle exec fastlane "$PLATFORM" "$LANE" "${EXTRA[@]}"
