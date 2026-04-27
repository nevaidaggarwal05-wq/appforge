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
# iOS does NOT need a separate file edit: Info.plist reads
# $(FLUTTER_BUILD_NAME) / $(FLUTTER_BUILD_NUMBER), and Flutter populates
# those from pubspec.yaml's `version:` line at build time. So bumping
# pubspec.yaml above propagates to both Android and iOS.
#
# After running, commit the diff, then call:
#   scripts/release.sh <app>      (Android AAB)
#   scripts/release-ios.sh <app>  (iOS IPA — requires Xcode + Apple Dev account)
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

echo "✓ bumped. commit the diff, then run:"
echo "    scripts/release.sh $APP       # Android AAB"
echo "    scripts/release-ios.sh $APP   # iOS IPA"
