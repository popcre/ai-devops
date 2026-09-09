# Implementation-plan index

This is the current ownership index for every root `plan_*.md` file. Use the
**Active** table to choose work. The other files remain only as decision and
evidence records; their presence is not permission to restart them.

The inventory was reconciled against GitHub on 2026-09-08. When an issue, pull
request, or plan STATUS conflicts with this index, resolve the live state and
update both the plan and this index before acting. Do not delete a completed
record merely to reduce the file count.

## Active plans

| Plan | Live owner | Current restart point |
|---|---|---|
| [`plan_ai-devops-work-claims.md`](../plan_ai-devops-work-claims.md) | [#131](https://github.com/popcre/ai-devops/issues/131) | Step 2; the throughput prerequisites are complete |
| [`plan_ast-grep-multi-machine-management.md`](../plan_ast-grep-multi-machine-management.md) | [#187](https://github.com/popcre/ai-devops/issues/187) | In flight in PR #192; do not duplicate it |
| [`plan_cross_repo_routing_and_gate_enforcement.md`](../plan_cross_repo_routing_and_gate_enforcement.md) | [#335](https://github.com/popcre/ai-devops/issues/335) | Phase 2; implement and qualify the central task-gate engine |
| [`plan_full-strategy-remediation.md`](../plan_full-strategy-remediation.md) | [#62](https://github.com/popcre/ai-devops/issues/62) | First non-complete STATUS row; externally blocked work stays explicit |
| [`plan_grok_integration-review-access.md`](../plan_grok_integration-review-access.md) | [#249](https://github.com/popcre/ai-devops/issues/249) | Step 0; no implementation has landed |
| [`plan_pop-business-rules-skill.md`](../plan_pop-business-rules-skill.md) | [#35](https://github.com/popcre/ai-devops/issues/35) | Live trigger evidence remains before closure |
| [`plan_repo-throughput-restructure.md`](../plan_repo-throughput-restructure.md) | [#159](https://github.com/popcre/ai-devops/issues/159) | Continue the first eligible open child; #166 remains last |
| [`plan_reviewer-assisted-problem-solving.md`](../plan_reviewer-assisted-problem-solving.md) | [#198](https://github.com/popcre/ai-devops/issues/198) | Step 0; no implementation has started |
| [`plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md) | [#333](https://github.com/popcre/ai-devops/issues/333) | Step 2.1; only provider-returned cache reporting remains |
| [`plan_reviewer-investigation-mode-option-b.md`](../plan_reviewer-investigation-mode-option-b.md) | [#253](https://github.com/popcre/ai-devops/issues/253) | Step 0, then provider children #254-#257 |

## Completed decision records

These plans have no executable row. Their STATUS or named successor carries the
completion evidence. Open a file only to understand a guardrail or rejected
approach.

| Plans | Completion owner or durable evidence |
|---|---|
| `plan_ai-glm-permission-deadlock.md`, `plan_ai-glm-permission-failures.md`, `plan_ai-grok-review.md` | Complete STATUS tables and repository history |
| `plan_codex_reviewer_trust_repair.md`, `plan_gemini_reviewer_safety_repair.md`, `plan_kimi_reviewer_completion_repair.md`, `plan_muse_reviewer_availability_repair.md`, `plan_qwen_reviewer_evidence_repair.md`, `plan_reviewer_shared_evidence_integrity.md` | Complete STATUS tables and completed reviewer repair evidence |
| `plan_completion-honesty-enforcement.md` | Core rollout complete; residual issues #103, #108, and #119 own their narrower follow-ups |
| `plan_context-engineering-consolidation.md` | Complete STATUS and `docs/context-engineering.md` |
| `plan_glm-implementation-job-tracking.md`, `plan_glm-incomplete-implementation-recovery.md`, `plan_glm-service-reliability.md` | Complete STATUS tables and current GLM operating documentation |
| `plan_grok-build-1.0.13-wrapper-integration.md` | Closed issue #251 and `docs/grok-build-1.0.13-release-disposition.md` |
| `plan_kimi-debate-context-continuity.md`, `plan_kimi-incomplete-implementation-recovery.md`, `plan_kimi-persistent-implementation-sessions.md` | Complete STATUS tables and current Kimi wrapper contract |
| `plan_phase3-config-consolidation.md`, `plan_sync-machine-wrapper-reconciliation.md` | Complete STATUS tables and current restore/configuration documentation |
| `plan_progress-wait-misuse-guard.md` | Closed issue #89 and current wait-policy tests |
| `plan_reintegrate-gemini-flash-3-8-qwen-3-8-max.md` | Closed issue #261 and completed STATUS |
| `plan_reviewer_lease_liveness.md` | Closed issue #283; implementation lives in `u2giants/shared-db` |
| `plan_reviewer-diagnostics-quota-preflight.md` | Closed issue #312 and merged evidence |
| `plan_reviewer-log-repair-checkpoints.md` | Closed issue #308; issue #322 is a separate Qwen limitation |
| `plan_reviewer-system-repair.md` | Closed issue #34 and complete STATUS |

## Superseded or reference-only records

These files are deliberately non-executable. The named successor owns any live
work and preserves the earlier decisions; Git history preserves the original
text.

| Plan | Current owner or successor |
|---|---|
| `plan_ai-gemini-wrapper.md` | `plan_gemini_reviewer_safety_repair.md`; issue #38 is closed |
| `plan_deepseek_reviewer_safety_repair.md`, `plan_glm_reviewer_startup_repair.md`, `plan_grok_reviewer_runtime_repair.md` | Remaining cross-machine and landing gates are consolidated under `plan_full-strategy-remediation.md` and open issue #62 |
| `plan_delegate-wrapper-hardening.md` | Current provider wrappers and their provider-specific safety plans |
| `plan_grok-debate-continuity.md` | Closed issue #151 and `plan_context-engineering-consolidation.md` |
| `plan_grok-review-concurrency-cancellation-observability.md` | `plan_grok_reviewer_runtime_repair.md`; issues #56 and #61 are closed |
| `plan_kimi-review-failure-recovery.md`, `plan_kimi-windows-execution-reliability.md` | `plan_kimi_reviewer_completion_repair.md`; issues #46 and #31 are closed |
| `plan_muse-opencode-harness.md` | `plan_muse_reviewer_availability_repair.md`; issue #40 is closed |
| `plan_must_address.md` | Evidence appendix for `plan_ai-devops-work-claims.md`; not an implementation plan |
| `plan_repo-housekeeping-visibility.md` | Issue #168, this index, and the `cleanup-worktree` procedure |
| `plan_shared-db-finish-first-delivery.md` | Non-operative proposal superseded by current shared-db orchestration rules; a new owner ruling is required before reviving its 1+1 model |

## Maintenance rule

A new root plan needs an open owner issue, a current STATUS table, a router or
handoff path, and a retirement path. Add it to **Active plans** in the same
commit. When work closes, move it to the correct record table with completion
or successor evidence. Deletion is optional and requires proof that no live
issue or handoff relies on the path and that every unique decision remains in a
successor or Git history.
