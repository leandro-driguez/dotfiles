#
# ~/.zshrc
#

# Local secrets / per-machine env (gitignored, see env/.env.example)
[[ -f "$HOME/.env.local" ]] && set -a && source "$HOME/.env.local" && set +a
