# Implementation plan — stop recurring reviewer failures on edge-dev3

## STATUS — read first; do not re-derive completed programmes

Owner: [issue #1783](https://github.com/popcre/ai-devops/issues/1783), planning coordinator Codex chat `01a1423a-787d-7601-8ac5-49b0a42afbed` on edge-dev3.
Planning snapshot: October 15, 2026, 9:09 PM EDT. Implementation **started October 16, 2026** (steps 1–7 executed; coordinator Claude chat 05d44eb1 on edge-dev3). Current brief: [step-8 handoff](HANDOFF.d/2026-10-18T1524Z-edge-dev3-claude-reviewer-recurrence-fleet.md). Original plan merged in [PR1784](https://github.com/popcre/ai-devops/pull/1784) at [9acc9b1e](https://github.com/popcre/ai-devops/commit/9acc9b1ee565ecfc58a8bc66939e536fddee9954); addendum/closeout publication is [PR1786](https://github.com/popcre/ai-devops/pull/1786). Refresh its state before assuming merged delivery.
Handoff: [execution brief](HANDOFF.d/2026-10-16T0111Z-edge-dev3-codex-reviewer-recurrence-plan.md).

| Step | Work | State / date | Evidence required to advance |
|---|---|---|---|
| 1 | Freeze incident inventory, current versions and ownership | done — 2026-10-16 ([inventory](tests/verification/reviewer-recurrence/step1-inventory-2026-10-16.md)) | Private exact-ID inventory with digest; sanitized mapping and version manifest |
| 2 | Reproduce receipt conflict and evidence-recovery interference | done — 2026-10-16: cause was preparatory verify publishing the receipt early; repaired by PR1799 with fixture; sweep cannot refuse a review | Discriminating packet/sandbox/front-door fixtures; retained original evidence |
| 3 | Repair Muse Linux installation pin, completion and interruption recovery | pin: no re-pin needed, Muse Code (Linux) PASS at 1aefa959 (2026-10-16); completion/interruption stays with #674 | Native/OpenCode stream fixtures, no stale-turn replay, genuine terminal review |
| 4 | Repair StepFun report contract and large-input/runtime residuals | ✅ done — PR1812 (2026-10-16); live StepFun APPROVE on installed 1aefa959 after credit recharge; planted-defect REJECT proven | Single-decision contract tests plus complete-context live review |
| 5 | Finish demonstrated DeepSeek/GLM readiness and recovery gaps | ✅ no new defect reproduced — 2026-10-16: live DeepSeek and GLM cold/follow-up/fresh reviews all correct; GLM consumer proof by 01a14221 lane | Current-source reproductions and owner-linked fixes or verified existing repair |
| 6 | Restore verification/diagnostics; separate housekeeping false-PASS follow-up | housekeeping PR1810 and hook-test isolation PR1811 done (2026-10-16); Grok suite already non-gating (PR1778) | Exact hanging-test diagnosis, isolation, owned-process cleanup, offline suites |
| 7 | Review, merge, install and prove original capabilities | 🟡 partial — 2026-10-18: PR1826 (governed receipt for all doors) installed on edge-dev3, hetz, edge-dev; four-provider matrix passed. Open: 916 update; shared-db acceptance for DeepSeek/StepFun; StepFun Windows (#1678) | Exact-head approval, CI/queue, installed receipts, consumer review evidence |
| 8 | Sustained acceptance, incident reconciliation and retirement | 🟡 window restarted 2026-10-16 6:28 PM EDT after PR1826; no organic reviews on edge-dev3 through 2026-10-18, so not yet proof | Real >=24-hour interval, per-provider samples, failure accounting, issue checklist |

Fresh session starts with the [fleet handoff](HANDOFF.d/2026-10-18T1524Z-edge-dev3-claude-reviewer-recurrence-fleet.md) §6; do not redo steps 1–6. Prevention follow-ups: #1833. Steps 2–6 are proposals until discriminating fixtures establish the defect. This plan covers a new recurrence after #1562; it does not undo that programme's verified delivery. All rows describe repair work, not completion of this document.

## 1. Ultimate goal

Albert can request an independent review and get a trustworthy, preserved decision without repeatedly repairing the review system, losing paid work, or having unrelated abandoned reviews obstruct a new one. If a provider cannot finish, the system explains the exact failure, retains its evidence and permits only the recovery that evidence supports. A review must still examine the intended source and retain its normal reading and command capabilities.

**If a step conflicts with this goal, the goal wins — stop and flag it.**

Acceptance concerns all four maintained reviewers: Muse, DeepSeek, GLM and StepFun. Do not obtain apparent reliability by removing one, suppressing errors, accepting incomplete output, skipping tests, silently switching providers, or weakening source/evidence checks. Zero provider outages cannot be promised; transparent refusal with preserved evidence is a correct outcome, but an unresolved provider outage still limits acceptance and must be reported.

## 2. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is a public toolkit of Bash/Python/Node/PowerShell commands, provider adapters, tests, documentation and installers. AI coding sessions use it on Linux and Windows. It is not a hosted product and has no application database. `main` is protected and uses a merge queue. Installation is deployment.

The affected computer is **edge-dev3**, a Linux development host. Runtime entrypoints in `/usr/local/bin` currently resolve into `/home/ahazan/repos/ai-devops`; that checkout is landing/installation-only. The planning worktree is `/home/ahazan/.codex/worktrees/24eb/ai-devops`, branch `codex/reviewer-recurrence-plan`. Every implementation lane uses its own worktree from fresh `origin/main`.

Primary layers:

- `bin/ai-review` / `bin/ai-review-pool`: selection, admission and supported entrypoints.
- `bin/ai-review-engine`, `tools/lib/review-lifecycle-core.sh`, `tools/lib/review-doors/{muse,stepfun,deepseek}.sh`: shared lifecycle and provider execution. GLM's registered native pool route is also relevant; do not force it into a newly invented door.
- `bin/ai-review-packet`, `bin/ai-review-sandbox`, `tools/reviewer_events.py`: source snapshots, immutable receipts, durable evidence and safe cleanup.
- [popcre/shared-db](https://github.com/popcre/shared-db) `scripts/run-governed-review.mjs`: a consumer that validates receipts and accepts only a source-bound terminal decision. Its membership allocator is the authority for the review pool.

A **packet** is the review input and exact source identity; a **receipt** binds that packet to the originating source. A **terminal verdict** is the final completed review decision, not a progress sentence. A **lifecycle** records invocation/start/finish/failure and retained artifacts. A **cold** session is new provider conversation state; **warm** is a follow-up in the same conversation; a **fresh-process** launch starts a new wrapper process without rebooting the computer or disturbing other work.

## 3. Trigger and reproducible observations

Albert asked why reviewers still fail on this computer, then explicitly requested “make a plan to fix everything.” This is a planning/publishing request; no provider repair, paid review or installation was performed to prepare it.

Read exact private incidents through `ai-reviewer-issue path`, `list`, and `show ID`. They must not be copied into this public plan. The following IDs are lookup keys, not diagnoses:

| Local incident ID | Established symptom | Reproduction target |
|---|---|---|
| `20261015T033455Z-edge-dev3-muse-1331973` | Receipt conflict, retained evidence warnings and orphan examination cap before a verdict | Governed receipt passed through first/repeated packet builds; old unresolved snapshots |
| `20261015T033514Z-edge-dev3-deepseek-1373109` | Independent provider hit a receipt conflict too | Same receipt protocol; prove common cause rather than assuming provider fault |
| `20261015T191712Z-edge-dev3-muse-2415077` | Three attempts across native/new, native/follow-up and OpenCode stopped without proven completion, reason `tool-calls` | Replay retained streams offline, isolate failed tool and terminal-event handling |
| `20261015T213646Z-edge-dev3-muse-3020143` | Same incomplete-completion symptom in shared-db PR4344 | Exact source-bound governed route, not doctor only |
| `20261015T213646Z-edge-dev3-stepfun-3020039` | Report contained earlier decision wording; shared-db correctly refused recording | Report containing a quoted/earlier approval plus terminal verdict |
| `20261014T165827Z-edge-dev3-stepfun-3402377` | Front door swept unrelated snapshots before obtaining a decision | New review with retained foreign snapshots and failing cleanup |
| `20261014T175100Z-edge-dev3-stepfun-1623805` | Final check produced no usable decision | Retained provider result, process status and consumer parser |
| `20261015T234815Z-edge-dev3-grok-3214228` | Windows fallback verification suite reported running for hours | Diagnose exact suite/worker/run; do not cancel someone else's work |

### Additional installation report supplied by Albert

After this plan was published, Albert relayed an installation-stage report from another session: updating edge-dev3 to `f84085f93b6c20752d798a9b3db76b78bedb3d2f` passed every required stage but optional **Muse Code (Linux)** failed: `Meta installed a different Muse Code than the pinned 1.4.7-R6101.1`. The report also says **Housekeeping schedule** printed `bin/ai-housekeeping: line 1: tmp: unbound variable` while reporting PASS. These are reported symptoms, not independently reproduced by this planning update. The optional designation does not establish that the maintained native Muse capability is working.

The report says edge-dev (Windows) has uncommitted edits to `config/muse-code/version` and `config/muse-code/sha256`. Inspect those over its existing approved SSH route read-only as reference; never modify, stash, stage, commit or reset them. No remote inspection or executable re-pin was performed by this planning update. The build-movement explanation is a hypothesis until official release provenance, local installed version and binary digest are verified. Step 3's installation prerequisite below now makes this an explicit deliverable; step 6 carries the separate housekeeping follow-up.

These symptoms were read from local immutable incident summaries/details. They do not establish that both engines share one root cause, that an orphan caused a receipt conflict, or that Linux itself is broken.

At this snapshot `ai-reviewer-issue list` contains **80 unresolved edge-dev3 records**, including 17 dated October 11 onward. Counts by provider: Qwen48, Gemini9, DeepSeek6, StepFun6, Muse4, Grok3, GLM2, Codex2. This is an incident backlog, **not** 80 distinct defects or a measured failure rate. Re-derive it with the command in §12 before assigning work. Repeated allowance reports may be one cause; unresolved records may describe a subsequently repaired failure whose resolution was never appended.

## 4. Scope: in and out

**In:** every unresolved local reviewer incident gets an explicit disposition; current maintained reviewer failures get minimal root-cause repairs; shared packet/receipt, completion, report, lifecycle, admission, diagnostics and owned-process recovery remain coherent; exact-source installation and real acceptance on edge-dev3 are required. Existing Windows CI failures and cross-platform shared-code regressions are in scope where they block these repairs. Check applicability on affected authorized development hosts using existing secure routes; install there only when the same defect and authorization are established.

**NOT in this plan:** reinstating frozen providers in rotation; resuming heavy Qwen/Gemini/Grok/Kimi maintenance; changing models or paid-key fallback policy; reducing turn budgets; replacing working harnesses; building another recorder/dashboard/daemon; blanket deletion of evidence or worktrees; application features, database shape/data changes, cloud infrastructure changes, transcript mining or secret rotation. Preserve frozen wrappers' callable capability. An incident in a frozen provider is still classified, and a common-layer defect that affects it still gets repaired. A provider-only frozen defect remains an explicit tracked limitation unless Albert specifically requests that provider's repair; do not silently reactivate its programme.

This is one recurrence programme under #1783. Reuse existing owners/issues for the same need; do not open proof-only tickets or duplicate historical repair programmes.

## 5. Current state of code and delivery

Source reference for the line anchors below: fetched `origin/main` **`24b038bc7f4a6efc304031b9ab0a2bfc7228965f`** ([commit](https://github.com/popcre/ai-devops/commit/24b038bc7f4a6efc304031b9ab0a2bfc7228965f)). Line numbers are navigation aids; re-locate functions after upstream movement.

| Source anchor | Existing behavior / consequence |
|---|---|
| `bin/ai-muse:872–900`, `parse_turn()` | Separate native/OpenCode stream handling; refuses nonzero exit, mixed/missing session, non-terminal completion or empty text. `tool-calls` alone is correctly not completion. |
| `bin/ai-muse:1084–1120`, `failed_turn_stream_check()` / `failed_turn_source_check()` | Narrow evidence-based failed-turn reconciliation already exists; not a general permission to replay arbitrary partial work. |
| `bin/ai-review-packet:560–578`, `publish_receipt()` | Publishes create-only exact bytes; a pre-existing unequal receipt correctly returns `source-receipt-conflict`. |
| `bin/ai-review-sandbox:254`, `cmd_sweep_orphans()` at 1109–1165 | Unreconciled evidence is retained; sweep is bounded, checks live ownership and rotates its cursor. The cap is intentional. |
| `bin/ai-review:297–305` | Supported entrypoint runs a best-effort orphan sweep. Investigate expensive/interfering work here before altering cleanup semantics. |
| `tools/lib/review-lifecycle-core.sh:369–397` | Shared parser uses final `## Verdict`; full consumer acceptance additionally rejects parseable decisions elsewhere. These are different checks. |
| `tools/lib/review-doors/stepfun.sh:366`; `bin/ai-stepfun:255–279,815–871` | Door already requests exactly one terminal decision; standalone normalization is narrowly head-bound. Prompt-only advice has not eliminated recurrence. |
| `config/review-runner-doors.json:1–65` | Shared runner and six historical door entries already exist; registry entries alone do not mean six maintained pool members. |
| `docs/reviewer-rotation-rules.md:5–46`; `plan_review-scope-reduction.md` STATUS | Four maintained members; other wrappers retained callable. Never remove or disable capability to make metrics pass. |

Installer evidence newly checked in source: `install.sh:855–870` defines inline `install_muse_code_linux()` and invokes it as optional `run_stage "Muse Code (Linux)"`. It reads `config/muse-code/linux-$(uname -m)/version` and `sha256`, derives the expected filename `$HOME/.local/bin/muse-bin-$ver`, invokes the downloaded official `https://dev.meta.ai/install.sh` only if that filename is absent, requires the expected file to exist, and compares its SHA-256 exactly. This function **does not execute a version-string comparison**: the version selects the expected filename; the byte hash is checked directly. Native runtime version checks are a separate boundary in `bin/ai-muse` (pin selection around96–97 and reported-version refusal around326). The initial inspected Linux and top-level Windows version files both contain `1.4.7-R6101.1`, but their binary hashes differ because they are different platform artifacts. Do not copy one platform's hash into the other. `bin/windows-muse-code-install.ps1` additionally uses `config/muse-code/windows-installer-sha256` for the Windows installer itself. Housekeeping scheduling is invoked at `install.sh:737` through `bin/ai-housekeeping schedule`; the reported trap/error root cause remains unproved.

Read the current shared-db consumer's `scripts/run-governed-review.mjs`, `reserveReviewReceipt()` / `validateSourceReceipt()` around 204–242 and 579–642, plus extra-decision refusal around 650–700. Its matching tests are `scripts/run-governed-review.test.mjs`. Consumer anchors were inspected in the local shared-db checkout; step 1 must pin that repository's exact current HEAD before relying on its line references or changing it.

The installed checkout HEAD observed was **`f84085f93b6c20752d798a9b3db76b78bedb3d2f`**, an ancestor of the fetched source baseline ([commit](https://github.com/popcre/ai-devops/commit/f84085f93b6c20752d798a9b3db76b78bedb3d2f)). This proves checkout ancestry and launcher location, **not** a valid install receipt or wrapper-byte equality. Verify those in step 1. Do not assert that source/version drift caused these failures without comparing the relevant bytes and receipts.

Subsequent upstream movement during publication: `origin/main` advanced to [e9d0db64](https://github.com/popcre/ai-devops/commit/e9d0db64) via [PR1778](https://github.com/popcre/ai-devops/pull/1778), whose title is “ci: make frozen Grok reviewer suite non-gating.” This is source movement, not proof that the recorded long-running worker ended or that its root cause is repaired. Step 6 must inspect that landed change and current run state before duplicating it; preserve remaining required common/debate/approval-gate coverage. The pinned baseline above remains the investigation snapshot.

Fresh GitHub readback corrected stale memory: [#1562](https://github.com/popcre/ai-devops/issues/1562) is **CLOSED**, its acceptance checklist checked; [PR1565](https://github.com/popcre/ai-devops/pull/1565) is **MERGED**, commit [d6b787aad8f380f4436897f364dc75ca9e7c7993](https://github.com/popcre/ai-devops/commit/d6b787aad8f380f4436897f364dc75ca9e7c7993). Do not repeat the October11 claim that its merge failed and work remained wholly uninstalled.

Existing ownership/dependencies, read October15; activity is **unverified**, not claimed running:

| Existing card | Recorded owner / last issue update (EDT) | Reuse boundary |
|---|---|---|
| [#674](https://github.com/popcre/ai-devops/issues/674) | Codex chat on 916-ALIEN; October15 12:56 PM EDT | Muse interrupted-follow-up recovery; old paid uncertain turn remains separate |
| [#1349](https://github.com/popcre/ai-devops/issues/1349) | Codex chat on edge-dev3; October15 1:34 PM EDT | Registered GLM native pool dispatch; live proof still required |
| [#1370](https://github.com/popcre/ai-devops/issues/1370) | Codex chat on edge-dev3; October6 10:51 PM EDT | StepFun complete-input/readonly-profile startup failures; checklist open |
| [#1420](https://github.com/popcre/ai-devops/issues/1420) | MiMo on edge-dev; October7 3:46 PM EDT | Preserved legacy sandbox backlog; checklist checked but issue open. Edge-dev cleanup is not edge-dev3 proof. |
| [#1405](https://github.com/popcre/ai-devops/issues/1405) | Owner must be refreshed in step 1 | DeepSeek receipt leftovers; do not seize or delete its evidence |
| [#1301](https://github.com/popcre/ai-devops/issues/1301) | Owner must be refreshed in step 1 | Pipeline clean-window metrics/helper retirement; do not restart completed extraction |
| [#1674](https://github.com/popcre/ai-devops/issues/1674), [#1678](https://github.com/popcre/ai-devops/issues/1678) | Owners must be refreshed in step 1 | Apparently overlapping historical incident repair cards: determine canonical owner and link; do not close from title similarity |

## 6. Findings and root cause: proven versus unknown

1. **Completion was not established.** Muse rejected retained streams with reason `tool-calls`; this is correct refusal. It remains unknown whether the originating defect is engine tool execution, denied read recovery, premature termination, or adapter event handling. Step3 must distinguish them, preserving completed-but-unpublished and genuinely incomplete outcomes separately.
2. **Two producers/consumers can disagree on one receipt.** An incident's retained receipt digest differed from its retained snapshot's packet digest. `publish_receipt()` is deliberately immutable. It remains unknown whether the cause is duplicate preparation, changing prompt/context, a mutable packet, invocation collision or stale metadata; step 2 compares each stage's identity and bytes before changing the protocol.
3. **Report contracts differ across layers.** A report can satisfy the toolkit's final-heading parser and still be unsafe to publish to shared-db, which correctly rejects extra parseable approval text. StepFun already has a formatting instruction. The plan repairs production of a consumer-compatible terminal report, preserving the raw report and findings; it does not weaken the consumer.
4. **Old evidence creates work before new reviews.** Sweep warnings/caps are factual; causality for the receipt failure is unproved. Existing bounded cursor/live-owner safeguards must be preserved. The desired fix is non-interference and supported reconciliation, not guard removal.
5. **Historical repair closure is not a perpetual guarantee.** Pipeline extraction and prior installed repairs already exist. New failures require current discriminating fixtures, current installed bytes and stronger integrated acceptance, not another wholesale rewrite.
6. **Counts are not reliability.** Raw repeated quota incidents, synthetic state contamination and genuine review outcomes must have separate denominators. Existing isolation and incident classification capabilities should be used, not reimplemented.

## 7. Rejected approaches and failed attempts

- Repeating Muse on another engine as the diagnosis: the recorded new/follow-up/OpenCode attempts all stopped incomplete. Compare retained streams first; never replay an uncertain paid turn simply to get a result.
- Treating `tool-calls`, process exit0, earlier approval wording or a successful doctor as a completed review. Each can occur without a usable source-bound terminal decision.
- Deleting/replacing an existing conflicting receipt, reusing a predecessor's lifecycle, forging a terminal event or stripping unsafe findings after the fact into a pretend approval. These destroy the evidence that keeps approval truthful.
- Blanket orphan cleanup, raising the 16-entry cap or bypassing reconciliation to clear warnings. A cap message is not deletion authority; evidence and live owners must survive.
- Prompt wording as the entire StepFun fix: a one-decision instruction already exists. Keep it, add a tested output contract and safe failure handling.
- More retries or shorter turn budgets. Prior [system-repair decision record](plan_reviewer-system-repair.md) dropped short budgets after measured healthy reviews exceeded them. Preserve provider-specific permitted capacity retry rules; no generic retry loop.
- Rebuilding a second lifecycle/recorder. [Pipeline-core plan](plan_reviewer-pipeline-core.md) and [harness consolidation](docs/reviewer-harness-consolidation.md) already own the common engine. Its older roster/date/status wording can be stale; current membership wins.
- Reopening closed #1562 or treating its formerly failed merge as still pending. Fresh readbacks supersede the October11 memory note.
- Broad host-wide process kills to stop a reviewer/test. A recorded DeepSeek broad stop affected concurrent CI. Cancellation must prove exact owned process ancestry and retain evidence.
- Raising privileges, changing secrets, removing reviewers or weakening required CI to make installation/verification pass. Follow existing supported gates; a platform block stays explicit.

## 8. Decisions, dated October 15, 2026

**Locked:** preserve original reviewer capability, four-member membership, full source context, exact immutable source/receipt binding, read-only formal review, retained paid output, one completed terminal verdict, isolation from other sessions, required checks and supported installation. Existing service failures are not substantive REJECT decisions. Unknown history remains unknown. New public artifacts contain only sanitized facts.

**Locked delivery:** one recurrence owner (#1783) coordinates; existing cards retain ownership of overlapping repairs. Technical decisions, merges and installation admission remain with the coordinator. Source/test work cannot be called installed; installation cannot be called reliable until genuine consumer checks and the observation gate pass.

**Open implementation judgment:** which stage first corrupts or reuses receipt identity; exact safe terminal-event representation for each engine; whether a narrow existing adapter fix suffices or common code must change; the smallest useful isolation boundary for slow tests. Decide with a failing reproduction that the proposed fix turns green, supported engine/schema documentation and adversarial negatives. No owner business decision is required.

## 9. Ordered executable plan

### Phase A — inventory and common evidence path

**Step1 — freeze and reconcile before writing code.**

Use `bin/ai-reviewer-issue`, `bin/ai-review-preflight`, `config/reviewer-registry.json`, `config/review-runner-doors.json`, and the existing maintenance state. Read `maintenance show` first; resume an active frozen round instead of resetting it. Build a protected exact-ID manifest including provider, repo/head/run/caller, raw-evidence hash, resolution state, first/last occurrence, current owner/card and missing evidence. Include all 80 previously unresolved records plus anything newly arrived; deduplicate causes without dropping IDs. Join events/scoreboards by exact identifiers, never nearest timestamp. Record runtime versions, resolved launchers and relevant installed file hashes, install receipt and source SHA. Record synthetic rows separately. Produce sanitized verification documentation under `tests/verification/reviewer-recurrence/` with commands and hashes, never raw streams.

Refresh existing cards/PRs, current shared-db HEAD and owner state. Read visible chat status only if needed; no message to another chat is authorized by this plan. If ownership is active, retain it and work on nonoverlapping scope. If idle/unowned, explicitly claim the bounded work on its existing issue before editing; do not infer abandonment from age. #1783 coordinator owns reconciliation even if no child is active.

Dependencies: none. **Gate:** every frozen ID has a disposition and named owner, all executable source/installed identities are recorded, and existing repairs are distinguished from new reproductions. No historical incident is marked resolved merely because it does not reproduce today.

**Step2 — packet publication and recovery do not obstruct a new review.**

Targets: `bin/ai-review-packet` `publish_receipt()` and its build callers; `bin/ai-review:297–305`; `bin/ai-review-sandbox` `cmd_sweep_orphans()`; existing event reconciliation/store helpers. Consumer tracing targets shared-db `reserveReviewReceipt()`, `validateSourceReceipt()` and spawn environment. Add discriminating fixtures to `tests/test-ai-review-packet.sh`, `tests/test-ai-review-sandbox-self-cleanup.sh`, `tests/test-ai-review-sandbox-delete-guard.sh` and `tests/test-ai-review-engine.sh`.

Trace one exact invocation from receipt reservation through source snapshot, packet build, actual dispatch and final retained packet. Compare canonical source root, full base/head, source digest, decision/context inputs, packet digest and invocation ID at each boundary. Repeat once with two concurrent independent invocations. The first place two supposedly identical packets differ is the repair target. For one immutable identity, reuse exactly the sealed packet; if a new invocation/input needs new evidence, allocate its own create-only receipt through the existing owner. Never overwrite conflict or normalize away identity differences. Retain mismatched evidence with typed diagnostics.

Make foreign orphan evidence unable to mutate this invocation or change its outcome. Keep the existing bounded, cursor-based sweep and its checks. If startup housekeeping blocks useful work, separate its execution from approval-critical preparation using the existing maintenance owner; do not spawn an unmanaged background daemon or discard its errors. Reconciliation must preserve full unique packet/report bytes and prove the original run before normal cleanup. Existing live runs remain untouchable.

Dependencies: step 1. **Gate:** exact repeated publication is idempotent; changed input and mismatched binding refuse; independent invocations complete without receipt collision; an unreconciled foreign sandbox remains intact while a fresh valid review progresses. Current incident replay identifies the actual cause, or stays explicitly UNKNOWN with a bounded diagnostic patch rather than an invented fix.

### Phase B — provider completion and downstream report contracts

**Step3 — Muse completes and resumes only its actual turn.**

**Installation prerequisite — dedicated Muse Code re-pin repair, before native completion acceptance.** Targets: `install.sh` inline `install_muse_code_linux()` / its optional stage, `config/muse-code/linux-x86_64/{version,sha256}`, top-level `config/muse-code/{version,sha256,windows-installer-sha256}` only if verified Windows applicability requires changes, `bin/windows-muse-code-install.ps1`, and `bin/ai-muse` pin/version checks. Do not bundle the housekeeping fix into this re-pin PR.

1. Recover the original stage output and installed completion receipt at the reported source SHA, then independently inspect edge-dev3's actual Muse Code binary, resolved launcher, reported version, file type/architecture and SHA-256. Inspect regular-file identity and permissions before execution; do not run an unknown new download just to ask its version. Record the actual release/build and digest in protected evidence; missing original data stays explicit. Gate: distinguish absent old-version filename from hash mismatch, broken download, wrong architecture, partial install or a runtime-selection error.
2. Verify the replacement through Meta's official HTTPS installer/release provenance and available authoritative checksum/signature/release metadata; preserve evidence of origin, redirect destination, byte count, architecture and integrity. A local binary hash alone proves identity, not authenticity. If official publication does not expose a checksum/signature, document that limitation and require the assigned reviewer's explicit approval of the alternative official-origin verification method before accepting the re-pin. Never generate a pin from unexplained local bytes or turn an official installer's latest-build drift into an unbounded auto-update policy. Gate: the candidate is demonstrably a complete genuine Meta artifact, with the exact verification method documented.
3. Read edge-dev's uncommitted top-level version/hash diff over its approved SSH route without changing anything there. Establish Windows release identity/provenance and binary/installer hashes independently; the Linux build does not prove Windows has the same release. If another owner is actively repairing this, reconcile ownership on #1783 before editing. Update only necessary platform pin files in this task's own worktree; leave unrelated Windows local edits untouched and do not commit a remote diff as if owned. Preserve file-selection/version/hash guards. Gate: each changed pin names the intended platform artifact, verified bytes and current compatible runtime; unchanged platform behavior is covered.
4. Add discriminating offline cases in `tests/test-ubuntu-install-stages.sh`, `tests/test-ai-muse-code.sh` / part2, and `tests/test-windows-muse-code-install.ps1` when Windows pins/install behavior are touched. Cases: official installer supplies expected artifact, latest build differs from pin, absent expected filename, tampered hash, truncated/wrong-architecture download, valid platform-specific pin, and Windows-local edits untouched by remote read. Preserve a specific failure when bytes differ; never skip the stage or downgrade the failure into success. Gate: supported pinned install passes; every hostile/mismatch fixture refuses meaningfully.
5. Publish a dedicated protected re-pin PR stating observed old/new build, Linux SHA-256, Windows applicability, official provenance and exact validation. Obtain assigned independent exact-head approval, required CI/merge and supported installation authority. Prove **Muse Code (Linux) PASS on edge-dev3** through a supported stage-only route if one actually exists; otherwise use the candidate-worktree full `update.sh` procedure. Do not source `install.sh` to extract the function, run an ad-hoc copied stage, edit installed pins, bypass review or manually force a PASS line. Record the actual stage output plus installed binary hash/version and a genuine native Muse review. Gate: the dedicated re-pin PR exists and the actual installed Linux stage passes; source publication alone is not acceptance. Native completion tests and sustained programme acceptance still follow.

This prerequisite is owned by the #1783 coordinator until an existing responsible repair owner is verified. Its verification remains unchecked until the exact build and real install are proved. The planning request authorizes documenting it, not claiming its execution. If access/provenance/privilege prevents safe delivery, record the exact technical blocker rather than asking Albert to approve a bypass.

Bounded #674 follow-up design: [exact non-authorizing denied-read recovery](docs/muse-denied-read-recovery-design.md). Its one-to-three denied-read suffix requires independent design APPROVE before implementation; it does not change the other steps or claim their ownership. The additive provenance/navigation clarification also covers `bin/ai-review-packet`, Muse door text and their focused/shared packet tests, while preserving the existing original-checkout identity guardrail.

Targets: `bin/ai-muse` `run_turn()`, `retain_turn()`, `parse_turn()`, `failed_turn_stream_check()`, `failed_turn_source_check()` and supported reconcile/follow-up handlers; `tools/lib/review-doors/muse.sh`; existing `config/opencode-muse` only if a demonstrated profile defect requires it. Reconcile owner #674 before overlapping writes.

Turn sanitized retained failures into fixtures in `tests/test-ai-muse.sh`, `tests/test-ai-muse-part2.sh`, `tests/test-ai-muse-part3.sh`, and `tests/test-muse-opencode-contract.sh`; native runtime changes also use `tests/test-ai-muse-code.sh` and `tests/test-ai-muse-code-part2.sh`. Separate tool-start/tool-result/nonterminal-step/final-terminal events. Verify model pin, session, invocation and source identity before publishing any response. Find whether a denied/missing tool result prevented the engine's final event or whether an adapter discarded valid completion. Repair the responsible layer against supported schema, preserving the normal read/command tool set.

Only exact retained terminal completion can publish a decision after interrupted local postprocessing. A genuinely incomplete tool step remains incomplete; permit supported same-conversation continuation only where invocation/source ownership and existing uncertainty fences allow it. Archive predecessor descriptors before preparing new source. Never merge old completed text with a new head or silently create a replacement paid turn.

Dependencies: step 1; step 2's receipt contract must be stable before integrated acceptance. **Gate:** both supported engines complete a real review, offline fixtures distinguish partial from terminal, cold/warm/fresh-process behavior preserves identity, and all #674 stale-turn/mismatch negatives still refuse without changing recovery metadata first.

**Step4 — StepFun emits one unambiguous usable report.**

Targets: `tools/lib/review-doors/stepfun.sh`, `bin/ai-stepfun` prompt/report emission, `tools/lib/review-lifecycle-core.sh` validation only if the defect is demonstrably shared, and `tools/review_door_diagnostics.py` for preserved failures. Reuse #1370 for large argument input / per-run profile startup work. Test `tests/test-ai-stepfun.sh`, `tests/test-ai-stepfun-store.sh`, `tests/test-ai-stepfun-windows-shell.sh`, `tests/test-ai-review-engine.sh`, `tests/test-review-door-diagnostics.sh` and shared-db consumer tests.

Keep raw provider output immutable. Ensure the report produced by the supported adapter carries complete findings and exactly one final decision in the contract the consumer accepts, bound to the full current head. An unfinished response or substantively contradictory decisions stays refused. Do not generically remove earlier APPROVE/REJECT strings and reinterpret the remainder as authorization. Prefer the engine's supported final-answer boundary and tested prompt construction; if presentation normalization is necessary, prove it affects only non-authorizing presentation and never erases a finding, blocker, alternate decision or uncertainty. A malformed report must be retained and classified specifically, not retried blindly. A subsequent review is a fresh authorized source-bound review, not a fabricated completion of a spent one.

Reproduce full governed input above the OS argument bound, preserve every byte using the existing supported file-input route, keep private permissions and read-only mounting. Preserve immutable configuration while allowing only documented per-run bookkeeping. Use existing engine paths, no new runtime replacement.

Dependencies: steps 1–2; provider work can be prepared independently of step 3 after ownership checks. **Gate:** the original mixed-wording fixture remains unsafe as raw authorization, normal complete output records one valid terminal verdict in the real consumer, planted real defects produce substantive REJECT, complete large-input and supported shell/command capability work live, and original findings remain recoverable.

**Step5 — close remaining demonstrated DeepSeek/GLM gaps.**

Targets: `bin/ai-review-pool` registered-provider dispatch; `bin/ai-review-preflight` usability/local-doctor paths; `tools/lib/review-doors/deepseek.sh`, `bin/ai-deepseek-agent` retained-outcome/process ownership paths; `bin/ai-glm` only when current reproduction requires it. Use #1349 for GLM dispatch, #1405 for existing DeepSeek recovery evidence. Tests: `tests/test-glm-pool-dispatch.sh`, `tests/test-ai-review-preflight.sh`, `tests/test-ai-preflight-pinbump.sh`, `tests/test-ai-deepseek-agent.sh`, `tests/test-ai-review-engine.sh`, `tests/test-pool-dispatch-doors.sh`.

First test whether PR1565/current upstream already fixes old missing-executable/doctor failures; if so add evidence/disposition, not another implementation. GLM must execute through its existing registered supported native route with normal independent-review binding. DeepSeek must retain original diagnostic and command result, separate provider refusal from local postprocessing failure, and reap only owned children. Bare HTTP403/404/429 cannot alone label credit/outage/config. Never kill concurrent CI to recover a reviewer.

Dependencies: steps 1–2. **Gate:** actual supported GLM and DeepSeek reviews complete with retained exact-head evidence; missing runtime, empty/failed doctor, timeout, wrong-source and foreign-process negatives still refuse. Out-of-credit recovery occurs only after matching provider evidence, not clearing holds manually.

### Phase C — integration, delivery and sustained proof

**Step6 — diagnostics and test execution preserve capacity.**

Targets: `tests/lib-reviewer-events-isolation.sh`, `tests/test-reviewer-events-isolation.sh`, `tools/review_door_diagnostics.py`, `bin/ai-reviewer-issue`; diagnose the exact `windows-reviewer-fallback-grok` suite via `.github/workflows/verify.yml`, `config/ci-suite-manifest.json`, `bin/ai-test-local` and its selected test before modifying anything. Shared common/debate/approval-gate coverage remains required even when a provider is frozen.

Find the last active assertion/child of the reported hung run and establish whether it is provider latency, leaked child, lock wait, tool permission, test fixture or runner resource collision. Reproduce offline with bounded owned fixtures. Keep normal bounded waiters and process ownership; do not shorten real reviewer work budgets. For test-owned mock hangs, assert timeout diagnoses/reaps only owned children and the suite exits with a specific error while another concurrent fixture remains alive. All synthetic tests redirect event and scoreboard stores and must never publish live incident/capacity outcomes.

Planning also observed installation-path warnings naming a synthetic hook-test clone and a CI checkout during a prose ship check. This is evidence to investigate test/installation-detector isolation, not proof the installed checkout was moved; preserve the warning provenance and confirm before changing detection. Include the installed-path detector in the isolation negatives if that leak reproduces.

**Separate housekeeping follow-up (excluded from the Muse re-pin PR).** Targets: `bin/ai-housekeeping` scheduling/cleanup traps, `install.sh` `run_stage()` and the **Housekeeping schedule** invocation around737, `tests/test-ai-housekeeping.sh`, and `tests/test-ubuntu-install-stages.sh`. Retain the relayed `tmp: unbound variable` plus apparent PASS. Reproduce in an isolated scheduling fixture, trace variable lifetime/trap and propagated exit status, and repair only after evidence identifies the cause. Do not assume an error line necessarily made the command return nonzero. Require a fixture where the reported condition is reproduced, a genuine scheduler failure yields a truthful failed stage, and a healthy schedule both installs/validates its expected entry and emits no unbound-variable error. No live timers are modified by offline tests. Track ownership and live proof on #1783 or an already-existing canonical housekeeping repair issue; no duplicate/proof-only ticket. The re-pin may land independently; the overall recurrence programme retains this obligation until a separate fix and its normal gate/live proof pass.

Use the existing incident classification/maintenance lifecycle. Add precise reason codes and invocation/source/evidence references where diagnostic gaps prevented classification. Do not add another ledger, sweeper or review service.

Dependencies: step 1, integrate steps 2–5 as they land. **Gate:** exact original verification failure is reproduced then eliminated without skipping coverage; offline fixtures cannot affect production state; stderr/progress cannot masquerade as report; cleanup leaves no owned leak and does not touch another session. Document exact tests, exit statuses and resource evidence.

**Step7 — source review, merge, installation, genuine acceptance.**

For each protected repair declare `reviewer-safety` (or stronger effective class) and run `ai-task-gates check --before review` / `ship` / `deploy` at the required transitions. Use an independent in-rotation engine for exact-head final approval; never self-review a reviewer repair. If the shared mechanism is too broken to obtain admission, repair via the existing approved supported bootstrap/recovery path; otherwise record the actual gate blocker. Do not bypass it. Follow `docs/deployment.md` with a candidate worktree at the reviewed merged SHA, exact-head report, `authorize-install` and candidate `update.sh`. Never pull/merge the installed checkout.

Run focused checks once per stable head, required CI and queue through `bin/ai-pr-wait PR --timeout-minutes N`; do not repeat passing suites without changed inputs. Verify merged source, install-completion receipt, launcher routing and relevant byte hashes separately. Serialize shared files, merges, credentials and installations. A rollback is also a supported protected install of a known reviewed commit; preserve old receipts, evidence and compatible session descriptors before updating.

On edge-dev3, each of Muse/DeepSeek/GLM/StepFun must complete at least one cold review, one same-conversation follow-up and one fresh-process review through the supported entrypoint. Use public disposable representative source containing a planted defect for a meaningful REJECT and a corrected source for APPROVE; bind each to its own actual head. Exercise reading outside the summarized packet and the normal command/test ability promised by that provider. Retain invocation/caller/provider/runtime/source/digest/terminal decision/report/packet/lifecycle links. At least one real governed consumer review per provider must be accepted through shared-db; arrange this on the original open consumer request where applicable, without taking someone else's slot or spent attempt. No migration/data changes are required.

Negative controls include stale source, mismatched receipt, foreign snapshot, incomplete response and actual explicit credit refusal if observed. Use offline fixtures for quota/hostile cases; do not intentionally burn credit to manufacture a failure. For a capability that cannot be invoked without consuming spent authority, record the exact blocker rather than replaying it.

Dependencies: steps 2–6 and all owner overlap resolved. **Gate:** exact reviewed code is merged/installed, all four providers pass the cold/warm/fresh-process matrix and actual consumer acceptance; raw and final reports, packet and lifecycle survive process exit/recovery. Other authorized hosts are either proven applicable and updated, proven unaffected, or named inaccessible with actual route evidence. No fleet claim from edge-dev3 alone.

**Step8 — real observation and final reconciliation.**

Record a start checkpoint only after step 7's installed baseline is stable. Observe a real elapsed **>=24 hours**, with at least the three genuine reviews per maintained provider from step 7 plus ordinary eligible review traffic during the interval. Record actual sample counts; a quiet 24h with no reviews proves no additional review reliability. Record every observed failure, successful decision, timeout, refusal and unresolved turn separately. Report provider-specific usable-review counts and failure rates with honest denominators; all exclusions have evidence. A confirmed reviewer-code regression requires repair plus a new stable installed observation interval. A genuine provider outage does not reset invented code metrics, but remains an explicit availability limit and blocks an unconditional all-green claim.

Reuse existing collection/archive and lifecycle metrics; no new watchdog. If waiting exceeds the turn, leave the open checklist and named coordinator on #1783, timestamp last activity in EDT, and do not promise background execution. Use a scheduled wake only if the user requests it. Preserve the independent #1301 historical clean-window gate: this 24h acceptance does not replace its 14-day/50-review criterion or authorize premature helper retirement.

Append evidence-backed incident resolutions; unchanged historic unknowns receive an explicit remaining obligation, not invented causes. Join every step 1 ID to a verified repair/resolution, expected refusal, duplicate with original link, frozen-provider limitation, or exact evidence-unavailable carry-forward. Existing incidents cannot be reclassified to hide defects. Update plan STATUS/current-state/docs, finish checklist on the same repair issues, and retire this handoff only when every carried obligation is discharged or explicitly transferred with an owner. Do not close #1783 while a maintained capability or required live proof is still unverified.

Dependencies: step 7. **Gate:** real timestamps and evidence establish the interval and sample matrix; no unresolved actionable maintained-reviewer defect, all historical IDs accounted, and no extra proof ticket or source-only completion claim.

### Natural context boundaries and dependency control

Pause for context only after phase A fixtures/ownership, phase B's independently landed fixes, or phase C installation. At each boundary use `fresh-session`, update STATUS and re-read every downstream phase for drift. The coordinator retains responsibility through step 8. Disjoint provider preparation may run concurrently only under the environment's delegation instructions; shared packet/lifecycle files, consumer tests, secrets, review dispatch, installation and final decisions serialize. Plans do not designate a model/implementer. Do not create side projects or filler work when a dependency waits.

### Adversarial-cases table — trust-boundary acceptance

Names below are **required proposed regression case identifiers**, not claims that tests already exist. Add them to the named existing suite; a checkmark requires an executable case and saved run artifact.

| External/state input | Hostile case | Required test / location |
|---|---|---|
| Official download/pin | New latest build differs from pin; missing old filename; truncated/wrong architecture/tampered binary | `muse_linux_pin_drift_and_tamper_refused` / `muse_linux_verified_pin_stage_passes` — `test-ubuntu-install-stages.sh`; runtime refusal — `test-ai-muse-code.sh` |
| Cross-platform pin input | Linux bytes offered as Windows hash; Windows remote dirty diff changed | `muse_platform_pin_identity_is_distinct` — `test-windows-muse-code-install.ps1`; read-only diff evidence in verification record |
| Scheduler result/trap | Unbound temporary variable prints error while stage says PASS | `housekeeping_schedule_tmp_lifetime_is_safe` — `test-ai-housekeeping.sh`; `housekeeping_failed_stage_is_not_pass` — `test-ubuntu-install-stages.sh` |
| Provider stream | Ends at `tool-calls`, even with approval text | `muse_tool_calls_is_not_completion` — `test-ai-muse-part2.sh` |
| Provider stream | Valid terminal completion then interrupted local publication | `muse_completed_turn_recovers_without_provider_replay` — `test-ai-muse-part3.sh` |
| Provider stream | Mixed session/invocation/model or stale head | `muse_mixed_identity_never_publishes` — `test-ai-muse-part2.sh` |
| Session descriptor | Old success plus interrupted new follow-up, same/changed head | `muse_followup_cannot_reuse_predecessor_completion` — `test-ai-muse-part3.sh` |
| Tool result | Denied read, missing result, unsupported command, forged completed result | `muse_failed_tool_preserves_uncertainty` — `test-muse-opencode-contract.sh` |
| Receipt bytes/path | Different packet at same create-only destination | `receipt_conflict_retains_original_and_refuses` — `test-ai-review-packet.sh` |
| Receipt bytes/path | Same sealed bytes published twice | `receipt_identical_publication_is_idempotent` — `test-ai-review-packet.sh` |
| Invocation/source | Two concurrent calls; base/head/context/digest movement | `independent_receipts_do_not_collide` / `receipt_rejects_changed_source_or_context` — `test-ai-review-engine.sh` |
| Filesystem | Receipt symlink, replaced parent, traversal, foreign owned evidence | `receipt_link_or_parent_swap_refused` — `test-ai-review-packet.sh`; `sandbox_foreign_owner_never_removed` — `test-ai-review-sandbox-delete-guard.sh` |
| Cleanup backlog | >16 retained orphans and an active old run | `foreign_orphans_do_not_block_fresh_review` — `test-ai-review-sandbox-self-cleanup.sh` |
| Report text | Quoted/bold earlier APPROVE, two verdicts, wrong head, truncated final | `stepfun_extra_decision_never_authorizes` — `test-ai-stepfun.sh`; `consumer_rejects_extra_decision_report` — shared-db `run-governed-review.test.mjs` |
| Final output | Complete substantive REJECT or APPROVE with full head | `stepfun_terminal_report_matches_consumer_contract` — `test-ai-review-engine.sh` and shared-db consumer suite |
| Input file/profile | >64KiB context, malicious path, config unexpectedly writable | `stepfun_large_input_preserves_all_bytes` / `stepfun_profile_only_bookkeeping_writable` — `test-ai-stepfun.sh` |
| Readiness result | Missing executable, empty/failed/timed-out doctor despite registry | `registered_provider_requires_working_local_runtime` — `test-ai-review-preflight.sh` |
| Admission response | Bare403/404/429 vs explicit paid-funds/allowance evidence | `admission_status_code_alone_does_not_invent_credit` — `test-ai-review-preflight.sh` |
| Process cancellation | Hostile PID/foreign process group/shared CI | `review_cancel_reaps_only_owned_children` — `test-ai-deepseek-agent.sh` |
| Synthetic test env | Inherited real ledger/events/capacity paths | `synthetic_tests_cannot_write_live_outcomes` — `test-reviewer-events-isolation.sh` |
| Diagnostics | Progress on stdout, empty report, retained private output | `door_progress_cannot_be_a_report` — `test-review-door-diagnostics.sh` |
| Test runner | Owned mock child hangs; unrelated fixture runs concurrently | `review_fixture_timeout_preserves_foreign_worker` — exact suite selected in step 6 |

## 10. Required tests and durable evidence

Run only the suites relevant to the changed layer, with isolated event/scoreboard directories and existing test harness. Shell suites run with `bash tests/<name>.sh`. Before running a suite inspect its isolation bootstrap and use `bin/ai-test-local --check-collision`; keep real provider calls out of offline tests. Source suites to preserve: `test-ai-review-packet.sh`, `test-ai-review-sandbox.sh`, `test-ai-review-sandbox-self-cleanup.sh`, `test-ai-review-sandbox-delete-guard.sh`, `test-ai-review-engine.sh`, `test-ai-review-lifecycle.sh`, `test-pool-dispatch-doors.sh`, `test-glm-pool-dispatch.sh`, `test-ai-review-preflight.sh`, `test-ai-preflight-pinbump.sh`, `test-reviewer-events-isolation.sh`, `test-review-door-diagnostics.sh`, plus the provider suites named per step. Verify each exists on current source before dispatch; do not invent a pass for a missing suite.

For shared-db consumer validation use that repository's own AGENTS/test router and `node --test scripts/run-governed-review.test.mjs` if still its supported command. Work is tooling, not database structure: no schema claim or migration is created for this plan. Keep its normal repository gates/ownership. Consumer changes are unnecessary unless reproductions prove a defect there; consumer contract tests can validate toolkit changes without relaxing its parser.

Add a sanitized `tests/verification/reviewer-recurrence/README.md` with baseline/source/runtime identities, links to each regression case/run, install receipt hash, per-provider acceptance matrix and actual elapsed interval. Store raw stdout/stderr/prompt/session/token material only in existing private locations, with a digest/reference in sanitized records. Do not assume missing historical evidence can be reconstructed.

Installation-specific suites to preserve: `tests/test-ubuntu-install-stages.sh`, `tests/test-ai-housekeeping.sh`, and Windows `tests/test-windows-muse-code-install.ps1` when platform pins change. Pin/provenance repairs and housekeeping repair have separate PRs and separate acceptance evidence.

Planning-only validation: `git diff --check`, `bash tests/test-markdown-links.sh`, and `bin/ai-doc-reachability --base origin/main`. No paid review, runtime test or installation is warranted merely to publish this prose plan.

## 11. Constraints and gotchas

- Declare task class before work. Plan prose is `prose`; reviewer/evidence/safety-test implementation is `reviewer-safety`; stronger effective gates remain binding. No workaround for refusal, review lifecycle, spent attempts or OS privileges.
- All GitHub calls use `bin/ai-gh`, signed `Posted by Codex chat <CODEX_THREAD_ID> on <machine>` (or actual tool identity). Only task-owned files staged; Albert's committer identity must be verified. Protected `main` is never pushed directly, no `--admin`, no force push.
- Planning-only prose needs no discretionary review; merge normally without waiting on CI. Protected implementation requires independent exact-head review, required checks and governed installation. The two are separate.
- Installed checkout is landing-only. Never `git pull`/merge there. Candidate `update.sh`, exact merged target, reviewer report, admission and installation receipt are mandatory.
- Secrets remain in 1Password `vibe_coding` and protected runtime stores. No wrapper calls 1Password while reviewing. Load `secrets-to-1password` before any credential write/refresh; no credential work is needed for planning. Do not rotate under a no-rotation directive or expose values in arguments/logs.
- Full report/packet retention precedes cleanup. Preserve foreign live processes, session metadata, historical checkpoints, ignored artifacts and unique work. Read `cleanup-worktree` before cleanup; age/merged state never authorizes deletion.
- Windows/Linux behavior and actual host identities matter. `edge-alien`, `edge-runn-envy`, `edge-runn-xps` are networking-only: no toolkit installation there. Do not guess aliases or claim inaccessible hosts verified.
- Use America/New_York EST/EDT for human times. No fabricated elapsed interval or future proof. Generic outages, unknown balances and synthetic outcomes are not review verdicts.
- Formal reviewer remains read-only while retaining its promised tools and full source access. Shared-db membership is authoritative; no new cap, quiet disabling or frozen-provider reactivation.
- No shared root handoff rewrites. Keep all live proof on the same owning repair issue. The pipeline's older 14day/50review retirement criterion is independent of this recurrence24h gate.

## 12. Access and environment

Verified during planning: Git access to current `origin/main`; `bin/ai-gh` authenticated read/create access to public popcre/ai-devops; local read access to installed scripts, private reviewer incident packages and shared-db consumer source. Source publication verified push/PR access and the original plan merge; current PR1786 readback determines addendum merge. No implementation or installation was performed. Paid provider/model access, SSH routes, administrator privilege, all install receipts and current balances were **not tested** by planning; do not mark them available from presence of a command.

Start from a fresh `origin/main` worktree. Tools needed: git, Bash, Python3, jq, rg; Node and supported pinned provider CLIs for implementation/live checks. No web server to start. Follow `docs/configuration.md`, `docs/deployment.md`, `docs/reviewer-issues.md` and `docs/reviewer-rotation-rules.md` before changing their domains. Use the installed launcher to find private state (`ai-reviewer-issue path`); do not assume it lives in the planning worktree.

Safe inventory reproduction (summary output only):

```bash
ai-reviewer-issue path
ai-reviewer-issue maintenance show
ai-reviewer-issue list | python3 -c 'import sys,collections; r=[x.rstrip().split("\t",5) for x in sys.stdin]; r=[x for x in r if len(x)>=6 and x[3]!="resolved" and "edge-dev3" in x[0]]; print(len(r), dict(collections.Counter(x[2] for x in r)))'
git rev-parse origin/main
readlink -f /usr/local/bin/ai-muse
```

Create protected scratch with `mktemp -d` under a valid session `$TMPDIR`; quote paths and use mode 0700/0600. No fixed shared scratch names. Live commands must come from the current provider skill and supported `ai-review`/consumer help; use full immutable heads, caller identity and assigned slots. This plan intentionally does not give a reusable command with an old source/slot/receipt that would spend stale authority.

No secret item was read; there is no newly required credential or test-user login. Existing provider store owners and 1Password reference locations are documented by `docs/onboarding-secrets.md` and each installed provider skill. Discover those exact references there when maintenance is actually required; never guess an item title. Private fleet topology comes only from the approved machine atlas via `ai-private-config`, not this public document.

## 13. Definition of done, risks, rollback and uncertainties

### Planning deliverable

- [x] This 13-section plan, router/topic links and its own reciprocal handoff pass the self-audit below; all 13 sections and 8 steps verified, referenced existing test paths checked.
- [x] Markdown/whitespace/reachability checks pass; only owned prose is committed and pushed. Re-run the three planning checks in §10; initial publication commit `90cf3a8d` contains only the five owned Markdown files.
- [ ] Documentation PR is merged normally; merged source contains the plan. #1783 records plan publication and leaves repair/live proof unchecked.

### Repair deliverable (not completed by publishing this plan)

- [ ] Every step 1 incident ID is accounted against retained exact evidence with named owner; unknown history is explicit.
- [ ] Discriminating regressions and every adversarial row are executable and pass at the merged head; ordinary review/read/command capabilities survive.
- [ ] Protected source review, CI and queue pass; exact merged source and relevant installed byte hashes/receipts are verified independently.
- [ ] Dedicated verified Muse Code re-pin PR is delivered and edge-dev3’s real **Muse Code (Linux)** stage shows PASS; Windows edits are untouched and applicability verified.
- [ ] Separate housekeeping follow-up eliminates the reported unbound-variable error and proves accurate scheduling-stage status.
- [ ] All four maintained providers pass genuine cold/warm/fresh-process and actual governed consumer acceptance, including substantive defect detection.
- [ ] Paid incomplete/completed-but-unpublished work recovers only with proper identity; no replay, lost findings or foreign-process/evidence damage.
- [ ] >=24h actual observation with per-provider denominators/failures is recorded; quiet time alone is not acceptance. Existing #1301 retirement requirements remain intact.
- [ ] Applicable authorized hosts are independently accounted, frozen callability preserved, and original incident resolutions link repair/test/install/live evidence.
- [ ] Plan STATUS/current state and same-issue checklists are updated; handoff retired only when no carried work remains; no proof-only issue created.

Main risks: mistaking a valid fail-closed refusal for the defect; stale session or receipt replay; destructive cleanup; CI killing a concurrent session; changing shared core while another owner edits it; source installation drift; provider outage masking code behavior; overclaiming from few samples. Gates above mitigate each. If a repair regresses live capability, retain evidence/session descriptors and use the protected installer to restore the last reviewed compatible version; never erase the incident or edit live installed files. Document rollback hashes and rerun original capability checks before resuming the observation window.

Open technical questions are deliberately explicit, not requests to Albert: exact Muse premature-stop cause, first receipt-digest divergence, whether #1370/#1349 source is already landed but unaccepted, exact hanging Windows test/child, and which unresolved historical records already have repaired source but lack resolution entries. Step 1 assigns each, the relevant reproductions decide the answer, and step 8 blocks closure where a maintained capability still fails. There are no unresolved business-meaning choices.

## Mandatory self-audit — completed before publication

Additional report audit: the original plan had generic installation requirements but no explicit native Linux pin-drift deliverable or housekeeping false-PASS follow-up. This update closes those precise gaps in §§3,5,9–10,13, including source anchors, separate PR boundaries, official provenance, Windows edit preservation, named negative tests and actual stage-PASS acceptance. No re-pin or scheduler repair is claimed complete.

All 13 required sections are present. Goal/goal-wins: §1. Newcomer background and environment: §§2–6,12. Scope/exclusions: §4. Exact source anchors/current delivery: §5. Proven versus unknown causes and dead ends: §§6–7. Locked/open choices: §8. Every numbered step has targets/dependencies/observable gate: §9. Trust boundaries have named adversarial tests: §9 table. Required existing commands/suites and proposed tests are distinguished: §10. Safety/access/secrets: §§11–12. Commit/push/merge/install/live proof and rollback: §13. Plan/handoff link both ways; AGENTS/topic/task-router links make this discoverable. No memory file is changed: standing instructions allow memory writes only on Albert's explicit memory-update request.

1. **Could a brand-new AI session execute without asking for chat context? Yes.** §§2–5 identify repos/host/versions/incidents and prior owners; §§9–12 specify exact targets, commands, dependencies and verification. Unknown technical causes have bounded discriminating investigations rather than guessed fixes. No owner's technical approval or unstated business choice is needed.
2. **Does this carry all relevant background, nuance, rejected approaches and reasoning? Yes.** §§3,5–8 preserve the multi-engine failures, consumer-contract mismatch, intentional guards, stale-memory correction, existing shared runner and distinction between unresolved incident counts and actual reliability. §9 preserves legacy owners, spent authority and the separate #1301 criterion.
3. **Can the implementer make a correct judgment when a step proves wrong? Yes.** §1 prioritizes preserved trustworthy reviews and original capability; §§8–9 give locked constraints and measurable criteria; §13 keeps uncertainty, rollback and honest completion boundaries explicit. Reproduction evidence may change the repair location, never the acceptance or evidence requirements.
