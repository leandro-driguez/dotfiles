#!/usr/bin/env bash
# lint.sh — run shellcheck over every shell script in this repo.
#
# Sudo:     no.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

if ! command -v shellcheck >/dev/null 2>&1; then
    die "shellcheck not installed. Run: sudo pacman -S shellcheck"
fi

mapfile -t scripts < <(find "$REPO_ROOT" \
    -path "$REPO_ROOT/legacy" -prune -o \
    -path "$REPO_ROOT/.git" -prune -o \
    \( -name '*.sh' -o -name 'bootstrap.sh' \) -type f -print)

log_info "Linting ${#scripts[@]} scripts..."
fail=0
for s in "${scripts[@]}"; do
    if shellcheck -x "$s"; then
        log_dim "  OK ${s#"$REPO_ROOT/"}"
    else
        fail=1
    fi
done

if [[ $fail -eq 0 ]]; then
    log_info "All scripts pass shellcheck."
else
    die "Lint errors above."
fi
