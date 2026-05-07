# Maintenance

Recipes for common edits.

## Add a package

```bash
# Pacman
sudo pacman -S <pkg>

# AUR
yay -S <aur-pkg>

# Sync the lists
make export
git diff packages/
git commit -am "pkgs: add <pkg>"
```

`make export` re-runs `pacman -Qqen` and `pacman -Qqem`, so any explicitly
installed package shows up. Don't edit `packages/*.txt` by hand unless you
deliberately want to install a package on the next bootstrap that isn't
currently installed.

## Remove a package

```bash
sudo pacman -Rns <pkg>          # or: yay -Rns
make export
git commit -am "pkgs: remove <pkg>"
```

## Add a new app config

1. Look up where the app puts its config: usually `~/.config/<app>/`,
   sometimes a dotfile in `$HOME`.
2. Create a Stow package mirroring that path:
   ```bash
   mkdir -p <app>/.config/<app>
   cp -r ~/.config/<app>/. <app>/.config/<app>/
   ```
3. Stow it:
   ```bash
   cd ~/github/dotfiles
   stow -t ~ <app>
   ```
4. Verify the symlink: `readlink ~/.config/<app>/<somefile>` should point
   into the repo.
5. Commit:
   ```bash
   git add <app>/
   git commit -m "<app>: add config"
   ```

## Edit a config

Just edit the file in the repo. Because Stow created symlinks, the live
config and the repo file are the same inode.

```bash
$EDITOR hyprland/.config/hypr/hyprland.conf
hyprctl reload   # or whatever applies the change
git commit -am "hyprland: tweak Z"
```

## Add a new systemd service

```bash
sudo systemctl enable --now <unit>          # or: systemctl --user enable --now
make export                                 # regenerates services-*.txt
git commit -am "services: enable <unit>"
```

## Add a new /etc file

```bash
# 1. Make the change live (sudoedit or your tool of choice)
sudoedit /etc/<file>

# 2. Mirror it into the repo
sudo cp /etc/<file> system/etc/<file>
sudo chown "$USER:$USER" system/etc/<file>

# 3. Commit
git add system/etc/<file>
git commit -m "system: track /etc/<file>"
```

`apply-system.sh` will diff against `/etc/<file>` on subsequent bootstraps
and prompt before writing.

## Add a new secret / env var

1. Add a placeholder to `env/.env.example` (commit this):
   ```
   NEW_TOKEN=
   ```
2. Set the real value in `~/.env.local`:
   ```
   NEW_TOKEN=actual-secret
   ```
3. The next interactive shell will pick it up automatically (loaded by
   `shell/.bashrc` / `shell/.zshrc`).
4. Never commit the real value. Verify with `git diff` before pushing.

## Uninstall (back out the changes Stow made)

```bash
make uninstall
# Equivalent to:
#   for pkg in <stow-packages>; do stow -D -t ~ "$pkg"; done
```

This removes the symlinks; it does NOT uninstall packages, disable
services, or revert `/etc` files.

## Run on a brand-new machine

See `README.md` quickstart and `docs/MANUAL-STEPS.md` for things bootstrap
can't automate.

## Lint before pushing

```bash
make lint                       # shellcheck on all *.sh
./bootstrap.sh --dry-run        # smoke test
```
