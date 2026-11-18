#!/usr/bin/env bash
# Mock gh for test-report-ci-red.sh. Logs every call; returns fixtures.
log="${GH_LOG:?}"
echo "gh $*" >> "$log"
case "$1 $2" in
  "api --paginate")
    if [[ "$*" == *"labels=ci-red"* ]]; then
      if [ -n "${GH_LOOKUP_FAIL_FOR:-}" ] && [[ "$*" == *"ci-red: $GH_LOOKUP_FAIL_FOR\""* ]]; then
        printf 'fixture lookup failed\n' >&2
        exit 1
      fi
      if [ -n "${GH_FIXTURE_ISSUE:-}" ]; then
        echo "${GH_FIXTURE_ISSUE}"
      fi
    fi
    ;;
  "issue view")
    # Simulate --jq for green-count queries.
    if [[ "$*" == *"--json comments"* ]]; then
      echo "${GH_FIXTURE_GREEN_COUNT:-0}"
    fi
    ;;
  "issue create")
    if [ -n "${GH_BODY_FILE:-}" ]; then
      while [ "$#" -gt 1 ]; do
        if [ "$1" = --body ]; then
          printf '%s\n' "$2" > "$GH_BODY_FILE"
          break
        fi
        shift
      done
    fi
    echo "#99"
    ;;
esac
exit 0
