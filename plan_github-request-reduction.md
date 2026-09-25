# GitHub request reduction and complete quota protection

## STATUS — read first

Tracking: [ai-devops #658](https://github.com/popcre/ai-devops/issues/658).
Planning owner: Codex chat `01a0bfd7-ed81-76a1-bf4a-44763532a435`, machine 916.
Date: 2026-09-20. P1 is claimed under [#660](https://github.com/popcre/ai-devops/issues/660)
by Codex chat `01a0c02a-1fd1-7471-a874-4deb1038d114` on ALBT16. This is a new defect programme;
do not reopen the completed #401 throughput programme or claim its proofs cover this work.

P1 update 2026-09-24 2:58 PM EDT (Claude chat, edge-dev): PR #663 merged
10:31 PM EDT 2026-09-23 and installed on edge-dev. Live data: 2,205 records over
15 hourly windows, zero privacy violations, 1,577 quota snapshots
([evidence](https://github.com/popcre/ai-devops/issues/660#issuecomment-5817155903)).
BlockerWatch is about 95% of measured traffic, so P5 has the largest payoff.
Exact-head review of merged P1 rejected only a load-sensitive test; that test was
rebuilt as a handshake and approved in #776 (#775). Dispatch and privacy-proof
callers are not wrapped by design (P3). Acceptance still needs the other active
hosts (ALBT16, 916, hetz) installed and sampled; #660 stays open for its owner.

| Step | State | Owner / dependency | Evidence required to accept |
|---|---|---|---|
| P1. Attribute consumption and freeze a comparable baseline | Merged and live on edge-dev 2026-09-23; multi-host acceptance NOT complete | #660, Codex chat `01a0c02a-1fd1-7471-a874-4deb1038d114` on ALBT16 | [Inventory and measurement boundaries](tests/verification/github-requests/p1-baseline.md); two busy reset windows and 20 completed operations still required |
| P2. Protect the actual quota and preserve command behavior | Open, 2026-09-20 | P1; one claimed implementation owner | Mixed-bucket fixtures and installed quota-mismatch proof |
| P3. Route all managed request sources through the shared policy | Open, 2026-09-20 | P2 | Caller inventory reconciled, regression guard and installed representative paths |
| P4. Coalesce duplicate status reads and waiters | Open, 2026-09-25 — execution steps in [`plan_cut-unneeded-github-traffic.md`](plan_cut-unneeded-github-traffic.md) S2 | P1–P3 | Same-target multi-session trace with one upstream refresh and unchanged outcomes |
| P5. Remove repeated BlockerWatch scans and writes | In progress, 2026-09-25: PR #806 (shared open-issue read), PR #812 (depends_on PR skip), and PR #853 / commit `5f8cf19b` (#809 alarm read cache and node budget, file-based under `$ALARM_TICK`) are on `origin/main`. Remaining: propagate/wake/link REST savings (snapshot reuse), before/after traffic sample — execution plan: [`plan_cut-unneeded-github-traffic.md`](plan_cut-unneeded-github-traffic.md) S1/S4 | P1–P3; serialize with P4 helper edits | Scan/write counts plus wake, alarm and dependency-link equivalence |
| P6. Govern aggregate account demand across hosts | Open, 2026-09-20 | P2–P5 | Selected design record and simultaneous-host quota/recovery proof |
| P7. Install and prove coverage across active clients and hosts | Open, 2026-09-20 | P2–P6 | Host/client/version matrix with one bounded installation proof per session |
| P8. Accept measured savings with no workflow regression | Open, 2026-09-20 | P1–P7 | Comparable before/after report satisfying section 13 |

**Start:** claim P1 on #658, reconcile current upstream and read this entire plan,
then its [discovery handoff](HANDOFF.d/2026-09-20T1801Z-916-codex-github-request-reduction.md).
Each row is a separate outcome/session. The parent is a tracking record, not a
bundle to dispatch to one worker. A phase owner opens a scoped child issue before
implementation and updates this table. At each natural cut, use `fresh-session`
and re-read downstream phases for drift. A landed-but-unproven row must name
exactly one owned proof issue opened by its landing session, not this umbrella.

## 1. The ultimate goal — what we are actually trying to achieve

Albert's work should finish promptly without GitHub limits repeatedly interrupting
it. Remove unnecessary requests where they originate, share already-fetched
information, and reserve enough capacity for useful work. Keep every existing
safety check, notification, recovery path and concurrent work capability.

**If a step conflicts with this goal, the goal wins — stop and flag it.**
Longer sleeps, fewer workers, muted failures and a healthy-looking quota display
are not success. Request savings and workflow behavior must both be measured.

## 2. What this application is

`popcre/ai-devops` is a public recovery toolkit for Albert's multi-model development
workflow. It contains Bash commands, PowerShell installation, configuration,
skills and GitHub Actions tests. It is not an application or database. Installation
is deployment: scripts and client instructions must reach the machines using them.

Canonical Windows checkout: `D:\repos\ai-devops`, landing-only. This plan was
authored in `C:\Users\ahazan2\.codex\worktrees\github-request-reduction-plan\ai-devops`
on `codex/github-request-reduction-plan`, based on upstream
`eb92356e2ebbe2b05d353cbd9e9b26e1678ceb9e`. GitHub origin is
`https://github.com/popcre/ai-devops.git`; implementation branches target `main`.
Use a fresh current-upstream worktree for each implementation phase.

`ai-gh` wraps GitHub CLI calls with pacing and back-off. `ai-pr-wait` and
`ai-gh-wait` provide bounded waits. BlockerWatch maintains dependency links,
alarms and resumes parked work. Its configured propagation host is `edge-dev`;
this is configuration evidence, not proof that the host is currently reachable.
Other repositories, CI jobs, clients and hosts may use the same GitHub identity.
GraphQL is GitHub's query API; REST core and search have different budget buckets.

## 3. What triggered this work

Albert asked why limits continue despite a source-reduction plan, then requested
this complete plan. On 916, the installed `ai-gh.cmd` points to
`D:/repos/ai-devops/bin/ai-gh`. Read-only inspection found:

- Local `~/.ai-devops/gh-throttle/failures.log`, 2026-09-20T16:43:06Z:
  `args=api graphql -f [REDACTED]`, followed by
  `gh: API rate limit already exceeded for user ID 55610577.`
- Its separately fetched diagnostic headers reported `X-Ratelimit-Resource: core`,
  `X-Ratelimit-Remaining: 5000`, `X-Ratelimit-Used: 0`.
- The cached quota record read `1789922582 4999 5000 1789926183`.

Those headers describe the follow-up probe, not the failed request. This proves
the guard's bucket mismatch; it does not identify who consumed GraphQL capacity.
Preserve a scrubbed excerpt in P1. Do not commit the complete local logs.
Reproduce safely with a fake GitHub CLI: REST core healthy, GraphQL exhausted,
then invoke a GraphQL-backed read. Never burn live quota to recreate exhaustion.

## 4. Scope — in and out

In scope: attribution; REST/GraphQL/search and secondary-limit handling; actual
request/point accounting; direct caller migration; repeated read and scan removal;
cross-session and cross-host coordination; bounded waits; client/routing parity;
installation; regression prevention; measured acceptance.

**NOT in this plan:** database structure or data changes; changing review/merge
evidence requirements; reopening #401; rewriting #650 workflow-efficiency work;
rotating credentials, purchasing capacity, moving work to another account to evade
limits, production infrastructure changes without the required review/authority,
vendor binary edits, raw transcript analysis, or implementing the repairs in this
planning task. No new cloud service is pre-authorized. No concurrency ceiling.

Consumer-repository tooling changes, including shared-db tooling, are owned by
their implementation sessions and are non-orchestrator work: they do not change
database structure. Discover each consumer's present owner/repository and rules;
do not inherit a historical route or assume all CI tokens share Albert's budget.

## 5. Current state of the code

Anchors below were checked at planning base `eb92356e`; search by symbol after drift.

| Existing source | Current behavior / state |
|---|---|
| `bin/ai-gh:55`, `:204`, `probe_quota` at `:236–242` | State under one user's home; 300-second cached probe reads only `.resources.core` |
| `bin/ai-gh:268` | Decrements one per CLI invocation; not actual HTTP request count or GraphQL point cost |
| `bin/ai-gh:291–311` | Failure diagnostics fetch rate-limit headers afterward; reset can describe core rather than failed GraphQL |
| `bin/ai-pr-wait:243` | One GraphQL query obtains PR state/checks/merge-queue membership each polling cycle |
| `bin/ai-test-local:158` | Direct paginated `gh api` runner check; preserve collision protection when migrating |
| `bin/ai-verify-run:43–84` | Direct reads and mutations for exact-SHA dispatch/cancel; preserve duplicate prevention and cancellation authority |
| `bin/ai-workspace-status:94` | Direct `gh pr view` for a status snapshot |
| `bin/ai-memory-sync:90` | Direct private-repository proof; never replace with stale cached privacy state |
| `bin/ai-blocker-watch`, `PARENTS_Q`, `LINKS_Q` | Separate paginated OPEN issue queries for alarm and dependency-link work |
| `config/blocker-watch.json` | Ten-minute tick; separate hourly alarm/link scans; propagation on edge-dev |
| `tests/test-ai-gh.sh:17`, `:68–78` | Core-only quota fixture and primary/secondary refusal tests; mixed-bucket prevention missing |
| `AGENTS.md:51–55` | All callers must use wrapper, but explicitly acknowledges older bypasses |
| `plan_shared-db-complete-throughput-repair.md`, decision 19 / acceptance | Pacing and workflow evidence exist; no complete account-wide request/point acceptance report |

These mechanisms are already committed upstream; do not rebuild them from scratch.
Installed launcher resolution was checked on 916 only. No fleet-wide state,
account-wide consumer attribution, or source-saving baseline has been proven.
Planning changes are prose only; no runtime repair or installation has occurred.

## 6. Key findings and root cause

1. **Wrong budget gate.** GraphQL can be exhausted while core is full. GitHub
   explicitly separates the budgets and charges GraphQL by points:
   [official GraphQL limits](https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api),
   [official rate-limit resource](https://docs.github.com/en/rest/rate-limit/rate-limit).
2. **Calls are not requests.** A CLI command can paginate or perform multiple API
   operations. One decrement is a local estimate, not measured consumption.
3. **Local serialization is not account coordination.** Different homes/machines,
   unmanaged clients and independently authenticated jobs can contribute demand.
   Classify actual authenticated host/principal/bucket; never infer identity from
   a convenient environment label or token text.
4. **Pacing does not remove repeated work.** Independent waiters and scan functions
   can read the same state repeatedly. Their verified semantics must survive reuse.
5. **Coverage is voluntary today.** Rules do not route existing bare calls, SDKs,
   direct HTTP or future scripts automatically. Source guardrails need an inventory.
6. **Acceptance was narrower than the expectation.** Preserve historical throughput
   evidence as valid for its scope; add a new measurable demand/coverage gate.

Largest consumers, cross-host contribution, GraphQL cost distribution and the
amount of outside-tool consumption are unknown. Do not label BlockerWatch or
any particular session as today's culprit without P1 measurements.

## 7. Approaches considered and REJECTED, and why

- Raising sleeps/back-off or lowering parallelism: delays useful work and leaves
  duplicate demand intact. Back-off remains necessary for real refusals.
- Probing quota before every operation: creates another high-frequency caller.
  Use single-flight bounded probes and response metadata where available.
- Treating healthy core as proof that GitHub is healthy: contradicted by the incident.
- Logging raw `GH_DEBUG=api`, bodies, argv, tokens or complete queries: risks public
  disclosure. Collect only allowlisted metadata, scrub before persistence.
- Caching every command: mutations, privacy, authorization, exact-head merge/review
  evidence and collision checks need fresh authoritative state.
- New cloud broker/webhook fleet as the first move: adds installation, trust and
  availability obligations before proving simpler demand reduction sufficient.
- Token rotation or splitting identities to get more quota: does not repair sources.
- Blanket bare-`gh` text bans: tests and the wrapper legitimately invoke a fake/real
  CLI; SDK/HTTP paths could still bypass a simplistic grep rule.
- Claiming a complete request count from before/after quota deltas: other clients
  spend during that interval. Record deltas separately with uncertainty.
- Closing after unit tests or one quiet hour: proves neither installation nor peak
  workload behavior. A small-sample result stays provisional.

During diagnosis, `ai-task-gates start --class analysis` was rejected because that
class does not exist; prose is the planning class. Windows `.cmd` argument quoting
can split complex queries; use Git Bash and file-backed bodies. These were tooling
discovery errors, not evidence that GitHub capacity improved.

## 8. Design decisions already made (2026-09-20)

**Locked:** preserve capabilities, safety checks and concurrent workers; source
reduction precedes claims of completion; use existing `ai-gh`/waiters/BlockerWatch;
no hidden fallback, quota bypass or automatic mutation retry; no secret-bearing
telemetry; one live outcome per session; compare equivalent workloads.

**Selected direction:** separate bucket-aware admission from reusable read
snapshots. Keep `ai-gh` a transparent CLI boundary for existing callers. Add opt-in
structured request operations for managed high-volume paths, with explicit method,
read/mutation classification, identity, freshness and cost metadata. Unclassified
CLI calls remain visible conservative estimates; they cannot be advertised as exact
metering. Correct GraphQL errors returned inside HTTP 200 responses are failures.

**Open engineering decisions, not owner questions:** safe metadata transport;
cache implementation; measured batch size; fleet coordinator necessity. Resolve
each using P1/P6 criteria and record alternatives/results before implementation.
Never claim exact global admission from independent local snapshots. Do not deploy
a remote coordinator until its exact resource/action has the required authorization.

## 9. The plan — ordered executable phases

### P1 — Attribute consumption and establish the baseline

Targets: `bin/ai-gh` safe logging/probe boundaries; `tests/test-ai-gh.sh`; add
`tests/verification/github-requests/` for scrubbed reports. This existing toolkit
owns the report; it is not a new independent monitoring service. If a helper is
needed, put it under `tools/github-requests/`, owned by #658, consumed by ai-gh and
tests; retire any provisional collector when the shared helper replaces it.

Inventory repository-managed shell, PowerShell, Python/JS, workflows, schedules,
MCP/SDK/direct HTTP callers and installed aliases. Start with section 5 and follow
their real call paths: trigger → caller → transport → identity → bucket → guard →
retry → result. List all blockers together. Inventory active hosts from supported
machine records and read-only discovery; never traverse network drives or private
transcripts. Catalogue external clients as measured or unknown, not silently absent.

For each operation record UTC time, authenticated host/principal identifier,
machine, caller/operation ID, public repo or redacted identifier, request class,
bucket, observed cost/count versus estimate, cache hit, latency, result and reset.
No bodies, URLs with query values, credentials or raw arguments. Preserve stdout,
stderr and exit status. Bound retention/disk use; telemetry failure must be visible
without converting a failed operation to success. Private local aggregation is
separate from public scrubbed reports.

Capture at least two busy reset windows and 20 comparable completed operations,
including PR waiting, BlockerWatch, dispatch and privacy checks. Record current
versions, throughput, request counts/GraphQL points, quota deltas, detection latency,
idle scans and coverage. If volume is insufficient after two business days, use
controlled offline trace replay plus a bounded normal live sample and mark the
live baseline provisional. Do not generate pointless production work or quota load.

Gate: `tests/test-ai-gh.sh` passes new `telemetry_redacts_before_write` and
`telemetry_preserves_streams_and_status` cases; sanitized baseline identifies top
managed sources, unknown share, measurement method and all coverage gaps.
Each subsequent phase consumes this baseline; it does not repeat discovery.

### P2 — Correct resource-aware quota protection

Targets: `bin/ai-gh` `probe_quota`, state schema, admission, error classification,
reset/back-off and tests. Extend existing settings through documented configuration;
do not hard-code today's 5,000-point limit. Read all applicable resource buckets
from one bounded probe; track REST core, GraphQL and search separately, and shared
secondary back-off independently. Other reported buckets remain explicit unknowns
until mapped. Key observations by verified API host and authenticated principal;
respect separate application/repository tokens and changes in authentication.

GraphQL-backed CLI commands must not default to core. Classify known paths; for
unknown/mixed commands use conservative admission with explicit uncertainty.
Use response cost/headers when safely available and count pages for structured
paths. Never pretend opaque commands cost exactly one. Probe cache has a validated
version, expiry/reset semantics and atomic migration from the old core-only file.

Honor Retry-After and the relevant bucket's reset; do not derive GraphQL recovery
from core headers. Handle 403 permission errors separately, 429/secondary limits,
GraphQL HTTP-200 errors and partial results. A probe failure is unknown, never
healthy zero-use. Preserve bounded waits and exit 75 for deferred operations;
mutations are never automatically replayed after an ambiguous outcome.

Gate: healthy-core/exhausted-GraphQL fixture blocks before real call, and the
inverse does not unnecessarily block a safe independently budgeted read unless
shared secondary back-off applies. Prove separate reset times, pagination costs,
unknown identity, probe timeout and old-state migration. Installed dry-run admission
with injected quota fixtures plus one normal live read proves original CLI behavior;
do not intentionally exhaust the real account.

### P3 — Close managed bypasses and prevent regression

Targets: section 5 callers; `bin/ai-merge-group-evidence` if P1 confirms applicable;
their existing tests; consumer repository files explicitly recorded by P1;
`tests/test-workflow-policy.sh` and a focused source-coverage test under `tests/`.

Migrate each network call through shared admission without altering its purpose.
Collision protection, exact-SHA duplicate prevention, explicit cancellation and
private-repo validation retain fresh reads and failure behavior. Distinguish
Actions `GITHUB_TOKEN` from user credentials instead of imposing one false bucket.
Cover supported direct HTTP/SDK operations via the structured transport or a
documented adapter. Test fixtures and ai-gh's real CLI transport form a narrow
reasoned allowlist; it must not accept arbitrary executable bypasses.

Gate: inventory has a disposition and owner for every source; fake CLI/HTTP spies
prove representative paths enter admission, including failure and paginated paths.
New bypass fixture fails CI, legitimate test transport passes. A bounded installed
operation preserves each changed capability. Separate repository changes ship in
their own worktrees/PRs and require evidence links before marking coverage complete.

### P4 — Share status reads and eliminate duplicate waiter demand

Targets: `bin/ai-pr-wait`, `bin/ai-gh-wait`, ai-gh structured read support,
`tests/test-ai-pr-wait.sh`, `tests/test-ai-gh.sh`; add focused waiter-sharing tests
only where existing suites cannot represent multi-process behavior.

Implement single-flight, meaning one upstream read serves simultaneous consumers
of the same public status snapshot. Keys include verified host/principal/access
context, repo identity, operation/arguments, target SHA where relevant and schema
version. A cache is not authority. Partition private visibility; bound age and
storage. Fresh exact-head safety operations and mutations never reuse display data.

Coalesce same-PR waiters, reuse recent structured status and avoid re-fetching
unchanged fields. Preserve initial state, first failure, cancellation, merge,
queue ejection, deadline and terminal exit codes. A cancelled waiter must not cancel
others. Dead refresh owners are recovered by verified ownership, not age alone.
Events already available in the workflow can invalidate snapshots; retain bounded
reconciliation for lost events. Do not introduce a new webhook service here.
Truncated check connections or partial GraphQL results must never become a cached
success: fetch the missing pages or return an explicit incomplete/nonzero outcome.

Gate: multi-process fixture makes one upstream refresh per target/freshness window,
different identities never share private data, and every subscriber receives each
terminal result. On an existing authorized PR, demonstrate multiple local waiters
sharing reads without slower detection than the existing five-minute ceiling.
The ceiling is a maximum detection interval, not permission to add more delay.

### P5 — Reduce BlockerWatch source scans and redundant writes

Targets: `bin/ai-blocker-watch` `PARENTS_Q`, `LINKS_Q`, `alarm_scan`, `maintain_links`,
tick flow; `config/blocker-watch.json`; `tests/test-ai-blocker-watch.sh`.

Create one bounded paginated snapshot per repo/tick for compatible alarm/link
inputs, rather than separate complete OPEN scans. Measure GraphQL points as well
as HTTP calls: a giant combined query can be more expensive. Fetch minimal fields
and enrich only actual candidates. Use updated-since cursors with overlap only
where API semantics cover closures/reopens/relationship changes; otherwise preserve
bounded reconciliation and prove it catches missed transitions. Do not rely on
issue updatedAt for every dependency change without evidence.

Keep edge-dev's configured propagation role and local wake behavior. Idempotency
keys/state suppress duplicate comments, digest entries and existing links, with
fresh validation before mutations. A closed-unmerged PR remains cancellation,
not completion. Preserve stale-owner alarms, parked-work recovery and wake evidence.
Malformed input stays visible; partial scans cannot advance the completed cursor.

Gate: a replay with >100 issues and >50 dependencies exercises pagination/truncation,
reopen/close, missed events, crashes and retry. It produces the same eligible wakes,
alarms and links with fewer calls/points, zero repeated unchanged writes and no
missing tail records. One normal installed tick proves the same behavior; no mass
test comments, fake blockers or live failure injection across unrelated issues.

### P6 — Coordinate the account across machines without an unnecessary service

Targets: ai-gh state/transport, P1 consumer inventory, existing fleet configuration
and installation paths (`install.sh`, `bin/install-machine-tools.ps1` as applicable).
Read `docs/deployment.md` and current machine-atlas sections before selecting hosts.

First reconcile authenticated principals, applications and repository tokens across
active hosts. Aggregate observed consumption and server bucket deltas. Do not sum
the same shared quota delta once per host. Identify unobserved demand explicitly.
Reuse P4/P5 source ownership to eliminate redundant fleet-wide scans before adding
distributed locks. No quota-probe loop or per-request GitHub ledger is allowed.

Decision gate: test simultaneous representative host load against measured P1 peak.
If source deduplication plus bucket observations maintains section 13 headroom,
choose local admission with shared-source ownership and explicitly label it
non-global; no claim of strict account-wide reservation. Otherwise implement one
bounded account admission/snapshot coordinator on an existing approved host,
preferably the already designated propagation host after suitability is proven.
Record necessity, exact resource, owner, failure model and retirement path first.
No new infrastructure mutation is authorized merely by this plan.

Coordinator contract, if required: authenticated clients request expiring bounded
cost reservations for verified principal/bucket, execute with their own local
credentials, and reconcile observed spend. No token export, no raw operation bodies,
no forwarding arbitrary shell commands. Reject identity spoofing and replay; cap
lease duration/cost; recover crashed holders without double spending. Reuse a proven
authenticated channel already installed; if none qualifies, the phase is blocked
for the exact infrastructure review rather than inventing a weak shared file lock.
On outage, emit explicit deferred/unavailable status; any fallback must have a
proven bounded aggregate budget and be visible. Never fail open without accounting.

Gate: two or more real active hosts under ordinary workload plus deterministic
partition/crash tests demonstrate headroom, separate identities, correct back-off
and recovery. Offline hosts are documented uncovered, not accepted. Outside-client
consumption remains a measured residual; this tool cannot control all GitHub users.

### P7 — Install and prove the actual request paths

Targets: existing lifecycle installers, `config/machine-tools.tsv`, client globals
and matching ship/wait skills only where P3 inventory proves a routing gap;
`AGENTS.md`, `docs/task-router.md`, `docs/architecture.md`, this plan.

Use supported installers after backing up affected config. Preserve Claude, Codex
and ZCode parity; never overwrite a client's config through another client's setup.
Resolve each installed launcher/symlink and actual script hash. Windows and Bash
both need proof. A prose router change is not proof of installed executable routing.
Each installation session owns one host's outcome and retains all capabilities.

Gate: checked matrix names host, client/scheduler, authenticated-principal class,
script hash, installer evidence and representative live result. Every active source
in the frozen inventory is covered or explicitly excluded with rationale; unavailable
hosts block the fleet acceptance row. Existing schedules must not be disabled to pass.

### P8 — Measure and close on outcomes

Targets: dated reports under `tests/verification/github-requests/`, STATUS, #658
and scoped issues; root handoff pointer is untouched. Re-run the same trace shapes
and comparable live workload used in P1. Publish denominator, window boundaries,
host coverage, requests and points separately, event latency, throughput, failures,
uncertainty, raw-artifact digest and scrubbed reproducible commands.

Gate: all section 13 criteria pass. Update active current-state claims; preserve
the incident/rejected-design record. Delete this handoff only when its obligations
are proven or fully carried forward under the handoff successor rule. Close #658
only after whole-programme acceptance, never when this planning PR merges.

## 10. Tests required

Run focused tests for each touched capability using Git Bash on Windows:
`bash tests/test-ai-gh.sh`, `bash tests/test-ai-pr-wait.sh`,
`bash tests/test-ai-blocker-watch.sh`, `bash tests/test-ai-verify-run.sh`,
`bash tests/test-ai-test-local.sh`, `bash tests/test-ai-memory-sync.sh`,
`bash tests/test-ai-merge-group-evidence.sh`, `bash tests/test-workflow-policy.sh`
as applicable. Confirm filenames at current upstream before work. Add workspace
status coverage if absent. Installation phases use the existing Windows/Bash
installer tests. Full required CI remains authoritative; no duplicate same-host
full run or repeated already-proven exact commit. No UI tests: no UI is changed.

New adversarial cases below are required behaviors, not claims that tests exist.

| External input / boundary | Hostile or ambiguous case | Required named test |
|---|---|---|
| Quota response | Core healthy, GraphQL empty; inverse | `quota_buckets_independent` |
| Response/reset | Different resets; 200 with GraphQL errors; 403 permission | `quota_error_and_reset_classification` |
| Probe JSON | Missing/malformed/negative/overflow/unknown resource | `quota_unknown_never_healthy` |
| CLI transport | Pagination, mixed calls, large point cost | `cost_not_cli_invocation_count` |
| Authentication | Host change, token switch, unverifiable identity | `quota_identity_partition_and_unknown` |
| Rate refusal | Retry-After malformed, secondary burst, retry loop | `secondary_backoff_bounded_no_hot_retry` |
| Mutation response | Timeout after possible commit | `ambiguous_mutation_never_replayed` |
| Telemetry | Token/body/query/newline injection; log failure | `telemetry_redacts_before_write`, `telemetry_preserves_streams_and_status` |
| Local state | Old/corrupt file, crash during atomic write, stale lock | `state_migration_and_owner_recovery` |
| Cached read | Different access scope/SHA; stale success | `snapshot_identity_and_freshness_isolation` |
| PR check connections | More checks than one page; GraphQL partial data | `pr_snapshot_partial_never_success` |
| Concurrent waiters | Same key, cancelled consumer, dead leader | `singleflight_concurrent_terminal_delivery` |
| GitHub events | Dropped, replayed, reordered transition | `event_reconciliation_no_lost_terminal_state` |
| Paginated scans | >100 issues, >50 edges, partial response, reopen | `blocker_snapshot_complete_or_nonzero` |
| Dependency text | Malformed fence, cross-repo confusion, PR/issue mismatch | `blocker_input_does_not_create_wrong_link` |
| Duplicate work | Unchanged tick repeated; mutation acknowledged late | `blocker_unchanged_tick_no_duplicate_writes` |
| Source scanner | Bare HTTP/SDK bypass; fake CLI fixture | `managed_transport_coverage_guard` |
| Fleet admission | Clock skew, partition, forged lease, crashed holder | `fleet_admission_partition_and_replay` |
| Acceptance report | Missing host/window, double-counted shared delta | `request_report_coverage_and_denominator` |

Test the whole sibling-path class of each risk before first independent review.
Preserve all existing safety assertions. Fixtures must use isolated state and
fake transports: test suites never spend live GitHub quota.

## 11. Constraints, standing rules and gotchas

- `ai-task-gates start --class prose` for this plan. Implementers declare code,
  installation or reviewer-safety as the real change requires; check before
  review/ship/deploy/infrastructure. Do not work around refusals.
- Worktrees from current upstream; exact owned staging. Before first commit,
  `git var GIT_COMMITTER_IDENT` must show Albert Hazan with
  `u2giants@users.noreply.github.com`. Every GitHub call uses `bin/ai-gh`.
- Code ships through normal protected checks/queue. Reviewer safety/routing work
  needs independent read-only exact-head review. This prose-only plan follows
  Albert's documentation-only merge exception after verifying the file list.
- No production/shared-infrastructure mutation without the exact required authority
  and independent reviewer approval. Secrets remain in `vibe_coding`, never logs.
- Wait through bounded existing helpers. No `gh run watch`, ad hoc polling or new
  per-request GitHub bookkeeping. A real owned issue blocker uses BlockerWatch.
- Preserve exact-head safety evidence, private-repo proof, runner collision checks,
  wake/cancel distinctions and nonzero scheduled failures. Cached display data
  cannot authorize merging, dispatching or privileged writes.
- Sign every posted GitHub body with chat ID/machine. Memory updates are not
  authorized; discovery comes from repository links and the mandatory handoff.
- Before parallel implementation, assign disjoint files; ai-gh/shared helper changes
  serialize. Subagents report evidence; owner makes merge/security decisions.

## 12. Access and environment

PowerShell 7 and Git Bash (`C:\Program Files\Git\bin\bash.exe`) are available on
916. The installed ai-gh launcher was resolved and local logs read without secrets.
Authenticated ai-gh search and creation of #658 succeeded on 2026-09-20. Re-check
auth with a single safe supported probe when needed; never print tokens. No secret
lookup or permission expansion was needed for planning. There is no app login.

Windows shell quoting has damaged `--jq` expressions in other logged calls; use
Git Bash for complex commands and exact file-backed JSON/Markdown input. Never
interpolate secrets into arguments. Follow each consumer repo's AGENTS and current
GitHub identity. Remote hosts have not been live-qualified by this planning task.
Read their machine-atlas section and existing access instructions before any access.

Use normal local scratch state/fake CLI for tests. For live evidence use already
authorized normal operations and low-volume probes after reset. A primary refusal
defers with its real reset; it is not permission to use another token or disable ai-gh.

## 13. Definition of done, risks and open questions

P1 freezes a representative workload and denominators before repairs. Minimum
acceptance contract (engineering targets chosen for this plan, not historical facts):

1. **Coverage:** 100% of inventoried managed network paths have a tested disposition;
   all active hosts/clients installed. Unknown outside consumption is quantified
   or explicitly bounded; unexplained dominant spend blocks attribution acceptance.
2. **Source savings:** at least 50% fewer upstream reads for duplicate same-target
   waiter/scan replay, zero duplicate unchanged writes, and at least 30% lower
   managed API consumption per equivalent completed live outcome. Report requests
   and GraphQL points separately; shifting spend between APIs does not count.
3. **Headroom:** in at least two comparable busy reset windows, zero attributable
   primary/secondary refusals and at least 20% remaining per relevant bucket under
   the measured representative peak. External bursts are disclosed, never hidden.
4. **Workflow:** identical safety/terminal outcomes and no missed wake, alarm, link
   or queue failure. Compare at least 20 outcomes by operation type; p95 useful-work
   completion/detection latency must not regress by more than 5%, and configured
   five-minute waiter/ten-minute BlockerWatch detection ceilings must hold. Separate
   external CI/provider latency and disclose small samples; no invented p95.
5. **Budget honesty:** multi-page/mixed/GraphQL cost is observed or marked estimated;
   shared deltas are not double counted. Instrumentation overhead is included and
   no more than 5% of managed requests. Insufficient data stays provisional.
6. **Delivery:** focused tests and required CI pass; scoped commits/PRs merged;
   intended commits verified on origin/main; exact installed hashes and live
   outcomes linked; STATUS and ownership reconciled; all proof issues resolved.

If 50%/30% savings are mathematically unattainable because measured useful demand
dominates, do not manufacture waste or reduce capability. Record P1's irreducible
lower bound and concrete counterexample, independently review the revised target,
and amend the contract before acceptance. Never quietly weaken it after a miss.
If live samples remain too small after two business days, finish offline equivalence
proof and keep exactly one owned acceptance issue open with a bounded next sample.

Risks: stale evidence, private-data cache leakage, oversized GraphQL queries,
transport incompatibility, account misidentification, coordinator outage and partial
fleet rollout. Roll back through the prior known-good toolkit commit and supported
installer with saved state/config; retain diagnostics and report reduced coverage.
Do not clear rate-limit state, disable watchers, remove gates or expose raw logs.

Open factual questions belong to P1/P6: top spenders, available metadata, active
fleet/auth boundaries, event completeness and need for strict global reservations.
No current owner decision blocks writing/publishing this plan. A future new
infrastructure action must present its exact resource/design to the required
independent reviewer and respect current authority; it is not pre-approved here.

## Plan self-audit

1. **Could a brand-new AI session with no project knowledge and no context from
   this conversation execute this plan without asking anything?** Yes. Sections
   1–6 provide purpose, environment, incident, source anchors and uncertainty;
   STATUS and 9 give ownership, sequence, targets and observable gates; 10–13 give
   tests, access, constraints and acceptance. Unknown measurements have bounded
   discovery steps and decision criteria, not assumptions requiring Albert.
2. **Does the plan carry every relevant piece of background, nuance and reasoning,
   including what was ruled out and why?** Yes. Sections 3, 5–8 preserve the bucket
   mismatch, incomplete attribution, old plan's limited proof, false fixes and
   chosen design. Sections 9–13 preserve rollout, privacy and cross-host risks.
3. **Is the ultimate goal clear enough to guide a correct judgment call?** Yes.
   Section 1 makes source reduction plus preserved workflow the goal; sections 8
   and 13 forbid delay/capability cuts and supply measurable success criteria.

Checklist passed: all 13 sections, dated STATUS, concrete phase targets and gates,
named adversarial tests, explicit exclusions, locked/open decisions, rejected
approaches, secrets policy, delivery proof and reciprocal handoff/discovery links.
No claim is made that future implementation or its acceptance is already complete.
