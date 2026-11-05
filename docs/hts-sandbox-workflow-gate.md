# Reviewed HTS sandbox application workflow

## Current status

The two version-1 issue94 declarations remain unchanged. Version 2 adds a
strict, source-pinned and expiring synthetic acceptance declaration under
ai-devops #2395. Ubuntu is the reported failure platform; the validator uses
portable Python and the existing Bash admission path on Ubuntu and Windows.
Source tests, merge, protected installation and installed pass/fail admission
are separate deliverables; no application writes are admitted by preparation.

## Bounded synthetic acceptance declaration

Use `schema_version: 2`, the same canonical repository, API origin, project,
region, service and forbidden-action list as the legacy target, and
`scope: hts-bounded-synthetic-acceptance`. The issue must belong to that
repository. The complete route vocabulary is fixed in `ACCEPTANCE_ROUTES`;
callers cannot add, remove or substitute routes. The exact `ACCEPTANCE_LIMITS`
allow two synthetic saved fixtures, one optional synthetic container, at most
three provider turns per fixture and $10 in total. Messages and classification
Apply remain forbidden, and existing real records are read-only.

The declaration additionally requires a 40-character lowercase `source_head`
that is an ancestor of its current checkout, an `expires_at` UTC timestamp in
the next 24 hours, and an `AI-QA-YYYYMMDD-purpose-` fixture prefix. Git routing
environment overrides and replacement objects cannot redirect the ancestry
check. Strict types, complete keys, duplicate-key refusal and symlink refusal
apply to this profile too. The shell still requires the manifest at its exact
canonical path, clean and committed, and binds its blob to the admission receipt.

This is a declaration and receipt, not an executor or credential: the caller
must verify the deployed source and target before execution, check every write
against its synthetic prefix and retain identifiers, before/after evidence,
actual provider spending and cleanup. An uncertain HTTP outcome is read back
before any retry. No database, cloud, credential, production, real-record
mutation, classification Apply, merge or message authority is added.

Codex owns implementation and verification on #2395. Reuse this versioned
validator for later bounded acceptance rather than adding per-case bypasses;
retire expired consumer declarations after their acceptance work ends.

Current admission requires reviewer-safety or ui-live-workflow classification;
AI review is advisory and never grants or blocks this action. The older review
requirements below are historical and are superseded by owner ruling #2041.

## Single synthetic legacy-provider proof

Version 3 uses `scope: hts-bounded-synthetic-legacy-proof` with the same
source, expiry, prefix, target identity and forbidden actions. Its exact
`LEGACY_PROOF_ROUTES` adds only the dedicated HTS legacy POST alongside bounded
read-only checks. It cannot create records or containers, mutate existing
fixtures, call generic chat or shadow classification, or change queue settings.
The two-fixture, one-container and three-total-provider-turn boundaries remain.

`LEGACY_PROOF_BOUNDS` fixes one call, 512 output tokens, $0.10 maximum, no
automatic retry, the approved pinned Luna model through OpenRouter, and verified
positive credit from the actual sandbox binding. `description_prefix` must
exactly equal the declared synthetic fixture prefix. The executor must validate
that prefix on the actual request, verify immutable deployed policy and runtime
configuration, count earlier calls, and write its one-use marker before POST.
Unknown outcomes are observed without reposting. Meter actual cost afterward;
this admission is not a provider response or a spending guarantee.

Codex owns source tests, ordinary delivery, protected Ubuntu and Windows
installation, and installed positive/refusal/restored proofs on #2395. The
application's owning issue retains its separate paid-call authorization and
live result; preparation never counts as that result. Versions 1 and 2 remain
unchanged.

## Version 4: one request with an explicit internal-call envelope

Version 4 uses `hts-bounded-synthetic-legacy-envelope-proof`; versions 1–3
remain unchanged. It retains the exact legacy-proof routes, synthetic prefix,
source ancestry, expiry, target and forbidden actions. It admits one HTTP POST
with the approved pinned Luna/OpenRouter policy and at most nine internal Luna
API invocations, including the existing challenger and validation/follow-up
calls. Main output is capped at 4096 tokens with high reasoning unchanged.
Separate paid phrase/evidence requests, HTTP/provider retries and billable tools
are forbidden. It does not disable any validation or challenger to fit a test.

`prior_usage` contains `provider_calls` (a nonnegative integer),
`actual_cost_usd` (a finite nonnegative number), `snapshot_sha256` and the exact
source `session-provider-usage-verified`. The private executor must verify that
snapshot against all earlier actual session calls/spend, including any earlier
proof or evaluation. Both aggregate call limits equal that prior count plus
nine. The cumulative cost cap remains $10; prior actual cost plus the fixed
$3.23 conservative request risk must fit that cap before admission.

The request envelope pins the verified model catalog bounds of 1,050,000
context tokens and 128,000 maximum completion tokens. Using the highest approved
input rate ($0.25 per million, including cache writes) and completion rate
($0.75 per million), nine full catalog envelopes cost at most $3.2265, rounded
up to $3.23. This conservative admission calculation is not a provider-side
spend limiter. The source has no automatic provider retry or billable-tool path.

This remains a declaration/receipt, not a transport interceptor. The executor
must verify the exact deployed call graph and actual catalog/rates, preserve a
one-use marker before its one POST, and observe an unknown outcome without
reposting. Actual calls/spend are reconciled afterward. A changed call graph,
provider/model, catalog limit, retry behavior or pricing requires a new reviewed
profile rather than silently reusing this envelope. Source tests and normal
delivery are separate from protected two-OS installation and live admission.

## Historical implementation and verification record

Owner: Codex; application outcome: DesignFlow backend issue #94. Central safety
delivery belongs to ai-devops #335. PR171 integration remains Uma's responsibility.

The database gate correctly refuses SQL and shared structural work from a source
safety task. Ordinary authenticated application learning needs its own route.
Do not remove any existing forbidden action or relabel the task to evade it.

Implement one `application-workflow` action with a mandatory committed
`.ai-devops/application-workflow-target.json`, canonical backend origin, effective
reviewer-safety or ui-live-workflow class, and an independent exact-head final-check
or security-review APPROVE. The central target fixes the Alsand sandbox service,
API origin, issue94 and the ordinary CROSS evidence, precheck, shadow classification,
inquiry-history and inquiry-answer routes. The committed declaration permits only
non-operative shadow writes, paid provider calls, learning and replay/retrieval/visual acceptance.
Admin-only cross-user debate verification remains a separately credentialed, read-only
acceptance step; this ordinary workflow declaration does not admit it or grant admin authority. No SQL, schema,
cloud mutation, worker flag change, manual promotion, RFQ Apply/Save, production
cutover or DesignFlow merge is admitted. Read-only target identity proof is still
required immediately before execution; the gate is an admission receipt, not an
HTTP proxy or an execution sandbox.

Verification: preserve all existing task-gate tests; add adversarial cases for
wrong origin/target/class, missing or dirty/symlinked/duplicate manifest, stale or
non-independent review, missing declaration, and failed receipt persistence.
Run schema validation and Bash syntax checks. Obtain independent exact-head review,
merge through normal queue, install through the existing reviewed Linux route and
prove the installed command accepts only the declared sandbox workflow. Then refresh
the live backend source, review its exact workflow declaration and execute the
genuine HTS case. Preserve every previous proof and refusal.

## Frozen R9 diagnostic declaration

Version 5, `hts-frozen-r9-diagnostic-evaluation`, is separate from synthetic
acceptance and does not create fixtures. It fixes the existing 83-item frozen
membership hash, the authenticated Alsand sandbox and issue #278. Only
`POST /api/hts-rag/jobs` and `GET /api/hts-rag/jobs/:id` are admitted. There are
zero owner answers, one in-flight inquiry and one common-ledger run; resume
observes existing jobs and never repeats an ambiguous submission. No master-data,
item-fact, RFQ, Apply/Save, SQL, schema, learning or provider-policy changes follow.

The committed declaration binds private input, readiness, qualification, prior
spend, provenance, exact runner, catalog and pricing SHA-256 receipts. It binds
the immutable served source and revision separately from `source_head`, whose
existing meaning remains an ancestor of the committed declaration. The executor
must verify the files, installed gate receipt, eligibility and immutable ledger
before opening the cohort; this validator only checks the closed declaration,
not private evidence or actual execution. Do not run until that executor support
and the coordinator's readiness decision are verified.
Only v5 permits an initial expiry up to 72 hours to accommodate serial queue attempts;
profiles 1–4 keep their 24-hour metadata rule. The claimed manifest is immutable:
expiry stops the run without a new claim or silent renewal. Classification time
must be proved at most 170,000 ms on the actual immutable runtime, with the fixed
three-attempt/two-record-answer source bounds.

The preserved queue can create two record answers and attempt each of three jobs
three times. At eleven internal Luna calls per attempt, its conservative bound is
99 calls per inquiry and 8,217 for 83 inquiries, plus verified prior session calls.
Provider HTTP retry and billable tools remain absent. Catalog bounds are
1,050,000 context and 128,000 completion tokens; maximum approved input/output
rates are $0.00000025/$0.00000075 per token. One inquiry's conservative risk is
$35.4915. The coordinator explicitly authorizes up to $45.50 session exposure:
the $10 observed submission stop plus one in-flight overshoot. This is **not a
hard $10 cap**. These amounts are not an invoice or all third-party costs; they
concern Luna usage accounted
at approved application rates only; retained ScaleDown compression billing is
unquantified and not included. Initial live credit covers `10 - prior accounted
spend`, not the full exposure. If credit is declined, retain failed/unknown results; never
top up, change credentials or retry an ambiguous HTTP submission. Old profiles
1–4 retain their original limits.

Public reports contain aggregates only. Full per-item results, evidence lineage,
private receipt hashes and qualification context remain protected outside Git.

## Exact audited retry after provider credit recovery

The original five-route declaration remains accepted unchanged. A second closed
declaration, `RECOVERY_TARGET` in the same validator, additionally admits the
existing admin debate read, audited retry and read-only `POST /getRFQItemById`.
Its exact metadata binds one requeue to the already-observed issue94 failed run,
RFQ item17543, positive verified provider credit, zero eligible queue backlog,
an immutable full pre-snapshot, and the existing bounded automatic scheduler.
The validator uses strict JSON types: booleans and floats cannot substitute for
numeric bounds. No arbitrary route, run, item, budget or forbidden-list change
is admitted. Independent exact-head workflow approval is still mandatory.

This receipt grants no administrator identity or SQL execution. The caller must
use its existing authorized administrator for the audited retry, preserve the
full original row/error/provider/audit snapshot, and use a one-use execution
marker before the single POST; unknown outcomes are observed, never reposted.
The scheduler's model/attempt/evidence/time bounds remain unchanged, and manual
drain is excluded. The admin read contains parsed positions and hashes rather
than full native responses; native proof retains the separately authorized,
target-asserted read-only observer. RFQ reads retain normal role/factory checks
and may not Apply/Save, invent facts or alter pricing. No SQL write, promotion,
flag change, cloud mutation, production action or DesignFlow merge is admitted.
The closed retry profile can be retired after #94 acceptance; Codex owns its
verification and retirement under existing ai-devops #335. PR171 remains Uma's.

Verification checkpoint, October11, 8:58 AM EDT: behavioral source
`911a1ce6` was archived from Git and tested on the isolated vps2-direct host after
its collision check passed. The complete task-gate suite passed358/0, including
failure to persist the workflow receipt. The CI-reported missing reviewer-path
registration is corrected; the focused guard covers75 dependencies and passes.
Bash syntax, policy schema and whitespace checks pass. The owner-scoped history-detail route is explicit; the admin-only cross-user
audit route is excluded from ordinary workflow admission. These are source/test results;
merge, protected installation and DesignFlow #94 live acceptance remain open.
