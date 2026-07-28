#!/usr/bin/env bash
# Remove old compressed logs and gzip large uncompressed log files.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly DEFAULT_LOG_DIR="/var/log"
readonly DEFAULT_MAX_AGE=30

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -d DIR    Log directory to clean (default: ${DEFAULT_LOG_DIR})
  -a DAYS   Remove .gz logs older than DAYS days (default: ${DEFAULT_MAX_AGE})
  -n        Dry run: print actions without executing them
  -h        Show this help
EOF
}

main() {
  local log_dir="${DEFAULT_LOG_DIR}"
  local max_age="${DEFAULT_MAX_AGE}"
  local dry_run=0

  while getopts ":d:a:nh" opt; do
    case "${opt}" in
      d) log_dir="${OPTARG}" ;;
      a) max_age="${OPTARG}" ;;
      n) dry_run=1 ;;
      h) usage; exit 0 ;;
      :) print_error "-${OPTARG} requires an argument"; exit 1 ;;
      *) print_error "Unknown option: -${OPTARG}"; usage >&2; exit 1 ;;
    esac
  done

  if [[ ! -d "${log_dir}" ]]; then
    print_error "Directory does not exist: ${log_dir}"
    exit 1
  fi

  printf 'Log cleanup — dir: %s  max_age: %sd  dry_run: %s\n' \
    "${log_dir}" "${max_age}" "${dry_run}"

  print_header "Removing old compressed logs"
  while IFS= read -r -d '' file; do
    if [[ "${dry_run}" -eq 1 ]]; then
      printf '[dry-run] remove: %s\n' "${file}"
    else
      rm -f "${file}"
      printf 'Removed: %s\n' "${file}"
    fi
  done < <(find "${log_dir}" -maxdepth 2 -name '*.gz' -mtime +"${max_age}" -print0 2>/dev/null)

  print_header "Compressing large logs (> 1M)"
  while IFS= read -r -d '' file; do
    if [[ "${dry_run}" -eq 1 ]]; then
      printf '[dry-run] compress: %s\n' "${file}"
    else
      gzip -9 "${file}"
      printf 'Compressed: %s\n' "${file}"
    fi
  done < <(find "${log_dir}" -maxdepth 2 -name '*.log' -size +1M -print0 2>/dev/null)

  printf 'Done.\n'
}

main "$@"
