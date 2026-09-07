# Reviewer failure diagnostics and quota preflight

Owner: reviewer infrastructure, [issue #312](https://github.com/popcre/ai-devops/issues/312).
Planning baseline: `586de2511d680f2d69e5cd4d550a7d4485ea0c76`, September 7, 2026.
Implementation is locally complete through step 4 on an isolated branch. Step 5
remains open until exact-head review, CI, merge, installation, and live proof.
Handoff: [execution brief](HANDOFF.d/2026-09-07T1807Z-edge-dev-codex-reviewer-diagnostics-quota.md).

## STATUS

| Step | State, September 7 | Evidence needed to mark done |
|---|---|---|
| 0. Qualify existing interfaces and ownership | local complete | Capability matrix records pinned versions, official sources, unsupported interfaces, and every review dispatch path |
| 1. Add bounded diagnostic contract | local complete | Lifecycle 38/38 and incident recorder 116/116 with 4 platform skips after the final code rebase |
| 2. Instrument Kimi, Grok and GLM | local complete | Kimi 213/213, Grok 222/222, and GLM 250/250 after the final code rebase |
| 3. Implement non-generating quota preflight | local complete | Preflight 78/78 proves tri-state validation, one request, strict scope/freshness, and zero network for unsupported interfaces |
| 4. Integrate review dispatch | local complete | Provider fixtures prove exhausted Kimi and Grok dispatches submit zero model turns; normal provider suites remain green |
| 5. Qualify, install and close evidence | in progress | Independent review, merged SHA, CI and controlled live proof |

## 1. Ultimate goal

When a reviewer stops, Albert should know what actually happened and where the
evidence is, without paying for repeated attempts to reconstruct it. A reviewer
known to have no capacity should stop before submitting review work. When capacity
cannot be checked, say so honestly and retain the existing ability to review.
If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this toolkit is

`popcre/ai-devops` is a public Bash/PowerShell toolkit used by Albert's AI coding
sessions. Provider wrappers run locally, keep private evidence and enforce
independent review boundaries. Source is installed through local launchers or
symlinks, not an application deployment. EDGE-DEV uses `C:\repos\ai-devops` as its
landing-only installation; every implementation task needs a fresh upstream worktree.
`u2giants/shared-db` consumes reviewer results for governed assignments. It owns
its coordination code; this plan needs no database or production infrastructure changes.

## 3. Trigger and evidence

Albert requested this plan after September 7 reviewer repairs exposed three
unexplained failures and a quota block. Toolkit repair PR #310 merged at
`6ac22eb8b286a64d5198b18117ed005d412c6018`; coordination PR #2532 merged at
`ba2d5b38257f43040b486956e464f0b44d797097`. These are completed prerequisites,
not work to reimplement. See the [residual incident handoff](HANDOFF.d/2026-09-07T1800Z-edge-dev-codex-reviewer-residual-failures.md).

The private ledger under the installed toolkit's `.ai/reviewer-issues` includes:

- `20260907T145035Z-edge-dev-kimi-k3-1398567`: no verdict after 13 minutes;
  false permission diagnosis fixed, underlying slow-run cause unproven.
- `20260907T145226Z-edge-dev-grok-4.6-1399781`: ten-minute no-verdict result;
  provider reported cancelled but did not identify the initiator.
- `20260907T165131Z-edge-dev-glm-23851`: local server listener existed but health
  and permission requests did not answer; same-session recovery succeeded.
- `20260907T165823Z-edge-dev-kimi-66135`: live canary refused for usage limit.

These failures are not all reproducible on demand. Use synthetic faults for
deterministic tests; never manufacture a production outage. Private evidence and
`audit.md` reside at `C:\Users\ahazan\.local\state\ai-devops\repair-evidence\20260907-reviewer-logs`.

## 4. Scope

In scope: a common bounded diagnostic envelope; instrumentation for Kimi, Grok
and GLM review paths; quota capability qualification for those providers; bounded
non-generating checks where supported; explicit unknown where unsupported;
exact-run incident capture; tests, docs, installation and live acceptance.

NOT in this plan: automatic provider switching, purchased quota, subscription
changes, automatic retries, service restarts, broader tool permissions, provider
CLI upgrades, investigation/implementation modes, merge-queue or assignment
capacity changes, a fleet-wide wrapper rewrite, dashboards, monitoring services,
automatic incident publication, or maintenance scan checkpoints (#308).
Other providers retain behavior and get compatibility tests only.

## 5. Current code state

References below are baseline anchors; locate functions again after fetching main.

- `bin/ai-review-lifecycle:88` (`begin`) records identity, preflight, source and
  ownership; `:145` (`terminal`) binds reports, source freshness and scoreboard;
  `:174` (`join`) provides exact incident identity. Reuse this shared home.
- `bin/ai-review-preflight:169` classifies diagnostic output; `:249`
  (`check_provider`) dispatches doctors, and `:284-288` can run live doctors.
  Live doctors are not proof of a free quota query. Current capacity output can
  be `not-separately-exposed`; do not relabel it available.
- `bin/ai-kimi:1155` recognizes usage errors after execution; `:1261` explains
  the usage-limit result. Review `start_review_job`, its worker/terminal code,
  `cmd_cancel_job` and `cmd_recover_job`; do not confuse implementation finalizers
  at `:1635-1691` with review job ownership.
- `bin/ai-grok-review:754` (`await_result`), `:804` (`run_turn`) and `:1025`
  handle provider completion/cancellation. Local cancellation uncertainty is
  deliberately retained at `:693`; process exit is not proof of remote cancellation.
- `bin/ai-glm:130` (`server_up`), `:343` (`metadata_lock_acquire`), `:597-771`
  permission polling, and `:860` turn-timeout record existing observations.
  Use `server_up` with a short bound; do not invoke server start/restart.
- `docs/reviewer-issues.md:45` defines exact-run joins and private evidence
  capture. `bin/ai-reviewer-issue` owns sanitization and immutable incident packages.
  No need for a second evidence ledger.

The previously shipped wrappers are installed on EDGE-DEV. This plan introduces
no implementation changes. Do not use older `bugs.md` audit prose as current
failure proof without checking the relevant source and tests.

## 6. Findings and root causes

The Kimi classifier formerly treated quoted repository text as an execution
denial; measured timeout now takes precedence. Grok already exposes a terminal
stop reason, but a cancelled result does not prove who initiated cancellation.
GLM can have a live listener and an unresponsive service; process presence alone
is insufficient. Successful later reviews do not establish these original causes.

No reliable, non-generating Kimi quota interface was established during planning.
The first implementation gate must qualify supported interfaces, account/model
scope, freshness and whether calls incur generation. Unknown is a necessary
result, not evidence that capacity is either exhausted or available.

## 7. Rejected approaches

- Parsing arbitrary assistant/tool text for causes: repository content can quote
  errors and manufacture false diagnoses. Use wrapper observations and qualified
  structured provider fields, with bounded adapter-specific stderr classification.
- Inferring provider cancellation from a killed local process: remote billing
  may continue. Preserve existing exact-work protection and uncertainty.
- Using `doctor --live` or a tiny prompt as a quota probe: that may itself submit
  paid work, defeating the purpose. No generative probe in the automatic preflight.
- Treating HTTP 403 or 429 alone as exhausted quota: authentication, policy or
  rate throttling can produce them. Require qualified provider-specific evidence.
- Treating an unavailable quota endpoint as a hard block: this would disable an
  otherwise working reviewer. Unknown proceeds visibly under existing guards.
- Reusing yesterday's quota failure indefinitely: resets and other clients change
  capacity. V1 makes no persistent quota cache or sticky account-wide prohibition.
- Adding a parallel logging daemon or replacing all wrapper lifecycle ownership:
  unnecessary concurrency and maintenance risk; extend the existing shared home.

## 8. Design decisions — September 7

**Locked:** observations never become an approval; exact source/report binding,
permissions, quarantine and cancellation protections remain authoritative.
Diagnostic fields are optional additive data, not a new authority to release
locks or reclaim jobs. Instrument provider-local records through shared validation
and serialization; do not enroll wrappers into a second owner/lock mechanism.

Diagnostic envelope version 1: exact existing join identity; phase enum
`preflight|launch|awaiting-provider|awaiting-local-service|finalizing|terminal`;
UTC observation timestamps and elapsed durations; last observation type;
wrapper exit code/signal if known; deadline kind; qualified provider terminal
reason; local health result `healthy|unreachable|timed-out|unknown`;
cancellation initiator `wrapper-deadline|user-command|signal|provider|unknown`,
requested time and confirmation `confirmed|unconfirmed|not-requested`;
safe failure class; quota result reference. Null means unavailable.
Provider cancellation with no local initiating evidence has initiator unknown.

Keep one bounded current envelope and a capped transition history within existing
run storage. Cap at 64 events and 32 KiB serialized per run; emit `truncated=true`
if older transitions roll off, preserving launch and terminal summaries. Record
phase changes, observed failures and terminal outcomes, not every poll or token.
No raw prompts, responses, stdout/stderr, environment, credential values, command
lines or unrestricted provider strings in this envelope. Validate enums and
bounded opaque identifiers. Exact raw logs remain private under existing rules.

Quota contract: `available|exhausted|unknown`, checked-at, provider/installed
version, opaque local credential-profile scope, model/plan scope if exposed,
source kind, reason enum, and reset-at only if returned authoritatively. Available
means reported capacity at that instant, never a reservation or guarantee. Do not
derive credential identity by hashing a secret. Unscopable results are unknown.

Use one non-generating request per review dispatch, maximum five seconds, no
automatic retries or persistent cache. Put these validated defaults in the
existing configuration home (`config/` with machine overrides), not scattered
wrapper literals. Unsupported adapters return unknown without network access.
Fresh exhausted returns a non-success preflight result before generation; unknown
prints one safe explanation then permits the normal review attempt. Retain
provider-side quota handling after submission because capacity may race.

**Open implementation choices:** exact JSON property nesting, configuration
filename in the existing config home, and whether to expose an additive
`ai-review-preflight capacity <provider> --json` command. Prefer that command for
testability. Decisions must preserve the contract and existing CLI compatibility.
No owner decision is needed to select names. Missing quota interfaces must remain
an explicit qualification limitation; do not invent endpoints or billing claims.

## 9. Ordered implementation

### Phase A — contracts and diagnostic evidence

**Step 0: verify baseline and capabilities.** In a fresh upstream worktree, read
AGENTS.md, routed provider plans and affected verification headers. Inspect
`config/provider-cli-versions.json`, `bin/ai-review-preflight`, provider-local
metadata paths and existing wrapper locks. Qualify quota interfaces using installed
help/source and official provider documentation, recording exact source URLs,
versions, response schema, scope and non-generation proof in
`tests/verification/reviewer-diagnostics-quota/capabilities.md`. No guessed endpoint
or credentials in output. Classify each provider supported or unsupported with
evidence. Map review entry points, worker/cancel/finalize paths and existing join
fields. Gate: all three providers and every review dispatch path mapped; unknowns
explicit, and no paid test used to discover quota. No dependencies.

**Step 1: implement shared additive contract.** Extend `bin/ai-review-lifecycle`
with a validator/serializer callable for provider-owned records without calling
`begin` or acquiring another assignment lock. Use existing per-run ownership and
atomic replacement; reject paths outside managed run storage, symlinks, foreign
join identities, invalid enums and excess input. Extend `bin/ai-reviewer-issue`
sanitization/copying to include only exact matching diagnostic envelopes; accept
legacy records with no envelope. Do not rewrite old incidents. Depends on step 0.
Gate: `tests/test-ai-review-lifecycle.sh` and `tests/test-ai-reviewer-issue.sh`
prove bounded, private, backward-compatible exact-run capture under hostile input.

**Step 2: instrument the three wrappers.** At the step-0-mapped launch, wait,
cancel and finalize sites in `bin/ai-kimi`, `bin/ai-grok-review`, `bin/ai-glm`,
write shared envelopes into their existing private records. Prefer existing
wait-loop observations. For GLM, one bounded health observation on launch and one
on failure, within the overall deadline; never per-poll extra HTTP calls. Preserve
the original exit status if evidence writing fails; report evidence unavailable,
never successful completion. Successful verdict publication still requires all
existing evidence. A hard kill may leave a running envelope: observation must
report unknown termination, never claim remote cancellation or release ownership.
Depends on step 1. Gate: injected deadline, cancellation, local health failure and
normal completion each retain one correctly joined record and unchanged guards.

Natural cut: commit evidence-backed Phase A; update STATUS and use fresh-session
if needed. Re-read Phase B before starting it, including its unknown semantics.

### Phase B — quota preflight and dispatch

**Step 3: implement capacity checks.** Extend `bin/ai-review-preflight` and
provider-local read-only adapters using step 0's qualified interface only. Do not
shell-evaluate configured commands. Validate response type, scope and timestamps;
timeouts, malformed data, transport/auth errors and unsupported versions become
unknown with a safe distinct reason. A standalone capacity query may exit zero
for a valid tri-state response; operational dispatcher must inspect state rather
than equate exit zero with available. Existing authentication/preflight failures
remain failures independently. Depends on step 0; may proceed independently of
step 2 after step 1's identity contract is settled. Gate: bounded request-count
fixtures prove no generation, no retry and no raw response leakage for all states.

**Step 4: integrate immediately before review submission.** Wire each mapped
review start/resume path in the three wrappers after existing identity, version,
auth and ownership checks but before generation. Ensure shared lifecycle and
wrapper paths do not double-probe. Persist fresh result and terminal preflight
failure for exhausted capacity without inventing a review verdict or provider
session; release only resources that existing ownership rules permit. Preserve
resume context when submission is refused. Unknown gives one concise diagnostic
and continues; exhaustion after available remains a normal provider quota failure.
Depends on steps 2 and 3. Gate: call counters show exhausted=zero submissions,
unknown/available=one intended submission; distinct sessions remain independent.

### Phase C — acceptance and landing

**Step 5: qualify and install.** Run the tests in section 10, read-only exact-head
independent final review, normal PR/CI/merge and installation per deployment docs.
Extend `docs/reviewer-issues.md`, `docs/configuration.md`, and affected provider
skills with measured behavior and unsupported capability limits. Preserve user
settings and backup changed installed configuration. Use synthetic repositories
for live canaries; record redacted proof under the existing verification home.
Check one qualified non-generating capacity call and one successful live review
per affected provider when existing capacity allows. Compare installed bytes to
merged source. Original incident closure still needs symptom-specific root-cause
proof; diagnostics alone cannot close them. Depends on all prior steps. Gate:
section 13's checklist is evidenced; quota-blocked live acceptance stays pending.

## 10. Required tests

Extend existing suites; do not add another test harness:

- `tests/test-ai-review-lifecycle.sh`: event caps, invalid enums, missing optional
  legacy envelope, path traversal/symlink/foreign join rejection, atomic writes,
  concurrent terminal/cancel updates, no second assignment lock, truncated history
  retaining start/terminal summary, hard-kill uncertainty, write-failure truth.
- `tests/test-ai-reviewer-issue.sh`: exact envelope copied, mismatched run/source
  rejected, secret sentinels and arbitrary provider text absent, existing incident
  bytes unchanged, legacy capture and resolution behavior preserved.
- `tests/test-ai-review-preflight.sh`: all tri-state cases; unsupported means zero
  network; timeout <= configured bound; no retries; malformed/stale/wrong-scope
  response unknown; 403/429 alone not quota; unavailable reset remains null;
  no generation endpoint contacted; flags remain backward-compatible.
- `tests/test-ai-kimi.sh`: timeout beats quoted permission text; quota blocked
  before generation; normal and resumed successful review; unknown permits attempt;
  post-check quota race still fails; cancellation record survives cleanup.
- `tests/test-ai-grok-review.sh`: provider-cancelled initiator unknown; explicit
  user cancellation distinguished; deadline and local child exit never imply
  confirmed remote cancellation; exact-work duplicate protection unchanged.
- `tests/test-ai-glm.sh`: listener present/health timeout, permission endpoint
  timeout and ordinary provider completion distinguished; health requests bounded;
  no restart, no cross-session abort, named session continuity preserved.

Run each changed suite with Git Bash (`bash tests/<suite>.sh`) and retain its
summary. Syntax-check touched Bash files and run `git diff --check`. Use existing
test doubles for API counts and fault injection; never induce quota exhaustion
or kill the shared live service. Run Windows checks only on a verified idle or
reserved appropriate host; read current runner docs first. CI covers platform
compatibility, not live provider acceptance. No UI exists to screenshot.

## 11. Constraints

Branch/PR required, no direct push to main; merge through required checks and
bounded `bin/ai-pr-wait`. Independent exact-head review required for wrappers,
evidence tools and safety tests. Source changes invalidate prior review evidence.
Never relax quarantine, verdict parsing, source binding or six shared-db terminal
failure codes to fit new data. No database migration or shared cloud mutation.
No raw transcript access, secret output or public private logs. Preserve all
concurrent work and original incident packages. New code belongs to existing
reviewer infrastructure; this plan is owned by #312 and consolidates into reviewer
docs when complete. It does not replace #169's broader wrapper-sharing work.
No automatic task, quota purchase or recurring watcher is authorized.

## 12. Access and environment

PowerShell and Git Bash on EDGE-DEV; dependencies Bash, Git, jq, curl and gh.
GitHub access was authenticated during planning. Recheck identity before commit:
`git var GIT_COMMITTER_IDENT` must show Albert Hazan with
`u2giants@users.noreply.github.com`. Credentials live in 1Password vault
`vibe_coding`; use existing wrapper credential loading, never request broader
credentials or inspect auth files to find an undocumented endpoint. Read the
secrets skill before any needed credential operation. Provider item titles must
come from current authorized configuration, not guesses.
Canonical shared-db has another task's dirty files. #308 checkpoint work is
separately owned; coordinate via source inspection, never overwrite its work.

## 13. Done, risks and remaining uncertainty

Done requires all STATUS gates with files/run IDs, regression suites green,
independent exact-head approval, merged commit on origin/main, installed-byte
proof, successful live capability preserved for each affected provider and a
qualified capacity matrix. No provider has its quota result guessed. Where a
non-generating interface is unavailable, explicit unknown is the delivered honest
behavior; describe that limitation rather than claiming quota avoidance there.
If Kimi capacity never becomes available during execution, its successful live
review gate remains blocked and #312 stays open. No owner purchase is required.

Main risks: diagnostic writes racing cancellation; double probes; stale or
wrong-account quota reports; new logging exposing secrets; preflight extending
deadlines; unknown being misread as healthy. The specific tests above address
them. Capacity is inherently subject to a race after checking; provider-side
failure handling remains mandatory. More diagnostic evidence may still not reveal
the original provider-internal cause; explicitly retain unknown.

Rollback through a reviewed revert and supported installation with backed-up
settings, preserving incident evidence. Never weaken a guard or live-edit a server
to recover. Update STATUS as phases ship; carry unfinished proof in an own handoff.
Retire this plan's handoff when #312 is complete; retain the plan as a decision record.

Self-audit: (1) Fresh-session execution passes: sections 2–6 establish baseline and
evidence, 9–12 give files, dependencies, commands and gates. (2) Context transfer
passes: sections 3, 6–8 and 13 retain incidents, rejected approaches, quota unknowns
and cancellation limits. (3) Goal-directed judgment passes: section 1 states the
business outcome; sections 4, 8 and 13 define scope, locked behavior and honest
acceptance when an interface is unsupported. No planning-chat dependency remains.
