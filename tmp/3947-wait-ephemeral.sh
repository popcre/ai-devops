#!/usr/bin/env bash
# Bounded waiter for PR 4047 required checks (scratch).
set -euo pipefail
GH=C:/repos/ai-devops/bin/ai-gh
PR=4047
REPO=popcre/shared-db
deadline=$(( $(date +%s) + 600 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  out="$("$GH" pr checks "$PR" --repo "$REPO" 2>/dev/null || true)"
  echo "---- $(date -u +%H:%M:%SZ) ----"
  echo "$out" | rg 'supabase/tests|Handoff|Migration guarded|pending|fail' || true
  if echo "$out" | rg -q 'supabase/tests.*pass'; then
    echo "EPHEMERAL_OK"
    exit 0
  fi
  if echo "$out" | rg 'supabase/tests.*fail'; then
    echo "EPHEMERAL_FAIL"
    exit 1
  fi
  sleep 25
done
echo "TIMEOUT waiting for ephemeral db test"
exit 3
