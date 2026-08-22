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
for f in bin/setup-machine.ps1 bin/setup-opencode-glm.ps1; do
  if grep -q 'PSCommandPath' "$f"; then ok "$(basename "$f") defaults to its own checkout"
  else bad "$(basename "$f") does not derive RepoPath from its own location"; fi
done
# The full restore contract deliberately owns C:\repos\ai-devops. No other
# component may invent a drive-letter default.
drive_defaults="$(grep -nE '\$RepoPath\s*=.*"[A-Za-z]:' bin/*.ps1 || true)"
unexpected_defaults="$(printf '%s\n' "$drive_defaults" | grep -vF 'bin/setup-machine.ps1:123:    $RepoPath = "C:\repos\ai-devops"' || true)"
if [ -n "$unexpected_defaults" ]; then
  bad "unexpected hardcoded drive-letter RepoPath default"; printf '%s\n' "$unexpected_defaults" | sed 's/^/       /'
else ok "only the canonical C:\\repos\\ai-devops fallback is hardcoded"; fi

echo "== Windows paths must not trust Git Bash \$HOME =="
if grep -q 'export HOME=' bin/setup-opencode-glm.ps1; then ok "GLM launcher pins HOME to the Windows profile"
else bad "GLM launcher relies on Git Bash \$HOME"; fi
if grep -q 'set "HOME=' bin/setup-opencode-glm.ps1; then ok "ai-glm shim pins HOME"
else bad "ai-glm shim does not pin HOME"; fi

echo "== MCP remote bridge version must be pinned =="
if grep -q 'mcp-remote@0\.1\.38' bin/mcp-secret-launch.ps1 \
  && grep -q 'mcp-remote@0\.1\.38' bin/setup-machine.ps1 \
  && grep -q 'mcp-remote@0\.1\.38' bin/setup-secrets.sh \
  && ! grep -q 'mcp-remote@latest' bin/mcp-secret-launch.ps1 bin/setup-machine.ps1 bin/setup-secrets.sh; then
  ok "mcp-remote is pinned to 0.1.38 in generated launch paths"
else
  bad "mcp-remote launch paths are unpinned or disagree"
fi

echo "== a failed GLM launcher must show its error =="
if grep -q 'Smoke-testing the launcher' bin/setup-opencode-glm.ps1; then ok "launcher is smoke-tested before the task is registered"
else bad "no launcher smoke test; failures would be silent"; fi

echo "== the generated Windows launcher must be valid bash =="
# It is written from a PowerShell here-string, so a quoting slip yields a broken shell
# script that only fails on Windows. Render it and check it here instead.
PYTHON=python3
if ! "$PYTHON" -c 'import sys' >/dev/null 2>&1; then PYTHON=python; fi
if rendered="$("$PYTHON" tests/render-windows-launcher.py 2>&1)"; then
  if printf '%s' "$rendered" | bash -n 2>/dev/null; then ok "rendered launcher is valid bash"
  else bad "rendered launcher is not valid bash"; fi
  # op.exe is a native Windows process and cannot exec an extension-less shell script.
  if printf '%s' "$rendered" | grep -q 'exec op run .* -- "C:/Program Files/Git/bin/bash.exe" "$0"'; then
    ok "op run re-execs through bash.exe by absolute path"
  else bad "op run re-exec does not name bash.exe (Windows cannot exec the script directly)"; fi
  if printf '%s' "$rendered" | grep -q 'export HOME='; then ok "launcher pins HOME"; else bad "launcher does not pin HOME"; fi
else
  bad "could not render the launcher: $rendered"
fi

# `\$` is never a valid escape inside a PowerShell here-string: PowerShell expands the
# variable anyway and leaves a stray backslash. Caught twice by hand; now checked.
if grep -nE '\\\$(HOME|\()' bin/*.ps1 >/dev/null 2>&1; then
  bad "backslash-dollar in a .ps1 here-string (use a backtick)"; grep -nE '\\\$(HOME|\()' bin/*.ps1 | sed 's/^/       /'
else ok "no invalid backslash-dollar escapes in .ps1 files"; fi

# The scheduled task must log somewhere, or a failure under Task Scheduler is invisible.
if grep -q 'opencode-glm-service' bin/setup-opencode-glm.ps1 && grep -q 'server.log' bin/setup-opencode-glm.ps1; then
  ok "scheduled task writes a server log"
else bad "scheduled task output is discarded"; fi
if grep -q 'Wait-PortFree' bin/setup-opencode-glm.ps1; then ok "waits for the port before starting the task"
else bad "no port wait; the smoke test can block the real server"; fi
if grep -q "ProcessName -notmatch 'opencode'" bin/ai-glm; then ok "restart verifies the old listener before stopping it"
else bad "restart may stop an unrelated listener"; fi
if grep -q 'stayed busy for 30 seconds' bin/ai-glm; then ok "restart has a bounded port-free wait"
else bad "restart can race the old listener"; fi

echo "== GLM task recovery policy =="
if grep -q 'max_attempts=4' bin/setup-opencode-glm.ps1 && grep -q 'sleep 60' bin/setup-opencode-glm.ps1; then
  ok "wrapper has bounded three-at-one-minute recovery"
else bad "wrapper recovery count or interval changed"; fi
if grep -q 'New-ScheduledTaskTrigger -AtLogOn' bin/setup-opencode-glm.ps1; then ok "task starts at logon"
else bad "task no longer starts at logon"; fi
if grep -q 'wc -c' bin/setup-opencode-glm.ps1 && grep -q '"`$log.1"' bin/setup-opencode-glm.ps1; then
  ok "service wrapper rotates its log"
else bad "service wrapper does not rotate its log"; fi
if grep -q 'bounded recovery exhausted' bin/setup-opencode-glm.ps1 && ! grep -q 'exec "\$launchBash"' bin/setup-opencode-glm.ps1; then
  ok "service wrapper normalizes child failure"
else bad "service wrapper does not return a restartable failure"; fi
if grep -q 'service wrapper retries 3 times at 1 minute' bin/ai-glm; then ok "doctor verifies the recovery policy"
else bad "doctor does not verify the recovery policy"; fi

echo "== portable Codex defaults =="
if grep -q 'codex-portable.toml' bin/setup-machine.ps1 && grep -q -- '-not (Test-Path -LiteralPath $codexConfigPath)' bin/setup-machine.ps1; then
  ok "setup seeds Codex defaults only when config is absent"
else bad "Codex defaults may overwrite an established config"; fi
if grep -q 'model_reasoning_effort = "low"' config/codex-portable.toml &&
   ! grep -q '^model = ' config/codex-portable.toml; then
  ok "portable Codex defaults pin safe effort without hard-coding a model"
else bad "portable Codex defaults are unsafe or model-pinned"; fi

echo "== complete MCP set is managed for both clients =="
if grep -q '\$McpServers\["chrome-devtools"\]' bin/setup-machine.ps1; then
  ok "Claude MCP set includes Chrome DevTools"
else bad "Claude MCP set does not include Chrome DevTools"; fi
if grep -q 'configure-codex-mcps.ps1' bin/setup-machine.ps1 &&
   grep -q '\$CodexMcpServers' bin/setup-machine.ps1; then
  ok "Windows setup configures the complete MCP set for Codex"
else bad "Windows setup leaves the Codex MCP set incomplete"; fi
if grep -Fq "\$CodexMcpServers['railway']" bin/setup-machine.ps1 &&
   grep -Fq 'https://mcp.railway.com' bin/setup-machine.ps1 &&
   grep -Fq '@railway/cli@latest' bin/reconcile-windows-package-exceptions.ps1; then
  ok "Windows setup installs Railway CLI and configures Railway MCP for Codex"
else bad "Windows setup does not fully manage Railway"; fi
for server in ag-grid playwright codex-cli synology-monitor devops-mcp railway trigger recall-ai 1password supabase; do
  if grep -Fq "\$McpServers[\"$server\"]" bin/setup-machine.ps1; then
    ok "shared MCP set includes $server"
  else
    bad "shared MCP set is missing $server"
  fi
done
if ! grep -Fq '$McpServers["vercel"]' bin/setup-machine.ps1 &&
   grep -Fq "\$CodexMcpServers['vercel']" bin/setup-machine.ps1; then
  ok "Vercel is Codex-only and cannot trigger Claude browser-auth loops"
else
  bad "Vercel must be absent from Claude and native in Codex"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
