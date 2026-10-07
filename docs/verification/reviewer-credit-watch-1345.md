# Reviewer credit watch — issue #1345

Parent: popcre/shared-db#3536. Owner: Codex reviewer-relief child.

The existing local-watch duty pool runs `ai-review-credit-watch tick` every
60 minutes. There is no additional timer. The tool claims the existing duty
lease before reading or changing admission; `check` only reads.
Installation and live scheduled execution remain unchecked below.

Qualified inputs are the installed Gemini `/usage` allowance reader and
DeepSeek's [official account balance interface](https://api-docs.deepseek.com/api/get-user-balance/),
plus GLM's [official ZCode quota reader contract](https://github.com/zai-org/ZCode/blob/29628c9acdb81b703bbd4080c207a0e7ce5e276e/packages/services/src/usage-stats/providers/bigmodelUsageQuotaProvider.ts).
StepFun's [official account interface](https://platform.stepfun.ai/docs/en/api-reference/accounts/get)
is also qualified for the existing Oversea API-key pay-per-request profile.
The fixed DeepSeek GET makes one bounded request, refuses redirects and reads
the existing owner-only cached key. No reviewer calls 1Password. Only coarse
availability is retained. Numeric balances, allowance, credentials and raw
errors never enter watchdog output.

An explicit exhausted result asks the existing admission store to pause the
provider globally for one hour. Its monotonic pause preserves stronger holds.
Available and unknown observations never clear holds, grant admission or
reset review rounds. A nondefault AI_GLM_MODEL returns UNKNOWN before any GLM cache or network access. Gemini credential/profile identity is unknown; provenance
is the current authenticated agy interface, not credential-qualified readiness.
DeepSeek binds its private observation to a cached-key fingerprint, which is
discarded before public logging.

GLM makes one fixed GET to `https://api.z.ai/api/monitor/usage/quota/limit`
with raw authorization (no Bearer), a 15-second bound, no redirects or retries.
Its CREDIT_LIMIT/TOKENS_LIMIT model buckets must contain exactly the qualified
5-hour (unit 3, number 5) and weekly (unit 6, number 1) periods. Both positive
means observed available; a proven zero means exhausted; missing, duplicate,
conflicting, malformed or tool-only limits mean unknown. The internal helper
reads an owner-only cache published by the existing GLM provisioning launcher
after vault resolution. Current vault-reference, provider, model, endpoint and
private credential fingerprint bind it; changed binding or invalid authentication
means unknown. Linux atomic 0600 files in a 0700 directory and the existing
Windows private ACL/atomic publication helper preserve access boundaries.
Cache publication failure preserves original GLM startup and leaves monitoring
unknown. Neither a reviewer nor the watcher resolves vault credentials.

The thin launcher binds the actual running Git Bash executable on Windows.
Native Python sends fixed toolkit wrapper paths and arguments to that validated
executable directly, preserving spaces without a shell string. Missing,
relative, forged or linked executable paths refuse. The standard CMD launcher
and machine tool catalog retain native Windows discovery.

StepFun reads only the existing private provider cache and makes one fixed
GET to `https://api.stepfun.ai/v1/accounts`, bounded to 15 seconds without
redirects or retries. The closed account schema must identify prepaid billing
and strict finite nonnegative numeric balances. Only its available balance
positive/zero proves available/exhausted. Postpaid, ambiguous, duplicate,
missing or malformed data and a changed profile/cache binding remain unknown.
The reader reuses existing physical-path/private-ACL/HTTP redirect guards;
it fetches no credentials and creates no additional store. A missing Windows
cache remains unknown without changing the original reviewer capability.
Private fingerprints and amounts never enter the public duty output.

Malformed, missing, stale, future, wrong-model and wrong-provider observations
stay unknown. Both supported Gemini windows must be present with strict finite
numeric values. Authentication, transport and timeout failure do not prove
exhaustion. Unsupported predictive interfaces remain unknown: Grok, Muse,
and Qwen. These three are incomplete coverage owned on this same issue;
this implementation must not be presented as complete provider coverage.

Offline verification covers fixed endpoint/timeout, redirect refusal, invalid
key/no network, malformed payload/no holds, fresh scope, claim refusal,
read-only checks, one-hour exhaustion-only pause and existing hourly scheduling.
Existing Gemini allowance regression suite: 39 passed, 0 failed on the author's unshimmed machine, reverified after actual dependency integration. The independent Muse disposable sandbox produced 20 passed / 19 failed because timeout-mediated fixture execution was denied with Operation not permitted; Gemini source and tests are unchanged from the merged base. This is retained as an environment limitation, not a reviewer 39/39 claim.
Integrated credit Python tests: 31 passed against merged pause API edcccb4dcfaddf85ba7dd7cc6f799d4c4e7027d9, including actual stronger-hold preservation, truthful accepted requests, original-observation windows and invalid timestamps for all four providers. The registered isolated real pause CLI preserves the stronger record and refuses malformed duration. Existing Windows generated-launcher
tests: 53 passed; CMD launcher audit passed. The registered credit suite also
requires the real merged pause CLI, preserves a stronger isolated hold and
refuses malformed input. Its API dependency is #1347, not the continuation
receipt change #1352. Exact merged integration and scheduling remain pending.
The GLM cache path reuses the maintenance toolkit's physical-path normalizer;
its optional conversion budget is two seconds and conversion errors or
nonabsolute outputs leave availability unknown. Existing callers retain their
default behavior and shared link/junction refusal remains enforced.
Live read-only observations at 2:52 PM EDT October 6, 2026: Gemini available;
DeepSeek available. No hold changed by this read-only proof.
GLM official read-only qualification at 3:25 PM EDT October 6, 2026 returned
code 200 / success true and both qualified CREDIT_LIMIT periods positive.
The pinned official reader also accepts successful code 0 envelopes (its success predicates at lines 1093–1102). The helper requires an integer code of 0 or 200 and rejects explicit success false; qualified period and numeric checks still apply. The live qualification observed code 200, not code 0.
This one-off proof did not publish a credential cache or alter the runtime.

Remaining qualification evidence (October 6, 2026): Grok authenticated account
shows positive coarse credit availability, but its separate management credential
does not exist and creating persistent access requires unavailable platform
confirmation (3:19 PM EDT). StepFun's dashboard sign-in encountered a platform
CAPTCHA (3:19 PM EDT); its default zero was not proof. The separately documented
API-key prepaid account interface was qualified AVAILABLE at 5:00 PM EDT using
the existing protected cache, without a model call or runtime change. That
read-only API observation supersedes the dashboard-only interface blocker.
Muse authenticated billing shows historical use/payment information but
no authoritative remaining allowance signal (3:30 PM EDT); the subscription link
offers a new purchase and was left untouched. Qwen's actual Singapore
International Token Plan uses monthly credits. Official CLI usage exposes
five-hour/weekly fields and requires console authentication; neither this
account's monthly schema nor an authenticated response is qualified. The
existing browser session is signed out, with Account/Password sign-in only,
and no console login exists in the supported vault metadata (3:36 PM EDT).
Inference credentials and old Coding Plan/account billing counters do not
qualify. Alibaba Cloud account/platform authority owns this qualification gap.
These gaps stay on issue #1345; no reviewer capability was reduced.

## Acceptance still required

- [ ] Independent exact-head reviewer approval and required CI.
- [ ] Supported installation after reviewed merge.
- [ ] Actual recurring duty-timer execution on the installed command.
- [x] GLM official predictive interface qualified read-only (owner: reviewer-relief child); installed cache/recurring execution still required above.
- [ ] Grok predictive interface qualified (owner: reviewer-relief child).
- [ ] Muse predictive interface qualified (owner: reviewer-relief child).
- [ ] Qwen predictive interface qualified (owner: reviewer-relief child).
- [x] StepFun official prepaid interface qualified read-only (owner: reviewer-relief child); installed recurring execution still required above.

The existing pause API receives the exact strict helper observation epoch through `--observed`; delayed dispatch or repeat processing never refreshes that original one-hour window. Malformed, future and stale times remain UNKNOWN. Stronger existing holds remain unchanged.

Windows interpreter qualification queries OS known-folder APIs for the system
Program Files and per-user Local AppData roots, independently of caller
environment. Both supported Git `bin/bash.exe` and `usr/bin/bash.exe` layouts
remain usable. Every original path component is checked for symbolic links/reparse
points before resolution. A bounded PE format and executable-flag check runs
before any child launch. This checks executable format, not vendor authenticity;
the existing same-user per-user installation trust boundary remains accepted.
Missing discovery, forged environment roots, plain text, truncated/nonexecutable
PE files, outside-root paths and symbolic links refuse before credential-bearing tools.
Folder identifiers follow Microsoft's
[known-folder definitions](https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid).
The separately verified official API allocation/free contract is retained in private qualification evidence.
