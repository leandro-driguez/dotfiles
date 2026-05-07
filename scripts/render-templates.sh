#!/usr/bin/env bash
# render-templates.sh — expand *.tmpl files using ~/.env.local + envsubst.
#
# Looks for files named <name>.tmpl inside Stow packages and writes the
# expanded result to ./<dest_dir>/<name> (where <dest_dir> is the same dir
# the .tmpl lives in). After this, `stow` will symlink the rendered file
# into $HOME normally; the rendered files are gitignored.
#
# Sources ~/.env.local before running envsubst, so any ${VAR} in the
# templates can be supplied there.
#
# Sudo:     no.
# Idempotent: yes (rewrites the rendered file every time).

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

if ! command -v envsubst >/dev/null 2>&1; then
    die "envsubst not found. Install gettext."
fi

if [[ -f "$HOME/.env.local" ]]; then
    log_info "Sourcing $HOME/.env.local"
    set -a
    # shellcheck source=/dev/null
    source "$HOME/.env.local"
    set +a
else
    log_warn "$HOME/.env.local not found. Templates may render with empty vars."
fi

mapfile -t templates < <(find "$REPO_ROOT" -path "$REPO_ROOT/legacy" -prune -o \
                              -path "$REPO_ROOT/.git" -prune -o \
                              -type f -name '*.tmpl' -print)

if [[ ${#templates[@]} -eq 0 ]]; then
    log_warn "No *.tmpl files found."
    exit 0
fi

for tmpl in "${templates[@]}"; do
    out="${tmpl%.tmpl}"
    log_info "Rendering ${tmpl#"$REPO_ROOT/"} → ${out#"$REPO_ROOT/"}"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_dim "  DRY-RUN: envsubst < '$tmpl' > '$out'"
    else
        envsubst < "$tmpl" > "$out"
    fi
done

log_info "Templates rendered."
