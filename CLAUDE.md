# shell-setup

Repeatable zsh shell stack installer. Works on Arch/CachyOS, Debian/Ubuntu,
macOS. See README.md for user-facing docs.

## Layout

- `clean-install-zsh.sh` — the recipe: backup → clean → install dependencies.
  CONFIG block at the top pins versions (mise, starship), plugin repos,
  packages and dotfiles. It never writes `zshrc`.
- `updateRemoteShell.sh <target>` — scp the repo to a remote and re-run the
  install there.
- `cleanup-legacy-p10k.sh` — standalone one-shot for machines that ran the
  pre-starship installer: removes `~/.p10k.zsh` (backing up a real file
  first) and `~/.cache/p10k-*`. Nothing in the repo references it; delete it
  once no machine needs it.
- `zshrc` — STATIC, hand-edited (not generated). This is where features are
  wired up; the install script only provides their dependencies.
- `dot-files/` — repo-managed dotfiles, symlinked into `~`:
  - `.zshrc` — wrapper that sources `<repo>/zshrc` then personal additions.
    This is the file for personal shell tweaks. Machine-local overrides go in
    `~/.zshrc-local` (untracked).
  - `.vimrc`, `.inputrc`, `.fastfetch.jsonc` — flat dotfiles (LINKED_DOTFILES).
  - `starship.toml` — prompt config, symlinked to `~/.config/starship.toml`
    (LINKED_CONFIG_FILES).
  - `completions/` — repo-managed zsh completion functions (e.g. `_g` for the
    g gradle wrapper); NOT symlinked, added to fpath by `zshrc`.
- `bin/` — repo-managed scripts (e.g. `g`), symlinked into `~/.bin` (created
  if missing). Real files at the target are backed up before linking;
  symlinks are not (their content lives in the repo already).
- `.claude/settings.local.json` — local permission settings.

## Invariants (don't break these)

- **The prompt is starship, not an OMZ theme**: `ZSH_THEME=""` in `zshrc`,
  and `eval "$(starship init zsh)"` must stay at the very END of `zshrc`
  (starship docs — init wraps zle widgets and registers hooks). Config is
  repo-tracked: `dot-files/starship.toml` symlinked to
  `~/.config/starship.toml` by `link_configs()` (LINKED_CONFIG_FILES); the
  script never writes the target. Bump `STARSHIP_VERSION` in CONFIG to
  upgrade (arm64 Linux uses the musl asset — starship ships no
  aarch64-linux-gnu build).
- **Exit-status hygiene**: guards that run just before the first prompt use
  `if ... fi`, not `&&` — a false condition leaves `$?=0`, so starship's
  default character isn't red on every new shell. Applies to
  `dot-files/.zshrc` (`~/.zshrc-local`) and the starship init guard.
- **`~/.zshrc` is a symlink** into the repo. The install script never writes
  to `~/.zshrc`, `<repo>/zshrc`, or the LINKED_CONFIG_FILES targets. Same for
  the other LINKED_DOTFILES.
- **`~/.config/mise` and `~/.local/share/mise` are never cleaned** — rebuilds
  must not wipe the global config or toolchains installed through mise. Bump
  `MISE_VERSION` in CONFIG to upgrade mise itself. More generally, `clean()`
  touches `~/.config` only at the exact repo-linked file paths (never
  `rm -rf ~/.config`).
- **`~/.zsh_history` is never touched** — it's not in the script's DOTFILES
  list, so clean() neither removes it nor backs it up: autosuggestions and
  history-substring-search read it, so deleting it on a rebuild silently
  kills both. It's user data, not config.
- **Legacy p10k cleanup lives in `cleanup-legacy-p10k.sh`, not the
  installer** — pre-starship installs left `~/.p10k.zsh` (a repo symlink) and
  `~/.cache/p10k-*` behind; `clean-install-zsh.sh` deliberately never touches
  them (no backup, no removal). The one-shot script removes them (a real
  `~/.p10k.zsh` is backed up first, a symlink is just deleted). Once no
  machine needs it, delete the script — nothing depends on it. The MesloLGS
  NF download/AUR lines in the installer are fonts (starship glyphs), not
  p10k leftovers — keep them.
- Script must stay distro-agnostic: system packages only `zsh`/`git`/`curl`
  (plus optional fastfetch); everything else comes from git or precompiled
  release binaries. Don't add distro-specific package deps.

## mise Version & Toolchain Notes

- **PATH-based activation**: `mise.zsh` runs `mise activate zsh` (no shims),
  which sets tool versions + `JAVA_HOME` on cd/prompt. `mise activate` does
  NOT install missing tools — a `_mise_auto_install` chpwd hook does, using
  `mise install --dry-run-code` (exits 1 iff any configured tool is missing;
  covers `.tool-versions`, `mise.toml`, and enabled idiomatic files). Gated
  on `mise hook-env` exiting 0 — `mise install` auto-trusts even with
  `--dry-run-code`, so without the gate the first cd would silently trust
  the bootstrap file (trust records: `~/.local/state/mise/trusted-configs/`).
- **`.envrc` bootstrap**: `_mise_bootstrap_envrc` (a chpwd hook that runs
  before `_mise_auto_install`) auto-creates an UNTRUSTED `mise.toml` with
  `[env] _.source = { path = ".envrc", tools = true, redact = true }` when a
  project has an `.envrc` but no `mise.toml` (the direnv-replacement
  wiring). Left untrusted on purpose — `mise trust` is the one-time consent
  step per project, so a cloned repo's `.envrc` is never sourced without the
  user saying yes. It prints `run 'mise trust'` on every cd until trust is
  granted (hook-env's exit code — 1 while untrusted — is not
  session-suppressed like its WARN is).
- **Idiomatic version files** (`.java-version`, `.nvmrc`, `.node-version`,
  `.python-version`) are read only for the opt-in tools in
  `idiomatic_version_file_enable_tools = ["java", "node", "python"]`, set in
  the global config by `clean-install-zsh.sh` (create-if-missing / insert
  under `[settings]` — user settings are never clobbered).
- **`env_cache = true`** is set in the global config by
  `clean-install-zsh.sh` (same insert-under-`[settings]` mechanism). It makes
  `mise hook-env` serve the computed env from a disk cache instead of
  re-sourcing env files (e.g. a trusted `.envrc` `_.source`) on every shell
  hook — several hook-env calls fire per cd (activation chpwd +
  `_mise_bootstrap_envrc` + `_mise_auto_install`). Invalidation: config/tool/
  settings/mise-version changes and edited `_.source`d files; TTL
  `env_cache_ttl` (default 1h). Opt out per machine with `env_cache = false`
  in `config.local.toml`; per-directive opt-out is `cacheable = false`.
- **Global config** at `~/.config/mise/config.toml`; machine-local overrides
  go in `~/.config/mise/config.local.toml` (untracked — the analog of
  `.zshrc-local`). A `mise.toml` with `[env]`/`_.source` is untrusted by
  default — `mise trust <project>` is needed before env is applied.
- **Tools must be reinstalled under mise** — it does not reuse
  `~/.asdf/installs`. Java/python/node are core plugins; asdf-backend tools
  (e.g. jfrog) need `mise plugins install jfrog https://github.com/mise-plugins/mise-jfrog-cli`.
- **`.tool-versions` is no longer repo-managed** — dropped from
  `LINKED_DOTFILES` (its only entry, direnv, went with the direnv migration);
  per-project `.tool-versions` files are still read by mise.

## Workflow

1. To add a feature: add its dependency install to `clean-install-zsh.sh`
   (the CONFIG block pins versions/repos) AND wire it up in `zshrc` directly
   (mind the starship-init-at-end and exit-status invariants above). To
   change behavior: edit `zshrc`.
2. Verify with a fake home in /tmp (see Testing below).

## Environment 
You must not assume that you can diagnose an issue from the local machine environment, 
the user uses this setup on remote machings and any error they are talking about is probably
on a remove machine where this setup has been run.
e.g checking things are present in local home is wrong.

## Testing

**Never run `clean-install-zsh.sh` for real** — it rebuilds the user's live
shell stack. The user runs it themselves.
Same for `updateRemoteShell.sh` (it reinstalls on a remote machine). Agents
test against a **fake home directory in /tmp**, which redirects everything the
script touches (backup, `~/.oh-my-zsh`, `~/.zsh-plugins`, dotfile symlinks,
fonts, mise, the starship binary, `~/.config/starship.toml`) away from the
real home:

```sh
mkdir -p /tmp/zsh-test-home
HOME=/tmp/zsh-test-home bash clean-install-zsh.sh --skip-fonts --skip-packages
```

`--skip-fonts` avoids the Nerd Font download/fontconfig side effects;
`--skip-packages` skips the distro package check (still needs network — OMZ
and the plugins are cloned, the mise and starship binaries downloaded). A
plain default run is sudo-free: `sudo` only appears in `set_default_shell`
(chsh), so never pass `--set-default` in a test.

Expected noise in the test log: mise reports the real
`~/.config/mise/config.toml` as untrusted and the `gh` install step warns.
That's an artifact of the HOME override — mise walks up from the checkout,
finds the real home's config as an ancestor config, and (since HOME differs)
treats it as untrusted. On a real machine that file is the global config and
no trust applies. Don't chase it.

Check after the run:

- Exit code 0.
- `ls -la /tmp/zsh-test-home/` — dotfiles symlinked into the repo
  (`~/.zshrc -> <repo>/dot-files/.zshrc`), backup dir `zsh-backup-*` created.
- `ls -la /tmp/zsh-test-home/.bin/` — repo bin scripts symlinked
  (`~/.bin/g -> <repo>/bin/g`).
- `~/.config/starship.toml` is a symlink into the repo
  (`dot-files/starship.toml`); `~/.local/bin/starship --version` matches
  `STARSHIP_VERSION`.
- `~/.config/mise/config.toml` contains `idiomatic_version_file_enable_tools`
  with java, node, python.
- `git status zshrc` — the script must leave the static `zshrc` untouched.
- Smoke-test the setup:
  `HOME=/tmp/zsh-test-home zsh -i -c 'command -v mise; command -v starship'`.

`cleanup-legacy-p10k.sh` is separate from the installer and safe to test the
same way: seed a dangling `~/.p10k.zsh` symlink (or a real file) plus
`~/.cache/p10k-*`, run `HOME=/tmp/zsh-test-home bash cleanup-legacy-p10k.sh`,
and check they're gone (a real file lands in `zsh-backup-*-p10k/`); a second
run reports nothing to clean.

Clean up with `rm -rf /tmp/zsh-test-home`.
