#!/usr/bin/env bash
# Print a system health report: load, memory, disk, and failed services.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

check_cpu() {
  print_header "CPU / Load"
  local load
  load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
  printf 'Load average: %s\n' "${load}"
}

check_memory() {
  print_header "Memory"
  require_cmd free
  free -h
}

check_disk() {
  print_header "Disk Usage"
  df -h | grep -v '^tmpfs' || true
}

check_services() {
  print_header "Failed Services"
  if command -v systemctl &>/dev/null; then
    systemctl list-units --state=failed --no-legend 2>/dev/null || true
  else
    print_warn "systemd not available on this system"
  fi
}

main() {
  printf 'System Health — %s — %s\n' "$(hostname)" "$(date)"
  check_cpu
  check_memory
  check_disk
  check_services
}

main "$@"
