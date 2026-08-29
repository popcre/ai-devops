# The local ten-run series was abandoned — twice, for two different reasons

**Date:** 2026-08-28 (UTC)
**Machine:** `edge-dev` (Intel Core i7-12700, 20 threads)
**Supersedes as the active measurement route:**
[`2026-08-27-ten-run-series.md`](2026-08-27-ten-run-series.md)

This file exists so that no later session mistakes the absence of a ten-run
result for a ten-run failure, or re-runs the same two dead ends.

## Attempt 1 — contaminated by a self-inflicted concurrent suite

A second batch of runs was launched while the first batch was still going. The
batch was stopped, but stopping the wrapper did **not** stop the suite it had
spawned: two independent `test-ai-grok-review.sh` process trees were later
observed running at once. Every timing number from that attempt is therefore a
measurement of contention this session created.

The results were discarded. `fix_test_ai.md` §8 already names this exact
mistake — *do not create your own storm and then certify against it* — and it
was made anyway.

## Attempt 2 — run concurrently on purpose, then killed by its own cleanup

The owner directed a second attempt run deliberately concurrent: ten runs, eight
at a time, on the reasoning that a 20-thread machine sitting below 35% has the
headroom. Eight suites did start and were confirmed running side by side.

Two things went wrong, and both are properties of the machine, not of the fix:

1. **The self-hosted runner shares the machine.** With eight suites resident,
   the runner's heartbeat to GitHub stopped arriving and the repository API
   reported it `status=offline` while it was still working. The runner process
   itself was alive throughout; only its reporting was starved.
2. **The cleanup killed the wrong processes.** Terminating the series matched on
   the suite's process name — and the CI job running on the same machine was
   executing a suite *with that same name*. Job `98712820009`
   (`windows-reviewer-safety`) shows `cancelled` at its test step as a direct
   result. That is not a test failure and must never be cited as one.

## The rule this establishes

**This machine hosts either the CI checks or a local test series — never both.**
The two share process names and compete for the same cores, so a local series
can silently corrupt a check, and a check can silently inflate a series. Before
starting a local series, confirm the runner is idle:

```bash
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|"\(.name) busy=\(.busy)"'
```

And scope any cleanup to the series' own process tree — never a bare name match
against every matching process on the machine.

## What this does and does not tell us about the fix

**Nothing either way.** No clean ten-run series has been completed. The
progress-sensitive wait in `fe7c0606` is proven only by its own unit suite,
[`tests/test-lib-test-timing.sh`](../../test-lib-test-timing.sh) — 10 checks,
10 passed — which demonstrates that a slow-but-advancing fixture is no longer
failed and that a genuinely stalled one still is.

That is a proof of the mechanism, not a measurement of the flake rate. Step 1.2
of [`plan_repo-throughput-restructure.md`](../../../plan_repo-throughput-restructure.md)
stays **not satisfied** until ten consecutive green runs exist on an otherwise
idle machine.
