#!/usr/bin/env bash
set -euo pipefail
GH=C:/repos/ai-devops/bin/ai-gh
REPO=popcre/shared-db
RUN_ID="${1:?run id}"
MINUTES="${2:-15}"
deadline=$(( $(date +%s) + MINUTES * 60 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  echo "==== $(date -u +%H:%M:%SZ) run $RUN_ID ===="
  "$GH" run view "$RUN_ID" --repo "$REPO" 2>&1 | head -35
  status="$("$GH" run view "$RUN_ID" --repo "$REPO" --json status --jq .status 2>/dev/null || echo unknown)"
  if [ "$status" = "completed" ]; then
    conclusion="$("$GH" run view "$RUN_ID" --repo "$REPO" --json conclusion --jq .conclusion 2>/dev/null || echo unknown)"
    echo "COMPLETED conclusion=$conclusion"
    exit 0
  fi
  sleep 25
done
echo "TIMEOUT"
exit 3
