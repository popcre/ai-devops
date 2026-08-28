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

printf '#!/usr/bin/env bash\necho green-one\nexit 0\n' > "$SUITES/test-green-one.sh"
printf '#!/usr/bin/env bash\necho green-two\nexit 0\n' > "$SUITES/test-green-two.sh"
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
check 'each suite gets its own TMPDIR' '[ -d "$green_dir/tmp/test-green-one.sh" ]'

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

# --- launcher --------------------------------------------------------------
check 'ai-test-local is executable' '[ -x "$LAUNCHER" ]'
check 'ai-test-local has valid syntax' 'bash -n "$LAUNCHER"'
check 'ai-test-local help lists every CI-job mode' 'bash "$LAUNCHER" --help | grep -q -- --reviewer && bash "$LAUNCHER" --help | grep -q -- --powershell'
bash "$LAUNCHER" --nonsense >/dev/null 2>&1
check 'ai-test-local rejects an unknown option' '[ "$?" -ne 0 ]'
check 'the reviewer mode targets exactly the two reviewer suites' \
  '[ "$(bash "$RUNNER" --list -p "test-ai-@(grok-review|codex-review).sh" | wc -l)" -eq 2 ]'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
