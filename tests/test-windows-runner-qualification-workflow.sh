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
grep -Fq 'options: [complete, sections, ssh-host-trust]' "$workflow" || fail 'qualification must offer the original scopes and fixed diagnostic'
grep -Fq "inputs.scope == 'complete'" "$workflow" || fail 'the complete job must not also run for other dispatch scopes'
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

# Diagnostic scope has no qualification or maintenance side effects.
python3 - "$workflow" "$ROOT/tools/ci/read-windows-ssh-host-trust.ps1" <<'PY' || fail 'host trust diagnostic is not fixed, pinned and bounded'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
job = text.split('  ssh-host-trust:\n', 1)[1].split('\n  qualify-sections:', 1)[0]
for required in ('needs: sections-host-pin', "inputs.scope == 'ssh-host-trust'", 'timeout-minutes: 3',
                 '$env:RUNNER_NAME -cne $env:PINNED_RUNNER_NAME', 'ref: ${{ inputs.expected_source_sha }}',
                 '$env:DISPATCHED_SOURCE_SHA -cne $env:EXPECTED_SOURCE_SHA',
                 'EXPECTED_SOURCE_SHA: ${{ inputs.expected_source_sha }}',
                 '(git rev-parse HEAD) -cne $env:EXPECTED_SOURCE_SHA',
                 'EXPECTED_PEER_DIGEST: ${{ inputs.expected_peer_digest }}',
                 'run: .\\tools\\ci\\read-windows-ssh-host-trust.ps1'):
    assert required in job, required
for forbidden in ('assert-windows-runner-host', 'test-all.ps1', 'qualification-refresh', 'workflow_dispatch.inputs.command'):
    assert forbidden not in job, forbidden
assert '[ "$DIAGNOSTIC_SCOPE" != ssh-host-trust ]' in text
assert '[[ "$EXPECTED_PEER_DIGEST" =~ ^[0-9a-f]{64}$ ]]' in text
assert '[ "$DISPATCHED_SOURCE_SHA" = "$EXPECTED_SOURCE_SHA" ]' in text
assert '[[ "$EXPECTED_SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]]' in text
# Execute the exact hosted refusal block with wrong/moved and matched source.
import os, subprocess
block = text.split('          if [ "$DIAGNOSTIC_SCOPE" = ssh-host-trust ]; then\n', 1)[1].split('\n          fi', 1)[0]
expected = '1' * 40
for source, success in ((expected, True), ('2' * 40, False), ('', False)):
    env = dict(os.environ, EXPECTED_PEER_DIGEST='a' * 64, EXPECTED_SOURCE_SHA=expected, DISPATCHED_SOURCE_SHA=source)
    result = subprocess.run(['bash', '-c', block], env=env, capture_output=True)
    assert (result.returncode == 0) is success
env = dict(os.environ, EXPECTED_PEER_DIGEST='a' * 64, EXPECTED_SOURCE_SHA='', DISPATCHED_SOURCE_SHA=expected)
assert subprocess.run(['bash', '-c', block], env=env, capture_output=True).returncode != 0
source = pathlib.Path(sys.argv[2]).read_text()
for required in ('param()', 'C:\\ProgramData\\ssh\\ssh_host_', 'kind+"_key.pub"',
                 '0x08200000', 'info.Attr & 0x410', 'WaitForExit(15000)',
                 '$digest -cne $env:EXPECTED_PEER_DIGEST'):
    assert required in source, required
assert 'Set-Service' not in source and 'Register-ScheduledTask' not in source
PY

printf 'PASS: dedicated Windows runner qualification is security- and capability-complete\n'
