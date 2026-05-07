#!/usr/bin/env bash
# export-state.sh — regenerate package and service lists from this machine.
#
# Outputs (overwritten):
#   packages/pacman.txt   ← pacman -Qqen
#   packages/aur.txt      ← pacman -Qqem
#   system/services-system.txt
#   system/services-user.txt
#
# Run this on the source machine before committing, to keep the repo
# in sync with the actual installed state.
#
# Sudo:     no.
# Idempotent: yes (overwrites the lists).

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

log_info "Exporting pacman explicit native packages..."
run bash -c "pacman -Qqen > '$REPO_ROOT/packages/pacman.txt'"

log_info "Exporting AUR / foreign packages..."
run bash -c "pacman -Qqem > '$REPO_ROOT/packages/aur.txt'"

log_info "Exporting system services..."
run bash -c "systemctl list-unit-files --state=enabled --no-pager 2>/dev/null \
    | awk 'NR>1 && \$2==\"enabled\"{print \$1}' \
    | grep -v '^getty@' \
    > '$REPO_ROOT/system/services-system.txt'"

log_info "Exporting user services..."
run bash -c "systemctl --user list-unit-files --state=enabled --no-pager 2>/dev/null \
    | awk 'NR>1 && \$2==\"enabled\"{print \$1}' \
    > '$REPO_ROOT/system/services-user.txt'"

if [[ "$DRY_RUN" != "1" ]]; then
    log_info "Done. Counts:"
    log_dim "  pacman: $(wc -l < "$REPO_ROOT/packages/pacman.txt")"
    log_dim "  aur:    $(wc -l < "$REPO_ROOT/packages/aur.txt")"
    log_dim "  sys svc:$(wc -l < "$REPO_ROOT/system/services-system.txt")"
    log_dim "  usr svc:$(wc -l < "$REPO_ROOT/system/services-user.txt")"
fi
