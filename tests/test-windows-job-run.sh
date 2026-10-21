#!/usr/bin/env bash
# Behavioral tests for bin/windows-job-run.ps1 against real processes
# (popcre/ai-devops#1891): ending the launcher must kill every descendant,
# including native processes started through Git Bash. Windows only.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
echo '== windows-job-run'
if [ -z "${SYSTEMROOT:-}" ] || ! command -v cygpath >/dev/null 2>&1; then
  echo '  skip (not Windows)'; echo "$PASS passed, $FAIL failed"; exit 0
fi
ps_q(){ powershell.exe -NoProfile -NonInteractive -Command "$1" | tr -d '\r'; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
N="$(( 400 + RANDOM % 500 ))"   # unique ping counts identify this run's processes
count(){ ps_q "@(Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match 'ping\\s+-n\\s+($N|$((N+1)))\\s' }).Count"; }
cat > "$TMP/run.sh" <<EOF
timeout 300 ping -n $N 127.0.0.1 >/dev/null &
cmd //c "start /b ping -n $((N+1)) 127.0.0.1 >nul & ping -n $((N+1)) 127.0.0.1 >nul" &
echo ready > "$TMP/ready"; wait
EOF
cat > "$TMP/ok.sh" <<'EOF'
exit 7
EOF
LAUNCH="$(cygpath -w "$REPO_ROOT/bin/windows-job-run.ps1")"; BASH_W="$(cygpath -w "$(command -v bash)")"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$LAUNCH" -Bash "$BASH_W" -Script "$(cygpath -w "$TMP/ok.sh")"; RC=$?
check "launcher_returns_the_script_exit_code" "[ '$RC' = 7 ]"

LPID="$(ps_q "(Start-Process -PassThru -WindowStyle Hidden powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"$LAUNCH\"','-Bash','\"$BASH_W\"','-Script','\"$(cygpath -w "$TMP/run.sh")\"').Id")"
for _ in $(seq 60); do [ -e "$TMP/ready" ] && break; sleep .5; done; sleep 2
BEFORE="$(count)"
check "fixture_starts_native_grandchildren_through_bash" "[ '$BEFORE' -ge 3 ]"
ps_q "Stop-Process -Id $LPID -Force" >/dev/null; sleep 2
check "killing_the_launcher_kills_every_descendant" "[ \"\$(count)\" = 0 ]"
ps_q "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match 'ping\\s+-n\\s+($N|$((N+1)))\\s' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" >/dev/null
echo "$PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
