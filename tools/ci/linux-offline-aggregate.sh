#!/usr/bin/env bash
# Close the sectioned offline Bash lane into the stable linux-offline context.
# Fails closed unless every section succeeded and the declared balanced
# sections reconstitute the complete suite exactly once.
set -uo pipefail

[ "$#" -eq 2 ] || {
  echo 'linux-offline-aggregate: section-result and section-count are required.' >&2
  exit 2
}
SHARD_RESULT="$1"
SHARD_TOTAL="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="${AI_LINUX_OFFLINE_TEST_ALL:-$ROOT/tests/test-all.sh}"

printf 'linux-offline: sections=%s count=%s\n' "$SHARD_RESULT" "$SHARD_TOTAL"
case "$SHARD_TOTAL" in ''|*[!0-9]*|0) echo 'linux-offline-aggregate: section count must be a positive integer.' >&2; exit 2 ;; esac
[ "$SHARD_RESULT" = success ] || {
  printf 'linux-offline: sections reported %s; failing closed.\n' "${SHARD_RESULT:-nothing}" >&2
  exit 1
}

all="$(bash "$RUNNER" --list)" || { echo 'linux-offline: could not list the complete suite; failing closed.' >&2; exit 1; }
all="$(printf '%s\n' "$all" | grep '^test-' | LC_ALL=C sort)"
sections=''
for ((i = 1; i <= SHARD_TOTAL; i++)); do
  part="$(bash "$RUNNER" --balanced --shard "$i/$SHARD_TOTAL" --list)" || {
    printf 'linux-offline: section %s of %s could not be listed; failing closed.\n' "$i" "$SHARD_TOTAL" >&2
    exit 1
  }
  sections+="$(printf '%s\n' "$part" | grep '^test-')"$'\n'
done
sections="$(printf '%s' "$sections" | grep '^test-' | LC_ALL=C sort)"
[ -n "$all" ] && [ "$all" = "$sections" ] || {
  echo 'linux-offline: the sections do not run every suite exactly once; failing closed.' >&2
  exit 1
}
printf 'linux-offline: all %s sections passed; %s suites each ran exactly once.\n' \
  "$SHARD_TOTAL" "$(printf '%s\n' "$all" | wc -l | tr -d ' ')"
