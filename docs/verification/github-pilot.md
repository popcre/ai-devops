---
summary: Verdicts of the GitHub continuity and throughput pilot (#2869) for outages, status-read quota and merge delay, with aggregates and cleanup receipts.
kind: proof
status: done
read-when: Deciding outage hardening, a GitHub event listener or check-speed work for ai-devops
---

# GitHub continuity and throughput pilot — findings

Plan: [plan_github-continuity-pilot.md](../../plan_github-continuity-pilot.md). Issue: [#2869](https://github.com/popcre/ai-devops/issues/2869). Run on edge-dev3, November 25, 2026, 3:20–4:00 PM EST. Harness: `tools/github-pilot/`. Raw records stayed in private temporary storage; only aggregates appear here.

Fixture and replay results are labelled as such. Live proof is limited to the two disposable draft pull requests in experiment 1 and the saved GitHub records in experiments 2 and 3.

## Verdicts

| Experiment | Verdict | Deciding evidence | Next action |
|---|---|---|---|
| 1. Work through an outage | **Fail** on the five-second gate; recovery and safety **pass** | Slow GitHub: workspace status 93.7 s, collision check 48.6 s, memory sync hung until the 120 s watchdog. Refused and 503: every tool answered safely in 0.2–6.9 s. Local edit, test and commit: 0.05 s in every mode. | Adopt the journalled, serialized, deferred submission pattern. Separate repair: bound network waits in workspace status, memory sync and the collision check. |
| 2. Shared status notifications | **Inconclusive** for REST core; **ruled out** for GraphQL. Listener not built. | Peak core hour: 4,165 of 5,000 used; 0 verified status reads; 4,165 unattributed. GraphQL peak: 416 points, all verified other spend. | Do not build a listener now. First attribute the unaccounted core spend (at least 94.6% of the peak hour came from outside both machines' recorded calls). |
| 3. Check and merge delay | **Diagnosis only** (no matched pairs) | Required check done about 15 s after the run starts; queue entry to merge median 0.9 min; 0 ejections. 4 of 11 PRs waited 9–60 min before entering the queue. | Leave checks and runners alone. Investigate the wait before a PR enters the queue. |

## Step 1 — samples and coverage

Complete New York days with records from both machines: November 19–24, 2026 (six days). A seven-day peak cannot be established; the peak below is the peak of this window only, and is observed usage, since no refusal was captured in it.

- Quota hour: November 19, 2026, 2:08–3:08 PM EST (GitHub's own rolling window), REST core, 4,165 of 5,000 used.
- Timing day: November 23, 2026, the day with the most distinct non-prose PRs (11).
- Live request budget: 50 extra requests reserved as 10 discovery, 12 drafts and cleanup, 8 status, 20 timing. Spent 22 (discovery 3, timing 3, drafts 11, status 2, final checks 3); no allocation overran.

## 1. Work through an outage (fixture, network-isolated)

The drill ran the real toolkit entry points in two disposable workspaces inside a network namespace that only had loopback. HOME and temporary storage were private, the toolkit was mounted read-only, and every connection and write was traced. Audit: destinations only loopback and local sockets; 0 writes outside scratch storage. The fixture gh holds no credential.

Entry points, two workspaces, seconds (target: a clear deferred or blocked answer within 5 s):

| Tool | Healthy | Refused | 503 | Slow (30 s per answer) |
|---|---|---|---|---|
| Task declaration | 0.23, ok | 0.23, ok | 0.24, ok | 0.24, ok |
| Workspace status | 6.95 | 6.86, "not current" warning | 6.87, warning | 93.7 |
| Memory sync | 6.97 † | 3.5, refused: private visibility unverifiable, no push | 3.5, same | killed at 120 s, no push |
| Runner collision check | 3.45, clear | 3.54, unknown (exit 4) | 3.53, unknown (exit 4) | 48.6, clear (correct, late) |

† The healthy memory-sync control reached the test hub (clone and fetch succeeded) and then stopped on a check that the private test home is toolkit-managed. That stop is unrelated to the network, so its healthy time is not a comparable baseline.

No mode pushed anything, overrode a collision or skipped a visibility check. The failures are responsiveness only: workspace status exceeds 5 s even when healthy, and three tools wait without limit on a slow GitHub, which the plan counts as a failed continuity trial.

Local work and recovery, both workspaces:

- Edit, isolated test and commit while disconnected: 0.05 s, test passed.
- Submission worker: deferred in 0.06 s (refused, 503) and 5.06 s (slow). Killed mid-outage and restarted offline: deferred again, work recoverable.
- Journal killed mid-write, before and after the atomic replace: always a complete previous or new record; every retained commit resolves.
- Reconnect with an overlapping upstream edit: A rebased and its test passed; B conflicted and stayed pending until resolved, then passed and was submitted on top of A.
- Lost response after creation, crash before recording delivery, two concurrent restarts: one PR per branch, 0 force pushes, dependency order kept, both changes preserved. A stale journal replayed after merge recorded "already merged".

Live submission proof (normal path, `ai-gh pr create --draft`):

- Draft [#2879](https://github.com/popcre/ai-devops/pull/2879) (head `74d1fef0`) and [#2880](https://github.com/popcre/ai-devops/pull/2880) (head `508743aa`, stacked on #2879). Each create took 3 GraphQL exchanges.
- Each prose-only draft triggered 21 check runs; 1 required (verification-closure, passed). doc-safety failed on purpose (probe pages without an index update), which opened advisory issue [#2881](https://github.com/popcre/ai-devops/issues/2881); it was closed as pilot cleanup.
- Both drafts closed unmerged, never marked ready or queued; both branches deleted and verified gone.

## 2. Shared status notifications (saved records)

Rule: T = consumed, S = verified status-read cost, O = verified other cost, U = T − S − O. Build the listener only if S/T ≥ 20%; rule it out if (S+U)/T < 20%.

| Bucket, peak hour | T | S | O | U | S/T | (S+U)/T | Verdict |
|---|---|---|---|---|---|---|---|
| REST core | 4,165 | 0 | 0 | 4,165 | 0 | 1.0 | Inconclusive |
| GraphQL | 416 | 0 | 416 | 0 | 0 | 0 | Ruled out |

Both machines recorded about 223 invocations in the core hour, at most about 5.4% of T, so at least about 94.6% came from callers these records do not see. The largest measured caller was an unattributed issue read repeated about every 2 minutes (42 times), which spends GraphQL, not core. Opaque command counts were never counted as verified cost.

The listener, its replay and its live arm were not run: the gate was not met and no approved receiver exists. Live proof for shared notifications stays open on #2869.

## 3. Check and merge delay (saved records, diagnosis only)

Sample: the 11 non-prose PRs merged on November 23, 2026; 583 jobs (369 PR, 191 merge-group, 23 other). 43 jobs that never started were excluded. Nearest-rank percentiles, minutes from the first check run on the final revision:

| Measure | Median | p90 |
|---|---|---|
| Required check complete | 0.2 | 0.3 |
| Entered the queue | 0.6 | 30.1 |
| Merged | 1.4 | 31.0 |
| Advisory PR checks complete | 25.9 | 27.1 |
| Merge-group jobs complete | 12.7 | 44.6 |

- Each PR entered the queue once; 0 ejections, 0 reruns. Queue entry to merge: median 0.9 min.
- Runner wait after dependencies and the intentional 90 s push-settle delay: median 2–3 s, p95 at most 5 s for PR jobs (reusable-workflow jobs p95 about 80 s). Jobs start about 100 s after their run is created, which is the settle delay, not a runner shortage.
- Advisory checks (about 26 min) and the remaining merge-group jobs finish after the merge, so they do not hold it.
- Seven PRs merged about 1.1–1.4 min after checks began. The four slow PRs (11–61 min) spent that time before entering the queue.

No change to required checks, advisory checks or runners would shorten these merges. No matched pairs exist, so no speed claim is made.

## Cleanup receipts

- Drafts #2879 and #2880: closed, unmerged, branches deleted (verified by GraphQL and `ls-remote`).
- Issue #2881 (opened by CI for draft #2879): closed with a signed note.
- edge-dev3: the toolkit copy, drill output and fixture server under the temporary area were removed and verified absent. No host networking, DNS, credentials, backoff settings, subscriptions or installs were changed.
- The ordinary waiter still works: this findings PR was followed to merge with the normal wait helper.

## Limitations

- The slow-GitHub case is modelled by a fixture that answers after 30 s. Real gh and git have no default overall timeout, so the hang is expected live too, but it was not reproduced against GitHub.
- The quota window is six days of two machines' records; other machines and CI are invisible.
- One timing day; percentiles over 11 PRs are coarse.
