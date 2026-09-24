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

check 'a complete code pull request closes' bash "$TOOL" pull_request success true success success success success
check 'a classified prose-only pull request closes with the declared Linux skip' bash "$TOOL" pull_request success false success skipped success success
reject 'an unfinished exact-head Windows run cannot close' bash "$TOOL" pull_request success true success success skipped success
reject 'a failed exact-head reviewer run cannot close' bash "$TOOL" pull_request success true success success success failure
reject 'a failed merge-group evidence gate blocks closure' bash "$TOOL" merge_group success true failure success skipped skipped
reject 'a failed merge-group Linux run blocks closure' bash "$TOOL" merge_group success true success failure skipped skipped
check 'a complete merge group closes without repeating Windows suites' bash "$TOOL" merge_group success true success success skipped skipped
reject 'a classifier failure remains fail closed' bash "$TOOL" pull_request failure true success success success success
reject 'a missing run-long output remains fail closed' bash "$TOOL" pull_request success '' success skipped success success
reject 'a malformed run-long output remains fail closed' bash "$TOOL" pull_request success maybe success skipped success success

# hosted-start-watch.sh (#742): a hosted Windows lane still queued past its
# start deadline is diverted to Blacksmith; a started lane is waited on and its
# real result reported. A stub gh answers from a file.
WATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/ci/hosted-start-watch.sh"
WTMP="$(mktemp -d)"
mkdir -p "$WTMP/bin"
cat >"$WTMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
cat "$WATCH_JOBS"
STUB
chmod +x "$WTMP/bin/gh"
watch_case() { # expected-output lane-lines key expected deadline
  local want="$1" lines="$2"; shift 2
  printf '%b' "$lines" >"$WTMP/jobs"
  : >"$WTMP/out"
  PATH="$WTMP/bin:$PATH" WATCH_JOBS="$WTMP/jobs" GITHUB_REPOSITORY=o/r GITHUB_RUN_ID=1 \
    GITHUB_OUTPUT="$WTMP/out" HOSTED_START_WATCH_POLL_SECONDS=0 bash "$WATCH" "$@" >/dev/null 2>&1 &&
    grep -qx "$want" "$WTMP/out"
}
check 'a lane queued past its deadline is diverted' watch_case 'divert=true' 'queued\t\nin_progress\t\n' sec 2 0
check 'a lane with a job not yet created is diverted' watch_case 'hosted_result=diverted' 'in_progress\t\n' sec 2 0
check 'a started lane is not diverted and reports success' watch_case 'hosted_result=success' 'completed\tsuccess\ncompleted\tsuccess\n' sec 2 0
check 'a started lane that failed reports failure, never diverted' watch_case 'hosted_result=failure' 'completed\tsuccess\ncompleted\tfailure\n' sec 2 0
check 'a cancelled hosted job is a failure' watch_case 'hosted_result=failure' 'completed\tcancelled\n' fb 1 0
rm -rf "$WTMP"

[ "$failures" -eq 0 ] || exit 1
printf 'verify-closure tests passed\n'
