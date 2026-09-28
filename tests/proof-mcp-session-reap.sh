#!/usr/bin/env bash
# Live proof helper: start and end several fake sessions and show the node
# process count returns to baseline. Used by the MCP session-guard work.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE="${MCP_SESSION_GUARD_NODE:-node}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

node_count() {
  # Count node processes we can see (Windows: tasklist; POSIX: pgrep).
  if command -v tasklist >/dev/null 2>&1; then
    tasklist //FI "IMAGENAME eq node.exe" 2>/dev/null | grep -c 'node.exe' || true
  else
    pgrep -c node 2>/dev/null || echo 0
  fi
}

cat > "$TMP/hold.js" <<'EOF'
const fs = require('fs')
fs.writeFileSync(process.argv[2], String(process.pid))
const { spawn } = require('child_process')
const kid = spawn(process.execPath, ['-e', 'setTimeout(()=>{}, 60000)'], { stdio: 'ignore' })
fs.writeFileSync(process.argv[2] + '.kid', String(kid.pid))
setInterval(() => {}, 1000)
EOF

cat > "$TMP/session.js" <<'EOF'
const { spawn } = require('child_process')
const fs = require('fs')
const [guard, hold, pidfile, mode] = process.argv.slice(2)
const child = spawn(process.execPath, [guard, process.execPath, hold, pidfile], {
  stdio: ['pipe', 'inherit', 'inherit'],
})
const ready = setInterval(() => {
  if (fs.existsSync(pidfile) && fs.statSync(pidfile).size > 0) {
    clearInterval(ready)
    process.stdout.write('READY\n')
    if (mode === 'eof') setTimeout(() => child.stdin.end(), 200)
    if (mode === 'hold') { /* keep stdin */ }
  }
}, 50)
child.on('exit', (code) => process.exit(code ?? 0))
EOF

echo "baseline_node_count=$(node_count)"
BASE=$(node_count)

pids=()
for i in 1 2 3; do
  "$NODE" "$TMP/session.js" "$ROOT/bin/mcp-session-guard.mjs" "$TMP/hold.js" "$TMP/pid$i" hold \
    >"$TMP/out$i" 2>"$TMP/err$i" &
  pids+=($!)
done

for i in 1 2 3; do
  for _ in $(seq 1 50); do [ -s "$TMP/pid$i" ] && break; sleep 0.1; done
done

sleep 0.3
echo "after_start_node_count=$(node_count)"
echo "helpers:"
for i in 1 2 3; do
  echo "  session$i helper=$(cat "$TMP/pid$i" 2>/dev/null || echo none) kid=$(cat "$TMP/pid$i.kid" 2>/dev/null || echo none)"
done

# End every session the way a client close / OOM does.
for p in "${pids[@]}"; do kill -9 "$p" 2>/dev/null || true; done
sleep 2

echo "after_end_node_count=$(node_count)"
END=$(node_count)
for i in 1 2 3; do
  P=$(cat "$TMP/pid$i" 2>/dev/null || true)
  if [ -n "$P" ]; then
    if kill -0 "$P" 2>/dev/null; then echo "LEAK helper $P still alive"; else echo "  helper $P reaped"; fi
  fi
  K=$(cat "$TMP/pid$i.kid" 2>/dev/null || true)
  if [ -n "$K" ] && kill -0 "$K" 2>/dev/null; then echo "LEAK kid $K still alive"; else echo "  kid $K reaped"; fi
done

if [ "$END" -le "$BASE" ]; then
  echo "PROOF: node process count returned to baseline ($END <= $BASE)"
  exit 0
fi
echo "PROOF FAILED: node count $END > baseline $BASE"
exit 1
