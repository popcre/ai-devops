#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cygpath -u "$1")"
installed="$ROOT"
SCRIPT_DIR="$ROOT/bin"
STATE_DIR="${AI_TASK_GATES_DIR:-$HOME/.local/state/ai-devops/task-gates}"
. "$ROOT/tools/lib/mcp-launcher-install-gate.sh"
# This hook is called at the full install's final boundary, after managed
# command stamping. Independently validate both full source receipt launchers.
target="$(git -C "$installed" rev-parse HEAD)"
[ -z "$(git -C "$installed" status --porcelain=v1 --untracked-files=all)" ]
source_hash="$(sha256sum "$ROOT/bin/ai-task-gates" | cut -d' ' -f1)"
for launcher in "$HOME/.local/bin/ai-task-gates" "$HOME/.local/bin/ai-task-gates.cmd"; do
  grep -Fq "source-sha=$target" "$launcher"
  grep -Fq "source-hash=$source_hash" "$launcher"
done
receipt_dir="$STATE_DIR/full-windows-installs"
mkdir -p "$receipt_dir"
chmod 700 "$receipt_dir"
receipt="$receipt_dir/$target.json"
tmp="$(mktemp "$receipt_dir/.full.XXXXXXXX")"
jq -nc --arg t "$target" --arg p "$installed" --arg h "$source_hash" \
  '{schema_version:1,scope:"full-toolkit",target_head:$t,installed_checkout:$p,source_sha256:$h}' > "$tmp"
chmod 600 "$tmp"
mv -- "$tmp" "$receipt"
mcp_install_supersede_full "$installed" "$target" "$receipt"
