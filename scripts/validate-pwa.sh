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

# 3. Every HTML page in the shell must link the manifest, register the SW,
#    and balance its <script> tags.
check_page() {
  page="$1"
  if [ ! -f "$page" ]; then
    err "$page not found"
    return
  fi
  say "checking $page…"
  grep -q 'rel="manifest"' "$page" || err "$page missing <link rel=\"manifest\">"
  grep -q "serviceWorker" "$page" || err "$page missing SW registration"
  # grep -o counts every occurrence (not lines); || true keeps a zero-match
  # grep from tripping set -e / pipefail
  o=$({ grep -oE "<script(\s|>)" "$page" || true; } | wc -l)
  c=$({ grep -oE "</script>" "$page" || true; } | wc -l)
  [ "$o" = "$c" ] || err "unbalanced <script> tags in $page ($o open / $c close)"
}

check_page index.html
check_page zero-brain/index.html

# 3b. The console is only useful with its generated data file loaded.
if [ -f zero-brain/index.html ]; then
  say "checking zero-brain data wiring…"
  grep -q 'src="brain-data.js"' zero-brain/index.html \
    || err "zero-brain/index.html does not load brain-data.js"
  [ -f zero-brain/brain-data.js ] \
    || err "zero-brain/brain-data.js missing — run: python3 scripts/gen_secondbrain.py"
  [ -f zero-brain/brain.json ] \
    || err "zero-brain/brain.json missing — run: python3 scripts/gen_secondbrain.py"
  if command -v node >/dev/null 2>&1 && [ -f zero-brain/brain-data.js ]; then
    node --check zero-brain/brain-data.js || err "zero-brain/brain-data.js has JS syntax errors"
  fi
fi

# 3c. The landing page must link the console, or nobody will ever find it.
if [ -f index.html ]; then
  grep -q 'zero-brain/' index.html || err "index.html does not link to zero-brain/"
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
      # "./" and "sub/" precache a directory index — resolve them to index.html
      [ -z "$rel" ] && continue
      case "$rel" in
        */) rel="${rel}index.html" ;;
      esac
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
