#!/usr/bin/env bash
# report-scheduled-failure.sh — open or update the scheduled verification
# incident, labeled with the action taxonomy (capacity/infra vs result).
#
# Capacity (timeout, kill, rate-limit) is not broken code. A `result` label
# means a real test outcome. Empty-verdict never lands here as `result`.
#
# Usage:
#   report-scheduled-failure.sh --run-url URL --repo OWNER/NAME \
#     [--results "job=result job=result ..."] [--title TEXT]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=action-taxonomy.sh
. "$ROOT/tools/ci/action-taxonomy.sh"

die() { printf 'report-scheduled-failure: error: %s\n' "$*" >&2; exit 1; }

RUN_URL=""
REPO="${GITHUB_REPOSITORY:-}"
RESULTS=""
TITLE='Scheduled full verification is failing'

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-url) [ "$#" -ge 2 ] || die '--run-url requires a value'; RUN_URL="$2"; shift 2 ;;
    --repo) [ "$#" -ge 2 ] || die '--repo requires a value'; REPO="$2"; shift 2 ;;
    --results) [ "$#" -ge 2 ] || die '--results requires a value'; RESULTS="$2"; shift 2 ;;
    --title) [ "$#" -ge 2 ] || die '--title requires a value'; TITLE="$2"; shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "$RUN_URL" ] || die '--run-url is required'
[ -n "$REPO" ] || die '--repo is required'

# Collect job conclusions from the run when the caller did not pass --results.
# Each entry is "check-name=CONCLUSION".
if [ -z "$RESULTS" ] && command -v gh >/dev/null 2>&1; then
  RESULTS="$(gh api "repos/$REPO/actions/runs/${RUN_URL##*/}/jobs" --jq '.jobs[] | select(.conclusion != "success" and .conclusion != "skipped" and .conclusion != null) | "\(.name)=\(.conclusion)"' 2>/dev/null || true)"
fi

action=result
detail=test-failure
capacity_seen=0
result_seen=0
review_seen=0
detail_notes=""
# Accept space- or newline-separated name=conclusion pairs.
for entry in $RESULTS; do
  case "$entry" in
    *=*) ;;
    *) continue ;;
  esac
  job="${entry%%=*}"
  conclusion="${entry#*=}"
  case "$conclusion" in
    success|skipped|neutral|''|null) continue ;;
  esac
  job_action="$(action_taxonomy_check "$conclusion" "$job" "")"
  job_detail="$(action_taxonomy_detail "$conclusion" "$job" "")"
  detail_notes="${detail_notes}- ${job}: ${job_detail} (action ${job_action})"$'\n'
  case "$job_action" in
    capacity/infra) capacity_seen=1 ;;
    review-step) review_seen=1 ;;
    *) result_seen=1 ;;
  esac
done

# Two labels only for ordinary red work. Prefer capacity/infra when any
# failing job is capacity: do not bury a timeout under a `result` label.
# Review-step carve-outs never force `result`.
if [ "$capacity_seen" -eq 1 ]; then
  action=capacity/infra
  detail=capacity
elif [ "$result_seen" -eq 1 ]; then
  action=result
  detail=test-failure
elif [ "$review_seen" -eq 1 ]; then
  # Empty-verdict style failure: review step owns it. Do not label as result.
  action=review-step
  detail=empty-verdict
else
  action=result
  detail=test-failure
fi

label="$action"
body="The complete scheduled matrix failed at ${RUN_URL}.

Action label: \`${label}\`
Report-only category: ${detail}

${detail_notes}Diagnose the named failing job and close this issue only after a later complete scheduled run passes. A \`capacity/infra\` label means timeout/kill/rate-limit — park and retry; do not re-diagnose as broken code. A \`result\` label is a real test outcome."

existing="$(gh issue list --repo "$REPO" --state open --search "in:title $TITLE" --json number,title --jq ".[] | select(.title == \"$TITLE\") | .number" | head -1)"
if [ -n "$existing" ]; then
  gh issue comment "$existing" --repo "$REPO" --body "$body"
  # Keep the action label current; never leave a capacity incident labeled result.
  gh issue edit "$existing" --repo "$REPO" --add-label "$label" >/dev/null
  printf 'report-scheduled-failure: updated issue #%s label=%s\n' "$existing" "$label"
else
  # Labels are created by repository setup; fall back to creating on first use.
  gh label create "$label" --repo "$REPO" --force >/dev/null 2>&1 || true
  number="$(gh issue create --repo "$REPO" --title "$TITLE" --body "$body" --label "$label")"
  printf 'report-scheduled-failure: opened %s label=%s\n' "$number" "$label"
fi
