---
issue: 131
status: OPEN
owner: codex/ai-devops-work-claims-plan-131
---

# Handoff — ai-devops collision-resistant work claims plan

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### No owner decision blocks advisory v1

Work-units, takeover, shared Git hooks, and required-check promotion were removed from v1. Any future addition needs a measured incident, the 30-day v1 evidence, a plan amendment, and—where applicable—Albert's exact current-chat authorization. Do not ask for those choices during v1.

### Already settled — do NOT re-ask

- 2026-08-27: use lightweight cross-machine claims, not a permanent orchestrator or committed claims file.
- 2026-08-27: unrelated/read-only work remains concurrent; copied reviewer-code consolidation is separate.
- 2026-08-27: feature branch + PR + merge queue is mandatory; never use organization-admin bypass for normal ai-devops work.
- 2026-08-27: stale claims remain protective until explicit reconciliation; timeout alone never transfers ownership.
- 2026-08-27: stabilize and shorten the merge queue before claims implementation.
- 2026-08-27: v1 is task-only, has owner-appendable path diagnostics and separate fast advisory CI, with no exact-head binding, push wrapper, hooks, takeover, or required-check change.

No ruleset mutation is part of v1.

## 1. What this application is

`popcre/ai-devops` is POP Creations’ public toolkit for restoring and operating Albert’s multi-model AI workflow. It contains commands, setup, global Claude/Codex rules, skills, reviewer wrappers, and offline tests. It has no hosted application or database. Installation from the repository is deployment.

Live `main` is protected by ruleset `21564317`: feature branch, pull request, Linux/Windows checks, squash merge queue. Admin bypass exists technically but is prohibited for ordinary work.

## 2. What we set out to do this session, and why

Albert asked for the work-claims implementation plan to be fully revised after Grok challenged it, then reviewed by GLM 5.3 with the entire collision history.

The authoritative build specification is [`../plan_ai-devops-work-claims.md`](../plan_ai-devops-work-claims.md). Issue [#131](https://github.com/popcre/ai-devops/issues/131) is the completion contract.

## 3. Current state — what is true right now

The first plan was published at `ac72d40798d3867feef83b3d4de1bcc49acf045c`; no claim code exists. Grok 4.6 returned `REVISE`. Its branch-policy finding was independently confirmed from live `origin/main`, `config/repository-policy.json`, merged PR #104, and ruleset `21564317`. The earlier direct push worked only because organization admins can bypass the rule; it was not the correct workflow.

Two execution-heavy sessions then added Parts A, B, and C to [`../plan_must_address.md`](../plan_must_address.md). Their evidence changed the plan materially: the unreliable hour-long merge queue is the first-order tax, and four locked choices would have worsened throughput. The revised v1 is now task-only, owner paths are append-only, exact-head binding and push wrapping are deferred, ordinary `git commit` and `git push` stay unwrapped, CI is advisory, and units/hooks/takeover/required-check promotion are deferred. It adds reproducible baseline and 30-day effectiveness gates. Grok reviewed the full evidence, rejected two intermediate drafts, and then returned `APPROVE` with no blocking findings. No claim implementation has started.

## 4. Everything we tried that did NOT work

- Full orchestrator: excessive serialization and overhead for recoverable Git work.
- Committed claims file/index: stale across branches/worktrees and a new shared hot file.
- GitHub claim issue + five-second settlement + lowest issue number: not atomic under delayed visibility/retries/partial listings.
- Automatic lease expiry: permits an old disconnected writer and new owner to work simultaneously.
- Required claim check on the unstable `ALLGREEN` queue: adds another batch-ejection path before the existing queue is reliable.
- Network-dependent commit hooks: a measured secondary-limit window would stop every session from making reversible local commits.
- Shared-git-directory hooks: one broken dispatcher can affect every linked worktree on the machine.
- Fixed paths and issue-close blocking: issue #89 correctly expanded from two files to ten and continued after merges.
- Direct-to-main landing: stale instruction superseded by PR #104 and active ruleset.
- REST PATCH treated as compare-and-swap: GitHub offers no expected-old-SHA parameter; ownership mutation now uses Git force-with-lease.
- Component refs in v1: added partial-acquisition/livelock/orphan machinery without evidence that cross-issue component contention justified it.

Full rejected-approach reasoning is in plan §7.

## 5. Root causes and key findings

Duplicate implementation is an intent collision, so ownership is task-wide. Read-only diagnosis remains non-blocking. Optional paths are owner-appendable diagnostics because debugging scope is discovered, not known in advance. Git-ref atomicity remains a Phase 1 hypothesis to prove on both platforms. Lost responses re-adopt only an exact token hash/object; later mutations use force-with-lease. Stale remains protective, with exact Albert-authorized manual reconciliation. Publication remains ordinary Git; a separate workflow reports advisory PR/merge-group evidence quickly without hooks or exact-head claims.

The selected custom/branch ref namespace remains evidence-driven: Phase 1 must prove REST create/read/list, Git force-with-lease update/delete, and cleanup before code is built.

## 6. Exact next steps

1. Commit/push the revised plan/handoff/review record on `codex/revise-work-claims-plan-131`, refresh PR #136, and land through the merge queue without bypass.
2. A fresh implementation session begins plan Step 9.1 by completing the separate throughput prerequisite. Claims code starts only after that plan's STATUS gates pass.

## 7. Constraints and gotchas in force

Feature branch + PR + merge queue only. Preserve unrelated dirty work; stage only issue #131 files. Public repo: no transcript excerpts, secrets, raw tokens, or private paths. Stabilize the queue first. V1 has no Git hook or ruleset mutation. Stale/malformed claims remain protective. Use explicit Git Bash on Windows. Exact-head independent review is required for implementation.

## 8. Access and environment

Canonical repo: `popcre/ai-devops`; target `main`; revision branch `codex/revise-work-claims-plan-131`. Discover the worktree locally; do not copy a machine path. GitHub CLI is authenticated. Windows Bash is `C:\Program Files\Git\bin\bash.exe`. Grok review uses `ai-grok-review` with `AI_GROK_CALLER=codex`. No database, hosted app, test login, or new secret is involved.

## 9. Open questions and risks

The only implementation-time choice is custom versus branch ref namespace, decided by two-platform evidence. Units, takeover, exact-head binding, push wrappers, hooks, and required checks are not open v1 choices.

Main risks: queue instability, lost create response, crash blockage, unclaimed ordinary `git push` visible only through advisory CI, ref clutter, selective GitHub throttling, and machinery costing more than it saves. The plan assigns a gate and a 30-day keep/change/remove decision.

## Handoff self-audit

1. **Fresh developer can continue without context: yes.** Sections 1–3 identify the repo, live workflow, issue, revision, and exact current state; the linked plan is the complete build spec.
2. **They can continue as effectively as this session: yes.** Sections 4–5 preserve every rejected design and the atomicity/split-brain/fencing reasoning.
3. **Every execution detail is included: yes.** Section 6 gives ordered actions and gates; Sections 7–9 give constraints, access, risks, and open criteria.
4. **Section 0 contains every owner decision: yes.** Sections 1–9 were swept. No owner decision blocks advisory v1; post-v1 escalation is explicitly deferred.
