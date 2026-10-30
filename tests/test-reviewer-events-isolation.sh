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
# The real profile home, in Python's own spelling (C:\Users\... on Windows), so
# the default-live probe needs no POSIX suffix strip.
live_home="$(cd "$ROOT/tools" && "$PY" -c 'import reviewer_events; print(reviewer_events._profile_home())')"
# Windows Python prints C:\...\Temp paths for Git Bash /tmp inputs; the shared
# helper compares both spellings as one place (#1835).
source "$ROOT/tools/lib/path-identity.sh"
same_path(){ ai_same_path "$@"; }

check "harness exports the test isolation marker" '[ "${AI_REVIEW_TEST_ISOLATION:-}" = 1 ]'
check "harness gives the suite a private events directory" '[ -n "${AI_REVIEW_EVENT_DIR:-}" ] && [ -d "$AI_REVIEW_EVENT_DIR" ]'
check "private events directory is not the live ledger" '[ "$(cd "$AI_REVIEW_EVENT_DIR" && pwd -P)" != "$live" ]'
check "harness isolates outcome ledger beside private events" '[ "$AI_REVIEW_SCOREBOARD_FILE" = "$AI_REVIEW_EVENT_DIR/scoreboard/reviews.jsonl" ]'

# Exercise a real outcome append with hostile inherited caller locations.
# The sentinel represents the caller's ledger; never touch the actual live log.
mkdir -p "$TMP/parent-ledger"
printf 'caller-owned-sentinel\n' > "$TMP/parent-ledger/reviews.jsonl"
printf '{"run_id":"isolated-outcome-proof","caller":"codex"}\n' > "$TMP/outcome.json"
env AI_REVIEW_EVENT_DIR="$TMP/child-events" \
  AI_REVIEW_SCOREBOARD_DIR="$TMP/parent-ledger" \
  AI_REVIEW_SCOREBOARD_FILE="$TMP/parent-ledger/reviews.jsonl" bash -c \
  '. "$1/tests/lib-test-harness.sh"; "$1/bin/ai-review-scoreboard" append deepseek "$2" --elapsed 1 --failure incomplete-code-only-invocation >/dev/null' \
  _ "$ROOT" "$TMP/outcome.json"
check "nested test outcome records only in its private ledger" 'grep -q isolated-outcome-proof "$TMP/child-events/scoreboard/reviews.jsonl"'
check "nested test cannot append into inherited caller ledger" '[ "$(cat "$TMP/parent-ledger/reviews.jsonl")" = caller-owned-sentinel ]'

out="$(resolve AI_REVIEW_TEST_ISOLATION=1 AI_REVIEW_EVENT_DIR="$live" 2>&1)"; rc=$?
check "marker refuses an explicit live events directory" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q "refused the live reviewer events log"'

out="$(resolve -u AI_REVIEW_EVENT_DIR -u AI_REVIEWER_STATE_BASE AI_REVIEW_TEST_ISOLATION=1 HOME="$live_home" 2>&1)"; rc=$?
check "marker refuses the default live location" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q "refused the live reviewer events log"'

out="$(resolve -u AI_REVIEW_TEST_ISOLATION AI_REVIEW_EVENT_DIR="$live" 2>&1)"; rc=$?
check "real runs without the marker still use the live ledger" '[ "$rc" -eq 0 ] && [ "$out" = "$live" ]'

out="$(resolve -u AI_REVIEW_EVENT_DIR AI_REVIEW_TEST_ISOLATION=1 AI_REVIEWER_STATE_BASE="$TMP/base" 2>&1)"; rc=$?
check "marker allows a private state base" '[ "$rc" -eq 0 ] && same_path "$out" "$TMP/base/reviewer-events"'

out="$(resolve -u AI_REVIEW_EVENT_DIR -u AI_REVIEWER_STATE_BASE AI_REVIEW_TEST_ISOLATION=1 HOME="$TMP/home" 2>&1)"; rc=$?
check "marker allows a substituted test HOME" '[ "$rc" -eq 0 ] && same_path "$out" "$TMP/home/.local/state/ai-devops/reviewer-events"'

# Windows passed-head lookup: a missing cygpath skips that one report instead
# of raising out of the whole lookup (which ai-review-preflight turns into exit 3).
mkdir -p "$TMP/ph/runs/$(printf 'c%.0s' {1..64})/deepseek/claude"
cygpath_probe="$(cd "$ROOT/tools" && STATE="$TMP/ph" "$PY" - <<'PYEOF' 2>&1
import json, os, subprocess
from pathlib import Path
from unittest import mock
import reviewer_events as r
key = "c" * 64; head = "a" * 40; dig = "b" * 64; rid = "20261012T000000-1-1"
Path(os.environ["STATE"], "runs", key, "deepseek", "claude", rid + ".json").write_text(json.dumps({
    "schema_version": 1, "provider": "deepseek", "review_mode": "final-check", "head": head,
    "source_digest": dig, "repository_key": key, "status": "completed", "verdict": "APPROVE",
    "stale": False, "failure_class": None, "run_id": rid,
    "report_path": "/c/nowhere/deepseek-final-check-" + rid + ".md", "report_sha256": "0" * 64}))
class NtOs:
    name = "nt"
    def __getattr__(self, attr):
        return getattr(os, attr)
def no_cygpath(*a, **k):
    raise FileNotFoundError("cygpath")
with mock.patch.object(r, "os", NtOs()), mock.patch.object(r.subprocess, "run", no_cygpath):
    print("result=%r" % (r.find_passing_report(os.environ["STATE"], "deepseek", "final-check", head, dig, key),))
PYEOF
)"
check "passed-head skips a report when cygpath is missing" '[ "$cygpath_probe" = "result=None" ]'

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

# Real diagnostic writes must use the child fixture, never inherited live
# door/lifecycle custody. Empty parent destination catches first-write pollution;
# an existing report sentinel catches a separate report overwrite.
mkdir -p "$TMP/parent-custody" "$TMP/child-custody"
printf 'parent-report-sentinel\n' > "$TMP/parent-custody/report.md"
printf 'synthetic child native failure\n' > "$TMP/child-custody/native.stderr"
: > "$TMP/child-custody/native.jsonl"
env DOOR_DIAGNOSTICS_DIR="$TMP/parent-custody/diagnostics" \
  DOOR_REPORT_OUT="$TMP/parent-custody/report.md" DOOR_HEAD=parent-head \
  RLC_DOOR_DIAGNOSTICS_DIR="$TMP/parent-custody/diagnostics" RLC_STAMP=parent-stamp \
  AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_REVIEW_VIA_RUNNER=1 \
  AI_REVIEW_RUNNER_NAME=parent-run bash -c '
    . "$1/tests/lib-test-harness.sh"
    printf "%s|%s|%s|%s|%s|%s|%s|%s" "${DOOR_DIAGNOSTICS_DIR-unset}" "${DOOR_REPORT_OUT-unset}" "${DOOR_HEAD-unset}" "${RLC_DOOR_DIAGNOSTICS_DIR-unset}" "${RLC_STAMP-unset}" "${AI_REVIEW_RUNNER_CORE-unset}" "${AI_REVIEW_VIA_RUNNER-unset}" "${AI_REVIEW_RUNNER_NAME-unset}" > "$2/context.txt"
    "$3" "$1/tools/review_door_diagnostics.py" deepseek "$2/native.jsonl" "$2/native.stderr" 2 synthetic-child-failure "${DOOR_REPORT_OUT:-$2/report.md}" "${DOOR_DIAGNOSTICS_DIR:-$2/diagnostics}"
  ' _ "$ROOT" "$TMP/child-custody" "$PY"
check "offline child clears inherited door and runner custody context" '[ "$(cat "$TMP/child-custody/context.txt")" = "unset|unset|unset|unset|unset|unset|unset|unset" ]'
check "offline child retains real native evidence in its fixture" 'test -s "$TMP/child-custody/diagnostics/native.stderr" && grep -q synthetic-child-failure "$TMP/child-custody/diagnostics/report.md"'
check "offline child never creates parent live diagnostic destination" 'test ! -e "$TMP/parent-custody/diagnostics"'
check "offline child never overwrites parent live report" '[ "$(cat "$TMP/parent-custody/report.md")" = parent-report-sentinel ]'

# The native reviewer launch and the runner's --tests command must both strip
# live door/lifecycle custody from the child environment (#1562).
probe="$TMP/custody-probe"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s|%%s|%%s" "${DOOR_DIAGNOSTICS_DIR-unset}" "${RLC_DOOR_DIAGNOSTICS_DIR-unset}" "${DOOR_REPORT_OUT-unset}" "${AI_REVIEW_RUNNER_CORE-unset}" > "$1"\n' > "$probe"
chmod +x "$probe"
custody_seen="$(env DOOR_DIAGNOSTICS_DIR="$TMP/live/diag" RLC_DOOR_DIAGNOSTICS_DIR="$TMP/live/diag" \
  DOOR_REPORT_OUT="$TMP/live/report" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  bash -c '. "$1/tools/reviewer_event_guard.sh"; reviewer_credit_run deepseek "$2/out" "$2/err" -- "$3" "$2/seen" </dev/null >/dev/null 2>&1; cat "$2/seen" 2>/dev/null' _ "$ROOT" "$TMP" "$probe")"
check "native reviewer child never sees live door custody" '[ "$custody_seen" = "unset|unset|unset|unset" ]'

# Every offline suite that drives the review pool must source the shared
# isolation helper, directly or through lib-test-harness.sh.
unisolated=""
for suite in "$ROOT"/tests/test-*.sh; do
  grep -q 'ai-review-pool' "$suite" || continue
  grep -Eq '^[[:space:]]*(\.|source)[[:space:]].*lib-(reviewer-events-isolation|test-harness)\.sh' "$suite" \
    || unisolated="$unisolated ${suite##*/}"
done
check "every pool-invoking suite sources the isolation helper" '[ -z "$unisolated" ]'
[ -z "$unisolated" ] || printf 'unisolated suites:%s\n' "$unisolated" >&2

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
