#!/usr/bin/env bats
# Functional tests for src/logclean.sh against a temp-dir fixture.
# Highest-risk script in the repo: it removes and compresses files.

load test_helper

SCRIPT="src/logclean.sh"

setup() {
  common_setup
  LOG_DIR="${TEST_TMP}/logs"
  mkdir -p "${LOG_DIR}"

  # .gz older than the default 30-day threshold -> should be removed
  printf 'old' > "${LOG_DIR}/old.log.gz"
  touch -d '40 days ago' "${LOG_DIR}/old.log.gz"

  # fresh .gz -> should be kept
  printf 'recent' > "${LOG_DIR}/recent.log.gz"

  # uncompressed log over 1M -> should be gzipped
  truncate -s 2M "${LOG_DIR}/big.log"

  # small uncompressed log -> should be left alone
  printf 'small' > "${LOG_DIR}/small.log"
}

teardown() { common_teardown; }

@test "logclean: dry run reports actions but touches nothing" {
  run "${REPO_ROOT}/${SCRIPT}" -n -d "${LOG_DIR}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] remove: ${LOG_DIR}/old.log.gz"* ]]
  [[ "$output" == *"[dry-run] compress: ${LOG_DIR}/big.log"* ]]

  [ -e "${LOG_DIR}/old.log.gz" ]
  [ -e "${LOG_DIR}/big.log" ]
  [ ! -e "${LOG_DIR}/big.log.gz" ]
}

@test "logclean: removes old .gz and keeps recent .gz" {
  run "${REPO_ROOT}/${SCRIPT}" -d "${LOG_DIR}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed: ${LOG_DIR}/old.log.gz"* ]]

  [ ! -e "${LOG_DIR}/old.log.gz" ]
  [ -e "${LOG_DIR}/recent.log.gz" ]
}

@test "logclean: compresses logs over 1M and leaves small logs alone" {
  run "${REPO_ROOT}/${SCRIPT}" -d "${LOG_DIR}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Compressed: ${LOG_DIR}/big.log"* ]]

  [ -e "${LOG_DIR}/big.log.gz" ]
  [ ! -e "${LOG_DIR}/big.log" ]
  [ -e "${LOG_DIR}/small.log" ]
  [ ! -e "${LOG_DIR}/small.log.gz" ]
}

@test "logclean: -a raises the age threshold so newer .gz survive" {
  run "${REPO_ROOT}/${SCRIPT}" -d "${LOG_DIR}" -a 60
  [ "$status" -eq 0 ]
  [ -e "${LOG_DIR}/old.log.gz" ]
}

@test "logclean: errors on a nonexistent directory" {
  run "${REPO_ROOT}/${SCRIPT}" -d "${TEST_TMP}/no-such-dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Directory does not exist"* ]]
}

@test "logclean: -h prints usage and exits 0" {
  run "${REPO_ROOT}/${SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "logclean: unknown option exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -z
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "logclean: missing argument for -d exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -d
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires an argument"* ]]
}
