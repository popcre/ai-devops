# P1 request attribution — working baseline

Owner: Codex chat `01a0c02a-1fd1-7471-a874-4deb1038d114`, ALBT16.
Tracking: [P1 #660](https://github.com/popcre/ai-devops/issues/660), parent
[#658](https://github.com/popcre/ai-devops/issues/658).
Contract: [request reduction plan](../../../plan_github-request-reduction.md).
Inventory source: upstream `ae1ace582ca4838ce8a8cc7c59aa23d2384ead0d`, 2026-09-20.

## Acceptance status

**Incomplete.** This is instrumentation and an inventory, not an accepted live
baseline or evidence of request savings. No phase after P1 is claimed here.
Acceptance still requires two busy reset windows and twenty comparable completed
operations including PR waiting, BlockerWatch, dispatch and privacy checks. The
offline-replay fallback is available only after two business days of insufficient
volume; a quiet sample today cannot satisfy it.

## Measurement method and denominators

`ai-gh` writes allowlisted local metadata to
`~/.ai-devops/gh-throttle/measurements/YYYY-MM-DD.jsonl`, with seven-day retention
and a 4 MiB daily ceiling. It does not request additional GitHub data. An
independent non-waiting write lock protects complete records; lock contention,
disk failure or capacity exhaustion emits a warning and leaves the command's
status unchanged. A crash may leave that measurement lock and requires inspection
and removal of that exact empty directory before collection resumes. This never
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

The existing quota probe now also selects GraphQL and search counters from the
same response. Its latest allowlisted numeric observation is atomically saved as
`quota-observation.json`; admission still uses core exactly as before (P2 owns
bucket-aware protection). This adds no request or quota probe frequency. Snapshot
deltas describe shared bucket consumption, not attributable managed usage, and
must not be summed across hosts. Missing/invalid bucket values stay null. Reset
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
head requires a fresh independent review; the first rejection is not approval.
After that repair and bounded quota history, `tests/test-ai-gh.sh` passed 61/61
on Windows, including both FIFO cases; no skipped or ignored cases. The quota
fixture executes the real wrapper-supplied jq projection rather than returning a
preconstructed projection, so the three-bucket extraction itself is exercised.

An isolated Windows timing comparison ran ten zero-delay fake CLI operations per
version: prior wrapper 7,362 ms total, instrumented wrapper 9,176 ms total (about
181 ms additional processing per operation). This is a small offline startup
sample, not a workflow p95 or acceptance result. Instrumentation makes zero extra
GitHub requests; ordinary pacing and all networking were excluded from this test.

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
resolve to installed executables. Task Scheduler returned no BlockerWatch or
reviewer-start-watch registration. Therefore a normal local sample cannot be
assumed to include scheduled BlockerWatch scans. P1 must obtain representative
ordinary observations from the appropriate already-configured source host, or
retain that coverage gap and keep attribution acceptance open.

## Remaining evidence and blockers

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
