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
PYTHON_RUNNER=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))' >/dev/null 2>&1; then PYTHON_RUNNER="$(command -v "$candidate")"; break; fi
done
[ -n "$PYTHON_RUNNER" ] || { printf 'Python 3.10 or newer is required\n' >&2; exit 2; }
# The wait behaviour below is what these cases are about, so the task gate is
# switched off for them and exercised on its own at the end of this file.
export AI_DEVOPS_TEST_MODE=1
export AI_TASK_GATES_MODE=none
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

case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*) export TMPDIR="$HOME" ;;
esac
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ -z "${AI_PR_WAIT_TEST_MARKER:-}" ] || : > "$AI_PR_WAIT_TEST_MARKER"
exit 1
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -le 3 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date"
check "fixture resolves its exact gh stub" \
  "test \"$(PATH="$TMP/bin:$PATH" command -v gh)\" = '$TMP/bin/gh'"
mkdir -p "$TMP/no-throttle"
cp "$CMD" "$TMP/no-throttle/ai-pr-wait"
OUT="$(AI_PR_WAIT_TEST_MARKER="$TMP/no-throttle-called" PATH="$TMP/bin:$PATH" bash "$TMP/no-throttle/ai-pr-wait" 1 --repo popcre/ai-devops 2>&1)"; RC=$?
check "a missing throttle refuses the wait before any direct gh call" \
  "test '$RC' -eq 3 && printf '%s' \"$OUT\" | grep -q 'ai-gh throttle is missing; no GitHub call was made' && test ! -e '$TMP/no-throttle-called'"
OUT="$(AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 60 2>&1)"; RC=$?
check "repeated API failure still exits at the deadline" \
  "test '$RC' -eq 2 && printf '%s' \"$OUT\" | grep -q 'could not be read before the 1m deadline'"

# A recorded machine-wide back-off: the throttle exits 75 without calling GitHub,
# and ai-pr-wait treats it as temporary and gives up only at its deadline.
mkdir -p "$TMP/bo-state"; echo $(( $(date +%s) + 3600 )) > "$TMP/bo-state/backoff_until"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
: > "${AI_PR_WAIT_TEST_MARKER:?}"
echo '{}'
EOF
chmod +x "$TMP/bin/gh"; rm -f "$TMP/clock" "$TMP/bo-called"
OUT="$(AI_DEVOPS_TEST_MODE=1 AI_GH_STATE_DIR="$TMP/bo-state" AI_PR_WAIT_TEST_MARKER="$TMP/bo-called" AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 60 2>&1)"; RC=$?
check "a throttle back-off (exit 75) is temporary: GitHub is not called and the wait ends at its deadline" \
  "test ! -e '$TMP/bo-called' && test '$RC' -eq 2 && printf '%s' \"$OUT\" | grep -q 'transient'"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
count="$(cat "${AI_PR_WAIT_TEST_MARKER:?}" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$AI_PR_WAIT_TEST_MARKER"
if [ "$count" -eq 1 ]; then
  printf '%s\n' 'temporary upstream reset' >&2
  exit 1
fi
printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"MERGED","isInMergeQueue":false,"mergeCommit":{"oid":"retry123"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS","contexts":{"nodes":[]}}}}]}}}}}'
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
printf '1000\n'
EOF
cat > "$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date" "$TMP/bin/sleep"
rm -f "$TMP/transient-called"
OUT="$(AI_DEVOPS_TEST_MODE=1 AI_PR_WAIT_TEST_TRACE="$TMP/transient-trace" AI_PR_WAIT_TEST_MARKER="$TMP/transient-called" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 2>&1)"; RC=$?
check "a transient read reports its cause and elapsed time, then recovers" \
  "test '$RC' -eq 0 && test \"$(cat "$TMP/transient-called")\" -eq 2 && printf '%s' \"$OUT\" | grep -q 'after [0-9][0-9]*s (transient: temporary upstream reset); retrying' && printf '%s' \"$OUT\" | grep -q 'MERGED  merge commit retry123' && ! printf '%s' \"$OUT\" | grep -q 'deadline - giving up'"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
: > "${AI_PR_WAIT_TEST_MARKER:?}"
sleep 300
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -le 3 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
rm -f "$TMP/bin/sleep"
rm -f "$TMP/clock"
SECONDS=0
OUT="$(AI_DEVOPS_TEST_MODE=1 AI_PR_WAIT_TEST_TRACE="$TMP/hung-trace" AI_PR_WAIT_TEST_MARKER="$TMP/hung-called" AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 60 --api-timeout-seconds 1 2>&1)"; RC=$?
ELAPSED=$SECONDS
check "a hung GitHub request is killed inside the overall deadline" \
  "test -f '$TMP/hung-called' && test '$RC' -eq 2 && test '$ELAPSED' -lt 5 && printf '%s' \"$OUT\" | grep -q 'could not be read before the 1m deadline'"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
: > "${AI_PR_WAIT_TEST_MARKER:?}"
printf '%s\n' "${AI_GH_CALLER:-unset}" > "$AI_PR_WAIT_TEST_TRACE.caller"
printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"MERGED","isInMergeQueue":false,"mergeCommit":{"oid":"abc123"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS","contexts":{"nodes":[]}}}}]}}}}}'
EOF
rm -f "$TMP/clock"
SECONDS=0
OUT="$(AI_DEVOPS_TEST_MODE=1 AI_PR_WAIT_TEST_TRACE="$TMP/fast-trace" AI_PR_WAIT_TEST_MARKER="$TMP/fast-called" AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --api-timeout-seconds 5 2>&1)"; RC=$?
ELAPSED=$SECONDS
[ "$RC" -eq 0 ] || printf '  diagnostic: fast request rc=%s elapsed=%ss resolved=%s child=%s stderr=%s output=%s\n' "$RC" "$ELAPSED" "$(cat "$TMP/fast-trace.resolved" 2>/dev/null || printf missing)" "$(cat "$TMP/fast-trace.child" 2>/dev/null || printf missing)" "$(cat "$TMP/fast-trace.stderr" 2>/dev/null || printf missing)" "$OUT" >&2
check "a fast successful request returns without an orphan timer" \
  "test -f '$TMP/fast-called' && test '$RC' -eq 0 && test '$ELAPSED' -lt 5 && printf '%s' \"$OUT\" | grep -q 'MERGED  merge commit abc123' && ! grep -q '( sleep \"\$limit\"' '$CMD'"
check "PR waiter labels only its GitHub transport invocation" \
  "grep -qx ai-pr-wait '$TMP/fast-trace.caller' && ! grep -Eq '^ *export .*AI_GH_CALLER=' '$CMD'"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
count="$(cat "${AI_PR_WAIT_TEST_MARKER:?}" 2>/dev/null || printf 0)"
printf '%s\n' "$(( count + 1 ))" > "$AI_PR_WAIT_TEST_MARKER"
printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"OPEN","headRefOid":"abc123","isInMergeQueue":false,"mergeCommit":null,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false,"startCursor":null},"nodes":[]}}}}]}}}}}'
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -le 4 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
cat > "$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date" "$TMP/bin/sleep"
rm -f "$TMP/clock" "$TMP/deadline-called"
OUT="$(AI_PR_WAIT_TEST_MARKER="$TMP/deadline-called" AI_PR_WAIT_TEST_CLOCK="$TMP/clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 60 2>&1)"; RC=$?
check "deadline after a proven pending read is not mislabeled as an API failure" \
  "test '$RC' -eq 2 && test \"$(cat "$TMP/deadline-called")\" -eq 1 && printf '%s' \"$OUT\" | grep -q 'still in progress after 1m' && ! printf '%s' \"$OUT\" | grep -q 'could not read PR'"

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

# --------------------------------------------------------------------------
# Task gate. A documentation-only pull request must not start a long wait at
# all, and the owner may still ask for one.
# --------------------------------------------------------------------------
GR="$TMP/gated"; mkdir -p "$GR"; git -C "$GR" init -q --initial-branch=main
git -C "$GR" config user.name Test; git -C "$GR" config user.email t@example.com
git -C "$GR" remote add origin 'https://github.com/popcre/ai-devops.git'
printf 'base\n' > "$GR/README.md"; git -C "$GR" add -A; git -C "$GR" commit -qm init
printf 'a note\n' > "$GR/docs.md"
export AI_TASK_GATES_DIR="$TMP/gates"
( cd "$GR" && "$ROOT/bin/ai-task-gates" start --class prose --reason 'documentation only' ) >/dev/null 2>&1

# The refusal text carries backticks, so it is kept in a file rather than in a
# shell variable the check would re-expand.
GATE_OUT="$TMP/gate-refusal.txt"
( cd "$GR" && AI_TASK_GATES_MODE=standard bash "$CMD" 1 --repo popcre/ai-devops ) >"$GATE_OUT" 2>&1; RC=$?
check "a documentation-only pull request does not start a long wait" "test '$RC' -eq 3"
check "the refusal names the admin squash merge instead" \
  "grep -qF -- 'gh pr merge --squash --admin' '$GATE_OUT'"
check "the refusal explains which gate applied" \
  "grep -q ai-task-gates '$GATE_OUT'"

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-reviewer-approval.sh"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/review-lifecycle"
LIB_REVIEWER_APPROVAL_BIN="$ROOT/bin"
appr_file(){ mint_reviewer_approval "$TMP" "$1" plan-review; }
WAIT_APPROVAL="$(appr_file "$GR" pr-wait "$ROOT/bin/ai-task-gates")"
OUT="$( cd "$GR" && AI_TASK_GATES_MODE=standard bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 0 --reviewer-approval "$WAIT_APPROVAL" 2>&1 )"; RC=$?
check "a reviewer-approved wait passes the gate and reaches the normal checks" \
  "test '$RC' -eq 3 && printf '%s' \"$OUT\" | grep -q 'positive whole number'"

printf 'select 1;\n' > "$GR/migration.sql"
OUT="$( cd "$GR" && AI_TASK_GATES_MODE=standard bash "$CMD" 1 --repo popcre/ai-devops 2>&1 )"; RC=$?
check "work that outgrew its declared class still refuses the wait" \
  "test '$RC' -eq 3 && printf '%s' \"$OUT\" | grep -q migration.sql"
rm -f "$GR/migration.sql"

# Two independent waiters start together on one PR. The shared first status
# response is OPEN, and each retains its own deadline result.
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'x\n' >> "${AI_PR_WAIT_TEST_MARKER:?}"
/bin/sleep 0.3
printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"OPEN","headRefOid":"shared-head","isInMergeQueue":false,"mergeCommit":null,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false,"startCursor":null},"nodes":[]}}}}]}}}}}'
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -le 3 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date"
rm -f "$TMP/shared-calls" "$TMP/shared-clock-a" "$TMP/shared-clock-b"
AI_TASK_GATES_MODE=none AI_PR_WAIT_TEST_CONTEXT_KEY='host credential principal scopes-a' \
  AI_PR_WAIT_SNAPSHOT_DIR="$TMP/pr-status" AI_GH_STATE_DIR="$TMP/shared-throttle" \
  AI_PR_WAIT_TEST_MARKER="$TMP/shared-calls" AI_PR_WAIT_TEST_CLOCK="$TMP/shared-clock-a" \
  PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 >"$TMP/shared-a.out" 2>&1 & shared_a=$!
AI_TASK_GATES_MODE=none AI_PR_WAIT_TEST_CONTEXT_KEY='host credential principal scopes-a' \
  AI_PR_WAIT_SNAPSHOT_DIR="$TMP/pr-status" AI_GH_STATE_DIR="$TMP/shared-throttle" \
  AI_PR_WAIT_TEST_MARKER="$TMP/shared-calls" AI_PR_WAIT_TEST_CLOCK="$TMP/shared-clock-b" \
  PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 >"$TMP/shared-b.out" 2>&1 & shared_b=$!
wait "$shared_a"; shared_a_rc=$?
wait "$shared_b"; shared_b_rc=$?
check "two simultaneous first waiters share one complete upstream read and keep independent deadlines" \
  "test '$shared_a_rc' -eq 2 && test '$shared_b_rc' -eq 2 && test \"\$(wc -l < '$TMP/shared-calls')\" -eq 1 && grep -q 'still in progress' '$TMP/shared-a.out' && grep -q 'still in progress' '$TMP/shared-b.out'"

# After both waiters have seen queue membership, their next concurrent demand
# must use one fresh complete response. Each still decides its own terminal
# result; a queued snapshot from the previous poll cannot prove ejection.
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'x\n' >> "${AI_PR_WAIT_TEST_MARKER:?}"
count="$(wc -l < "$AI_PR_WAIT_TEST_MARKER")"
/bin/sleep 0.3
if [ "$count" -eq 1 ]; then
  state=OPEN; queued=true; merge=null
else
  state="${AI_PR_WAIT_TEST_TERMINAL:?}"; queued=false; merge=null
  [ "$state" != MERGED ] || merge='{"oid":"done"}'
  [ "$state" != EJECTED ] || state=OPEN
fi
printf '{"data":{"repository":{"pullRequest":{"state":"%s","headRefOid":"h1","isInMergeQueue":%s,"mergeCommit":%s,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false,"startCursor":null},"nodes":[]}}}}]}}}}}\n' "$state" "$queued" "$merge"
EOF
cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -lt 40 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
cat > "$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
/bin/sleep 0.1
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date" "$TMP/bin/sleep"
for terminal in MERGED CLOSED EJECTED; do
  rm -f "$TMP/queued-$terminal-calls" "$TMP/queued-$terminal-a.clock" "$TMP/queued-$terminal-b.clock"
  AI_PR_WAIT_TEST_CONTEXT_KEY='host credential principal scopes-a' \
    AI_PR_WAIT_SNAPSHOT_DIR="$TMP/queued-$terminal-snapshots" AI_GH_STATE_DIR="$TMP/queued-$terminal-throttle" \
    AI_PR_WAIT_TEST_TERMINAL="$terminal" AI_PR_WAIT_TEST_MARKER="$TMP/queued-$terminal-calls" \
    AI_PR_WAIT_TEST_CLOCK="$TMP/queued-$terminal-a.clock" PATH="$TMP/bin:$PATH" \
    bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 >"$TMP/queued-$terminal-a.out" 2>&1 & queued_a=$!
  AI_PR_WAIT_TEST_CONTEXT_KEY='host credential principal scopes-a' \
    AI_PR_WAIT_SNAPSHOT_DIR="$TMP/queued-$terminal-snapshots" AI_GH_STATE_DIR="$TMP/queued-$terminal-throttle" \
    AI_PR_WAIT_TEST_TERMINAL="$terminal" AI_PR_WAIT_TEST_MARKER="$TMP/queued-$terminal-calls" \
    AI_PR_WAIT_TEST_CLOCK="$TMP/queued-$terminal-b.clock" PATH="$TMP/bin:$PATH" \
    bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 >"$TMP/queued-$terminal-b.out" 2>&1 & queued_b=$!
  wait "$queued_a"; queued_a_rc=$?
  wait "$queued_b"; queued_b_rc=$?
  expected_rc=1; [ "$terminal" != MERGED ] || expected_rc=0
  check "two queued waiters share one fresh $terminal read and retain terminal outcomes" \
    "test '$queued_a_rc' -eq '$expected_rc' && test '$queued_b_rc' -eq '$expected_rc' && test \"\$(wc -l < '$TMP/queued-$terminal-calls')\" -eq 2 && grep -q '$terminal' '$TMP/queued-$terminal-a.out' && grep -q '$terminal' '$TMP/queued-$terminal-b.out'"
done
rm -f "$TMP/bin/sleep"

cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -lt 20 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'x\n' >> "${AI_PR_WAIT_TEST_MARKER:?}"
[ -z "${AI_PR_WAIT_TEST_PAGED_DELAY:-}" ] || /bin/sleep "$AI_PR_WAIT_TEST_PAGED_DELAY"
[[ "$*" == *'rateLimit{cost remaining resetAt}'* ]] || { printf 'missing same-response quota fields\n' >&2; exit 9; }
if [[ "$*" == *'before:"older"'* ]]; then
  head=h1; [ "${AI_PR_WAIT_TEST_BAD_PAGE:-0}" != 1 ] || head=h2
  printf '{"data":{"repository":{"pullRequest":{"headRefOid":"%s","commits":{"nodes":[{"commit":{"statusCheckRollup":{"contexts":{"totalCount":1,"pageInfo":{"hasPreviousPage":false,"startCursor":null},"nodes":[{"name":"older failure","conclusion":"FAILURE"}]}}}}]}}}}}\n' "$head" |
    jq -c '.data.rateLimit={cost:5,remaining:4992,resetAt:"2026-09-28T05:00:00Z"}'
elif [[ "$*" == *before:* ]]; then
  printf '%s\n' 'unexpected GraphQL cursor encoding' >&2
  exit 9
else
  printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"OPEN","headRefOid":"h1","isInMergeQueue":false,"mergeCommit":null,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":1,"pageInfo":{"hasPreviousPage":true,"startCursor":"older"},"nodes":[]}}}}]}}}}}' |
    jq -c '.data.rateLimit={cost:3,remaining:4997,resetAt:"2026-09-28T05:00:00Z"}'
fi
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/date"
rm -f "$TMP/paged-calls" "$TMP/paged-clock"
OUT="$(AI_PR_WAIT_TEST_MARKER="$TMP/paged-calls" AI_PR_WAIT_TEST_CLOCK="$TMP/paged-clock" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 2>&1)"; RC=$?
check "a failure on a previous check page remains terminal after complete pagination" \
  "test '$RC' -eq 1 && test \"\$(wc -l < '$TMP/paged-calls')\" -eq 2 && printf '%s' \"$OUT\" | grep -q 'older failure' && ! printf '%s' \"$OUT\" | grep -q 'unexpected GraphQL cursor encoding'"

rm -f "$TMP/paged-shared-calls" "$TMP/paged-shared-a.clock" "$TMP/paged-shared-b.clock"
paged_context="v1:$(printf '%064d' 0)"
AI_PR_WAIT_TEST_CONTEXT_KEY="$paged_context" \
  AI_PR_WAIT_SNAPSHOT_DIR="$TMP/paged-shared-snapshots" AI_GH_STATE_DIR="$TMP/paged-shared-throttle" \
  AI_PR_WAIT_TEST_PAGED_DELAY=0.3 AI_PR_WAIT_TEST_MARKER="$TMP/paged-shared-calls" \
  AI_PR_WAIT_TEST_CLOCK="$TMP/paged-shared-a.clock" PATH="$TMP/bin:$PATH" \
  bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 >"$TMP/paged-shared-a.out" 2>&1 & paged_a=$!
AI_PR_WAIT_TEST_CONTEXT_KEY="$paged_context" \
  AI_PR_WAIT_SNAPSHOT_DIR="$TMP/paged-shared-snapshots" AI_GH_STATE_DIR="$TMP/paged-shared-throttle" \
  AI_PR_WAIT_TEST_PAGED_DELAY=0.3 AI_PR_WAIT_TEST_MARKER="$TMP/paged-shared-calls" \
  AI_PR_WAIT_TEST_CLOCK="$TMP/paged-shared-b.clock" PATH="$TMP/bin:$PATH" \
  bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 >"$TMP/paged-shared-b.out" 2>&1 & paged_b=$!
wait "$paged_a"; paged_a_rc=$?
wait "$paged_b"; paged_b_rc=$?
check "two waiters share one complete multi-page failure read" \
  "test '$paged_a_rc' -eq 1 && test '$paged_b_rc' -eq 1 && test \"\$(wc -l < '$TMP/paged-shared-calls')\" -eq 2 && grep -q 'older failure' '$TMP/paged-shared-a.out' && grep -q 'older failure' '$TMP/paged-shared-b.out'"
check "two-page upstream refresh records each page cost once and no follower cost" \
  "'$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/paged-shared-throttle/measurements' | jq -e '.observed_graphql_cost_records == 2 and .observed_graphql_points == 8 and .linked_graphql_points == 8 and .completed_workflow_receipts == 2 and .observed_graphql_windows_local_only[0].min_remaining == 4992' && ! grep -q '$paged_context' <('$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/paged-shared-throttle/measurements')"

cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -lt 30 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
cat > "$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/date" "$TMP/bin/sleep"
rm -f "$TMP/paged-bad-clock" "$TMP/paged-bad-calls"
OUT="$(AI_PR_WAIT_TEST_CONTEXT_KEY='host credential principal scopes-a' \
  AI_PR_WAIT_SNAPSHOT_DIR="$TMP/paged-bad-snapshots" AI_GH_STATE_DIR="$TMP/paged-bad-throttle" \
  AI_PR_WAIT_TEST_BAD_PAGE=1 AI_PR_WAIT_TEST_MARKER="$TMP/paged-bad-calls" \
  AI_PR_WAIT_TEST_CLOCK="$TMP/paged-bad-clock" PATH="$TMP/bin:$PATH" \
  bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 2>&1)"; RC=$?
check "a mismatched earlier page never publishes a complete snapshot" \
  "test '$RC' -eq 2 && test \"\$(wc -l < '$TMP/paged-bad-calls')\" -ge 2 && test -z \"\$(find '$TMP/paged-bad-snapshots' -name '*.json' -print 2>/dev/null)\" && printf '%s' \"$OUT\" | grep -q 'could not read PR'"
rm -f "$TMP/bin/sleep"

cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
printf '1000\n'
EOF

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
count="$(cat "${AI_PR_WAIT_TEST_MARKER:?}" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$AI_PR_WAIT_TEST_MARKER"
if [ "$count" -eq 3 ]; then state=MERGED; queue=false; head=h2
elif [ "$count" -eq 2 ]; then state=OPEN; queue=false; head=h2
else state=OPEN; queue=true; head=h1; fi
printf '{"data":{"repository":{"pullRequest":{"state":"%s","headRefOid":"%s","isInMergeQueue":%s,"mergeCommit":{"oid":"done"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false},"nodes":[]}}}}]}}}}}\n' "$state" "$head" "$queue"
EOF
chmod +x "$TMP/bin/gh"
rm -f "$TMP/head-move-count"
OUT="$(AI_PR_WAIT_TEST_MARKER="$TMP/head-move-count" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 2>&1)"; RC=$?
check "a changed head after queue membership is not falsely called an ejection" \
  "test '$RC' -eq 0 && test \"\$(cat '$TMP/head-move-count')\" -eq 3 && ! printf '%s' \"$OUT\" | grep -q EJECTED"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
count="$(cat "${AI_PR_WAIT_TEST_MARKER:?}" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$AI_PR_WAIT_TEST_MARKER"
if [ "$count" -eq 1 ]; then queue=true; else queue=false; fi
printf '{"data":{"repository":{"pullRequest":{"state":"OPEN","headRefOid":"h1","isInMergeQueue":%s,"mergeCommit":null,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false},"nodes":[]}}}}]}}}}}\n' "$queue"
EOF
chmod +x "$TMP/bin/gh"
rm -f "$TMP/ejected-count"
OUT="$(AI_PR_WAIT_TEST_MARKER="$TMP/ejected-count" PATH="$TMP/bin:$PATH" bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 2>&1)"; RC=$?
check "a genuine same-head merge-queue ejection is terminal" \
  "test '$RC' -eq 1 && test \"\$(cat '$TMP/ejected-count')\" -eq 2 && printf '%s' \"$OUT\" | grep -q EJECTED"

# An explicit --repo skips the preliminary repo lookup. A cold ai-gh state
# therefore has no principal when the waiter starts; a successful first call
# can warm it, and later waiters must use that verified local identity.
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    acl_helper="$(cygpath -w "$ROOT/tools/github-requests/secure-windows-path.ps1")"
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$acl_helper" \
      -Mode EnsureCache -Path "$(cygpath -w "$TMP/cold-throttle")" >/dev/null || exit 1
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$acl_helper" \
      -Mode EnsureCache -Path "$(cygpath -w "$TMP/cold-throttle/identities")" >/dev/null || exit 1
    ;;
  *)
    mkdir -m 700 -p "$TMP/cold-throttle/identities"
    chmod 700 "$TMP/cold-throttle" "$TMP/cold-throttle/identities"
    ;;
esac
printf '%064d\n' 0 > "$TMP/cold-throttle/principal-salt"
chmod 600 "$TMP/cold-throttle/principal-salt"
cold_credential_hash="$(printf 'ghp_cold_fixture\n' | sha256sum | cut -d' ' -f1)"
cold_identity_key="$(printf '3 github.com %s' "$cold_credential_hash" | sha256sum | cut -d' ' -f1)"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-} ${2:-}" = 'auth token' ]; then
  printf 'x\n' >> "${AI_PR_WAIT_TEST_AUTH_LOG:?}"
  printf 'ghp_cold_fixture\n'
  exit 0
fi
if [ "${1:-} ${2:-}" = 'api graphql' ]; then
  printf 'x\n' >> "${AI_PR_WAIT_TEST_MARKER:?}"
  if [ "${AI_PR_WAIT_TEST_COLD_MODE:-}" = warm ]; then
    printf '123 %s\n' "$(/bin/date +%s)" > "$AI_GH_STATE_DIR/identities/${AI_PR_WAIT_TEST_IDENTITY_KEY:?}"
    chmod 600 "$AI_GH_STATE_DIR/identities/$AI_PR_WAIT_TEST_IDENTITY_KEY"
    printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"MERGED","headRefOid":"shared-head","isInMergeQueue":false,"mergeCommit":{"oid":"warm"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false},"nodes":[]}}}}]}}}}}'
  else
    /bin/sleep 0.3
    printf '%s\n' '{"data":{"repository":{"pullRequest":{"state":"OPEN","headRefOid":"shared-head","isInMergeQueue":false,"mergeCommit":null,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"totalCount":0,"pageInfo":{"hasPreviousPage":false},"nodes":[]}}}}]}}}}}'
  fi
  exit 0
fi
exit 8
EOF
chmod +x "$TMP/bin/gh"
rm -f "$TMP/cold-auth" "$TMP/cold-calls"
OUT="$(AI_GH_STATE_DIR="$TMP/cold-throttle" AI_PR_WAIT_TEST_AUTH_LOG="$TMP/cold-auth" \
  AI_PR_WAIT_TEST_MARKER="$TMP/cold-calls" AI_PR_WAIT_TEST_IDENTITY_KEY="$cold_identity_key" \
  AI_PR_WAIT_TEST_COLD_MODE=warm PATH="$TMP/bin:$PATH" \
  bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 2>&1)"; RC=$?
check 'cold explicit-repo waiter rechecks verified identity after its first successful read' \
  "test '$RC' -eq 0 && test \"\$(wc -l < '$TMP/cold-auth')\" -eq 2 && test \"\$(wc -l < '$TMP/cold-calls')\" -eq 1 && printf '%s' \"$OUT\" | grep -q MERGED"

cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
state="${AI_PR_WAIT_TEST_CLOCK:?}"
count="$(cat "$state" 2>/dev/null || printf 0)"
count=$(( count + 1 )); printf '%s\n' "$count" > "$state"
if [ "$count" -le 3 ]; then printf '1000\n'; else printf '1060\n'; fi
EOF
chmod +x "$TMP/bin/date"
rm -f "$TMP/cold-shared-calls" "$TMP/cold-clock-a" "$TMP/cold-clock-b"
AI_GH_STATE_DIR="$TMP/cold-throttle" AI_PR_WAIT_SNAPSHOT_DIR="$TMP/cold-snapshots" \
  AI_PR_WAIT_TEST_AUTH_LOG="$TMP/cold-auth" AI_PR_WAIT_TEST_MARKER="$TMP/cold-shared-calls" \
  AI_PR_WAIT_TEST_IDENTITY_KEY="$cold_identity_key" AI_PR_WAIT_TEST_COLD_MODE=share \
  AI_PR_WAIT_TEST_CLOCK="$TMP/cold-clock-a" PATH="$TMP/bin:$PATH" \
  bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 > "$TMP/cold-shared-a.out" 2>&1 & cold_a=$!
AI_GH_STATE_DIR="$TMP/cold-throttle" AI_PR_WAIT_SNAPSHOT_DIR="$TMP/cold-snapshots" \
  AI_PR_WAIT_TEST_AUTH_LOG="$TMP/cold-auth" AI_PR_WAIT_TEST_MARKER="$TMP/cold-shared-calls" \
  AI_PR_WAIT_TEST_IDENTITY_KEY="$cold_identity_key" AI_PR_WAIT_TEST_COLD_MODE=share \
  AI_PR_WAIT_TEST_CLOCK="$TMP/cold-clock-b" PATH="$TMP/bin:$PATH" \
  bash "$CMD" 1 --repo popcre/ai-devops --timeout-minutes 1 --interval 1 > "$TMP/cold-shared-b.out" 2>&1 & cold_b=$!
wait "$cold_a"; cold_a_rc=$?
wait "$cold_b"; cold_b_rc=$?
check 'two explicit-repo waiters share one refresh after the cold identity is verified' \
  "test '$cold_a_rc' -eq 2 && test '$cold_b_rc' -eq 2 && test \"\$(wc -l < '$TMP/cold-shared-calls')\" -eq 1 && grep -q 'still in progress' '$TMP/cold-shared-a.out' && grep -q 'still in progress' '$TMP/cold-shared-b.out'"

cat > "$TMP/error-page-gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"data":{"rateLimit":{"cost":6,"remaining":4994,"resetAt":"2026-09-28T05:00:00Z"}},"errors":[{"message":"fixture error"}]}'
exit 7
EOF
chmod +x "$TMP/error-page-gh"
error_deadline=$(( $(/usr/bin/date +%s) + 30 ))
AI_GH_STATE_DIR="$TMP/error-page-state" PR_WAIT_RECEIPT_ID="$(printf '%032d' 0)" \
  AI_GH_COST_CONTEXT="v1:$(printf '%064d' 0)" PATH=/usr/bin:/bin \
  bash "$ROOT/tools/github-requests/pr-status-complete.sh" "$TMP/error-page-gh" "$PYTHON_RUNNER" \
  "$ROOT/bin/ai-process-supervisor" "$(command -v bash)" o r 1 "$error_deadline" 10 0 "$TMP/error-page-source" \
  > "$TMP/error-page-out" 2> "$TMP/error-page-err"; error_page_rc=$?
check 'a nonzero upstream page with usable rateLimit still records its cost' \
  "test '$error_page_rc' -eq 7 && test \"\$(cat '$TMP/error-page-source')\" = upstream && '$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/error-page-state/measurements' | jq -e '.observed_graphql_cost_records == 1 and .observed_graphql_points == 6'"

check "the cross-process cache preserves privacy, completeness, cancellation and recovery" \
  "python3 '$ROOT/tests/test-ai-pr-status-singleflight.py' -q"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
