#!/usr/bin/env bats
# Tests for src/safeinstall.sh — the safe curl|sh alternative.
# Hermetic: curl is stubbed (no network); "installers" are local scripts that
# touch marker files so execution vs non-execution is observable.

load test_helper

setup() {
  common_setup
  SCRIPT="${REPO_ROOT}/src/safeinstall.sh"

  # The payload our stubbed curl "downloads"
  PAYLOAD="${TEST_TMP}/payload.sh"
  printf '#!/bin/sh\ntouch "%s/ran"\nexit 0\n' "${TEST_TMP}" > "${PAYLOAD}"
  PAYLOAD_SHA=$(sha256sum "${PAYLOAD}" | cut -d' ' -f1)

  # curl stub: copy $CURL_PAYLOAD to the path after -o; exit $CURL_EXIT
  make_stub curl '
    out=""
    prev=""
    for a in "$@"; do
      [ "$prev" = "-o" ] && out="$a"
      prev="$a"
    done
    [ "${CURL_EXIT:-0}" -ne 0 ] && exit "${CURL_EXIT}"
    [ -n "$out" ] && cat "${CURL_PAYLOAD}" > "$out"
    exit 0
  '
}

teardown() { common_teardown; }

run_safeinstall() {
  run env PATH="${STUB_DIR}:${PATH}" CURL_PAYLOAD="${PAYLOAD}" bash "${SCRIPT}" "$@"
}

@test "safeinstall: -h prints usage and exits 0" {
  run_safeinstall -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"curl URL | sh"* ]]
}

@test "safeinstall: no URL exits 1" {
  run_safeinstall
  [ "$status" -eq 1 ]
  [[ "$output" == *"No URL specified"* ]]
}

@test "safeinstall: rejects non-https URLs" {
  run_safeinstall http://example.com/install.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Only https:// URLs are accepted"* ]]
}

@test "safeinstall: unknown option exits 1" {
  run_safeinstall -z https://example.com/install.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "safeinstall: missing argument for -c exits 1" {
  run_safeinstall -c
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires an argument"* ]]
}

@test "safeinstall: inspect-only downloads, reports SHA, executes nothing" {
  run_safeinstall -n https://example.com/install.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHA-256  : ${PAYLOAD_SHA}"* ]]
  [[ "$output" == *"Inspect-only mode: nothing executed"* ]]
  [ ! -e "${TEST_TMP}/ran" ]
}

@test "safeinstall: inspect-only prints a ready-made pin line" {
  run_safeinstall -n https://example.com/install.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"-c ${PAYLOAD_SHA} https://example.com/install.sh"* ]]
}

@test "safeinstall: checksum mismatch refuses to execute" {
  run_safeinstall -y -c "0000000000000000000000000000000000000000000000000000000000000000" \
    https://example.com/install.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum mismatch"* ]]
  [ ! -e "${TEST_TMP}/ran" ]
}

@test "safeinstall: pinned checksum + -y executes the installer" {
  run_safeinstall -y -c "${PAYLOAD_SHA}" https://example.com/install.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checksum : OK"* ]]
  [ -e "${TEST_TMP}/ran" ]
}

@test "safeinstall: checksum comparison is case-insensitive" {
  upper=$(printf '%s' "${PAYLOAD_SHA}" | tr '[:lower:]' '[:upper:]')
  run_safeinstall -y -c "${upper}" https://example.com/install.sh
  [ "$status" -eq 0 ]
  [ -e "${TEST_TMP}/ran" ]
}

@test "safeinstall: -y without -c warns about trusting the server" {
  run_safeinstall -y https://example.com/install.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"trusts the server blindly"* ]]
}

@test "safeinstall: refuses to run unreviewed when stdin is not a terminal" {
  run_safeinstall https://example.com/install.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"stdin is not a terminal"* ]]
  [ ! -e "${TEST_TMP}/ran" ]
}

@test "safeinstall: download failure exits 1" {
  run env PATH="${STUB_DIR}:${PATH}" CURL_PAYLOAD="${PAYLOAD}" CURL_EXIT=22 \
    bash "${SCRIPT}" -n https://example.com/install.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Download failed"* ]]
}

@test "safeinstall: warns when the download looks like an HTML error page" {
  printf '<!doctype html><html><body>404</body></html>\n' > "${PAYLOAD}"
  run_safeinstall -n https://example.com/install.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"looks like HTML, not a shell script"* ]]
}

@test "safeinstall: -o saves an audit copy" {
  run_safeinstall -n -o "${TEST_TMP}/audit.sh" https://example.com/install.sh
  [ "$status" -eq 0 ]
  [ -f "${TEST_TMP}/audit.sh" ]
  cmp -s "${TEST_TMP}/audit.sh" "${PAYLOAD}"
}

@test "safeinstall: propagates the installer's exit code" {
  printf '#!/bin/sh\nexit 7\n' > "${PAYLOAD}"
  sha=$(sha256sum "${PAYLOAD}" | cut -d' ' -f1)
  run_safeinstall -y -c "${sha}" https://example.com/install.sh
  [ "$status" -eq 7 ]
  [[ "$output" == *"exited with status 7"* ]]
}

@test "safeinstall: passes extra arguments through to the installer" {
  printf '#!/bin/sh\necho "args:$*" > "%s/args"\n' "${TEST_TMP}" > "${PAYLOAD}"
  sha=$(sha256sum "${PAYLOAD}" | cut -d' ' -f1)
  run_safeinstall -y -c "${sha}" https://example.com/install.sh --prefix=/opt
  [ "$status" -eq 0 ]
  grep -q -- 'args:--prefix=/opt' "${TEST_TMP}/args"
}
