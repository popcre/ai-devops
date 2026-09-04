#!/usr/bin/env bash
# Run the offline Bash suites concurrently on this machine.
#
# tests/test-all.sh runs the same suites one at a time; on a 20-core desktop that
# wastes almost all of the machine. This runner shards them across worker slots,
# gives every suite its own uniquely named log (a shared log produced an
# interleaved file and a bogus result once — never share one), and reports which
# suites failed and where to read why.
#
# It changes nothing about the suites themselves: same scripts, same assertions,
# same exit codes. Only the scheduling differs.
set -uo pipefail
shopt -s extglob

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The suite directory is overridable so the runner's own test can drive it with
# tiny fixture suites instead of the real 70-minute set.
SUITE_DIR="${AI_TEST_SUITE_DIR:-$ROOT/tests}"

detect_cpus() {
  if command -v nproc >/dev/null 2>&1; then nproc; else echo 4; fi
}

# A quarter of the cores by default, and never more than 8.
#
# This is measured, not guessed. On a 20-core desktop, -j 10 turned two suites
# red that pass on their own — test-ai-grok-review.sh and
# test-ai-review-lifecycle.sh, both of which wait on wall-clock deadlines. A
# loaded machine makes every wait slower, which is precisely the defect class of
# issue #89. Until every reviewer suite derives its budgets from a measured
# per-machine baseline, a conservative default is the difference between a
# runner you can trust and one that cries wolf.
#
# Raise it with -j only when you accept that a red result may be the load.
default_jobs() {
  local cpus; cpus="$(detect_cpus)"
  local n=$(( cpus / 4 ))
  [ "$n" -lt 1 ] && n=1
  [ "$n" -gt 8 ] && n=8
  echo "$n"
}

JOBS=""
PATTERN=""
LOG_DIR=""
LIST_ONLY=0
RERUN_FAILED=0

usage() {
  cat <<'USAGE'
usage: tests/run-parallel.sh [options]

  -j N            worker slots (default: a quarter of this machine's cores, max 8)
  -p PATTERN      only suites whose filename matches this shell pattern
  -l DIR          log directory (default: a fresh dir under the repo's .test-logs)
  --list          print the suites that would run, then exit
  --rerun-failed  run only the suites listed in the newest run's failed.txt
  -h              this help

Every suite writes <log-dir>/<suite>.log. Failing suites are listed at the end
with their log paths, and in <log-dir>/failed.txt.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -j) JOBS="${2:-}"; shift 2 ;;
    -p) PATTERN="${2:-}"; shift 2 ;;
    -l) LOG_DIR="${2:-}"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --rerun-failed) RERUN_FAILED=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$JOBS" ] || JOBS="$(default_jobs)"
case "$JOBS" in ''|*[!0-9]*) printf 'run-parallel: -j needs a whole number, got %s\n' "$JOBS" >&2; exit 2 ;; esac
[ "$JOBS" -ge 1 ] || { printf 'run-parallel: -j must be at least 1\n' >&2; exit 2; }

LOG_ROOT="${AI_TEST_LOG_ROOT:-$ROOT/.test-logs}"
if [ "$RERUN_FAILED" = 1 ]; then
  # Newest run directory that actually recorded a failure list.
  prev=""
  while IFS= read -r dir; do
    [ -s "$dir/failed.txt" ] && prev="$dir"
  done < <(find "$LOG_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort)
  [ -n "$prev" ] || {
    printf 'run-parallel: no previous run recorded a failure under %s
' "$LOG_ROOT" >&2
    exit 2
  }
fi
if [ -z "$LOG_DIR" ]; then
  LOG_DIR="$LOG_ROOT/bash-$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi
mkdir -p "$LOG_DIR" || exit 1

# Collect the suites. Same discovery rule as tests/test-all.sh.
suites=()
if [ "$RERUN_FAILED" = 1 ]; then
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -f "$SUITE_DIR/$name" ] && suites+=("$name")
  done < "$prev/failed.txt"
else
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ -n "$PATTERN" ]; then
      case "$name" in $PATTERN) ;; *) continue ;; esac
    fi
    suites+=("$name")
  done < <(find "$SUITE_DIR" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)
fi

[ "${#suites[@]}" -gt 0 ] || { printf 'run-parallel: no suites matched\n' >&2; exit 2; }

if [ "$LIST_ONLY" = 1 ]; then
  printf '%s\n' "${suites[@]}"
  exit 0
fi

# Slowest first: with a fixed number of slots, starting a 16-minute suite last
# leaves every other slot idle waiting for it.
KNOWN_SLOW='test-ai-grok-review.sh test-ai-glm.sh test-ai-qwen.sh test-ai-gemini.sh test-ai-kimi.sh test-ai-muse.sh test-ai-codex-review.sh test-ai-claude-review.sh test-ai-review-packet.sh test-ai-memory-health.sh test-ai-review-sandbox.sh test-ai-run-task.sh test-ai-config-migrate.sh'

# Slowest known suites first, then everything else in discovery order.
order_by_cost() {
  local -n _in="$1" _out="$2"
  local slow name skip
  _out=()
  for slow in $KNOWN_SLOW; do
    for name in "${_in[@]}"; do [ "$name" = "$slow" ] && _out+=("$name"); done
  done
  for name in "${_in[@]}"; do
    skip=0
    for slow in $KNOWN_SLOW; do [ "$name" = "$slow" ] && skip=1; done
    [ "$skip" = 0 ] && _out+=("$name")
  done
}

order_by_cost suites ordered; suites=("${ordered[@]}")

# Short-lived temp root outside the log tree; see run_one.
TMP_ROOT="$(dirname "$(mktemp -u)")/ait-$$"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

printf 'run-parallel: %s suites, %s workers, logs in %s\n\n' \
  "${#suites[@]}" "$JOBS" "$LOG_DIR"

run_one() {
  local name="$1" log="$LOG_DIR/$name.log" start end rc
  # Each suite gets its own TMPDIR so concurrent runs cannot collide on a
  # temp name, and so a crashed suite's leftovers are attributable.
  # Short path on purpose. Windows still caps most paths at 260 characters, and
  # the suites nest their own mktemp trees several levels below TMPDIR. Handing
  # them a temp directory inside .test-logs (already ~140 characters deep in a
  # worktree) silently broke file writes and turned six healthy suites red.
  local tmp="$TMP_ROOT/${name#test-}"
  mkdir -p "$tmp"
  start="$(date +%s)"
  TMPDIR="$tmp" TMP="$tmp" TEMP="$tmp" AI_TEST_PARALLEL=1 \
    bash "$SUITE_DIR/$name" >"$log" 2>&1
  rc=$?
  end="$(date +%s)"
  printf '%s\n' "$rc" > "$LOG_DIR/$name.rc"
  printf '%s\n' "$(( end - start ))" > "$LOG_DIR/$name.secs"
  if [ "$rc" -eq 0 ]; then
    printf '  pass  %-46s %4ss\n' "$name" "$(( end - start ))"
  else
    printf '  FAIL  %-46s %4ss  rc=%s\n' "$name" "$(( end - start ))" "$rc"
  fi
}

# Stop launching new suites if a CI job starts on THIS machine mid-series.
#
# bin/ai-test-local checks the GitHub API once, at start-up. That cannot see a
# job dispatched ten minutes into a 65-minute series -- and GitHub will dispatch
# one, because a runner's "busy" flag only reflects jobs it accepted, so a local
# shell suite is invisible to it. This is the other half of the same guard, and
# it is the only one that covers a direct `tests/run-parallel.sh` run.
#
# The signal is local, not the API: the runner spawns Runner.Worker only while a
# job is actually executing. No polling of GitHub (docs/critical-incidents.md
# warns that tight Actions polling trips a secondary rate limit), and nothing
# here can be influenced by a job on any other host.
#
# We stop OUR work, never CI's. Suites already running are allowed to finish.
[ -n "${AI_TEST_RUNNER_PROC:-}" ] && AI_TEST_RUNNER_PROC_SET=1
AI_TEST_RUNNER_PROC="${AI_TEST_RUNNER_PROC:-Runner.Worker}"
ci_job_on_this_host() {
  [ "${AI_TEST_IGNORE_CI:-0}" = 1 ] && return 1
  # Inside a CI job we ARE the runner worker; do not abort our own job.
  [ -n "${GITHUB_ACTIONS:-}" ] && [ -z "${AI_TEST_RUNNER_PROC_SET:-}" ] && return 1
  if command -v tasklist >/dev/null 2>&1; then
    tasklist //FI "IMAGENAME eq $AI_TEST_RUNNER_PROC.exe" 2>/dev/null |
      grep -qi "$AI_TEST_RUNNER_PROC" && return 0
  fi
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$AI_TEST_RUNNER_PROC" >/dev/null 2>&1 && return 0
  fi
  return 1
}

CI_ABORT=0
suite_start="$(date +%s)"

# A pool of background jobs, at most $2 at a time.
run_pool() {
  local -n _items="$1"
  local slots="$2" running=0 name
  [ "${#_items[@]}" -gt 0 ] || return 0
  for name in "${_items[@]}"; do
    while [ "$running" -ge "$slots" ]; do
      wait -n 2>/dev/null || wait
      running=$(( running - 1 ))
    done
    if ci_job_on_this_host; then
      CI_ABORT=1
      cat <<'STOPMSG'

  STOPPING: a CI job started on this machine.
  A local series and a CI job on the same host kill each other
  (docs/critical-incidents.md, 2026-08-28). Suites already running
  will finish; the rest were not launched.

STOPMSG
      break
    fi
    run_one "$name" &
    running=$(( running + 1 ))
  done
  wait
}

run_pool suites "$JOBS"
suite_end="$(date +%s)"

failed=()
total_cpu=0
for name in "${suites[@]}"; do
  rc="$(cat "$LOG_DIR/$name.rc" 2>/dev/null || echo 1)"
  secs="$(cat "$LOG_DIR/$name.secs" 2>/dev/null || echo 0)"
  total_cpu=$(( total_cpu + secs ))
  [ "$rc" -eq 0 ] || failed+=("$name")
done

: > "$LOG_DIR/failed.txt"
[ "${#failed[@]}" -gt 0 ] && printf '%s\n' "${failed[@]}" > "$LOG_DIR/failed.txt"

wall=$(( suite_end - suite_start ))
printf '\nPARALLEL BASH SUMMARY tests=%s failures=%s wall=%ss serial-equivalent=%ss workers=%s\n' \
  "${#suites[@]}" "${#failed[@]}" "$wall" "$total_cpu" "$JOBS"

if [ "$CI_ABORT" -eq 1 ]; then
  cat <<'CUTMSG'

This run was CUT SHORT by a CI job on this machine and proves nothing.
Suites that never ran are counted as failures on purpose -- an aborted
series must never read as green. Rerun when the runner here is idle.
CUTMSG
fi

if [ "${#failed[@]}" -gt 0 ]; then
  printf '\nFailing suites — read the log, do not assume flake:\n'
  for name in "${failed[@]}"; do
    printf '  %s\n    %s\n' "$name" "$LOG_DIR/$name.log"
    grep -E '^\s*FAIL ' "$LOG_DIR/$name.log" | head -n 5 | sed 's/^/      /'
  done
  printf '\nRerun just these with: bash tests/run-parallel.sh --rerun-failed\n'
  exit 1
fi
exit 0
