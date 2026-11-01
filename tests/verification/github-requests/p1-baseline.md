# P1 request attribution — working baseline

## Coordinator natural sample — October 31, 2026 EDT

Owner: Codex chat `01a194df-87e5-7531-974d-19472397132a` under #658/#660.
Only closed October 26–30 UTC daily files were copied into protected private
machine state; October 25 UTC was absent and the live October 31 file was
excluded. The actual interval is October 25, 2026, 8:00:05 PM EDT through
October 30, 2026, 7:58:56 PM EDT. Originals remain unchanged; directories are
mode 700 and files mode 600. No raw observations are published.

Input digest: `b33bac05846308e04dda21524d16c671174fc6961e9e477d02552ce943b966c1`.
Report digest: `c190c01f0e4258d5c22f64f3cc1f6c641950b46b63ed7ea1f45dbb3e16fe5e00`.
Reporter digest: `b1caea99b0435137112aa4a4b7c58301586639d3822090b71d01247544665872`.
The existing reporter passed. Finite-key/label privacy validation checked
13,870 raw rows with zero violations.

- 7,908 wrapper records; 7,479 opaque executions and 306 identity-probe
  invocations. These are instrument counts, not HTTP totals.
- 964 completed receipts: 720 ticks and 244 nondeadline PR outcomes
  (177 checks-failed, 55 merged, nine ejected, three closed).
  Another 269 deadline outcomes are excluded from useful completions.
- 513 local duration observations; all 513 schema-4 safety records retain
  unknown source/clock qualification. No qualified remote detection latency
  or paired baseline/candidate latency ratio is established.
- 1,243 observed GraphQL points, 1,203 linked to outcomes. Whole-account
  GraphQL and actual HTTP totals remain null; 5,974 caller rows are unknown.
- 972 same-target replays include 26 cache serves and 946 upstream refreshes.
  Their 2.675% instrumented cache share is not a savings rate. There are 1,217
  write observations and zero observed unchanged writes; completeness and
  target qualification remain prerequisites.

This is a retrospective natural-activity sample, not a newly frozen baseline.
After measurement qualification and active-host coverage are complete, freeze
prospective baseline/candidate cohorts before the next reduction. The bounded
next natural sample is two business days, with at least twenty equivalent
completed outcomes per operation type in each cohort. Include active wake,
alarm, link and dispatch/privacy outcomes; idle ticks alone do not prove them.
If too small, retain exactly one owned programme acceptance card on #658,
with #660's existing instrumentation obligations, and set the next bounded
sample there. Do not manufacture activity, weaken targets or claim background
collection/automatic continuation from this note.

## Superseding source audit — October 31, 2026, 10:13 PM EDT

Owner: current #658 coordinator, with P1 acceptance retained on #660.
The frozen samples and their original limits below remain unchanged. Pending
source-delivery statements are historical: #1710 merged as `3b9ac286`, #1510
as `1861259d`, and #1511 as `2ed3c24b`. The [October 31 installed cached-waiter
proof](admission-20261031.md#final-source-installed-proof) establishes the scoped
Linux/Windows capability repair, not whole-workload savings or cache-hit rates.

Dispatch and privacy callers now use the shared transport; descriptions below
calling them unwrapped predate the accepted [P3 installed proof](p3-installed-proof-edge-dev-2026-10-13.md).
Their terminal outcome receipts remain absent: the current collector and
reporter accept workflow outcomes only for PR waiting and BlockerWatch ticks.
Current managed-transport guard and request-counter tests pass (15 counter
tests). This does not qualify missing outcomes or historical observations.

Keep #658/#660 open for matched baseline/candidate costs, source and clock
qualification, safety-event equivalence, useful-work latency and host/client
coverage. Schema-4 source/clock evidence remains deliberately unknown; local
monotonic duration observations do not establish GitHub-event detection latency.
No source landing, installed command or new status note retrospectively turns
the samples below into a matched comparison.

## Resume sample — October 21, 2026, 2:12 PM EDT

Owner: current Codex session on edge-dev3 under #658/#660. This supplements
the frozen P1 evidence below; it does not replace its baseline or turn the
existing candidate cohort into a retrospective baseline.

Six closed daily telemetry files were copied without modifying the originals.
The existing reporter validates the immutable copy from October 14, 2026,
8:00 PM EDT through October 20, 2026, 7:58:05 PM EDT. Input digest:
`f8477e7532d881905a4e3c7dda07500ea47863576c4bb2739a6d42a3f868cb28`.
Report digest:
`454bd166cf9e1f8943205b1a29e802b05b241cdadeae26823b7d22fec27a31a6`.
The private snapshot and full report are retained in the protected machine-local
state under `658-resume-20261021`; raw rows are not published.

- 262 local timing observations: 57 merged, 41 checks-failed, 3 ejected,
  1 closed and 160 deadlines. Excluding deadlines leaves 102 completed
  observations. These unpaired observations do not establish a latency ratio.
- 712 target-correlated reads, 217 target ordinals, 495 same-target replays,
  zero cache serves. Repetition over six days is not proof that those reads
  were redundant or eligible for one shared refresh.
- 712 new-write observations and zero observed unchanged writes. Target
  adapter qualification and completeness remain acceptance prerequisites;
  the existing PR #1710 contains their pending source repair.
- 712 observed GraphQL points. Actual total HTTP requests and whole-account
  GraphQL points remain null. The report retains 6,112 unknown-caller rows.
- Schema-4 safety evidence remains unqualified: all 262 records lack source
  verification, target ordinal and clock-error bound. Qualified local duration
  intervals do not substitute for safety-event detection latency.

The actual installed manifest names `eeae25ef`, which contains duration adapter
`4e172768`; no repeat installation of that historical adapter is required.
The rejected item-2 source is not considered repaired or live until #1710
lands, passes its installation gate and preserves original waiter coalescing.
Keep live proof and matched baseline/candidate costs, latency, safety equivalence
and host/client coverage open on #658/#660. No savings or completion is claimed.

Owner: Codex chat `01a0c02a-1fd1-7471-a874-4deb1038d114`, ALBT16.
Tracking: [P1 #660](https://github.com/popcre/ai-devops/issues/660), parent
[#658](https://github.com/popcre/ai-devops/issues/658).
Contract: [request reduction plan](../../../plan_github-request-reduction.md).
Inventory source: upstream `ae1ace582ca4838ce8a8cc7c59aa23d2384ead0d`, 2026-09-20.
Integration boundary: upstream `b05d15d` ([PR #662](https://github.com/popcre/ai-devops/pull/662))
landed during P1 CI and changes quota admission and probe refresh. Its behavior is
preserved in the P1 integration; this does not establish P2 acceptance.

## Acceptance status

**Partial, baseline frozen 2026-10-13.** Privacy-safe attribution and a measured
edge-dev3 baseline are established (section "Measured baseline, 2026-10-07 to
2026-10-13"). Two busy reset windows and twenty comparable completed operations
are proven for the instrumented types (PR waiting and BlockerWatch). Whole-account
HTTP requests and GraphQL points remain unknown, not zero. Dispatch and privacy
outcomes are still outside the wrapper (P3). Multi-host coverage, after-workload
comparison, and qualified useful-work latency remain open. No savings are claimed.
P1 instrumentation merged in PR #663 and is installed on edge-dev and edge-dev3.
The historical text below records its pre-merge state.

### Integration candidate, 2026-09-28

The candidate measures `rateLimit.cost`, `remaining`, and `resetAt` from each
actual upstream GraphQL page used by the PR waiter or BlockerWatch. This adds
no GitHub call. Opaque workflow IDs bind a page's cost to a terminal wait or
completed tick; a shared waiter follower records no duplicate cost. The report
accepts older cost rows and groups reset headroom only by a validated, opaque
local access-context key. Reports print a context ordinal, never the key;
unknown context stays unattributed. It cannot add reset-window totals across
hosts because local keys are deliberately host-specific. Dispatch and privacy
outcome receipts, two comparable busy windows, and installed proof remain open.
The 2026-09-24 baseline cannot be retroactively turned into per-call costs.

### Installed live supplement, 2026-09-27

Read-only collection over pinned Tailscale SSH confirmed that edge-dev's
installed `bin/ai-gh` SHA-256 is
`f501f95acc9e8a54fb151f41ed9c9568f64525c56e8cdb63d42df4e682974d2a`;
its installed `report.py` SHA-256 is
`375b66b4661a3d3b84a89d480bc51616f920d328e8409cc831e1417598818f95`.
The offline report read private local measurements without copying raw records
to this public repository or contacting GitHub. Its source digest is
`eb88425c804e7a0818239a9af0b27951ca10db4212e20bc468eb41e123720091`.
It found 8,175 wrapper records and 8,079 opaque CLI executions from
7:45 PM EDT September 23 through 11:09 PM EDT September 27. Caller labels
include 6,888 BlockerWatch records, 1,024 PR-waiter records, and 263 unknown
caller records. There were 259 failed and 94 deferred records. These are
wrapper observations, not HTTP request counts or completed workflows.

Two observed active GraphQL reset windows on edge-dev provide comparable
pre-reduction samples:

| Window (EDT) | Quota snapshots | Wrapper records | BlockerWatch | PR waiter | Unknown caller | Failures / deferrals | Observed GraphQL remaining |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| September 24, 3:45:06–4:44:59 PM | 229 | 294 | 190 | 96 | 8 | 7 / 3 | 4,999 to 4,933 |
| September 24, 8:03:31–9:03:25 PM | 165 | 226 | 218 | 8 | 0 | 10 / 3 | 4,999 to 4,942 |

Both windows have a constant reported reset and no increase in observed
GraphQL remaining inside the window. The observed bucket changes are 66 and
57 points, respectively; they cannot be attributed to these wrapper commands
because the authenticated principal is not bound to records, some managed
callers bypass the wrapper, and other clients may share the account. CLI
execution volume is not GraphQL point volume. The report's `http_requests`
and `graphql_points` fields remain null by design.

edge-dev3 separately has 1,929 wrapper records through 11:07 PM EDT September
27, including 1,140 BlockerWatch and 228 PR-waiter GraphQL labels. Its input
digest is `38a6c899254a132ddd496e12425e6a635135609389232da98ffeea3e007b7859`.
The 916 checkout was still at pre-P1 `b05d15d3` on September 27, with no P1
measurement directory. Its full current-main installation is blocked by the
local reviewer-safety deployment gate, which requires Albert to name the exact
resource and action. Hetz was also verified at pre-P1 `cdd18b9b` with no P1
measurement directory. Installation and representative samples on both hosts
remain open. External-client coverage remains unverified. Recent edge-dev telemetry
may also be incomplete because the live watcher reported a storage write failure;
the host owner is diagnosing that condition.

No existing record binds calls to 20 completed PR wait, BlockerWatch, dispatch,
and privacy-check workflows. Dispatch and privacy checks are outside the P1
wrapper as inventoried below. Accordingly these active windows satisfy only
the window-volume part of P1. A controlled offline trace replay after the
two-business-day threshold may support a clearly provisional baseline, but
cannot make these missing workflow outcomes or account-wide HTTP/point counts
measured facts. The P1 issue stays open for that proof and host coverage.

## Measurement method and denominators

`ai-gh` writes allowlisted local metadata to
`~/.ai-devops/gh-throttle/measurements/YYYY-MM-DD.jsonl`, with seven-day retention
and a 4 MiB daily ceiling. It does not request additional GitHub data. An
independent write lock with a short bounded retry (about half a second) protects complete records; longer lock contention,
disk failure or capacity exhaustion emits a warning and leaves the command's
status unchanged. A lock older than one minute is treated as left by a crash
and cleared once, so collection resumes without manual repair. This never
blocks request execution. Do not interpret missing samples as zero consumption.

Labels are fixed allowlists. Bodies, arguments, query values, identifiers and
authentication material do not enter the measurement record. Existing legacy
failure diagnostics are unchanged and are not inputs to this report. Never copy
them into the public repository. stdout/stderr and exit status remain the caller's;
existing rate-limit conversion to exit 75 remains unchanged.

`cli_executions` counts opaque command executions, **not** HTTP requests. Pagination,
internal CLI lookups and GraphQL point use remain unknown. The GraphQL label is
known only for an explicit `api graphql` command; other buckets stay unknown.
Caller attribution is an allowlisted provenance hint, not authenticated identity.
`api_host` and `principal` are unknown rather than inferred from environment
variables. Machine `local` is a redacted location, not a fleet identity. Cache hit
is false because P1 introduces no response reuse. Latency includes local pacing
and network execution; it is not workflow-completion or event-detection latency.

The offline helper `tools/github-requests/report.py` summarizes daily metadata,
validates output labels/numbers and emits a digest of its inputs. It never contacts
GitHub. Its counts are denominated by saved wrapper samples, not account-wide
requests or completed workflows. An empty sample stays incomplete; no invented
p95, top request spender, unexplained residual or savings percentage is published.

The existing quota probe supplies numeric counters for the local observation,
atomically saved as `quota-observation.json`. The original P1 implementation used
the then-existing core-only admission; upstream PR #662 subsequently changed
admission and probe refresh independently. Preserve that upstream behavior and
separate samples from before and after integration. P1 measurement itself adds no
probe or request. REST counter discrepancies described below mean these snapshots
cannot currently prove actual account GraphQL consumption or headroom. Even a
validated shared-bucket delta would not identify managed usage and must not be
summed across hosts. Missing/invalid bucket values stay null. Reset
window observations are retained in `quota-measurements/YYYY-MM-DD.jsonl` with the
same seven-day / 4 MiB daily bound, independently of the latest snapshot. Normal
existing probes supply that history; no additional sampling loop is introduced.

## Source inventory and coverage

Every row is currently inventoried; none establishes verified account identity.
External consumers and consumer repositories are explicitly unmeasured.

| Trigger / source | Transport / guard / retries | Current measurement disposition |
|---|---|---|
| PR waiter (`bin/ai-pr-wait`, GraphQL PR/check/queue query) | ai-gh; bounded 300-second minimum polling and deadline | Caller label; opaque execution estimates; actual points unknown |
| Generic waiter (`bin/ai-gh-wait`) | ai-gh; bounded wait, shared backoff | Caller label; endpoint/bucket may remain unknown |
| Scheduled BlockerWatch (`bin/ai-blocker-watch`) | ai-gh by default, configurable override; separate paginated alarm/link scans, search and issue writes | Caller label for default transport; override unmeasured; ten-minute schedule and hourly scans unchanged |
| Local collision check (`bin/ai-test-local:158`) | Direct paginated REST runner read | Unwrapped; P3 owns routing, preserve collision safety |
| Dispatch/cancel (`bin/ai-verify-run:43–84`) | Direct commit/tag/run reads, dispatch, explicit cancel | Unwrapped; P3 owns routing, preserve exact-SHA and cancellation authority |
| Merge proof (`bin/ai-merge-group-evidence:98–140`) | Direct repo discovery, GraphQL queue and REST run/job reads | Unwrapped; P3 owns routing, preserve fresh exact-head evidence |
| Privacy proof (`bin/ai-memory-sync:90`, `bin/ai-transcript-destination-check:27`) | Direct fresh private-repository REST checks | Unwrapped; P3 owns routing, no private identifiers published |
| Workspace snapshot (`bin/ai-workspace-status:94`) | Direct CLI PR read | Unwrapped; P3 owns routing |
| Runner maintenance (`bin/promote-windows-runner-to-service.ps1:71–125`) | Direct REST runner list/removal/registration | Protected maintenance, no replay; P3 inventory disposition required |
| CI runner watchdog (`.github/workflows/runner-pool-watchdog.yml:51`) | Scheduled direct paginated REST via configured credential | Separate unverified principal; do not pool with personal quota |
| CI queue watchdog (`.github/workflows/windows-queue-watchdog.yml:51–99`) | Workflow-run-triggered SDK jobs/comments reads/writes | SDK bypass; token identity and HTTP cost unmeasured |
| CI verification (`.github/workflows/verify.yml:58,346,587–591`) | SDK pagination and scheduled-failure issue reads/writes | Job token and runner credential are distinct unverified identity classes |

Read-only survey found no additional GitHub-specific direct HTTP/MCP transport in
the inspected `mcp`, `config`, `templates`, or Python/JS `tools` sources. This is
not proof of installed external-client or consumer-repository coverage. Source
inventory was independently surveyed in an isolated worktree; no private logs or
transcripts were inspected.

## Host and installation evidence

Focused offline verification on ALBT16, 2026-09-20: `tests/test-ai-gh.sh`
55 passed / 0 failed, `tests/test-ai-pr-wait.sh` 29 passed / 0 failed,
`tests/test-ai-blocker-watch.sh` 94 passed / 0 failed; no skipped/ignored cases.
Includes `telemetry_redacts_before_write`, `telemetry_preserves_streams_and_status`,
separate bucket observations, visible telemetry failure, retention and
`request_report_coverage_and_denominator`. The clock fix uses Bash's own clock so
instrumentation neither advances a waiter's mocked deadline nor contaminates its
transient failure cause. Existing waiter failure/deadline checks remain intact.

First exact-head independent review of `083d91e` rejected non-regular filesystem
inputs: a date-named FIFO could block the collector or offline reader. The repair
rejects all non-regular existing destinations/inputs, including quota snapshots,
and creates quota temporaries exclusively with `mktemp`. Regression fixtures use
directories on every host and FIFOs where the filesystem supports them. The new
head received an independent APPROVE at `ccb6439e5c7bdf17dc5100bb070eb4b6d8813084`
in `codex-final-check-20260920T192551-52435-14784.md`. Integration of upstream
`b05d15d` changes that reviewed source; the integrated head requires a fresh
independent review. Neither the earlier rejection nor the prior-head APPROVE
approves the new integration.
After that repair and bounded quota history, `tests/test-ai-gh.sh` passed 61/61
on Windows, including both FIFO cases; no skipped or ignored cases. The quota
fixture executes the real wrapper-supplied jq projection rather than returning a
preconstructed projection, so the three-bucket extraction itself is exercised.

### Integrated source verification, 2026-09-20

After integrating PR #662, review of `27a2620` rejected inherited caller labels,
uncontrolled non-object JSON errors, and stale test evidence. All BlockerWatch
GitHub transports now receive a command-scoped label; resumed sessions retain
their own environment. Both waiter paths also scope labels to their transports.
The report rejects non-object records, wrong-type labels, malformed required
fields and excessive nesting with a fixed diagnostic and no partial report.

The repaired source passed **243 focused assertions, 0 failures, no skips**:

| Suite | Result | Complete local output SHA-256 |
|---|---|---|
| `tests/test-ai-gh.sh` | 117 passed, 0 failed | `b02770245434be3cc169b38890bf254cf05fe24b24704757227d41476e1eeadc` |
| `tests/test-ai-pr-wait.sh` | 30 passed, 0 failed | `a84071e340d348fa214c3b5bef84aff946ca8ed6a7162f0e0abbc8804a60875c` |
| `tests/test-ai-blocker-watch.sh` | 96 passed, 0 failed | `e8a436b394529630e9bdd4cb6cc470021aa607b99bcd033d2fe0efc7806c85ec` |

The waiter timing checks were run alone: an earlier concurrent run exceeded two
strict local timing thresholds, while the unchanged suite passed serially. No
timeout or assertion was relaxed. The report suite's 18 new cases preserve all
99 existing assertions. The caller checks exercise real fake transports and both
resumed harnesses, rather than merely searching for a label in source code.

A local SHA-256 receipt binds the tested scripts, their transport/supervisor/gate
dependencies, BlockerWatch configuration and all three complete outputs. Its
source-input manifest digest is
`141a231836a060db044336b5143b4252d869a5faf4a67d2b9b29e2e3f5bc4835`.
The first receipt-bearing review of `e43b3ec` rejected the packet: Windows
rewrote the Python helper to CRLF in the review copy while its test receipt
described mixed line endings. No additional caller, parser or quota-integration
defect was found.
The helper directory now pins Python files to LF in `.gitattributes`; a fresh
review-copy preflight verifies the receipt before another paid review starts.
The canonical-LF helper was retested at `f97953e`: 117 passed, 0 failed, no skips;
its raw SHA-256 is `375b66b4661a3d3b84a89d480bc51616f920d328e8409cc831e1417598818f95`.
At 20:49 UTC the fresh review-copy preflight matched all 13 source inputs and
three full-output hashes, including the updated canonical-byte test receipt.
The final review packet verifies these input/output hashes and displays the
recorded results, reusing completed focused tests rather than rerunning them.
Full required CI remains separate; these results are not installed/live proof.

An isolated Windows timing comparison ran ten zero-delay fake CLI operations per
version: prior wrapper 7,362 ms total, instrumented wrapper 9,176 ms total (about
181 ms additional processing per operation). This is a small offline startup
sample, not a workflow p95 or acceptance result. Instrumentation makes zero extra
GitHub requests; ordinary pacing and all networking were excluded from this test.
These tests, timing and development-worktree samples precede the PR #662
integration; they are historical evidence, not postintegration or installed proof.

On ALBT16 the installed `ai-gh.cmd` currently resolves to
`C:/repos/ai-devops/bin/ai-gh`; the user confirmed C: for this phase because this
machine has no D: drive. The plan's D: path describes its planning machine 916.
The public machine atlas delegates topology to protected configuration. Configured
host names and schedules are not proof of reachability or active installation.
No remote fleet coverage is claimed. Installed changed hashes and a normal live
sample must be recorded after merge and installation before accepting this part.

Read-only discovery also checked the protected atlas's current Windows section
and its dated harness census. That historical census lists seven host roles with
mixed/unknown authentication and reachability; it is not current fleet proof and
its private topology is not copied here. On ALBT16, Codex, Claude and GitHub CLI
resolve to installed executables. Initial discovery returned no BlockerWatch or
reviewer-start-watch registration. BlockerWatch was subsequently installed through
its supported scheduling command: the task is Ready, with last run
2026-09-20 15:43 local time (ALBT16, UTC-04:00) and result 0. This establishes a
schedule and successful task exit, not a successful wake or representative scan.
P1 must obtain representative
ordinary observations from the appropriate already-configured source host, or
retain that coverage gap and keep attribution acceptance open.

## Live endpoint discrepancy

A bounded authenticated GraphQL observation at approximately 2026-09-20 19:57 UTC
reported viewer `u2giants`, numeric identifier `55610577`, and cost 1, with remaining
4,773, used 227, limit 5,000 and reset 20:48:13 UTC. The immediately following REST
rate-limit response instead reported GraphQL remaining 5,000, used 0 and reset
20:57:17 UTC. A no-cache cross-check at 20:02:40 UTC again returned full buckets
with reset 21:02:40 UTC.

The root cause is unproven. These conflicting REST observations cannot establish
actual account GraphQL usage, available headroom or busy reset-window evidence.
The GraphQL viewer is point-in-time identity evidence only; it does not bind all
earlier metadata, external callers or other hosts to that identity. Retain both
observations as a measurement limitation rather than calculating false savings
or treating full REST counters as proof of an idle account.

## Remaining evidence and blockers

### Coordinator reconciliation, October 7, 2026, 10:05 AM EDT

Owner: Codex chat `01a116aa-0400-7230-97d9-3fab73f00bd1`, edge-dev3,
under #658 and #660. This supplement is a checked aggregate only; raw telemetry,
credential contexts and host routes remain private.

The report over the complete local history correctly refused malformed input.
A read-only inspection found one October 1 record prefixed with NUL bytes. The
original daily files were preserved unchanged. A bounded October 2–7 copy,
excluding the entire October 1 input rather than silently repairing a record,
produced this provisional aggregate. Its raw-artifact digest is
`6d28c9e118ef27e38a00764ab7fa0f5c0d46a9df9b2886bc5001a57cf0ceb901`.
Observation interval: October 1, 2026, 8:03 PM EDT through October 7, 2026,
10:02 AM EDT (daily files use UTC boundaries).

- 18,721 schema-1 call records; 1,065 workflow receipts, including 188 deadlines.
- 800 completed BlockerWatch ticks; PR wait outcomes: 45 checks-failed,
  31 merged, one ejected, and 188 deadlines. Active-tick comparability is unproved.
- 624 observed GraphQL points, of which 552 link to workflow receipts.
  Total HTTP requests and total GraphQL consumption remain unknown.
- 35 local context/reset groups, including 32 with multiple observations;
  observed GraphQL minimum remaining is 2,345/5,000 (46.9%). These are not
  two workload-comparable busy windows or account-wide headroom proof.
- 7,525 records have unknown caller attribution. Dependency-fallback reads
  account for 9,393 call records; telemetry lacks target IDs, so their count
  alone cannot establish redundancy or savings.

The report verdict is **incomplete: busy windows, workflow outcomes, identities
and quota observations required**. No savings, p95 useful-work latency,
cross-host same-principal contention, zero missed events or fleet completion
are inferred from this aggregate. #1211 quota admission and #1212 operation
label defects are separately owned repairs. Acceptance stays on #660/#658.

P1 owner (#660) retains the complete outcome: installed hashes, source-to-identity
mapping, observed per-bucket snapshots and non-double-counted deltas, measured
managed request/point counts or explicit uncertainty bounds, outside-client share,
instrumentation overhead, two comparable busy reset windows and twenty completed
workflow outcomes. Current collector cannot observe pagination, points or bypasses.
Those unknowns must not be relabeled as measured counts. Dominant unexplained spend
blocks attribution acceptance. Preserve the normal workload and all safeguards;
do not generate artificial live jobs or increase probing to manufacture samples.

Planning incident remains the evidence in plan section 3: GraphQL refusal at
2026-09-20T16:43:06Z followed by a healthy **separate core** probe. That incident
proves a bucket mismatch, not which caller consumed GraphQL capacity.

## Measured baseline, 2026-10-07 to 2026-10-13 (edge-dev3)

Read-only offline report over private local measurements on edge-dev3. Nine
fixture rows were excluded from the report input and preserved with a quarantine
manifest (placeholder workflow id `0123456789abcdef0123456789abcdef` written
2026-10-08T12:52:49Z and one evidence row without a matching outcome receipt).
Live telemetry was not modified. Filtered input SHA-256:
`e98b8c1f6026663a73a008a4a4d4c7634e97977ac5622c5a92f0e1560541bdf2`.
Report file SHA-256: `def6134c907d26653d7b6d93e65ed992494ab21df555c3af9d8dc4a91b3d7a9d`.
Interval: 2026-10-07T00:00:05Z through 2026-10-13T15:12:05Z.

### Privacy

26,630 measurement rows checked. Repository, principal, and machine labels are
redacted or hashed on every row. Zero violations. Access context is a local
opaque `v1:` hash; reports print a context ordinal only.

### Attribution and measured cost

| Quantity | Value | Notes |
| --- | ---: | --- |
| Wrapper records (schema 1) | 22,192 | opaque CLI execution estimates |
| Opaque CLI executions | 21,045 | not HTTP requests |
| Observed GraphQL cost records | 1,921 | schema 2, same-response `rateLimit.cost` |
| Observed GraphQL points | 1,921 | all `ai-pr-wait` / `graphql.pr_status` / `pr_wait` |
| Cost records linked to a workflow receipt | 1,823 | 1,823 linked points |
| Unattributed quota-window records | 0 | every window row carries an access context |
| Whole-account HTTP requests | unknown | `http_requests` is null on every row |
| Whole-account GraphQL points | unknown | report field stays null; observed subset above |
| Unknown-caller wrapper records | 11,090 | |
| Verified-principal wrapper records | 14,092 | opaque local hash, not a bound GitHub login |

### Completed workflow receipts (comparable operations)

1,192 non-deadline completed receipts, well above the twenty-operation floor:

| Caller / workflow | Outcome | Count |
| --- | --- | ---: |
| `ai-blocker-watch` / `blocker_watch_tick` | completed | 949 |
| `ai-pr-wait` / `pr_wait` | checks_failed | 126 |
| `ai-pr-wait` / `pr_wait` | merged | 108 |
| `ai-pr-wait` / `pr_wait` | ejected | 8 |
| `ai-pr-wait` / `pr_wait` | closed | 1 |

Deadline receipts (508) are excluded from the comparable set. Dispatch and
privacy-check outcomes are absent: those callers remain unwrapped under P3.
Idle BlockerWatch ticks are included as completed ticks; they are not claimed
equivalent to active business workflows.

### Busy reset windows

101 access-context reset windows have observed GraphQL remaining below 4,900.
The five deepest:

| Reset (UTC) | Samples | Min remaining | Max remaining | Observed points | Bucket span | Unattributed in window |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2026-10-07T14:55:57Z | 30 | 2,505 | 4,957 | 30 | 2,452 | 2,422 |
| 2026-10-11T20:18:39Z | 38 | 2,564 | 4,850 | 38 | 2,286 | 2,248 |
| 2026-10-11T21:18:47Z | 35 | 2,745 | 4,999 | 35 | 2,254 | 2,219 |
| 2026-10-07T00:54:49Z | 44 | 2,907 | 4,639 | 44 | 1,732 | 1,688 |
| 2026-10-13T12:26:16Z | 8 | 2,923 | 4,447 | 8 | 1,524 | 1,516 |

Across all 101 busy windows: 1,861 observed managed points versus a total
observed bucket span of 85,831 points. The unattributed residual inside those
windows is therefore at least 83,970 points. That residual is now bounded from
below and is not zero; its composition (other hosts, unwrapped managed callers,
external clients) remains unknown. No per-call savings percentage is computed
from this imbalance.

### Installation (edge-dev3)

- Install manifest `source_sha` `1840f783f947104a680d52a263fe0a68e447d0cc` equals
  the checkout HEAD.
- `/usr/local/bin/ai-gh` resolves to `/home/ahazan/repos/ai-devops/bin/ai-gh`;
  SHA-256 `f4569f7ab9da1663303059d2208c50b118ddeb7f2785eb438837ef452a01081e`.
- A normal installed issue read returned the live issue state with exit 0.

### What this baseline does and does not prove

Proven: privacy-safe attribution shape, access-context binding on every cost
window row, two or more comparable busy reset windows, twenty or more completed
comparable operations for the instrumented types, and a frozen measured baseline
with an input digest.

Not proven (keep open on #660): whole-account HTTP/GraphQL totals; dispatch and
privacy-check receipts; multi-host and external-client coverage; after-workload
comparison; safety-event equivalence; qualified useful-work latency (schema-4
qualified latency count is 0; 563 evidence rows lack cohort, source fingerprint
and clock bound). Missing values stay unknown, never zero. No manufactured
demand, no raw secrets and no savings claim.

## Coordinator measured comparison — October 31, 2026 EDT

Owner: current #658/#660 coordinator. This supplement separates observations
from acceptance; it does not retrospectively qualify the historical baseline.

The frozen October 14–20 input has SHA-256
`f8477e7532d881905a4e3c7dda07500ea47863576c4bb2739a6d42a3f868cb28`.
Offline replay ran the literal helpers from baseline `f55c1a6` and candidate
`3b9ac286` using a virtual clock and local upstream stub. Both stable-open and
unknown-head profiles retained 712 reads and equivalent paired command outcomes:
**0% read reduction**. All 495 same-target gaps were at least 16 seconds,
outside the ten-second TTL. Original arrival times, overlap and heads are
unknown; this replay cannot prove the natural workload irreducible.

Unchanged-content writes fell from 488 to zero; 488 necessary metadata refreshes
were retained. Replay p95 intervals increased from [3,4] to [8,9] milliseconds,
failing the 5% local budget. This is local helper timing, not useful-work or
remote detection latency. Shared input bootstrap was 52.914 milliseconds;
four replay cohorts took 13.034 seconds including capture, setup and cleanup.
HTTP totals and GraphQL points remain unknown.

Six necessary live coordinator reads completed successfully through the
original shared admission state, retained installed source and a finite
version-matched CLI counter. They covered the two owning issues, current PR
and run inventories, and two superseded PRs. The numeric channel observed
13 primary API writes across 30 native invocations, including admission and
identity probes; this is **six useful command outcomes**, not thirty workflow
completions or a whole-account census. All six source qualifications passed;
external writes were zero within the counter's declared scope. Individual
command durations were 26.208, 28.085, 39.806, 42.078, 23.596 and 27.815 seconds.
The first four-command cohort additionally retained 155.89 milliseconds of
bootstrap and 136.35 seconds total elapsed time. These are current observations,
not matched historical savings.

Twenty-pair direct counter fixtures on the actual Linux CLI version passed
the 5% p95 and total timing budgets with no added requests. The complete
observer route, including source capture and per-call isolation, did not:
bootstrap-amortized p95 ratios were approximately 1.532 cold and 1.626 warm.
It remains explicit bounded qualification machinery, never global routing.
Neither result establishes installed useful-work performance acceptance.

The comparison command enforces paired cases, matching outcomes, twenty cases
per operation, conservative latency intervals and existing thresholds. Missing
counts stay null and programme acceptance always requires independent live
evidence. New prospective read receipts retain arrivals, publication times,
head/cache generation, reuse policy and clock limitations. Historical records
are never upgraded by inference. Raw artifacts remain protected locally.

Native Windows source/event qualification passed 52 cases, including unsafe
staging-parent refusal before creation and replacement-before-seal refusal.
Existing shared temporary permissions were unsuitable; a verified standard
protected parent was used without changing existing permissions. Earlier
temporary-directory source-boundary claims are superseded, while their ordinary
authenticated read outcomes remain historical capability evidence. Actual offline
SSH help preserved output and exit 0 with verified source but unknown event;
cancellation returned 130 without a false receipt. Ten Linux framing/clock and
three writer-dispatch unit tests pass. No live API event was created by these
fixtures. Final installation and a genuinely later PR event remain separate.

PR #1709 was closed after proving all three changes already present upstream.
PR #1567 was closed without deleting its branch after exact recovery of its
unique historical document: 19,432 bytes, SHA-256
`6ede7fb6622eaab6cebc2ad704fb8e91f9076e2d769358a863a18e719f670bfa`.
Its historical operational instructions are not current acceptance authority.
Both existing issues retain live proof, fleet coverage and genuinely matched
natural-workload acceptance until independently demonstrated.

## November 1 native continuation — not programme acceptance

The coordinator independently checked the protected numeric receipt digest
`90679c99888637c07003d090b03f04fbc9843da48b1aa1cc0fcb782570261ce0`.
The actual CLI 2.88.1 native Windows counter failed the cold gate twice. The
first failure remains preserved; a typed-profile/ten-input receipt-writer repair
allowed one controlled diagnostic without changing either executable CLI image
or either performance threshold. No further rerun is authorized by this record.

All four retained distributions contain twenty measurements. Cold baseline
p95 was 32.6482 ms versus candidate 35.6978 ms (ratio 1.0934079061); totals were
633.593 versus 780.8177 ms (ratio 1.2323647831). Warm p95 was 36.4771 versus
35.0808 ms (ratio 0.9617211895); totals were 653.1579 versus 646.8241 ms
(ratio 0.9903028043). The cold outlier remains in the distribution. The selected
`^TestWindows` source census contains 27 top-level functions across the CLI and
channel test files, including one role helper that returns immediately in the
parent process. Twenty-six reported no failure; the overhead function failed
cold and passed warm. This is a selected-function census, not 27 independent
functional scenarios. Seven hostile-environment and nine native custody cases
passed. This is local synthetic qualification with no real API
traffic; it neither accepts cold performance nor proves ordinary Windows
authentication/context or whole-command/account costs. HTTP totals stay null.

Independent sanitized installation receipts bind the three reachable Windows
hosts to merged `8ab68085c4fee1ad00fe9b26e991c3b595c69168`, installer exit 0,
clean canonical source and matching managed launcher. Necessary ordinary issue
reads on 4837 and edge-dev returned OPEN with exit 0 in 14.065 and 12.745 seconds;
916 also returned issue 658 OPEN and its correct URL with exit 0. These are
consumer outcomes, not loaded-source counter or savings proof. No vendor CLI
or persistent execution policy changed.

The local Linux full installer also returned exit 0 at `8ab68085`; its actual
canonical source, managed launcher and manifest digest
`7144424e0abff8e22249213a3e95edace0f15bb8607d730cbc1ee766e7cc40e6`
were checked. A necessary post-install issue read then returned exit 0 with
verified installed source and complete numeric metadata: two primary completed
writes, zero external writes and five native invocations including unseparated
admission/identity/quota probes. Command elapsed time was 4.095459595 seconds;
the one-command cohort took 4.265265832 seconds including 163.427346 ms bootstrap.
The observation and summary digests are
`4a576e2ef70d1fe0edbc3cccd077720d5d6d8a34534e66197a7ab5fa2161a45d`
and `6848ff36fbedd1b3dc466997f28e0155a87ec2d62ef43d8bed7802174491575e`.
The corrected ten-input build retained both earlier executable hashes and the
same `updateable` feature variant. This is one useful outcome, not five useful
outcomes, a matched before/after cohort, remote detection or whole-account HTTP.

Hetz's root-run installer passed all eighteen required stages at the same
source. Its initial root-only tracked-file regression is preserved. The owning
installation recovery restored 91 metadata entries without changing content,
then all eighteen required stages passed again. Separate prior-head metadata
recovery restored normal-owner readability without changing its content. The
protected recovery digests are
`4e26bb69750e6aad92aaf66c1bca1a46b516d8c89249eb21d59ed5fa5c4dd99e`
and `bc0af196024f15b8d74f88d62836181570eb667ebd170883b211663964d5b5c7`.
Normal-owner live source custody, ordinary import and sealed waiter help then
passed; the parent's original descriptor limit was restored. A necessary
normal-owner installed read returned MERGED and exit 0 in 11.306788892 seconds,
including 149.701114 ms source bootstrap, with verified raw and loaded source.
Its sanitized receipt digest is
`cc10728a9a309cd784bc0f581725d8472cf1589c1a54405c1290608d39284c24`.
Eligibility preceded observation, so detection latency remains unknown; request
totals and savings also remain unknown. This normal-owner proof is distinct
from root execution and does not erase the original installation regression.

The necessary PR #2252 repair subsequently merged as
`30f235dba3305e1dfec412ae36e95f36756b5c2f`. A real 4837 waiter was observed
running with OPEN/unqueued output before the coordinator queued that PR.
It retained installed `8ab68085` raw Git source under the explicit restricted
read profile and later returned MERGED with exit 0. The independently checked
receipt digest is `141a4530c7a499987cd2fb3fde1238cd7b2aa6767d66f4c0f8f24ba8e92165b6`.
Its event arrived after `process_resumed`; source verified and event status
received. Linux-observed delivery bounds were 237,466–238,628 milliseconds,
including SSH delivery, with the explicit GitHub UTC assumption and timestamp
resolution. This passes the owning plan's 300,000-millisecond waiter ceiling;
there is no substituted sixty-second acceptance target. Full observation was
345.859124593 seconds, including 4.097065970 seconds startup/SSH. One genuine
outcome does not satisfy the twenty-outcome floor, establish p95 regression,
count actual requests or prove savings. The source witness is `8ab68085`, not
the later merge commit being detected.
