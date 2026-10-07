#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/tools/lib/mcp-launcher-install-linux.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -m 700 "$tmp/cfg" "$tmp/txn"
printf old-launcher > "$tmp/cfg/mcp-remote-launch.sh"
printf old-guard > "$tmp/cfg/mcp-session-guard.mjs"
chmod 640 "$tmp/cfg/"*
printf new-launcher > "$tmp/launcher"
printf new-guard > "$tmp/guard"
printf unrelated > "$tmp/cfg/mcp.env"
before="$(sha256sum "$tmp/cfg/mcp.env")"
mcp_linux_write_pair "$tmp/cfg" "$tmp/txn" "$tmp/launcher" "$tmp/guard"
cmp -s "$tmp/launcher" "$tmp/cfg/mcp-remote-launch.sh"
cmp -s "$tmp/guard" "$tmp/cfg/mcp-session-guard.mjs"
[ "$(sha256sum "$tmp/cfg/mcp.env")" = "$before" ]
mcp_linux_rollback "$tmp/cfg" "$tmp/txn"
[ "$(cat "$tmp/cfg/mcp-remote-launch.sh")" = old-launcher ]
[ "$(stat -c %a "$tmp/cfg/mcp-remote-launch.sh")" = 640 ]
[ "$(cat "$tmp/cfg/mcp-session-guard.mjs")" = old-guard ]
echo 'PASS: exact pair writes and rollback preserve unrelated data and prior modes'
# Simulate interruption after first atomic write using the real journal.
mcp_linux_write_pair "$tmp/cfg" "$tmp/txn" "$tmp/launcher" "$tmp/guard"
cp -p "$tmp/txn/mcp-remote-launch.sh.old" "$tmp/cfg/mcp-remote-launch.sh"
mcp_linux_write_pair "$tmp/cfg" "$tmp/txn" "$tmp/launcher" "$tmp/guard"
cmp -s "$tmp/launcher" "$tmp/cfg/mcp-remote-launch.sh"
mcp_linux_rollback "$tmp/cfg" "$tmp/txn"
echo 'PASS: interrupted mixed old/new transaction recovers before retry'
mcp_linux_write_pair "$tmp/cfg" "$tmp/txn" "$tmp/launcher" "$tmp/guard"
printf foreign-edit > "$tmp/cfg/mcp-session-guard.mjs"
if mcp_linux_rollback "$tmp/cfg" "$tmp/txn"; then echo 'FAIL: rollback destroyed foreign edit'; exit 1; fi
[ "$(cat "$tmp/cfg/mcp-session-guard.mjs")" = foreign-edit ]
echo 'PASS: crash recovery refuses changed destination'
# Restore the known transaction bytes and test symlink/unknown stage refusal.
cp "$tmp/guard" "$tmp/cfg/mcp-session-guard.mjs"
mcp_linux_rollback "$tmp/cfg" "$tmp/txn"
ln -s "$tmp/launcher" "$tmp/cfg/.mcp-remote-launch.sh.stage"
if mcp_linux_write_pair "$tmp/cfg" "$tmp/txn" "$tmp/launcher" "$tmp/guard"; then echo 'FAIL: symlink stage accepted'; exit 1; fi
rm "$tmp/cfg/.mcp-remote-launch.sh.stage"
rm "$tmp/cfg/mcp-session-guard.mjs"
ln -s "$tmp/guard" "$tmp/cfg/mcp-session-guard.mjs"
if mcp_linux_write_pair "$tmp/cfg" "$tmp/txn" "$tmp/launcher" "$tmp/guard"; then echo 'FAIL: symlink destination accepted'; exit 1; fi
echo 'PASS: staged path and destination links refuse before writes'
if "$REPO_ROOT/install.sh" --mcp-launchers-only --skip-secrets >/dev/null 2>&1; then echo 'FAIL: mixed full/partial options accepted'; exit 1; fi
echo 'PASS: partial installer refuses full-install options'
