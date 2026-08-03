# CLAUDE.md

This file provides guidance for AI assistants working with the **awesome-ninja-admins** repository.

## Project Type

This is an **awesome-list** repository. Keep entries alphabetized within categories, ensure all links point to valid `http://` or `https://` URLs, and follow the HTML-in-Markdown entry format documented below. When adding entries, always read `README.md` first to avoid duplicates and place items in the correct existing category.

## Project Overview

This is a curated "Awesome" list repository — a collection of tools, manuals, blogs, hacks, and resources for system administrators (Ninja Admins). The primary deliverable is the curated list in `README.md`, but the repo has grown two additional layers:

1. **Bash utility scripts** — working sysadmin scripts live in `src/`, sharing helpers from `lib/common.sh`.
2. **A Progressive Web App (PWA)** — an immersive 3D landing page (`index.html`) served via GitHub Pages, installable and offline-capable through a service worker (`sw.js`) and web manifest.
3. **A second brain** — an Obsidian vault (`vault/`) and the Z.E.R.O. knowledge-graph console (`zero-brain/`), both **generated** from the repo's own skills and README by `scripts/gen_secondbrain.py`.

**Tech stack:** Markdown (content), Bash (scripts), ShellCheck (linting), bats-core (functional tests), GitHub Actions (CI/CD), HTML/JS/Three.js + Service Worker (PWA), Python (icon generation with Pillow, second-brain generation with the stdlib).

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
├── SECOND_BRAIN_INDEX.md    # Master map; its catalog section is GENERATED
├── .github/workflows/
│   ├── ci.yml               # CI: shellcheck, bats, pwa, readme, vault, icons (PRs + master/testing)
│   └── links.yml            # Weekly README dead-link check (lychee; not PR-blocking)
├── .gitignore               # Ignores log/ directory
├── _config.yml              # GitHub Pages config (serves index.html + zero-brain/)
│
├── index.html               # Immersive 3D "Codex" landing page (GitHub Pages / PWA shell)
├── manifest.webmanifest     # PWA manifest (name, icons, display mode)
├── sw.js                    # Service worker (offline precache + runtime caching)
├── icons/                   # Generated PWA icons (icon-192/512, maskable-512, favicon-64)
│
├── zero-brain/              # Z.E.R.O. second-brain console (second PWA page)
│   ├── index.html           #   interactive 3D knowledge graph, search, roadmap, capture
│   ├── brain-data.js        #   GENERATED — the graph payload as window.__BRAIN__
│   └── brain.json           #   GENERATED — same payload, machine-readable export
│
├── vault/                   # GENERATED Obsidian vault — the mind map
│   ├── Home.md              #   root map of content; open this, then Ctrl/Cmd+G
│   ├── Pillars/             #   one note per pillar
│   ├── Skills/              #   one note per .claude/skills/ entry
│   ├── Tools/               #   one note per README category
│   ├── Roadmap.md, Repo Map.md, Z.E.R.O. Console.md
│   └── .obsidian/           #   preconfigured graph view + appearance
│
├── src/                     # Bash utility scripts (real, working scripts)
│   ├── syshealth.sh         #   system health report (load, memory, disk, services)
│   ├── diskusage.sh         #   disk usage reporter with alert thresholds
│   ├── logclean.sh          #   rotate/compress old logs
│   ├── netdiag.sh           #   network diagnostics (ping, DNS, traceroute, port)
│   ├── safeinstall.sh       #   safe curl|sh alternative (checksum pinning, review gate)
│   └── sslcheck.sh          #   SSL/TLS certificate expiry checker
├── lib/
│   └── common.sh            # Shared bash helpers (print_header, require_cmd, ...) — sourced, not run
├── test/                    # Functional test suite (hermetic — stubs external commands)
│   ├── test_helper.bash     #   shared bats setup: temp dirs + PATH-based command stubs
│   ├── common.bats          #   unit tests for lib/common.sh
│   ├── *.bats               #   one suite per src/ script, the .githooks/ hooks, the vault
│   ├── gen_icons_test.py    #   icon generator smoke test (needs Pillow)
│   └── gen_secondbrain_test.py  # second-brain generator tests (stdlib only)
├── skel/                    # Skeleton/template files (placeholder — .gitkeep only)
├── bin/
│   └── git-template-full    # One-time signed-off-by git-template setup
│
├── scripts/
│   ├── install-hooks.sh     # Point git at tracked .githooks/ (run once per clone)
│   ├── validate-pwa.sh      # PWA shell validation (shared by pre-push hook + CI pwa job)
│   ├── check-readme.sh      # README quality gate: links, duplicates, format, stat accuracy
│   ├── check-vault.sh       # Vault integrity: wikilinks, frontmatter, reachability, freshness
│   ├── check-all.sh         # Run every gate CI runs, in one command
│   ├── gen_secondbrain.py   # THE generator: skills + README → vault/ + zero-brain data
│   └── gen_icons.py         # Regenerate PWA icons (needs python3 + Pillow)
│
├── .githooks/               # Tracked git hooks (enabled via core.hooksPath)
│   ├── pre-push             #   lints manifest/sw.js/index.html before push
│   └── post-merge          #   regenerates icons + bumps SW build stamp after pull
│
├── .claude/
│   ├── settings.json        # Hooks: PostToolUse shellcheck + README link check, Stop reminder
│   ├── hooks/               # check-readme-links.sh + shellcheck-edited.sh (PostToolUse validators)
│   ├── skills/              # Reusable workflow skills (SKILL.md files: add-entry, review, ...)
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
| `pre-push`    | Blocks the push if the PWA shell is broken or the second brain is stale — delegates to `scripts/validate-pwa.sh` (manifest JSON/keys/icons, `sw.js` syntax, both HTML pages' manifest link + SW registration, `brain-data.js` wiring, precache list consistency) and `scripts/check-vault.sh`. The CI `pwa` and `vault` jobs run the same scripts. |
| `post-merge`  | After a pull/merge, regenerates icons if `gen_icons.py`/`manifest.webmanifest` changed, and bumps the `sw.js` `BUILD_STAMP` when any PWA shell file changed. |

Bypass when necessary: `git push --no-verify`. Icon regeneration needs `python3` + `pillow`; `sw.js` syntax check uses `node --check` when available (falls back to a grep sanity check). See `PWA-AND-HOOKS.md` for full details.

## Linting and Validation

### Run everything at once

```bash
bash scripts/check-all.sh
```

Runs every gate CI runs — ShellCheck, bats, PWA, README, second brain, vault,
icons — without stopping at the first failure, and prints a pass/fail/skip
summary. Missing optional tooling (shellcheck, bats, Pillow) is reported as
SKIP rather than failing. Use this before opening a PR; the individual gates
below are for when you want to iterate on one of them.

### ShellCheck

All Bash scripts in `src/`, `lib/`, and `bin/` must pass ShellCheck before merging.

**Run locally:**
```bash
shellcheck --version
shellcheck -s bash -e 1072,1094 -x src/*.sh lib/common.sh bin/git-template-full
```

Flags:
- `-s bash` — treat files as bash scripts
- `-e 1072,1094` — suppress these false-positive error codes
- `-x` — follow sourced files (needed because `src/*` scripts source `lib/common.sh`)

If a non-critical warning like SC2154 appears and cannot be fixed, suppress it inline:
```bash
# shellcheck disable=SC2154
```

The `.claude/settings.json` **PostToolUse** hook automatically runs ShellCheck on any edited `.sh` file (and anything under `src/`, `lib/`, or `bin/`).

### Functional tests (bats)

The `test/` directory holds a [bats-core](https://github.com/bats-core/bats-core) suite covering `lib/common.sh` and all `src/` scripts (threshold/exit-code logic, file removal/compression behavior, argument parsing).

**Run locally:**
```bash
bats test/
```

Tests are **hermetic**: external commands (`df`, `openssl`, `ping`, `dig`, `free`, ...) are replaced by stubs that `test/test_helper.bash` places first in `PATH`, and file operations run against per-test temp dirs — no network access and no dependence on the host's real filesystems. When adding or changing a `src/` script, add or update its `.bats` suite; use `make_stub`/`run_stubbed` from the helper rather than calling real system tools.

### PWA validation

`scripts/validate-pwa.sh` is the single source of truth for PWA shell checks — the `pre-push` hook runs it locally and the CI `pwa` job runs it on every PR. Run it manually with:

```bash
bash scripts/validate-pwa.sh
```

It validates: manifest JSON + required keys + icon files, `sw.js` syntax (`node --check` when available), `index.html` manifest link / SW registration / balanced `<script>` tags, and that every path in the `sw.js` `SHELL_ASSETS` precache list exists in the repo.

When editing PWA shell files (`index.html`, `sw.js`, `manifest.webmanifest`, `icons/`), **always bump the `VERSION` constant in `sw.js`** — the cache names (`SHELL`/`RUNTIME`) derive from it, and only a `VERSION` change rotates them. The `post-merge` hook's `BUILD_STAMP` merely byte-changes `sw.js` so browsers re-install the service worker; it does not rotate cache names and is not a substitute for a `VERSION` bump.

### Second brain (vault + Z.E.R.O. console)

`scripts/gen_secondbrain.py` is the single source of truth for both. It parses
`.claude/skills/*/SKILL.md` and `README.md`, applies the hand-maintained `PILLARS`
map at the top of the script, and writes every downstream artifact:

```bash
python3 scripts/gen_secondbrain.py           # rebuild everything
python3 scripts/gen_secondbrain.py --check   # report drift, write nothing (used by CI)
bash scripts/check-vault.sh                  # links + frontmatter + reachability + freshness
python3 test/gen_secondbrain_test.py         # generator unit tests
```

**Generated — never hand-edit:**

- `vault/**` (except that the whole directory is regenerated; deleted sources have their notes swept)
- `zero-brain/brain.json` and `zero-brain/brain-data.js`
- the block between `<!-- BEGIN GENERATED: skill-catalog -->` and its `END` marker in `SECOND_BRAIN_INDEX.md`

Hand-edit the *sources* instead (`SKILL.md` files, `README.md`, the `PILLARS` map,
`zero-brain/index.html`), then rerun the generator and commit the result. Output is
deterministic — no timestamps, everything sorted — so a stale checkout is caught by
`git diff --exit-code` in CI.

A skill missing from `PILLARS` is filed under an **Unsorted** pillar with a warning
rather than being dropped, so nothing disappears silently.

### CI (GitHub Actions)

`.github/workflows/ci.yml` runs six jobs on pushes to `master`/`testing` and on pull requests targeting those branches, so feature branches get feedback via their PR:

1. **ShellCheck** — lints `src/`, `lib/common.sh`, `bin/git-template-full`, `scripts/*.sh`, the `.githooks/` hooks, and the `.claude/hooks/` validators
2. **Bats tests** — `bats test/` (src scripts, common.sh, the git hooks, the vault checker)
3. **PWA validation** — `scripts/validate-pwa.sh` (same gate as the local `pre-push` hook)
4. **README checks** — `scripts/check-readme.sh` (link schemes, duplicate URLs, entry format, landing-page stat accuracy)
5. **Second brain** — `test/gen_secondbrain_test.py`, `scripts/check-vault.sh`, and a `git diff --exit-code` after regenerating, so a stale `vault/` or console payload fails the build
6. **Icon generator smoke test** — `test/gen_icons_test.py` with Pillow

`.github/workflows/links.yml` additionally runs a **weekly lychee dead-link check** over README.md (plus manual dispatch). It is deliberately not PR-blocking so third-party outages and link rot never fail unrelated changes.

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

All `href` values must start with `http://`, `https://`, `#`, or `mailto:` — the `.claude/hooks/check-readme-links.sh` hook flags anything else after an edit, and the CI `readme` job (`scripts/check-readme.sh`) enforces link schemes, duplicate-URL detection, and entry-format conformance on every PR. Prefer the `add-entry` skill (`.claude/skills/add-entry/`) to add entries in the correct format.

### Existing categories in README.md

- CLI Tools → Shells, Managers, Text & Search, Network, Databases
- Web Tools → SSL, HTTP Headers, DNS, Mail, Mass scanners, Net-tools, Performance, Passwords
- Manuals/Howtos/Tutorials → Bash, Unix tutorials, AI Tools & Agents, Hacking
- Blogs
- Systems/Services → Systems, HTTP(s) Services, Security/hardening
- Monitoring/Observability → System Monitoring, Log Management
- DevOps & Cloud → Kubernetes, Infrastructure as Code, CI/CD, Cloud CLIs, Service Mesh
- Infrastructure → Containers & Virtualization, Configuration Management, Backup & Recovery, VPN
- Security → Identity & Access Management, Network Security & Firewall, Network Troubleshooting, Penetration Testing Tools
- One-liners
- Lists
- Other

When adding entries, place them in the most appropriate existing category before creating a new one.

**After adding an entry, rerun the generator** (`python3 scripts/gen_secondbrain.py`) so `vault/` and the Z.E.R.O. console pick it up, and commit the regenerated files — CI fails if they are stale. Adding a *category* also means updating the landing-page stat tiles in `index.html`; `scripts/check-readme.sh` compares them against README and fails on a mismatch.

## Bash Script Standards

`src/` scripts are real, working utilities that source shared helpers from `lib/common.sh` (e.g. `print_header`, `print_error`, `print_warn`, `require_cmd`). When adding or editing scripts, reuse these helpers rather than reinventing them.

References:
- [Bash Hackers Wiki](http://wiki.bash-hackers.org/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shell.xml)
- [bashstyle](https://github.com/progrium/bashstyle)

Key conventions:
- Use `#!/usr/bin/env bash` (not `#!/bin/bash`)
- Use `set -euo pipefail` at the top of every script for safe error handling
- Source the shared lib relative to the script: `source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`
- `lib/common.sh` is **sourced, not executed** — don't add a shebang-driven entry point there
- Use `su -` for root login (not `su`)
- All scripts must pass `shellcheck -s bash -e 1072,1094 -x`
- Anchor `.env` key lookups with `^KEY=` and use `cut -d= -f2-` to preserve values containing `=`
- Never rely on `|| fallback` at the end of a pipeline — check emptiness explicitly with `[ -z "$VAR" ]`

## Code Review

**IMPORTANT: Before requesting human review or committing any shell script, run a self-review pass:**

1. Re-read the script top-to-bottom and ask: what input, state, or environment makes each line wrong?
2. Check all grep patterns are anchored and won't match unintended substrings
3. Check all pipeline fallbacks (`|| default`) actually fire when expected (they don't when the last command in the pipe exits 0)
4. Verify every exit code that matters is captured, not silently swallowed with `&>/dev/null`
5. Confirm all relative paths are guarded with a CWD check or `cd "$(dirname "$0")"`

The `/review` skill (`.claude/skills/review/`) automates this write-review-fix loop for a shell script or the current branch diff.

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
- **PostToolUse** (after `Edit`/`Write`) — runs ShellCheck on edited `.sh`/`src/`/`lib/`/`bin/` files, and runs `.claude/hooks/check-readme-links.sh` to validate README links.
- **Stop** — warns if the last commit is missing the required signed-off-by line.

### Skills

`.claude/skills/<name>/SKILL.md` holds reusable workflows. Repo-specific ones include **`add-entry`** (adds a README entry in the correct format) and **`review`** (shell-script write-review-fix loop); the rest are a large library of AI-tooling/workflow skills.

### Subagents

`.claude/agents/` defines custom subagents — notably **`readme-reviewer`**, which reviews README entries for formatting consistency and duplicates.

## What AI Assistants Should Know

- **README is the primary deliverable.** Most contributions are new entries in `README.md`; some are Bash scripts in `src/` or PWA changes.
- **No package build step.** There is no `npm install` or `make`. Markdown and the PWA are served as-is. The two "builds" are both Python: `scripts/gen_icons.py` (PWA icons, needs Pillow) and `scripts/gen_secondbrain.py` (vault + console data, stdlib only).
- **Tests = ShellCheck + the bats suite (`bats test/`)** for Bash, **`scripts/validate-pwa.sh`** for the PWA (run by both the `pre-push` hook and CI), **`scripts/check-readme.sh`** for README quality, and **`scripts/check-vault.sh`** + **`test/gen_secondbrain_test.py`** for the second brain. All of these run in CI (GitHub Actions) on PRs, plus a weekly dead-link check.
- **`vault/` and `zero-brain/brain*.{json,js}` are generated.** Edit the sources and rerun `python3 scripts/gen_secondbrain.py`; never hand-edit the output. CI fails if the committed copies are stale.
- **IMPORTANT: Signed commits are required.** Never commit without the signed-off-by line.
- **IMPORTANT: PR target is `testing`**, not `master`.
- **`src/` and `lib/` contain real scripts** — their `.gitkeep` placeholders are gone. `skel/` is still an empty placeholder (`.gitkeep` only). Do not delete `src/`, `lib/`, or `skel/`.
- **`log/` is gitignored** — do not commit anything to that directory.
- **Enable the tracked hooks** with `bash scripts/install-hooks.sh` after cloning if you'll push PWA changes.
- **When editing PWA shell files**, bump `sw.js` `VERSION` so caches refresh, and keep `index.html` ↔ `zero-brain/index.html` ↔ `manifest.webmanifest` ↔ `icons/` in sync (the `pre-push` hook enforces the links). The shell is two pages now, not one.
- **When compacting context**, preserve: the signed-off-by requirement, the PR target branch (`testing`), and any list of modified files.
- **Explore before editing README.md** — read the current file first to avoid duplicate entries and ensure correct category placement.
