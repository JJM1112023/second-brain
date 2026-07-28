#!/usr/bin/env bash
# validate-pwa.sh — single source of truth for PWA shell validation.
# Called by .githooks/pre-push locally and by the CI `pwa` job, so the same
# checks gate both paths. Exits non-zero if any check fails.
#
# Checks:
#   1. manifest.webmanifest is valid JSON with required keys and existing icons
#   2. sw.js parses (node --check when available, grep sanity otherwise)
#   3. index.html links the manifest, registers the SW, balances <script> tags
#   4. every path in sw.js's SHELL_ASSETS precache list exists in the repo
set -euo pipefail

# Run from the repo root whether invoked from a hook, CI, or by hand.
if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
fi

fail=0
say(){ printf '\033[36m[validate-pwa]\033[0m %s\n' "$*"; }
err(){ printf '\033[31m[validate-pwa]\033[0m %s\n' "$*"; fail=1; }

# 1. Manifest JSON validity + required fields + icon files
if [ -f manifest.webmanifest ]; then
  say "checking manifest.webmanifest…"
  python3 - <<'PY' || err "manifest.webmanifest is not valid JSON or missing keys"
import json, os
m = json.load(open("manifest.webmanifest"))
for k in ("name", "start_url", "display", "icons"):
    assert k in m, f"missing key: {k}"
assert any(i.get("sizes") == "192x192" for i in m["icons"]), "need 192x192 icon"
assert any(i.get("sizes") == "512x512" for i in m["icons"]), "need 512x512 icon"
for i in m["icons"]:
    p = i["src"]
    if not os.path.exists(p):
        raise SystemExit(f"icon file missing: {p}")
print("  manifest OK")
PY
else
  err "manifest.webmanifest not found"
fi

# 2. Service worker syntax check via node if available, else basic sanity
if [ -f sw.js ]; then
  say "checking sw.js…"
  if command -v node >/dev/null 2>&1; then
    node --check sw.js || err "sw.js has JS syntax errors"
  else
    grep -q "addEventListener" sw.js || err "sw.js looks empty"
  fi
else
  err "sw.js not found"
fi

# 3. index.html sanity — must have manifest link + SW registration
if [ -f index.html ]; then
  say "checking index.html…"
  grep -q 'rel="manifest"' index.html || err "index.html missing <link rel=\"manifest\">"
  grep -q "serviceWorker" index.html || err "index.html missing SW registration"
  # grep -o counts every occurrence (not lines); || true keeps a zero-match
  # grep from tripping set -e / pipefail
  o=$({ grep -oE "<script(\s|>)" index.html || true; } | wc -l)
  c=$({ grep -oE "</script>" index.html || true; } | wc -l)
  [ "$o" = "$c" ] || err "unbalanced <script> tags in index.html ($o open / $c close)"
else
  err "index.html not found"
fi

# 4. Precache list in sw.js must only reference files that exist
if [ -f sw.js ]; then
  say "checking sw.js precache list…"
  assets="$(sed -n '/const SHELL_ASSETS *= *\[/,/\];/p' sw.js \
    | grep -oE '"[^"]+"' | tr -d '"')"
  if [ -z "$assets" ]; then
    err "could not find SHELL_ASSETS precache list in sw.js"
  else
    while IFS= read -r asset; do
      rel="${asset#./}"
      # "./" precaches the directory index — covered by the index.html check
      [ -z "$rel" ] && continue
      [ -f "$rel" ] || err "precached asset missing from repo: $asset"
    done <<< "$assets"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "  PWA validation failed. Fix the errors above."
  exit 1
fi

say "all checks passed."
