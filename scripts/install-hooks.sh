#!/usr/bin/env bash
# Point this repo at the tracked hooks in .githooks/.
# Run once after cloning:  bash scripts/install-hooks.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

chmod +x .githooks/*
git config core.hooksPath .githooks

echo "installed hooks from .githooks/"
git config --get core.hooksPath
ls -la .githooks/
