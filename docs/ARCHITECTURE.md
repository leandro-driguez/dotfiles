# Architecture

## Bootstrap flow

```
┌────────────┐
│ preflight  │  Verify: Arch?, sudo?, git?, network?
└─────┬──────┘
      │
┌─────▼──────┐
│ base-pkgs  │  pacman -S base-devel git stow gettext
└─────┬──────┘
      │
┌─────▼──────┐
│ aur-helper │  Install yay if missing
└─────┬──────┘
      │
┌─────▼──────────────┐
│ official-pkgs      │  pacman -S - < packages/pacman.txt
│ + aur-pkgs         │  yay   -S - < packages/aur.txt
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ system-files       │  diff + sudo cp system/etc/* → /etc/
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ render-templates   │  envsubst on *.tmpl using ~/.env.local
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ stow               │  stow -t ~ for every Stow package
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ fonts-refresh      │  fc-cache -f
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ services-system    │  sudo systemctl enable --now …
│ + services-user    │       systemctl --user enable --now …
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ env-setup          │  cp env/.env.example ~/.env.local (if missing)
└─────┬──────────────┘
      │
┌─────▼──────────────┐
│ post               │  Print verification summary + manual steps
└────────────────────┘
```

Every phase has a corresponding `--only=<phase>` flag and a function
`phase_<phase>` in `bootstrap.sh`. Most phases are also implemented as
standalone scripts under `scripts/`.

## File destinations

| Source in repo                               | Destination on disk                       | Mechanism                |
|----------------------------------------------|-------------------------------------------|--------------------------|
| `<pkg>/<path>` (top-level Stow package)      | `$HOME/<path>`                            | `stow`                   |
| `system/etc/<file>`                          | `/etc/<file>`                             | `apply-system.sh` + sudo |
| `<pkg>/<path>.tmpl`                          | `<pkg>/<path>` (then stowed)              | `render-templates.sh`    |
| `packages/pacman.txt`                        | (no file; consumed by pacman)             | `install-packages.sh`    |
| `packages/aur.txt`                           | (no file; consumed by yay)                | `install-packages.sh`    |
| `system/services-system.txt`                 | (consumed by systemctl)                   | `enable-services.sh`     |
| `env/.env.example`                           | `$HOME/.env.local` (only on first run)    | `bootstrap.sh` env-setup |

## Change cycle

```
  edit a config in the repo  ──►  git commit  ──►  git push
                                                       │
  on the other machine:                                ▼
  git pull  ──►  stow -R <pkg>   (re-stow if files were added/removed)
            └──►  no action      (existing symlinks already point at the repo)
```

If a phase changed (new package added to `packages/pacman.txt`,
new service in `system/services-system.txt`, …), run the matching
`bootstrap.sh --only=<phase>` instead of full bootstrap.

## How Stow works in this repo

Each Stow package is rooted at the destination's top level. So
`hyprland/.config/hypr/hyprland.conf` is meant to land at
`~/.config/hypr/hyprland.conf`. From the repo root,
`stow -t ~ hyprland` walks `hyprland/` and for every file there,
creates a symlink in the corresponding location under `~`.

The `-t ~` (target) tells Stow where the destination tree starts.
`bootstrap.sh` always uses `-t "$HOME"`.

Stow refuses to overwrite real files — if there's a non-symlink at the
destination, it errors out so you can resolve manually. `--adopt`
(behind `--force` in `bootstrap.sh`) inverts that: it pulls the
destination contents into the repo. That is destructive to the repo
and only useful when first migrating a machine into Stow management.

## Secrets architecture

```
env/.env.example  (committed, placeholders only)
   │
   │ on first run:
   │   cp env/.env.example  ~/.env.local
   ▼
~/.env.local      (NEVER committed; user fills in real values)
   │
   │ sourced at the bottom of:
   │   shell/.bashrc, shell/.zshrc
   │
   │ also sourced by render-templates.sh
   ▼
Available as $VAR to:
   - interactive shells
   - envsubst (renders git/.gitconfig.tmpl → git/.gitconfig)
```

## Idempotence guarantees

| Operation                             | Why re-run is safe                    |
|---------------------------------------|---------------------------------------|
| `pacman -S --needed`                  | `--needed` skips installed pkgs       |
| `yay -S --needed`                     | same                                  |
| `stow <pkg>`                          | refuses to clobber, no-op when linked |
| `systemctl enable --now <unit>`       | already-enabled is a no-op            |
| `apply-system.sh` (cp to /etc)        | `cmp -s` short-circuits when match    |
| `render-templates.sh`                 | overwrites rendered file every time   |
| `fc-cache -f`                         | always safe                           |
| `cp env/.env.example ~/.env.local`    | guarded by `[[ -f ]]` check           |
