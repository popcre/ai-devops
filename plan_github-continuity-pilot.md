---
summary: Three bounded experiments for GitHub outages, shared PR status and slow checks.
kind: plan
status: open
read-when: Testing GitHub outage continuity, status request savings or check delays
---

# Can work continue through a GitHub outage, and what slows down a busy day?

Keep people working through interruptions and shorten delivery on ordinary days. [Execution handoff](HANDOFF.d/2026-11-25T1632Z-edge-dev3-codex-github-pilot.md).

## STATUS

Start at step 1. Each row is open as of November 25, 2026. Update the row with a dated evidence path, run ID or reproducible command after execution.

| Step | State | Evidence |
|---|---|---|
| 1. Select sample | ⬜ open | — |
| 2. Offline recovery | ⬜ open | — |
| 3. Shared notifications | ⬜ open | — |
| 4. Check delays | ⬜ open | — |
| 5. Decide and retire | ⬜ open | — |

## 1. Ultimate goal

A short GitHub interruption should delay submission while people can still finish and save independent work. On busy days, fewer requests should buy the same trustworthy status, and changes to checks should target measured delay. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Application

POP Creations uses [ai-devops](https://github.com/popcre/ai-devops) to coordinate many coding sessions. Its Bash and Python tools run on Ubuntu and Windows Git Bash. GitHub hosts the authoritative history, pull requests (PRs), checks and protected merge queue. Use this toolkit repository as the single pilot on edge-dev3. Its high activity is the selection assumption, not a measured fleet ranking.

## 3. Trigger

Albert reports outages stopping all work, slow checks and hourly request exhaustion across high daily PR volume. No incident timestamps or measured cause were supplied. Reproduce the outage locally with unavailable Git and API endpoints for two disposable workspaces. Use historical records for actual volume and timings. Distinguish service unavailability, local quota refusal, queue delay and execution time.

## 4. Scope

One repository, two disposable workspaces, seven completed days of local measurements, one busy code-change day, the busiest quota hour and a conditional shadow event consumer and one findings record. Outside scope: replacing GitHub, revisiting the ended Entire trial, guessing the other product, creating a fleet service, changing branch protection, buying runners or deploying production changes.

## 5. Existing implementation

Baseline source on main at a43b08da. bin/ai-gh:35–45 documents spacing, quota probes and redacted records. bin/ai-pr-wait:193–209 already shares snapshots within its configured context, keys by repository and revision, and refreshes after queue membership. tests/test-ai-gh.sh and tests/test-ai-pr-wait.sh cover those paths. plan_github-request-reduction.md:12–21 describes earlier installation evidence. Issue 658 was closed when checked. Keep that historical record intact. This plan adds no installed capability. Recheck current source and existing tooling before building any experimental adapter.

## 6. Findings and hypotheses

The short snapshot lifetime and explicit refresh in bin/ai-pr-wait:199–208 mean a baseline assuming every observer makes a separate request overstates possible savings. bin/ai-gh:39 distinguishes budget probes from work requests. A request to start a job, a job waiting for a runner, and a test already running consume different kinds of time. Earlier measurements attributed about 95% of managed traffic to BlockerWatch (plan_cut-unneeded-github-traffic.md:254–257). This historical subset excludes unattributed traffic and cannot establish today's cause. None of the three reported causes has yet been quantified for this sample.

## 7. Prior alternatives

Albert reported difficulty implementing Entire and another service whose name is unknown. Neither is needed to test continuity. The earlier source-reduction plan excluded a new webhook service (plan_cut-unneeded-github-traffic.md:183). Keep this experiment disposable and report the operating cost before proposing adoption. Artificially spending the hourly allowance would disrupt other work. Use replay and measured request counts. Increasing merge batch size alone cannot eliminate merge-group builds. [GitHub queue documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)

## 8. Decisions on November 25, 2026

Locked for this pilot: GitHub remains authoritative, required checks still run, event observations never authorize a merge, and the existing quota guard stays active. Thresholds below are proposed pilot acceptance criteria fixed before collection. Open to the lead: choose an existing approved delivery endpoint and one safe timing experiment after measuring the sample. If the prerequisite is unavailable, record the affected result as inconclusive and complete the other two trials.

## 9. Execution

Use a task worktree. All pilot-only fixtures and scripts live under tools/github-pilot/ within that worktree. Use docs/verification/github-pilot.md for aggregate evidence. Use private temporary files for raw evidence. Steps 2–4 can proceed independently after 1. At either context cut (after 1 or before 5), use the fresh-session skill and reread downstream steps.

1. **lead-only — select evidence and boundaries.** Read AGENTS.md and the linked handoff. Check issue ownership and active work. Target the last seven complete New York calendar days of local gh-throttle measurements, quota measurements, failures and refusals before requesting GitHub data. Group hourly consumption by identity, caller and quota bucket; keep GraphQL points separate from REST requests and preserve unknown consumption. Select the hour with the largest fraction of its bucket consumed and the day with the most distinct non-prose PRs (earliest tie). Record coverage, refusals, missing observations, sample IDs and exclusions. If no refusal was captured, label the peak as observed usage only. Prefer saved job data; attempts, job details and pagination can each cost additional calls. Through bin/ai-gh collect at most 50 additional API requests including pages and retries, stopping sooner at a quota guard or unverifiable remaining budget. Freeze separate quota-hour and timing-day samples using the collection rules below. Check approved ingress, subscription access and evidence of runner availability without changing settings. Gate: the saved aggregate inputs reproduce both selections and the peak breakdown; incomplete attribution stays visible.
2. **lead-only — recovery involves reconciliation and remote writes.** In tools/github-pilot/outage.py use per-workspace test remotes and a test API adapter; interrupt those connections only. Run the real startup path twice, once online for comparison and again with GitHub unreachable before either workspace starts. Create both worktrees from the same locally available revision. Exercise bin/ai-task-gates, bin/ai-workspace-status, bin/ai-memory-sync (private test state), and bin/ai-test-local --check-collision with process-scoped connection refusal, service-unavailable and timeout cases. Record elapsed time, exits and whether the next ordinary edit, safe isolated test and commit worked. Never override an unknown runner collision or unverifiable private visibility. Any required local operation that hangs or fails is a failed continuity trial even if journal replay passes. Require each unavailable remote dependency to return a clear deferred or blocked result within five seconds; track protected online-only operations separately. Commit and run a local test in both while disconnected. Save repo, base, branch, full commit, dependency and intended PR identity in a private durable local journal using atomic writes; retain local refs. Restart both workers during the outage. Reconnect with an upstream overlapping edit. Reconcile against the new base and rerun the affected test. Serialize submission by repo and branch, check for an existing open or already merged PR, and simulate a lost response after creation; interrupt again before marking the journal delivered. Demonstrate a conflict stays pending until resolved. Gate: original work recoverable after restart, both expected changes preserved, one PR per intended submission, zero force pushes, correct dependency order. Prove the normal GitHub submission path with a disposable prose-only non-merging draft PR for each branch; record the checks and quota these drafts actually trigger; close only owned drafts after saving links and final revisions. Simulate ambiguous responses locally, never interrupt unrelated traffic.
3. **lead-only — event authentication and live accuracy.** First attribute the constrained hour. Run the event experiment only if status reads account for at least 20% of measured consumption in the affected bucket, counting unknown spend in the denominator. Otherwise record a no-adoption verdict for the listener when the upper bound is below 20%, or inconclusive if unknown spend could change the decision. Identify the largest measured caller and estimate the effect of eliminating duplicate reads from its saved trace. Keep any repair outside the pilot. If status reads qualify, confirm approved ingress and access before building the live arm. Compare two or more concurrent observers using the existing snapshot waiter against one receiving GitHub events with local fan-out. Replay identical timestamped observer reads and events in tools/github-pilot/events.py against both arms, including the baseline cache, budget probes, reconciliation calls and restarts. Count each actual HTTP exchange with a metadata-only transport counter in the isolated harness for both arms (one increment per request including retries and pages); validate it with a known redirect and retry sequence. Retain only counts, bucket, time and observed cost. Existing command logs with null HTTP counts cannot establish savings. For live proof use attributable metered exchanges or isolated quota deltas with no competing consumers. Report GraphQL points separately. Prefer an existing approved receiver; use a scoped, temporary subscription only on the pilot repo if permitted. Authenticate the raw payload, restrict repo and event type, deduplicate deliveries, store revision and last verified state atomically. Verify required-check membership against GitHub for the exact revision and reconcile queue ejection. On gaps, stale state or ambiguous queue transitions, use one bounded shared reconciliation through bin/ai-gh. Failure means unknown, never success. Correlate a real draft PR update and check completion with an authoritative read; include any delay, retries and receiver downtime. Gate: at least 50% fewer outbound status HTTP requests on matched reads, all observed terminal states correct for their exact revisions, healthy delivery visible within 60 seconds, missed event detected and reconciled within five minutes when GitHub is available. Also require at least 10% lower total peak-hour consumption in the affected bucket on the matched workload, no new paid service, and a named owner for receiver upkeep. Report operating time, denominators, observed peak calls/hour and quota bucket. Counts from command invocations alone do not qualify; if read request metering or live delivery is unavailable, label replay separately and leave live proof open.
4. **helper-ok — deterministic timing analysis.** Using the frozen sample, write tools/github-pilot/timing.py and its fixtures. For each job attempt calculate start minus workflow creation (includes dependencies), and completion minus start. Read workflow dependencies at each run’s revision. Separate the deliberate push-settle delay from runner wait. For jobs with known prerequisites subtract the later of creation and last prerequisite completion to estimate ready-to-start wait. Mark unknown readiness explicitly. Separate PR, merge-group, rerun and cancelled work. Report sample sizes, median and nearest-rank p95 by workflow and runner; reconstruct elapsed critical path per PR instead of summing parallel jobs. Gate: fixtures with parallel jobs, dependencies and reruns yield the hand-calculated totals. Stop and ask the lead if identifiers cannot join or timestamps are ambiguous. **Lead verifies and owns the live judgment:** use at least 20 matched pairs, interleaving baseline and candidate on identical inputs and fixed runner lanes. Separately report elapsed time to the last required check (verify the effective rules and verification-closure), advisory completion and merge-group completion. For the measured bottleneck, use an isolated runner replay for a queue-dominated path or replay equivalent jobs with duplicate advisory work removed for an execution-dominated path. Match job mix and runner class, report both component times. For adoption require at least 20% lower median time to the chosen merge-blocking milestone, no worse paired-sample p90, and identical required-check coverage and outcomes. Label simulated capacity effects as estimates; if comparable live attempts are unavailable, publish diagnosis only.
5. **lead-only — verdict and cleanup.** In docs/verification/github-pilot.md give each experiment a pass, fail or inconclusive verdict with observed values, denominators, evidence links, limitations, operating cost and recommended next action. Compare recovery time, peak requests/hour and delivery latency independently. Remove only pilot hooks, credentials, drafts and transient state after preserving evidence; verify existing waiters and checks still work. Give the findings document its four-key header, link it from this plan, regenerate docs/INDEX.md with bin/ai-doc-health --repo . --fix-index, and run bin/ai-doc-safety --changed origin/main. Gate: a second reader can reproduce all three verdicts from redacted artifacts. Update this STATUS and the same issue; retire the handoff only when the trial is resolved.

### Collection and scoring rules for the lead

**Step 1 — coverage and budget.** List each requested date with its actual coverage. Exclude truncated days from the busiest-day ranking and incomplete hours from the peak ranking. Use the earliest tie for either. If retention leaves fewer than seven complete days, name the observed window; a peak in that window cannot establish a seven-day peak. Without a complete hour and reliable total, leave the quota verdict inconclusive. Offline tests need neither sample.

Reserve the 50 extra HTTP requests across the live pilot: 10 for discovery, 12 for draft submission and cleanup, 8 for status verification, 20 for timing evidence. Include wrapper probes, redirects, retries and pagination in the relevant allocation. Use saved data first. Before any live mutation, verify metering and reserve enough calls to reconcile an ambiguous write, remove the pilot resource and verify removal. Skip creation if costs cannot be bounded. Allocate from a single ledger; do not spend cleanup reserves on measurement. Before scheduling timing runs, count already available complete pairs and price missing job, rule and attempt reads; switch to diagnosis only if 20 valid pairs cannot fit. Missing evidence in one experiment does not hold another.

**Step 2 — isolate the outage before testing.** Start disposable processes under a clean test account or container with no host credentials, no host state directories mounted and no outbound network. Use a private clone with local fixture refs, two worktrees, loopback Git remotes and a separate private journal per workspace. Within each child process set AI_GH_STATE_DIR to its own scratch directory and AI_GH_REAL_GH to a fixture executable accepting the normal gh arguments. Have the fixture return synthetic responses for identity and quota probes and send simulated remote operations only to the loopback endpoint. Exercise refusal (closed port), HTTP 503 and a delayed response. Use a healthy loopback control with identical state and starting revisions. Record the test process's destination addresses and writes; require all destinations local and all writes inside its disposable storage. Abort on any unexpected destination or mount. Keep real GitHub proof in a separate, normally authenticated process after the drill. Never change host networking, DNS, credentials or shared backoff settings.

Record wall time from entry to return, including identity and quota probes, lock waits and retries. First measure shipped defaults (the quota probe alone permits 15 seconds). The five-second limit is a responsiveness target: a correct protected stop can miss that limit without being a safety failure. If testing shorter limits, label that as a second configuration, record each override and keep the default result. Enforce an external 120-second watchdog on each test process; a killed call is a timeout, never a successful defer.

| Entry point | Expected outcome while offline |
|---|---|
| Task declaration, ordinary edit, isolated local test and commit | Complete locally, including after restart. A required online dependency here fails continuity. |
| Workspace status | Local revision remains recoverable. Remote status is unknown or explicitly deferred. |
| Private memory sync | Defer if privacy cannot be verified. No push or disclosure. |
| Shared-runner collision check | Unknown (exit 4) blocks the shared suite. A separately isolated test can still run. |

Kill the journal writer immediately before and after atomic replacement. On restart require the previous or new complete record, and resolve every retained commit with git cat-file. Record accepted updates on the fixture remote and require fast-forward ancestry, one PR identity per intended submission, and the prerequisite revision present before its dependent revision. For live submission use bin/ai-gh pr create --draft with explicit repository, base and unique owned head. Record the PR ID, head revision and draft state; never mark ready or enqueue. Close the owned drafts and verify closed and unmerged. These drafts prove submission only. Use existing real code PRs and merge-group records for required-check and queue evidence, including ejections if claiming live ejection handling.

**Step 3 — handle unknown consumption.** For one identity, one quota bucket and one hour let T be independently observed total consumption, S verified status-read cost, and O verified other cost, all in the same units. Deduplicate before attribution. U = T − S − O is unattributed. Require T > 0, U ≥ 0 and coverage of resets or replenishment. A missing or inconsistent total is inconclusive. If S/T ≥ 20%, test the listener. If (S+U)/T < 20%, rule it out for that hour. Otherwise the unknowns could change the verdict. Keep replay results separate: without verified ingress and attributable live measurements there is no live savings verdict. Missing HTTP counts are never zero.

**Step 4 — timing decision.** Match workflow revision, input, runner label, platform, capacity and concurrency policy within each pair, changing only the tested factor. Use the effective required rules for that revision. Freeze the milestone and pair exclusions in advance. With at least 20 complete pairs, compute median improvement as 1 − median(candidate)/median(baseline); require a positive baseline. Sort the within-pair differences (candidate minus baseline) and require the value at rank ceil(0.90 × pair count) to be ≤ 0. Report intentional settling, dependency wait, unknown readiness and runner wait separately. Thresholds guide this Ubuntu pilot; they do not qualify a fleet rollout or Windows behavior.

**Step 5 — verify restoration.** Before creating resources, inventory type, ID, scope, owner and initial state, without credential values. At teardown compare only pilot-owned resources to that inventory. Verify draft closure and removal of any temporary subscription and signing credential. Recheck one ordinary existing PR via the normal waiter against its recorded revision and required-check state. Record the comparison, receipt and any outstanding cleanup on the same issue.

### External-input tests

| Input | Failure case | Named test |
|---|---|---|
| Startup dependencies | offline before startup, refused connection, 503 and timeout; collision state unknown | test_real_offline_startup, test_fixture_isolation |
| Measurement records | missing costs, unknown caller, mixed buckets and truncated day | test_quota_attribution, test_partial_window_and_budget |
| HTTP counter | redirect, retry and pagination counted without headers or bodies | test_exchange_count |
| Local journal and refs | truncated write, concurrent restart, unexpected repo or missing commit | test_journal_recovery |
| Remote PR result | accepted write then lost response, concurrent resubmit, already merged | test_retry_one_pr |
| Upstream edits | divergent base, overlapping edits, dependent branch | test_conflict_preserves_work |
| Incoming event | bad signature, foreign repo, oversized or malformed payload | test_reject_invalid_event |
| Delivery sequence | duplicate, old head, reordered close, missing event, restart | test_reconcile_current_head |
| Status read | rate limit, timeout or stale cache during outage | test_unknown_until_verified |
| Timing export | null, negative or mismatched times, duplicate pages, parallel attempts | test_timing_sample, test_paired_tail_gate |

## 10. Tests

Put the named cases in tools/github-pilot/test_pilot.py. Run python3 -m unittest discover -s tools/github-pilot and bash tests/test-ai-gh.sh and bash tests/test-ai-pr-wait.sh. Use bin/ai-test-local --check-collision before full local suites. A fixture pass alone cannot satisfy a live gate.

## 11. Constraints

Use a current upstream worktree, the declared task class and stronger action checks, GitHub access through bin/ai-gh, no unbounded polling, no wait or retry over 30 minutes. Preserve runner collision controls, existing safety checks and current merge ownership. Do not log tokens, signatures, raw webhook bodies, private repo names or code. Limit benchmark claims to the tested environment. Do not install experiments on developer machines.

## 12. Access and environment

Start in a fresh task worktree of popcre/ai-devops from origin/main on edge-dev3 with Git, Bash, Python 3 and the installed GitHub wrapper. Verify identity with git var GIT_COMMITTER_IDENT and scoped read access with bin/ai-gh repo view popcre/ai-devops. Webhook administration and access to matching runner capacity are unverified. Use the secrets-to-1password skill for a temporary signing secret in vibe_coding, item GitHub continuity pilot webhook, only if a real subscription needs it. Serve replay on loopback. Never expose a local listener directly to the internet. If approved ingress is unavailable, execute replay and document the specific missing live proof.

## 13. Done, risks and rollback

Completion of the study requires three evidence-backed outcomes, including a clear reason for any inconclusive trial. Acceptance of a proposed capability additionally requires the corresponding live gate. Track outstanding live proof on the pilot issue. Commit owned test/evidence files, push, merge through the queue, record passing checks and verify the landing commit on origin/main. Production deployment is outside this pilot. Remove temporary components and confirm ordinary GitHub submission, status and checks still work. Verify cleanup against the pre-test inventory. Missing observations, unrepresentative workload and shared runner contention limit conclusions; state exactly which conclusions survive. The implementing lead owns the evidence and the decision to retain or retire each experimental file.

### Self-audit

1. Can a fresh lead run the trial without the planning chat? Yes. Sections 2–5 and 9–13 identify the site, owner, input sample, test paths, gates, fallbacks and cleanup.
2. Does the plan preserve known context and failed alternatives? Yes. Sections 3 and 5–8 distinguish the owner's report, existing cache and quota controls, ended platform trial and unverified causes.
3. Can the goal resolve a wrong step? Yes. Sections 1, 8 and 13 prioritize continuity and trustworthy status, and permit an inconclusive verdict when evidence is missing.

### Lead launch prompt

```
Read AGENTS.md, this plan's STATUS and its execution handoff. Start at the first open row. Recheck current source and issue ownership. Do steps 1–3 and 5 yourself. After step 1 delegate only the timing script and fixtures in step 4, verify the arithmetic yourself and own the live timing judgment. Run each applicable named suite and live gate; document any conditional trial skipped under step 3, preserve receipts and clean up. Read downstream phases again at each context cut.
Your helper is your own tool's smaller model — Haiku (high effort) for Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for Mimo Pro. Never a full-strength model.
Use https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md. Require finished work or a blocker with verbatim evidence. No design decisions, merges or posts by the helper. Send stop-and-ask triggers to the lead; take work back after 30 minutes stuck.
```
