#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${WORKFLOW_UNDER_TEST:-$ROOT/.github/workflows/verify.yml}"
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

windows_timeout="$(sed -n '/^  windows-offline-complete:/,/^  windows-offline:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
reviewer_timeout="$(sed -n '/^  windows-reviewer-safety:/,/^  report-scheduled-failure:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
fallback_timeout="$(sed -n '/^  windows-reviewer-fallback:/,/^  report-scheduled-failure:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
section_timeout="$(sed -n '/^  windows-offline-section:/,/^  windows-offline-complete:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
check 'complete Windows job keeps measured headroom' '[ -n "$windows_timeout" ] && [ "$windows_timeout" -ge 75 ]'
check 'reviewer Windows job keeps measured headroom' '[ -n "$reviewer_timeout" ] && [ "$reviewer_timeout" -ge 30 ]'
check 'hosted reviewer fallback covers measured worst case and stays bounded' '[ -n "$fallback_timeout" ] && [ "$fallback_timeout" -ge 50 ] && [ "$fallback_timeout" -le 60 ]'
check 'fast classifier is a separate reusable hosted-Ubuntu workflow' "grep -q 'uses: ./.github/workflows/fast-classifier.yml' '$workflow' && grep -q '^  workflow_call:' '$fast_workflow' && grep -q 'runs-on: ubuntu-24.04' '$fast_workflow'"
check 'Linux dependency refresh ignores unrelated runner feeds' "grep -q 'Dir::Etc::sourcelist=/etc/apt/sources.list.d/ubuntu.sources' '$workflow' && grep -q 'Dir::Etc::sourceparts=-' '$workflow'"
check 'long jobs skip only after successful prose classification' "[ \"\$(grep -c \"needs.fast-classifier.outputs.run_long == 'true'\" '$workflow')\" -eq 6 ] && [ \"\$(grep -cF 'needs: [fast-classifier, manual-preflight]' '$workflow')\" -eq 4 ] && grep -qF 'needs: [fast-classifier, manual-preflight, merge-group-evidence]' '$workflow'"
check 'classifier failure runs every existing check fail closed' "[ \"\$(grep -c \"needs.fast-classifier.result != 'success'\" '$workflow')\" -eq 6 ]"
check 'rename sources cannot disappear from classification' "grep -q 'git diff --no-renames --name-only' '$fast_workflow'"
check 'workflows have no top-level paths-ignore' "! grep -q 'paths-ignore:' '$workflow' && ! grep -q 'paths-ignore:' '$fast_workflow'"
check 'scheduled and manual complete runs exist' "grep -q '^  schedule:' '$workflow' && grep -q '^  workflow_dispatch:' '$workflow'"
check 'scheduled failures create or update an issue' "grep -q '^  report-scheduled-failure:' '$workflow' && sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q 'issues: write' && sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q 'gh issue create'"
# Windows verification runs in two lanes at once (issue #209): the long offline
# matrix on GitHub's hosted image, where concurrency is unmetered, and the
# reviewer safety suites on the qualified self-hosted pool, where a timing
# flake can be reproduced on a known physical machine. Neither lane may route
# to the daily-use EDGE-DEV computer or a bare candidate host.
# `ai-devops-windows` is the qualification-only label: a host carrying it has
# been registered, not proven.
check 'reviewer Windows job runs on the qualified independent pool' "[ \"\$(grep -cF 'runs-on: [self-hosted, Windows, X64, ai-devops-windows-qualified]' '$workflow')\" -eq 1 ]"
check 'sections, complete matrix and reviewer fallback keep the hosted lane' "[ \"\$(grep -cE '^[[:space:]]*runs-on:[[:space:]]*windows-2025[[:space:]]*\$' '$workflow')\" -eq 3 ]"
check 'no job routes to the daily-use desktop or an unqualified host' "! grep -E '^[[:space:]]*runs-on:' '$workflow' | grep -Eq 'ai-devops-windows\]|edge-dev\]'"
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
windows_sensitive="$(jq -r '.windows_sensitive_bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
windows_offline="$(jq -r '.windows_offline_bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
windows_reviewer="$(jq -r '.windows_reviewer_safety_bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
reviewer_workflow_count="$(grep -Fc "foreach (\$test in @('tests/test-ai-codex-review.sh', 'tests/test-ai-grok-review.sh'))" "$workflow")"
hosted_without_reviewer="$(comm -23 <(printf "%s\n" "$windows_offline") <(printf "%s\n" "$windows_reviewer"))"
# The queue gate carries no long jobs by design (#204), so the only thing
# standing between a queued commit and main is proof that the pull-request run
# on that exact commit passed. Losing this job would restore the silent trust
# #164 removed, and nothing else in this suite would notice.
check 'the merge queue proves the queued commit carries its own full verification' \
  "grep -q 'merge-group-evidence:' '$workflow' && grep -q 'ai-merge-group-evidence --ref' '$workflow'"
check 'the queue evidence gate demands both Windows lanes' \
  "grep -q -- '--require windows-offline' '$workflow' && grep -q -- '--require windows-reviewer-safety' '$workflow'"
# It must report on ordinary pull requests too. A required context that is
# silent on one event either hangs the queue for the full response timeout or
# blocks every pull request permanently - both halves of the #204 incident.
check 'the queue evidence gate reports on every event, not only merge groups' \
  "! awk '/^  merge-group-evidence:/{f=1;next} f&&/^  [a-z]/{exit} f' '$workflow' | grep -q \"if: .*event_name == 'merge_group'\""

check 'manifest declares 70 unique Bash suites' "[ \"\$(jq '.bash | length' '$manifest')\" -eq 70 ] && [ \"\$(jq '.bash | unique | length' '$manifest')\" -eq 70 ]"
check 'manifest declares 18 unique PowerShell suites' "[ \"\$(jq '.powershell | length' '$manifest')\" -eq 18 ] && [ \"\$(jq '.powershell | unique | length' '$manifest')\" -eq 18 ]"
check 'manifest exactly matches Bash discovery' '[ "$actual_bash" = "$manifest_bash" ]'
check 'manifest exactly matches PowerShell discovery' '[ "$actual_pwsh" = "$manifest_pwsh" ]'
check 'Windows groups are unique subsets of Bash discovery' \
  '[ "$(printf "%s\n" "$windows_sensitive" | LC_ALL=C sort -u)" = "$windows_sensitive" ] && [ "$(printf "%s\n" "$windows_offline" | LC_ALL=C sort -u)" = "$windows_offline" ] && [ "$(printf "%s\n" "$windows_reviewer" | LC_ALL=C sort -u)" = "$windows_reviewer" ] && [ -z "$(comm -13 <(printf "%s\n" "$manifest_bash") <(printf "%s\n" "$windows_sensitive"))" ]'
check 'manifest Windows coverage is complete before the reviewer split' '[ "$windows_offline" = "$windows_sensitive" ]'
check 'reviewer lane owns exactly Codex and Grok safety suites' \
  '[ "$windows_reviewer" = "$(printf "%s\n" test-ai-codex-review.sh test-ai-grok-review.sh | LC_ALL=C sort)" ] && [ "$reviewer_workflow_count" -eq 2 ] && [ -z "$(comm -23 <(printf "%s\n" "$windows_reviewer") <(printf "%s\n" "$windows_offline"))" ]'
section_block="$(sed -n '/^  windows-offline-section:/,/^  windows-offline-complete:/p' "$workflow")"
aggregate_block="$(sed -n '/^  windows-offline:$/,/^  windows-reviewer-safety:/p' "$workflow")"
shard_union="$(jq -r '.windows_offline_shards[][]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
shard_count="$(jq '.windows_offline_shards | length' "$manifest" | tr -d '\r')"
shard_smallest="$(jq '[.windows_offline_shards[] | length] | min' "$manifest" | tr -d '\r')"
powershell_owner="$(jq -r '.windows_offline_powershell_shard' "$manifest" | tr -d '\r')"
sections_declared="$(printf '%s\n' "$section_block" | sed -n 's/^[[:space:]]*section:[[:space:]]*//p' | tr -d '\r' | head -1)"
sections_expected="[$(seq -s ', ' 1 "$shard_count")]"
check 'declared sections cover the ordinary hosted lane exactly, with no suite twice' \
  '[ "$shard_union" = "$hosted_without_reviewer" ] && [ "$(printf "%s\n" "$shard_union" | LC_ALL=C sort -u)" = "$shard_union" ]'
check 'every declared section carries work' \
  '[ "$shard_count" -ge 2 ] && [ "$shard_smallest" -ge 1 ]'
check 'the PowerShell suites are owned by exactly one existing section' \
  '[ "$powershell_owner" != null ] && [ "$powershell_owner" -ge 1 ] && [ "$powershell_owner" -le "$shard_count" ]'
check 'the workflow runs exactly the sections the manifest declares' \
  '[ "$sections_declared" = "$sections_expected" ] && printf "%s" "$section_block" | grep -qF "matrix.section }}/$shard_count"'
# Sections run at the same time on independent hosted machines, and one failing
# section must never hide the other three.
check 'sections run on independent hosted machines and all keep reporting' \
  '[ -n "$section_timeout" ] && [ "$section_timeout" -le 40 ] && printf "%s" "$section_block" | grep -qF "fail-fast: false" && printf "%s" "$section_block" | grep -qE "^[[:space:]]*runs-on:[[:space:]]*windows-2025[[:space:]]*$"'
# #166 restores `windows-offline` as a required context, so it must keep that
# exact name and stay fail-closed: any lane result other than success, or a skip
# the classifier did not justify, fails the aggregate.
check 'one stable aggregate publishes the whole Windows lane' \
  '[ -n "$aggregate_block" ] && printf "%s" "$aggregate_block" | grep -qF "needs: [fast-classifier, manual-preflight, windows-offline-section, windows-offline-complete]"'
check 'the aggregate fails closed on anything but a justified skip' \
  'printf "%s" "$aggregate_block" | grep -qF "failing closed" && printf "%s" "$aggregate_block" | grep -qF "exit 1"'
# The scheduled backstop must watch the complete matrix, never a section of it.
check 'the scheduled reporter watches the complete Windows matrix' \
  "sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -qF 'windows-offline-complete'"
check 'ordinary hosted and self-hosted assignments are disjoint and complete' \
  '[ -z "$(comm -12 <(printf "%s\n" "$hosted_without_reviewer") <(printf "%s\n" "$windows_reviewer"))" ] && [ "$(printf "%s\n%s\n" "$hosted_without_reviewer" "$windows_reviewer" | LC_ALL=C sort -u)" = "$windows_sensitive" ]'

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
# and the long suite holds a qualified pool host for the better part of an hour.
windows_skips="$(grep -c "github.event_name != 'merge_group' &&" "$workflow" | tr -d '
')"
[ "$windows_skips" -eq 2 ] || {
  printf 'FAIL: both Windows jobs must be skipped on merge_group
' >&2
  exit 1
}
# Pull requests use the hosted Windows-sensitive assignment. Schedule and
# workflow_dispatch keep the no-argument complete runner as the backstop.
grep -Fq '.\tests\test-all.ps1 -WindowsPullRequest -ExcludeReviewerSafety -Shard' "$workflow" &&
[ "$(grep -cF '.\tests\test-all.ps1' "$workflow")" -eq 2 ] &&
grep -Eq '^[[:space:]]*\.\\tests\\test-all\.ps1[[:space:]]*$' "$workflow" &&
sed -n '/^  windows-offline-section:/,/^  windows-offline-complete:/p' "$workflow" | grep -Fq "github.event_name == 'pull_request'" &&
sed -n '/^  windows-offline-complete:/,/^  windows-offline:/p' "$workflow" | grep -Fq "github.event_name != 'pull_request'" || {
  printf 'FAIL: ordinary Windows selection and complete scheduled/manual fallback must both remain\n' >&2
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
[ "$hosted_pool" -eq 3 ] || {
  printf "FAIL: the sections, the complete matrix and the reviewer fallback must all keep GitHub's hosted lane\n" >&2
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
[ "$cancel_aware_jobs" -eq 7 ] || {
  printf 'FAIL: every dependent verification job must stop when its run is cancelled\n' >&2
  exit 1
}
if sed -n '/^  linux-offline:/,/^  report-scheduled-failure:/p' "$workflow" | grep -Fq 'if: always()'; then
  printf 'FAIL: always() would keep superseded pull-request work running after cancellation\n' >&2
  exit 1
fi
grep -Fq "github.event.pull_request.head.repo.full_name == github.repository" "$workflow" || {
  printf 'FAIL: untrusted fork pull requests must never reach the persistent self-hosted runner\n' >&2
  exit 1
}
grep -Fq "candidate.name === 'windows-reviewer-safety'" "$workflow" &&
grep -Fq "job.status === 'queued'" "$workflow" &&
grep -Fq 'const startDeadline = Date.now() + 10 * 60 * 1000' "$workflow" &&
grep -Fq 'const completionDeadline = Date.now() + 42 * 60 * 1000' "$workflow" &&
grep -Fq "needs['reviewer-safety-start-deadline'].result != 'success'" "$workflow" &&
grep -Fq "core.setOutput('fallback_required', 'true')" "$workflow" &&
grep -Fq "needs['reviewer-safety-start-deadline'].outputs.fallback_required == 'true'" "$workflow" || {
  printf 'FAIL: a reviewer lane that does not start or succeed must release the hosted fallback\n' >&2
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
  sed '/-WindowsPullRequest/d' "$workflow" >"$mutation_dir/full-windows-pr.yml"
  assert_rejected full-windows-pr
  sed "/needs\['reviewer-safety-start-deadline'\].outputs.fallback_required == 'true'/d" "$workflow" >"$mutation_dir/reviewer-gap.yml"
  assert_rejected reviewer-gap
  sed "/needs\['reviewer-safety-start-deadline'\].result != 'success'/d" "$workflow" >"$mutation_dir/watchdog-error-gap.yml"
  assert_rejected watchdog-error-gap
  sed "/job.status === 'queued'/d" "$workflow" >"$mutation_dir/unbounded-reviewer-queue.yml"
  assert_rejected unbounded-reviewer-queue
  sed '/Dir::Etc::sourceparts=-/d' "$workflow" >"$mutation_dir/third-party-apt-feed.yml"
  assert_rejected third-party-apt-feed
fi

[ "$failures" -eq 0 ] || { printf 'FAIL: %s workflow policy assertions failed\n' "$failures" >&2; exit 1; }
printf 'PASS: fast routing and both Windows lanes are preserved; manual proof cannot be cancelled automatically, exact-SHA successes deduplicate, provenance is required, and PR supersession remains enabled\n'
