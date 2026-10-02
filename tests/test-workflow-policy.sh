#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${WORKFLOW_UNDER_TEST:-$ROOT/.github/workflows/verify.yml}"
warpbuild_workflow="$ROOT/.github/workflows/windows-offline-warpbuild.yml"
fast_workflow="$ROOT/.github/workflows/fast-classifier.yml"
classifier="$ROOT/tools/ci/classify-changes.sh"
global_manifest="$ROOT/config/ci-suite-manifest.json"
manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
# The reader-shaped manifest is assembled by the per-suite loader (#1001);
# every inventory, membership and section check below pins the loader output.
bash "$ROOT/tools/ci-suites/load-manifest" >"$manifest" || {
  printf 'FAIL: the suite manifest did not assemble through the loader\n' >&2
  exit 1; }
. "$ROOT/tools/lib/task-gates.sh"
failures=0

check() {
  local label="$1" command="$2"
  if eval "$command"; then printf '  ok   %s\n' "$label"
  else printf '  FAIL %s\n' "$label" >&2; failures=$((failures + 1)); fi
}
classify() {
  local result
  result="$(printf '%s\n' "$2" | tg_legacy_classify "$1")" || return
  printf '%s\n' "$result"
}

windows_timeout="$(sed -n '/^  windows-offline-complete:/,/^  windows-offline:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
reviewer_timeout="$(sed -n '/^  windows-reviewer-preferred:/,/^  reviewer-safety-start-deadline:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
fallback_timeout="$(sed -n '/^  windows-reviewer-fallback-codex:/,/^  windows-reviewer-fallback-grok:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
fallback_grok_timeout="$(sed -n '/^  windows-reviewer-fallback-grok:/,/^  windows-reviewer-safety:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
section_timeout="$(sed -n '/^  windows-offline-section:/,/^  windows-offline-warpbuild-proof:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
check 'complete Windows sections retain the existing timeout bound' '[ "$windows_timeout" = 105 ]'
check 'reviewer Windows job keeps measured headroom' '[ -n "$reviewer_timeout" ] && [ "$reviewer_timeout" -ge 30 ]'
check 'hosted reviewer fallback covers measured worst case and stays bounded' '[ -n "$fallback_timeout" ] && [ "$fallback_timeout" -ge 50 ] && [ "$fallback_timeout" -le 120 ] && [ -n "$fallback_grok_timeout" ] && [ "$fallback_grok_timeout" -ge 50 ] && [ "$fallback_grok_timeout" -le 120 ]'
check 'fast classifier is a separate reusable hosted-Ubuntu workflow' "grep -q 'uses: ./.github/workflows/fast-classifier.yml' '$workflow' && grep -q '^  workflow_call:' '$fast_workflow' && grep -q 'runs-on: ubuntu-24.04' '$fast_workflow'"
check 'Linux dependency refresh ignores unrelated runner feeds' "grep -q 'Dir::Etc::sourcelist=/etc/apt/sources.list.d/ubuntu.sources' '$workflow' && grep -q 'Dir::Etc::sourceparts=-' '$workflow'"
# P3 splits selection from fast validation. The assertions below check each
# expensive job's dependencies and required outcomes directly. They do not
# count how many times a fragment appears: a new expensive lane must carry the
# same gates, and a removed gate must fail here whatever the layout looks like.
job_block() {
  sed -n "/^  $1:/,/^  $2:/p" "$workflow"
}
# Capture the block first: `sed | grep -q` under `set -o pipefail` reports a
# false negative on Linux, where grep -q closes the pipe after the first match
# and sed's broken-pipe exit status is then what the pipeline returns.
job_has() {
  local block
  block="$(job_block "$1" "$2")"
  printf '%s' "$block" | grep -Fq "$3"
}
# Every long-suite job selects on the run-long output, not on the whole
# classifier result, and every reviewer-lane job selects on the reviewer
# output. Both keep the conservative "unknown selection runs everything" arm.
long_jobs_select_run_long_ok() {
  job_has linux-offline-shard linux-offline "outputs.run_long != 'false'" || return 1
  job_has linux-offline merge-group-evidence "outputs.run_long != 'false'" || return 1
  job_has windows-offline-section windows-offline-warpbuild-proof "outputs.run_long != 'false'" || return 1
  job_has windows-offline-complete windows-offline "outputs.run_long != 'false'" || return 1
  job_has linux-offline-shard linux-offline "outputs.selection_result != 'success'" || return 1
  job_has windows-offline-section windows-offline-warpbuild-proof "outputs.selection_result != 'success'" || return 1
  job_has windows-offline-complete windows-offline "outputs.selection_result != 'success'" || return 1
}
reviewer_jobs_select_reviewer_ok() {
  job_has reviewer-runner-availability windows-reviewer-preferred "outputs.reviewer != 'false'" || return 1
  job_has windows-reviewer-preferred reviewer-safety-start-deadline "outputs.reviewer != 'false'" || return 1
  job_has reviewer-safety-start-deadline windows-reviewer-fallback-codex "outputs.reviewer != 'false'" || return 1
  job_has windows-reviewer-fallback-codex windows-reviewer-fallback-grok "outputs.reviewer != 'false'" || return 1
  job_has windows-reviewer-fallback-grok windows-reviewer-safety "outputs.reviewer != 'false'" || return 1
  job_has reviewer-runner-availability windows-reviewer-preferred "outputs.selection_result != 'success'" || return 1
  job_has windows-reviewer-preferred reviewer-safety-start-deadline "outputs.selection_result != 'success'" || return 1
}
# A known terminal fast-validation failure starts no long job. This is the
# per-suite auto-cancel: each expensive suite is stopped before it starts, one
# suite at a time, without any whole-queue status tool.
expensive_jobs_carry_validation_stop_ok() {
  job_has linux-offline-shard linux-offline "outputs.validation_result != 'failure'" || return 1
  job_has linux-offline merge-group-evidence "outputs.validation_result != 'failure'" || return 1
  job_has windows-offline-section windows-offline-warpbuild-proof "outputs.validation_result != 'failure'" || return 1
  job_has windows-offline-complete windows-offline "outputs.validation_result != 'failure'" || return 1
  job_has reviewer-safety-start-deadline windows-reviewer-fallback-codex "outputs.validation_result != 'failure'" || return 1
  job_has windows-reviewer-fallback-codex windows-reviewer-fallback-grok "outputs.validation_result != 'failure'" || return 1
  job_has windows-reviewer-fallback-grok windows-reviewer-safety "outputs.validation_result != 'failure'" || return 1
  job_has reviewer-runner-availability windows-reviewer-preferred "outputs.validation_result != 'failure'" || return 1
}
check 'long and reviewer jobs use their separate selection outputs' long_jobs_select_run_long_ok
check 'reviewer lane selects on the reviewer output, not the whole classifier' reviewer_jobs_select_reviewer_ok
check 'a known terminal validation failure stops every expensive suite before it starts' expensive_jobs_carry_validation_stop_ok
# Missing or invalid classification never becomes a green skip: the aggregates
# accept a skip only on an explicit prose-only verdict from a successful
# selection. The old "anything that is not true" arm let an empty output skip
# every expensive suite and still pass.
never_green_skip_ok() {
  grep -Fq "\"\$RUN_LONG\" = 'false'" "$workflow" || return 1
  grep -Fq "\"\$RUN_REVIEWER\" = 'false'" "$workflow" || return 1
  ! grep -Fq "\"\$RUN_LONG\" != 'true'" "$workflow" || return 1
  ! grep -Fq "\"\$RUN_REVIEWER\" != 'true'" "$workflow" || return 1
}
check 'missing or invalid classification is never a green skip' never_green_skip_ok
# No-progress detector / per-suite auto-cancel: a suite that is cancelled or
# that never reported is no progress, never a pass. Per-suite cancel is the
# only cancellation scope; there is no whole-queue status tool.
no_progress_never_pass_ok() {
  grep -Fq 'bash tools/ci/verify-closure.sh' "$workflow" || return 1
  local closure_block
  closure_block="$(sed -n '/^  verification-closure:/,/^  report-scheduled-failure:/p' "$workflow")"
  printf '%s' "$closure_block" | grep -Fq 'outputs.validation_result' || return 1
  # The closure evaluator is the no-progress detector: it is the component that
  # names a cancelled or missing lane and refuses to close.
  grep -Fq 'cancelled' "$ROOT/tools/ci/verify-closure.sh" || return 1
  grep -Fq 'no progress' "$ROOT/tests/test-verify-closure.sh" || return 1
}
check 'no_progress_detector: a cancelled or missing suite is no progress and never a pass' no_progress_never_pass_ok
check 'rename sources cannot disappear from classification' "grep -q 'git diff --no-renames --name-only' '$fast_workflow'"
check 'workflows have no top-level paths-ignore' "! grep -q 'paths-ignore:' '$workflow' && ! grep -q 'paths-ignore:' '$fast_workflow'"
check 'scheduled and manual complete runs exist' "grep -q '^  schedule:' '$workflow' && grep -q '^  workflow_dispatch:' '$workflow'"
check 'scheduled failures create or update an issue with action labels' "grep -q '^  report-scheduled-failure:' '$workflow' && sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q 'issues: write' && sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q 'tools/ci/report-scheduled-failure.sh' && test -f '$ROOT/tools/ci/report-scheduled-failure.sh' && grep -q 'action-taxonomy' '$ROOT/tools/ci/report-scheduled-failure.sh'"
check 'capacity labels land on scheduled incidents (timeout/kill/rate-limit = capacity/infra)' \
  "grep -q 'capacity/infra' '$ROOT/tools/ci/action-taxonomy.sh' && grep -q 'action_taxonomy_check' '$ROOT/tools/ci/report-scheduled-failure.sh' && bash '$ROOT/tools/ci/action-taxonomy.sh' check TIMED_OUT | grep -qx 'capacity/infra' && bash '$ROOT/tools/ci/action-taxonomy.sh' check CANCELLED | grep -qx 'capacity/infra' && bash '$ROOT/tools/ci/action-taxonomy.sh' review empty-report | grep -qx 'review-step'"
check 'managed bin commands use the shared GitHub admission path' \
  "python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$ROOT' >/dev/null"
# Windows verification runs in two lanes at once (issue #209): the long offline
# matrix on Blacksmith, and the reviewer safety suites on the qualified
# self-hosted pool, where a timing flake can be reproduced on a known physical
# machine. Neither lane may route to the daily-use EDGE-DEV computer or a bare
# candidate host.
# `ai-devops-windows` is the qualification-only label: a host carrying it has
# been registered, not proven.
check 'reviewer Windows job prefers the qualified pool (ENVY)' "[ \"\$(grep -cF 'runs-on: [self-hosted, Windows, X64, ai-devops-windows-qualified]' '$workflow')\" -eq 1 ]"
check 'every fixed non-preferred Windows job runs on GitHub-hosted; routed sections fall back to it' "[ \"\$(grep -cE '^[[:space:]]*runs-on:[[:space:]]*windows-2025[[:space:]]*\$' '$workflow')\" -eq 3 ] && grep -qF 'needs.runner-router.outputs.windows_matrix ||' '$workflow'"
check 'no job routes to the daily-use desktop or an unqualified host' "! grep -E '^[[:space:]]*runs-on:' '$workflow' | grep -Eq 'ai-devops-windows\]|edge-dev\]'"
check 'scheduled cancellation is actionable' "sed -n '/^  report-scheduled-failure:/,\$p' '$workflow' | grep -q \"contains(needs.\\*.result, 'cancelled')\""

check 'docs are prose-only' "classify pull_request 'docs/example.md' | grep -q '^run_long=false$'"
check 'root plans are prose-only' "classify pull_request 'plan_example.md' | grep -q '^run_long=false$'"
check 'skills always run long' "classify pull_request 'skills/shared/example/SKILL.md' | grep -q '^run_long=true$'"
check 'code runs long' "classify pull_request 'bin/ai-example' | grep -q '^run_long=true$'"
check 'workflow changes run long' "classify pull_request '.github/workflows/verify.yml' | grep -q '^workflow=true$'"
check 'PowerShell changes run long' "classify pull_request 'tests/example.ps1' | grep -q '^powershell=true$'"
check 'test fixtures run long' "classify pull_request 'tests/fixtures/example/data.md' | grep -q '^test_fixtures=true$'"
check 'unrelated code skips reviewer lane' "classify pull_request 'bin/ai-example' | grep -q '^reviewer=false$'"
check 'every declared reviewer dependency selects reviewer lane' \
  ". '$ROOT/tools/lib/task-gates.sh'; while IFS= read -r pattern; do pattern=\${pattern%\$'\\r'}; case \"\$pattern\" in ''|'#'*) continue ;; esac; sample=\${pattern//\*\*\/nested\/file}; sample=\${sample//\*/file}; tg_legacy_classify pull_request <<<\"\$sample\" | grep -q '^reviewer=true$' || exit 1; done < '$ROOT/config/reviewer-ci-paths.txt'"
check 'reviewer path policy is safe after a Windows CRLF checkout' \
  "tmp=\$(mktemp -d); mkdir -p \"\$tmp/config\"; sed 's/\$/\\r/' '$ROOT/config/reviewer-ci-paths.txt' >\"\$tmp/config/reviewer-ci-paths.txt\"; saved_root=\$TG_LIB_REPO_ROOT; TG_LIB_REPO_ROOT=\$tmp; result=\$(tg_legacy_classify pull_request <<<'bin/ai-codex-review'); TG_LIB_REPO_ROOT=\$saved_root; rm -rf \"\$tmp\"; grep -Fqx 'reviewer=true' <<<\"\$result\""
check 'representative shared reviewer paths select reviewer lane' \
  ". '$ROOT/tools/lib/task-gates.sh'; for path in 'tools/reviewer_event_guard.sh' 'tools/reviewer_events.py' 'tools/reviewer_maintenance.py' 'tools/lib/provider-wrapper-common.sh' 'config/provider-cli-versions.json' 'tests/lib-test-timing.sh' '.github/workflows/verify.yml'; do tg_legacy_classify pull_request <<<\"\$path\" | grep -q '^reviewer=true$' || exit 1; done"
check 'non-PR events always run reviewer lane' "classify schedule 'docs/example.md' | grep -q '^reviewer=true$' && classify workflow_dispatch 'docs/example.md' | grep -q '^reviewer=true$'"
check 'non-PR events always run long' "classify schedule 'docs/example.md' | grep -q '^run_long=true$' && classify workflow_dispatch 'docs/example.md' | grep -q '^run_long=true$' && classify merge_group 'docs/example.md' | grep -q '^run_long=true$'"
check 'mixed changes fail closed' "printf 'docs/example.md\nbin/ai-example\n' | bash '$classifier' pull_request | grep -q '^run_long=true$'"
check 'skills-to-docs rename paths fail closed' "printf 'skills/shared/example/SKILL.md\ndocs/example.md\n' | bash '$classifier' pull_request | grep -q '^run_long=true$'"

actual_bash="$(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)"
actual_pwsh="$(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.ps1' ! -name 'test-all.ps1' -printf '%f\n' | LC_ALL=C sort)"
# A suspended suite is a declared omission from every executing lane, never a
# coverage hole: the complete-section union below must cover the remainder
# exactly (Kimi CI suspension, 2026-09-17).
suspended_bash="$(jq -r '.suspended_bash // [] | .[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
expected_bash="$(LC_ALL=C comm -23 <(printf '%s\n' "$actual_bash") <(printf '%s\n' "$suspended_bash"))"
manifest_bash="$(jq -r '.bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
manifest_pwsh="$(jq -r '.powershell[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
windows_sensitive="$(jq -r '.windows_sensitive_bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
windows_offline="$(jq -r '.windows_offline_bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
windows_reviewer="$(jq -r '.windows_reviewer_safety_bash[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
reviewer_workflow_count="$(grep -Ec 'test-ai-codex-review\.sh' "$workflow")"
# P6: hosted Codex and Grok proofs are independent jobs. Each suite must be
# named by the workflow at least once (preferred serial pair or its hosted
# fallback job).
codex_suite_count="$(grep -c 'test-ai-codex-review.sh' "$workflow" | tr -d '\r')"
grok_suite_count="$(grep -c 'test-ai-grok-review.sh' "$workflow" | tr -d '\r')"
hosted_without_reviewer="$(LC_ALL=C comm -23 <(printf "%s\n" "$windows_offline") <(printf "%s\n" "$windows_reviewer"))"
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
check 'one stable required closure covers pull requests and merge groups' \
  "grep -q '^  verification-closure:' '$workflow' && sed -n '/^  verification-closure:/,/^  report-scheduled-failure:/p' '$workflow' | grep -q \"github.event_name == 'pull_request'.*github.event_name == 'merge_group'\""
check 'the required closure depends on every pull-request and queue proof' \
  "grep -Fq 'needs: [fast-classifier, merge-group-evidence, doc-safety, linux-offline, windows-offline, windows-reviewer-safety]' '$workflow'"
check 'the required closure delegates to the regression-tested evaluator' \
  "sed -n '/^  verification-closure:/,/^  report-scheduled-failure:/p' '$workflow' | grep -Fq 'bash tools/ci/verify-closure.sh'"
check 'the required closure checks out its evaluator before running it' \
  "sed -n '/^  verification-closure:/,/^  report-scheduled-failure:/p' '$workflow' | awk '/uses: actions\/checkout@/{checkout=NR} /bash tools\/ci\/verify-closure.sh/{run=NR} END {exit !(checkout && run && checkout < run)}'"

# The #1188 doc gate: the two whole-repo doc invariants must run on EVERY
# event with no classification condition and no path filter — the opposite of
# the #1073 hole — and closure must receive its result fail-closed. A
# condition added to this job would let prose-only landings skip the only
# check whose input they control.
doc_safety_block="$(awk '/^  doc-safety:/{f=1;next} f&&/^  [a-z]/{exit} f' "$workflow")"
check 'a doc-safety job exists' "test -n '$doc_safety_block'"
check 'the doc-safety job is unconditional: no path filter, no classification condition' \
  "! printf '%s' '$doc_safety_block' | grep -q '^[[:space:]]*if:'"
check 'the doc-safety job runs the public-boundary and Markdown-link suites' \
  "printf '%s' '$doc_safety_block' | grep -q 'tests/test-public-boundary.sh' && printf '%s' '$doc_safety_block' | grep -q 'tests/test-markdown-links.sh'"
check 'the doc-safety job stays on the GitHub-hosted Linux pool' \
  "printf '%s' '$doc_safety_block' | grep -q 'runs-on: ubuntu-24.04'"
check 'closure evaluates the doc-safety result fail-closed' \
  "sed -n '/^  verification-closure:/,/^  report-scheduled-failure:/p' '$workflow' | grep -q 'needs.doc-safety.result'"

# Counts are derived from discovery (checked exactly below), never hard-coded:
# a literal count went stale on every new suite and failed 11 of 23 runs.
check 'manifest declares unique, non-empty Bash suites' "[ \"\$(jq '.bash | length' '$manifest')\" -gt 0 ] && [ \"\$(jq '.bash | length' '$manifest')\" -eq \"\$(jq '.bash | unique | length' '$manifest')\" ]"
# The split (#1001): per-suite data lives only in config/ci-suites/*.json and
# is assembled by the loader. Reintroducing a per-suite array or map in the
# global file would recreate the shared-file collision the split removed.
slim_violations() {
  jq -r 'keys | map(select(. == "bash" or . == "powershell" or . == "linux_offline_suite_seconds" or . == "windows_sensitive_bash" or . == "windows_reviewer_safety_bash" or . == "windows_offline_bash" or . == "windows_offline_shards")) | length' "$1" | tr -d '\r'
}
check 'the global manifest carries no per-suite data' '[ "$(slim_violations "$global_manifest")" -eq 0 ]'
slim_probe="$(mktemp)"
jq '. + {bash: ["test-reintroduced.sh"]}' "$global_manifest" >"$slim_probe"
check 'a reintroduced per-suite array in the global manifest is rejected' '[ "$(slim_violations "$slim_probe")" -ne 0 ]'
rm -f "$slim_probe"
check 'per-suite manifest files exist beside the global manifest' \
  '[ -d "$ROOT/config/ci-suites" ] && [ "$(find "$ROOT/config/ci-suites" -maxdepth 1 -name "*.json" | wc -l | tr -d " ")" -gt 0 ]'
check 'manifest declares unique, non-empty PowerShell suites' "[ \"\$(jq '.powershell | length' '$manifest')\" -gt 0 ] && [ \"\$(jq '.powershell | length' '$manifest')\" -eq \"\$(jq '.powershell | unique | length' '$manifest')\" ]"
check 'manifest exactly matches Bash discovery' '[ "$actual_bash" = "$manifest_bash" ]'
check 'manifest exactly matches PowerShell discovery' '[ "$actual_pwsh" = "$manifest_pwsh" ]'
check 'Windows groups are unique subsets of Bash discovery' \
  '[ "$(printf "%s\n" "$windows_sensitive" | LC_ALL=C sort -u)" = "$windows_sensitive" ] && [ "$(printf "%s\n" "$windows_offline" | LC_ALL=C sort -u)" = "$windows_offline" ] && [ "$(printf "%s\n" "$windows_reviewer" | LC_ALL=C sort -u)" = "$windows_reviewer" ] && [ -z "$(LC_ALL=C comm -13 <(printf "%s\n" "$manifest_bash") <(printf "%s\n" "$windows_sensitive"))" ]'
check 'manifest Windows coverage is complete before the reviewer split' '[ "$windows_offline" = "$windows_sensitive" ]'
check 'reviewer lane owns exactly Codex and Grok safety suites' \
  '[ "$windows_reviewer" = "$(printf "%s\n" test-ai-codex-review.sh test-ai-grok-review.sh | LC_ALL=C sort)" ] && [ "$codex_suite_count" -ge 1 ] && [ "$grok_suite_count" -ge 1 ] && [ -z "$(LC_ALL=C comm -23 <(printf "%s\n" "$windows_reviewer") <(printf "%s\n" "$windows_offline"))" ]'
# P6: hosted Codex and Grok proofs are independent jobs (wall near max, not sum).
# Each fallback job names exactly one suite and the aggregate requires both.
check 'hosted reviewer proofs are independent Codex and Grok jobs' \
  "grep -q '^  windows-reviewer-fallback-codex:' '$workflow' && grep -q '^  windows-reviewer-fallback-grok:' '$workflow' && printf '%s' \"\$(job_block windows-reviewer-fallback-codex windows-reviewer-fallback-grok)\" | grep -q 'tests/test-ai-codex-review.sh' && ! printf '%s' \"\$(job_block windows-reviewer-fallback-codex windows-reviewer-fallback-grok)\" | grep -q 'test-ai-grok-review.sh' && printf '%s' \"\$(job_block windows-reviewer-fallback-grok windows-reviewer-safety)\" | grep -q 'tests/test-ai-grok-review.sh' && ! printf '%s' \"\$(job_block windows-reviewer-fallback-grok windows-reviewer-safety)\" | grep -q 'test-ai-codex-review.sh'"
# Inputs are byte-sorted; comm under a UTF-8 locale (Git Bash) collates
# differently and silently misreports membership, so every comm is C-locale.
check 'every set comparison uses byte order on every platform'   "! grep -nE '(^|[^_=A-Z])comm -' '$0' | grep -v 'LC_ALL=C comm -'"
section_block="$(sed -n '/^  windows-offline-section:/,/^  windows-offline-warpbuild-proof:/p' "$workflow")"
aggregate_block="$(sed -n '/^  windows-offline:$/,/^  windows-reviewer-safety:/p' "$workflow")"
shard_union="$(jq -r '.windows_offline_shards[][]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
shard_count="$(jq '.windows_offline_shards | length' "$manifest" | tr -d '\r')"
shard_smallest="$(jq '[.windows_offline_shards[] | length] | min' "$manifest" | tr -d '\r')"
powershell_owner="$(jq -r '.windows_offline_powershell_shard' "$manifest" | tr -d '\r')"
deepseek_owner="$(jq -r 'to_entries[] | select(.value | index("test-ai-deepseek-agent.sh")) | .key + 1' < <(jq '.windows_offline_shards' "$manifest") | tr -d '\r')"
muse_owner="$(jq -r 'to_entries[] | select(.value | index("test-ai-muse.sh")) | .key + 1' < <(jq '.windows_offline_shards' "$manifest") | tr -d '\r')"
# The three suites that exceeded section 4's combined 40-minute budget on
# PR #666 must stay on separate hosts. The union check below protects every
# suite even when future timing measurements rebalance the lighter sections.
heavy_owners="$(jq -r '. as $manifest | ["test-ai-gemini.sh","test-ai-glm.sh","test-ai-muse-code.sh"] as $heavy | [$heavy[] | . as $suite | ($manifest.windows_offline_shards | to_entries[] | select(.value | index($suite)) | .key)] | @json' "$manifest" | tr -d '\r')"
# The section list is the router's all-GitHub fallback plan in verify.yml.
sections_declared="[$(printf '%s\n' "$section_block" | grep -o '"section":[0-9]*' | cut -d: -f2 | tr -d '\r' | paste -sd, - | sed 's/,/, /g')]"
routing="$ROOT/config/ci-runner-routing.json"
check 'the routing config names GitHub, ENVY, and WarpBuild — never Blacksmith' \
  '[ "$(jq -r .windows_sections "$routing")" = "$shard_count" ] && [ "$(jq -r .github_windows "$routing")" = windows-2025 ] && [ "$(jq -c .qualified_windows "$routing")" = "[\"self-hosted\",\"Windows\",\"X64\",\"ai-devops-windows-qualified\"]" ] && [ "$(jq -r .warpbuild_windows "$routing")" = warp-custom-warpbuild-win2022-canary ] && ! jq "del(._comment)" "$routing" | grep -qi blacksmith'
sections_expected="[$(seq -s ', ' 1 "$shard_count")]"
check 'declared sections cover the ordinary hosted lane exactly, with no suite twice' \
  '[ "$shard_union" = "$hosted_without_reviewer" ] && [ "$(printf "%s\n" "$shard_union" | LC_ALL=C sort -u)" = "$shard_union" ]'
check 'every declared section carries work' \
  '[ "$shard_count" -ge 2 ] && [ "$shard_smallest" -ge 1 ]'
check 'the PowerShell suites are owned by exactly one existing section' \
  '[ "$powershell_owner" != null ] && [ "$powershell_owner" -ge 1 ] && [ "$powershell_owner" -le "$shard_count" ]'
check 'the expanded DeepSeek and Muse suites run in separate sections' \
  '[ -n "$deepseek_owner" ] && [ -n "$muse_owner" ] && [ "$deepseek_owner" -ne "$muse_owner" ]'
check 'Gemini, GLM and Muse Code run in different sections within the same 90-minute bound' \
  '[ "$shard_count" -ge 6 ] && [ "$(printf "%s" "$heavy_owners" | jq "length")" -eq 3 ] && [ "$(printf "%s" "$heavy_owners" | jq "unique | length")" -eq 3 ] && [ "$section_timeout" -eq 90 ]'
check 'the workflow runs exactly the sections the manifest declares' \
  '[ "$sections_declared" = "$sections_expected" ] && printf "%s" "$section_block" | grep -qF "matrix.section }}/$shard_count"'
check 'manual WarpBuild lane runs the same complete section mapping' \
  'grep -qF "section: $sections_expected" "$warpbuild_workflow" && grep -qF "matrix.section }} of $shard_count" "$warpbuild_workflow" && grep -qF "matrix.section }}/$shard_count" "$warpbuild_workflow" && grep -qF -- "-Shard" "$warpbuild_workflow" && grep -qF "all eight WarpBuild sections succeeded" "$warpbuild_workflow"'
check 'WarpBuild stays manual, bounded, independently hosted and fail-closed' \
  'grep -q "^  workflow_dispatch:" "$warpbuild_workflow" && ! grep -Eq "^  (pull_request|schedule|merge_group|workflow_run):" "$warpbuild_workflow" && grep -qF "runs-on: warp-custom-warpbuild-win2022-canary" "$warpbuild_workflow" && grep -qF "timeout-minutes: 20" "$warpbuild_workflow" && grep -qF "fail-fast: false" "$warpbuild_workflow" && grep -qF "failing closed" "$warpbuild_workflow"'
# Sections run at the same time on independent hosted machines, and one failing
# section must never hide the other sections.
check 'sections run on independent hosted machines and all keep reporting' \
  '[ -n "$section_timeout" ] && [ "$section_timeout" -le 90 ] && printf "%s" "$section_block" | grep -qF "fail-fast: false" && printf "%s" "$section_block" | grep -qF "runs-on: \${{ matrix.runs_on }}" && [ "$(printf "%s" "$section_block" | grep -o "\"runs_on\":\"windows-2025\"" | wc -l | tr -d " ")" = "$shard_count" ]'
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
complete_block="$(awk '/^  windows-offline-complete:/{f=1;next} f&&/^  [a-z]/{exit} f' "$workflow")"
complete_sections="$(printf '%s\n' "$complete_block" | sed -n 's/^[[:space:]]*section:[[:space:]]*//p' | tr -d '\r')"
complete_count="$(printf '%s' "$complete_sections" | jq -er 'if type=="array" and length>0 and .==[range(1;length+1)] then length else error("invalid complete sections") end' 2>/dev/null || printf 0)"
check 'complete Windows matrix declares every section exactly once' \
  '[ "$complete_count" -ge 2 ] && [ "$powershell_owner" -ge 1 ] && [ "$powershell_owner" -le "$complete_count" ]'
check 'complete sections retain every test and report failures independently' \
  'printf "%s" "$complete_block" | grep -qF "fail-fast: false" && printf "%s" "$complete_block" | grep -qF "test-all.ps1 -Shard" && printf "%s" "$complete_block" | grep -qF "matrix.section }}/$complete_count" && ! printf "%s" "$complete_block" | grep -Eq -- "-WindowsPullRequest|-ExcludeReviewerSafety"'
complete_union=''; complete_selection_ok=true
for ((section=1; section<=complete_count; section++)); do
  if selected="$(bash "$ROOT/tests/test-all.sh" --shard "$section/$complete_count" --list 2>/dev/null)"; then
    complete_union+=$'\n'"$(printf '%s\n' "$selected" | grep '^test-')"
  else
    complete_selection_ok=false
  fi
done
complete_union="$(printf '%s\n' "$complete_union" | sed '/^$/d' | LC_ALL=C sort)"
check 'complete workflow sections cover runnable Bash discovery exactly, with no omissions or duplicates' \
  '[ "$complete_selection_ok" = true ] && [ "$complete_union" = "$expected_bash" ] && [ "$(printf "%s\n" "$complete_union" | LC_ALL=C sort -u)" = "$complete_union" ]'
check 'ordinary hosted and self-hosted assignments are disjoint and complete' \
  '[ -z "$(LC_ALL=C comm -12 <(printf "%s\n" "$hosted_without_reviewer") <(printf "%s\n" "$windows_reviewer"))" ] && [ "$(printf "%s\n%s\n" "$hosted_without_reviewer" "$windows_reviewer" | LC_ALL=C sort -u)" = "$windows_sensitive" ]'

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
# No physical Windows or fallback job may run on merge_group; a queue rebuild
# restarts them, and the long suite holds a qualified pool host for the better
# part of an hour. Asserted per job, not as a fragment count: a new Windows job
# must carry the same event isolation.
windows_merge_group_isolated_ok() {
  job_has windows-offline-section windows-offline-warpbuild-proof "github.event_name == 'pull_request'" || return 1
  job_has windows-offline-complete windows-offline "github.event_name != 'merge_group'" || return 1
  job_has windows-offline windows-reviewer-safety "github.event_name != 'merge_group'" || return 1
  job_has reviewer-runner-availability windows-reviewer-preferred "github.event_name != 'merge_group'" || return 1
  job_has windows-reviewer-preferred reviewer-safety-start-deadline "github.event_name != 'merge_group'" || return 1
  job_has reviewer-safety-start-deadline windows-reviewer-fallback-codex "github.event_name != 'merge_group'" || return 1
  job_has windows-reviewer-fallback-codex windows-reviewer-fallback-grok "github.event_name != 'merge_group'" || return 1
  job_has windows-reviewer-fallback-grok windows-reviewer-safety "github.event_name != 'merge_group'" || return 1
}
check 'physical Windows routing and fallback jobs are skipped on merge_group' windows_merge_group_isolated_ok
# Pull requests use the hosted Windows-sensitive assignment. Schedule and
# workflow_dispatch keep the complete sharded runner as the backstop.
grep -Fq '.\tests\test-all.ps1 -WindowsPullRequest -ExcludeReviewerSafety -Shard' "$workflow" &&
[ "$(grep -cF '.\tests\test-all.ps1' "$workflow")" -eq 3 ] &&
printf '%s' "$complete_block" | grep -Fq '.\tests\test-all.ps1 -Shard' &&
sed -n '/^  windows-offline-section:/,/^  windows-offline-warpbuild-proof:/p' "$workflow" | grep -F "github.event_name == 'pull_request'" >/dev/null &&
sed -n '/^  windows-offline-complete:/,/^  windows-offline:/p' "$workflow" | grep -F "github.event_name != 'pull_request'" >/dev/null || {
  printf 'FAIL: ordinary Windows selection and complete scheduled/manual fallback must both remain\n' >&2
  exit 1
}
# The WarpBuild BYOC proof lane (issue #961) runs the same required Windows
# suite but must never be load-bearing: continue-on-error, absent from
# verification-closure's needs, guarded against fork heads (those VMs are our
# Azure subscription), on the WarpBuild label, and capped at the live quota
# (standardDASv4Family 10 vCPUs = 2 concurrent Standard_D4as_v4 VMs). The
# required Blacksmith sections must never borrow these properties by accident,
# so the checks below read the proof job's own block only.
proof_ok() {
  local proof
  proof="$(job_block windows-offline-warpbuild-proof windows-offline-complete)"
  [ -n "$proof" ] || return 1
  printf '%s' "$proof" | grep -qF 'continue-on-error: true' || return 1
  printf '%s' "$proof" | grep -qF 'github.event.pull_request.head.repo.full_name == github.repository' || return 1
  printf '%s' "$proof" | grep -qF 'runs-on: warp-custom-warpbuild-win2022-canary' || return 1
  printf '%s' "$proof" | grep -qF 'max-parallel: 2' || return 1
  printf '%s' "$proof" | grep -qF 'section: [1, 2, 3, 4, 5, 6, 7, 8]' || return 1
  printf '%s' "$proof" | grep -qF '.\tests\test-all.ps1 -WindowsPullRequest -ExcludeReviewerSafety -Shard' || return 1
  # Not load-bearing: verification-closure must not depend on it.
  ! grep -qF 'windows-offline-warpbuild-proof' <(sed -n '/^  verification-closure:/,/^  report-scheduled-failure:/p' "$workflow") || return 1
  # And the required section matrix must never route to the WarpBuild label.
  ! grep -qF 'warp-custom-warpbuild-win2022-canary' <(sed -n '/^  windows-offline-section:/,/^  windows-offline-warpbuild-proof:/p' "$workflow") || return 1
}
check 'the WarpBuild proof lane is non-blocking, fork-guarded, quota-capped and outside the required aggregate' proof_ok
# The fork-isolation guard on the required section matrix is security-critical:
# a foreign head must always get the all-GitHub-hosted literal regardless of
# what the router reports. This test reads the matrix expression itself and
# fails if the head-repo check or the GitHub-hosted fallback is removed or
# weakened. Blacksmith is turned off and must not appear.
fork_guard_ok() {
  local section_block matrix_line
  section_block="$(sed -n '/^  windows-offline-section:/,/^  windows-offline-warpbuild-proof:/p' "$workflow")"
  [ -n "$section_block" ] || { echo 'fork_guard: empty section block' >&2; return 1; }
  matrix_line="$(printf '%s
' "$section_block" | grep 'include:')"
  [ -n "$matrix_line" ] || { echo 'fork_guard: no include line found' >&2; return 1; }
  # The guard must test head repo against the repository itself.
  printf '%s' "$matrix_line" | grep -qF 'github.event.pull_request.head.repo.full_name == github.repository' || { echo 'fork_guard: missing head-repo check' >&2; return 1; }
  # The fallback must be the all-GitHub-hosted literal.
  printf '%s' "$matrix_line" | grep -qF 'windows-2025' || { echo 'fork_guard: no windows-2025 label in fallback' >&2; return 1; }
  # No WarpBuild, self-hosted, or Blacksmith label in the fallback literal.
  printf '%s' "$matrix_line" | grep -qF 'warp-custom' && { echo 'fork_guard: warp label leaked into fallback' >&2; return 1; }
  printf '%s' "$matrix_line" | grep -qF 'self-hosted' && { echo 'fork_guard: self-hosted label leaked into fallback' >&2; return 1; }
  printf '%s' "$matrix_line" | grep -qiF 'blacksmith' && { echo 'fork_guard: blacksmith label leaked into fallback' >&2; return 1; }
  # The surrounding comment must name the primary fork protection and
  # describe the workflow check as defense-in-depth.
  printf '%s
' "$section_block" | grep -qF 'all_external_contributors' || { echo 'fork_guard: missing all_external_contributors reference' >&2; return 1; }
  printf '%s
' "$section_block" | grep -qF 'defense-in-depth' || { echo 'fork_guard: missing defense-in-depth note' >&2; return 1; }
}
check 'the required section matrix fork guard falls back to GitHub-hosted and cannot be silently removed' fork_guard_ok
# Windows verification runs in two lanes at once, and both must stay present.
# The self-hosted pool was added to this repository to have MORE Windows
# capacity than Blacksmith alone, not to replace it: routing every
# Windows job to a one-host pool serialised the whole repository on
# 2026-09-02. So the long offline matrix stays on Blacksmith (owner 2026-10-01:
# KEEP Blacksmith in the pool until WarpBuild is fully up) and the reviewer
# safety suites - the source of every timing flake worth investigating - keep
# the qualified self-hosted lane, where a failure can be reproduced on a known
# physical machine.
#
# EDGE-DEV and bare candidate hosts stay banned from `runs-on` either way.
# `ai-devops-windows` is the qualification-only label: a host carrying it has
# been registered, not proven. Membership in `ai-devops-windows-qualified`
# requires a green `qualify Windows runner` job on that exact physical host,
# and the pool may hold any number of qualified hosts.
# 2026-10-01: Albert took Blacksmith out of the pool. Preference order is
# GitHub-hosted runners and idle edge-runn-envy first; WarpBuild Azure BYOC is
# the final option only after both are full (config/ci-runner-routing.json).
# The reviewer lane still prefers idle ENVY and falls back to GitHub-hosted.
# Permitted runners: the qualified self-hosted pool is allowed only on the
# preferred reviewer job, and the fixed non-preferred Windows jobs must
# stay on GitHub-hosted. Asserted per job so a new job cannot quietly claim a
# runner it was never granted.
qualified_pool_ok() {
  job_has windows-reviewer-preferred reviewer-safety-start-deadline 'runs-on: [self-hosted, Windows, X64, ai-devops-windows-qualified]' || return 1
  [ "$(grep -F 'ai-devops-windows-qualified]' "$workflow" | grep -c 'runs-on' | tr -d '\r')" -eq 1 ]
}
check 'only the preferred reviewer job may use the qualified self-hosted pool' qualified_pool_ok
github_fixed_windows_ok() {
  job_has windows-offline-complete windows-offline 'runs-on: windows-2025' || return 1
  job_has windows-reviewer-fallback-codex windows-reviewer-fallback-grok 'runs-on: windows-2025' || return 1
  job_has windows-reviewer-fallback-grok windows-reviewer-safety 'runs-on: windows-2025' || return 1
}
check 'the fixed non-preferred Windows verify jobs run on GitHub-hosted' github_fixed_windows_ok
if grep -E '^[[:space:]]*runs-on:' "$workflow" | grep -Eqi 'blacksmith'; then
  printf 'FAIL: Blacksmith is out of the runner pool
' >&2
  exit 1
fi
if ! grep -E '^[[:space:]]*runs-on:' "$workflow" | grep -Eq 'ubuntu-24\.04|windows-2025'; then
  printf 'FAIL: verify jobs must use GitHub-hosted runners as the default pool
' >&2
  exit 1
fi
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
linux_shard_block="$(sed -n '/^  linux-offline-shard:/,/^  linux-offline:$/p' "$workflow")"
linux_aggregate_block="$(sed -n '/^  linux-offline:$/,/^  merge-group-evidence:/p' "$workflow")"
linux_weight_names="$(jq -r '.linux_offline_suite_seconds | keys[]' "$manifest" | tr -d '\r' | LC_ALL=C sort)"
# docs/ci-speed-audit-2026-09-17.md speedup 2: the Linux lane is sectioned on
# independent hosted machines, and the required `linux-offline` name survives
# as a fail-closed aggregate that proves every suite ran exactly once.
check 'the offline Bash suite runs as balanced parallel sections' \
  'printf "%s" "$linux_shard_block" | grep -qF "fail-fast: false" && printf "%s" "$linux_shard_block" | grep -qF "shard: [1, 2, 3, 4]" && printf "%s" "$linux_shard_block" | grep -qF "tests/test-all.sh --balanced --shard" && printf "%s" "$linux_shard_block" | grep -qF "matrix.shard }}/4" && ! printf "%s" "$linux_shard_block" | grep -qE "run: bash tests/test-all.sh[[:space:]]*$"'
check 'the required linux-offline name is a fail-closed aggregate over every section' \
  'printf "%s" "$linux_aggregate_block" | grep -qF "needs: [fast-classifier, manual-preflight, linux-offline-shard]" && printf "%s" "$linux_aggregate_block" | grep -qF "bash tools/ci/linux-offline-aggregate.sh \"\$SHARD_RESULT\" 4" && printf "%s" "$linux_aggregate_block" | grep -qF "needs.linux-offline-shard.result" && printf "%s" "$linux_aggregate_block" | awk "/uses: actions\/checkout@/{c=NR} /linux-offline-aggregate.sh/{r=NR} END {exit !(c && r && c < r)}"'
check 'the aggregate and its sections share one run condition, so a skip is never a pass' \
  '[ "$(printf "%s\n" "$linux_shard_block" | grep "^    if:")" = "$(printf "%s\n" "$linux_aggregate_block" | grep "^    if:")" ]'
check 'measured Linux suite seconds name only discovered suites' \
  '[ -n "$linux_weight_names" ] && [ -z "$(LC_ALL=C comm -23 <(printf "%s\n" "$linux_weight_names") <(printf "%s\n" "$manifest_bash"))" ]'
check 'the four balanced sections partition every runnable Bash suite exactly once' \
  '[ "$(for i in 1 2 3 4; do bash "$ROOT/tests/test-all.sh" --balanced --shard "$i/4" --list | grep "^test-"; done | LC_ALL=C sort)" = "$expected_bash" ]'
# Every dependent verification job must stop when its run is cancelled. The
# assertion is per job: a new dependent job must carry the same cancellation
# awareness, and a removed arm must fail here whatever the layout looks like.
cancel_aware_ok() {
  job_has linux-offline-shard linux-offline '!cancelled()' || return 1
  job_has linux-offline merge-group-evidence '!cancelled()' || return 1
  job_has windows-offline-section windows-offline-warpbuild-proof '!cancelled()' || return 1
  job_has windows-offline-complete windows-offline '!cancelled()' || return 1
  job_has windows-offline windows-reviewer-safety '!cancelled()' || return 1
  job_has reviewer-runner-availability windows-reviewer-preferred '!cancelled()' || return 1
  job_has windows-reviewer-preferred reviewer-safety-start-deadline '!cancelled()' || return 1
  job_has reviewer-safety-start-deadline windows-reviewer-fallback-codex '!cancelled()' || return 1
  job_has windows-reviewer-fallback-codex windows-reviewer-fallback-grok '!cancelled()' || return 1
  job_has windows-reviewer-fallback-grok windows-reviewer-safety '!cancelled()' || return 1
  job_has windows-reviewer-safety report-scheduled-failure '!cancelled()' || return 1
  job_has verification-closure report-scheduled-failure '!cancelled()' || return 1
}
check 'every dependent verification job stops when its run is cancelled' cancel_aware_ok
if sed -n '/^  linux-offline:/,/^  report-scheduled-failure:/p' "$workflow" | grep -Fq 'if: always()'; then
  printf 'FAIL: always() would keep superseded pull-request work running after cancellation\n' >&2
  exit 1
fi
grep -Fq "github.event.pull_request.head.repo.full_name == github.repository" "$workflow" || {
  printf 'FAIL: untrusted fork pull requests must never reach the persistent self-hosted runner\n' >&2
  exit 1
}
grep -Fq '$process.WaitForExit(55 * 60 * 1000)' "$workflow" &&
grep -Fq 'proof_result=timed_out' "$workflow" &&
grep -Fq 'proof_result=failure' "$workflow" &&
grep -Fq 'proof_result=success' "$workflow" &&
grep -Fq 'proof_result=cleanup_failure' "$workflow" &&
grep -Fq "v === 'success' || v === 'cleanup_failure' ? 'false' : 'true'" "$workflow" &&
grep -Fq "needs['reviewer-safety-start-deadline'].result != 'success'" "$workflow" &&
grep -Fq "core.setOutput('fallback_codex', fallbackCodex)" "$workflow" &&
grep -Fq "core.setOutput('fallback_grok', fallbackGrok)" "$workflow" &&
grep -Fq "needs['reviewer-safety-start-deadline'].outputs.fallback_codex == 'true'" "$workflow" &&
grep -Fq "needs['reviewer-safety-start-deadline'].outputs.fallback_grok == 'true'" "$workflow" || {
  printf 'FAIL: a reviewer lane that does not start or succeed must release the hosted fallback\n' >&2
  exit 1
}

reviewer_aggregate="$(sed -n '/^  windows-reviewer-safety:/,/^  report-scheduled-failure:/p' "$workflow")"
reviewer_preferred="$(sed -n '/^  windows-reviewer-preferred:/,/^  reviewer-safety-start-deadline:/p' "$workflow")"
reviewer_fallback="$(sed -n '/^  windows-reviewer-fallback-codex:/,/^  windows-reviewer-safety:/p' "$workflow")"
reviewer_availability="$(sed -n '/^  reviewer-runner-availability:/,/^  windows-reviewer-preferred:/p' "$workflow")"
! printf '%s' "$reviewer_availability" | grep -Fq "github.event_name == 'workflow_dispatch' &&" &&
printf '%s' "$reviewer_availability" | grep -Fq "github.event.pull_request.head.repo.full_name == github.repository" &&
printf '%s' "$reviewer_preferred" | grep -Fq "group: ai-devops-windows-reviewer-preferred" &&
printf '%s' "$reviewer_preferred" | grep -q '^[[:space:]]*continue-on-error:[[:space:]]*true' &&
printf '%s' "$reviewer_preferred" | grep -Fq "needs.reviewer-runner-availability.outputs.preferred_available == 'true'" &&
grep -Fq "runner.status === 'online' && !runner.busy" "$workflow" &&
grep -Fq "core.setOutput('preferred_available', 'false')" "$workflow" &&
! printf '%s' "$reviewer_fallback" | grep -Fq 'github.event.pull_request.head.repo.full_name == github.repository' &&
printf '%s' "$reviewer_aggregate" | grep -Fq 'needs: [fast-classifier, manual-preflight, reviewer-safety-start-deadline, windows-reviewer-fallback-codex, windows-reviewer-fallback-grok]' &&
! printf '%s' "$reviewer_aggregate" | grep -Fq 'needs.windows-reviewer-preferred' || {
  printf 'FAIL: preferred reviewer failure or scheduling must not block the stable aggregate\n' >&2
  exit 1
}
printf '%s' "$reviewer_aggregate" | grep -Fq "suite_proved \"\$CODEX_PREFERRED\" \"\$CODEX_FALLBACK\"" &&
printf '%s' "$reviewer_aggregate" | grep -Fq "suite_proved \"\$GROK_PREFERRED\" \"\$GROK_FALLBACK\"" &&
printf '%s' "$reviewer_aggregate" | grep -Fq "no complete reviewer proof" || {
  printf 'FAIL: stable reviewer aggregate must accept per-suite proof and fail closed without complete proof\n' >&2
  exit 1
}

aggregate_script="$(mktemp)"
awk '
  /^  windows-reviewer-safety:$/ { in_job=1 }
  in_job && /^[[:space:]]+run: \|$/ { in_run=1; next }
  in_run && /^  [a-zA-Z0-9_-]+:$/ { exit }
  in_run { sub(/^          /, ""); print }
' "$workflow" >"$aggregate_script"
chmod +x "$aggregate_script"
check_reviewer_result() {
  expected="$1"; shift
  if env "$@" bash "$aggregate_script" >/dev/null 2>&1; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || {
    printf 'FAIL: reviewer aggregate returned %s, expected %s for %s\n' "$actual" "$expected" "$*" >&2
    exit 1
  }
}
common_reviewer_env='EVENT=pull_request SELECTION_RESULT=success RUN_REVIEWER=true RUN_EXPENSIVE=true WATCHDOG_RESULT=success'
# Regression: a timed-out or cancelled preferred host is not a global stop when
# the independent hosted runners completed every identical reviewer assertion.
# Each suite is proved on its own; both hosted suites succeeding is complete.
check_reviewer_result 0 $common_reviewer_env PREFERRED_RESULT=cancelled CODEX_PREFERRED=cancelled GROK_PREFERRED=cancelled CODEX_FALLBACK=success GROK_FALLBACK=success
check_reviewer_result 0 $common_reviewer_env PREFERRED_RESULT=failure CODEX_PREFERRED=failure GROK_PREFERRED=success CODEX_FALLBACK=success GROK_FALLBACK=skipped
check_reviewer_result 1 $common_reviewer_env PREFERRED_RESULT=cancelled CODEX_PREFERRED=cancelled GROK_PREFERRED=cancelled CODEX_FALLBACK=failure GROK_FALLBACK=success
check_reviewer_result 1 $common_reviewer_env PREFERRED_RESULT=cancelled CODEX_PREFERRED=cancelled GROK_PREFERRED=cancelled CODEX_FALLBACK=skipped GROK_FALLBACK=skipped
check_reviewer_result 1 $common_reviewer_env PREFERRED_RESULT=cleanup_failure CODEX_PREFERRED=cleanup_failure GROK_PREFERRED=cleanup_failure CODEX_FALLBACK=skipped GROK_FALLBACK=skipped
check_reviewer_result 0 EVENT=pull_request SELECTION_RESULT=success RUN_REVIEWER=false RUN_EXPENSIVE=true WATCHDOG_RESULT=skipped PREFERRED_RESULT= CODEX_PREFERRED= GROK_PREFERRED= CODEX_FALLBACK=skipped GROK_FALLBACK=skipped
check_reviewer_result 0 EVENT=workflow_dispatch SELECTION_RESULT=success RUN_REVIEWER=true RUN_EXPENSIVE=false WATCHDOG_RESULT=skipped PREFERRED_RESULT= CODEX_PREFERRED= GROK_PREFERRED= CODEX_FALLBACK=skipped GROK_FALLBACK=skipped
# Missing or invalid selection never becomes a green skip of the reviewer lane.
check_reviewer_result 1 EVENT=pull_request SELECTION_RESULT=missing RUN_REVIEWER= RUN_EXPENSIVE=true WATCHDOG_RESULT=skipped PREFERRED_RESULT= CODEX_PREFERRED= GROK_PREFERRED= CODEX_FALLBACK=skipped GROK_FALLBACK=skipped
check_reviewer_result 1 EVENT=pull_request SELECTION_RESULT=failure RUN_REVIEWER= RUN_EXPENSIVE=true WATCHDOG_RESULT=skipped PREFERRED_RESULT= CODEX_PREFERRED= GROK_PREFERRED= CODEX_FALLBACK=skipped GROK_FALLBACK=skipped
rm -f "$aggregate_script"

if [ "${WORKFLOW_POLICY_MUTATION_CHILD:-0}" != 1 ]; then
  mutation_dir="$(mktemp -d)"
  trap 'rm -rf "$mutation_dir"' EXIT
  mkdir -p "$mutation_dir/bin"
  printf '#!/usr/bin/env bash\n"$ROOT/bin/ai-gh" api repos/acme/example\n' > "$mutation_dir/bin/ai-fixture"
  check 'a delegated fake transport remains allowed' \
    "python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null"
  cat > "$mutation_dir/bin/ai-private-config" <<'BOOTSTRAP'
#!/usr/bin/env bash
if ! gh auth status >/dev/null 2>&1; then
mkdir -p "$(dirname "$ROOT")"; gh repo clone "$REPOSITORY" "$ROOT" >/dev/null
BOOTSTRAP
  check 'approved first-clone authentication and Git clone remain allowed' \
    "python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null"
  printf 'gh auth status\n' > "$mutation_dir/bin/ai-bypass"
  check 'new direct auth status probes are rejected' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  cp "$ROOT/bin/ai-pr-wait" "$mutation_dir/bin/ai-pr-wait"
  printf '\ngh api repos/acme/example\n' >> "$mutation_dir/bin/ai-pr-wait"
  check 'retired waiter fallback cannot reappear beside guidance text' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-pr-wait"
  printf '#!/usr/bin/env bash\ngh api repos/acme/example\n' > "$mutation_dir/bin/ai-bypass"
  check 'a new direct gh command is rejected' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env bash\nCLI=gh\n"$CLI" api repos/acme/example\n' > "$mutation_dir/bin/ai-bypass"
  check 'a CLI alias cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env bash\ngh \\\n api repos/acme/example\n' > "$mutation_dir/bin/ai-bypass"
  check 'a line continuation cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env node\nconst cli = "gh"; require("child_process").execFileSync(cli, ["api", "rate_limit"]);\n' > "$mutation_dir/bin/ai-bypass"
  check 'a Node CLI alias cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env python3\nimport subprocess\nsubprocess.run(["gh", "api", "rate_limit"])\n' > "$mutation_dir/bin/ai-bypass.py"
  check 'a Python argument array cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.py"
  printf '@echo off\r\ngh api repos/acme/example\r\n' > "$mutation_dir/bin/ai-bypass.cmd"
  check 'a Windows CMD launcher cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.cmd"
  printf '@echo off\r\ngh ^\r\n cache list\r\n' > "$mutation_dir/bin/ai-bypass.cmd"
  check 'a CMD continuation and cache command cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.cmd"
  printf '& "gh.exe" `\n label list\n' > "$mutation_dir/bin/ai-bypass.ps1"
  check 'a quoted PowerShell continuation and label command cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.ps1"
  printf '#!/usr/bin/env bash\n/usr/local/bin/gh api repos/acme/example\n' > "$mutation_dir/bin/ai-bypass"
  check 'an absolute GitHub CLI path cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env python3\nimport subprocess\nsubprocess.run(["/usr/local/bin/gh", "api", "rate_limit"])\n' > "$mutation_dir/bin/ai-bypass.py"
  check 'an absolute Python CLI array cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.py"
  printf '#!/usr/bin/env python3\nimport subprocess\nsubprocess.run([\n    "gh",\n    "status",\n])\n' > "$mutation_dir/bin/ai-bypass.py"
  check 'a multiline Python status call cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.py"
  printf '#!/usr/bin/env node\nrequire("child_process").execFileSync("/usr/local/bin/gh", ["api", "rate_limit"]);\n' > "$mutation_dir/bin/ai-bypass"
  check 'an absolute Node CLI argument cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env node\nrequire("child_process").execFileSync(\n  "gh", ["api", "rate_limit"]\n);\n' > "$mutation_dir/bin/ai-bypass"
  check 'a multiline Node call cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf 'Start-Process -FilePath "gh.exe" -ArgumentList "api", "rate_limit"\n' > "$mutation_dir/bin/ai-bypass.ps1"
  check 'PowerShell Start-Process cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.ps1"
  printf 'Start-Process -FilePath "C:\\Program Files\\GitHub CLI\\gh.exe" -ArgumentList "api", "rate_limit"\n' > "$mutation_dir/bin/ai-bypass.ps1"
  check 'a spaced PowerShell CLI path cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass.ps1"
  printf '#!/usr/bin/env bash\ngh futureverb list\n' > "$mutation_dir/bin/ai-bypass"
  check 'a future GitHub CLI verb cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf 'gh api repos/acme/example\n' > "$mutation_dir/bin/promote-windows-runner-to-service.ps1"
  check 'retired runner exception cannot admit direct gh again' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/promote-windows-runner-to-service.ps1"
  printf '& gh.exe api repos/acme/example\n' > "$mutation_dir/bin/ai-powershell.ps1"
  check 'Windows executable spelling cannot bypass admission' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-powershell.ps1"
  printf '#!/usr/bin/env node\nrequire("child_process").execFileSync("gh", ["api", "rate_limit"])\n' > "$mutation_dir/bin/ai-bypass"
  check 'a new SDK/Node CLI bypass is rejected' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
  printf '#!/usr/bin/env bash\ncurl https://api.github.com/repos/acme/example\n' > "$mutation_dir/bin/ai-bypass"
  check 'a new direct HTTP bypass is rejected' \
    "! python3 '$ROOT/tools/ci/check-managed-github-transport.py' '$mutation_dir' >/dev/null 2>&1"
  rm -f "$mutation_dir/bin/ai-bypass"
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
  sed "/needs\['reviewer-safety-start-deadline'\].outputs.fallback_codex == 'true'/d" "$workflow" >"$mutation_dir/reviewer-gap.yml"
  assert_rejected reviewer-gap
  sed "/needs\['reviewer-safety-start-deadline'\].outputs.fallback_grok == 'true'/d" "$workflow" >"$mutation_dir/reviewer-gap-grok.yml"
  assert_rejected reviewer-gap-grok
  sed "/needs\['reviewer-safety-start-deadline'\].result != 'success'/d" "$workflow" >"$mutation_dir/watchdog-error-gap.yml"
  assert_rejected watchdog-error-gap
  sed '/\$process\.WaitForExit(55 \* 60 \* 1000)/d' "$workflow" >"$mutation_dir/unbounded-reviewer-execution.yml"
  assert_rejected unbounded-reviewer-execution
  sed '/continue-on-error: true/d' "$workflow" >"$mutation_dir/fatal-preferred-reviewer.yml"
  assert_rejected fatal-preferred-reviewer
  sed '/proof_result=failure/d' "$workflow" >"$mutation_dir/hidden-preferred-failure.yml"
  assert_rejected hidden-preferred-failure
  sed '/proof_result=cleanup_failure/d' "$workflow" >"$mutation_dir/unfenced-timeout.yml"
  assert_rejected unfenced-timeout
  sed "/runner.status === 'online' && !runner.busy/d" "$workflow" >"$mutation_dir/busy-runner-selected.yml"
  assert_rejected busy-runner-selected
  sed "/needs.reviewer-runner-availability.outputs.preferred_available == 'true'/d" "$workflow" >"$mutation_dir/availability-bypass.yml"
  assert_rejected availability-bypass
  sed "/^  windows-reviewer-fallback-codex:/,/^  windows-reviewer-safety:/ s/always() && !cancelled()/always() \&\& !cancelled() \&\& github.event.pull_request.head.repo.full_name == github.repository/" "$workflow" >"$mutation_dir/fork-fallback-blocked.yml"
  assert_rejected fork-fallback-blocked
  sed '/Dir::Etc::sourceparts=-/d' "$workflow" >"$mutation_dir/third-party-apt-feed.yml"
  assert_rejected third-party-apt-feed
  # P3 load-bearing gates: removing the known-terminal-failure stop, or
  # reintroducing the green-skip arm, must fail policy just like the older
  # mutations. A deliberately invalid candidate is the same shape as these.
  sed "s/validation_result != 'failure'/validation_result != 'never'/" "$workflow" >"$mutation_dir/validation-stop-removed.yml"
  assert_rejected validation-stop-removed
  sed "s/RUN_LONG\" = 'false'/RUN_LONG\" != 'true'/" "$workflow" >"$mutation_dir/green-skip-reintroduced.yml"
  assert_rejected green-skip-reintroduced
  sed "s/RUN_REVIEWER\" = 'false'/RUN_REVIEWER\" != 'true'/" "$workflow" >"$mutation_dir/reviewer-green-skip.yml"
  assert_rejected reviewer-green-skip
fi

[ "$failures" -eq 0 ] || { printf 'FAIL: %s workflow policy assertions failed\n' "$failures" >&2; exit 1; }
printf 'PASS: fast routing and both Windows lanes are preserved; manual proof cannot be cancelled automatically, exact-SHA successes deduplicate, provenance is required, and PR supersession remains enabled\n'
