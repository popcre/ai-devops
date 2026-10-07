# Process bottlenecks and improvements — decision document for the owner

> **Owner ruling, 2026-10-07 EDT:** automatic one-child, one-phase and
> one-live-outcome stopping limits are permanently revoked. Older recommendations
> below imposing those limits are historical. Continue the authorized scope
> when actual dependencies, ownership, collision controls and safety gates allow;
> verify every outcome and keep genuine proof gaps on the same issue.

**Date range of evidence:** 2026-09-08 through 2026-09-29 (some live state checked 2026-09-30). Human times in EST.
**Written:** 2026-09-29/30. **Repository:** `popcre/ai-devops` (public).
**Purpose:** This is a decision document, not an incident log. It answers four questions in plain language: what we are doing wrong, where work piles up, which steps we should delete, and how to stop sessions sitting around waiting on CI. It is built from two filtered transcript studies (a 1,306-session process remainder and a 309-session CI/rate-limit remainder), the shared-db process diagnosis already in this repository, and the STATUS of the plans that already own related work. Every recommendation says what to change, why, the payoff, and the rough cost. Where work is already owned, this document says so and forbids a parallel plan.

---

## 2. Executive summary for Albert

Over these two weeks the work did not stall because the models were lazy. It stalled because our own process manufactures more open work than it finishes, and because failures report themselves as the wrong thing.

Sessions end by opening another ticket, starting another helper, or writing another handoff. In one measured 24-hour window of shared-db work there were roughly 57 issue opens against 25 closes, 155 leftover-proof mentions, and 308 unproven-step mentions. Five active sessions were each sitting "waiting on" three to five things our own process had created; 31 background helpers were running, and several of the things they waited on had already stopped. That is not a coding problem. That is a process shape problem.

CI lies about what went wrong. A Windows job that is killed under load, or that runs out of time because the machine is busy, is reported as an ordinary test failure. A GitHub block caused by too many requests in the same second is reported as "out of quota" even when 5,000 of 5,000 requests remain. One pull request even landed with both Windows checks red at exactly their timeouts. Sessions then spend hours re-diagnosing a mislabel instead of fixing anything.

Two hard capacity limits amplified everything: one shared Windows machine hosting runners and daily work, and one GitHub identity shared by background watchers and interactive work. The watcher identity has now been split (GitHub App `pop-ai-watchers`), and three machines' watchers were staggered off the same 10-minute mark after five same-day refusals — those two fixes worked and must be kept.

The highest-leverage changes are therefore not "add more checks." The agreed order after the Muse audit is below.

---

## 2b. Agreed plan (Muse audit, 2026-09-30)

This order supersedes the draft ranking. It was adversarially audited in a
back-and-forth with Muse (`muse-spark-1.3-contributor`, session
`process-plan-audit-20260930`) and both sides signed AGREE. Lead with the daily
merge tax; one-time cleanup trails.

1. **Label capacity as capacity.** Two labels only in the action taxonomy:
   `capacity/infra` vs `result`. Timeout, kill, and rate-limit are capacity.
   An empty reviewer verdict fails the **review step** and reroutes (map to
   workflow-efficiency P7) — it never reddens the PR test verdict. Detailed
   incident categories stay in reports only.
2. **Parallelize the merge critical path and finish fast-fail.** Finish
   workflow-efficiency P3/P5/P6 acceptance. Required `verification-closure` and
   the merge queue survive. Windows stays gating (parallel lanes). No path
   filters. Never raise ceilings.
3. **Delete waiters as a class.** Bounded in-session `ai-pr-wait` with an
   explicit deadline only. No TTL service, no parked-state store, no waiter
   registry. **`ai-blocker-watch wait` registration is out as any required or
   standing rule** (never adopted in practice; locked deletion in
   `plan_shared-db-coordination-deletion.md`). Turn-end blocker state lives on
   the issue and is re-surfaced by the bounded janitor. Voluntary registration
   is permitted, unrequired, unmeasured. Re-admit as a rule only on 14-day
   measured wake evidence.
4. **Coord-deletion residuals, one-time, inside the existing PR-A…D slice.**
   Hetz/t16 globals re-adopt, machine-tools duplicate rows, parked-issue tidy.
   No new programme and no new tracking issue.
5. **Maintenance out of the hot path, no new machinery.** O(1) preflight,
   pin-only qualification, unowned reviewer doc table (reviewer → wrapper → pin
   → reroute), and the two named wrapper fixes (Qwen `NODE_OPTIONS` sandbox;
   Gemini headless command blocks) with reroute-on-empty.

**Binding constraints on every row.** Each row maps to exactly one existing
owner (#650 / #658 / #1061 / #511). Unmapped rows are rejected. Janitor bounds:
6h per-PR cooldown, comments only, never opens issues, no comment after human
activity in 24h, kill switch on the #1061 lineage. Windows runner slowness is
infra (#209 / #262), not process — this plan does not fix hardware. Keep list
unchanged: live proof before close, exact-head independent review, no path
filters on required checks, #401 and #204 stay closed.

---

## 3. What we are doing wrong (ranked)

### 3.1 The process manufactures more open work than it closes

**Wrong behavior.** Every incomplete live proof, every gap, every successor used to become a new issue, a new handoff, or a new marker. Opening is cheap; closing needs review, checks, merge, preview, production, and live proof. The queue grows while people are busy closing the old queue.

**Evidence.** Shared-db last-24h counts (~57 issue creates vs ~25 closes; 155 leftover-proof and 308 unproven-step mentions), recorded in `docs/reviewer-failure-evidence/process_diagnosis.md` and `docs/shared-db-delivery-failure-background-2026-09-29.md`. Owner-reported picture at the same time: five sessions each waiting on 3–5 process-created things, "nothing getting done." The throughput programme #401 closed as complete on 2026-09-20 with a rule that we would "never trip a GitHub rate limit again"; within ten days the same classes of failure were back. The mechanism was fixed; the shape that re-creates the stall was not.

**Why it happens.** The leftover-proof rule exists for honesty — never claim an unproven live result. That is correct. It was implemented as "open a new issue," which converts honesty into backlog. Handoff and marker succession were implemented as ceremony (new marker issue, handover PR, re-read, re-own the queue, re-fan-out helpers), which converts resilience into re-orientation.

**What to do instead.** Honesty stays; ticket-milling goes. A missing proof is a checklist item on the **same** issue, not a new issue. Claim-first is now the default: claim exact objects on the existing issue and start; no orchestrator chat or marker is required. Successors resume the queue; they do not rebuild it.

**Status.** Already owned and largely landed by `plan_shared-db-coordination-deletion.md` (parent #1061 and children closed 2026-09-30). Do not open a parallel plan. Finish the residuals only: globals re-adopt on Hetz (and t16 when reachable), the duplicate rows in the machine-tools table that break launcher sync, and the one-time tidy of old "parked" shared-db issues (waiting on a conductor, waiting on "after X merges", dead sessions). That tidy is cleanup with the deletion, not a new programme.

### 3.2 Sessions wait on work the process itself created, and the wait never dies

**Wrong behavior.** A session parks behind a helper, a reviewer verdict, or another session's pull request. The target stops, crashes, or is never going to answer. The waiter does not notice. Nothing expires it.

**Evidence.** The blocked-sessions investigation (2026-09-28/29, `process_diagnosis.md` §2.2) found 31 background helpers and waiters running while their targets had already stopped. Helper agents stop without reporting and get restarted. A merge helper that lived in a chat session died on restart ("the queue is not drained; nothing has merged"). BlockerWatch wakeups historically started a *new* session and lost context. One author-acquisition lock was held for about two hours under the same commit with reviewer draws refused behind it.

**Why it happens.** Waiters watch a state, not a liveness contract. Ephemeral state lives in scratch directories that other sessions wipe or overwrite (briefs relocated multiple times in one evening). There is an add-work counterpart (register a wait, open a ticket) and no remove-work counterpart.

**What to do instead.** Waiters and helpers must self-clear: if nothing they depend on has changed for a bounded time, they expire and post one line naming the real owner or the dead target. Locks get a short TTL and automatic recovery when the holder is gone. Parking must leave a machine-readable state file so the next turn *resumes* instead of redoing. One scheduled "unstick" duty (not a chat) is allowed only to free or name — never to create new work items.

### 3.3 Failures report as the wrong category, so everyone re-diagnoses the same mislabels

**Wrong behavior.** A capacity timeout and a process kill both show up as ordinary test failures. A secondary rate limit shows up as "out of quota." A preferred-lane misconfiguration shows up as "CI is just slow." An empty reviewer report shows up as PASS.

**Evidence.** `docs/windows-runner-interruptions-2026-09-01.md` records the death modes; two of four masquerade as test failures. One PR (#214) merged with both Windows checks red at exactly their timeouts while the same suite later passed in 62 minutes on a faster host. On 2026-09-28 five GitHub refusals landed at watcher ticks with the hourly allowance still at 5,000 of 5,000 (`docs/ci-failures-and-github-rate-limit-report-2026-09-29.md` FM-4). Reviewer quota is discovered by reading error text *after* a review already failed (FM-9). One provider produced a bare PASS with an empty report (process-improvements study, reviewer-registry finding).

**Why it happens.** The platforms report the same surface symptom for different causes, and our wrappers did not add a category. Sessions then burn hours proving "the code is fine" — which it usually was.

**What to do instead.** One required change in reporting: every failed check and every refused call must carry a **category** (test failure / timeout-capacity / killed-interrupt / rate-limit-capacity / empty-verdict / config-drift). Timeout, kill, and rate-limit are **capacity** outcomes and must not invalidate an exact-head approval — they park the merge, they do not reopen review. Empty/no-verdict is a FAILURE, never a PASS.

### 3.4 Long Windows work sits on the merge critical path of everything

**Wrong behavior.** Small changes buy hour-long Windows suites. The merge queue used to re-run the full Windows matrix on every rebuild (one change restarted a 75-minute job five times). Unrelated required checks block changes that cannot touch them. Merging while another change's queue run is live restarts that run, so sessions wait on "queue clear."

**Evidence.** Issue #204 / PR #215 fixed the worst of this (group runs by PR number, skip Windows on `merge_group`, required list = `linux-offline`) and proved a second push now cancels the first build. Before the fix, one 75-minute job restarted five times for one PR. Remaining friction is everywhere else: September audit median successful PR ~35 minutes, p90 ~58; hosted queue backlog ~20 minutes just to start; preferred-lane pre-check that only ran on manual starts sent 20 recent runs to the slow fallback lane (fixed 2026-09-25, ENVY limit raised 30→55 minutes); flaky checks hold up unrelated work with no safe "known flaky, do not block" path (a quarantine design was correctly rejected because 24 test files report failures in a format the filter could not read — it would have hidden real bugs).

**Why it happens.** Safety correctly wants a green merge queue. Selection was coarse (improving: path-to-suite selection landed 2026-09-25 via #805/#820). Capacity was one physical host with ~15% suite headroom (62–65 minutes inside a 75-minute limit). "Red" was trusted as "broken code" (see 3.3).

**What to do instead.** Keep the queue and keep required checks; change what runs on the critical path and how red is labeled. Short reviewer-safety work already routes to free GitHub-hosted runners (this is a public repo). Keep Windows off the merge-group path. Finish the affected-test selector acceptance (P4/P5). Prefer fixing observed flaky causes (the #89 work: 15-second wait ceilings losing to process startup under load; concurrency assertions that are inherently load-sensitive; one check that never tested anything) over any quarantine filter. Do **not** add path filters to required checks — that is a locked constraint from the merge-queue guard; use aggregate verification and capacity instead.

### 3.5 Reviewer machinery fails closed and takes days to repair

**Wrong behavior.** Preflights run maintenance work inline and blow their own budgets (a doctor that prunes/reconciles per record exceeded a 60-second governed-review preflight, so every review "failed"). A 10-second live preflight timeout rejects legitimate starts. A provider auto-updated past its approved pin and the whole pool went down. Membership lives in more than one place and rots (retired providers still listed; about an hour spent reaching a removed reviewer). Fixing a broken reviewer wrapper often requires the broken reviewer to review its own fix, and one such fix stalled on an unrelated Windows lane while a competing fix appeared.

**Evidence.** Process-improvements study findings 1–3 (reviewer registry, bounded preflight, pin-only qualification) with deep-read incidents including all four rotation reviewers refusing to start on one machine (#686), a local review server in a hang/crash loop for days, and an empty PASS from a drifted provider (#285). Qwen and Gemini wrapper breaks in the shared-db window (2026-09-28/29) each spawned incident → fix PR → governed review → install → live re-qualification → leftover-proof issue. "No policy lets a required check be skipped" blocked a wrapper fix behind a Windows lane that runs none of the changed files.

**Why it happens.** Safety wants a broken reviewer to be repaired under review (correct in principle). It also put maintenance sweeps in the check path (incorrect). It also made a version bump cost a full qualification (incorrect scale).

**What to do instead.** Preflight = cheap fixed checks only (binary present, health probe, version pin). Prune/reconcile becomes a scheduled maintenance command with a wall-time budget and a regression test. One authoritative reviewer registry with a CI check that fails when mirrors disagree. Pin-only qualification lane: hash the binary, doctor, one live smoke; auto-quarantine on pin mismatch and auto-restore when the pin is updated in the same change. When the wrapper itself is down, allow a cheaper path: self-fix + live re-qualification + owner notice, instead of a full pool review of the fix to the reviewer.

---

## 4. Bottlenecks — where work piles up

| Bottleneck | Symptom | Root cause | What it costs | What relieves it |
|---|---|---|---|---|
| **CI funnel (merge queue + verify)** | Nothing moves; PRs wait in one ordered line; median PR ~35 min, p90 ~58; ~20 min hosted queue backlog; shared-db side saw ~20 workflows per push and ~957 Actions runs in one hour | Coarse selection (improving), full suites for tiny diffs, Windows on the critical path, per-push fan-out | Hours per small change; "queue clear" babysitting | Affected-test selector acceptance (P4/P5, already landed in code), keep Windows off merge_group (landed), aggregate per-push workflows with concurrency groups (direction already opened in shared-db #3744/#3746), auto-cancel superseded queue entries |
| **Single Windows host / capacity** | Suite at 62–75 min inside a 75-min ceiling; runs die under local load; ENVY ran 5× slower than at qualification; Blacksmith judged expensive | Two runners on one physical desktop plus daily work plus endpoint software (process-launch overhead still 2.1–2.5× after exclusions); preferred-lane pre-check only on manual starts | Whole-day stalls; timeout-as-failure re-diagnosis | Routing already improved (hosted short job, ENVY preferred lane fixed, Blacksmith overflow #742). Remaining: third host capacity, keep the internal 150-minute limit temporary and bring it down as capacity becomes real, never raise ceilings to silence the alarm |
| **One shared GitHub identity (largely fixed)** | Work stopped on rate-limit holds; background scans starving interactive work | Scheduled watchers used the personal token; BlockerWatch was ~95% of measured managed traffic; three machines ticked on the same minute (secondary limit) | Whole-fleet pauses on the owner's budget | Keep App `pop-ai-watchers` for scheduled ticks (PR #1006) and the per-machine tick stagger (PRs #999, #1003, #1004). Finish #658 remaining rows (installed attribution, BlockerWatch savings proof, host matrix, measured acceptance) — already owned by `plan_github-request-reduction.md` / `plan_cut-unneeded-github-traffic.md` |
| **Reviewer preflights and qualification** | Reviews fail "doctor did not answer within 60s"; pin bump costs two days; out-of-quota discovered after failure | Sweeps inside the check path; too-short timeouts; no headroom check; multiple membership sources | Multi-day reviewer outages; competing fix PRs | Bounded O(1) preflight, pin-only lane, single registry, headroom gate before long reviews (`ai-gemini-usage` pattern is the model — extend or do not duplicate) |
| **Handoffs and succession** | Hours of re-orientation; claims left under dead names; briefs wiped; marker rotation (#3570 → #3655-style chains) | Handoff as ceremony; ephemeral scratch state; required orchestrator role | Most wall-clock was coordination, waiting, handover, re-orientation | Coordination deletion (landed: claim-first, no marker, no chat conductor). Keep handoffs for **unfinished work only**. Positive machine-checkable conditions in handoff text, never bare negative instructions |
| **Waiters and background helpers** | 31 helpers running against stopped targets; orphan 14-hour background tasks; 24-hour repeat of one ~6-hour test | No liveness, no TTL, no no-progress detector; waits do not expire | Days of apparent activity with zero delivery | **NOT ADOPTED as TTL/park-state** (#1183 c3). Bounded in-session deadlines + issue-as-card only |

---

## 5. Unnecessary steps and processes to CUT

This is the highest-value section. Prefer deleting rules over adding them.

### CUT-1 — Leftover-proof / unproven-step ticket mill (delete; do not bring back)
**What it is.** Any missing live proof became a new issue ("open exactly one leftover-proof issue"). **Why it existed.** Honesty: never claim an unproven live result. **Cost.** ~155 leftover-proof and 308 unproven-step mentions in one 24h window; issue opens outran closes ~2:1. **Delete/collapse.** Already deleted by `plan_shared-db-coordination-deletion.md` (Step 2, landed with parent #1061). A missing proof is a checklist item on the **same** issue. The honesty rule itself stays.

### CUT-2 — Negative handoff wording that blocks free work
**What it is.** Handoff lines like "do not run X while Y" without a machine-checkable condition. **Why it existed.** Caution. **Cost.** At least one session idled while a runner slot was actually free because a handoff forbade the work; sibling instructions elsewhere told it to proceed. **Delete/collapse.** Rewrite as positive conditions ("run X when Y is green") or as a check the tool can evaluate. Ban bare negative instructions in handoff templates.

### CUT-3 — Duplicate qualification and per-change full re-qualification
**What it is.** A version-pin bump or a tiny wrapper change triggering a whole check, Windows run, and live re-qual. **Why it existed.** One qualification standard for every change size. **Cost.** Two days for a pin change; the owner asked why a version update needs "a whole check, windows run, etc." **Delete/collapse.** Pin-only qualification lane (hash + doctor + one live smoke). Reserve full qualification for behavior changes.

### CUT-4 — Sweeps inside the preflight/check path
**What it is.** Doctor/preflight running prune, reconcile, or per-record process spawns inline. **Why it existed.** Convenience — keep the system tidy on the way through. **Cost.** A 60-second governed-review preflight blown at ~150 records, so every review failed; a 10-second default timeout rejecting legitimate starts. Fixes took 5–6 days. **Delete/collapse.** Preflight is O(1) fixed checks. Maintenance moves to a scheduled command with its own budget and a regression test on wall-time.

### CUT-5 — Redundant plans, issues, and "monitoring" artifacts
**What it is.** Several dozen `plan_*.md` files, follow-up issues opened during diagnosis (#1001 and #1002 were spawned mid-investigation and are already finished — another session will close them; do not reopen or extend), parked issues waiting on a conductor or "after X merges", programmes that close while children still instruct execution. **Why it existed.** Traceability. **Cost.** Sessions spend the first hour reconciling owners instead of doing the work; new sessions re-plan already-owned work. **Delete/collapse.** Reuse before adding (standing rule). When work is owned, finish or cut that plan's remaining steps — never open a parallel plan. Do the one-time parked-issue tidy with the coordination-deletion residuals. Close finished investigation spin-offs promptly.

### CUT-6 — Polling and waiting that outlives what it waits on
**What it is.** Waiters with no deadline, helper agents that stop silently, BlockerWatch-style registration as ceremony, restart-from-scratch wakeups. **Why it existed.** To not lose work. **Cost.** 31 live waiters on dead targets; 14-hour orphan tasks; one 24-hour repeat loop of a single ~6-hour test with no progress. **Delete/collapse.** Every wait needs a deadline or iteration cap (already a standing rule — enforce it in the tools, not only in prose). Self-expiring waiters. Required BlockerWatch *registration* is already shrunk to the automatic stuck-PR janitor; do not re-add registration, `has-wait`, or `--park` as required process. Background tasks get a TTL and auto-reap with a one-line summary.

### CUT-7 — Marker succession and orchestrator ceremony
**What it is.** Rotating marker issues, claim transfer tools, re-fan-out of fixer helpers on every successor. **Why it existed.** To keep a single coordination point alive across sessions. **Cost.** Hours of re-orientation per handover; claims reserved under dead predecessors; the claim-transfer tool was itself blocked by competing edits. **Delete/collapse.** Already deleted (claim-first; no required orchestrator; chat merge conductors stopped). Do not replace with a new lock, scheduler, watchdog, or issue type. Successor handover is "resume the queue," not "rebuild the queue."

### CUT-8 — Any rule that creates a ticket instead of finishing work
**What it is.** The general shape behind CUT-1: when a gap appears, mint an issue. **Why it existed.** Cheap traceability. **Cost.** The queue grows faster than outcomes close; the #401 programme closed "complete" while the same failure modes returned within days. **Delete/collapse.** Default is finish the gap in-session. If it cannot be finished in-session, it is a checklist item on the existing issue with one named owner. New issues are for genuinely new needs, with an owner and a reason the existing issue cannot serve.

### CUT-9 — Wall-clock test assertions and silent timeouts
**What it is.** Tests that assert timing windows; guessing timeouts; a check that waited for a filename pattern that could never match and passed because its wait was shorter than a fake delay. **Why it existed.** Quick coverage of concurrency/timeout behavior. **Cost.** Flaky reds under load block merges; 24-hour no-progress loops; inherited diagnoses blamed the wrong timers on both suites. **Delete/collapse.** Ban wall-clock assertions (lint the test tree); use deterministic fixtures/fake clocks. PR #123 already removed guessing and silent timeouts and found four genuine bugs — finish that direction. Never "fix" flakiness by raising timeouts.

### CUT-10 — Per-push workflow fan-out
**What it is.** Many small workflows firing per PR push (~20 on the shared-db side; ~957 Actions runs in one hour before partial fixes). **Why it existed.** Independent concerns, each with its own workflow. **Cost.** Runner burn, quota burn, queue depth, secondary rate limits. **Delete/collapse.** One aggregated pull-request workflow with concurrency groups (runs per push already fell from 8/13/78 to 2–5 where that landed). Keep the policy test that asserts PR-number concurrency grouping and Windows-off-merge-group so the old shape cannot return.

### CUT-11 — Contradictory delivery instructions (four stages vs full local vs focused vs "never verify twice")
**What it is.** Docs that describe several delivery procedures at once. **Why it existed.** Historical accumulation. **Cost.** Agents obey one paragraph by violating another; "never verify the same commit twice" collides with "run the full suite before merge." **Delete/collapse.** One authoritative proportional procedure (this is already row P8 of `plan_workflow-efficiency.md` — finish it; do not write a new procedure document).

---

## 6. How to stop sessions sitting around waiting on CI

Concrete mechanisms and a numbered playbook. Several pieces have already landed; the playbook says what remains.

### 6.1 Mechanisms that work

1. **Auto-cancel superseded runs (landed — keep it).** Runs are grouped by PR number, so a new push cancels the old build. Live proof: a second commit cancelled all three jobs of the first; the merge-queue run skipped both Windows jobs with zero runner minutes versus ~100 before. Keep the policy test. Residual risk is a workflow that reintroduces SHA-keyed grouping or Windows-on-merge-queue.

> **SUPERSEDED by §2b (Muse-agreed, 2026-09-30) and #1183 child 3.** Draft items below that add park-with-state, self-expiring waiters, or background-task TTL are **not** adopted. The agreed shape is bounded in-session `ai-pr-wait`/`ai-gh-wait` with an explicit `--timeout-minutes` deadline only; turn-end state lives on the issue. Required BlockerWatch registration is OUT.

2. **Ejection-aware waiters that terminate on every terminal outcome.** A merge-queue ejection leaves the PR OPEN; a waiter that only watches for "merged" waits forever. `bin/ai-pr-wait` must end on merge, ejection, closure, or failure — and must say which. That is already the contract in `docs/task-router.md`; make every caller obey it, and reject waits started without a deadline.

3. **Capacity routing so one slow Windows job does not block everything.** Short reviewer-safety work on free GitHub-hosted runners (public repo). ENVY preferred lane with a pre-check that actually runs on the PR path (the bug that sent 20 runs to the slow lane is fixed). Blacksmith overflow for stuck Windows jobs (#742). Windows jobs skipped on `merge_group`. Affected-test selection so a one-file change does not buy every suite (landed 2026-09-25; finish P4/P5 acceptance). Prefer a short Windows job on the queue over the 75-minute one.

4. **Park versus redo.** **NOT ADOPTED** under #1183 child 3 (no park-state store). A long wait leaves the issue/PR as the card; the turn ends.

5. **Separate lanes and identities.** Scheduled background traffic on App `pop-ai-watchers`; interactive work stays personal. Per-machine watcher ticks stay staggered (minutes 3 / 6 / 9 past each 10-minute mark). Keep both; add a regression check that schedules stay desynchronized and scheduled ticks stay on the app.

6. **Report timeout/kill/rate-limit as capacity, not as test failure.** This is the single biggest reducer of "sitting around re-diagnosing." A red check whose category is `timeout-capacity` or `killed-interrupt` is an alarm about machines, not about code. Rate-limit failures park the merge; they do not invalidate an exact-head approval and force a new review cycle.

7. **No-progress detection.** If the same test fails the same way N times, stop and report the category. No session may repeat a multi-hour suite for a day. The 24-hour loop (owner-reported) is exactly this failure.

8. **Do independent useful work while waiting (rule already exists — make it structural).** A session that is waiting on CI should be doing another bounded task, or the turn should end with the issue/PR as the card (registration is OUT). Sitting in the turn polling is forbidden and is also how secondary rate limits get tripped.

### 6.2 Numbered playbook

1. **Keep** PR-number concurrency grouping and Windows-off-merge-group; add/keep one policy test so they cannot regress. *(Landed; residual = keep the test.)*
2. **Make every waiter ejection-aware and deadline-bounded** in the tools (`ai-pr-wait` / `ai-gh-wait`), not only in prose. Waiter terminates on every terminal outcome and names the category. *(Small; under `plan_workflow-efficiency.md` / task-router PR-CI row.)*
3. **Category in CI reporting:** timeout, kill, and rate-limit reported as capacity. Needed by issue #210 lineage and `plan_workflow-efficiency.md` P7. *(M; highest payoff of the remaining CI work.)*
4. **Finish capacity routing:** keep hosted short job + ENVY + Blacksmith; do not raise ceilings; bring the temporary 150-minute internal limit down as real capacity lands; third host if the pool still has ~15% headroom. *(M/L; runner-pool lineage, #209 successor work, `plan_windows-runner-maintenance-elevation.md` for maintenance only.)*
5. **Self-expiring waiters and background-task TTL** — **NOT ADOPTED** under #1183 child 3 (no TTL service).
6. **Aggregate per-push workflows with concurrency groups** on the shared-db side to finish what #3744/#3746 started; keep ai-devops workflows as they are once grouping tests are green. *(M; shared-db non-orchestrator work plus this repo's workflow-policy tests.)*
7. **Quota failures park, never re-review.** If the only failing checks are rate-limit/capacity, do not invalidate approvals and do not start a new review cycle. *(S; policy + one test.)*
8. **Ban open-ended waits in session instructions** (already the standing rule) and add a cheap lint/guard so a handoff cannot instruct an unbounded loop. *(S.)*
9. **Park-with-state** — **NOT ADOPTED** under #1183 child 3 (no park-state store). Leave the issue/PR as the card.
10. **Keep the stagger and the app identity** and add the regression check. *(S; already owned under #658.)*

---

## 7. Other improvements (high payoff)

**Install drift doctor.** Duplicate installs shadow each other (old CLI first on PATH), stale 1Password item names break MCP servers ("half the MCP servers are now failing"), SSH host-key checks fail, wrappers fail because the password-manager CLI is not visible. Each incident is rediscovered by hand. One `ai-fleet-doctor` (per machine: versions vs declared pins, duplicates on PATH, secret references resolve, MCP servers answer, SSH known_hosts) run at session start and on runner images. Treat a stale secret reference as an install bug — fix the reference. **Effort M.** Note the live residual from coordination deletion: duplicate rows in the machine-tools table break launcher sync on every machine — fix that first; it is small and already flagged.

**Empty-verdict rejection.** A review that returns no verdict or an empty report must be a FAILURE, never a PASS. One provider already produced a bare PASS with an empty report. **Effort S.** This is a safety fix disguised as an efficiency fix.

**One reviewer registry, drift-checked.** Membership in two places rots. A CI check fails when mirrors disagree; the allocator consults only the registry. **Effort M.** Already drafted in-session; land and enforce it.

**Reviewer quota headroom before the run.** "Out of quota" should be known before a long review starts, not read out of an error afterwards. Where a provider reports headroom (Gemini weekly/5-hour with reset times; Claude partial), use it — the `ai-gemini-usage` + pre-review gate pattern is the model. Do not build a second copy. **Effort S–M.**

**Session sizing hygiene.** Multi-day sessions with 3–5 context compactions, 14-hour orphan background tasks, and repeat loops with no change. Keep "one unproven live-behavior outcome per session" — but when the remaining gap is a checklist item, finishing it in-session is cheaper than a handover. Add a wrap-up gate that lists leftover proof items on the **same** issue. Cap wall-clock per task in the harness. **Effort M.** Already partly owned by `plan_live-proof-session-sizing.md` (Step 8 is the only open row: installed-global proof and close). Finish that; do not reopen the design.

**Work-claims before edits.** Owner: "we've had a LOT of collisions." Parallel sessions edited the same wrappers; one session's commit broke another's; exact-head reviews went stale. `plan_ai-devops-work-claims.md` already owns this (issue #131). Land it as a pre-edit claim; do not start another claims design.

**Locks with TTL.** Author-acquisition locks held for hours under a dead holder. Short TTL + automatic recovery when the holder is gone. **Effort S.**

**One place that shows why nothing is moving.** A single `ai-ci-status` (queue depth, per-lane wait, tip-PR owner, cost/day) surfaced in the task router and in the automatic stuck-PR janitor. The owner currently cannot tell who owns a stuck merge. **Effort M.** This is visibility only — it must not become a new coordinator role.

**Merge path durability.** The chat merge conductor is deleted (correct). The durable merge path is the repository's own merge queue. Do **not** build a replacement conductor, scheduler, or lock. If anything is needed, it is a scheduled unstick duty that frees or names — never one that merges on its own authority or creates work items.

---

## 8. Prioritized action table

Ranked by impact ÷ effort. "Already owned" means: finish or cut that plan's remaining steps. Do not open a parallel plan.

| # | Change | Why it matters | Effort | Owner / plans already open | Do-not-do |
|---|---|---|---|---|---|
| 1 | Finish coordination-deletion residuals (Hetz/t16 globals adopt, machine-tools duplicate rows, one-time parked-issue tidy) | The ticket-milling process is deleted on paper and on main; residuals are what still create handoff drag | S | `plan_shared-db-coordination-deletion.md` (#1061 closed; residuals in the 2026-09-30 handoff) | Do not re-add leftover-proof issues, required orchestrator, markers, chat merge conductor, or BlockerWatch registration |
| 2 | Report timeout / kill / rate-limit as **capacity** categories; empty verdict = FAILURE | Stops hours of re-diagnosing mislabeled red; stops rate-limit from invalidating approvals | M | `plan_workflow-efficiency.md` P7; issue #210 lineage | Do not raise timeouts or delete assertions to make red go away |
| 3 | Self-expiring waiters + background-task TTL + park-with-state | Kills the "31 waiters on dead targets" and multi-day idle shapes at the source | M | Fold into `plan_blockerwatch-reliability-repair.md` or `plan_workflow-efficiency.md` | Do not add a new watchdog programme or a new issue type |
| 4 | Keep CI off the critical path: PR-number grouping, Windows off merge_group, hosted short job, ENVY pre-check on PR path, Blacksmith overflow, affected-test selector acceptance | The difference between a 35-minute change and a day | M (much already landed) | `plan_workflow-efficiency.md` P3–P5; runner-pool lineage; #742 | No path filters on required checks (locked). Do not reopen #204. Do not put Windows back on merge_group |
| 5 | Bounded O(1) preflight + pin-only qualification + single reviewer registry | Reviewer outages currently cost days; pin bumps cost two days | M | `plan_reviewer-reliability-and-efficiency.md`; `plan_reviewer-diagnostics-quota-preflight.md`; pin-only lane is new but small | Do not put prune/reconcile in the check path. Do not require a full pool review to fix a down wrapper |
| 6 | Separate identities kept + finish #658 acceptance rows (installed attribution, BlockerWatch savings proof, host matrix, measured acceptance) | Background traffic must never starve interactive work again | L (measurement heavy) | `plan_github-request-reduction.md` #658; `plan_cut-unneeded-github-traffic.md` S1/S4 | Do not reopen #401. Do not build a fleet coordinator without same-principal contention evidence (P6 decision) |
| 7 | Ban wall-clock assertions; no-progress detector (N identical failures ⇒ stop) | Ends 24-hour loops and load-flakes at the source | M | #89 / #160; `plan_workflow-efficiency.md` P7 | No flaky-quarantine filter that cannot read the failure formats it would suppress |
| 8 | Finish live-proof session sizing Step 8 (installed-global proof, close #511); checklist-item rule for small gaps | Keeps honesty without the handoff tax | S | `plan_live-proof-session-sizing.md` | Do not bundle several unproven outcomes into one session; do not steal another owner's remaining proofs |
| 9 | Aggregate per-push workflows with concurrency groups (finish the shared-db direction) | ~20 workflows per push and ~957 runs/hour is pure waste and quota risk | M | shared-db #3744/#3746 direction (non-orchestrator); workflow-policy tests here | Do not weaken required checks to make the queue shorter |
| 10 | Fleet install-drift doctor + stale secret-ref as install bug | Repeatedly rediscovered incidents (PATH shadowing, MCP death, SSH keys) | M | new small tool under existing install/deployment docs | Do not make the doctor a required gate that can block ordinary work |
| 11 | One `ai-ci-status` visibility surface | Owner can see who owns a stuck merge and what a day costs | M | under `plan_workflow-efficiency.md` | Must not become a new coordinator role |
| 12 | Close investigation spin-offs (#1001, #1002 already finished — closing elsewhere) and stop minting issues during diagnosis | Stays true to "cut process over adding process" | S | already finished; one-time tidy only | Do not reopen or extend those two; do not open a "cleanup programme" |

---

## 9. What NOT to change

So nobody "fixes" this by adding process back:

- **The shared-db safety engine:** exact-object claims, permanent version reservation in GitHub refs, stage leases for preview/merge/production, forward-only migrations, dependency closure, target-database proof. Overlap must fail closed before SQL runs.
- **Exact-head independent review** of the PR head, including the independent review requirement for reviewer-safety path changes (wrappers, evidence tools, safety tests, installed routing rules).
- **Live behavior verification before close**, with an exact stated reason on claim close.
- **The merge queue and protected `main`.** Feature branch → PR → merge queue. Never push to a protected `main`.
- **`bin/ai-gh` as the only GitHub transport** (lock, spacing, hourly budget, rate-limit back-off) and bounded, event-aware waiting through `ai-pr-wait` / `ai-gh-wait`.
- **"One unproven live-behavior outcome per session"** and "never save leftover proofs for later sessions." The honesty rule stays; only the ticket-milling implementation is gone. When the remaining gap is a checklist item, finish it in-session.
- **The timeout as a smoke alarm.** Do not raise ceilings to hide capacity problems. Do not inflate timeouts until nothing fails.
- **Watcher stagger + App identity separation** for scheduled ticks.
- **Independent useful work while waiting**, and the local-sweep collision rule (`ai-test-local --check-collision`) so a local full series never overlaps a live GitHub job on the same physical host.
- **Observation-backed flaky fixes** (name the real cause). No unreadable quarantine filters.
- **No path filters on required checks** (merge-queue guard constraint). Use aggregate verification and real capacity instead.
- **Do not reopen** #401 (throughput programme — closed decision record), #204 (concurrency grouping — fixed), #1001/#1002 (finished; closing elsewhere). Do not replace the deleted orchestrator with a new lock, scheduler, watchdog, or issue type.

---

## 10. Limitations

- **Selection bias.** Both corpora are filtered remainders ("not clearly unrelated"), biased toward failure and slowness. Counts are in-corpus only; they do not estimate fleet-wide incident rates. Sessions that merely waited on CI without discussing it may be under- or over-represented.
- **Classification.** Automated classification selected candidates for reading; every claim here is grounded in what sessions and repository documents actually show. Short real incidents can be dropped by a confidence threshold; high topic scores do not guarantee relevance (several high-score sessions were about reviewer rotation or data work and were excluded after reading).
- **Depth.** Of the 309 CI/rate-limit remainder, 39 sessions were deep-read in full; the rest were stratified and sampled. The 1,306-session process remainder used 22 deep reads plus keyword screens over titles/excerpts. Codex-kind sessions are underrepresented in deep-read relative to their share.
- **Timestamps.** A large share of imported rows carry a bulk-import stamp (2026-09-20) that is not true activity time; date clustering is approximate except where bodies recorded absolute clock times.
- **Corpus scope.** Private chat transcripts 2026-09-08..29 (CI focus 09-15..29) across the owner's AI clients and hosts. Product/application work, licensed data, and other repositories are out of scope except where they show toolkit process failures. Shared-db numbers cited here are from `popcre/shared-db` (the coordination/queue observations are non-orchestrator operational work; structural database work is separate and claim-first).
- **Causality.** Root causes are evidence-backed hypotheses. Where a session later revised a cause (flaky-test attribution was wrong in an inherited note), the revised observation is used.
- **Privacy.** No raw transcript text, secrets, tokens, emails, or private paths appear in this document. Auditable detail is paraphrased (dates, issue/PR numbers, measured minutes, counts).

---

## If we only did five things

1. **Finish the coordination-deletion residuals** (globals on Hetz, machine-tools duplicates, parked-issue tidy) and never re-add the ticket mill, orchestrator role, markers, or required wait registration.
2. **Label timeout / kill / rate-limit as capacity** in CI and waiter reporting — and never let a capacity failure invalidate an exact-head approval.
3. **Make waits die:** **NOT ADOPTED as TTL/park-state** (#1183 c3). Bounded explicit deadlines + leave the issue/PR as the card.
4. **Keep long Windows work off the merge critical path** and finish real capacity routing (hosted short job, ENVY, Blacksmith, affected-test selection) — without raising ceilings.
5. **Take maintenance out of the hot path:** O(1) preflight, pin-only qualification, one reviewer registry, empty-verdict = failure.

---

*End of document.*
