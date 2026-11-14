# CI process repair — 6.1 acceptance measurement (2026-11-14)

Window: 2026-11-07T02:34Z (5.2 merge, last phase-5 landing) through 2026-11-14 ~14:00Z.
Measured 2026-11-14 ~9:00 AM EST by the scheduled acceptance run (ZCode session
`892c98b3-eccc-4876-bf88-1a9f7a328321`, edge-dev). All evidence is live GitHub data;
queries noted per row.

## Verdict

**5 of 10 section-13 targets pass. 5 miss.** One root cause explains the two
signal targets (1 and 2); two are queue-throughput symptoms; two are
definitional/standing gaps. Follow-up issues are filed (linked below) — this
measurement does not silently absorb them.

## Measurements vs section 13

| # | Measure | Target | Result | Evidence |
|---|---|---|---|---|
| 1 | ai-devops merge-queue `verify` runs green | ≥90% | **MISS — 0%** (0/9 completed green; 11 cancelled churn) | `gh run list --workflow verify.yml` (merge_group, window): all completed runs red; every one fails `test-ai-devops-doctor-install-lag.sh` ("expected the up-to-date report") and `merge-group-evidence` (<1s, exit 1). The ten queued PRs #2489–#2511 all MERGED anyway (verify is advisory under the lean-checks ruling), so delivery worked — the green/red signal did not. |
| 2 | Merged PRs with a failed check | <10%, each with an owned issue | **MISS — 10/10 sampled** | The same ten merged PRs each landed with a red `verify` merge-group run; no owned issue existed for the fixture failure until this measurement filed one. |
| 3 | `review-fixer` share of ai-devops runs | <15% | **MISS — 36.6%** (79/216) | Run count by workflow name, window. 1.5 landed the design (two-hourly schedule + finding-closed events); at current volume the scheduled cadence alone is ~11 runs/day. The letter of the target is missed; meeting it needs either fixer retirement (0 outstanding findings) or a target restated per-day rather than per-share. |
| 4 | Open fixer PRs >48h, shared-db | 0 | **MISS — ≥7** | Open PRs 2026-11-14: #6006, #6015 (Nov 10), #6099 (Nov 11), #6160, #6185, #6205, #6218 (Nov 12) — all "Fix review finding", all >48h. |
| 5 | Advisory logs saying REFUSED on merged changes | 0 | **PASS** | Sample: merged-PR refusal texts in-window are hard gates (project-ref mismatch, freshness), not advisory gates; 1.6's "advisory: would have" wording is live. |
| 6 | Merged migration not live after 24h with no owner | 0 | **PASS** | `migration-ledger-drift.yml`: 10/10 runs green across the window; no verified-drift report since 2026-11-07. |
| 7 | Good production apply marked red | 0 | **PASS (with churn noted)** | 6 production applies in-window, 5 red — every one refused PRE-apply (`EXPECTED_PROJECT_REF environment does not match requested ref`); no succeeded-apply-marked-red found. The env-mismatch retry churn (PR #6288 needed 3 attempts) is its own reliability smell, filed with the follow-ups. |
| 8 | shared-db workflow count | <35 | **MISS — 56** | `git ls-tree origin/main .github/workflows` (was 52 at baseline). 2.9's dependency check remains: nothing was deletable from shared-db alone; the count grew with new monitors. |
| 9 | Sessions told "blocked" with the reason unnamed | 0 in ten waits | **PASS** | Sample of ten wait/block situations across the window's issues and this repair's own queue waits: every stop named its reason (the 5.1 named-reason work, the fixer queue, the canary path). |
| 10 | Live version mismatch unnoticed | Detected in the deploy run | **PASS** | Deploy-proof runs in-window: poppim-web 5/5 green, popcrm-web 6/6 green; popdam3 had no deploy-path run in the window to exercise the proof (capability live since 4.1). |

## Root cause behind targets 1 and 2

`tests/test-ai-devops-doctor-install-lag.sh` (landed 2026-11-07, PR #2453) passes
on pull-request runners and locally, but fails on merge-group runners: the
fixture's synthetic repo reports "N commits behind" where the up-to-date report
is expected — the shim SHA and the fixture's `origin/main` diverge in that
environment (suspect: fixture `git init` inheriting runner template/config that
changes branch or ref resolution). The `merge-group-evidence` job failing in
under a second on the same runs is the second half of the red signal.
Follow-up issue: see the tracker comment accompanying this file.

## What passed outright

The database delivery lane (targets 6–7): zero undelivered migrations, zero
good-apply-red across seven days of automatic promotion. Deploy proofs (10) and
named-reason waits (9) held.

## Follow-ups opened by this measurement

- ai-devops: "merge-group verify red — doctor-install-lag fixture + merge-group-evidence" (reopens the 5.2/1.1 signal surface).
- ai-devops: "shared-db fixer PRs age past 48 hours" (reopens the 0.1/1.4 lifecycle surface).
- Standing, no reopen action defined: fixer share definition (3), workflow count (8).

Posted by ZCode chat sess_892c98b3-eccc-4876-bf88-1a9f7a328321 on edge-dev
