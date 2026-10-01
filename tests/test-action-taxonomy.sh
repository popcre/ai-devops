#!/usr/bin/env bash
# test-action-taxonomy.sh — two action labels only: capacity/infra vs result.
# Empty reviewer verdict is the review-step carve-out and never `result`.
# These checks execute the classifier; they do not grep for its strings.
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
check "it is committed as mode 100755" "git -C '$ROOT' ls-files -s tools/ci/action-taxonomy.sh | grep -q '^100755 '"

act() { bash "$CMD" check "$@"; }
det() { bash "$CMD" detail "$@"; }
rev() { bash "$CMD" review "$@"; }

check "TIMED_OUT is capacity/infra" \
  "test \"$(act TIMED_OUT windows-offline)\" = 'capacity/infra'"
check "CANCELLED is capacity/infra (killed/interrupt)" \
  "test \"$(act CANCELLED windows-offline)\" = 'capacity/infra'"
check "rate-limit summary is capacity/infra" \
  "test \"$(act FAILURE some-check 'GraphQL rate limit exceeded')\" = 'capacity/infra'"
check "a real test FAILURE is result" \
  "test \"$(act FAILURE linux-offline 'assertion failed')\" = 'result'"
check "ERROR without capacity signal is result" \
  "test \"$(act ERROR windows-offline)\" = 'result'"

# Finding 5: a check *name* containing quota/kill/429 must stay result.
check "quota in the check name is not capacity" \
  "test \"$(act FAILURE quota-check 'suite failed')\" = 'result'"
check "kill in the check name is not capacity" \
  "test \"$(act FAILURE skills-lint 'lint failed')\" = 'result'"
check "429 in the check name is not capacity" \
  "test \"$(act FAILURE job-429 'assert failed')\" = 'result'"

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

# The carve-out must fire from a real check signal (name or summary), not only
# from the review failure_class API. An empty-verdict check is never `result`.
check "empty-verdict in the check name is review-step, never result" \
  "test \"$(act FAILURE empty-report 'provider returned no analysis')\" = 'review-step'"
check "empty-verdict in the check summary is review-step, never result" \
  "test \"$(act FAILURE windows-reviewer-safety 'empty report from provider')\" = 'review-step'"
check "empty-verdict detail is empty-verdict" \
  "test \"$(det FAILURE x 'empty report')\" = 'empty-verdict'"

check "no empty-verdict path returns result" \
  "test \"$(rev empty-report)\" != 'result' && test \"$(rev empty-verdict)\" != 'result' && test \"$(rev no-verdict)\" != 'result' && test \"$(rev malformed-verdict)\" != 'result' && test \"$(act FAILURE empty-verdict x)\" != 'result'"

# End-to-end: the classification ai-pr-wait and report-scheduled-failure run.
check "report-scheduled-failure classifies a cancelled need as capacity/infra" \
  "test \"$(act cancelled windows-offline-complete)\" = 'capacity/infra'"
check "report-scheduled-failure classifies a failure need as result" \
  "test \"$(act failure linux-offline)\" = 'result'"

printf 'action-taxonomy: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
