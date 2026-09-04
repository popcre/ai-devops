# Reviewer investigation mode — Option B implementation plan

Plan owner: issue [#253](https://github.com/popcre/ai-devops/issues/253)

Plan handoff: [`HANDOFF.d/2026-09-04T0055Z-edge-dev-codex-reviewer-investigation-option-b.md`](HANDOFF.d/2026-09-04T0055Z-edge-dev-codex-reviewer-investigation-option-b.md)

Repository: `popcre/ai-devops` (local checkout `C:\repos\ai-devops`)

Target branch: `main`

## STATUS — read this first

| Step | Owner issue | Status | Evidence |
|---|---:|---|---|
| 0. Re-resolve the current tree and active work | #253 | ⬜ open | Run the commands in Step 0 and record the output under `tests/verification/reviewer-investigation-option-b/` |
| 1. GLM/OpenCode upgrade and investigation mode | #254 | ⬜ open | Required artifacts are listed in Step 1 |
| 2. Kimi CLI upgrade and investigation mode | #255 | ⬜ open | Required artifacts are listed in Step 2 |
| 3. Qwen discovery repair, upgrade, and investigation mode | #256 | ⬜ open | Required artifacts are listed in Step 3 |
| 4. Muse investigation mode on the qualified OpenCode pin | #257 | ⬜ open | Required artifacts are listed in Step 4 |
| 5. Cross-provider integration, final review, and landing | #253 | ⬜ open | Required artifacts are listed in Step 5 |

Fresh session starts at **Step 0**. GLM Step 1 must land before Muse Step 4. Kimi Step 2 and Qwen Step 3 can be developed independently after Step 0, but this repository works directly on `main`; serialize commits and re-resolve current state before each landing. Re-read the remaining downstream steps before beginning each new provider because native CLI contracts may have changed.

## 1. Ultimate goal

The business outcome is that GLM 5.3, Kimi, Qwen, and Muse can investigate software thoroughly: they can run builds and tests, inspect runtime behavior, and reach public internet resources when the work requires it. This must be delivered with the fewest new moving parts and without giving a reviewer the operator's credentials or allowing it to damage the shared checkout used by other sessions.

The chosen approach is **Option B**: reuse each provider's existing wrapper and capable implementation machinery, add a thin explicit `investigate` mode, and add only the missing Muse capable path. Do not build a new shared lifecycle framework.

If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is a public backup-and-restore toolkit for Albert Hazan's multi-model coding workflow. It contains Bash and PowerShell launchers, provider wrappers, prompt/profile configuration, installers, documentation, and offline verification. It is not a hosted application and has no application deployment. Installation places commands and secret-free configuration on Windows and Ubuntu machines; GitHub `origin/main` is the code truth.

The affected reviewers are:

- **GLM 5.3**, hosted by the repository-pinned OpenCode runtime through `bin/ai-glm`.
- **Kimi Code**, driven headlessly through `bin/ai-kimi`.
- **Qwen Code**, driven headlessly through `bin/ai-qwen`.
- **Muse**, driven through repository-pinned OpenCode direct mode by `bin/ai-muse`.

“Formal review” means the existing read-only judge mode whose output may satisfy an independent review gate. “Investigation” means a capable advisory turn with shell and internet access. Investigation output never becomes formal approval merely because it reached a verdict.

The work runs on Windows host `EDGE-DEV` and the configured Ubuntu reviewer host(s). Machine facts must be read from `templates/system/machine-atlas.md` only when the relevant installation or live qualification step begins.

## 3. What triggered this work

On 2026-09-03 Albert decided that reviewers need shell and internet access so they can perform more thorough testing. His priority is the least possible complexity. A GLM 5.3 consultation recommended retaining a formal read-only judge tier and adding a capable investigation tier in disposable copies. The first GLM suggestion—extracting a new shared lifecycle core—was rejected as too much initial machinery. Option B instead reuses the implementation paths already present in GLM, Kimi, and Qwen, and adds the equivalent to Muse.

The live baseline observed during planning was:

- OpenCode repository and installed pin: `1.18.12`; current upstream stable observed: `1.18.27`.
- Kimi installed: `0.36.1`; current upstream stable observed: `0.40.1`.
- Qwen installed: `0.21.15`; current upstream stable observed: `0.23.0`.
- `ai-qwen doctor` could not find the binary even though PowerShell resolved it, so discovery must be repaired before treating an upgrade as successful.
- The repository model catalog pins GLM 5.3 and Muse Spark 1.2 Contributor. A provider/model change is not implied by a CLI upgrade; re-resolve authenticated model inventory first.

These version observations are planning evidence, not future pins. The implementing session must re-check official stable releases and pin exact tested versions.

## 4. Scope — in and out

### In scope

- One explicit `investigate` command for each of the four existing wrappers.
- Shell, build/test, and outbound public-internet capability inside a disposable repository copy.
- Exact native CLI/harness upgrades where a current stable release passes the complete qualification matrix.
- Reuse of existing named sessions, clone/worktree lifecycle, remote removal, provider credential handoff, completion parsing, bounded execution, incomplete artifact recovery, and report publication.
- A separate capable provider profile where native tooling requires one.
- Windows and Ubuntu installation, doctor, documentation, skill, and live qualification updates.
- Exact-head independent final review because AGENTS.md classifies this as a reviewer safety-path change.

### Not in this plan

- A new shared lifecycle library or broad wrapper consolidation; that remains separate issue #169.
- Unrestricted execution in the live shared checkout.
- Passing 1Password service tokens, GitHub write credentials, cloud credentials, SSH keys, `.env` contents, or the caller's general environment to reviewer shell children.
- An egress allowlist/broker, container platform, VM platform, daemon fleet, or new network service.
- Automatic application of complete or incomplete reviewer patches.
- Treating investigation output as formal read-only approval.
- Grok, Gemini, DeepSeek, Claude, or Codex reviewer changes.
- Production infrastructure or shared-database writes.

## 5. Current state of the code

No implementation code for Option B has started. The only completed artifacts are this plan, its handoff, parent issue #253, and four child issues #254–#257.

The planning checkout was dirty before this work. Existing modifications include `bin/ai-muse`, `bin/ai-review-sandbox`, `docs/critical-incidents.md`, `docs/muse-opencode.md`, `skills/shared/ask-muse/SKILL.md`, and several other files. They belong to other work and must not be overwritten or broadly staged. `AGENTS.md` also contains an unrelated uncommitted router row for protected Windows verification. Re-resolve ownership before editing any overlapping path.

Existing reusable machinery:

- `bin/ai-review-sandbox:27-32,298-365` creates, refreshes, validates, and removes recorded disposable copies.
- `bin/ai-glm:1154-1407` already owns capable implementation clone lifecycle, terminal state, patch/report export, abort, and cleanup. `config/opencode/agent/glm-implement.md` grants Bash.
- `bin/ai-kimi:608-694,1422-1967` already owns capable implementation turns in a stable disposable worktree, cumulative patch recovery, and completion handling. `config/kimi/local-implement.md` is the capable profile.
- `bin/ai-qwen:485-540,929-1489` already launches full tools under Qwen's native sandbox in a disposable worktree and scrubs child credentials.
- `bin/ai-muse:236-359` currently supports protected read-only turns only; it already has named sessions, private snapshots, private credential handoff, terminal `step_finish` proof, and durable reports.
- `config/opencode/version` pins the OpenCode version consumed by GLM and Muse installers.

Repository status at planning time was local `main` at `ff72d5735b80beb2e05e94e552264674280fbdd4` while fetched `origin/main` was `71bfed6eb12f252e8f3996e91038519958c9aae9`. This is not authority for implementation: Step 0 must determine ancestry, concurrent work, and the actual current source of truth without destructive commands.

## 6. Key findings and root cause

1. The capability gap is mostly naming and policy, not missing machinery. GLM, Kimi, and Qwen implementation modes already provide shell access and can reach the network; duplicating that machinery would add complexity without capability.
2. Muse is the sole provider that needs a new capable execution path. Its direct OpenCode wrapper has the session, report, key-handoff, and completion foundations, but only a no-shell agent profile.
3. A disposable remote-less copy is not an elaborate network sandbox. It is one existing helper that prevents a shell-capable reviewer from modifying the checkout shared by concurrent sessions and keeps evidence tied to a stable source state.
4. Internet access turns every readable credential into an exfiltration risk. Therefore the minimal credential control is to launch with an allowlisted environment, inject only the provider credential required for the model call through the existing private mechanism, and remove/scrub it before reviewer shell children run.
5. Native provider completion differs. Kimi relies on its recorded `session.resume_hint`; Qwen requires a terminal successful `result`; OpenCode/Muse uses structured stop/`step_finish`; GLM validates server/session/model state. Exit zero alone is not completion and must remain insufficient.
6. CLI upgrades can silently change flags, profiles, default subagents, permission behavior, completion events, or credential inheritance. “Latest” must therefore become one exact reviewed pin only after hostile and authenticated qualification.
7. Qwen currently has a concrete local installation fault: PowerShell finds `qwen`, while the wrapper doctor does not. Upgrading without fixing cross-shell resolution would leave restoration and qualification misleading.

## 7. Approaches considered and rejected

### Rejected: unrestricted live-checkout and live-machine access

It is superficially the fewest controls, but it gives an internet-enabled model access to concurrent work and any inherited credentials. It also lets the reviewer change the evidence it is judging. The extra value over a disposable copy is negligible because the copy already supports shell, builds, tests, and internet.

### Rejected: preserve all current read-only isolation

This directly conflicts with the requested outcome. Read-only reviewers cannot run tests or reproduce runtime failures, so the capability remains incomplete.

### Rejected: replace all wrappers with one shared lifecycle core

This was GLM's clean long-term recommendation, but it is not the least-moving-parts delivery. It would create a broad migration across four providers before the requested capability exists. Issue #169 remains the separate home for safe infrastructure consolidation.

### Rejected: an egress broker or domain allowlist

It provides stronger control but adds a service, policy language, broker protocol, and ongoing allowlist ownership. Reconsider only if investigation targets must contain licensed/private data or secrets that cannot be excluded from the disposable copy.

### Rejected: use native “latest” updates or auto-update

Recovery must be reproducible. Native defaults can change unreviewed behavior. Pin the exact qualified version in repository-owned installation/configuration.

### Rejected: turn the formal review command into full-access mode

That would remove the independent judge boundary and make existing governed workflows ambiguous. An explicit `investigate` command is a small interface addition that keeps the consequence visible.

## 8. Design decisions already made

### Locked decisions — do not relitigate

- **2026-09-03, owner:** reviewers must gain shell and internet capability for deeper testing.
- **2026-09-03, owner:** choose the least-moving-parts Option B; do not introduce the shared lifecycle-core rewrite.
- Investigation uses existing capable machinery and a disposable remote-less repository copy.
- Investigation and formal review remain separate modes and evidence classes.
- Reviewer shell children receive no operator credentials. Only the minimum provider credential may enter the model launcher, and existing private/self-deleting handoff patterns must keep it out of child process environments and arguments.
- Execution stays bounded; exact session/model identity, source identity, terminal completion, durable evidence, and incomplete-work recovery remain.
- No auto-application of reviewer changes.
- Exact stable versions are pinned only after qualification; never use a floating runtime `latest`.

### Open implementation judgment

- Whether the thin public command dispatches directly to the existing `implement` function or factors a tiny provider-local helper. Choose the smaller tested change; do not create cross-provider infrastructure.
- Whether investigation returns a patch when the reviewer changed files. Prefer reusing the existing patch and incomplete-patch format rather than inventing a new artifact.
- Whether a provider's current stable release is safe to adopt. If it fails any mandatory canary, retain the last qualified pin, document the exact failed behavior in the child issue, and still deliver investigate mode on the qualified version where possible.
- Whether Muse's authenticated inventory supports a newer model. Model upgrade is allowed only if explicitly verified and does not change the plan's shell/internet objective.

## 9. Ordered implementation plan

### Step 0 — re-resolve source truth, ownership, and qualification baseline (#253)

1. Read `AGENTS.md`, then `docs/architecture.md`, `docs/development.md`, `docs/design-decisions.md`, `docs/critical-incidents.md`, and the verification headers of the four wrappers and `bin/ai-review-sandbox`.
2. Run `git status --short`, `git fetch origin main`, `git rev-parse HEAD origin/main`, `git merge-base --is-ancestor` in both directions, `git worktree list --porcelain`, and inspect active handoffs/issues. Do not pull, reset, clean, or overwrite dirty files.
3. Resolve ownership of every overlapping dirty file. If an active session owns it, wait or implement in a non-overlapping file and serialize landing. Do not create a feature branch; this repository lands directly on `main`.
4. Record exact current native versions, binary paths, `--help`, doctors, configured models, and sanitized environment behavior on Windows and Ubuntu under `tests/verification/reviewer-investigation-option-b/<UTC>-baseline/`. Do not store credentials or raw transcripts.
5. Re-check the latest official stable version for OpenCode, Kimi Code, and Qwen Code. Record URLs, release dates, checksums/package identities, and the exact candidate versions.
6. Check protected Windows CI/runner activity before any local full suite. If protected work is active, perform only focused read-only preparation and defer the local suite.

**Verification gate:** the baseline artifact identifies current HEAD/origin ancestry, every dirty overlapping path and owner, installed and candidate provider versions, current doctors, and the exact safe point for each child issue. No implementation begins with ambiguous ownership.

**Natural context cut:** after Step 0, update this STATUS table and re-read Steps 1–5.

### Step 1 — GLM and shared OpenCode pin (#254)

Targets: `bin/ai-glm`, `config/opencode/version`, `config/opencode/agent/glm-implement.md` or a new provider-local investigation profile, `bin/setup-opencode-glm.sh`, `bin/setup-opencode-glm.ps1`, Muse installer compatibility files as required by the shared pin, `tests/test-ai-glm.sh`, OpenCode contract fixtures/tests, `docs/glm-opencode.md`, `docs/model-setup.md`, `docs/development.md`, and `skills/shared/ask-glm/SKILL.md`.

1. Capture the old and candidate OpenCode contracts: server health/version, session creation/resume, permission event/reply shapes, structured completion, model identity, token object, abort behavior, and direct-mode compatibility required by Muse.
2. Upgrade the exact OpenCode pin only after the contract diff is understood. Update both OS installers and checksums/package identity. Back up installed configuration before changing it; installation must remain recoverable.
3. Add `ai-glm investigate <name> --prompt-file <file>` as a thin dispatch into the existing implementation job lifecycle. Its user-facing report must say `INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL`.
4. Give the investigation agent Bash and normal outbound internet through Bash. Do not add a new broker. Keep the clone remote removed and launch with an allowlisted environment.
5. Ensure the provider key reaches only the OpenCode provider transport and is absent from Bash child environment, process arguments, reports, patches, and logs. If the candidate OpenCode cannot enforce this, do not ship investigation mode on that candidate.
6. Preserve named-session locking, exact model verification, bounded wall time, abort, terminal state, complete/incomplete patch export, exact cleanup, and formal review's no-shell profile.
7. Update focused tests, doctor output, documentation, and the installed shared skill. Preserve all old formal review assertions; add explicit capable-mode assertions.
8. Run focused offline tests, Windows and Ubuntu setup/doctor, hostile write/network/credential canaries, one authenticated investigation that runs a harmless command plus public HTTP request, and one authenticated formal review proving no shell.

**Verification gate:** issue #254 contains redacted artifacts proving the exact OpenCode version, GLM 5.3 identity, working shell and public internet in investigation, no credential in tool children/output, remote-less disposable copy, bounded completion/recovery, and unchanged formal read-only behavior. Commit is on current `main` before Step 4 starts.

### Step 2 — Kimi Code (#255)

Targets: `bin/ai-kimi`, `config/kimi/local-implement.md` or a new `config/kimi/investigate.md`, Kimi installation/version management scripts identified during Step 0, `tests/test-ai-kimi.sh`, `docs/model-setup.md`, `docs/development.md`, and `skills/shared/kimi-code-delegation/SKILL.md`.

1. Capture candidate Kimi help, agent/profile schema, exact-session resume, headless output, `session.resume_hint`, data locations, model selection, permissions, subagent defaults, and environment inheritance.
2. Upgrade to the exact current stable candidate only if all mandatory contracts pass. Explicitly disable default secondary-model/subagent behavior for investigation unless attribution, bounds, and completion can be proven without additional orchestration.
3. Add `ai-kimi investigate <name> --prompt-file <file>` as a thin use of the current implementation-session/worktree path. Use a dedicated capable profile if that is smaller than conditional mutation of `local-implement.md`.
4. Grant Bash and public internet tools; retain stable named-session continuation, immutable base plus cumulative patch, remote-less disposable tree, bounded execution, terminal proof, incomplete recovery, and artifact cleanup.
5. Keep provider/OAuth data in the protected Kimi home. Launch tool children without OAuth, 1Password, GitHub, SSH, cloud, or general operator credentials. Prompts remain secret-free because Kimi may expose them through local process arguments.
6. Preserve formal review's no-Bash/no-network/no-write profile and before/after mutation detection.
7. Update doctors, installers, focused tests, docs, and shared skill with current-version facts only.
8. Run focused offline hostile tests and authenticated Windows/Ubuntu canaries for shell, public HTTP, exact continuation, interruption recovery, and formal review denial.

**Verification gate:** issue #255 contains redacted evidence for the exact candidate version and requested model, successful shell/internet investigation, credential-free children, one accountable named reviewer, correct completion proof, safe recovery, and unchanged formal read-only review. The commit is on current `main`.

### Step 3 — Qwen Code (#256)

Targets: `bin/ai-qwen`, Qwen provider installer and sanitizer/preloader identified by the wrapper verification header, version configuration, `tests/test-ai-qwen.sh`, installation tests, `docs/model-setup.md`, `docs/development.md`, and `skills/shared/qwen-code/SKILL.md`.

1. Repair binary discovery first. Windows PowerShell and Git Bash must resolve the same repository-qualified binary. `ai-qwen doctor` must identify it before any upgrade claim.
2. Capture candidate help, `stream-json` terminal result, model identity, safe/sandbox/approval flags, exact-session resume, provider endpoint, tool-child environment, and native credential sanitizer behavior.
3. Upgrade to the exact stable candidate only after reapplying and behaviorally verifying the repository-owned credential hardening. Do not adopt `qwen serve`, loopback unauthenticated operator APIs, Channels, or native multi-agent workflows for this plan.
4. Add `ai-qwen investigate <name> --prompt-file <file>` as a thin alias/dispatch over the existing implementation worktree path with Qwen sandbox enabled.
5. Keep the private self-deleting provider-key handoff, child-process scrubber, remote-less disposable worktree, bounded turns/tools/time, exact model/session proof, terminal `result` requirement, and incomplete patch recovery.
6. Preserve formal review safe mode, excluded shell/write tools, full dirty-tree content hash, and no-network/no-write assertions.
7. Update installer qualification, doctor, focused tests, docs, and shared skill.
8. Run cross-shell discovery tests, offline hostile tests, Windows/Ubuntu installation/doctor, authenticated investigation shell/public-HTTP canary, credential-child canary, interruption recovery, and formal review denial.

**Verification gate:** issue #256 contains redacted evidence that both shells resolve one exact qualified version, investigation shell/internet works inside the disposable sandbox, credentials do not reach tool children, missing terminal result fails, interrupted work is recoverable, and formal review remains read-only. The commit is on current `main`.

### Step 4 — Muse on the qualified OpenCode pin (#257)

Dependencies: Step 1 is merged to `origin/main`; re-read Step 1 artifacts and the current `bin/ai-muse` before starting.

Targets: `bin/ai-muse`, new `config/opencode-muse/agent/muse-investigate.md`, `config/opencode-muse/opencode.json` only if required, both Muse installers, `tests/test-ai-muse.sh`, `tests/test-muse-opencode-contract.sh`, sanitized Muse fixtures, `docs/muse-opencode.md`, `docs/development.md`, and `skills/shared/ask-muse/SKILL.md`.

1. Re-capture the Meta provider's exact OpenCode event/token/finish contract on the Step 1 pin. Verify authenticated model inventory; change the Muse model pin only if the provider currently supports and identifies the intended newer model.
2. Add a separate Muse investigation agent with Bash enabled and an explicit `ai-muse investigate <name> --prompt-file <file>` command. Do not mutate the existing formal review agent into a capable profile.
3. Reuse `ai-review-sandbox` and the existing Muse named-session/report path. The investigation copy must be self-contained and remote-less; add only the minimal patch/report export needed to preserve reviewer changes or failed partial work, preferably by reusing an existing helper rather than importing another provider wrapper.
4. Reuse Muse's private key handoff, but prove the handoff file is consumed/deleted and the key removed before any model-controlled Bash child can inspect environment, arguments, filesystem, logs, or reports.
5. Preserve caller identity, session lock, exact returned session, bounded turn, terminal `step_finish`/stop proof, usage reporting, stale-source truth, reconciliation, and exact recorded-copy cleanup.
6. Update installers, fixtures, doctors, focused tests, docs, and shared skill. Preserve the formal `muse-review` profile's no-shell contract.
7. Run offline hostile tests and authenticated Windows/Ubuntu investigation/formal-review canaries.

**Verification gate:** issue #257 contains redacted evidence for the exact OpenCode and Muse model identities, working shell/public HTTP, credential-free tool children, remote-less disposable copy, truthful completion/reconciliation/recovery, and unchanged formal read-only review. The commit is on current `main`.

### Step 5 — cross-provider integration, independent review, and landing (#253)

Targets: `AGENTS.md`, `README.md` only if user-facing command discovery requires it, `docs/architecture.md`, `docs/development.md`, `docs/design-decisions.md`, `docs/critical-incidents.md` only for durable new incidents, `docs/skills-map.md`, affected shared skills, installation inventory, version catalog, and cross-provider test routing.

1. Re-fetch `origin/main`, reconcile each child commit without force, and verify all four child issues refer to current artifacts rather than superseded heads.
2. Add the plan to the AGENTS.md documentation router without disturbing the unrelated protected-Windows row. Update durable design decisions: formal review remains judge mode; investigation is capable advisory mode; Option B intentionally avoids shared-core work.
3. Verify consistent command vocabulary and report labels across all four providers while retaining native completion semantics. Do not factor shared code merely for textual uniformity.
4. Run all focused provider suites, setup/restore checks, secret scans, shell-format checks, and the complete offline Bash plus PowerShell verification when the protected Windows host is free. Do not rerun an unchanged timeout without a diagnostic purpose.
5. Install the exact tree on Windows and Ubuntu, then run each doctor plus one live investigation canary per provider. Store only redacted aggregate evidence under `tests/verification/reviewer-investigation-option-b/`.
6. Run one read-only exact-head independent final review against the frozen tree. The reviewer may be any qualified independent provider that is not the implementing agent, but it must inspect the exact commit/diff and all evidence. Correct substantive findings and repeat on the new exact head.
7. Before the final commit, run `git var GIT_COMMITTER_IDENT` and require `Albert Hazan <u2giants@users.noreply.github.com>`. Stage only owned files. Commit directly to `main`, reconcile concurrent main safely, push without force, and verify the intended SHA is present on `origin/main`.
8. Close child issues only when their evidence is current. Close parent #253 only after all children are closed, the full exact-head gate passes, installed live canaries pass, and this plan's STATUS table is updated with artifact paths. Retire this handoff in the completion commit.

**Verification gate:** all four reviewers have working `investigate` modes and unchanged formal review modes on both supported operating systems; the exact-head full suite and independent review pass; installed live canaries pass; no secret appears in repository, output, process arguments, or reviewer child environment; the final SHA is verified on `origin/main`; issues #254–#257 and parent #253 are closed with evidence.

## 10. Tests required

Every provider suite must add named behavior for:

- `investigate` appears in help and rejects unknown/arbitrary native flags.
- Investigation uses the exact existing capable lifecycle rather than a parallel unbounded path.
- A harmless shell write occurs only inside the recorded disposable copy.
- The disposable copy has no usable Git remote and cleanup targets only the exact recorded path.
- A public HTTP canary succeeds in investigation mode.
- Provider keys and representative operator-secret canaries are absent from tool-child environment, command arguments, report, patch, and logs.
- Formal review still cannot use shell, write, edit, or network tools.
- Exit zero without the provider-specific terminal event fails.
- Timeout, cancellation, provider failure, and interrupted changed work produce truthful terminal metadata and recoverable incomplete artifacts.
- Exact named-session continuation is preserved; another session cannot be selected accidentally.
- Source/head and returned model identity are recorded where the provider exposes them; unavailable fields are labeled unavailable, never invented.
- Windows path case/8.3/Git-Bash translation cannot redirect creation or cleanup outside the managed root.
- Current installed binary/version and profile bytes match the repository pin after setup.

Focused suites:

- `C:\Program Files\Git\bin\bash.exe tests/test-ai-glm.sh`
- `C:\Program Files\Git\bin\bash.exe tests/test-ai-kimi.sh`
- `C:\Program Files\Git\bin\bash.exe tests/test-ai-qwen.sh`
- `C:\Program Files\Git\bin\bash.exe tests/test-ai-muse.sh`
- `C:\Program Files\Git\bin\bash.exe tests/test-muse-opencode-contract.sh`
- the existing sandbox, lifecycle, setup, version-pin, secret-scan, and skill-trigger tests named by each wrapper header and `docs/development.md`.
- final complete Bash suite through Git Bash and complete PowerShell suite through the repository's documented Windows runner path.

Live tests must use harmless content, a public non-authenticated HTTP endpoint, disposable records, and redacted output. They must never include secret values in prompts or commands.

## 11. Constraints, standing rules, and gotchas

- Work directly on `main`; no feature branches for this repository. Several sessions share the checkout, so inspect status before every pull/commit and stage only owned files.
- Do not reset, clean, force-push, overwrite, or broadly stage existing dirty work.
- This repository is public. Never commit raw transcripts, real `.env` files, licensed/private data, credentials, or sensitive live responses.
- Use 1Password vault `vibe_coding` through existing repository-owned secret references and serialized access. Never put secret values in prompts, command arguments, output, logs, reports, patches, or commits.
- A shell-capable reviewer may send anything it can read to the internet. Therefore its readable inputs must be the disposable repository copy plus deliberately supplied public/scrubbed evidence. Do not use investigation mode on licensed/private repositories until the caller confirms the included files are safe for that provider and internet-capable mode.
- Preserve capability: if a native upgrade breaks the requested model, session continuation, shell, internet, credential boundary, or completion proof, retain the prior qualified version and document the blocker; do not “fix” it by disabling investigation.
- Never substitute native auto-update or a floating `latest` pin.
- Investigation is advisory and cannot satisfy formal exact-head approval. Formal review remains read-only.
- Provider-specific completion evidence is mandatory; process exit alone is never sufficient.
- Keep time, turn/tool, and cost bounds. Do not retry indefinitely or turn unavailable usage into zero.
- Back up configuration before installer changes and validate byte-for-byte installed results.
- GPT-5.6 Codex work uses low or medium reasoning only.
- Do not run local reviewer suites while protected `windows-*` CI is active on the shared `EDGE-DEV` physical host.
- Any change to wrappers, evidence tools, safety tests, or installed routing rules needs an independent exact-head final review before landing.

## 12. Access and environment

- GitHub: authenticated `gh` access to `https://github.com/popcre/ai-devops`; parent #253 and child issues #254–#257 are the work ledger.
- Local repository: `C:\repos\ai-devops`, branch `main`; source of truth is the freshly fetched `origin/main`, not the planning SHA in this document.
- Windows shell: PowerShell for native setup/status; `C:\Program Files\Git\bin\bash.exe` for Bash scripts/tests.
- Ubuntu: use the configured ai-devops reviewer host and non-root `ai` user according to `templates/system/machine-atlas.md`. Do not guess host/user details.
- Provider authentication stays in existing locations: GLM and Muse API references, Qwen Coding Plan reference, and Kimi OAuth are managed through existing setup and 1Password vault `vibe_coding`. Read the affected wrapper/setup documentation for item titles; never copy values into this plan or issue comments.
- Candidate versions must come from official release pages and be pinned with their verified package/checksum identity.
- There is no hosted application deployment. “Deployment” here means commit/push to `origin/main`, installation on supported machines, and live provider qualification.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] Parent issue #253 has exactly the four intended child issues #254–#257 and every child is closed with current evidence.
- [ ] `ai-glm`, `ai-kimi`, `ai-qwen`, and `ai-muse` each expose a documented `investigate` mode with shell and public internet.
- [ ] Investigation runs only in a disposable remote-less copy and does not inherit operator credentials.
- [ ] Formal review remains structurally read-only and clearly distinct from advisory investigation.
- [ ] Exact qualified CLI/harness versions are pinned and restored consistently on Windows and Ubuntu.
- [ ] Focused, full offline, installation, hostile, and authenticated live tests pass with redacted artifacts.
- [ ] Independent exact-head final review passes after the final content change.
- [ ] Documentation, installers, version catalog, skills, plan STATUS, and handoff state match the shipped implementation.
- [ ] Git identity is verified; owned files alone are committed; final SHA is pushed and confirmed on `origin/main`.
- [ ] No hosted deployment is claimed; installed live qualification is recorded.

### Principal risks and mitigations

- **Credential exfiltration:** minimize readable environment and inputs; keep provider-key handoff private/self-deleting; hostile-test tool-child environment and arguments.
- **Concurrent work damage:** use the existing disposable-copy helper; never run capable mode in the live checkout.
- **False completion:** retain provider-specific terminal events, timeouts, and uncertain states.
- **Native version drift:** exact pins, contract fixtures, hostile tests, and authenticated live qualification before adoption.
- **Scope expansion into framework work:** enforce Option B and keep shared-core consolidation in issue #169.
- **Private repository leakage:** do not use internet-capable investigation on protected/licensed content without an explicit safe evidence packet; this plan adds no egress broker.
- **Shared OpenCode incompatibility:** GLM owns the upgrade and must prove Muse direct-mode compatibility before landing; Muse requalifies again in Step 4.

### Rollback

Each provider child must be independently revertible. Roll back the provider's exact commit and reinstall the previous pinned binary/configuration from `origin/main`. Preserve reports and incident evidence, but remove failed runtime configuration through the existing lifecycle scripts. Do not disable the other providers or delete unrelated sessions. If the OpenCode upgrade fails Muse after GLM lands, revert the shared pin/installer commit or forward-fix with a newly qualified pin before closing either affected child.

### Open questions

No owner decision is currently required. Implementation judgment is limited to the provider-local smallest code shape and whether each newly current stable release passes qualification. A failed candidate version does not block delivering investigation mode on the last qualified version.

## Mandatory plan self-audit

1. **Could a brand-new AI session execute this plan without asking a question? Yes.** Sections 1–4 define the business outcome, product, trigger, terminology, scope, and exclusions; Sections 5–8 carry exact current state, findings, rejected approaches, and locked/open decisions; Section 9 provides ordered file-level work and a verification gate for every step; Sections 10–13 provide tests, rules, access, landing, rollback, and closure.
2. **Does the plan carry every relevant background, nuance, and rejected approach? Yes.** Sections 3, 5, 6, 7, and 8 record the live version/discovery evidence, dirty/concurrent checkout warning, why Option B was chosen, why live-machine access/shared-core/egress-broker/latest/formal-mode conversion were rejected, and which minimum guarantees remain.
3. **Is the ultimate goal clear enough for correct judgment if a step is wrong? Yes.** Section 1 states the owner-visible outcome, the fewest-moving-parts rule, the minimum harm/credential boundary, the chosen Option B, and explicitly says the goal wins over a conflicting step.

Checklist result: **PASS**. All 13 sections are present; the plan is standalone; every step names targets, dependencies, and evidence gates; locked and open decisions are labeled; tests are behavioral and command-specific; identifiers and environments are defined; secrets are location-only; and completion includes commit, push, exact-head review, installation, live qualification, documentation, issue closure, and `origin/main` proof.
