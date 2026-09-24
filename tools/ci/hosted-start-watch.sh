#!/usr/bin/env bash
# Watch one hosted Windows lane of the current run and decide, fail-closed,
# whether it must be diverted to Blacksmith (issue #742).
#
#   hosted-start-watch.sh <job-key> <expected-count> <deadline-seconds>
#
# <job-key> is the workflow job id; a matrix lane's jobs are named
# "<job-key> (<value>)". If any expected job has not started (it is missing,
# queued, waiting or pending) once <deadline-seconds> have passed, the lane is
# diverted: outputs divert=true, hosted_result=diverted, and this exits at once
# so the Blacksmith equivalent can start. Otherwise it waits for every hosted
# job to finish and reports hosted_result=success only when all succeeded.
# Albert, 2026-09-23 (#742): "anything that's queued and not actually running,
# send to blacksmith".
set -uo pipefail

[ "$#" -eq 3 ] || { echo 'hosted-start-watch: job-key expected-count deadline-seconds are required.' >&2; exit 2; }
KEY="$1"; EXPECTED="$2"; DEADLINE="$3"
POLL="${HOSTED_START_WATCH_POLL_SECONDS:-20}"
: "${GITHUB_REPOSITORY:?}" "${GITHUB_RUN_ID:?}" "${GITHUB_OUTPUT:?}"
ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"

emit() {
  printf 'divert=%s\nhosted_result=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"
  printf 'hosted-start-watch: %s divert=%s hosted_result=%s\n' "$KEY" "$1" "$2"
}

read_lane() { # prints "status<TAB>conclusion" per matching job
  gh api --paginate "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/$ATTEMPT/jobs?per_page=100" \
    --jq ".jobs[] | select(.name == \"$KEY\" or (.name | startswith(\"$KEY (\"))) | [.status, (.conclusion // \"\")] | @tsv"
}

start="$(date +%s)"
api_failures=0
while :; do
  if ! lane="$(read_lane)"; then
    api_failures=$((api_failures + 1))
    # An unreadable lane is never evidence of anything. Past the deadline it
    # diverts (the Blacksmith job is independent proof); before, it retries.
    if [ $(( $(date +%s) - start )) -ge "$DEADLINE" ] && [ "$api_failures" -ge 3 ]; then
      emit true diverted; exit 0
    fi
    sleep "$POLL"; continue
  fi
  api_failures=0
  lane="$(printf '%s\n' "$lane" | sed 's/\r$//' | sed '/^$/d')"
  count="$(printf '%s\n' "$lane" | sed '/^$/d' | wc -l | tr -d ' ')"
  [ -n "$lane" ] || count=0
  not_started="$(printf '%s\n' "$lane" | awk -F'\t' '$1 != "in_progress" && $1 != "completed" && $1 != "" {n++} END {print n+0}')"
  unfinished="$(printf '%s\n' "$lane" | awk -F'\t' '$1 != "completed" && $1 != "" {n++} END {print n+0}')"
  elapsed=$(( $(date +%s) - start ))

  if [ "$count" -ge "$EXPECTED" ] && [ "$unfinished" -eq 0 ]; then
    bad="$(printf '%s\n' "$lane" | awk -F'\t' '$2 != "success" {n++} END {print n+0}')"
    if [ "$bad" -eq 0 ]; then emit false success; else emit false failure; fi
    exit 0
  fi
  if [ "$elapsed" -ge "$DEADLINE" ] && { [ "$count" -lt "$EXPECTED" ] || [ "$not_started" -gt 0 ]; }; then
    printf 'hosted-start-watch: %s had %s of %s jobs not started after %ss; diverting to Blacksmith.\n' \
      "$KEY" "$(( not_started + EXPECTED - (count < EXPECTED ? count : EXPECTED) ))" "$EXPECTED" "$elapsed"
    emit true diverted
    exit 0
  fi
  sleep "$POLL"
done
