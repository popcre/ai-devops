#!/usr/bin/env bash
# Offline allowance tests. The agy fixture never contacts Google or reads OAuth.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-gemini-usage"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

# The fixture replays a recorded /usage envelope chosen by MOCK_USAGE_CASE. It
# never starts a conversation, so no test here consumes real allowance.
cat > "$TMP/bin/agy" <<'EOF'
#!/usr/bin/env bash
set -e
case "${MOCK_USAGE_CASE:-full}" in
 full) cat <<'JSON'
{"conversation_id":"","status":"SUCCESS","response":"","duration_seconds":0,"num_turns":0,"command":{"name":"usage","data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly","name":"Weekly Limit Remaining","window":"weekly","remaining_fraction":0.8757114410400391,"reset_time":"2036-09-11T01:34:29Z"},{"id":"gemini-5h","name":"Five Hour Limit Remaining","window":"5h","remaining_fraction":0.25,"reset_time":"2036-09-07T04:30:29Z"}]},{"name":"Claude and GPT models","buckets":[{"id":"3p-weekly","name":"Weekly Limit Remaining","window":"weekly","remaining_fraction":1,"reset_time":"2036-09-14T01:21:58Z"}]}]}}}
JSON
 ;;
 exhausted) cat <<'JSON'
{"conversation_id":"","status":"SUCCESS","command":{"name":"usage","data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-5h","name":"Five Hour Limit Remaining","window":"5h","remaining_fraction":0,"reset_time":"2036-09-07T04:30:29Z"}]}]}}}
JSON
 ;;
 missing_fraction) cat <<'JSON'
{"conversation_id":"","status":"SUCCESS","command":{"name":"usage","data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-5h","name":"Five Hour Limit Remaining","window":"5h","reset_time":"2036-09-07T04:30:29Z"}]}]}}}
JSON
 ;;
 no_gemini_group) cat <<'JSON'
{"conversation_id":"","status":"SUCCESS","command":{"name":"usage","data":{"groups":[{"name":"Claude and GPT models","buckets":[{"id":"3p-5h","name":"Five Hour Limit Remaining","window":"5h","remaining_fraction":1,"reset_time":"2036-09-07T04:30:29Z"}]}]}}}
JSON
 ;;
 wrong_command) printf '%s\n' '{"status":"SUCCESS","command":{"name":"model","data":{"id":"gemini-3.8-flash-high"}}}' ;;
 not_success) printf '%s\n' '{"status":"ERROR","response":"quota exhausted"}' ;;
 garbage) printf '%s\n' 'not json at all' ;;
 fail) exit 7 ;;
esac
EOF
chmod +x "$TMP/bin/agy"
export AI_GEMINI_BIN="$TMP/bin/agy"

run(){ MOCK_USAGE_CASE="$1" "$SCRIPT" "${@:2}" 2>"$TMP/err"; }

printf 'ai-gemini-usage\n'

# --- happy path -------------------------------------------------------------
out="$(run full || true)"
check 'text output names the Gemini weekly bucket' "printf %s \"\$out\" | grep -q 'Weekly Limit Remaining'"
check 'text output shows the remaining percentage' "printf %s \"\$out\" | grep -q '87.6%'"
check 'text output shows the reset timestamp' "printf %s \"\$out\" | grep -q '2036-09-11T01:34:29Z'"
check 'text output shows a human countdown' "printf %s \"\$out\" | grep -qE 'in [0-9]+d'"
check 'text output includes the non-Gemini group too' "printf %s \"\$out\" | grep -q 'Claude and GPT models'"

j="$(run full --json || true)"
check 'json parses' "printf %s \"\$j\" | jq -e . "
check 'json reports the provider' "printf %s \"\$j\" | jq -e '.provider==\"gemini\"'"
check 'json carries the bucket id' "printf %s \"\$j\" | jq -e '[.groups[].buckets[].id]|index(\"gemini-5h\")'"
check 'json converts the fraction to a percentage' "printf %s \"\$j\" | jq -e '[.groups[].buckets[]|select(.id==\"gemini-weekly\").remaining_percent]|.[0]==87.6'"
check 'json carries the reset timestamp' "printf %s \"\$j\" | jq -e '[.groups[].buckets[]|select(.id==\"gemini-5h\").reset_time]|.[0]==\"2036-09-07T04:30:29Z\"'"
check 'json carries seconds until reset' "printf %s \"\$j\" | jq -e '[.groups[].buckets[]|select(.id==\"gemini-5h\").seconds_until_reset]|.[0]>0'"

# --- zero is exhausted, absent is unknown -----------------------------------
j="$(run exhausted --json || true)"
check 'an exhausted bucket reports zero percent, not null' "printf %s \"\$j\" | jq -e '.groups[0].buckets[0].remaining_percent==0'"
j="$(run missing_fraction --json || true)"
check 'a missing fraction reports null, never zero' "printf %s \"\$j\" | jq -e '.groups[0].buckets[0].remaining_percent==null'"
out="$(run missing_fraction || true)"
check 'text prints unavailable for a missing fraction' "printf %s \"\$out\" | grep -q unavailable"
check 'text never prints 0% for a missing fraction' "! printf %s \"\$out\" | grep -q '0%'"

# --- the --min-percent gate -------------------------------------------------
rc=0; run full --min-percent 20 >/dev/null 2>&1 || rc=$?
check '--min-percent passes when every Gemini bucket is above the floor' "[ $rc -eq 0 ]"
rc=0; run full --min-percent 50 >/dev/null 2>&1 || rc=$?
check '--min-percent exits 3 when a Gemini bucket is below the floor' "[ $rc -eq 3 ]"
run full --min-percent 50 >/dev/null 2>&1 || true
check 'the floor failure names the low bucket' "grep -q 'Five Hour Limit Remaining at 25%' \"$TMP/err\""
run full --min-percent 50 >/dev/null 2>&1 || true
check 'the floor ignores the non-Gemini group' "! grep -q 'Claude and GPT' \"$TMP/err\""
rc=0; run exhausted --min-percent 1 >/dev/null 2>&1 || rc=$?
check 'an exhausted Gemini bucket trips the floor' "[ $rc -eq 3 ]"

# An unreadable allowance must never be reported as available headroom.
rc=0; run no_gemini_group --min-percent 50 >/dev/null 2>&1 || rc=$?
check 'a missing Gemini group fails the gate rather than passing it' "[ $rc -eq 1 ]"
rc=0; run missing_fraction --min-percent 50 >/dev/null 2>&1 || rc=$?
check 'an unmeasurable Gemini bucket fails the gate rather than passing it' "[ $rc -eq 1 ]"
run no_gemini_group --min-percent 50 >/dev/null 2>&1 || true
check 'the unreadable-gate error says the headroom was never measured' "grep -q 'never measured' \"$TMP/err\""

# --- provider and runtime faults --------------------------------------------
rc=0; run wrong_command >/dev/null 2>&1 || rc=$?
check 'a non-usage command response is rejected' "[ $rc -eq 1 ]"
rc=0; run not_success >/dev/null 2>&1 || rc=$?
check 'a non-SUCCESS response is rejected' "[ $rc -eq 1 ]"
rc=0; run garbage >/dev/null 2>&1 || rc=$?
check 'unparseable output is rejected' "[ $rc -eq 1 ]"
rc=0; run fail >/dev/null 2>&1 || rc=$?
check 'a failing agy run is reported, not silently empty' "[ $rc -eq 1 ]"
run fail >/dev/null 2>&1 || true
check 'the request failure message names the timeout budget' "grep -q 'failed or timed out' \"$TMP/err\""

# Every discovery path must be empty, including the Windows LOCALAPPDATA
# fallback, or this test silently exercises the real installed runtime.
JQ_DIR="$(dirname "$(command -v jq)")"
env -u LOCALAPPDATA AI_GEMINI_BIN="$TMP/bin/does-not-exist" PATH="$TMP/empty:$JQ_DIR:/usr/bin:/bin" HOME="$TMP/nohome" \
  "$SCRIPT" >/dev/null 2>"$TMP/err" || true
check 'a missing runtime is named a local dependency fault, not a provider fault' "grep -q local_dependency_unavailable \"$TMP/err\""

# --- argument handling ------------------------------------------------------
rc=0; "$SCRIPT" --min-percent abc >/dev/null 2>&1 || rc=$?
check 'a non-numeric floor is rejected' "[ $rc -eq 1 ]"
rc=0; "$SCRIPT" --min-percent 101 >/dev/null 2>&1 || rc=$?
check 'a floor above 100 is rejected' "[ $rc -eq 1 ]"
rc=0; "$SCRIPT" --min-percent >/dev/null 2>&1 || rc=$?
check 'a floor with no value is rejected' "[ $rc -eq 1 ]"
rc=0; "$SCRIPT" --nonsense >/dev/null 2>&1 || rc=$?
check 'an unknown flag exits 2' "[ $rc -eq 2 ]"
check '--help works without a runtime' "AI_GEMINI_BIN=$TMP/bin/does-not-exist \"$SCRIPT\" --help | grep -q min-percent"
check '--version works without a runtime' "AI_GEMINI_BIN=$TMP/bin/does-not-exist \"$SCRIPT\" --version | grep -q ai-gemini-usage"

# --- containment ------------------------------------------------------------
check 'the allowance query never asks for a conversation' "! grep -q -- '--conversation' \"$SCRIPT\""
check 'the allowance query never starts a project' "! grep -q -- '--new-project' \"$SCRIPT\""
check 'the allowance query never skips permissions' "! grep -q -- '--dangerously-skip-permissions' \"$SCRIPT\""
check 'the allowance query does not touch the review wrapper qualification' "! grep -q 'review-quarantine' \"$SCRIPT\""

printf '%s\n' "ai-gemini-usage: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
