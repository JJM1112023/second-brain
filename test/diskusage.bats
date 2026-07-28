#!/usr/bin/env bats
# Functional tests for src/diskusage.sh with a stubbed `df`.
# Exercises the threshold logic and the 0/1/2 exit-code contract.

load test_helper

SCRIPT="src/diskusage.sh"

setup() { common_setup; }
teardown() { common_teardown; }

# stub_df LINES... — stub `df` to print a realistic header plus fixture rows.
stub_df() {
  local body="cat <<'EOF'
Filesystem      Size  Used Avail Use% Mounted on"
  local line
  for line in "$@"; do
    body+=$'\n'"${line}"
  done
  body+=$'\nEOF'
  make_stub df "${body}"
}

@test "diskusage: all filesystems below warn -> OK lines, exit 0" {
  stub_df '/dev/root        50G   30G   20G  60% /'
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:       /dev/root"* ]]
  [[ "$output" != *"WARNING"* ]]
  [[ "$output" != *"CRITICAL"* ]]
}

@test "diskusage: filesystem at warn threshold -> WARNING, exit 1" {
  stub_df \
    '/dev/root        50G   30G   20G  60% /' \
    '/dev/sdb1       100G   80G   20G  80% /data'
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WARNING:  /dev/sdb1"* ]]
  [[ "$output" == *"OK:       /dev/root"* ]]
}

@test "diskusage: filesystem at crit threshold -> CRITICAL, exit 2" {
  stub_df '/dev/sdb1       100G   90G   10G  90% /data'
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"CRITICAL: /dev/sdb1"* ]]
}

@test "diskusage: critical outranks warning in the exit code" {
  stub_df \
    '/dev/sda1       100G   85G   15G  85% /warn' \
    '/dev/sdb1       100G   95G    5G  95% /crit'
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"WARNING:  /dev/sda1"* ]]
  [[ "$output" == *"CRITICAL: /dev/sdb1"* ]]
}

@test "diskusage: -w and -c override the default thresholds" {
  stub_df '/dev/root        50G   30G   20G  60% /'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" -w 50 -c 99
  [ "$status" -eq 1 ]
  [[ "$output" == *"WARNING:  /dev/root"* ]]
}

@test "diskusage: tmpfs and udev filesystems are ignored" {
  stub_df \
    '/dev/root        50G   30G   20G  60% /' \
    'tmpfs            16G   16G     0  99% /dev/shm' \
    'udev             16G   16G     0  99% /dev'
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"tmpfs"* ]]
}

@test "diskusage: -t with a real directory lists top dirs" {
  stub_df '/dev/root        50G   30G   20G  60% /'
  mkdir -p "${TEST_TMP}/tree/a" "${TEST_TMP}/tree/b"
  printf 'data' > "${TEST_TMP}/tree/a/file"
  run_stubbed "${REPO_ROOT}/${SCRIPT}" -t "${TEST_TMP}/tree" -n 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Top 2 Directories by Size under ${TEST_TMP}/tree"* ]]
}

@test "diskusage: -t with a nonexistent directory exits 1" {
  stub_df '/dev/root        50G   30G   20G  60% /'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" -t "${TEST_TMP}/no-such-dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Directory does not exist"* ]]
}

@test "diskusage: -h prints usage and exits 0" {
  run "${REPO_ROOT}/${SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "diskusage: unknown option exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -z
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "diskusage: missing argument for -w exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -w
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires an argument"* ]]
}
