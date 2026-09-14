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

[ "$failures" -eq 0 ] || exit 1
printf 'verify-closure tests passed\n'
