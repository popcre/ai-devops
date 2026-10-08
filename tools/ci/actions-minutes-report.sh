#!/usr/bin/env bash
# actions-minutes-report.sh — estimate GitHub-hosted Actions minutes for one
# repository and day range, and print the billing API's daily totals beside it.
#
# Usage: tools/ci/actions-minutes-report.sh <owner/repo> <start-YYYY-MM-DD> [end-YYYY-MM-DD]
#        tools/ci/actions-minutes-report.sh --billing-only <org> <start> [end]
#        tools/ci/actions-minutes-report.sh --run <owner/repo> <run-id>
#
# Method (plan_actions-minutes-reduction.md step 0): list every workflow run
# created in each UTC day (queried hour by hour to stay under the 1,000-result
# search cap), fetch its jobs (all attempts), keep only jobs whose labels name a
# GitHub-hosted image (ubuntu-*, windows-*, macos-*), round each job up to a
# whole minute, and total by workflow / job. Self-hosted and Blacksmith jobs are
# counted separately and never billed by GitHub.
#
# Env: PARALLEL (default 8) concurrent job fetches.
set -euo pipefail

PARALLEL="${PARALLEL:-8}"

die() { echo "actions-minutes-report: $*" >&2; exit 2; }
command -v gh >/dev/null || die "gh CLI required"
command -v jq >/dev/null || die "jq required"

# jq program: job JSON array -> TSV rows: workflow \t job \t class \t minutes
JOBS_JQ='
  .[] | select(.started_at != null and .completed_at != null) |
  ((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601)) as $s |
  (if ([.labels[]? | test("^(ubuntu|windows|macos)-")] | any) and
      ([.labels[]? | test("self-hosted|blacksmith"; "i")] | any | not)
   then "hosted" else "other" end) as $class |
  [ .workflow_name, .name, $class,
    (if $s <= 0 then 0 else (($s + 59) / 60 | floor) end) ] | @tsv'

fetch_run_jobs() { # repo run_id
  gh api --paginate "repos/$1/actions/runs/$2/jobs?filter=all&per_page=100" \
    --jq '.jobs' 2>/dev/null | jq -s 'add // []' | jq -r "$JOBS_JQ"
}
export -f fetch_run_jobs
export JOBS_JQ

billing_day() { # org yyyy mm dd [repo] -> "date repo minutes" per repo
  local org=$1 y=$2 m=$3 d=$4
  gh api "organizations/$org/settings/billing/usage?year=$y&month=$((10#$m))&day=$((10#$d))" \
    --jq '.usageItems[] | select(.product=="actions" and .unitType=="Minutes") |
          [.repositoryName, .sku, .quantity] | @tsv'
}

summarise() { # tsv on stdin
  awk -F'\t' '
    $3=="hosted" { h+=$4; key=$1" / "$2; w[key]+=$4; n[key]++ }
    $3=="other"  { o+=$4 }
    END {
      printf "Hosted job-minutes (rounded up per job): %d\n", h
      printf "Self-hosted/Blacksmith job-minutes (not billed): %d\n", o
      print "Top hosted workflow / job (minutes, jobs):"
      for (k in w) printf "%6d  %5d  %s\n", w[k], n[k], k | "sort -rn | head -25"
    }'
}

if [[ "${1:-}" == "--run" ]]; then
  [[ $# -eq 3 ]] || die "usage: --run <owner/repo> <run-id>"
  fetch_run_jobs "$2" "$3" | summarise
  exit 0
fi

billing_only=0
if [[ "${1:-}" == "--billing-only" ]]; then billing_only=1; shift; fi
[[ $# -ge 2 ]] || die "usage: $0 <owner/repo> <start> [end]"
target=$1 start=$2 end=${3:-$2}
org=${target%%/*}

day=$start
while [[ "$day" < "$end" || "$day" == "$end" ]]; do
  IFS=- read -r y m d <<<"$day"
  echo "=== $target  $day (UTC) ==="
  echo "Billing API (Actions minutes, all repos in $org):"
  billing_day "$org" "$y" "$m" "$d" | sort -t$'\t' -k3 -rn |
    awk -F'\t' -v r="${target#*/}" '{ t+=$3; printf "  %-32s %-16s %8.0f%s\n", $1, $2, $3, ($1==r?"  <==":"") } END { printf "  %-49s %8.0f\n", "ORG TOTAL", t }'
  if [[ $billing_only -eq 0 ]]; then
    runs=$(mktemp)
    for h in $(seq -w 0 23); do
      gh api --paginate \
        "repos/$target/actions/runs?per_page=100&created=${day}T${h}:00:00Z..${day}T${h}:59:59Z" \
        --jq '.workflow_runs[].id' >>"$runs"
    done
    echo "Workflow runs created: $(sort -u "$runs" | wc -l)"
    sort -u "$runs" | xargs -P "$PARALLEL" -I{} bash -c 'fetch_run_jobs "$0" {}' "$target" | summarise
    rm -f "$runs"
  fi
  day=$(date -u -d "$day + 1 day" +%F)
done
