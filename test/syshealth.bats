#!/usr/bin/env bats
# Hermetic smoke tests for src/syshealth.sh with stubbed system tools.

load test_helper

SCRIPT="src/syshealth.sh"

setup() {
  common_setup
  make_stub uptime 'echo " 12:00:00 up 1 day,  1 user,  load average: 0.10, 0.20, 0.30"'
  make_stub free 'printf "%s\n%s\n" "               total  used  free" "Mem:            16Gi  8Gi   8Gi"'
  make_stub df 'printf "%s\n%s\n" "Filesystem  Size  Used Avail Use% Mounted on" "/dev/root    50G   30G   20G  60% /"'
  make_stub systemctl 'echo "broken.service loaded failed failed Broken Unit"'
}

teardown() { common_teardown; }

@test "syshealth: reports all four sections and exits 0" {
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"System Health"* ]]
  [[ "$output" == *"=== CPU / Load ==="* ]]
  [[ "$output" == *"=== Memory ==="* ]]
  [[ "$output" == *"=== Disk Usage ==="* ]]
  [[ "$output" == *"=== Failed Services ==="* ]]
}

@test "syshealth: extracts the load average from uptime output" {
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Load average: 0.10, 0.20, 0.30"* ]]
}

@test "syshealth: lists failed services from systemctl" {
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"broken.service"* ]]
}

@test "syshealth: filters tmpfs lines out of the disk report" {
  make_stub df 'printf "%s\n%s\n" "/dev/root    50G   30G   20G  60% /" "tmpfs        16G     0   16G   0% /dev/shm"'
  run_stubbed "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"tmpfs"* ]]
}
