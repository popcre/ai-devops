#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/ci/verify-closure.sh"
failures=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok   %s\n' "$name"
  else
    printf '  FAIL %s\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

reject() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  FAIL %s\n' "$name" >&2
    failures=$((failures + 1))
  else
    printf '  ok   %s\n' "$name"
  fi
}

# Argument order: event selection run_long validation evidence linux windows
# reviewer doc. Each lane state is success / failure / cancelled / skipped /
# missing.

check 'a complete code pull request closes' bash "$TOOL" pull_request success true success success success success success success
check 'a classified prose-only pull request closes with the declared Linux skip' bash "$TOOL" pull_request success false success success skipped success success success
check 'a complete merge group closes without repeating Windows suites' bash "$TOOL" merge_group success true success success success skipped skipped success

# closure_fast_failure_blocks: a known terminal fast-validation failure is the
# signal that stopped every expensive suite before it started. Those suites are
# therefore skipped, and that skip must never close the check.
reject 'closure_fast_failure_blocks: known terminal validation failure with blocked lanes fails closure' bash "$TOOL" pull_request success true failure success skipped skipped skipped success
reject 'closure_fast_failure_blocks: known terminal validation failure alone fails closure' bash "$TOOL" pull_request success true failure success success success success success
reject 'closure_fast_failure_blocks: known terminal validation failure on a merge group fails closure' bash "$TOOL" merge_group success true failure success skipped skipped skipped success
reject 'closure_fast_failure_blocks: known terminal validation failure on a prose-only change fails closure' bash "$TOOL" pull_request success false failure success skipped success success success

# The same truth table for validation: cancelled / skipped / missing are no
# proof at all and fail closed rather than reading as a pass.
reject 'closure_fast_failure_blocks: cancelled fast validation fails closure' bash "$TOOL" pull_request success true cancelled success success success success success
reject 'closure_fast_failure_blocks: skipped fast validation fails closure' bash "$TOOL" pull_request success true skipped success success success success success
reject 'closure_fast_failure_blocks: missing fast validation fails closure' bash "$TOOL" pull_request success true '' success success success success success
reject 'closure_fast_failure_blocks: malformed fast validation fails closure' bash "$TOOL" pull_request success true maybe success success success success success

# closure_unknown_selection_not_green: missing or invalid classification never
# becomes a green skip, even when every expensive lane did run and pass.
reject 'closure_unknown_selection_not_green: missing selection with every lane green still fails closure' bash "$TOOL" pull_request '' true success success success success success success
reject 'closure_unknown_selection_not_green: failed selection never closes' bash "$TOOL" pull_request failure true success success success success success success
reject 'closure_unknown_selection_not_green: cancelled selection never closes' bash "$TOOL" pull_request cancelled true success success success success success success
reject 'closure_unknown_selection_not_green: skipped selection never closes' bash "$TOOL" pull_request skipped true success success success success success success
reject 'closure_unknown_selection_not_green: malformed selection never closes' bash "$TOOL" pull_request forged true success success success success success success

# closure_missing_required_fails: every required lane must report a real
# outcome. A missing lane is no progress, never a pass.
reject 'closure_missing_required_fails: a missing Linux lane fails closure' bash "$TOOL" pull_request success true success '' success success success success
reject 'closure_missing_required_fails: a missing Windows lane fails closure' bash "$TOOL" pull_request success true success success success '' success success
reject 'closure_missing_required_fails: a missing reviewer lane fails closure' bash "$TOOL" pull_request success true success success success success '' success
reject 'closure_missing_required_fails: a missing evidence gate fails closure' bash "$TOOL" pull_request success true '' success success success success success
reject 'closure_missing_required_fails: a missing merge-group Linux lane fails closure' bash "$TOOL" merge_group success true success success '' skipped skipped success

# No-progress detector: a cancelled suite is a stopped suite, not a result.
# Per-suite auto-cancel may stop an expensive lane; closure must still fail.
reject 'closure_no_progress_detector: a cancelled Linux lane is no progress and fails closure' bash "$TOOL" pull_request success true success success cancelled success success success
reject 'closure_no_progress_detector: a cancelled Windows lane is no progress and fails closure' bash "$TOOL" pull_request success true success success success cancelled success success
reject 'closure_no_progress_detector: a cancelled reviewer lane is no progress and fails closure' bash "$TOOL" pull_request success true success success success success cancelled success
reject 'closure_no_progress_detector: a cancelled merge-group Linux lane is no progress and fails closure' bash "$TOOL" merge_group success true success success cancelled skipped skipped success

# Other pre-existing fail-closed routes.
reject 'an unfinished exact-head Windows run cannot close' bash "$TOOL" pull_request success true success success success skipped success success
reject 'a failed exact-head reviewer run cannot close' bash "$TOOL" pull_request success true success success success success failure success
reject 'a failed merge-group evidence gate blocks closure' bash "$TOOL" merge_group success true failure failure skipped skipped
reject 'a failed merge-group Linux run blocks closure' bash "$TOOL" merge_group success true success failure skipped skipped
reject 'a failed exact-head Linux run cannot close' bash "$TOOL" pull_request success true success success failure success success success
reject 'a skipped exact-head Linux run cannot close' bash "$TOOL" pull_request success true success success skipped success success success
reject 'a missing run-long output remains fail closed' bash "$TOOL" pull_request success '' success success skipped success success success
reject 'a malformed run-long output remains fail closed' bash "$TOOL" pull_request success maybe success success skipped success success success

# closure_doc_safety_required: the unconditional doc lane has no legitimate
# skip on either required event (#1188). Anything but success fails closure,
# including on the prose-only pull requests that skip every offline suite.
reject 'closure_doc_safety_required: a failed doc lane fails closure on a code pull request' bash "$TOOL" pull_request success true success success success success success failure
reject 'closure_doc_safety_required: a failed doc lane fails closure on a prose-only pull request' bash "$TOOL" pull_request success false success success skipped success success failure
reject 'closure_doc_safety_required: a skipped doc lane never closes, prose-only included' bash "$TOOL" pull_request success false success success skipped success success skipped
reject 'closure_doc_safety_required: a cancelled doc lane never closes' bash "$TOOL" merge_group success true success success success skipped skipped cancelled
reject 'closure_doc_safety_required: a missing doc lane never closes' bash "$TOOL" merge_group success true success success success skipped skipped ''
reject 'closure_doc_safety_required: a malformed doc lane never closes' bash "$TOOL" pull_request success true success success success success success maybe
check 'closure_doc_safety_required: a green doc lane closes a prose-only pull request' bash "$TOOL" pull_request success false success success skipped success success success

# The gate pair for this routing outcome: a deliberately invalid bounded CI
# candidate (fast validation found a known terminal failure) starts no long
# job - the expensive lanes are therefore skipped - and fails closure. Its
# repaired successor passes the same evaluator with every lane green.
reject 'deliberately_invalid_candidate_fails: the invalid candidate starts no long job and fails closure' bash "$TOOL" pull_request success true failure success skipped skipped skipped success
check 'repaired_successor_passes: the repaired candidate closes with every lane green' bash "$TOOL" pull_request success true success success success success success success

[ "$failures" -eq 0 ] || exit 1
printf 'verify-closure tests passed\n'
