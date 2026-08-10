#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-deepseek-agent"
PASS=0
FAIL=0
ok() { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home/.config/ai-devops"
printf 'placeholder-token\n' > "$TMP/home/.config/ai-devops/op-service-account"
printf 'DEEPSEEK_API_KEY=op://example\n' > "$TMP/home/.config/ai-devops/mcp.env"

cat > "$TMP/bin/op" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DEEPSEEK_TEST_ARGS"
exit 0
STUB
chmod +x "$TMP/bin/op"

echo 'ai-deepseek-agent tests'
HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_TEST_ARGS="$TMP/args" \
  bash "$SCRIPT" send test >/dev/null 2>&1
check "1Password re-exec was attempted" "grep -qx -- 'run' '$TMP/args'"
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  check "Windows re-exec uses an explicit Git Bash executable" \
    "grep -Eqi 'Git.*bash.exe$' '$TMP/args'"
  check "Windows never asks op to execute the script directly" \
    "! awk 'seen { print; exit } /^--$/ { seen=1 }' '$TMP/args' | grep -q '^C:/repos/.*/bin/ai-deepseek-agent$'"
else
  check "POSIX re-exec keeps the script path" "grep -q 'ai-deepseek-agent' '$TMP/args'"
fi

check "help succeeds" "bash '$SCRIPT' --help"
check "unknown command fails" "! bash '$SCRIPT' unknown"

printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
