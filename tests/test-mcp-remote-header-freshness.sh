#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

awk '/^  cat > "\$REMOTE_SH" <<EOF$/ { copy=1; next }
     copy && /^EOF$/ { exit }
     copy { print }' "$repo/bin/setup-secrets.sh" > "$tmp/template"
test -s "$tmp/template" || { echo 'FAIL: remote launcher template missing' >&2; exit 1; }

mkdir -p "$tmp/bin"
cat > "$tmp/bin/flock" <<'SH'
#!/bin/sh
while [ "$#" -gt 0 ] && [ "$1" != op ]; do shift; done
[ "$#" -gt 0 ] || exit 2
exec "$@"
SH
cat > "$tmp/bin/op" <<'SH'
#!/bin/sh
[ "$1" = read ] || exit 2
[ "${FAKE_OP_FAIL:-}" != 1 ] || exit 1
case "$2" in
  op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token|op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token|op://vibe_coding/recall-ai\ MCP/password) printf 'new-synthetic-token' ;;
  *) exit 2 ;;
esac
SH
cat > "$tmp/bin/node-mock" <<'SH'
#!/bin/sh
printf '%s\n' "$MCP_REMOTE_AUTH_HEADER" > "$PROOF_DIR/header"
printf '%s\n' "$@" > "$PROOF_DIR/argv"
printf '%s' "${DEVOPS_MCP_TOKEN:-}${NAS_MCP_TOKEN:-}${RECALL_AI_TOKEN:-}" > "$PROOF_DIR/stale-env"
printf '%s' "${OP_SERVICE_ACCOUNT_TOKEN:-}" > "$PROOF_DIR/service-env"
SH
chmod +x "$tmp/bin/flock" "$tmp/bin/op" "$tmp/bin/node-mock"

export TOKEN_FILE="$tmp/no-service-token" CFG_DIR="$tmp" NODE_BIN="$tmp/bin/node-mock" GUARD_JS="$tmp/guard"
{ printf 'cat <<EOF\n'; cat "$tmp/template"; printf 'EOF\n'; } | bash > "$tmp/launcher"
chmod +x "$tmp/launcher"

export PATH="$tmp/bin:$PATH" PROOF_DIR="$tmp"
export DEVOPS_MCP_TOKEN='old-synthetic-token' NAS_MCP_TOKEN='old-synthetic-token' RECALL_AI_TOKEN='old-synthetic-token' OP_SERVICE_ACCOUNT_TOKEN='old-synthetic-service-token'
for ref in 'op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token' 'op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token' 'op://vibe_coding/recall-ai MCP/password'; do
  "$tmp/launcher" 'https://example.invalid/mcp' "$ref"
  grep -qx 'Bearer new-synthetic-token' "$tmp/header" || { echo "FAIL: $ref did not use fresh vault value" >&2; exit 1; }
  grep -Fxq 'Authorization:${MCP_REMOTE_AUTH_HEADER}' "$tmp/argv" || { echo "FAIL: $ref lost the argv placeholder" >&2; exit 1; }
  if grep -Eq 'old-synthetic-token|new-synthetic-token' "$tmp/argv"; then
    echo "FAIL: $ref exposed a bearer value in argv" >&2; exit 1
  fi
  test ! -s "$tmp/stale-env" || { echo "FAIL: $ref passed stale parent values to the child" >&2; exit 1; }
  test ! -s "$tmp/service-env" || { echo "FAIL: $ref passed the vault service-account token to the child" >&2; exit 1; }
done
rm -f -- "$tmp/header" "$tmp/argv"
if FAKE_OP_FAIL=1 "$tmp/launcher" 'https://example.invalid/mcp' 'op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token' > "$tmp/failed-read.out" 2>&1; then
  echo 'FAIL: vault read failure was accepted' >&2; exit 1
fi
if [ -e "$tmp/header" ] || [ -e "$tmp/argv" ]; then
  echo 'FAIL: remote MCP started after vault read failure' >&2; exit 1
fi
if "$tmp/launcher" 'https://example.invalid/mcp' 'op://unmanaged/token' > "$tmp/invalid.out" 2>&1; then
  echo 'FAIL: unmanaged token reference was accepted' >&2; exit 1
fi
echo 'PASS: remote MCP launcher accepts managed references and keeps bearer values out of child argv and environment'
