---
issue: 62
status: OPEN
owner: codex/wrapup-open-issues-20260917
---

# AI DevOps open-issues continuation

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

1. **Rotate two exposed MCP bearer tokens.** A process-list diagnostic in this session printed the live DesignFlow and NAS MCP bearer values into tool output. Do not repeat either value. Both fields already live in 1Password item `f335s4oy3m6n74jmwj74hunrtu` as `devops_token` and `nas_token`; no new vault item is needed. Containment is not remediation: Albert must explicitly authorize rotation before either live credential is replaced.
2. **Authorize an exact installation action if the merged source is to be activated.** The task gate refused the #103 completion-hook/global installation because the protected class requires Albert to name the exact resource and action. The same installation boundary remains for #511 and the Windows-host portions of #133, #200, and #262.
3. **Decide #122's `tokensave` disposition.** Current `main` has no `tokensave` references; removal versus restoration is an owner choice. `ai-headroom` is tool-managed but its MCP registration remains outside restore management.
4. **Name a confirmed non-production Linux host for #249.** The inspected Linux candidate did not have Grok installed and was not confirmed non-production in the machine atlas. Do not install or experiment on an unclassified host.

## 1. What this application is

`popcre/ai-devops` is the public recovery and governance toolkit for POP Creations' multi-model AI workflow. GitHub `main` is authoritative. Source changes use a feature branch, pull request, required checks, and the merge queue; installation is this repository's deployment mechanism. The canonical checkout is landing-only, so every continuation must use its own current-upstream worktree.

This handoff covers the bounded session Albert started with “resolve all open issues.” It does not claim that all repository issues are resolved. At 2026-09-17 21:02Z GitHub reported 35 open issues and 11 open pull requests; those counts are moving facts and must be refreshed before acting.

## 2. What we set out to do this session, and why

The goal was to reduce the entire open-issue inventory by closing already-satisfied issues, landing repair-ready work, and turning ambiguous leftovers into evidence-backed next actions. The session used isolated worktrees and three sub-agents for bounded, non-overlapping pieces. It did not touch a shared database, create a shared-db migration, mutate preview/production data, or hold an orchestrator marker; the shared-db handover path therefore required no database issue or transfer.

Scope was frozen when Albert invoked `wrap-up`. After that point the session finished only work already in flight, updated stale session documentation, performed the secrets sweep, and prepared this continuation record.

## 3. Current state — what is true right now

### Landed or closed in this session

- #35 was already closed and was verified rather than reworked.
- #103 closed. PR #486 merged as `f93499c`; source is landed, but installation was not authorized.
- #117 closed at 2026-09-17 18:29Z because the duplicate maps no longer exist. Obsolete PR #114 was closed.
- #131 Step 2 evidence PR #553 merged as `d30b5a321f30f37d9f2c37bc567796b0b9c0e276`.
- #262 security-plan PR #552 merged as `c327a31008541f27593db8f2555241349c260344`.
- #133 source/status-line PR #483 merged as `7853205745b446dbe8256876599ef26f47906fe7`; machine rollout beyond EDGE-DEV remains unproved.
- #131 policy/baseline PR #556 merged as `eff2c5ec23b7a4d9b8770b440338a975ba3d6339`. It adds bounded discovery budgets: availability 5, acquire 10, core minimum 200, and refusal before reference allocation for secondary/abuse attempts.
- #200 Smart App Control PR #488 received exact-head approval and merged as `334145ef85d35a86d9e9fef99d70602d57c5ce8a`. Merged-source EDGE-DEV TestOnly proof and disposable-Windows proof are still required before closure.
- #511 PR #520 received exact-head approval and merged as `7f8976a8d3e4542dc6a3c042cf3a73560e7ea1aa`. Installed-global proof and issue closure remain. This closeout updates `plan_live-proof-session-sizing.md`, which had still described PR #520 as unmerged.
- #79 replacement documentation PR #563 changed only `docs/configuration.md` and `docs/design-decisions.md`, passed reachability/context checks, and merged as `001c3390a33bb7fcd4c654e8bee0f8fdc92a1ae2`. Stale PR #135 remains open and should be closed as superseded; do not merge it.

### Open work with concrete evidence

- **#262 / PR #560:** branch `codex/issue-262-phase-a-0917`, worktree `C:\repos\ai-devops-wt-issue262-phasea-0917`, head `656ecf9c4b5ecb1d853b74f0a12697a7b6232f90` before the final rebase. Focused maintenance tests passed 43/43; qualification guard, Windows scripts 47/47, workflow policy, reachability, and context audit passed. The permitted local full suite hit Windows page-file exhaustion (`CreateFileMapping`, Win32 1455) in concurrent reviewer tests, so clean-host CI is the full-suite proof. The exact-head security review was deliberately stopped after PR #563 moved `main`; it could no longer qualify the old base. The plan inside PR #560 is also stale: Step 5 still says no PR/review exists. Next action is rebase onto current `origin/main`, update only the plan STATUS/restart point, rerun focused validation, then obtain a new exact-head security review and CI before merge. No host installation occurred.
- **#185:** the repair is complete in source. Five hosted Windows sections and fail-closed aggregation passed in runs `35251990218` and `34905839047`. The only scheduled run was pre-repair and cancelled at 105 minutes. Acceptance waits for the first post-repair scheduled run.
- **#186:** unresolved. Current markers distinguish sections/tests but there is no bounded startup/progress watchdog, so a no-progress start still collapses into the ordinary 40/105-minute timeout. Implement a narrow watchdog that emits a distinct stalled category without penalizing legitimately long suites.
- **#307:** the latest scheduled run timed out, while the repaired manual full run passed. A heartbeat named `verify-issue-307-scheduled-run` monitors the next scheduled run on 2026-09-21 at 06:17Z and stays quiet unless the state meaningfully changes.
- **#249:** Windows Grok was healthy at `1.0.13 (5e9a58528b76)`. The Linux candidate returned `grok: command not found`, its non-production status was not established, and the attempted official-source lookup returned HTTP 422. Start only after an eligible host and version-pinned official source are known.
- **#133:** source is merged; installation and actual status-line behavior on every intended machine remain unverified.
- **#200:** source is merged; exact merged-source TestOnly evidence and disposable-host proof remain.
- **#511:** source is merged; installed globals and issue closure remain.

### Open pull requests at the last inventory

At 2026-09-17 21:02Z, GitHub showed PRs #15, #33, #66, #135, #184, #192, #392, #478, #555, #557, and #560 open. Refresh this list. PR #135 is explicitly superseded by merged PR #563. PR #560 is this session's live code work. Other PRs belong to separate workstreams and must not be altered without re-resolving ownership.

### Sub-agent: `issue131_readonly_command_0917`

- **Asked to do:** implement only #131 §9.4 read-only claim discovery in `bin/ai-work-claim`, its focused test, and suite manifest registration.
- **Actually did:** the worktree `C:\repos\ai-devops-wt-131-readonly-0917` holds uncommitted changes to `config/ci-suite-manifest.json` plus new `bin/ai-work-claim` and `tests/test-ai-work-claim.sh`. The Windows focused suite passed 33/0/0 and proved read-only commands, bounded pagination, fail-closed ambiguity, GitHub server time, strict schema, redaction, exact local recovery, and zero remote mutations.
- **Found:** the first workflow-policy run exposed incorrect Windows-shard registration; the manifest was corrected, but the verification rerun was interrupted for wrap-up before producing a result.
- **PR / branch:** no PR at draft time; branch `codex/131-readonly-discovery-0917`.
- **Worktree:** live and resumable; do not clean.
- **Deliberately did NOT do:** no remote mutation, acquisition, release, administration, reconciliation, or pruning was authorized.

### Sub-agent: `issues185_186_audit_0917`

- **Asked to do:** read-only acceptance audit of #185 and #186.
- **Actually did:** produced the evidence summarized above; changed no files or GitHub state.
- **Found:** #185 repair is source-complete but scheduled acceptance is pending; #186 needs a bounded inactivity detector.
- **PR / branch:** none.
- **Worktree:** none created for retained work.
- **Deliberately did NOT do:** no implementation, rerun, issue edit, or host action.

### Sub-agent: `issue79_pr135_audit_0917`

- **Asked to do:** replace the useful documentation delta from stale PR #135 on current `main` without private-memory mutation.
- **Actually did:** opened PR #563 with only two prose files; the parent verified the file list and merged it as `001c3390`.
- **Found:** the functional defect had already been superseded; only the durable configuration/design documentation was missing.
- **PR / branch:** PR #563 merged; branch `codex/issue-79-docs-repair-20260917`.
- **Worktree:** finished and safe to retire after the PR state is rechecked.
- **Deliberately did NOT do:** no private index mutation, automatic sync enablement, plan change, handoff change, or issue-state change.

## 4. Everything we tried that did NOT work

- Installing the #103 completion hook/global rules was refused by the task gate: `deploy` is forbidden for protected `reviewer-safety` without Albert naming the exact resource and action. The refusal was honored; capability was not disabled or bypassed.
- PR #560's first security-review attempt failed because its source/target moved. After rebasing, a second review was started, but this session then merged the already-running prose PR #563. That moved `main` again and invalidated the review base, so the review was stopped rather than presenting stale approval. Rebase once, update the stale plan, and review only the final head.
- PR #560's local full suite did not prove a product defect. Windows failed to allocate a shared mapping (`Win32 error 1455`) during concurrent reviewer tests. Do not rerun unchanged on the same busy host; use clean-host PR CI after the next meaningful head change.
- The #249 Linux probe did not provide an eligible host: Grok was absent, non-production classification was unproved, and official-source lookup returned HTTP 422.
- The first attempt to merge docs-only PR #563 used `--delete-branch`, which merge-queue repositories reject. Retrying without that flag merged successfully.
- #131 §9.4's first workflow-policy run rejected the Windows-shard registration. The manifest was corrected, but wrap-up stopped the rerun before a result; do not claim policy validation yet.
- A process diagnostic was too broad and printed live MCP bearer tokens. Do not repeat broad command-line process dumps. Use narrowly filtered process IDs/names and redact command lines. Rotation is the only remediation for the exposed values.

## 5. Root causes and key findings

- “Open issue” did not mean “missing code.” Several tickets were already satisfied or had source landed but lacked current documentation, installation, or live acceptance evidence.
- Installation is a separate protected outcome. A merge cannot be reported as machine-wide acceptance for #103, #133, #200, #511, or #262.
- #185 and #186 are distinct: splitting tests across hosted jobs solves shared-host duration pressure, but it does not identify a process that never makes progress.
- #262 needs both a narrow privilege boundary and a truthful plan. Exact-head approval must cover the same head and current target base that will enter the merge queue.
- The current handoff directory has stale contracts. A live comparison found these files tied to closed issues: the #131 handoff, the #337 handoff, nine #159 handoffs, and the #478 PR handoff. Issue #125 owns retirement; do not delete them casually because obligations must be reconciled first. Several older files also still use `issue: none`.
- Secrets sweep result: the two exposed values were already stored in the correct 1Password item. No credential was newly created or copied. The transcript exposure still requires rotation approval.

## 6. Exact next steps

1. Refresh `origin/main`, the open-issue list, open PRs, and worktree ownership. Do not rely on the 21:02Z counts.
2. Inspect `C:\repos\ai-devops-wt-131-readonly-0917`, review the exact three-file uncommitted diff, and rerun workflow policy plus the smallest manifest/line-ending selection checks. The focused suite is already 33/0/0. Because #131 itself is closed, decide which open issue/plan owns §9.4 before committing or shipping; do not invent a new public issue during cleanup.
3. **DONE (2026-09-18, ZCode session on EDGE-DEV).** PR #560 was rebased, the plan STATUS corrected, focused tests rerun at every head, and eight exact-head security reviews obtained: six REJECTs fully repaired on-branch (session hijack surface, .NET startup-hook and CoreCLR profiler environment channels, evidence-neighbourhood ownership, ledger integrity, launcher injection), then APPROVE at `ed7fa089`, a CI-convention rename of the launcher to `launch-worker.bat`, and APPROVE at `b1627d56`. All checks passed; the merge queue landed it as squash `bdb44193` on `origin/main`. No host was installed. The plan STATUS and index on `main` carry the restart point (Step 6, one live host per fresh session). The owning session of this handoff is unreachable (owner confirmed 2026-09-18); this file stays OPEN for its remaining items (#62 still open), and the #262 worktree was retired after the merge with PR-lineage proof.
4. Close obsolete PR #135 as superseded by merged PR #563. Do not merge or resurrect it.
5. For #185, wait for and inspect the first post-repair scheduled run; do not rerun the already-proved manual matrix. For #186, open one isolated implementation session for the inactivity watchdog.
6. When the 2026-09-21 #307 automation reports, either close with scheduled-run proof or diagnose the exact failing section; do not treat the manual run alone as scheduled acceptance.
7. After explicit owner authorization, rotate both exposed MCP bearer tokens using their existing 1Password fields, then restart affected MCP consumers without printing values and verify by fingerprint or authenticated non-secret behavior.

## 7. Constraints and gotchas in force

- Use one current-upstream worktree per write-capable task; keep the canonical checkout landing-only.
- Start the task class and recheck before review, shipment, installation, or infrastructure action.
- Make every GitHub call through `bin/ai-gh`; use `bin/ai-pr-wait` for bounded PR waits.
- Never push directly to `main`. Outside DesignFlow, the session that opens a PR owns merging it unless a real blocker remains.
- Reviewer wrappers, evidence tools, safety tests, and installed routing rules require a read-only exact-head final review.
- Do not overlap a local full suite with jobs using the same Windows host or installed runtime. Do not rerun the unchanged #560 full suite after the Win32 1455 resource failure.
- Preserve capability. Do not close issues by deleting, bypassing, or disabling the behavior they requested.
- This repository is public. Do not commit private transcripts, raw licensed data, machine secrets, or token values.
- The user asked for wrap-up; do not start another issue from this handoff. A successor may resume only after a fresh request/session.

## 8. Access and environment

- Repository: `C:\repos\ai-devops`, remote `popcre/ai-devops`.
- Handoff/docs branch: `codex/wrapup-open-issues-20260917`; its worktree is `C:\repos\ai-devops-worktrees\wrapup-open-issues-20260917` until the docs-only PR merges and cleanup is verified.
- #262 worktree: `C:\repos\ai-devops-wt-issue262-phasea-0917`; preserve.
- #131 §9.4 worktree: `C:\repos\ai-devops-wt-131-readonly-0917`; preserve until its final state is resolved.
- #79 docs worktree: `C:\repos\ai-devops-worktrees\issue-79-docs-repair-20260917`; PR merged, safe to retire through `cleanup-worktree` after rechecking cleanliness.
- Git committer identity was verified as `Albert Hazan <u2giants@users.noreply.github.com>` before this handoff edit.
- No production or shared-cloud mutation occurred. No database mutation occurred.

## 9. Open questions and risks

- Will Albert authorize rotation of the exposed DesignFlow and NAS MCP tokens? Until then, assume compromise even if current calls still succeed.
- Which open programme issue should own #131 §9.4 now that #131 is closed? Resolve this before shipping the uncommitted implementation.
- PR #560's hosted Windows checks were still in progress at the last inspection; their result is not acceptance because the branch must change to refresh the plan and base.
- #185 can close only after a post-repair scheduled run; #186 needs implementation, not another audit.
- Installation claims for #103, #133, #200, and #511 remain incomplete. A source merge or healthy endpoint is not machine acceptance.
- Counts, PR heads, CI state, and worktree ownership become stale quickly. Re-resolve all four at session start.

### Mandatory fresh-developer self-audit

1. **Can a brand-new developer continue without chat context? Yes.** Sections 1–3 identify the repository, goal, landed commits, open proofs, live worktrees, and separated sub-agent state.
2. **Can they continue as effectively as this session? Yes.** Sections 4–8 preserve failed approaches, exact restart commands/tools, ownership boundaries, review/install gates, and the current evidence behind each major issue.
3. **Is every execution-critical detail present? Yes, with moving facts explicitly marked.** Section 0 names owner decisions; Section 6 gives ordered next actions; Section 7 preserves safety constraints; Section 9 names unresolved risks. The successor must refresh GitHub and worktree state rather than trusting dated counts.
