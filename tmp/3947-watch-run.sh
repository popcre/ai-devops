#!/usr/bin/env bash
# Bounded watcher for a workflow run (scratch).
set -euo pipefail
GH=C:/repos/ai-devops/bin/ai-gh
REPO=popcre/shared-db
RUN_ID="${1:?run id}"
MINUTES="${2:-20}"
deadline=$(( $(date +%s) + MINUTES * 60 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  st="$("$GH" run view "$RUN_ID" --repo "$REPO" --json status,conclusion,jobs 2>/dev/null || echo '{}')"
  echo "---- $(date -u +%H:%M:%SZ) ----"
  echo "$st" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('status'), d.get('conclusion'));
[print(' ', j.get('name'), j.get('status'), j.get('conclusion')) for j in d.get('jobs') or []]" 2>/dev/null || echo "$st" | head -c 500
  echo "$st" | rg -q '"status":"completed"' && { echo "COMPLETED conclusion=$(echo "$st" | python -c 'import sys,json; print(json.load(sys.stdin).get(\"conclusion\"))' 2>/dev/null)"; exit 0; }
  sleep 30
done
echo "TIMEOUT after ${MINUTES}m on run $RUN_ID"
exit 3
