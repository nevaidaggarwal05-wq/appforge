#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# bump-version.sh <app> <patch|minor|major>
#
# Increments version_code by 1 and version_name per semver bump type,
# then syncs the new values into:
#   • apps/<app>/app.yaml
#   • apps/<app>/overrides/pubspec.yaml              (version: x.y.z+N)
#   • apps/<app>/overrides/android/app/build.gradle  (versionCode / versionName)
#
# After running, commit the change before calling release.sh.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

APP="${1:-}"
BUMP="${2:-patch}"
if [[ -z "$APP" ]]; then
  echo "usage: scripts/bump-version.sh <app> [patch|minor|major]" >&2; exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YAML="$ROOT/apps/$APP/app.yaml"
PUB="$ROOT/apps/$APP/overrides/pubspec.yaml"
GRADLE="$ROOT/apps/$APP/overrides/android/app/build.gradle"

VNAME=$(awk -F': *' '$1=="version_name"{print $2; exit}' "$YAML")
VCODE=$(awk -F': *' '$1=="version_code"{print $2; exit}' "$YAML")

IFS=. read -r MAJ MIN PAT <<<"$VNAME"
case "$BUMP" in
  major) MAJ=$((MAJ+1)); MIN=0; PAT=0 ;;
  minor) MIN=$((MIN+1)); PAT=0 ;;
  patch) PAT=$((PAT+1)) ;;
  *) echo "bump must be patch|minor|major" >&2; exit 2 ;;
esac
NEW_VNAME="$MAJ.$MIN.$PAT"
NEW_VCODE=$((VCODE+1))

echo "▶ $APP: $VNAME (code $VCODE) → $NEW_VNAME (code $NEW_VCODE)"

# app.yaml
sed -i '' -E "s/^version_name:.*/version_name: $NEW_VNAME/"  "$YAML"
sed -i '' -E "s/^version_code:.*/version_code: $NEW_VCODE/"  "$YAML"

# pubspec.yaml
sed -i '' -E "s/^version:.*/version: $NEW_VNAME+$NEW_VCODE/" "$PUB"

# build.gradle
sed -i '' -E "s/versionCode +[0-9]+/versionCode $NEW_VCODE/" "$GRADLE"
sed -i '' -E "s/versionName +\"[^\"]+\"/versionName \"$NEW_VNAME\"/" "$GRADLE"

echo "✓ bumped. commit the diff, then run scripts/release.sh $APP"
