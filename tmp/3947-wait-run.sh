#!/usr/bin/env bash
export PATH="/c/Program Files/GitHub CLI:$PATH"
set -euo pipefail
REPO="popcre/shared-db"
RUN_ID="${1:?run id}"
for i in $(seq 1 20); do
  s="$(gh run view "$RUN_ID" --repo "$REPO" --json status,conclusion --jq '.status + ":" + (.conclusion // "-")')"
  echo "poll $i: $s"
  case "$s" in
    completed:*) break ;;
  esac
  sleep 30
done
echo "FINAL:"
gh run view "$RUN_ID" --repo "$REPO" --json status,conclusion,jobs,url \
  --jq '{status,conclusion,url,jobs:[.jobs[]|{name,status,conclusion}]}'
