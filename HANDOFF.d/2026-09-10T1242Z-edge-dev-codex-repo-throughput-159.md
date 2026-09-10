---
issue: 159
status: OPEN
owner: codex/issue-167-shared-harness
---

# HANDOFF — repository throughput parent #159 (2026-09-10 12:42Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing currently needs Albert's decision. The next session should not
ask permission to continue: finish #167, then #169, and run #166 last as Albert
already directed on 2026-09-10.

Already settled — do not re-ask:

- Parent #159 stays open until every child is delivered to production.
- #166 is deliberately last because it changes the required-check cutover.
- Preserve every assertion, scheduled/manual complete fallback, #260's
  fail-closed reviewer coverage, and the stable `windows-offline` aggregate;
  never depend on the number of ordinary Windows sections.
- Blacksmith is additive capacity, not permission to remove GitHub-hosted or
  qualified local lanes.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery toolkit for a multi-model
AI workflow. It is not a deployed web application. GitHub Actions and protected
merge-queue checks are its production delivery path; installation is its
machine deployment mechanism. Parent GitHub issue #159 tracks a repository
throughput redesign so concurrent AI sessions finish and ship without weakening
reviewer, Windows, scheduled, or manual safety coverage.

Repository: `C:\repos\ai-devops`. Canonical checkout is landing-only. The live
#167 worktree is `C:\repos\ai-devops-worktrees\issue-167-shared-harness`.

## 2. What we set out to do this session, and why

The session first completed child #164, whose PR #365 attempted to prove that a
merge-queue build carried successful verification from its exact pull-request
head. Albert required a real merge-group exercise because the original ancestry
assumption had never been tested. We then closed obsolete PR #115 and started
#167, consolidating duplicated Bash test result plumbing without losing an
assertion or weakening complete fallback coverage. #169 must follow; #166 is
the final cutover.

## 3. Current state — what is true right now

### Completed and on `origin/main`

- #164 is CLOSED. PR #365 merged as `ac6b2188`; corrective PR #369 merged as
  `3d42a82b`; the narrow injected-test cleanup PR #370 merged as `8f349f49`.
  `tests/verification/repo-throughput/issue-164-merge-queue-convergence.md`
  records the real merge-group and injected-failure evidence.
- Real GitHub merge-group commits here are one-parent synthetic squash commits,
  so `git merge-base --is-ancestor <pr-head> <group-sha>` is invalid. The final
  gate atomically reads `pullRequest.headRefOid` and
  `pullRequest.mergeQueueEntry.headCommit.oid`, binds the latter to the workflow
  SHA, then requires successful exact-head PR evidence.
- Real merge-group run `34440507656` failed closed and skipped its dependent
  Linux job. It failed first because exact-head PR run `34439723342` was still
  queued; the focused test separately exercises the missing-job branch.
- Exact-head review approved PR #370 commit
  `506d56dbef6c0886ea4867ec21f5218757515389`; hosted run `34442392362` passed.
- PR #115 is CLOSED as obsolete; #204 already superseded its concurrency change.
- Parent #159 has a completion comment for #164. `origin/main` was
  `6c3042db29b6a98320bdc503d7d976fbfcea9367` at closeout, so it has advanced
  beyond this session's #164 merges.

### #167 is committed, pushed, open, and not merge-ready

- Issue #167 is OPEN and assigned to `u2giants`.
- Branch: `codex/issue-167-shared-harness`.
- Worktree: `C:\repos\ai-devops-worktrees\issue-167-shared-harness`.
- PR: #371, `https://github.com/popcre/ai-devops/pull/371`.
- Exact head before this handoff commit:
  `c0199e8f38b3c6a15d4499fa18b3e8040bdf331a`.
- Commits: `6b9fc729` adds the shared harness and migration; `c0199e8f` makes
  the harness proof fail closed.
- `tests/lib-test-harness.sh` owns byte-equivalent `ok`, `bad`, `skip`, and
  quiet `check` behavior. Twenty-nine suites source it. Existing human output,
  counters, final exit conditions, and 1,563 counted `check` calls remain.
- `AI_TEST_REPORT_FILE` optionally receives stable TSV fields: suite, status,
  and check identity. `tests/test-lib-test-harness.sh` injects a failed command
  and byte-compares pass/fail/skip records.
- Distinct local contracts were deliberately preserved: TAP output, lowercase
  counters, multi-value comparisons, immediate-exit checks, and visible-output
  checks were not forced into the shared helper.
- No per-suite path graph was added. #163 provides coarse categories but no
  measured unnecessary-work saving that justifies a finer omission risk.
- Evidence draft is
  `tests/verification/repo-throughput/issue-167-shared-harness.md`. The branch's
  plan STATUS row says done, but #167 must remain open until the complete manual
  matrix and final exact-head review pass and PR #371 lands.

### Verification state

- Exact-head PR run `34445087943` on `c0199e8f` PASSED: Linux, four independent
  Windows sections, stable `windows-offline`, self-hosted reviewer safety, and
  the hosted reviewer fallback all succeeded.
- Manual run `34444695949` PASSED, including the full Windows backstop, but it
  tested predecessor head `6b9fc729`, before the one-line fail-closed test fix.
- Exact-head manual run `34445127896` was CANCELLED. Its full Windows suite step
  actually succeeded at 99m56s, but the 100-minute job ceiling cancelled
  finalization; reviewer safety also hit its 30-minute ceiling. The aggregate
  therefore failed.
- Exact-head manual run `34445717137` was CANCELLED at the same 100-minute full
  Windows ceiling; Linux and reviewer safety passed, but the aggregate failed.
- Do not rerun either unchanged. Diagnose the measured ceiling interaction
  first. `.github/workflows/verify.yml:198` defines the complete job and line
  228 currently sets `timeout-minutes: 100`.
- Independent review `codex-final-check-20260910T061941-404022-25398.md`
  rejected head `6b9fc729` because the new test used only `set -u`; that real
  flaw was fixed in `c0199e8f` with `set -euo pipefail`.
- Independent review `codex-final-check-20260910T062536-410070-24966.md`
  found no harness defect on exact head `c0199e8f`, but rejected shipment
  because exact-head complete-matrix evidence was missing. No APPROVE verdict
  exists yet.
- This handoff commit changes PR #371's head and will start fresh ordinary PR
  checks. The prior run IDs remain code evidence for their stated commits, not
  exact-head approval for the handoff commit.

### Not started

- #169 is OPEN and unassigned. No branch or worktree was created. A read-only
  inventory found overlapping lock, metadata, boundary, digest, and report
  helpers across `bin/ai-grok-review`, `bin/ai-glm`, `bin/ai-kimi`, and
  `bin/ai-qwen`; no extraction or double-billing conclusion was made.
- #166 is OPEN and unassigned. It must run last.
- Parent #159 remains OPEN and unassigned.

## 4. Everything we tried that did NOT work

1. The original #164 ancestry gate used `git merge-base --is-ancestor`. It
   seemed natural for a merge commit, but real queue commits in this repository
   are synthetic squash trees and do not contain PR-head ancestry.
2. REST `commits/{sha}/pulls` seemed able to associate a live synthetic commit
   with its PR. Real run `34437374341` showed the association is empty while the
   commit is still queued, so the gate correctly failed closed.
3. The first GraphQL interpretation treated
   `mergeQueueEntry.headCommit.oid` as the PR head. Run `34439264770` proved it
   is the synthetic group SHA. The corrected query reads that field together
   with `pullRequest.headRefOid`.
4. A temporary missing-job injection landed through the queue because
   `merge-group-evidence` is not yet a required context and the current ruleset
   accepted a skipped Linux context. This did not weaken the final code; PR
   #370 removed the injection. #166 must require the evidence context directly.
5. The first #167 harness test used `set -u`. Independent review correctly
   found that failed `grep` or `cmp` commands could be masked by the final
   successful `printf`. Commit `c0199e8f` changed it to `set -euo pipefail`.
6. Two workflow-dispatch attempts used wrong input spellings and returned HTTP
   422; the valid key is `requester_task` (underscore), best passed with
   `--raw-field requester_task=issue-167`.
7. Repeating the exact-head manual matrix did not produce acceptance. Runs
   `34445127896` and `34445717137` both reached the existing 100-minute complete
   Windows ceiling. Do not repeat this deterministic failure without a targeted
   diagnosis or repair.

## 5. Root causes and key findings

- Merge-group identity must come from one atomic queue snapshot, not Git
  ancestry or the REST association endpoint. The synthetic group SHA is queue
  state, while `headRefOid` is the PR identity.
- The existing ruleset can accept a skipped dependent context. #166 must make
  `merge-group-evidence` itself required; indirect protection is insufficient.
- #167's helper consolidation is behavior-safe only for byte-equivalent helper
  contracts. The remaining local helper names are not automatically duplicate
  behavior.
- The complete fallback is now at the edge of its 100-minute bound. On
  `34445127896` the substantive suite succeeded seconds before the job was
  cancelled, showing the finalization allowance—not an assertion failure—was
  insufficient. The second run confirms this is repeatable on the current
  exact head. Any repair must preserve the complete matrix, not split, skip, or
  disable it.
- Ordinary PR run `34445087943` demonstrates the stable aggregate is independent
  of the four underlying section names/count. Continue relying on
  `windows-offline` only.

## 6. Exact next steps

1. Start in the existing #167 worktree. Re-read `AGENTS.md`,
   `docs/task-router.md`, this handoff, and the STATUS section of
   `plan_repo-throughput-restructure.md`. Fetch and re-verify `origin/main`, all
   open PRs/worktrees, #167 assignment, PR #371 head, and live CI. You will know
   this worked when no newer owner or conflicting #167 branch exists and the
   exact current SHA is recorded.
2. Inspect PR #371's new head after this handoff commit and read every review
   thread. Rebase/merge current `origin/main` only if required and only after
   confirming the worktree is clean. You will know it worked when GitHub reports
   the PR mergeable and the branch contains current upstream without losing the
   two #167 commits or this handoff.
3. Diagnose runs `34445127896` and `34445717137` before any rerun. Compare the
   complete Windows job's 100-minute timeout, actual suite duration, finalization
   time, and reviewer-safety timeout against the successful predecessor run
   `34444695949`. Make the smallest evidence-backed repair that preserves every
   suite and complete fallback; do not merely rerun unchanged. You will know it
   worked when the cause is stated with exact timings and a focused policy test
   fails before and passes after the repair.
4. Update `tests/verification/repo-throughput/issue-167-shared-harness.md` with
   the exact PR and complete-manual run IDs, timings, injected-failure result,
   and repair rationale. Keep the plan row honest if acceptance is still
   pending. You will know it worked when the document no longer says evidence
   will be recorded later and every claim points to a completed run.
5. Run the focused tests appropriate to any repair; do not run the local full
   suite while the Windows runner is active. Verify `git diff --check` and
   `git var GIT_COMMITTER_IDENT`, which must be Albert Hazan's GitHub noreply
   identity. Commit and push only owned files. You will know it worked when the
   worktree is clean and PR #371 points at the pushed commit.
6. Obtain a fresh exact-head read-only independent final review with the actual
   focused test command supplied. You will know it worked when the review names
   the exact PR head and ends `APPROVE`, with no unresolved review thread.
7. Wait through `bin/ai-pr-wait 371`, enqueue PR #371, and verify the merge-group
   gate and stable `windows-offline` context on the actual queued commit. Merge
   through the queue, fetch, and verify the resulting commit on `origin/main`.
   You will know it worked when PR #371 is MERGED, issue #167 is CLOSED, and the
   evidence/plan row are present on current `origin/main`.
8. Delete this handoff under the successor rule in the commit that genuinely
   finishes #167, after carrying #169/#166 obligations forward. You will know it
   worked when Git history retains the handoff but it is absent from the landed
   tree.
9. Re-inventory and confirm #169 is still unclaimed, claim it, and create a new
   current-upstream isolated worktree. First prove each provider's lock and paid
   uncertainty behavior, especially whether GLM, Kimi, or Qwen can double-bill
   without Grok's `remote-uncertain` protection. Extract only byte-equivalent or
   behavior-proven helpers in small reviewed batches. You will know it worked
   when provider-specific uncertainty and terminal tests pass, an exact-head
   review approves, the PR merges, and #169 closes with evidence.
10. Start #166 only after every other #159 child is closed. Reconcile PR #361
    and `tests/verification/repo-throughput/issue-210-blacksmith-baseline-20260910.md`
    before cutover. Require stable aggregate names rather than section counts,
    preserve scheduled/manual fallback and #260 reviewer coverage, run the
    throwaway failure matrix, obtain exact-head review, merge, verify main,
    close #166, and update #159. You will know it worked when all #159 children
    are closed and live ruleset evidence supports closing parent #159.

## 7. Constraints and gotchas in force

- Use a fresh isolated current-upstream worktree for every new issue; the
  canonical checkout is landing-only.
- Never push directly to `main`; use PRs and the merge queue. Albert does not
  merge these PRs—the session does.
- Do not weaken, delete, skip, split away, or replace assertions to meet a time
  budget. Preserve the scheduled/manual complete fallback and #260's fail-closed
  reviewer coverage.
- Do not infer merge-group ancestry. Use the atomic GraphQL binding already on
  main.
- Do not rerun a deterministic timeout without a targeted diagnostic or repair.
- Do not verify the same commit twice; the merge queue supplies exact landing
  verification.
- Reviewer wrappers, safety tests, evidence tooling, workflow safety, and
  installed routing changes require exact-head independent read-only review.
- Use bounded event-aware waiting (`bin/ai-pr-wait`). Surface failures and queue
  ejections immediately.
- The repository is public. Never commit raw transcripts, licensed data,
  secrets, `.env` files, or private artifacts.
- Production/shared cloud and shared database are read-only by default. This
  session did not touch `u2giants/shared-db`, dispatch agents, or own the live
  shared-db orchestrator marker #2669.

## 8. Access and environment

- Machine: `edge-dev` on Windows; shell is PowerShell, with Git Bash at
  `C:\Program Files\Git\bin\bash.exe` for Bash tests.
- `gh` is authenticated as the repository owner identity and could read/comment
  issues, run workflows, open/merge PRs, and inspect Actions.
- Git commit identity was verified during both #164 and #167 commits as
  `Albert Hazan <u2giants@users.noreply.github.com>`; recheck before the next
  commit.
- Secrets, if ever needed, belong in 1Password vault `vibe_coding`; none were
  read or changed in this session. Added diff lines were scanned for credential,
  connection-string, `.env`, and embedded-auth URL patterns; zero matched.
- Relevant local review artifacts are under the #167 worktree's ignored
  `.ai/reviews/` directory. They are not committed evidence and may be machine
  local, so the run IDs and verdicts above are the durable summary.

## 9. Open questions and risks

- Exact cause/risk to resolve: whether the 100-minute complete Windows timeout
  simply lacks finalization headroom after the added suite, or whether a
  particular migrated provider suite slowed materially. The two exact-head
  manual runs establish repeatability but do not identify which suite consumed
  the time. Diagnose from the complete suite timing block before changing the
  bound.
- PR #371 was based on `8f349f49`, while `origin/main` advanced to `6c3042db` by
  closeout. GitHub reported it mergeable/clean, but the next session must
  re-resolve current state before changing anything.
- The branch STATUS row says #167 is done while the live issue and PR remain
  open. Treat it as the intended post-merge row, not current acceptance; amend
  it if PR #371 cannot be completed in the next repair.
- #169's double-billing question is unresolved. No shared abstraction is safe
  until provider-specific paid-work uncertainty behavior is proven.
- #166's ruleset cutover is intentionally deferred and remains the final child.
  Parent #159 must not be closed early.
- Closeout found one stale handoff whose issue is already closed:
  `HANDOFF.d/2026-09-01T1709Z-edge-dev-codex-issue-161-fast-ci.md`, owner
  `codex/issue-161-fast-ci`, issue #161. Do not edit it. The next session may
  delete it only after the successor-rule checks prove its commitments and
  unique decisions are carried into the live plan or this handoff.

## Handoff self-audit

1. **Yes, a new developer can continue without asking a question.** Sections
   1–3 define the repository, goal, exact branches/SHAs/runs, and unfinished
   state; section 6 gives ordered commands/actions and success gates.
2. **Yes, they can continue as effectively as this session.** Sections 4–5
   preserve every significant dead end and non-obvious merge-group, reviewer,
   and timeout finding; sections 7–8 preserve operating constraints and access.
3. **Yes, every execution-relevant detail is present.** Background/goals are in
   sections 1–2, live state/evidence in 3, failures in 4, findings in 5, exact
   actions in 6, constraints/access in 7–8, and unresolved risks in 9. The only
   deliberately omitted material is secret values, because none belong here.
4. **Yes, Albert would see every needed decision in section 0.** A line-by-line
   sweep of sections 1–9 found no unresolved owner choice: the sequence, safety
   boundaries, provider policy, and final-cutover order were already decided.
   Section 0 consolidates those settled decisions and says not to re-ask them.
