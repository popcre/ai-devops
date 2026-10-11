#!/usr/bin/env bash
# Shared by every offline suite (sourced by lib-test-harness.sh, or directly).
# Test runs must never append stub rows to the live reviewer events log
# (~/.local/state/ai-devops/reviewer-events/events.jsonl), the reviewer spend
# ledger (#1435). The marker makes tools/reviewer_events.py refuse the live
# log outright; the private directory gives wrappers somewhere to write.
# A suite that already chose its own AI_REVIEW_EVENT_DIR keeps it.
export AI_REVIEW_TEST_ISOLATION=1
# A suite run as a review's --tests command inherits the outer review
# session that bin/ai-review exported (operation, gate mode, implementer,
# reviewer approval). Those describe the caller's review, not the fixtures:
# an inherited AI_REVIEW_OPERATION made every fake pool dispatch in
# tests/test-ai-grok-review.sh refuse during a stale-manifest recovery review.
# Suites set these inline per case when a case needs one.
unset AI_REVIEW_OPERATION AI_REVIEW_GATE_MODE AI_REVIEW_IMPLEMENTER AI_REVIEW_REVIEWER_APPROVAL
# Offline child suites own their fixture doors and lifecycle state. The outer
# review exports these invocation variables to its native tools; inheriting
# them here can create failure evidence at the still-running review's live
# destination or overwrite its report. Clear only test-child context, leaving
# normal reviewer tool environments and explicit later fixture setup intact.
for ai_test_outer_context in $(compgen -v DOOR_) $(compgen -v RLC_); do
  unset "$ai_test_outer_context"
done
unset ai_test_outer_context
unset AI_REVIEW_RUNNER_CORE AI_REVIEW_VIA_RUNNER AI_REVIEW_RUNNER_NAME
if [ -z "${AI_REVIEW_EVENT_DIR:-}" ]; then
  # Suites own their EXIT traps, so this helper cannot remove its directory at
  # exit. Instead it removes its own private directories left by runs that
  # ended more than a day ago (name-scoped; never a live ledger).
  find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'ai-review-test-events.??????' -mmin +1440 \
    -exec rm -rf {} + 2>/dev/null || true
  AI_REVIEW_EVENT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-review-test-events.XXXXXX")" || {
    printf 'lib-reviewer-events-isolation: cannot create a private events directory\n' >&2
    return 1 2>/dev/null || exit 1
  }
  export AI_REVIEW_EVENT_DIR
fi
# A nested offline suite must not inherit the caller's live outcome ledger.
# Events already had a private home, but lifecycle failure fixtures still
# appended synthetic failures to the real scoreboard through its default.
# Suites may select their own fixture ledger after sourcing this helper.
export AI_REVIEW_SCOREBOARD_DIR="$AI_REVIEW_EVENT_DIR/scoreboard"
export AI_REVIEW_SCOREBOARD_FILE="$AI_REVIEW_SCOREBOARD_DIR/reviews.jsonl"
