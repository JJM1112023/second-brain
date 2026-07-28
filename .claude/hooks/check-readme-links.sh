#!/usr/bin/env bash
# PostToolUse hook — validates that all href links in README.md are well-formed.
# Claude Code passes the event JSON on stdin; the edited path is tool_input.file_path.
# Non-http links (relative paths, empty hrefs) indicate a broken or missing URL.

file_path="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
print(data.get("tool_input", {}).get("file_path", ""))
' 2>/dev/null || true)"

if [[ "${file_path}" == *README.md ]]; then
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
