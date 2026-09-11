---
issue: 159
status: OPEN
owner: codex/159-session-closeout-20260911
---

# HANDOFF — #159 reviewer delivery (2026-09-11, EDGE-DEV/Codex)

## 0. Decisions only the owner can make

None needed for the next repairs. The programme is NOT complete. Already settled on September 11: finish all #159 children in production; preserve every capability and safety boundary; use isolated current-upstream worktrees and independent exact-head review; no database structure changes, no messages or issues to the shared-db orchestrator. Do not reset maintenance round `0c62f3dffce145c4b2768855b912b958`. #398 runs last within #337; #166 runs last within #159. User subsequently invoked session closeout. Preserve unfinished work and do not add new scope. Do not interpret pending technical verification as a request for owner permission.

## 1. What this application is

`popcre/ai-devops` is a public recovery toolkit, primarily Bash/Python/PowerShell reviewer wrappers, safety gates, installation tools and offline tests. Installation on EDGE-DEV Windows is deployment. Canonical checkout `C:/repos/ai-devops` is landing-only. Task trees live under `C:/repos/ai-devops-worktrees/`. Private `.ai` directories hold provider evidence and experiments; never publish raw evidence, transcripts or credentials. Application-tooling consumers also exist in `u2giants/shared-db`; this session did no database work.

## 2. Goal and trigger

Continue parent [#159](https://github.com/popcre/ai-devops/issues/159) and reviewer programme [#337](https://github.com/popcre/ai-devops/issues/337): source identity #393, terminal diagnostics #394, evidence #395, availability #396, recovery #397, Windows containment #271, usage #333, shared primitives #169. Complete root-cause fixes, review, CI, merge, install, live verification and affected private incident reconciliation. Read AGENTS.md, docs/task-router.md and both root plans first. PR #344 was inspected before #393; its source-base problem is covered by #410, but final consumer acceptance is still pending.

## 3. Current state — verified closeout snapshot

At 2026-09-11 11:52–11:55 UTC GitHub main was `c44c10278a7db965f25f22e58ed6a27384606963`; canonical installed checkout remained clean at `ecbbe4cd2391ff64f9f645dbdcf125fb4a83ec1c`. No Runner.Worker process appeared in the closeout query. Do not assume this remains true on resume.

### Delivered

- #410 source identity merged `d8e7450d9d886742ec7f653c268b197fda028dc4`, installed. Landing run `34577200959` passed. Nine-wrapper proof is in `tests/verification/reviewer-reliability/issue-393-source-identity.md`. Source CI `34572992566` qualified; hosted reviewer job `103181620271` passed after the primary lane timed out. Governed consumer live acceptance remains open.
- #411 queue evidence repair merged/installed `be5f1e2c25e12abc4b0c57cf1f1f11ffc83811b1`, queue `34574548945` passed. Helper SHA256 `7E37E1BC87C3AC1A7858FBE2DD0BDF2AFD002A6799FAD8EFB6E31B747341D042`.
- #169 is CLOSED with installed verification in `tests/verification/reviewer-reliability/issue-169-installed-primitives.md`. #405 DeepSeek Unicode and #408 Grok concurrent authentication fixes landed and were installed. #423 updated both plans at installed `ecbbe4cd`.
- #417 DeepSeek governed exact-head verdict fix merged at 10:11:34 UTC as current main `c44c1027`. Original head `e90ecb3ffaf480b9822587981c60be496403f1dd` received independent GLM APPROVE, SHA256 `b6db37e43f3b31bbfb8915f4e0e5ec662fe790d70cf376265d2f2ec0c37e328c`. **Not installed at closeout.** Landing run `34585150426` is FAILURE: `merge-group-evidence` job `103217520332` failed, Linux passed, Windows skipped. Four subsequent workflow_run jobs succeeded (`34589050889`, `34590325047`, `34592715108`, `34595171400`), but those alone do not prove the failed evidence gate repaired. Inspect exact outputs before installation; do not claim landing CI green.

### Open repair stack (all pushed, retained, no automatic merge enabled)

Each worktree below is under `C:/repos/ai-devops-worktrees/`; PR URLs use `https://github.com/popcre/ai-devops/pull/NUMBER`.

- **416 / 396-kimi-scoped-refusal** head `84ef3a549181ef474ac847944060e48d7edb37c0`, base main. No failing checks at snapshot; reviewer safety pending. Prior core head `704d3f002fe7b09960b9bb3d262bb6bd9b687313` approved, report SHA `93543EB69455B09D6A62E981330C400A2D6E96B252D4F92DFB0226ECBC4FDED5`. New head adds measured Qwen readiness fixture fix `d7357051`; exact-head review hit GLM quota, so it has NO approval. Focused admission 30/0, preflight 92/0, Python 9/0. Scoped fresh refusal, OS lock, delegated effective profile and legacy quarantine preserved. Installed probe `.ai/probes/396-installed-admission.sh`, use `AI_KIMI_ADMISSION_TEST_ONLY=1 AI_KIMI_LIVE=0` after install; expect 30/0 and unchanged real quarantine hash.
- **420 / 333-truthful-reviewer-usage** head `32a260b9672bdafd41e358b96b659a7fba9b7402`, now base main (GitHub retargeted after 417 merged). Independent APPROVE SHA `70803A8C76FBB2E9D243A8385E8579287CF65C130C1BEF52FFF32A9CDA368A54`. CI `34580110309` fails Windows section4 Qwen interrupted managed credential cleanup readiness, 118/1. The exact fixture fix d735 is now on main; absorb main before re-review. Muse44/0, Grok14/0, DeepSeek46/0 plus 10 concurrent, formatter13 cases, GLM4/0. Live Muse retained fixture proved session recall, not a savings claim. Installed accounting acceptance pending.
- **421 / 395-durable-review-evidence** head `04388344c83ab7b1d29f5b8d51fd4c731ac39742`, base `codex/333-truthful-reviewer-usage`. Independent APPROVE SHA `04D90F489227DE633AAE022FF0C6B654E9AA2BB639D4A87867045F9B568C0EE6`. CI `34581475589` FAILS genuine cases below. Do not merge or rerun unchanged. Root owns this diagnosis. Earlier local core91 passed/4 skipped, helpers27/0, Qwen19/0, Gemini2/0, Kimi15/0. Installed probe `.ai/probes/395-installed-evidence.py` expects source_removed, exact report+binary recovered, provider_submissions=0.
- **422 / 397-glm-expired-terminal** head `13625aa6ccbfc1baa32eff6f96ea97cf4d5207b3`, base `codex/395-durable-review-evidence`. GLM APPROVE SHA `C79E77DB3BF496FBBEBE7A58B1F0267F022EF18C3E90A3BAE0A675BCBAC05FC0`. CI `34581634887` inherits Linux and Windows1/3/fallback failures. Includes Qwen local finalization, GLM exact retained GET recovery/deadline, auth pipe, Muse atomic metadata, DeepSeek caller/model identity. Reviewer runtime tree `397-qwen-local-finalization` was advanced to 6257622 for later review; do not confuse it with frozen PR422 tree.
- **418 / 394-grok-terminal-reasons** head `03c6c3949364c15ad8b4520d493097dcb97184e3`, base `codex/397-glm-expired-terminal`. CI `34582893727` Linux/Windows1/3/fallback fail. Final GLM review was pending when quota surfaced, no final approval established. Native/provider tests27/0, modern+legacy local failure receipts24/0. Legacy receipt proves local wait expired, not remote termination or an authorization to clear a fence.
- **419 / 394-qwen-terminal-diagnostics** head `c49878670fecc37298f952e921f6ea09bbe7777f`, same base. APPROVE SHA `8ce422c7fe9372eb119305c0b6850b92a97d322c947a5b4fb589b62b2ab604da`; CI `34580315750` inherits above failures. Typed content-filter refusal, private stderr hashes, no verdict from success-looking text.
- **424 / 397-deepseek-local-finalization** head `6257622b881d626cce0caf8528814da414c9eff9`, same base. CI `34584602892` inherits above failures. Final GLM review unresolved after quota. Focused recovery25/0/0, identity32/0/0. Prospective pending transaction binds identity and response hash before paid request; local finalization never replays payment, tamper refuses, unknown transport stays fenced.

All #393–398, #271, #333, #337, #159 and #166 remain OPEN, verified live. #344 remains open. No completion was inferred from a review alone.

### Uncommitted work explicitly retained

- `397-deepseek-stale-mutex` at 6257622: modified `bin/ai-deepseek-agent` and `tests/test-ai-deepseek-agent.sh`. Source agent's unfinished lock recovery experiment; do not discard or stage into another PR. Log `.ai/deepseek-stale-lock.log`. Closeout read the final log: passed16, failed0, skipped0, including alive owner/reused PID, inspection failure, foreign namespace, unknown transport, dead-owner finalization and normal continuation. Code remains uncommitted and independently unreviewed. Proposed receipt binds host/namespace/token and completed HTTP hash, refuses foreign/unknown owners; no PID-only takeover.
- `394-deepseek-native-terminal` at `287574d1e544dcbc7d0d0b154f7438745f644dbf`: same two modified paths. Programme agent's finish_reason handling, coordinated with local-finalization helper. Earlier baseline1/8 reproduced false acceptance of incomplete native finishes; 17-case follow-up result must be recovered, not assumed passed.
- `271-lpac-executor` at ecbbe has clean tracked files, but unique ignored `.ai/lpac-probe.py`, `LpacAdapter.cs/.exe`, `BoundaryCanary.cs/.exe`, `volume-acl.py`, `exec-protocol.rs`. These are private unfinished prototype evidence; keep tree. No installed capability changed.
- Other repair trees have private `.ai` artifacts even when tracked status is clean. Preserve all; do not run broad cleanup. Frozen runtime `159-frozen-review-runtime-6538` at `6538f0c69f16af775547f1bcdab8f8382974412d` was used for root reviews; never edit code under an active shell.

## 4. Failed attempts and why

1. GLM returned HTTP429/code1308, usage limit reached for5hour, reported reset `2026-09-11 18:39:20` **without timezone**. Wrapper polled terminal finish=error until1800 seconds, mislabelled timeout. Do not repeat paid calls based on a passing doctor, invent reset timezone, abort/replay or erase original fences. Incident recorded privately as `20260911T114520Z-edge-dev-glm-1781` under canonical `.ai/reviewer-issues/`.
2. Root #396 Grok review of older head ac8 timed out900 seconds. No verdict. Work `48c3f52ce4f67bb7fa0e1076687e5603` remains uncertain. Private incident `20260911T081145Z-edge-dev-grok-1823796`; local-wait receipt does not establish remote exit.
3. #395 patch-publication ordering repair189f48ad fixed two real partial-export fixtures (red0/2 to green2/0), but subsequent full CI found five other failures. Earlier green focused tests cannot substitute for those cases.
4. Native Codex0.153.2 and isolated official0.154 could read outside the packet despite root deny/minimal policy. PR44327 did not fix it. No WSL distro; virtualization disabled. No global upgrade, reboot or feature enablement was done.
5. Initial LPAC prototype used wrong process attribute14; correct opt-out is15. Its earlier initialization failure was invalid evidence. Token information class46 returned ERROR_INVALID_PARAMETER87, so false output did not prove child escape. .NET network initialization failure was not network denial proof.
6. Known #166 waiter mislabels its deadline as unreadable PR and treats cancelled original lane as failure despite qualified replacement. Use compact exact GitHub queries for now; repair #166 last, no unchanged retries.

## 5. Root causes and key evidence

### Immediate #395 regression diagnosis

Private logs in `395-durable-review-evidence/.ai/`: `395-job-103206405729.log` Linux, `395-job-103206405824.log` Windows1, `395-job-103206405759.log` Windows3. Linux failing names: `interrupt_records_terminal_state_and_cleans`, `aborted-partial exports before cleanup`, `patch_failure_preserves_recovery_evidence`, `live doctor keeps malformed cost unknown`, `delete cleans hash-mismatched state but keeps human artifacts`. Windows Kimi219/1 and GLM261/3 reproduce subsets. Ignore the harness's deliberate FAIL example.

`tests/test-ai-glm.sh:427` run_fake_impl creates isolated repo and stubs provider; :563 interrupted session, :626 patch failure. Real publication preconditions may interact with terminal cleanup; diagnosis not yet proven. Existing `395-glm-partial-publication` tree contains earlier real-binary probe; reuse it.
`tests/test-ai-kimi.sh:564` corrupts persistent metadata patch_sha256 then deletes; `bin/ai-kimi:2115` archives implementation metadata and verifies archive before cleanup. Determine whether archival refusal or human-artifact count is failing before changing assertions.
`tests/test-ai-grok-review.sh:684` pipes live doctor to grep for unknown cost; `bin/ai-grok-review:1349` owns doctor. Capture output and exit status; pipe failure is a hypothesis only. Existing usage probe builder lives in `333-truthful-reviewer-usage/.ai/`.

### Quota evidence and recovery

`396-kimi-scoped-refusal/.ai/glm-terminal-metadata.json` records message `msg_08fbbbb72001kA5sZfGXfUCFG2`, session `ses_f7078be97ffeDJmsKmoaHngraD`, invocation `3384f1b798ad4b3a923cbe5e23025361`, head84ef. Private `.ai/glm-terminal-metadata.sh` sources frozen wrapper's last_assistant helper and emits only diagnostic fields. Original review log `.ai/availability396-fixture-followup.log`. Repair under existing #394/#397 and scope-aware #396; no symptom issue. Inspect existing 418/424/consumer2750 requests read-only before deciding their outcome.

### Windows containment research

Correct zero-capability LPAC ran official0.154 exec-server over stdio. Packet read, outside-file denial, source-write denial and scratch-write success were observed. DOS/GUID canonicalization failed because MountPointManager is unavailable to LPAC. Confined adapter used NT final path plus sealed startup volume map and verified reopened file ID/volume under the same token; no device ACL relaxation. Copied shell launched with registryRead process capability; a synthetic private registry key remained unreadable. Final child restriction and direct Winsock network-denial proofs remain pending.
Official tag research is in `333-truthful-reviewer-usage/.ai/271-research/`. Isolated CODEX_HOME/environments.toml uses default=lpac and include_local=false, external program transport; config enables deferred_executor (under development/default false). Parent local zero-cost Responses HTTP stub can drive function_call/exec_command followed by assistant output. Prove every file/search/patch/process path uses LPAC, unavailable executor fails closed, and model loop works before any paid canary. Keep actual runtime provenance, not exec-server's misleading0.0.0 handshake version.

## 6. Exact next steps and acceptance gates

1. Re-read router/plans, fetch upstream, inventory PRs/worktrees/runner and current installed SHA. Inspect417 landing failure and subsequent evidence runs. Gate: distinguish qualified landing evidence from helper success; only then serialize install.
2. Reproduce #395 five failures using retained stub fixtures; make smallest capability-preserving repair, run focused cases then required suites. Gate: all actual failed cases green, exact-head independent review and required CI pass.
3. Coordinate one owner for GLM terminal usage refusal and retained recovery. Inspect retained terminal objects without new paid request. Gate: exact refusal exits promptly with typed evidence, no replay, correct pending/fence disposition; obtain outstanding reviews through a qualified available provider.
4. Absorb current main into333 (readiness fix), retarget stacked PRs to actual landed main in order333→395→397→terminal/follow-ups. Never merge into a temporary base. Re-review each changed exact head. Gate: correct owned diffs, passing checks, merge queue and installed hashes.
5. Resume private LPAC prototype with behavior-based child restriction sentinel and direct Winsock tests, then zero-cost complete model-loop routing and fail-closed tests. Gate: original reviewer functionality plus read/write/network isolation; only then paid live review.
6. Complete consumer source/admission acceptance below after installed wrappers, then reconcile each affected private incident append-only. Gate: exact-source governed execution and durable accepted artifacts, not presence or doctor alone.
7. Only after components complete run #398 original198 record dispositions, installed nine-provider matrix and recurrence scan; then #166 final throughput/cutover proof. Update both plans and issue evidence. Gate: every child truly complete in production before closing159.

## 7. Constraints and gotchas

Never contact shared-db orchestrator or open issues for it. Closeout skill's generic routing requirement is overridden by the user's explicit prohibition. Marker2714 was observed open read-only and is not ours. No DDL, schema, data loads, migrations, cloud mutations or broader credentials. Do not touch another task's handoff or branch. No full Windows test suite while Runner.Worker active. Preserve actual caller=codex and exact source base/head; never bypass provider wrapper to buy a review. Frozen198 started record expected hash `aad9e0f327a135d8b684f03768b702aa675981f738924b468215ef61aeefa8f0` (historical verified value, recheck without resetting).

## 8. Access and environment

Authenticated gh CLI; Git Bash `C:/Program Files/Git/bin/bash.exe`; Python and PowerShell. Commit identity verified `Albert Hazan <u2giants@users.noreply.github.com>`. Credentials remain in 1Password vault vibe_coding and protected installed auth files, never print values. Installed `C:/Users/ahazan/.local/bin/ai-deepseek-agent` is a managed Bash launcher executing canonical bin/ai-deepseek-agent, not a symlink. Installation lock `C:/Users/ahazan/.local/state/ai-devops/159-install.lock` requires exclusive FileShare.None handle; do not delete it. Root alone handled installation. Capture active job logs with gh api actions/jobs/ID/logs into private files when gh run view refuses an incomplete run.

## 9. Open questions and risks

Current CI failures prevent safe merging of most stack. GLM availability is unknown until truthful refusal/recovery diagnosis; reset timezone unknown. #271 prototype is not production-qualified. Private worktree evidence must survive cleanup. Main417 merged with a reported landing-evidence failure; do not imply installation or complete qualification. All counts, states and SHAs must be refreshed before mutation. No new owner decision identified during closeout.

## Agent handoff blocks

### programme_audit

Owned417 governed DeepSeek,418 terminal diagnostics,419 Qwen, native DeepSeek unfinished tree, and nonstructural consumer PRs2749/2750 in u2giants/shared-db. No DB writes or orchestrator contact. Consumer2749 source-contract worktree `393-governed-source-contract` (under shared-db worktree parent), last known head798bef82,60/0 source tests; older exact Grok approval eedc5acd cannot approve newer head. Consumer2750 `396-scoped-reviewer-admission`, last91b3f9e8,524/0/0 tests, earlier Muse approval but newer GLM unresolved. Older manager-policy PR2738 creates a filename collision and was DIRTY at560dfed; do not weaken the guard or take over unrelated work. Refresh both PRs and exact filesystem location through shared-db git worktree list; these consumer facts are prior-session observations, not closeout-live proof. Read applicable router STATUS without contacting orchestrator.

### source_audit

Owned422 recovery,424 DeepSeek retained transaction and uncommitted stale mutex experiment. Delivered Grok receipt commits0ba545dc/f4fb7021 to programme. Actual legacy2726 receipt `.ai/legacy-2726-local-wait.json` in397-grok-local-failure SHA `98557D6EE426F2E5BF5A46FA5A0E231A7BE0D0AA79EF565329352150A7A9EAA3`; root396 receipt `.ai/legacy-396-local-wait.json` SHA `71AC88C2377BFDA85D71061C5B52334EEFA31BE5E8D9499C6A0F74C0E4291826`. Both prove local wait ended only. Do not clear original fences or mutate external2726 lane.

### maintenance_audit (historical agent, no longer in live agent list)

Delivered396 fixes,395 durability pieces, then271 LPAC prototype. All prototype files and limits are recorded above. Did not change host/device ACL, accounts, global runtime or install. Resume in its existing isolated tree after inspecting ignored artifacts; do not discard unique experiments because tracked status is clean.

At closeout only programme_audit and source_audit appeared in agent inventory, both pending_init. Messages requested checkpoint/status; no reply available at snapshot. Do not assume a test or provider process still runs merely because an old tool session ID exists; inspect exact process/retained evidence safely.

## Self-audit

1. Can a newcomer resume without chat? Yes: sections1–3 establish product, exact delivery states and branches; section6 supplies ordered gates and section8 access.
2. Can they continue with the knowledge retained here? Yes: sections4–5 preserve failed approaches, concrete failing tests, quota evidence, prototype boundaries, and agent blocks retain separate ownership.
3. Are relevant goals, failures, decisions, risks and evidence included? Yes: sections0–9 distinguish current verification from prior observations; no approval or prototype is called production completion. Uncommitted paths and private evidence preservation are explicit in section3.
4. Does section0 contain every owner decision? Yes: reviewed sections1–9 and all agent blocks; all remaining gates are technical work, no new human authorization requested. Existing prohibition and frozen-round decisions are consolidated in section0.
All ten sections are present; each next step has a gate; failed attempts are explicit. The handoff passes the audit for preserving this unfinished programme, not for claiming the programme complete.
