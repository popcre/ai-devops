---
issue: 2531
status: OPEN
owner: codex/01a1e599
---
# DeepSeek Harness through OpenRouter

## 0. Business decisions

None. No owner decision is pending. Albert requires extensive testing before either review path switches.

## 1. Application

[AI DevOps Toolkit](https://github.com/popcre/ai-devops) supplies reviewers for coding sessions and GitHub Actions. It runs on Ubuntu and Windows.

## 2. Purpose

Preserve automatic advisory verdicts and on-demand follow-ups with one DeepSeek Harness engine over OpenRouter. Both paths must remain read-only. The planning session was scoped to documentation and tracking.

## 3. Current state

The [implementation plan](../plan_deepseek-harness-openrouter.md) starts at step 1. The planning baseline is [bc7a42c](https://github.com/popcre/ai-devops/commit/bc7a42c027fb6eadd0d7fa6c42b2213a0ca438c1). Both existing paths are still configured as before. No candidate code, live trials, installs or cutover were performed. Consult the [tracking issue](https://github.com/popcre/ai-devops/issues/2531) and current main for publication and execution status.

## 4. Dead ends

No runtime attempts were made. A URL swap in the on-demand wrapper would conflict with its endpoint pin. Plan §7 records the other approaches considered.

## 5. Findings

[Automatic review](https://github.com/popcre/ai-devops/blob/bc7a42c027fb6eadd0d7fa6c42b2213a0ca438c1/bin/ai-review-simple#L49) uses OpenCode with DeepSeek direct. [Second opinions](https://github.com/popcre/ai-devops/blob/bc7a42c027fb6eadd0d7fa6c42b2213a0ca438c1/bin/ai-deepseek-agent#L74) use the direct API and persist discussion state. DeepSeek Harness documents unattended execution, session continuation and custom providers. The plan links the upstream sources.

## 6. Next actions

1. Claim execution on #2531 and start from current upstream. The first gate is a pinned runner and live OpenRouter fixture on both OSes.
2. Implement both candidate entry points from plan §9. The second gate is passing offline checks with previous defaults in effect.
3. Run the complete qualification matrix. A published exact-head verdict, two restarts per tested conversation and read-only receipts must be available before changing defaults.
4. Execute cutover and verify live receipts or restore the prior routing. Record the outcome on #2531.

## 7. Constraints

Use an isolated worktree, protected merge queue, protected keys, and disposable test fixtures. Existing discussions keep their original engine. Advisory review and writable coding delegation retain their existing behavior. See plan §§8–11.

## 8. Access

Use repo GitHub access and approved Ubuntu/Windows installation routes. Plan §12 names the proposed item in the `vibe_coding` vault. No credential was created or used during planning. Begin with public fixtures.

## 9. Risks

On 2026-11-16 the cutover was conditioned on live evidence. Provider compatibility, scope isolation and durable resume remain unresolved until the matrix passes. The existing paths supply rollback. The same issue carries the live proof checkbox.

## Self-audit

1. §§1–3 and 6 supply context, current state and the first executable gate.
2. §§4–5 record the endpoint pin and distinction between lifecycles. The linked plan supplies source references.
3. §§6–9 and the plan specify the next actions, access, risk tests, rollback and completion evidence.
4. The sweep of §§1–9 found no outstanding business decisions. §0 records that result. Fresh-reader review was skipped under the closed pilot policy.
