#!/usr/bin/env bash
#
# cleanup-legacy-p10k.sh
# One-shot cleanup for machines that ran the pre-starship installer: removes
# the leftover ~/.p10k.zsh (a real file is backed up first — symlinks are not,
# their content lives elsewhere) and the ~/.cache/p10k-* snapshot files.
# Safe to re-run; a no-op once there's nothing left.
#
# Run it directly on each machine that used the old powerlevel10k setup:
#   bash cleanup-legacy-p10k.sh
# When no machine needs this anymore, just delete this script — nothing in
# clean-install-zsh.sh depends on it.

set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/zsh-backup-$STAMP-p10k"
P10K_CONFIG="$HOME/.p10k.zsh"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

main() {
  log "Removing legacy powerlevel10k leftovers"
  local found=0

  # ~/.p10k.zsh: the old installer symlinked it from the repo (the file is
  # gone from the repo now, so the symlink dangles). A real file is the
  # user's own wizard config — back it up before removing.
  if [ -L "$P10K_CONFIG" ]; then
    rm -f "$P10K_CONFIG"
    echo "  removed ~/.p10k.zsh (stale symlink)"
    found=1
  elif [ -f "$P10K_CONFIG" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$P10K_CONFIG" "$BACKUP_DIR/"
    rm -f "$P10K_CONFIG"
    echo "  backed up + removed ~/.p10k.zsh → $BACKUP_DIR/"
    found=1
  fi

  # p10k instant-prompt snapshots: regenerable, safe to drop
  local d
  for d in "$HOME"/.cache/p10k-*; do
    [ -e "$d" ] || continue
    rm -rf "$d"
    echo "  removed $d"
    found=1
  done

  [ "$found" -eq 1 ] || echo "  nothing to clean — no p10k leftovers found"
  echo "  Done."
}

main "$@"
