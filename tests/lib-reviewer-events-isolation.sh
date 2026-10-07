#!/usr/bin/env bash
# Shared by every offline suite (sourced by lib-test-harness.sh, or directly).
# Test runs must never append stub rows to the live reviewer events log
# (~/.local/state/ai-devops/reviewer-events/events.jsonl), the reviewer spend
# ledger (#1435). The marker makes tools/reviewer_events.py refuse the live
# log outright; the private directory gives wrappers somewhere to write.
# A suite that already chose its own AI_REVIEW_EVENT_DIR keeps it.
export AI_REVIEW_TEST_ISOLATION=1
if [ -z "${AI_REVIEW_EVENT_DIR:-}" ]; then
  AI_REVIEW_EVENT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-review-test-events.XXXXXX")" || {
    printf 'lib-reviewer-events-isolation: cannot create a private events directory\n' >&2
    return 1 2>/dev/null || exit 1
  }
  export AI_REVIEW_EVENT_DIR
fi
