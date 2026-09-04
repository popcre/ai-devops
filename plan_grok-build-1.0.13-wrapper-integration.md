# IMPLEMENTATION PLAN — Grok Build 1.0.13 wrapper integration

Planning handoff: [`HANDOFF.d/2026-09-04T0025Z-edge-dev-codex-grok-build-1-0-13.md`](HANDOFF.d/2026-09-04T0025Z-edge-dev-codex-grok-build-1-0-13.md)  
Tracking issue: [#251](https://github.com/popcre/ai-devops/issues/251)  
Official release source: [Grok Build changelog](https://x.ai/build/changelog)

> Planning record only. No Grok update, wrapper behavior change, provider call,
> installer execution, or machine configuration change was made while writing it.

## STATUS — read this first

| Step | State | Date | Evidence |
|---|---|---|---|
| 0. Reconfirm clean ownership and exact baseline | ⬜ open | — | A dated baseline under `tests/verification/grok-build-1.0.13/` |
| 1. Pin and safely install Grok Build 1.0.13 | ⬜ open | — | Installer tests plus before/after version and recoverable backup evidence |
| 2. Qualify the 1.0.13 CLI and JSON contracts | ⬜ open | — | Redacted help/inspect/schema and two-turn live qualification artifacts |
| 3. Integrate useful review-wrapper behavior | ⬜ open | — | Focused `tests/test-ai-grok-review.sh` cases and live read-only review |
| 4. Integrate useful implementation/integration behavior | ⬜ open | — | Focused implementation and integration-review tests/probes |
| 5. Update guidance, routing, and installed copies | ⬜ open | — | Source/installed hashes and documentation checks |
| 6. Independent exact-head review and full verification | ⬜ open | — | Review verdict, full suites, CI run, installed smoke, and `origin/main` SHA |

**Fresh-session start:** Step 0. Do not edit a wrapper until the concurrent dirty
checkout is reconciled and the version-bound baseline is recorded. After Step 2,
update this table, use the `fresh-session` skill if context is crowded, and re-read
Steps 3–6 before continuing.

## 1. Ultimate goal

Albert should receive the reliability and automation improvements delivered by
Grok Build 1.0.6 through 1.0.13 while keeping the current Grok workflows safe,
bounded, economical, recoverable, and truthful. Upgrading the executable alone is
not enough: the repository-owned installers, wrappers, parsers, tests, operating
guidance, and live evidence must all agree on 1.0.13.

The approval reviewer must remain read-only and exact-head. The isolated
implementation wrapper must continue preserving unique work without applying it.
The planned integration-review tier remains separately governed by issue #249;
this upgrade may qualify its provider assumptions but must not implement or weaken
that unfinished containment design.

**If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for a
multi-model development workflow. It contains Bash and PowerShell wrappers,
installers, shared skills, documentation, and offline verification. It is not a
hosted application and has no application deployment or database.

- Repository: `C:\repos\ai-devops`; source of truth is GitHub `main`.
- Current remote as verified during planning: `https://github.com/popcre/ai-devops.git`.
- Branch rule: work directly on `main`; do not create a feature branch.
- Runtime installation: repository wrappers are installed/symlinked through the
  toolkit; Grok itself lives in the user's machine-local `~/.grok` tree.
- Primary paths: `bin/ai-grok-review` (read-only review),
  `bin/ai-grok-implement` (isolated editing), provider installers under `bin/`,
  shared instructions at `skills/shared/grok-cli/SKILL.md`, and tests under
  `tests/`.
- GitHub issue #251 owns this upgrade. Issue #249 owns the distinct, unfinished
  controlled-shell integration-review tier.

## 3. What triggered this work

EDGE-DEV still runs `grok 1.0.5 (5115b46bc9) [stable]`. xAI published 1.0.6
through 1.0.13 from 2026-08-18 through 2026-08-28. Those releases add or repair
headless session discovery, permission prompting, transient retries, truncation
recovery, session durability, usage/context accounting, MCP startup, Windows
worktree handling, and background/subagent completion. Several intersect with
assumptions enforced or documented by our wrappers.

The request is to upgrade to exactly 1.0.13 and integrate **all useful additions
since 1.0.5**, not merely run the vendor updater. “Useful” therefore means a
release item that improves or changes a supported repository workflow, its safety
contract, its evidence, or its operating guidance. Every changelog item must be
classified; only items with no wrapper/workflow consequence may be excluded.

## 4. Scope

### In scope

- Pinning, installing, verifying, and rolling back Grok Build 1.0.13 on supported
  Windows and Linux hosts without exposing `~/.grok/auth.json`.
- Revalidating every CLI flag, `inspect --json` field, terminal result field,
  stop reason, usage/cost field, session-resume behavior, and process-lifecycle
  assumption used by our Grok wrappers.
- Integrating useful 1.0.6–1.0.13 capabilities into `ai-grok-review`,
  `ai-grok-implement`, and the still-planned integration-review profile only where
  evidence shows a real benefit and the existing boundary remains intact.
- Updating installer pins/version gates, tests, docs, skills, router links, and
  version-qualified evidence.
- Removing obsolete workaround wording only after a 1.0.13 regression probe proves
  the underlying defect gone; retain defensive completion validation even then.

### NOT in this plan

- Building issue #249's sandbox, egress broker, MCP bridge, or new integration
  wrapper. This plan only refreshes #249's version assumptions and test matrix.
- Enabling Bash, Edit, web search, MCPs, agents, memory, ambient hooks, or imported
  profiles in the read-only approval reviewer.
- Adopting interactive-only UI features: selection keys, status-line appearance,
  prompt menus, image previews, mouse behavior, voice, feedback UI, minimal/fullscreen
  layout, hyperlink rendering, or table-copy cosmetics.
- Using Grok's own worktree/clone lifecycle in place of our independently verified
  snapshots and disposable worktrees without a separate design and equivalence proof.
- Changing the model pin, cost ceiling, default turn bound, verdict format, exact-head
  rules, or duplicate-paid-work locks merely because the provider changed.
- Production, shared-database, hosted-service, firewall, or secret changes.

## 5. Current state of the code

Planning baseline: local `main` at `a4cc336f15b7a01bf5842b221c10a65efc738a75`
(`docs: plan isolated Grok integration review`, 2026-09-03). The checkout was dirty
and included concurrent edits to `AGENTS.md`, `bin/ai-grok-review`, reviewer tools,
tests, plans, skills, and handoffs. Those changes are not owned by this planning
session and must be preserved. Re-resolve the live state before implementation.

- `bin/ai-grok-review:1-59` declares the wrapper-owned safety/result contract and
  records its last CLI qualification: 0.2.118 on Linux and 1.0.5 on Windows.
- `bin/ai-grok-review:66-87` freezes the approval profile: model `grok-4.6`, Read
  and Grep only, Edit/Bash/MCP denied, agents/subagents/web/memory disabled, and
  Claude/Cursor/Codex imports suppressed.
- `bin/ai-grok-review:680-936` supervises the complete local process tree, waits
  for terminal JSON, gives Grok neutral homes, links authentication without
  copying it, verifies `inspect --json`, and invokes the provider.
- `bin/ai-grok-review:950-1099` validates stop reasons, reports usage/cost/model,
  extracts the verdict, and persists the report.
- `tests/test-ai-grok-review.sh` already guards fixed permissions, isolation,
  resumability, prefix stability, terminal-JSON waiting, stop reasons, usage/cost,
  process cleanup, locks, and incident evidence.
- `skills/shared/grok-cli/SKILL.md` tells both clients to use the wrappers, preserve
  named-session continuity, keep the prefix fixed, record cost, and consult
  version-matched installed docs.
- `bin/install-windows-ai-provider-clis.ps1` pins the official installer script by
  SHA-256 but currently skips any provider already present; it does not prove a
  required Grok version or upgrade an older working binary.
- `bin/install-ai-provider-clis.sh` similarly skips a working Grok unless `--force`;
  it does not pin the resulting provider version.
- `tests/test-windows-ai-provider-clis.ps1` and
  `tests/test-install-ai-provider-clis.sh` cover provider installation mechanics,
  but no current test proves “Grok must be exactly 1.0.13.”
- `plan_grok_integration-review-access.md` and its linked handoff pin security and
  capability findings to 1.0.5. They are planning records, not implemented code.
- Installed Grok is currently 1.0.5; no 1.0.13 update or paid live probe was run.

## 6. Key findings and root cause

1. **The installation path is presence-based, not version-based.** Both provider
   installers consider a runnable `grok` sufficient, so a restore or bootstrap can
   remain indefinitely on 1.0.5. The upgrade requires an explicit version policy
   and post-install verification, not only a new installer hash.
2. **Provider contracts are version-bound.** The wrapper parses one JSON object,
   accepts specific stop reasons, keys model identity through `modelUsage`, and
   reasons about child-process completion. 1.0.13 changes retry, truncation,
   persistence, context counting, and background behavior; all must be probed.
3. **The vendor fixes do not replace our controls.** Automatic recovery from 5xx,
   stalls, truncation, power loss, MCP startup, or background waits improves
   reliability, but it does not prove remote cancellation, exact source, local
   process cleanup, read-only scope, terminal completion, or cost correctness.
4. **A 1.0.11 headless permission hint may be useful but is not automatically
   safe.** It can prevent non-interactive prompts, yet the read-only wrapper already
   uses explicit rules and must never gain blanket approval. Adopt only the narrow,
   documented mechanism after argv/help/source and negative tests prove it cannot
   broaden the frozen rule set. Otherwise document “no wrapper change.”
5. **Corrected server-reported context/usage is useful evidence.** 1.0.12 fixes
   reasoning, rewind, mode-switch, and compaction estimates. The wrapper must keep
   reporting provider values as unavailable when absent and must never derive or
   invent numbers from UI estimates.
6. **1.0.13's response/retry fixes target known wrapper pain.** Auto-continuation of
   length-truncated responses, execution of complete truncated tool calls, and
   transient inference retries should reduce false empty/failure results. Our
   terminal JSON and descendant-process gates remain load-bearing until a live
   qualification proves exactly what changed.
7. **Most release items are intentionally not wrapper features.** Interactive UI,
   visual, voice, scheduling, dashboard, clone, and workflow conveniences should
   not be copied into a non-interactive safety wrapper. Classification is the
   integration; blind adoption is not.

## 7. Approaches considered and rejected

1. **Run `grok update` now, then write the plan from the new machine state.**
   Rejected: the user requested a plan, and an unplanned executable replacement
   would erase the before-state and bypass rollback/evidence gates.
2. **Update only the installer SHA.** Rejected: installer content integrity does
   not prove the binary version installed, and presence-based skip logic would
   leave existing machines on 1.0.5.
3. **Always track latest stable.** Rejected: the wrapper contract is qualified
   against exact behavior. Silent future drift can change flags, JSON, permissions,
   billing, or cancellation semantics.
4. **Delete our terminal wait, supervisor, exact-work locks, or JSON validation
   because 1.0.13 claims retry and persistence fixes.** Rejected: those vendor
   fixes cover different failure layers and do not prove remote cancellation or
   owned local process completion.
5. **Use `--always-approve`, `permission-mode auto`, or a broad 1.0.11 startup hint.**
   Rejected: convenience cannot widen the approval reviewer's fixed read-only
   policy. Only a narrow, source-verified hint that preserves explicit deny rules
   may be considered.
6. **Adopt `grok clone`/provider worktree reuse in the wrappers.** Rejected for this
   upgrade: our snapshot and disposable-worktree evidence is independent of Grok,
   while the new clone path changes source identity and cleanup ownership.
7. **Enable MCPs because 1.0.12/1.0.13 make startup faster and retries better.**
   Rejected for the approval reviewer: speed and resilience do not alter the
   ambient-authority threat. Issue #249 separately governs a narrow bridge.
8. **Treat every changelog bullet as a required code edit.** Rejected: many are UI
   details irrelevant to headless wrappers. Every bullet must be classified, but
   “verified no repository action” is a legitimate disposition.
9. **Reuse the dirty checkout for implementation without ownership reconciliation.**
   Rejected: `bin/ai-grok-review` and `AGENTS.md` already contain concurrent edits.
   Overwriting or broadly staging them would risk another session's work.

## 8. Design decisions

### Locked decisions — do not relitigate

- **2026-09-04:** Support exactly Grok Build 1.0.13 for this qualification. Future
  versions fail with a clear “unqualified version” result until separately reviewed.
- **2026-09-04:** Preserve every existing approval-review safety control and
  capability. A vendor reliability fix is not authorization to remove a guardrail.
- **2026-09-04:** Classify all 1.0.6–1.0.13 release notes, but implement only
  headless/wrapper-relevant items supported by live or deterministic evidence.
- **2026-09-04:** Keep #249's integration reviewer separate. This upgrade refreshes
  its assumptions; it does not make Windows sandboxing or provider hooks a perimeter.
- **2026-09-04:** Keep secrets machine-local. Never read, print, copy, log, hash in
  public evidence, or commit `~/.grok/auth.json`.
- **Existing:** `ai-grok-review` remains fixed-model, read-only, exact-head,
  isolated, bounded, and paid-work duplicate-safe; `ai-grok-implement` remains
  disposable and never auto-applies a patch.

### Open implementation judgments

- Choose the smallest repository-owned version-pin representation that both
  Windows and Unix installers/tests can consume. Criteria: one source of truth,
  no duplicate version literals, readable offline, and fail-closed post-install.
- Decide whether the 1.0.11 startup hint is needed after the live headless probe.
  Adopt only if it prevents a real prompt without granting any tool beyond the
  existing explicit allow/deny profile.
- Decide whether any 1.0.13 vendor fix permits simplifying diagnostics. Default is
  to keep safeguards and update obsolete explanatory wording only; remove code only
  with a reproducer showing equivalence and an independent review agreeing.

No owner decision is required to implement this plan. Escalate only if the exact
1.0.13 artifact cannot be obtained from xAI, the vendor no longer supports a
locked safety flag/result, or keeping the capability would require weakening a
boundary.

## 9. Executable plan

### Phase 0 — ownership and baseline

1. **Reconcile the checkout without touching others' work.** Re-read `AGENTS.md`,
   this STATUS table, issue #251, issue #249, and the current dirty tree. Identify
   the owner/status of concurrent edits to `AGENTS.md`, `bin/ai-grok-review`, its
   tests, and Grok plans. Work directly on current `main`; use an isolated current-
   main worktree only if that does not strand required dirty changes. Stage only
   owned files. **You'll know it worked when:** a dated baseline records local HEAD,
   `origin/main`, branch, remote, `git status --short`, owned-file list, and the
   reconciliation choice under `tests/verification/grok-build-1.0.13/`.

2. **Capture a privacy-safe 1.0.5 before-state.** Without opening auth/session/log
   files, record `grok --version`, `grok --help`, relevant subcommand help,
   wrapper `doctor` output, and redacted `inspect --json` shape. Run existing focused
   Grok tests before modifying source. **You'll know it worked when:** artifacts
   reproduce the 1.0.5 CLI/schema and focused tests pass or each pre-existing failure
   is named and excluded from upgrade claims.

3. **Freeze the release classification.** Copy no vendor prose wholesale. Add a
   concise checked matrix under `docs/` or this plan mapping every 1.0.6–1.0.13
   changelog bullet to: adopt in wrapper, validate/no code change, update guidance,
   defer to #249, or interactive/out of scope. Re-check official changelog and
   version-matched source/docs on implementation day. **You'll know it worked when:**
   no bullet from the eight releases is unclassified and every adopted item names a
   test/probe.

### Phase 1 — exact version installation and rollback

4. **Create one exact Grok version policy.** Add a small secret-free config artifact
   (recommended `config/provider-cli-versions.json`) containing Grok `1.0.13` and
   update both installers and doctors to consume it. Do not force unrelated Kimi/Qwen
   upgrades. Unknown/missing/malformed policy fails before download. **You'll know it
   worked when:** offline tests prove 1.0.5 is stale, 1.0.13 is accepted, 1.0.14 is
   unqualified, and no separate Grok version literal exists in installer logic.

5. **Make Windows and Unix upgrades recoverable and exact.** Update
   `bin/install-windows-ai-provider-clis.ps1` and
   `bin/install-ai-provider-clis.sh` so Grok is skipped only when its reported
   version exactly matches policy; otherwise use the official version-capable update
   path discovered from 1.0.13 docs/help. Verify the downloaded installer hash before
   execution, capture the existing binary/version for rollback without copying auth,
   and verify the new binary reports 1.0.13 before success. Never put remote script
   text directly into a shell pipeline. **You'll know it worked when:** installer
   fixtures cover current, older, newer, bad hash, failed update, wrong resulting
   version, rollback, spaces in paths, and provider isolation; an induced failure
   restores the original executable and leaves credentials untouched.

6. **Install 1.0.13 on EDGE-DEV only after source review.** Verify official URLs,
   exact installer bytes/hash, release identity, and supported version selection.
   Back up only the exact executable/config files the vendor updater may replace;
   never expose auth. Run the repository-owned installer. **You'll know it worked
   when:** `grok --version` is exactly `1.0.13`, `ai-grok-review doctor` resolves the
   intended binary, and the rollback rehearsal can restore the pre-upgrade version.

**Natural context cut:** update STATUS with artifact paths. If starting a fresh
session, re-read Phases 2–6 and the current official 1.0.13 documentation.

### Phase 2 — qualify contracts before adapting behavior

7. **Diff the supported CLI surface.** Capture and compare 1.0.5 vs 1.0.13 help for
   root, `inspect`, `sessions`, `export`, `update`, headless/agent, and worktree/clone
   commands. Inspect the exact 1.0.13 source definitions for flags that wrappers use,
   including the headless permission startup hint. **You'll know it worked when:**
   every argv element emitted by both wrappers is marked unchanged, changed with an
   adaptation, or removed with a hard blocker; no paid run is needed for syntax proof.

8. **Probe isolation and permission behavior without spending first.** Extend fake
   Grok fixtures to reflect 1.0.13 `inspect --json` and help. Prove neutral HOME,
   USERPROFILE/XDG roots, `GROK_HOME`, disabled imports, no MCP/agent/subagent/web,
   fixed Read/Grep or implementation permissions, and deny precedence. Test the
   headless startup hint narrowly. **You'll know it worked when:** any added hint
   cannot approve Edit/Bash/MCP in review mode, schema drift fails closed, and current
   1.0.5-compatible isolation assertions still pass.

9. **Run one bounded two-turn live qualification.** Use a no-secret fixture repo and
   `AI_GROK_CALLER=codex`. First turn tests terminal JSON, a safe denied action, and
   usage/model/cost; resumed turn tests same session ID, context/cache reporting,
   persistence, and transcript export. Simulate/induce only safe transient or length
   conditions if a vendor-supported test mechanism exists—never generate deliberate
   runaway cost. Cap total planned provider spend at $1.50 and record each turn once.
   **You'll know it worked when:** redacted artifacts establish exact keys/types,
   stop reasons, per-call versus cumulative cost, cache semantics, and successful
   resume on 1.0.13; uncertainty is recorded rather than guessed.

10. **Qualify completion and background-process semantics.** Test early launcher
    return, delayed output, invalid/partial JSON, vendor retry, child completion,
    truncation continuation, complete truncated tool calls, cancellation, and timeout
    using fakes plus the smallest safe live probe necessary. **You'll know it worked
    when:** the wrapper accepts only a complete terminal result after owned descendants
    exit and still leaves remote-uncertain work blocked after local interruption.

### Phase 3 — adopt review-wrapper improvements

11. **Update `bin/ai-grok-review`'s version gate and qualification header.** Fail
    before paid work when the resolved Grok version is not the exact supported version;
    allow doctor to explain installed versus required. Replace stale 0.2.118/1.0.5
    claims with artifact-backed 1.0.13 facts while retaining historical reasons for
    load-bearing controls. **You'll know it worked when:** fake-version tests cover
    missing/malformed/older/newer/exact versions and a real doctor reports 1.0.13.

12. **Adopt narrow headless permission handling only if Step 8 proves it.** If the
    startup hint eliminates a real non-interactive prompt without broad approval, add
    it to the fixed prefix and freeze it in tests. Otherwise record the feature as
    evaluated/no-change. Never use `--always-approve`, `auto`, or
    `bypassPermissions`. **You'll know it worked when:** a headless permission request
    either follows only the predeclared narrow rule or fails nonzero without hanging,
    and forbidden tools remain unavailable.

13. **Align terminal-result, persistence, retry, and usage handling.** Adapt parsing
    only where the 1.0.13 live artifacts require it. Recognize no undocumented stop
    reason; preserve raw evidence before emitting a verdict; never count provider
    internal retries as user retries; report server-supplied usage/cost/context fields
    exactly once and `unavailable` when absent. Retain bounded waiting, child
    supervision, atomic state, and exact-work locks. **You'll know it worked when:**
    fixtures cover auto-continued truncation, transient recovery, retry exhaustion,
    power-loss/partial state, resumed sessions, corrected token values, absent fields,
    and no duplicate cost.

14. **Refresh session discovery and transcript behavior.** Evaluate 1.0.11's
    browsable headless sessions and 1.0.13's persistence/Windows worktree fixes against
    `list`, `show`, `transcript`, and resume. Preserve repository/caller isolation and
    explicit session IDs; do not switch to “most recent.” **You'll know it worked
    when:** headless sessions appear only in the intended wrapper scope, two repos and
    two callers cannot collide, and exported/resumed history matches the exact named
    session after restart.

### Phase 4 — implementation and planned integration profiles

15. **Audit `bin/ai-grok-implement` against 1.0.13.** Re-run its entire suite before
    changing behavior. Validate Windows `~/.grok`/worktree fixes and background-command
    completion, but retain wrapper-owned Git worktree creation, patch export, primary-
    checkout immutability, failure preservation, and cleanup. **You'll know it worked
    when:** success, provider failure, cancellation, binary changes, cleanup failure,
    and restart cases pass on 1.0.13 with no auto-apply/commit/push.

16. **Refresh issue #249's version-bound assumptions without implementing it.** Update
    `plan_grok_integration-review-access.md` and its own handoff only if ownership rules
    permit; otherwise add the required delta to issue #249. Reclassify 1.0.7–1.0.13
    MCP retries/startup, form/URL consent, hooks confirmation, workflow/subagent, and
    Windows worktree changes. Preserve the conclusion that hooks/rules are defense in
    depth and Windows lacks the required external containment. **You'll know it worked
    when:** #249 no longer cites 1.0.5 as current and every changed assumption points
    to 1.0.13 evidence without claiming the sandbox exists.

17. **Do not conflate MCP reliability with permission.** If the future integration
    profile uses a single controlled MCP bridge, add 1.0.12/1.0.13 retry/startup and
    consent behaviors to its hostile tests: retries must be idempotent, bounded, and
    incapable of widening endpoints or replaying writes. This is a plan/test-spec
    update only until #249 implementation begins. **You'll know it worked when:** the
    #249 test matrix covers duplicate/replayed MCP calls, transient connection failure,
    auth-ready fast startup, and failure without fallback to ambient MCP.

### Phase 5 — tests, guidance, installation, and landing

18. **Expand focused offline suites.** Modify `tests/test-ai-grok-review.sh`, the
    implementation-wrapper suite, `tests/test-install-ai-provider-clis.sh`,
    `tests/test-windows-ai-provider-clis.ps1`, doctor/setup tests, and fixtures. Add
    explicit test names for exact version gating, installer rollback, permission hint
    denial, terminal retry/truncation, session persistence, server usage truth,
    background descendants, and 1.0.13 inspect schema. **You'll know it worked when:**
    each new behavior has a positive and negative case, existing capability/safety
    cases remain green, and tests make no network/provider call.

19. **Update operator documentation and discovery.** Update
    `skills/shared/grok-cli/SKILL.md`, `docs/config-inventory.md`,
    `docs/windows-winget-configuration.md`, `docs/development.md`, relevant README and
    wrapper headers, `AGENTS.md`, this plan, and issue #251. Separate vendor-native
    reliability from wrapper guarantees; explain exact supported version, upgrade,
    rollback, and incident behavior. **You'll know it worked when:** searches find no
    current 1.0.5 qualification claim outside historical evidence and every plan/router
    link resolves.

20. **Install changed shared skills/wrappers through the supported lifecycle.** Read
    `docs/deployment.md` first, back up exact targets, run the canonical installers,
    and compare source/installed hashes for Claude and Codex skill copies plus wrapper
    launchers. **You'll know it worked when:** installed bytes match reviewed source,
    `doctor` reports exact 1.0.13, and both clients route Grok work through wrappers.

21. **Run exact-head independent review.** Because this touches the reviewer safety
    path, run one read-only final review against the exact candidate HEAD after all
    changes/tests. Any later code change invalidates it. **You'll know it worked when:**
    a retained artifact says APPROVE for the exact commit/source digest and reports no
    weakened permission, isolation, billing, completion, or cancellation behavior.

22. **Run full verification and land.** Run syntax checks on changed scripts, all
    focused Grok/installer/supervisor/sandbox/packet tests, then
    `pwsh -NoProfile -File tests/test-all.ps1` on Windows and `bash tests/test-all.sh`
    on Linux. Verify Git identity is `Albert Hazan <u2giants@users.noreply.github.com>`,
    stage only owned files, reconcile concurrent `main`, commit, push, and confirm the
    commit on `origin/main`. Wait boundedly for GitHub `verify`; fix code failures.
    **You'll know it worked when:** focused and full artifacts, green CI run ID,
    exact-head review, commit SHA, and remote containment are recorded.

23. **Perform post-install live acceptance and close.** On supported Windows and
    Linux hosts, prove exact binary version, free doctor/auth check, one bounded
    read-only new+resume review, and one safe implementation smoke if authorized and
    cost-bounded. Confirm no working-tree mutation from review, correct patch isolation
    from implementation, correct usage/cost, no orphan process, and rollback viability.
    Update STATUS and close #251 only after all evidence exists; then retire this plan's
    handoff in the completion commit. **You'll know it worked when:** live evidence is
    tied to installed hashes and exact source SHA, `origin/main` contains the commit,
    CI is green, and every definition-of-done checkbox is proven.

## 10. Tests required

### Installer/version tests

- `grok_exact_supported_version_is_skipped`
- `grok_older_version_triggers_exact_upgrade`
- `grok_newer_unqualified_version_is_not_accepted`
- `grok_installer_hash_drift_fails_before_execution`
- `grok_wrong_post_install_version_rolls_back`
- `grok_failed_upgrade_restores_original_binary`
- `grok_upgrade_never_reads_or_copies_auth_json`
- `other_provider_versions_are_unchanged`

### Review-wrapper tests

- `grok_1_0_13_help_and_inspect_contract_is_accepted`
- `unknown_grok_version_fails_before_paid_turn`
- `headless_hint_cannot_broaden_fixed_review_permissions`
- `automatic_transient_retry_yields_one_terminal_result_and_one_cost`
- `retry_exhaustion_is_nonzero_and_remote_uncertain_when_required`
- `length_truncation_continues_to_complete_terminal_json`
- `complete_truncated_tool_call_does_not_weaken_tool_policy`
- `partial_or_power_loss_state_is_never_accepted_as_complete`
- `resumed_headless_session_keeps_exact_id_repo_and_caller`
- `server_usage_fields_are_reported_once_without_estimation`
- `missing_usage_context_or_duration_is_unavailable_not_zero`
- `background_descendant_must_exit_before_success`
- Existing permission, exact-head, packet, lifecycle, lock, cancellation, timeout,
  report, transcript, and incident-evidence cases remain green.

### Implementation/integration tests

- `implementation_1_0_13_preserves_primary_checkout_and_exports_patch`
- `windows_worktree_paths_round_trip_on_1_0_13`
- `provider_background_exit_does_not_race_patch_export`
- `failed_implementation_preserves_or_exports_unique_work`
- `integration_mcp_retry_is_bounded_idempotent_and_scope_preserving` (plan/#249)
- `integration_mcp_failure_never_falls_back_to_ambient_server` (plan/#249)

### Commands and evidence

- `bash -n` for every changed Bash file.
- Focused Bash/PowerShell suites named above.
- `pwsh -NoProfile -File tests/test-all.ps1` on Windows.
- `bash tests/test-all.sh` on Linux.
- One exact-head read-only independent final review.
- One cost-bounded 1.0.13 new/resume live qualification per supported platform;
  never run live provider probes in CI.

## 11. Constraints and gotchas

- Preserve concurrent dirty changes. Never reset, clean, broadly stage, or overwrite
  another session's files.
- Work directly on `main`. GitHub is source of truth. No force push.
- Before committing, `git var GIT_COMMITTER_IDENT` must show Albert's `u2giants`
  noreply identity even though the current remote resolves to `popcre/ai-devops`.
- Reviewer safety-path changes require an independent exact-head final review.
- Do not run local reviewer suites while protected Windows CI/reviewer activity owns
  EDGE-DEV; check current runner/process state first.
- Never read or print `~/.grok/auth.json`, raw sessions, or raw logs. Redact paths,
  prompts, repository identities, and credentials from committed evidence.
- Never pipe a downloaded installer directly into execution. Verify exact bytes,
  protect the temp path, and retain a recoverable exact-target backup.
- Do not trust exit status alone. Require valid terminal JSON, accepted stop reason,
  intended session ID, provider/model identity, and owned descendant completion.
- Provider retries are not authorization for wrapper retries. An interrupted paid turn
  stays blocked until remote state is reconciled.
- Do not invent usage, cache, duration, context, cost, or returned-model metadata.
- Version 1.0.13 fixes Windows path/session behavior; it does not supply an enforcing
  Windows OS sandbox. Permission rules and hooks are not containment.
- `grok clone`/worktree improvements do not supersede repository-owned source identity,
  snapshot, patch, cleanup, or rollback proof.
- Do not update another session's write-once handoff. Carry a delta into this handoff
  or the owning issue when ownership prevents an edit.
- No database, production, hosted-service, or secret mutation is authorized.

## 12. Access and environment

- Local checkout: `C:\repos\ai-devops`, Windows PowerShell plus Git Bash.
- Machine: EDGE-DEV; local Grok 1.0.5 is authenticated and callable today.
- GitHub CLI is authenticated to the current `popcre/ai-devops` remote and issue #251.
- Grok provider credentials remain under machine-local `~/.grok`; do not inspect them.
- No 1Password item is required for the normal official update. If a future hosted
  #249 sandbox is chosen, its item belongs in vault `vibe_coding`, title to be defined
  by that workstream; never put a value in this plan.
- Windows install entry: `bin/install-windows-ai-provider-clis.ps1` through the
  supported bootstrap/lifecycle after reading `docs/deployment.md`.
- Linux/macOS install entry: `bin/install-ai-provider-clis.sh` as the non-root user
  who runs Grok; use its supported force/version path after implementation.
- Offline full suite: `pwsh -NoProfile -File tests/test-all.ps1` on Windows and
  `bash tests/test-all.sh` on Linux.
- Live tests use `AI_GROK_CALLER=codex`, a no-secret fixture repository, named sessions,
  prompt files, and the wrapper; never call raw Grok for review work except the
  version/help/qualification commands explicitly required above.

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] Official 1.0.6–1.0.13 changelog is fully classified; every useful item is
  adopted, validated as native/no-code, documented, or deliberately deferred.
- [ ] One shared exact-version policy requires Grok Build 1.0.13.
- [ ] Windows and Unix installers upgrade older Grok safely, verify the result, and
  have a tested rollback without touching credentials.
- [ ] All wrapper argv, inspect, terminal JSON, stop, session, usage, cost, retry,
  truncation, and child-process contracts are qualified against 1.0.13.
- [ ] `ai-grok-review` remains read-only, exact-head, isolated, bounded, and
  duplicate-paid-work safe.
- [ ] `ai-grok-implement` retains disposable worktree/patch recovery and never mutates
  the primary checkout or auto-applies changes.
- [ ] Issue #249's assumptions/test matrix are refreshed without pretending its
  unimplemented containment exists.
- [ ] Focused and full Windows/Linux suites pass with retained artifacts.
- [ ] Independent exact-head review approves the final safety-path diff.
- [ ] Installed wrapper/skill hashes match source; Grok reports exactly 1.0.13.
- [ ] Live new/resume and safe implementation acceptance prove intended behavior,
  usage/cost truth, no orphan process, and no unintended checkout mutation.
- [ ] Git identity is verified; only owned files are committed; commit is on
  `origin/main`; GitHub `verify` is green.
- [ ] Plan STATUS is current, issue #251 is closed with evidence, and this plan's
  handoff is retired in the completion commit.

### Risks and mitigations

- **Installer drift or unavailable exact artifact:** fail before replacement; keep the
  backup and prior working binary. Do not accept “latest.”
- **CLI/JSON schema drift:** fail closed before a paid turn and preserve redacted raw
  evidence for diagnosis.
- **Provider internal retry duplicates cost or work:** treat one wrapper invocation as
  one exact-work reservation and prove reported billing semantics live.
- **New permission hint broadens scope:** omit it unless deny-precedence and available
  tools are proven. Reliability is not worth authority expansion.
- **Vendor persistence changes corrupt wrapper state:** keep wrapper metadata atomic
  and treat provider session state as external evidence, not the sole ledger.
- **Concurrent checkout edits collide:** stop before overwriting; reconcile ownership
  or use a clean isolated current-main worktree.
- **1.0.13 breaks a locked capability:** roll back the exact binary, leave repository
  version support unlanded, attach evidence to #251, and preserve the old capability.

### Open questions to resolve with evidence, not owner preference

1. What exact documented command installs **1.0.13**, rather than the moving stable
   channel, on each platform? Resolve from 1.0.13 `update --help`, installer source,
   and a no-secret dry-run/source audit before Step 5.
2. Does 1.0.11's headless startup hint add anything when explicit fixed rules already
   prevent prompts? Resolve in Step 8; default to no added flag.
3. Did the single-object JSON schema, stop reasons, cost semantics, or model identity
   change by 1.0.13? Resolve with Step 9 artifacts before parser edits.
4. Does 1.0.13 eliminate the early launcher-return symptom on Windows under load?
   Even if yes, keep terminal/descendant proof unless an independent review finds a
   safe simplification with equivalent protection.
5. Which #249 capability assumptions changed? Refresh only from official 1.0.13
   documentation/source and keep platform containment conclusions separate.

## Appendix A — release disposition baseline

This is the planning classification to verify at Step 3. It groups related official
bullets but covers every 1.0.6–1.0.13 item.

| Release | Useful to our wrappers — required disposition | Validated native benefit, normally no code change | Interactive/UI only — out of scope |
|---|---|---|---|
| 1.0.6 | Large/unhealthy-repo startup; queued-goal messages; Windows hook project path (recheck #249 only); clone projected tree (evaluate, do not adopt) | Consent and `/dev/null`-adjacent reliability; storage error | Selection, editing, double-click, link, image/video UI |
| 1.0.7 | Noninteractive tokenless MCP auth, auth-refresh races, loop interruption, subagent tool reduction; connection timeout only if wrapper needs it | Scheduled deletion and status script timer | Permission cards, workflow catalog/UI, mail links |
| 1.0.8 | MCP form/URL consent for #249; concurrent subagent/startup behavior; follow-up while waiting | Invented-tool error and folder zip semantics | Draft stash, workflow autocomplete, status row, UI context display |
| 1.0.9 | MCP URL identity/add behavior for #249; subagent retry/burst/startup; narrow Bash allow semantics for hostile tests; memory-as-history guidance; background shell interjection | Workflow effort/budget and clone optimizations are evaluated but not adopted | Feedback, menus, dashboard, prompt/layout/copy/modal/minimal/fullscreen cosmetics |
| 1.0.10 | Evaluate provider worktree reuse but retain repository-owned lifecycle | Faster matching checkout reuse | None beyond command UX |
| 1.0.11 | Headless session discovery; narrow headless permission startup hint; permission chain reliability; background wait completion | Configurable interactive default and history duration/footer inform docs only | Mouse/paste/cards/images/execute expansion/voice |
| 1.0.12 | MCP transient retry for #249; subagent wait isolation; reasoning/rewind/mode token truth; compaction state; worktree speed | .NET watcher and recap reliability | Table-copy and friendly prompt descriptions |
| 1.0.13 | Truncation continuation/tool-call completion; transient inference retries; Windows home/worktree; durable session saves; compaction/truncation diagnostics; subagent/MCP startup; full UUID scheduled IDs if monitor wrapper ever consumes them | Large-image resilience, compressed updates, monitor stop reminder | iTerm image preview and Windows hyperlink cosmetics |

## Mandatory self-audit — final pass

1. **Could a brand-new AI session execute this without asking a question? Yes.**
   §§1–5 define the business goal, repository, trigger, scope, exact current state,
   issue ownership, branch, and environment. §9 gives ordered file-specific steps
   with a verification gate for every step; §§10–13 supply tests, constraints,
   access, completion, rollback, and evidence-resolved questions.
2. **Does it preserve every relevant finding, nuance, and rejected path? Yes.**
   §§6–8 record the version-bound root causes, why vendor fixes do not replace our
   controls, all rejected shortcuts, and locked versus open decisions. Appendix A
   prevents any release family from disappearing during implementation.
3. **Is the goal clear enough for a correct judgment call when a step is wrong? Yes.**
   §1 states the owner outcome and the goal-wins rule. §§4 and 8 make capability
   preservation, exact 1.0.13 support, read-only approval, isolated implementation,
   and #249 separation explicit.

All checklist items pass: all 13 sections are present; the out-of-scope list,
rejected approaches, locked/open decisions, concrete paths/functions, named tests,
secrets boundary, commit/push/CI/install/live gates, and two-way handoff links are
included.
