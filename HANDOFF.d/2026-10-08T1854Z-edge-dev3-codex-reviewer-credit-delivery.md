---
issue: 1345
status: BLOCKED
owner: codex/reviewer-credit-wrap-closeout
---

# Reviewer credit delivery — installed Qwen reset acceptance gap

Snapshot: October 8, 2026, 3:00 PM EDT. Source delivery, independent review and final installation completed. Actual installed acceptance found a NEW Qwen reset-propagation bug; it remains OPEN on issue1345. User explicitly invoked wrap-up: "A bug found during wrap-up is a handoff item, not a task" (wrap-up skill). No new fix is started here, no actual failure is hidden, and no extra provider canary is authorized. No database claim or database write was performed in this toolkit lane.

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner. Technical approval belongs to the assigned independent AI reviewer. Albert already authorized completing the original credit repair, coordinated through subagents, and explicitly authorized typing his password into a visible installation terminal. Do not ask him to approve technical delivery again. His October 7 configured-account instruction distinguishes subscriptions GLM/Qwen/Gemini/Kimi from pay-as-you-go Muse/Grok/StepFun/DeepSeek. His supplied GLM reset was Friday October 9 at 5:00 AM EDT; the later authenticated provider quota response differs. Preserve both observations; do not invent a business question or turn either date into permission to erase an opaque credit restriction.

## 1. What this application is

`popcre/ai-devops`, https://github.com/popcre/ai-devops, is Albert Hazan's public toolkit for restoring and operating multiple AI clients and reviewer wrappers. It is not a deployed application or shared database. Installation is its deployment mechanism. Canonical `/home/ahazan/repos/ai-devops` is landing-only; `/etc/ai-devops/install-manifest.tsv` records installed source. Linux host is edge-dev3. Independent source review and required Linux/Windows CI protect reviewer safety changes; protected main merges through GitHub's queue. Native Windows proof supplements required CI and never replaces it.

## 2. Goal and scope

Stop wasting lengthy reviewer waits when a provider has already refused credit, distinguish credit exhaustion from ordinary failure, exclude exhausted reviewers, restore only qualified subscription allowance after an authoritative reset, and document billing/reset limitations. Preserve original capabilities and stronger funds/authentication/membership restrictions. User required root coordinator plus subagent execution. Work is on toolkit issue #1345, with existing related #1346/#1349 and original shared-db parent #3536. Wrapping up freezes new scope only; original authorized delivery still finishes. No new issue, provider rollout, Kimi activation, new scheduler or speculative cooldown is authorized by closeout.

## 3. Current state and exact evidence

### Delivered source and earlier installation

- PR1404 merged October 7 at 7:13:52 PM EDT as `08ef1c733a600dbd46d70cd34361f86f4d8fc436`. All seven active wrappers share distinct exit92 for qualified terminal credit/allowance failures, provider-scoped admission holds and bounded prompt owned-process cleanup. Ordinary silent/unqualified errors retain existing failure/timeout semantics; do not claim every failure is immediate.
- Initial installation target `958c543415b312a8c37c5b6b3527716a2d243029` completed October 8 at 10:05 AM EDT with INSTALL_EXIT=0. Original exact installation review: `/home/ahazan/.codex/worktrees/reviewer-credit-install-review-958c/ai-devops/.ai/reviews/deepseek-final-check-20261008T135903-1401708-10438.md`. Original completion/stage records are under `/home/ahazan/.local/state/ai-devops/task-gates/`. This installation has since been superseded by another authorized session; do not reuse its authority.
- PR1517 merged as `e5f81548f1e8da1bde3714850cf9e168e6658e83`; changed files match independently reviewed source `cfcc8e39ba124522541be370de81933a34e0c3fd`. The Qwen doctor now consumes the final structured refusal before deleting its temporary diagnostic; final supervisor scanning catches a fast terminal refusal without an extra healthy-process query. Qwen140PASS, scanner28PASS, preflight214PASS; native Windows scanner28PASS/6POSIX skips. Independent original report `/home/ahazan/.codex/worktrees/qwen-doctor-reset-receipt/ai-devops/.ai/reviews/deepseek-final-check-20261008T142142-1130832-985.md`, APPROVE, digest `4b2b4738f321620bb91621676e19626ae46f4fada59a0a9dd47699c2fddd659b`. Required checks pass after unchanged-source retry of an unrelated PowerShell runtime crash.
- #1346 ordinary failure pause is closed with installed public pause proof preserving stronger holds, https://github.com/popcre/ai-devops/issues/1346#issuecomment-6062198412. Existing main contained `edcccb4dcfaddf85ba7dd7cc6f799d4c4e7027d9`; do not implement it again.

### In-flight repeated installation guard

PR1523: https://github.com/popcre/ai-devops/pull/1523, source `d8eafec5cfd1e053c6deb675b7967ed80e91aa83`, branch `codex/qualification-capacity-guard`, worktree `/home/ahazan/.codex/worktrees/qualification-capacity-guard/ai-devops`, base `230235788296b9a3f6f2fa6bd7f940195a165304`. Two files,15insertions/4deletions,219PASS. `bin/ai-review-preflight:776` refreshes only the deferred qualification intent to the exact current wrapper/runtime subject during a qualified future allowance hold. Changed bytes remain quarantined until the existing due-reset qualification succeeds; no second quota-only canary and no authorization of changed code. Exact DeepSeek APPROVE original `.ai/reviews/deepseek-final-check-20261008T172131-3769801-5868.md`, digest `505ebec98fd350a8ae61d2cb42feafd910ba84a1373d7fd020d4636132f51970`, report SHA256 `87fa3697b636bf57aaf4f39c0887b982a26c3129372374a22694293b44d06a7a`. All required checks passed and PR1523 merged as `6f764928e92b3c27c2718767e6c6a93d71124024`; final target is reachable from origin/main. No CI waiter remains. This is source proof, not installed proof.

### Host and final installation candidates

Historical pre-install root observation: main `8602fca15542524cc3541af5d20e891f6fe46156` at2:08PMEDT; then-installed canonical clean `e1723db85c9cc20dc3bed310d66b0463a0552052`, manifest SHA256 `87b2503f5942770d85748437b86e010fed23aee9293df7cfbbff5fee6451f66c`, gate hash `d5dd1e2d19146824e9dba0fb9a03e42cc3d4ccc6d1d9ac7177d3be46bf419024`. Separate owned candidates `/home/ahazan/.codex/worktrees/reviewer-credit-final-install/ai-devops` and `/home/ahazan/.codex/worktrees/reviewer-credit-final-review/ai-devops` were both clean e172; first installation class already declared at e172, second reviewer-safety. They were advanced only to the verified merged target. Both candidates are now clean at final merged target `6f764928e92b3c27c2718767e6c6a93d71124024`. Final exact installation DeepSeek review APPROVE: `/home/ahazan/.codex/worktrees/reviewer-credit-final-review/ai-devops/.ai/reviews/deepseek-final-check-20261008T182957-371794-4032.md`, base e172, digest `b1de30ae9fb772f7808a6a3b0ba755d83aaf892198d4c8c89727d8d909108b1b`, SHA256 `dde144ae4e1db89b76002d73074fe0c182cda21fae417118408cf764649ef519`. Root issued ordinary exact installation authority and final update consumed it successfully. Never reuse consumed authority.

Final visible installation `/tmp/reviewer-credit-final-visible.IrNIeGhI/install.sh` succeeded after Albert explicitly resumed password entry. `installation-result.txt` contains `INSTALL_EXIT=0`; canonical clean at6f and `/etc/ai-devops/install-manifest.tsv` records6f, SHA256 `237708c89965564e19f79553bb7f71e5419d63cd80415a251b36f1c8cdf0aa60`. Required stages PASS; secrets wiring explicitly SKIP via --skip-secrets. Protected durable stage report `/home/ahazan/.local/state/ai-devops/task-gates/install-stage-reports/6f764928e92b3c27c2718767e6c6a93d71124024.tsv`, SHA256 `d0b7f15ffe3232ce24d10ce0099763faa1b0207c4401851b782822be99dd8039`; completion `/home/ahazan/.local/state/ai-devops/task-gates/install-completions/last.json` binds target6f, manifest and stage hashes. Authority consumed; no updater remains active. Prior2:54:28PMEDT unavailable cachedauth was recovered by fresh user-authorized visible entry, so credentials are NOT the current blocker.

### Installed acceptance evidence and remaining account limitations

Private acceptance `/tmp/reviewer-credit-acceptance-_3bjeaga/`: native Windows cfcc proof, public stronger-hold-preserving pause proof, isolated installed allowance/funds fixtures, four bounded non-generating provider observations. GLM/Gemini/DeepSeek/StepFun readers are qualified; Grok/Muse/Qwen predictive availability remains UNKNOWN. StepFun read proves standard prepaid scope only. Existing watchdog leader cadence was verified without a new timer; host-specific lazy readiness still matters. Four reader successes do not prove actual future subscription refill.

Actual final-installed Qwen canary at October8,2:56:29PMEDT correctly exited92 with typed terminal allowance exhaustion and provider date `11-01 16:00:00 UTC`, meaning November1,2026,11:00AM EST. However its new allowance hold has reset_atNULL, so automatic timed recovery is not yet proven and the task cannot close. Durable diagnostic `/home/ahazan/repos/ai-devops/.ai/reviews/qwen-qualification/20261008T185629Z-597532-31898-qwen-live-failure.json`; durable hold `/home/ahazan/.local/state/ai-devops/review-quarantine/qwen.json`, record `0756cec8da1c0a4025ab6fdbd9f870f750a84ea1e0b699434805663f5a13e6e2`, observed_epoch1791485790; matching `qwen-requalify-marker.json` correctly binds that record and exact current subject. Wrapper hash `cf47299d73f07385cbb44c2a953e02b2d50b5c3be295ec44b21562189614826b`. New incident `/home/ahazan/repos/ai-devops/.ai/reviewer-issues/20261008T185630Z-edge-dev3-qwen-598226/details.redacted.txt` preserves typed date followed by "reset unavailable." All29prior incidents remain OPEN; no false partial closures. Installer verified the full native frame/supervisor receipt was inside the owned session temporary root and the existing watcher removed that root on wrapper exit; bounded matching-receipt searches found no retained copy. Root cause of reset loss remains UNKNOWN; loss of temporary evidence is not proof of the reset-loss cause. Offline canonical monthly date grammar parses the correct ISO date, which does not prove actual complete frame handling. Private acceptance snapshot `/tmp/reviewer-credit-closure-74z4ddyt/final-installed-reset-gap.json` is convenience evidence, not the only retained proof.

GLM opaque record `cfd78160bbcaaa217b396e89420f6b6b361ff1ca31a84703a798f19faa3b87d6`, observed October8,9:03:59AMEDT: out-of-credit,resetNULL,scopeNULL. Retained immutable error `/home/ahazan/.local/state/ai-devops/glm/sessions/d1c580d3fba9/setup--secrets-probe.1c21a0634bf041afba7df6422859cf58.error.json` lacks original native1310/1302 evidence. Authenticated non-generating quota observation at10:09:29AMEDT reports weekly allowance exhausted with reset October8,4:35:22PMEDT; five-hour allowance available. This unclassified legacy out-of-credit restriction conservatively protects possible funds exhaustion; funds exhaustion is NOT proven. A quota timestamp cannot clear it. Private sanitized provenance `/tmp/glm-reset-provenance-i22_9onq`; public https://github.com/popcre/ai-devops/issues/1345#issuecomment-6061802809. Original native GLM dispatch review proof stays on separate #1349; this toolkit credit acceptance never closes parent#3536 or seizes its claims.

## 4. Failed approaches and dead ends

- Generic credit guard/cooldown expiry cannot establish subscription-only exhaustion. Legacy guards remain conservative persistent holds; provider-qualified allowance resets clear only exact matching allowance records.
- Initial Qwen24day synthetic date was earlier than preserved later actual Nov1 reset; monotonic policy correctly prevented weakening. Correct test used25days; do not weaken monotonic hold selection.
- Merely scanning every250ms missed providers exiting sooner. Final scan now runs only after owned tree empties, bounded64KiB per channel; quoted tool/assistant errors do not qualify. No repeated full-stream scanning.
- CI1517 Windows section10 Muse failed40PASS/1FAIL because native PowerShell/.NET10 threw `System.ExecutionEngineException: Illegal instruction`. Muse source/helper byte-identical baseline. Unchanged-source one-job retry passed. Do not disable privacy storage, skip assertions or replace system binaries.
- Earlier Muse paid review hit1800-second timeout without credit evidence. Remote outcome UNKNOWN and paid replay fence preserved; never replay or relabel quota. Diagnostic public https://github.com/popcre/ai-devops/issues/1345#issuecomment-6059283885.
- Attempted tool-created password PTY was not the visible attached terminal. Cancelled without password capture. Supported visible Konsole window solved installation. No sudoers, pkexec or privilege bypass.
- Root original958 installation approval is invalid for current e172 host. Fresh exact combined review is required; approved source alone is not installed proof.

## 5. Root causes and durable findings

Runtime rejection and billing evidence have different meanings. Qualified native refusals give exit92 and durable scoped holds; genericHTTP402/403/429, rate limits, assistant quotations and plain failures cannot prove exhausted funds. `tools/reviewer_credit_stream.py` and `bin/ai-process-supervisor` bound scanning/owned-tree termination; POSIX and WindowsNativeJob guards differ but cancellation keeps precedence. `bin/ai-qwen` doctor consumes its own current receipt. `bin/ai-review-preflight:761–831` separates quarantined qualification intent from admission readiness. Existing `tools/reviewer_credit_watch.py` and ordinary readiness own due-reset retries.

Billing/reset facts are already durably documented in `docs/reviewer-rotation-rules.md`, section Billing and reset evidence. GLM epoch-ms nextResetTime handles latest exhausted5h/weekly; Gemini latest exhausted bucket reset_time; Qwen fresh typed International Token Plan MM-DDHH:mm:ssUTC date uniquely resolved within32days; no generic calendar reset inference. Kimi official usage supports optionalRFC3339resetAt but installed path unqualified and membership separately suspended. Ordinary DeepSeek uses the newer OpenCode harness; successful independent reviews here exercised it. Healthy scanner overhead measured Linux.82ms/100checks and Windows13.54ms/100checks over54,500B; no extra healthy provider call/new timer.

## 6. Exact continuation and verification gates

1. Read issue1345 and this handoff, freeze actual installed6f evidence without modifying holds. Recover the durable diagnostic/hold/marker/new incident above. Full native frame was in an owned temporary root removed on wrapper exit; avoid repeating unbounded searches. Inspect the existing receipt-retention/current-receipt flow offline, never raw transcripts. Verify actual recordUUID, date string and resetNULL are reproducible from retained evidence; preserve unavailable full-frame details as unknown.
2. Reproduce OFFLINE through the existing scanner, doctor current-receipt recording and admission path using sanitized typed terminal fixtures derived from retained metadata. No provider call, real-store mutation, quota-only retry or hold deletion. Inspect exact frame nesting/grammar and final fast-terminal receipt. Verify the test exposes date loss at a precise boundary; parsing a standalone canonical sentence alone is insufficient.
3. Start a fresh current-upstream isolated reviewer-safety worktree and existing issue1345 scope for the minimal source fix. Root keeps decisions; agent implements. Add a meaningful regression for the actual loss boundary and run focused required tests, including Windows path when affected. Verify failure before fix and exact reset-bound hold/receipt/marker after fix, with quoted assistant errors excluded and stronger holds preserved.
4. Obtain independent read-only exact-head reviewer APPROVE, ship protected PR and normal checks/merge queue, verify actual merged source on origin/main. No directmain/adminmerge or duplicate copies.
5. Re-derive current installed host pins and fresh reviewed installation authority for the new merged source; execute supported visible installation only if needed. Verify exact manifest, required stages, consumed authority and canonical clean. Existing6f consumed authority is not reusable.
6. Run actual installed acceptance only when supported admission permits it; never clear a known quota guard to force another paid refusal. Use already retained actual error data plus private offline proof to verify repair, and wait for authoritative recovery when a real canary is not permitted. Verify reset date survives fresh immutable receipt into matching allowance hold and deferred qualification marker, repeated install skips without extra provider request, and ordinary due-reset readiness retains stronger restrictions.
7. Append honest partial-resolution evidence to exact affected incident packages only once original reported problem is actually repaired and installed. Keep real quota exhaustion and future refill limits named. Verify all29prior packages plus new598226 incident are accounted, no deleted originals or invented historical diagnosis.
8. Root reconcile issue1345 source/install versus remaining live-proof checkbox; close only after observable reset-propagation/automatic qualification acceptance succeeds. Keep separate GLM opaque guard and #1349 native-review obligation; never close parent3536 from toolkit proof. Retire this handoff only after successor rule proves all carried obligations and no unique decision lost.

## 7. Constraints and traps

All public GitHub actions through bin/ai-gh with signature `Posted by Codex chat 01a11690-8b09-7821-8591-0c40c4221224 on edge-dev3`. Root owns merge/review/install decisions, agents execute. No directmain/adminmerge, quota-only retries, 1Password duringreview, rawtranscript access, secret output, foreignhandoff edits, fabricated reset proof or reviewer membership removal. Scoped hold update is not permission to clear stronger restrictions. Real provider reset remains account eligibility, not proof funds arrived. One bounded CI waiter; no parallelpolls. Do not duplicate source tests already proven at exact head. No database/productioninfra route applies. Human clock labels NYC EST/EDT; ISO machine timestamps may remainUTC. Never overwriteOS binaries. New closeout findings outside originalscope go to handoff, not newfixes.

## 8. Access and environment

Linux shell can use supported tools and private protected cached credentials. Secret references belong to 1Password vault vibe_coding, no values in this handoff; no credential/token/connectionstring appeared in this session's delivered text or owned source. User password was entered directly in visible terminal, not captured. No secrets-storage operation needed. Desktop Konsole is available for legitimate interactive password entry. Installed/candidate gates and original reports are local protected files. Native Windows tests used isolated own snapshots and collision checks; foreign installed runtimes, session claims and ongoing Windows installers remain untouched. No promise of background Codex execution: GitHub issue/PR and existing installed watcher are durable cards, not a new thread timer.

## 9. Open questions and dated risks

October8,3:00PMEDT: final6f installation succeeded, but actual live Qwen reset propagation failed. Fresh typed reset retained in diagnostic while admission hold resetNULL; precise lost-frame/receipt boundary UNKNOWN. No second canary, guard proof or incident partial closure attempted. Future November1Qwen refill cannot be observed today; any closing engineering assertion must state this limit. GLM native original refusal classification remains unknown and quota reset conflicts with owner-supplieddate; original unclassified legacy restriction remains binding without proof of funds exhaustion. Kimi reset field is optional and interface not qualified; suspended membership must remain. Current source main/manifest/queue snapshots are drift-prone and must be refreshed at transitions. Separate #1349 native GLM review may be capacity-blocked; root retains ownership of toolkit1345 and does not claim unrelatedparentdone. No new business question exists.

## Part B. Delegated work and retained state

- Provider A/B and shared-contract implementation agents (original run): implemented provider-qualified parsers/shared supervised contract, tests/docs leading1404; original agents finished. Worktrees credit-stream/capacity-reset/credit-contract-docs/gemini-reset-caller retain original evidence; do not assume cleanup safe by age. They did not clear opaquefunds or activateKimi.
- timeout_repair original agent: diagnosed GLM generic retained receipt and unknownMuse timeout; private sanitized provenance and public issue comments above. Finished; no code workaround, no provider replay.
- installation original/current executor: initial958 visible installedsuccess, Qwen1517 source repair, final install candidate preparation. Final candidate6f installed successfully after exact merged APPROVE, required stages PASS and consumed authority; owns retained installation receipts, no new repair started during wrap-up. No foreign authority consumed.
- verify_delivery/acceptance executor: nativeWindows28PASS proof, installed fixtures/publicpause, four non-generating readers, recurring leader observation,29incident enumeration. Current acceptance found actual resetNULL failure after final6f installation; no artificialrealholdclear or newprovider availability claim. Private directories listed§3.
- wrap_docs (this spawnedagent): read invokedwrap-up/docs-update/handoff standards; audited existing durablebillingdocs, prepared this audited handoff in its own current-upstream prose worktree. No foreign GitHub records altered, no foreignhandoffread/delete, no secretsvault operation. Root decides finalpublication only after actualdeliveryfacts.

## Self-audit

All tensections0–9 and per-agentblocks present. Coldstart continuation:§1–3define toolkit/ownership/source/host/cards/evidence;§6gives orderedactions andobservablegates. Equivalent-context detail:§4retains deadends,§5providerqualificationfindings,§7–9constraints/access/limits. Execution completeness:§3separatesreviewed/merged/installed/actualfutureaccountproof and§6covers everyremainingdeliverable. Ownerquestion sweep reread§1–9andPartB: no sentence requires a new businessjudgement; technical review/root authority and visiblepassword are operationalsteps, consolidated§0None. Final snapshot was refreshed after source merge, final review, successful installation and actual new acceptance failure. Root technical delivery decisions remain with root; no pending obligation is labelled complete.

## Recoverable private evidence and affected incident inventory

Temporary proof directories may disappear after this session. Recover original independent reports from the named retained review worktrees `.ai/reviews/`; immutable lifecycle files remain in their corresponding private lifecycle directory. Recover installation authority/completion/stage state through supported task-gate tools and `/home/ahazan/.local/state/ai-devops/task-gates/`. Private original reviewer incident packages live under the canonical toolkit `.ai/reviewer-issues/` or the configured `AI_REVIEWER_ISSUE_DIR`; `ai-reviewer-issue path`, `list`, and `show ID` locate them without reading raw transcripts. Preserve original packages, append evidence only, and do not commit them. Regenerate the inventory from these identifiers and the supported incident listing rather than depending on a temporary text file. Exact frozen affected Qwen IDs:

- `20261007T000104Z-edge-dev3-qwen-3113446`
- `20261007T024205Z-edge-dev3-qwen-1655030`
- `20261007T111013Z-edge-dev3-qwen-146812`
- `20261007T141006Z-edge-dev3-qwen-3590487`
- `20261007T141059Z-edge-dev3-qwen-3624413`
- `20261007T141116Z-edge-dev3-qwen-3629142`
- `20261007T154554Z-edge-dev3-qwen-860969`
- `20261007T210034Z-edge-dev3-qwen-2213368`
- `20261007T221627Z-edge-dev3-qwen-3858645`
- `20261007T231514Z-edge-dev3-qwen-2298350`
- `20261007T235217Z-edge-dev3-qwen-3920638`
- `20261007T235953Z-edge-dev3-qwen-402697`
- `20261008T014930Z-edge-dev3-qwen-3893499`
- `20261008T035938Z-edge-dev3-qwen-4063487`
- `20261008T070343Z-edge-dev3-qwen-970417`
- `20261008T072113Z-edge-dev3-qwen-1859510`
- `20261008T074109Z-edge-dev3-qwen-2222953`
- `20261008T085819Z-edge-dev3-qwen-1329895`
- `20261008T094144Z-edge-dev3-qwen-2661050`
- `20261008T110208Z-edge-dev3-qwen-3349568`
- `20261008T113330Z-edge-dev3-qwen-601203`
- `20261008T120954Z-edge-dev3-qwen-2067971`
- `20261008T121406Z-edge-dev3-qwen-2267456`
- `20261008T130148Z-edge-dev3-qwen-2636651`
- `20261008T132530Z-edge-dev3-qwen-3524059`
- `20261008T140525Z-edge-dev3-qwen-2684392`
- `20261008T151047Z-edge-dev3-qwen-3647010`
- `20261008T162256Z-edge-dev3-qwen-643077`
- `20261008T162548Z-edge-dev3-qwen-676528`

The actual Qwen incident explicitly identified by root is `20261008T140525Z-edge-dev3-qwen-2684392`; include it when reconciling the frozen inventory. Also include new installed incident `20261008T185630Z-edge-dev3-qwen-598226`; do not hide the fresh acceptance failure in the historical29. If supported listing reports a missing package, retain that uncertainty rather than invent a resolution. Re-run only installed acceptance that never completed, keeping original capacity exhaustion and stronger restrictions intact.

Posted by Codex chat 01a11690-8b09-7821-8591-0c40c4221224 on edge-dev3
