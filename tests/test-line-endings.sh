#!/usr/bin/env bash
# Every Bash script must be pinned to LF line endings.
#
# Windows machines here run with core.autocrlf=true. Without a .gitattributes
# rule, Git rewrites LF to CRLF on checkout and the script then dies on its own
# `set -euo pipefail` line under WSL's bash:
#
#     : invalid option name line 42: set: pipefail
#
# That broke bin/ai-adopt-globals on t16 on 2026-08-27 while the committed file
# was perfectly correct. This suite fails if a shell script ever loses its LF
# pin, or if a CRLF script is committed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

if [ ! -f .gitattributes ]; then
  bad ".gitattributes exists (without it every Windows checkout corrupts the scripts)"
  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi
ok ".gitattributes exists"

# Collect every tracked file the shell has to execute: an explicit .sh suffix,
# or a bash/sh shebang on an extensionless file.
shell_files=()
while IFS= read -r f; do
  case "$f" in
    *.sh) shell_files+=("$f"); continue ;;
    *.ps1|*.cmd|*.bat|*.md|*.json|*.tsv|*.py|*.yml|*.yaml|*.txt) continue ;;
  esac
  [ -f "$f" ] || continue
  case "$(head -c 60 "$f" 2>/dev/null | head -n 1)" in
    '#!'*bash*|'#!'*/sh|'#!'*"env sh") shell_files+=("$f") ;;
  esac
done < <(git ls-files '*.sh' 'bin/*' 'tests/*' 'tools/*' 'mcp/*')

if [ "${#shell_files[@]}" -eq 0 ]; then
  bad "found at least one shell script to check"
  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi
ok "found ${#shell_files[@]} shell scripts to check"

# 1. Every one of them must resolve to eol=lf.
unpinned=()
while IFS= read -r line; do
  case "$line" in
    *": eol: lf") : ;;
    *) unpinned+=("${line%%: eol:*}") ;;
  esac
done < <(printf '%s\n' "${shell_files[@]}" | git check-attr --stdin eol)

if [ "${#unpinned[@]}" -eq 0 ]; then
  ok "every shell script resolves to eol=lf"
else
  bad "every shell script resolves to eol=lf — not pinned: ${unpinned[*]}"
fi

# 2. Nothing committed may already carry CRLF, which a rule alone cannot undo.
# 2. Nothing may be COMMITTED with CRLF, which an attribute alone cannot undo,
#    and no checkout may be left with CRLF, which is what actually breaks the
#    shell. `git ls-files --eol` reports both in one pass; `git grep` is NOT
#    usable here because it re-applies the checkout conversion.
committed_crlf=()
checkout_crlf=()
while IFS= read -r line; do
  case "$line" in
    "i/lf"*)   : ;;
    *)         committed_crlf+=("${line##*$'	'}") ;;
  esac
  case "$line" in
    *"w/crlf"*|*"w/mixed"*) checkout_crlf+=("${line##*$'	'}") ;;
  esac
done < <(git ls-files --eol -- "${shell_files[@]}")

if [ "${#committed_crlf[@]}" -eq 0 ]; then
  ok "no shell script is committed with CRLF"
else
  bad "no shell script is committed with CRLF — offenders: ${committed_crlf[*]}"
fi

if [ "${#checkout_crlf[@]}" -eq 0 ]; then
  ok "this checkout has the scripts as LF"
else
  bad "this checkout has the scripts as LF — ${#checkout_crlf[@]} file(s) are CRLF here and will fail under WSL bash."
  printf '       This checkout predates .gitattributes. Repair it with:
'
  printf '         git rm --cached -r -q . && git reset --hard
'
  printf '       (commit or stash your own work first — that command discards uncommitted changes)
'
fi

# 3. Windows-native scripts keep CRLF; the bin/** rule must not capture them.
ps1_wrong=()
while IFS= read -r line; do
  case "$line" in
    *": eol: crlf") : ;;
    *) ps1_wrong+=("${line%%: eol:*}") ;;
  esac
done < <(git ls-files '*.ps1' '*.cmd' '*.bat' | git check-attr --stdin eol)
if [ "${#ps1_wrong[@]}" -eq 0 ]; then
  ok "PowerShell, .cmd and .bat files stay pinned to CRLF"
else
  bad "PowerShell, .cmd and .bat files stay pinned to CRLF — wrong: ${ps1_wrong[*]}"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
