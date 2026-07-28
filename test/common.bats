#!/usr/bin/env bats
# Unit tests for lib/common.sh helper functions.

load test_helper

setup() { common_setup; }
teardown() { common_teardown; }

# Run a snippet with lib/common.sh sourced.
with_lib() {
  run bash -c "source '${REPO_ROOT}/lib/common.sh'; $1"
}

@test "print_header wraps the title in === markers" {
  with_lib "print_header 'My Section'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== My Section ==="* ]]
}

@test "print_error writes to stderr, not stdout" {
  with_lib "print_error 'boom' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  with_lib "print_error 'boom' 2>&1 1>/dev/null"
  [[ "$output" == *"Error: boom"* ]]
}

@test "print_warn writes to stdout" {
  with_lib "print_warn 'heads up' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: heads up"* ]]
}

@test "require_cmd returns 0 for an existing command" {
  with_lib "require_cmd bash"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "require_cmd returns 1 and reports a missing command" {
  with_lib "require_cmd definitely-not-a-real-command-xyz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Required command not found: definitely-not-a-real-command-xyz"* ]]
}

@test "common.sh sources cleanly under set -euo pipefail" {
  run bash -c "set -euo pipefail; source '${REPO_ROOT}/lib/common.sh'"
  [ "$status" -eq 0 ]
}
