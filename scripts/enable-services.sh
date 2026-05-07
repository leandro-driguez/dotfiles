#!/usr/bin/env bash
# enable-services.sh — enable systemd services from system/services-*.txt.
#
# Inputs:   system/services-system.txt, system/services-user.txt
# Side effects: enables (and starts) services system-wide and per-user.
# Sudo:     yes for system services.
# Idempotent: yes (systemctl enable on an already-enabled unit is a no-op).

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

SYS_LIST="$REPO_ROOT/system/services-system.txt"
USR_LIST="$REPO_ROOT/system/services-user.txt"

enable_each() {
    local scope="$1"; shift  # "--system" or "--user"
    local list="$1"
    [[ -r "$list" ]] || { log_warn "Missing $list, skipping."; return; }
    local units
    units=$(grep -vE '^\s*(#|$)' "$list" || true)
    [[ -z "$units" ]] && { log_warn "$list is empty, skipping."; return; }

    while IFS= read -r unit; do
        [[ -z "$unit" ]] && continue
        if [[ "$scope" == "--system" ]]; then
            run sudo systemctl enable --now "$unit"
        else
            run systemctl --user enable --now "$unit"
        fi
    done <<<"$units"
}

log_info "Enabling system services..."
enable_each --system "$SYS_LIST"

log_info "Enabling user services..."
enable_each --user "$USR_LIST"

log_info "Service enabling complete."
