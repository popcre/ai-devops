# GLM own-output recovery — implementation plan

## STATUS — read first

Owner: Oracle parent #24 coordinator; source lane Codex /root/s03. Existing defect [#1791](https://github.com/popcre/ai-devops/issues/1791). Root approved bounded B–D source architecture and explicit activation with immutable reviewed runtime copy. First afadf382 SECURITY review REJECT is retained: declared moving base had advanced to sibling #1793; unconditional formal selection preceded installation readiness. Rebased onto immutable b20da460df6b3c18410723a50899a7ed7c586413, preserving sibling work, and substantively fixed activation. No installation or real GLM original-capability proof occurred. Fresh final-head verification/review/shipment remain open; source preparation is not accepted repair.

| Step | State, October 15, 2026 EDT | Evidence |
|---|---|---|
| A diagnostic and causal proof | source prepared; final regression open | metadata-only exact caller/session diagnostic; prior 399-test run predates final edits |
| B isolated formal profile and origin receipt | revised source prepared; final independent review open | explicit protected activation; full tracked release snapshot; sealed private inventory/config/core .gitignore;28 focused tests |
| C instruction preservation and new-run protocol | source prepared; final packet regression open | scoped instruction bytes/hashes; original deadline/account/run/head/packet retained; five wrapper-control cases pass |
| D own-output recovery and pinned fixture | source prepared; final-head proof open | actual pinned isolated fixture reconstructs all nine pages byte-exact and denies another session; no provider or production origin |
| E review, shipping, installation, original capability | open | #1791 live-proof checklist remains unchecked |

Next: freeze candidate, run final exact-head relevant suites when the same-host CI collision gate clears, then obtain assigned non-GLM SECURITY review. Existing shared service and old sessions remain untouched. [Coordination baton](HANDOFF.d/2026-10-16T0234Z-edge-dev3-codex-glm-own-output.md) links back here. Root HANDOFF.md stays unchanged.

## 1. Ultimate goal

A GLM reviewer must be able to read the full output of its own earlier file read and finish its original review, while every other session's output remains inaccessible. Preserve its existing review depth, repository instructions, tools, account rules and source identity. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Application and ownership

`popcre/ai-devops` is Albert Hazan's machine-installed reviewer/tooling repository. Source worktree `/home/ahazan/.codex/worktrees/glm-own-output-routing/ai-devops`, branch `codex/glm-own-output-routing`, began at `d70a9e3a00a96c3b0a1e35a7a3c6c42b9ba5c8e9`. The installed checkout is separate and must never be edited or pulled. This first repair target is edge-dev3 Linux. Normal `ai-glm` also implements tasks, so formal review isolation must not change the general service. OpenCode pin is `config/opencode/version`, currently 1.18.12.

## 3. Trigger and reproduction

Oracle processing-context security review failed on its own saved output. Incident `20261016T020434Z-edge-dev3-glm-1179957` was encrypted/synced with 23 files; original wrapper recovery log `/tmp/tmp.6ZU5vfAHUY`. Exact safe error: `GLM permission failed: unknown permission action: external_directory`. Original session `pool-glm-bef76752c3adb1f4`, caller `zcode`, server session `ses_ebd901072ffeFs8aurMXt84za0`. Owned read `call_806d5646f98a498f9e8f2687` completed with outputPaths naming `tool_142700e55001lzuOCXNrp86Unp`; later running read `call_cdf3afc7b4fa475aa81de8a0` requests that same file. OpenCode requests parent wildcard permission. No global output files were inspected.

The old run is NOT eligible for this new protocol. It binds old head `5eb315d153b78cc5d069f4050295227e26479fbd`, packet `8b776c556cc422a5a0d66ad4405b7b72136d7fec69bb586272882a2d7f543209`, original invocation `877848b00d7a4db5af350f0fc9d564ce`, deadline October 15, 2026, 10:29:54 PM EDT. Current source moved. Do not resume, renew, migrate, backfill or spend a new provider turn on that old authority.

## 4. Scope

In: metadata-only diagnostics; a NEW explicitly installed Linux formal-review profile; immutable repository-instruction preservation; protected launcher origin receipt; one own-output recovery per newly admitted review invocation; offline and pinned local-transport fixture proof; independent security/final review; ordinary PR and protected installation followed by admitted live proof.

NOT in this plan: widening external-directory grants; global config changes; changes to general `glm-implement` or custom MCP workflows; Windows profile activation; reviewer step/turn/token caps; new API key/account or fallback; old-session renewal; Oracle source/schema/runtime/company processing; cross-session output discovery or cleanup; changing model/provider; modifying installed OpenCode binaries. Windows formal-profile requests fail explicitly until separately qualified, while normal Windows GLM remains unchanged.

Bounded implementation estimate: three source groups B–D, approximately 8 existing source/config files plus 3 internal helpers/tests, no dependencies added. Installer/profile and recovery are separate testable concerns but one issue/PR. Exact deployment stays a later gated technical action, never a request to Albert.

## 5. Current source and untouched state

`bin/ai-glm:33–76` selects config/password/state/port; `mark_remote_turn_pending` around line466 seals deadline/head/packet/run; `handle_permissions` around1247 strictly rejects unknown actions; `await_turn` around1430 publishes final stop; `read_prompt` around1565 preserves original prompt prefix; `cmd_recover` around1691 never submits prompts; `cmd_transcript` around2346 is now locally modified for metadata-only JSON. General text transcript remains unchanged. Local diagnostics and tests are uncommitted.

`bin/setup-opencode-glm.sh` now accepts explicit formal-review installation through `tools/glm_formal_profile.py`; its no-argument general path remains unchanged. PowerShell and canonical agent/config/general unit are unchanged. Linux pool selects formal review only after protected installation/activation; Windows retains its current general route. `bin/ai-review-packet` incorporates exact scoped instruction assets into its existing hash/verification contract.

Absent activation selects the existing general route. A present malformed/stale activation stops without fallback. Ready activation selects only the hash-validated pinned wrapper under the private SHA runtime directory. Provisioning/starting a profile alone never activates routing. The explicit `--activate-glm-formal` installer/updater option publishes activation only after protected finalization, current installed manifest/tool identity, actual fixed origin and authenticated health agree. It is not an environment toggle or caller-supplied JSON grant.

The initial private prototype remains historical only. Candidate `tools/glm_output_recovery.py` is integrated with protected actual origin resolution and wrapper lifecycle. It preserves raw output plus a schema-specific lossless readable view inside the disposable remote-less clone's real `.git` directory, never a worktree pointer or original source metadata directory. No shared wildcard is granted.

## 6. Findings and root cause

Pinned 1.18.12 embeds two different execution paths. Legacy read/grep/glob set `metadata.truncated`; generic Tool.execute returns early. Legacy `tool.execute.after` therefore does not prove an applicable v2 repair. V2 `ToolRegistry.settle` executes builtin then `ToolOutputStore.bound`, which writes into fixed `join(data,'tool-output')`, returns outputPaths, and has no legacy after hook.

V2 read first resolves an external absolute path, then asserts `external_directory`; resolver emits parent/* even for files, BEFORE ordinary exact read permission. Granting exact read permission cannot satisfy that precondition safely. Its supported rejection feedback is also lost: exact builtin read maps PermissionV2.CorrectedError to generic `Unable to read <path>`.

Pinned source-expression fixture `/tmp/glm-pinned-feedback-ov9a86uh/fixture.cjs` (with provenance.txt) proves the error mapping without provider calls; it is NOT full-server integration. The live owned-session metadata diagnostic established genuine own read-to-read provenance, not fabricated wildcard speculation.

`OPENCODE_DISABLE_PROJECT_CONFIG` is supported, but also disables project AGENTS discovery (v2 source byte98472430, plus legacy instruction loader). Applying it to the shared server would affect both review and implementation and remove required instructions. Existing setup has no separate managed profile route: changing CFG_DIR/PORT alone overwrites shared launcher/unit and retains global data paths. This is source work to add, not missing external authorization.

## 7. Rejected approaches

- Shared parent wildcard approval exposes sibling/other-session outputs: forbidden.
- Exact file ordinary-read grant still meets prior parent wildcard gate: ineffective.
- Legacy after hook does not cover measured v2 bound store: ungrounded.
- Rejection message alone loses the new copy path in actual builtin read: measured failure.
- Global disable-project-config removes AGENTS and changes implementation: capability loss.
- Alternate config/port with unchanged installer overwrites shared launcher/unit: collision.
- Retry old run, rebuild/reset packet/deadline, spend another account/key, or change reviewer to hide failure: forbidden.
- New reviewer step/turn caps contradict Albert's locked policy; no such caps are introduced.
- First independent afadf382 SECURITY verdict was REJECT (run20261016T034154-1906454-7882,235s). No authored Muse change existed; the moving base introduced reverse sibling material into the packet. Rebase and immutable actual ancestor fix packet validity, never erase the rejection. Unconditional Linux pool routing was a real deployment defect, fixed through explicit activation. Low .git mirror digest exclusion remains an explicit intentional limit with private raw provenance.

## 8. Decisions

LOCKED October 15, 2026 EDT: root retains security/install/merge decisions; new formal profile only; same subscription account, original absolute deadline, run/head/packet/provider identity and quota admission; max one mechanical recovery per run AND output; unknown provenance/binding stops; general service untouched. Owner quote in `plan_reviewer-spend-waste.md:99`: “LOCKED (Albert, 2026-10-07): never cap turn/step budgets; Qwen's 120-turn raise stays.” This outranks proposed new financial/turn caps. Recovery count is an idempotence bound on wrapper repair, not a cap on reviewer reasoning or tools.

Root approved the explicit Linux formal-profile route and instruction contract for source implementation only. Source line estimates may drift; resolve symbols, not guessed offsets. Any failed independent review remains a rejection until substantively repaired; no installation or runtime admission follows merely from this source approval.

## 9. Executable steps

### A. Finish diagnostic (independent source preparation)

Keep `transcript --json` metadata-only, validate stored caller/name/session before authenticated API use; fixed field names, no model/source/reasoning/input/output contents. Expose only exact canonical managed-output references as metadata claims, never as file-read authority. Update `tests/test-ai-glm.sh` redaction, invalid ID/caller, traversal/foreign root and unchanged plain-text tests. Gate: offline GLM suite plus formal-prompt suite pass; no provider POST in diagnostic fixtures.

### B. Add explicitly isolated formal-review profile

Extend `bin/setup-opencode-glm.sh` with fixed enum `--profile formal-review`; default general behavior byte/functionally unchanged. Formal profile gets distinct launcher, systemd unit, config home, password/maintenance lock, state and XDG data/cache roots, and its own port chosen through one documented formal-profile setting. Never reuse general unit/launcher path, never overwrite shared profile. No new provider key/account: use same existing protected Z.ai coding-plan injection route. General implementation process remains unchanged.

Create internal `tools/lib/glm-profile.sh` (or one equivalent owned helper) resolving only fixed profile names to paths. `bin/ai-glm` accepts formal-profile routing only as explicit wrapper-controlled selection from the formal GLM door in `bin/ai-review-pool`; ordinary new/ask/implement keep general profile. No caller-supplied arbitrary server URL, receipt path, tool/model override or directory grant. The Windows installer rejects formal-profile install explicitly before mutation; normal installer behavior unchanged.

Formal launcher uses supported pinned `serve --hostname 127.0.0.1 --port <formalport>` and supported project-config-disabled environment only in that process, not global defaults. It emits an atomic private receipt after process launch/health verification binding PID/start identity, loopback endpoint, exact binary/version/hash, launcher/config/agent hashes, config/data roots and disabled project config. Receipt is protected launcher state, not a repository marker or caller JSON. `bin/ai-glm` verifies live process identity plus receipt/files/hashes and absence of MCP/custom-read overrides before creating any eligible new run. Unknown or mutable origin fails closed. Formal config installs fixed read-only builtin tools and no plugin/MCP custom tool providers; provider is same GLM coding-plan fixed model.

Gate: mocked installer proves distinct paths/no shared writes; receipt mutation/stale PID/version/config/agent failures stop; general existing installer/server/implementation tests unchanged. No installed activation during source work.

#### Reviewed release snapshot and activation contract

Copy the complete Git archive of the clean, installed, merged release into fixed private `~/.config/ai-devops/glm-formal/runtimes/<full-SHA>`; compare archive entries with exact Git-tree inventory and bytes/modes. Never copy the working tree, `.git`, untracked/private overlays or arbitrary caller paths. The sole known `transcripts` gitlink is recorded by commit pointer and excluded without opening or initializing its private repository; unknown gitlinks and tracked symlinks/special entries refuse. The complete public code archive covers every actual WRAPPER_DIR dependency, including wrapper, packet, sandbox, reviewer events, policy/config and shared helpers. Do not guess a partial transitive subset.

Each immutable runtime has a private manifest of source SHA, every tracked blob hash/mode, audited critical-code inventory and excluded pointer. Existing cache must match actual Git archive, not merely its own mutable manifest. Settings and live origin bind the runtime manifest hash; wrong source/head, inventory/file/permission drift or symlink refuses. Launcher and activated pool invoke this pinned code. A later canonical update cannot mutate an in-flight wrapper or its helper chain. Exact compatibility dependencies are the explicit `CRITICAL_FILES` set in `tools/glm_formal_profile.py`: GLM/capture/config plus actual evidence, accounting, policy and shared safety helpers; standalone Muse/other-provider/app implementations are excluded. Full copied inventory remains1517 blobs, not a partial dependency copy.

Current installed front door still enforces current rotation/admission/global policy and supplies its fixed current preflight/lifecycle paths. Unrelated forward source/provider movement is allowed only after fresh installed-manifest validation, proven ancestry and identical audited GLM/shared-safety dependency inventory. A protected updater checks target Git blobs BEFORE canonical advance; an essential dependency change stops the installation while existing general and pinned formal capability remain intact. It requires a separately qualified exclusive profile upgrade, rather than silently advancing and leaving GLM broken. Source guard tests allow unrelated Muse code and deny changed GLM safety before head movement. An actual invalid/stale activation never falls back or renews the old review.

Reuse existing profile-local `opencode-maintenance-lock.sh`: authenticated invocations retain their shared lock through the original/corrective turn; formal setup takes exclusive before configuration/runtime/password/unit changes (only safe private lock-parent bootstrap precedes it). General locks/service and existing general sessions are untouched. Exact ready active setup is a read-only no-op; changed active profile refuses before writes. Future critical profile upgrades require a separately reviewed explicit exclusive reprovision/version switch, never automatic overwrite.

Only the existing protected installer/update process may publish activation: real inherited fd9 must identify its private checkout installation lock, exact parent script must match the installed reviewed code and repository, and explicit option must be present. Caller flags/environment/repo JSON alone do not establish issuer identity. After all required stages/finalization, take existing formal exclusive lock, validate actual installed manifest/tool hashes and complete pinned critical code, actual live origin and bounded authenticated loopback health without proxies, then atomically write0600 activation. Supported completed-install retry may publish a still-absent record; explicit same-code healthy re-attestation never rewrites an original review's protocol/deadline. No actual installer or production origin is invoked by tests.

Snapshot retention owner is the protected formal-profile installer on #1791. Keep old version directories by default. Retirement needs exact activation/settings/session-reference reconciliation, no in-flight original/corrective invocation, retained incident/review evidence and a reviewed recoverable cleanup; then retire only that exact unreferenced release path. No age-based deletion, global scan cleanup, or automatic old-release removal is implemented.

### C. Preserve applicable repository instructions and issue new protocol

Extend the existing packet generator, not a new packet system: formal-only instruction asset inventories exact applicable root and nested AGENTS in the reviewer snapshot, maps path scope to unchanged UTF-8 bytes and hash, includes bytes in immutable packet hash and verification. Preserve global protected instructions unchanged. For arbitrary permitted repo reads, every corresponding nested AGENTS must be represented; collect snapshot instruction files safely without reading ignored external roots, symlinks, `.git` internals or credentials. An unsupported/oversized/unreadable instruction set stops rather than silently drops content.

Before initial formal prompt submission, append exact instruction asset content with explicit original path scopes to the immutable prompt; original review request remains exact prefix, formatting and requested independent decision unchanged. Root/nested instructions must be applied with their original scope, never flattened into conflicting global rules. Tests compare byte hashes and path-scope behavior to the actual pinned native loader's expected applicable set. If faithful scope preservation cannot be proved, stop B/C deployment rather than remove instructions.

Only after live formal origin, exact instruction packet and existing `capacity_gate` admission pass, `mark_remote_turn_pending` issues NEW versioned own-output protocol in protected metadata, binding run/head/packet/server-origin receipt/instruction hash/provider/model/deadline/caller. No upgrade of old metadata. Existing `cmd_recover` remains observational and non-generating. General `ask`, implementation and old pending sessions unchanged.

Gate: exact original prompt prefix and instructions survive; hashes change on instruction movement; no eligible protocol without authentic live origin; old5eb fixture cannot become eligible. Formal prompt and packet regression suites pass.

### D. Implement one supported recovery and prove pinned path

Use internal helper `tools/glm_output_recovery.py`, invoked only by wrapper with protected stored metadata plus own-session supported API response; no arbitrary file grant or public copy command. In `handle_permissions`, consider only exactly one pending external request whose own session/message/call matches a running fixed builtin read, requesting the exact canonical managed output file recorded by an earlier completed own builtin read in that same run. Reject ambiguous parallel external requests, MCP/custom tools, prior-run outputs, wrong root/head/packet/caller/receipt/deadline or loop.

Atomically reserve one recovery receipt under protected invocation state with O_EXCL0600 BEFORE any mechanical action; a crash/spent reservation cannot retry. Use supported permission response `reply:reject`, never once/always; preserve original failure/provenance. After confirmed rejection, securely copy only that exact output: O_NOFOLLOW descriptor, regular/current UID/nlink1, bounded size, stable inode/size/time and repeated exact bytes, current canonical protected source directory, no scan/glob. Create one unique0700 directory under exact disposable reviewer boundary with O_EXCL0600 file; refuse preexisting/symlink/hardlink/path mutation/collision. Record original IDs/path/hash/bytes, denial receipt, destination and original protocol in protected evidence. No cross-session or shared cleanup.

Wait original provider activity to stop/idle through existing supported status/message polling; preserve that intermediate terminal result as recovery evidence without publishing it as final review. Recheck exact source/packet/instructions/live origin, current subscription quota admission and unchanged original absolute deadline. Then exactly one normal same-session corrective prompt through existing wrapper API names precise private copy and asks completion of SAME original review. Preserve original invocation/lifecycle and initial prompt hash; record added provider submission, watermark and correction hash; never call mark_remote_turn_pending to reset the deadline. Unknown POST outcome fences the run, never retries. No provider/key fallback and no cap on model reasoning steps.

A second external request/recovery or drift refuses visibly. Final publication must bind final result AND intermediate receipt, include both generation usage observations with explicit unavailable scope rather than relabel final-step tokens as full cost, and pass existing lifecycle/ship checks. No old source acceptance or review shopping.

Measured pinned tool timestamps are integer Unix milliseconds; original wrapper start is an aware ISO timestamp. Reject other tool formats, booleans and prior-run values. Before origin attestation the installer creates and seals pinned core's exact `.gitignore` bytes in its private config directory; unknown content/path/symlink drift refuses, never broadens the config inventory after launch.

The pinned builtin's saved TextPage JSON has a long escaped content line that ordinary read truncates. Therefore retain exact raw bytes/hash and additionally render only the measured strict TextPage schema as lossless JSONL pages. Each segment labels original line/UTF-8 byte offset, continuation and exact content hash; controls are JSON-escaped and inserted labels are explicitly wrapper provenance. Preserve offset/truncated/next/EOF metadata; reject unknown schema/extra framing rather than parse arbitrary MCP/model text. Actual original page truncation remains incomplete source, never silently becomes whole-file completion. Rendered rows stay below actual read's line limit, and the fixture reads every page and reconstructs both view and original-content hashes.

Pinned local fixture must invoke actual 1.18.12 through the new supported formal-profile test harness in isolated temp roots, with deterministic loopback fake transport and no real credentials, outside network, actual model or paid provider. Simulate original read that truncates and subsequent exact own-file read. Prove complete byte retrieval from private mirror, standard read paging, other-session/sibling denial and preserved scoped instructions. Test harness must not invoke installed general server or direct operational APIs outside wrapper fixture route. Offline source-expression proof alone is insufficient for runtime acceptance.

Gate: fixtures below, existing suites, actual pinned local fixture receipt with binary/config/agent/instruction hashes and zero external network/provider traffic.

### E. Review and deliver actual repair

Declare reviewer-safety, exact-head independent healthy non-GLM security/final review through `ai-review` with literal immutable ancestor SHA (never a moving origin/main argument), run required source suites, commit owned files only with correct identity, normal PR/checks and root merge decision. Review dissent stays recorded. Root then admits protected candidate installation after fresh checkout/manifest reconciliation. First install leaves legacy pool routing intact until explicit post-finalization activation; no global hold or quota pause is used. Verify installed receipt and both shared general and isolated formal services, all original required tools/instructions and general implementation capability.

Run one newly admitted actual formal GLM review under current source/packet/normal subscription authority; demonstrate actual own truncated-output retrieval and successful final review while other-session/sibling access is denied. Preserve original old incident, update it honestly resolved only after actual original capability proof; #1791 remains open until that. No paid call or installation follows merely from this plan.

### Adversarial cases

| External input | Hostile case | Named test |
|---|---|---|
| profile selector | arbitrary path/URL/general override | formal_profile_enum_rejects_paths |
| launcher receipt | repo-forged/stale PID/config/agent/version drift | formal_origin_receipt_rejects_drift |
| repository instruction | nested conflict/symlink/omission/mutation | formal_instruction_scope_and_hash_preserved |
| permission | wrong session/message/call/tool/multiple/wildcard mismatch | own_output_permission_binding |
| stored output metadata | earlier run/foreign/sibling/forged MCP | own_output_provenance_rejects_foreign |
| actual file | symlink/hardlink/oversize/wrong UID/notregular/changed bytes | own_output_fd_capture_adversarial |
| destination | existing path/symlink/collision | own_output_destination_exclusive |
| original lifecycle | old/unversioned/expired/drift/spent/secondoutput | own_output_original_run_fences |
| continuation | transport unknown/current quota hold/notidle | own_output_continuation_never_resubmits |
| provider result | partial usage/old stop mistaken final | own_output_final_receipt_preserves_intermediate |
| general service | formal install mutates shared routes or implementation | formal_profile_preserves_general |
| pinned server | paging/fullownoutput/sibling read and instruction behavior | pinned_formal_own_output_fixture |

## 10. Required tests

Keep `tests/test-ai-glm.sh`, `tests/test-glm-formal-prompt.sh`, installer/OpenCode setup suites, packet/retained packet tests, reviewer lifecycle/credit/admission and pool GLM door tests green. Add named adversarial tests above in focused existing suites or one internal Python test suite registered through actual CI-suite procedure. Use deterministic fixtures; no provider test hidden in normal CI. Record exact commands/output artifacts rather than counts alone. Do not run unrelated fleet installation or quota probes.

## 11. Constraints and gotchas

Canonical checkout landing-only; candidate worktree only. Current effective task class reviewer-safety. Use gates before paid review/PR wait/ship/install; exact independent reviewer engine differs from implementer and retains failed verdicts. No direct OpenCode operational API, no installed binary edits, no shared wildcard, no uncontrolled repo plugin, no capability suppression. Git identity Albert Hazan <u2giants@users.noreply.github.com>; repository GitHub via candidate `bin/ai-gh`, sign every issue/PR comment with actual CODEX_THREAD_ID and edge-dev3. Normal PR/checks/merge path, no protected-main push. No model/provider calls or secret reads during source tests. All human-facing times EDT/EST. Never cap review turns/steps; account subscription and existing wall deadline stay authoritative.

## 12. Access/environment

No credential values in this plan or tests. Existing setup owns same protected Z.ai coding-plan 1Password injection route; follow actual `bin/setup-opencode-glm.sh` key reference and secrets-to-1password skill when an admitted installation needs it. No new vault item/account/paid-key fallback. Installed `/usr/local/bin/ai-review` resolves `/home/ahazan/repos/ai-devops/bin/ai-review`. Earlier read-only snapshot observed checkout24b038bc7f4a6efc304031b9ab0a2bfc7228965f and install-manifestf84085f93b6c20752d798a9b3db76b78bedb3d2f differ; root must reconcile current state before install, no plain pull/repair guess. Source tests run from candidate repo. Profile fixture uses owned temp config/data, synthetic credentials only and loopback deterministic transport, never installed shared service.

## 13. Done, risks and remaining decisions

Done only when independent source/security review and required checks pass, reviewed source is merged, protected install receipt verified, general review/implementation/tools/instructions preserved, isolated formal actual own-output retrieval succeeds, original incident updated with actual proof and #1791 live checklist completed. Preparation, local source expression, mocked fixture, merged code and installation are distinct facts.

Main risks: instruction-scope mismatch, stale launcher process/config attestation, wrong tool origin, race after denial, unknown submission, usage misattribution, unsafe copy, and profile install collision. Every risk has named fixture and fails closed. Rollback removes/disables only NEW formal profile through reviewed protected installer route after exact state/backup proof; general service remains unchanged. Private evidence and old sessions are retained; do not delete another owner's artifacts. Root approved phases B–D for source only; independent review and actual installation/live admission remain open, with no business question for Albert.

## Final self-audit

1. A new implementer can execute without chat: sections2–6 identify exact repositories, incident, source/runtime states; section9 gives dependencies/files/behaviors/gates and section12 access limits. Root architecture gate is explicit, not guessed authority.
2. All current nuance is retained: sections6–8 preserve failed hooks/feedback/exactgrant/globalflag/oldrun and locked owner no-caps policy; sections9–11 define original lifecycle and hostile cases. No original metadata or platform proof is invented.
3. Business goal guides conflicts: section1 requires full own output while preserving original capability and denying other sessions. Sections9/13 require stopping any instruction/tool loss and actual original-capability proof. All13 sections, STATUS, reciprocal baton, exact tests, scope, rollout and rollback are present. Self-audit passed for this OPEN source-preparation plan; source completion is not installation or accepted live repair.
