#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/verify.yml"

windows_timeout="$(sed -n '/^  windows-offline:/,/^  windows-reviewer-safety:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
case "$windows_timeout" in
  ''|*[!0-9]*) printf 'FAIL: windows-offline timeout is missing or invalid\n' >&2; exit 1 ;;
esac
[ "$windows_timeout" -ge 75 ] || { printf 'FAIL: windows-offline needs at least 75 minutes of measured runtime headroom\n' >&2; exit 1; }

# A pull-request run must be superseded by a newer push to the same pull
# request. Keying the group on the head SHA made that impossible and filled the
# two-runner Windows pool with builds nobody was waiting for (issue #204).
grep -Fq "format('pr-{0}', github.event.pull_request.number)" "$workflow" || {
  printf 'FAIL: pull-request verification must be keyed on the pull request, not its head SHA
' >&2
  exit 1
}
# Concurrent merge-queue entries must never cancel one another, so merge_group
# keeps a group per queue branch.
grep -Fq "github.event_name == 'merge_group' && github.ref" "$workflow" || {
  printf 'FAIL: merge-group verification must be keyed on its own queue branch
' >&2
  exit 1
}
# push: main keeps a per-SHA group so each immutable commit keeps its own proof.
grep -Fq '|| github.sha' "$workflow" || {
  printf 'FAIL: push runs must still be scoped to their immutable source SHA
' >&2
  exit 1
}
# The edge-dev Windows jobs must not run on merge_group; a queue rebuild
# restarts them and starves the two-runner pool.
windows_skips="$(grep -c "if: github.event_name != 'merge_group'" "$workflow" | tr -d '
')"
[ "$windows_skips" -eq 2 ] || {
  printf 'FAIL: both edge-dev Windows jobs must be skipped on merge_group
' >&2
  exit 1
}
grep -Fq 'cancel-in-progress: true' "$workflow" || {
  printf 'FAIL: duplicate verification runs for the same source must still be cancellable\n' >&2
  exit 1
}

printf 'PASS: Windows headroom kept, superseded pull-request runs are cancellable, and the merge queue does not schedule edge-dev Windows jobs\n'
