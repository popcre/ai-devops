# Specialized task router

Use this only after `AGENTS.md` routes the current task here. It holds
low-frequency task pointers and changing operational detail so every session
does not pay to load them. Read only the matching row and its named sources.

| Current task | Read first | Important boundary |
|---|---|---|
| Implement the 2026-08-21 full repository audit | [`../plan_full-strategy-remediation.md`](../plan_full-strategy-remediation.md) STATUS, [`../bugs.md`](../bugs.md) current audit | Incident-first; preserve capabilities; all 30 findings must reach production evidence |
| False completion or closeout honesty | [`../plan_completion-honesty-enforcement.md`](../plan_completion-honesty-enforcement.md) STATUS, Response Style in both `templates/system/*global*.md` | Globals, `context-audit.py`, and `bin/ai-completion-check-hook` move together; require a `tools/completion-eval/` run |
| Standing Claude/Codex behavior | Both globals under [`../templates/system/`](../templates/system/), [`../templates/system/machine-atlas.md`](../templates/system/machine-atlas.md), affected shared skill | Keep clients aligned; install with `bin/ai-adopt-globals` |
| `bin/` tool or workflow | [`architecture.md`](architecture.md), [`development.md`](development.md), tool verification header and tests | Do not simplify a measured guardrail without reading its reason |
| Install, update, uninstall, or restore | [`deployment.md`](deployment.md), [`restore-from-zero.md`](restore-from-zero.md), affected lifecycle scripts | Preserve machine-local configuration |
| Windows machine setup | [`windows-winget-configuration.md`](windows-winget-configuration.md), `bin/bootstrap-windows-dev.ps1`, `bin/setup-machine.ps1`, `bin/verify-windows-dev.ps1` | Transitional scripts are not the primary path |
| Secrets, MCP tokens, or 1Password | [`onboarding-secrets.md`](onboarding-secrets.md), [`config-inventory.md`](config-inventory.md), affected setup script | Serialize 1Password access; never expose secret values |
| Model commands or settings | [`configuration.md`](configuration.md), [`model-setup.md`](model-setup.md) | Per-machine commands stay outside source code |
| Prompt templates | `templates/prompts/`, [`architecture.md`](architecture.md) | Change only the affected workflow stage |
| Skill creation, placement, or triggers | [`skills-map.md`](skills-map.md), [`skills-usage-guide.md`](skills-usage-guide.md), [`skill-trigger-eval.md`](skill-trigger-eval.md) | Shared is the default; never keep duplicate client copies |
| Install or refresh skills/globals | [`skills-usage-guide.md`](skills-usage-guide.md), [`codex-skills-usage-guide.md`](codex-skills-usage-guide.md), `bin/ai-install-skills`, `bin/ai-adopt-globals` | Preserve and verify machine sections |
| Delegated reviewer work | [`../bugs.md`](../bugs.md), linked provider plan, [`reviewer-issues.md`](reviewer-issues.md), wrapper header/skill/tests | Preserve read-only boundaries, exact-head evidence, and provider restrictions |
| Reviewer diagnostics or quota preflight | [`../plan_reviewer-diagnostics-quota-preflight.md`](../plan_reviewer-diagnostics-quota-preflight.md) STATUS, issue #312 | Qualify non-generating interfaces first; unknown quota never disables a working reviewer |
| Reviewer-log repair rounds | [`../plan_reviewer-log-repair-checkpoints.md`](../plan_reviewer-log-repair-checkpoints.md) STATUS, issue #308, [`reviewer-issues.md`](reviewer-issues.md), `ai-reviewer-issue maintenance show` | Resume the frozen round and account for every candidate |
| Reviewer-assisted stuck-session diagnosis | [`../plan_reviewer-assisted-problem-solving.md`](../plan_reviewer-assisted-problem-solving.md) STATUS, issue #198 | Advisory, one-reviewer bounded, private, and separate from formal approval |
| Grok integration-review shell or internet access | [`../plan_grok_integration-review-access.md`](../plan_grok_integration-review-access.md) STATUS, issue #249, wrapper/profile/tests | Keep approval review unchanged; brokered operations only |
| Grok Build upgrade or wrapper integration | [`../plan_grok-build-1.0.13-wrapper-integration.md`](../plan_grok-build-1.0.13-wrapper-integration.md) STATUS, issue #251, [`grok-build-1.0.13-release-disposition.md`](grok-build-1.0.13-release-disposition.md), version policy | Preserve reviewer boundaries and qualify the exact pinned version |
| Third-party provider CLI version | `config/provider-cli-versions.json`, `bin/ai-provider-version`, installers and tests | Change the pin and requalify; never loosen wrapper refusal |
| Reviewer packet or sandbox | `bin/ai-review-packet` or `bin/ai-review-sandbox` header and tests | Full repository read access; linked worktrees need self-contained snapshots |
| Reviewer caching or token/cost reporting | [`../plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md) STATUS | Never trade evidence integrity for speed or invent provider token counts |
| End-to-end reviewer reliability, caching, or session qualification | [`../plan_reviewer-reliability-and-efficiency.md`](../plan_reviewer-reliability-and-efficiency.md) STATUS | Reuse completed diagnostics and active provider repairs; preserve private evidence and require measured installed acceptance |
| Dead reviewer worker or invisible slot wait | [`../plan_reviewer_lease_liveness.md`](../plan_reviewer_lease_liveness.md) STATUS, issue #283, `u2giants/shared-db#2345` | Code lives in shared-db; retain terminal failure codes and never release on age alone |
| `ai-muse` stale-turn rejection | [`../fix_muse_wrapper_reject.md`](../fix_muse_wrapper_reject.md) STATUS | The guard is correct; never narrow `tree_state` to stop it firing |
| Reviewer investigation mode | [`../plan_reviewer-investigation-mode-option-b.md`](../plan_reviewer-investigation-mode-option-b.md) STATUS, issue #253 and provider child | Investigation is advisory; formal review stays read-only |
| Concurrent-session work claims | [`../plan_ai-devops-work-claims.md`](../plan_ai-devops-work-claims.md) STATUS, issue #131 | Wait for throughput gates; V1 remains task-only and advisory |
| Managed ast-grep | [`../plan_ast-grep-multi-machine-management.md`](../plan_ast-grep-multi-machine-management.md) STATUS, issue #187 | This repo owns Windows/version/guidance; `u2giants/ansible` owns Ubuntu installation |
| Bloated routing, task-class drift, or an unnecessary expensive gate | [`../plan_cross_repo_routing_and_gate_enforcement.md`](../plan_cross_repo_routing_and_gate_enforcement.md) STATUS, issue #335 | Central enforcement lives here; consumer repos keep thin declarations and stronger local gates win |
| Throughput, slow CI, flaky checks, or merge-queue ejections | [`../plan_repo-throughput-restructure.md`](../plan_repo-throughput-restructure.md) STATUS, issue #159 | Execute its child issues; required-check cutover #166 is last |
| Reviewer-suite stall or progress wait | [`../plan_progress-wait-misuse-guard.md`](../plan_progress-wait-misuse-guard.md) STATUS | A progress signal must change during healthy quiet phases; cancellation is not a test result |
| Task classification or a gate that refused an action | `bin/ai-task-gates`, `config/task-gates.json`, `config/task-gates.schema.json`, `tests/test-ai-task-gates.sh` | Strongest matching class always wins; a protected class is never acknowledged away, and anything unclassifiable is refused |
| Pull-request CI or merge monitoring | `bin/ai-pr-wait` and its verification header/tests | An ejected PR remains OPEN; the waiter must terminate on every terminal outcome |
| Windows CI, runner, or local reviewer series | [`self-hosted-windows-runner.md`](self-hosted-windows-runner.md), [`independent-windows-runner-setup.md`](independent-windows-runner-setup.md), [`critical-incidents.md`](critical-incidents.md) 2026-09-02 | Resolve current jobs, hosts, labels, and services live; never overlap local and CI suites on one host |
| Diagnose a known tool failure | [`critical-incidents.md`](critical-incidents.md), [`design-decisions.md`](design-decisions.md), affected tool/tests | Odd behavior may be an intentional guardrail |
| Transcript backup or analysis | Matching transcript skill and routed docs | Do not open raw archives unless the task explicitly requires them |

## Operational facts that change

- Runner labels, host membership, active jobs, pull-request heads, check results,
  issue status, and provider versions must be resolved live. Historical values
  explain a guardrail but never prove current state.
- The Windows workflow has separate GitHub-hosted and Blacksmith offline lanes,
  plus a qualified self-hosted reviewer-safety lane. Each provider is additional
  capacity, not a replacement for another. Qualification uses its documented
  candidate label; public fork approval remains `all_external_contributors`.
- A merge-queue ejection can leave a pull request OPEN. Use `bin/ai-pr-wait`
  instead of watching PR state, and never rerun a green result for an identical
  commit.
