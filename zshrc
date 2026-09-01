# ── Static zshrc ──────────────────────────────────────────────
# This file is maintained in relation to the setup script clean-install-zsh.sh
# which installs dependencies, this file wires them into the shell.
#
# !!! ORDERING INVARIANT — pre-instant-prompt zone !!!
# Anything that PRINTS to the terminal during zsh init must stay in the
# zone above the "END of pre-instant-prompt zone" marker: output after
# the instant prompt has been sourced triggers p10k's "console output
# during zsh initialization" warning. The fastfetch banner and the mise
# startup hooks (mise.zsh) live in that zone today; new init-time output
# goes above the marker, never below (and never in dot-files/.zshrc,
# which loads after the prompt). Config-only lines (exports, hooks,
# sourcing non-printing files) may go anywhere.

typeset -U path fpath

# Never nano:
export EDITOR=vim

# Prefer Chrome for opening links (xdg-open and CLI tools honor $BROWSER):
(( $+commands[google-chrome] )) && export BROWSER=google-chrome

# ── fastfetch banner (must precede the instant prompt) ──────────
# Prints the system banner before p10k captures the terminal for its
# instant-prompt snapshot; any output after that point triggers the
# "console output during zsh initialization" warning (p10k FAQ).
(( $+commands[fastfetch] )) && fastfetch --config ~/.fastfetch.jsonc


# ── Environment & Toolchains (pre-instant-prompt zone) ─────────
# mise.zsh's startup hooks can print ("run 'mise trust'", missing-tool
# installs), so the whole file must stay above the instant-prompt
# preamble below.
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


# ── END of pre-instant-prompt zone ──────────────────────────────
# Nothing below this marker may print during init. New init-time
# output goes ABOVE it (see the invariant note at the top of the file).
# ── Powerlevel10k instant prompt ────────────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Oh My Zsh ───────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
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

# ── Powerlevel10k prompt config ─────────────────────────────────
# Customise with:  p10k configure
[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh


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