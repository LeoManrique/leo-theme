#!/usr/bin/env bash
#
# 11-script.sh — shell is where quoting rules become a colouring problem.
# Single-quoted, double-quoted, unquoted, heredocs, command substitution and
# parameter expansion all have to stay distinguishable from each other.
#
# Runs clean under: shellcheck 11-script.sh

set -euo pipefail
IFS=$'\n\t'

# ── Constants ─────────────────────────────────────────────────────────────

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly VERSION='1.0.2'
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=$((30 * 2))
readonly HEX_MASK=0xFF00FF

declare -a LEVELS=(debug info warn fatal)
declare -A COLORS=(
  [chrome]='#1a1a1a'
  [surface]='#161616'
  [accent]='#5996db'
)

VERBOSE=0
DRY_RUN=false
TARGET="${PREVIEW_TARGET:-all}"

# ── Traps and cleanup ─────────────────────────────────────────────────────

TMPDIR_LOCAL="$(mktemp -d "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX")"

cleanup() {
  local code=$?
  [[ -d "$TMPDIR_LOCAL" ]] && rm -rf -- "$TMPDIR_LOCAL"
  (( code != 0 )) && printf 'failed with status %d\n' "$code" >&2
  return "$code"
}

trap cleanup EXIT
trap 'echo "interrupted" >&2; exit 130' INT TERM

# ── Functions ─────────────────────────────────────────────────────────────

log() {
  local level="$1"; shift
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '[%s] %-5s %s\n' "$ts" "$level" "$*" >&2
}

die() {
  log fatal "$@"
  exit 1
}

usage() {
  cat <<-'USAGE'
	Usage: 11-script.sh [options] <target>

	  -v, --verbose      increase verbosity (repeatable)
	  -n, --dry-run      print actions without running them
	  -t, --target NAME  one of: all, api, db, cache
	  -h, --help         show this message

	Single-quoted heredoc: $VARIABLES are NOT expanded here.
	USAGE
}

is_loud() {
  local level="$1"
  case "$level" in
    warn|fatal) return 0 ;;
    debug|info) return 1 ;;
    *)          die "unknown level: ${level}" ;;
  esac
}

retry() {
  local attempt=1
  until "$@"; do
    if (( attempt >= MAX_RETRIES )); then
      log warn "giving up after ${attempt} attempts: $*"
      return 1
    fi
    log info "retry ${attempt}/${MAX_RETRIES} in $(( attempt ** 2 ))s"
    sleep "$(( attempt ** 2 ))"
    (( attempt++ ))
  done
  return 0
}

# ── Argument parsing ──────────────────────────────────────────────────────

while (( $# > 0 )); do
  case "$1" in
    -v|--verbose)  (( VERBOSE++ )); shift ;;
    -n|--dry-run)  DRY_RUN=true; shift ;;
    -t|--target)   TARGET="${2:?--target needs a value}"; shift 2 ;;
    --target=*)    TARGET="${1#*=}"; shift ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; break ;;
    -*)            die "unknown flag: $1" ;;
    *)             break ;;
  esac
done

# ── Parameter expansion showcase ──────────────────────────────────────────

path='/Users/leo/Dev/LeoManrique/Etc/leo-theme/preview/11-script.sh'
log debug "basename    ${path##*/}"
log debug "dirname     ${path%/*}"
log debug "no ext      ${path%.sh}"
log debug "upper       ${TARGET^^}"
log debug "lower       ${TARGET,,}"
log debug "length      ${#path}"
log debug "substring   ${path:0:20}"
log debug "replace     ${path//\//·}"
log debug "default     ${UNSET_VAR:-fallback}"
log debug "alt value   ${TARGET:+target is set}"

# ── Main ──────────────────────────────────────────────────────────────────

main() {
  log info "${SCRIPT_NAME} v${VERSION} · target=${TARGET} · verbose=${VERBOSE}"

  if [[ ! -d "$SCRIPT_DIR" ]]; then
    die "script dir vanished: ${SCRIPT_DIR}"
  elif [[ "$DRY_RUN" == true ]]; then
    log warn 'dry run — nothing will be written'
  fi

  local count=0
  for level in "${LEVELS[@]}"; do
    if is_loud "$level"; then
      printf '  %-6s → loud\n' "$level"
    else
      printf '  %-6s → quiet\n' "$level"
    fi
    (( count += 1 ))
  done

  for key in "${!COLORS[@]}"; do
    printf '  %-8s %s\n' "$key" "${COLORS[$key]}"
  done

  # Command substitution, pipes, redirects, and process substitution.
  local samples
  samples="$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '[0-9][0-9]-*' | sort | wc -l | tr -d ' ')"
  log info "found ${samples} numbered samples"

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '  seen: %s\n' "${line:0:60}"
  done < <(head -n 5 "${SCRIPT_DIR}/00-plain.txt" 2>/dev/null || true)

  cat > "${TMPDIR_LOCAL}/report.txt" <<-EOF
	Double-quoted heredoc: expansions DO happen.
	  target   = ${TARGET}
	  samples  = ${samples}
	  mask     = $(printf '0x%06X' "$HEX_MASK")
	  levels   = ${LEVELS[*]}
	EOF

  retry test -s "${TMPDIR_LOCAL}/report.txt" \
    && log info 'report written' \
    || log warn 'report missing'

  (( count == ${#LEVELS[@]} )) || die "counted ${count}, expected ${#LEVELS[@]}"
}

main "$@"
