#!/usr/bin/env bash
# 3947-fire-production-apply.sh
#
# Staged dispatch for shared-db #3947. Fires the historical preview recovery
# lane; the workflow's OWN automatic-production-promotion job then dispatches
# production. NEVER hand-dispatch target=production with these inputs.
#
# Prepared 2026-10-07 15:40 EDT (America/New_York). Times below are EST/EDT.
#
# Preconditions before the coordinator fires this:
#   1. A fence-bearing APPROVE exists at live main for PR #3957
#      head f8b8b32139380911c315001238e63a149af5fda9.
#   2. The assessment's main_sha is passed as $1 and still equals origin/main.
#
# Usage:
#   bash C:/repos/ai-devops/tmp/3947-fire-production-apply.sh <assessment-main-sha>
#
# Known-good historical recovery inputs (mirror run 37648319800):
#   historical_preview_source_pr=3957
#   historical_preview_original_run_map=20261007020907:37572585770
#   preview_allowlist=20261007020907
#   target=preview  mode=apply   (historical recovery is apply-only)
#
# Ledger proof (READ ONLY — run AFTER the production apply, never writes):
#   op run --no-masking \
#     --env 'PGPASSWORD=op://vibe_coding/Supabase DB Password - shared POP database/password' \
#     -- psql "host=aws-1-us-east-1.pooler.supabase.com port=6543 dbname=postgres \
#              user=postgres.qsllyeztdwjgirsysgai sslmode=require" \
#        -tAc "select version, name from supabase_migrations.schema_migrations \
#              where version = '20261007020907'"

set -euo pipefail

EXPECTED_SHA="${1:?usage: $0 <assessment-main-sha>}"
REPO="popcre/shared-db"
WORKFLOW="shared-supabase-migrations.yml"
SHARED_DB_DIR="${SHARED_DB_DIR:-C:/repos/shared-db}"
AI_DEVOPS_BIN="${AI_DEVOPS_BIN:-C:/repos/ai-devops/bin}"

# Known-good historical recovery inputs (mirror run 37648319800).
HISTORICAL_PREVIEW_SOURCE_PR="3957"
HISTORICAL_PREVIEW_ORIGINAL_RUN_MAP="20261007020907:37572585770"
PREVIEW_ALLOWLIST="20261007020907"

# Exact-head APPROVE gate target: PR #3957 at its live head.
PR_NUMBER="3957"
REQUESTED_SHA="f8b8b32139380911c315001238e63a149af5fda9"

# ---------------------------------------------------------------------------
# 1. Re-read MAIN_SHA from origin/main and assert it equals the assessment's.
# ---------------------------------------------------------------------------
git -C "$SHARED_DB_DIR" fetch --quiet origin main
MAIN_SHA="$(git -C "$SHARED_DB_DIR" rev-parse origin/main)"
echo "origin/main = $MAIN_SHA"
if [ "$MAIN_SHA" != "$EXPECTED_SHA" ]; then
  echo "REFUSED: origin/main moved. expected=$EXPECTED_SHA live=$MAIN_SHA" >&2
  echo "Re-assess before firing. Nothing was dispatched." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Fence-bearing exact-head APPROVE check (read-only gate).
# ---------------------------------------------------------------------------
echo "Checking exact-head approval for PR #$PR_NUMBER at $REQUESTED_SHA ..."
(
  cd "$SHARED_DB_DIR"
  PR_NUMBER="$PR_NUMBER" REQUESTED_SHA="$REQUESTED_SHA" \
    node scripts/check-exact-head-approval.mjs
)
echo "Exact-head approval check passed."

# ---------------------------------------------------------------------------
# 3. Dispatch historical preview recovery. Production is fired by the
#    workflow's automatic-production-promotion job, not by this script.
# ---------------------------------------------------------------------------
GH="$AI_DEVOPS_BIN/ai-gh"
if [ ! -e "$GH" ]; then
  GH="gh"
  echo "NOTE: bin/ai-gh not found; falling back to gh." >&2
fi

# Capture epoch so the post-dispatch lookup can filter by creation time even
# if main moved between the assert above and the dispatch (the workflow itself
# re-checks tip freshness; this only keeps the URL lookup honest).
DISPATCH_EPOCH="$(date -u +%s)"
echo "Dispatching $WORKFLOW on $REPO at $(date -u +%Y-%m-%dT%H:%M:%SZ) UTC ..."
"$GH" workflow run "$WORKFLOW" \
  --repo "$REPO" \
  --ref main \
  --field "target=preview" \
  --field "mode=apply" \
  --field "preview_allowlist=$PREVIEW_ALLOWLIST" \
  --field "historical_preview_source_pr=$HISTORICAL_PREVIEW_SOURCE_PR" \
  --field "historical_preview_original_run_map=$HISTORICAL_PREVIEW_ORIGINAL_RUN_MAP" \
  --field "commit_sha=$MAIN_SHA"

echo "Dispatched. Looking up run URL (bounded: 5 attempts x 3s) ..."

# ---------------------------------------------------------------------------
# 4. Print the run URL. Prefer the run whose headSha equals MAIN_SHA; fall
#    back to the newest workflow_dispatch created at/after this dispatch so a
#    concurrent main move cannot hide the run we just started.
# ---------------------------------------------------------------------------
RUN_URL=""
for _ in 1 2 3 4 5; do
  RUN_URL="$("$GH" run list \
    --repo "$REPO" \
    --workflow "$WORKFLOW" \
    --event workflow_dispatch \
    --limit 10 \
    --json url,headSha,createdAt \
    --jq "map(select((.headSha == \"$MAIN_SHA\") or (.createdAt | fromdateiso8601) >= $DISPATCH_EPOCH)) | sort_by(.createdAt) | reverse | .[0].url" \
    | sed -n '1p')" || true
  [ -n "$RUN_URL" ] && [ "$RUN_URL" != "null" ] && break
  RUN_URL=""
  sleep 3
done

if [ -n "$RUN_URL" ]; then
  echo "RUN_URL=$RUN_URL"
else
  echo "Dispatch accepted; run URL not visible yet. Find it with:" >&2
  echo "  gh run list --repo $REPO --workflow $WORKFLOW --event workflow_dispatch --limit 5" >&2
fi

echo "Done. Automatic production promotion will fire from this preview-apply path."
echo "Do NOT hand-dispatch target=production."
