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
# An empty reviewer verdict is NOT in that red-check taxonomy. It fails the
# review step and reroutes (workflow-efficiency P7). It never reddens the PR
# test verdict: a review empty-report must never be labeled `result`.
#
# Usage (source this file, or call as a script):
#   action_taxonomy_check <conclusion> [check_name] [summary]
#     -> prints capacity/infra | result | review-step
#        (review-step is the empty-verdict carve-out: fail review and reroute,
#        never label it a PR test result)
#   action_taxonomy_review <failure_class>
#     -> prints review-step | capacity/infra | result
#   action_taxonomy_detail <conclusion> [check_name] [summary]
#     -> prints a detailed report-only category (timeout-capacity,
#        killed-interrupt, rate-limit-capacity, empty-verdict, test-failure,
#        config-drift)
#
# As a script:
#   tools/ci/action-taxonomy.sh check <conclusion> [name] [summary]
#   tools/ci/action-taxonomy.sh review <failure_class>
#   tools/ci/action-taxonomy.sh detail <conclusion> [name] [summary]

set -euo pipefail

action_taxonomy_detail() {
  local conclusion="${1:-}" name="${2:-}" summary="${3:-}"
  local blob
  blob="$(printf '%s %s %s' "$conclusion" "$name" "$summary" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"
  # Match hyphen/space/dot variants of the same phrase.
  case "$blob" in
    *rate\ limit*|*rate-limit*|*rate.limit*|*secondary\ rate*|*secondary-rate*|*abuse.detection*|*abuse-detection*|*quota*|*429*|*allowance*)
      printf 'rate-limit-capacity\n'; return 0 ;;
    *timed\ out*|*timed-out*|*timed.out*|*timeout*)
      printf 'timeout-capacity\n'; return 0 ;;
    *killed*|*kill*|*sigkill*|*exit\ 137*|*exit\ -9*|*interrupt*)
      printf 'killed-interrupt\n'; return 0 ;;
  esac
  case "$conclusion" in
    TIMED_OUT|timed_out|timeout)
      printf 'timeout-capacity\n'; return 0 ;;
    CANCELLED|cancelled)
      # A cancelled Actions job is most often a timeout or a kill under load.
      printf 'killed-interrupt\n'; return 0 ;;
  esac
  case "$blob" in
    *empty\ report*|*empty-report*|*empty.report*|*empty\ verdict*|*empty-verdict*|*empty.verdict*|*no\ verdict*|*no-verdict*|*no.verdict*|*malformed\ verdict*|*malformed-verdict*|*malformed.verdict*)
      printf 'empty-verdict\n'; return 0 ;;
    *config\ drift*|*config-drift*|*config.drift*)
      printf 'config-drift\n'; return 0 ;;
  esac
  case "$conclusion" in
    SUCCESS|success|NEUTRAL|neutral|SKIPPED|skipped)
      printf 'test-failure\n'; return 0 ;;
  esac
  printf 'test-failure\n'
}

# Two action labels only for a red PR check: capacity/infra vs result.
# Empty-verdict is carved out to the review step and is never `result`, so an
# empty reviewer verdict cannot redden the PR test verdict.
action_taxonomy_check() {
  local conclusion="${1:-}" name="${2:-}" summary="${3:-}"
  local detail
  detail="$(action_taxonomy_detail "$conclusion" "$name" "$summary")"
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
  local failure_class="${1:-}"
  case "$failure_class" in
    empty-report|empty-verdict|empty_provider_stream|no-verdict|malformed-verdict)
      printf 'review-step\n' ;;
    provider-timeout|timeout|allowance-exhausted|out-of-credit|rate-limit|killed|interrupted)
      printf 'capacity/infra\n' ;;
    '')
      printf 'result\n' ;;
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
