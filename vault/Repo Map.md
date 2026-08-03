---
title: Repo Map
tags:
  - repo
  - moc
---

# 🗺️ Repo Map

How this repository is wired. Up: [[Home]]

## Deliverables

| Path | What it is |
|---|---|
| `README.md` | The curated tool list — the primary deliverable |
| `vault/` | This Obsidian vault (generated) |
| `zero-brain/` | [[Z.E.R.O. Console]] — the browser dashboard |
| `index.html` | Immersive 3D landing page / PWA shell |
| `.claude/skills/` | The skill library |

## Bash layer

| Script | Purpose |
|---|---|
| `src/syshealth.sh` | System health report |
| `src/diskusage.sh` | Disk usage with alert thresholds |
| `src/logclean.sh` | Rotate and compress old logs |
| `src/netdiag.sh` | Network diagnostics |
| `src/safeinstall.sh` | Safe curl-pipe-sh alternative with checksum pinning |
| `src/sslcheck.sh` | TLS certificate expiry checker |
| `lib/common.sh` | Shared helpers (sourced, never executed) |

## Validation

| Gate | Command |
|---|---|
| Shell lint | `shellcheck -s bash -e 1072,1094 -x src/*.sh lib/common.sh` |
| Functional tests | `bats test/` |
| PWA shell | `bash scripts/validate-pwa.sh` |
| README quality | `bash scripts/check-readme.sh` |
| Vault integrity | `bash scripts/check-vault.sh` |
| Regenerate everything | `python3 scripts/gen_secondbrain.py` |

## Rules that never bend

- Every commit carries a `signed-off-by` line.
- Pull requests target `testing`, never `master`.
- Editing PWA shell files means bumping `VERSION` in `sw.js`.
- `vault/` and `zero-brain/brain.json` are generated — edit the sources, then rerun the generator.
