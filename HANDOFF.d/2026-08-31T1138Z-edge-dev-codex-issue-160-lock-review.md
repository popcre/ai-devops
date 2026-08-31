---
issue: 160
status: OPEN
owner: codex/issue-160-reviewer-determinism
---

# HANDOFF — issue #160 lock review follow-up (2026-08-31T1138Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert. Continue the authorized repair,
testing, independent review, pull request, merge queue, and merge. Do not ask to
weaken, skip, quarantine, or retry away a safety assertion.

Already settled — do not re-ask:

- 2026-08-28: parent #159 owns the full throughput outcome and #160–#169 are its
  executable children; #166 is the final cutover and always runs last.
- 2026-08-31: reviewer safety capability must be preserved. A cancelled run,
  stale review, partial suite, or pass on a different tree is not acceptance.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public backup-and-restore toolkit for its
multi-model AI development workflow. It contains Bash and PowerShell commands,
reviewer safety wrappers, skills, configuration templates, documentation, and
offline tests. It is not a hosted application and has no application database.
GitHub is the source of truth; installation is deployment. This work runs in the
Windows worktree `C:\repos\ai-devops-throughput-160` on host `edge-dev`.

## 2. What we set out to do this session, and why

Continue parent issue #159 from child #160 and finish deterministic reviewer
safety under realistic Windows load. The inherited repair prevented an old Kimi
worker from deleting a successor's repository lock after terminal cleanup. The
required closeout is: focused and full tests on the final tree, exact-head
independent approval, pull request and merge-queue CI, merge to `origin/main`,
issue/evidence agreement, downstream plan drift audit, then a fresh #161 session.

## 3. Current state — what is true right now

- Branch: `codex/issue-160-reviewer-determinism`.
- Remote branch exists. Local committed head before this handoff commit is
  `e6dbd3f24a0a32f31219e7c124da994d3c2c960b`; it is one commit ahead of the
  prior remote handoff head `d80d2f9`.
- Commit `e6dbd3f` contains the atomic private-release-path repair, its first
  successor-reacquisition test, updated plan status, and evidence. It is not
  approved: exact-head review `20260831T083632-2688225-3701` rejected it.
- The review found a valid second branch at `bin/ai-kimi` function
  `release_review_worker_resources`: if the public lock owner changed before the
  atomic rename, `owned_repo_lock` still pointed at the public successor path,
  so the EXIT trap could delete it.
- The uncommitted follow-up in `bin/ai-kimi` clears the EXIT trap's public-path
  target when the recorded owner is no longer the worker. The uncommitted test
  in `tests/test-ai-kimi.sh` deterministically replaces the lock before owner
  validation and proves the successor directory and `test-replaced` label
  survive while the job records `repository-lock-release-failed`.
- The focused Kimi suite passed **207/207** on this uncommitted repair. It also
  passed the existing Windows spaced-state-path assertion that failed once in
  the rejecting review's sealed test run.
- A complete Windows run on the earlier `e6dbd3f` tree passed all **61 Bash
  suites** and **17 PowerShell suites**, zero failures, in **4,014.1 seconds**
  (`2026-08-31T06:44:24Z` to `07:51:18Z`). That proof became stale after the
  reviewer-driven code change.
- The required fresh full run on the current uncommitted repair started
  `2026-08-31T10:35:06Z` on an idle machine. It reproduced the known Grok
  readiness race: **196/199**, failing
  `different_named_sessions_can_ask_concurrently`,
  `same_next_ask_turn_is_serialized`, and
  `uncertain_ask_blocks_its_exact_retry` after 150-second silent windows. The
  Kimi suite inside that same run passed **207/207**. Because the run could no
  longer be acceptance evidence, this session stopped its own remaining test
  process after Kimi completed; there is no complete Windows summary for this
  final tree.
- The three current uncommitted files are `bin/ai-kimi`,
  `tests/test-ai-kimi.sh`, and
  `tests/verification/reviewer-reliability/issue-160-determinism.md`, plus this
  new handoff. Preserve them exactly.
- No pull request exists for #160. Issue #160 and parent #159 remain open. No
  deployment or live application exists.

## 4. Everything we tried that did NOT work

1. Merge-group run `33345342011` was allowed to finish before local testing. Its
   Linux and focused Windows jobs passed, but `windows-offline` was cancelled at
   75 minutes when the merge queue ejected it. A cancellation is not a test
   result and supplied no acceptance proof.
2. Several newer PR runs occupied both self-hosted Windows runners for hours.
   Local suites were deliberately not started during that time because local
   reviewer processes can cancel or contaminate CI on the same host. Waiting was
   correct; borrowing the idle-looking second registration would not have been.
3. Exact-head review `20260831T083632-2688225-3701` rejected `e6dbd3f`. The
   atomic post-rename reacquisition test did not cover ownership changing before
   the rename, and the EXIT trap could still delete that successor. Do not
   restore the combined owner/release-path conditional.
4. That review's exact-source Kimi run reported 205 passes and one failure in
   the existing spaced-state-path assertion. The identical committed tree had
   passed 206/206 locally and in the full Windows suite, and the final repair
   later passed it at 207/207. Do not remove or allow-fail the assertion; retain
   it and diagnose only if it fails again with preserved evidence.
5. The fresh full run on the final repair was not green because the same three
   Grok readiness assertions failed under load. Merely rerunning, raising the
   150-second window, or deleting assertions is forbidden. The failure is the
   core #160 condition and needs diagnosis from the exact latest fixture state.

## 5. Root causes and key findings

- `release_review_worker_resources` must never leave the EXIT trap pointing at a
  public lock whose ownership is no longer proven. Successful release atomically
  renames the worker-owned public directory to `${repo_lock}.releasing.<pid>`;
  ownership mismatch must instead clear `owned_repo_lock` before returning.
- Two distinct races require two tests: replacement before owner validation and
  reacquisition after atomic rename. Both successor directories must survive.
- `lock_release` intentionally ignores deletion errors, so terminal publication
  must verify the private release path is absent. Cleanup failure remains typed
  `recovery-required`; do not publish readiness from uncertain cleanup.
- The Grok failure signature is unchanged from runs `33292673304` and
  `33343417980`: progress advances, then the watched fixture is silent for 150
  seconds while healthy/expected work may still be happening outside the sensed
  boundary. The final local run again failed exactly the three named readiness
  assertions at 196/199. This is evidence, not permission for a retry loop.
- `windows-offline` and `windows-reviewer-safety` share the same physical
  `edge-dev` host with local reviewer suites. Runner registrations being separate
  does not make parallel local testing safe.

## 6. Exact next steps

1. Start by reading `AGENTS.md`, this file, the previous
   `HANDOFF.d/2026-08-31T0056Z-edge-dev-codex-issue-160-reviewer-determinism.md`,
   and `plan_repo-throughput-restructure.md`. Inspect `git status`, the exact
   diff, live CI, and both runner busy flags. You will know this worked when the
   four handed-off files are intact and no same-machine CI is active.
2. Reproduce the three Grok failures with the narrow suite and preserved logs;
   inspect which real preparation activity is outside the current progress
   fingerprint. Do not alter ceilings first. You will know the diagnosis is
   adequate when the log distinguishes a genuinely hung worker from healthy
   quiet preparation and names the unsensed activity.
3. Repair the progress boundary or event signal without allowing unrelated work
   to hide a stall. Add a deterministic regression if a new unsensed phase is
   found. You will know it worked when all three named assertions pass and the
   guarded hang/early-return defects still fail closed.
4. Run `C:\Program Files\Git\bin\bash.exe tests/test-ai-kimi.sh`; expect at least
   207 checks, including both successor-lock tests. Then run the focused Grok
   suite. You will know this worked when both are zero-failure and assertion
   counts have not decreased.
5. With all GitHub Windows jobs terminal and both runner registrations idle, run
   `pwsh -NoProfile -File tests/test-all.ps1`. Record exact start/end, elapsed,
   hostname, load, head/tree/diff digest, and counts. You will know this worked
   only when all 61 Bash suites and all 17 PowerShell suites pass, including
   Grok 199/199 and Kimi at least 207/207.
6. Update the evidence and plan only with proven final-tree results. Run
   `git diff --check`, verify `git var GIT_COMMITTER_IDENT`, and commit only the
   owned files. Fetch/reconcile `origin/main` before review. You will know this
   worked when the tree is clean and the branch is based on current main.
7. Run a fresh read-only exact-head `ai-codex-review final-check` with the
   focused reviewer test command. Any head change invalidates it. Repair every
   valid finding and repeat proportionate tests/review. You will know this worked
   when the report says `APPROVE`, names the exact commit, and its sealed tests
   pass.
8. Push, open the #160 pull request, enter the merge queue, and monitor with
   `bin/ai-pr-wait <pr>`. Do not hand-roll polling. You will know this worked when
   exact PR and merge-group checks are green, the PR is merged, and the merge is
   present on `origin/main`.
9. Close #160 only after issue, evidence, and plan agree. Reread live #161,
   #162, #163, #164, #167, #169, #168, and #166-last specs; record drift and
   update remaining phases if needed. Retire both #160 handoffs only in the
   completion commit when their obligations are carried forward. You will know
   this worked when #160 is closed, #159 remains open, and a fresh #161 handoff
   exists.

## 7. Constraints and gotchas in force

- Preserve every paid-review safety capability; never raise timeouts, delete an
  assertion, allow-fail, quarantine, conceal readiness failures, or retry until
  green as a substitute for diagnosis.
- Use explicit Git Bash on Windows. Bare `bash` may invoke unavailable WSL.
- Never run local reviewer suites while any CI job is active on `edge-dev`.
- Loaded repetition is serial per machine. Parallel copies change the tested
  contention.
- Work on the branch and pull-request path; never push directly to `main`, force
  push, reset, clean, or broadly stage.
- Verify Albert's Git identity before each commit and stage only owned paths.
- Exact-head review becomes stale after every commit, rebase, merge, or evidence
  edit. Required-check cutover #166 remains last.
- Do not edit either existing handoff. Presence means the workstream remains
  open; delete them only after #160 genuinely lands.

## 8. Access and environment

- Worktree: `C:\repos\ai-devops-throughput-160`; branch
  `codex/issue-160-reviewer-determinism`; host `edge-dev`.
- Repository: `https://github.com/popcre/ai-devops`; authenticated `gh` access
  was working. Git identity was
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Tools: PowerShell 7, Git Bash at
  `C:\Program Files\Git\bin\bash.exe`, GitHub CLI, and repository reviewer
  wrappers.
- Offline tests require no secrets. Any paid/live provider credential belongs
  in 1Password vault `vibe_coding`; never print or commit values. This session
  used offline test stubs and the configured read-only Codex reviewer.
- Local reviewer issue audit previously reported no recorded issues. Re-audit
  before final repair completion and resolve any newly affected record per
  `docs/reviewer-issues.md`.

## 9. Open questions and risks

- Evidence question: which current Grok preparation phase remains invisible to
  the progress fingerprint during the 150-second quiet period? This is resolved
  by logs/code/tests, not an owner decision.
- Risk: another PR may occupy either Windows runner between local phases. Recheck
  immediately before every local reviewer or full-suite start.
- Risk: the test-only pre-owner replacement hook uses a deterministic simulated
  successor. Independent review must confirm it covers the dangerous branch
  without changing production behavior.
- Risk: repeated documentation edits after approval invalidate exact-head
  review. Make evidence final before the approving run.

## Handoff self-audit

1. **Yes — a brand-new developer can continue without chat.** Sections 1–3
   define the repository, goal, branch, commits, files, tests, review result, and
   exact unfinished state; section 6 supplies executable gates.
2. **Yes — the developer has all session knowledge.** Sections 4–5 preserve the
   queue cancellation, runner collision, rejected-review branches, transient
   spaced-path result, and repeated Grok failure signature.
3. **Yes — every required execution dimension is present.** Background and goal
   are in §§1–2; current state and evidence in §3; failed attempts in §4; root
   causes in §5; ordered work in §6; constraints/access/risks in §§7–9.
4. **Yes — section 0 is complete.** A line-by-line sweep of §§1–9 found no owner
   approval or judgement request. All remaining questions are evidence-bound;
   the two settled owner instructions are listed in §0 so they are not re-asked.

The objective checklist also passes: all sections 0–9 exist, secrets are named
only by vault, commit/push/deployment state is explicit, failed work is retained,
and every next step has a verification condition.
