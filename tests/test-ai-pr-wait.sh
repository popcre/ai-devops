#!/usr/bin/env bash
# test-ai-pr-wait.sh — bin/ai-pr-wait exists, refuses bad input, and is the only
# way this repository waits on a pull request.
#
# The failure being guarded: a session that hand-rolls `gh pr view <n> --json
# state` in a loop cannot see a merge-queue ejection, because an ejected pull
# request stays OPEN. On 2026-08-28 that wasted about five hours on PR #142.
# These checks run offline; nothing here contacts GitHub.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$ROOT/bin/ai-pr-wait"
pass=0; fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; pass=$(( pass + 1 ))
  else printf '  FAIL %s\n' "$1"; fail=$(( fail + 1 )); fi
}

check "the pull-request waiter exists and is executable" "test -x '$CMD'"
check "it parses as valid bash" "bash -n '$CMD'"

OUT="$(bash "$CMD" 2>&1)"; RC=$?
check "a missing pull request number is refused, not waited on" \
  "test '$RC' -eq 3 && printf '%s' \"$OUT\" | grep -q 'pull request number'"

OUT="$(bash "$CMD" not-a-number 2>&1)"; RC=$?
check "a non-numeric pull request number is refused" "test '$RC' -eq 3"

OUT="$(bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 0 2>&1)"; RC=$?
check "a zero deadline is refused" "test '$RC' -eq 3 && printf '%s' \"$OUT\" | grep -q 'positive whole number'"
OUT="$(bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 00 2>&1)"; RC=$?
check "a zero-prefixed zero deadline is refused" "test '$RC' -eq 3"
OUT="$(bash "$CMD" 1 --repo popcre/ai-devops --interval 00 2>&1)"; RC=$?
check "a zero-prefixed zero interval is refused" "test '$RC' -eq 3"
OUT="$(bash "$CMD" 1 --repo popcre/ai-devops --api-timeout-seconds 00 2>&1)"; RC=$?
check "a zero-prefixed API timeout is refused" "test '$RC' -eq 3"
for OPTION in --repo --timeout-minutes --interval --api-timeout-seconds; do
  OUT="$(bash "$CMD" 1 "$OPTION" 2>&1)"; RC=$?
  check "$OPTION without a value is refused immediately" \
    "test '$RC' -eq 3 && printf '%s' \"$OUT\" | grep -q 'requires a value'"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -le 2 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date"
check "fixture resolves its exact gh stub" \
  "test \"$(PATH="$TMP/bin:$PATH" command -v gh)\" = '$TMP/bin/gh'"
OUT="$(AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 60 2>&1)"; RC=$?
check "repeated API failure still exits at the deadline" \
  "test '$RC' -eq 2 && printf '%s' \"$OUT\" | grep -q 'could not be read before the 1m deadline'"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
: > "${AI_PR_WAIT_TEST_MARKER:?}"
sleep 300
EOF
rm -f "$TMP/clock"
SECONDS=0
OUT="$(AI_DEVOPS_TEST_MODE=1 AI_PR_WAIT_TEST_TRACE="$TMP/hung-trace" AI_PR_WAIT_TEST_MARKER="$TMP/hung-called" AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 60 --api-timeout-seconds 1 2>&1)"; RC=$?
ELAPSED=$SECONDS
check "a hung GitHub request is killed inside the overall deadline" \
  "test -f '$TMP/hung-called' && test '$RC' -eq 2 && test '$ELAPSED' -lt 5 && printf '%s' \"$OUT\" | grep -q 'could not be read before the 1m deadline'"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
: > "${AI_PR_WAIT_TEST_MARKER:?}"
printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"MERGED","isInMergeQueue":false,"mergeCommit":{"oid":"abc123"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS","contexts":{"nodes":[]}}}}]}}}}}'
EOF
rm -f "$TMP/clock"
SECONDS=0
OUT="$(AI_DEVOPS_TEST_MODE=1 AI_PR_WAIT_TEST_TRACE="$TMP/fast-trace" AI_PR_WAIT_TEST_MARKER="$TMP/fast-called" AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --api-timeout-seconds 5 2>&1)"; RC=$?
ELAPSED=$SECONDS
[ "$RC" -eq 0 ] || printf '  diagnostic: fast request rc=%s elapsed=%ss resolved=%s child=%s stderr=%s output=%s\n' "$RC" "$ELAPSED" "$(cat "$TMP/fast-trace.resolved" 2>/dev/null || printf missing)" "$(cat "$TMP/fast-trace.child" 2>/dev/null || printf missing)" "$(cat "$TMP/fast-trace.stderr" 2>/dev/null || printf missing)" "$OUT" >&2
check "a fast successful request returns without an orphan timer" \
  "test -f '$TMP/fast-called' && test '$RC' -eq 0 && test '$ELAPSED' -lt 5 && printf '%s' \"$OUT\" | grep -q 'MERGED  merge commit abc123' && ! grep -q '( sleep \"\$limit\"' '$CMD'"

check "it exits on an ejection instead of waiting" \
  "grep -q 'EJECTED from the merge queue' '$CMD'"
check "it exits on a failing check instead of waiting" \
  "grep -q 'failing checks and will not merge' '$CMD'"
check "it has its own deadline so it can never wait forever" \
  "grep -q 'giving up rather than waiting silently' '$CMD'"
check "it warns that a CANCELLED check is usually a job timeout" \
  "grep -q 'usually a job timeout' '$CMD'"

# The guard that actually prevents a repeat: no other file may hand-roll the
# blind wait loop. Matches a `gh pr view ... state` inside a shell loop.
STRAYS="$(cd "$ROOT" && git grep -l -E "gh pr view[^\\n]*--json[^\\n]*state" -- \
  ':!tests/test-ai-pr-wait.sh' ':!bin/ai-pr-wait' ':!*.md' 2>/dev/null | \
  while read -r f; do grep -qE '^\s*(while|until)\b' "$f" && printf '%s ' "$f"; done)"
check "nothing else in the repository hand-rolls a pull-request wait loop" \
  "test -z '$STRAYS'"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
