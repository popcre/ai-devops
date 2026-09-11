# Implementation plan — reviewer reliability and measured efficiency

## Ultimate goal

Albert should get accurate, usable reviews without paying repeatedly for the wrong evidence, lost work, exhausted accounts, or unnecessary rereading. Every supported reviewer should preserve the right conversation and code state, report cost and caching honestly, and either finish with trustworthy evidence or explain precisely why it could not.

**If a step conflicts with this goal, the goal wins — stop and flag it.** “100% optimal” means the explicit qualification criteria below are satisfied; it is not a promise of zero provider outages or a mathematically maximal cache-hit rate.

Owner: reviewer infrastructure, [issue #337](https://github.com/popcre/ai-devops/issues/337), registered under repository-throughput parent [#159](https://github.com/popcre/ai-devops/issues/159). Authored September 8, 2026; coding-boundary refactor September 11, 2026. [Execution handoff](HANDOFF.d/2026-09-08T1957Z-edge-dev-codex-reviewer-reliability-plan.md).

## STATUS — implementation, not planning progress

**2026-09-11 delivery checkpoint:** #417's failed landing-evidence job was a fail-closed timing race: its required pull-request run was still queued, not failed. #333 merged as `d2e4327d9ef5d2b80219a874e4a4a605b2a19595`; #395 merged as `972d03b601dd18815627e1d268f3a7375516820b`. Both passed their product and fallback gates, received exact-head independent approval, were installed from current `main`, and have live retained-result proof. #395's 33 frozen-round evidence gaps are preserved as incidents with repair evidence; their unknowable historical causes were not inferred. The round remains open for #398, which still runs last inside #337; #166 remains last for #159. #271's private LPAC prototype is not production qualification.

| Coding owner | State | Updated | Required evidence before complete |
|---|---|---|---|
| [#393](https://github.com/popcre/ai-devops/issues/393) source identity and complete input | Open; nine-wrapper contract merged and installed as `d8e7450d` via PR #410 | 2026-09-11 | [Exact review, complete CI, installed hashes and identity smoke](tests/verification/reviewer-reliability/issue-393-source-identity.md); governed live comparison and affected incident reconciliation remain |
| [#394](https://github.com/popcre/ai-devops/issues/394) terminal outcomes and diagnostics | Open; DeepSeek Unicode/ordinary terminal slice merged, installed and live verified | 2026-09-11 | PR #405 merge `068c6cb9f07c`; 85/0/0 focused checks, exact-head GLM APPROVE, CI `34563556041` and queue `34567376452` successful; installed synthetic Unicode review/replay passed. Governed terminal parity remains in progress |
| [#395](https://github.com/popcre/ai-devops/issues/395) durable evidence and interruption provenance | Complete; merged, installed and live verified | 2026-09-11 | [Exact review, CI, installed recovery proof and 33 preserved incident resolutions](tests/verification/reviewer-reliability/issue-395-durable-evidence.md) |
| [#396](https://github.com/popcre/ai-devops/issues/396) availability, cooldown, and concurrency | Open; Grok auth concurrency slice installed | 2026-09-11 | Auth slice merged `e3b4700d`; allocation/cooldown matrix and governed live proof remain |
| [#397](https://github.com/popcre/ai-devops/issues/397) provider execution and same-session recovery | Open | 2026-09-11 | Provider progress/finalization/restart matrix and live canaries |
| [#271](https://github.com/popcre/ai-devops/issues/271) Codex Windows read-only sandbox | Open; native runtime cannot enforce root-read denial; [measured evidence](docs/codex-windows-containment-2026-09-11.md) | 2026-09-11 | Marker read/write denial proven; outside-read isolation and full network denial remain unqualified; live review pending |
| [#333](https://github.com/popcre/ai-devops/issues/333) truthful usage and measured context efficiency | Complete; merged, installed and live verified | 2026-09-11 | [Pinned semantics, exact review, CI, installed source and retained-result proof](tests/verification/reviewer-reliability/issue-333-truthful-usage.md); no compaction changes |
| [#169](https://github.com/popcre/ai-devops/issues/169) shared wrapper infrastructure | Installed acceptance complete | 2026-09-11 | [Installed hash, fixture adapter, both migrated launcher checks and incident audit](tests/verification/reviewer-reliability/issue-169-installed-primitives.md); allocation/recovery remain #396/#397 |
| [#398](https://github.com/popcre/ai-devops/issues/398) integrated qualification and maintenance closure | Open; runs last inside #337 | 2026-09-11 | All 198 dispositions, installed nine-provider matrix, bounded recurrence scan |

**Fresh-session start:** select one registered child by dependency order below and keep its code/test changes inside that coding boundary. Update this table as each slice lands. An open tracking issue or a passing doctor is not completion evidence. #398 runs only after the component children; #166 remains the final #159 cutover.

The bounded #405 installed proof uses wrapper SHA-256
`be0f1cdd8708355d76285e7c3ba682fe4e137ec3fb8097a13ea30434098b47c6`.
One paid synthetic formal-review turn preserved the exact Unicode sentinel,
returned one terminal APPROVE, and retained the same text for stored replay;
private output SHA-256 is
`fa0c6506690c8cb1d8bb98ff27b08453b1693086985748134817014162a53434`.
The affected private incident received an append-only partial resolution:
its separate large-attachment failure still awaits #393 installed live proof.

The bounded queue-evidence repair [PR #411](https://github.com/popcre/ai-devops/pull/411)
is installed at `be5f1e2c25e12abc4b0c57cf1f1f11ffc83811b1`: 42 focused
checks passed, exact-head GLM approved `d8f8c0a1d338c507ce884888471b3de17eb37ea7`,
and queue `34574548945` succeeded. Installed helper SHA-256
`7e37e1bc87c3ac1a7858fbe2dd0bdf2afdf002a6799fad8efb6e31b747341d042`
was independently verified; its matcher accepted the qualified captured
run `34567280854` while retaining every required code safety check. This is
bounded #161/#164 acceptance; #337/#159 and final #398/#166 remain open.

The maintenance round remains `0c62f3dffce145c4b2768855b912b958` with all 198 original candidates. Its installed `show` and exact-round `start --resume` commands work again after an unrelated analysis sidecar was moved out of the checkpoint directory into private analysis storage. The frozen started record still hashes to `aad9e0f327a135d8b684f03768b702aa675981f738924b468215ef61aeefa8f0`. No candidate was reset or disposition invented; final reconciliation remains #398's last step.

**#396 installed slice, 2026-09-11:** [PR #408](https://github.com/popcre/ai-devops/pull/408) merged as `e3b4700d1005088065740200a70d68d7574a4243` after exact-head independent Grok APPROVE on `84274fd629fec8324ecef58373c8b8f011faabb3` and passing required CI/merge queue. Final local Grok suite: 226 passed, zero failed/skipped; focused authentication regressions: seven passed, zero failed/skipped. Installed wrapper SHA256 `c40012683a67f87878c90bb5b4acfd8431d02c1f032fa2afc6e72e723e115260` matches the tested source. Two concurrent initializers against the actual installed authentication link passed 100 readability/same-inode checks without replacing the existing credential inode; no credential values were read and no provider request was made. The matching private concurrency incident received append-only repair evidence. This does not close the broader availability/cooldown programme or classify the frozen 198-entry round.

## 1. Goal and acceptance model

Accuracy comes first: the reviewer must evaluate the intended base/head and current files. Reliability comes next: a paid completion survives local reporting failure, and an incomplete response is never promoted to a verdict. Efficiency is accepted only after those properties pass.

Define three separate things throughout implementation:

- **Provider prompt/context cache:** provider reuse of an identical token prefix. It can expire independently of local state.
- **Conversation persistence:** retaining and resuming the exact provider conversation and its task decisions. Automatic compaction may summarize earlier reasoning even while the session ID stays unchanged.
- **Local caches and code persistence:** on-disk runtime/session data, and implementation source/artifacts. A reconstructed Git tree does not restore ignored dependencies, build caches, credentials, or external side effects.

A high cached-token percentage with repeated large reads can still cost more than a shorter review. Evaluate uncached input, total input, output, elapsed time, successful verdicts, retained facts, and repeated tool reads together. Unknown counters stay unknown.

## 2. What this toolkit is

`popcre/ai-devops` is a public Bash/Python/PowerShell recovery toolkit for Albert's AI development workflow. It is not an application server or database. Source is installed through managed launchers/symlinks and protected configuration. Primary Windows installation: `C:/repos/ai-devops`; tasks must use independent current-upstream worktrees. Linux support remains required. Inspect only the relevant machine section of `templates/system/machine-atlas.md` when qualifying another host.

Nine review adapters are `bin/ai-claude-review`, `ai-codex-review`, `ai-grok-review`, `ai-glm`, `ai-muse`, `ai-kimi`, `ai-qwen`, `ai-gemini`, and `ai-deepseek-agent`. GLM runs through an OpenCode server; Muse uses an isolated direct OpenCode process with persistent data directories. GLM also provides disposable implementation jobs. Kimi and Qwen provide implementation continuation with reconstructed code state. Other implementation wrappers are regression dependencies when they share touched helpers, not an invitation to redesign every provider.

`u2giants/shared-db` owns governed reviewer allocation and verdict recording in `scripts/manage-migration-author-lanes.mjs` and `scripts/run-governed-review.mjs`. That integration is repository-maintenance code, not a database structure change. Re-resolve its current routing contract before creating a consumer issue or editing code; do not enter the database orchestrator's structure lane for tooling maintenance. Any actual database structure work is out of scope.

## 3. Trigger and reproducible evidence

Albert requested review of recent reviewer failures and a comprehensive audit of context caching, prompt caching, and session persistence across all reviewers/wrappers/OpenCode paths, then explicitly requested this implementation plan.

The private audit examined 37 incident records and froze a first real maintenance round with 198 candidates: 25 existing unresolved incidents, 46 failed invocations, four invocations lacking terminal proof, and 123 scoreboard outcomes requiring classification. These are categories of evidence, not 198 distinct defects. The restored round is `0c62f3dffce145c4b2768855b912b958`; its frozen boundary must never be reset. New events after that boundary belong to the next interval.

The private evidence is discoverable through `bin/ai-reviewer-issue path`, `list`, and `maintenance show`. Do not publish the private report, source paths within private repositories, raw provider bodies, or conversation transcripts. The audit is an inventory, not a closed repair round.

Reproduction for the strongest source defect: create an isolated fixture with local `main` at A, `origin/main` advanced to B, and feature HEAD C containing only one new feature after B. Build a review snapshot and default packet. At the planning baseline, snapshot creation prefers A and packet selection prefers local main, so the reviewer can receive A..C instead of the intended B..C. Add a merge-commit variant and an explicit non-main target; the solution must handle both, not merely reorder one loop.

The 67 formerly ambiguous scoreboard records now divide into 33 confirmed Codex Windows read-sandbox denials, one legitimate evidence-based BLOCKED review, 31 referenced reports no longer retained, and two interruptions without retained cause. The remaining new uncovered symptoms are a DeepSeek Windows output-encoding failure, Qwen content-filter failure classified as generic stderr, Muse start failure without durable evidence, and Grok turn-limit cancellation without a terminal result. A symptom is not a proven root cause; #394 and #395 own the diagnostic and retention contracts that make the causes provable.

## 4. Scope and consolidation

This issue is a programme parent. Each remaining change has exactly one coding-boundary child:

| Coding boundary | Canonical owner | Absorbed evidence/issues |
|---|---|---|
| Packet/snapshot source identity and completeness | #393 | #179, #188, #189, PR #344 |
| Terminal result parsing and failure diagnostics | #394 | #182, #183, #217, #218; four newly uncovered failures |
| Durable report publication and interruption provenance | #395 | 31 missing-report and two unknown-interruption records; completed #212 |
| Availability, cooldown, allocation, and concurrency | #396 | #233, #304; #169 Kimi disposition; #312 diagnostics |
| Provider-turn progress, finalization, and recovery | #397 | #177, #233, #351; completed #322/PR #330 |
| Codex Windows read-only enforcement | #271 | duplicate #290 and 33 confirmed maintenance records |
| Usage, cache, and measured context efficiency | #333 | `plan_reviewer-cache-efficiency.md` and old plan Steps 7/9 |
| Shared provider-wrapper primitives | #169 | Extraction only after provider-specific contracts exist |
| Installed integration and 198-entry closure | #398 | #308 maintenance infrastructure and all component evidence |

Old symptom issues are evidence, not parallel implementation owners. Transfer their still-valid reproductions and acceptance requirements to the canonical child, then close them as superseded without claiming the defect is fixed. Investigation mode #253–#257, credential maintenance #326, and reviewer-assisted problem solving #198 remain separate capabilities/dependencies. Retire this handoff only when #337 and #398 are truly complete.

**Not in this plan:** model/provider switching; permanent reviewer retirement or automatic re-enablement; raising global timeouts; removing review guards; changing production/cloud infrastructure; database/schema/data work; purchasing quota; credential rotation; shared-server redesign; new memory plugins; automatic application of implementation patches; deleting provider/session histories; global instruction overhaul; CI redesign. A planning request does not authorize implementation deployment. Execute this plan when implementation is requested; ordinary scoped implementation work then follows existing authorization rules.

## 5. Current code and delivery baseline

Current refactor source is ai-devops commit `b5a08cb55b0b4f71debcad272c591b3d3a026cc3`. Older line references below came from planning commit `d5522d9a8bcdef49db917d37002166aaaff5be73`; re-find by symbol after drift. Active PR #344 owns the current #393 source-base slice but remains blocked by failing reviewer-safety checks.

- `bin/ai-review-packet:179`: default order `main`, `master`, `origin/main`, `origin/master`. `bin/ai-review-sandbox:246`: copies local base branch before consulting remote. This establishes the wrong-base mechanism.
- `bin/ai-deepseek-agent:268–329`: sends persisted `messages`, extracts response content, appends conversation; usage is discarded at `:303`. Transcript JSON is the next request body, not a place for metrics.
- `bin/ai-muse:123`: persistent isolated XDG data/state/cache paths; `:250` exact `--session`; `:285–292` stream/identity checks; `:290` last step token selection; `:319` opaque token report; `:334` preserves paid completion before local checks.
- `bin/ai-glm:930–969`: reads returned token object and writes reports; `cmd_new`/`cmd_ask` retain exact OpenCode identity. `:1331–1479` implementation finalization records and exports results. Do not substitute an assumption that one token object means the entire tool-using turn.
- `bin/ai-grok-review:1160`, `:1268`: absent cached tokens/cost can become zero. Session prefix and directory are frozen. Preserve exact-work cancellation/uncertainty locking.
- `bin/ai-codex-review:20`: governed read-only command, explicit GPT-5.6 low/medium setting. `doctor` validates command and dependencies but is not an end-to-end file-read test. Claude explicitly uses `--no-session-persistence`; fresh approval calls are intentional.
- `bin/ai-kimi:1238`, `:1883`: durable upstream binding; `:1943–1985`: continuation recovery and exact session checks. Qwen has corresponding exact resume and canonical-state refusal paths. Gemini requires fixed source/model/conversation identity on follow-up.
- `config/opencode/version` is 1.18.12. Both installed OpenCode configuration files matched their repository copies during the audit. That proves file parity, not the effective settings of every running process. GLM has no explicit compaction block; Muse has auto compaction, pruning disabled, eight tail turns and 32,768 reserved tokens, with a cache-key/24-hour-retention request.
- #312 landed as `a570069a95d06c271895a33565785c2784e32a8b`. Its capability matrix says Kimi/Grok/GLM have no qualified automatic non-generating quota interfaces; all production adapters return unknown with zero network calls. Do not infer that implemented tri-state plumbing already prevents every repeated exhausted assignment.
- PR #330 was OPEN at head `f7cc2739ca3174508669dcb5b4f7ab69d65a7825`; Linux had passed and Windows checks were running. Its body reports a 3.888-second identity result. Treat that as PR-reported evidence until exact review, merge, installation and default qualification are verified.
- Current shared-db remote main was inspected at `0f22de12562b7250ebf70fb07502e0fbce429cb3`, newer than its canonical local checkout. `reviewerExecutionPreflight` at line 4112 checks approved wrapper, exact head, clean tree and doctor; its returned readiness does not itself include account-capacity state. Do not use the stale local checkout as live integration proof.

## 6. Findings and research still required

**Proven by source:** wrong default base preference exists at both snapshot and packet layers; DeepSeek drops usage; Muse chooses the last token event; Grok substitutes zeros for missing counters. These can proceed to reproducing fixtures and targeted fixes.

**Established observations, cause not proven:** GLM timeout versus local endpoint failure; Qwen's provider-complete versus finalization failure; Codex's Windows read restriction. Diagnose these separately. Do not attribute them to CPU, antivirus, permissions, quota, or caching without exact failure-window evidence.

**Capacity gap:** unsupported quota APIs cannot be manufactured. An observed provider quota refusal can support a separate scoped temporary backoff decision; it cannot prove authoritative remaining capacity or a reset time. Verify whether current allocation already consumes such evidence before adding it.

**Measurement gap:** local persistence counts establish records exist, not that all provider sessions remain resumable. A report of substantial cached input does not prove economical behavior. One recorded Grok consultation used over a million tokens across 19 steps despite substantial caching; its useful answer does not erase the repeated-work concern.

**Pinned-version research gate:** before any token aggregation or compaction change, inspect the installed 1.18.12 contract fixtures (`tests/fixtures/muse-opencode/`), source at the exact release if available, and a bounded synthetic run. Current online OpenCode documentation may describe a newer version. Determine whether events are per-step or cumulative, whether reasoning is included in output, how duplicate parts are identified, and whether a terminal usage event can be absent even when the session persisted. Upstream bug reports are research leads, not proof that this installed build has that defect.

## 7. Rejected approaches and past failures

1. Deterministic approval snapshot paths as a cache cure: earlier Claude measurements did not improve cache reads. Codex lacked exposed cache split. Do not revive without new contrary evidence; fresh approval isolation remains locked.
2. Digest-gated snapshot reuse: the old digest cannot cover everything the reviewer can read. Preserve fresh self-contained snapshots and full evidence verification.
3. Shared Muse/GLM OpenCode server: Muse server mode previously failed authorization and couples failure domains. Exact direct-session continuation already exists.
4. Increasing all Qwen timeouts: a process-only larger allowance restored qualification in a later attempt but did not explain the earlier post-write failure or fix default identity latency. PR #330 addresses that latency separately.
5. Treating unknown usage as zero, summing cumulative usage twice, or adding usage to DeepSeek messages: all create misleading cost claims or change future prompts.
6. Replaying a completed paid turn after a report-write failure: duplicate spend and potentially divergent evidence. Finalize or reconcile the exact retained turn.
7. Generating `/usage` prompts or guessing private quota endpoints: these are not qualified non-generating capacity checks. Do not scrape auth state or buy capacity.
8. Removing sandbox restrictions, abandoning source freshness checks, disabling a broken reviewer, or deleting uncertain state: hides symptoms by removing capability/evidence.
9. Turning all GLM implementation jobs into persistent sessions: current disposable-job semantics are intentional. Qualify artifact continuity; introduce conversational implementation only under a separate explicit requirement.
10. Treating docs, issue status, historical metadata, or a controlled checkpoint demo as live repair closure: none proves the real backlog or installed business flow.

## 8. Design decisions — September 8, 2026

**Locked:** preserve supported capabilities and read-only boundaries; exact base/head binding end-to-end; immutable incident evidence; strict terminal verdict rules; separate caller/repository identities; per-session/exact-work locking rather than global serialization; no invented metrics; one owner for each shared helper; no raw private evidence in this public repository; no permanent model or provider disposition change.

**Selected architecture:** extend existing packet, preflight, lifecycle/event and report paths. Keep account-exhaustion observations separate from authoritative quota state. Store normalized metrics as a sidecar/report with explicit provenance and scope; do not mutate prompts to record metrics. Keep the capability to inspect full doctor results while providing a fast qualified identity path. Retain fresh Claude/Codex approvals and named advisory continuation.

**Implementation judgment, bounded by gates:** helper versus local formatter based on actual reuse; exact scoped backoff duration from existing configured cooldown policy and observed evidence, never an invented provider reset; whether an OpenCode metric is incremental or cumulative from the pinned contract; context/compaction tuning only after controlled paired evidence. No owner decision is needed to write or validate this plan. Credential purchases, capability reductions, or production mutations remain outside scope and must not be silently introduced.

## 9. Ordered implementation phases

### Phase A — evidence and correctness

#### Programme gate. Refresh current ownership and freeze the right work (#337)

Read AGENTS, `docs/task-router.md`, this STATUS and relevant child STATUS. Fetch ai-devops main; create a dedicated current-upstream worktree. Inspect open PRs, especially #330, and current installation identity. Resolve shared-db upstream through GitHub before creating its own worktree for integration changes. Check live runner jobs before any local suite. Reuse the current real maintenance round via `bin/ai-reviewer-issue maintenance show` and `maintenance start --resume ROUND-ID`; obtain ROUND-ID from show, never guess or reset it. If another owner is actively classifying it, agree on disjoint candidate ownership or keep this slice read-only.

Gate: retained private source/version/owner inventory, no competing checkout edits, exact frozen lower/upper boundaries, and explicit disposition for each dependency. Depends on nothing. This step authorizes no provider retry.

#### Maintenance accounting. Account for every candidate before repair closure (#398)

Use `tools/reviewer_maintenance.py` through `bin/ai-reviewer-issue`, following `docs/reviewer-issues.md`. Link exact existing incidents with `maintenance classify`; use `maintenance record` for a newly established defect. Classify expected refusals, quota, application failures, duplicate events and user cancellation only with exact evidence. An orphaned start needs current worker proof, not age. Audit all nine providers' supporting metadata, lifecycle failures, owned logs and known DeepSeek sidecars for pre-journal coverage; never open raw session transcripts as a shortcut.

For each incident preserve: observed symptom, evidence availability, current code disposition, root-cause confidence, owner, planned step, and exact closure gate. Unrecoverable overwritten history is an explicit blocker. New post-boundary failures go into the next round and current incident ledger; do not expand the frozen upper boundary.

Gate: every candidate has an accountable classification or specifically documented blocker; no unexplained event is dropped. Full completion waits for #398's integrated acceptance. Classification may proceed alongside disjoint component diagnosis.

#### Source identity. Bind the intended review base through the entire pipeline (#393)

Change `bin/ai-review-sandbox` base-ref preservation and `bin/ai-review-packet` base resolution together. Trace every packet caller in the nine wrappers and consumer `run-governed-review.mjs`. For governed PR reviews, resolve target branch/base/head using current trusted PR data, validate repository/ancestry/object existence, and carry immutable resolved SHAs through snapshot and manifest. A SHA must be locally resolvable; never silently fetch arbitrary prompt-supplied remotes. A mid-run base/head movement invalidates authorization and requires a newly bound run, not rewritten old evidence.

For standalone reviews preserve explicit `--base` behavior. Define default semantics for feature branches, merge commits, root commits and HEAD-on-target. Do not silently fall back to HEAD~1 for a governed PR when target evidence is unavailable. A non-main PR target must work. Preserve existing root-commit standalone support, and make default/fallback scope visible in the manifest. Exclude neither untracked files nor evidence paths to make freshness pass.

Gate: `tests/test-ai-review-packet.sh` and `tests/test-ai-review-sandbox.sh` prove A/B/C stale-main reproduction fixed, merge-commit comparison correct, non-main target honored, explicit SHA preserved, missing/mismatched target rejected and source movement rejected. Add consumer tests to `scripts/run-governed-review.test.mjs` and `scripts/manage-migration-author-lanes.test.mjs` after verifying those test owners at current main. Live synthetic PR comparison must match GitHub's intended changed-file set and sealed base/head; a generic APPROVE alone is insufficient. Depends on 0.

**Cut point:** land #393 through the delivery gate, update evidence and child issues, then use `fresh-session` if needed. Re-read the remaining child contracts before continuing.

### Phase B — failure prevention and recovery

#### Availability. Avoid assigning repeatedly to an account known exhausted (#396)

2026-09-11 coding evidence: the versioned preflight store and scoped admission
contract are implemented in an isolated worktree. Initial verification passed
seven behavioral cases and 92 preflight assertions. [Scope, migration, concurrency
and remaining delivery gates](tests/verification/reviewer-reliability/issue-396-scoped-admission.md).
Terminal/consumer integration and installed acceptance remain open.

Trace `bin/ai-review-preflight` capacity/quarantine paths, `config/reviewer-capacity.json`, Kimi terminal `usage-limit` classification, diagnostic observation hooks, and shared-db allocation/preflight/failure recording. Existing adapters remain unknown when unsupported. Add only the missing connection from a proven terminal exhaustion observation to a scoped temporary admission backoff. Prefer the existing preflight/quarantine store; if its provider-only key cannot safely represent credential-profile/model scope, extend its versioned schema with migration tests rather than create a second store.

Store only opaque non-secret account/profile identity, provider/model scope where evidenced, source run identity, observation time, expiry and reason. Do not hash or expose credential values to construct identity. If scope cannot be established, do not apply an account-wide exclusion. Expiry means eligible for a guarded attempt, not proven quota available. One failed attempt may establish backoff; concurrent contenders must not all race through an already-known refusal. Preserve any review artifact before release/replacement; manual ref deletion and invented verdicts remain forbidden.

Gate: fake clock/transport tests show repeat dispatch submits zero provider calls during an applicable backoff, different scope stays usable, unknown remains usable, stale/unscopable evidence cannot block indefinitely, expiry permits a guarded attempt, and allocation plus dispatch recheck share the same reason. Local dependency failures must never become quota exclusions. Test both Kimi durable worker and ordinary wrapper paths. Live validation uses an existing real refusal if still applicable; do not intentionally exhaust an account. Depends on 0 and scope evidence from 1; #312 is a completed prerequisite.

#### Session recovery. Reuse Qwen's fast identity repair; diagnose the remaining recovery gap (#397)

First verify PR #330's current head/review/merge/installation and the default qualification result. Do not reimplement its one-pass identity contract in `bin/ai-review-preflight`/`bin/ai-qwen`. If open, leave ownership with that task and continue independent steps. Its reported passing test counts do not prove installed completion.

For remaining failures instrument the exact `ai-qwen` turn/finalization paths: provider completion, runtime/preloader fingerprint validation, report publication and pending-state transition. Capture field-level comparison outcomes and child exit/timing without secret values or raw provider text. Retain original qualification evidence on refusal; do not manually manufacture a qualified record. Verify `reconcile`/recovery behavior actually supported by this wrapper before invoking it. Add an idempotent local finalizer only if a proven completed turn can be finalized without another provider call.

Gate: default identity/qualification budgets pass on the installed build; changed, duplicate, missing and malformed fingerprints refuse; successful provider output plus failed local write is recoverable without generating again; unproven output stays incomplete; timeout cancellation state is truthful. Existing `tests/test-ai-qwen.sh` and `tests/test-ai-review-preflight.sh` remain green. Depends on 0; startup acceptance depends on PR #330, not provider recovery diagnosis.

#### Session recovery. Diagnose GLM transport and progress with exact failure-window evidence (#397)

Use `bin/ai-glm` `send_prompt`/`await_turn`, existing #312 diagnostic hooks and implementation v3 records. Capture bounded loopback health/permission latency, process/listener identity, last actual provider progress and cancellation acknowledgement during failure. A listener existing does not prove a responsive server; an unanswered endpoint does not prove a denied permission. First reproduce with mocked local endpoint stalls and delayed provider progress; then choose the smallest fix supported by observations.

If server recovery is necessary, qualify it in a dedicated test instance; never restart the shared production reviewer server while another task uses it. Keep exact sessions and paid completion across a local transport outage. Preserve the narrow TodoWrite action contract and read-only tools. If no causal reproduction exists, leave the incident partial and identify the exact missing telemetry rather than tuning speculative timeouts.

Gate: `tests/test-ai-glm.sh` distinguishes stalled transport, real permission denial, quiet healthy provider work and completed-but-unpublished output; no duplicate submission; recovery resumes the same session. If setup/recovery scripts change, `tests/test-windows-scripts.sh` plus the documented owned-child crash/restart canary are required. Depends on the programme gate and existing diagnostics; live crash proof requires an isolated instance or a proven idle maintenance window.

#### Terminal contract. Standardize outcomes and failure diagnostics (#394)

Make exit status, stdout, report state, and governed consumption agree on one terminal result. Add provider-shaped fixtures for the newly uncovered DeepSeek Windows encoding failure, Qwen content-filter/DataInspectionFailed path, Muse start failure, and Grok turn-limit cancellation, plus the absorbed #182/#183/#217/#218 cases. Preserve sanitized terminal diagnostics before cleanup and distinguish a legitimate evidence-based BLOCKED review from infrastructure failure.

Gate: every supported wrapper returns one parseable verdict or stable failure reason; malformed, missing, trailing, filtered, encoding-failed, start-failed, tool-denied, cancelled, and turn-limited outputs cannot become generic success or approval. The governed consumer records the same reason.

#### Evidence durability. Publish reports and interruption provenance before cleanup (#395)

Write sanitized reports and terminal metadata atomically to the central private evidence store before deleting disposable worktrees. Record interruption source, actor class, phase, last proven provider state, and paid-work uncertainty. Cleanup must refuse when required evidence publication has not completed. This absorbs the 31 missing-report and two unknown-interruption maintenance records while reusing completed #212 metadata work.

Gate: crash, cleanup, and race fixtures preserve exact invocation linkage; user cancellation, scheduler interruption, timeout, process death, and unknown remain distinct; publication failure neither erases paid work nor causes replay. Historical unknowns remain unknown.

#### Codex containment. Restore Codex's original read-only capability (#271)

Reproduce in a synthetic repository using the exact validated `CODEX_CMD` from `bin/ai-codex-review` and the current Windows CLI/build. Compare CLI process execution, private-path ACL setup, sandbox root spelling and source snapshot access. Keep authentication private. Determine whether denial occurs before shell launch, at path authorization, or inside a supported sandbox configuration. Inspect current official OpenAI documentation/installed CLI source or help before selecting a platform repair.

Preserve sandbox enforcement, allowed command shape and GPT-5.6 low/medium reasoning. Do not change to unrestricted mode, delegate file reads to a privileged helper as a bypass, or declare read success from a doctor header. If the supported runtime cannot satisfy both read and deny-write tests, this is an external blocker; retain capability requirements and do not restore its retired consumer rotation without separate authorization.

Gate: `tests/test-ai-codex-review.sh` plus a live synthetic exact-head review reads a known marker and the intended diff; attempted source write and out-of-boundary sentinel read fail; final verdict/report hashes match the reviewed head. #393 source identity must be in the integrated live path.

**Cut point:** each repair lands independently through the delivery gate. Do not hold proven accuracy/observability fixes behind an unrelated provider outage. Re-read the measurement/closure phases after drift.

### Phase C — truthful telemetry and persistent state

#### Usage. Normalize usage without changing requests or verdicts (#333)

Implement #333 in `bin/ai-deepseek-agent` and `bin/ai-muse`; extend Grok's missing-field formatting and GLM's report scope only as justified. Keep usage out of stdout if stdout is the governed terminal-verdict channel. For DeepSeek append per-turn usage to `<session>.usage.jsonl`, not `<session>.usage.json` (the latter can be mistaken for a session). Publish the successfully paid response/conversation atomically before any optional metrics failure can cause a replay. A sidecar failure must be visible but must not erase the paid result or create a false whole-turn total.

Define report fields: provider/model/version, session/run/turn identity, scope (`step`, `turn`, or `session`), raw counter provenance, normalized input/cache-read/cache-write/output/reasoning/cost, availability reason, completeness, and counting semantics. Preserve a true returned zero. Reject or mark invalid nonnumeric/negative counters; unknown must propagate when a required component is absent. Separate provider-returned price/cost from an explicitly dated estimate. No sum of reasoning and output until overlap semantics are proven.

For Muse/OpenCode deduplicate by qualified stable part/message identity, never text equality. Establish incremental versus cumulative usage with pinned-version multi-step fixtures before summing. Do not add message aggregate plus its component parts. Missing final usage does not authorize inventing a value or accepting an unproven verdict. Use supported exact-session inspection for recovery where qualified; never edit OpenCode's raw database.

Gate: tests in `test-ai-deepseek-agent.sh`, `test-ai-muse.sh`, `test-ai-grok-review.sh`, `test-ai-glm.sh` and `test-muse-opencode-contract.sh` cover missing/null/zero/malformed/nested counters, two tool steps, duplicate events, cumulative counters, compaction, missing final usage, sidecar write failure and resumed turn. Requests and existing terminal verdicts remain byte-equivalent in deterministic fixtures. Depends on 0 and the pinned-schema research gate in §6.

#### Session recovery. Qualify persistence for every advertised path (#397, with #395 evidence publication)

Create a qualification record under the existing `tests/verification/reviewer-reliability/` home, with synthetic fixtures beside the relevant existing provider tests. Do not create a competing generic harness. For Grok, GLM, Muse, Kimi, Qwen, Gemini and DeepSeek verify fresh task → explicit follow-up → wrapper process exit/restart → exact continuation. Use two repository/caller identities and concurrent independent names to prove separation; an attempt to continue an ambiguous/changed identity must refuse. Check retained decision-critical facts and original evidence, not only the session ID.

Claude/Codex qualification is fresh-review artifact durability and no accidental inherited conversation, not named-session resume. For providers lacking telemetry, mark cache metrics unsupported with their exact tested interface/version; that is an honest capability limit, not a fabricated failure or pass.

GLM implementation must preserve complete/incomplete binary patches, ownership, abort semantics and one-shot documentation. Kimi/Qwen implementation continuation must preserve canonical Git-visible code and block mismatched conversations while explicitly describing lost ignored build caches. Cross-test restart, export failure, source movement and interrupted save. Never auto-apply generated patches. Test OpenCode GLM service restart separately from Muse direct process restart, preserving their separate stores.

Gate: every provider/path cell is Pass, Unsupported-by-contract, or Blocked-with-exact-evidence; no blank cell, and no advertised supported continuation is marked unsupported just to pass. Relevant existing wrapper/implementation suites and the synthetic live matrix agree. Depends on individual reliability repairs for final pass; safe offline fixtures can begin earlier.

### Phase D — measured tuning and delivery

#### Efficiency. Tune only measured inefficiency (#333)

Use existing provider test/probe paths and `tests/probes/muse-opencode-contract.sh`. Select a synthetic multi-file review with planted defects and a fixed expected result, a follow-up asking about a previously established fact, and a bounded compaction/restart case. Run three paired samples of unchanged baseline and candidate with equivalent task/source/model/tool settings. Alternate order; record cache warming, timing and retention interval. Preserve existing per-run limits. Stop immediately on incorrect evidence, lost facts, duplicate paid work, quota refusal or unproven cancellation. No unchanged retry after a deterministic failure.

Record input/cache/output/cost availability, latency, tool calls and repeated reads, step count, compaction occurrence and answer correctness. Cache-hit ratio uses cached input divided by eligible total input, never all tokens including output. Compare known billed cost only when pricing/provenance is valid; do not use OpenCode local disk usage as account quota. Collect only synthetic prompts for shareable evidence.

Candidate changes may include fixing packet path retries, reducing redundant per-turn boilerplate, referencing unchanged sealed material instead of reattaching it, and adjusting compaction/pruning/reserved context only when pinned-version behavior and retained-fact tests justify it. GLM defaults or Muse pruning-off are not defects without this evidence. Preserve all ruling/decision-critical content; summaries need provenance and re-reading access. Do not modify a stable system prefix on every follow-up.

Acceptance: all planted defects and retained-fact checks pass; safety checks unchanged; candidate improves median known cost or median elapsed time by at least 10% across the three pairs with no greater than 10% regression in the other measured dimension. This is a practical local acceptance threshold, not a statistical generalization. If counters are unavailable, claim time improvement only. If noise or tradeoffs defeat the gate, retain baseline and record no justified tuning; do not widen scope or run an indefinite benchmark. No provider is required to hit an arbitrary cache percentage. Depends on 7–8 for trusted interpretation.

#### Delivery gate. Deliver each coding child safely

For each repository: current-upstream isolated worktree, owned files only, correct Albert Git identity, focused regression suite then the current required verification route. Wrapper/evidence/safety-path changes require one read-only independent exact-head final review. Use the approved wrapper/skill for that review; no self-approval. Keep concurrent installations and Windows suite lanes exclusive after current job inspection. Retain skipped counts and blockers.

Commit/push a branch, inspect PR changed files/body/review threads, merge through the current repository policy and verify the intended change on fetched origin/main. Use `bin/ai-pr-wait` for bounded event-aware CI; do not rerun identical green checks. The current prose-only planning PR uses the standing immediate administrative squash policy after its file list is verified; that exception does not apply to implementation.

Installation is deployment: read `docs/deployment.md`, prove the installed launcher targets and active processes, back up exact configuration, serialize the landing/install, preserve machine-local values, and validate effective installed hashes/default behavior. No service restart while another task owns sessions. Re-run only live checks needed to prove the installed changed path, not unchanged green suites. Qualify Windows and supported Linux behavior; lack of a reachable Linux host is a named pending gate, not a claimed pass.

Gate: exact source/review/CI/merge/install identities and synthetic live artifacts exist for each changed path. Depends on its slice's tests; runs repeatedly as delivery work, not as a final monolithic release.

#### Integrated acceptance. Close the real repair round and reconcile owners (#398)

Resolve every affected incident through `ai-reviewer-issue resolve` with exact merged repair commit, repository when cross-repo, and evidence. Use partially-resolved only where some symptoms remain, with `maintenance carry-forward` and remaining-work proof. No resolution by similarity alone. Run maintenance completion with the documented proof JSON: repair_commit, tests, independent_review, installation, live and first-round legacy_audit. Open unexplained candidates or broken continuity keep the round open. Source loss cannot be waved away; a historical coverage blocker means full #337 closure is blocked.

Perform a bounded next-round scan for failures arriving during execution so “current” acceptance does not silently stop at the old cutoff. Freeze that next interval, account for every candidate and carry legitimately running work with current proof. Do not chase an infinitely moving upper boundary; report the exact completed boundary and any later observed work separately.

Update this STATUS, #333 and other affected child STATUS, `docs/reviewer-issues.md`, relevant provider docs and verification evidence. Correct stale cache-plan statements about repository policy/retired providers when finishing its scope, preserving rejected-approach history. Retire only handoffs whose completion and unique-obligation transfer are proven. Close #337 only when all supported-path gates and real checkpoint closure pass; no synthetic demo substitutes for the backlog.

Gate: every incident has one evidence-backed disposition, installed matrix is complete, real round completion succeeds, and remaining post-boundary work is explicitly identified. Depends on 1–10.

## 10. Required tests and evidence storage

Existing suites are the owners; add named regression cases there, not a mirrored implementation test framework. Execute Bash through Git Bash on Windows. Example focused invocation: `bash tests/test-ai-review-packet.sh`. Resolve current broad required commands from `docs/development.md` and `.github/workflows/verify.yml`; do not run `tests/test-all.sh` beside active Windows CI.

Mandatory behavioral cases by slice:

- Base: stale local main; non-main target; merge commit; missing target; root commit standalone; explicit base; target/head race; consumer manifest mismatch; untracked-source change.
- Capacity: scoped refusal; different profile; unsupported adapter; expired evidence; no reset supplied; concurrent admission; no provider call on applicable backoff; no suppression of valid artifact.
- Qwen/GLM/Codex: malformed identity; completed-provider/local-failure; uncertain cancellation; missing terminal event; stalled endpoint versus quiet provider; exact resume after restart; Codex reads permitted/writes denied/outside reads denied.
- Metrics: absent/zero/invalid; per-step versus cumulative; duplicate parts; reasoning overlap; report/sidecar failure after paid completion; no transcript pollution; no extra verdict line.
- Persistence: cross-caller and cross-repo separation; independent concurrency; same-session serialization; source/model mismatch; lost worker; idempotent artifact recovery; binary implementation state; ignored-cache disclosure; compaction recall.

Keep raw private diagnostics under the existing private issue/state homes. Put synthetic sanitized fixtures in existing `tests/fixtures/` provider homes and final redacted proof under `tests/verification/reviewer-reliability/`. Each record includes exact commit, installed versions, command, start/end, expected versus actual, counts including skips, and integrity hashes. Never commit the audit's private candidate/incident inventory or provider session databases.

## 11. Constraints and traps

- Canonical checkouts are landing-only. Never reset, clean, broadly stage, force-push or overwrite another task's files. PR #330 remains separately owned until verified complete.
- Public toolkit: raw licensed/private source, transcripts, secrets and auth files never enter Git or reviewer prompts. Load `secrets-to-1password` before credential handling; serialize access and use protected files/pipes.
- Independent exact-head review is mandatory for reviewer safety changes. Preserve terminal failure codes, evidence joins, caller identity and current source bindings; successful model prose is not authorization.
- Do not run local full suites on an active Windows runner host, cancel another run or restart a shared service. Use bounded waits and preserve unknown outcomes.
- No OS binary replacement. No broad runtime update without explicit version-policy qualification. GPT-5.6 must use low/medium only.
- No database migration or cloud/production mutation is needed. Any discovered genuine structure change must be separately routed; this plan conveys no such authority.
- Do not confuse installed configuration equality with effective running config, exact session ID with full context recall, or provider model context limits with account capacity.
- Plan publication is preparation. All implementation rows remain open until their evidence exists; no claim that the system is already repaired.
- At the end of every implementation phase, re-read every downstream phase through plan-end and report any assumption, interface, identifier, decision, or evidence drift before handing off or starting the next phase.

## 12. Access and environment

GitHub CLI access was verified for `popcre/ai-devops` and read-only `u2giants/shared-db` source/status. Planning worktree: `C:/repos/ai-devops-worktrees/reviewer-audit-20260908`, branch `codex/reviewer-audit-20260908`. Git Bash executable: `C:/Program Files/Git/bin/bash.exe`. Python, Node, jq and provider availability must be checked in the execution session before use; a historical installed version is not fresh proof.

GLM protected configuration is under the managed ai-devops configuration root; Muse uses its separate `ai-devops-muse/opencode-xdg/opencode` root. Source owners are `config/opencode/`, `config/opencode-muse/`, `bin/setup-opencode-glm.sh`, `bin/setup-opencode-glm.ps1`, `bin/setup-opencode-muse.sh`. Preserve existing secret indirection. The documented GLM reference is vault `vibe_coding`, item `GLM z.ai API`, field `api key`; DeepSeek/Muse references must be resolved from managed configuration via the secrets skill rather than invented item names. No credential acquisition is needed for offline planning/tests.

Use each supported wrapper's doctor/show/status for safe inspection, but inspect its documented side effects first; do not assume a doctor is free or non-generating. Live provider calls need the existing authenticated profile and bounded synthetic fixture. Provider quota/availability may block a live cell; record it without fabricating proof or asking Albert to repeat information already available through tools.

Useful current official research sources: [DeepSeek context caching](https://api-docs.deepseek.com/guides/kv_cache/), [OpenCode configuration](https://opencode.ai/docs/config/), and the [qualified capacity matrix](tests/verification/reviewer-diagnostics-quota/capabilities.md). Online documentation does not override installed pinned-version evidence.

## 13. Definition of done, rollback, and open questions

Done requires every STATUS row evidenced; correct governed comparison and valid verdicts; all advertised persistence paths qualified; truthful complete-or-explicitly-incomplete usage; objective tuning decision records; relevant Windows/Linux checks; exact-head independent review; merged source verified on origin/main; serialized installation and live default-path proof; incident resolutions and real checkpoint closure; child issues/docs/handoff reconciled. Unsupported provider metrics may remain unavailable with interface evidence. A supported read/recovery capability that remains broken prevents full completion.

Rollback is slice-specific: retain pre-install configuration backups and installed source identity; stop new submissions only during an authorized serialized changeover, preserve in-flight records and paid artifacts, and revert the exact owned code/configuration slice through GitHub. Do not downgrade/delete a new state schema blindly. Versioned state readers must either read prior records or fail with an explicit recovery path; qualification tests cover forward-written state before rollback approval. If rollback would remove an original capability or destroy state, stop before it and present the concrete owner decision.

Open technical questions have defined resolution gates, not missing product requirements: OpenCode usage semantics (#333); GLM and Qwen execution causes (#397); Codex supported sandbox repair (#271); scope/freshness of exhaustion observations (#396); and justified compaction settings (#333). Outcomes may be no justified change, targeted repair, or external blocker with retained evidence. None permits claiming a blocked supported capability is complete.

The public plan is sufficient to start and execute diagnosis without the planning chat. Private historical closure still requires the original host evidence; if unavailable, create synthetic regression proof for code work but retain that historical closure blocker. Do not ask Albert to choose technical mechanics already bounded here. No outstanding owner decision blocks the planning deliverable.

## Final self-audit

1. **Can a fresh session execute without the chat? Yes.** §§2–6 identify repository roles, exact baselines, current concurrent work and proven versus unproven findings; §§9–12 give named files, dependencies, commands, research criteria, access and gates. Unknown root causes have executable diagnosis paths rather than guessed fixes.
2. **Does this carry the relevant reasoning and rejected work? Yes.** §§1, 6–8 distinguish the three kinds of persistence/cache, preserve rejected snapshot/server/timeout approaches, and correct the stale assumption that #312 remains unimplemented. §4 prevents duplication of #333 and PR #330.
3. **Is the goal clear enough to override a mistaken step? Yes.** The opening goal and §1 prioritize accurate usable reviews, preserved paid work and demonstrated efficiency; §9's metric and safety gates reject cost savings that lose evidence or capability.

All 13 required sections, explicit scope, locked/open decisions, concrete per-step gates, tests, secret handling, delivery/rollback criteria and bidirectional handoff registration are present. The handoff and topic router provide discovery; the existing reviewer-issue skill reaches this plan through its existing `docs/reviewer-issues.md` route, avoiding an unrelated installed-skill change. Memory files are not modified because Albert did not request a memory update.
