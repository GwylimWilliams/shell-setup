# shell-setup

Repeatable zsh shell stack: one script that backs up, wipes, and reinstalls a
complete shell environment on any machine — Arch/CachyOS (pacman),
Debian/Ubuntu (apt), or macOS (Homebrew). Everything is either fetched from
git or downloaded as a precompiled binary, so the only required system
packages are `zsh`, `git`, and `curl`.

## What you get

- **Oh My Zsh** with the **powerlevel10k** theme (instant prompt, icons)
- **Plugins**: git, sudo, z, docker, command-not-found, colored-man-pages
- **Fish-feel typing** (from git, no distro packages): zsh-syntax-highlighting,
  zsh-autosuggestions, zsh-history-substring-search, zsh-completions
- **mise** version manager (precompiled binary): PATH-based activation (no
  shims), java/python/node core plugins, idiomatic version file support
  (`.java-version`, `.nvmrc`, `.node-version`, `.python-version`), plus the
  GitHub CLI (`gh`) as a global mise tool (bump `GH_VERSION` in the CONFIG
  block to upgrade)
- **fastfetch** system banner on every new shell
- **MesloLGS Nerd Font** (required by p10k icons)
- Repo-managed dotfiles symlinked into `~`: `.zshrc`, `.p10k.zsh`, `.vimrc`,
  `.inputrc`, `.fastfetch.jsonc`

## Repo layout

```
clean-install-zsh.sh    the recipe: backup → clean → reinstall (deps only — never writes zshrc)
updateRemoteShell.sh    push this repo to a remote machine and reinstall there
zshrc                   STATIC hand-edited setup — wire features up here
dot-files/
  .zshrc                thin wrapper: sources <repo>/zshrc + personal additions
  .p10k.zsh             prompt config (written by `p10k configure`)
  .vimrc, .inputrc      editor/readline config
  .fastfetch.jsonc      fastfetch banner config
```

## Usage

```sh
bash clean-install-zsh.sh                    # backup + clean + install
bash clean-install-zsh.sh --backup-only      # just back up, change nothing
bash clean-install-zsh.sh --keep-config      # remove OMZ/plugins/p10k, keep dotfiles
bash clean-install-zsh.sh --set-default      # chsh to zsh (no prompt)
bash clean-install-zsh.sh --restore-p10k     # restore ~/.p10k.zsh from backup
bash clean-install-zsh.sh --skip-packages    # skip the package presence check
bash clean-install-zsh.sh --skip-fonts       # skip the Nerd Font install
```

On a fresh machine: install `zsh git curl` first (the script prints the exact
command for your distro), then re-run. After install: `p10k configure` to
customize the prompt, `chsh -s /usr/bin/zsh` if the default shell wasn't
changed, and select MesloLGS NF as your terminal font.

Backups land in `~/zsh-backup-<timestamp>`.

## Updating a remote machine

```sh
bash updateRemoteShell.sh <target-machine>
```

Copies the repo to `~/.shell-setup` on the target (via scp/ssh) and re-runs
the clean-install there. `rm -rf` first, so a first push works too.

## How it works

The script is a **dependency installer**: it backs up, cleans, then installs
everything the setup needs — Oh My Zsh, plugins, the mise binary (toolchains
install through it), fonts, dotfile symlinks — from git or
precompiled releases. The `CONFIG` block pins
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
- **Startup ordering is load-bearing** — anything that prints during zsh init
  (the fastfetch banner and the mise startup hooks today) must run *before*
  the p10k instant prompt, or p10k warns about "console output during zsh
  initialization". It all sits above the "END of pre-instant-prompt zone"
  marker in `<repo>/zshrc`; don't put printing init below that marker or in
  `dot-files/.zshrc`.
- **mise survives rebuilds** — `clean()` deliberately leaves `~/.config/mise`
  and `~/.local/share/mise` alone so the global config and toolchains aren't
  wiped. Bump `MISE_VERSION` in the CONFIG block to upgrade mise.
- **Edits in `~` are committable** — the symlinked dotfiles point into the
  repo, so changing `~/.vimrc` or re-running `p10k configure` produces
  commits directly.

## Customizing

| What | Where |
|---|---|
| Dependency versions, plugin repos | `CONFIG` block in `clean-install-zsh.sh`, then re-run |
| Feature wiring (plugins, mise…) | `zshrc` — edit directly, keep the pre-instant-prompt ordering |
| Personal zsh additions | `dot-files/.zshrc` (after the "your personal additions" marker) |
| Machine-local overrides | `~/.zshrc-local` |
| Prompt look | `p10k configure` (writes `~/.p10k.zsh`, tracked) |
| fastfetch banner | `dot-files/.fastfetch.jsonc` |
