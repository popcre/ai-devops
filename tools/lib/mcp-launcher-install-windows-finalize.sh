#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cygpath -u "$1")"
primary="$(cygpath -u "$2")"
target="$3"
transaction="$(cygpath -u "$4")"
SCRIPT_DIR="$ROOT/bin"
. "$ROOT/tools/lib/mcp-launcher-install-gate.sh"
inventory="$(mcp_install_inventory)"
report="$transaction/stage-report.json"
jq -nc --arg t "$target" --arg p "$primary" --arg i "$inventory" \
  '{schema_version:1,scope:"mcp-launchers",target_head:$t,installed_checkout:$p,after_inventory:$i,synthetic_probe_pass:true}' > "$report"
chmod 600 "$report"
cd "$ROOT"
exec "$SCRIPT_DIR/ai-task-gates" install-verify --mcp-launchers-only --phase finalize \
  --target-head "$target" --installed-checkout "$primary" \
  --installed-launcher "$HOME/.local/bin/ai-task-gates" --stage-report "$report"
