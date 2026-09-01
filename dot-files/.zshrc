# ── dot-files/.zshrc — wrapper, symlinked to ~/.zshrc ─────────────
# Sources the repo's top-level zshrc (static, hand-edited — NOT generated
# by clean-install-zsh.sh) then applies your personal additions below.
#
# The top-level zshrc handles Oh My Zsh, plugins, extras, asdf and the
# p10k config. Edit <repo>/zshrc directly for the managed setup; edit
# THIS file for anything personal — it's committed to the repo.

# locate <repo>/zshrc relative to this file (dot-files/..)
__zsh_setup=${${(%):-%x}:A:h}/../zshrc
if [[ -r $__zsh_setup ]]; then
  source $__zsh_setup
else
  print -u2 "zsh: setup file not found: $__zsh_setup"
fi
unset __zsh_setup

# ── machine-local overrides (untracked, e.g. per-host tweaks) ────
# `if` (not `&&`) so a missing file leaves $?=0 — otherwise the last
# command before the first prompt is non-zero and the p10k chevron
# renders red on every new shell.
if [[ -r ~/.zshrc-local ]]; then
  source ~/.zshrc-local
fi

# Set up local and home bin in the path:
PATH=~/.bin:~/.local/bin:$PATH

# ── your personal additions ──────────────────────────────────────

# Tab on an empty line runs ls instead of inserting a literal tab
_tab_ls() {
  if [[ -z $BUFFER ]]; then
    BUFFER="ls"
    zle accept-line
  else
    zle expand-or-complete
  fi
}
zle -N _tab_ls
bindkey '^I' _tab_ls

