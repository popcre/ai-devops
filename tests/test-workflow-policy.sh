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
# Neither Windows job may run on merge_group; a queue rebuild restarts them,
# and the long suite holds a qualified pool host for over an hour each time.
windows_skips="$(grep -c "if: github.event_name != 'merge_group'" "$workflow" | tr -d '
')"
[ "$windows_skips" -eq 2 ] || {
  printf 'FAIL: both Windows jobs must be skipped on merge_group
' >&2
  exit 1
}
# Windows verification runs in two lanes at once, and both must stay present.
# The self-hosted pool was added to this repository to have MORE Windows
# capacity than GitHub's runners alone, not to replace them: routing every
# Windows job to a one-host pool serialised the whole repository on
# 2026-09-02. So the long offline matrix keeps the GitHub-hosted lane, where
# concurrency is unmetered on a public repository and a run never waits for a
# machine, and the reviewer safety suites - the source of every timing flake
# worth investigating - keep the qualified self-hosted lane, where a failure
# can be reproduced on a known physical machine.
#
# EDGE-DEV and bare candidate hosts stay banned from `runs-on` either way.
# `ai-devops-windows` is the qualification-only label: a host carrying it has
# been registered, not proven. Membership in `ai-devops-windows-qualified`
# requires a green `qualify Windows runner` job on that exact physical host,
# and the pool may hold any number of qualified hosts.
windows_pool="$(grep -cF 'runs-on: [self-hosted, Windows, X64, ai-devops-windows-qualified]' "$workflow" | tr -d '\r')"
[ "$windows_pool" -eq 1 ] || {
  printf 'FAIL: the reviewer safety suites must run on the qualified self-hosted pool\n' >&2
  exit 1
}
hosted_pool="$(grep -cE '^[[:space:]]*runs-on:[[:space:]]*windows-2025[[:space:]]*$' "$workflow" | tr -d '\r')"
[ "$hosted_pool" -eq 1 ] || {
  printf "FAIL: the long Windows matrix must keep GitHub's hosted lane so the pool is extra capacity, not a replacement\n" >&2
  exit 1
}
if grep -E '^[[:space:]]*runs-on:' "$workflow" | grep -Eq 'ai-devops-windows\]|edge-dev\]'; then
  printf 'FAIL: verification must never route to the daily-use desktop or an unqualified candidate host\n' >&2
  exit 1
fi

grep -Fq 'cancel-in-progress: true' "$workflow" || {
  printf 'FAIL: duplicate verification runs for the same source must still be cancellable\n' >&2
  exit 1
}

printf 'PASS: Windows work runs in both the hosted and qualified self-hosted lanes, headroom kept, superseded pull-request runs are cancellable, and the merge queue schedules no Windows jobs
'
