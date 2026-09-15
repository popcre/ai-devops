#!/usr/bin/env bash
# Tests for bin/ai-gh (machine-wide GitHub throttle) and bin/ai-gh-wait.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; GH="$ROOT/bin/ai-gh"; WAIT="$ROOT/bin/ai-gh-wait"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/fake-gh"
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
echo "start $(date +%s%N) $*" >> "$FAKE_LOG"
case "${FAKE_MODE:-ok}" in
  ok) sleep "${FAKE_SLEEP:-0}"; echo "out:$*" ;;
  secondary) echo 'HTTP 403: You have exceeded a secondary rate limit. Please wait a few minutes before you try again.' >&2; echo 'Retry-After: 900' >&2; echo "end $(date +%s%N)" >> "$FAKE_LOG"; exit 1 ;;
  secondary-short) echo 'gh: HTTP 429: Too Many Requests (retry-after: 60)' >&2; exit 1 ;;
  notfound) echo 'HTTP 404: Not Found' >&2; exit 1 ;;
  counter) n=$(( $(cat "$FAKE_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_COUNT"; [ "$n" -ge 2 ] && echo '{"status":"completed"}' || echo '{"status":"in_progress"}' ;;
esac
echo "end $(date +%s%N)" >> "$FAKE_LOG"
EOF
chmod +x "$FAKE"
export AI_GH_REAL_GH="$FAKE" FAKE_LOG="$TMP/log" AI_GH_STATE_DIR="$TMP/state" AI_GH_MIN_SPACING_SECONDS=0 FAKE_COUNT="$TMP/count"

check 'passes arguments and output through' "[ \"\$('$GH' pr view 5)\" = 'out:pr view 5' ]"
check 'gh run watch is refused without calling GitHub' "! '$GH' run watch 12 && ! grep -q 'run watch' '$FAKE_LOG'"
"$GH" run watch 12 >/dev/null 2>&1; check 'run watch exits 2' "[ $? -eq 2 ]"
"$GH" pr checks 3 --watch >/dev/null 2>&1; check '--watch flag exits 2' "[ $? -eq 2 ]"
FAKE_MODE=notfound "$GH" api x >/dev/null 2>&1; rc=$?
check 'ordinary failure keeps gh status and records no back-off' "[ $rc -eq 1 ] && [ ! -s '$TMP/state/backoff_until' ]"

# Spacing across calls.
: > "$FAKE_LOG"
AI_GH_MIN_SPACING_SECONDS=2 "$GH" a >/dev/null; AI_GH_MIN_SPACING_SECONDS=2 "$GH" b >/dev/null
s1=$(awk '/^start/{print $2}' "$FAKE_LOG" | sed -n 1p); s2=$(awk '/^start/{print $2}' "$FAKE_LOG" | sed -n 2p)
check 'calls are spaced by the minimum interval' "[ $(( (s2 - s1) / 1000000 )) -ge 1000 ]"

# Serialization across concurrent processes: no two fake calls overlap.
: > "$FAKE_LOG"
for i in 1 2 3; do FAKE_SLEEP=1 "$GH" p$i >/dev/null & done; wait
check 'concurrent processes never overlap GitHub calls' "awk '/^start/{if(open){exit 1} open=1} /^end/{open=0}' '$FAKE_LOG' && [ \$(grep -c '^start' '$FAKE_LOG') -eq 3 ]"
check 'lock is released after calls' "[ ! -d '$TMP/state/lock.d' ]"

# Secondary rate limit: back-off uses Retry-After, no retry, and blocks later calls.
: > "$FAKE_LOG"
before=$(date +%s)
FAKE_MODE=secondary "$GH" api repos/x >/dev/null 2>"$TMP/err"; rc=$?
check 'secondary limit exits 75' "[ $rc -eq 75 ]"
check 'refused call is not retried' "[ \$(grep -c '^start' '$FAKE_LOG') -eq 1 ]"
check 'back-off honours Retry-After 900' "[ \$(cat '$TMP/state/backoff_until') -ge $((before + 900)) ]"
check 'refusal is logged' "grep -q 'retry_after=900' '$TMP/state/refusals.log'"
AI_GH_NO_WAIT=1 "$GH" pr view 1 >/dev/null 2>&1; rc=$?
check 'during back-off NO_WAIT exits 75 without calling GitHub' "[ $rc -eq 75 ] && [ \$(grep -c '^start' '$FAKE_LOG') -eq 1 ]"
rm -f "$TMP/state/backoff_until"
before=$(date +%s)
FAKE_MODE=secondary-short "$GH" api y >/dev/null 2>&1; rc=$?
check 'short Retry-After is raised to the 600s floor' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -ge $((before + 600)) ]"
rm -f "$TMP/state/backoff_until"

# Stale lock from a dead process is recovered.
mkdir -p "$TMP/state/lock.d"; echo "999999 $(( $(date +%s) - 60 ))" > "$TMP/state/lock.d/owner"
check 'abandoned lock from a dead process is recovered' "timeout 20 '$GH' z"

# ai-gh-wait
AI_DEVOPS_TEST_MODE=0 "$WAIT" --until-regex x --interval 60 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait refuses an interval below 300 seconds' "[ $rc -eq 3 ]"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 FAKE_MODE=counter "$WAIT" --until-regex completed --interval 1 --timeout-minutes 1 -- run view 1 > "$TMP/wout" 2>/dev/null; rc=$?
check 'wait exits 0 when the state matches' "[ $rc -eq 0 ] && grep -q completed '$TMP/wout' && [ \$(cat '$FAKE_COUNT') -eq 2 ]"
check 'wait default interval is at least 300 seconds' "grep -q '^INTERVAL=300' '$WAIT' && grep -q '^MIN=300' '$WAIT'"
check 'ai-pr-wait routes through the throttle' "grep -q 'ai-gh' '$ROOT/bin/ai-pr-wait'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
