# Issue #89 — post-fix run series on `edge-dev`

**Status: SERIES INCOMPLETE, AND THE FIX IS NOT PROVEN.**
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
| 7–10 | — | not yet run |

`bash tests/test-ai-grok-review.sh`, sequential, quiet machine, no other suite
running. Logs under the capture directory named in the session handoff.

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

## Probable cause, and the concrete next action

Run 4 was the **slowest run in the series** — 990s against 728–834s for the
others — so the machine degraded partway through.

`tests/lib-test-timing.sh` measures its baseline **once, at suite start**, and
derives every later ceiling from it. Run 4's baseline was 12s, giving
`budget 15 30` = 180s. The library's own header records a wrapper round trip
costing ~15s idle, 26–42s with two suites, and 82s under a four-suite storm. If
the box degrades *after* the baseline is taken, every ceiling for the rest of the
run is measured against a machine that no longer exists.

That is a design gap, not a tuning problem, and raising the multiplier would
paper over it.

**Next action — do not skip to a bigger number:**

1. Re-measure the baseline immediately before the ask-concurrency block, or
   re-measure periodically, so ceilings track the machine's current state rather
   than its state ten minutes ago.
2. Only then re-run this series.

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
