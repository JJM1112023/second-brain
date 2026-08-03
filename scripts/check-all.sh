#!/usr/bin/env bash
# check-all.sh — run every gate CI runs, in one command.
#
#   bash scripts/check-all.sh
#
# Each gate reports pass/fail independently and the script keeps going, so one
# run tells you everything that is broken instead of only the first thing.
# Missing optional tooling (shellcheck, bats, Pillow) is reported as SKIP.
set -uo pipefail

# Unlike the other scripts here this one deliberately runs without `set -e`,
# so every gate reports even after an earlier one fails — which means the cd
# needs its own guard.
if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root" || exit 1
else
  cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fi

pass=0 fail=0 skip=0
failed_gates=()

hdr() { printf '\n\033[36m══ %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  PASS\033[0m  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '\033[31m  FAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); failed_gates+=("$1"); }
meh()  { printf '\033[33m  SKIP\033[0m  %s (%s)\n' "$1" "$2"; skip=$((skip + 1)); }

# gate NAME REQUIRED_CMD COMMAND...
#   REQUIRED_CMD of "-" means no external tool is needed.
gate() {
  name="$1"; need="$2"; shift 2
  if [ "$need" != "-" ] && ! command -v "$need" >/dev/null 2>&1; then
    meh "$name" "$need not installed"
    return
  fi
  hdr "$name"
  if "$@"; then ok "$name"; else bad "$name"; fi
}

gate "ShellCheck" shellcheck \
  shellcheck -s bash -e 1072,1094 -x \
    src/*.sh \
    lib/common.sh bin/git-template-full \
    scripts/validate-pwa.sh scripts/check-readme.sh scripts/install-hooks.sh \
    scripts/check-vault.sh scripts/check-all.sh \
    .githooks/pre-push .githooks/post-merge \
    .claude/hooks/check-readme-links.sh .claude/hooks/shellcheck-edited.sh

gate "Bats functional tests" bats bats test/

gate "PWA shell" - bash scripts/validate-pwa.sh

gate "README quality" - bash scripts/check-readme.sh

gate "Second brain generator" - python3 test/gen_secondbrain_test.py

gate "Vault integrity" - bash scripts/check-vault.sh

if python3 -c "import PIL" >/dev/null 2>&1; then
  gate "Icon generator" - python3 test/gen_icons_test.py
else
  meh "Icon generator" "Pillow not installed"
fi

printf '\n\033[36m══ Summary\033[0m\n'
printf '  %d passed · %d failed · %d skipped\n' "$pass" "$fail" "$skip"
if [ "$fail" -ne 0 ]; then
  printf '\n  failing gates:\n'
  for gate_name in "${failed_gates[@]}"; do printf '    - %s\n' "$gate_name"; done
  exit 1
fi
echo "  everything green."
