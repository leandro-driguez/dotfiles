# Shared helpers for bootstrap scripts. Source this file from any script:
#   # shellcheck source=scripts/lib/common.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#
# Provides: log_info, log_warn, log_error, die, confirm, run, REPO_ROOT, DRY_RUN, ASSUME_YES.

set -euo pipefail

# Repo root: parent of scripts/ (this file lives in scripts/lib/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Defaults; bootstrap.sh re-exports overrides.
: "${DRY_RUN:=0}"
: "${ASSUME_YES:=0}"

# Colors only when stderr is a terminal.
if [[ -t 2 ]]; then
    _C_RESET='\033[0m'
    _C_INFO='\033[1;34m'
    _C_WARN='\033[1;33m'
    _C_ERROR='\033[1;31m'
    _C_DIM='\033[2m'
else
    _C_RESET='' _C_INFO='' _C_WARN='' _C_ERROR='' _C_DIM=''
fi

log_info()  { printf "%b[INFO]%b %s\n"  "$_C_INFO"  "$_C_RESET" "$*" >&2; }
log_warn()  { printf "%b[WARN]%b %s\n"  "$_C_WARN"  "$_C_RESET" "$*" >&2; }
log_error() { printf "%b[ERROR]%b %s\n" "$_C_ERROR" "$_C_RESET" "$*" >&2; }
log_dim()   { printf "%b%s%b\n"         "$_C_DIM"   "$*"        "$_C_RESET" >&2; }

die() { log_error "$*"; exit 1; }

# confirm "Question?" — returns 0 on yes, 1 on no. Auto-yes if ASSUME_YES=1.
confirm() {
    local prompt="$1"
    if [[ "$ASSUME_YES" == "1" ]]; then
        log_dim "  (auto-yes) $prompt"
        return 0
    fi
    local reply
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# run <cmd...> — log the command and execute, or just log when DRY_RUN=1.
run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        log_dim "  DRY-RUN: $*"
    else
        log_dim "  $*"
        "$@"
    fi
}

# Trap handler: report the failing line.
_on_err() {
    local exit_code=$?
    local lineno=${BASH_LINENO[0]:-?}
    log_error "Script failed at ${BASH_SOURCE[1]:-?}:${lineno} (exit $exit_code)"
    exit "$exit_code"
}
trap _on_err ERR
