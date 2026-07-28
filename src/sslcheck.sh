#!/usr/bin/env bash
# Check SSL/TLS certificate expiry and validity for one or more hosts.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly DEFAULT_WARN_DAYS=30
readonly DEFAULT_PORT=443

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] host [host ...]

Options:
  -p PORT   Port to connect on (default: ${DEFAULT_PORT})
  -w DAYS   Warn if certificate expires within DAYS days (default: ${DEFAULT_WARN_DAYS})
  -h        Show this help

Examples:
  $(basename "$0") example.com
  $(basename "$0") -w 60 example.com api.example.com
EOF
}

check_cert() {
  local host="$1"
  local port="$2"
  local warn_days="$3"

  local cert_info expiry_date expiry_epoch now_epoch days_left

  if ! cert_info=$(echo | openssl s_client -servername "${host}" \
      -connect "${host}:${port}" 2>/dev/null); then
    printf '%-40s  ERROR: could not connect\n' "${host}:${port}"
    return 1
  fi

  expiry_date=$(echo "${cert_info}" \
    | openssl x509 -noout -enddate 2>/dev/null \
    | cut -d= -f2)

  if [[ -z "${expiry_date}" ]]; then
    printf '%-40s  ERROR: could not parse certificate\n' "${host}:${port}"
    return 1
  fi

  expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null \
    || date -jf "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  if [[ "${days_left}" -lt 0 ]]; then
    printf '%-40s  EXPIRED (%d days ago)\n' "${host}:${port}" "$(( -days_left ))"
  elif [[ "${days_left}" -lt "${warn_days}" ]]; then
    printf '%-40s  WARNING: expires in %d days  [%s]\n' \
      "${host}:${port}" "${days_left}" "${expiry_date}"
  else
    printf '%-40s  OK: expires in %d days  [%s]\n' \
      "${host}:${port}" "${days_left}" "${expiry_date}"
  fi
}

main() {
  local port="${DEFAULT_PORT}"
  local warn_days="${DEFAULT_WARN_DAYS}"

  while getopts ":p:w:h" opt; do
    case "${opt}" in
      p) port="${OPTARG}" ;;
      w) warn_days="${OPTARG}" ;;
      h) usage; exit 0 ;;
      :) print_error "-${OPTARG} requires an argument"; exit 1 ;;
      *) print_error "Unknown option: -${OPTARG}"; usage >&2; exit 1 ;;
    esac
  done
  shift $(( OPTIND - 1 ))

  if [[ "$#" -eq 0 ]]; then
    print_error "No hosts specified"
    usage >&2
    exit 1
  fi

  require_cmd openssl

  print_header "SSL Certificate Check (warn < ${warn_days} days)"
  printf '%-40s  %s\n' "HOST:PORT" "STATUS"
  printf '%s\n' "------------------------------------------------------------------------"

  local exit_code=0
  for host in "$@"; do
    check_cert "${host}" "${port}" "${warn_days}" || exit_code=1
  done

  return "${exit_code}"
}

main "$@"
