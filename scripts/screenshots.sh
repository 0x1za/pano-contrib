#!/usr/bin/env bash
# Re-take the README screenshots from a running dev server (bin/dev with the
# pano API up). Drives the installed Chrome through puppeteer-core with real
# waits so MapLibre finishes drawing. The signed-in shots need a moderator:
#   SHOT_EMAIL=... SHOT_PASSWORD=... SHOT_SURVEY=<survey id> scripts/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
BASE_URL="${BASE_URL:-http://127.0.0.1:3000}"
work="$(mktemp -d)"
cp scripts/screenshots/shot.mjs "$work/"
(cd "$work" && npm init -y >/dev/null && npm install --silent puppeteer-core@23)
mkdir -p "$work/out"
(cd "$work" && node shot.mjs "$BASE_URL" "$work/out" "${SHOT_EMAIL:-}" "${SHOT_PASSWORD:-}" "${SHOT_SURVEY:-}")
for f in "$work"/out/*.png; do
  name="$(basename "$f")"
  sips -Z 1600 -s format png "$f" --out "docs/screenshots/$name" >/dev/null
  echo "docs/screenshots/$name"
done
rm -rf "$work"
