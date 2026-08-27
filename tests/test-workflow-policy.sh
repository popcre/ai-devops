#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/verify.yml"

windows_timeout="$(sed -n '/^  windows-offline:/,/^  windows-reviewer-safety:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
case "$windows_timeout" in
  ''|*[!0-9]*) printf 'FAIL: windows-offline timeout is missing or invalid\n' >&2; exit 1 ;;
esac
[ "$windows_timeout" -ge 75 ] || { printf 'FAIL: windows-offline needs at least 75 minutes of measured runtime headroom\n' >&2; exit 1; }

grep -Fq "group: verify-\${{ github.workflow }}-\${{ github.event_name }}-\${{ github.event_name == 'merge_group' && github.event.merge_group.base_ref || github.event.pull_request.head.sha || github.sha }}" "$workflow" || {
  printf 'FAIL: push and pull_request verification must stay scoped to immutable event and source SHA, and merge_group must be scoped to the target branch
' >&2
  exit 1
}

# A dead merge-group candidate must not hold a windows-2025 runner for its
# full timeout while the live candidate waits. Guard the merge_group half
# explicitly so a future edit cannot quietly restore per-SHA pinning there.
grep -Fq "github.event_name == 'merge_group' && github.event.merge_group.base_ref" "$workflow" || {
  printf 'FAIL: superseded merge_group runs must be cancellable (key merge_group concurrency on the target branch, not the candidate SHA)
' >&2
  exit 1
}

# windows-reviewer-safety is never a required check and is a strict subset of
# windows-offline. Inside a merge group it costs a second Windows runner and
# blocks nothing, so it must be skipped there and kept on pull requests.
awk '/^  windows-reviewer-safety:/,/^      - /' "$workflow" | grep -Fq "if: github.event_name != 'merge_group'" || {
  printf 'FAIL: windows-reviewer-safety must not consume a windows-2025 runner inside a merge group
' >&2
  exit 1
}
grep -Fq 'cancel-in-progress: true' "$workflow" || {
  printf 'FAIL: duplicate verification runs for the same source must still be cancellable\n' >&2
  exit 1
}

printf 'PASS: complete Windows suite keeps measured runtime headroom and immutable runs survive newer commits\n'
