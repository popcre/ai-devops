#!/usr/bin/env bash
# Guards for the class of bugs that only ever appear on a Windows machine, where we
# cannot see them until a setup run fails in front of Albert.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

cd "$REPO_ROOT"

echo "== PowerShell files must be pure ASCII =="
# Windows PowerShell 5.1 reads a BOM-less .ps1 as Windows-1252. A UTF-8 em dash
# (E2 80 94) then decodes to a smart RIGHT DOUBLE QUOTATION MARK, which PowerShell
# accepts as a string delimiter. That silently corrupts quote state for the rest of
# the file: on 2026-08-04 two em dashes in install-ai-devops-windows.ps1 produced
# "The string is missing the terminator" and aborted setup on all three Windows
# machines. Keep every repo-owned .ps1 ASCII-only.
dirty=0
while IFS= read -r f; do
  case "$f" in claude_chats/*) continue ;; esac
  if LC_ALL=C grep -qP '[^\x00-\x7F]' "$f" 2>/dev/null; then
    bad "non-ASCII in $f"; LC_ALL=C grep -nP '[^\x00-\x7F]' "$f" | head -3 | sed 's/^/       /'
    dirty=1
  fi
done < <(git ls-files '*.ps1')
[ "$dirty" -eq 0 ] && ok "no non-ASCII in any repo .ps1"

echo "== checked-out paths must fit Windows =="
# Windows fails a checkout outright at ~260 characters unless long paths are enabled.
# claude_chats/ reached 411 and aborted the clone on 4837, leaving a half-written repo
# and a setup run that then died on a missing config file.
longest=$(git ls-files | awk '{print length}' | sort -rn | head -1)
if [ "${longest:-0}" -lt 200 ]; then ok "longest tracked path is $longest chars"
else bad "longest tracked path is $longest chars (Windows checkout risk)"; fi
if git ls-files claude_chats | grep -q .; then bad "claude_chats/ is tracked again"; else ok "claude_chats/ is not tracked"; fi

echo "== setup must not clone a second copy of itself =="
if grep -q 'PSCommandPath' bin/setup-machine.ps1; then ok "setup-machine.ps1 defaults to its own checkout"
else bad "setup-machine.ps1 does not derive RepoPath from its own location"; fi

echo "== Windows paths must not trust Git Bash \$HOME =="
if grep -q 'export HOME=' bin/setup-opencode-glm.ps1; then ok "GLM launcher pins HOME to the Windows profile"
else bad "GLM launcher relies on Git Bash \$HOME"; fi
if grep -q 'set "HOME=' bin/setup-opencode-glm.ps1; then ok "ai-glm shim pins HOME"
else bad "ai-glm shim does not pin HOME"; fi

echo "== a failed GLM launcher must show its error =="
if grep -q 'Smoke-testing the launcher' bin/setup-opencode-glm.ps1; then ok "launcher is smoke-tested before the task is registered"
else bad "no launcher smoke test; failures would be silent"; fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
