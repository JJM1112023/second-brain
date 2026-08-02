#!/usr/bin/env bash
# check-readme.sh — quality gate for README.md, the repo's primary deliverable.
# Run locally or from the CI `readme` job. Exits non-zero on any violation.
#
# Checks:
#   1. every href uses http://, https://, #, or mailto: (no relative/empty links)
#   2. no duplicate external URLs (same tool listed twice)
#   3. every :small_orange_diamond: entry line matches the documented format:
#      &nbsp;&nbsp;:small_orange_diamond: <a href="..."><b>Name</b></a> - description.<br>
set -euo pipefail

if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
fi

python3 - <<'PY'
import re
import sys
from collections import Counter
from pathlib import Path

content = open("README.md", encoding="utf-8").read()
failures = []

# 1. href scheme check
links = re.findall(r'href="([^"]*)"', content)
bad = [l for l in links if not l.startswith(("http://", "https://", "#", "mailto:"))]
if bad:
    failures.append(f"bad href scheme ({len(bad)}): " + ", ".join(repr(b) for b in bad[:10]))

# 2. duplicate external URLs
external = [l for l in links if l.startswith(("http://", "https://"))]
dupes = {u: c for u, c in Counter(external).items() if c > 1}
if dupes:
    listing = ", ".join(f"{u} (x{c})" for u, c in list(dupes.items())[:10])
    failures.append(f"duplicate URLs ({len(dupes)}): {listing}")

# 3. entry format conformance
entry_pat = re.compile(
    r'^&nbsp;&nbsp;:small_orange_diamond: <a href="[^"]+"><b>[^<]+</b></a>.*<br>\s*$'
)
ENTRY_RE_MATCH = entry_pat.match
bad_entries = [
    (n, line)
    for n, line in enumerate(content.splitlines(), 1)
    if ":small_orange_diamond:" in line and not entry_pat.match(line)
]
if bad_entries:
    listing = "; ".join(f"line {n}: {line[:80]!r}" for n, line in bad_entries[:5])
    failures.append(f"malformed entries ({len(bad_entries)}): {listing}")

# 4. the landing page's headline stats must match reality
entries = sum(1 for line in content.splitlines() if ENTRY_RE_MATCH(line))
categories = sum(1 for line in content.splitlines() if line.startswith("#### "))
subcategories = sum(1 for line in content.splitlines() if line.startswith("##### "))
skills = len(list(Path(".claude/skills").glob("*/SKILL.md")))

expected = {
    "Top Categories": categories,
    "Sub-Domains": subcategories,
    "Curated Tools": entries,
    "AI Skills": skills,
}
index_html = Path("index.html").read_text(encoding="utf-8")
stats = dict(
    (label, int(count))
    for count, label in re.findall(
        r'data-count="(\d+)"[^>]*>0</div><div class="l">([^<]+)</div>', index_html
    )
)
for label, want in expected.items():
    got = stats.get(label)
    if got is None:
        failures.append(f"index.html has no '{label}' stat tile")
    elif got != want:
        failures.append(
            f"index.html '{label}' says {got}, README has {want}"
        )

if failures:
    print("README check FAILED:")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print(
    f"README OK: {len(links)} links checked, "
    f"{len(external)} external URLs unique, all entry lines well-formed"
)
print(
    f"  landing-page stats match: {categories} categories, "
    f"{subcategories} sub-domains, {entries} tools, {skills} skills"
)
PY
