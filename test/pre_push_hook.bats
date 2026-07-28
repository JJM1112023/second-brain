#!/usr/bin/env bats
# Tests for the .githooks/pre-push PWA gate (which delegates to
# scripts/validate-pwa.sh) against fixture git repos.

load test_helper

setup() {
  common_setup
  FIXTURE="${TEST_TMP}/fixture"
  mkdir -p "${FIXTURE}/.githooks" "${FIXTURE}/scripts"
  git init -q "${FIXTURE}"

  cp "${REPO_ROOT}/manifest.webmanifest" "${FIXTURE}/"
  cp "${REPO_ROOT}/sw.js" "${FIXTURE}/"
  cp "${REPO_ROOT}/index.html" "${FIXTURE}/"
  cp -r "${REPO_ROOT}/icons" "${FIXTURE}/icons"
  cp "${REPO_ROOT}/.githooks/pre-push" "${FIXTURE}/.githooks/"
  cp "${REPO_ROOT}/scripts/validate-pwa.sh" "${FIXTURE}/scripts/"
}

teardown() { common_teardown; }

run_hook() {
  run bash -c "cd '${FIXTURE}' && bash .githooks/pre-push"
}

@test "pre-push: passes on a valid PWA shell" {
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"all checks passed"* ]]
}

@test "pre-push: blocks on invalid manifest JSON" {
  echo '{ broken' > "${FIXTURE}/manifest.webmanifest"
  run_hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"not valid JSON"* ]]
  [[ "$output" == *"push blocked"* ]]
}

@test "pre-push: blocks when a manifest icon file is missing" {
  rm "${FIXTURE}/icons/icon-192.png"
  run_hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"push blocked"* ]]
}

@test "pre-push: blocks when index.html loses its manifest link" {
  sed -i 's/rel="manifest"/rel="mannifest"/' "${FIXTURE}/index.html"
  run_hook
  [ "$status" -eq 1 ]
  [[ "$output" == *'missing <link rel="manifest">'* ]]
}

@test "pre-push: blocks on unbalanced script tags in index.html" {
  printf '<script>\n' >> "${FIXTURE}/index.html"
  run_hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"unbalanced <script> tags"* ]]
}

@test "pre-push: blocks on sw.js syntax errors" {
  command -v node >/dev/null 2>&1 || skip "node not available"
  printf 'function broken( {\n' >> "${FIXTURE}/sw.js"
  run_hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"sw.js has JS syntax errors"* ]]
}

@test "pre-push: blocks when a precached asset does not exist" {
  rm "${FIXTURE}/icons/favicon-64.png"
  run_hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"precached asset missing"* ]]
}
