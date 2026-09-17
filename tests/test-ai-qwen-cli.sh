#!/usr/bin/env bash
# Offline tests: fake op and qwen; no 1Password or provider call.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-qwen-cli"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/cfg"
cat > "$TMP/bin/op" <<'OP'
#!/usr/bin/env bash
[ "$1" = run ] && [ "$2" = --no-masking ] && [ "$3" = --env-file ] || exit 9
ref="$(sed -n 's/^BAILIAN_CODING_PLAN_API_KEY=//p' "$4")"; shift 5
BAILIAN_CODING_PLAN_API_KEY="resolved:$ref" exec "$@"
OP
cat > "$TMP/bin/qwen" <<'Q'
#!/usr/bin/env bash
printf 'key=%s args=%s\n' "$BAILIAN_CODING_PLAN_API_KEY" "$*"
Q
chmod +x "$TMP/bin/op" "$TMP/bin/qwen"
run() { AI_DEVOPS_CONFIG_DIR="$TMP/cfg" AI_QWEN_CLI_OP_BIN="$TMP/bin/op" AI_QWEN_CLI_QWEN_BIN="$TMP/bin/qwen" OP_SERVICE_ACCOUNT_TOKEN=x "$SCRIPT" "$@"; }

check 'fails without mcp.env' "! run -p hi 2>/dev/null"
printf 'OTHER=1\nBAILIAN_CODING_PLAN_API_KEY=plain\n' > "$TMP/cfg/mcp.env"
check 'rejects a non-1Password key' "! run -p hi 2>/dev/null"
printf 'OTHER=1\nBAILIAN_CODING_PLAN_API_KEY=op://v/i/f\n' > "$TMP/cfg/mcp.env"
check 'passes the resolved key and arguments to qwen' "run -p 'say OK' | grep -qx 'key=resolved:op://v/i/f args=-p say OK'"
printf 'BAILIAN_CODING_PLAN_API_KEY=op://a\nBAILIAN_CODING_PLAN_API_KEY=op://b\n' > "$TMP/cfg/mcp.env"
check 'rejects duplicate references' "! run -p hi 2>/dev/null"
check '--version needs nothing' "\"$SCRIPT\" --version | grep -q ai-qwen-cli"
printf '%s\n' "ai-qwen-cli: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
