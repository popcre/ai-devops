#!/usr/bin/env bash
# Regression test for tools/ci/edge-dev3-route.sh, the reusable router that
# sends a job to edge-dev3 only when its heartbeat proves the runner online and
# idle, and to GitHub-hosted in every other case (owner request 2026-11-03).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/tools/ci/edge-dev3-route.sh"
fail=0
SH='["self-hosted","Linux","X64","ai-devops-linux"]'
check() { # label expected env...
  local label="$1" want="$2"; shift 2
  local got; got="$(env -i PATH="$PATH" NOW=1800000000 REPOSITORY=o/r "$@" bash "$R" 2>/dev/null)"
  if [ "$got" = "$want" ]; then printf '  ok   %s\n' "$label"; else printf '  FAIL %s: got %s want %s\n' "$label" "$got" "$want" >&2; fail=1; fi
}
check 'fresh idle heartbeat routes to edge-dev3' "$SH" EVENT_NAME=push HEARTBEAT=online,idle,1799999900
check 'same-repo pull request routes to edge-dev3' "$SH" EVENT_NAME=pull_request HEAD_REPO=o/r HEARTBEAT=online,idle,1799999900
check 'fork pull request stays hosted' '"ubuntu-24.04"' EVENT_NAME=pull_request HEAD_REPO=f/r HEARTBEAT=online,idle,1799999900
check 'pull request with no head repo stays hosted' '"ubuntu-24.04"' EVENT_NAME=pull_request HEARTBEAT=online,idle,1799999900
check 'pull_request_target stays hosted' '"ubuntu-24.04"' EVENT_NAME=pull_request_target HEAD_REPO=o/r HEARTBEAT=online,idle,1799999900
check 'busy runner stays hosted' '"ubuntu-24.04"' EVENT_NAME=push HEARTBEAT=online,busy,1799999900
check 'offline runner stays hosted' '"ubuntu-24.04"' EVENT_NAME=push HEARTBEAT=offline,idle,1799999900
check 'stale heartbeat stays hosted' '"ubuntu-24.04"' EVENT_NAME=push HEARTBEAT=online,idle,1799999000
check 'missing heartbeat stays hosted' '"ubuntu-24.04"' EVENT_NAME=push
check 'malformed heartbeat stays hosted' '"ubuntu-24.04"' EVENT_NAME=push 'HEARTBEAT=online,idle,abc'
check 'custom fallback is honored' '"ubuntu-22.04"' EVENT_NAME=push FALLBACK=ubuntu-22.04
check 'custom labels are honored' '["self-hosted","edge-dev3"]' EVENT_NAME=push HEARTBEAT=online,idle,1799999900 'SELF_HOSTED=["self-hosted","edge-dev3"]'
check 'labels without self-hosted stay hosted' '"ubuntu-24.04"' EVENT_NAME=push HEARTBEAT=online,idle,1799999900 'SELF_HOSTED=["ubuntu-24.04"]'
check 'non-array labels stay hosted' '"ubuntu-24.04"' EVENT_NAME=push HEARTBEAT=online,idle,1799999900 'SELF_HOSTED=nope'
[ "$fail" -eq 0 ] && echo 'PASS test-ci-edge-dev3-route' || exit 1
