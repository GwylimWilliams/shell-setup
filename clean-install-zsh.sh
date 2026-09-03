#!/usr/bin/env bash
#
# clean-install-zsh.sh
# Backup → clean → reinstall the zsh shell stack. Works on Arch/CachyOS
# (pacman), Debian/Ubuntu (apt) and macOS (Homebrew).
#
# Usage:
#   bash clean-install-zsh.sh                     # backup + clean + install
#   bash clean-install-zsh.sh --backup-only       # just back up, change nothing
#   bash clean-install-zsh.sh --keep-config       # remove OMZ/plugins/p10k, keep dotfiles
#   bash clean-install-zsh.sh --set-default       # chsh to zsh (no prompt)
#   bash clean-install-zsh.sh --restore-p10k      # restore ~/.p10k.zsh from backup
#   bash clean-install-zsh.sh --skip-packages     # skip the package presence check
#   bash clean-install-zsh.sh --skip-fonts        # skip the Nerd Font install
#
# Design: this script installs dependencies — clones, precompiled binaries,
# symlinked dotfiles and repo bin scripts. The top-level `zshrc` is a static,
# hand-edited file: the script never writes it. To add a feature, add its
# dependency install to this script AND wire it up in `zshrc` directly.
#
# Fresh-machine behaviour: required commands (zsh, git, curl) and a Nerd Font
# (MesloLGS NF) are checked up front. If any are missing, the script prints the
# install command and exits — run it, then re-run this script. Everything else
# (Oh My Zsh, plugins, p10k) is pulled from git.

# ════════════════════════════════════════════════════════════════════
# CONFIG — edit these at the top before running
# ════════════════════════════════════════════════════════════════════

# The zsh setup itself (theme, OMZ plugins, feature wiring) lives in the
# top-level `zshrc` — a static, hand-edited file; this CONFIG block only pins
# what the script installs: packages, binaries, fonts, dotfiles, plugin repos.

# Commands the recipe needs on a fresh machine. The script checks these and
# prints the install command + exits if any are missing. zsh is the only real
# package; git + curl are needed to fetch the repos and Nerd Font. Oh My Zsh,
# plugins and p10k are all cloned from git, so they need no distro packages.
REQUIRED_PACKAGES=(
  zsh
  git
  curl
)

# Optional tools: the install never fails if these are missing, but their
# install command is printed so you can add them when you want. fastfetch
# prints the system banner on every new shell (see the top of <repo>/zshrc —
# the banner must run before the p10k instant prompt or it trips the
# console-output warning, so it can't live in the dot-files/.zshrc personal
# additions).
OPTIONAL_PACKAGES=(
  fastfetch
)

# Nerd Font(s) for p10k icons. The installer downloads a weight only if its
# file is absent from ~/.local/share/fonts (or ~/Library/Fonts on macOS).
# Add other Nerd Font families (e.g. "FiraCode Nerd Font") here if you prefer
# a different terminal font.
REQUIRED_FONTS=(
  "MesloLGS NF"
)

# Repo-managed dotfiles: symlinked into $HOME so edits there are committable
# back to the repo. Targets resolve against this script's own location.
# dot-files/.zshrc is a thin wrapper that sources the static top-level
# `zshrc` — never write directly to ~/.zshrc in this script, it would
# clobber the symlink.
LINKED_DOTFILES=(.vimrc .inputrc .p10k.zsh .zshrc .fastfetch.jsonc)

# Git-based zsh extras — cloned into $PLUGIN_DIR instead of installed via the
# distro package manager, so the same script works on Arch, Ubuntu and macOS.
# zsh-completions needs no source line: it just has to be on zsh's fpath
# before compinit (the zshrc adds it).
PLUGIN_DIR="$HOME/.zsh-plugins"
SYNTAX_REPO="https://github.com/zsh-users/zsh-syntax-highlighting"
AUTOSUGGEST_REPO="https://github.com/zsh-users/zsh-autosuggestions"
HISTORY_SEARCH_REPO="https://github.com/zsh-users/zsh-history-substring-search"
COMPLETIONS_REPO="https://github.com/zsh-users/zsh-completions"

# mise — language/tool version manager, installed as a precompiled binary
# into ~/.local/bin (already on PATH via dot-files/.zshrc). Pin MISE_VERSION
# to upgrade: bump it, re-run the script. Java, python and node are core
# plugins — no plugin installs needed.
MISE_VERSION="2026.8.14"

# GitHub CLI — installed as a global mise tool so `gh` is on PATH everywhere
# (mise activate). Uses the aqua backend (official cli/cli release binaries),
# no plugin install needed. Pin GH_VERSION to upgrade: bump it, re-run the
# script.
GH_VERSION="2.98.0"

# Optional asdf-backend plugins for mise (e.g. jfrog). Not installed by the
# script — they're per-machine dev tools, added at rollout with
# `mise use -g jfrog@latest`. For reference, the install command is
# `mise plugins install <name> <url>`.
#MISE_ASDF_PLUGINS=(
#  "jfrog=https://github.com/mise-plugins/mise-jfrog-cli"
#)

# ════════════════════════════════════════════════════════════════════

set -euo pipefail

# flags
DO_CHSH=0
BACKUP_ONLY=0
KEEP_CONFIG=0
RESTORE_P10K=0
SKIP_PACKAGES=0
SKIP_FONTS=0

for arg in "$@"; do
  case "$arg" in
    --backup-only)   BACKUP_ONLY=1 ;;
    --keep-config)   KEEP_CONFIG=1 ;;
    --set-default)   DO_CHSH=1 ;;
    --restore-p10k)  RESTORE_P10K=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-fonts)    SKIP_FONTS=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# sanity
[ -n "${BASH_VERSION:-}" ] || { echo "Run with bash: bash clean-install-zsh.sh" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "Do not run as root (sudo is used internally)." >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/zsh-backup-$STAMP"
OMZ_DIR="$HOME/.oh-my-zsh"
P10K_DIR="$OMZ_DIR/custom/themes/powerlevel10k"
P10K_CONFIG="$HOME/.p10k.zsh"
# ~/.zshrc is repo-managed (LINKED_DOTFILES); the rest are loose dotfiles.
# .zsh_history is deliberately absent: it's user data, not config — a rebuild
# must not wipe command history (autosuggestions/history-search read it), and
# since it's never touched, there's nothing to back up.
DOTFILES=(.zshrc .zshenv .zprofile .zlogin .zlogout)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dot-files"
# Repo-managed bin scripts — every file in repo/bin/ is symlinked into ~/.bin
# (created if missing). Same contract as LINKED_DOTFILES: existing real files
# are backed up first; existing symlinks are not (their content lives in the
# repo already).
BIN_DIR="$SCRIPT_DIR/bin"
BIN_LINK_DIR="$HOME/.bin"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# 1. backup
backup() {
  log "Backing up existing shell config → $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  local found=0
  for f in "${DOTFILES[@]}"; do
    if [ -e "$HOME/$f" ]; then
      cp -a "$HOME/$f" "$BACKUP_DIR/" && { echo "  ✓ ~/$f"; found=1; }
    fi
  done
  # repo-managed dotfiles: back up real files only (a symlink's content lives
  # in the repo already)
  for f in "${LINKED_DOTFILES[@]}"; do
    if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
      cp -a "$HOME/$f" "$BACKUP_DIR/" && { echo "  ✓ ~/$f"; found=1; }
    fi
  done
  # repo-managed bin scripts: same rule — real files at ~/.bin targets get
  # backed up, symlinks are skipped (they point at the repo already)
  for src in "$BIN_DIR"/*; do
    [ -e "$src" ] || continue
    f="$(basename "$src")"
    if [ -e "$BIN_LINK_DIR/$f" ] && [ ! -L "$BIN_LINK_DIR/$f" ]; then
      cp -a "$BIN_LINK_DIR/$f" "$BACKUP_DIR/" && { echo "  ✓ ~/.bin/$f"; found=1; }
    fi
  done
  if [ -d "$OMZ_DIR" ]; then
    cp -a "$OMZ_DIR" "$BACKUP_DIR/oh-my-zsh" && { echo "  ✓ ~/.oh-my-zsh"; found=1; }
  fi
  for d in "$HOME"/.cache/p10k-*; do
    [ -e "$d" ] && cp -a "$d" "$BACKUP_DIR/" && { echo "  ✓ $(basename "$d")"; found=1; }
  done
  [ "$found" -eq 1 ] || echo "  (nothing to back up — fresh machine?)"
  echo "  Backup complete: $BACKUP_DIR"
}

# 2. platform + packages — verify present, print install command + exit if missing
detect_platform() {
  if [ "$(uname)" = "Darwin" ]; then
    PLATFORM="macOS"; PKG_MANAGER="brew"
  elif command -v pacman >/dev/null 2>&1; then
    PLATFORM="Arch/CachyOS"; PKG_MANAGER="pacman"
  elif command -v apt-get >/dev/null 2>&1; then
    PLATFORM="Debian/Ubuntu"; PKG_MANAGER="apt"
  else
    PLATFORM="unknown"; PKG_MANAGER=""
  fi
}

pkg_installed() {
  case "$PKG_MANAGER" in
    pacman) pacman -Q "$1" >/dev/null 2>&1 ;;
    apt)    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    # macOS ships zsh/git/curl — accept the system binary OR a brew install
    brew)   command -v "$1" >/dev/null 2>&1 || brew list --formula "$1" >/dev/null 2>&1 ;;
    *)      command -v "$1" >/dev/null 2>&1 ;;
  esac
}

check_packages() {
  if [ "$SKIP_PACKAGES" -eq 1 ]; then
    echo "  --skip-packages: skipping package presence check."
    return
  fi
  echo "  Platform: $PLATFORM (${PKG_MANAGER:-no package manager detected})"
  local missing=()
  local pkg
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    pkg_installed "$pkg" || missing+=("$pkg")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "  Missing required packages: ${missing[*]}" >&2
    echo "  Install them, then re-run this script:" >&2
    case "$PKG_MANAGER" in
      pacman) echo "    sudo pacman -S --needed ${missing[*]}" >&2 ;;
      apt)    echo "    sudo apt-get install -y ${missing[*]}" >&2 ;;
      brew)   echo "    brew install ${missing[*]}" >&2 ;;
      *)      echo "    (package manager unknown — install ${missing[*]} manually)" >&2 ;;
    esac
    exit 1
  fi
  echo "  All required packages present: ${REQUIRED_PACKAGES[*]}"
}

# Optional packages: warn + print the install command, but never block the
# install. The shell still works without them (their zshrc hooks no-op).
# Prints nothing when all are present, so it reads cleanly in the Next list.
check_optional_packages() {
  local missing=()
  local pkg
  for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    pkg_installed "$pkg" || missing+=("$pkg")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "    Optional (skipped, still functional): ${missing[*]}"
    case "$PKG_MANAGER" in
      pacman) echo "    Install them whenever with:  sudo pacman -S --needed ${missing[*]}" ;;
      apt)    echo "    Install them whenever with:  sudo apt-get install -y ${missing[*]}" ;;
      brew)   echo "    Install them whenever with:  brew install ${missing[*]}" ;;
      *)      echo "    Install ${missing[*]} manually (package manager unknown)" ;;
    esac
  fi
}

# 3. plugin source files — verify what the zshrc sources exists
check_sources() {
  log "Checking zsh plugin source files"
  local missing=()
  [ -f "$PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || missing+=("zsh-syntax-highlighting")
  [ -f "$PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || missing+=("zsh-autosuggestions")
  [ -f "$PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh" ] || missing+=("zsh-history-substring-search")
  [ -d "$PLUGIN_DIR/zsh-completions/src" ] || missing+=("zsh-completions")
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "  Plugin clone missing expected files:" >&2
    printf '    %s\n' "${missing[@]}" >&2
    exit 1
  fi
  echo "  Plugin source files present"
}

# 3b. Nerd Font — install MesloLGS NF if missing (p10k needs it for icons).
# Downloads each weight only when that file is absent, so re-runs are cheap.
install_fonts() {
  if [ "$SKIP_FONTS" -eq 1 ]; then
    echo "  --skip-fonts: skipping Nerd Font install."
    return
  fi

  local dest
  if [ "$PLATFORM" = "macOS" ]; then
    dest="$HOME/Library/Fonts"
  else
    dest="$HOME/.local/share/fonts"
  fi
  mkdir -p "$dest"

  local v file downloaded=0
  for v in Regular Bold Italic; do
    file="$dest/MesloLGS NF $v.ttf"
    if [ -f "$file" ]; then
      echo "  ✓ $file already present"
      continue
    fi
    curl -Lfo "$file" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20$v.ttf"
    downloaded=1
  done

  if [ "$downloaded" -eq 0 ]; then
    echo "  Nerd Font present: ${REQUIRED_FONTS[*]}"
    return
  fi

  # rebuild the user-font cache explicitly (fc-cache -f with no args doesn't
  # always refresh ~/.local/share/fonts synchronously). macOS reads
  # ~/Library/Fonts directly and has no fc-list/fc-cache.
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dest" >/dev/null

  # Source of truth is the files on disk (downloads above are curl -f, so they
  # either landed or the script aborted). fc-list can lag the cache rebuild,
  # so a miss here is informational — the terminal will see the font anyway.
  if command -v fc-list >/dev/null 2>&1; then
    local still=()
    local font
    for font in "${REQUIRED_FONTS[@]}"; do
      fc-list 2>/dev/null | grep -qi "$font" || still+=("$font")
    done
    if [ "${#still[@]}" -gt 0 ]; then
      echo "  Font files are in $dest, but fc-list hasn't picked them up yet." >&2
      echo "  Log out/in (or restart fontconfig) and select 'MesloLGS NF' in your terminal." >&2
      echo "  Equivalent AUR package if it never registers: yay -S ttf-meslo-nerd-font-powerlevel10k" >&2
    fi
  fi
  echo "  Nerd Font installed: ${REQUIRED_FONTS[*]}"
}

# 4. clean
clean() {
  log "Cleaning old shell stack"
  if [ "$KEEP_CONFIG" -eq 1 ]; then
    echo "  --keep-config: leaving dotfiles in place (removing only OMZ + plugins + p10k)."
  else
    for f in "${DOTFILES[@]}"; do
      [ -e "$HOME/$f" ] && rm -rf "$HOME/$f" && echo "  removed ~/$f"
    done
    for f in "${LINKED_DOTFILES[@]}"; do
      [ -e "$HOME/$f" ] && rm -rf "$HOME/$f" && echo "  removed ~/$f (repo-managed — relinking)"
    done
    # repo-managed bin scripts — removed so they get relinked; anything else
    # in ~/.bin is the user's own and is left alone
    for src in "$BIN_DIR"/*; do
      [ -e "$src" ] || continue
      f="$(basename "$src")"
      dest="$BIN_LINK_DIR/$f"
      if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -rf "$dest" && echo "  removed ~/.bin/$f (repo-managed — relinking)"
      fi
    done
  fi
  [ -d "$OMZ_DIR" ] && rm -rf "$OMZ_DIR" && echo "  removed ~/.oh-my-zsh"
  [ -d "$PLUGIN_DIR" ] && rm -rf "$PLUGIN_DIR" && echo "  removed ~/.zsh-plugins"
  rm -rf "$HOME"/.cache/p10k-* 2>/dev/null || true
  echo "  Clean complete"
}

# 5. oh-my-zsh
install_omz() {
  if [ -d "$OMZ_DIR/.git" ]; then
    echo "  oh-my-zsh present — updating"
    (cd "$OMZ_DIR" && git pull --ff-only) || echo "  (update skipped)"
  else
    log "Cloning Oh My Zsh"
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
  fi
}

# 6. p10k
install_p10k() {
  mkdir -p "$(dirname "$P10K_DIR")"
  if [ -d "$P10K_DIR/.git" ]; then
    echo "  powerlevel10k present — updating"
    (cd "$P10K_DIR" && git pull --ff-only) || echo "  (update skipped)"
  else
    log "Cloning Powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  fi
}

# 6a. git-based zsh plugins (syntax highlighting, autosuggestions, history
# search, completions) — cloned from git instead of distro packages, so the
# only system packages needed are zsh itself (plus git/curl to fetch these).
sync_plugin() {
  local name="$1" url="$2"
  local dir="$PLUGIN_DIR/$name"
  mkdir -p "$PLUGIN_DIR"
  if [ -d "$dir/.git" ]; then
    echo "  $name present — updating"
    (cd "$dir" && git pull --ff-only) || echo "  (update skipped)"
  else
    git clone --depth=1 "$url" "$dir"
  fi
}

install_plugins() {
  log "Fetching zsh plugins from git → $PLUGIN_DIR"
  sync_plugin zsh-syntax-highlighting "$SYNTAX_REPO"
  sync_plugin zsh-autosuggestions "$AUTOSUGGEST_REPO"
  sync_plugin zsh-history-substring-search "$HISTORY_SEARCH_REPO"
  sync_plugin zsh-completions "$COMPLETIONS_REPO"
  check_sources
}

# 6a2. mise — language/tool version manager, installed as a precompiled
# binary from GitHub releases. clean() deliberately leaves ~/.config/mise and
# ~/.local/share/mise alone so a rebuild never wipes the global config or the
# toolchains installed through it.
mise_target() {
  local os="" arch=""
  case "$(uname)" in
    Darwin) os="macos" ;;
    Linux)  os="linux" ;;
    *) die "mise: unsupported OS: $(uname)" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "mise: unsupported architecture: $(uname -m)" ;;
  esac
  printf '%s-%s' "$os" "$arch"
}

# Ensure a key exists under [settings] in the global mise config: create the
# file if missing, otherwise insert the key below [settings] (creating the
# section if needed) so other user settings (e.g. trusted_config_paths) are
# never clobbered. Machine-local overrides go in
# ~/.config/mise/config.local.toml (untracked).
ensure_mise_setting() {
  local cfg="$1" key="$2" line="$3"
  if [ ! -f "$cfg" ]; then
    mkdir -p "$(dirname "$cfg")"
    printf '[settings]\n%s\n' "$line" > "$cfg"
    echo "  wrote $cfg ($line)"
  elif ! grep -qE "^[[:space:]]*${key}([[:space:]]|=|$)" "$cfg"; then
    if grep -q '^[[:space:]]*\[settings\]' "$cfg"; then
      awk -v line="$line" '!done && /^[[:space:]]*\[settings\]/ { print; print line; done=1; next } { print }' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
    else
      printf '\n[settings]\n%s\n' "$line" >> "$cfg"
    fi
    echo "  set $line in $cfg"
  else
    echo "  $cfg already sets $key"
  fi
}

install_mise() {
  local mise_bin="$HOME/.local/bin/mise"
  if [ -x "$mise_bin" ] && "$mise_bin" --version 2>/dev/null | grep -Fq "$MISE_VERSION"; then
    echo "  mise $MISE_VERSION present — skipping download"
  else
    log "Installing mise $MISE_VERSION → $HOME/.local/bin"
    local tarball="mise-v${MISE_VERSION}-$(mise_target).tar.gz"
    local extract_dir
    extract_dir="$(mktemp -d)"
    mkdir -p "$HOME/.local/bin"
    curl -Lfo "$HOME/.local/bin/$tarball" \
      "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/$tarball"
    tar -xzf "$HOME/.local/bin/$tarball" -C "$extract_dir"
    mv "$extract_dir/mise/bin/mise" "$mise_bin"
    rm -rf "$extract_dir"
    rm -f "$HOME/.local/bin/$tarball"
    [ -x "$mise_bin" ] || die "mise binary missing after extract: $mise_bin"
  fi
  # zsh completions (mise.zsh prepends this dir to fpath)
  mkdir -p "$HOME/.local/share/mise/completions"
  "$mise_bin" completion zsh > "$HOME/.local/share/mise/completions/_mise" || true

  # [settings] keys for the global config. Idiomatic version files
  # (.java-version, .nvmrc, .node-version, .python-version) are read only for
  # opt-in tools; env_cache=true stops hook-env from re-sourcing env files
  # (e.g. the .envrc _.source) on every shell hook — the cache is invalidated
  # on config/tool/settings changes and edited source files (TTL: 1h default).
  local cfg="$HOME/.config/mise/config.toml"
  ensure_mise_setting "$cfg" idiomatic_version_file_enable_tools \
    'idiomatic_version_file_enable_tools = ["java", "node", "python"]'
  ensure_mise_setting "$cfg" env_cache 'env_cache = true'

  # GitHub CLI — global tool so `gh` is available everywhere. mise use -g
  # installs it (aqua backend) and pins it in the global config's [tools].
  # Warn instead of fail: gh is a dev tool, not part of the shell stack.
  if "$mise_bin" use -g "github-cli@$GH_VERSION"; then
    echo "  gh $GH_VERSION installed (mise global)"
  else
    echo "  (warning) gh install failed — re-run with: mise use -g github-cli@$GH_VERSION" >&2
  fi
}


# 6b. repo-managed dotfiles — symlink from repo into $HOME so edits are committable
link_dotfiles() {
  if [ "$KEEP_CONFIG" -eq 1 ]; then
    echo "  --keep-config: leaving existing dotfiles in place, skipping symlinks."
    return
  fi
  if [ ! -d "$DOTFILES_DIR" ]; then
    echo "  dot-files dir not found — skip symlinking: $DOTFILES_DIR" >&2
    return
  fi
  log "Symlinking repo dotfiles into ~"
  local f src dest
  for f in "${LINKED_DOTFILES[@]}"; do
    src="$DOTFILES_DIR/$f"
    dest="$HOME/$f"
    if [ ! -e "$src" ]; then
      echo "  (skip) $f not in repo: $src"
      continue
    fi
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "  ✓ ~/$f already linked"
      continue
    fi
    # clean() normally removes these first; guard anyway so we never silently
    # leave a stale link or clobber without saying so
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "  (replace) ~/$f"
      rm -rf "$dest"
    fi
    ln -s "$src" "$dest"
    echo "  ✓ linked ~/$f -> $src"
  done
}

# 6c. repo-managed bin scripts — symlink repo/bin/* into ~/.bin (created if
# missing) so edits are committable back to the repo, same as link_dotfiles
link_bin() {
  if [ "$KEEP_CONFIG" -eq 1 ]; then
    echo "  --keep-config: leaving existing ~/.bin items in place, skipping symlinks."
    return
  fi
  if [ ! -d "$BIN_DIR" ]; then
    echo "  bin dir not found — skip symlinking: $BIN_DIR" >&2
    return
  fi
  log "Symlinking repo bin scripts into ~/.bin"
  mkdir -p "$BIN_LINK_DIR"
  local src f dest
  for src in "$BIN_DIR"/*; do
    [ -e "$src" ] || continue
    f="$(basename "$src")"
    dest="$BIN_LINK_DIR/$f"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "  ✓ ~/.bin/$f already linked"
      continue
    fi
    # clean() normally removes these first; guard anyway so we never silently
    # leave a stale link or clobber without saying so
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "  (replace) ~/.bin/$f"
      rm -rf "$dest"
    fi
    ln -s "$src" "$dest"
    echo "  ✓ linked ~/.bin/$f -> $src"
  done
}

# 7. restore p10k config
restore_p10k() {
  if [ "$RESTORE_P10K" -eq 1 ] && [ -f "$BACKUP_DIR/.p10k.zsh" ]; then
    cp -a "$BACKUP_DIR/.p10k.zsh" "$P10K_CONFIG"
    echo "  restored ~/.p10k.zsh from backup"
  fi
}

# 9. default shell
set_default_shell() {
  command -v zsh >/dev/null 2>&1 || { echo "  zsh not found, skipping chsh"; return; }
  if [ "$DO_CHSH" -eq 1 ]; then
    sudo chsh -s "$(command -v zsh)" "$USER" && echo "  default shell set to $(command -v zsh)"
  else
    echo "  default shell unchanged (use --set-default)"
  fi
}

# main
main() {
  log "zsh stack clean-install for $(whoami)@$(hostname)"
  detect_platform
  backup
  if [ "$BACKUP_ONLY" -eq 1 ]; then
    log "Backup only — nothing else touched. Restore with: cp -a $BACKUP_DIR/.* ~/"
    exit 0
  fi
  check_packages
  install_fonts
  clean
  install_omz
  install_p10k
  install_plugins
  install_mise
  link_dotfiles
  link_bin
  restore_p10k
  set_default_shell

  log "Done"
  echo "  Backup:        $BACKUP_DIR"
  echo "  zsh:           $(zsh --version 2>/dev/null | head -1 || echo 'not in PATH')"
  echo "  oh-my-zsh:     $OMZ_DIR"
  echo "  powerlevel10k: $P10K_DIR"
  echo
  echo "  Next:"
  echo "   1. Start zsh and run:  p10k configure   (writes the prompt config to ~/.p10k.zsh)"
  echo "      ~/.p10k.zsh is symlinked to $DOTFILES_DIR/.p10k.zsh, so the wizard's"
  echo "      output is already tracked in the repo."
  echo "   2. If default shell wasn't changed:  chsh -s /usr/bin/zsh"
  echo "   3. Log out & back in. Fish is untouched."
  echo "   4. MesloLGS NF was installed if missing; select it as your terminal"
  echo "      font (the p10k wizard also offers ASCII mode without icons)."
  echo "   5. mise: in a project with a mise.toml that sets env, run:  mise trust"
  check_optional_packages
}

main "$@"
