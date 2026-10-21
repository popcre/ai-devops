#!/usr/bin/env bash
# Behavioral tests for bin/windows-kill-process-tree.ps1 against real native
# processes (popcre/ai-devops#1891). Windows only; skipped elsewhere.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
echo '== windows-kill-process-tree'
if [ -z "${SYSTEMROOT:-}" ] || ! command -v cygpath >/dev/null 2>&1; then
  echo '  skip (not Windows)'; echo "$PASS passed, $FAIL failed"; exit 0
fi
HELPER="$(cygpath -w "$REPO_ROOT/bin/windows-kill-process-tree.ps1")"
kill_tree(){ AI_REVIEW_KILL_MARKER="$1" powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$HELPER" | tr -d '\r'; }
ps_q(){ powershell.exe -NoProfile -NonInteractive -Command "$1" | tr -d '\r'; }
MARK="C:\\ai-review-test-marker-$$-$RANDOM"
# A native root whose command line carries the marker, a cmd child and a ping
# grandchild (native parent links), like codex.exe and its sandboxed commands.
ROOT="$(ps_q "(Start-Process -PassThru -WindowStyle Hidden cmd.exe -ArgumentList '/c', 'cmd /c ping -n 120 127.0.0.1 >nul & rem $MARK').Id")"
BYSTANDER="$(ps_q "(Start-Process -PassThru -WindowStyle Hidden ping.exe -ArgumentList '-n', '120', '127.0.0.1').Id")"
sleep 2
tree_ids(){ ps_q "\$all = Get-CimInstance Win32_Process; \$t = @($ROOT); \$i = 0; while (\$i -lt \$t.Count) { \$t += @(\$all | ? { \$_.ParentProcessId -eq \$t[\$i] } | % { \$_.ProcessId }); \$i++ }; \$t -join ','"; }
IDS="$(tree_ids)"
alive_any(){ [ -n "$(ps_q "Get-Process -Id $1 -ErrorAction SilentlyContinue | % { \$_.Id }")" ]; }

check "fixture_builds_a_three_level_native_tree" "[ \"\$(printf '%s' '$IDS' | tr ',' '\n' | wc -l)\" -ge 3 ]"
check "short_marker_is_refused" "[ \"\$(kill_tree C:\\\\x)\" = alive ] && alive_any $ROOT"
check "unmatched_marker_kills_nothing" "[ \"\$(kill_tree 'C:\\no-such-review-marker-xyz')\" = yes ] && alive_any $ROOT && alive_any $BYSTANDER"
check "whole_tree_is_killed_and_proven_gone" "[ \"\$(kill_tree '$MARK')\" = yes ] && ! alive_any '$IDS'"
check "unrelated_process_survives_a_tree_kill" "alive_any $BYSTANDER"
ps_q "Stop-Process -Id $BYSTANDER -Force -ErrorAction SilentlyContinue; Get-CimInstance Win32_Process | ? { \$_.CommandLine -like '*$MARK*' } | % { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" >/dev/null
echo "$PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
