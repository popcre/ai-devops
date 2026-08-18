# Shared-db finish-first implementation-plan consensus — 2026-08-18

Plan reviewed: [`../plan_shared-db-finish-first-delivery.md`](../plan_shared-db-finish-first-delivery.md)

Primary evidence: [`../shared-db_orchestrator_failure_analysis.md`](../shared-db_orchestrator_failure_analysis.md)

## Review contract

Grok 4.6 and the Kimi wrapper requesting Kimi K3 received the same complete 583-line plan, postmortem, reviewer analysis, orchestrator skill, operating manual, incident ledger, and handoff in a stable self-contained review clone. Each reviewer had to classify all ten plan groups and every locked decision as `AGREE`, `REVISE`, or `OBJECT`. Agreement on only the central direction was explicitly insufficient.

Both reviewers used persistent named sessions and re-read the revised plan after every amendment. Debate stopped after two rebuttal turns, within the maximum of three.

## Sessions and objective usage

- Grok session: `shared-db-finish-first-plan-consensus`, requested model Grok 4.6.
  - Initial exact-plan review: 789,517 tokens, 10 turns, $0.11300682.
  - Rebuttal 1: 412,418 tokens, 3 turns, $0.05042336.
  - Rebuttal 2: 298,949 tokens, 2 turns, $0.02868478.
  - Total reported by the wrapper: 1,500,884 tokens, 15 turns, $0.19211496.
- Kimi session: `shared-db-finish-first-plan-consensus`, exact session ID `session_1303442c-35b4-41b1-b65a-ea0e9895d9c1`, wrapper-requested model `kimi-code/k3`.
  - Kimi headless output provides no returned-model, token, cache, or cost figures. None are claimed.

## Initial Grok objections and resolutions

1. Waiting-owner work was not explicitly counted. Resolved in §8 and §9.2: a yielded waiting-owner claim occupies the one non-shared slot and preserves objects/version.
2. Shared-stage locks did not explicitly require the shared role. Resolved: preview, preview-recovery, merge, and production refuse `role: authoring`.
3. Merge-time claim release remained possible. Resolved: release requires `live-verified` or exact owner-confirmed safe abandonment; merge alone is refused.
4. `status` versus delivery state and legacy issue adoption were underspecified. Resolved: fields remain independent; old structural issues become `LEGACY_SCOPE_MISSING_DELIVERY_FIELDS` and remain visible to health/candidate reads.
5. The standing marker, one-session handover, and always-delegate memory could rebuild the coordinator under a new name. Resolved: delete the marker rule, rewrite both handover paths, and supersede always-delegate.
6. Generic catalog preflight risked becoming another platform project. Resolved: ledger identity composes the existing reader; catalog reads are bounded to exact objects named on the outcome card.
7. Sample Tracking could be excluded based on a closed handover. Resolved: live preview/types/production proof determines exclusion; handover closure does not.
8. Field, command, threshold, and scheduler choices were left open. Resolved in §8: exact names/defaults are locked, and no scheduler is part of the first implementation.

## Initial Kimi objections and resolutions

1. The post-owner-answer state was undefined. Resolved: the issue becomes `status: ready` plus `delivery_state: queued`, keeps its counted non-shared claim, cannot preempt, and cannot promote until the active shared claim/stages release.
2. The handover replacement was too vague. Resolved: path A stops mutation and writes/updates one outcome record; path B closes only currently claimed outcomes and never seeds a refill queue.
3. Historical allowlisting by line number was brittle. Resolved: use whole historical files or stable fenced markers.
4. The safety-control citation pointed at diagnosis. Resolved: §8 cites §§1 and 11 plus the incident ledger.
5. The consensus plan omitted the Kimi-wrapper failure mode. Resolved: §13 requires a stable self-contained Kimi workspace and treats directory, concurrent-tree, timeout, and terminal-record failures as transport.

## Rebuttal 1

Kimi returned: `NO MATERIAL OBJECTION TO THE ENTIRE PLAN`.

Grok confirmed all initial objections resolved except one contradictory §9.1 verification sentence. The behavior allowed an empty `live_verification` before production proof and kept legacy issues parseable, while the verification sentence still said to reject a missing verification value.

Resolution: §9.1 now requires the three fields on claim/promotion/update paths, permits an empty verification value until the live transition, keeps legacy issues visible, and requires non-empty evidence only for `live-verified`.

## Rebuttal 2 and final verdicts

Grok final verdict:

> NO MATERIAL OBJECTION TO THE ENTIRE PLAN

Kimi final verdict:

> NO MATERIAL OBJECTION TO THE ENTIRE PLAN

Both reviewers stated that implementation and exact-head code tests remain future evidence and do not block plan consensus.

## Consensus result

Every plan group, locked decision, state transition, safety boundary, test family, activation step, recovery step, and rollback rule has no remaining material objection from Codex, Grok, or Kimi.

A fourth opinion is not needed. The plan requires GLM only if Grok and Kimi become materially split in a future revision or share one unverified assumption. Adding another model now would add breadth without resolving a live objection.
