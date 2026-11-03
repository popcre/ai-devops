#!/usr/bin/env bash
# bin/cmd-compat routes shared `cmd /c ...` MCP launch lines to the Linux launchers (#2324).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '#!/bin/sh\necho "L:$*"\n' > "$TMP/mcp-launch.sh"
printf '#!/bin/sh\necho "R:$*"\n' > "$TMP/mcp-remote-launch.sh"
chmod +x "$TMP"/*.sh
run() { AI_DEVOPS_CONFIG="$TMP" sh "$ROOT/bin/cmd-compat" "$@"; }
[ "$(run /c '${USERPROFILE}\.config\ai-devops\mcp-launch.cmd' node -v)" = 'L:node -v' ] || { echo 'FAIL: stdio launcher'; exit 1; }
[ "$(run /c 'C:\x\mcp-remote-launch.cmd' https://u --t)" = 'R:https://u --t' ] || { echo 'FAIL: remote launcher'; exit 1; }
[ "$(run /c cmd /c echo nested)" = 'nested' ] || { echo 'FAIL: nested cmd /c'; exit 1; }
if run /k echo x 2>/dev/null; then echo 'FAIL: non-/c form accepted'; exit 1; fi
if run /c 'other.cmd' 2>/dev/null; then echo 'FAIL: unknown .cmd accepted'; exit 1; fi
echo 'PASS: cmd-compat routes shared MCP launch lines on Linux'
