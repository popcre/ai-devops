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
check "a stalled fixture says it stalled, not that the code under test failed" \
  "grep -q 'stalled' '$TMP/stall.err' && grep -q 'no observable progress' '$TMP/stall.err'"

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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
