# GitHub request reduction and complete quota protection

## STATUS — read first

Tracking: [ai-devops #658](https://github.com/popcre/ai-devops/issues/658).
Planning owner: Codex chat `01a0bfd7-ed81-76a1-bf4a-44763532a435`, machine 916.
Date: 2026-09-20. P1 is claimed under [#660](https://github.com/popcre/ai-devops/issues/660)
by Codex chat `01a0c02a-1fd1-7471-a874-4deb1038d114` on ALBT16. This is a new defect programme;
do not reopen the completed #401 throughput programme or claim its proofs cover this work.

P1 update 2026-09-27 11:09 PM EDT (Codex, read-only fleet survey): PR #663 merged
10:31 PM EDT 2026-09-23 and installed on edge-dev. Live data: 2,205 records over
15 hourly windows, zero privacy violations, 1,577 quota snapshots
([initial evidence](https://github.com/popcre/ai-devops/issues/660#issuecomment-5817155903)).
BlockerWatch is about 95% of measured traffic, so P5 has the largest payoff.
Exact-head review of merged P1 rejected only a load-sensitive test; that test was
rebuilt as a handshake and approved in #776 (#775). Dispatch and privacy-proof
callers are not wrapped by design (P3). A later read-only sample found 8,175
wrapper records and two active reset windows on edge-dev, but no count of 20
completed workflows or exact HTTP/GraphQL consumption. The 916 and hetz
installations are still pre-P1 with no measurement history. The full 916 update
is stopped by its protected reviewer-safety deployment gate; #660 stays open.

Update 2026-09-28 2:41 PM EDT (Codex issue #658 orchestration): P2 #929,
P4/S2 #948, installer #950, P3/S3 #973, and P1 #970 have merged. P2 #914

2026-09-29 transcript finding 5: GitHub quota — finish P5 (BlockerWatch → existing App) before any multi-App split; lint direct `gh`; show remaining quota in `ai-gh` output.
and P4 #925 passed installed proof and closed. Guarded installation and measured
acceptance remain open. A forward-only P1 attribution repair is in PR #1000;
its first Windows CI run failed two fixture assertions; the then-current scoped
repair received exact-head independent APPROVE, but subsequent commits invalidated
that verdict. Historical GraphQL cost and quota snapshots cannot be
joined to one credential context.
The current phase states are below and in the
[active handoff](HANDOFF.d/2026-09-28T1149Z-edge-dev3-codex-github-request-reduction.md).

Stop-state update 2026-09-28 3:40 PM EDT: Albert explicitly stopped this
session and requested handover. Parent #658 was reopened because nine acceptance
items remained unchecked. PR #1000 is open at `7190d7a`; Linux focused tests
passed 204/0 and a protected Windows fixture pattern passed on 916, but the
latest exact-head review is BLOCKED because its packet omitted test evidence.
No merge or installation may use that verdict. A valid 4837 exact-head REJECT
found a report crash and Windows recovery defect; scoped #1008 contains an
interrupted, uncommitted repair in its own worktree. No fresh install approval
exists for that changed target. The replacement standing rules put technical
sign-in/access recovery on AI and prohibit asking Albert to perform it.

Update 2026-09-28 10:55 PM EDT (MiMo on edge-dev): PR #1000 merged through
the queue as `2b0fe5ab2553d31378e6caa81ac3fb74d111e762` and confirmed on
`origin/main`. Exact head `953997e7` repaired Windows quota-context fixtures
(`Get-Acl` import failure → .NET ACL APIs) and non-regular `principal-salt`
reads (FIFO must not block). Codex exact-head final-check APPROVE with
`tests/test-ai-gh.sh` 205/0 in the packet. Signed proof:
https://github.com/popcre/ai-devops/issues/658#issuecomment-5887556377.
Installed P1 reporting (#660) and the rest of the handoff remain open.

| Step | State | Owner / dependency | Evidence required to accept |
|---|---|---|---|
| P1. Attribute consumption and freeze a comparable baseline | Partial: PR #970 merged as e108418 and PR #1000 merged as 2b0fe5ab (access-context join + Windows ACL/salt fixtures, Codex APPROVE at 953997e7); edge-dev3 still has only 2 completed non-deadline receipts; installed reporting proof remains open | #660, successor owner of #658; guarded installation and live proof | Baseline exists; 20 comparable operations, host samples, principal binding, and actual request/point attribution still required |
| P2. Protect the actual quota and preserve command behavior | Accepted: PR #929 (b2fb997) merged after review/CI; installed edge-dev3 hash matched and normal GraphQL read passed at 11:37 AM EDT; #914 closed with signed proof | Codex issue #658 orchestrator | Separate-bucket, identity, malformed-state and cost fixtures plus installed read passed; broader P8 savings remain separate |
| P3. Route all managed request sources through the shared policy | PR #973 merged as 9cf87d4 after exact-head approval, focused tests, and green CI; shared-db consumer #3649 merged; installed #931/#933 proof open | #931 and #933 scoped proof owners; installation | Caller inventory, regression guard, and PR/CI passed; installed representative paths remain |
| P4. Coalesce duplicate status reads and waiters | Accepted: PR #948 (f55c1a6) merged after review/CI; two installed edge-dev3 waiters shared one OPEN refresh and kept independent deadline outcomes at 11:45–11:46 AM EDT; #925 closed with signed proof | Codex issue #658 orchestrator | Live same-target trace passed; terminal merge/ejection and identity isolation passed checked-in fixtures |
| P5. Remove repeated BlockerWatch scans and writes | Snapshot live proof accepted October 1 under closed #868; category-label defect #1212 and quota-context defect #1211 remain open; repeated same-target fallback reads are under investigation | Current #658 coordinator; scoped #1211/#1212 repairs | Existing snapshot proof retained; new repairs require tests, guarded install and live proof |
| P6. Govern aggregate account demand across hosts | Provisional decision on #658: retain local admission; no coordinator without same-principal contention evidence | Codex issue #658 orchestrator; P1/P7 samples | Simultaneous-host quota/recovery proof or evidence-backed final design record |
| P7. Install and prove coverage across active clients and hosts | Open: #1008 code repair accepted and closed October 7; guarded installation needs the [bounded partial-install specification](#p7-bounded-partial-installation-repair-specification), independent plan review, implementation, and host proof; prior host observations below remain historical | Current #658 coordinator; exact-host reviews, runtime collision controls and installation gates | Active fleet/client/source-hash matrix and original installed paths; production remains separately gated |
| P8. Accept measured savings with no workflow regression | Open: no valid 20-outcome/two-busy-window comparison yet | Codex issue #658 orchestrator; P1-P7 | Comparable before/after report satisfying section 13 or independently reviewed lower-bound amendment |

Update October 7, 2026, 10:05 AM EDT: Codex chat
`01a116aa-0400-7230-97d9-3fab73f00bd1` on edge-dev3 owns programme
coordination. Albert explicitly authorized independent parallel lanes through
tested delivery, installation and measured closeout. Earlier automatic child,
phase or session stopping instructions are superseded; dependency, ownership,
collision and safety gates remain binding. Separate owners cover quota/label
repairs, measurement/source savings and fleet readiness. Reviewer allocation,
shared files, credentials, merge decisions and each installation are serialized.
The [bounded October 2–7 aggregate](tests/verification/github-requests/p1-baseline.md)
contains 1,065 receipts and 624 observed GraphQL points, but no comparable
savings, whole-account totals or useful-work latency proof. #658 stays open.

**Start:** reconcile current upstream, read this STATUS and the
[active handoff](HANDOFF.d/2026-09-28T1149Z-edge-dev3-codex-github-request-reduction.md),
then finish the first actionable unproved outcome under #658. The original
the discovery handoff (retired; see git history)
remains historical context.
Each row is a separate outcome with one accountable owner under the current
orchestrator. The parent is a tracking record; distinct proof outcomes stay on
scoped child issues. A phase owner updates this table and re-reads downstream
phases for drift. A landed-but-unproven row must name exactly one owned proof
issue rather than treating this umbrella as live proof.

## 1. The ultimate goal — what we are actually trying to achieve

The source inventory and phase instructions below record the original design.
Use the dated STATUS table above for what has landed, what is installed, and
which proof remains open; do not redo a merged phase from historical prose.

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
telemetry; continue authorized live outcomes when actual gates allow; compare equivalent workloads.

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
Verify each host’s installation outcome separately and retain all capabilities; continue authorized work when actual gates allow.

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

## P7 bounded partial installation repair specification

### 1. Ultimate goal

Install the accepted GitHub request-saving changes on active managed machines,
so existing work uses fewer requests without losing any command, wake, alarm,
link, privacy check, queue outcome, or safety protection. **If a step conflicts
with this goal, the goal wins: stop and flag it to the #658 coordinator.**
This is an installation repair within P7 and existing issue #658, not a new
programme, plan, leftover-proof issue, or security-incident implementation.

Specification state on October 7, 2026: design only; independent plan review
and coordinator decision are required before source implementation. The existing
STATUS and historical handoff above are this section's discovery route; no new
handoff is created. Re-read this section, P1/P3/P5/P8, current GitHub and fetched
upstream before each phase. Moving host, source and reviewer facts must be
refreshed; examples do not constitute installation authority.

| Delivery step | State | Acceptance artifact |
|---|---|---|
| A. Review bounded design and fixed route protocol | Open | Assigned independent exact-plan APPROVE and coordinator decision |
| B. Implement shared receipt, authority and resolver | Open | Reviewed commit, adversarial receipts and platform tests |
| C. Extend existing installers and full-install reconciliation | Open | Exact-head APPROVE, required CI, normal merge queue |
| D. Install one inventoried host/profile outcome | Open | Protected partial receipt, original capability evidence on owning issue |
| E. Complete fleet and measurement acceptance | Open | P7 matrix and P1/P8 evidence; no inference from merge alone |

### 2. Application and environment

`popcre/ai-devops` is the public recovery toolkit used by Albert's AI agents.
It is Bash, PowerShell, Python and Node source, not a deployed web application.
Installation supplies managed command routes, globals and scheduled operations.
GitHub protected `main` and its merge queue are authoritative; primary checkouts
are landing-only. Ubuntu and native Windows/Git Bash are supported platforms.
Fleet host/profile identities come from protected configuration and current
read-only inventories; never publish topology or infer a host from a label.

Use the existing [deployment procedure](docs/deployment.md),
[implementation-plan standard](templates/system/implementation-plan-standard.md)
and [task router](docs/task-router.md). The full installer remains supported.
This partial mode stages public source and changes selected owned execution
pointers; it does not provision provider runtimes or machine services.

### 3. Trigger and reproducible problem

P1/P3/P5 code can be merged while installed launchers still run older source.
#931 and #933 require original installed caller/elevated Windows coverage, and
#660 requires installed attribution and actual consumption measurements.
Current full installers perform unrelated package, skill, config, service,
memory and provider operations. Existing limited host inventories do not bound
those operations. Linux `install.sh --skip-secrets` skips Secrets wiring only;
it still runs required protected-config sync and private-memory seed, optional
Desktop MCP wiring, and token-backed provider stages. Source-only Windows
installation keeps authority pending and cannot honestly issue a completed
full installation receipt.

Reproduce read-only: inspect `install.sh` stage declarations and
`bin/ai-task-gates:linux_stage_report_valid`, then inspect
`bin/install-ai-devops-windows.ps1` SourceGateOnly and final launcher refresh,
and `bin/install-machine-tools.ps1` canonical complete-catalog checks. Do not
run installation to reproduce this scope problem.

### 4. Scope

In scope: fixed `github-request-reduction` partial mode in existing installer
and gate homes; immutable exact public source; fixed route catalog and
source-verified host inventory; receipt-aware resolver; one-use exact-operation
authority; retry/rollback; full-install reconciliation; Linux and native Windows
proof. Managed scheduler actions and consumer invocation pointers are included
only when explicitly inventoried and owned.
The existing elevated Windows maintenance payload is refreshed through its
supported protected installer stage; its fixed ProgramFiles path and fixed
task/action are preserved. It is not an ordinary launcher-pointer switch.

Not in this specification: provider/package/skill/global/MCP installation,
credential rotation or retrieval, service installation, new scheduled tasks,
new GitHub identities, production mutation, trust-key replacement, canonical
tracked-file overlays, primary HEAD advance, arbitrary entrypoint selection,
rewriting other repositories, or reducing existing commands. Preserve unrelated
draft worktrees. Do not reuse an unfinished MCP partial-install draft or its
authority. A full install remains an alternative only after complete all-stage
inventory and exact operation review; it is not the current shortcut.

### 5. Current source state and evidence locations

Design baseline is fetched `origin/main` commit
`75ce91136037` (resolve the full SHA from Git before implementation). No partial
release mode exists there. `install.sh` owns Linux stages/lock/manifest/finalize.
`bin/install-ai-devops-windows.ps1` owns Windows source gate, skills and final
machine-tools call. `bin/install-machine-tools.ps1` owns complete-catalog
launcher receipts. `bin/ai-task-gates` owns `cmd_authorize_install`,
`cmd_install_verify`, `linux_manifest_receipt`, `toolkit_source_receipt`,
`windows_launcher_route`, `windows_managed_inventory` and stage validation.
`bin/ai-repo-identity` currently canonicalizes/validates repository URLs; extend
this existing home for partial receipt-aware primary identity.

`bin/ai-devops` resolves its source root and runs doctor/version/paths;
`update.sh` owns the full update operation. `bin/ai-test-local`
and other callers resolve siblings from source root. `bin/ai-blocker-watch`
stores its source absolute path in cron/Task Scheduler actions. Therefore
changing PATH alone does not migrate a schedule or hardcoded canonical caller.
The transitive source closure includes telemetry, status contexts, watchdog
code, policy/config and sibling commands, not only `bin/ai-gh`.

At drafting, #1401 and #1408 were undergoing coordinator review/checks; their
heads are not installation releases. Refresh their actual merged status and
the exact fetched release before authority. Preserve #914/#925/#868 accepted
proofs. #1008 closed code acceptance does not close fleet installation proof.
Raw host inventories, runtime identities and review receipts stay protected;
publish only sanitized acceptance evidence on the existing owning issues.

### 6. Findings and root cause

Full and partial installation are different claims. The Linux gate demands
one PASS for every required full stage; a selected command install cannot
forge that stage report or rewrite the full manifest SHA. Windows machine-tools
refuses a selected replacement catalog because it stamps a complete-source
receipt. A pending source gate is preparation, not completed deployment.

Caller roots also matter: an immutable release command may locate helpers and
policy in its payload, but commands performing Git work must keep the original
caller working directory. The existing `update.sh` must operate on the durable primary
checkout, not fetch/merge into immutable payload. `ai-task-gates` must identify
the caller Git repository and prove the partial gate override against the old
full receipt. A payload is never a substitute primary repository.

An old tracked executable invoked by absolute canonical path cannot discover
a resolver it does not contain. PATH cannot intercept it. Under the locked
no-overlay/no-HEAD-advance design, its invocation owner must be switched through
an explicitly inventoried supported pointer. Unknown/unmigratable direct paths
remain unaccepted; do not promise invisible universal interception.

### 7. Rejected approaches

- Full install with `--skip-secrets`: other broad writes and provider setup
  still execute; the current bounded inventory does not cover them.
- SourceGateOnly/LauncherGateOnly followed by invented full receipt or consumed
  full authority: original required stages and launchers are not proven.
- Root installation, masked token variables, fake credentials or changed state
  to suppress stages: alters capability or bypasses the intended gate.
- PATH-only migration: direct and scheduled source paths can keep old code.
- Overlay canonical tracked callers with shims: makes old Git HEAD lie about
  executable source and violates landing-only ownership.
- Hand-copy a guessed helper subset: dynamic sibling/import resolution loses
  original functions. Use complete tracked public source layout as inert payload.
- Reuse the preserved MCP draft: different scope, incomplete installer/tests,
  and no authority for GitHub receipts or caller coverage.

### 8. Locked design decisions and allowed judgment

Locked by coordinator on October 7, 2026: one fixed partial mode in existing
installers/gate; immutable complete public source without `.git` or private
submodule payload; unchanged canonical HEAD; separate old full/new partial
receipts; fixed source-verified catalog; protected receipt-aware resolver;
exact-operation/host-inventory one-use authority; only owned inventoried pointer
switches; refusal for unknown direct consumers; full-install reconciliation.
All original subcommands and stream/exit/working-directory semantics survive.

Linux payload root is `/var/lib/ai-devops/releases/github-request-reduction/<SHA>`
with root-owned non-writable ancestors/files (0755 directories/executables,
0644 public non-executables). Windows payload root is
`C:/ProgramData/ai-devops/releases/github-request-reduction/<SHA>`, writable only
by Administrators/SYSTEM and readable/executable by the inventoried runtime
principal. No symlinks, junctions, reparse ancestors, shared hardlinks or
runtime-writable parents. Establish ownership through supported installer
privilege; lack of authority is a platform blocker, never an ACL relaxation.

Allowed implementation judgment: code factoring inside existing homes and
platform atomic-copy APIs, provided named invariants/tests hold. Not open:
scope/receipt/source-root semantics. Outside consumer destination files are not
chosen here: the inventory protocol below supplies exact owned destinations,
which the coordinator/reviewer must approve before host mutation. An unsupported
consumer is a concrete blocker, not permission to broaden the allowlist.

### 9. Ordered implementation phases and interfaces

**Phase A — plan gate.** Reconcile upstream/owners and obtain assigned independent
read-only exact-plan APPROVE. Coordinator decides whether this specification
may execute. No code or installation before that decision. Verification:
plan review binds exact prose head and names no unresolved safety flaw.

**Phase B1 — fixed catalog and public payload.** Add
`config/github-toolkit-release.json` with schema 1, fixed scope, fixed public
source entrypoints, platform route types and `payload=tracked-public-tree`.
Do not accept a caller-provided catalog/root or arbitrary source path. Validate
the exact catalog against current managed transport source inventory and
`tools/ci/check-managed-github-transport.py` and its
`tests/test-workflow-policy.sh` regressions; stale/missing/additional network
consumer fails until the same owned code change explicitly reconciles it.

Fixed extensionless routes: `ai-gh`, `ai-gh-wait`, `ai-pr-wait`,
`ai-blocker-watch`, `ai-gh-app-auth`, `ai-workspace-status`, `ai-verify-run`,
`ai-test-local`, `ai-merge-group-evidence`, `ai-transcript-destination-check`,
`ai-memory-sync`, `ai-local-watch`, `ai-windows-queue-watch`,
`ai-runner-pool-watch`, `ai-reviewer-membership-drift`, `ai-merge-queue-drift`,
`ai-devops`, `ai-task-gates`. Matching existing tracked `.cmd` wrappers are
catalogued separately; generate both supported Windows launcher forms only
for an existing inventoried command route, using the established machine-tools
renderer. `ai-reviewer-membership-drift.cjs` is a payload dependency.

Fixed Windows source entrypoints: `runner-github-admission.ps1`,
`promote-windows-runner-to-service.ps1`, `qualify-windows-runner.ps1`,
`invoke-windows-runner-maintenance.ps1`, `windows-runner-maintenance-worker.ps1`.
No promotion/qualification/service change is performed during installation.
Inventory every action/pointer invoking them; existing maintenance scope,
fixed task/action, protected payload location and elevation remain unchanged.
Extend existing `bin/install-windows-runner-maintenance.ps1` with a guarded
protected-payload refresh stage under the same exact partial authority. Never
redirect its fixed scheduled action to the immutable release resolver. The
worker and qualification code may select GitHub helper source only through
the protected bounded active partial receipt and exact payload/catalog/host
hash binding. Keep durable primary Git identity and old full baseline separate
from selected partial helper source. Every existing runtime payload hash,
fixed-action, autoload and hostile-environment defense remains mandatory.
If this existing contract cannot bind both source namespaces without weakening
those defenses, stop and return exact evidence to the coordinator for a design
decision before source implementation. `ai-reviewer-start-watch` is not a current direct
managed-transport caller; preserve it and validate any selected sibling binding
discovered in inventory rather than silently migrating it.

Stage complete `git ls-tree -r` public blobs at exact fetched merged SHA, retaining
relative paths/executable modes. Gitlink entries are metadata only, no private
content; exclude `.git` internals and untracked material. Reject symlink blobs
and unsupported file modes before any switch. Required source/helper coverage
includes `tools/github-requests`, `tools/lib`, `tools/ci`, `tools/stuck-work`,
`config` and sibling commands such as `ai-process-supervisor`; complete tracked
layout avoids a guessed import closure. Stage under protected same-volume
exclusive temporary directory, hash every blob, verify permissions and rename
atomically. Existing SHA directory must match byte-for-byte or installation
refuses. Verification: `payload_exact_tree`, `payload_private_gitlink_excluded`,
`payload_mutable_ancestor_refused`, `catalog_current_callers_complete`.

**Phase B2 — shared receipt/identity/resolver.** Add
`tools/lib/github-toolkit-release.sh` for `read_partial_receipt`,
`verify_public_payload`, `verify_old_full_baseline`, `verify_route_inventory`,
`resolve_partial_entrypoint`, `stage_partial_routes`, `rollback_partial_routes`
and `reconcile_partial_release`. Platform receipt parsing/validation must be
shared through new `tools/lib/github-toolkit-release.py` operations
`validate-inventory`, `validate-authority`, `validate-receipt` and
`validate-payload-manifest`, not permissive shell eval. Each operation uses a
fixed schema and bounded protected file, emits sanitized status and rejects
duplicate keys, unknown schema fields and executable data.
Extend `bin/ai-repo-identity` with `installed-primary` and `partial-entrypoint`
operations using only fixed protected platform receipt locations. Update
`bin/ai-devops` source-root resolution to distinguish public payload from durable
primary identity; doctor uses installed routes without disabling checks, while
the existing `update.sh` finds the authenticated canonical primary and enters
its existing full update/install gate. Do not invent an `ai-devops update`
subcommand: preserve doctor/version/paths. Extend `update.sh` entry preflight
to call `installed-primary` and full partial-state reconciliation before any
fetch/source mutation. Update `bin/ai-task-gates` source-root/receipt resolution;
policy may come from the immutable payload, task identity/change classification
still comes from original caller Git cwd.

The partial receipt is machine-protected, schema 1, with: `scope`,
`transaction_id`, `host_identity_sha256`, `profile_identity_sha256`,
`runtime_inventory_sha256`, `primary_checkout`, `primary_origin_identity`,
`primary_head_unchanged`, `full_baseline_head`, `full_baseline_receipt_sha256`,
`full_gate_sha256`, `partial_head`, `payload_root`, `payload_manifest_sha256`,
`catalog_sha256`, `route_inventory_sha256`, `operation_review_sha256`,
`authorization_sha256`, `stage_report_sha256`, `state=active`, and exact route
records. Add `baseline_kind` with exactly `verified_current`, `stale_manifest`
or `verified_legacy_routes`, and a typed `baseline_evidence` object. A legacy
baseline records `full_receipt_absent=true` and null full-receipt/head/hash
fields, never invented full proof. Its proven clean primary source HEAD and
owned route/source hashes are separate evidence, not a full install receipt.
Route records contain fixed command ID, route kind, approved destination,
prior type/hash/absence/owner/ACL, new hash/target/owner/ACL and recoverable prior
backup reference. Schedules additionally bind action, cadence, principal,
trigger/settings and prior definition hash. Never credential values or raw
telemetry. Host names/routes stay in private inventory; public evidence uses
safe digests. Before every gate override prove protected partial authority,
catalog, payload/gate hash, recorded route and the untouched full baseline.
Never treat `partial_head` as a forged full source SHA. Fixed state home:
Linux `/var/lib/ai-devops/github-toolkit-release/state`, Windows
`C:/ProgramData/ai-devops/github-toolkit-release/state`. Store authority,
journal, active receipt, stage report and protected backups below that home;
the active receipt is `active.json`. Linux state is root-owned, 0750 directories
and 0640 records readable only by the approved runtime group; Windows ACL grants
Administrators/SYSTEM write and inventoried runtime identity read. No runtime
identity writes authority/journal/receipt. Issuance through supported installer
privilege preserves the assigned-review binding; inability to establish this
protection blocks installation. Input inventories/reports stay owner-only;
protected review/report hashes are frozen in authority before writes.

Managed resolver is generated by existing installer renderer into inventoried
owned route locations, preserving original arguments/stdin/stdout/stderr/exit
code and working directory. Ordinary hot command launchers compile the reviewed fixed
command ID and exact payload executable path at installation, not a
user-supplied command/root. They invoke that exact path without per-call Python
parsing or full-payload hashing. Complete tree/hash/ACL validation occurs during
authorization, staging and explicit live audit; protected root/Admin immutable
storage prevents runtime byte substitution. This optimization does not apply
to the privileged maintenance worker: retain all its required runtime payload
hash checks and source/hostile-environment verification. No PATH injection or environment
release override. Gate/doctor/update receipt-aware paths validate exact partial
override and primary identity using bounded schema and ownership checks, not
every hot GitHub call. Windows admission still resolves
the payload's reviewed `ai-gh` launch route in the same execution tree.
Verification: `resolver_original_streams_cwd`, `gate_partial_override_proven`,
`gate_caller_repository_preserved`, `doctor_update_primary_identity`.

**Phase B3 — one-use authority and inventory protocol.** Extend
`cmd_authorize_install` and `cmd_install_verify` in `bin/ai-task-gates` with
`--scope github-request-reduction` and explicit `--inventory <protected file>`;
no existing mode silently changes semantics. Add
`authorize_partial_install`, `verify_partial_install_phase` and
`consume_partial_install_authority` through the shared library. Extend
`tools/lib/review-operation.sh` and the existing review wrapper operation
allowlist for `github-request-reduction-partial-install`; exact-source assigned
operation APPROVE must contain
`Approved github-request-reduction-partial-install.` and wrapper-written exact
source/policy/catalog/inventory bindings. Source implementation is
`reviewer-safety`; per-host installation task is `installation`. Recheck gates
before paid review/ship/install. Baseline handling is explicit:

- `verified_current`: real full receipt verifies installed source/gate/routes;
  the partial operation header records receipt hash, full source SHA, live gate
  hash and clean primary HEAD.
- `stale_manifest`: a real Linux manifest is present and verified against its
  committed source, but source differs from clean live primary HEAD. Run the
  existing `stale-linux-manifest-recovery` exact-host wrapper operation, whose
  header binds stale manifest SHA/hash and live installed SHA/gate hash. Require
  `Approved stale-linux-manifest-recovery.` in that exact report, plus the new
  partial operation report at the same exact target source. Gate uses
  `--baseline-kind stale_manifest --baseline-review-report <report>`; it checks
  header hashes again on-host. It does not stamp a repaired full manifest.
- `verified_legacy_routes`: missing Windows source receipt is explicitly absent;
  each old managed launcher and source must match clean committed primary source
  and supported ownership/route shape. The new partial operation independently
  captures both launcher-form hashes, source hashes/ownership, missing-receipt
  state and clean primary HEAD in its wrapper-written header. It also requires
  the exact line `Approved verified-legacy-routes baseline.` in addition to
  `Approved github-request-reduction-partial-install.` at the same current
  target source. Gate uses `--baseline-kind verified_legacy_routes`; no legacy
  unchanged-main refresh operation is borrowed when inapplicable. Unknown or
  unproven owner/source/absence refuses authorization; absence is never proof.

Extend `bin/ai-review --operation github-request-reduction-partial-install`
with `--installation-inventory <protected file>` and
`--baseline-kind verified_current|stale_manifest|verified_legacy_routes`.
`tools/lib/review-operation.sh` reads fixed host receipt/launcher paths itself,
verifies the inventory against live host state and writes the header fields:
`partial scope`, `partial target SHA`, `catalog SHA256`, `inventory SHA256`,
`host identity SHA256`, `runtime inventory SHA256`, `baseline kind`,
`baseline receipt state`, `baseline receipt SHA256` (literal `absent` when
absent), `baseline source SHA` (literal `not-established` for missing full
proof), `clean primary HEAD`, `old launcher inventory SHA256`,
`old source inventory SHA256`, `ownership inventory SHA256` and, when relevant,
`stale recovery report SHA256`. Reject caller-supplied header text or invented
digest/absence. Report records the same fields; authority binds their hashes.
The ordinary operation approval never implies the additional legacy-baseline
approval line. A typed legacy baseline is an accepted owned source/route
starting point only; doctor continues reporting absent full installation state.

Inventory schema 1: fixed scope, exact host/profile/runtime identity, primary
origin/path/head and full receipt hash, optional prior active partial receipt
hash, exact source/catalog hash and every existing execution route. Discovery
reads command resolution, managed launchers/profiles, cron/Task Scheduler,
fixed Windows maintenance entry actions, and direct caller configurations.
Every route must be source-verified against a catalog command and its original
functions; ownership marker/installed receipt and recoverable backup must be
proven. A source path found only by text search is a candidate, not a write
target. The inventory lists unowned/unknown/direct-unmigratable consumers;
any required one blocks host acceptance. No choosing arbitrary external files
from this document. Validate schema, owner-only permissions, no symlink/reparse,
bounded paths/records, duplicate aliases, escaping/control characters and
current on-host identity/hash before authorization and again before writes.

Authority schema 1 binds the receipt fields above plus prior active partial
hash/absence, exact fetched `origin/main`, reviewer report+operation+head hashes,
candidate Git common-dir identity, fixed destination inventory and
`state=issued`. Store under protected scope-specific authority directory keyed
by transaction ID, not the full installer authority path. No credential
substitution. Verification: `authority_exact_operation_inventory`,
`authority_changed_host_runtime_refused`, `authority_replay_refused`.

**Phase C1 — existing installer partial branches.** Extend `install.sh` and
`bin/install-ai-devops-windows.ps1` with fixed `--scope github-request-reduction`
and Windows `-Scope github-request-reduction`, plus reviewed inventory input.
Branch after supported source/authority validation and installation lock,
before any full-stage machine/user writes. Do not clone/advance primary HEAD.
Both new full and partial installer paths, source/launcher-only modes,
`update.sh` and direct machine-tools entrypoints acquire the same machine
installation lock before any installed route or installation-state writes.
Linux fixed lock is `/var/lock/ai-devops-toolkit-install.lock`, protected against
replacement; Windows uses existing `Global\AiDevOpsToolkitInstall` mutex.
Retain existing checkout lock and maintenance locks as additional guards,
with acquisition order machine -> checkout -> maintenance. An updater may pass
owned Linux machine/check-out descriptors to its direct child only after exact
descriptor-path/parent checks; no environment flag alone proves ownership.
Supported re-entry is only the same transaction. Old unpatched or foreign
installers do not automatically participate. Preflight checks all inventoried
owned old-checkout locks and known installation runtime activity/pending
journals; a held lock, active old runtime or unresolved prior pending install
refuses before mutation. Unknown installer ownership or unverifiable activity
blocks, rather than claiming global exclusion. Reuse
`bin/install-machine-tools.ps1` renderer via
an explicit guarded internal partial route branch, not a caller-defined
CatalogPath bypass. Full canonical catalog validation remains unchanged for
ordinary mode. Pass exact reviewed head and protected authority; no broad
bootstrap/install command used to establish runtime prerequisites.

Switch only inventoried existing managed launchers/profile bindings and actions.
Schedule allowlist: existing managed BlockerWatch tick; existing managed
ai-local-watch tick-all when present. Windows maintenance is inventoried and
verified but its fixed task/action is not switched or relocated. Refresh only
its existing protected ProgramFiles payload through the supported maintenance
installer stage under exact partial authority; retain original fixed action,
principal, S4U/Highest boundaries, protected ownership/ACL and runtime hashes.
No new
schedule; preserve cadence, principal, conditions, existing App identity,
state/log paths, alarm/link/tick/queue semantics. A managed direct canonical
consumer must have its owned invocation pointer switched to resolver; an old
canonical script cannot be intercepted. Unowned/unsupported consumer stops
before mutation and remains a named #658 blocker. No canonical source overlay,
Git HEAD change or arbitrary external source edit.

Transaction states: issued -> reserved (lock + baseline proven) -> staged
(payload/backup hashes proven) -> switched (owned routes proven) -> verified
(required partial stage receipts passed) -> active/consumed (receipt published,
authority consumed once). Keep a protected journal recording identities and
each mutation. Recheck predecessor identity and hash before each write;
concurrent difference refuses, never overwrites. Interrupted staging may retry
against exact pinned inputs; interrupted switching must restore old complete
routes or finish the same transaction after validating every journal record.
Rollback checks the current target still equals this transaction's own output
before restoring backups/ACLs/schedule definitions. Changed target blocks safe
rollback and assigns coordinator repair; never destroy someone else's update.
Failure retains pending authority. Completion retry validates active receipt
and consumes no new write. Record separate partial stage report; never forge
Linux full required stages/manifest or Windows complete-source launcher receipt.
The partial stage report has a fixed required-stage list, each recorded once
as PASS with exact transaction/input/output receipt hashes:
`public-source-tree-and-immutable-ownership`, `old-full-baseline-and-partial-gate-override`,
`owned-command-and-direct-consumer-route-hashes`,
`owned-schedule-definition-and-semantics-hashes`,
`original-github-caller-capabilities`, `reviewer-door-requalification`,
and `paired-route-performance`. Active receipt publication is the finalization
output after those seven required stages, not a stage whose receipt hash would
circularly include its own stage-report hash. Finalization binds the complete
stage-report hash and publishes the active receipt before consuming authority.
An absent schedule
is a verified inventoried absence within its required stage, not an omitted
stage. Original caller stage exercises installed success/failure/pagination
and relevant elevated Windows transport/wake/alarm/link/queue functions.
Reviewer-door stage invokes the existing supported
`bin/ai-review-preflight requalify` for affected gate/routing and proves actual
reviewer-door acceptance, preserving every provider/safety check. Do not stamp
PASS from source hashes alone, suppress qualification or substitute a full-stage
report. Credentials remain serialized through protected existing consumers.
If requalification requires unbounded unrelated installation stages, stop that
host and assign coordinator recovery; never expand scope or disable the check.
Verification: `partial_no_unrelated_writes`, `partial_retry_exact_transaction`,
`partial_rollback_concurrent_change_refused`, `schedule_semantics_preserved`,
`partial_required_stages_and_reviewer_door`,
`maintenance_partial_authority_both_namespaces`,
`maintenance_tampered_partial_receipt_refused`.

**Phase C2 — full consolidation.** Before existing full installers/updater run,
`reconcile_partial_release` proves old full baseline, active partial payload,
all recorded routes and pending transaction state. A subsequent partial release
also validates predecessor receipt and uses a new exact one-use authority.
Full update authority includes active partial inventory/receipt in its exact
review; normal full stages remain required. Only after full stages and normal
receipts succeed may recorded owned partial routes move back to canonical
source, then archive partial receipt as retired with consolidation source SHA.
On failure retain/restore coherent partial routing and pending full authority;
do not leave mixed unrecorded routes. Payload retirement is separate recoverable
cleanup after no active receipt/consumer references it, not installation deletion.
Verification: `full_reconcile_partial_routes`, `full_failure_keeps_partial_live`,
`next_partial_requires_predecessor_binding`.

**Phase C3 — faulty active release recovery.** Interrupted pre-activation
rollback may use the still-pending installation transaction, as above.
After activation its authority is consumed: recovery requires a separate NEW
one-use authority and exact operation review, never replay of that authority.
Add `github-request-reduction-partial-rollback` to the same review-operation
home, requiring `Approved github-request-reduction-partial-rollback.`.
Review CLI is `bin/ai-review --operation github-request-reduction-partial-rollback
--installation-inventory <protected file>`; wrapper independently reads the
fixed active receipt/journal/backup records and current host/route state.
Header additionally records `active partial receipt SHA256`,
`active transaction ID`, `current route inventory SHA256`,
`retained backup inventory SHA256`, `previous receipt state`,
`previous receipt SHA256` (literal `absent` if verified predecessor had none)
and `rollback target route inventory SHA256`, alongside host/runtime/catalog
and typed baseline fields. This rollback may restore the verified previous
owned full/legacy/partial route state, never invent a previous full receipt.

Authorization CLI: `ai-task-gates authorize-install
--scope github-request-reduction --rollback --inventory <protected file>
--review-report <exact rollback APPROVE> --reviewer-approval <same report>`.
Rollback authority schema 1 adds `operation=partial-rollback`, new transaction
ID, `active_receipt_sha256`, `active_transaction_id`, current route/host/runtime
hashes, retained backup hashes/ownership, previous receipt state/hash and exact
target route inventory hash. It is stored separately from consumed install
authority. Installer CLI uses `--scope github-request-reduction --rollback
--authorization-id <new transaction ID>` (PowerShell `-Scope
github-request-reduction -Rollback -AuthorizationId <ID>`); no arbitrary backup
path or action argument is accepted. Installation scope interface otherwise
uses `--inventory <protected file> --authorization-id <ID>` (Windows
`-InstallationInventory <file> -AuthorizationId <ID>`). The scope's verifier
adds phases `rollback-preflight`, `rollback-staged`, `rollback-restored`,
`rollback-verified` and `rollback-finalize` bound to that exact authority.

State transitions: active -> fault-recorded (keep active receipt and exact
observed failure) -> rollback-issued -> rollback-reserved -> rollback-staged
-> predecessor-restored -> rollback-verified -> rollback-consumed/retired.
Hold the same machine/check-out/maintenance locks. Revalidate current outputs
and retained backups before each restore. All routes, maintenance protected
payload and schedule definitions must return coherently to the recorded
predecessor, with its original capabilities verified before rollback authority
is consumed. If current receipt, route, protected payload/ACL or backup differs
from authorized observed state, refuse destructive restoration and use newly
reviewed forward repair; never overwrite another actor's change. A tampered
receipt cannot authorize its own repair: compare to protected journal and
retained issued authority; mismatch stops automatic recovery and assigns
coordinator diagnosis. Preserve the fault and recovery history. Successful
rollback marks the faulty receipt retired and reactivates the exact prior
partial receipt or verified original routes; full receipt is never forged.
Verification: `active_fault_new_rollback_authority`,
`active_rollback_install_authority_replay_refused`,
`active_rollback_tampered_receipt_or_backup_refused`,
`active_rollback_restores_coherent_predecessor`,
`active_rollback_concurrent_mutation_refused`.

**Phase C4 — deactivation and uninstall lifecycle.** Extend the existing
`uninstall.sh`, not a new generic uninstaller. Add fixed
`--scope github-request-reduction --deactivate-partial
--authorization-id <ID>` for recoverable partial deactivation. Native Windows
has no corresponding full uninstaller: extend only existing
`bin/install-ai-devops-windows.ps1 -Scope github-request-reduction
-RemovePartialScope -AuthorizationId <ID>` for that fixed scope. This removes
the selected partial state by safely restoring its verified predecessor
routes; it does not remove services or fixed maintenance tasks. Do not add an
arbitrary removal path, operation, service/task selector or payload root.

Require new exact review operation `github-request-reduction-partial-uninstall`
and line `Approved github-request-reduction-partial-uninstall.`. Review uses
`bin/ai-review --operation github-request-reduction-partial-uninstall
--installation-inventory <protected file>`; wrapper independently binds active
partial receipt/transaction, current host/runtime/routes/ACLs/schedule definitions,
retained predecessor backups and all current payload references. Add wrapper
header `uninstall intent` (`deactivate-partial` or Linux `full-uninstall`),
`current payload reference inventory SHA256` and `safe predecessor inventory
SHA256`, alongside the rollback lifecycle's exact header fields. Authorize via
`ai-task-gates authorize-install --scope github-request-reduction --uninstall
--uninstall-intent deactivate-partial|full-uninstall --inventory <protected file>
--review-report <exact uninstall APPROVE> --reviewer-approval <same report>`.
Authority schema 1 sets `operation=partial-uninstall`, new one-use transaction
ID, intent, exact source/review/host/runtime hashes, active receipt/route hashes,
reference inventory hash, predecessor safety hash and protected backup hashes.
Consumed install/rollback authority cannot authorize removal. Existing Linux
`--full` must accept `--partial-authorization-id <ID>` when active partial state
exists; absence or wrong full-uninstall intent refuses before destructive work.
Ordinary uninstall modes also detect active partial routes rather than silently
classify them as harmless full-manifest drift.

Acquire the same protected machine lock before route/state writes, retain
checkout/maintenance locks and pending-old-runtime preflight. Back up exact
owned destinations/state first; verify active receipt, current route hashes,
ACLs, backups and references again before every mutation. States: active ->
uninstall-issued -> uninstall-reserved -> uninstall-backed-up ->
predecessor-restored (deactivation) or owned-partial-routes-removed (Linux full
uninstall) -> uninstall-verified -> uninstall-consumed/retired. Interruptions
retain pending uninstall authority/journal; exact retry proves completed steps,
never replays consumed authority or destroys another actor's change.

Partial deactivation defaults to restoring only verified safe previous owned
routes, schedule definitions and protected maintenance payload. Verify original
capabilities before consuming authority. If old source is unsafe, security
state cannot be preserved, a route/receipt has drifted or a predecessor backup
is unproven, stop deactivation and use new reviewed forward repair. Preserve
the active route and report INCOMPLETE; never restore known unsafe security
source just to finish removal. Full Linux uninstall includes owned active
partial command routes, owned schedule pointers/definitions and receipt/payload
references in its recoverable preview/backup/removal contract. Preserve foreign
or drifted routes and report nonzero INCOMPLETE, with exact remaining references,
not completion. No removal of Windows service/fixed maintenance task or action
outside existing allowlisted ownership contract is introduced.

Never delete immutable payload while any recorded or newly observed consumer
still references it, or when reference ownership/completeness is unknown.
Archive/retire a no-longer-active receipt, keep recoverable backup history and
record retained payload as retained when references remain. Payload cleanup is
allowed only after exact reviewed absence of references and recoverable archive;
otherwise report INCOMPLETE and coordinator-owned repair. Gate phases are
`uninstall-preflight`, `uninstall-backed-up`, `uninstall-mutated`,
`uninstall-verified`, `uninstall-finalize`, each bound to its exact new authority.
Verification: `partial_uninstall_new_authority_required`,
`partial_deactivate_restores_safe_predecessor`,
`partial_deactivate_unsafe_predecessor_forward_repair`,
`partial_uninstall_interrupt_retry`, `partial_uninstall_replay_refused`,
`partial_uninstall_tamper_refused`, `full_uninstall_active_partial_owned_routes`,
`full_uninstall_foreign_or_drifted_incomplete`,
`partial_payload_referenced_retained`.

**Phase D/E — reviewed landing and one host outcome.** Focused tests, native
platform proof, exact-head assigned independent review, normal required CI and
merge queue precede installation. Confirm exact fetched merged source and
on-host collision status. Obtain fresh per-host inventory/operation review and
authority. Install serially on that host, prove original functions and record
sanitized receipt/capability acceptance on the same owning #658/#660/#931/#933
issues. Repeat only for next independently inventoried host. No duplicate
accepted #914/#925/#868 proofs. P1/P8 measured savings remain separate gates.

Before that landing, update the canonical instructions in `docs/deployment.md`
with fixed Linux/Windows scope interfaces, exact operation review/inventory,
separate partial/full state, one-use authority, retry/rollback and full-install
reconciliation, fixed deactivation/uninstall interfaces and INCOMPLETE semantics.
Update `docs/independent-windows-runner-setup.md` maintenance
contract with the supported protected-payload refresh interface, retained
fixed task/action/runtime defenses and exact old-primary/new-helper namespace
binding. These are implementation steps, not current host permissions. Gate:
`documentation_partial_interfaces_match_source` verifies documented fixed
interfaces against actual CLI/source, and both public-boundary/Markdown-link
checks pass. Do not write misleading install instructions before source exists.

Trust-boundary adversarial matrix:

| External input | Hostile case | Named regression |
|---|---|---|
| Fetched source/review | Moved head, wrong operation, stale report | `authority_exact_operation_inventory` |
| Host/profile/runtime | Different host, interpreter, user or prior receipt | `authority_changed_host_runtime_refused` |
| Catalog | Extra/missing caller or arbitrary executable/root | `catalog_current_callers_complete` |
| Payload tree | Private gitlink, symlink, mutable parent, wrong blob | `payload_exact_tree`, `payload_private_gitlink_excluded`, `payload_mutable_ancestor_refused` |
| Inventory | Duplicate/escaping/control path, extra unowned destination | `inventory_unowned_duplicate_escape_refused` |
| Partial receipt/gate | Forged full SHA, mismatched override, altered gate | `gate_partial_override_proven` |
| Partial stage receipt | Missing/duplicate PASS, forged reviewer-door success | `partial_required_stages_and_reviewer_door` |
| Hot route | Per-call tree hash/parser or unacceptable added latency | `hot_route_no_fulltree_parser`, `paired_route_performance` |
| Caller context | Wrong repository cwd, immutable update target | `gate_caller_repository_preserved`, `doctor_update_primary_identity` |
| Direct consumer | Hardcoded unrouteable canonical invocation | `direct_canonical_unmigratable_refused` |
| Authority/journal | Replay, concurrent installer, interrupted step | `authority_replay_refused`, `partial_retry_exact_transaction` |
| Machine installation | Full/partial installs from different clones, old pending runtime | `different_clone_full_partial_race_refused`, `old_pending_install_preflight_refused` |
| Typed baseline | Missing receipt presented as verified full state, unknown old owner | `typed_legacy_baseline_no_forged_fullproof`, `legacy_wrapper_header_source_owner_bound` |
| Active rollback | Consumed install authority, tampered receipt/backup, mixed restoration | `active_fault_new_rollback_authority`, `active_rollback_install_authority_replay_refused`, `active_rollback_restores_coherent_predecessor` |
| Uninstall | Consumed authority, interrupted/tampered state, foreign active route | `partial_uninstall_replay_refused`, `partial_uninstall_interrupt_retry`, `partial_uninstall_tamper_refused`, `full_uninstall_foreign_or_drifted_incomplete` |
| Predecessor/payload removal | Unsafe old source or referenced payload deletion | `partial_deactivate_unsafe_predecessor_forward_repair`, `partial_payload_referenced_retained` |
| Owned route/rollback | Another actor changed destination or ACL | `partial_rollback_concurrent_change_refused` |
| Schedule | Different principal/cadence/action or foreign task | `schedule_semantics_preserved` |
| Privileged maintenance | Redirected fixed action, skipped runtime hashes, hostile autoload/env | Existing `tests/test-windows-runner-maintenance.ps1` regressions |
| Maintenance authority | Wrong primary/helper namespace or tampered partial receipt | `maintenance_partial_authority_both_namespaces`, `maintenance_tampered_partial_receipt_refused` |
| Full successor | Changed partial receipt or failed full stage | `full_reconcile_partial_routes`, `full_failure_keeps_partial_live` |

### 10. Required tests and evidence

Add `tests/test-github-toolkit-release.sh` and
`tests/test-github-toolkit-release.ps1` with every named case above plus
`resolver_original_streams_cwd`, `partial_no_unrelated_writes` and
`next_partial_requires_predecessor_binding`,
`partial_required_stages_and_reviewer_door`, `hot_route_no_fulltree_parser`
and `paired_route_performance`. Performance proof requires at least twenty
paired original-route versus partial-route observations for the same useful
work, alternating order and holding host/runtime/principal/workload constant.
Include routing, counter and metadata overhead in measured end-to-end latency;
do not time only the downstream GitHub subprocess. Report sample count,
distributions and p95 useful-work latency with receipt/source identity. Partial
p95 may increase by at most 5%; deadlines must remain unchanged. Failure
requires implementation repair and fresh failed/changed measurement, never a
weaker threshold, deadline extension or omitted overhead. Use deterministic
supported transport fixtures for offline timing and matched bounded live work
for installed acceptance, preserving network/request-cost classification.
Register their exact platform
manifests under `config/ci-suites/` and select them through existing test loader;
do not invent a second harness. Disposable fixtures must stay outside canonical
repositories and reject production-looking test origins. Native Windows tests
exercise PowerShell 5.1, Git Bash launchers, spaces in paths, ACL/reparse and
scheduled-action comparisons without creating real service/tasks.

Retain `tests/test-ai-task-gates.sh`,
`tests/test-ai-task-gates-linux-install.sh`,
`tests/test-linux-install-authorization.sh`,
`tests/test-install-ai-devops-windows.ps1`, `tests/test-ai-machine-tools.sh`,
`tests/test-ubuntu-install-stages.sh`, `tests/test-ai-install-manifest.sh`,
`tests/test-ai-devops-doctor-install-state.sh`, managed transport regressions
in `tests/test-workflow-policy.sh`, `test-ai-gh.sh`, BlockerWatch/waiter/queue tests,
repo identity, public boundary, Markdown links and suite-loader checks. Resolve
exact existing installation test names through `rg --files tests` at execution;
do not guess that an unrun file passed. Full platform suites required by CI stay
intact. Do not verify the same unchanged commit twice; repeat failed/changed
tests only. Before a Windows local suite use collision check on the same host.
Record actual receipt paths, source hashes/head, runtime and exit/result;
candidate receipts are not installed acceptance.
`tests/test-windows-runner-maintenance.ps1` is mandatory: run all its existing
native fixed-action, payload-hash, autoload, hostile-environment, ACL and
protected-source regressions unchanged. Extend that same suite with
`maintenance_partial_authority_both_namespaces` and
`maintenance_tampered_partial_receipt_refused`, proving primary/full baseline
and selected helper release are bound independently and tampering fails before
helper execution. Add `maintenance_fixed_action_payload_unchanged`,
`maintenance_runtime_hash_checks_retained` and
`maintenance_unbound_helper_source_refused`; never skip existing assertions
to accommodate the partial route. Performance sampling distinguishes ordinary
hot launchers from privileged maintenance: required runtime hashes remain
included in the latter's original versus partial end-to-end measurements.
Add Linux and native Windows cases `different_clone_full_partial_race_refused`,
`old_pending_install_preflight_refused`,
`typed_legacy_baseline_no_forged_fullproof`,
`legacy_wrapper_header_source_owner_bound` and every active rollback case in
Phase C3. Exercise full/full and full/partial routes, updater/direct installer,
source/launcher-only entry modes, exact same-transaction child re-entry and
foreign/unpatched runtime refusal. Missing/legacy/stale fixtures prove exact
header/operation/approval-line semantics, with no full receipt fabricated.
Active-fault fixtures cover all lifecycle boundaries, restored original
capabilities, authority replay, current-route changes and protected backup/
receipt tampering; rollback failure must retain a named safe forward-repair path.
Extend existing `tests/test-uninstall.sh` with every Linux lifecycle case in
Phase C4, preserving its current recoverable full/minimal/purge/preview tests.
Add the native partial-deactivation/removal cases to
`tests/test-github-toolkit-release.ps1` and supported maintenance fixtures;
prove fixed `-RemovePartialScope`, no extra service/task removal, exact fresh
uninstall authority, safe predecessor restoration and original capability,
interruptions/replays/tampering, referenced-payload retention and nonzero
INCOMPLETE for drift/foreign references. No success message may hide active
owned partial routes that the requested full uninstall failed to account for.
Actual public-boundary command is `bash tests/test-public-boundary.sh`; retain
its real passing receipt/source identity. A wrong reviewer packet filename is
an evidence defect, not a claimed scanner/source fix. Markdown suite requires
the supported Python interpreter on PATH; failed/missing-command output cannot
be relabeled PASS.

### 11. Constraints and operational traps

Use dedicated current-upstream worktrees, scoped staging, Albert's verified
Git identity, `bin/ai-gh` for every GitHub call, signed public comments, normal
merge queue and bounded event-aware waits. Coordinator serializes reviewers,
merge/security decisions, credentials and each host installation. Protected
production actions remain separately gated. Private inventories, routes and
raw telemetry stay out of this public repository. No secret reads needed for
source implementation/tests; installed proofs use original authenticated
routes, not substituted credentials. Preserve provider/SSH/wake capabilities.

State directory and release roots must be protected against the executing
runtime user, not merely chmodded within a user-writable parent. No unsafe
symbolic-link traversal or hardlink reuse. A proven typed baseline is mandatory:
real verified current receipt, reviewed stale Linux manifest, or independently
reviewed verified legacy routes. Receipt absence is never full-install proof;
unknown owner/source state refuses. Exact flags/header/approval lines are in B3.
Source-linked helper resolution, caller Git cwd and durable primary identity
are three distinct roots. Never infer them from the current executable's dirname
alone after partial installation. Keep full-stage authority semantics unchanged.

### 12. Access and environment

Source work needs Git, Bash, Python, Node and the existing test runner; native
Windows fixtures require supported authenticated host access and Git Bash plus
PowerShell. Current authenticated access and collision status are moving facts
to establish read-only on each host. Protected host/profile inventory is
resolved through the existing private configuration route; no public hostname,
IP, token, username or raw task definition belongs in evidence here. Credentials
remain in the `vibe_coding` 1Password vault via existing supported consumers;
this mode does not retrieve/install them. Lack of existing runtime or privilege
stops that host with exact evidence and coordinator ownership.

### 13. Definition of done, risks and self-audit

- [ ] Exact-plan independent APPROVE and coordinator implementation decision.
- [ ] Fixed catalog, authority/receipt/resolver semantics and adversarial tests
  implemented; existing full gates and original capabilities preserved.
- [ ] Required tests/CI and independent exact-head review pass; owned source
  committed/pushed, merged normally and verified on fetched `origin/main`.
- [ ] Each accepted host has exact inventory/operation authority, separate
  partial receipt, unchanged primary HEAD/full receipt, installed path/hash
  proof, original success/failure/pagination/wake/alarm/link/queue/elevated
  capability evidence, and issue checklist updated with no unowned gap.
- [ ] P7 fleet coverage and P1/P8 measured acceptance are complete before #658
  closes; full install consolidation path is tested, not deferred invention.
- [ ] Partial deactivation and full uninstall lifecycle are exact-authority,
  recoverable and tested; unsafe/foreign/drifted/referenced remnants report
  INCOMPLETE with coordinator ownership instead of hidden completion.

Risks: route inventory can miss hardcoded callers, immutable runtime ACLs can
require unavailable supported elevation, mutable host/source facts invalidate
authority, and interrupted changes can create mixed routes. Named refusal,
transaction and rollback cases above are mandatory. Unknown/unrouteable
consumer or unsupported privilege blocks that specific host outcome under #658;
the coordinator owns recovery. No business choice is needed for this source
repair. Technical plan/review objections must be repaired before implementation,
not forwarded to Albert as an approval request.

Self-audit: (1) A fresh session has the goal/context in §§1–6, locked boundary
in §§7–8, concrete files/interfaces/schemas/transitions/gates in §9, tests and
access in §§10–12, and completion/rollback criteria here. (2) Rejected shortcuts,
the direct-canonical limitation, gate override and primary-root distinction are
explicit in §§6–9; no planning-chat dependency remains. (3) §1 makes preserved
functionality the governing goal, with exact refusal and same-issue ownership
when a step cannot achieve it. All thirteen sections and named adversarial
cases are present. This is an addition to the registered existing plan, so its
existing STATUS/router/historical handoff links satisfy discovery; coordinator
explicitly excludes a new root plan or handoff. Self-audit passed for design;
implementation and installed acceptance are not claimed.
