#!/usr/bin/env bash
# bootstrap.sh — One-shot installer for this dotfiles repo on a fresh Arch box.
#
# Run from the repo root:
#   ./bootstrap.sh                   # full install
#   ./bootstrap.sh --dry-run         # log what would happen, do nothing
#   ./bootstrap.sh --yes             # no confirmation prompts
#   ./bootstrap.sh --only=stow       # run a single phase
#   ./bootstrap.sh --skip-pkgs       # skip official-pkgs + aur-pkgs phases
#   ./bootstrap.sh --skip-system     # skip system-files phase
#   ./bootstrap.sh --skip-services   # skip services-system + services-user
#   ./bootstrap.sh --force           # use stow --adopt on conflicts (destructive)
#
# Phases (in order):
#   preflight          → verify Arch, network, sudo, git
#   base-pkgs          → install base-devel git stow gettext
#   aur-helper         → install yay if missing
#   official-pkgs      → install all of packages/pacman.txt
#   aur-pkgs           → install all of packages/aur.txt
#   system-files       → diff + sudo cp of system/etc/* to /etc/
#   render-templates   → expand *.tmpl files (uses ~/.env.local)
#   stow               → symlink every Stow package into $HOME
#   fonts-refresh      → fc-cache -f
#   services-system    → enable + start services from system/services-system.txt
#   services-user      → enable + start services from system/services-user.txt
#   env-setup          → seed ~/.env.local from env/.env.example if missing
#   post               → print verification summary + manual steps
#
# Stow packages are every top-level directory in the repo EXCEPT meta dirs
# (docs/, env/, packages/, scripts/, system/, legacy/).
#
# Idempotent: every phase can be re-run safely.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/scripts/lib/common.sh"

# ---- Argument parsing -------------------------------------------------------

ONLY=""
SKIP_PKGS=0
SKIP_SYSTEM=0
SKIP_SERVICES=0
FORCE=0

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)        DRY_RUN=1 ;;
        --yes|-y)         ASSUME_YES=1 ;;
        --skip-pkgs)      SKIP_PKGS=1 ;;
        --skip-system)    SKIP_SYSTEM=1 ;;
        --skip-services)  SKIP_SERVICES=1 ;;
        --force)          FORCE=1 ;;
        --only=*)         ONLY="${arg#--only=}" ;;
        -h|--help)        usage ;;
        *) die "Unknown argument: $arg" ;;
    esac
done

export DRY_RUN ASSUME_YES

# ---- Phase definitions ------------------------------------------------------

# Stow packages = top-level dirs minus meta dirs.
STOW_META=(docs env packages scripts system legacy)
list_stow_packages() {
    local d
    for d in "$REPO_ROOT"/*/; do
        d="${d%/}"; d="${d##*/}"
        local skip=0
        for m in "${STOW_META[@]}"; do
            [[ "$d" == "$m" ]] && skip=1 && break
        done
        [[ $skip -eq 0 ]] && echo "$d"
    done
}

phase_preflight() {
    log_info "Phase: preflight"
    [[ -f /etc/arch-release ]] || die "Not running on Arch Linux."
    command -v sudo >/dev/null 2>&1 || die "sudo not found."
    command -v git  >/dev/null 2>&1 || log_warn "git not installed; will be added in base-pkgs."
    if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        log_warn "No network reachable to archlinux.org. pacman/yay phases may fail."
    fi
}

phase_base_pkgs() {
    log_info "Phase: base-pkgs"
    run sudo pacman -Sy --needed --noconfirm base-devel git stow gettext
}

phase_aur_helper() {
    log_info "Phase: aur-helper"
    if command -v yay >/dev/null 2>&1; then
        log_dim "  yay already installed"
        return
    fi
    local tmp; tmp=$(mktemp -d)
    log_info "Installing yay from AUR via $tmp ..."
    run git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    run bash -c "cd '$tmp/yay' && makepkg -si --noconfirm"
    run rm -rf "$tmp"
}

phase_official_pkgs() {
    log_info "Phase: official-pkgs"
    [[ "$SKIP_PKGS" == "1" ]] && { log_dim "  --skip-pkgs"; return; }
    run "$REPO_ROOT/scripts/install-packages.sh"
}

phase_aur_pkgs() {
    # install-packages.sh handles both. Calling it once is enough; we reuse it.
    log_dim "  (handled in official-pkgs)"
}

phase_system_files() {
    log_info "Phase: system-files"
    [[ "$SKIP_SYSTEM" == "1" ]] && { log_dim "  --skip-system"; return; }
    run "$REPO_ROOT/scripts/apply-system.sh"
}

phase_render_templates() {
    log_info "Phase: render-templates"
    run "$REPO_ROOT/scripts/render-templates.sh"
}

phase_stow() {
    log_info "Phase: stow"
    if ! command -v stow >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == "1" ]]; then
            log_warn "stow not installed yet (would be installed by base-pkgs phase); skipping."
            return
        fi
        die "stow not installed (should be from base-pkgs)."
    fi

    local stow_args=(-v -t "$HOME" -d "$REPO_ROOT")
    [[ "$FORCE" == "1" ]] && stow_args+=(--adopt)

    local pkgs
    mapfile -t pkgs < <(list_stow_packages)
    log_info "Stowing packages: ${pkgs[*]}"
    for p in "${pkgs[@]}"; do
        run stow "${stow_args[@]}" "$p"
    done
}

phase_fonts_refresh() {
    log_info "Phase: fonts-refresh"
    run "$REPO_ROOT/scripts/install-fonts.sh"
}

phase_services_system() {
    log_info "Phase: services-system"
    [[ "$SKIP_SERVICES" == "1" ]] && { log_dim "  --skip-services"; return; }
    # enable-services.sh handles both system + user; we split for naming.
    local list="$REPO_ROOT/system/services-system.txt"
    [[ -r "$list" ]] || { log_warn "Missing $list"; return; }
    while IFS= read -r unit; do
        [[ -z "$unit" || "$unit" =~ ^# ]] && continue
        run sudo systemctl enable --now "$unit"
    done < "$list"
}

phase_services_user() {
    log_info "Phase: services-user"
    [[ "$SKIP_SERVICES" == "1" ]] && { log_dim "  --skip-services"; return; }
    local list="$REPO_ROOT/system/services-user.txt"
    [[ -r "$list" ]] || { log_warn "Missing $list"; return; }
    while IFS= read -r unit; do
        [[ -z "$unit" || "$unit" =~ ^# ]] && continue
        run systemctl --user enable --now "$unit"
    done < "$list"
}

phase_env_setup() {
    log_info "Phase: env-setup"
    if [[ -f "$HOME/.env.local" ]]; then
        log_dim "  ~/.env.local already exists"
        return
    fi
    run cp "$REPO_ROOT/env/.env.example" "$HOME/.env.local"
    run chmod 600 "$HOME/.env.local"
    if [[ "$DRY_RUN" != "1" ]]; then
        log_warn "Created $HOME/.env.local from template — fill in real values now."
    fi
}

phase_post() {
    log_info "Phase: post"
    log_info "Verification summary:"

    # Stow link checks
    local check_paths=(
        "$HOME/.config/hypr/hyprland.conf"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/alacritty/alacritty.toml"
        "$HOME/.bashrc"
    )
    for p in "${check_paths[@]}"; do
        if [[ -L "$p" ]]; then
            log_dim "  ✓ symlink: $p"
        else
            log_warn "  ✗ not a symlink: $p"
        fi
    done

    # Manual checklist
    if [[ -f "$REPO_ROOT/docs/MANUAL-STEPS.md" ]]; then
        log_info "Manual steps remaining (see docs/MANUAL-STEPS.md):"
        sed -n 's/^- \[ \] /  • /p' "$REPO_ROOT/docs/MANUAL-STEPS.md"
    fi
}

# ---- Phase dispatcher -------------------------------------------------------

# All phases in order. Names match --only= values.
ALL_PHASES=(
    preflight
    base-pkgs
    aur-helper
    official-pkgs
    aur-pkgs
    system-files
    render-templates
    stow
    fonts-refresh
    services-system
    services-user
    env-setup
    post
)

run_phase() {
    case "$1" in
        preflight)         phase_preflight ;;
        base-pkgs)         phase_base_pkgs ;;
        aur-helper)        phase_aur_helper ;;
        official-pkgs)     phase_official_pkgs ;;
        aur-pkgs)          phase_aur_pkgs ;;
        system-files)      phase_system_files ;;
        render-templates)  phase_render_templates ;;
        stow)              phase_stow ;;
        fonts-refresh)     phase_fonts_refresh ;;
        services-system)   phase_services_system ;;
        services-user)     phase_services_user ;;
        env-setup)         phase_env_setup ;;
        post)              phase_post ;;
        *) die "Unknown phase: $1" ;;
    esac
}

if [[ -n "$ONLY" ]]; then
    run_phase "$ONLY"
else
    for p in "${ALL_PHASES[@]}"; do
        run_phase "$p"
    done
fi

log_info "Bootstrap finished."
