#!/usr/bin/env bash
# check-vault.sh — integrity gate for the generated Obsidian vault.
# Run locally or from the CI `vault` job. Exits non-zero on any violation.
#
# Checks:
#   1. the vault exists and has the expected top-level notes
#   2. every [[wikilink]] resolves to a note that exists
#   3. every note is reachable from Home.md (no islands in the graph)
#   4. every note carries YAML frontmatter with a title
#   5. the generator is up to date with its sources (gen_secondbrain.py --check)
set -euo pipefail

if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
fi

blue() { printf '\033[36m[check-vault]\033[0m %s\n' "$1"; }

if [ ! -d vault ]; then
  echo "check-vault FAILED: vault/ does not exist. Run: python3 scripts/gen_secondbrain.py" >&2
  exit 1
fi

blue "checking vault structure, links, and reachability…"
python3 - <<'PY'
import re
import sys
from collections import deque
from pathlib import Path

VAULT = Path("vault")
failures = []

# vault/Private/ is the gitignored clone of the private half of the brain —
# personal notes, never part of this repo, never checked by this gate.
notes = sorted(
    p for p in VAULT.rglob("*.md") if "Private" not in p.relative_to(VAULT).parts
)
by_name = {}
for note in notes:
    by_name.setdefault(note.stem, note)

# vault/.generated lists the notes the generator owns. Structural rules
# (frontmatter, reachability) are enforced on those; notes you add yourself are
# only checked for broken links, so your own writing never fails the build.
manifest = VAULT / ".generated"
if manifest.exists():
    generated = {
        VAULT / line
        for line in manifest.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    }
else:
    generated = set(notes)
mine = [n for n in notes if n not in generated]

# 1. required entry points
for required in ("Home.md", "Roadmap.md", "Repo Map.md", "README.md"):
    if not (VAULT / required).exists():
        failures.append(f"missing required note: vault/{required}")

# 2 + 4. wikilink resolution and frontmatter
WIKILINK = re.compile(r"\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]")
FENCED = re.compile(r"^```.*?^```", re.MULTILINE | re.DOTALL)
INLINE_CODE = re.compile(r"`[^`\n]*`")
graph = {note: set() for note in notes}


def prose(text: str) -> str:
    """Drop code blocks and inline code — `[[wikilink]]` in a code span is a
    literal example, not a link, and must not be resolved."""
    return INLINE_CODE.sub("", FENCED.sub("", text))


for note in notes:
    text = note.read_text(encoding="utf-8")

    # README.md is the human-facing vault guide, not a graph note — no frontmatter.
    if note.name != "README.md" and note in generated:
        if not text.startswith("---\n"):
            failures.append(f"{note}: missing YAML frontmatter")
        elif "\ntitle:" not in text.split("\n---\n", 1)[0]:
            failures.append(f"{note}: frontmatter has no title")

    for match in WIKILINK.finditer(prose(text)):
        target = match.group(1).strip()
        if target in by_name:
            graph[note].add(by_name[target])
        else:
            failures.append(f"{note}: broken wikilink [[{target}]]")

# 3. reachability from Home (treat links as undirected — backlinks count)
home = VAULT / "Home.md"
if home.exists():
    undirected = {note: set(links) for note, links in graph.items()}
    for note, links in graph.items():
        for link in links:
            undirected[link].add(note)

    seen = {home}
    queue = deque([home])
    while queue:
        current = queue.popleft()
        for neighbour in undirected.get(current, ()):
            if neighbour not in seen:
                seen.add(neighbour)
                queue.append(neighbour)

    unreached = set(notes) - seen
    islands = sorted(str(n) for n in unreached & generated)
    if islands:
        failures.append(
            f"unreachable from Home.md ({len(islands)}): " + ", ".join(islands[:8])
        )
    # Your own orphaned notes are worth knowing about, but not worth failing on.
    loose = sorted(str(n) for n in unreached - generated)
    if loose:
        print(f"  note: {len(loose)} of your own notes are not linked from Home.md")
        for path in loose[:5]:
            print(f"    - {path}")

if failures:
    print("check-vault FAILED:")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

links = sum(len(v) for v in graph.values())
own = f", {len(mine)} of them yours" if mine else ""
print(
    f"  vault OK: {len(notes)} notes{own}, {links} resolved wikilinks, "
    "generated notes all reachable from Home.md"
)
PY

blue "checking the generator is up to date with its sources…"
python3 scripts/gen_secondbrain.py --check

blue "all checks passed."
