#!/usr/bin/env bash
# DietCode intercept for Claude Code binaries that Claude Desktop launches
# by absolute path (not via PATH). Keeps the real ELF as sibling claude-real.
set -euo pipefail

REAL="/home/ahazan/.config/Claude/claude-code/2.1.295/71164c85f9d2/claude-real"
PORT="${SCALEDOWN_PROXY_PORT:-8788}"

port_open() {
  (exec 3<>"/dev/tcp/127.0.0.1/${PORT}") 2>/dev/null || return 1
  exec 3>&- 3<&-
  return 0
}

# Already inside a proxy session (dietcode claude / DIETCODE_PROXY) — just run.
if [ "${DIETCODE_PROXY:-}" = "1" ] || [ "${DIETCODE_PROXY:-}" = "true" ]; then
  exec "$REAL" "$@"
fi

# No key on this box? Stay a pure passthrough so Claude never breaks.
if [ ! -f "$HOME/.scaledown/config.json" ] && [ -z "${SCALEDOWN_API_KEY:-}" ]; then
  exec "$REAL" "$@"
fi

# Start a persistent DietCode proxy if it is not already listening.
if ! port_open; then
  mkdir -p "$HOME/.scaledown"
  nohup "$HOME/.local/bin/dietcode" proxy --port "$PORT" \
    >>"$HOME/.scaledown/proxy.log" 2>&1 &
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if port_open; then
      break
    fi
    sleep 0.2
  done
fi

# Fail-open: if the proxy still is not up, run stock Claude.
if ! port_open; then
  exec "$REAL" "$@"
fi

export ANTHROPIC_BASE_URL="http://127.0.0.1:${PORT}"
export DIETCODE_PROXY=1
# Keep Claude's own auto-compaction out of the way so DietCode owns history.
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-95}"
exec "$REAL" "$@"
