#!/usr/bin/env bash
# Safe alternative to `curl URL | sh`: download an install script, show its
# checksum, let you inspect it, and only run it after explicit confirmation.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly DEFAULT_INTERPRETER="sh"

TMPFILE=""
KEEP_TMPFILE=0

cleanup() {
  if [[ "${KEEP_TMPFILE}" -eq 0 && -n "${TMPFILE}" ]]; then
    rm -f "${TMPFILE}"
  fi
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] URL [SCRIPT_ARGS...]

Download an installer script over HTTPS, report its SHA-256, review it, and
run it only after confirmation. A safer habit than \`curl URL | sh\`.

Options:
  -c SHA256   Refuse to run unless the download matches this SHA-256 checksum
  -o FILE     Also save a copy of the downloaded script to FILE (for audit)
  -n          Download and inspect only — never execute
  -s SHELL    Interpreter to run the script with (default: ${DEFAULT_INTERPRETER})
  -y          Skip the interactive review/confirmation (for pinned, automated
              runs — strongly recommended only together with -c)
  -h          Show this help

Examples:
  $(basename "$0") -n https://cli.example.com/install.sh
  $(basename "$0") -c 3f5a...9b https://cli.example.com/install.sh
  $(basename "$0") -s bash https://example.com/setup.sh --prefix=\$HOME/.local
EOF
}

# SHA-256 of a file; GNU sha256sum with a BSD/macOS shasum fallback
sha256_of() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Report basic facts about the downloaded file so the caller can pin it later
describe_download() {
  local file="$1"
  local url="$2"
  local sha="$3"
  local bytes lines

  bytes=$(wc -c < "${file}")
  lines=$(wc -l < "${file}")

  print_header "Downloaded ${url}"
  printf 'Saved to : %s\n' "${file}"
  printf 'Size     : %s bytes (%s lines)\n' "${bytes}" "${lines}"
  printf 'SHA-256  : %s\n' "${sha}"
  printf 'Pin it   : %s -c %s %s\n' "$(basename "$0")" "${sha}" "${url}"

  # A served error page instead of a script is a common failure mode
  if head -c 1024 "${file}" | grep -qi -e '<html' -e '<!doctype'; then
    print_warn "Content looks like HTML, not a shell script — check the URL"
  fi
}

main() {
  local checksum=""
  local outfile=""
  local inspect_only=0
  local interpreter="${DEFAULT_INTERPRETER}"
  local assume_yes=0

  while getopts ":c:o:ns:yh" opt; do
    case "${opt}" in
      c) checksum="${OPTARG}" ;;
      o) outfile="${OPTARG}" ;;
      n) inspect_only=1 ;;
      s) interpreter="${OPTARG}" ;;
      y) assume_yes=1 ;;
      h) usage; exit 0 ;;
      :) print_error "-${OPTARG} requires an argument"; exit 1 ;;
      *) print_error "Unknown option: -${OPTARG}"; usage >&2; exit 1 ;;
    esac
  done
  shift $(( OPTIND - 1 ))

  if [[ "$#" -eq 0 ]]; then
    print_error "No URL specified"
    usage >&2
    exit 1
  fi

  local url="$1"
  shift

  if [[ "${url}" != https://* ]]; then
    print_error "Only https:// URLs are accepted (got: ${url})"
    exit 1
  fi

  require_cmd curl
  if ! command -v sha256sum &>/dev/null && ! command -v shasum &>/dev/null; then
    print_error "Required command not found: sha256sum (or shasum)"
    exit 1
  fi
  if [[ "${inspect_only}" -eq 0 ]]; then
    require_cmd "${interpreter}"
  fi

  TMPFILE=$(mktemp "${TMPDIR:-/tmp}/safeinstall.XXXXXX")

  # --proto '=https' also forbids redirects downgrading to plain http
  if ! curl -fsSL --proto '=https' --tlsv1.2 -o "${TMPFILE}" "${url}"; then
    print_error "Download failed: ${url}"
    exit 1
  fi

  if [[ ! -s "${TMPFILE}" ]]; then
    print_error "Server returned an empty file: ${url}"
    exit 1
  fi

  if [[ -n "${outfile}" ]]; then
    cp "${TMPFILE}" "${outfile}"
    printf 'Audit copy saved to: %s\n' "${outfile}"
  fi

  local sha
  sha=$(sha256_of "${TMPFILE}")

  describe_download "${TMPFILE}" "${url}" "${sha}"

  if [[ -n "${checksum}" ]]; then
    if [[ "${sha,,}" != "${checksum,,}" ]]; then
      KEEP_TMPFILE=1
      print_error "Checksum mismatch — expected ${checksum,,}, got ${sha}"
      print_warn "Kept the download for inspection: ${TMPFILE}"
      exit 1
    fi
    printf 'Checksum : OK (matches pinned SHA-256)\n'
  fi

  if [[ "${inspect_only}" -eq 1 ]]; then
    KEEP_TMPFILE=1
    printf '\nInspect-only mode: nothing executed. Review it with:\n'
    printf '  %s %s\n' "${PAGER:-less}" "${TMPFILE}"
    exit 0
  fi

  if [[ "${assume_yes}" -eq 0 ]]; then
    if [[ ! -t 0 ]]; then
      KEEP_TMPFILE=1
      print_error "stdin is not a terminal; refusing to run unreviewed (use -y with -c to automate)"
      print_warn "Kept the download for inspection: ${TMPFILE}"
      exit 1
    fi

    # EOF on either prompt (Ctrl-D) falls through to the safe default
    local reply
    read -r -p "View the script before running? [Y/n] " reply || reply="n"
    if [[ ! "${reply}" =~ ^[Nn]$ ]]; then
      "${PAGER:-less}" "${TMPFILE}"
    fi

    read -r -p "Execute with '${interpreter}'? [y/N] " reply || reply="n"
    if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
      KEEP_TMPFILE=1
      print_warn "Aborted by user; kept the download at ${TMPFILE}"
      exit 1
    fi
  elif [[ -z "${checksum}" ]]; then
    print_warn "Running with -y but no -c checksum pin — this trusts the server blindly"
  fi

  print_header "Executing installer"
  local rc=0
  "${interpreter}" "${TMPFILE}" "$@" || rc=$?

  if [[ "${rc}" -ne 0 ]]; then
    KEEP_TMPFILE=1
    print_error "Installer exited with status ${rc}; kept the script at ${TMPFILE}"
  fi
  return "${rc}"
}

main "$@"
