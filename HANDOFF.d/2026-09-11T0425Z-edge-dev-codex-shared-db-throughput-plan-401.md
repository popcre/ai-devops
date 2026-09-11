---
issue: 401
status: OPEN
owner: codex/shared-db-throughput-plan-401
---

# HANDOFF — complete shared-db throughput repair plan

Implementation plan: [`../plan_shared-db-complete-throughput-repair.md`](../plan_shared-db-complete-throughput-repair.md)

## 0. Decisions only the owner can make

### Blocking now

None. Step 0 and all reversible code/test work can begin without another decision.

### Blocking later irreversible actions

1. Transferring public `u2giants/shared-db` to `popcre/shared-db` and changing its live ruleset requires Albert to name that exact action when Step 8 is ready. Recommendation: authorize it after Steps 0–7 prove the new operating model and the existing #2530 recovery pack is refreshed.
2. Activating #2716 changes global and shared-db policy so fully governed migrations promote automatically without Albert naming technical versions. Recommendation: authorize that policy once when its independent session presents the exact global/workflow diff; missing evidence must stop for an engineer.

### Already settled — do not re-ask

- Preserve every database safety control.
- Keep up to eight non-conflicting author lanes; do not restore the superseded 1+1 proposal.
- Urgency changes scheduling, never evidence requirements.
- Merge and preview proof are not live application completion.
- Repository maintenance and ordinary application data work remain outside the structural orchestrator.
- Sending sessions and the orchestrator must independently prove structure/schema scope; neither trusts the other's label or judgment.

The implementing session must present the complete later decision in one plain message only when its prerequisite step is ready.

## 1. What this application is

`popcre/ai-devops` owns the AI operating rules, reviewer tools, and cross-repository throughput system. `u2giants/shared-db` owns the shared database structure and its guarded delivery machinery for POP applications.

## 2. What this session set out to do

Albert requested an execution-ready plan fixing every cause in the seven-transcript shared-db throughput review and asked whether shared-db issues #2705/#2709 already covered it. This session created the comprehensive successor plan and tracking issue #401.

## 3. Current state

- Plan is complete at `plan_shared-db-complete-throughput-repair.md` and all implementation rows are open.
- #2705 covers unusable reviewer allocation only; PR #2717 was open and failing two checks at the planning snapshot.
- #2709 covers wrong review packet base only; ai-devops PR #402 was open at the planning snapshot.
- #2715 belongs as an independently executed repo-maintenance prerequisite: it keeps prose-only PRs out of the migration guarded-merge path.
- #2716 belongs as an independently executed cross-repository prerequisite: it removes technical version-naming asks only after all existing machine gates, dry-run, and serial lock pass.
- Existing Phase 2 concurrency, evidence, events, and guard-truth plans are complete and must be reused.
- The shared-db organization/merge-queue plan exists under #2530 and remains entirely unexecuted.
- No database, production, repository-transfer, settings, or installed-rule mutation occurred.

## 4. What did not work

- Treating GitHub Merge Queue alone as the fix: it does not address dispatch, reviewers, runners, handoffs, production, or live verification.
- Reusing the older finish-first plan unchanged: its 1+1 capacity proposal predates and conflicts with the later approved eight-author model.
- Treating #2705/#2709 as comprehensive: both are narrow reviewer correctness defects.
- Leaving routing to session judgment: both sender and orchestrator need enforced, evidence-based structural admission.

## 5. Root causes and findings

The system already has safe parallel authors and durable evidence, but they are not connected into an urgent, outcome-owned, event-driven delivery lifecycle. Work can stay busy while an application blocker remains undispatched. Late preflight failures, reviewer/runner non-starts, manual handoffs, polling, and repeated authority questions add most delay.

## 6. Exact next steps

1. Read the plan STATUS and §§1, 5–9. Re-resolve every live issue/PR/SHA in Step 0. Gate: commit the redacted baseline.
2. Execute Steps 1–3 in order. Do not touch #2705/#2709 from this programme; consume their sessions' merged proof. Run #2715/#2716 as their own repo-maintenance/policy sessions, never inside the orchestrator. Gate: two-sided admission, urgent, and outcome lifecycle scenarios pass.
3. Start a fresh session; re-read remaining phases; execute Steps 4–7. Gate: event/snapshot, preflight, migration-train, reviewer, and runner tests pass.
4. Obtain the owner action for Step 8 only when ready; execute #2530 exactly. Gate: native queue canary and migration proof pass.
5. Execute Steps 9–10, update STATUS continuously, and close #401 only after five live outcomes pass. Gate: merged SHAs, installed hashes, and live evidence are recorded.

## 7. Constraints and gotchas

Use isolated current-upstream worktrees. Never weaken database gates, delete durable claims, edit applied migrations, expose private transcripts, or infer transfer/policy authority. Preserve concurrent work and stage only owned files. A `db-work` label or handover claim never proves orchestrator scope.

## 8. Access and environment

Windows host `edge-dev`; authenticated GitHub CLI; repositories at `C:\repos\ai-devops` and `C:\repos\shared-db`. Secrets remain in 1Password vault `vibe_coding`; no values belong in plans or logs. Database identity must be proved immediately before any later write.

## 9. Open questions and risks

No design question blocks implementation. Drift in #2705/#2709/#2715/#2716/#159/#2530 is expected, so consume newer merged evidence. Main risks are scope misclassification, urgency abuse, false reviewer release, duplicate runner execution, partial migration trains, and instruction drift; §13 defines each rollback.

## Handoff self-audit

1. A new developer can continue without chat context: §§1–8 identify purpose, repositories, exact plan, state, next steps, constraints, and access.
2. They can continue as effectively as this session: §§3–5 preserve live issue/PR state, completed foundations, narrow issue coverage, and rejected paths.
3. Every execution-critical detail is carried by the linked 13-section plan; §6 supplies the ordered start.
4. The owner-decision sweep passed: the repository transfer/settings mutation and #2716 policy activation appear in §0 and the plan; no other owner decision is hidden in §§1–9.
