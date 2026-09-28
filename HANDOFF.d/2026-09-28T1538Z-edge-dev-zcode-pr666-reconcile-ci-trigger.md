---
issue: 989
status: OPEN
owner: zcode/pr666-reconcile (session sess_ab88a655)
---

# PR #666 sealed-review reconciliation landed; intermittent CI-trigger failure handed to issue #989

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Recoverable (wrong guess just costs rework):**

- **None needed to start.** Diagnosing issue #989 (why pushes sometimes create
  no verify run) is ordinary agent work: read-only analysis of workflow runs,
  then a fix through the normal branch + review + queue lane. Recommendation:
  do NOT ask Albert anything before the diagnosis; ask him only if the fix
  turns out to need a structural change (e.g. removing the merge queue, paying
  for a different runner pool, or changing the required-check contract).

**Already settled — do NOT re-ask:**

- 2026-09-26: the sealed private-review design (#666 + #881 + #882 + #883) is
  merged and approved; do not reopen the design.
- 2026-09-28 (this session): the manual `workflow_dispatch` workaround for
  missing runs is acceptable interim practice; it runs complete-lane checks
  and the merge queue accepts those check-runs.

**Not part of this work and nobody is on it:**

- Issue #989 itself (this is the handoff for it — the next session IS the owner
  once it picks it up).

## 1. What this application is

`popcre/ai-devops` is Albert's internal AI-operations toolkit repository: the
task-gate engine, reviewer wrappers (Grok, DeepSeek, Muse, StepFun, …), CI
workflows (`.github/workflows/verify.yml`), and shared test suites. All
machines install it; changes land through branch + pull request + merge queue.
Albert owns POP Creations and is not a programmer; sessions run the whole git
and CI mechanics themselves.

## 2. What we set out to do this session, and why

Albert pasted a self-contained prompt: reconcile PR #666 ("read-only private
code review", the sealed attachment-only DeepSeek export) with main's #702
rule ("keep formal review out of private repos"), then land or close it with a
decision, under the reviewer-safety task class with exact-head reviews before
any merge. That work is **finished** (see §3). While finishing it, the session
repeatedly hit pushes that produced no CI run; diagnosing that became issue
#989, which is the open workstream this handoff carries.

## 3. Current state — what is true right now

**Finished and verified on `origin/main` of `popcre/ai-devops`:**

- #666 (merge commit 5899e604): the reconciliation — new `code-only-review`
  gate action bound to the repository-declared `synthetic-fixtures-only`
  opt-in; `review` stays forbidden for both private classes.
- #881 (6990099a, by the concurrent session): front door strips inherited
  Git location variables.
- #882 (1a6aee9f): the opt-in enforced at `ai-review-sandbox ensure-code-only`
  itself.
- #883 (59f2875d): the export gate resolves before entering the tree,
  refuses relative-PATH resolution; StepFun suite Linux-gated; physical-path
  test normalization. Verified after merge by grepping `origin/main` for the
  fix markers (gate_bin_path ×4, planted-gate/TMP_PHYS fixtures ×4, StepFun
  gating ×2).

**Open (the reason this file exists):** issue #989 — pushes to PR branches
intermittently create no `pull_request`-triggered verify run. Affected heads
seen this session: 83917396, 35601a63, 6bbe027f, eb114918, ffb67986, 94302eb2
(branches `codex/readonly-private-review-20260920`, `zcode/pr666-export-optin`).
On the same branches, bd0b7d33, f0169dc9 and a486d036 DID get runs —
intermittent, not deterministic. Evidence detail is in the issue body.
Workaround in use: `gh workflow run verify.yml --ref <branch> -f
requester_task=… -f purpose=…` (runs complete-lane checks; the merge queue
accepts those check-runs on the head SHA).

## 4. Everything we tried that did NOT work

- **Waiting for the missing run to appear late** — none of the affected heads
  ever got a pull_request run, even an hour later.
- **`gh pr close` + `gh pr reopen`** on #882 (head eb114918 era) — did not
  trigger a `reopened` run either.
- **Deleting+re-pushing the branch** — not tried; judged too disruptive to the
  open PR at the time (do consider it as a deliberate reproduction step).
- **Treating it as a queue problem** — wrong: the merge queue itself worked
  (#666, #881, #882, #883 all merged through it); the gap is only the initial
  run creation for a pushed head.

## 5. Root causes and key findings

- The `[code]smith` check DID start on affected heads → the push event reached
  GitHub; only the `verify` workflow produced no run. So the event delivery is
  fine; the failure is between the event and verify's run creation.
- Prime suspect: the verify workflow's concurrency group
  `verify-verify-pull_request-pr-<n>` with `cancel-in-progress: true`
  (`.github/workflows/verify.yml`, ~lines 30-45), interacting with rapid
  successive pushes and with a second session pushing the same branch minutes
  apart. A cancelled-before-any-job run may leave no visible trace the CLI
  lists per-SHA.
- Second suspect: conditions on the first jobs (`fast-classifier`,
  `manual-preflight`) producing a run with no jobs that GitHub drops.
- Session-context trap worth knowing: a **concurrent ZCode session** worked
  the same PR throughout (it merged #666 and #881 itself). Every push race,
  rebase and review-voiding this session experienced traces back to that.
  Before pushing to any branch in this repo, `git fetch` and check the remote
  head.

## 6. Exact next steps

1. Reproduce cheaply: create a scratch branch off `origin/main`, open a draft
   PR, push 5-10 trivial commits a minute apart, and record for each whether
   `gh run list --branch <branch>` shows a `pull_request` run. You'll know it
   worked when you have at least one no-run reproduction with the push SHA,
   timestamp, and the codesmith check present.
2. Correlate: for each reproduction (and the six historical heads in issue
   #989), fetch `gh api repos/popcre/ai-devops/actions/runs?event=pull_request`
   around the timestamp and check for cancelled/empty runs. Gate: a written
   table of push → run-or-none → cancelled-run-or-none.
3. If the concurrency group is the cause, the fix is a workflow change (e.g.
   cancelling only same-SHA groups, or a short debounce) — take it through a
   normal branch + PR + review; reviewer-safety class applies
   (`ai-task-gates start --class reviewer-safety`). Gate: a PR merged whose
   head reproduces the old failure mode zero times over 10+ pushes.
4. Close issue #989 with the evidence, and delete this handoff file in the
   same change (successor rule). Gate: `gh issue view 989 --json state` says
   closed and this file is gone from `HANDOFF.d/`.

## 7. Constraints and gotchas in force

- Never push directly to protected `main`; branch + PR + merge queue; you
  merge it yourself. Sign every GitHub post: `Posted by ZCode chat <session
  id> on <machine>`, times in EST.
- Exact-head review discipline: an APPROVE binds its SHA; any push after
  approval voids it and needs a fresh review. The queue merges with
  `gh pr merge <n> --squash`; the queue's Windows jobs are selection-based
  (long jobs skipped on merge_group), but the PR-head gate wants green checks
  on the exact head — which is exactly what issue #989 breaks.
- A docs-only PR may be merged immediately with `--squash --admin`.
- Concurrency: check the remote branch head before every push; rebase rather
  than force-push shared PR branches; never edit another session's
  `HANDOFF.d/` file or the root `HANDOFF.md` pointer.

## 8. Access and environment

- Machine: `edge-dev`. Worktree for this session's work:
  `D:/repos/ai-devops-worktrees/pr666-reconcile-702` (this file is written
  there; push it via a docs-only PR from that worktree or move it to a fresh
  one).
- `gh` authenticated as Albert (u2giants); git identity verified this session
  as `Albert Hazan <u2giants@users.noreply.github.com>`.
- No credentials appeared this session; Grok reviewer runs through the
  authenticated wrapper (keys live in the toolkit's own stores, not in this
  handoff).

## 9. Open questions and risks

- Unknown whether the missing runs correlate with pushes made while a
  `workflow_dispatch` run for the same PR is in progress (both existed during
  this session's failures) — worth checking in step 2.
- Risk: because the workaround dispatch runs the COMPLETE suite set, it is
  slower and touches suites the pull-request lane would not select; two real
  main-breakages were found that way this session (already fixed and merged).
- The concurrent session (sess_d1069d40) that shared this workstream may still
  be active on adjacent follow-ups; its handoffs are in this same
  `HANDOFF.d/` directory — do not edit them.
