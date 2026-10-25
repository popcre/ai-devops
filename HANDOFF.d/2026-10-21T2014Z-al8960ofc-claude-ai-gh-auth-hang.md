---
issue: 1941
status: OPEN
owner: claude/handoff-1941
---

# Handoff — `ai-gh auth status` hangs on Windows (al8960ofc)

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner. It is a purely technical
tooling fault; the fix is AI work gated by the normal reviewer rules.

Already settled — do NOT re-ask: none.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's (POP Creations) shared AI-tooling toolkit:
wrappers for AI reviewers (GLM, Muse, StepFun, DeepSeek, …), GitHub helpers,
safety gates, and installers for every developer machine. al8960ofc is a Windows
11 developer computer whose installed toolkit checkout is the canonical install
(updated only by `bin/install-ai-devops-windows.ps1`).
Repo: https://github.com/popcre/ai-devops

## 2. What this session set out to do, and why

Original job (done): repair the reviewer failure "could not create the review
snapshot" (reviewer issue `20261021T141818Z-al8960ofc-glm-1871678`), run the
independent GLM final-check of
https://github.com/popcre/ai-devops/pull/1923 (Muse repin, 66e8fa0e), and
install the fix on al8960ofc and edge-dev3.

This handoff exists only for a fault found **during wrap-up** and deferred under
the scope freeze: the toolkit's GitHub wrapper can't confirm sign-in on al8960ofc.

## 3. Current state — what is true right now

Done and verified (2026-10-21):
- Fix merged: https://github.com/popcre/ai-devops/pull/1927 (commit
  https://github.com/popcre/ai-devops/commit/b86cff23368fe4a2aa2026a8e0ddeea81b38279c).
  A short-SHA expression base such as `66e8fa0e~1` was turned into the invalid
  ref `refs/heads/66e8fa0e~1`; now only real refs are recreated
  (https://github.com/popcre/ai-devops/blob/main/bin/ai-review-sandbox, `plan_snapshot`).
- GLM final-check of 66e8fa0e: APPROVE, posted at
  https://github.com/popcre/ai-devops/pull/1923#issuecomment-6319351092.
- Reviewer issue resolved with `ai-reviewer-issue resolve`.
- al8960ofc: protected installer ran at b86cff23 (launcher `source-sha` =
  b86cff23); live `ensure-copy` with base `66e8fa0e~1` succeeded.
- edge-dev3: another session had already installed 6f79a7c4 (newer, contains
  the fix; `/etc/ai-devops/install-manifest.tsv` attests it); live `ensure-copy`
  with the same base succeeded.

Open (this handoff): issue https://github.com/popcre/ai-devops/issues/1941.
- `timeout 30 bin/ai-gh auth status` → exit 124 after 32 s on al8960ofc.
- `bin/ai-gh api rate_limit` returns normally (core remaining 3706); plain
  `gh auth status` is instant (logged in as u2giants, file storage).
- Therefore `ai-housekeeping` prints "GitHub: UNKNOWN (GitHub unavailable)";
  gate at https://github.com/popcre/ai-devops/blob/main/bin/ai-housekeeping#L276-L280.
- Earlier, `bin/ai-pr-wait 1927 --repo popcre/ai-devops --timeout-minutes 9`
  never read the PR ("pr_status_singleflight.py … Traceback", then "GitHub
  client exited 125 without a diagnostic"). Possibly the same transport fault;
  unproven.
Nothing is half-edited; no code for #1941 has been written.

## 4. What did NOT work

- `ai-pr-wait` without `--repo` from a worktree: "cannot determine the
  repository; pass --repo". With `--repo` it still failed as above. Used
  `gh pr checks` / `gh api graphql … mergeQueueEntry` instead.
- First Windows `authorize-install` refused: the GLM approval had no test
  evidence. A review must be run with `--tests "<runnable command>"`.
  `tests/test-ai-review-sandbox.sh` exceeds 10 min on Windows; the
  `test-ai-review-snapshot-bounded-history.sh` suite has 4 pre-existing Windows
  failures (`source-repository-mismatch`, also on unchanged main). Passing
  Windows choice: `bash tests/test-ai-review-sandbox-delete-guard.sh && bash
  tests/test-ai-review-sandbox-self-cleanup.sh` (~5 min).
- Linux `update.sh` from a candidate refused "target is not a fast-forward" —
  because edge-dev3 was already past the target. Not an error to fix.

## 5. Root causes and key findings

- #1941 root cause is NOT known. Only `auth status` hangs; `api` calls work. Look
  at how https://github.com/popcre/ai-devops/blob/main/bin/ai-gh handles the
  `auth` subcommand (admission/singleflight path vs direct passthrough).
- Merge-queue runs flaked on unrelated tests twice (`PowerShell ordinary Windows
  sectioning still requires the reviewer split`, StepFun `paces_before_call`);
  re-queueing passed.

## 6. Exact next steps

1. Declare the class: `ai-task-gates start --class reviewer-safety` (or the
   class `ai-task-gates` assigns to `bin/ai-gh`). Gate: start succeeds.
2. On al8960ofc reproduce: `timeout 30 bin/ai-gh auth status; echo $?` → 124.
   Then trace (`bash -x bin/ai-gh auth status`) to find where it blocks.
   Gate: you can name the blocking line.
3. Fix the cause (never raise the timeout or drop the auth check in
   housekeeping). Add a regression test. Gate: `bin/ai-gh auth status` returns in
   < 5 s and `ai-housekeeping` prints "GitHub: available".
4. Check whether `ai-pr-wait <pr> --repo popcre/ai-devops` now reads a PR; if not,
   trace `tools/github-requests/pr_status_singleflight.py`. Gate: it reports
   check states.
5. PR, non-Claude exact-head review with `--tests`, merge, protected Windows
   install, tick #1941's boxes including live proof, delete this file.

## 7. Constraints and gotchas

- Never push to `main`; never `git pull` the installed checkout — only the
  protected installer advances it (docs/deployment.md).
- Reviewer-safety installs need: release live check
  (`ai-release-live-check fleet --target-head <sha>` from edge-dev3), an
  exact-head APPROVE **with tests**, `authorize-install` run with the
  candidate's own `bin/ai-task-gates`, then the candidate's
  `install-ai-devops-windows.ps1 -RepoPath <checkout> -ExpectedHead <sha>`.
- Don't delete the reviewer candidate worktree until after the installer
  finishes and any shell that ran it is gone.
- Times in EST/EDT.

## 8. Access and environment

- `gh` authenticated as `u2giants` on al8960ofc and edge-dev3 (`ssh edge-dev3`).
- No secrets were involved; 1Password vault `vibe_coding` if any are needed.

## 9. Open questions and risks

- (2026-10-21) Unknown whether the `ai-pr-wait` failure shares the cause; treat
  as separate until proven.
- Risk: while unfixed, housekeeping on al8960ofc cannot flag merged worktrees,
  so cleanup there must use `gh pr view` per branch.

Self-audit (2026-10-21): Q1 yes — §1–§3 give app, goal, state; Q2 yes — §4–§5
carry the dead ends and findings; Q3 yes — §6 steps with gates, §7 constraints,
§8 access; Q4 yes — swept for owner asks, none exist, §0 says so.

Posted by Claude chat f566b5aa-339a-4641-adee-39a87de6bf2d on al8960ofc
