#!/usr/bin/env bash
# Runs after edits — validates that all href links in README.md are well-formed.
# Non-http links (relative paths, empty hrefs) indicate a broken or missing URL.

if [[ "${CLAUDE_FILE_PATH:-}" == *README.md ]]; then
  python3 - <<'EOF'
import re, sys

with open("README.md") as f:
    content = f.read()

links = re.findall(r'href="([^"]*)"', content)
bad = [l for l in links if not l.startswith(("http://", "https://", "#", "mailto:"))]

if bad:
    print(f"README link issues ({len(bad)} found): {bad[:5]}")
    print("Fix these before committing.")
else:
    print(f"README links OK ({len(links)} checked)")
EOF
fi
