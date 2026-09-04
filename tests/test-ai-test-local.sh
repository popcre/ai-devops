#!/usr/bin/env bash
# Tests for tests/run-parallel.sh and bin/ai-test-local.
#
# Offline and fast: the runner is driven against tiny fixture suites through
# AI_TEST_SUITE_DIR, never against the real 70-minute set.
#
# The properties that must never regress:
#   - a failing suite makes the runner exit non-zero (a parallel runner that
#     swallows a failure is worse than no runner at all)
#   - every suite gets its own log file (a shared log once produced an
#     interleaved file and a believed-but-false failure count)
#   - --rerun-failed replays exactly the suites that failed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$REPO_ROOT/tests/run-parallel.sh"
LAUNCHER="$REPO_ROOT/bin/ai-test-local"
PASS=0; FAIL=0
ok()  { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SUITES="$WORK/suites"; LOGS="$WORK/logs"
mkdir -p "$SUITES" "$LOGS"

printf '#!/usr/bin/env bash\necho green-one\necho "TMPDIR=$TMPDIR"\nexit 0\n' > "$SUITES/test-green-one.sh"
printf '#!/usr/bin/env bash\necho green-two\necho "TMPDIR=$TMPDIR"\nexit 0\n' > "$SUITES/test-green-two.sh"
printf '#!/usr/bin/env bash\necho "  FAIL deliberate"\nexit 3\n' > "$SUITES/test-red.sh"
chmod +x "$SUITES"/*.sh

run() { AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" bash "$RUNNER" "$@"; }

# --- discovery -------------------------------------------------------------
listed="$(run --list -l "$LOGS/list" 2>/dev/null)"
check 'lists every fixture suite' '[ "$(printf "%s\n" "$listed" | wc -l)" -eq 3 ]'
check 'excludes the serial test-all runner' '! printf "%s" "$listed" | grep -q test-all'
filtered="$(run --list -p "test-green-*.sh" 2>/dev/null)"
check 'honours the -p filter' '[ "$(printf "%s\n" "$filtered" | wc -l)" -eq 2 ]'
run --list -p 'test-nothing-*.sh' >/dev/null 2>&1
check 'a filter that matches nothing is an error, not a silent pass' '[ "$?" -ne 0 ]'

# --- green path ------------------------------------------------------------
green_dir="$LOGS/green"
run -j 2 -p 'test-green-*.sh' -l "$green_dir" >"$WORK/green.out" 2>&1
green_rc=$?
check 'all-green run exits zero' '[ "$green_rc" -eq 0 ]'
check 'green run reports zero failures' 'grep -q "failures=0" "$WORK/green.out"'
check 'each suite has its own log' '[ -s "$green_dir/test-green-one.sh.log" ] && [ -s "$green_dir/test-green-two.sh.log" ]'
check 'a suite log holds only that suite output' 'grep -q green-one "$green_dir/test-green-one.sh.log" && ! grep -q green-two "$green_dir/test-green-one.sh.log"'
check 'each suite gets its own TMPDIR' 'one=$(sed -n "s/^TMPDIR=//p" "$green_dir/test-green-one.sh.log"); two=$(sed -n "s/^TMPDIR=//p" "$green_dir/test-green-two.sh.log"); [ -n "$one" ] && [ -n "$two" ] && [ "$one" != "$two" ]'
# Windows still caps most paths at 260 characters and the suites nest their own
# mktemp trees below TMPDIR. A temp path inside the log tree once broke six
# healthy suites, so the budget is asserted, not assumed.
check 'the suite TMPDIR is short enough for Windows' 'one=$(sed -n "s/^TMPDIR=//p" "$green_dir/test-green-one.sh.log"); [ "${#one}" -lt 100 ]'

# --- red path --------------------------------------------------------------
red_dir="$LOGS/red"
run -j 3 -l "$red_dir" >"$WORK/red.out" 2>&1
red_rc=$?
check 'a failing suite makes the runner exit non-zero' '[ "$red_rc" -ne 0 ]'
check 'the failing suite is named in the summary' 'grep -q "test-red.sh" "$WORK/red.out"'
check 'the failure count is exact' 'grep -q "failures=1" "$WORK/red.out"'
check 'the log path of the failure is printed' 'grep -q "test-red.sh.log" "$WORK/red.out"'
check 'the FAIL line from the suite is surfaced' 'grep -q "deliberate" "$WORK/red.out"'
check 'failed.txt lists exactly the failing suite' '[ "$(cat "$red_dir/failed.txt")" = "test-red.sh" ]'
check 'passing suites still ran alongside the failure' '[ -s "$red_dir/test-green-one.sh.log" ]'
check 'the suite exit code is preserved' '[ "$(cat "$red_dir/test-red.sh.rc")" = "3" ]'

# --- rerun-failed ----------------------------------------------------------
printf '#!/usr/bin/env bash\nexit 0\n' > "$SUITES/test-red.sh"
rerun_dir="$LOGS/rerun"
AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" bash "$RUNNER" -l "$rerun_dir" --rerun-failed >"$WORK/rerun.out" 2>&1
rerun_rc=$?
check 'rerun-failed replays only the failed suite' 'grep -q "1 suites" "$WORK/rerun.out"'
check 'rerun-failed passes once the suite is fixed' '[ "$rerun_rc" -eq 0 ]'

# --- argument validation ---------------------------------------------------
run -j 0 --list >/dev/null 2>&1;  check 'rejects -j 0' '[ "$?" -ne 0 ]'
run -j abc --list >/dev/null 2>&1; check 'rejects a non-numeric -j' '[ "$?" -ne 0 ]'
run --nonsense >/dev/null 2>&1;    check 'rejects an unknown option' '[ "$?" -ne 0 ]'

# --- default worker count --------------------------------------------------
# The default must stay a QUARTER of the cores, capped at 8. It shipped as
# min(cores, 16) in #146, which on this 20-core desktop meant 16 concurrent
# suites -- double the eight that starved the runner's heartbeat and killed a
# CI job on 2026-08-28. The PowerShell twin always had this right.
FAKEBIN="$WORK/fakebin"; mkdir -p "$FAKEBIN"
workers_for() {
  { echo '#!/usr/bin/env bash'; echo "echo $1"; } > "$FAKEBIN/nproc"
  chmod +x "$FAKEBIN/nproc"
  PATH="$FAKEBIN:$PATH" AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" \
    bash "$RUNNER" -p 'test-green-*.sh' -l "$LOGS/j$1" 2>/dev/null |
    sed -n 's/^run-parallel: .* suites, \([0-9][0-9]*\) workers.*/\1/p'
}
check 'a 20-core machine defaults to 5 workers, not 16' '[ "$(workers_for 20)" = "5" ]'
check 'the cap holds at 8 on a 64-core machine' '[ "$(workers_for 64)" = "8" ]'
check 'a 2-core machine still gets one worker' '[ "$(workers_for 2)" = "1" ]'
check 'the usage text states the real policy' \
  'bash "$RUNNER" -h | grep -q "a quarter of this machine.s cores, max 8"'

# --- launcher --------------------------------------------------------------
check 'ai-test-local is executable' '[ -x "$LAUNCHER" ]'
check 'ai-test-local has valid syntax' 'bash -n "$LAUNCHER"'
check 'ai-test-local help lists every CI-job mode' 'bash "$LAUNCHER" --help | grep -q -- --reviewer && bash "$LAUNCHER" --help | grep -q -- --powershell'
bash "$LAUNCHER" --nonsense >/dev/null 2>&1
check 'ai-test-local rejects an unknown option' '[ "$?" -ne 0 ]'
check 'the reviewer mode targets exactly the two reviewer suites' \
  '[ "$(bash "$RUNNER" --list -p "test-ai-@(grok-review|codex-review).sh" | wc -l)" -eq 2 ]'

# --- CI collision guard ----------------------------------------------------
# ai-test-local must refuse to start when a CI job is live on THIS host, and
# must NOT care about a job on any other runner in the pool. Both halves matter:
# the first prevents the 2026-08-28 mutual kill, the second is why we own a
# pool at all.
#
# Everything here is driven by FIXTURES: a fake .runner tree via
# AI_TEST_RUNNER_DIRS and a stub gh on PATH. The first version of these tests
# read the machine's real runner install, which meant they silently skipped on
# both GitHub-hosted CI lanes -- a green pipeline that proved nothing about the
# guard. Never gate these on a real runner being present.
GHBIN="$WORK/ghbin"; mkdir -p "$GHBIN"
RDIR="$WORK/runners/actions-runner"; mkdir -p "$RDIR"
stub_gh() {
  { echo '#!/usr/bin/env bash'
    echo '[ "${1:-}" = api ] || exit 0'
    printf 'cat <<BUSY\n%s\nBUSY\n' "$1"
  } > "$GHBIN/gh"
  chmod +x "$GHBIN/gh"
}
fixture_runner() { printf '{ "agentId": 1, "agentName": "%s" }\n' "$1" > "$RDIR/.runner"; }
guard_run() {
  PATH="$GHBIN:$PATH" AI_TEST_RUNNER_DIRS="$WORK/runners/actions-runner*" \
    AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" \
    bash "$LAUNCHER" --bash "$@" 2>&1
}
fixture_runner 'edge-fixture-win'

stub_gh 'edge-fixture-win'; out="$(guard_run)"; rc=$?
check "refuses when this host's own runner is busy" '[ "$rc" -eq 3 ]'
check 'the refusal names the busy runner on this host' 'printf "%s" "$out" | grep -q edge-fixture-win'

guard_run --force >/dev/null 2>&1; frc=$?
check '--force overrides the refusal' '[ "$frc" -ne 3 ]'
fout="$(guard_run --force 2>&1)"
check '--force says so, rather than skipping the check silently' \
  'printf "%s" "$fout" | grep -q -- --force'

stub_gh 'some-other-host-runner'; guard_run >/dev/null 2>&1; orc=$?
check 'a busy runner on another host does not block' '[ "$orc" -ne 3 ]'

# The API reports EDGE-ALIEN where that host's .runner says edge-alien. An
# exact compare fails OPEN there -- it starts the series on a busy machine
# while reporting all clear -- so case must not matter.
stub_gh 'EDGE-FIXTURE-WIN'; guard_run >/dev/null 2>&1; crc=$?
check 'a case difference between the API and .runner still refuses' '[ "$crc" -eq 3 ]'

# Same for a stray CR, which is easy to acquire from a Windows tool.
printf '{ "agentName": "edge-fixture-win" }\r\n' > "$RDIR/.runner"
stub_gh 'edge-fixture-win'; guard_run >/dev/null 2>&1; rrc=$?
check 'a CR in the runner name still refuses' '[ "$rrc" -eq 3 ]'
fixture_runner 'edge-fixture-win'

# No runner installed here at all: proceed. A developer laptop must not be
# blocked by a guard aimed at hosts that run CI.
PATH="$GHBIN:$PATH" AI_TEST_RUNNER_DIRS="$WORK/no-such-runner*" \
  AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" \
  bash "$LAUNCHER" --bash >/dev/null 2>&1; nrc=$?
check 'a machine with no runner installed is never blocked' '[ "$nrc" -ne 3 ]'

# Fails open, deliberately: a pre-check that cannot run must not stop the work.
{ echo '#!/usr/bin/env bash'; echo 'exit 1'; } > "$GHBIN/gh"; chmod +x "$GHBIN/gh"
guard_run >/dev/null 2>&1; erc=$?
check 'an unusable gh fails open rather than blocking' '[ "$erc" -ne 3 ]'

# --- mid-run CI arrival ----------------------------------------------------
# The launcher checks once, at start-up. A 65-minute series started while idle
# is still handed a job halfway through, so run-parallel.sh watches for the
# runner's worker process between suites and stops launching more. The process
# name is overridable so this can be tested without a live CI job.
# A real process is started so the detector exercises its real code path; only
# the name it looks for is overridden. `sleep` exists on both platforms.
sleep 45 & sleeper=$!
AI_TEST_RUNNER_PROC=sleep AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" \
  bash "$RUNNER" -l "$LOGS/ciabort" >"$WORK/abort.out" 2>&1; arc=$?
kill "$sleeper" 2>/dev/null
check 'a CI job appearing mid-series stops further launches' \
  'grep -q STOPPING "$WORK/abort.out"'
check 'a series cut short by CI never reports green' '[ "$arc" -ne 0 ]'
check 'the cut-short run says it proves nothing' \
  'grep -q "proves nothing" "$WORK/abort.out"'
AI_TEST_IGNORE_CI=1 AI_TEST_SUITE_DIR="$SUITES" AI_TEST_LOG_ROOT="$LOGS" \
  bash "$RUNNER" -l "$LOGS/noabort" >"$WORK/noabort.out" 2>&1
check 'no CI job means no interruption' '! grep -q STOPPING "$WORK/noabort.out"'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
