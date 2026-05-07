# Manual post-bootstrap steps

`bootstrap.sh` covers packages, configs, services, and `/etc`. The list below
covers everything it cannot do — sign-ins, key transfers, and machine-specific
state. Work through it once on a new machine.

## Secrets

- [ ] Edit `~/.env.local` and fill in real values for every key
      (`SUPABASE_ACCESS_TOKEN`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, …).
- [ ] Run `./bootstrap.sh --only=render-templates` to regenerate
      `~/.gitconfig` from the template.

## Identity / keys (transfer over a secure channel — never via this repo)

- [ ] Copy SSH keys: `~/.ssh/{id_*,config,known_hosts}` from old machine
      (`scp` or USB stick), then `chmod 600 ~/.ssh/id_*`.
- [ ] Import GPG keys:
      ```bash
      # On old machine:
      gpg --export-secret-keys --armor > /tmp/gpg-secret.asc
      # On new machine:
      gpg --import /tmp/gpg-secret.asc
      shred -u /tmp/gpg-secret.asc
      ```

## CLI logins

- [ ] `gh auth login` (this also fixes `~/.gitconfig` credential helpers).
- [ ] `gcloud auth login` (and `gcloud auth application-default login` if
      using ADC).
- [ ] `tailscale up` (start Tailscale; `tailscaled.service` is already enabled).
- [ ] `supabase login` if you use the Supabase CLI.

## GUI app sign-ins

- [ ] Google Chrome: sign in to Google account, sync.
- [ ] VS Code: sign in to GitHub for Settings Sync (`code` then Cmd-Shift-P
      → "Settings Sync: Turn On").
- [ ] Notion: sign in.
- [ ] Obsidian: open vault, sign in to Sync if used.

## Bluetooth / audio sanity check

- [ ] `bluetoothctl power on && bluetoothctl pair <device>` if you use BT
      peripherals.
- [ ] PipeWire is enabled by default; `pavucontrol` (or `wpctl status`) to
      pick the right output.

## Final reboot

- [ ] Reboot once to make sure Hyprland session via SDDM comes up clean.
