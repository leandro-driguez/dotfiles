# Arch Linux Dotfiles Migration — Design

**Date**: 2026-05-07
**Status**: Approved (pending user spec review)
**Author**: brainstorming session with Claude
**Source machine**: Arch Linux rolling, kernel 6.19.9-arch1-1, Wayland + Hyprland session

## 1. Goal

Turn this `dotfiles` repository into a self-contained, idempotent reproduction of the user's Arch Linux setup. A fresh Arch install must reach a working desktop with one clone + one command, with manual steps clearly documented for things that cannot be automated (secrets, browser logins, SSH/GPG key transfer).

## 2. Scope

In scope:

- All actively used `~/.config/` configurations (Hyprland, Waybar, Alacritty, Ghostty, Rofi, Fontconfig, Git, GTK, mimeapps, etc.)
- Shell rcfiles (`.bashrc`, `.bash_profile`, `.zshrc`, `.gitconfig`, `.npmrc`, `.asoundrc`)
- Package lists: official (pacman) + AUR (yay)
- Enabled systemd services (system + user)
- Modified `/etc` files (currently: `pacman.conf`)
- Locally installed fonts (`~/.local/share/fonts/`)
- Bootstrap script that installs everything from a clean Arch base
- Documentation oriented for both humans and AI coding agents (Claude Code et al.)

Out of scope (explicitly excluded):

- Heavy or session-bound `~/.config/` directories: `Code`, `Code - OSS`, `google-chrome` (1.5G), `Notion` (609M), `obsidian`, `gcloud`, `gh`, `ngrok`, `pulse`, `inkscape`, `gogcli`, `go`, `systemd` (user generated symlinks)
- Secrets in plaintext (handled via `~/.env.local`, see §6)
- SSH/GPG keys (transferred manually through a secure channel)
- Application data inside browsers, Notion, Obsidian (sign in again on the new machine)

## 3. Source machine snapshot

Captured during brainstorming and used to seed package/service lists:

- Distro: Arch Linux rolling
- Display server: Wayland, Hyprland session via SDDM
- AUR helper: `yay`
- Pacman explicit packages: 74
- AUR packages: 10
- System services enabled: bluetooth, NetworkManager, sddm, tailscaled (+ defaults)
- User services enabled: openclaw-gateway, pipewire/pipewire-pulse/wireplumber (+ default sockets)
- Custom font: `CommitMono-ExtraLight.woff2` in `~/.local/share/fonts/`
- Modified `/etc`: `/etc/pacman.conf` (touched 2025-03-27)

## 4. Approach

GNU Stow + phased bootstrap script. Considered alternatives: a single `home/` Stow package (rejected: poor granularity); Ansible (rejected: overkill for one target machine).

Each top-level directory in the repo (except for meta directories) is a Stow package whose internal tree mirrors `$HOME` exactly. `stow <pkg>` from the repo root creates the symlinks; `stow -D <pkg>` reverses them.

## 5. Repository structure

```
dotfiles/
├── README.md                    # Quickstart + filosofía
├── CLAUDE.md                    # Repo guide for AI coding agents
├── bootstrap.sh                 # Orchestrator (idempotent, --dry-run, --yes, --only=<phase>)
├── Makefile                     # make install | make stow | make pkgs | make uninstall | make export
├── .gitignore                   # ignores ~/.env.local-style files; also .lock, secrets
│
├── packages/
│   ├── pacman.txt               # `pacman -Qqen`
│   ├── aur.txt                  # `pacman -Qqem`
│   └── flatpak.txt              # placeholder (empty, optional)
│
├── system/
│   ├── etc/
│   │   └── pacman.conf
│   ├── services-system.txt      # one unit per line
│   └── services-user.txt
│
├── fonts/                       # Stow → ~/.local/share/fonts/
│   └── .local/share/fonts/
│       └── CommitMono-ExtraLight.woff2
│
├── shell/                       # Stow → $HOME (rcfiles)
│   ├── .bashrc
│   ├── .bash_profile
│   ├── .zshrc                   # no secrets; sources ~/.env.local
│   └── .npmrc
│   └── .asoundrc
│
├── git/                         # Stow → $HOME and $HOME/.config/git
│   ├── .gitconfig.tmpl          # template with {{GIT_USER_NAME}} etc.
│   └── .config/git/ignore
│
├── hyprland/                    # Stow → ~/.config/hypr/
├── waybar/                      # Stow → ~/.config/waybar/
├── alacritty/                   # Stow → ~/.config/alacritty/
├── ghostty/                     # Stow → ~/.config/ghostty/
├── rofi/                        # Stow → ~/.config/rofi/
├── fontconfig/                  # Stow → ~/.config/fontconfig/
├── desktop/                     # Stow → ~/.config/{gtk-3.0,mimeapps.list,xdg-terminals.list,yay,dconf}/
│
├── env/
│   └── .env.example             # placeholder keys, value empty
│
├── scripts/
│   ├── install-packages.sh      # pacman + yay from packages/*.txt
│   ├── install-fonts.sh         # fc-cache after stow
│   ├── enable-services.sh       # systemctl enable from services-*.txt
│   ├── apply-system.sh          # sudo cp of system/etc/* with diff + confirm
│   ├── render-templates.sh      # envsubst on *.tmpl files
│   ├── export-state.sh          # regenerate packages/*.txt + services-*.txt
│   └── lint.sh                  # shellcheck on all scripts
│
├── docs/
│   ├── ARCHITECTURE.md          # bootstrap flow, file destinations, change cycle
│   ├── MAINTENANCE.md           # how to add packages, configs, regenerate state
│   ├── MANUAL-STEPS.md          # checklist for things bootstrap can't do
│   └── superpowers/specs/2026-05-07-arch-dotfiles-migration-design.md
│
└── legacy/                      # Archived old setup (not active)
    ├── nixos/
    ├── home-manager/
    ├── xmonad/
    ├── polybar/
    └── nvim/
```

### Stow package convention

A "Stow package" is any top-level directory whose contents mirror the destination tree starting from `$HOME`. So `hyprland/.config/hypr/hyprland.conf` becomes `~/.config/hypr/hyprland.conf` after `stow hyprland`. Meta directories (`packages/`, `system/`, `scripts/`, `docs/`, `env/`, `legacy/`) are **not** Stow packages and are skipped by `make stow`.

## 6. Secrets handling

No secret values live in the repo. Detected secret on the source machine: `SUPABASE_ACCESS_TOKEN` in `~/.zshrc` and `~/.bash_profile`.

Mechanism:

- `shell/.bashrc` and `shell/.zshrc` end with:
  ```bash
  [[ -f "$HOME/.env.local" ]] && set -a && source "$HOME/.env.local" && set +a
  ```
- `env/.env.example` (committed) lists the keys with empty values.
- `~/.env.local` (gitignored, **never** in repo) holds real values. User copies the example and fills it in on the new machine.
- `git/.gitconfig.tmpl` is a committed template; `scripts/render-templates.sh` runs `envsubst` against it (consuming env vars or `~/.env.local`) and writes the rendered `~/.gitconfig`. The rendered file is gitignored.

## 7. Bootstrap flow

`bootstrap.sh` runs these phases in order. Each phase is idempotent and can be invoked alone via `--only=<phase>`.

| # | Phase             | Action                                                                   | Needs sudo |
|---|-------------------|--------------------------------------------------------------------------|------------|
| 1 | preflight         | Verify: Arch Linux, network reachable, sudo available, git installed     | no         |
| 2 | base-pkgs         | `pacman -S --needed base-devel git stow`                                 | yes        |
| 3 | aur-helper        | Install `yay` if missing (clone from AUR, `makepkg -si`)                 | yes        |
| 4 | official-pkgs     | `pacman -S --needed - < packages/pacman.txt`                             | yes        |
| 5 | aur-pkgs          | `yay -S --needed - < packages/aur.txt`                                   | yes (yay)  |
| 6 | system-files      | For each file in `system/etc/`: `diff` against destination, then sudo cp | yes        |
| 7 | render-templates  | Render `*.tmpl` to gitignored siblings using `~/.env.local`              | no         |
| 8 | stow              | `stow -t $HOME` for every Stow package                                   | no         |
| 9 | fonts-refresh     | `fc-cache -fv`                                                           | no         |
| 10| services-system   | `sudo systemctl enable --now $(< system/services-system.txt)`            | yes        |
| 11| services-user     | `systemctl --user enable --now $(< system/services-user.txt)`            | no         |
| 12| env-setup         | If `~/.env.local` missing: `cp env/.env.example ~/.env.local` and warn   | no         |
| 13| post              | Print verification summary and the contents of `docs/MANUAL-STEPS.md`   | no         |

Flags:

- `--dry-run`: log every command without executing.
- `--yes`: assume yes for all confirmations.
- `--skip-pkgs` / `--skip-system` / `--skip-services`: turn off whole phase groups.
- `--only=<phase>`: run a single phase.
- `--force`: pass `--adopt` to stow (resolves conflicts by adopting destination contents into the repo — destructive, never default).

## 8. Error handling and verification

Every script begins with `set -euo pipefail` and a shared logger. `bootstrap.sh` traps `ERR` and prints the failing line. After all phases complete it prints a verification summary:

- Stow links: `readlink` checks for a fixed set of canonical paths (e.g. `~/.config/hypr/hyprland.conf`).
- Packages: diff between `pacman -Qq` and the union of `packages/pacman.txt` + `packages/aur.txt`.
- Services: `systemctl is-enabled` for each entry of the lists.
- Manual checklist: rendered from `docs/MANUAL-STEPS.md`.

`scripts/lint.sh` runs `shellcheck` over all shell scripts. `bootstrap.sh --dry-run` is the smoke test; full smoke test on a clean Arch VM is documented in `docs/MAINTENANCE.md` but not automated.

## 9. Documentation strategy (AI-agent-friendly)

The repo is documented so a future Claude Code session can orient itself in one or two file reads.

- **`README.md`** — Human quickstart. 3-step new-machine flow (clone, run `./bootstrap.sh`, reboot), tables of Stow packages and scripts with one-line descriptions, "How to add a new config" section.
- **`CLAUDE.md`** at repo root — Agent-oriented guide. Repository invariants (every top-level dir with a `.config/` or rcfile is a Stow package; nothing in `legacy/` is active; no secrets in tracked files). Common commands. Where to look for what. What NOT to do.
- **`docs/ARCHITECTURE.md`** — ASCII diagram of bootstrap phases; table of file destinations (`$HOME` vs `/etc` vs `~/.local`); change lifecycle (edit → commit → on other machine `git pull` + `stow -R`).
- **`docs/MAINTENANCE.md`** — Recipes: add a package, add a new config (copy from `~/.config/X` → create Stow package → `stow X`), regenerate lists with `scripts/export-state.sh`, uninstall (`make uninstall` → `stow -D` for everything).
- **`docs/MANUAL-STEPS.md`** — Post-bootstrap checklist that cannot be automated: import SSH and GPG keys via secure channel, `gh auth login`, sign in to Chrome / Notion / Obsidian, `gcloud auth login`, `tailscale up`, populate `~/.env.local`.
- Every script starts with a header comment: purpose (one line), inputs, side effects, sudo requirements.

## 10. Migration of existing repo content

- Move `nixos/`, `home-manager/`, `xmonad/`, `polybar/`, `nvim/` under `legacy/` (preserves history, removes from active surface).
- Keep `hypr/` content as the new `hyprland/.config/hypr/` package's seed (the existing files are the basis).
- Keep `waybar/` and `rofi/` as bases for the new packages.
- Repo `README.md` is currently a single-line stub; replace per §9.

## 11. Open questions

None at design time. Decisions taken during brainstorming:

- Stow over a one-shot copy script (granularity, reversibility).
- Phased bootstrap over Ansible (one target machine; minimize dependencies).
- Plaintext `~/.env.local` over git-crypt/sops (no key-transport burden; user copies via secure channel).
- Heavy `~/.config/` directories excluded (caches, session tokens, browser binary state).

## 12. Out of scope (now), candidates for later

- Per-host overlays (different machines, different configs): would split packages into `common/` + `hosts/<hostname>/`. Current target is a single second machine, so deferred.
- Encrypted secrets in repo (`git-crypt`): can be added later as an extra mechanism without breaking the current `~/.env.local` flow.
- CI smoke test in a Docker Arch image: nice-to-have, deferred.
