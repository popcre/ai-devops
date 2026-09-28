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
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "  ok $*"; }

command -v "$NODE" >/dev/null 2>&1 || fail "node is required"
[ -f "$GUARD" ] || fail "missing $GUARD"

# Stand-in for an MCP server: records its pid tree and sleeps.
cat > "$TMP/hold.js" <<'EOF'
const fs = require('fs')
fs.writeFileSync(process.argv[2], String(process.pid))
const { spawn } = require('child_process')
const kid = spawn(process.execPath, ['-e', 'setTimeout(()=>{}, 60000)'], { stdio: 'ignore' })
fs.writeFileSync(process.argv[2] + '.kid', String(kid.pid))
setInterval(() => {}, 1000)
EOF

# Session client: like Claude, owns the helper's stdin and can close it.
cat > "$TMP/session.js" <<'EOF'
// usage: session.js <guard.mjs> <hold.js> <pidfile> <mode>
//   mode=hold     — start helper, keep stdin open forever (write READY)
//   mode=eof      — start helper, keep stdin open until READY, then end stdin
//   mode=kill     — start helper under a child we will not signal (parent death)
const { spawn } = require('child_process')
const fs = require('fs')
const [guard, hold, pidfile, mode] = process.argv.slice(2)

const child = spawn(process.execPath, [guard, process.execPath, hold, pidfile], {
  stdio: ['pipe', 'inherit', 'inherit'],
})
child.stdin.write('') // ensure the pipe exists
const ready = setInterval(() => {
  if (fs.existsSync(pidfile) && fs.statSync(pidfile).size > 0) {
    clearInterval(ready)
    process.stdout.write('READY\n')
    if (mode === 'eof') {
      // Client goes away shortly — leave time for the test to observe the live helper.
      setTimeout(() => child.stdin.end(), 300)
    }
    if (mode === 'kill') {
      // Parent death: this session process is about to be SIGKILLed by the test.
      // Keep the stdin write end open (via this process) until we are killed.
    }
    if (mode === 'hold') {
      // stay alive holding stdin
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

wait_ready() {
  local f="$1" i
  for i in $(seq 1 50); do
    [ -s "$f" ] && return 0
    sleep 0.1
  done
  return 1
}

echo "== mcp-session-guard"

# --- 1. stdin EOF reaps the helper tree ---------------------------------
rm -f "$TMP/pid1" "$TMP/pid1.kid"
"$NODE" "$TMP/session.js" "$GUARD" "$TMP/hold.js" "$TMP/pid1" eof \
  >"$TMP/out1" 2>"$TMP/err1" &
SESSION=$!
wait_ready "$TMP/pid1" || fail "helper did not start (stdin-eof case): $(cat "$TMP/err1" 2>/dev/null)"
HELPER_PID="$(cat "$TMP/pid1")"
KID_PID="$(cat "$TMP/pid1.kid" 2>/dev/null || true)"
alive "$HELPER_PID" || fail "helper not alive before stdin close"
sleep 1
alive "$HELPER_PID" && fail "helper still alive after stdin EOF (pid $HELPER_PID)"
[ -n "$KID_PID" ] && alive "$KID_PID" && fail "grandchild still alive after stdin EOF (pid $KID_PID)"
wait "$SESSION" 2>/dev/null || true
ok "stdin_eof_kills_helper_and_grandchild"

# --- 2. session SIGKILL (Claude OOM) reaps the helper tree -------------
# Killing the session closes its stdin write end — the same event an OOM
# SIGKILL produces. The guard must reap npx/node grandchildren too.
rm -f "$TMP/pid2" "$TMP/pid2.kid"
"$NODE" "$TMP/session.js" "$GUARD" "$TMP/hold.js" "$TMP/pid2" hold \
  >"$TMP/out2" 2>"$TMP/err2" &
SESSION=$!
wait_ready "$TMP/pid2" || fail "helper did not start (session-kill case): $(cat "$TMP/err2" 2>/dev/null)"
HELPER_PID="$(cat "$TMP/pid2")"
KID_PID="$(cat "$TMP/pid2.kid" 2>/dev/null || true)"
kill -9 "$SESSION" 2>/dev/null || true
sleep 3
alive "$HELPER_PID" && fail "helper still alive after session SIGKILL (pid $HELPER_PID)"
[ -n "$KID_PID" ] && alive "$KID_PID" && fail "grandchild still alive after session SIGKILL (pid $KID_PID)"
ok "session_sigkill_reaps_helper_tree"

# --- 3. normal child exit is forwarded ---------------------------------
set +e
"$NODE" "$GUARD" "$NODE" -e "process.exit(7)" </dev/null >"$TMP/out3" 2>"$TMP/err3"
RC=$?
set -e
[ "$RC" -eq 7 ] || fail "guard did not forward child exit code (got $RC)"
ok "child_exit_code_forwarded"

# --- 4. Windows .cmd shims must start (H1: spawn cannot run batch files) ---
if [ "$OSTYPE" = "msys" ] || [ "$OSTYPE" = "cygwin" ] || [ -n "${WINDIR:-}" ]; then
  TMP_WIN="$(cygpath -w "$TMP" 2>/dev/null || echo "$TMP")"
  NODE_WIN="$(cygpath -w "$(command -v "$NODE")" 2>/dev/null || echo "$NODE")"
  cat > "$TMP/hold.cmd" <<EOF
@echo off
"$NODE_WIN" "$TMP_WIN\\hold.js" "$TMP_WIN\\pidcmd"
EOF
  rm -f "$TMP/pidcmd" "$TMP/pidcmd.kid"
  HOLD_CMD_WIN="$(cygpath -w "$TMP/hold.cmd")"
  "$NODE" "$GUARD" "$HOLD_CMD_WIN" >"$TMP/outcmd" 2>"$TMP/errcmd" &
  GUARD_CMD=$!
  wait_ready "$TMP/pidcmd" || fail "helper did not start via .cmd shim: $(cat "$TMP/errcmd" 2>/dev/null)"
  HELPER_PID="$(cat "$TMP/pidcmd")"
  alive "$HELPER_PID" || fail "cmd shim helper not alive"
  kill "$GUARD_CMD" 2>/dev/null || true
  wait "$GUARD_CMD" 2>/dev/null || true
  sleep 0.5
  alive "$HELPER_PID" && fail "cmd shim helper leaked after guard exit (pid $HELPER_PID)"
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

echo "PASS: mcp-session-guard"
