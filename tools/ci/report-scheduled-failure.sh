#!/usr/bin/env bash
# report-scheduled-failure.sh — open or update the scheduled verification
# incident, labeled with the action taxonomy (capacity/infra vs result).
#
# Capacity (timeout, kill, rate-limit) is not broken code. A `result` label
# means a real test outcome. Empty-verdict never lands here as `result`.
#
# Per-test mode (--per-test): one ci-red issue per failing test, closed
# automatically after three later green runs. Capacity failures produce none.
# The fixer also accepts ci-red (plan_ci-process-repair.md step 1.4).
#
# Usage:
#   report-scheduled-failure.sh --run-url URL --repo OWNER/NAME \
#     [--results "job=result job=result ..."] [--title TEXT]
#   report-scheduled-failure.sh --run-url URL --repo OWNER/NAME \
#     --per-test [--results "job=conclusion ..."] \
#     [--pr-number N] [--head-sha SHA] [--event NAME]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=action-taxonomy.sh
. "$ROOT/tools/ci/action-taxonomy.sh"

die() { printf 'report-scheduled-failure: error: %s\n' "$*" >&2; exit 1; }

RUN_URL=""
REPO="${GITHUB_REPOSITORY:-}"
RESULTS=""
RESULTS_FROM_API=0
TITLE='Scheduled full verification is failing'
PER_TEST=0
PR_NUMBER=""
HEAD_SHA=""
EVENT_NAME="${GITHUB_EVENT_NAME:-}"
CI_RED_CAP="${CI_RED_CAP:-20}"
GREEN_MARK='<!-- ci-red-green -->'

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-url) [ "$#" -ge 2 ] || die '--run-url requires a value'; RUN_URL="$2"; shift 2 ;;
    --repo) [ "$#" -ge 2 ] || die '--repo requires a value'; REPO="$2"; shift 2 ;;
    --results) [ "$#" -ge 2 ] || die '--results requires a value'; RESULTS="$2"; shift 2 ;;
    --title) [ "$#" -ge 2 ] || die '--title requires a value'; TITLE="$2"; shift 2 ;;
    --per-test) PER_TEST=1; shift ;;
    --pr-number) [ "$#" -ge 2 ] || die '--pr-number requires a value'; PR_NUMBER="$2"; shift 2 ;;
    --head-sha) [ "$#" -ge 2 ] || die '--head-sha requires a value'; HEAD_SHA="$2"; shift 2 ;;
    --event) [ "$#" -ge 2 ] || die '--event requires a value'; EVENT_NAME="$2"; shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "$RUN_URL" ] || die '--run-url is required'
[ -n "$REPO" ] || die '--repo is required'

# Collect job conclusions from the run when the caller did not pass --results.
# Each entry is "check-name=CONCLUSION".
if [ -z "$RESULTS" ] && command -v gh >/dev/null 2>&1; then
  RESULTS_FROM_API=1
  RESULTS="$(gh api "repos/$REPO/actions/runs/${RUN_URL##*/}/jobs" --jq '.jobs[] | select(.conclusion != null) | "\(.name)=\(.conclusion)"' 2>/dev/null || true)"
fi

# ── per-test mode (step 1.4) ──────────────────────────────────────────────
# One ci-red issue per failing test; capacity produces none; auto-close after
# three later green runs. Advisory: blocks nothing.
if [ "$PER_TEST" -eq 1 ]; then
  # Never publish an incident the fixer cannot attribute to a source.
  [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]] || die 'per-test mode requires a numeric PR number'
  [[ "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]] || die 'per-test mode requires a 40-hex Head SHA'
  # API entries are already complete lines. Keep legacy space-separated pairs.
  if [ "$RESULTS_FROM_API" -eq 0 ]; then
    RESULTS="$(printf '%s\n' "$RESULTS" | python3 -c 'import re,sys; print(re.sub(r"(=(?:failure|success|cancelled|timed_out|skipped|neutral|action_required|startup_failure|stale|null)) +", r"\1\n", sys.stdin.read()))')"
  fi
  find_ci_red_issue() {
    # Exact title match on an open ci-red issue. Title is deterministic.
    local title="ci-red: $1 (PR #${PR_NUMBER})"
    gh issue list --repo "$REPO" --state open --label ci-red \
      --limit 1000 --json number,title | python3 -c '
import json, sys
print(next((i["number"] for i in json.load(sys.stdin) if i["title"] == sys.argv[1]), ""))
' "$title"
  }

  green_count() {
    local issue_num="$1"
    gh issue view "$issue_num" --repo "$REPO" --json comments | python3 -c '
import json, sys
greens = set()
for comment in reversed(json.load(sys.stdin)["comments"]):
    body = comment["body"]
    if "<!-- ci-red-failure -->" in body or body.startswith("CI red:"):
        break
    if "<!-- ci-red-green -->" in body:
        greens.add(body)
print(len(greens))
'
  }

  opened=0
  label_ready=0
  # Accept space- or newline-separated name=conclusion pairs. Split safely.
  while IFS= read -r entry; do
    case "$entry" in
      *=*) ;;
      *) continue ;;
    esac
    job="${entry%=*}"
    conclusion="${entry##*=}"

    # Green tracking: a success closes ci-red issues after three greens.
    case "$conclusion" in
      success)
        existing_green="$(find_ci_red_issue "$job")"
        if [ -n "$existing_green" ]; then
          gh issue comment "$existing_green" --repo "$REPO" \
            --body "${GREEN_MARK} Green run: ${RUN_URL}"
          greens="$(green_count "$existing_green")"
          if [ "${greens:-0}" -ge 3 ]; then
            gh issue close "$existing_green" --repo "$REPO" \
              --comment "Closed automatically: three later green runs of \`${job}\`. Last: ${RUN_URL}" 2>/dev/null || true
            printf 'report-scheduled-failure: closed #%s after %s green runs\n' "$existing_green" "$greens"
          fi
        fi
        continue ;;
      skipped|neutral|''|null) continue ;;
    esac

    job_action="$(action_taxonomy_check "$conclusion" "$job" "")"
    job_detail="$(action_taxonomy_detail "$conclusion" "$job" "")"
    existing="$(find_ci_red_issue "$job")"
    if [ -n "$existing" ]; then
      gh issue comment "$existing" --repo "$REPO" \
        --body "<!-- ci-red-failure --> Run: ${RUN_URL}" >/dev/null
    fi

    # Capacity/infra and review-step failures open no per-test issue.
    case "$job_action" in
      capacity/infra|review-step)
        printf 'report-scheduled-failure: %s is %s; no ci-red issue\n' "$job" "$job_action"
        continue ;;
    esac

    # Cap per run: one bad commit must not flood the tracker.
    if [ -z "$existing" ] && [ "$opened" -ge "$CI_RED_CAP" ]; then
      printf 'report-scheduled-failure: cap %s reached; %s not reported\n' "$CI_RED_CAP" "$job"
      continue
    fi

    title="ci-red: ${job} (PR #${PR_NUMBER})"
    body="CI red: \`${job}\` failed in a ${EVENT_NAME:-CI} run.

Run: ${RUN_URL}
Action label: \`result\`
Report-only category: ${job_detail}

PR: https://github.com/${REPO}/pull/${PR_NUMBER}
Head SHA: \`${HEAD_SHA}\`

Guidance: result is a real test outcome. Diagnose the failing suite.
This issue is advisory: it blocks nothing."

    if [ -n "$existing" ]; then
      gh issue edit "$existing" --repo "$REPO" --body "$body" >/dev/null
      gh issue comment "$existing" --repo "$REPO" --body "$body" 2>/dev/null || true
      printf 'report-scheduled-failure: updated issue #%s label=ci-red\n' "$existing"
    else
      if [ "$label_ready" -eq 0 ]; then
        gh label create ci-red --repo "$REPO" --color D93F0B --force >/dev/null 2>&1 || true
        label_ready=1
      fi
      number="$(gh issue create --repo "$REPO" --title "$title" --body "$body" --label ci-red)"
      printf 'report-scheduled-failure: opened %s label=ci-red\n' "$number"
      opened=$(( opened + 1 ))
    fi
  done <<EOF
$RESULTS
EOF
  exit 0
fi
# ── end per-test mode ─────────────────────────────────────────────────────

action=result
detail=test-failure
capacity_seen=0
result_seen=0
review_seen=0
detail_notes=""
# Accept space- or newline-separated name=conclusion pairs. Split safely.
while IFS= read -r entry; do
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
done <<EOF
$(printf '%s\n' "$RESULTS" | tr ' ' '\n')
EOF

# Two labels only for ordinary red work. A mixed run (one timeout plus one
# real test failure) is `result`: a genuine failure must not be parked as
# capacity. Review-step carve-outs never force `result`.
if [ "$result_seen" -eq 1 ]; then
  action=result
  detail=test-failure
elif [ "$capacity_seen" -eq 1 ]; then
  action=capacity/infra
  detail=capacity
elif [ "$review_seen" -eq 1 ]; then
  action=review-step
  detail=empty-verdict
else
  action=result
  detail=test-failure
fi

label="$action"
guidance="Diagnose the named failing job and close this issue only after a later complete scheduled run passes."
if [ "$action" = capacity/infra ]; then
  guidance="capacity/infra means timeout/kill/rate-limit — park and retry; do not re-diagnose as broken code."
elif [ "$action" = review-step ]; then
  guidance="empty reviewer verdict fails the review step and reroutes. It never reddens the PR test verdict."
else
  guidance="result is a real test outcome. Diagnose the failing suite."
fi
if [ "$capacity_seen" -eq 1 ] && [ "$result_seen" -eq 1 ]; then
  guidance="$guidance Note: this run mixed capacity and result; the result label wins so a real failure is not parked."
fi

body="The complete scheduled matrix failed at ${RUN_URL}.

Action label: \`${label}\`
Report-only category: ${detail}

${detail_notes}${guidance}"

existing="$(gh issue list --repo "$REPO" --state open --search "in:title $TITLE" --json number,title --jq ".[] | select(.title == \"$TITLE\") | .number" | head -1)"
# Labels may not exist yet; create before every attach.
gh label create "$label" --repo "$REPO" --force >/dev/null 2>&1 || true
if [ -n "$existing" ]; then
  gh issue comment "$existing" --repo "$REPO" --body "$body"
  gh issue edit "$existing" --repo "$REPO" --add-label "$label" >/dev/null 2>&1 || true
  printf 'report-scheduled-failure: updated issue #%s label=%s\n' "$existing" "$label"
else
  number="$(gh issue create --repo "$REPO" --title "$TITLE" --body "$body" --label "$label")"
  printf 'report-scheduled-failure: opened %s label=%s\n' "$number" "$label"
fi
