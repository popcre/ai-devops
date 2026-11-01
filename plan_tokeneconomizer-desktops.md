# TokenEconomizer — desktop applicability, qualification and measured rollout

Owner: the implementing Codex session on the owning GitHub issue. Date: October 31, 2026 (EDT).
Owning issue: [#2220](https://github.com/popcre/ai-devops/issues/2220).
Sibling: [fresh-reader #2222](https://github.com/popcre/ai-devops/issues/2222),
with its [separate implementation plan](plan_selective-fresh-reader.md).
Coordination parent: [#2227](https://github.com/popcre/ai-devops/issues/2227)
(isolation contract and combined proof only).
Paired [handoff](HANDOFF.d/2026-11-01T0020Z-edge-dev3-codex-tokeneconomizer-desktops.md).

## STATUS — read before doing work

October 31 execution: [current applicability](tests/verification/tokeneconomizer-desktops/applicability.md)
and [native preflight](tests/verification/tokeneconomizer-desktops/report.md) are
published with a separate [bounded cost schedule](tests/verification/tokeneconomizer-desktops/measurement.md).
Execution owner is Codex chat `01a194ee-7e16-70b3-9ebd-307fdd653f15` on #2220.
Discovery is partial; a Claude native SessionStart hook ran, but revoked OAuth
stopped its model call. No pair, native desktop acceptance or saving is claimed.
The reader pilot found and the coordinator accepted the merge-order and
per-installation measurement clarifications below; it did not review a runtime.

October 31 closeout: Muse's corrected static source/plan review approved narrow
qualification pilots only. Read the
[decision record](docs/muse-egm-tokeneconomizer-review-2026-10-31.md) and
[small-trials handoff](HANDOFF.d/2026-11-01T0208Z-edge-dev3-codex-small-trials-handoff.md)
before step 1. Reconcile current #2220 execution ownership first. Handoff §6
specifies the tiny isolated loopguard/environment-facts smoke after applicability
and privacy checks, before the larger managed-installation matrix. No trial or
installation was performed by this review/closeout session; rows remain open.

| Step | State | Evidence / next gate |
|---|---|---|
| 1 Inventory and classify all four desktops | 🟨 partial | Current package/process inventory published; embedded desktop engines/native control remain unverified |
| 2 Qualify privacy, hooks and recovery | 🟨 partial/blocked | Pinned offline tests and isolated native start receipt; working model access, full adversarial/recovery and capability proof remain open |
| 3 Build managed installation and diagnostics | ⬜ open | Cross-platform fixture tests |
| 4 Prove applicable Ubuntu desktops | ⬜ open | Actual desktop session receipts |
| 5 Resolve Windows applicability | ⬜ open | Actual MiMo/ZCode supported-or-inapplicable evidence |
| 6 Measure benefit and decide rollout | ⬜ open | Paired cost and quality report |
| 7 Land, install, restore and close | ⬜ open | Exact landing plus per-target live proof |

Execution resumes at the remaining native access/privacy gates in steps 1–2,
not by replaying the published planning work. The earlier closeout paragraphs
describe their own historical session. No managed installation, smoke pair or
desktop acceptance has been delivered. Re-read downstream steps at each boundary.

## 1. Ultimate goal

Reduce Albert's tokens and cost while preserving the ability to finish work correctly in Claude Desktop and Codex Desktop on Ubuntu, and MiMo Desktop and ZCode Desktop on Windows. Install TokenEconomizer only where the actual desktop runtime supports it, and prove whether it helps our real work. Account explicitly for every requested app, including a supported explanation when it is inapplicable.

**If a step conflicts with this goal, the goal wins — stop and flag it.** A successful command-line demonstration is not desktop delivery. A lower token count with worse completion, missed checks or lost capabilities fails the goal.

## 2. Application and operating setting

This is the public [popcre/ai-devops](https://github.com/popcre/ai-devops) recovery toolkit, not a deployed web application. It installs scripts, skills, instructions and provider integrations on Ubuntu and Windows. GitHub is source truth; installation is deployment. Read [AGENTS.md](AGENTS.md), [deployment](docs/deployment.md), [configuration](docs/configuration.md) and the matching [task router](docs/task-router.md) rows before modifying behavior.

Requested surfaces: Ubuntu Claude Desktop's coding sessions, Ubuntu Codex Desktop's coding sessions, Windows MiMo Desktop and Windows ZCode Desktop. Normal Claude conversational chat is not automatically a Claude Code session. Inventory the actual running product, runtime, execution host and profile rather than inferring them from a desktop icon.

Primary Ubuntu candidate is edge-dev3, the planning host. Windows development candidates recorded by the repository are edge-dev, al8960ofc/4837 and 916. These are discovery candidates, not a claim that every app is installed on every host. Inventory all four requested app types on development hosts from the protected machine atlas; deploy to each verified installation of the requested combinations. Networking-only machines are excluded.

## 3. Trigger and authorization

Albert asked: “make a plan to implement it for all the harnesses we use that it is applicable to: claude desktop for ubuntu, codex desktop for ubuntu, mimo desktop for windows, zcode desktop for windows.” This authorizes this plan and its publication, not immediate desktop installation. A subsequent execution session uses the plan as its complete brief.

The preceding assessment found recurring token-waste subjects in the private topic-cut store: repeated verification, unchanged queue updates and oversized tool output. Those are qualitative signals, not measured TokenEconomizer savings. No private segment text is included here. Existing [compression evidence](docs/compression-and-process-fixes.md#measured-evidence) distinguishes large raw reductions from approximately 2% net savings measured by an earlier coding proxy after cache effects.

## 4. Scope

In scope: applicability discovery, upstream source qualification, supported native integrations, managed installation/recovery, actual desktop tests, cache-aware measurement, documented unsupported outcomes and rollout only after acceptance.

NOT in this plan: building a new optimizer; adding MiMo/ZCode adapters from scratch; assuming OpenCode ancestry implies compatible plugins; patching vendor files; changing models, providers, subscriptions or billing; automatic tool removal; replacing existing skills/memory or transcript processing; uploading private transcripts; production/shared-db changes; Entire activation; new reviewers; normal non-coding chat optimization.

## 5. Current source and delivery state

Repository baseline inspected: [7e591363634be65a6b99d7e60443afc6f1091716](https://github.com/popcre/ai-devops/commit/7e591363634be65a6b99d7e60443afc6f1091716). Planning worktree was clean and matched fetched origin/main before edits. This plan and its handoff are the only new workstream artifacts; no TokenEconomizer code, runtime setting, model call or install has been introduced.

Concrete existing evidence:

- [docs/task-router.md:99–100](https://github.com/popcre/ai-devops/blob/7e591363634be65a6b99d7e60443afc6f1091716/docs/task-router.md#L99-L100) routes Windows client integration and records MiMo's missing hook surface.
- [MiMo baseline:12–19](https://github.com/popcre/ai-devops/blob/7e591363634be65a6b99d7e60443afc6f1091716/tests/verification/mimo-windows-2026-09-23/README.md#L12-L19) records Desktop presence and historical standalone CLI absence; line 38 records no hooks. These September facts require current requalification.
- [ZCode baseline:10–28](https://github.com/popcre/ai-devops/blob/7e591363634be65a6b99d7e60443afc6f1091716/tests/verification/zcode-windows-2026-09-17/README.md#L10-L28) distinguishes desktop and embedded core versions. Its [support plan](plan_zcode-windows-support.md) step 7 records configured hooks without proven headless firing.
- [compression record:9–25](https://github.com/popcre/ai-devops/blob/7e591363634be65a6b99d7e60443afc6f1091716/docs/compression-and-process-fixes.md#L9-L25) names dominant waste and cache-aware evidence.

Reconcile all facts against current upstream and installed versions before implementation. Do not convert these historical facts into current support claims.

## 6. Findings and evidence

Upstream candidate discovered by git HEAD lookup: [c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23](https://github.com/microsoft/TokenEconomizer/commit/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23). Pin and verify this exact tree; if the fetched documentation differs, report the discrepancy before choosing a newer candidate.

Read its [README](https://github.com/microsoft/TokenEconomizer/blob/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23/README.md), [plugin instructions](https://github.com/microsoft/TokenEconomizer/blob/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23/plugin/README.md) and [runtime design](https://github.com/microsoft/TokenEconomizer/blob/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23/docs/PLUGIN.md). The inspected moving documentation lists Claude Code, Codex, Copilot CLI, Pi and experimental OpenCode; it names neither MiMo nor ZCode. Codex demonstrations are CLI demonstrations. This is a qualification gap, not evidence of desktop failure.

The design's lines 44–60 distinguish benchmark termination from the shipped plugin's advisory redirection. Lines 501–520 describe local private state, outgoing model digests and learned text as untrusted input. Lines 524–545 document unproven real-loop efficacy, imperfect verification recognition and Windows gaps. Inspect exact pinned line numbers when saving qualification receipts.

[Claude's desktop documentation](https://code.claude.com/docs/en/desktop) says coding sessions share hooks/settings with Claude Code. [OpenAI hook documentation](https://learn.chatgpt.com/docs/hooks) describes plugin hooks and exact-definition trust. Neither proves this third-party plugin works in our installed Ubuntu apps. Official sources were fetched during planning; archive public source URLs and relevant version facts in the report, never full private settings.

Upstream optimization can make its own model calls. A local state directory does not mean zero outgoing session-derived material. Current transcript-store policy requires ScaleDown for transcript text processing; learned facts and judge digests must be examined against that boundary before real session use. Synthetic qualification is permitted; production transcript use is not assumed.

## 7. Rejected approaches and failed attempts

No installation was attempted, so there is no failed install to repeat. Reject these shortcuts:

- Install default settings globally: defaults can prune tools, and hook inheritance could affect unrelated/private sessions.
- Treat CLI hooks or a status response as desktop proof: the GUI may use a different runtime, profile or event stream.
- Copy the experimental OpenCode adapter into MiMo or ZCode: no compatible loader/event schema is established.
- Upload existing transcripts for learning or infer savings from raw token volume: violates custody boundaries or ignores cache discounts and extra calls.
- Call loop warnings a guaranteed runaway stopper: upstream does not stop the turn itself.
- Replace a failed native integration with a custom proxy, wrapper, app downgrade or lost capability: outside scope and contrary to preservation.

## 8. Decisions

### Coordination with fresh-reader checks — October 31, 2026

Keep two implementation plans and two independent child acceptances. #2220 owns
optimizer installation, native session exclusions, desktop applicability and
cost measurement. #2222 owns document-comprehension checks and the canonical
[clean-reader contract](plan_selective-fresh-reader.md#coordination-with-tokeneconomizer--october-31-2026).
The parent owns combined compatibility and shared-file scheduling only; it must
not duplicate either implementation backlog or claim their standalone results
prove the combination. Neither child waits for the other to start or finish its
standalone pilot. Standalone adoption remains possible if the sibling is rejected.

Before any optimizer integration can affect a fresh-reader session, qualify an
officially supported isolated profile/state boundary or native exclusion. No
learned facts, micro-skills, optimizer summaries, environment facts or other
remembered context may reach that reader outside its explicit packet. Exclude
reader events/output from optimizer learning, capture and judge/proposer calls
as well. Inspect inherited hooks/settings and native child context, rather than
assuming a new chat or no-history agent is clean. Ordinary author optimization
and existing app capabilities must keep working. No global disabling, hook
removal, fabricated trust or unsupported vendor flag is permitted. If exclusion
cannot be proved, record that combined configuration unsupported/blocked and
retain supported standalone modes; do not silently contaminate the reader.

Keep this plan's ten-pair cost pilot free of fresh-reader calls in both arms;
record source, model/settings, profile aliases and state isolation. The sibling
runs its own pilot with TokenEconomizer absent from its trial profile, including
the author/remediation work. Do not pool baselines, transfer learned state,
double-count savings or claim combined improvement from separate measurements.

After both relevant standalone receipts exist, provide them to the parent
coordinator for a combined smoke on each common supported app/OS combination:
optimizer active for normal author work, reader input and events excluded,
ordinary edit/test journey and comprehension result still correct. Use the
sibling's `tests/verification/fresh-reader/combined-compatibility.md` as the one
combined receipt, not a second report. This is compatibility proof, not a joint
cost benchmark. A rejected/inapplicable sibling yields evidenced N/A; access
gaps remain blocked. Parent live proof gates shared-mode rollout only.

Post intended shared-file edits and ownership on the parent before writing
skills, standards, routers, context or installation guidance. Serialize each
shared file and reuse the sibling's rule instead of duplicating it. #2222 owns
reader-rule text; #2220 owns optimizer installation/configuration text. Re-read
both current STATUS sections and downstream phases after shared changes land.

In step 2 add `memory-injection-exclusion` and `reader-event-exclusion` tests:
seed synthetic ordinary optimizer state/memory, inspect native clean-child
settings/reads and input receipts, prove no child-driven state write or model
call, and prove ordinary author optimization remains functional. Missing marker
echo alone is not a pass. Run fixtures on both OSes for every claimed native
route; unsupported routes remain explicit, never simulated with another engine.
These tests implement the sibling-owned boundary rather than new review gates.

Locked October 31, 2026 (EDT): qualify all four desktop types; automatic tool pruning remains off; use only supported extension surfaces; preserve original capabilities; keep private evidence private; measure total overhead; no forced termination, turn cap or human setup task; no fleet installation based only on a benchmark.

Initial synthetic profile: toolprune=off, microskills=off, loopguard=off until the privacy/model-call audit passes. Then qualify envfacts and loopguard individually. Full model-based micro-skills stays off unless its transcript-derived processing is compatible with the standing policy; do not silently reinterpret that policy. Learned facts are subordinate to owner rules and current repository source.

Implementer judgment: select a supported current upstream release if the pinned candidate is unsuitable, with a recorded reason; choose the smallest additive managed helper; classify each desktop after probes. A vendor limitation is a supported-inapplicable outcome with evidence, not permission to invent an adapter. Missing access is blocked, never inapplicable.

## 9. Executable phases

### Phase A — discovery and qualification

**1. Inventory.** Create `tests/verification/tokeneconomizer-desktops/report.md` and `applicability.md`. Use current protected machine atlas via `ai-private-config path machine_atlas` (do not copy addresses or secrets publicly). Record a public-safe row per app/host: app and embedded engine version, OS, profile identity alias, local/remote execution, supported extension loader, event capabilities, usage evidence and access state. Re-read the existing MiMo/ZCode baselines and inspect current vendor documentation from within the respective app where necessary. For Claude distinguish Code tab from conversational chat. Gate: every requested desktop has a supported, unsupported, or blocked disposition with dated source/probe evidence; missing access remains an open issue item. No install in this step.

**2. Pin, isolate and audit.** In a task-owned temporary clone fetch the candidate; record digest, version, license, entrypoints and dependencies in the report. Inspect hooks, parsers, model invocation paths, config resolution, recursive judge-session exclusion, state ownership and network destinations. Use an empty task-owned home/profile and public synthetic repository. Never expose existing session archives to qualification. Add `tests/test-ai-tokeneconomizer.sh` and `tests/test-ai-tokeneconomizer.ps1` fixtures named in §10. Prove supported configuration is set before any real session can run; if no repository allowlist can prevent global private-session ingestion, keep installation isolated and classify ordinary global adoption blocked. Gate: all adversarial rows pass, outbound payloads contain only synthetic material, and recovery returns original synthetic configuration byte-for-byte.

### Phase B — managed integration and native proofs

**3. Integrate supported installation.** Add the minimum helper `bin/ai-tokeneconomizer` with `doctor`, `preview`, `install` and `restore` modes, and a Windows shim/catalog entry only if Windows applicability is proven. Reuse `install.sh`, `update.sh`, `bin/install-ai-devops-windows.ps1` and `config/machine-tools.tsv`; never install the plugin unconditionally during a generic toolkit update. Store a public-safe upstream pin/eligibility manifest in `config/tokeneconomizer.json` and documented behavior in `docs/tokeneconomizer.md`. Report diagnostics separately for installed, trusted, desktop-proven, measurement-accepted and unsupported; no silent successful skip. Use native marketplace/plugin installation and normal exact-hook trust. Preserve every foreign setting, hook, permission, MCP and skill. Gate: preview makes no changes; install twice is idempotent; restore removes only owned additions; tests pass on Ubuntu and Windows for shared code.

Land that opt-in, disabled-by-default integration through the normal PR route
after its offline gates pass and before step 4 needs a merged candidate. This
source landing is not desktop acceptance or rollout. Step 7 subsequently lands
the actual acceptance/diagnostic documentation and installs only accepted targets.

**4. Ubuntu desktop proofs.** On each discovered Ubuntu installation, first snapshot original configuration and protect recovery privately. Declare installation/deployment class and pass the corresponding task gate before writes. Install the merged supported candidate through the documented machine route, with allowlisted public synthetic sessions first. Start a genuinely new session in each actual desktop. Capture synthetic evidence of SessionStart, a successful tool event, a failed event, injected context consumption, turn completion and session folding. Establish the required number of clean turns before provoking a bounded synthetic repeated failure; demonstrate a visible redirect, then a productive recovery without changing task requirements. Gate: screenshot plus sanitized event/ledger receipt from the desktop, not merely CLI status; original MCP/skills and one ordinary edit/test journey still work. If native desktop control is unavailable, route to a session with that access; do not ask Albert to operate it.

**5. Windows disposition and conditional proof.** Recheck current MiMo and ZCode loader/hooks using `bin/ai-mimo`, `bin/ai-zcode`, their doctors and the actual desktops. No provider inference or engine substitution. If an official native loader plus compatible lifecycle/config/payload contract now exists, apply steps 2–4 separately and add Windows path, CRLF, spaces and PowerShell 5.1 coverage before managed rollout. If not, publish exact vendor/version evidence and mark that combination inapplicable. Keep both apps fully functioning with existing integration; no replacement token optimizer is added. Gate: each Windows app has either real desktop receipts or a defensible unsupported disposition. Historically inert hooks and absent hooks must not be confused with current failures.

### Phase C — benefit, delivery and acceptance

**6. Paired measurement.** Add public synthetic task fixtures and scoring instructions under `tests/verification/tokeneconomizer-desktops/tasks/`, with a measurement CSV schema documented in `measurement.md`. Freeze ten task pairs per applicable desktop: repository discovery, repeated known command error, bounded synthetic failure loop, ordinary edit/test, and unchanged-status handling (two pairs each). Alternate baseline/treatment order; use the same repository commit, model, effort, starting facts, cache warm/cold condition and success criteria within a pair. Use fresh chats and controlled state snapshots to prevent treatment leaking into baseline. Collect input/output/cache tokens, extra judge/proposer calls, elapsed time, completed checks, correct outputs and interruptions. Score all ten pairs. Acceptance: no additional failed task, missing required check or capability loss; at least 10% lower aggregate priced token cost including optimizer overhead on each desktop adopted. Report raw tokens separately. If subscription billing has no per-run monetary figure, use explicit published cache-aware equivalent prices and label them estimated, never dollars saved. Unknown token counters invalidate the savings claim; do not invent them. At most one repeat batch for a documented measurement error; no open-ended tuning. Gate: reproducible per-pair artifacts and acceptance calculation. A failed benefit gate means no broad adoption, preserve recovery and record a measured rejection.

Here “desktop” means each intended app/host installation, not one machine's
result extrapolated to every host with the same app/OS. Shared offline tests may
be reused; native model/settings/cache and priced benefit require local evidence.

**7. Land and roll out accepted targets.** Update this STATUS, `docs/tokeneconomizer.md`, `docs/task-router.md`, `docs/compression-and-process-fixes.md`, `docs/deployment.md` and relevant client support plans with exact supported/inapplicable/blocked states. Follow existing GitHub issue, PR and merge policy; advisory review never blocks. Run required safety checks, verify identity, commit only owned files, push and use the queue for code/config changes. Confirm exact landing on origin/main; do not repeat an already-passing landing test. Install from that merged candidate using protected update routes on each accepted target. Repeat one actual desktop smoke/recovery journey per installed app/host. Gate: issue checklist reconciles all four requested combinations; applicable targets have installed proof, unsupported targets have evidence, blocked targets retain named execution ownership and `- [ ] live proof` on this same issue. Retire the paired handoff only when all obligations are met or explicitly carried forward.

### External-input adversarial cases

| External input | Hostile case | Required test |
|---|---|---|
| Marketplace/upstream path | Spaces, metacharacters or changed SHA | `pin-and-argv-integrity` |
| Agent config | Malformed JSON/TOML or foreign keys/hooks | `config-refusal-and-foreign-preservation` |
| Filesystem ownership | Escaping symlink/junction or another profile | `profile-boundary` |
| Runtime transcript | Unknown schema, truncated/rotated log, duplicate event | `parser-no-false-success` |
| Learned text | Output says to ignore owner rules or skip tests | `untrusted-fact-subordination` |
| Fresh-reader child context | Learned facts, hook injection or remembered summaries reach isolated child | `memory-injection-exclusion` |
| Fresh-reader child events | Optimizer learns/captures output or launches judge/proposer | `reader-event-exclusion` |
| Digest/network payload | Synthetic secret/path canary and private repo marker | `no-private-egress` |
| Plugin defaults | Starts before safe settings or processes disallowed repo | `safe-before-first-hook` |
| Background judge | Judge recursively invokes its own judge | `judge-recursion-exclusion` |
| Parallel sessions | Cross-profile state or partial writes | `concurrent-state-isolation` |
| Uninstall | Foreign permissions/hooks changed since snapshot | `owned-restore-only` |
| Usage metadata | Missing cache count, duplicates or unpriced extra calls | `ledger-unknown-is-unknown` |
| App update | Loader/event schema changes | `version-drift-refusal` |

## 10. Tests required

Implement the named §9 tests in the two proposed fixture suites, using fakes and disposable profiles; no real credentials or real model calls in CI. Include native PowerShell 5.1 execution on Windows and Bash under Git Bash where relevant. Any OS-specific adapter gets its OS fixture, while shared behavior must pass on both.

Run focused suites first; retain existing `tests/test-install-ai-devops-windows.ps1`, `tests/test-ai-mimo.sh`, `tests/test-ai-zcode.sh`, `tests/test-configure-mimocode-mcps.ps1`, `tests/test-configure-zcode-mcps.ps1`, `tests/test-ai-adopt-globals.sh`, `tests/test-client-globals-required-phrases.sh` when their owned surfaces change. Run `tests/test-markdown-links.sh` and `bin/ai-doc-safety` for documentation. Before local full tests use the collision checker. Upstream's offline tests are supporting evidence only; they do not replace desktop proof or our preservation tests.

## 11. Constraints and traps

Every write uses a current-upstream task worktree. Use `ai-task-gates` at the appropriate class and before stronger actions. All GitHub calls use `bin/ai-gh`; wait through bounded event-aware tools. No human approval loop or manual instruction to Albert. Platform trust limitations must be respected; never synthesize a trusted hash, bypass hook trust or alter managed policy to manufacture success.

Private raw evidence remains in an approved private location; public evidence contains versions, digests, synthetic fixtures and conclusions only. TokenEconomizer is not permission to process historical private transcripts with an LLM. Keep existing memory unchanged; the request did not authorize updating personal memory. Do not add global capture, vendor binary changes, forced shutdowns, paid services or alternate reviewers. No GLM review of ZCode work.

The separate Entire trial remains under #2022 and its original deadline. Check current New York time and its session workflow before any public trial activity; disclose missing/stale Trail evidence and continue GitHub delivery. Never send this conversation or private inventory to Entire.

## 12. Access and environment

Planning ran on edge-dev3 Ubuntu in a Codex-managed worktree. Git fetch/remote lookup worked; committer identity was verified as Albert Hazan with the prescribed noreply address. GitHub API calls are subject to the shared throttle, so authentication and write availability must be rechecked at delivery. No remote desktop control, MiMo/ZCode access, current app version or provider login was qualified by this plan.

Use protected machine configuration for host routes. Existing provider authentication is reused through supported clients; TokenEconomizer requires no independent key according to upstream. If a secret must be handled, read the secrets-to-1password skill and use vault `vibe_coding`; no item title is invented and no credential is printed. Resolve required existing item metadata during execution. No local web server is needed. Python 3.10+ is an upstream prerequisite; verify the interpreter visible inside the desktop hook environment, not only the shell.

## 13. Definition of done, risks and decision rules

- All four requested desktop types have current, evidenced applicability outcomes; access gaps remain open, never silently excluded.
- Applicable targets preserve existing functions, pass fixture and real desktop tests, meet measured benefit, and are installed from a verified merged source.
- Upstream pin, configuration ownership, recovery, tests and update/drift checks are documented and reproducible from zero.
- Code is committed/pushed/merged through the correct lane; origin/main and installed candidate agree; owning issue contains live-proof acceptance. Plan-only delivery does not check off implementation.

Risks: desktop/CLI profile differences, internal transcript schema changes, privacy leakage in digests, stale learned facts, recurring judge cost, inaccurate subscription savings and configuration collisions. Rollback is surgical removal of owned plugin entries/hooks/settings using recorded ownership, restoring only owned changes while preserving later foreign edits. Keep evidence and pre-change recovery until restore is verified; do not delete user history. A candidate that cannot isolate private sessions or preserve capabilities is not adopted.

Uncertainties are technical and assigned to the implementing session: present desktop versions and event support (step 1), privacy compatibility (step 2), Windows native support (step 5), and net benefit (step 6). No business choice is pending. Unsupported targets close only with evidence; blocked access stays on the same issue with an exact owner and next safe action.

The parent retains combined `- [ ] live proof` independently of this child's
standalone acceptance. Do not release a shared configuration until native reader
isolation/event exclusion and ordinary author capability both pass. On failure,
restore only owned trial settings and keep both standalone capabilities intact.

## Final self-audit

All thirteen sections and the trust-boundary table are present. Concrete targets, gates, rejected shortcuts, access limits, locked decisions, rollback, delivery and cross-links are specified.

1. **Can a fresh session execute without this chat? Yes.** §§1–6 define the goal, products, baseline and source evidence; §§9–12 define ordered work, fixtures, access and decision rules. Unknown platform facts are explicit qualification tasks, not assumed support.
2. **Does it carry the known background and rejected paths? Yes.** §§3, 5–8 preserve the transcript-derived motivation without private text, historic limitations, desktop-versus-CLI distinction, outgoing digests and rejected integrations. No failed install is invented.
3. **Can the implementer steer if a step is wrong? Yes.** §§1, 8 and 13 prioritize cost with preserved task completion; define applicability, blocked access, measured rejection and recovery. Audit gaps found while drafting were privacy-before-first-hook, unknown usage counters and every installed host; each is explicitly covered above.

Coordination amendment self-audit passed: §8 cross-links the canonical boundary,
separates measurements and ownership, specifies combined evidence and failure
dispositions; §9 names the adversarial tests; §13 keeps standalone acceptance
separate from the parent's shared-mode live proof. All thirteen sections remain.
