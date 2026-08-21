---
issue: 56
status: OPEN
owner: codex/grok-issue-56-source
---

# HANDOFF — Grok issue #56 provider repair (2026-08-21 12:38Z, edge-dev/codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None. The remaining paid live check is already required and bounded by the approved implementation plan.

## 1. What this application is

`u2giants/ai-devops` is a public backup-and-restore toolkit for Albert's AI coding workflow. `bin/ai-grok-review` runs fixed-model, read-only Grok reviews and records their results locally; it is not a hosted service.

## 2. What we set out to do this session, and why

Resume the interrupted provider-specific repair for GitHub issue #56. Equivalent clones could previously start multiple paid reviews, active work was not visible across clones, interruption language could imply more certainty than existed, and long turns gave no useful progress.

## 3. Current state — what is true right now

The isolated checkout `C:\repos\ai-devops-grok-fix-20260821-081300` contains a complete local source repair. `bin/ai-grok-review` now separates checkout-bound session identity from normalized upstream paid-work identity; HTTPS, SSH, case, `.git`, and local clone paths converge. Cross-clone `list` shows active work. A local interruption preserves an uncertainty marker that blocks another paid call. Long calls emit factual elapsed-time heartbeats. `delete` refuses an active session. The work is committed locally but is not pushed by this sub-agent.

Offline evidence is in `tests/verification/grok-review-issue-56/2026-08-21-offline.md`. Shared incident-report correlation is deliberately outside this commit and remains owned by the shared evidence plan.

## 4. Everything we tried that did NOT work

The inherited first draft calculated the old checkout-based lock in an existing test, so three checks failed even though production code had moved to upstream identity. The fixture was corrected to the normalized identifier and every temporary repository that is expected to reach review-file safety now has a harmless network origin.

The first interruption fixture killed an outer subshell rather than the wrapper itself, so it did not exercise the wrapper's signal handler. Replacing the nested shell with `exec` made the test target the real wrapper process.

The inherited signal handler released the paid-work lock after warning that provider cancellation was unknown. That would permit another charge immediately. It now preserves a `remote-uncertain` marker and the acquisition path refuses to reclaim it automatically.

## 5. Root causes and key findings

Session identity belongs to one checkout and caller, but billing protection belongs to the normalized network repository. Combining them allowed clones to bypass serialization. Local process death cannot prove the provider stopped, so uncertainty must fail closed. Heartbeats can report only observable local facts: elapsed time, local process state, and output byte count.

## 6. Exact next steps

1. Merge this scoped commit into the main repair task without overwriting shared evidence work. Verify with the six commands recorded in the offline evidence file.
2. Complete shared incident correlation under `plan_reviewer_shared_evidence_integrity.md`. Verify unrelated recent records are never substituted.
3. Install the merged wrapper and prove installed/source hashes match. Verify identical hashes.
4. Run the one bounded live qualification specified by the issue #56 plan. Verify one provider turn, cross-clone refusal and visibility, heartbeat, terminal result, then normal lock release.
5. Obtain an independent exact-head review, push `main`, close issue #56 with evidence, and delete this handoff only when all obligations are complete.

## 7. Constraints and gotchas in force

Preserve the STEP-0 controls: fixed model and permissions, no arbitrary flags, no worktree mode, maximum turns, private snapshots, and terminal `stopReason` as the only completion proof. Never weaken an uncertain lock automatically. Never force-push or stage unrelated files.

## 8. Access and environment

Worktree: `C:\repos\ai-devops-grok-fix-20260821-081300`; target repository/branch: `u2giants/ai-devops` `main`; shell: Windows Git Bash. Offline tests require no secret. Grok login remains in its protected local CLI state and must not be opened or printed.

## 9. Open questions and risks

The installed Grok version's remote-abort behavior remains unproven; warning plus retained blocking state is therefore the safe implementation. Live qualification and independent review remain. A retained uncertain lock needs deliberate human reconciliation after checking provider state; automatic cleanup would reopen the duplicate-charge risk.

## Mandatory self-audit

Yes to all six standard questions and all four synthesis questions. Sections 1–3 define the application, goal, exact source state, and proof; Section 4 records failed attempts; Sections 5–9 preserve root causes, exact gated next steps, constraints, access, and risks. The section-0 sweep found no new Albert decision: all remaining actions were already approved by the implementation plan.
