# P1 request attribution — working baseline

Owner: Codex chat `01a0c02a-1fd1-7471-a874-4deb1038d114`, ALBT16.
Tracking: [P1 #660](https://github.com/popcre/ai-devops/issues/660), parent
[#658](https://github.com/popcre/ai-devops/issues/658).
Contract: [request reduction plan](../../../plan_github-request-reduction.md).
Inventory source: upstream `ae1ace582ca4838ce8a8cc7c59aa23d2384ead0d`, 2026-09-20.
Integration boundary: upstream `b05d15d` ([PR #662](https://github.com/popcre/ai-devops/pull/662))
landed during P1 CI and changes quota admission and probe refresh. Its behavior is
preserved in the P1 integration; this does not establish P2 acceptance.

## Acceptance status

**Incomplete.** This is instrumentation and an inventory, not an accepted live
baseline or evidence of request savings. No phase after P1 is claimed here.
P1 has not merged or been installed, and its live acceptance remains open.
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
