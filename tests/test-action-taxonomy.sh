#!/usr/bin/env bash
# test-action-taxonomy.sh — two action labels only: capacity/infra vs result.
# Empty reviewer verdict is the review-step carve-out and never `result`.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$ROOT/tools/ci/action-taxonomy.sh"
pass=0; fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; pass=$(( pass + 1 ))
  else printf '  FAIL %s\n' "$1"; fail=$(( fail + 1 )); fi
}

check "the taxonomy helper exists and is executable" "test -x '$CMD'"
check "it parses as valid bash" "bash -n '$CMD'"

act() { bash "$CMD" check "$@"; }
det() { bash "$CMD" detail "$@"; }
rev() { bash "$CMD" review "$@"; }

check "TIMED_OUT is capacity/infra" \
  "test \"$(act TIMED_OUT windows-offline)\" = 'capacity/infra'"
check "CANCELLED is capacity/infra (killed/interrupt)" \
  "test \"$(act CANCELLED windows-offline)\" = 'capacity/infra'"
check "rate-limit text is capacity/infra" \
  "test \"$(act FAILURE some-check 'GraphQL rate limit exceeded')\" = 'capacity/infra'"
check "a real test FAILURE is result" \
  "test \"$(act FAILURE linux-offline 'assertion failed')\" = 'result'"
check "ERROR without capacity signal is result" \
  "test \"$(act ERROR windows-offline)\" = 'result'"

check "timeout detail is report-only timeout-capacity" \
  "test \"$(det TIMED_OUT)\" = 'timeout-capacity'"
check "cancel detail is report-only killed-interrupt" \
  "test \"$(det CANCELLED)\" = 'killed-interrupt'"
check "rate-limit detail is report-only rate-limit-capacity" \
  "test \"$(det FAILURE x 'secondary rate limit')\" = 'rate-limit-capacity'"
check "ordinary failure detail is test-failure" \
  "test \"$(det FAILURE linux-offline)\" = 'test-failure'"

check "empty-report review failure is review-step" \
  "test \"$(rev empty-report)\" = 'review-step'"
check "empty-verdict review failure is review-step" \
  "test \"$(rev empty-verdict)\" = 'review-step'"
check "provider timeout review failure is capacity/infra" \
  "test \"$(rev provider-timeout)\" = 'capacity/infra'"
check "allowance exhaustion is capacity/infra" \
  "test \"$(rev allowance-exhausted)\" = 'capacity/infra'"
check "stale-source is a result" \
  "test \"$(rev stale-source)\" = 'result'"

check "an empty-verdict check signal is never labeled result (no PR test red)" \
  "test \"$(act FAILURE x 'empty report')\" = 'review-step'"
check "empty-verdict detail is empty-verdict" \
  "test \"$(det FAILURE x 'empty report')\" = 'empty-verdict'"

# Binding constraint from the Muse-agreed plan: empty reviewer verdict must
# never be classified as a PR test result.
check "no empty-verdict path returns result" \
  "test \"$(rev empty-report)\" != 'result' && test \"$(rev empty-verdict)\" != 'result' && test \"$(rev no-verdict)\" != 'result' && test \"$(rev malformed-verdict)\" != 'result'"

printf 'action-taxonomy: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
