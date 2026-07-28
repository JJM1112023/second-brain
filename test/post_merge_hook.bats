#!/usr/bin/env bats
# Tests for the .githooks/post-merge hook: BUILD_STAMP bumping and icon
# regeneration triggering, against fixture git repos with real history.

load test_helper

OLD_STAMP="00000000000000"

setup() {
  common_setup
  FIXTURE="${TEST_TMP}/fixture"
  mkdir -p "${FIXTURE}/.githooks"
  git init -q "${FIXTURE}"

  printf 'const VERSION = "v1.0.0";\nconst BUILD_STAMP = "%s";\n' "${OLD_STAMP}" \
    > "${FIXTURE}/sw.js"
  printf '<html>shell</html>\n' > "${FIXTURE}/index.html"
  printf 'unrelated\n' > "${FIXTURE}/other.txt"
  cp "${REPO_ROOT}/.githooks/post-merge" "${FIXTURE}/.githooks/"

  fixture_git add .
  fixture_git commit -q -m 'base'
}

teardown() { common_teardown; }

fixture_git() {
  git -C "${FIXTURE}" -c user.name=test -c user.email=test@example.com "$@"
}

# Commit the current working tree as a "merge result" and point ORIG_HEAD at
# the previous commit, which is the state post-merge runs in after git pull.
simulate_merge() {
  fixture_git add .
  fixture_git commit -q -m 'merged change'
  fixture_git update-ref ORIG_HEAD HEAD~1
}

run_hook() {
  run bash -c "cd '${FIXTURE}' && bash .githooks/post-merge"
}

@test "post-merge: bumps BUILD_STAMP when a PWA shell file changed" {
  printf '<html>shell v2</html>\n' > "${FIXTURE}/index.html"
  simulate_merge
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"sw.js BUILD_STAMP="* ]]
  ! grep -q "${OLD_STAMP}" "${FIXTURE}/sw.js"
  grep -q 'BUILD_STAMP = "' "${FIXTURE}/sw.js"
}

@test "post-merge: leaves BUILD_STAMP alone for unrelated changes" {
  printf 'still unrelated\n' > "${FIXTURE}/other.txt"
  simulate_merge
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"BUILD_STAMP="* ]]
  grep -q "${OLD_STAMP}" "${FIXTURE}/sw.js"
}

@test "post-merge: manifest change triggers icon regeneration path" {
  printf '{"name": "x"}\n' > "${FIXTURE}/manifest.webmanifest"
  simulate_merge
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"regenerating PWA icons"* ]]
}

@test "post-merge: is a no-op without ORIG_HEAD (fresh clone, no merge)" {
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"done."* ]]
  grep -q "${OLD_STAMP}" "${FIXTURE}/sw.js"
}
