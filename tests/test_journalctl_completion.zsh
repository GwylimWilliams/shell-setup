#!/usr/bin/env zsh
#
# test_journalctl_completion.zsh
# Verify the _journalctl completion override (dot-files/completions/_journalctl)
# routes -u/--unit in --user mode through `systemctl --user list-unit-files`
# (which includes quadlet-generated services) instead of the stock
# `journalctl --user -F _SYSTEMD_UNIT` (journal field values).
#
# Deterministic — no PTY. Exercises the exact shipped logic:
#   1. Delegation: when _journalctl autoloads from the repo completions dir it
#      must skip its own file and source the system one (no self-recursion).
#   2. Helper branch: for -u (field=_SYSTEMD_UNIT) with --user set, the helper
#      must take the systemctl branch (not the stock journal-field branch);
#      --user-unit (USER_UNIT) likewise; plain -u and -p must keep stock.
#
# Usage:
#   zsh tests/test_journalctl_completion.zsh [repo-path]

local repo=${1:-${${(%):-%x}:A:h}/..}
local comp="$repo/dot-files/completions/_journalctl"
local passes=0 fails=0
local okc=$'\e[32m' failc=$'\e[31m' endc=$'\e[0m'

ok()   { print -r -- "  ${okc}ok${endc}  $1"; (( passes++ )); }
fail() { print -r -- "  ${failc}FAIL${endc} $1"; (( fails++ )); }

[[ -f $comp ]] || { print -u2 "no override file: $comp"; exit 2; }

# ── 1. Delegation / no recursion ─────────────────────────────────────────
# fake fpath: repo completions dir (our _journalctl) then a "system" dir whose
# _journalctl is a marker that echoes when sourced.
local fake=$(mktemp -d)
mkdir -p $fake/repo $fake/system
cp "$comp" $fake/repo/_journalctl
cat > $fake/system/_journalctl <<'EOF'
echo "SYSTEM_JOURNALCTL_SOURCED"
EOF

(
  fpath=($fake/repo $fake/system)
  autoload -Uz compinit && compinit -u -d $fake/dump 2>/dev/null
  autoload +X _journalctl 2>/dev/null
  _journalctl > $fake/out.txt 2>&1
)

local got=$(<$fake/out.txt)
if [[ $got == SYSTEM_JOURNALCTL_SOURCED ]]; then
  ok "delegates to system _journalctl (no self-recursion)"
else
  fail "delegation: got '$got' (expected SYSTEM_JOURNALCTL_SOURCED)"
fi

# ── 2. Helper branch selection ───────────────────────────────────────────
# Stub _describe/_call_program so we can observe which branch runs, then source
# the real helper definition out of the shipped override.
_describe()     { print -r -- "DESCRIBE tag=$1 entries=${(j:,:)@[2,-1]}"; }
_call_program() { print -r -- "CALL_PROGRAM tag=$1 cmd=${(j: :)@[2,-1]}"; }
_message()      { print -r -- "MESSAGE: $*"; }

local helper_body=/tmp/jc_helper_body.$$
sed -n '/^(( \$+functions\[_journalctl_field_values\] ))/,/^}/p' "$comp" > $helper_body
source $helper_body
rm -f $helper_body

local -a _sys_service_mgr
local out

# 2a. --user -u (field=_SYSTEMD_UNIT) → systemctl branch
_sys_service_mgr=(--user)
out=$(_journalctl_field_values _SYSTEMD_UNIT)
if [[ $out == *'DESCRIBE tag=units'* ]]; then
  ok "--user -u: systemctl branch (list-unit-files)"
elif [[ $out == *CALL_PROGRAM* ]]; then
  fail "--user -u: fell back to stock journalctl -F (systemctl returned no units here)"
else
  fail "--user -u: unexpected output: $out"
fi

# 2b. --user --user-unit= (field=USER_UNIT) → systemctl branch
_sys_service_mgr=(--user)
out=$(_journalctl_field_values USER_UNIT)
if [[ $out == *'DESCRIBE tag=units'* ]]; then
  ok "--user-unit: systemctl branch"
else
  fail "--user-unit: got: $out"
fi

# 2c. -u without --user (field=_SYSTEMD_UNIT, mgr empty) → stock branch
# The stock branch calls `_describe 'possible values' _fields`; the stub's
# _call_program output is captured into _fields, so we key on the tag.
_sys_service_mgr=()
out=$(_journalctl_field_values _SYSTEMD_UNIT)
if [[ $out == *'DESCRIBE tag=possible values'* ]]; then
  ok "-u (no --user): stock journalctl -F path kept"
else
  fail "-u (no --user): got: $out"
fi

# 2d. -p priority (field=PRIORITY) → stock branch
_sys_service_mgr=()
out=$(_journalctl_field_values PRIORITY)
if [[ $out == *'DESCRIBE tag=possible values'* ]]; then
  ok "-p (PRIORITY): stock path kept"
else
  fail "-p (PRIORITY): got: $out"
fi

rm -rf $fake

# ── 3. _systemctl override ────────────────────────────────────────────────
# The same delegation pattern must apply, and the fixed restartable-units
# filter must include `generated` (quadlet) units.

local sysctl_comp="$repo/dot-files/completions/_systemctl"
if [[ -f $sysctl_comp ]]; then
  # 3a. Delegation: our _systemctl skips itself and sources the system one.
  local fake2=$(mktemp -d)
  mkdir -p $fake2/repo $fake2/system
  cp "$sysctl_comp" $fake2/repo/_systemctl
  cat > $fake2/system/_systemctl <<'EOF'
echo "SYSTEM_SYSTEMCTL_SOURCED"
EOF
  (
    fpath=($fake2/repo $fake2/system)
    autoload -Uz compinit && compinit -u -d $fake2/dump 2>/dev/null
    autoload +X _systemctl 2>/dev/null
    _systemctl > $fake2/out.txt 2>&1
  )
  got=$(<$fake2/out.txt)
  if [[ $got == SYSTEM_SYSTEMCTL_SOURCED ]]; then
    ok "_systemctl: delegates to system completion (no self-recursion)"
  else
    fail "_systemctl: delegation got '$got'"
  fi

  # 3b. The override file defines _systemctl_restartable_units with a state
  # filter that includes `generated` (quadlet units). Extract that block from
  # the shipped file and check it.
  local restblk=$(sed -n '/_systemctl_restartable_units()/,/^}/p' "$sysctl_comp")
  if [[ $restblk == *'generated'* && $restblk == *'list-unit-files'* ]]; then
    ok "_systemctl: restartable filter includes generated (quadlet) units"
  else
    fail "_systemctl: restartable filter missing 'generated'"
  fi
  rm -rf $fake2
else
  fail "_systemctl: no override file found ($sysctl_comp)"
fi

print
print -r -- "PASSED: $passes  FAILED: $fails"
(( fails == 0 ))
