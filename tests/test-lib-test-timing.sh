#!/usr/bin/env bash
# Proves the shared timing helpers behave as the reviewer suites assume.
#
# The interesting one is poll_until_progress. Issue #89's flake was a fixture
# that timed out on a slow machine because every ceiling derived from a baseline
# measured ten minutes earlier. The rule these checks pin down is the one that
# replaces it: a fixture that is still moving keeps its time; a fixture that has
# stopped moving is reported in the stall window, no slower than the old ceiling.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib-test-timing.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- ai_test_fingerprint -----------------------------------------------------
mkdir -p "$TMP/d"
F0="$(ai_test_fingerprint "$TMP/d" "$TMP/f" )"
: > "$TMP/f"
F1="$(ai_test_fingerprint "$TMP/d" "$TMP/f" )"
check "fingerprint distinguishes an absent file from an empty one" "test '$F0' != '$F1'"
echo growing >> "$TMP/f"
F2="$(ai_test_fingerprint "$TMP/d" "$TMP/f" )"
check "fingerprint changes when a watched file grows" "test '$F1' != '$F2'"
touch "$TMP/d/entry"
F3="$(ai_test_fingerprint "$TMP/d" "$TMP/f" )"
check "fingerprint changes when a watched directory gains an entry" "test '$F2' != '$F3'"
F4="$(ai_test_fingerprint "$TMP/d" "$TMP/f" )"
check "fingerprint is stable while nothing changes" "test '$F3' = '$F4'"

# --- poll_until_progress: the condition is already true ----------------------
START="$(date +%s)"
poll_until_progress 5 'an already-satisfied condition' "ai_test_fingerprint '$TMP/f'" "true"
RC=$?
check "a satisfied condition returns immediately and successfully" \
  "test '$RC' -eq 0 && test \$(( $(date +%s) - START )) -lt 3"

# --- poll_until_progress: nothing moves, so it must give up in the window ----
# This is the hang case. It must still be caught, and caught fast.
START="$(date +%s)"
poll_until_progress 3 'a hung fixture' "ai_test_fingerprint '$TMP/absent'" "false" 2>"$TMP/stall.err"
RC=$?
ELAPSED=$(( $(date +%s) - START ))
check "a fixture that never moves fails inside the stall window" \
  "test '$RC' -ne 0 && test '$ELAPSED' -lt 10"
# A signal that never changed even once cannot distinguish a hang from a badly
# chosen signal, so the tool must not claim it caught a hang. It must name
# itself as the suspect and say what to do instead. This is the failure that
# ejected PR #142 from the merge queue on 2026-08-28.
check "a never-moving signal is blamed on the test, not on the code under test" \
  "grep -q 'never changed once' '$TMP/stall.err' && grep -q 'defect in the TEST' '$TMP/stall.err' && grep -q 'poll_until' '$TMP/stall.err'"

# --- poll_until_progress: advanced, then stopped -----------------------------
# The genuine hang: the signal proved it can move, then stopped. That message
# must be different from the one above, because the remedy is different.
: > "$TMP/half"
( sleep 1; echo x >> "$TMP/half" ) &
HALF_PID=$!
poll_until_progress 3 'a fixture that advanced then stopped' \
  "ai_test_fingerprint '$TMP/half'" "false" 2>"$TMP/half.err"
wait "$HALF_PID" 2>/dev/null
check "a fixture that advanced then stopped is reported as a stall, not a test defect" \
  "grep -q 'it advanced, then nothing changed' '$TMP/half.err' && ! grep -q 'defect in the TEST' '$TMP/half.err'"

# --- ai_test_fingerprint: a touched file counts as progress ------------------
# A wrapper building its review packet rewrites and touches files without
# growing them or creating locks. A size-and-count-only fingerprint goes blind
# for minutes and reports a healthy process as hung.
: > "$TMP/touched"
FP1="$(ai_test_fingerprint "$TMP" "$TMP/touched")"
sleep 1
touch "$TMP/touched"
FP2="$(ai_test_fingerprint "$TMP" "$TMP/touched")"
check "the fingerprint moves when a file is only touched, not grown" \
  "test \"$FP1\" != \"$FP2\""

# --- poll_until_progress: slow but advancing must NOT be failed --------------
# The whole point. A background writer keeps the fingerprint moving for longer
# than the stall window, and the condition only becomes true at the end. A
# deadline-sensitive wait of the same size fails this; a progress-sensitive one
# must not.
: > "$TMP/slow"
( for i in 1 2 3 4 5 6; do sleep 1; echo "$i" >> "$TMP/slow"; done; touch "$TMP/slow-done" ) &
SLOW_PID=$!
poll_until_progress 3 'a slow but advancing fixture' \
  "ai_test_fingerprint '$TMP/slow'" "test -f '$TMP/slow-done'"
RC=$?
wait "$SLOW_PID" 2>/dev/null
check "a fixture that keeps advancing is not failed by the stall window" "test '$RC' -eq 0"

# --- poll_until_progress: runaway backstop ----------------------------------
check "the absolute ceiling is a multiple of the stall window, not the deadline" \
  "grep -q 'hard=\$(( stall \* 10 ))' '$ROOT/tests/lib-test-timing.sh'"

# --- poll_until is unchanged for the waits that still use it -----------------
START="$(date +%s)"
poll_until 2 'an unchanged deadline wait' "false" 2>/dev/null
RC=$?
check "poll_until still fails at its own deadline" \
  "test '$RC' -ne 0 && test \$(( $(date +%s) - START )) -lt 8"

# --- worker-aware waits ------------------------------------------------------
( sleep 2; touch "$TMP/worker-ready" ) & WORKER_PID=$!
poll_worker_until "$WORKER_PID" 5 'a quiet healthy worker' "test -f '$TMP/worker-ready'"
RC=$?; wait "$WORKER_PID"
check "a quiet live worker is allowed to reach readiness" "test '$RC' -eq 0"

( sleep 2; touch "$TMP/workers-ready" ) & WORKER_A_PID=$!
( sleep 3 ) & WORKER_B_PID=$!
poll_workers_until "$WORKER_A_PID $WORKER_B_PID" 5 'two quiet healthy workers' "test -f '$TMP/workers-ready'"
RC=$?; wait "$WORKER_A_PID"; wait "$WORKER_B_PID"
check "multiple live workers are allowed to reach shared readiness" "test '$RC' -eq 0"

( exit 0 ) & DEAD_WORKER_PID=$!; wait "$DEAD_WORKER_PID"
poll_worker_until "$DEAD_WORKER_PID" 5 'an exited worker' "false" 2>"$TMP/worker-dead.err"
RC=$?
check "an exited worker fails immediately and names the fixture" \
  "test '$RC' -ne 0 && grep -q 'worker exited' '$TMP/worker-dead.err'"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
