#!/usr/bin/env bash
# Finish-line probe helpers for shared-db #3947 (scratch; not committed).
set -euo pipefail
GH="${GH:-C:/repos/ai-devops/bin/ai-gh}"
REPO="popcre/shared-db"

case "${1:-}" in
  handoff-job)
    "$GH" api "repos/$REPO/actions/runs/37674260315/jobs" \
      --jq '.jobs[] | select(.name=="Handoff contract") | {id,name,conclusion,steps:[.steps[]|select(.conclusion=="failure")]}'
    ;;
  handoff-log)
    JOB_ID="${2:?job id}"
    "$GH" api "repos/$REPO/actions/jobs/$JOB_ID/logs" 2>&1 | tail -80
    ;;
  required-checks)
    "$GH" api "repos/$REPO/branches/main/protection" --jq '.required_status_checks.contexts' 2>&1 | head -60
    ;;
  rulesets)
    "$GH" api "repos/$REPO/rules/branches/main" 2>&1 | head -80
    ;;
  pr-status)
    "$GH" pr view "${2:-4047}" --repo "$REPO" --json number,state,headRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup \
      --jq '{number,state,headRefOid,mergeable,mergeStateStatus,reviewDecision,checks:[.statusCheckRollup[]|{name,conclusion,status,context}]}' 2>&1
    ;;
  exact-head)
    HEAD="${2:-e35c1ecde901b55e7ed3a343da685d5f2c4c7a37}"
    PR_NUMBER=4047 REQUESTED_SHA="$HEAD" node scripts/check-exact-head-approval.mjs
    ;;
  reviews)
    "$GH" api "repos/$REPO/pulls/4047/reviews" \
      --jq '[.[] | {user:.user.login,state,commit_id:.commit_id,submitted_at:.submitted_at,body:(.body|tostring|.[0:200])}]'
    ;;
  main-sha)
    "$GH" api "repos/$REPO/commits/main" --jq '.sha'
    ;;
  dispatch-merge)
    HEAD="${2:?head sha}"
    "$GH" workflow run "guarded-migration-merge.yml" \
      --repo "$REPO" \
      --ref main \
      --field "pull_request=4047" \
      --field "head_sha=$HEAD"
    echo "DISPATCHED guarded-migration-merge for PR 4047 head $HEAD"
    ;;
  latest-merge-runs)
    "$GH" run list --repo "$REPO" --workflow "guarded-migration-merge.yml" --limit 5 \
      --json databaseId,url,status,conclusion,createdAt,headSha,displayTitle
    ;;
  run)
    RUN_ID="${2:?run id}"
    "$GH" run view "$RUN_ID" --repo "$REPO" --json databaseId,url,status,conclusion,jobs \
      --jq '{databaseId,url,status,conclusion,jobs:[.jobs[]|{name,status,conclusion,steps:[.steps[]|select(.conclusion=="failure")]}]}'
    ;;
  *)
    echo "usage: $0 <handoff-job|handoff-log|required-checks|rulesets|pr-status|exact-head|reviews|main-sha|dispatch-merge|latest-merge-runs|run>"
    exit 2
    ;;
esac
