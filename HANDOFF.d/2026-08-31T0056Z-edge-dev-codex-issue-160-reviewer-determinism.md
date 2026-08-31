---
issue: 159
status: OPEN
owner: codex/issue-160-reviewer-determinism
---

# Handoff — parent #159, current child #160

## 0. Owner decisions

No owner decision is open. Continue the authorized implementation and preserve
all reviewer safety capabilities. Do not weaken, bypass, remove, or quarantine
tests to obtain a pass.

## 1. Objective and completion contract

Implement parent #159 in the order defined by
`plan_repo-throughput-restructure.md`, with independent reviewer validation at
each safety step. Current work is child #160: deterministic reviewer safety
under realistic Windows load. #160 is complete only after its focused and full
tests pass on the final tree, the exact-head independent review approves, CI is
green, the PR merges through the queue, origin/main contains the merge, and the
issue/evidence/plan agree. Parent #159 remains open through children #161–#169;
#166 is always last.

## 2. Repository and exact working state

- Worktree: `C:\repos\ai-devops-throughput-160`
- Branch: `codex/issue-160-reviewer-determinism`
- Committed implementation head before this handoff: `96374d64fbdd3bc971f806f382bf9cae4cb79088`
- Machine: `edge-dev`
- Identity verified: `Albert Hazan <u2giants@users.noreply.github.com>`
- The branch was not present on origin before this handoff push.
- Preserve the uncommitted repair in `bin/ai-kimi`, `tests/test-ai-kimi.sh`,
  `tests/verification/reviewer-reliability/issue-160-determinism.md`, and
  `plan_repo-throughput-restructure.md`. Do not pull, reset, switch, clean, or
  overwrite before inspecting this exact diff.

The plan now explicitly requires #160 closeout to reread every downstream phase
through #166, report drift, and update remaining phase specs before handoff.

## 3. Completed work and proof

- #165 merged as PR #181 at merge
  `15991e63e53dbded3d52c218ff7f62430ef05bca`; issue #165 is closed.
- #160 previously achieved ten loaded serial Grok passes at 199/199 and ten
  loaded serial Kimi passes at 204/204, later 205/205 after cleanup coverage.
- Guarded defect injections passed.
- Two full Windows verification runs passed before the latest lock-handoff
  repair: 61 Bash suites and 17 PowerShell suites, zero failures; the later run
  took 4,480 seconds.
- Exact-head reviewer run `20260831T000304-1076947-9812` approved commit
  `b9c203c`, but later documentation changes made that approval stale.
- Reviewer run `20260831T004143-1251035-10407` rejected committed head
  `96374d6`: the old worker could delete a successor's repository lock after
  releasing it, and the evidence incorrectly described the earlier approval as
  exact-head.

## 4. Uncommitted repair awaiting proof

The repair atomically renames the owned public Kimi repository lock to a private
release path before terminal cleanup. The old worker's EXIT trap points only to
that private path, so a successor may safely acquire the public path without
the predecessor deleting it. Ownership requires the lock PID to equal the
current worker PID; release failure records `repository-lock-release-failed`.

The test-only `AI_KIMI_TEST_REACQUIRE_TERMINAL_LOCK=1` path creates a successor
lock immediately after the rename. The new `terminal-lock-reacquire` test
asserts that successor lock remains and bears label `test-reacquired`. An early
draft accidentally left an old public-path `lock_release` call; it has already
been removed. Re-inspect the final diff to confirm no predecessor cleanup can
delete the public successor path.

## 5. Live external work and collision boundary

Do not run any local reviewer suite while GitHub CI is active on this same
machine. At 2026-08-31T00:56Z merge-group run `33345342011` for head
`9e3d2fbcaa6558e671f628f28fd6c028a65e6168` was still active:

- Linux job `99348272577`: completed successfully.
- Focused Windows reviewer job `99348272750`: in progress.
- Full Windows job `99348272755`: in progress.

This run and its predecessor are on pre-repair code. Prior run `33343417980`
failed the known Grok readiness race with 193 passed and three failed
(`different_named_sessions_can_ask_concurrently`,
`same_next_ask_turn_is_serialized`, and
`uncertain_ask_blocks_its_exact_retry`); its full Windows job was cancelled.
Treat this as corroboration for #160, not proof of the uncommitted repair.

## 6. Exact next actions

1. Read `AGENTS.md`, this handoff, and the entire current plan. Inspect status
   and the complete uncommitted diff before changing anything.
2. Poll run `33345342011` and both Windows jobs. Wait until all same-machine CI
   is terminal; do useful read-only review while waiting.
3. Run the focused Kimi suite through
   `C:\Program Files\Git\bin\bash.exe tests/test-ai-kimi.sh`. The new test should
   increase the prior 205-test total by one; confirm the actual count rather
   than assuming it.
4. Re-run the relevant guarded lock/terminal defect coverage. Then run the full
   Windows offline verification because the safety-path code changed after the
   last full pass. Record exact counts, time, SHA/tree, hostname, and load.
5. Update the #160 evidence and plan only with proven results. Run diff checks,
   verify identity, and commit only task-owned files.
6. Obtain a fresh read-only independent exact-head final review. Any head
   change, including documentation, invalidates that approval. Repair all valid
   findings, retest proportionately, and review again until approved.
7. Reconcile current origin/main without losing concurrent work. If rebase or
   merge changes the head, rerun exact-head review. Push, open the #160 PR,
   enter the merge queue, monitor exact CI, merge, confirm origin/main, close
   #160, and update the parent evidence.
8. At #160 closeout, reread every downstream phase (#161, #162, #163, #164,
   #167, #169, #168, then #166 last), report any drift against the current
   repository/live GitHub state, update phase specs if needed, and use a fresh
   session for #161.

## 7. Constraints and rejected shortcuts

- Reviewer wrappers spend real money. Preserve refusal/wait semantics,
  terminal-state proof, remote-uncertain behavior, process-tree cleanup, and
  exact lock ownership.
- Loaded repetitions are serial per machine; parallel copies alter the tested
  contention.
- A green run, count alone, stale review, or pre-repair full suite is not final
  proof.
- Never merely raise timeouts, delete assertions, add allowed-to-fail behavior,
  or conceal readiness failures.
- Use Git Bash explicitly on Windows; bare `bash` may invoke unavailable WSL.
- Stage exact owned paths only; do not use broad staging, reset, clean, force
  push, or overwrite another session's work.
- Do not change required contexts or live rulesets until #166.

## 8. Downstream plan audit

The whole plan was reread through its final definition of done before writing
this handoff. The required order and dependencies remain coherent: finish #160;
then baseline/#161, #162, #163; then #164; perform dependent consolidation
#167/#169/#168; run #166 cutover last. The current #160 lock repair does not
invalidate a downstream target. The only handoff drift found was that A2 did
not explicitly require rereading all downstream phases at closeout; that
reciprocal instruction has been added to the plan and must remain.

## 9. Handoff self-audit

1. **Can a new session execute without chat? Yes.** The worktree, branch,
   committed base, uncommitted files, live CI handles, test/review gates, and
   next actions are explicit.
2. **Is material background and rejected reasoning preserved? Yes.** The
   approval/rejection chain, exact race, earlier test proof, collision boundary,
   and forbidden shortcuts are recorded.
3. **Are owner decisions separated from evidence questions? Yes.** No owner
   decision is open; remaining questions are resolved by tests, exact-head
   review, CI, and live GitHub state.
4. **Does the handoff cover the whole authorized job? Yes.** It preserves #160
   delivery and requires a downstream reread through final #166 and closure of
   parent #159.
