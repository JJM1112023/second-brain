#!/usr/bin/env bats
# Tests for src/sslcheck.sh with a stubbed `openssl` — no network needed.

load test_helper

SCRIPT="src/sslcheck.sh"

setup() { common_setup; }
teardown() { common_teardown; }

# stub_openssl EXPIRY — stub openssl so s_client "connects" and x509 reports
# the given notAfter date. The real GNU date then does the epoch math.
stub_openssl() {
  make_stub openssl "case \"\$1\" in
  s_client) cat; echo 'fake cert chain' ;;
  x509) echo 'notAfter=$1' ;;
esac"
}

@test "sslcheck: healthy cert far from expiry -> OK, exit 0" {
  stub_openssl 'Dec 31 23:59:59 2099 GMT'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: expires in"* ]]
}

@test "sslcheck: cert inside the warn window -> WARNING" {
  stub_openssl 'Dec 31 23:59:59 2099 GMT'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" -w 999999 example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: expires in"* ]]
}

@test "sslcheck: expired cert -> EXPIRED" {
  stub_openssl 'Jan 01 00:00:00 2020 GMT'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"EXPIRED"* ]]
}

@test "sslcheck: connection failure reports error and exits 1" {
  make_stub openssl 'exit 1'
  run_stubbed "${REPO_ROOT}/${SCRIPT}" unreachable.example
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: could not connect"* ]]
}

@test "sslcheck: one bad host does not hide results for good hosts" {
  # s_client fails only for the host "bad.example"
  make_stub openssl "case \"\$1\" in
  s_client) [[ \"\$*\" == *bad.example* ]] && exit 1; cat; echo 'fake cert chain' ;;
  x509) echo 'notAfter=Dec 31 23:59:59 2099 GMT' ;;
esac"
  run_stubbed "${REPO_ROOT}/${SCRIPT}" bad.example good.example
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: could not connect"* ]]
  [[ "$output" == *"OK: expires in"* ]]
}

@test "sslcheck: no hosts specified exits 1" {
  run "${REPO_ROOT}/${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No hosts specified"* ]]
}

@test "sslcheck: -h prints usage and exits 0" {
  run "${REPO_ROOT}/${SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "sslcheck: unknown option exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -z example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "sslcheck: missing argument for -p exits 1" {
  run "${REPO_ROOT}/${SCRIPT}" -p
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires an argument"* ]]
}
