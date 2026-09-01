#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/windows-runner-qualification.yml"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -f "$workflow" ] || fail 'qualification workflow is missing'
grep -Fq 'runs-on: [self-hosted, Windows, X64, ai-devops-windows]' "$workflow" || fail 'qualification must use only the dedicated runner label'
grep -Fq 'workflow_dispatch:' "$workflow" || fail 'qualification needs an explicit manual rerun path'
grep -Fq "CurrentBuildNumber" "$workflow" || fail 'qualification must prove the Windows build'
grep -Fq 'windows-runner-security.json' "$workflow" || fail 'qualification must consume Administrator security evidence'
grep -Fq '[math]::Abs($evidenceAge.TotalHours) -gt 24' "$workflow" || fail 'qualification must reject stale evidence while tolerating bounded clock skew'
grep -Fq "@('git', 'gh', 'jq', 'pwsh')" "$workflow" || fail 'qualification must prove service-visible dependencies'
grep -Fq 'actions.runner.*' "$workflow" || fail 'qualification must prove the runner service'
grep -Fq 'run: .\tests\test-all.ps1' "$workflow" || fail 'qualification must run the complete declared suite'
grep -Fq 'git status --short --untracked-files=all' "$workflow" || fail 'qualification must prove reusable workspace cleanup'

if grep -Fq 'edge-dev' "$workflow"; then
  fail 'qualification must not route through the legacy shared-host label'
fi

printf 'PASS: dedicated Windows runner qualification is security- and capability-complete\n'
