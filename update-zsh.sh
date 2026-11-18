#!/usr/bin/env bash
#
# update-zsh.sh
# Non-destructive, idempotent update of the zsh stack — safe to run on every
# container start, including from an empty $HOME.
#
# Thin wrapper around `clean-install-zsh.sh --update`: existing checkouts are
# pulled in place (a failed pull warns and is retried next run), missing pieces
# are cloned, version-pinned binaries are installed only when the pinned
# version is absent, and the repo dotfiles/config/bin symlinks are re-checked.
# No backup or clean pass runs.
#
# Usage:
#   bash update-zsh.sh                 # update/install the stack in place
#   bash update-zsh.sh --skip-fonts    # also skip the Nerd Font install
#   bash update-zsh.sh --help          # clean-install-zsh.sh options, incl. --update
#
# Exit status: 0 when the stack is complete and current; non-zero when the
# update failed (e.g. network blocked) — the previous stack is left usable.

set -euo pipefail

# Resolve this script's own directory: the caller's cwd is irrelevant (the
# container entrypoint invokes it by absolute path).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec bash "$SCRIPT_DIR/clean-install-zsh.sh" --update "$@"
