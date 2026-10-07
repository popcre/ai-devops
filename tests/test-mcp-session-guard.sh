#!/usr/bin/env bash
# tests/test-mcp-session-guard.sh — the MCP helper must die with its session.
#
# Regression for the edge-dev3 OOM (2026-09-28): leaked npx/node MCP helpers
# piled up after sessions ended. Three release paths must reap the helper tree:
# client stdin EOF, parent death, and normal child exit.
#
# A small Node "session" client owns the guard's stdin pipe (the way Claude
# does), so the tests are honest on Windows too — MSYS FIFOs are not visible
# to native Node as live fds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/bin/mcp-session-guard.mjs"
NODE="${MCP_SESSION_GUARD_NODE:-node}"
TMP="$(mktemp -d)"
CHECKS_PASSED=0

# Kill every helper this script started, then clean TMP. Never override the
# script's own exit status: a leftover helper or a busy TMP must not turn a
# green run red (the CI "Killed" flake).
cleanup() {
  local rc=$?
  set +e
  for f in "$TMP"/pid*; do
    [ -f "$f" ] || continue
    local pid
    pid="$(cat "$f" 2>/dev/null || true)"
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    [ -f "$f.kid" ] || continue
    pid="$(cat "$f.kid" 2>/dev/null || true)"
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
  done
  rm -rf "$TMP"
  exit "$rc"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "  ok $*"; CHECKS_PASSED=$((CHECKS_PASSED + 1)); }

command -v "$NODE" >/dev/null 2>&1 || fail "node is required"
[ -f "$GUARD" ] || fail "missing $GUARD"

# Stand-in for an MCP server: records its pid tree and sleeps.
# The grandchild hold is short-lived on purpose: it only needs to outlive the
# reap assertions (~3 s), not a minute. A 60 s Node timer made each case four
# live Node processes and was an OOM risk on shared CI runners.
cat > "$TMP/hold.js" <<'EOF'
const fs = require('fs')
fs.writeFileSync(process.argv[2], String(process.pid))
const { spawn } = require('child_process')
const kid = spawn(process.execPath, ['-e', 'setTimeout(()=>{}, 15000)'], { stdio: 'ignore' })
fs.writeFileSync(process.argv[2] + '.kid', String(kid.pid))
setTimeout(() => {}, 15000)
EOF

# Session client: like Claude, owns the helper's stdin and can close it.
cat > "$TMP/session.js" <<'EOF'
// usage: session.js <guard.mjs> <pidfile> <mode> <command> [args...]
//   mode=hold — keep stdin open; mode=eof — wait for the test's explicit close.
const { spawn } = require('child_process')
const fs = require('fs')
const [guard, pidfile, mode, command, ...rest] = process.argv.slice(2)

const child = spawn(process.execPath, [guard, command, ...rest], {
  stdio: ['pipe', 'inherit', 'inherit'],
})
child.stdin.write('')
const ready = setInterval(() => {
  if (fs.existsSync(pidfile) && fs.statSync(pidfile).size > 0) {
    clearInterval(ready)
    process.stdout.write('READY\n')
    if (mode === 'eof') {
      const close = setInterval(() => {
        if (!fs.existsSync(pidfile + '.close')) return
        clearInterval(close)
        child.stdin.end(() => fs.writeFileSync(pidfile + '.eof', 'closed'))
      }, 50)
    }
  }
}, 50)
child.on('exit', (code) => process.exit(code ?? 0))
EOF

alive() {
  # Node's process.kill(pid, 0) is reliable for native Windows PIDs; Git Bash
  # kill -0 is not (it can miss live node.exe processes).
  "$NODE" -e "try{process.kill(Number(process.argv[1]),0);process.exit(0)}catch{process.exit(1)}" "$1" 2>/dev/null
}

wait_reaped() {
  # Observe both native PIDs in one process. The six-second upper bound
  # covers the guard's 250ms EOF grace, 2s force fallback and Windows
  # taskkill startup, while staying below the fixture's 15s natural exit.
  "$NODE" -e '
    const pids = process.argv.slice(1).map(Number)
    if (!pids.length || pids.some(p => !Number.isInteger(p) || p <= 0)) process.exit(2)
    const deadline = Date.now() + 6000
    const check = () => {
      const live = pids.some(pid => { try { process.kill(pid, 0); return true } catch { return false } })
      if (!live) process.exit(0)
      if (Date.now() >= deadline) process.exit(1)
      setTimeout(check, 50)
    }
    check()
  ' "$@" 2>/dev/null
}

wait_ready() {
  # 30s budget: GitHub-hosted Windows can spend several seconds just starting
  # node.exe (Defender / cold PATH). 5s made "helper did not start" a flake.
  local f="$1" i
  for i in $(seq 1 300); do
    [ -s "$f" ] && return 0
    sleep 0.1
  done
  return 1
}

# Wait for a background session we intentionally SIGKILLed. Bash prints a
# "Killed" job-status line when it reaps a SIGKILLed job; that is the expected
# outcome here, not a suite failure. Assert the status so a host/OOM kill
# cannot masquerade as a silent pass, and so the line is explained.
wait_sigkill() {
  local pid="$1" rc
  set +e
  wait "$pid" 2>/dev/null
  rc=$?
  set -e
  # 137 = 128 + SIGKILL(9). Any other status means the process died another way.
  [ "$rc" -eq 137 ] || fail "expected SIGKILL (137) for session $pid, got $rc"
}

echo "== mcp-session-guard"

# --- 1. stdin EOF reaps the helper tree ---------------------------------
rm -f "$TMP/pid1" "$TMP/pid1.kid"
"$NODE" "$TMP/session.js" "$GUARD" "$TMP/pid1" eof "$NODE" "$TMP/hold.js" "$TMP/pid1" \
  >"$TMP/out1" 2>"$TMP/err1" &
SESSION=$!
wait_ready "$TMP/pid1" || fail "helper did not start (stdin-eof case): $(cat "$TMP/err1" 2>/dev/null)"
wait_ready "$TMP/pid1.kid" || fail "grandchild did not start (stdin-eof case)"
HELPER_PID="$(cat "$TMP/pid1")"
KID_PID="$(cat "$TMP/pid1.kid" 2>/dev/null || true)"
alive "$HELPER_PID" || fail "helper not alive before stdin close"
alive "$KID_PID" || fail "grandchild not alive before stdin close"
printf 'close\n' > "$TMP/pid1.close"
wait_ready "$TMP/pid1.eof" || fail "session did not close stdin (stdin-eof case)"
wait_reaped "$HELPER_PID" "$KID_PID" || fail "helper tree still alive after stdin EOF (helper $HELPER_PID; grandchild $KID_PID)"
wait "$SESSION" 2>/dev/null || true
ok "stdin_eof_kills_helper_and_grandchild"

# --- 2. session SIGKILL (Claude OOM) reaps the helper tree -------------
# Killing the session closes its stdin write end — the same event an OOM
# SIGKILL produces. The guard must reap npx/node grandchildren too.
rm -f "$TMP/pid2" "$TMP/pid2.kid"
"$NODE" "$TMP/session.js" "$GUARD" "$TMP/pid2" hold "$NODE" "$TMP/hold.js" "$TMP/pid2" \
  >"$TMP/out2" 2>"$TMP/err2" &
SESSION=$!
wait_ready "$TMP/pid2" || fail "helper did not start (session-kill case): $(cat "$TMP/err2" 2>/dev/null)"
wait_ready "$TMP/pid2.kid" || fail "grandchild did not start (session-kill case)"
HELPER_PID="$(cat "$TMP/pid2")"
KID_PID="$(cat "$TMP/pid2.kid" 2>/dev/null || true)"
alive "$HELPER_PID" || fail "helper not alive before session SIGKILL"
alive "$KID_PID" || fail "grandchild not alive before session SIGKILL"
kill -9 "$SESSION" 2>/dev/null || true
wait_sigkill "$SESSION"
wait_reaped "$HELPER_PID" "$KID_PID" || fail "helper tree still alive after session SIGKILL (helper $HELPER_PID; grandchild $KID_PID)"
ok "session_sigkill_reaps_helper_tree"

# --- 3. normal child exit is forwarded ---------------------------------
set +e
"$NODE" "$GUARD" "$NODE" -e "process.exit(7)" </dev/null >"$TMP/out3" 2>"$TMP/err3"
RC=$?
set -e
[ "$RC" -eq 7 ] || fail "guard did not forward child exit code (got $RC)"
ok "child_exit_code_forwarded"

# --- 4. Windows .cmd shims must start (H1: spawn cannot run batch files) ---
# Drive it through session.js so stdin is a live pipe (CI's inherited stdin is
# already EOF and would reap the helper before the assertion).
if [ "$OSTYPE" = "msys" ] || [ "$OSTYPE" = "cygwin" ] || [ -n "${WINDIR:-}" ]; then
  TMP_WIN="$(cygpath -w "$TMP" 2>/dev/null || echo "$TMP")"
  NODE_WIN="$(cygpath -w "$(command -v "$NODE")" 2>/dev/null || echo "$NODE")"
  cat > "$TMP/hold.cmd" <<EOF
@echo off
"$NODE_WIN" "$TMP_WIN\\hold.js" "$TMP_WIN\\pidcmd"
EOF
  rm -f "$TMP/pidcmd" "$TMP/pidcmd.kid"
  HOLD_CMD_WIN="$(cygpath -w "$TMP/hold.cmd")"
  # session.js expects (guard, hold.js-or-cmd, pidfile, mode). Pass the .cmd as
  # the "hold" command; the guard wraps it in cmd /c.
  "$NODE" "$TMP/session.js" "$GUARD" "$TMP/pidcmd" eof "$HOLD_CMD_WIN" \
    >"$TMP/outcmd" 2>"$TMP/errcmd" &
  GUARD_CMD=$!
  wait_ready "$TMP/pidcmd" || fail "helper did not start via .cmd shim: $(cat "$TMP/errcmd" 2>/dev/null)"
  wait_ready "$TMP/pidcmd.kid" || fail "grandchild did not start via .cmd shim"
  HELPER_PID="$(cat "$TMP/pidcmd")"
  KID_PID="$(cat "$TMP/pidcmd.kid")"
  alive "$HELPER_PID" || fail "cmd shim helper not alive (pid $HELPER_PID; err=$(cat "$TMP/errcmd" 2>/dev/null))"
  printf 'close\n' > "$TMP/pidcmd.close"
  wait_ready "$TMP/pidcmd.eof" || fail "session did not close stdin (.cmd shim case)"
  wait_reaped "$HELPER_PID" "$KID_PID" || fail "cmd shim helper tree leaked after stdin EOF (helper $HELPER_PID; grandchild $KID_PID)"
  wait "$GUARD_CMD" 2>/dev/null || true
  ok "windows_cmd_shim_starts_and_reaps"
else
  ok "windows_cmd_shim_starts_and_reaps (skipped, not Windows)"
fi

# --- 5. usage ----------------------------------------------------------
set +e
"$NODE" "$GUARD" </dev/null >"$TMP/out4" 2>"$TMP/err4"
RC=$?
set -e
[ "$RC" -eq 2 ] || fail "empty command should exit 2 (got $RC)"
ok "empty_command_is_usage_error"

echo "PASS: mcp-session-guard checks=$CHECKS_PASSED"
