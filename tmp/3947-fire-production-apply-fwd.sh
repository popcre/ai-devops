#!/usr/bin/env bash
# 3947-fire-production-apply-fwd.sh
#
# FORWARD-REPLACEMENT dispatch for shared-db #3947.
# Old version 20261007020907 is HARD_BLOCKED (never promote).
# NEW version 20261007190954 on PR #4047 head e35c1ecde, claim #3955 reissued.
#
# DETERMINATION: 20261007190954 requires a FRESH preview-apply run.
#   Historical preview recovery (historical_preview_* inputs) is a no-write
#   recovery lane: it REFUSES when an allowlisted version is missing from the
#   preview ledger ("Recover proof for migrations already present on preview"
#   raises SystemExit for missing ledger versions). Only 20261007020907 was
#   applied to preview (run 37572585770); 20261007190954 has never been
#   applied. Therefore historical recovery cannot be used until after a real
#   preview apply.
#
# This script dispatches TWO sequential phases:
#   (a) Preview apply of 20261007190954 (post-merge rehearsal, Bounded apply).
#       Uses merged_preview_source_pr=4047. This writes to preview AND triggers
#       the workflow's own automatic-production-promotion job.
#   (b) Auto-promotion to production fires from phase (a)'s run automatically.
#       The automatic-production-promotion job resolves the preview evidence
#       artifact, re-proves guarded merge + exact-head approval, and dispatches
#       the serial production lane with source_pr=4047, work_issue=3947,
#       merged_pr_issue_binding=4047:3947.
#
# Usage:
#   bash C:/repos/ai-devops/tmp/3947-fire-production-apply-fwd.sh \
#     <expected-main-sha> <expected-pr-head>
#
# Exact workflow inputs for the NEW version (single dispatch covers both phases):
#   target=preview
#   mode=apply
#   preview_allowlist=20261007190954
#   merged_preview_source_pr=4047
#   commit_sha=<main-sha>
#   merged_pr_issue_binding=4047:3947
#
# Production dispatch (fired by automatic-production-promotion, NOT by hand):
#   target=production  mode=apply
#   production_allowlist=20261007190954
#   source_pr=4047  work_issue=3947
#   merged_pr_issue_binding=4047:3947
#
# Ledger proof (READ ONLY — run AFTER the production apply, never writes):
#   op run --no-masking \
#     --env 'PGPASSWORD=op://vibe_coding/Supabase DB Password - shared POP database/password' \
#     -- psql "host=aws-1-us-east-1.pooler.supabase.com port=6543 dbname=postgres \
#              user=postgres.qsllyeztdwjgirsysgai sslmode=require" \
#        -tAc "select version, name from supabase_migrations.schema_migrations \
#              where version = '20261007190954'"

set -euo pipefail

EXPECTED_SHA="${1:?usage: $0 <expected-main-sha> <expected-pr-head>}"
EXPECTED_PR_HEAD="${2:?usage: $0 <expected-main-sha> <expected-pr-head>}"
REPO="popcre/shared-db"
WORKFLOW="shared-supabase-migrations.yml"
SHARED_DB_DIR="${SHARED_DB_DIR:-C:/repos/shared-db}"
AI_DEVOPS_BIN="${AI_DEVOPS_BIN:-C:/repos/ai-devops/bin}"

# Forward-replacement constants.
NEW_VERSION="20261007190954"
PR_NUMBER="4047"
MERGED_PR_ISSUE_BINDING="4047:3947"

# ---------------------------------------------------------------------------
# 1. Re-read MAIN_SHA from origin/main and assert it equals the expected.
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
echo "Checking exact-head approval for PR #$PR_NUMBER at $EXPECTED_PR_HEAD ..."
(
  cd "$SHARED_DB_DIR"
  PR_NUMBER="$PR_NUMBER" REQUESTED_SHA="$EXPECTED_PR_HEAD" \
    node scripts/check-exact-head-approval.mjs
)
echo "Exact-head approval check passed."

# ---------------------------------------------------------------------------
# 3. Phase (a): dispatch the post-merge rehearsal preview apply.
#
#    merged_preview_source_pr=4047 runs "Bounded apply" of 20261007190954 to
#    preview and then the workflow's automatic-production-promotion job fires
#    phase (b) — production dispatch — from the same run. Historical preview
#    recovery is NOT used here: 20261007190954 is not yet in the preview
#    ledger, and that lane is a no-write recovery that refuses missing
#    versions.
# ---------------------------------------------------------------------------
GH="$AI_DEVOPS_BIN/ai-gh"
if [ ! -e "$GH" ]; then
  GH="gh"
  echo "NOTE: bin/ai-gh not found; falling back to gh." >&2
fi

DISPATCH_EPOCH="$(date -u +%s)"
echo "Dispatching $WORKFLOW on $REPO at $(date -u +%Y-%m-%dT%H:%M:%SZ) UTC ..."
"$GH" workflow run "$WORKFLOW" \
  --repo "$REPO" \
  --ref main \
  --field "target=preview" \
  --field "mode=apply" \
  --field "preview_allowlist=$NEW_VERSION" \
  --field "merged_preview_source_pr=$PR_NUMBER" \
  --field "commit_sha=$MAIN_SHA" \
  --field "merged_pr_issue_binding=$MERGED_PR_ISSUE_BINDING"

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

echo "Done. Phase (a) preview apply of $NEW_VERSION and phase (b) automatic"
echo "production promotion will fire from this single merged_preview_source_pr run."
echo "Production allowlist: $NEW_VERSION  source_pr=$PR_NUMBER  work_issue=3947"
echo "Do NOT hand-dispatch target=production."
