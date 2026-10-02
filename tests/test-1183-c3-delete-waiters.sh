#!/usr/bin/env bash
# Bound to this snapshot: resolve the repo root from this script's location.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
test -f bin/ai-pr-wait
test -f bin/ai-gh-wait
test -f bin/ai-blocker-watch
echo "=== ai-pr-wait ==="
bash tests/test-ai-pr-wait.sh | tail -1
echo "=== ai-gh waiter CLI ==="
out=$(bin/ai-pr-wait 1 --repo popcre/ai-devops 2>&1) && rc=0 || rc=$?
test "$rc" -eq 3
echo "$out" | grep -q "explicit deadline only"
echo "pr-wait deadline gate OK"
out=$(bin/ai-gh-wait --until-regex x --interval 300 -- run view 1 2>&1) && rc=0 || rc=$?
test "$rc" -eq 3
echo "$out" | grep -q "explicit deadline only"
echo "gh-wait deadline gate OK"
echo "=== completion-eval ==="
bash tests/test-completion-eval.sh | tail -1
echo "=== session-conduct ==="
bash tests/test-session-conduct-policy.sh | tail -1
echo "FOCUSED_OK"
