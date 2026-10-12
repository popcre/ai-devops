#!/usr/bin/env bash
# Offline native-envelope acceptance and private failure retention for Gemini.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup() {
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -rf "$TMP"
  else
    printf 'Gemini test failed: case=%s; private evidence=%s\n' "${test_case:-setup}" "$TMP" >&2
  fi
}
trap cleanup EXIT
export AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
export AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard"
source "$ROOT/tests/lib-test-harness.sh"
test_case=setup
trap 'ai_test_record fail "case=$test_case line=$LINENO"; printf "Gemini assertion failed: case=%s line=%s\n" "$test_case" "$LINENO" >&2' ERR
# Retained synthetic failure evidence must be private before any bytes are written.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    AI_DEVOPS_PRIVATE_HELPER="$(cygpath -w "$ROOT/bin/windows-private-file.ps1")" \
    AI_DEVOPS_PRIVATE_TARGET="$(cygpath -w "$TMP")" \
    env -u PSModulePath powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \
      '. $env:AI_DEVOPS_PRIVATE_HELPER; Protect-AiDevOpsPrivatePath -Path $env:AI_DEVOPS_PRIVATE_TARGET -Directory' \
      >/dev/null
    ;;
esac
mkdir -p "$TMP/work" "$TMP/packet"
printf 'Review the sealed packet.\n' > "$TMP/prompt"
cat > "$TMP/agy" <<'STUB'
#!/usr/bin/env bash
prompt="$(jq -er 'select(.event=="user" and .message.role=="user") | .message.content[0].text')" || exit 93
stream_in=0; stream_out=0; empty_print=0
for arg in "$@"; do [ "$arg" != --dangerously-skip-permissions ] || exit 90; done
while [ "$#" -gt 0 ]; do
  case "$1" in
    --input-format) [ "$2" = stream-json ] || exit 94; stream_in=1; shift 2 ;;
    --output-format) [ "$2" = stream-json ] || exit 94; stream_out=1; shift 2 ;;
    --print) [ "$2" = '' ] || exit 94; empty_print=1; shift 2 ;;
    *) shift ;;
  esac
done
[ "$stream_in$stream_out$empty_print" = 111 ] || exit 94
if [ "${AGY_CLI_DISABLE_AUTO_UPDATE:-}" != 1 ]; then
  printf 'silently replaced runtime\n' > "$GEMINI_RUNTIME_MARKER"
fi
if [ "${GEMINI_CONTRACT_CASE:-0}" = 1 ]; then
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --print) [ "$2" = '' ] || exit 92; shift 2 ;;
      --dangerously-skip-permissions) exit 90 ;;
      *) shift ;;
    esac
  done
  # Model the real headless native boundary: requesting execution without
  # an explicit file-tool-only contract auto-denies RunCommand and ends empty.
  if ! printf '%s' "$prompt" | grep -q 'Shell commands are NOT available' \
    || ! printf '%s' "$prompt" | grep -q 'file-reading tools instead' \
    || ! printf '%s' "$prompt" | grep -q 'never claim command execution'; then
    printf '%s\n' '{"status":"SUCCESS","response":"","denied_actions":[{"action":"command","display_name":"RunCommand"}]}'
    exit 0
  fi
  grep -q 'if count < 0:' allocation.py || exit 91
  printf '%s\n' '{"event":"init","conversation_id":"contract","init":{"model":"gemini-3.8-flash-high"}}' '{"event":"result","result":{"conversation_id":"contract","status":"SUCCESS","response":"allocation.py accepts count zero because its check is count < 0, then divides by zero instead of raising ValueError. Native file tools read that source. Terminal checks were not executed because this runtime does not support them.\n## Verdict\nREJECT"}}'
  exit 0
fi
cat "$GEMINI_FIXTURE"
printf '%s\n' 'private provider diagnostic sentinel' >&2
exit "${GEMINI_NATIVE_EXIT:-0}"
STUB
chmod +x "$TMP/agy"
export AGY_CLI_DISABLE_AUTO_UPDATE=0 GEMINI_RUNTIME_MARKER="$TMP/runtime-marker"
printf 'qualified runtime bytes\n' > "$GEMINI_RUNTIME_MARKER"
cp "$GEMINI_RUNTIME_MARKER" "$TMP/runtime-before"
export AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_GEMINI_BIN="$TMP/agy"
export DOOR_WORKDIR="$TMP/work" DOOR_PACKET_DIR="$TMP/packet" DOOR_PROMPT_FILE="$TMP/prompt"
export DOOR_HEAD=0123456789012345678901234567890123456789 DOOR_TIMEOUT=10
export GEMINI_FIXTURE="$TMP/response.json"
passed=0
run_case() {
  local name="$1" expected="$2" json="$3" native_exit="${4:-0}" rc=0
  test_case="$name"
  printf '%s\n' "$json" > "$GEMINI_FIXTURE"
  if jq -e 'type=="object" and (has("event")|not)' "$GEMINI_FIXTURE" >/dev/null 2>&1; then
    jq -c '. as $r | {event:"init",conversation_id:"native",init:(if $r|has("model") then {model:$r.model} else {} end)}, {event:"result",result:($r + {conversation_id:"native"})}' "$GEMINI_FIXTURE" > "$GEMINI_FIXTURE.stream"
    mv "$GEMINI_FIXTURE.stream" "$GEMINI_FIXTURE"
  fi
  export DOOR_REPORT_OUT="$TMP/$name.report" DOOR_DIAGNOSTICS_DIR="$TMP/$name.diagnostics" GEMINI_NATIVE_EXIT="$native_exit"
  bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/$name.out" 2> "$TMP/$name.err" || rc=$?
  if [ "$expected" = success ]; then
    [ "$rc" -eq 0 ]
    grep -q '^APPROVE$' "$DOOR_REPORT_OUT"
    [ ! -e "$DOOR_DIAGNOSTICS_DIR" ]
  else
    [ "$rc" -eq 1 ]
    grep -q "\"reason\": \"$expected\"" "$DOOR_DIAGNOSTICS_DIR/report.md"
    cmp "$GEMINI_FIXTURE" "$DOOR_DIAGNOSTICS_DIR/native.jsonl"
    grep -q 'private provider diagnostic sentinel' "$DOOR_DIAGNOSTICS_DIR/native.stderr"
    ! grep -q 'private provider diagnostic sentinel' "$DOOR_REPORT_OUT" "$TMP/$name.err"
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*)
        AI_DEVOPS_PRIVATE_HELPER="$(cygpath -w "$ROOT/bin/windows-private-file.ps1")" \
        AI_DEVOPS_PRIVATE_TARGET="$(cygpath -w "$DOOR_DIAGNOSTICS_DIR")" \
        env -u PSModulePath powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \
          '. $env:AI_DEVOPS_PRIVATE_HELPER; Assert-AiDevOpsPrivateAcl -Path $env:AI_DEVOPS_PRIVATE_TARGET; Get-ChildItem -LiteralPath $env:AI_DEVOPS_PRIVATE_TARGET | ForEach-Object { Assert-AiDevOpsPrivateAcl -Path $_.FullName }' \
          > "$TMP/$name.acl-proof" 2>&1
        ;;
      *) python3 - "$DOOR_DIAGNOSTICS_DIR" <<'PY'
import pathlib,stat,sys
p=pathlib.Path(sys.argv[1]);assert stat.S_IMODE(p.stat().st_mode)==0o700
assert all(stat.S_IMODE(f.stat().st_mode)==0o600 for f in p.iterdir())
PY
        ;;
    esac
  fi
  passed=$((passed+1))
}
run_case good success '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":"Substantive findings\n## Verdict\nAPPROVE"}'
run_case empty empty-response-text '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":""}'
run_case whitespace empty-response-text '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":" \n\t"}'
run_case response-object empty-response-text '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":{"message":"APPROVE"}}'
run_case status provider-status-failed '{"status":"ERROR","model":"gemini-3.8-flash-high","response":"## Verdict\nAPPROVE","error":"private provider diagnostic sentinel"}'
run_case denied native-tool-denied '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":"## Verdict\nAPPROVE","denied_actions":[{"action":"command","display_name":"RunCommand"}]}'
run_case wrong-model model-mismatch '{"status":"SUCCESS","model":"other-model","response":"## Verdict\nAPPROVE"}'
run_case missing-model model-mismatch '{"status":"SUCCESS","response":"## Verdict\nAPPROVE"}'
run_case spoofed-result-model model-mismatch '{"status":"SUCCESS","init_model":"gemini-3.8-flash-high","response":"## Verdict\nAPPROVE"}'
run_case mismatch invalid-response-json '{"event":"init","conversation_id":"a","init":{"model":"gemini-3.8-flash-high"}}
{"event":"result","result":{"conversation_id":"b","status":"SUCCESS","response":"## Verdict\nAPPROVE"}}'
run_case multi-result invalid-response-json '{"event":"init","conversation_id":"a","init":{"model":"gemini-3.8-flash-high"}}
{"event":"result","result":{"conversation_id":"a","status":"SUCCESS","response":"## Verdict\nAPPROVE"}}
{"event":"result","result":{"conversation_id":"a","status":"SUCCESS","response":"## Verdict\nAPPROVE"}}'
run_case missing-init invalid-response-json '{"event":"result","result":{"conversation_id":"a","status":"SUCCESS","response":"## Verdict\nAPPROVE"}}'
run_case empty-conversation invalid-response-json '{"event":"init","conversation_id":"","init":{"model":"gemini-3.8-flash-high"}}
{"event":"result","result":{"conversation_id":"","status":"SUCCESS","response":"## Verdict\nAPPROVE"}}'
run_case multi-init invalid-response-json '{"event":"init","conversation_id":"a","init":{"model":"gemini-3.8-flash-high"}}
{"event":"init","conversation_id":"a","init":{"model":"gemini-3.8-flash-high"}}
{"event":"result","result":{"conversation_id":"a","status":"SUCCESS","response":"## Verdict\nAPPROVE"}}'
run_case invalid invalid-response-json '{broken-json'
run_case array invalid-response-json '[{"status":"SUCCESS"}]'
run_case native-error provider-call-failed '{"status":"ERROR","error":"private provider diagnostic sentinel"}' 1
# Credit exhaustion keeps exit 92 and the capacity hold, and still retains the
# native result privately like every other refused provider call (#1562).
test_case=out-of-credit
cp "$ROOT/tests/fixtures/reviewer-credit/gemini-prepay.json" "$GEMINI_FIXTURE"
export DOOR_REPORT_OUT="$TMP/credit.report" DOOR_DIAGNOSTICS_DIR="$TMP/credit.diagnostics" GEMINI_NATIVE_EXIT=0
credit_rc=0
bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/credit.out" 2> "$TMP/credit.err" || credit_rc=$?
[ "$credit_rc" -eq 92 ]
grep -qx 'AI_REVIEWER_OUT_OF_CREDIT provider=gemini code=insufficient_quota' "$TMP/credit.err"
"$(command -v python3 || command -v python)" "$ROOT/tools/reviewer_admission.py" capacity-status gemini --directory "$AI_REVIEW_QUARANTINE_DIR" | jq -e '.failure_class=="out-of-credit"' >/dev/null
grep -q '"reason": "out-of-credit"' "$DOOR_DIAGNOSTICS_DIR/report.md"
cmp "$GEMINI_FIXTURE" "$DOOR_DIAGNOSTICS_DIR/native.jsonl"
grep -q 'private provider diagnostic sentinel' "$DOOR_DIAGNOSTICS_DIR/native.stderr"
! grep -q 'private provider diagnostic sentinel' "$TMP/credit.err"
printf '%s\n' 'credit exhaustion exits 92, records capacity, and retains private native diagnostics'
passed=$((passed+1))
test_case=file-tool-contract
printf 'def allocation(total, count):\n    if count < 0:\n        raise ValueError("count must be positive")\n    return total / count\n' > "$TMP/work/allocation.py"
printf 'Review allocation.py. Execute python3 -m unittest when supported; otherwise report the unsupported capability.\n' > "$TMP/prompt"
export DOOR_REPORT_OUT="$TMP/contract.report" DOOR_DIAGNOSTICS_DIR="$TMP/contract.diagnostics"
GEMINI_CONTRACT_CASE=1 bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/contract.out" 2> "$TMP/contract.err"
grep -q '^REJECT$' "$DOOR_REPORT_OUT"
grep -q 'count < 0' "$DOOR_REPORT_OUT"
grep -q 'checks were not executed' "$DOOR_REPORT_OUT"
[ ! -e "$DOOR_DIAGNOSTICS_DIR" ]
printf '%s\n' 'headless native stub reads the defect and returns REJECT without unsupported command execution'
passed=$((passed+1))
test_case=runtime-preservation
cmp "$TMP/runtime-before" "$GEMINI_RUNTIME_MARKER"
printf '%s\n' 'native calls preserve qualified runtime bytes despite inherited update permission'
passed=$((passed+1))
test_case=implementation-contract
GEMINI_CONTRACT_CASE=1 bash "$ROOT/tools/lib/review-doors/gemini.sh" implement > "$TMP/implement.out" 2> "$TMP/implement.err"
grep -q '^REJECT$' "$DOOR_REPORT_OUT"
printf '%s\n' 'review and implement use native stream model evidence and STDIN user events'
passed=$((passed+1))
printf '%s Gemini native-envelope checks passed\n' "$passed"
