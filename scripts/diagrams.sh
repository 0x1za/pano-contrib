#!/usr/bin/env bash
# Re-render docs/diagrams/*.mmd to SVG with the Mermaid CLI, using the
# installed Chrome rather than downloading a browser. Commit the SVGs; the
# README embeds them so they render everywhere, not only on GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
cfg="$(mktemp)"
printf '{"executablePath": "%s", "args": ["--no-sandbox", "--headless=new"]}\n' "$CHROME" > "$cfg"
for src in docs/diagrams/*.mmd; do
  out="${src%.mmd}.svg"
  npx -y @mermaid-js/mermaid-cli@11 -p "$cfg" -i "$src" -o "$out" -b white
  echo "rendered $out"
done
rm -f "$cfg"
