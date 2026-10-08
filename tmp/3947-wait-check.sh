#!/usr/bin/env bash
export PATH="/c/Program Files/GitHub CLI:$PATH"
set -euo pipefail
SHA="e35c1ecde901b55e7ed3a343da685d5f2c4c7a37"
REPO="popcre/shared-db"
for i in $(seq 1 15); do
  out="$(gh api "repos/$REPO/commits/$SHA/check-runs" --jq '[.check_runs[]|select(.name=="supabase/tests against an ephemeral database")|{status,conclusion}]|first')"
  echo "poll $i: $out"
  echo "$out" | grep -q '"status":"completed"' && break
  sleep 20
done
echo "FINAL:"
gh api "repos/$REPO/commits/$SHA/check-runs" --jq '[.check_runs[]|select(.name=="supabase/tests against an ephemeral database" or .name=="Migration guarded merge authorization")|{name,status,conclusion}]'
