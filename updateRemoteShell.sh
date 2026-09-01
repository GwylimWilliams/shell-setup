#!/bin/bash
#
# updateRemoteShell.sh <target-machine>
# Copies this repo to <target> and re-runs the clean-install script there.
#
# Usage:
#   bash updateRemoteShell.sh <target-machine>

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "ERROR: target machine required." >&2
  echo "Usage: $0 <target-machine>" >&2
  exit 1
fi

TARGET="$1"

# Install the repo as a hidden dot-dir at the target's home root, regardless
# of this directory's name. rm -rf so a first push (no existing copy) works.
LOCAL_DIR="$(pwd)"
REMOTE_DIR=".shell-setup"

ssh "$TARGET" rm -rf "$REMOTE_DIR"
scp -r "$LOCAL_DIR" "$TARGET":"$REMOTE_DIR"
ssh "$TARGET" "$REMOTE_DIR/clean-install-zsh.sh"
