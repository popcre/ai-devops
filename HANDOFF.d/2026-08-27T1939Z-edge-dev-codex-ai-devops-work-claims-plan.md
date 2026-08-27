---
issue: 131
status: OPEN
owner: codex/ai-devops-work-claims-plan-131
---

# Handoff — ai-devops collision-resistant work claims plan

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### Blocking only final enforcement, not code/test work

- **Require the new `work-claim-guard` GitHub check in ruleset `21564317`.** Recommendation: authorize this exact ruleset update only after its workflow and live PR qualification pass. Without the required-check update, implementation remains partial and issue #131 stays open.
- **Authorize any real stale-claim takeover.** Recommendation: only after a claim has had no heartbeat for at least 24 hours, name the exact task/ref in the current chat and require no open PR for its bound branch/head. This is per-incident authorization, not a standing permission.

### Already settled — do NOT re-ask

- 2026-08-27: use lightweight cross-machine claims, not a permanent orchestrator or committed claims file.
- 2026-08-27: unrelated/read-only work remains concurrent; copied reviewer-code consolidation is separate.
- 2026-08-27: feature branch + PR + merge queue is mandatory; never use organization-admin bypass for normal ai-devops work.
- 2026-08-27: stale claims remain protective until explicit reconciliation; timeout alone never transfers ownership.
- 2026-08-27: v1 uses task refs only; declared/high-risk paths fence publication and diagnose overlap but do not create component refs.

The next session must put the one blocking ruleset decision to Albert in one message only when the tested guard is ready to become required. Do not ask before code/test qualification needs it.

## 1. What this application is

`popcre/ai-devops` is POP Creations’ public toolkit for restoring and operating Albert’s multi-model AI workflow. It contains commands, setup, global Claude/Codex rules, skills, reviewer wrappers, and offline tests. It has no hosted application or database. Installation from the repository is deployment.

Live `main` is protected by ruleset `21564317`: feature branch, pull request, Linux/Windows checks, squash merge queue. Admin bypass exists technically but is prohibited for ordinary work.

## 2. What we set out to do this session, and why

Albert asked for the work-claims implementation plan to be fully revised after Grok challenged it, then reviewed by GLM 5.3 with the entire collision history.

The authoritative build specification is [`../plan_ai-devops-work-claims.md`](../plan_ai-devops-work-claims.md). Issue [#131](https://github.com/popcre/ai-devops/issues/131) is the completion contract.

## 3. Current state — what is true right now

The first plan was published at `ac72d40798d3867feef83b3d4de1bcc49acf045c`; no claim code exists. Grok 4.6 returned `REVISE`. Its branch-policy finding was independently confirmed from live `origin/main`, `config/repository-policy.json`, merged PR #104, and ruleset `21564317`. The earlier direct push worked only because organization admins can bypass the rule; it was not the correct workflow.

This revision replaces issue/sleep admission with atomic create-only task refs, defaults to one writer per task, requires declared paths, hashes public owner tokens, keeps stale claims protective, adds local/PR fencing, and uses branch + PR + merge queue. GLM 5.3’s first critique returned `REVISE`: REST refs lack CAS, takeover/head binding/lost-response recovery were under-specified, and component refs were unnecessary v1 risk. Its closing critique confirmed those findings were resolved and required one final correction: task-wide and work-unit modes must be mutually exclusive, with exact scope-digest fencing; it also required publication-specific staged/push-range checks so unrelated dirty files do not interfere. All findings are now incorporated and recorded in [`../docs/work-claims-plan-review-2026-08-27.md`](../docs/work-claims-plan-review-2026-08-27.md). Revision work is isolated on `codex/revise-work-claims-plan-131`; no implementation is started.

## 4. Everything we tried that did NOT work

- Full orchestrator: excessive serialization and overhead for recoverable Git work.
- Committed claims file/index: stale across branches/worktrees and a new shared hot file.
- GitHub claim issue + five-second settlement + lowest issue number: not atomic under delayed visibility/retries/partial listings.
- Automatic lease expiry: permits an old disconnected writer and new owner to work simultaneously.
- Prompt-only renew/verify/release: repeats a measured enforcement failure; mechanical fencing is required.
- Free-form work-unit and optional paths: easy accidental collision bypass.
- Direct-to-main landing: stale instruction superseded by PR #104 and active ruleset.
- REST PATCH treated as compare-and-swap: GitHub offers no expected-old-SHA parameter; ownership mutation now uses Git force-with-lease.
- Component refs in v1: added partial-acquisition/livelock/orphan machinery without evidence that cross-issue component contention justified it.

Full rejected-approach reasoning is in plan §7.

## 5. Root causes and key findings

Duplicate work is an intent collision, so default ownership is task-wide. Declared/high-risk paths fence publication and flag suspicious cross-issue overlap; v1 has no component locks. Git ref creation provides one-winner admission; comments/labels provide human visibility only. Lost create responses re-adopt only an exact per-acquisition token hash/object. Git force-with-lease protects later updates/deletion from stale expected objects. Stale ownership remains protective because cross-machine process death cannot be inferred safely. Publication is bound through `bind-head`, trailers, local hooks, and PR/merge-group verification because prose alone has not held.

The selected custom/branch ref namespace remains evidence-driven: Phase 1 must prove REST create/read/list, Git force-with-lease update/delete, and cleanup before code is built.

## 6. Exact next steps

1. Commit only the revised plan, handoff, router wording, and durable review record on `codex/revise-work-claims-plan-131`; push, open a PR, wait for checks, enqueue through merge queue, and verify the squash SHA on `origin/main`. You’ll know planning revision landed when PR state is `MERGED`, merge-group/main checks are green, and no admin bypass was used.
2. A fresh implementation session begins plan Step 9.1. It re-derives live policy/refs/issues before action and updates STATUS after every executed step.
3. Before making `work-claim-guard` required, put the single Section 0 ruleset decision to Albert. You’ll know final enforcement is authorized only from an explicit current-chat instruction naming ruleset `21564317` and that check.

## 7. Constraints and gotchas in force

Feature branch + PR + merge queue only. Preserve unrelated dirty work; stage only issue #131 files; never reset/clean/force-push or broad-delete refs. Public repo: no transcript excerpts, secrets, raw owner tokens, or private paths. GitHub refs are admission authority; issue comments are audit only. Stale/malformed claims remain protective. Ruleset mutation needs exact current-chat authorization. Use explicit Git Bash on Windows. Exact-head independent review is required for the eventual implementation.

## 8. Access and environment

Canonical repo: `popcre/ai-devops`; target `main`; revision branch `codex/revise-work-claims-plan-131`; worktree `C:\Users\ahazan\.codex\worktrees\ai-devops-work-claims-plan-revision`. GitHub CLI is authenticated. Windows Bash is `C:\Program Files\Git\bin\bash.exe`. GLM review uses `ai-glm` with `AI_GLM_CALLER=codex`. No database, hosted app, test login, or new secret is involved.

## 9. Open questions and risks

Open choices are bounded in plan §8/§13: custom vs branch ref namespace, supported shared-gitdir fencing adapter, and later required-check authorization. Takeover timing/authority and PR head binding are now locked; none may weaken atomic ownership or stale protection.

Main risks: lost create response, crash blockage, old-owner resumption, model bypass, shared-gitdir hook interference, ref clutter, GitHub outage, and admin bypass. The plan assigns a mechanical mitigation and verification gate to each.

## Handoff self-audit

1. **Fresh developer can continue without context: yes.** Sections 1–3 identify the repo, live workflow, issue, revision, and exact current state; the linked plan is the complete build spec.
2. **They can continue as effectively as this session: yes.** Sections 4–5 preserve every rejected design and the atomicity/split-brain/fencing reasoning.
3. **Every execution detail is included: yes.** Section 6 gives ordered actions and gates; Sections 7–9 give constraints, access, risks, and open criteria.
4. **Section 0 contains every owner decision: yes.** Sections 1–9 were swept. Only the exact future ruleset/check update needs Albert; it is consolidated with recommendation and timing.
