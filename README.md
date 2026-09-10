# shell-setup

Repeatable zsh shell stack: one script that backs up, wipes, and reinstalls a
complete shell environment on any machine — Arch/CachyOS (pacman),
Debian/Ubuntu (apt), or macOS (Homebrew). Everything is either fetched from
git or downloaded as a precompiled binary, so the only required system
packages are `zsh`, `git`, and `curl`.

## What you get

- **Oh My Zsh** with the **starship** prompt (cross-shell; the OMZ theme is disabled)
- **Plugins**: git, sudo, z, docker, command-not-found, colored-man-pages
- **Fish-feel typing** (from git, no distro packages): zsh-syntax-highlighting,
  zsh-autosuggestions, zsh-history-substring-search, zsh-completions
- **mise** version manager (precompiled binary): PATH-based activation (no
  shims), java/python/node core plugins, idiomatic version file support
  (`.java-version`, `.nvmrc`, `.node-version`, `.python-version`), plus the
  GitHub CLI (`gh`) as a global mise tool (bump `GH_VERSION` in the CONFIG
  block to upgrade)
- **fastfetch** system banner on every new shell
- **MesloLGS Nerd Font** (required by starship glyphs)
- Repo-managed dotfiles symlinked into `~`: `.zshrc`, `.vimrc`, `.inputrc`,
  `.fastfetch.jsonc` — and the prompt config `starship.toml` →
  `~/.config/starship.toml`

## Quick install

```sh
if [ -e ~/.shell-setup ]; then git -C ~/.shell-setup pull; else git clone --depth 1 https://github.com/GwylimWilliams/shell-setup.git ~/.shell-setup; fi && bash ~/.shell-setup/clean-install-zsh.sh
```

> **This will:**
> - Clone the repo into `~/.shell-setup` (shallow — latest commit only), or
>   update an existing checkout there with `git pull`
> - Back up your current setup to `~/zsh-backup-<timestamp>`, then clean and
>   reinstall Oh My Zsh, starship, the plugins, mise, and the MesloLGS
>   Nerd Font
> - Symlink the repo's dotfiles into `~` (`.zshrc`, `.vimrc`, `.inputrc`,
>   `.fastfetch.jsonc`) and `starship.toml` into `~/.config/`
> - Leave `~/.zsh_history`, `~/.config/mise`, and your toolchains untouched

Requires `zsh`, `git`, and `curl` already installed — on a fresh machine,
install those first (the script prints the exact command if any are missing),
then re-run.

## Repo layout

```
clean-install-zsh.sh    the recipe: backup → clean → reinstall (deps only — never writes zshrc)
updateRemoteShell.sh    push this repo to a remote machine and reinstall there
cleanup-legacy-p10k.sh  one-shot: removes powerlevel10k leftovers on old machines
zshrc                   STATIC hand-edited setup — wire features up here
dot-files/
  .zshrc                thin wrapper: sources <repo>/zshrc + personal additions
  starship.toml         starship prompt config (→ ~/.config/starship.toml)
  .vimrc, .inputrc      editor/readline config
  .fastfetch.jsonc      fastfetch banner config
```

## Usage

```sh
bash clean-install-zsh.sh                    # backup + clean + install
bash clean-install-zsh.sh --backup-only      # just back up, change nothing
bash clean-install-zsh.sh --keep-config      # remove OMZ/plugins, keep dotfiles
bash clean-install-zsh.sh --set-default      # chsh to zsh (no prompt)
bash clean-install-zsh.sh --skip-packages    # skip the package presence check
bash clean-install-zsh.sh --skip-fonts       # skip the Nerd Font install
```

On a fresh machine: install `zsh git curl` first (the script prints the exact
command for your distro), then re-run. After install: `starship config` (or
`starship preset --list`) to customize the prompt, `chsh -s /usr/bin/zsh` if
the default shell wasn't changed, and select MesloLGS NF as your terminal
font.

Backups land in `~/zsh-backup-<timestamp>`.

If a machine previously ran the powerlevel10k setup: `~/.p10k.zsh` and
`~/.cache/p10k-*` may linger — `bash cleanup-legacy-p10k.sh` removes them (a
real `~/.p10k.zsh` is backed up first). It's independent of the installer, so
run it whenever convenient.

## Updating a remote machine

```sh
bash updateRemoteShell.sh <target-machine>
```

Copies the repo to `~/.shell-setup` on the target (via scp/ssh) and re-runs
the clean-install there. `rm -rf` first, so a first push works too.

## How it works

The script is a **dependency installer**: it backs up, cleans, then installs
everything the setup needs — Oh My Zsh, plugins, the mise and starship
binaries (toolchains install through mise), fonts, dotfile symlinks — from
git or precompiled releases. The `CONFIG` block pins
versions and repos; the zsh setup itself lives in the static, hand-edited
`zshrc`. To add a feature: add its dependency install to the script (pinning
versions/repos in `CONFIG`) and add the zshrc lines yourself. Missing required packages print their install command
and exit; optional tools (fastfetch) are skipped with a hint instead of
blocking.

Key design points:

- **Layered zshrc** — `dot-files/.zshrc` (symlinked to `~/.zshrc`) sources the
  static `<repo>/zshrc`, then applies personal additions. The install script
  never writes either file, so re-running it can never clobber your edits.
  Machine-local overrides live in `~/.zshrc-local` (untracked).
- **Starship draws the prompt, config is repo-tracked** — OMZ loads no theme;
  starship (pinned precompiled binary, `STARSHIP_VERSION`) owns the prompt.
  `dot-files/starship.toml` is symlinked to `~/.config/starship.toml`, so
  prompt tweaks are committable. The fastfetch banner still runs early in
  `zshrc` so it prints before mise's notices and the first prompt — cosmetic
  ordering only, nothing depends on it.
- **mise survives rebuilds** — `clean()` deliberately leaves `~/.config/mise`
  and `~/.local/share/mise` alone so the global config and toolchains aren't
  wiped. Bump `MISE_VERSION` in the CONFIG block to upgrade mise. More
  generally `~/.config` is only ever touched at the exact repo-linked files
  (`LINKED_CONFIG_FILES`).
- **Edits in `~` are committable** — the symlinked dotfiles point into the
  repo, so changing `~/.vimrc` or the starship config produces commits
  directly.

## Customizing

| What | Where |
|---|---|
| Dependency versions, plugin repos | `CONFIG` block in `clean-install-zsh.sh`, then re-run |
| Feature wiring (plugins, mise…) | `zshrc` — edit directly |
| Personal zsh additions | `dot-files/.zshrc` (after the "your personal additions" marker) |
| Machine-local overrides | `~/.zshrc-local` |
| Prompt look | `starship config` / `starship preset` (edits `dot-files/starship.toml`, tracked) |
| fastfetch banner | `dot-files/.fastfetch.jsonc` |
