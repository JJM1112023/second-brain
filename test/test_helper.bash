# Shared helpers for the bats suite. Loaded from each .bats file via `load test_helper`.
#
# Tests are hermetic: external commands (df, openssl, ping, ...) are replaced by
# stubs placed in a per-test directory that is prepended to PATH, so no test
# touches the network or depends on the host's real filesystems.

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export REPO_ROOT

# Per-test scratch space. BATS_TEST_TMPDIR needs bats >= 1.4, so make our own
# to stay compatible with the bats shipped in older distro packages.
common_setup() {
  TEST_TMP="$(mktemp -d)"
  STUB_DIR="${TEST_TMP}/stubs"
  mkdir -p "${STUB_DIR}"
}

common_teardown() {
  rm -rf "${TEST_TMP}"
}

# make_stub NAME BODY
# Create an executable stub command in STUB_DIR. BODY is a bash snippet that
# becomes the stub's script body ("$@" are the stub's arguments).
make_stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "${STUB_DIR}/$1"
  chmod +x "${STUB_DIR}/$1"
}

# run_stubbed CMD [ARGS...]
# bats `run` with STUB_DIR first in PATH so stubs shadow real commands.
run_stubbed() {
  run env PATH="${STUB_DIR}:${PATH}" "$@"
}
