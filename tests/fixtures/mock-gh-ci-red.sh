#!/usr/bin/env bash
# Mock gh for test-report-ci-red.sh. Logs every call; returns fixtures.
log="${GH_LOG:?}"
echo "gh $*" >> "$log"
case "$1 $2" in
  "issue list")
    if [[ "$*" == *"--label ci-red"* ]]; then
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
    echo "#99"
    ;;
esac
exit 0
