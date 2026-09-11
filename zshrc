# ── Static zshrc ──────────────────────────────────────────────
# This file is maintained in relation to the setup script clean-install-zsh.sh
# which installs dependencies, this file wires them into the shell.
#
# The fastfetch banner sits near the top so it prints before mise's startup
# notices and the first prompt — readability, not correctness.

# zsh sizes the prompt — icon widths, the right prompt's position, the input
# cursor — by counting characters in the locale's charset: without a UTF-8
# locale each byte of a nerd-font icon counts as a column and things drift
# ~2 columns per icon. IDE-integrated terminals often start the shell
# without the login environment that carries LANG, so force one if missing.
if [[ ${(L)$(locale charmap 2>/dev/null)} != utf-8 ]]; then
  for __loc in C.UTF-8 en_US.UTF-8 en_GB.UTF-8 UTF-8; do
    export LANG=$__loc LC_ALL=$__loc
    if [[ ${(L)$(locale charmap)} == utf-8 ]]; then
      break
    fi
  done
  unset __loc
fi

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

# starship can't lay this out itself (right_format pins the right prompt to
# the first line; zsh drops RPROMPT when the left leaves no room), so render
# its pieces separately - left modules, chevron (starship's character module,
# absent from starship.toml's format), right modules - and compose:
#   - fits and the left covers at most half the line: one line, right prompt
#     through zsh's RPROMPT (so the input cursor follows the chevron);
#   - left covers over half the line: chevron and input move to a line below
#     (the right prompt stays on the left line if it still fits there);
#   - right prompt doesn't fit beside the left prompt: line of its own above.
# PROMPT and RPROMPT each run a $(...) call that renders the pieces and lays
# out its own side - they are separate subshells and zsh doesn't fix their
# evaluation order, so they can't share state. Being calls, not rendered
# strings, vi-mode changes (starship's zle reset-prompt) and terminal resizes
# re-render.
starship_prompt_width() {
  emulate -L zsh
  setopt local_options extendedglob
  # Strip SGR sequences and zsh's zero-width %{%} markers before counting.
  local s=${1//$'\e'\[[0-9;:]#[a-zA-Z]/}
  s=${s//'%{%}'/}
  print -rn -- ${#s}
}

starship_prompt_part() {
  emulate -L zsh
  setopt local_options extendedglob
  local side=$1 left right char lw rw cw pad cols=${COLUMNS:-80}
  local -a args=(
    --terminal-width="$cols" --keymap="${KEYMAP:-}"
    --status="${STARSHIP_CMD_STATUS:-}"
    --pipestatus="${STARSHIP_PIPE_STATUS[*]:-}"
    --cmd-duration="${STARSHIP_DURATION:-}" --jobs="$STARSHIP_JOBS_COUNT"
  )
  left=$(starship prompt "${args[@]}")
  right=$(starship prompt --right "${args[@]}")
  # `starship module` output lacks the %{%} markers `starship prompt` adds.
  char=$(starship module character --keymap="${KEYMAP:-}" --status="${STARSHIP_CMD_STATUS:-}")
  char=${char//(#b)$'\e'\[([0-9;:]#)([a-zA-Z])/%{$'\e'[${match[1]}${match[2]}%}}
  lw=$(starship_prompt_width "$left")
  rw=$(starship_prompt_width "$right")
  cw=$(starship_prompt_width "$char")
  local char_below inline
  (( char_below = (lw + cw) * 2 > cols ))
  (( inline = ! char_below && lw + cw + rw + 1 <= cols ))
  if [[ $side == right ]]; then
    # The right prompt is RPROMPT's to draw only on the one-line layout.
    (( inline )) && print -rn -- "$right"
    return 0
  fi
  # zsh's own RPROMPT stops one column short of the edge; match that in the
  # composed layouts so the right prompt doesn't jump columns between them.
  if (( char_below )); then
    if (( lw + rw + 2 <= cols )); then
      printf '%s%*s%s\n%s' "$left" $((cols - lw - rw - 1)) '' "$right" "$char"
    else
      (( pad = cols - rw - 1 > 0 ? cols - rw - 1 : 0 ))
      printf '%*s%s\n%s\n%s' "$pad" '' "$right" "$left" "$char"
    fi
  elif (( inline )); then
    print -rn -- "$left$char"
  else
    (( pad = cols - rw - 1 > 0 ? cols - rw - 1 : 0 ))
    printf '%*s%s\n%s%s' "$pad" '' "$right" "$left" "$char"
  fi
}

# Registered before the init below, so this runs before starship's own precmd
# hook; hand the original $? back for it to record (character colour and
# command duration are derived from it).
starship_prompt_precmd() {
  local ret=$?
  PROMPT='$(starship_prompt_part left)'
  RPROMPT='$(starship_prompt_part right)'
  return $ret
}

if (( $+commands[starship] )); then
  precmd_functions+=(starship_prompt_precmd)
  eval "$(starship init zsh)"
fi
