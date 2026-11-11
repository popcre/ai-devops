---
summary: Plan for issue 988 scheduled full verification failing; confirm new runner lane passes, harden one flaky fixture, close.
kind: plan
status: open
read-when: Fixing the scheduled full verification failure (issue 988)
---

# Implementation plan — popcre/ai-devops#988: scheduled full verification failing

Written 2026-11-04 3:54 PM EST by a read-only planning session (Claude). Handoff link: none yet — the implementing session must create its own `HANDOFF.d/<UTC>-<machine>-<agent>-988-scheduled-verify.md` linking to this plan (per `implementation-plan-writer` mechanics); this plan was written to a scratch location because the planning session was read-only.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Confirm the new runner lane passes the complete matrix | ⬜ open | — |
| 2 Watch the next scheduled run (Mon 2026-11-09 1:17 AM EST) | ⬜ open | — |
| 3 Fix any test that fails deterministically on GitHub-hosted Windows | ⬜ open (may be N/A) | — |
| 4 Harden the one known timing-flaky admission fixture only if it recurs | ⬜ open (conditional) | — |
| 5 Close #988 with run evidence | ⬜ open | — |

**Start at step 1.**

## 1. Ultimate goal

Albert wants the weekly "full check" of the AI toolkit to come back clean so a red result means something real. Today it has been red every Monday for six weeks, so nobody trusts it and the auto-filed issue #988 is just noise. Done = the weekly scheduled run is green (or any red is a real, fixed bug), and #988 is closed with proof. **If a step conflicts with this goal, the goal wins — stop and flag it.** Skinny mindset: do the least that makes the weekly signal trustworthy; do not add new infrastructure, checks, or gates (owner rulings 2026-10-29/2026-10-30 in `docs/owner-rulings.md`: lean required checks; reviews advisory).

## 2. What this application is

`popcre/ai-devops` (public) is Albert's AI-tooling toolkit: Bash/PowerShell/Python scripts in `bin/`, skills, installers, and their test suites in `tests/`. CI workflow `.github/workflows/verify.yml` runs the suites. A `schedule` trigger (`cron: '17 6 * * 1'`, line 19 = Mondays 06:17 UTC = 1:17 AM EST) runs the **complete** matrix: `linux-offline` plus `windows-offline-complete` (5 parallel Windows sections, job defined ~line 420, `runs-on: windows-2025`). Job `report-scheduled-failure` (~line 560) calls `tools/ci/report-scheduled-failure.sh`, which comments on #988 when the scheduled run fails.

## 3. What triggered this work

Issue #988 accumulates an auto-comment for every failed scheduled run. Scheduled `verify` runs (`gh run list -R popcre/ai-devops -w verify --event schedule`): 36431640097 (09-28), 37325796725 (10-05), 38269588229 (10-12), 39257947847 (10-19), 40326717284 (10-26), 41475024326 (11-02) — all `failure`, every time only `windows-offline-complete` (the 09-28-era comment also showed capacity timeouts).

## 4. Scope

In: making the scheduled complete matrix green; fixing a specific test proven to fail on the current runner; closing #988.
NOT in this plan: changing required checks or rulesets; changing the runner pool/router (#2339/#2345/#2347 own that); rewriting `report-scheduled-failure.sh`; touching `pull_request`/`merge_group` lanes; broad "deflake Windows" sweeps; the separate merge-queue failure 41908084621 (2026-11-04) unless it is the same test.

## 5. Current state

- Every failing scheduled run ran Windows jobs on **Blacksmith** runners (log line `Runner name: 'blacksmith-4vcpu-windows-2025-…'`, machine `BLACKSMITH-WIN`) even though the YAML says `windows-2025`.
- PR #2339 "ci: take Blacksmith out of the runner pool" (merged this week), then #2345 (edge-dev3-first router) and #2347 (user namespaces on GitHub-hosted Linux). No scheduled run has happened since; the next is Mon 2026-11-09 1:17 AM EST.
- A manual (`workflow_dispatch`) complete run 41153031732 on 2026-10-31 (head fba518eb) passed all five `windows-offline-complete` sections — proof the suite *can* pass in full.

## 6. Key findings / root cause

The failing tests differ every week and are Windows-environment/timing sensitive, not one code bug:
- 11-02: `tests/test-ai-gh-admission.py:161` `test_pr_waiter_keeps_ticket_past_old_short_default` → `wait_for` (line ~80) gave up after its fixed **8-second** budget ("fixture did not reach expected admission state"); suite `test-ai-gh.sh` took 694 s, i.e. a slow machine.
- 10-26: five `CreditTests` failures + installation-authority tests.
- 10-19 / 10-12: POSIX permission / symlink tests (`root mode 700`, `refuses a symlink root`, `deepseek_private_diagnostic_permissions`, `symlink entry -> kept`), stepfun blankline tests.
Rotating failures + all on Blacksmith Windows + a green full run elsewhere ⇒ **verdict: runner-environment flakiness (Blacksmith Windows: slow, different filesystem/permission semantics), largely already addressed by #2339.** Not a code regression.

## 7. Rejected approaches

- Re-diagnosing each week's failure as a code bug — failures rotate; would chase ghosts.
- Marking the Windows complete lane advisory / dropping it from schedule — removes the capability (standing rule: preserve capability).
- Blanket retries or raising all timeouts — symptom suppression.
- Rerunning old failed runs — they ran on a pool that no longer exists; proves nothing.

## 8. Decisions

Locked: runner pool choices from #2339/#2345/#2347 (do not revert); lean required checks (owner ruling 2026-10-30); the scheduled run keeps the complete Windows matrix.
Open (implementer judgment): whether step 4 is needed (only if the same admission test fails again on GitHub-hosted); exact timing budget value (criterion: env-tunable, default ≥ 30 s, still fails fast on real hang).

## 9. Steps

1. **Prove the new lane now.** Dispatch `verify` on `main` with the complete/expensive option (read `manual-preflight` job inputs in `verify.yml` for the exact input name; run `gh workflow run verify.yml -R popcre/ai-devops --ref main -f <input>=…`). Wait with `bin/ai-pr-wait`-style bounded waiting (background), not a sleep loop. Confirm in the job log `Runner name:` is a GitHub-hosted image (not `blacksmith-`). *Gate:* all `windows-offline-complete (1..5)` = success on GitHub-hosted runners.
2. **Watch the scheduled run** of 2026-11-09 1:17 AM EST (`gh run list -w verify --event schedule --limit 1`). Independent of step 1. *Gate:* conclusion success and no new #988 comment.
3. **If either run fails:** save `gh run view <id> --log-failed` to `$TMPDIR`, grep `FAIL`. If a test fails on GitHub-hosted Windows and reproduces on a second run, fix that test or the code under test in its own file (e.g. a POSIX-mode assertion needs a Windows-appropriate check, as other suites do). One PR per failing area, branch from `main`, never push to `main`. *Gate:* a fresh dispatch is green.
4. **Conditional: admission fixture.** Only if `test_pr_waiter_keeps_ticket_past_old_short_default` / `test_generic_waiter_…` fail again: in `tests/test-ai-gh-admission.py` `wait_for`, replace the hard-coded `8` with an env-overridable budget (e.g. `AI_TEST_ADMISSION_WAIT_SECONDS`, default 30). *Gate:* `python tests/test-ai-gh-admission.py` passes locally and in the next complete run.
5. **Close #988** with a signed comment (`$AI_GH_SIGNATURE`) citing the green scheduled run id (and dispatch run id). If step 2 was green, step 5 needs no code at all. *Gate:* issue closed; the following Monday the reporter re-opens/comments only on a real failure.

## 10. Tests

No new tests unless step 3/4 fires. Must stay green: complete `verify` matrix (`linux-offline`, `windows-offline-complete` 1–5). For step 4: `tests/test-ai-gh-admission.py` (17 tests) and `tests/test-ai-gh.sh` section "FIFO admission…".

## 11. Constraints / gotchas

- Do not rerun or cancel others' runs; dispatching one new run is fine (public repo — Actions minutes free).
- A local run can cancel live CI on the same ref concurrency group — dispatch, don't push spam.
- `windows-offline-complete` is skipped on `pull_request`/`merge_group` (line ~426) — PR CI will not prove a Windows fix; use dispatch.
- Times to Albert in EST. Commit as Albert's verified identity; sign GitHub posts. Worktree per write task.

## 12. Access

`gh` authenticated for `popcre/ai-devops` (u2giants identity). No secrets needed. Local Python 3 + bash for step 4.

## 13. Done + risks

Done: scheduled run 2026-11-09 (or later) green on GitHub-hosted Windows; any fix PR merged with CI green; #988 closed with run ids; STATUS table updated. Risks: GitHub-hosted Windows may be slower → timing flake persists (step 4); 105-min section bound could be hit (earlier run 34856869730) → partition, not timeout bump. Rollback: revert the specific test PR.
Open question: none for the owner.

## Self-audit

1. Fresh session can execute without asking? Yes — §2 names the workflow/lines, §9 gives commands and gates, §11 the traps (dispatch-only Windows proof).
2. All background incl. ruled-out paths? Yes — §5–§7: run ids, runner evidence, per-week failures, rejected options.
3. Goal clear enough for judgment calls? Yes — §1: trustworthy weekly signal, skinny, preserve capability. Gap found: handoff link absent because session was read-only; §header instructs implementer to create it.
