#!/usr/bin/env bash
# install-packages.sh — install pacman + AUR packages from packages/*.txt.
#
# Inputs:   packages/pacman.txt, packages/aur.txt
# Side effects: installs system-wide packages via pacman + yay.
# Sudo:     yes (pacman); yay handles its own sudo prompts.
# Idempotent: --needed skips already-installed packages.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

PACMAN_LIST="$REPO_ROOT/packages/pacman.txt"
AUR_LIST="$REPO_ROOT/packages/aur.txt"

[[ -r "$PACMAN_LIST" ]] || die "Missing $PACMAN_LIST"
[[ -r "$AUR_LIST" ]]    || die "Missing $AUR_LIST"

# Pacman first (official). Filter out blank lines / comments.
PACMAN_PKGS=$(grep -vE '^\s*(#|$)' "$PACMAN_LIST" || true)
if [[ -n "$PACMAN_PKGS" ]]; then
    log_info "Installing $(wc -l <<<"$PACMAN_PKGS") official packages with pacman..."
    # shellcheck disable=SC2086
    run sudo pacman -S --needed --noconfirm $PACMAN_PKGS
else
    log_warn "packages/pacman.txt is empty, skipping."
fi

# Need yay for AUR. Bootstrap installs it earlier; this script may be run alone.
if ! command -v yay >/dev/null 2>&1; then
    die "yay not installed. Run bootstrap.sh --only=aur-helper first."
fi

AUR_PKGS=$(grep -vE '^\s*(#|$)' "$AUR_LIST" || true)
if [[ -n "$AUR_PKGS" ]]; then
    log_info "Installing $(wc -l <<<"$AUR_PKGS") AUR packages with yay..."
    # shellcheck disable=SC2086
    run yay -S --needed --noconfirm $AUR_PKGS
else
    log_warn "packages/aur.txt is empty, skipping."
fi

log_info "Package installation complete."
