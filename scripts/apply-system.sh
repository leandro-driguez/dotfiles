#!/usr/bin/env bash
# apply-system.sh — copy modified /etc files from system/etc/ into /etc/.
#
# Inputs:   system/etc/<file> for every file to manage.
# Side effects: writes to /etc with sudo. Shows diff and asks confirmation
#               unless ASSUME_YES=1.
# Sudo:     yes.
# Idempotent: yes (no-op when files already match).

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

SRC_DIR="$REPO_ROOT/system/etc"
[[ -d "$SRC_DIR" ]] || die "Missing $SRC_DIR"

mapfile -t files < <(find "$SRC_DIR" -type f | sort)
if [[ ${#files[@]} -eq 0 ]]; then
    log_warn "No files in $SRC_DIR, nothing to apply."
    exit 0
fi

for src in "${files[@]}"; do
    rel="${src#"$SRC_DIR/"}"
    dst="/etc/$rel"

    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_dim "  /etc/$rel already in sync"
        continue
    fi

    log_info "Diff for /etc/$rel:"
    if [[ -f "$dst" ]]; then
        diff -u "$dst" "$src" | sed 's/^/    /' || true
    else
        log_dim "  (destination does not exist; will be created)"
    fi

    if confirm "Write $src → $dst?"; then
        run sudo install -D -m 0644 -o root -g root "$src" "$dst"
    else
        log_warn "Skipped /etc/$rel"
    fi
done

log_info "System files applied."
