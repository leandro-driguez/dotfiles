#!/usr/bin/env bash
# install-fonts.sh — refresh the font cache.
#
# Side effects: regenerates the user font cache.
# Sudo:     no.
# Idempotent: yes (fc-cache is safe to re-run).

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

if ! command -v fc-cache >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "1" ]]; then
        log_warn "fc-cache not found (would be installed via fontconfig); skipping."
        exit 0
    fi
    die "fc-cache not found. Install fontconfig first."
fi

log_info "Refreshing font cache..."
run fc-cache -f
log_info "Font cache refreshed."
