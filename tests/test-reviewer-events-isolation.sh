#!/usr/bin/env bash
# Test runs must never write the live reviewer events ledger (#1435).
# Offline. Never appends to any ledger: the refusal is probed by resolving the
# location only, so a regressed guard cannot itself pollute the live log.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$ROOT/tests/lib-test-harness.sh"
PY="$(command -v python3 || command -v python)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

live="$(cd "$ROOT/tools" && "$PY" -c 'import reviewer_events; print(reviewer_events.live_location())')"
resolve(){ (cd "$ROOT/tools" && env "$@" "$PY" -c 'import reviewer_events; print(reviewer_events.location())'); }

check "harness exports the test isolation marker" '[ "${AI_REVIEW_TEST_ISOLATION:-}" = 1 ]'
check "harness gives the suite a private events directory" '[ -n "${AI_REVIEW_EVENT_DIR:-}" ] && [ -d "$AI_REVIEW_EVENT_DIR" ]'
check "private events directory is not the live ledger" '[ "$(cd "$AI_REVIEW_EVENT_DIR" && pwd -P)" != "$live" ]'

out="$(resolve AI_REVIEW_TEST_ISOLATION=1 AI_REVIEW_EVENT_DIR="$live" 2>&1)"; rc=$?
check "marker refuses an explicit live events directory" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q "refused the live reviewer events log"'

out="$(resolve -u AI_REVIEW_EVENT_DIR -u AI_REVIEWER_STATE_BASE AI_REVIEW_TEST_ISOLATION=1 HOME="${live%/.local/state/ai-devops/reviewer-events}" 2>&1)"; rc=$?
check "marker refuses the default live location" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q "refused the live reviewer events log"'

out="$(resolve -u AI_REVIEW_TEST_ISOLATION AI_REVIEW_EVENT_DIR="$live" 2>&1)"; rc=$?
check "real runs without the marker still use the live ledger" '[ "$rc" -eq 0 ] && [ "$out" = "$live" ]'

out="$(resolve -u AI_REVIEW_EVENT_DIR AI_REVIEW_TEST_ISOLATION=1 AI_REVIEWER_STATE_BASE="$TMP/base" 2>&1)"; rc=$?
check "marker allows a private state base" '[ "$rc" -eq 0 ] && [ "$out" = "$TMP/base/reviewer-events" ]'

out="$(resolve -u AI_REVIEW_EVENT_DIR -u AI_REVIEWER_STATE_BASE AI_REVIEW_TEST_ISOLATION=1 HOME="$TMP/home" 2>&1)"; rc=$?
check "marker allows a substituted test HOME" '[ "$rc" -eq 0 ] && [ "$out" = "$TMP/home/.local/state/ai-devops/reviewer-events" ]'

# Wrappers scrub their environment before recording; the marker must survive.
check "event guard forwards the marker on every recording path" \
  '[ "$(grep -c "AI_REVIEW_EVENT_DIR AI_REVIEW_TEST_ISOLATION" "$ROOT/tools/reviewer_event_guard.sh")" -eq 4 ]'
check "deepseek agent forwards the marker" 'grep -q "AI_REVIEW_EVENT_DIR AI_REVIEW_TEST_ISOLATION" "$ROOT/bin/ai-deepseek-agent"'

# A real begin under isolation lands in the private directory only.
priv="$TMP/events"
(cd "$TMP" && git init -q repo) >/dev/null 2>&1
id="$(cd "$TMP/repo" && env AI_REVIEW_TEST_ISOLATION=1 AI_REVIEW_EVENT_DIR="$priv" "$PY" "$ROOT/tools/reviewer_events.py" begin qwen invocation 2>/dev/null)"
check "isolated begin records in the private directory" '[[ "$id" =~ ^[0-9a-f]{32}$ ]] && grep -q "$id" "$priv/events.jsonl"'
check "isolated begin left no row in the live ledger" '! grep -qs "$id" "$live/events.jsonl"'

# A suite run as a review's --tests command must not inherit the outer review
# session (stale-manifest recovery review REJECT, 21 false failures).
leak="$(env AI_REVIEW_OPERATION=stale-linux-manifest-recovery AI_REVIEW_GATE_MODE=final-check \
  AI_REVIEW_IMPLEMENTER=codex AI_REVIEW_REVIEWER_APPROVAL=/x/approve.md bash -c \
  '. "$1/tests/lib-test-harness.sh"; printf "%s|%s|%s|%s|%s" "${AI_REVIEW_OPERATION-unset}" "${AI_REVIEW_GATE_MODE-unset}" "${AI_REVIEW_IMPLEMENTER-unset}" "${AI_REVIEW_REVIEWER_APPROVAL-unset}" "$AI_REVIEW_TEST_ISOLATION"' _ "$ROOT")"
check "harness clears the inherited outer review session" '[ "$leak" = "unset|unset|unset|unset|1" ]'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
