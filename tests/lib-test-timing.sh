#!/usr/bin/env bash
# Shared timing helpers for the AI reviewer test suites.
#
# WHY THIS FILE EXISTS
#
# These suites drive real wrapper processes and used to assert on wall-clock
# budgets — sub-five-second ceilings against a 900-second production default.
# A constant that is generous on an idle CI runner is a lost race on a loaded
# developer machine, so the same commit passed in GitHub Actions and failed
# intermittently on `edge-dev`. Measured on that box, one Grok wrapper round
# trip cost 15 seconds against roughly 1 second on the CI runner. The full
# diagnosis is in fix_test_ai.md at the repository root.
#
# NOTHING HERE WEAKENS AN ASSERTION. budget() never returns less than the floor
# it is given, so on a fast machine every ceiling keeps exactly the value it had
# before. The scaling only ever buys time on a machine that has been measured to
# need it, and every ceiling that is hit reports itself distinctly, so "the
# fixture never became ready" can never again be mistaken for "the wrapper
# misbehaved".
#
# USAGE
#   . "$(dirname "${BASH_SOURCE[0]}")/lib-test-timing.sh"
#   ai_test_measure_baseline <command performing one representative round trip>
#   ... or, where no cheap representative round trip exists:
#   ai_test_measure_spawn_baseline
#   CEILING="$(budget 10 15)"        # 10x the baseline, never below 15s
#   poll_until "$(budget 15 30)" 'the worker registered' "test -f '$MARKER'"

# Whole seconds. 1 means "as fast as an idle CI runner", which is the floor.
AI_TEST_BASELINE=1

# Upper bound on the measured baseline. Scaling exists to survive a busy
# machine, not to let one inflate the suite without limit: a run that takes
# hours because the box was thrashing is its own kind of broken. Past this
# point the honest answer is that the machine cannot meet the timing
# preconditions at all, and the cap is announced so that stays visible.
#
# 45 is measured, not guessed. On edge-dev one wrapper round trip costs ~15s
# with a single suite running, 26-42s with two, and 82s under a deliberate
# four-suite storm. A cap of 20 was too low: it clamped an ordinary two-suite
# run and cost that run eight checks. 45 covers realistic concurrent use and
# still refuses to let a thrashing machine inflate the suite without limit.
AI_TEST_BASELINE_CAP="${AI_TEST_BASELINE_CAP:-45}"

# ai_test_clamp_baseline LABEL - floor at 1, cap at AI_TEST_BASELINE_CAP, and
# say which happened. A capped baseline is a warning, never a silent change.
ai_test_clamp_baseline() {
  local measured="$AI_TEST_BASELINE"
  [ "$AI_TEST_BASELINE" -lt 1 ] && AI_TEST_BASELINE=1
  if [ "$AI_TEST_BASELINE" -gt "$AI_TEST_BASELINE_CAP" ]; then
    AI_TEST_BASELINE="$AI_TEST_BASELINE_CAP"
    printf '  note baseline %s: %ss, CAPPED to %ss - this machine is heavily loaded and timing-sensitive checks may still lose their races\n' \
      "$1" "$measured" "$AI_TEST_BASELINE" >&2
    return 0
  fi
  printf '  note baseline %s: %ss\n' "$1" "$AI_TEST_BASELINE"
}

# ai_test_measure_baseline COMMAND... — time one representative round trip.
# Prefer this: it measures the exact operation whose latency the ceilings bound.
ai_test_measure_baseline() {
  local start
  start="$(date +%s)"
  "$@" >/dev/null 2>&1 || true
  AI_TEST_BASELINE=$(( $(date +%s) - start ))
  ai_test_clamp_baseline 'wrapper round trip'
}

# ai_test_measure_spawn_baseline — for suites with no cheap representative round
# trip. Measures process spawn cost, which is what actually differs between an
# idle runner and a contended Windows box: every wrapper call pays it, several
# times over, before it does any work of its own.
ai_test_measure_spawn_baseline() {
  local start i
  start="$(date +%s)"
  for i in $(seq 1 40); do bash -c ':'; done
  AI_TEST_BASELINE=$(( $(date +%s) - start ))
  ai_test_clamp_baseline 'process spawn cost'
}

# budget FACTOR FLOOR -> seconds. Never below FLOOR, so an idle machine keeps
# the suite's original ceilings and every check keeps its original meaning.
budget() {
  local v=$(( AI_TEST_BASELINE * $1 ))
  [ "$v" -lt "$2" ] && v="$2"
  printf '%s' "$v"
}

# scale_ticks BASE_ITERATIONS -> iterations, scaled by the measured baseline.
# For the existing sub-second polling loops (`for _ in $(seq 1 100); ... sleep
# .05`), whose shape is already right and only whose ceiling was a guess.
scale_ticks() {
  local v=$(( $1 * AI_TEST_BASELINE ))
  [ "$v" -lt "$1" ] && v="$1"
  printf '%s' "$v"
}

# poll_until CEILING WHAT CONDITION... — wait for observable state instead of
# guessing with a fixed sleep. A ceiling hit is reported on stderr as a FIXTURE
# problem so it is never confused with a wrapper defect.
poll_until() {
  local ceiling="$1" what="$2"; shift 2
  local i=0
  while [ "$i" -lt "$ceiling" ]; do
    eval "$*" >/dev/null 2>&1 && return 0
    sleep 1; i=$((i + 1))
  done
  printf '  fixture: %s did not hold within %ss (baseline %ss)\n' "$what" "$ceiling" "$AI_TEST_BASELINE" >&2
  return 1
}

# fixture_expected WHAT CONDITION... — assert a fixture precondition without
# counting it as a suite check. Reports distinctly when the fixture, rather than
# the code under test, is what failed.
fixture_expected() {
  local what="$1"; shift
  eval "$*" >/dev/null 2>&1 && return 0
  printf '  fixture: %s (baseline %ss)\n' "$what" "$AI_TEST_BASELINE" >&2
  return 1
}
