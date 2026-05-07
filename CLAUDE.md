# CLAUDE.md — agent orientation

This file is read by AI coding agents (Claude Code, Copilot CLI, Codex, etc.)
opening the repo. Skim it before doing anything.

## What this repo is

A reproducible Arch Linux + Hyprland setup. One clone + `./bootstrap.sh` on a
fresh Arch install produces the user's working desktop. The pieces:

- **Stow packages** at the top level mirror `$HOME`. Stowing them creates
  symlinks from `$HOME` into the repo, so editing the file in the repo
  immediately changes the live config.
- **`bootstrap.sh`** at the root is the orchestrator. It runs phases in
  order; each phase is also an individual script under `scripts/`.
- **`legacy/`** holds archived configs (NixOS, XMonad, etc.) that are NOT
  active. Don't edit them; their git history is the only reason they exist.

## Repository invariants (don't break these)

1. **Top-level dirs are Stow packages**, except for the meta dirs:
   `bootstrap.sh`, `Makefile`, `packages/`, `system/`, `scripts/`, `env/`,
   `docs/`, `legacy/`. If you create a new top-level dir, it MUST be a Stow
   package whose tree mirrors `$HOME` (e.g. `myapp/.config/myapp/...`).
2. **No secrets in tracked files.** Secrets live in `~/.env.local` (gitignored)
   and are sourced by `shell/.bashrc` / `shell/.zshrc`. The template is
   `env/.env.example`. If you find a secret in a tracked file, treat it as a bug.
3. **Templates use `${VAR}` (envsubst)**, not `{{VAR}}` (Mustache). They live
   beside their rendered destination as `<file>.tmpl` and are expanded by
   `scripts/render-templates.sh`. Rendered files are gitignored.
4. **Every script sources `scripts/lib/common.sh`** and uses `set -euo pipefail`
   plus `log_info`/`log_warn`/`die` for output. Don't print directly with
   `echo` from scripts.
5. **Idempotence** — every script and every phase must be safe to re-run.
   Use `--needed` for pacman, `--needed` for yay, `cmp -s` before overwriting
   `/etc`, etc.

## Where to look for what

| Question                                  | File                                           |
|-------------------------------------------|------------------------------------------------|
| What does bootstrap actually do?          | `bootstrap.sh` header comment + `docs/ARCHITECTURE.md` |
| What packages does the user have?         | `packages/pacman.txt`, `packages/aur.txt`      |
| What systemd services are enabled?        | `system/services-{system,user}.txt`            |
| What `/etc` files differ from defaults?   | `system/etc/`                                  |
| How do I add a new app config?            | `README.md` ("How to add a new config") + `docs/MAINTENANCE.md` |
| How do I regenerate the package lists?    | `scripts/export-state.sh` (or `make export`)   |
| Why is this repo organized this way?      | `docs/superpowers/specs/2026-05-07-arch-dotfiles-migration-design.md` |
| What can't be automated?                  | `docs/MANUAL-STEPS.md`                         |

## Common commands

```bash
./bootstrap.sh --dry-run             # see what bootstrap would do
./bootstrap.sh --only=stow           # run one phase
make stow                            # symlink-only (skip packages, services)
make export                          # refresh packages/*.txt + services-*.txt
make lint                            # shellcheck
stow -t ~ <package>                  # link a single package by hand
stow -D -t ~ <package>               # unlink a single package
```

## What NOT to do

- Don't commit `~/.env.local`, `git/.gitconfig` (rendered, not the `.tmpl`),
  or anything under `~/.config/{Code,google-chrome,Notion,obsidian,gcloud}`.
- Don't add backwards-compatibility shims for the old NixOS/XMonad setup.
  That work lives in `legacy/` and stays frozen.
- Don't bake in absolute paths like `/home/leandro_driguez/...`. Use `$HOME`.
- Don't run `stow --adopt` casually — it overwrites the repo with whatever
  is on disk in `$HOME`. It's only available behind `bootstrap.sh --force`.
- Don't bypass `apply-system.sh`'s diff + confirm flow when touching `/etc`.

## Verifying changes

```bash
make lint                            # before committing
./bootstrap.sh --dry-run             # smoke test the full flow
stow -nv -t ~ <package>              # preview link changes for one package
```

The author's preferred commit style: imperative, short subject (under
70 chars), present tense ("add", "fix", "update"), with the
`Co-Authored-By: Claude` trailer when an AI agent helped.
