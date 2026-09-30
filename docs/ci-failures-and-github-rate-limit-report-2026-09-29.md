# CI failures and GitHub rate-limiting — incident report (2026-09-15 to 2026-09-29)

**Date range covered:** 2026-09-15 through 2026-09-29 (America/New_York / EST dating for human-facing times).
**Report written:** 2026-09-29.
**Repository:** `popcre/ai-devops` (public recovery toolkit for the multi-model AI workflow).
**Scope:** Continuous-integration failures and GitHub API rate-limiting / quota problems observed in the two-week window, with root-cause analysis and mapping to existing owners.

## 1. Method note

This report is built from a filtered set of private AI chat transcripts from the same two weeks.

- 949 unique session digests in the window were scored with TypeSafe Jev Noul on the question “is this session primarily about CI failures **or** GitHub rate-limiting / API quota?”
- 640 sessions were disregarded with greater than 90% confidence they are **not** about that topic (topic probability below 0.10).
- 309 sessions remained as the working corpus. Topic probabilities in the remainder ranged from about 0.10 to 0.72.
- The 309 were stratified by date, machine (`edge-dev` / `edge-dev3`), and client kind (Claude / Codex). Sessions with topic probability ≥ 0.40 were deep-read first (~72), then mid-band sessions with meaningful titles or large bodies, then the rest were sampled for corroboration. In total, 39 priority sessions were deep-read in full text; the rest were read at excerpt and path level and cross-checked against repository plans, issue numbers, and docs.
- Titles, excerpts, and worktree names mentioning CI, check failure, merge queue, rate limit, quota, 403/429, runner, flaky, timeout, GitHub API, polling, `ai-gh`, `ai-pr-wait`, or BlockerWatch were treated as core evidence.
- A small burst of canned one-liner evaluation fixtures (around 2026-09-15 late evening, skill-trigger evaluation paths) was excluded as non-incident material.

**Jev is advisory classification only.** It selected candidates for human-style reading; every claim below is grounded in what sessions actually observed and in public repository documents, not in the classifier score.

**Privacy:** session paths and digests stay in a private notes file. This report paraphrases observations and cites only public-safe references (issue/PR numbers, plan and doc file names, tool names already in the repository, dates, and hostnames that already appear in public docs).

---

## 2. Executive summary (plain language)

Over these two weeks, work repeatedly stalled for two families of reasons: **red or missing CI results that were not really “broken code,”** and **GitHub refusing or throttling API calls even when the hourly quota looked full.**

The top failure modes, in order of how much they cost:

1. **Windows CI jobs died or timed out and looked like product bugs.** A suite that had grown to the edge of its time limit was killed under machine load; a killed process and a capacity timeout both show up as ordinary test failures. One pull request even landed with both Windows checks red at exactly their timeouts.
2. **Duplicate and superseded CI runs burned the runners.** Builds for the same pull request piled up instead of replacing each other, and the merge queue re-ran hour-long Windows jobs on every rebuild — one change restarted a 75-minute job five times.
3. **GitHub rate limiting that was not really “out of quota.”** Several blocks happened while the hourly allowance still showed 5,000 of 5,000 remaining. The real trigger was a burst of requests at the same second (three machines’ background watchers all firing on the same 10-minute mark) hitting GitHub’s unpublished secondary limit.
4. **Background automation spending the owner’s personal GitHub budget.** The scheduled issue-watcher accounted for roughly 95% of measured managed GitHub traffic and shared the same identity as interactive work.
5. **Flaky timing tests and load-sensitive checks** that fail when the machine is busy, block merges, and force long re-runs (including one session that repeated the same multi-hour test for about a day without progress).

Several of these are already owned by open plans (`plan_github-request-reduction.md`, `plan_workflow-efficiency.md`, `plan_blockerwatch-reliability-repair.md`). Two important mitigations landed late in the window: staggering watcher schedules across machines, and moving scheduled background traffic onto a separate GitHub App identity.

---

## 3. Background and context

`popcre/ai-devops` is Albert’s public recovery toolkit for a multi-model AI coding workflow. It is not a product application. It ships Bash/PowerShell tools, installers, skills, and GitHub Actions tests. **Installation is the deployment mechanism** for the tools and instructions that AI clients use.

Relevant machinery:

- **Reviewers:** multiple external model reviewers (Grok, Muse, Qwen, Gemini, DeepSeek, and others) are wrapped by repo-owned tools with read-only, exact-head, cost, and isolation rules. Reviews run on worktrees and often wait on CI.
- **CI:** `.github/workflows/verify.yml` runs Linux offline tests on GitHub-hosted runners and Windows offline / reviewer-safety jobs on a small self-hosted Windows pool (`edge-dev`, later `EDGE-RUNN-ENVY` and others). A merge queue protects `main`.
- **GitHub traffic:** `bin/ai-gh` is the paced GitHub CLI transport (lock, spacing, hourly budget, rate-limit back-off). Waiters are `bin/ai-pr-wait` and `bin/ai-gh-wait`. `bin/ai-blocker-watch` runs on a 10-minute schedule and wakes parked work. Callers are supposed to go through `ai-gh` so one policy governs pacing.

Existing plans that already own related work (read their STATUS first before re-planning):

| Plan / doc | Owns |
|---|---|
| `plan_github-request-reduction.md` (issue #658, children #660 and others) | Attribution of GitHub consumption, quota-bucket protection, coalescing waiters, cutting unneeded traffic, fleet coordination, measured acceptance |
| `plan_cut-unneeded-github-traffic.md` | Source-reduction steps S1–S4 (BlockerWatch snapshot reuse, shared PR status reads, route leftover callers, before/after sample) |
| `plan_workflow-efficiency.md` (issue #650) | Slow CI, repeated tests/reviews, inventory cost, affected-test selection, known-fast-failure routing |
| `docs/windows-runner-interruptions-2026-09-01.md` | Windows runner interruption mechanisms and the “failure states are not distinguishable” problem |
| `docs/ci-speed-audit-2026-09-17.md` | Measured job times and speedup opportunities |
| `docs/ai-devops-required-checks-gap.md` | Required-check configuration gaps that let merges land without a real green |
| `plan_blockerwatch-reliability-repair.md` | BlockerWatch registration/wake/scheduler reliability |
| `plan_reviewer_lease_liveness.md` (#283) | Dead reviewer workers and invisible slot waits |

The corpus below is best read as **live evidence of how those known problems still bit work in this window**, plus a few newer operational findings (secondary-limit synchronization and identity separation) that landed near the end of the window.

---

## 4. Failure-mode catalogue

Frequency language (“rare / occasional / frequent”) is **within this 309-session corpus**, which is pre-filtered toward the topic. Absolute production incidence is higher; the corpus is not a random sample of all sessions.

### FM-1 — Superseded CI builds pile up; merge queue re-runs long Windows jobs

**What goes wrong.** Builds for the same pull request do not replace each other. Pushing a new commit leaves the old build running. The merge queue also scheduled the full Windows matrix on every queue rebuild, so one change could restart an hour-long job many times and still not merge.

**When.** Documented root-cause work dated 2026-09-01 and still being cleaned up in sessions that imported under 2026-09-20 stamps and later (issue #204 / PR #215 era, with follow-ups through issue #209 and runner-pool work).

**How often (in corpus).** One deep, complete incident session plus several runner-pool continuations; the interruption doc describes the same shape on PR #197 (queued four separate times) and PR #191.

**Why (root cause).** The workflow’s concurrency group was keyed on the **head commit SHA**. A newer commit creates a *different* group, so GitHub never cancels the old run. Separately, Windows jobs were not excluded from `merge_group`, so every queue rebuild re-ran them. Removing Windows from the required list without also skipping it in the queue would hang the queue waiting for a check that never arrives — the session that fixed this changed grouping, queue skip, and required checks together.

**Proof (paraphrased, auditable).** On `edge-dev`, Claude session implementing tracking issue #204 confirmed neither concurrent Codex session (#161 / #209) had landed the concurrency-key fix; PR #213 left the SHA key and would have made merge_queue always run the full matrix. PR #215 then grouped pull-request runs by PR number, skipped both Windows jobs on merge_group, and left `linux-offline` as the only required check. Live proof: pushing a second commit cancelled all three jobs of the first (impossible under the SHA key); the merge-queue run skipped both Windows jobs with zero runner minutes (versus ~100 minutes before). Merged as `ee2b5a82`; issue #204 closed. The same session counted “the 75-minute job restarted five times for one pull request” before the fix.

**Known or new.** Known and **fixed in this programme**; residual risk is any workflow that reintroduces SHA-keyed grouping or Windows-on-merge-queue.

**Next owner / action.** Keep the policy test that asserts the PR-number grouping. `plan_workflow-efficiency.md` still owns further CI waste (P3–P5). Do not reopen #204.

---

### FM-2 — Windows suite duration creep: timeout reported as “broken code”

**What goes wrong.** The long Windows offline suite grew until it sat on the edge of its configured time limit (75 minutes). Under any extra load it exceeded the limit and was killed. GitHub reports that as a **failure**, identical in the UI to a real assertion failure. One pull request (#214) was even merged with both Windows checks red at exactly their timeouts.

**When.** Same 2026-09-01 window and again during runner-pool / ENVY work through 2026-09-25. A single day’s pattern: three morning runs passed at 63, 63, and 75 minutes (the last finishing with about 20 seconds spare); after about 3:00 PM every Windows run hit the ceiling.

**How often (in corpus).** Recurring theme across concurrency-fix, runner-pool, ENVY-fallback, and rebase-PR sessions; the interruption doc’s table shows two of four death modes masquerade as test failures.

**Why.** Suite length crept toward the ceiling while capacity shrank: two runners on one physical host (`edge-dev`), plus local work, plus SentinelOne/endpoint overhead on candidate hosts. Under contention a 63-minute suite does not need much slowdown to hit 75. Raising the limit to 90 or 120 was deliberately rejected as “silencing the smoke alarm”; later work did raise an *internal* wrapper limit to 150 minutes with a named interrupted test, explicitly flagged to bring back down once capacity is real.

**Proof.** Concurrency-fix session: “windows-offline … ran 22:11 to 23:26, exactly 75 minutes, and hit its own timeout”; same suite had passed three times that morning. Runner-pool session: wrapper now streams live output and names the interrupted test; limit 75→150 with measurement. Rebase-PR session: PR #214 merged `36bd7a5f` with both Windows checks red at timeouts; the same long test later passed on `EDGE-RUNN-ENVY` in 62 minutes — the run cancelled three times on the desktop — which is the routing proof. ENVY session: ENVY ran suites ~5× slower than at qualification and hit a 30-minute preferred-lane limit, then the tests themselves proved ~45 minutes.

**Known or new.** Known (`docs/windows-runner-interruptions-2026-09-01.md`, issue #210’s “report the real category instead of a generic 75-minute failure”). Partially mitigated (naming the interrupted test; routing to faster machines).

**Next owner.** Runner-pool / capacity work (issue #209 lineage, `plan_windows-runner-maintenance-elevation.md` #262 for maintenance) and `plan_workflow-efficiency.md` for suite length. Keep the timeout as a capacity signal; do not paper over it by raising ceilings without measurement.

---

### FM-3 — Local work and host contention kill live CI

**What goes wrong.** A local full test sweep on the machine that hosts the Windows runners kills or starves live GitHub jobs. A process killed mid-suite reports as `failure` (exit -1), not as `cancelled`. Endpoint software (SentinelOne on EDGE-ALIEN) multiplies process-launch cost for the kind of workload the suite runs.

**When.** Documented 2026-08-29..09-01; constraints still quoted in later sessions (“never start a local full test sweep while a GitHub run is active”). SentinelOne exclusion rounds discussed mid-window (Nexustek 2nd round).

**How often.** Explicit collision rule is now in standing instructions; at least one session in the corpus *did* start a local sweep by mistake while CI was live and killed it after realizing. PR #197’s run 33486858691 is the canonical killed-mid-suite example.

**Why.** Shared physical host for runners and daily/agent use; no machine-wide admission control beyond a check (`bin/ai-test-local --check-collision`) that must be called. Resource storms and security agents reduce headroom further (script execution 9.3× → 1.5× after exclusions, but process launch still 2.1–2.5×; SentinelAgent ~4.2s CPU in a 7s benchmark).

**Proof.** Interruption doc: local durable Bash rerun overlapped CI; run 33486858691 coincided with a local #160 suite and died with `windows-offline` failure exit `-1` at 08:55:51Z; the local run was then deliberately interrupted. Same doc: “a full test sweep started on that machine kills the running CI job.” SentinelOne session (edge-dev, Claude): measured before/after exclusion numbers above and requested a *type* change of exclusion because process-launch overhead remained.

**Known or new.** Known. Mitigation is procedural (`--check-collision`) plus moving capacity off the shared host (FM-2, ENVY/Blacksmith).

**Next owner.** Windows runner docs and `plan_workflow-efficiency.md`; endpoint exclusion follow-through is outside this repo (vendor/IT).

---

### FM-4 — Secondary rate limit / “blocked while quota looks full”

**What goes wrong.** GitHub refuses calls (often as 403 / rate-limit errors on Actions or API calls) even though the standard hourly allowance still reports thousands of requests remaining. Work appears “out of quota” when it is not.

**When.** Strongest evidence 2026-09-28: five blocked calls at 1:49 AM, 2:00 AM, 12:40 PM, 12:50 PM, and 1:00 PM EDT. Earlier the request-reduction programme (opened ~2026-09-20) recorded a GraphQL exhaustion while diagnostic headers for a *follow-up probe* still showed core remaining 5000 — a bucket-mismatch illusion.

**How often.** Multiple discrete block events in one day; programme-level chronic issue (#658).

**Why.** Two independent mechanisms:

1. **Burst synchronization.** Three machines (edge-dev, edge-dev3, hetz) each ran the 10-minute issue-watcher on the *same* clock marks (:00, :10, …). Each block landed at the exact tick, while a batch of ticket reads was in flight. That is the unpublished secondary limit (too many requests in a short window), not primary quota exhaustion.
2. **Bucket confusion in guards.** REST core, GraphQL, and search are separate budgets. A guard that reads “remaining” from the wrong resource (or from a later probe) can look healthy while GraphQL is already exhausted.

Tight polling (`gh run watch`, second-level loops) is a documented way to trip the same secondary limit and get 403s on every Actions call while `rate_limit` still reports a full allowance.

**Proof.** Rate-limit diagnosis session (edge-dev3, Claude): “You’re not actually out of GitHub quota. Your hourly allowance shows 5,000 of 5,000 left … All five blocks today (1:49 AM, 2:00 AM, 12:40 PM, 12:50 PM and 1:00 PM EDT) landed at the exact moment it ran.” Fix: stagger each machine’s watcher minute (PRs #999, #1003, #1004); after install, “GitHub hasn’t refused a single request since 1:00 PM EDT, about an hour and a half ago.” Request-reduction plan §3 records the GraphQL/core header mismatch on 2026-09-20. Interruption doc warns explicitly about secondary limits from aggressive Actions polling.

**Known or new.** Mechanism known in docs; **the three-machine same-minute synchronization was a new, concrete root cause found and fixed in this window**. Bucket mismatch is known and owned by P1/P2 of #658.

**Next owner.** `plan_github-request-reduction.md` (#658) for measurement, bucket protection, and acceptance; staggering and app identity (FM-5) are landed mitigations to keep. Issues #1001/#1002 (shared test-list split; self-clearing locks) were opened from the same investigation and may still need owners.

---

### FM-5 — Background automation spends the personal GitHub identity

**What goes wrong.** Scheduled BlockerWatch ticks (and issue-watching) used the same GitHub identity as interactive sessions. Measured P1 data showed BlockerWatch on the order of **95% of managed traffic**, so background scans could starve the human/agent work that needs the budget.

**When.** Measured under PR #663 (installed ~2026-09-23); identity separation landed 2026-09-28.

**How often.** Structural until fixed; every 10-minute tick on every host.

**Why.** One personal token for everything; no split between scheduled watchers and interactive API use; plus uncoalesced duplicate reads (multiple waiters polling the same PR).

**Proof.** Request-reduction STATUS: “BlockerWatch is about 95% of measured traffic, so P5 has the largest payoff.” Separation session (edge-dev3): created GitHub App `pop-ai-watchers`, installed on both orgs; live watcher run spent 104 app points and at most 1 personal point; merged popcre/ai-devops#1006 and verified on edge-dev and edge-dev3. Coalescing waiters landed earlier (PR #948, issue #925: two waiters shared one OPEN refresh with independent deadlines). Routing leftover callers through `ai-gh` landed as PR #973.

**Known or new.** Known as a traffic problem (#658); **app-identity separation is a new mitigation in this window**.

**Next owner.** #658 P5 (BlockerWatch scan/write removal, #868 live proof), P7 install matrix, P8 measured acceptance. Keep the app identity for scheduled ticks.

---

### FM-6 — Flaky and load-sensitive tests block merges and waste days

**What goes wrong.** Timing-based tests fail under load (including CI running on the same box). Inherited diagnoses blamed the wrong timers. One known-bad check can hold up unrelated work because there is no “known flaky, do not block” mechanism that is safe. One session reportedly looped the same ~6-hour test for about 24 hours with no progress.

**When.** Issue #89 lineage (handoffs from 2026-08-26 / 08-28 still being worked in-window); 24-hour loop reported mid-window.

**How often.** Eight flaky checks named from observation in the two suites under #89; load-sensitive concurrency checks fail whenever three CI jobs share the host (207 passed / 3 failed pattern). Occasional “3-second timing window” flakes appear in unrelated runs.

**Why.** Real causes observed: a default 15-second wait ceiling losing to process startup under load; concurrency assertions that are inherently load-sensitive; one check that never tested anything (waited for a filename pattern that could never match, and passed because its wait was shorter than the fake delay). Raising timeouts until nothing fails is explicitly rejected as a strategy.

**Proof.** Flaky-tests session: “All eight flaky checks are named from observation. The inherited fix_test_ai.md §3 attribution was wrong on both suites… The real causes…” and “207 passed, 3 failed… load-sensitive concurrency checks, which the suite’s own notes flag as failing under a loaded machine — three CI jobs are running on this box right now.” A later plan review: Grok REJECT of a flaky-quarantine design because 24 test files report failures in a format the filter could not read (could mark real bugs “known flaky”); GLM: enabling merge protection before fixing flaky tests is “actively harmful.” PR #123 removed guessing/silent timeouts and found four genuine bugs.

**Known or new.** Known (issue #89, #160; `plan_workflow-efficiency.md` P7 “transient health timeouts no longer masquerade as bad reviewers”).

**Next owner.** `plan_workflow-efficiency.md` (#650) and the #89/#160 repair line. Prefer observation-backed renaming of causes over quarantine filters.

---

### FM-7 — Merge queue ejection, required-check gaps, and waiter traps

**What goes wrong.** A merge-queue ejection leaves the pull request **OPEN**; automation that only watches PR state waits forever. A required check that no longer runs (or never ran) can hang the queue or, worse, allow a merge without real evidence. Auto-merge can fail with GraphQL “Auto merge is not allowed for this repository.”

**When.** Throughout; documented in the interruption doc and `docs/ai-devops-required-checks-gap.md`.

**How often.** Recurring operational friction (ejection-aware waiters appear in several sessions; PR #197 re-queued by hand four times).

**Why.** Queue behavior and required-check configuration are separate contracts; waiters that ignore ejection states stall; aggressive polling to compensate hits FM-4.

**Proof.** Interruption doc: ejection leaves PR OPEN; no automatic retry; nothing alerts on repeated cancellations. Required-checks gap doc: a commit landed despite a failed evidence job because required contexts did not cover it. Concurrency-fix session had to remove Windows from required checks *and* skip it in the queue together. Muse/Grok session used an “ejection-aware waiter” and still waited on a full verify including a >1h Windows job.

**Known or new.** Known.

**Next owner.** `bin/ai-pr-wait` tests and `docs/task-router.md` PR-CI row; required-checks gap doc for gate design.

---

### FM-8 — Slow CI and inventory cost (delivery latency)

**What goes wrong.** Requests take far longer than the change itself warrants: full suites for tiny diffs, slow inventory hashing (issue #633: 30,384 files, 5+ hours per inventory pass on a loaded Windows host), hosted queue backlog (~20 minutes just to start), and preferred-lane misconfiguration sending 20 recent runs to the slow fallback lane.

**When.** Audit 2026-09-17 and baseline 2026-09-20; ENVY misconfiguration observed for PR #718 on 2026-09-23 (diagnosed 2026-09-25).

**How often.** Structural; affects almost every PR (median successful PR ~35 minutes, p90 ~58 in the September audit).

**Why.** Coarse test selection (improving: PR #805/#820 path-to-suite selection landed 2026-09-25), serial reviewer lanes, inventory subprocess-per-file, and a preferred-lane pre-check that only ran on manual starts so every PR skipped it.

**Proof.** `docs/ci-speed-audit-2026-09-17.md` and `plan_workflow-efficiency.md` §3 (66 successes / 20 cancellations / 12 failures in 100 runs). ENVY session: “The pre-check that looks for a free fast machine only ran when someone started a run by hand. On every pull request it was skipped, so all 20 recent runs went to GitHub’s slow machines.” Fix raised ENVY’s limit 30→55 minutes and proved fallback skip; Blacksmith overflow (#742) started for stuck Windows jobs.

**Known or new.** Known roadmap (#650). ENVY preferred-lane bug was a **new operational finding** in this window.

**Next owner.** `plan_workflow-efficiency.md` rows P3–P6, P10.

---

### FM-9 — Reviewer quota discovered only after failure

**What goes wrong.** “You’re out of quota” is usually discovered by reading an error after a review already failed. Most reviewer APIs do not expose subscription headroom; where they do (Gemini weekly/5-hour with reset times; Claude partial), the wrappers ignored the useful fields.

**When.** Investigated 2026-09-18 on edge-dev.

**How often.** Every long review on a constrained provider; adjacent to but distinct from GitHub rate limits.

**Proof.** Session that wired `ai-gemini-usage` and a pre-review headroom gate (39 offline tests): “Everywhere else, ‘you’re out of quota’ is discovered only by reading the error text after a review already failed. There is no headroom check before a run anywhere.” Shared reviewer status format still lacks the fields (left outstanding deliberately).

**Known or new.** Partially new (visibility gap); related to `plan_reviewer-reliability-and-efficiency.md` and `plan_reviewer-diagnostics-quota-preflight.md`.

---

## 5. GitHub rate-limiting / API quota — deep dive

### 5.1 What the account actually hit

Three different phenomena look the same from a chat window (“GitHub said no”):

1. **Primary hourly quota exhausted** — rare in this corpus. One request-reduction probe saw GraphQL exhausted while a later core probe still had 5000 remaining (wrong-bucket illusion). Programmes still treat full attribution as open (P1 under #658 / #660).
2. **Secondary / abuse-detection limit** — the dominant live failure on 2026-09-28. Five blocks, all at watcher ticks, all with full hourly allowance remaining. Triggered by request *rate*, not request *count*.
3. **Identity contention** — scheduled watchers and interactive sessions sharing one personal budget. Measured split: BlockerWatch ≈95% of managed traffic.

### 5.2 What produced the traffic

- BlockerWatch on a 10-minute schedule across multiple hosts (edge-dev primary propagation host; also edge-dev3 and hetz), scanning issues and writing state.
- Multiple waiters refreshing the same pull request status independently (fixed by coalescing, PR #948).
- Leftover direct `gh` callers outside `ai-gh` (routed in PR #973; installed proof still tracked).
- Interactive AI sessions acting as the owner (open PR, merge, comment) — must stay on the personal identity by design.
- Occasional tight polling in incident babysitting (documented to trip secondary limits).

### 5.3 What was fixed in this window

| Mitigation | Evidence | Status |
|---|---|---|
| Stagger watcher ticks per machine (minutes 3 / 6 / 9 past each 10-minute mark) | PRs #999, #1003, #1004; no refusals after 1:00 PM EDT 2026-09-28 | Live on edge-dev, edge-dev3, hetz |
| GitHub App `pop-ai-watchers` for scheduled ticks | PR #1006; live run 104 app points vs ≤1 personal | Live on edge-dev, edge-dev3 |
| Coalesce duplicate PR status reads across waiters | PR #948 / issue #925 | Accepted (edge-dev3 proof) |
| Route managed callers through `ai-gh` policy | PR #973 / #931 #933 | Merged; installed proof open |
| BlockerWatch snapshot reuse (cut per-item REST) | Code through #923; live savings proof #868 | Open (telemetry categories lag) |
| Quota-bucket separation / malformed-state fixtures | PR #929 | Accepted |
| Attribution / access-context join | PRs #970, #1000 | Merged; installed reporting open |

### 5.4 What remains

- P1 installed reporting and a comparable 20-operation baseline (#660).
- P5 live proof after install (#868) that BlockerWatch traffic actually dropped.
- P7 host/client install matrix (916 and hetz still pre-P1 in plan STATUS; personal auth routes unresolved).
- P8 measured before/after acceptance with no workflow regression.
- Historical GraphQL cost and quota snapshots cannot yet be joined to one credential context (plan STATUS 2026-09-28).
- Follow-ups #1001 (shared test-list split — may close as unnecessary if no ejection evidence) and #1002 (self-clearing locks / settings check) need owners.

---

## 6. CI failure deep dive

### 6.1 How a Windows job dies (and how it lies)

From `docs/windows-runner-interruptions-2026-09-01.md` and in-window sessions:

| Reality | Reported as |
|---|---|
| Queue regrouped / superseded | `cancelled` (honest) |
| Process killed mid-suite (local sweep, resource kill) | **`failure`** (looks like broken code) |
| Suite exceeded time limit under contention | **`failure`** (looks like broken code) |
| Local sweep cancelled the job | `cancelled`, cause invisible |

**Red is not evidence of broken code** on this Windows path until the failing step and timing are inspected. That single fact explains a large share of “CI failure” chat traffic in the corpus.

### 6.2 Capacity and routing

- Two self-hosted Windows runners on one physical desktop cannot serve concurrent AI + CI load; suite headroom was ~15% (62–65 min in a 75 min limit).
- GitHub-hosted Windows is free for this public repository and was underused for a while (sometimes deliberately, to keep flaky failures reproducible on fixed hardware — a real trade-off discussed in-session).
- Mitigations in flight: short reviewer-safety job on hosted runners (PR #219 routing proof), ENVY preferred lane with a correct pre-check and 55-minute limit, Blacksmith overflow (#742), a third Windows host (issue #209), and a watchdog for the pool.
- Smart App Control once prevented runner assemblies from loading (Code Integrity 3077/3033); that was a *start* failure, not a job failure — worth remembering when “runners look offline.”

### 6.3 Merge queue

- Full Windows matrix on merge_group was removed (FM-1).
- Queue ejection leaves PRs open; waiters must be ejection-aware (FM-7).
- Merging while another change’s queue run is live restarts that run — sessions repeatedly waited on “queue clear” before merging.

### 6.4 Flaky tests and timeouts

- See FM-6. Policy: do not inflate timeouts; name the real cause from observation; do not quarantine failures you cannot parse (risk of hiding real bugs).

---

## 7. Cross-cutting root causes

What ties CI and rate-limiting together:

1. **One shared bottleneck machine and one shared GitHub identity.** `edge-dev` hosts runners, daily work, and watchers; the personal token did everything. Both designs amplify every other failure.
2. **Failure modes that report as the wrong category.** Timeouts and kills look like test failures; secondary limits look like empty quota; preferred-lane misconfig looks like “CI is slow.” Sessions waste hours re-diagnosing the same mislabels.
3. **Synchronized background work.** Same concurrency key, same merge-queue rebuilds, same 10-minute watcher marks, multiple waiters on one PR — independent agents acting on the same clock without coordination.
4. **Suite and request growth without a ratchet.** Windows suite length and BlockerWatch scan volume both grew until they hit a ceiling (time limit / secondary limit) rather than being measured and reduced at the source.
5. **Missing preflight.** No headroom check before reviewer runs; preferred-lane check skipped on the common path; no alert on repeated cancellations.

These are why `plan_github-request-reduction.md` and `plan_workflow-efficiency.md` insist on *measured* before/after and *workflow-preserving* acceptance — fewer requests or faster green is not success if a safety check or wake path broke.

---

## 8. Proof appendix (paraphrased evidence)

All rows are paraphrased from private sessions or public docs. Times are EST where the source recorded local wall-clock.

| Date (approx.) | Machine | Kind | Observation | Fits |
|---|---|---|---|---|
| 2026-08-29..09-01 (doc) | edge-dev | mixed | PR #197 queued four times; run killed mid-suite reported as failure exit -1; local sweep overlapped CI; 75-min limit vs 62–65 min suite | FM-2, FM-3 |
| 2026-09-01 | edge-dev | Claude | Neither #161 nor #209 landed concurrency-key fix; PR #215 groups by PR number, skips Windows on merge_queue, required list = linux-offline only; live cancel-on-new-push proof; merged `ee2b5a82` | FM-1 |
| 2026-09-01 | edge-dev | Claude | Same day: every Windows run after ~3:00 PM hit 75-min timeout; morning passes 63/63/75 min; timeout kept as smoke alarm | FM-2 |
| 2026-09-01 | edge-dev | Claude | Started local full sweep while CI live — recognized violation and killed it | FM-3 |
| 2026-09-08..18 | edge-dev | Claude | SentinelOne exclusions: script 9.3×→1.5×, process launch still 2.1–2.5×; agent 4.2s CPU / 7s bench | FM-3 |
| 2026-09-18 | edge-dev | Claude | Reviewer APIs mostly do not report quota; only post-failure error text; shipped `ai-gemini-usage` + preflight gate | FM-9 |
| 2026-09-18 | edge-dev | Claude | edge-dev-win back in pool after resource storm; thread-cap questions | FM-3 |
| ~2026-09-20 | edge-dev | Claude | Issue #209 wrapper streams output, names interrupted test, 75→150 min flagged temporary; reviewer REJECT handled without override | FM-2 |
| 2026-09-20 (plan) | 916 | Codex | `failures.log`: GraphQL rate limit exceeded while follow-up core headers showed 5000 remaining (bucket mismatch) | FM-4 |
| 2026-09-23..25 | edge-dev | Claude | ENVY skipped on all PR runs (pre-check only on manual); 20 runs → slow fallback; ENVY 5× slower than qualify; raise 30→55 min and prove fallback skip | FM-8 |
| 2026-09-25 | edge-dev | Claude | Request-reduction work: reviewer reject on lock-after-crash flaw; 15s timeouts under load | FM-4, FM-6 |
| 2026-09-25 | edge-dev | Claude | PR #214 already merged with both Windows checks red at timeouts; same suite 62 min on ENVY vs three 75-min cancels on desktop | FM-2 |
| 2026-09-28 | edge-dev3 | Claude | Five blocks at 1:49/2:00/12:40/12:50/1:00 PM with 5000/5000 remaining; stagger watchers; PRs #999/#1003/#1004; no refusals after 1:00 PM | FM-4 |
| 2026-09-28 | edge-dev3 | Claude | App `pop-ai-watchers` separates scheduled ticks; 104 app points vs ≤1 personal; PR #1006 live on two hosts | FM-5 |
| 2026-09-28 | edge-dev3 | Claude | hetz watcher also on shared minute; staggered to :6/:16/:26 after SSH key fix | FM-4 |
| in-window | edge-dev | Claude | #89: eight flaky checks named from observation; inherited cause wrong; 207/3 under load; 24h repeat loop reported | FM-6 |
| in-window | edge-dev | Claude | Grok REJECT of flaky quarantine (unreadable failure formats); GLM: merge protection before flaky fix is harmful | FM-6 |
| in-window | shared-db / ai-devops | Claude | Merge queue funnel and ejection-aware waits; GraphQL auto-merge not enabled | FM-7 |
| 2026-09-15 late | edge-dev | Claude | Skill-trigger eval one-liners (“CI is still running…”, “A unit test failed once…”) — fixtures, excluded | method |

---

## 9. Limitations

- **Selection bias.** The corpus was pre-filtered to sessions *likely* about CI failures or GitHub rate limits. Counts are in-corpus only; they do not estimate fleet-wide incident rates. Sessions that merely *waited* on CI without discussing failures may be under- or over-represented.
- **Jev threshold.** Discarding topic_p < 0.10 with “>90% confidence not about the topic” can drop short but real incidents. Conversely, high topic_p does not guarantee relevance (several ≥0.40 sessions were about reviewer rotation, shared-db items, or Coldlion data and were excluded after reading).
- **Excerpt noise.** Many excerpts begin with worktree `system-reminder` preambles; titles were often empty. Priority selection therefore mixed topic_p, worktree/path slugs, and body text.
- **Timestamps.** A large share of remainder rows share an import stamp (2026-09-20T23:30) that is not the session’s true activity time; date clustering is approximate except where session bodies recorded absolute clock times.
- **Not fully read.** 39 of 309 sessions were deep-read in full text; the rest were stratified and sampled. Codex-kind sessions are underrepresented in deep-read relative to their 78/309 share (many were review-sandbox prompt fixtures). Mid/low topic_p bands were sampled, not exhaustively read.
- **Fixture burst.** The expected 2026-09-15 19:00–19:45 canned burst was not present under those timestamps; a similar skill-trigger evaluation cluster appeared near 23:23–23:25 and was excluded.
- **Paraphrase only.** Auditable detail is preserved (dates, PR/issue numbers, measured minutes, counts) but not raw transcript text. Private paths and digests remain in the private notes file only.
- **Causality.** Root-cause statements are hypotheses with evidence (live proofs, plan STATUS, doc cross-check). Where a session later revised a cause (e.g. flaky-test attribution), the revised observation is used.

---

## 10. Recommended next owners (summary)

| Priority | Action | Owner / map |
|---|---|---|
| 1 | Finish #658 P1/P5/P7/P8: installed attribution, BlockerWatch savings proof, host matrix, measured acceptance | `plan_github-request-reduction.md` |
| 2 | Keep watcher stagger + app identity; add a regression check that schedules stay desynchronized and scheduled ticks stay on the app | #658 / install owners |
| 3 | Distinguish timeout/kill/capacity from test failure in CI reporting (category, not just name) | `plan_workflow-efficiency.md` / issue #210 lineage |
| 4 | Suite length and capacity: keep timeout as alarm; finish routing (hosted short job, ENVY, Blacksmith, third host); revisit the 150-min internal limit downward | runner-pool / #650 |
| 5 | Flaky tests: observation-backed fixes only; no unreadable quarantine filters | #89 / #160 / #650 P7 |
| 6 | Owner-less follow-ups #1001, #1002 (or close #1001 as unnecessary with evidence) | assign explicitly |
| 7 | Required-check and ejection-aware waiter coverage | `docs/ai-devops-required-checks-gap.md`, `bin/ai-pr-wait` |

---

*End of report.*
