# shellcheck shell=bash
# Shared Linux remote launcher renderer; full and bounded installs use identical bytes.
# Required variables: TOKEN_FILE CFG_DIR NODE_BIN GUARD_JS.
mcp_remote_render() {
  cat <<EOF
#!/usr/bin/env sh
# [ai-devops] managed by setup-secrets.sh — do not edit by hand.
# \$1 = server URL, \$2 = op:// ref to the bearer token, \$3+ = extra mcp-remote flags.
# Pinned mcp-remote expands header placeholders from its environment. Keep the
# bearer value out of argv while retaining the same authenticated request.
# Keep the refresh lock through op's exit, not through its children.
if [ -s "$TOKEN_FILE" ]; then
  OP_SERVICE_ACCOUNT_TOKEN="\$(cat "$TOKEN_FILE")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi
URL="\$1"; REF="\$2"; shift 2
# Serialize the fallback op read like the MCP launcher: a failure while the
# lock is provably free is op's own error (no sweep, no retry); a still-held
# lock gets one doctor pass and one retry (#1002), never holding the lock
# around mcp-remote.
_aidev_flock() {
  # Exit 87 means the wait timed out on contention; any other failure is the
  # op command's own error: no sweep, no retry. On real contention
  # ai-lock-doctor clears this toolkit's own holders once, then one retry
  # (#1002); a foreign holder is never touched and the failure stands.
  flock --close -E 87 -w 90 "$CFG_DIR/op-refresh.lock" "\$@" && return 0
  _aidev_rc=\$?
  [ "\$_aidev_rc" -eq 87 ] || return "\$_aidev_rc"
  command -v ai-lock-doctor >/dev/null 2>&1 && ai-lock-doctor --recover --older-than 90 "$CFG_DIR/op-refresh.lock"
  flock --close -w 90 "$CFG_DIR/op-refresh.lock" "\$@"
}
case "\$REF" in
  op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token|op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token) ;;
  *) echo "ai-devops: unmanaged remote MCP reference — not starting \$URL" >&2; exit 1 ;;
esac
# Resolve at launch even if the parent process still carries an older token.
TOK="\$(_aidev_flock op read "\$REF")" || {
  echo "ai-devops: serialized remote token refresh FAILED for \$REF — not starting \$URL" >&2
  exit 1
}
[ -n "\$TOK" ] || {
  echo "ai-devops: \$REF resolved EMPTY — not starting \$URL" >&2
  exit 1
}
MCP_REMOTE_AUTH_HEADER="Bearer \$TOK"
export MCP_REMOTE_AUTH_HEADER
unset TOK DEVOPS_MCP_TOKEN NAS_MCP_TOKEN OP_SERVICE_ACCOUNT_TOKEN
exec "$NODE_BIN" "$GUARD_JS" npx -y mcp-remote@0.1.38 "\$URL" --header 'Authorization:\${MCP_REMOTE_AUTH_HEADER}' "\$@"
EOF
}
