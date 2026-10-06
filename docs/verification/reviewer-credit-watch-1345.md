# Reviewer credit watch — issue #1345

Parent: popcre/shared-db#3536. Owner: Codex reviewer-relief child.

The existing local-watch duty pool runs `ai-review-credit-watch tick` every
60 minutes. There is no additional timer. The tool claims the existing duty
lease before reading or changing admission; `check` only reads.

Qualified inputs are the installed Gemini `/usage` allowance reader and
DeepSeek's [official account balance interface](https://api-docs.deepseek.com/api/get-user-balance/).
The fixed DeepSeek GET makes one bounded request, refuses redirects and reads
the existing owner-only cached key. No reviewer calls 1Password. Only coarse
availability is retained. Numeric balances, allowance, credentials and raw
errors never enter watchdog output.

An explicit exhausted result asks the existing admission store to pause the
provider globally for one hour. Its monotonic pause preserves stronger holds.
Available and unknown observations never clear holds, grant admission or
reset review rounds. Gemini credential/profile identity is unknown; provenance
is the current authenticated agy interface, not credential-qualified readiness.
DeepSeek binds its private observation to a cached-key fingerprint, which is
discarded before public logging.

Malformed, missing, stale, future, wrong-model and wrong-provider observations
stay unknown. Both supported Gemini windows must be present with strict finite
numeric values. Authentication, transport and timeout failure do not prove
exhaustion. Unsupported predictive interfaces remain unknown: GLM, Grok, Muse,
Qwen and StepFun. These five are incomplete coverage owned on this same issue;
this implementation must not be presented as complete provider coverage.

Offline verification covers fixed endpoint/timeout, redirect refusal, invalid
key/no network, malformed payload/no holds, fresh scope, claim refusal,
read-only checks, one-hour exhaustion-only pause and existing hourly scheduling.
Existing Gemini allowance regression suite: 39 passed, 0 failed.
Live read-only observations at 2:52 PM EDT October 6, 2026: Gemini available;
DeepSeek available. No hold changed by this read-only proof.

## Acceptance still required

- [ ] Independent exact-head reviewer approval and required CI.
- [ ] Supported installation after reviewed merge.
- [ ] Actual recurring duty-timer execution on the installed command.
- [ ] GLM predictive interface qualified (owner: reviewer-relief child).
- [ ] Grok predictive interface qualified (owner: reviewer-relief child).
- [ ] Muse predictive interface qualified (owner: reviewer-relief child).
- [ ] Qwen predictive interface qualified (owner: reviewer-relief child).
- [ ] StepFun predictive interface qualified (owner: reviewer-relief child).
