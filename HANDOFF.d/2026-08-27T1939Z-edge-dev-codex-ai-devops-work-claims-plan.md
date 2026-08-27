---
issue: 131
status: OPEN
owner: codex/ai-devops-work-claims-plan-131
---

# Handoff — ai-devops collision-resistant work claims plan

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert before implementation. Already settled on 2026-08-27: use lightweight GitHub-backed work claims, not a full orchestrator or committed claims file; keep unrelated work concurrent; treat reviewer-code consolidation as separate work. Do not re-ask these questions.

## 1. What this application is

`popcre/ai-devops` is POP Creations’ public toolkit for restoring and operating Albert’s multi-model AI workflow. It contains commands, setup, global Claude/Codex rules, skills, and offline tests. It has no hosted application or database. Work lands directly on `main`; local installation is deployment.

## 2. What we set out to do this session, and why

Albert asked for an implementation plan for the right way to prevent concurrent ai-devops sessions from colliding or duplicating work. The plan had to preserve useful parallel work and avoid importing shared-db’s full orchestrator overhead.

The complete build specification is [`../plan_ai-devops-work-claims.md`](../plan_ai-devops-work-claims.md). GitHub issue [#131](https://github.com/popcre/ai-devops/issues/131) is the completion contract.

## 3. Current state — what is true right now

Planning is complete; implementation has not started. The plan specifies a two-phase GitHub issue lease, deterministic lowest-issue-number winner, task/work-unit duplicate identity, protected-path overlap, expiry/renewal/release, mocked concurrency tests, aligned Claude/Codex routing, live qualification, independent exact-head review, installation, and origin/CI proof.

This checkout contains unrelated dirty reviewer-cache and taxonomy work. Preserve it and stage only issue #131 artifacts. The new plan and this handoff are not committed or pushed at the instant this file is written; the planning session owns landing them on `main`.

## 4. Everything we tried that did NOT work

- A full orchestrator was rejected because it would serialize intentional independent work.
- A committed claims file was rejected because worktrees/branches see stale copies and the file becomes a new collision point.
- A simple GitHub query-then-create claim was rejected because simultaneous sessions can both win the check.
- Local locks, one mutable registry issue, Git refs, broad malformed-record freezes, and a scheduled closer were considered and rejected with full reasoning in plan §7.

No implementation attempt was made, so there are no failed code changes to recover.

## 5. Root causes and key findings

The transcript review found that visible merge conflicts cluster around shared operating files, while duplicate diagnosis/implementation costs more and can occur with no Git conflict. Therefore the claim key must include the task/work-unit, not only files. GitHub must be the live authority across machines. The plan closes the simultaneous-acquisition race by forbidding edits until a settlement re-query selects the lowest server-assigned issue number.

Current repository anchors and evidence are recorded in plan §5–6, including `AGENTS.md:20-27,65,120`, `install.sh:201-206`, `tests/test-all.sh:6`, and existing local reviewer mutex examples.

## 6. Exact next steps

1. Read [`../plan_ai-devops-work-claims.md`](../plan_ai-devops-work-claims.md) completely, beginning with STATUS. You’ll know this is done when every locked decision, rejected approach, and Phase 1 gate is understood without using this chat.
2. Re-derive live `main`, issue #131, dirty-tree, and concurrent-session state. You’ll know it worked when the intended base and every unrelated dirty path are named before editing.
3. Execute plan Steps 9.1–9.4, updating STATUS with artifacts as each gate passes. You’ll know Phase 1 worked when deterministic mocked acquisition yields exactly one winner and ownership lifecycle tests pass.
4. At the marked context cut, use `fresh-session`, re-read downstream phases, then execute Steps 9.5–9.7. You’ll know Phase 2 worked when focused/full tests pass and aligned global instructions are previewed safely.
5. Execute Steps 9.8–9.10: live race qualification, frozen-tree review, full suite, commit/push/CI/install proof. You’ll know the workstream is complete only when issue #131 is closed, the exact commit is on `origin/main`, CI is green, live smoke succeeds, and this handoff is deleted.

## 7. Constraints and gotchas in force

Work directly on `main`; verify Albert’s Git identity before commit; never broad-stage or disturb unrelated dirty files. Use Git Bash explicitly on Windows. This public repository must contain no transcript excerpts, secrets, owner tokens, or private paths. GitHub/network failure must fail closed for write claims. Read-only work stays exempt. The claim tool cannot expand authority for destructive, production, or shared-db actions. Exact-head independent review is required for this concurrency-safety routing change.

## 8. Access and environment

Checkout: `C:\repos\ai-devops` on `edge-dev`. Canonical live repository: `popcre/ai-devops`, branch `main`. GitHub CLI is authenticated and issue #131 is open. Windows Bash is `C:\Program Files\Git\bin\bash.exe`. No database, hosted deployment, test account, new secret, or 1Password item is required.

## 9. Open questions and risks

The only measured design question is whether five seconds is enough for GitHub indexing; ten live simultaneous trials decide it, using the smallest passing value. The implementation must reuse the established cross-platform user-state convention rather than inventing repository-local state. If GitHub issue settlement cannot reliably produce one winner within a bounded interval, stop and report the evidence on #131 before changing authority design.

Risks, mitigations, rollback, and the exact definition of done are in plan §13.

## Handoff self-audit

1. **Fresh developer can continue without context: yes.** Sections 1–3 establish the system, goal, issue, plan, and exact current state.
2. **They can continue as effectively as this session: yes.** Sections 4–5 preserve rejected designs and the central race/root-cause reasoning; the linked plan holds the full build specification.
3. **Every execution detail is included: yes.** Section 6 gives ordered actions and gates; Sections 7–9 give constraints, access, risks, and stopping criteria.
4. **Section 0 contains every owner decision: yes.** Sections 1–9 were swept; none requires Albert. Settled decisions are explicitly listed so they are not re-asked.
