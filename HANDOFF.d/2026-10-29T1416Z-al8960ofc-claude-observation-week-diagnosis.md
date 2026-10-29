---
issue: 1948
status: OPEN
owner: claude/observation-week-diagnosis-handoff
---

# HANDOFF — reviewer observation week: diagnosis and fixes (2026-10-29T14:16Z, al8960ofc/claude)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

1. **Do shared-db changes need a reviewer APPROVE before merge?** Conflicting rulings:
   - shared-db's 2026-10-15 ruling says it gets no reviewers.
   - The plan ([plan_reviewer-observation-week.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-observation-week.md)) says "shared-db keeps the full gate".
   - The globals say reviews are required only in shared-db.
   - Albert said on Oct 25 (shared-db #4700): "forget the review. this repo doesn't need reviews. proceed without one".

   Ask Albert once. Record the answer in [docs/owner-rulings.md](https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md), then align globals and the plan.
2. **Freeze lift.** Albert said "stop" on Oct 29 at about 10:10 AM EDT. Do NOT lift the freeze or start the fixes until he says to resume.

## 1. What this application is

`popcre/ai-devops` is Albert's AI toolkit. It includes the reviewer harness (`ai-review`, door scripts per reviewer: Muse, GLM, DeepSeek, StepFun), the safety gates (`ai-task-gates`), and the installer that puts them on every machine (edge-dev3, hetz, al8960ofc/4837, edge-dev, 916).

## 2. What we set out to do, and why

- **Issue #1948:** run a 7-day reviewer observation week, so reviewer failures could be measured instead of guessed.
  - Built: fast-fail, per-session skip, `--detach`, the week merge gate, and a post-hoc tool.
  - Merged in PR #1952.
  - Installed fleet-wide; freeze declared Oct 22 at 9:56 AM EDT.
- **Albert's Oct 29 ask:** "today is the 8th day of the freeze, we need to diagnose what happened and how to fix".
- **Albert's correction:** the first diagnosis used only reviewer event logs and missed most problems ("we've had WAY more problems across all reviewers. are you only looking at the logs?").

## 3. Current state — true right now

- **Freeze:** still ON. The window file is present on all 5 hosts, and its 7 days ended Oct 29 at 9:56 AM EDT. It has not been lifted, per Albert's "stop".
- **Log diagnosis:** posted at https://github.com/popcre/ai-devops/issues/1948#issuecomment-6497102610. All hosts:
  - Muse: ~334 runs, ~16 failures.
  - GLM: ~126 runs, ~19 failures.
  - DeepSeek: ~160 runs, ~49 failures.
  - StepFun: ~112 runs, ~46 failures.
- **Transcript diagnosis:** PARTIAL.
  - Done: hetz (78 transcripts) and al8960ofc (148). Findings are in §5.
  - NOT done: edge-dev (326) and edge-dev3 (489). Their copies are in Albert's Dropbox `ai/chat_transcripts/<machine>/`. Both scans were stopped at Albert's "stop".
  - The Dropbox backups for hetz, 4837 and 916 have no files after Oct 22, so read those machines live.
- **Branch:** `claude/observation-week-steps1-4` is landed via PR #1952 (merged).

## 4. Tried and did NOT work

- **Diagnosing from reviewer event logs alone:** it undercounts. Logs miss quota exhaustion, sessions idling, sessions giving up, unreviewed merges, and lost results.
- **The `ai-pr-wait` waiter on Windows:** broken. Use the PR status view instead.
- **Muse reviews against a moving `origin/main` base:** voided. Pin `--base` to the merge-base.
- **Linux live checks with bytecode writing disabled (PYTHONDONTWRITEBYTECODE unset):** fail on `__pycache__` fixtures. Set it to 1.

## 5. Root causes and key findings

From the logs:
- **StepFun silent-start kills (31 runs; 12 edge-dev3, 19 hetz) are our own defect.**
  - The 300 s silence watcher killed healthy runs; healthy StepFun runs took up to 366 s.
  - The StepFun door writes its log only at the end. See `sf_rpc_turn` in [tools/lib/review-doors/stepfun.sh](https://github.com/popcre/ai-devops/blob/main/tools/lib/review-doors/stepfun.sh).
  - Fix: append a heartbeat to a file in the door TMPDIR on each RPC event. Interim: a ~600 s threshold for StepFun.
  - The approved StepFun stall fix PR #1993 and the DeepSeek/Muse draft PR #2000 were parked by the freeze (see #1999). Land those too.
- **DeepSeek "owned native review boundary refused" (27 runs) is a local refusal.**
  - It comes from [bin/ai-process-supervisor](https://github.com/popcre/ai-devops/blob/main/bin/ai-process-supervisor) at around line 981, `except (ValueError, OSError): die(...)`, which swallows the reason.
  - Fix: print the exception text, then fix the check it names.
- **About 45 failures were caused by the calling session, not the reviewer:** stale-source, source-identity-changed, tests-command-failed.

From the transcripts (hetz):
- An unreviewed production merge on Oct 26 at 8:04 PM EDT, in transcript `8d7b7e4a…`. All reviewers were skipped or failed, and StepFun was out of credit.
- Credit or rate-limit exhaustion: ~49 hits in 22 sessions. Nobody is warned before credit runs out.
- The shared-db replacement-reviewer tool sometimes picked the same reviewer again, or refused unknown failure codes: 18 sessions.
- Sessions idle-waiting on reviews: ~33 sessions, some for 40+ minutes. No wake-up arrives when a review finishes.
- "Durable store did not succeed … retaining sandbox": 16 sessions. Results were lost after a failure.
- Missing `docs/reviewer-rotation-rules.md` in some checkouts.
- No-verdict results: 20 sessions.

From the transcripts (al8960ofc): minor issues only.
- A false-alarm in a session's own watcher.
- The worktree guard refused a quoted `--tests` argument.

## 6. Exact next steps (only after Albert says resume)

1. Finish the transcript scans for edge-dev and edge-dev3 from Dropbox `ai/chat_transcripts/`. Use the same categories as §5.
2. Write `docs/reviewer-observation-week-2026-10-22.md`, the plan step 8 report, with log plus transcript findings. Post a summary on #1948.
3. Lift the freeze by deleting the window file on all 5 hosts:
   - Linux: `/etc/ai-devops/observation-week.json`. edge-dev3 needs sudo via 1Password item "edge-dev3 ahazan sudo password".
   - Windows: `C:\ProgramData\ai-devops\observation-week.json`.
   - Post freeze-end notes on #1783, #1822 and #1678.
4. Land the fixes, each with an exact-head review using `--tests` on edge-dev3, a merge, and a reviewed install:
   - The StepFun heartbeat.
   - The DeepSeek supervisor error text.
   - #1993 and #2000.
   - Then the transcript-found fixes: a credit-low warning, a review-done wake-up, and replacement-reviewer selection.
5. Run post-hoc reviews of shared-db #4680, #4682 and #4700 per Albert's §0 answer.
6. Done when: the report is merged, the freeze is lifted on 5/5 hosts, the fixes are installed, and #1948 is closed.

## 7. Constraints and gotchas in force

- During the freeze, do not change reviewer-safety or installation code. Run-to-run checker files are the exception (#2007).
- Do doc-safety runs on edge-dev3; Windows is too slow.
- Prose PRs merge with `gh pr merge --squash --admin` after `bin/ai-doc-safety`.
- Sign GitHub posts.
- Quote times in EDT.

## 8. Access and environment

- **edge-dev3:** user `ahazan`, LAN address in 1Password `vibe_coding`, ssh key `916-alien`. For op_run, use `-F none -o HostKeyAlias=edge-dev3`. Checkout: `/home/ahazan/repos/ai-devops`.
- **hetz:** `ssh -i ~/.ssh/916-alien root@hetz`. Checkout: `/worksp/ai-devops`. Use `python3`.
- **916:** checkout on `D:`.
- **Secrets:** 1Password `vibe_coding` only.

## 9. Open questions and risks

- edge-dev and edge-dev3 hold most of the reviews, so the biggest findings may still be unread.
- The freeze running past day 7 keeps known-broken StepFun behavior live.
