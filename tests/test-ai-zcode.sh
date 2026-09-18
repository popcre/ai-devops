#!/usr/bin/env bash
# Tests for bin/ai-zcode.
#
# Offline: a mock "zcode.cjs" (a bash script run through AI_ZCODE_APP_EXE=bash)
# stands in for the real CLI core. The contract facts pinned here come from the
# live qualification of 2026-09-17 (tests/verification/zcode-windows-2026-09-17/):
# the provider-env assembly is mandatory, the parser rejects --max-turns /
# --settings / --allowed-tools, --prompt defaults to yolo mode, and completion
# is proven by a parsed JSON document with projection.status == "idle".
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-zcode"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Mock CLI core. Records its argv and the provider env it received, then emits
# the qualified JSON document (or a defect shape selected by the prompt).
# ---------------------------------------------------------------------------
MOCK="$TMP/zcode.cjs"
cat > "$MOCK" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$MOCK_ARGS"
{
  echo "builtin=${ZCODE_BUILTIN_PROVIDER_CONFIG_FILE:-UNSET}"
  echo "bundled=${ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG_FILE:-UNSET}"
  echo "personal=${ZCODE_PERSONAL_PROVIDER_CONFIG_FILE:-UNSET}"
  echo "electron_node=${ELECTRON_RUN_AS_NODE:-UNSET}"
} > "$MOCK_ENV"
while [ $# -gt 0 ]; do
  case "$1" in
    --help) echo "zcode 9.9.9-mock"; exit 0 ;;
    --mode) MOCK_MODE="$2"; shift 2 ;;
    --disallowed-tools) MOCK_DENY="$2"; shift 2 ;;
    --json) shift ;;
    -p) shift; break ;;
    *) shift ;;
  esac
done
case "$1" in
  *DEFECT-NOT-JSON*) echo "this is not json"; exit 0 ;;
  *DEFECT-NOT-IDLE*) printf '{"sessionId":"s","response":"partial","usage":{},"projection":{"status":"running"}}\n'; exit 0 ;;
  *DEFECT-EMPTY*)    printf '{"sessionId":"s","response":"","usage":{},"projection":{"status":"idle"}}\n'; exit 0 ;;
  *) printf '{"sessionId":"sess_mock-0001","response":"OK","usage":{"modelRequestCount":1,"totalTokens":42},"projection":{"status":"idle","turnCount":1}}\n' ;;
esac
EOF
chmod +x "$MOCK"
printf '{}' > "$TMP/zcode-builtin.json"
printf '{}' > "$TMP/bundled.json"

run_mock() {  # run_mock <args...>  — wrapper under the mock environment
  MOCK_ARGS="$TMP/args" MOCK_ENV="$TMP/env" \
  AI_ZCODE_APP_EXE="$(command -v bash)" \
  AI_ZCODE_CLI_CORE="$MOCK" \
  AI_ZCODE_BUILTIN_PROVIDER_CONFIG="$TMP/zcode-builtin.json" \
  AI_ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG="$TMP/bundled.json" \
  "$SCRIPT" "$@"
}

# ---------------------------------------------------------------------------
# STEP 0 facts are pinned in the wrapper header.
# ---------------------------------------------------------------------------
check "STEP 0 block records the qualified build" "grep -q 'STEP 0 VERIFICATION' '$SCRIPT' && grep -q '0.16.5' '$SCRIPT'"
check "STEP 0 records the mandatory provider-env assembly" "grep -q 'ZCODE_BUILTIN_PROVIDER_CONFIG_FILE' '$SCRIPT'"
check "STEP 0 records the parser-rejected flags" "grep -q -- '--max-turns' '$SCRIPT' && grep -q -- '--settings' '$SCRIPT' && grep -q -- '--allowed-tools' '$SCRIPT'"
check "wrapper pins plan mode default and refuses yolo" "grep -q 'refused: ZCode' '$SCRIPT'"

# ---------------------------------------------------------------------------
# Binary resolution fails closed.
# ---------------------------------------------------------------------------
out="$(AI_ZCODE_APP_EXE="$TMP/does-not-exist.exe" AI_ZCODE_CLI_CORE="$MOCK" \
       AI_ZCODE_BUILTIN_PROVIDER_CONFIG="$TMP/zcode-builtin.json" \
       AI_ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG="$TMP/bundled.json" \
       "$SCRIPT" ask "hi" 2>&1)" && rc=0 || rc=$?
check "missing app fails closed with local_dependency class" "[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'local_dependency_unavailable'"
check "missing app names the exact path" "printf '%s' \"$out\" | grep -qF \"\$TMP/does-not-exist.exe\""

out="$(AI_ZCODE_APP_EXE="$(command -v bash)" AI_ZCODE_CLI_CORE="$TMP/no-core.cjs" \
       AI_ZCODE_BUILTIN_PROVIDER_CONFIG="$TMP/zcode-builtin.json" \
       AI_ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG="$TMP/bundled.json" \
       "$SCRIPT" ask "hi" 2>&1)" && rc=0 || rc=$?
check "missing CLI core fails closed naming the path" "[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF '$TMP/no-core.cjs'"

# Runtime provider config missing and no override -> refuse before contacting.
mkdir -p "$TMP/empty-zcode-home"
out="$(AI_ZCODE_APP_EXE="$(command -v bash)" AI_ZCODE_CLI_CORE="$MOCK" \
       AI_ZCODE_HOME="$TMP/empty-zcode-home" \
       AI_ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG="$TMP/bundled.json" \
       "$SCRIPT" ask "hi" 2>&1)" && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'Provider was not contacted'; then
  ok "missing runtime provider config refuses with Provider was not contacted"
else
  bad "missing runtime provider config refuses with Provider was not contacted"
fi

# ---------------------------------------------------------------------------
# ask: argv pinning and output contract.
# ---------------------------------------------------------------------------
rm -f "$TMP/args" "$TMP/env"
out="$(run_mock ask "hello")" && rc=0 || rc=$?
check "ask succeeds against the mock" "[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK$'"
check "ask pins --mode plan" "grep -q -- '--mode' "$TMP/args" && grep -q 'plan' "$TMP/args""
check "ask pins the write/bash denylist" "grep -q -- '--disallowed-tools' "$TMP/args" && grep -qi 'Edit,Write,ApplyPatch,Bash' "$TMP/args""
check "ask passes --json and -p" "grep -q -- '--json' "$TMP/args" && grep -q -- '-p' "$TMP/args""
check "ask never passes a rejected flag" "! grep -qE -- '--max-turns|--settings|--allowed-tools' "$TMP/args""
check "provider env assembled (builtin)" "grep -q '^builtin=.*zcode-builtin.json' \"$TMP/env\""
if grep -q '^bundled=.*json' "$TMP/env" && ! grep -q '^bundled=UNSET' "$TMP/env"; then
  ok "provider env assembled (bundled)"
else
  bad "provider env assembled (bundled)"
fi
if grep -q '^personal=.*json' "$TMP/env" && ! grep -q '^personal=UNSET' "$TMP/env"; then
  ok "provider env assembled (personal)"
else
  bad "provider env assembled (personal)"
fi
check "ELECTRON_RUN_AS_NODE exported" "grep -q '^electron_node=1$' \"$TMP/env\""

run_mock ask "hello" --mode yolo >/dev/null 2>&1 && rc=0 || rc=$?
check "yolo from caller input is refused" "[ "$rc" -ne 0 ]"
run_mock ask "hello" --allowed-tools "Read" >/dev/null 2>&1 && rc=0 || rc=$?
check "allowlist flag refused with pointer to denylist" "[ "$rc" -ne 0 ]"
run_mock ask "hello" --frobnicate >/dev/null 2>&1 && rc=0 || rc=$?
check "unknown ask option refused" "[ "$rc" -ne 0 ]"
run_mock ask >/dev/null 2>&1 && rc=0 || rc=$?
check "ask without a prompt refused" "[ "$rc" -ne 0 ]"

run_mock ask "DEFECT-NOT-JSON" >/dev/null 2>&1 && rc=0 || rc=$?
check "non-JSON output is a failed run, not empty success" "[ "$rc" -ne 0 ]"
run_mock ask "DEFECT-NOT-IDLE" >/dev/null 2>&1 && rc=0 || rc=$?
check "non-idle projection status is a failed run" "[ "$rc" -ne 0 ]"
run_mock ask "DEFECT-EMPTY" >/dev/null 2>&1 && rc=0 || rc=$?
check "empty response still completes with exit 0 (contract keys present)" "[ "$rc" -eq 0 ]"

json="$(run_mock ask "hello" --json-output)"
if printf '%s' "$json" | jq -e '.sessionId == "sess_mock-0001" and .response == "OK"' >/dev/null 2>&1; then
  ok "--json-output passes the full document through"
else
  bad "--json-output passes the full document through"
fi

# ---------------------------------------------------------------------------
# version + doctor.
# ---------------------------------------------------------------------------
out="$(run_mock version)"
check "version reports wrapper and CLI versions" "printf '%s' "$out" | grep -q 'ai-zcode 1' && printf '%s' "$out" | grep -q '9.9.9-mock'"

# doctor against a fixture ZCode home: present, signed in, valid config,
# managed skills dir, shim on PATH (fabricated via PATH).
ZHOME="$TMP/zcode-home"
mkdir -p "$ZHOME/cli" "$ZHOME/v2" "$ZHOME/skills/ask-glm" "$TMP/shimdir"
printf '{}' > "$ZHOME/cli/config.json"
printf 'x' > "$ZHOME/v2/credentials.json"
printf 'marker' > "$ZHOME/skills/ask-glm/.ai-devops-managed"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/shimdir/zcode"; chmod +x "$TMP/shimdir/zcode"
# A config with hooks enabled and mcp present so doctor's structural checks pass.
jq -n '{mcp:{servers:{"1password":{command:"cmd",args:[],timeoutMs:120000}}},hooks:{enabled:true}}' > "$ZHOME/cli/config.json"
out="$(AI_ZCODE_APP_EXE="$(command -v bash)" AI_ZCODE_CLI_CORE="$MOCK" \
       AI_ZCODE_HOME="$ZHOME" \
       AI_ZCODE_BUILTIN_PROVIDER_CONFIG="$TMP/zcode-builtin.json" \
       AI_ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG="$TMP/bundled.json" \
       PATH="$TMP/shimdir:$PATH" \
       "$SCRIPT" doctor 2>&1)" && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'all checks green'; then
  ok "doctor green on a fully-wired fixture"
else
  bad "doctor green on a fully-wired fixture"
fi
check "doctor reports login state without reading credentials" "printf '%s' "$out" | grep -q 'signed in (credentials file present)'"

# Doctor must fail on the un-migrated junction fixture.
ZHOME2="$TMP/zcode-home-junction"
mkdir -p "$ZHOME2/cli" "$ZHOME2/v2" "$TMP/real-skills"
printf '{}' > "$ZHOME2/cli/config.json"; printf 'x' > "$ZHOME2/v2/credentials.json"
jq -n '{hooks:{enabled:true}}' > "$ZHOME2/cli/config.json"
cmd //c "mklink /J \"$(cygpath -w "$ZHOME2/skills")\" \"$(cygpath -w "$TMP/real-skills")\"" >/dev/null 2>&1
out="$(AI_ZCODE_APP_EXE="$(command -v bash)" AI_ZCODE_CLI_CORE="$MOCK" \
       AI_ZCODE_HOME="$ZHOME2" \
       AI_ZCODE_BUILTIN_PROVIDER_CONFIG="$TMP/zcode-builtin.json" \
       AI_ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG="$TMP/bundled.json" \
       PATH="$TMP/shimdir:$PATH" \
       "$SCRIPT" doctor 2>&1)" && rc=0 || rc=$?
check "doctor flags a still-junctioned skills dir" "[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'STILL A JUNCTION'"
check "junction fixture target untouched by doctor (read-only check)" "test -d '$TMP/real-skills'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
