# HANDOFF — #1116 D1 land + flake fix (2026-09-30)

Status: OPEN — finish D1, then final report.
Machine: edge-dev. Session: ses_ffe5f109076cdffezkdxImMKg3. Written 2026-09-30T11:51Z.

## 1. What this work is

Parent issue https://github.com/popcre/ai-devops/issues/1116 — process re-cut children A1, A2, B1, C1–C4, D1 ranked by hours saved. Plan of record: `IMPLEMENTATION-PLAN.md` on branch `mimo/doctor-orphan-scan-guard` (worktree `C:\repos\ai-devops-wt-doctor-orphan-guard`), commits `ec684b56..9407b735`.

**Goal:** tick every child on #1116 with openable evidence, or record a hard external blocker with an owner.

## 2. What is already done (do not redo)

| Child | Evidence | Ticked on #1116 |
|---|---|---|
| **A1** P3 CI fast-fail | PR #1134 merged `f8f032ed`; `tests/test-verify-closure.sh` 35/35 + `tests/test-workflow-policy.sh` 102/102; live pair runs 36651631566 (negative) / 36653293397 (positive) | yes |
| **A2** P7 timeout ≠ broken reviewer | PR #1136 merged `cbe08f5d`; Muse APPROVE; `tests/test-reviewer-credit.sh` 59/0 after credit-hold grep fix (`60dfaeb7`); lifecycle 68/0 | yes |
| **B1** task/orphan TTL + reap | PR #1129 merged `c12470a5`; `tests/test-ai-blocker-watch-reap.sh` 20/20; live proof `tests/verification/blocker-watch/2026-09-30-b1-reap-live-proof.md` (18 reaped / 21 waiting kept; reviewer lease never freed on age) | yes |
| **C1–C4** docs | PR #1123 `b0779156` (handoff 10s/lease fix, 19 plans indexed, 5 fold markers) + PR #1124 `ff28e561` (decision ledger 3/9) | yes |

Plan STATUS rows for A1/A2/B1/C are committed on `mimo/doctor-orphan-scan-guard` (`daeb7c65`, `68353970`, `9407b735`).

## 3. What is left

### D1 — doctor orphan spawn guard (ONLY remaining child)

- **PR:** https://github.com/popcre/ai-devops/pull/1149 — head `d43df6c1` (OPEN)
- **Worktree:** `C:\repos\ai-devops-wt-1116-d1-orphan` branch `mimo/1116-d1-orphan-spawn-guard`
- **Code complete:** `bin/ai-glm` batches `stat` in 100-chunks (O(batches) not O(N)); named residual for `reconcile_implementation_records` in IMPLEMENTATION-PLAN.md §8 (step **2b**).
- **Tests:** `bash tests/test-ai-glm.sh` → 364 passed, 0 failed
  - `scanning 5 orphan sandboxes costs a bounded number of spawns` (7 spawns)
  - `scanning 50 orphan sandboxes costs the same spawn bound as 5` (7 spawns)
- **Reviewer:** Qwen APPROVE exact-head `d43df6c1` — `.ai/reviews/qwen-d1-orphan-final-check.md` (in the D1 worktree; `.ai/` is gitignored)
- **Blocked on:** merge queue keeps ejecting #1149 for an **unrelated pre-existing flake**.

### Flake blocking D1 (must fix first)

`tests/test-mcp-session-guard.sh` line 100 — Node hold helper is **Killed** (SIGKILL/OOM) on GitHub Linux runners. Offline runner counts `failures=1` in `linux-offline-shard (2)` with no named FAIL line.

Failed merge_group runs: `36666364771`, `36669546713`, `36670620125`, `36671715695` (and earlier `36665657825` class).

**Not D1's code** — `tests/test-ai-glm.sh` stays green. File exists on `origin/main` (blob `f9487b99…`); the landing checkout `C:\repos\ai-devops` may appear stale if not fetched.

**Repair intent (from two failed subagent attempts):**
1. Read `tests/test-mcp-session-guard.sh` around line 100 and `$GUARD`.
2. Harden: bounded waits + kill-aware assertion so a host kill cannot surface as an unexplained `Killed` with no check; keep coverage; print a clear summary line.
3. Run the suite ≥5 times locally; then `tests/test-ai-blocker-watch.sh`, `tests/test-ai-test-local.sh`.
4. Land the flake fix via a small PR (class `code`), then **re-queue #1149**.

### After D1 lands

1. Tick D1 on #1116 with PR merge SHA + `tests/test-ai-glm.sh` result + live proof (`ai-glm doctor` with ~20 seeded orphan dirs inside 10s) if not already captured; else open exactly one leftover-proof issue (`plan_live-proof-session-sizing`).
2. Update IMPLEMENTATION-PLAN.md STATUS for D1 + steps 7–8.
3. One short final report to Albert: children ticked with SHAs, any blockers, leftover-proof issues.

## 4. Discoveries that change how you work

1. **Subagents cannot use the `bash` tool in this environment.** Two flake-fix children (general-7 cancelled, general-8) failed: every Bash call is permission-denied (`bash`/`ask` collapses to deny with no approver). **Shell work must run in the parent session**, or bash must be pre-allowed for children. Do not dispatch a child that needs Git Bash unless that is fixed.
2. Canonical `C:\repos\ai-devops` is landing-only and often dirty/behind. Verify with `git show origin/main:<path>` rather than assuming the checkout is current.
3. `ai-gh` sometimes claims "already queued to merge" while `autoMergeRequest` is null — check `gh run list --event merge_group` for truth.
4. Merge-group failures are often flaky (`sed|grep -q` pipefail 141 was A1's class; Node Killed is this class). Re-queue is valid for ejects; fix only when the same test fails repeatedly.
5. Reviewer reports live under the implementer worktree `.ai/reviews/` (gitignored). Copy paths into the PR body / issue comments.

## 5. Locked (do not relitigate)

- No new root `plan_*.md`. No item 3 pin-only. No item 9 `ai-ci-status`. No loss ledger. **No lease TTL** (reviewer slots never freed on age).
- No wall-clock asserts as the primary guard (generous upper-bound is the only timing exception).
- Independent exact-head APPROVE before merge for reviewer-safety paths (`bin/ai-glm`, preflight/lifecycle, their tests).
- Branch + PR + merge queue only. Never push `main`. `bin/ai-gh` for GitHub. Git Bash (`C:\Program Files\Git\bin\bash.exe`), not WSL.
- `git var GIT_COMMITTER_IDENT` = `Albert Hazan <u2giants@users.noreply.github.com>`.
- Sign GitHub comments: `Posted by MiMo chat <id> on edge-dev`.
- One unproven live outcome per session; leftover-proof issue if code lands without live proof.
- `plan_live-proof-session-sizing.md` is frozen (except its index row note).

## 6. Exact next steps

1. Fix `tests/test-mcp-session-guard.sh` flake (parent session has shell) on its own PR; merge via queue.
2. Re-queue https://github.com/popcre/ai-devops/pull/1149 (`bin/ai-gh pr merge 1149 --repo popcre/ai-devops`).
3. When merged: tick D1 on #1116, update plan STATUS, final report to Albert.
4. If the flake cannot be fixed and keeps ejecting: record on #1116 as a hard external blocker (owner: CI test flake in `test-mcp-session-guard.sh`) and still tick D1 only if there is another authorized land path — do not fake-done.

## 7. Access

| Need | Location |
|---|---|
| D1 worktree | `C:\repos\ai-devops-wt-1116-d1-orphan` (`mimo/1116-d1-orphan-spawn-guard`, tip `d43df6c1`) |
| Plan worktree | `C:\repos\ai-devops-wt-doctor-orphan-guard` (`mimo/doctor-orphan-scan-guard`) |
| A2 worktree (A2 landed) | `C:\repos\ai-devops-wt-1116-a2` |
| Qwen APPROVE (D1) | `.ai/reviews/qwen-d1-orphan-final-check.md` in D1 worktree |
| Muse APPROVE (A2) | `.ai/reviews/muse-final-check-20260930T030948-2976801-12842.md` in A2 worktree |
| Parked wait brief | `C:\repos\ai-devops\.ai\parked\1116-coordinator-subagents-brief.md` |
| Git Bash | `C:\Program Files\Git\bin\bash.exe` |
| Test (D1) | `bash tests/test-ai-glm.sh` |
| Flake test | `bash tests/test-mcp-session-guard.sh` |

## 8. Reciprocal instruction

When D1 is done (or blocked with an owner), re-read IMPLEMENTATION-PLAN.md §9–13 and this handoff §3–5, and report any drift you introduced for later work (STATUS rows, residual wording, leftover-proof issues). Do not start new children beyond #1116.

## 9. Self-audit

- Brand-new session with no chat context can execute from this file + #1116 + IMPLEMENTATION-PLAN.md? **Yes** — remaining work is one flake fix, one re-queue, one tick, one report; SHAs and paths are named.
- All live state captured (done SHAs, PR head, flake run IDs, worktrees, lockeds)? **Yes.**
- Next-session prompt below is enough to start? **Yes.**
