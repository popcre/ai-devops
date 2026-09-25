#!/usr/bin/env bash
# Close the sectioned offline Bash lane into the stable linux-offline context.
# Fails closed unless every section succeeded and the declared balanced
# sections reconstitute the expected inventory exactly once.
#
# Without --changed-since the expected inventory is the complete suite.
# With --changed-since (issue #805) the expected inventory is only the suites
# the change can break; a justified empty selection is a pass, not a gap.
set -uo pipefail

SHARD_RESULT=''
SHARD_TOTAL=''
CHANGED_SINCE=''
while [ $# -gt 0 ]; do
  case "$1" in
    --changed-since)
      [ $# -ge 2 ] || { echo 'linux-offline-aggregate: --changed-since needs a git ref.' >&2; exit 2; }
      CHANGED_SINCE="$2"; shift 2 ;;
    *)
      if [ -z "$SHARD_RESULT" ]; then SHARD_RESULT="$1"
      elif [ -z "$SHARD_TOTAL" ]; then SHARD_TOTAL="$1"
      else
        echo 'linux-offline-aggregate: unexpected argument.' >&2
        exit 2
      fi
      shift ;;
  esac
done

[ -n "$SHARD_RESULT" ] && [ -n "$SHARD_TOTAL" ] || {
  echo 'linux-offline-aggregate: section-result and section-count are required.' >&2
  exit 2
}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="${AI_LINUX_OFFLINE_TEST_ALL:-$ROOT/tests/test-all.sh}"

printf 'linux-offline: sections=%s count=%s changed-since=%s\n' \
  "$SHARD_RESULT" "$SHARD_TOTAL" "${CHANGED_SINCE:-none}"
case "$SHARD_TOTAL" in ''|*[!0-9]*|0) echo 'linux-offline-aggregate: section count must be a positive integer.' >&2; exit 2 ;; esac
[ "$SHARD_RESULT" = success ] || {
  printf 'linux-offline: sections reported %s; failing closed.\n' "${SHARD_RESULT:-nothing}" >&2
  exit 1
}

selection_args=()
if [ -n "$CHANGED_SINCE" ]; then
  selection_args=(--changed-since "$CHANGED_SINCE")
fi

# Expected inventory: the complete suite, or the affected subset on a PR.
all="$(bash "$RUNNER" ${selection_args[@]+"${selection_args[@]}"} --list)" || {
  echo 'linux-offline: could not list the expected inventory; failing closed.' >&2
  exit 1
}
all="$(printf '%s\n' "$all" | grep '^test-' | LC_ALL=C sort)"

sections=''
for ((i = 1; i <= SHARD_TOTAL; i++)); do
  part="$(bash "$RUNNER" ${selection_args[@]+"${selection_args[@]}"} --balanced --shard "$i/$SHARD_TOTAL" --list)" || {
    printf 'linux-offline: section %s of %s could not be listed; failing closed.\n' "$i" "$SHARD_TOTAL" >&2
    exit 1
  }
  sections+="$(printf '%s\n' "$part" | grep '^test-')"$'\n'
done
sections="$(printf '%s' "$sections" | grep '^test-' | LC_ALL=C sort)"

if [ -z "$all" ]; then
  [ -z "$sections" ] || {
    echo 'linux-offline: sections ran suites outside the empty selection; failing closed.' >&2
    exit 1
  }
  printf 'linux-offline: all %s sections passed; empty selection justified.\n' "$SHARD_TOTAL"
  exit 0
fi

[ -n "$sections" ] && [ "$all" = "$sections" ] || {
  echo 'linux-offline: the sections do not run every expected suite exactly once; failing closed.' >&2
  exit 1
}
printf 'linux-offline: all %s sections passed; %s suites each ran exactly once.\n' \
  "$SHARD_TOTAL" "$(printf '%s\n' "$all" | wc -l | tr -d ' ')"
