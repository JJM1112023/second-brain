# /review — Write-Review-Fix Loop

Run this skill on any shell script (or the current branch diff) to perform a full
build-review-fix cycle without human intervention between steps.

## Steps

1. **Identify target** — use the argument passed to `/review` as the file path.
   If no argument, review all `.sh` files changed in the current branch
   (`git diff origin/master...HEAD --name-only | grep '\.sh$'`).

2. **Static analysis** — run ShellCheck:
   ```bash
   shellcheck -s bash -e 1072,1094 -x <target>
   ```
   Capture all findings.

3. **Logic review** — read the full script and check each of the following angles:
   - CWD guard: does the script assume a working directory without enforcing it?
   - Pipeline fallbacks: does any `|| default` follow a pipeline whose last command exits 0 on empty input?
   - Grep anchoring: does any `grep -q "pattern"` risk matching an unintended substring (e.g. `"healthy"` inside `"unhealthy"`)?
   - Swallowed exit codes: are `&>/dev/null` redirections hiding failures that a caller needs to diagnose?
   - Broad success checks: does the script use `grep -q "keyword"` to detect success where an error response could also contain that keyword?

4. **Consolidate findings** — produce a single ranked list of all bugs (ShellCheck + logic review), most severe first. Label each CONFIRMED or PLAUSIBLE.

5. **Fix all CONFIRMED findings** — apply fixes in one consolidated edit pass. Do not fix PLAUSIBLE findings without noting them.

6. **Verify** — re-run ShellCheck on the patched file. Report pass/fail.

7. **Summarise** — output a table: file, line, what was wrong, what was changed.

## Example invocation

```
/review verify.sh
/review          # reviews all .sh files in the branch diff
```
