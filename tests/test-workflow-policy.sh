#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${WORKFLOW_UNDER_TEST:-$ROOT/.github/workflows/verify.yml}"

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
# Queue-tested commits must not consume a second Windows slot after landing.
if grep -Eq '^[[:space:]]+push:' "$workflow"; then
  printf 'FAIL: verify must not repeat merge-queue proof on push to main\n' >&2
  exit 1
fi
grep -Fq '|| github.sha' "$workflow" || {
  printf 'FAIL: manual verification must remain scoped to its immutable source SHA\n' >&2
  exit 1
}
# Neither Windows job may run on merge_group; a queue rebuild restarts them,
# and the long suite holds a qualified pool host for over an hour each time.
windows_skips="$(grep -c "github.event_name != 'merge_group' &&" "$workflow" | tr -d '
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

grep -Fq "cancel-in-progress: \${{ github.event_name == 'pull_request' }}" "$workflow" || {
  printf 'FAIL: only obsolete pull-request proof may be cancelled automatically\n' >&2
  exit 1
}

grep -Fq 'requester_task:' "$workflow" && grep -Fq 'purpose:' "$workflow" || {
  printf 'FAIL: manual verification must require visible task and purpose provenance\n' >&2
  exit 1
}
required_inputs="$(grep -c '^[[:space:]]*required: true' "$workflow" | tr -d '\r')"
[ "$required_inputs" -ge 2 ] || {
  printf 'FAIL: both manual provenance inputs must be required\n' >&2
  exit 1
}
grep -Fq "event: 'workflow_dispatch', status: 'completed'" "$workflow" &&
grep -Fq "run.head_sha === sha && run.conclusion === 'success'" "$workflow" || {
  printf 'FAIL: deduplication must reuse only complete successful exact-SHA proof\n' >&2
  exit 1
}
grep -Fq 'run.id !== current' "$workflow" || {
  printf 'FAIL: manual preflight must exclude its own run\n' >&2
  exit 1
}
cancel_aware_jobs="$(grep -c '!cancelled()' "$workflow" | tr -d '\r')"
[ "$cancel_aware_jobs" -eq 3 ] || {
  printf 'FAIL: every dependent verification job must stop when its run is cancelled\n' >&2
  exit 1
}
if grep -Fq 'if: always()' "$workflow"; then
  printf 'FAIL: always() would keep superseded pull-request work running after cancellation\n' >&2
  exit 1
fi
grep -Fq "github.event.pull_request.head.repo.full_name == github.repository" "$workflow" || {
  printf 'FAIL: untrusted fork pull requests must never reach the persistent self-hosted runner\n' >&2
  exit 1
}

if [ "${WORKFLOW_POLICY_MUTATION_CHILD:-0}" != 1 ]; then
  mutation_dir="$(mktemp -d)"
  trap 'rm -rf "$mutation_dir"' EXIT
  assert_rejected() {
    name="$1"
    if WORKFLOW_POLICY_MUTATION_CHILD=1 WORKFLOW_UNDER_TEST="$mutation_dir/$name.yml" bash "$0" >/dev/null 2>&1; then
      printf 'FAIL: policy test accepted mutation %s\n' "$name" >&2
      exit 1
    fi
  }
  sed "s/cancel-in-progress: \${{ github.event_name == 'pull_request' }}/cancel-in-progress: true/" "$workflow" >"$mutation_dir/manual-cancellation.yml"
  assert_rejected manual-cancellation
  sed "s/cancel-in-progress: \${{ github.event_name == 'pull_request' }}/cancel-in-progress: false/" "$workflow" >"$mutation_dir/pr-supersession.yml"
  assert_rejected pr-supersession
  sed 's/|| github.sha/|| github.run_id/' "$workflow" >"$mutation_dir/unique-manual-group.yml"
  assert_rejected unique-manual-group
  sed '0,/!cancelled()/s//!always()/' "$workflow" >"$mutation_dir/cancellation-insensitive-job.yml"
  assert_rejected cancellation-insensitive-job
fi

printf 'PASS: Windows lanes and headroom are preserved, manual proof cannot be cancelled automatically, exact-SHA successes deduplicate, provenance is required, and PR supersession remains enabled\n'
