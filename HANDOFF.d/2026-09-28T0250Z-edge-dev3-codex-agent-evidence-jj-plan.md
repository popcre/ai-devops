---
issue: 903
status: OPEN
owner: codex/agent-evidence-jj-plan
---

# Agent evidence and Jujutsu pilot handoff

The executable specification is [the implementation plan](../plan_agent_evidence_and_jujutsu_pilot.md). Read its STATUS first. This file records the planning session's state; the plan owns all build detail.

## 0. Owner decisions and action index

None — nothing in this workstream needs Albert before the first implementation child. The requested pilot is reversible and GitHub remains authoritative. Any later default-client switch or production action requires its own exact reviewed authority; the plan does not grant it. Already settled: on 2026-09-27 EDT Albert asked for a plan to reduce evidence commits, tolerate unrelated `main` movement and test Jujutsu, with GitHub code backup retained. Do not re-ask him to approve drafting or the disposable-clone pilot.

## 1. Goal and owner

Reduce time wasted on unchanged code being re-reviewed and on evidence-only commits. Recover interrupted agent work and keep accepted code on GitHub. Parent [ai-devops #903](https://github.com/popcre/ai-devops/issues/903) is the routing index. The next session takes only its first unticked child, records proof, comments the next child and stops.

## 2. What happened in this session

Read current ai-devops/shared-db rules, existing plans and local Git history; researched official Jujutsu, Delta and Forgejo documents. Found ai-devops forward-main packet tolerance already merged via #639 and shared-db evidence-isolation work already owned by its workflow-refactor Step 1. Opened parent #903 and wrote the linked new plan. No implementation code, database operation, Jujutsu install or live pilot was performed. No agent delegation occurred.

## 3. Current state and exact next action

At plan creation, ai-devops `origin/main` was `3d509f47a3467c220e8db523016d28b8431aee65`; shared-db's locally fetched `origin/main` was `7fab5c716eb111a10c865b99e09b5ad94ff092b2`. Refresh both, because these are moving refs. The ai-devops working branch is `codex/agent-evidence-jj-plan` in its isolated worktree. Before implementing Step 0, verify this planning PR was merged and read plan STATUS §9. Step 0's result is a dated, reproducible baseline and an ownership map; it makes no database writes.

## 4. Evidence and non-obvious findings

The September 22–28 local shared-db history had 505 reachable commits; 244 subjects mentioned evidence and 59 mentioned refresh/merge. These are overlapping subject classifications, not 505 PRs or a measured collision count. A local sample of 84 recent chat files was available; older history is better represented by the cited incident and refactor plans. Ai-devops `bin/ai-review-packet:275–330` and its tests already tolerate a true forward target move. Shared-db has equivalence and exact-head logic; its older shared evidence paths caused real PR conflicts. The plan separates measured remaining defects from work already owned.

## 5. Failed or rejected routes

Do not repeat the merged ai-devops #639 repair. Do not fork shared-db's Step 1 or replace its existing equivalence validator. A Forgejo move still leaves Git integration and would relocate CI/issues; DeltaDB still uses Git and is beta. Do not copy old reviewer approval to new content, treat a commit subject count as delay proof, ignore arbitrary `.agent/` files, or suppress protected checks. The detailed reasoning and sources are in plan §§5–8.

## 6. Remaining steps and proof

First: finish and merge this documentation-only plan through the current ai-devops branch/PR route; verify the merged SHA on GitHub. Then the next session performs plan Step 0 under #903 and updates the plan STATUS with the report link. Existing shared-db Step 1 stays with its own non-orchestrator issue; the parent records its live outcome rather than duplicating a PR. Subsequent children address only demonstrated gaps, then run a disposable Jujutsu comparison and publish a go/no-go. Each plan §9 step names files and a verification gate. No child may inherit a prior issue's work type or database-object claim.

## 7. Constraints and access

Use fresh current-upstream worktrees; canonical checkouts are landing-only. Run `ai-task-gates start` for the actual class and `check` before stronger gates. Use `bin/ai-gh` for GitHub access. `git var GIT_COMMITTER_IDENT` must report Albert's noreply identity before commits. Sign GitHub posts with chat ID/machine. Keep production and shared cloud read-only. Shared-db tooling tasks are **non-orchestrator work**; any newly discovered structure change needs its own orchestrator route. No credential is needed for the plan or offline pilot. Jujutsu is not installed on this planning host; use a supported user-local install only for the future disposable-clone test.

## 8. Delivery and verification state

Planning files and router entry were drafted in the isolated ai-devops worktree. At the time this handoff was written they were not yet committed, pushed, reviewed, merged or installed; the closing session must update this section before shipping. Issue #903 exists. Implementation and pilot are unstarted. There is no deployable app artifact in this documentation-only change. Successful plan delivery means the PR is merged and these files are present on `origin/main`; successful implementation requires the plan's per-child checks and GitHub code continuity.

## 9. Risks, rollback and final self-audit

The main risk is false review equivalence authorizing changed code; the implementation plan requires refusal fixtures and current integration checks. Jujutsu's local Git interoperation and concurrency limitations are tested before any default switch. The plan can yield no-change/no-go without weakening safeguards. A documentation-only planning PR can be reverted normally; future code changes retain old readers and old Git worktrees until replacement proof is complete.

Self-audit: (1) newcomer can continue: §§1,3,6 and plan STATUS/§9 give owner, start point and gates. (2) Same session knowledge is preserved: §§2,4,5 and plan §§3–8 cover findings and dead ends. (3) Complete action/safety state: §§6–9 plus plan §§9–13 cover tests, access, risk and landing. (4) All owner decisions are in §0; the sweep found none needed for the first child. No subagent report exists.
