#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/verify.yml"
fast_workflow="$ROOT/.github/workflows/fast-classifier.yml"
classifier="$ROOT/tools/ci/classify-changes.sh"
manifest="$ROOT/config/ci-suite-manifest.json"
failures=0

check() {
  local label="$1" command="$2"
  if eval "$command"; then printf '  ok   %s\n' "$label"
  else printf '  FAIL %s\n' "$label" >&2; failures=$((failures + 1)); fi
}
classify() { printf '%s\n' "$2" | bash "$classifier" "$1"; }

windows_timeout="$(sed -n '/^  windows-offline:/,/^  windows-reviewer-safety:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
reviewer_timeout="$(sed -n '/^  windows-reviewer-safety:/,/^  report-scheduled-failure:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
check 'complete Windows job covers lock wait plus execution' '[ -n "$windows_timeout" ] && [ "$windows_timeout" -ge 245 ]'
check 'reviewer Windows job covers lock wait plus execution' '[ -n "$reviewer_timeout" ] && [ "$reviewer_timeout" -ge 120 ]'
check 'fast classifier is a separate reusable hosted-Ubuntu workflow' "grep -q 'uses: ./.github/workflows/fast-classifier.yml' '$workflow' && grep -q '^  workflow_call:' '$fast_workflow' && grep -q 'runs-on: ubuntu-24.04' '$fast_workflow'"
check 'long jobs skip only after successful prose classification' "[ \"\$(grep -c \"needs.fast-classifier.outputs.run_long == 'true'\" '$workflow')\" -eq 3 ] && [ \"\$(grep -c '^    needs: fast-classifier$' '$workflow')\" -eq 3 ]"
check 'classifier failure runs every existing check fail closed' "[ \"\$(grep -c \"needs.fast-classifier.result != 'success'\" '$workflow')\" -eq 3 ]"
check 'rename sources cannot disappear from classification' "grep -q 'git diff --no-renames --name-only' '$fast_workflow'"
check 'workflows have no top-level paths-ignore' "! grep -q 'paths-ignore:' '$workflow' && ! grep -q 'paths-ignore:' '$fast_workflow'"
check 'scheduled and manual complete runs exist' "grep -q '^  schedule:' '$workflow' && grep -q '^  workflow_dispatch:' '$workflow'"
check 'scheduled failures create or update an issue' "grep -q '^  report-scheduled-failure:' '$workflow' && sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q 'issues: write' && sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q 'gh issue create'"
check 'EDGE-DEV jobs share one host lock without lossy Actions concurrency' "[ \"\$(grep -c 'Invoke-EdgeDevSerialized' '$workflow')\" -eq 2 ] && ! grep -q 'group: edge-dev-windows' '$workflow' && grep -Fq 'Global\ai-devops-edge-dev-ci' '$ROOT/tools/ci/edge-dev-serialization.ps1'"
check 'EDGE-DEV execution retains separate measured deadlines' "grep -q 'Invoke-EdgeDevSerialized -BodyMinutes 150' '$workflow' && grep -q 'Invoke-EdgeDevSerialized -BodyMinutes 30' '$workflow' && grep -q 'exceeded its.*execution limit' '$ROOT/tools/ci/edge-dev-serialization.ps1'"
check 'EDGE-DEV timeouts name the interrupted work instead of only the cutoff' "grep -q 'Last progress marker' '$ROOT/tools/ci/edge-dev-serialization.ps1' && grep -q 'StreamReader' '$ROOT/tools/ci/edge-dev-serialization.ps1'"
check 'EDGE-DEV behavioral fixture is present' "[ -f '$ROOT/tests/fixtures/ci/test-edge-dev-serialization.ps1' ]"
if command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -Command 'if (-not $IsWindows) { exit 1 }'; then
  check 'EDGE-DEV serialization behavior passes on Windows' "pwsh -NoProfile -File '$ROOT/tests/fixtures/ci/test-edge-dev-serialization.ps1'"
else
  printf '  ok   EDGE-DEV behavioral fixture is Windows-only (structural policy checked here)\n'
fi
check 'scheduled cancellation is actionable' "sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q \"contains(needs.\\*.result, 'cancelled')\""

check 'docs are prose-only' "classify pull_request 'docs/example.md' | grep -q '^run_long=false$'"
check 'root plans are prose-only' "classify pull_request 'plan_example.md' | grep -q '^run_long=false$'"
check 'skills always run long' "classify pull_request 'skills/shared/example/SKILL.md' | grep -q '^run_long=true$'"
check 'code runs long' "classify pull_request 'bin/ai-example' | grep -q '^run_long=true$'"
check 'workflow changes run long' "classify pull_request '.github/workflows/verify.yml' | grep -q '^workflow=true$'"
check 'PowerShell changes run long' "classify pull_request 'tests/example.ps1' | grep -q '^powershell=true$'"
check 'test fixtures run long' "classify pull_request 'tests/fixtures/example/data.md' | grep -q '^test_fixtures=true$'"
check 'non-PR events always run long' "classify schedule 'docs/example.md' | grep -q '^run_long=true$' && classify workflow_dispatch 'docs/example.md' | grep -q '^run_long=true$' && classify merge_group 'docs/example.md' | grep -q '^run_long=true$'"
check 'mixed changes fail closed' "printf 'docs/example.md\nbin/ai-example\n' | bash '$classifier' pull_request | grep -q '^run_long=true$'"
check 'skills-to-docs rename paths fail closed' "printf 'skills/shared/example/SKILL.md\ndocs/example.md\n' | bash '$classifier' pull_request | grep -q '^run_long=true$'"

actual_bash="$(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)"
actual_pwsh="$(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.ps1' ! -name 'test-all.ps1' -printf '%f\n' | LC_ALL=C sort)"
manifest_bash="$(jq -r '.bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
manifest_pwsh="$(jq -r '.powershell[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
check 'manifest declares 61 unique Bash suites' "[ \"\$(jq '.bash | length' '$manifest')\" -eq 61 ] && [ \"\$(jq '.bash | unique | length' '$manifest')\" -eq 61 ]"
check 'manifest declares 17 unique PowerShell suites' "[ \"\$(jq '.powershell | length' '$manifest')\" -eq 17 ] && [ \"\$(jq '.powershell | unique | length' '$manifest')\" -eq 17 ]"
check 'manifest exactly matches Bash discovery' '[ "$actual_bash" = "$manifest_bash" ]'
check 'manifest exactly matches PowerShell discovery' '[ "$actual_pwsh" = "$manifest_pwsh" ]'

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
windows_skips="$(grep -c "github.event_name != 'merge_group' &&" "$workflow" | tr -d '
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


[ "$failures" -eq 0 ] || { printf 'FAIL: %s workflow policy assertions failed\n' "$failures" >&2; exit 1; }
printf 'PASS: fast routing, complete event coverage, EDGE-DEV serialization, 61+17 suite manifest, cancellable superseded pull-request runs, and no edge-dev Windows jobs in the merge queue\n'