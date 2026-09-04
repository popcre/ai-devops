---
issue: 261
status: OPEN
owner: codex/gemini-38-activation
---

# HANDOFF — Gemini 3.8 reviewer activation (2026-09-04 02:11Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert's decision. Albert already ordered
the work completed and separately ordered that no active Windows run be cancelled,
restarted, superseded, or made to start over. Do not re-ask either decision.

Already settled — do NOT re-ask:

- 2026-09-03: complete Gemini 3.8 Flash reviewer activation now, but never at the
  cost of interrupting another Windows run.
- 2026-09-03: a branch/worktree is acceptable for safe isolation.
- 2026-09-04: Qwen may remain quarantined while its separate provider failure is
  diagnosed under issue #259; it must not block safe Gemini activation.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for a
multi-model, read-only AI reviewer workflow. It contains reviewer wrappers,
safety tests, installation scripts, prompt skills, and GitHub verification.
Installation on Windows hosts is the deployment; there is no web application.
This work concerns the `ai-gemini` wrapper and exact model
`gemini-3.8-flash-high`, run through the authenticated Antigravity `agy` CLI.

## 2. What we set out to do this session, and why

The goal is to restore Gemini 3.8 Flash as a real governed reviewer: not merely
recognised by configuration, but live-qualified, merged, installed, reported
available, and proven by one read-only review. The work started because Gemini
and Qwen had previously been removed from rotation and Albert asked for both to
be prepared without wasting another 90-minute Windows run.

This session specifically corrected the mistaken implication that a successful
live qualification meant Gemini was already fully active. It then began the
remaining release gates immediately while preserving active Windows work.

## 3. Current state — what is true right now

- Source preparation for Gemini 3.8 is committed in the four-commit stack
  `5443feec`, `8fda7fca`, `3f069694`, `ddfffd9e` based on `origin/main`
  `16cb629b`. That stack also contains Qwen preparation; Qwen remains fail-closed.
- Gemini's governed hostile live qualification passed on idle `EDGE-DEV` for
  exact model `gemini-3.8-flash-high`, `agy` 1.1.25, and wrapper SHA-256
  `dac5862e5f12b75ff3f8b00075c339e404b62db8b55441012d2fcde6f3ca1f9e`.
  Do not repeat this paid gate unless one of those bound identities changes.
- The durable working checkout is
  `C:\Users\ahazan\.codex\worktrees\gemini-38-release\ai-devops`. It is detached
  at local commit `93fd96fc`, which adds two documentation corrections to the
  prepared stack. Nothing from this checkout is pushed.
- The corrections change `plan_gemini_reviewer_safety_repair.md` from Gemini 3.7
  to 3.8 and change `plan_reintegrate-gemini-flash-3-8-qwen-3-8-max.md` from an
  obsolete direct-main instruction to the current protected branch/PR route.
- Independent read-only final review of `ddfffd9e` completed and returned REJECT.
  Its report is `.ai/reviews/codex-final-check-20260904T020157-815877-8289.md`.
  Two owned findings are fixed by `93fd96fc`. The remaining workflow-policy
  finding concerns existing `origin/main` and must be reconciled with issue #246,
  not silently changed in this workstream. The review also correctly required a
  complete gate result, which is still pending.
- GitHub issue #261 is the completion record for this work. Issue #259 separately
  owns privacy-safe Qwen qualification diagnostics.
- At closeout, runs `33824050222` and `33824022251` still had GitHub-hosted
  `windows-offline` jobs in progress. They started around 01:00Z. Do not push,
  merge, dispatch, install, or run local suites until all Windows jobs are terminal.
- Heartbeat automation `resume-reviewer-3-8-safely` is ACTIVE on this task at a
  ten-minute interval. Its prompt points to commit `93fd96fc` and requires quiet,
  non-interfering continuation. It should be deleted after Gemini is fully active.
- No branch, pull request, merge, installation from the new code, final availability
  proof, or real post-install Gemini review exists yet. The deliverable is PENDING.

## 4. Everything we tried that did NOT work

1. A final review was first run in
   `C:\repos\ai-devops-worktrees\reviewer-38-prep`. Another session rebased that
   detached checkout and then edited Qwen files while the reviewer was reading it.
   The safety wrapper detected source drift and blocked the report as stale. Do not
   reuse that worktree for Gemini release; preserve its Qwen diagnostic edits.
2. The review was repeated in the private checkout above and completed safely,
   but returned REJECT. It found the obsolete direct-main plan instruction, stale
   Gemini 3.7 text, missing full-gate evidence, and an existing workflow/policy
   contradiction. The first two are fixed locally; the latter two require the
   ordered release sequence below.
3. Pushing immediately was considered and rejected because two long Windows jobs
   were still active. A push or PR synchronization can create new work and, under
   older concurrency rules, has repeatedly cancelled existing runs. Waiting here
   is an explicit safety gate, not loss of ownership or lack of progress.

## 5. Root causes and key findings

- Live qualification proves a specific wrapper/runtime/model combination on one
  machine; it does not prove that code is merged, installed everywhere, assigned,
  or able to complete a production review. Those are separate release gates.
- `AGENTS.md` at `origin/main` requires a feature branch and protected merge queue,
  while the new reintegration plan still said direct main. Commit `93fd96fc` fixes
  the plan rather than weakening repository policy.
- `plan_gemini_reviewer_safety_repair.md` still described Gemini 3.7 even though
  `bin/ai-gemini` pins 3.8. Commit `93fd96fc` aligns the durable explanation.
- The workflow at `origin/main` still contains a `push: main` trigger while current
  `AGENTS.md` says not to restore one. Issue #246 is actively implementing protected
  Windows-run handling and must be incorporated before deciding whether any local
  workflow change remains necessary.
- GitHub's three long jobs inspected in this session were on GitHub-hosted Windows
  machines (`windows-2025` labels), not EDGE-DEV, EDGE-RUNN-ENVY, or EDGE-ALIEN.
  That made the local read-only review safe but did not make a push safe.

## 6. Exact next steps

1. Query all open `popcre/ai-devops` GitHub runs and their jobs. Do not continue
   until every Windows job is terminal. You will know this worked when no job with
   a Windows label or `windows-*` name reports queued or in progress.
2. Fetch `origin/main` without changing another checkout. Inspect whether issue
   #246 and branch `codex/issue-246-protected-windows` have landed and read their
   exact workflow/policy changes. You will know this worked when the new base SHA
   and the disposition of the reviewer's workflow finding are documented.
3. Create branch `codex/gemini-38-activation` in the private checkout and rebase
   the local stack ending `93fd96fc` onto current `origin/main`. Resolve only this
   workstream's conflicts; preserve issue #246. You will know this worked when the
   branch is clean and its diff contains the reviewer preparation plus the two
   documentation corrections, with no unrelated reversions.
4. Re-check the Gemini qualification binding. If rebase changed `bin/ai-gemini`
   bytes, the old record must fail closed and one new governed qualification is
   required on an idle host. If bytes did not change, do not spend another paid
   call. You will know this worked when preflight truthfully reports either the
   unchanged valid identity or quarantine requiring an evidence-directed recheck.
5. Run the focused Gemini, shared preflight, sandbox, packet, installer, and any
   touched Qwen suites, followed once by the repository's complete gates. Do not
   raise timeouts or weaken assertions. You will know this worked when every suite
   exits zero with complete output and no interrupted/partial result is counted.
6. Run `ai-codex-review final-check` against the exact clean branch head. Repair
   actionable findings and repeat focused tests before one final full gate only if
   code changes. You will know this worked when the report is current, durable,
   exact-head, and ends `APPROVE`.
7. Verify `git var GIT_COMMITTER_IDENT`, push the feature branch once, open a PR,
   and use the protected merge queue. Never cancel another run to make room. You
   will know this worked when the PR is merged and its merge-group exact-head gates
   passed without restarting a protected Windows job.
8. Install verified `main` through the repository installer on each intended
   reviewer host only while idle. Confirm installed wrapper/runtime hashes and
   `ai-review-preflight status gemini`. You will know this worked when Gemini
   reports `available` with matching identity on each supported host.
9. Run one governed read-only Gemini review on a harmless public issue/repository
   target. Require exact model, durable report, unchanged source, and exact verdict.
   You will know this worked when the report succeeds and source hashes remain
   unchanged.
10. Update issue #261 with evidence, remove the Gemini no-new-work restriction,
    delete this handoff and heartbeat automation, and close #261. Leave Qwen
    quarantined if #259 remains unresolved. You will know this worked when Gemini
    can receive assignments and no stale automation or open handoff remains.

## 7. Constraints and gotchas in force

- Never cancel, rerun, supersede, or compete with an active Windows run.
- Never treat a live qualification pass as full reviewer availability.
- Never bypass quarantine or call `agy` directly; use governed wrapper/preflight.
- Work through a feature branch and protected PR merge queue; no direct main push.
- Preserve other sessions' dirty files and the Qwen diagnostics in
  `C:\repos\ai-devops-worktrees\reviewer-38-prep`.
- Do not rerun unchanged paid Qwen qualification; issue #259 owns its diagnostics.
- Independent exact-head review is mandatory for reviewer safety-path changes.
- Do not weaken safety checks, replace capabilities, expose provider output, or
  print credentials. The repository is public.

## 8. Access and environment

- GitHub CLI is authenticated for `popcre/ai-devops` and was used to inspect runs
  and create issues #259 and #261.
- The local machine is `EDGE-DEV`; Git Bash is
  `C:\Program Files\Git\bin\bash.exe`.
- Gemini's `agy` authentication exists on EDGE-DEV and qualification used version
  1.1.25. Do not reveal account/session contents.
- Provider secrets, where needed, belong in 1Password vault `vibe_coding`; never
  place values in commands, logs, chat, commits, or the public issue.
- Source checkout for continuation is the private worktree named in §3. The main
  checkout is dirty with unrelated concurrent work and must not be cleaned/reset.

## 9. Open questions and risks

- The exact landing state of issue #246 may change before continuation. This is
  expected drift, not an owner decision: inspect current main and adapt while
  preserving the no-interruption requirement.
- Rebasing may change Gemini wrapper bytes and invalidate the EDGE-DEV qualification.
  If so, quarantine is correct and a new bounded live qualification is necessary.
- The prepared stack contains Qwen changes as well as Gemini changes. Shipping is
  acceptable only while Qwen remains quarantined until its independent live proof
  succeeds; do not represent Qwen as active.
- A new PR can consume Windows capacity. Open/push it only after the pool is clear,
  and never update its head while a protected exact-head run is active.

## Self-audit

1. Yes. Sections 1–3 explain the product, purpose, exact commits, checkout,
   qualification, automation, and current blocker; §6 provides a no-guess resume.
2. Yes. Sections 4–5 preserve the failed collision, rejection findings, policy
   conflict, host placement, and distinction between qualification and activation.
3. Yes. Background and outcome are in §§1–2; state/evidence in §3; failures in §4;
   findings in §5; executable gates in §6; constraints/access/risks in §§7–9.
4. Yes. A line-by-line sweep of §§1–9 found no undecided owner judgement. Every
   owner instruction found was already settled and is consolidated in §0. The
   issue #246 drift and possible requalification are evidence-driven worker actions,
   not decisions to return to Albert.
