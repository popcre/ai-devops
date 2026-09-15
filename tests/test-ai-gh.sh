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
  quota) if [ "$*" = "api rate_limit --jq [.resources.core.remaining,.resources.core.limit,.resources.core.reset]|@tsv" ]; then printf '%s\t5000\t%s\n' "$FAKE_REMAINING" $(( $(date +%s) + 1800 )); elif [ "$1 $2" = "api --include" ]; then printf 'HTTP/2.0 200 OK\r\nX-Ratelimit-Remaining: %s\r\nX-Github-Request-Id: F95F:TEST\r\n\r\n{}\n' "$FAKE_REMAINING"; else echo "out:$*"; fi ;;
  primary) if [ "$1 $2" = "api --include" ]; then printf 'HTTP/2.0 200 OK\nX-Ratelimit-Remaining: 0\nX-Ratelimit-Reset: %s\nX-Github-Request-Id: F95F:1E2E31\n' $(( $(date +%s) + 3000 )); elif [ "$1 $2" = "api rate_limit" ]; then printf '%s\t5000\t%s\n' "${FAKE_REMAINING:-4000}" $(( $(date +%s) + 3000 )); else echo 'gh: API rate limit exceeded for user ID 55610577. (HTTP 403) token ghp_abcdefSECRET123' >&2; exit 1; fi ;;
  counter) n=$(( $(cat "$FAKE_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_COUNT"; [ "$n" -ge 2 ] && echo '{"status":"completed"}' || echo '{"status":"in_progress"}' ;;
esac
echo "end $(date +%s%N)" >> "$FAKE_LOG"
EOF
chmod +x "$FAKE"
export AI_GH_REAL_GH="$FAKE" FAKE_LOG="$TMP/log" AI_GH_STATE_DIR="$TMP/state" AI_GH_MIN_SPACING_SECONDS=0 FAKE_COUNT="$TMP/count" AI_GH_QUOTA_PROBE_SECONDS=off

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

# Hourly (primary) budget.
rm -f "$TMP/state/quota"
FAKE_MODE=quota FAKE_REMAINING=3000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" pr view 2 > "$TMP/qout" 2>/dev/null; rc=$?
check 'healthy budget allows the call and caches quota' "[ $rc -eq 0 ] && grep -q 'out:pr view 2' '$TMP/qout' && grep -q ' 2999 5000 ' '$TMP/state/quota'"
rm -f "$TMP/state/quota"; : > "$FAKE_LOG"
FAKE_MODE=quota FAKE_REMAINING=900 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_NO_WAIT=1 "$GH" pr view 3 >/dev/null 2>&1; rc=$?
check 'budget below 20% pauses machine-wide without making the call' "[ $rc -eq 75 ] && ! grep -q 'pr view 3' '$FAKE_LOG' && [ \$(cat '$TMP/state/backoff_until') -gt \$(date +%s) ] && grep -q 'budget-pause remaining=900/5000' '$TMP/state/refusals.log'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"
before=$(date +%s)
FAKE_MODE=primary AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" pr list >/dev/null 2>&1; rc=$?
check 'primary limit refusal backs off until the window resets' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -ge $((before + 2900)) ] && grep -q 'kind=primary' '$TMP/state/refusals.log'"
check 'refusal log keeps the exact refusal text' "grep -q 'API rate limit exceeded for user ID 55610577' '$TMP/state/refusals.log'"
check 'failure log records status, headers and body' "grep -q 'status: HTTP 403' '$TMP/state/failures.log' && grep -qi 'x-ratelimit-remaining: 0' '$TMP/state/failures.log' && grep -q 'X-Github-Request-Id: F95F:1E2E31' '$TMP/state/failures.log'"
check 'failure and refusal logs redact credentials' "! grep -q 'ghp_abcdef' '$TMP/state/failures.log' '$TMP/state/refusals.log' && grep -q REDACTED '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until"
FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" api nope >/dev/null 2>&1
check 'ordinary failures are logged too' "grep -q 'args=api nope' '$TMP/state/failures.log' && grep -q 'HTTP 404: Not Found' '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"

# Stale lock is recovered by age; a young lock with a live-looking owner is not stolen.
mkdir -p "$TMP/state/lock.d"; echo "999999 $(( $(date +%s) - 400 )) tok" > "$TMP/state/lock.d/owner"
check 'abandoned lock older than the stale limit is recovered' "timeout 20 '$GH' z"
mkdir -p "$TMP/state/lock.d"; : > "$TMP/state/lock.d/owner"; touch -d '@'$(( $(date +%s) - 120 )) "$TMP/state/lock.d"
check 'lock with an empty owner record is recovered' "timeout 20 '$GH' z"
mkdir -p "$TMP/state/lock.d"; echo "999999 $(date +%s) other" > "$TMP/state/lock.d/owner"
AI_GH_NO_WAIT=1 AI_GH_NO_WAIT_LOCK_SECONDS=2 "$GH" z >/dev/null 2>&1; rc=$?
check 'a fresh lock is not stolen even if its pid looks dead; NO_WAIT gives up with 75' "[ $rc -eq 75 ] && grep -q other '$TMP/state/lock.d/owner'"
rm -rf "$TMP/state/lock.d"
check 'release never removes a lock owned by someone else' "grep -q 'TOKEN' '$GH' && grep -q 'quarantine' '$GH'"
check 'redaction covers Bearer and inline Authorization' "[ \"\$(printf 'args=api -H Authorization: Bearer eyJabc.def\n' | bash -c \"\$(grep '^redact()' '$GH'); redact\")\" = 'args=api -H Authorization: [REDACTED]' ] && [ \"\$(echo 'x Bearer eyJabc' | bash -c \"\$(grep '^redact()' '$GH'); redact\")\" = 'x Bearer [REDACTED]' ]"
: > "$FAKE_LOG"; rm -f "$TMP/state/backoff_until"
FAKE_MODE=secondary AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" pr view 9 >/dev/null 2>&1
check 'no header snapshot request after a secondary refusal' "! grep -q 'api --include' '$FAKE_LOG'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"

# ai-gh-wait
AI_DEVOPS_TEST_MODE=0 "$WAIT" --until-regex x --interval 60 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait refuses an interval below 300 seconds' "[ $rc -eq 3 ]"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 FAKE_MODE=counter "$WAIT" --until-regex completed --interval 1 --timeout-minutes 1 -- run view 1 > "$TMP/wout" 2>/dev/null; rc=$?
check 'wait exits 0 when the state matches' "[ $rc -eq 0 ] && grep -q completed '$TMP/wout' && [ \$(cat '$FAKE_COUNT') -eq 2 ]"
check 'wait default interval is at least 300 seconds' "grep -q '^INTERVAL=300' '$WAIT' && grep -q '^MIN=300' '$WAIT'"
check 'ai-pr-wait routes through the throttle' "grep -q 'ai-gh' '$ROOT/bin/ai-pr-wait'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
