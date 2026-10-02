#!/usr/bin/env bash
# Narrow #1183 child 3 assertions only (seconds, not minutes).
# Full waiter/blocker-watch suites already run in PR CI and the merge queue.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== explicit deadline required ==="
out=$(bin/ai-pr-wait 1 --repo popcre/ai-devops 2>&1) && rc=0 || rc=$?
test "$rc" -eq 3
echo "$out" | grep -q "explicit deadline only"
echo "pr-wait missing timeout refused OK"

out=$(bin/ai-gh-wait --until-regex x --interval 300 -- run view 1 2>&1) && rc=0 || rc=$?
test "$rc" -eq 3
echo "$out" | grep -q "explicit deadline only"
echo "gh-wait missing timeout refused OK"

out=$(bin/ai-pr-wait 1 --repo popcre/ai-devops --timeout-minutes 0 2>&1) && rc=0 || rc=$?
test "$rc" -eq 3
echo "pr-wait zero timeout refused OK"

echo "=== registration OUT ==="
! grep -q 'REGISTERED with' AGENTS.md
! grep -q 'REGISTERED with' docs/standing-rules-details.md
! grep -q 'Registration is the DEFAULT' docs/task-router.md
grep -q 'Registration is OUT' docs/task-router.md
! grep -q 'register a new wait' bin/ai-blocker-watch
! grep -RIn --include='SKILL.md' -E 'forces BlockerWatch registration|wakes parked cross-issue waits' skills
echo "registration residuals clean OK"

echo "=== no default deadlines ==="
! grep -q '^TIMEOUT_MINUTES=180' bin/ai-pr-wait
! grep -q 'TIMEOUT=120' bin/ai-gh-wait
grep -q 'explicit deadline only' bin/ai-pr-wait
grep -q 'explicit deadline only' bin/ai-gh-wait
echo "defaults removed OK"

echo "FOCUSED_OK"
