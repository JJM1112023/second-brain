#!/usr/bin/env bash
# Network diagnostic: ping, DNS lookup, traceroute, and port check for a host.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly DEFAULT_PORT=80
readonly PING_COUNT=4

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] host

Options:
  -p PORT   Port to test connectivity (default: ${DEFAULT_PORT})
  -h        Show this help

Examples:
  $(basename "$0") example.com
  $(basename "$0") -p 443 example.com
EOF
}

run_ping() {
  local host="$1"
  print_header "Ping (${PING_COUNT} packets)"
  if ping -c "${PING_COUNT}" "${host}" 2>/dev/null; then
    return 0
  else
    print_warn "Ping failed or host unreachable"
    return 1
  fi
}

run_dns() {
  local host="$1"
  print_header "DNS Lookup"
  require_cmd dig
  dig +short "${host}" A
  dig +short "${host}" AAAA
  printf 'PTR: '; dig +short -x "$(dig +short "${host}" A | head -1)" 2>/dev/null || true
}

run_traceroute() {
  local host="$1"
  print_header "Traceroute"
  if command -v traceroute &>/dev/null; then
    traceroute -m 15 "${host}" 2>/dev/null || true
  elif command -v mtr &>/dev/null; then
    mtr --report --report-cycles 3 "${host}" 2>/dev/null || true
  else
    print_warn "Neither traceroute nor mtr found — skipping"
  fi
}

run_port_check() {
  local host="$1"
  local port="$2"
  print_header "Port Check (${host}:${port})"
  if bash -c ">/dev/tcp/${host}/${port}" 2>/dev/null; then
    printf 'Port %s is OPEN\n' "${port}"
  else
    printf 'Port %s is CLOSED or FILTERED\n' "${port}"
  fi
}

main() {
  local port="${DEFAULT_PORT}"

  while getopts ":p:h" opt; do
    case "${opt}" in
      p) port="${OPTARG}" ;;
      h) usage; exit 0 ;;
      :) print_error "-${OPTARG} requires an argument"; exit 1 ;;
      *) print_error "Unknown option: -${OPTARG}"; usage >&2; exit 1 ;;
    esac
  done
  shift $(( OPTIND - 1 ))

  if [[ "$#" -ne 1 ]]; then
    print_error "Exactly one host required"
    usage >&2
    exit 1
  fi

  local host="$1"
  printf 'Network Diagnostic — %s — %s\n' "${host}" "$(date)"

  run_ping "${host}" || true
  run_dns "${host}"
  run_traceroute "${host}"
  run_port_check "${host}" "${port}"
}

main "$@"
