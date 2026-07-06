#!/usr/bin/env bash
# PostToolUse hook — run ShellCheck on an edited shell script.
# Claude Code passes the event JSON on stdin; the edited path is tool_input.file_path.

file="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
print(data.get("tool_input", {}).get("file_path", ""))
' 2>/dev/null || true)"

if [[ "$file" == *.sh || "$file" == */src/* || "$file" == */lib/* || "$file" == */bin/* ]]; then
  if [ -f "$file" ] && command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -s bash -e 1072,1094 -x "$file"; then
      echo "shellcheck: OK"
    else
      echo "shellcheck: FAILED — fix errors before committing"
    fi
  fi
fi
