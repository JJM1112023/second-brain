# CLAUDE.md

This file provides guidance for AI assistants working with the **awesome-ninja-admins** repository.

## Project Type

This is an **awesome-list** repository. Keep entries alphabetized within categories, ensure all links point to valid `http://` or `https://` URLs, and follow the HTML-in-Markdown entry format documented below. When adding entries, always read `README.md` first to avoid duplicates and place items in the correct existing category.

## Project Overview

This is a curated "Awesome" list repository — a collection of tools, manuals, blogs, hacks, and resources for system administrators (Ninja Admins). The primary deliverable is the curated list in `README.md`, but the repo has grown two additional layers:

1. **Bash utility scripts** — working sysadmin scripts live in `src/`, sharing helpers from `lib/common.sh`.
2. **A Progressive Web App (PWA)** — an immersive 3D landing page (`index.html`) served via GitHub Pages, installable and offline-capable through a service worker (`sw.js`) and web manifest.

**Tech stack:** Markdown (content), Bash (scripts), ShellCheck (linting), Travis CI (CI/CD), HTML/JS/Three.js + Service Worker (PWA), Python + Pillow (icon generation).

## Repository Structure

```
.
├── README.md                # Main curated list (the primary deliverable)
├── CLAUDE.md                # This file — AI assistant guidance
├── CLAUDE.local.md          # Personal/local overrides (gitignored, do not commit)
├── CONTRIBUTING.md          # Contribution standards
├── CODE_OF_CONDUCT.md
├── LICENSE.md               # GNU license
├── PWA-AND-HOOKS.md         # PWA install guide + local git-hook automation docs
├── .travis.yml              # CI configuration (ShellCheck on master/testing)
├── .gitignore               # Ignores log/ directory
├── _config.yml              # GitHub Pages config (serves index.html, excludes docs/scripts)
│
├── index.html               # Immersive 3D "Codex" landing page (GitHub Pages / PWA shell)
├── manifest.webmanifest     # PWA manifest (name, icons, display mode)
├── sw.js                    # Service worker (offline precache + runtime caching)
├── icons/                   # Generated PWA icons (icon-192/512, maskable-512, favicon-64)
│
├── src/                     # Bash utility scripts (real, working scripts)
│   ├── syshealth.sh         #   system health report (load, memory, disk, services)
│   ├── diskusage.sh         #   disk usage reporter with alert thresholds
│   ├── logclean.sh          #   rotate/compress old logs
│   ├── netdiag.sh           #   network diagnostics (ping, DNS, traceroute, port)
│   └── sslcheck.sh          #   SSL/TLS certificate expiry checker
├── lib/
│   └── common.sh            # Shared bash helpers (print_header, require_cmd, ...) — sourced, not run
├── skel/                    # Skeleton/template files (placeholder — .gitkeep only)
├── bin/
│   └── git-template-full    # One-time signed-off-by git-template setup
│
├── scripts/
│   ├── install-hooks.sh     # Point git at tracked .githooks/ (run once per clone)
│   └── gen_icons.py         # Regenerate PWA icons (needs python3 + Pillow)
│
├── .githooks/               # Tracked git hooks (enabled via core.hooksPath)
│   ├── pre-push             #   lints manifest/sw.js/index.html before push
│   └── post-merge          #   regenerates icons + bumps SW build stamp after pull
│
├── .claude/
│   ├── settings.json        # Hooks: PostToolUse shellcheck + README link check, Stop reminder
│   ├── hooks/               # check-readme-links.sh (validates README hrefs after edits)
│   ├── skills/              # Reusable workflow skills (SKILL.md files, incl. add-entry)
│   └── agents/              # Custom subagents (e.g. readme-reviewer.md)
│
└── doc/
    └── img/                 # Project images (awesome_ninja_admins.png)
```

## Development Workflow

### Branches

- `master` — stable, production branch
- `testing` — integration branch; **all pull requests target this branch first**
- Feature branches are named descriptively (e.g., `claude/claude-md-docs-oyll4d`)

### Making Changes

1. Base changes on the latest `master`
2. **IMPORTANT: Submit pull requests to the `testing` branch, NOT `master`**
3. Every commit **must** include a signed-off-by line (see below)

### Commit Signatures

**IMPORTANT: All commits require a signed-off-by line. Never commit without it.**

Commit messages follow this pattern:
```
<short description> - signed-off-by: Name <email>
```

To add it automatically, either run the one-time template setup:

```bash
bash bin/git-template-full
```

…or install a `prepare-commit-msg` hook:

```bash
# .git/hooks/prepare-commit-msg
SOB=$(git var GIT_AUTHOR_IDENT | sed -n 's/^\(.*>\).*$/- signed-off-by: \1/p')
grep -qs "^$SOB" "$1" || echo "$SOB" >> "$1"
```

The `.claude/settings.json` **Stop** hook prints a reminder if the last commit is missing the signed-off-by line.

### Local git hooks (`.githooks/`)

The repo ships tracked hooks under `.githooks/`, wired up via `core.hooksPath` so they travel with the repo. **Enable them once per clone:**

```bash
bash scripts/install-hooks.sh
```

| Hook          | What it does                                                                                     |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `pre-push`    | Blocks the push if `manifest.webmanifest` is invalid JSON/missing keys, `sw.js` has syntax errors, or `index.html` is missing its manifest link / SW registration. |
| `post-merge`  | After a pull/merge, regenerates icons if `gen_icons.py`/`manifest.webmanifest` changed, and bumps the `sw.js` `BUILD_STAMP` when any PWA shell file changed. |

Bypass when necessary: `git push --no-verify`. Icon regeneration needs `python3` + `pillow`; `sw.js` syntax check uses `node --check` when available (falls back to a grep sanity check). See `PWA-AND-HOOKS.md` for full details.

## Linting and Validation

### ShellCheck

All Bash scripts in `src/`, `lib/`, and `bin/` must pass ShellCheck before merging.

**Run locally:**
```bash
shellcheck --version
shellcheck -s bash -e 1072,1094 -x src/* -x lib/* bin/git-template-full
```

Flags:
- `-s bash` — treat files as bash scripts
- `-e 1072,1094` — suppress these false-positive error codes
- `-x` — follow sourced files (needed because `src/*` scripts source `lib/common.sh`)

If a non-critical warning like SC2154 appears and cannot be fixed, suppress it inline:
```bash
# shellcheck disable=SC2154
```

The `.claude/settings.json` **PostToolUse** hook automatically runs ShellCheck on any edited file under `src/`, `lib/`, or `bin/`.

### PWA validation

The `pre-push` hook is the PWA gate (see above). To check manually before pushing:
- `python3 -c "import json; json.load(open('manifest.webmanifest'))"` — manifest is valid JSON
- `node --check sw.js` — service worker parses
- Confirm `index.html` still has `<link rel="manifest">` and a `serviceWorker` registration

When editing PWA shell files (`index.html`, `sw.js`, `manifest.webmanifest`, `icons/`), bump the `VERSION` constant in `sw.js` (or let `post-merge` stamp `BUILD_STAMP`) so browsers refresh their cache.

### CI (Travis CI)

CI runs ShellCheck on `master` and `testing` branches only. It installs shellcheck from the Debian unstable repository to get a recent version. There is **no GitHub Actions workflow** — only `.travis.yml`. CI does **not** validate the PWA; that is enforced locally by the `pre-push` hook.

## Content Conventions (README.md)

The curated list uses a specific HTML-in-Markdown format. **Follow these patterns exactly** when adding entries.

### Section headers

```markdown
#### Category Name

##### :black_small_square: Subcategory

<p>
&nbsp;&nbsp;:small_orange_diamond: <a href="URL"><b>Tool Name</b></a> - brief description.<br>
</p>
```

### Entry format

Each entry is a `<p>` block with `&nbsp;&nbsp;:small_orange_diamond:` prefix, a bold linked name, an em dash, a short description, and a `<br>` at the end. Keep descriptions concise — one line.

Example:
```html
<p>
&nbsp;&nbsp;:small_orange_diamond: <a href="https://example.com/"><b>Tool Name</b></a> - one-line description of what it does.<br>
</p>
```

All `href` values must start with `http://`, `https://`, `#`, or `mailto:` — the `.claude/hooks/check-readme-links.sh` hook flags anything else after an edit. Prefer the `add-entry` skill (`.claude/skills/add-entry/`) to add entries in the correct format.

### Existing categories in README.md

- CLI Tools → Shells, Managers, Network, Databases
- Web Tools → SSL, HTTP Headers, DNS, Mail, Mass scanners, Net-tools, Performance, Passwords
- Manuals/Howtos/Tutorials → Bash, Unix tutorials, Hacking
- Blogs
- Systems/Services → Systems, HTTP(s) Services, Security/hardening
- One-liners
- Lists
- Other

When adding entries, place them in the most appropriate existing category before creating a new one.

## Bash Script Standards

`src/` scripts are real, working utilities that source shared helpers from `lib/common.sh` (e.g. `print_header`, `print_error`, `print_warn`, `require_cmd`). When adding or editing scripts, reuse these helpers rather than reinventing them.

References:
- [Bash Hackers Wiki](http://wiki.bash-hackers.org/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shell.xml)
- [bashstyle](https://github.com/progrium/bashstyle)

Key conventions:
- Use `#!/usr/bin/env bash` (not `#!/bin/bash`)
- Start scripts with `set -euo pipefail`
- Source the shared lib relative to the script: `source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`
- `lib/common.sh` is **sourced, not executed** — don't add a shebang-driven entry point there
- Use `su -` for root login (not `su`)
- All scripts must pass `shellcheck -s bash -e 1072,1094 -x`

## Claude Code Features Available

### Importing other files

CLAUDE.md can import additional context files using `@path/to/file` syntax:
```markdown
See @README.md for the current list content.
See @CONTRIBUTING.md for contribution rules.
```

### CLAUDE.local.md

Create `CLAUDE.local.md` in the project root for personal session overrides (e.g., your name/email for signed commits). **Add it to `.gitignore` — do not commit it.**

### Hooks (active)

`.claude/settings.json` defines these hooks, which run automatically:
- **PostToolUse** (after `Edit`/`Write`) — runs ShellCheck on edited `src/`/`lib/`/`bin/` files, and runs `.claude/hooks/check-readme-links.sh` to validate README links.
- **Stop** — warns if the last commit is missing the required signed-off-by line.

### Skills

`.claude/skills/<name>/SKILL.md` holds reusable workflows. The repo-specific one is **`add-entry`** (adds a README entry in the correct format); the rest are a large library of AI-tooling/workflow skills.

### Subagents

`.claude/agents/` defines custom subagents — notably **`readme-reviewer`**, which reviews README entries for formatting consistency and duplicates.

## What AI Assistants Should Know

- **README is the primary deliverable.** Most contributions are new entries in `README.md`; some are Bash scripts in `src/` or PWA changes.
- **No package build step.** There is no `npm install` or `make`. Markdown and the PWA are served as-is. The only "build" is `scripts/gen_icons.py`, which regenerates PWA icons (needs Pillow).
- **Tests = ShellCheck** for Bash, and the **`pre-push` hook** for the PWA. Markdown has no test.
- **IMPORTANT: Signed commits are required.** Never commit without the signed-off-by line.
- **IMPORTANT: PR target is `testing`**, not `master`.
- **`src/` and `lib/` now contain real scripts** — no longer placeholders. `skel/` is still an empty placeholder (`.gitkeep` only). Do not delete `src/`, `lib/`, or `skel/`.
- **`log/` is gitignored** — do not commit anything to that directory.
- **Enable the tracked hooks** with `bash scripts/install-hooks.sh` after cloning if you'll push PWA changes.
- **When editing PWA shell files**, bump `sw.js` `VERSION` so caches refresh, and keep `index.html` ↔ `manifest.webmanifest` ↔ `icons/` in sync (the `pre-push` hook enforces the link).
- **When compacting context**, preserve: the signed-off-by requirement, the PR target branch (`testing`), and any list of modified files.
- **Explore before editing README.md** — read the current file first to avoid duplicate entries and ensure correct category placement.
