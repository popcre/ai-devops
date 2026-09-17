# CI speed audit — 2026-09-17

Scope: `.github/workflows/verify.yml`, the last 24 completed Verify runs
(19 `pull_request`, 4 `merge_group` usable; run IDs from `gh run list -L 60`),
job timings from the Actions jobs API. Recommendations only — no workflow,
required-check, or ruleset change was made.

## Headline numbers

| Lane | Runs | Wall median | Wall p90 |
|---|---|---|---|
| pull_request | 19 | 26.1 min | 48.9 min |
| merge_group | 4 | 21.1 min | 21.3 min |

- Of the last 60 Verify runs, 24 PR runs were `cancelled` (superseded pushes).
- Runner queue time is negligible: median 0.1 min, p90 1.3 min for every job.
  **No PR job ran on the self-hosted Windows runners** in the sample —
  slowness is execution time, not waiting for runners.
- No head SHA ran both a PR run and a merge-group run (the queue tests a new
  merge commit), so there is no literal same-SHA duplicate; there is a
  functional one (linux-offline runs twice per change, see below).

## Per-job table (sample)

| Job | Event | n | Median | p90 | Real failures* | Protects | Duplicates? |
|---|---|---|---|---|---|---|---|
| fast-classifier / classify | both | 23 | 0.2 | 0.2 | 11 (Workflow policy step) | decides run_long; workflow-policy lint | no |
| linux-offline | PR | 18 | 19.6 | 21.8 | 8 | full Bash offline suite on Linux | re-run in merge_group |
| linux-offline | merge_group | 4 | 20.7 | 20.9 | (in 8 above) | same suite on merge commit (queue gate) | PR run of same change |
| windows-offline-section ×5 | PR | 90 jobs | 22.1 | 35.3 | 1 | Windows-sensitive suites, sharded 5 | overlaps linux-offline for cross-platform suites |
| windows-offline (aggregator) | PR | 19 | 0.0 | 0.1 | 1 | required check name | no |
| windows-reviewer-fallback | PR | 18 | 26.2 | 45.3 | 0 | codex + grok reviewer suites on hosted Windows | yes — its purpose is the preferred self-hosted lane |
| windows-reviewer-safety / reviewer-safety-start-deadline | PR | 19 | ~0.1 | 0.1 | 0 | aggregator/deadline | no |
| merge-group-evidence, verification-closure | both | 23 | ~0.1 | 0.1 | 3 | aggregators | no |
| windows-reviewer-preferred, reviewer-runner-availability, windows-offline-complete, manual-preflight | — | 0 ran | — | — | — | dispatch/schedule only | — |
| report-scheduled-failure | PR | 13 cancelled | 0 | 0 | 0 | schedule-only alerting | no |

*"Real failures" = conclusion `failure`; cancellations excluded (linux-offline
had 5, windows-offline-section 40, fallback 13 cancellations).

Long poles per PR run: windows-reviewer-fallback (26 / 45 min) and the slowest
Windows section (22 / 35 min); linux-offline (~20 min) sets the merge-queue time.

## Ranked speedups

1. **Only run windows-reviewer-fallback when reviewer files change.** It
   caught 0 failures in 18 runs yet is the PR long pole. Gate it in
   fast-classifier on paths (`bin/ai-codex-review*`, `bin/ai-grok-review*`,
   their libs and tests). Saves ~20–40 min wall on unrelated PRs. Risk: low–
   medium (path list must include shared helpers; keep full run on schedule).
2. **Split linux-offline into 3–4 shards like the Windows lane.** It is the
   sole merge-queue gate and the ~20 min floor of every PR round, and it is the
   job that actually catches regressions (8 failures). Saves ~12–14 min on both
   PR and queue runs. Risk: low (same mechanism already used on Windows;
   aggregator check keeps the required name).
3. **Rebalance / add a 6th Windows section.** p90 35 min vs median 22 means one
   section carries the heavy indivisible suites. Balancing by measured suite
   time should cut the Windows p90 to ~25 min. Saves ~10 min at p90. Risk: low.
4. **Docs-only / prose-only PRs skip long lanes entirely** (classifier already
   exists; confirm run_long=false for Markdown-only diffs and that aggregators
   pass). Saves the full ~26 min for doc PRs. Risk: low.
5. **Fix the Workflow policy step in fast-classifier** — 11/23 runs "failed"
   there, which forces the long lanes (`result != 'success'` runs everything).
   Saves full-lane runs whenever the failure is spurious. Risk: low; needs a
   separate diagnosis.
6. **Batch pushes between review rounds** — 24 of 51 PR runs were cancelled
   by the next push; each cancelled run burned up to ~26 min of runner time
   (not wall time for the author). Process change, zero risk.
7. **Use the self-hosted preferred reviewer lane on PRs** (currently
   workflow_dispatch-only). Only worth it if the qualified runner is reliably
   free; otherwise #1 is simpler. Risk: medium (runner availability, security
   of self-hosted on PR code).

## Checks that look unnecessary on every PR

- **windows-reviewer-fallback on PRs that do not touch reviewers** (0 failures).
- **linux-offline re-running in full in merge_group** when the PR run passed on
  a base that is still current — a candidate for a trimmed queue suite, but
  keep it until a same-base guarantee exists (it is the only queue gate).
- **report-scheduled-failure** is scheduled-only; it shows as 13 cancelled PR
  jobs — cosmetic noise, harmless.
