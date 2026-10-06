# Native GLM pool dispatch repair — issue #1349

Parent: popcre/shared-db#3536. Owner: Codex reviewer-relief child.

Observed supported-entry failure:
`ai-review-pool: error: glm is not a pool provider with a session runner.`
The front door accepts GLM's registered state, while the adapter omitted GLM
from its existing native-session path. The shipped door registry does not
register GLM, so it belongs to this already supported legacy adapter path.

The fix routes GLM to the existing `ai-glm` wrapper and extends the guarded
test-hook selector. No new wrapper or door is introduced. Model, credentials,
session budget and provider behavior remain owned by `ai-glm`. Pool lifecycle,
sealed snapshot, immutable source identity, head binding, verdict and minimum
model-analysis floor remain unchanged. Runner substitution remains test-only.

Current upstream `ai-glm` parser accepts `new NAME --prompt-file FILE --base
SHA --assert-head SHA`. Its `emit` function prints model body on stdout and
session/report progress on stderr. The adapter passes these exact arguments
and continues separating streams; no progress text can satisfy report gates.

Verification: focused offline native-shaped runner integration passes nine
checks for argument dispatch, isolated snapshot, caller-source preservation,
wrong report head, malformed verdict, insufficient body, chrome-only body,
model snapshot mutation, wrong dispatch head and ungated test substitution.
Existing shared-door dispatch suite: 18 passed, 0 failed.

## Required live acceptance

- [ ] Independent exact-head review and required CI.
- [ ] Supported reviewed toolkit installation.
- [ ] Native GLM well-formed final review through installed `ai-review`.

The original fault stays pending until that last native proof. This repair
does not qualify GLM's predictive credit interface; that remains unknown on
issue #1345. No raw provider harness or credential transport is bypassed.
