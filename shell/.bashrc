#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export ELECTRON_OZONE_PLATFORM_HINT=auto
export ELECTRON_OZONE_PLATFORM=wayland
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# OpenClaw completion (only if installed)
[[ -f "$HOME/.openclaw/completions/openclaw.bash" ]] && \
    source "$HOME/.openclaw/completions/openclaw.bash"

# Local secrets / per-machine env (gitignored, see env/.env.example)
[[ -f "$HOME/.env.local" ]] && set -a && source "$HOME/.env.local" && set +a
