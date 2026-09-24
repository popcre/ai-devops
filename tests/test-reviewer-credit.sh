#!/usr/bin/env bash
# Offline tests for the shared out-of-credit classifier (Albert, 2026-09-24):
# a reviewer run that fails for lack of paid credit must say so in that run.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PY="$(command -v python3 || command -v python)"
TOOL="$ROOT/tools/reviewer_admission.py"
FIX="$ROOT/tests/fixtures/reviewer-credit"
Q="$TMP/quarantine"

classify() { # PROVIDER FILE... -> stdout lines, status
  local provider="$1"; shift
  local -a scan=(); local f
  for f in "$@"; do scan+=(--scan "$f"); done
  "$PY" "$TOOL" credit "$provider" --directory "$Q" "${scan[@]}" --record
}

echo '== reviewer credit classifier'
for pair in grok:grok-xai-403.stderr muse:muse-insufficient-quota.jsonl qwen:qwen-arrearage.jsonl gemini:gemini-prepay.json deepseek:deepseek-402.json; do
  provider="${pair%%:*}"; file="$FIX/${pair#*:}"
  out="$(classify "$provider" "$file")"; rc=$?
  check "$provider fixture is classified as out of credit" "[ '$rc' = 0 ]"
  check "$provider prints the exact machine line" "printf '%s\n' \"\$(printf '%s' '$(printf '%s' "$out" | sed -n 1p)')\" | grep -qx 'AI_REVIEWER_OUT_OF_CREDIT provider=$provider code=insufficient_quota'"
  human="$(printf '%s\n' "$out" | sed -n 2p)"
  check "$provider human line names the provider and is ASCII, 10-300 chars" \
    "printf '%s' '$human' | grep -q '^OUT OF CREDIT: ' && [ \"\$(printf '%s' '$human' | LC_ALL=C tr -d '\040-\176' | wc -c)\" -eq 0 ] && [ ${#human} -ge 10 ] && [ ${#human} -le 300 ]"
  check "$provider quarantine is recorded as out-of-credit" \
    "\"$PY\" \"$TOOL\" global $provider --directory '$Q' | jq -e '.failure_class==\"out-of-credit\" and .expires_epoch > .created_epoch'"
done

rm -rf "$Q"
out="$(classify grok "$FIX/negative-rate-limit.txt")"; rc=$?
check "rate limits and bare RESOURCE_EXHAUSTED are not credit failures" "[ '$rc' = 3 ] && [ -z '$out' ]"
out="$(classify gemini "$ROOT/tests/fixtures/ai-gemini/quota-error.json")"; rc=$?
check "the existing Gemini quota fixture is not a credit failure" "[ '$rc' = 3 ]"
check "no quarantine is recorded without a match" "[ \"\$(\"$PY\" \"$TOOL\" global grok --directory '$Q')\" = null ]"
out="$(classify grok "$TMP/missing-file")"; rc=$?
check "missing evidence is no match, not an error" "[ '$rc' = 3 ]"
check "an unsupported provider is refused" "! \"$PY\" \"$TOOL\" credit kimi --directory '$Q' --scan '$FIX/deepseek-402.json' >/dev/null 2>&1"
check "the classifier source has no control characters" "! LC_ALL=C grep -q '[[:cntrl:]]' <(tr -d '\r\t\n' < '$TOOL')"
for phrase in 'Payment Required' 'out of credits.' 'monthly spending limit'; do
  printf '%s\n' "$phrase" > "$TMP/phrase.txt"
  classify grok "$TMP/phrase.txt" >/dev/null; rc=$?
  check "each signature matches on its own: $phrase" "[ '$rc' = 0 ]"
done
for phrase in 'Arrearage' 'FreeTierOnly' 'OUT_OF_SERVICE'; do
  printf '%s\n' "$phrase" > "$TMP/phrase.txt"
  classify qwen "$TMP/phrase.txt" >/dev/null; rc=$?
  check "a Qwen status code matches for Qwen: $phrase" "[ '$rc' = 0 ]"
  rm -rf "$Q"; classify grok "$TMP/phrase.txt" >/dev/null; rc=$?
  check "a Qwen status code is not a credit failure for another provider: $phrase" "[ '$rc' = 3 ]"
done
printf 'insufficient_quota\n' > "$TMP/phrase.txt"
rm -rf "$Q"; classify qwen "$TMP/phrase.txt" >/dev/null; rc=$?
check "insufficient_quota is not a credit failure for Qwen" "[ '$rc' = 3 ]"
MUSE_FILTER="$(grep -o "jq -c '[^']*'" "$ROOT/bin/ai-muse" | grep 'terminal\[' | head -1 | sed "s/^jq -c '//; s/'\$//")"
LONG="$(head -c 600 /dev/zero | tr '\0' 'r') out of credits"
{ jq -cn '{payload_type:"run.terminal.failed",payload:{terminal:"failed",text:"Error: insufficient_quota"}}'
  jq -cn --arg t "$LONG" '{payload_type:"run.terminal.failed",payload:{terminal:"failed",text:$t}}'; } | jq -c "$MUSE_FILTER" > "$TMP/muse-ev.txt"
check "muse scans a short terminal failure message" "grep -q insufficient_quota '$TMP/muse-ev.txt'"
check "muse does not scan a long partial review in a terminal failure" "! grep -q 'out of credits' '$TMP/muse-ev.txt'"
for phrase in 'Your account is in good standing.' 'Prepayment credits are available for this project.'; do
  printf '%s\n' "$phrase" > "$TMP/phrase.txt"
  classify grok "$TMP/phrase.txt" >/dev/null; rc=$?
  check "a positive billing statement is not a credit failure: $phrase" "[ '$rc' = 3 ]"
done

# A quarantine write failure must never hide the diagnosis or change the code.
printf 'not a directory' > "$TMP/blocked"
out="$("$PY" "$TOOL" credit deepseek --directory "$TMP/blocked/q" --scan "$FIX/deepseek-402.json" --record 2>/dev/null)"; rc=$?
check "an unwritable quarantine still reports the credit failure" "[ '$rc' = 0 ] && printf '%s' '$out' | grep -q '^AI_REVIEWER_OUT_OF_CREDIT provider=deepseek'"

# Only the tail is read, so a huge log cannot stall the stop.
{ head -c 3000000 /dev/zero | tr '\0' 'x'; printf '\n'; cat "$FIX/grok-xai-403.stderr"; } > "$TMP/big.err"
out="$(classify grok "$TMP/big.err")"; rc=$?
check "a match at the end of a large log is found" "[ '$rc' = 0 ]"
{ cat "$FIX/grok-xai-403.stderr"; head -c 3000000 /dev/zero | tr '\0' 'x'; } > "$TMP/old.err"
rm -rf "$Q"; out="$(classify grok "$TMP/old.err")"; rc=$?
check "an old match beyond the scanned tail is ignored" "[ '$rc' = 3 ]"

echo '== shared shell stop'
cat > "$TMP/stop.sh" <<EOF
source '$ROOT/tools/reviewer_event_guard.sh'
reviewer_credit_stop "\$@"
echo not-stopped
exit 1
EOF
AI_REVIEW_QUARANTINE_DIR="$Q" bash "$TMP/stop.sh" muse "$FIX/muse-insufficient-quota.jsonl" > "$TMP/stop.out" 2> "$TMP/stop.err"; rc=$?
check "the wrapper stop exits 92 on a credit failure" "[ '$rc' = 92 ]"
check "the wrapper stop prints both contract lines on stderr" "grep -qx 'AI_REVIEWER_OUT_OF_CREDIT provider=muse code=insufficient_quota' '$TMP/stop.err' && grep -q '^OUT OF CREDIT: .*dev.meta.ai' '$TMP/stop.err' && ! grep -q not-stopped '$TMP/stop.out'"
AI_REVIEW_QUARANTINE_DIR="$Q" bash "$TMP/stop.sh" muse "$FIX/negative-rate-limit.txt" > "$TMP/stop.out" 2> "$TMP/stop.err"; rc=$?
check "the wrapper stop is a no-op without a credit failure" "[ '$rc' = 1 ] && grep -q not-stopped '$TMP/stop.out' && [ ! -s '$TMP/stop.err' ]"

echo '== live health probes report credit failures too'
check "grok doctor live probe stops on a credit failure" "grep -A2 'FAILED — no terminal JSON' '$ROOT/bin/ai-grok-review' | grep -q 'grok_credit_scan \"\$RUN_TURN_RC\" \"\$tmp\"'"
check "muse doctor live probe stops on a credit failure" "grep 'run_turn \"\$fixture\"' '$ROOT/bin/ai-muse' | grep -q 'muse_credit_stop \"\$out\"'"
check "qwen doctor live probe stops on a credit failure" "grep -q 'reviewer_credit_scan qwen \"\$tmp.err\" \"\$tmp.credit\"' '$ROOT/bin/ai-qwen'"

echo '== preflight reports the provider unusable'
PREFLIGHT="$ROOT/bin/ai-review-preflight"
check "preflight explains the out-of-credit class" "bash '$PREFLIGHT' explain out-of-credit | grep -q 'Tell Albert in this same reply'"
check "preflight classifies billing text as out-of-credit" "bash -c 'source <(sed -n \"/^classify_failure()/,/^}/p\" \"$PREFLIGHT\"); [ \"\$(classify_failure \"Insufficient Balance\")\" = out-of-credit ] && [ \"\$(classify_failure \"429 rate limit\")\" = allowance-exhausted ] && [ \"\$(classify_failure \"HTTP 403 monthly spending limit\")\" = out-of-credit ] && [ \"\$(classify_failure \"403 out of credits\")\" = out-of-credit ]'"
check "preflight holds an out-of-credit doctor failure for the classifier's hour" "grep -q 'class\" != out-of-credit ] || seconds=3600' '$PREFLIGHT'"
AI_REVIEW_QUARANTINE_DIR="$Q" bash "$TMP/stop.sh" deepseek "$FIX/deepseek-402.json" >/dev/null 2>&1
check "preflight clear removes the out-of-credit quarantine" "AI_REVIEW_QUARANTINE_DIR='$Q' bash '$PREFLIGHT' clear deepseek >/dev/null 2>&1 && [ \"\$(\"$PY\" \"$TOOL\" global deepseek --directory '$Q')\" = null ]"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
