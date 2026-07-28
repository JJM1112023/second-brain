#!/usr/bin/env bash
# Disk usage reporter with configurable alert thresholds.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly DEFAULT_WARN=80
readonly DEFAULT_CRIT=90

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [path ...]

Options:
  -w PCT    Warn threshold percentage (default: ${DEFAULT_WARN})
  -c PCT    Critical threshold percentage (default: ${DEFAULT_CRIT})
  -t DIR    Show top N largest directories under DIR
  -n N      Number of top directories to show (default: 10)
  -h        Show this help

Examples:
  $(basename "$0")
  $(basename "$0") -w 70 -c 85
  $(basename "$0") -t /var -n 5
EOF
}

check_filesystems() {
  local warn="$1"
  local crit="$2"

  print_header "Filesystem Usage"
  printf '%-30s %6s %6s %6s %6s  %s\n' \
    "FILESYSTEM" "SIZE" "USED" "AVAIL" "USE%" "MOUNTED ON"
  printf '%s\n' "--------------------------------------------------------------------------------"

  local exit_code=0
  while IFS= read -r line; do
    local pct mount
    pct=$(printf '%s' "${line}" | awk '{print $5}' | tr -d '%')
    mount=$(printf '%s' "${line}" | awk '{print $6}')

    if [[ "${pct}" -ge "${crit}" ]]; then
      printf 'CRITICAL: %s\n' "${line}"
      exit_code=2
    elif [[ "${pct}" -ge "${warn}" ]]; then
      printf 'WARNING:  %s\n' "${line}"
      [[ "${exit_code}" -lt 1 ]] && exit_code=1
    else
      printf 'OK:       %s\n' "${line}"
    fi
    : "${mount}"
  # -P (POSIX) keeps each filesystem on one line — plain df -h wraps long
  # device names, which puts a non-numeric value in $5 and breaks the checks.
  done < <(df -hP | grep -vE '^(Filesystem|tmpfs|udev)' | awk 'NR>0{print}')

  return "${exit_code}"
}

show_top_dirs() {
  local dir="$1"
  local count="$2"

  print_header "Top ${count} Directories by Size under ${dir}"
  require_cmd du
  du -h --max-depth=1 "${dir}" 2>/dev/null \
    | sort -rh \
    | head -n "$(( count + 1 ))" \
    | tail -n "${count}"
}

main() {
  local warn="${DEFAULT_WARN}"
  local crit="${DEFAULT_CRIT}"
  local top_dir=""
  local top_n=10

  while getopts ":w:c:t:n:h" opt; do
    case "${opt}" in
      w) warn="${OPTARG}" ;;
      c) crit="${OPTARG}" ;;
      t) top_dir="${OPTARG}" ;;
      n) top_n="${OPTARG}" ;;
      h) usage; exit 0 ;;
      :) print_error "-${OPTARG} requires an argument"; exit 1 ;;
      *) print_error "Unknown option: -${OPTARG}"; usage >&2; exit 1 ;;
    esac
  done

  printf 'Disk Usage Report — %s — %s\n' "$(hostname)" "$(date)"

  check_filesystems "${warn}" "${crit}"

  if [[ -n "${top_dir}" ]]; then
    if [[ ! -d "${top_dir}" ]]; then
      print_error "Directory does not exist: ${top_dir}"
      exit 1
    fi
    show_top_dirs "${top_dir}" "${top_n}"
  fi
}

main "$@"
