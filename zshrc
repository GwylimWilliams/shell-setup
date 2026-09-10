# ── Static zshrc ──────────────────────────────────────────────
# This file is maintained in relation to the setup script clean-install-zsh.sh
# which installs dependencies, this file wires them into the shell.
#
# The fastfetch banner sits near the top so it prints before mise's startup
# notices and the first prompt — readability, not correctness.

typeset -U path fpath

# Never nano:
export EDITOR=vim

# Prefer Chrome for opening links (xdg-open and CLI tools honor $BROWSER):
(( $+commands[google-chrome] )) && export BROWSER=google-chrome

# ── fastfetch banner ────────────────────────────────────────────
(( $+commands[fastfetch] )) && fastfetch --config ~/.fastfetch.jsonc


# ── Environment & Toolchains ────────────────────────────────────
# mise.zsh's startup hooks can print ("run 'mise trust'", missing-tool
# installs).
# zsh-completions fpath (must be before compinit, which OMZ runs):
fpath=("$HOME/.zsh-plugins/zsh-completions/src" $fpath)
# Repo-managed completion functions (e.g. _g for the g gradle wrapper):
fpath=("${${(%):-%x}:A:h}/dot-files/completions" $fpath)

# MISE (PATH-based activation, JAVA_HOME, auto-install):
__mise_setup=${${(%):-%x}:A:h}/mise.zsh
if [[ -r $__mise_setup ]]; then
  source $__mise_setup
fi
unset __mise_setup


# ── Oh My Zsh ───────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # prompt is drawn by starship (see the end of this file)
plugins=( git sudo z docker gradle command-not-found colored-man-pages )
source "$ZSH/oh-my-zsh.sh"

# ── git-based zsh extras (fish-feel typing) ─────────────────────
# zsh-autosuggestions: grey inline suggestions as you type
[[ -r ~/.zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source ~/.zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-history-substring-search: fish-style up/down arrow history search
if [[ -r ~/.zsh-plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source ~/.zsh-plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi

# zsh-syntax-highlighting: colour as you type (must be last)
[[ -r ~/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source ~/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Ctrl+Backspace sends ^H in terminals (plain Backspace sends DEL) — kill word
bindkey '^H' backward-kill-word


# ── Custom setup ────────────────────────────────────────────────
# g script and completions that wrap gradle
# Remove unhelpful alias (OMZ git plugin: g='git'):
unalias g

# `g` (bin/g) is a gradlew wrapper that traverses up for build.gradle —
# complete task names from the project's own gradlew (no system gradle),
# plus CLI flags via OMZ's _gradle. `_g` shows tasks on the FIRST tab
# (OMZ's _gradle only describes on the second) and falls back to the
# built-in task list when generation fails.
autoload -U _g
compdef _g g gradlew gw


# ── starship prompt ─────────────────────────────────────────────
# Must stay at the end (starship docs): init wraps zle widgets and registers
# precmd/preexec hooks. `if`, not `&&`, keeps $?=0 when starship is absent —
# a non-zero last status would keep the default character red.
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
