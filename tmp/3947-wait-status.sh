#!/usr/bin/env bash
export PATH="/c/Program Files/GitHub CLI:/c/repos/ai-devops/bin:$PATH"
set -euo pipefail
SHA="${1:?sha}"
REPO="popcre/shared-db"
for i in $(seq 1 20); do
  out="$(ai-gh api "repos/$REPO/commits/$SHA/status" --jq '{state,statuses:[.statuses[]|{context,state,description}]}')"
  echo "poll $i: $out"
  echo "$out" | grep -q 'Migration guarded merge authorization' && echo "$out" | grep -q '"state":"success"' && break
  sleep 15
done
echo "DONE"
