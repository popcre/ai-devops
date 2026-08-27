# Issue #89 — post-fix run series on `edge-dev`

**Status: SERIES STOPPED AT 6 OF 10 RUNS. THE FIX IS REAL BUT NOT PROVEN, AND
ITERATION ON IT ENDED HERE BY OWNER DECISION (2026-08-27).**
**Captured:** 2026-08-27 by Claude (Opus 5) on `edge-dev` (Windows 11)
**Code under test:** `claude/flaky-reviewer-tests-timing-c1ba63` at `9aec837`
(PR [#123](https://github.com/popcre/ai-devops/pull/123) plus this session's
follow-up converting the last two silent waits to `poll_until`).

Read this before claiming issue #89 is fixed. It is not.

## Result so far

| Run | Seconds | Result |
|---|---|---|
| 1 | 795 | 191 passed, 0 failed |
| 2 | 728 | 191 passed, 0 failed |
| 3 | 816 | 191 passed, 0 failed |
| **4** | **990** | **190 passed, 1 failed** |
| 5 | 834 | 191 passed, 0 failed |
| 6 | 774 | 191 passed, 0 failed |
| 7–10 | — | **not run — series stopped** |

`bash tests/test-ai-grok-review.sh`, sequential, quiet machine, no other suite
running. Logs under the capture directory named in the session handoff.

**Why the series stopped at six.** Albert ended iteration on 2026-08-27 —
"if the first 25 iterations didn't work, it's not going to work on the 26th" —
after this problem had consumed two sessions for roughly 24 hours. That judgement
is correct and this file exists so the next attempt does not restart from zero.
Six runs at roughly 13 minutes each is about 80 minutes of evidence, and it is
enough to establish both of the findings below. What it is **not** enough for is
the plan's step 1.2 gate, which requires ten consecutive green runs on Windows CI
and is therefore still open.

## What run 4 actually said

```
  fixture: both named ask turns hold their own session locks did not hold within 180s (baseline 12s)
  FAIL different_named_sessions_can_ask_concurrently
  ok   same_next_ask_turn_is_serialized
  ok   uncertain_ask_blocks_its_exact_retry
  ok   uncertain_ask_blocks_changed_prompt_for_same_next_turn
  ok   uncertain_ask_does_not_block_other_named_session
```

## Read this carefully — two findings, and they point opposite ways

**The fix did something real.** Compare with the pre-fix baseline in
[`2026-08-27-merge-queue-ejection.md`](2026-08-27-merge-queue-ejection.md),
where **four** checks failed together:

- The blast radius shrank from **4 checks to 1**. The three checks that used to
  fall over with it all passed, because they no longer depend on a wait that gave
  up silently.
- The failure now **names itself as a fixture problem**, with the ceiling and the
  measured baseline. Before, it was an anonymous `FAIL` indistinguishable from a
  genuine paid-work locking regression. That was the single most expensive
  property of #89 and it is gone.

**And the fix is still insufficient.** One failure in six is roughly 17%. Better
than the ~33% measured pre-fix, but nowhere near a gate you can trust, and CI
runners are slower and busier than this box.

## Confirmed cause, and the concrete next action

Run 4 was the **slowest run in the series** — 990s against 728–834s for the
others — so the machine degraded partway through.

This is a confirmed diagnosis, not a hypothesis. The mechanism, with line
numbers:

- `tests/test-ai-grok-review.sh:216` calls `ai_test_measure_baseline` **exactly
  once**, near the top of the suite.
- `ai_test_measure_baseline` sets the global `AI_TEST_BASELINE` and never runs
  again.
- `budget FACTOR FLOOR` returns `max(AI_TEST_BASELINE * FACTOR, FLOOR)` — so
  every ceiling in the file is derived from that one frozen measurement.
- The failing wait is around line 730, **several hundred seconds later**.

Run 4's baseline was 12s, giving `budget 15 30` = 180s. The library's own header
records a wrapper round trip costing ~15s idle, 26–42s with two suites, and 82s
under a four-suite storm. So a machine that degrades *after* the baseline is
taken leaves every later ceiling sized for a computer that no longer exists —
and the concurrency block, which needs **two** wrapper round trips to overlap, is
the most exposed thing in the suite.

That is a design gap, not a tuning problem, and raising the multiplier would
paper over it.

**Next action. Two options; the second is better.**

1. **Cheap and targeted:** re-measure the baseline immediately before the
   ask-concurrency block. Costs one extra wrapper round trip (~12–15s) and makes
   that block's ceiling reflect current conditions.
2. **Better shape:** make the wait progress-sensitive rather than
   deadline-sensitive — keep waiting while the observed state is still advancing
   (one lock has appeared, the second has not), and fail only when nothing has
   changed for N seconds. This preserves exactly what the check exists to detect
   — a genuine hang — while tolerating a slow machine, which is the distinction a
   fixed ceiling cannot make at any value.

Either way, **re-run this series afterwards.** A fix to a flake is not evidence;
the series is.

**Do not "fix" this by raising `budget 15 30`.** A ceiling that is large enough
on a degraded machine is one that no longer detects a genuine hang, which is
what these checks exist to catch. Decision **B** of
`plan_repo-throughput-restructure.md` applies: no test is weakened to make a lane
green.

## What this means for the plan

`plan_repo-throughput-restructure.md` step **1.2** requires **10 consecutive
green** runs on Windows CI. This series is local, incomplete, and already
contains a failure, so **step 1.2 is not satisfied and step 1.1 is not done.**
Anyone updating that plan's STATUS table must cite this file, not the earlier
191/0 single-run result, which was true but not representative.

The earlier "191 passed, 0 failed" figure recorded against step 1.1 is a
**single quiet run** and must not be read as proof.

## Handing this back to issue #89

Iteration stopped here. Everything a successor needs is above; nothing further is
in flight, and no background run is still going.

**What is done and merged:** budgets derive from a measured baseline instead of
fixed sleeps; the last two silent waits became loud `poll_until` calls; a failure
now names itself as a fixture problem with its ceiling and baseline.
`fix_test_ai.md` has been corrected so it no longer reads as "FIXED".

**What is left, and it is one change, not an investigation.** Replace the
deadline-sensitive wait with a progress-sensitive one: keep waiting while the
observed state is still advancing (one lock has appeared, the second has not) and
fail only when nothing has changed for N seconds. That distinguishes a slow
machine from a genuine hang, which no fixed ceiling can do at any value.
Optionally re-measure the baseline immediately before the ask-concurrency block as
a cheaper stopgap.

**How the successor knows it worked.** Re-run this series to ten. Do not accept a
single green run as evidence — a single green run is what made this fix look
finished the first time.

**Do not** raise `budget 15 30`, add retries around the assertion, or mark the
check as allowed-to-fail. Decision **B** of `plan_repo-throughput-restructure.md`
forbids weakening a test to make a lane green, and this test guards paid-work
locking.
