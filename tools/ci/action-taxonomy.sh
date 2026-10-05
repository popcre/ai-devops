#!/usr/bin/env bash
# action-taxonomy.sh — two action labels for every failure that needs action.
#
# Agreed plan (docs/process-bottlenecks-and-improvements-2026-09-29.md §2b,
# Muse-audited): the action taxonomy has exactly two labels for red checks:
#   capacity/infra — timeout, kill, rate-limit. Park the merge; do not
#                    re-diagnose as broken code; do not reopen review.
#   result         — a real test or code outcome.
# Detailed incident categories stay in reports only.
#
# An empty reviewer verdict is NOT a PR test result. It fails the review step
# and reroutes (workflow-efficiency P7). Call action_taxonomy_review for a
# review failure_class; action_taxonomy_check also carves empty-verdict out of
# `result` when the check signal names one, so a review empty never reddens
# the PR test verdict.
#
# Usage (source this file, or call as a script):
#   action_taxonomy_check <conclusion> [check_name] [summary]
#     -> prints capacity/infra | result | review-step
#   action_taxonomy_review <failure_class>
#     -> prints review-step | capacity/infra | result
#   action_taxonomy_detail <conclusion> [check_name] [summary]
#     -> prints a report-only category (timeout-capacity, killed-interrupt,
#        rate-limit-capacity, empty-verdict, test-failure, config-drift)
#
# As a script:
#   tools/ci/action-taxonomy.sh check <conclusion> [name] [summary]
#   tools/ci/action-taxonomy.sh review <failure_class>
#   tools/ci/action-taxonomy.sh detail <conclusion> [name] [summary]

set -euo pipefail

# Capacity phrases are matched on the failure summary, never on the check
# name: a job named quota-check or skills-lint must stay `result`.
action_taxonomy_detail() {
  local conclusion="${1:-}" name="${2:-}" summary="${3:-}"
  local summary_blob name_blob
  summary_blob="$(printf '%s' "$summary" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"
  name_blob="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"

  # Conclusion is authoritative for Actions lifecycle states.
  case "$conclusion" in
    TIMED_OUT|timed_out|timeout)
      printf 'timeout-capacity\n'; return 0 ;;
    CANCELLED|cancelled)
      printf 'killed-interrupt\n'; return 0 ;;
  esac

  case "$summary_blob" in
    *rate\ limit*|*rate-limit*|*rate.limit*|*secondary\ rate*|*secondary-rate*|*abuse\ detection*|*abuse-detection*|*quota\ exceeded*|*quota-exceeded*|*allowance\ exhausted*|*allowance-exhausted*|*http\ 429*|*status\ 429*)
      printf 'rate-limit-capacity\n'; return 0 ;;
    *timed\ out*|*timed-out*|*timed.out*|*timeout*)
      printf 'timeout-capacity\n'; return 0 ;;
    *killed*|*sigkill*|*exit\ 137*|*exit\ -9*|*interrupted*)
      printf 'killed-interrupt\n'; return 0 ;;
  esac

  # Empty reviewer verdict: detect from the check name or summary. This is the
  # carve-out that keeps an empty verdict off the PR test verdict.
  case "$name_blob $summary_blob" in
    *empty\ report*|*empty-report*|*empty.report*|*empty\ verdict*|*empty-verdict*|*empty.verdict*|*no\ verdict*|*no-verdict*|*no.verdict*|*missing\ verdict*|*missing-verdict*|*missing.verdict*|*malformed\ verdict*|*malformed-verdict*|*malformed.verdict*|*empty_provider_stream*|*empty-provider-stream*|*invalid-provider-envelope*|*invalid.provider.envelope*)
      printf 'empty-verdict\n'; return 0 ;;
  esac

  case "$summary_blob" in
    *config\ drift*|*config-drift*|*config.drift*)
      printf 'config-drift\n'; return 0 ;;
  esac

  printf 'test-failure\n'
}

# Two action labels only for a red PR check: capacity/infra vs result.
# empty-verdict is carved out to review-step and is never `result`.
action_taxonomy_check() {
  local detail
  detail="$(action_taxonomy_detail "$@")"
  case "$detail" in
    timeout-capacity|killed-interrupt|rate-limit-capacity)
      printf 'capacity/infra\n' ;;
    empty-verdict)
      printf 'review-step\n' ;;
    *)
      printf 'result\n' ;;
  esac
}

# Review-step actions. Empty verdict fails the review and reroutes; it is
# never `result` and never reddens the PR test verdict.
action_taxonomy_review() {
  case "${1:-}" in
    empty-report|empty-verdict|empty_provider_stream|no-verdict|missing-verdict|malformed-verdict|invalid-provider-envelope)
      printf 'review-step\n' ;;
    provider-timeout|timeout|allowance-exhausted|out-of-credit|rate-limit|killed|interrupted)
      printf 'capacity/infra\n' ;;
    *)
      printf 'result\n' ;;
  esac
}

action_taxonomy_usage() {
  cat <<'EOF'
Usage:
  action-taxonomy.sh check <conclusion> [name] [summary]   # capacity/infra | result | review-step
  action-taxonomy.sh review <failure_class>                # review-step | capacity/infra | result
  action-taxonomy.sh detail <conclusion> [name] [summary]  # report-only category
EOF
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    check) shift; action_taxonomy_check "$@" ;;
    review) shift; action_taxonomy_review "$@" ;;
    detail) shift; action_taxonomy_detail "$@" ;;
    -h|--help|help|'') action_taxonomy_usage ;;
    *) action_taxonomy_usage >&2; exit 2 ;;
  esac
fi
