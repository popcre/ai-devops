#!/usr/bin/env bash
# P4/S2 owns this complete PR-status transaction. Keep every GraphQL page
# inside one single-flight refresh; retire this helper if the waiter gains a
# native complete-status transport.
set -uo pipefail

[ "$#" -eq 11 ] || exit 3
GH_RUNNER="$1"; PYTHON_RUNNER="$2"; SUPERVISOR="$3"; BASH_RUNNER="$4"
OWNER="$5"; NAME="$6"; PR="$7"; DEADLINE="$8"; API_TIMEOUT="$9"
shift 9
ALLOWANCE="$1"; SOURCE_FILE="$2"
if command -v cygpath >/dev/null 2>&1; then
  SOURCE_FILE="$(cygpath -u "$SOURCE_FILE")"
fi

page() {
  local now remaining limit
  now="$(date +%s)"
  remaining=$(( DEADLINE - now ))
  [ "$remaining" -gt 0 ] || return 125
  limit=$(( API_TIMEOUT + ALLOWANCE ))
  [ "$limit" -le "$remaining" ] || limit="$remaining"
  # A cache follower never runs this function and records no GitHub spend.
  printf 'upstream' > "$SOURCE_FILE"
  "$PYTHON_RUNNER" "$SUPERVISOR" --timeout-seconds "$limit" -- \
    "$BASH_RUNNER" -c 'runner="$1"; shift; command -v cygpath >/dev/null 2>&1 && runner="$(cygpath -u "$runner")"; if [ "${AI_DEVOPS_TEST_MODE:-0}" = 1 ] && [ -n "${AI_PR_WAIT_TEST_TRACE:-}" ]; then printf "%s\n" "$runner" > "$AI_PR_WAIT_TEST_TRACE.child"; fi; exec "$runner" "$@"' \
    bash "$GH_RUNNER" api graphql -f "query=$1"
}

Q="$(page "{repository(owner:\"$OWNER\",name:\"$NAME\"){pullRequest(number:$PR){state headRefOid isInMergeQueue mergeCommit{oid} commits(last:1){nodes{commit{statusCheckRollup{state contexts(last:100){totalCount pageInfo{hasPreviousPage startCursor} nodes{... on CheckRun{name conclusion} ... on StatusContext{context state}}}}}}}}}}")" || exit $?
first_head="$(printf '%s' "$Q" | jq -r '.data.repository.pullRequest.headRefOid // empty')" || exit 4
pages=0
while printf '%s' "$Q" | jq -e '.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo.hasPreviousPage == true' >/dev/null 2>&1; do
  pages=$(( pages + 1 ))
  [ "$pages" -le 20 ] || exit 4
  cursor="$(printf '%s' "$Q" | jq -r '.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo.startCursor // empty')"
  [ -n "$cursor" ] || exit 4
  quoted_cursor="$(jq -nr --arg value "$cursor" '$value|@json')"
  PAGE="$(page "{repository(owner:\"$OWNER\",name:\"$NAME\"){pullRequest(number:$PR){headRefOid commits(last:1){nodes{commit{statusCheckRollup{contexts(last:100,before:$quoted_cursor){totalCount pageInfo{hasPreviousPage startCursor} nodes{... on CheckRun{name conclusion} ... on StatusContext{context state}}}}}}}}}}")" || exit $?
  first_total="$(printf '%s' "$Q" | jq -r '.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.totalCount // empty')"
  printf '%s' "$PAGE" | jq -e --arg head "$first_head" --argjson total "$first_total" \
    '(.errors | not) and (.data.repository.pullRequest.headRefOid == $head) and (.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.totalCount == $total) and (.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.nodes | type == "array") and (.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo.hasPreviousPage | type == "boolean")' >/dev/null 2>&1 || exit 4
  Q="$(printf '%s\n%s\n' "$Q" "$PAGE" | jq -sc '.[0] as $first | .[1] as $older | $first | .data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.nodes += $older.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.nodes | .data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo = $older.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo')" || exit 4
done
printf '%s' "$Q" | jq -e '(.errors | not) and .data.repository.pullRequest and ((.data.repository.pullRequest.state != "OPEN") or (.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup == null) or ((.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo.hasPreviousPage == false) and (.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.totalCount == (.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.nodes | length))))' >/dev/null 2>&1 || exit 4
printf '%s\n' "$Q"
