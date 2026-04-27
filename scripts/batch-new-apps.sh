#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# batch-new-apps.sh <csv-file>
#
# Reads a CSV (export from Numbers / Excel / Google Sheets) and
# scaffolds an app folder per row by writing apps/<slug>/app.yaml
# directly from the row, then calling scripts/new-app.sh <slug>.
#
# Required CSV columns (header row, in any order):
#   slug                — folder name + Android applicationId namespace
#   display             — UI display name
#   package             — Android applicationId == iOS bundle ID
#   webview_url         — full https://… URL the app wraps
#   oauth_scheme        — custom URL scheme (defaults to slug if blank)
#   theme_color         — hex like #1DBF98 (defaults to #1A1A2E)
#   accent_color        — hex (defaults to #E94560)
#   share_message       — share-sheet text (defaults to "Check out <display>")
#
# Optional (filled with defaults when blank — externally-issued IDs
# you'll fill in later by editing apps/<slug>/app.yaml directly):
#   appforge_app_id          — Supabase row UUID (from admin panel)
#   firebase_android_app_id  — 1:NNN:android:HEX (from Firebase Console)
#   admob_app_id_android     — ca-app-pub-…~… (or test placeholder)
#   admob_app_id_ios         — ca-app-pub-…~… (or test placeholder)
#
# Example:
#   scripts/batch-new-apps.sh docs/new-apps-template.csv
#
# After running, for each scaffolded app:
#   1. Edit apps/<slug>/app.yaml with externally-issued IDs as they
#      become available (admin panel UUID, Firebase IDs, AdMob IDs)
#   2. Re-run scripts/new-app.sh <slug>     # idempotent regen
#   3. Drop binary assets (icons, google-services.json) per the
#      checklist printed by new-app.sh
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

CSV="${1:-}"
if [[ -z "$CSV" ]]; then
  echo "usage: scripts/batch-new-apps.sh <csv-file>" >&2
  echo "       (template at docs/new-apps-template.csv)" >&2
  exit 2
fi
if [[ ! -f "$CSV" ]]; then
  echo "error: $CSV not found" >&2; exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Use python for CSV parsing — bash splitting on commas breaks on any
# field containing a comma (share messages, future fields). Python's
# csv module handles quoting / escaping properly. Python 3 ships with
# macOS by default.
python3 - "$CSV" "$ROOT" <<'PY'
import csv, os, subprocess, sys, re

csv_path, root = sys.argv[1], sys.argv[2]

REQUIRED = ["slug", "display", "package", "webview_url"]
DEFAULTS = {
    "oauth_scheme":            None,        # falls back to slug
    "theme_color":             "#1A1A2E",
    "accent_color":            "#E94560",
    "share_message":           None,        # falls back to "Check out <display>"
    "appforge_app_id":         "00000000-0000-0000-0000-000000000000",
    "firebase_project":        "appforge-push",
    "firebase_android_app_id": "REPLACE_AFTER_FIREBASE_SETUP",
    "admob_app_id_android":    "ca-app-pub-3940256099942544~3347511713",
    "admob_app_id_ios":        "ca-app-pub-3940256099942544~1458002511",
    "appforge_api_base_url":   "https://flutteradmin.valuecreateventures.top",
}
SLUG_RE = re.compile(r"^[a-z][a-z0-9_]*$")

with open(csv_path, newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

if not rows:
    print(f"error: {csv_path} has no data rows", file=sys.stderr)
    sys.exit(1)

# Validate header
missing_cols = [c for c in REQUIRED if c not in reader.fieldnames]
if missing_cols:
    print(f"error: CSV missing required columns: {missing_cols}", file=sys.stderr)
    sys.exit(1)

failed = []
for i, row in enumerate(rows, start=2):  # row 1 is header
    slug = (row.get("slug") or "").strip()
    if not slug:
        print(f"row {i}: skipping — empty slug")
        continue
    if not SLUG_RE.match(slug):
        print(f"row {i}: SKIP — invalid slug '{slug}' (lowercase letters/digits/underscore, must start with letter)")
        failed.append(slug)
        continue

    display = (row.get("display") or "").strip() or slug
    package = (row.get("package") or "").strip() or f"com.{slug}.app"
    webview_url = (row.get("webview_url") or "").strip()
    if not webview_url:
        print(f"row {i} ({slug}): SKIP — empty webview_url")
        failed.append(slug)
        continue

    oauth_scheme = (row.get("oauth_scheme") or "").strip() or slug
    theme_color = (row.get("theme_color") or "").strip() or DEFAULTS["theme_color"]
    accent_color = (row.get("accent_color") or "").strip() or DEFAULTS["accent_color"]
    share_message = (row.get("share_message") or "").strip() or f"Check out {display}"

    appforge_app_id = (row.get("appforge_app_id") or "").strip() or DEFAULTS["appforge_app_id"]
    firebase_project = (row.get("firebase_project") or "").strip() or DEFAULTS["firebase_project"]
    firebase_aaid = (row.get("firebase_android_app_id") or "").strip() or DEFAULTS["firebase_android_app_id"]
    admob_android = (row.get("admob_app_id_android") or "").strip() or DEFAULTS["admob_app_id_android"]
    admob_ios = (row.get("admob_app_id_ios") or "").strip() or DEFAULTS["admob_app_id_ios"]
    api_base = (row.get("appforge_api_base_url") or "").strip() or DEFAULTS["appforge_api_base_url"]

    app_dir = os.path.join(root, "apps", slug)
    os.makedirs(app_dir, exist_ok=True)
    yaml_path = os.path.join(app_dir, "app.yaml")

    # Write app.yaml directly (skips new-app.sh's "first run" path
    # since we know exactly the values we want to write).
    with open(yaml_path, "w") as out:
        out.write(f"""# {display} — per-app metadata. Regenerate overrides with:
#   scripts/new-app.sh {slug}

# ── Identity ─────────────────────────────────────────────────────
name:        {slug}
display:     {display}
package:     {package}
webview_url: {webview_url}
oauth_scheme: {oauth_scheme}
theme_color:  {theme_color}
accent_color: {accent_color}
share_message: {share_message}

# ── AppForge backend + Firebase ──────────────────────────────────
appforge_api_base_url:    {api_base}
appforge_app_id:          {appforge_app_id}
firebase_project:         {firebase_project}
firebase_android_app_id:  {firebase_aaid}

# ── AdMob ────────────────────────────────────────────────────────
admob_app_id_android: {admob_android}
admob_app_id_ios:     {admob_ios}

# ── Signing (Android) ────────────────────────────────────────────
keystore_path:   ~/Desktop/{slug}-keystore.jks
keystore_alias:  {slug}
keystore_sha256: REPLACE_AFTER_KEYSTORE_GENERATED

# ── Build output ─────────────────────────────────────────────────
build_dir: ~/Desktop/builds/{slug}
out_dir:   ~/Desktop/builds/{slug}/out

# ── Version ──────────────────────────────────────────────────────
version_name: 1.0.0
version_code: 1
""")
    print(f"row {i} ({slug}): wrote {yaml_path}")

    # Now invoke new-app.sh for the regen pass — it reads the YAML
    # we just wrote and renders all the overrides.
    try:
        subprocess.run(
            [os.path.join(root, "scripts", "new-app.sh"), slug],
            check=True,
            cwd=root,
        )
    except subprocess.CalledProcessError as e:
        print(f"row {i} ({slug}): new-app.sh failed (exit {e.returncode})")
        failed.append(slug)

print()
if failed:
    print(f"⚠ {len(failed)} row(s) failed: {failed}")
    sys.exit(1)
print(f"✓ Scaffolded {len(rows) - len(failed)} app(s).")
print()
print("Next per app:")
print("  • Edit apps/<slug>/app.yaml as externally-issued IDs come in")
print("  • Drop google-services.json + launcher icons + iOS app icons")
print("  • Generate keystore, fill keystore_sha256, re-run scripts/new-app.sh <slug>")
print("  • scripts/sync-app.sh <slug> && scripts/release.sh <slug>")
PY
