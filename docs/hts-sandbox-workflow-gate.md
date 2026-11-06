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
exposure, provenance, exact runner, catalog and pricing SHA-256 receipts.
V5 requires `session-provider-exposure-verified`: reported calls, a conservative
call upper bound, accounted cost, an explicit unobserved-cost reserve, their
eight-decimal budget baseline and the private snapshot hash. The upper bound
cannot be below reported calls; costs are finite and nonnegative and the exact
rounded baseline must be below $10. An old exact-usage receipt cannot qualify v5. It binds
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
99 calls per inquiry and 8,217 for 83 inquiries, plus the verified prior session call upper bound.
Provider HTTP retry and billable tools remain absent. Catalog bounds are
1,050,000 context and 128,000 completion tokens; maximum approved input/output
rates are $0.00000025/$0.00000075 per token. One inquiry's conservative risk is
$35.4915. The coordinator explicitly authorizes up to $45.50 session exposure:
the $10 observed submission stop plus one in-flight overshoot. This is **not a
hard $10 cap**. These amounts are not an invoice or all third-party costs; they
concern Luna usage accounted
at approved application rates only; retained ScaleDown compression billing is
unquantified and not included. Initial live credit covers `10 - prior budget
baseline`, not the full exposure. If credit is declined, retain failed/unknown results; never
top up, change credentials or retry an ambiguous HTTP submission. Old profiles
1–4 retain their original limits.

Public reports contain aggregates only. Full per-item results, evidence lineage,
private receipt hashes and qualification context remain protected outside Git.

### One original-v5 operational continuation

Version 6, `hts-frozen-r9-operational-continuation`, declares exactly one
`pre-provider-immutable-input-repair` transition of an already claimed v5 run.
It retains every v5 route, provider, cohort, budget and initial-lifetime bound.
It grants no new submission for the first failed inquiry, no retry route, no
reset, no second transition and no new expiry. The first failed record stays
failed and untouched; only an append-only, privately proved zero-launch
accounting overlay is eligible. This does not turn a failure into a success.

The exact `operational_continuation` object contains `purpose`,
`receipt_sha256`, `original_ledger_sha256`, `original_admission_sha256`,
`original_manifest_sha256`, `original_readiness_sha256`,
`original_runner_sha256`, `original_served_source`,
`original_served_revision`, `original_served_digest`, `original_expires_at`
and `original_schema_version` (integer 5). New runner and served-source pins
must differ from their originals. `expires_at` must equal the declared original
expiry. All eight usual v5 bindings remain required, including the new runner,
readiness and actual served pricing evidence.

`original_ledger_sha256` hashes the exact protected original-ledger archive
bytes. `original_admission_sha256` hashes `JSON.stringify` of that archived
ledger's admission object, preserving its property order; it is distinct from
the admission object's manifest SHA. The private executor must verify every
archive and receipt hash against the actual original ledger, run identity,
created time, input/key, prior reserve, budget, qualification, catalog and expiry.
It must prove the exact first failed job's three attempts stopped before provider
registration with zero model launch, verify the narrowly approved immutable-input
repair and new epoch source, and refuse any existing transition or failed-job
rePOST. Native admission validates closed metadata, not those private facts.
No continuation may open the cohort until all actual executor checks pass.

## One current-v6 JSON literal operational repair

Schema 7 has the distinct closed scope
`hts-frozen-r9-json-literal-operational-continuation` and exact purpose
`pre-snapshot-json-literal-bind-repair`. It preserves all v5 limits, routes,
provider, source/origin/clean-tree restrictions and eight binding fields.
Schemas 5 and 6 retain their existing behavior unchanged.

Its `operational_continuation` uses the same twelve fields documented for v6,
but `original_schema_version` must be integer 6. Every `original_*` field binds
the immediate CURRENT v6 parent: the paused ledger's exact archived bytes,
its admission object's canonical `JSON.stringify` bytes, current manifest,
readiness, runner, served source/revision/digest and original expiry. The new
runner and served source must differ; expiry must remain exactly equal.
Schema 7 cannot cite a v5 or v7 parent, renew expiry, add a retry route or use
the previous repair purpose.

The private executor must additionally verify the archived v6 parent's embedded
immutable v5 lineage, exactly one existing operational epoch, and the fixed
synthetic JSON-literal roundtrip repair/proof. The new receipt binds that prior
receipt plus the paused ledger, all existing failures, costs and current
in-flight inquiry. Exactly one additional epoch is allowed; no third epoch,
second zero-cost reconciliation, reset, retry/rePOST or frozen-input/key change
is admitted. Existing raw failures and accounting remain untouched. This is
metadata admission only: private proofs and final execution authority remain
separate, and no cohort may be opened before the executor verifies them.

## One current-v7 prepack identity-join operational repair

Schema 8 has the distinct closed scope
`hts-frozen-r9-prepack-identity-operational-continuation` and fixed purpose
`prepack-item-identity-join-repair`. Its same twelve header fields bind the
immediate CURRENT v7 parent and paused ledger; `original_schema_version` must
be integer 7. New runner/source pins are required and the original expiry must
remain exactly equal. All v5 provider, budget, frozen, route, source/origin and
clean-tree restrictions are retained. Existing v5/v6/v7 predicates are unchanged.

The private executor verifies the complete embedded v5→v6→v7 lineage, exactly
two previous operational epochs, and the preserved pre-create refusal proof
plus the synthetic-proved canonical item-identity join contract. Only the third
operational epoch is admitted; a v8 parent/fourth epoch is refused. All original
failures, costs, qualification, budget, expiry, input and key remain preserved.
The refused slot remains failed with no job retry/rePOST. This does not bypass
prepack qualification, change product flags or establish that a particular
product's refusal was a false positive. No new zero-cost overlay or run reset
is authorized. As with earlier profiles, native metadata acceptance does not
replace private executor proof or final continuation authority.

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

### Post-run diagnostic metadata (schema 9)

This separate closed profile is not another evaluation epoch. Its only HTTP
route is `POST /api/hts-rag/jobs/diagnostic-tags`, with server-verified admin
access, one stored owner, and at most 83 exact artifact-proven identities in
alsand sandbox. It grants no provider, inquiry, answer, retry, Apply, SQL,
production, schema or cloud authority. Existing profiles 1–8 are unchanged.

Three scenarios are closed: `inspect` permits one read and zero writes, with
`snapshot_state: not-yet-captured` and a null snapshot binding;
`evaluation-mark` permits at most one `active:true` write and three reads;
`synthetic-roundtrip` permits exactly one synthetic identity, sequence
`true,false,true`, at most three writes and four reads. The final synthetic
state is marked. Every write uses a fresh server snapshot. An ambiguous write
is never resent: a later invocation may only observe the same exact set.

The declaration binds the actual served source/revision/digest, a 24-hour
expiry, exact count, and six opaque SHA-256 values: run, terminal ledger,
private identity manifest, terminal readiness, observed snapshot, and executor.
The maintained executor is `scripts/hts-diagnostic-inquiry-tags.js`. Initial
inspection records an actual private server snapshot; a write declaration
must subsequently pin it. No fabricated snapshot or authority flags are valid.
Original evaluation ledgers, reports, status, costs, questions and history stay
unchanged; only the trusted diagnostic marker controls attention/actions.

### Private immutable runtime continuation (schema 10)

This closed routing-only fourth operational epoch requires the immediate v8
parent, original expiry and all original ledger/input/key/budget bindings.
It adds no fifth epoch, retry, reset or extra inquiry. The executor must preserve
43 existing records and at most 40 planned submissions, and prove the complete
original lineage. Schema 9 remains a separate metadata closeout action.

The one resource identity is project `lithe-breaker-323913`, region `us-east4`,
service `popcre-albert-hts-r9-01a1ab99`, queue `hts-r9-01a1ab99`, lane
`r9-01a1ab99`, process role `isolated-hts`. The only admitted origin is the
actual canonical service `status.url`:
`https://popcre-albert-hts-r9-01a1ab99-mi7si7t62a-uk.a.run.app`. It was read
after separately governed creation; the predicted project-number alias is not
admitted. Metadata validation alone does not authorize a frozen continuation;
the executor still requires its exact private proof and owner release.

The private-runtime proof binds current-security server source/digest and the
approved semantic-closure proof, independently of the honest tool source and
runner. Direct private API origin has no public BFF `/api/core` prefix. The
original two inquiry routes and Luna/rulings-only provider bounds stay fixed.
One distinct auth route, `POST /findUserLoginInfo`, permits at most eight
zero-model application refreshes with the original verified actor/scope. It
provides no new user, key, privilege, inquiry retry or general auth endpoint.
# Independent common-sense development proof (schema 11)

This separate closed declaration admits seven fixed synthetic service assessments
and one ordinary sandbox application inquiry by the existing actor 77. It is not
another frozen-evaluation epoch and cannot renew, reset or alter that evaluation.
The eight fixed case identifiers and fixture prefix are bound to the maintained
`scripts/hts-common-sense-dev-proof.js` executor and private immutable fixture bytes.

Only the exact OpenRouter completion endpoint and sandbox inquiry POST/returned-ID
GET routes are declared. There is no login, answer, manual retry, Apply, real-item
write, infrastructure or production route. Existing protected session authentication
is read locally. Luna remains dated/pinned, high effort and operative output 32768;
the established phrase preprocessing setting is unchanged. The limits are seven
direct launches, one application inquiry, 117 source-bound application launches and
124 total, with three existing attempts and two automatic recorded-fact answers.

The new declaration expires within sixty minutes. Nine opaque private hashes bind
executor, fixtures, readiness, prices, catalog, credit, prior exposure, runtime bounds
and key attestation; current server source/revision/digest and source ancestry are
checked without exposing credentials or product content. Source and served source
must match. The cumulative approved-rate exposure is 39.7391773 within the explicitly
authorized 45.5 ceiling; the observed ten-dollar pre-submission stop is not a hard
invoice cap. Compression billing remains unquantified and excluded.

The native validator proves only closed admission metadata. Before key access or
network, the maintained executor must obtain genuine installed admission, enforce
physical direct-launch counts and the one-use inquiry journal, and independently
validate source/runtime/identity/accounting. Ambiguous inquiry POST outcomes never
retry. Existing profiles are unchanged. Invented tests are not live reasoning proof.
