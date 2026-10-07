#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/windows-runner-qualification.yml"
host_gate="$ROOT/tools/ci/assert-windows-runner-host.ps1"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -f "$workflow" ] || fail 'qualification workflow is missing'
[ -f "$host_gate" ] || fail 'shared host gate script is missing'
[ "$(grep -Fc 'run: .\tools\ci\assert-windows-runner-host.ps1' "$workflow")" -eq 2 ] || fail 'every qualification job must run the shared host gate'
grep -Fq 'runs-on: [self-hosted, Windows, X64, ai-devops-windows]' "$workflow" || fail 'qualification must use only the dedicated runner label'
grep -Fq 'workflow_dispatch:' "$workflow" || fail 'qualification needs an explicit manual rerun path'
grep -Fq "CurrentBuildNumber" "$host_gate" || fail 'qualification must prove the Windows build'
grep -Fq 'windows-runner-security.json' "$host_gate" || fail 'qualification must consume Administrator security evidence'
grep -Fq '[math]::Abs($evidenceAge.TotalHours) -gt 24' "$host_gate" || fail 'qualification must reject stale evidence while tolerating bounded clock skew'
grep -Fq "@('git', 'gh', 'jq', 'pwsh', 'node', 'python')" "$host_gate" || fail 'qualification must prove every service-visible runtime dependency'
grep -Fq 'actions.runner.*' "$host_gate" || fail 'qualification must prove the runner service'
grep -Fq '@($runnerService).Count -ne 1' "$host_gate" || fail 'qualification must require exactly one runner service'
grep -Fq 'github.event.pull_request.head.repo.full_name == github.repository' "$workflow" || fail 'fork pull requests must never reach the persistent runner'
grep -Fq 'run: .\tests\test-all.ps1' "$workflow" || fail 'qualification must run the complete declared suite'
grep -Fq 'git status --short --untracked-files=all' "$workflow" || fail 'qualification must prove reusable workspace cleanup'

# Sections scope: the lighter-jobs admission bar.
grep -Fq '      - tools/ci/assert-windows-runner-host.ps1' "$workflow" || fail 'a host gate change must trigger the qualification workflow'
grep -Fq 'needs: sections-host-pin' "$workflow" || fail 'sections must wait for the hosted host-pin proof'
grep -Fq "if: \${{ needs.sections-host-pin.result == 'success' &&" "$workflow" || fail 'sections must run only after a successful host-pin proof'
grep -Fq 'its sections would queue forever' "$workflow" || fail 'the host pin must refuse an offline runner'
grep -Fq 'not a Windows X64 ai-devops-windows candidate' "$workflow" || fail 'the host pin must refuse a non-candidate runner'
grep -Fq "tr '[:upper:]' '[:lower:]'" "$workflow" || fail 'the shared-label denylist must be case-insensitive'
grep -Fq 'must be carried by exactly one runner' "$workflow" || fail 'the host pin must prove a single candidate runner'
grep -Fq 'already in the qualified pool' "$workflow" || fail 'the host pin must refuse a qualified pool host'
grep -Fq 'options: [complete, sections]' "$workflow" || fail 'qualification must offer the sections scope'
grep -Fq "inputs.scope != 'sections'" "$workflow" || fail 'the complete job must not also run for a sections dispatch'
grep -Fq 'section: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]' "$workflow" || fail 'sections scope must cover all 12 pull-request sections'
grep -Fq 'runs-on: [self-hosted, Windows, X64, ai-devops-windows, "${{ inputs.runner_label }}"]' "$workflow" || fail 'sections must be pinned to the candidate host label'
grep -Fq "'ai-devops-windows-qualified')) {" "$workflow" || fail 'a shared pool label must not satisfy the host pin'
section_cmd="test-all.ps1 -WindowsPullRequest -ExcludeReviewerSafety -Shard '\${{ matrix.section }}/12'"
grep -Fq "$section_cmd" "$workflow" || fail 'sections must run exactly what verify.yml runs'
grep -Fq "$section_cmd" "$ROOT/.github/workflows/verify.yml" || fail 'verify.yml section command drifted from the qualification command'
[ "$(grep -Fc 'timeout-minutes: 40' "$workflow")" -eq 1 ] || fail 'each section must be held to the 40-minute section ceiling'
[ "$(grep -Fc 'git status --short --untracked-files=all' "$workflow")" -eq 2 ] || fail 'every qualification job must prove reusable workspace cleanup'

for wf in "$workflow" "$ROOT/.github/workflows/verify.yml"; do
  grep -Fq 'TMPDIR=$($short -replace' "$wf" || fail "$(basename "$wf") must point TMPDIR at the short TEMP root for Git Bash"
done

if grep -Fq 'edge-dev' "$workflow"; then
  fail 'qualification must not route through the legacy shared-host label'
fi

printf 'PASS: dedicated Windows runner qualification is security- and capability-complete\n'
