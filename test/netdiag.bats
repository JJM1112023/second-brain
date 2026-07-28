#!/usr/bin/env bats
# Tests for src/netdiag.sh — argument parsing plus a fully stubbed smoke run.

load test_helper

SCRIPT="src/netdiag.sh"

setup() { common_setup; }
teardown() { common_teardown; }

stub_network_tools() {
  make_stub ping 'echo "4 packets transmitted, 4 received, 0% packet loss"'
  make_stub dig 'echo "192.0.2.10"'
  make_stub traceroute 'echo " 1  gateway (192.0.2.1)  0.5 ms"'
}

# The port check uses a real /dev/tcp probe, so tests point it at 127.0.0.1
# where a closed port is refused instantly instead of hanging on a filtered
# remote host.
@test "netdiag: stubbed run covers ping, DNS, traceroute, and port check" {
  stub_network_tools
  run_stubbed "${REPO_ROOT}/${SCRIPT}" -p 1 127.0.0.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ping (4 packets)"* ]]
  [[ "$output" == *"DNS Lookup"* ]]
  [[ "$output" == *"Traceroute"* ]]
  [[ "$output" == *"Port Check (127.0.0.1:1)"* ]]
  [[ "$output" == *"CLOSED or FILTERED"* ]]
}

@test "netdiag: ping failure is a warning, not a fatal error" {
  stub_network_tools
  make_stub ping 'exit 1'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" -p 1 127.0.0.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ping failed or host unreachable"* ]]
  [[ "$output" == *"Port Check"* ]]
}

@test "netdiag: no host exits 1" {
  run "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Exactly one host required"* ]]
}

@test "netdiag: more than one host exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" one.example two.example
  [ "$status" -eq 1 ]
  [[ "$output" == *"Exactly one host required"* ]]
}

@test "netdiag: -h prints usage and exits 0" {
  run "${REPO_ROOT}/${SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "netdiag: unknown option exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -z example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "netdiag: missing argument for -p exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -p
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires an argument"* ]]
}
