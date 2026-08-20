# IMPLEMENTATION PLAN — Muse Spark 1.2 OpenCode harness on Windows and Ubuntu (2026-08-18)

Tracking issue: [u2giants/ai-devops#40](https://github.com/u2giants/ai-devops/issues/40)

Handoff for this plan: [`HANDOFF.d/2026-08-18T1929Z-al8960ofc-codex-muse-opencode-plan.md`](HANDOFF.d/2026-08-18T1929Z-al8960ofc-codex-muse-opencode-plan.md)

Official compatibility evidence:

- [Meta Model API cookbook](https://github.com/meta-models/meta-model-cookbook), which states that Meta Model API is compatible with OpenCode and includes an OpenCode repository-agent recipe.
- [OpenCode provider documentation](https://opencode.ai/v2/docs/providers), which defines the supported OpenAI-compatible provider configuration used by Meta Model API.

## STATUS

Read this table first. Do not re-plan completed work. Whoever executes a step must update this table and §5 in the same commit, citing a file or exact command that lets the next session reproduce the result.

| # | Step | Status | Evidence required before marking done |
|---|---|---|---|
| 1 | Freeze the Meta API, model, pricing/privacy, and OpenCode contracts | ✅ complete | [`docs/verification/muse-opencode/2026-08-18T2020Z-contract/README.md`](docs/verification/muse-opencode/2026-08-18T2020Z-contract/README.md), [`tests/fixtures/muse-opencode/contract-2026-08-18.json`](tests/fixtures/muse-opencode/contract-2026-08-18.json), and `bash tests/test-muse-opencode-contract.sh` |
| 2 | Extract a provider-neutral server core | superseded | Direct exact-session resume gives persistence without the server path that failed Meta authorization; GLM remains unchanged |
| 3 | Add the pinned Muse provider configuration and safety profile | ✅ complete | `tests/test-ai-muse.sh` validates the exact Contributor model, key reference, and removed dangerous tools |
| 4 | Build persistent `ai-muse new` / `ask` lifecycle | partial for persistent-debate scope | Named lifecycle, exact resume, recovery state, locking, reports, and delete pass. The original plan's broader timeout and live-provider failure matrix remains open. |
| 5 | Add Ubuntu service management | superseded | Direct persistence needs no service; Ubuntu uses the same installed command and separate OpenCode state |
| 6 | Add Windows service management | superseded | Direct persistence needs no task or port; Windows uses the same installed command and separate OpenCode state |
| 7 | Integrate packets, command catalog, and shared skill | partial for persistent-debate scope | Persistent turns refresh the packet; machine catalog installs `ai-muse`; shared skill requires named continuation. Original preflight/scoreboard work remains open. |
| 8 | Complete permanent documentation and routing | partial for persistent-debate scope | Core docs and the shared skill describe persistence. Final release evidence remains open with Step 11. |
| 9 | Qualify persistent Windows behavior | partial for persistent-debate scope | A live `new` returned `FIRST-OK`; a separate `ask` on the same ID recalled `MUSE-WRAPPER-7731`; delete removed the session. The original implementation and broad failure matrix remain open. |
| 10 | Qualify live review and implementation behavior on Ubuntu | ⬜ open | Equivalent redacted Ubuntu qualification bundle and cross-platform comparison |
| 11 | Independent review, landing, installation, and issue close | ⬜ open | Exact-head review report, commit SHA on `origin/main`, installed checks on both operating systems, and closed issue #40 |

> **Revised owner decision, 2026-08-19:** Muse must support persistent named debates,
> not only one-off reviews. The working design keeps direct mode because server mode
> failed Meta authorization, but uses OpenCode's exact `run --session <id>` resume
> contract. A measured second process resumed the same session and recalled the first
> turn. This supplies the requested `new` then `ask` workflow without adding a second
> background service. The former direct one-off decision is superseded.
> This change delivers persistent protected review/debate only. The original plan's
> implementation command, preflight/scoreboard integration, Ubuntu qualification, and
> broad failure matrix remain open and must not be inferred from the completed rows.

**Fresh-session starting point:** Step 10. Step 11 cannot land or close the issue until every remaining mandatory gate is complete or the owner explicitly narrows it in a later decision.

**Natural context cuts:** after Steps 2, 6, and 10. At each cut, use the `fresh-session` skill, update this STATUS table and §5, then re-read every downstream phase before starting it.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert should be able to ask Muse Spark 1.2 for an independent code review or a safely isolated implementation from Claude or Codex on Windows and Ubuntu through one dependable command. Conversations must survive follow-up calls, reviews must be unable to change files, implementation work must occur only in a disposable copy with no GitHub connection, and every failure must be visible and recoverable.

The business outcome is a second economical OpenCode-backed model alongside GLM, without duplicating fragile safety code or making GLM less reliable. A response from the wrong Muse model, a silent fallback, an empty “success,” a stale-code review, an unexplained charge, or a model that can reach the real repository is a failed release.

**If any step below conflicts with this goal, the goal wins — stop and flag it.** Do not ship a partial harness merely because a basic Meta API call succeeds.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan’s public backup-and-restore toolkit for a multi-model AI coding workflow. It contains hand-written Bash commands, PowerShell setup scripts, prompt and documentation templates, shared Claude/Codex skills, and dependency-free tests. It is not a web application, database, container, or hosted service.

Relevant existing components on `main`:

- [`bin/ai-glm`](bin/ai-glm) provides persistent named GLM review sessions and one-shot isolated implementation jobs through a local OpenCode server.
- [`bin/setup-opencode-glm.sh`](bin/setup-opencode-glm.sh) and [`bin/setup-opencode-glm.ps1`](bin/setup-opencode-glm.ps1) install the pinned OpenCode build and manage its Ubuntu user service or Windows Scheduled Task.
- [`config/opencode/`](config/opencode/) pins the OpenCode version, GLM provider, and the only tool settings measured to enforce read-only review.
- [`bin/ai-review-sandbox`](bin/ai-review-sandbox) converts a linked Git worktree into a self-contained review directory. “Linked worktree” means a second Git checkout whose control files remain in the main checkout.
- [`bin/ai-review-packet`](bin/ai-review-packet) adds verified facts and the exact change for reviewers that have no command shell.
- [`bin/ai-review-preflight`](bin/ai-review-preflight) checks whether a provider is usable or quarantined before starting a paid review.
- [`bin/ai-review-scoreboard`](bin/ai-review-scoreboard) records provider outcomes without automatically selecting a provider.
- [`config/machine-tools.tsv`](config/machine-tools.tsv) is the source of truth for commands installed on Albert’s machines.

Repository: `https://github.com/u2giants/ai-devops`. Branch policy: commit directly to `main`; do not create a feature branch. Ubuntu’s canonical checkout is `/worksp/ai-devops`, with commands linked under `/usr/local/bin`. On Windows, machine setup installs launchers under `%USERPROFILE%\.local\bin`. There is no CI/CD service or web deployment. “Deployment” here means installing the toolkit on the target computers and proving the installed commands work.

Planning baseline: `origin/main` commit `9188144` on 2026-08-18. The implementing session must fetch and quote the current `origin/main` SHA before editing because other sessions regularly change this repository.

## 3. What triggered this work

Albert asked whether the OpenCode harness used for GLM 5.3 could also run Muse Spark 1.2, then asked whether OpenCode or Meta’s own Muse Code inside Windows Subsystem for Linux would be the more efficient and accessible route for Claude and Codex on Windows.

The conclusion was:

1. Meta officially supports Muse Spark through OpenCode and an OpenAI-compatible API.
2. OpenCode is the better everyday bridge for Claude and Codex because it already exposes dependable local sessions and structured results on both operating systems.
3. Meta’s native Muse Code may eventually perform better on very long autonomous jobs because Muse Spark 1.2 was trained with that harness, but Muse Code is not yet the supported bridge in this plan.
4. The current GLM implementation is provider-specific throughout. Simply changing its model name or pointing both products at one state directory would mix credentials, sessions, ports, reports, and recovery records.

No Muse code, configuration, credential, service, or test has been added yet. This file is the first implementation artifact.

## 4. Scope — in and out

### In scope

- A new user-facing command, `ai-muse`, with `new`, `ask`, `implement`, `list`, `show`, `transcript`, `diff`, `abort`, `delete`, `doctor`, and `server` commands matching `ai-glm` where the verified Meta/OpenCode contract permits.
- Persistent, named, read-only review conversations separated by repository, caller, and session name.
- One-shot implementation inside a disposable clone whose Git remote is removed before Muse receives tools.
- A separate Muse OpenCode service, configuration home, local state, port, password, logs, Ubuntu service, and Windows Scheduled Task.
- One pinned OpenCode binary version shared by installation code, but no shared live server or session database with GLM.
- A provider-neutral harness library used by both `ai-glm` and `ai-muse`, with compatibility tests proving that extracting it does not change GLM behavior.
- Meta Model API through its OpenAI-compatible endpoint, with the Contributor model `muse-spark-1.2-contributor` verified against Albert's authenticated account and pinned.
- API-key storage in 1Password vault `vibe_coding`, item title `Meta Model API`, field `api key`; the plan references the location only and never stores the value.
- Windows 11 and Ubuntu installation, diagnosis, crash recovery, offline tests, paid live qualification, documentation, and a shared Claude/Codex delegation skill.
- Review evidence packets, exact-head checking, linked-worktree snapshots, provider preflight, quarantine, scoreboard reporting, and redacted usage/cost evidence.

### NOT in this plan

- Installing, wrapping, or comparing Meta Muse Code in WSL. That is a later experiment after `ai-muse` is qualified.
- Replacing `ai-glm`, changing its public command syntax, changing its qualified model, or merging GLM and Muse into one live service.
- Automatic provider selection, automatic fallback to another model, or replacing Grok, Kimi, Qwen, Gemini, Codex, or Opus.
- The standard Muse Spark 1.2 service tier. Albert explicitly stated on 2026-08-18 that he is only interested in Contributor.
- A model override on individual calls. The exact model is pinned in repository-owned configuration and verified at runtime.
- Direct Meta API calls outside OpenCode after the contract-probe step.
- Browser automation, Windows-to-WSL control, database work, shared cloud changes, production deployment, or user-interface work.
- Weakening review permissions, enabling a command shell for review, giving implementation a Git remote, following symlinks outside a disposable directory, or treating an after-the-fact diff check as the only protection.
- Editing or retiring another session’s handoff, plan, untracked file, or review artifact.

## 5. Current state of the code

### Already present and working

- `bin/ai-glm` currently pins provider `zai-coding-plan`, model `glm-5.3`, state directory `~/.local/state/ai-devops/glm`, and default port `4096` near [`bin/ai-glm:54`](bin/ai-glm#L54). These values must become a locked GLM profile, not generic defaults that Muse can override per call.
- GLM review safety is enforced by the agent `tools:` map in [`config/opencode/agent/glm-review.md`](config/opencode/agent/glm-review.md), not by OpenCode’s permission map. This was measured against OpenCode 1.18.12.
- GLM implementation runs in a no-hardlinks disposable clone and removes `origin`; [`tests/test-ai-glm.sh:56`](tests/test-ai-glm.sh#L56) guards both controls.
- Completion requires `finish == "stop"` and two consecutive idle polls. A missing active-session status alone is not completion.
- `ai-glm` already uses `ai-review-sandbox` and `ai-review-packet` before both new and resumed reviews; the corresponding regression checks begin near [`tests/test-ai-glm.sh:192`](tests/test-ai-glm.sh#L192).
- Ubuntu setup creates a loopback-only OpenCode user service. Windows setup creates a log-writing recovery wrapper and Scheduled Task that an ordinary user can repair.
- `tests/test-ai-glm.sh` contains extensive offline lifecycle, permission, recovery, long-path, and incomplete-artifact tests, with optional paid live tests behind `AI_GLM_LIVE=1`.
- `tests/test-windows-scripts.sh` enforces ASCII-only PowerShell and the measured Windows service rules.

### Open work nearby that must not be silently absorbed

- [`plan_reviewer-system-repair.md`](plan_reviewer-system-repair.md) still owns broader reviewer-system work. Its current STATUS and DRIFT blocks must be read before changing review packets, preflight, or scoreboard.
- [`plan_ai-gemini-wrapper.md`](plan_ai-gemini-wrapper.md) owns the separate Gemini reviewer. Muse must integrate with shared helpers without taking over that plan or its Google-specific decisions.
- Existing files under `HANDOFF.d/` belong to other workstreams. Their presence is not permission to edit them.

### Not present

- No `ai-muse` command, Muse configuration directory, setup script, system service, Windows task, skill, command-catalog row, preflight entry, or scoreboard normalization exists yet.
- Step 1 proved the account offers and returns `muse-spark-1.2-contributor`, supports streaming, tool calling, and multi-turn continuity, and returns structured 401/404 errors. It also proved pinned OpenCode 1.18.12 can use the Meta API through its legacy compatible-provider format. See `docs/verification/muse-opencode/2026-08-18T2020Z-contract/README.md`.
- Cache accounting was not returned by the tested usage responses; rate limits and cancellation were intentionally not induced. Later code must report these as unavailable or incomplete rather than inventing a success, usage, or cost value.

### Git and release state

Step 1 implementation began from `origin/main` commit `f25c725765f779012c3fc6448b109de3e09a81a6` on 2026-08-18. Unrelated untracked paths remain outside this work. There is no CI service, hosted release, or deployed SHA for this repository.

## 6. Key findings and root cause

1. **Protocol compatibility is strong, behavioral compatibility is unproven.** Meta says its Model API works with OpenCode, and OpenCode documents custom OpenAI-compatible providers. That proves a supported connection path. It does not prove Muse’s tool behavior, cache fields, stop condition, permissions, or error shapes match GLM.
2. **The existing wrapper is safe but provider-bound.** `ai-glm` combines general OpenCode lifecycle code with GLM names, environment variables, messages, state paths, doctor checks, and recovery records. Copying it to `ai-muse` would create two large safety implementations that inevitably drift.
3. **One shared live server is the wrong economy.** It would couple two credentials, providers, service restarts, default models, session stores, logs, and outage domains. A broken Muse configuration could take down GLM. Separate services on separate ports preserve fault isolation.
4. **Two independent copies of OpenCode are unnecessary.** Both services can use the same pinned OpenCode installation while keeping configuration, state, cache, password, port, logs, and process lifecycle separate.
5. **The requested model must be verified, not silently substituted.** The required identifier is `muse-spark-1.2-contributor`, but Step 1 must prove it appears in Albert's authenticated catalog and works through OpenCode. Any standard-model fallback is a failure.
6. **Contributor data use is an accepted owner decision.** Contributor permits Meta to train on submitted prompts and completions. Albert explicitly accepted that tradeoff on 2026-08-18 by stating he is only interested in Contributor. The harness must disclose this in its docs and doctor output; it must not second-guess the decision or silently use the standard tier.
7. **Review safety remains tool removal.** In the qualified OpenCode version, the agent-file `tools:` map is the only measured enforcement. Muse review must have no bash, write, edit, patch, web fetch, or sub-agent tool. A permission prompt is not a safety boundary.
8. **Implementation safety remains physical isolation.** A writable model needs a disposable clone with no remote. No provider permission response is trusted to prevent a push or an outside write.
9. **Linked worktrees require a self-contained snapshot.** Their `.git` file points outside the handed directory. Every review must call `ai-review-sandbox ensure`; widening the allowed folder is not supported.
10. **Windows and Ubuntu need equal proof, not assumed parity.** Windows has path, process, access-control, PowerShell encoding, and Scheduled Task behaviors that do not follow Ubuntu. Each platform has its own live qualification gate.
11. **A provider-neutral core is the root-cause fix.** Common lifecycle, locking, boundary, permission classification, completion, redaction, report, incomplete-patch, and cleanup logic belongs in one tested library. Provider-specific names and settings belong in small immutable profiles.

## 7. Approaches considered and REJECTED, and why

1. **Install Muse Code in WSL and drive it from Claude/Codex on Windows. Rejected for this plan.** It adds a Windows-to-Linux control layer and depends on Muse Code’s interactive terminal behavior. It may be worth a later quality comparison, but it is not the most dependable everyday bridge.
2. **Change the model in `ai-glm`. Rejected.** The command explicitly forbids model/provider overrides to preserve caching and safety. Reusing GLM’s identity would also mix sessions and reports.
3. **Run Muse and GLM in one OpenCode service. Rejected.** This saves one small local process but couples credentials, configuration, restarts, logs, and failures. The operational risk outweighs the small resource saving.
4. **Copy `bin/ai-glm` and search/replace GLM with Muse. Rejected.** The file contains the safety-critical job lifecycle. Two copies would diverge whenever one is repaired.
5. **Rewrite `ai-glm` from scratch into a generic framework in one step. Rejected.** A large unmeasured rewrite could silently weaken a working provider. The plan extracts behavior behind characterization tests and proves live GLM parity before Muse is allowed to depend on it.
6. **Trust OpenCode permission maps. Rejected by existing live evidence.** They allowed actions they claimed to deny. Only removed tools and the remote-less clone are treated as controls.
7. **Use a linked Git worktree directly. Rejected by a measured 2026-08-17 failure.** OpenCode received one directory and immediately encountered Git control data outside it. The wrapper must make a self-contained snapshot.
8. **Use the standard Muse Spark tier for privacy. Rejected by owner direction.** Albert stated on 2026-08-18 that he is only interested in Contributor. The accepted training terms must be disclosed, but they are not grounds to substitute the standard tier.
9. **Accept the provider’s default model. Rejected.** Provider defaults can change. Every session must use and verify one exact pinned model.
10. **Treat exit code, HTTP success, or any non-empty text as completion. Rejected.** The GLM history proves that transport success and a real completed answer are different facts. Muse must satisfy a measured strict completion rule.
11. **Store the Meta key in a file or OpenCode config. Permanently rejected.** The key belongs only in 1Password and the launched process environment. It must not appear in Git, logs, arguments, reports, or generated service files.

## 8. Design decisions already made, and their reasoning

### LOCKED decisions, 2026-08-18

- **Public interface:** `ai-muse`, not an option on `ai-glm`.
- **Harness:** OpenCode using Meta Model API’s OpenAI-compatible endpoint.
- **Isolation:** Muse and GLM use separate live services, ports, configuration homes, state homes, credentials, passwords, logs, and service names.
- **Shared implementation:** provider-neutral safety and lifecycle code is extracted once and used by both thin commands. GLM’s public behavior must remain byte-for-byte compatible where output is part of tests.
- **OpenCode version:** start with the repository’s qualified pin in `config/opencode/version`. Do not upgrade OpenCode as part of adding Muse unless Step 1 proves Meta requires it; if it does, stop and write a separate upgrade plan with full GLM requalification.
- **Default port:** reserve `127.0.0.1:4097` for Muse, configurable through `AI_MUSE_PORT`; GLM keeps `4096`.
- **Model:** require `muse-spark-1.2-contributor`, verify it against Albert's authenticated Meta catalog, and pin it. Never silently fall back to the standard tier or another model.
- **Privacy:** Contributor is the only permitted tier. Its provider-training terms are explicitly accepted by Albert as of 2026-08-18 and must be disclosed in permanent documentation and diagnostic output.
- **Review tools:** `read`, `list`, `glob`, `grep`, and the exact measured todo tool only. No shell, writing, patching, web access, or sub-agents.
- **Implementation tools:** enabled only inside a disposable clone. Remove its remote before creating the OpenCode session; preserve the existing artifact export and cleanup rules.
- **Review boundary:** always run `ai-review-sandbox ensure`, then build the additive evidence packet. The reviewer retains read/search access to the entire safe snapshot.
- **No per-call model/provider/agent/directory overrides:** stable profiles protect safety and caching.
- **Failure policy:** wrong model, missing answer, unknown permission, stale head, rate limit, timeout, malformed response, failed artifact export, or ambiguous cleanup is a loud nonzero failure.
- **Secrets:** 1Password vault `vibe_coding`, item `Meta Model API`, field `api key`. Resolve serially and verify non-empty without printing it.
- **Service names:** Ubuntu `opencode-muse.service`; Windows `AiDevOps-OpenCodeMuse`; launcher `opencode-muse-launch`; log `opencode-muse/server.log`.
- **No fallback:** `ai-muse` never calls GLM or another provider when Meta fails.

### OPEN implementation judgments

- **Exact Meta provider and model identifiers:** choose only from the authenticated Step 1 evidence. Expected endpoint is `https://api.meta.ai/v1`, but record and obey current official documentation.
- **Common-core file layout:** prefer `bin/lib/ai-opencode-harness.sh` plus small profile files if Bash sourcing remains testable on Git Bash and Ubuntu. A different layout is acceptable only if it still yields one safety implementation and thin provider entry points.
- **Usage and cache reporting:** expose only fields actually returned by Meta through OpenCode. Label unavailable values as unavailable, never zero.
- **Rate-limit handling:** retries are allowed only when Meta’s response proves the request was not accepted or supplies a safe retry instruction. Never replay an ambiguously delivered paid turn.
- **Meta item creation:** if `Meta Model API` does not exist in `vibe_coding`, create it using the `secrets-to-1password` skill with rich notes. If Albert has not yet generated the API key, stop at the access gate in §12 rather than inventing one.

## 9. The plan — numbered, ordered, executable steps

### Phase A — freeze contracts and protect GLM

#### Step 1 — Freeze the Meta API, model, privacy, cost, and OpenCode contracts

**Change:**

- Create `docs/muse-opencode.md` with the official endpoint, authentication variable, available Muse Spark 1.2 model IDs, data-use terms, current prices and limits, tool support, context/output limits, and the exact date each fact was checked.
- Add a redacted probe script under `tests/probes/muse-opencode-contract.sh`; it must never print headers, keys, or full provider error bodies.
- Save sanitized outputs under `docs/verification/muse-opencode/<UTC>-contract/README.md` and fixtures under `tests/fixtures/muse-opencode/`.
- Probe authenticated model listing, a minimal completion, streaming if OpenCode needs it, function/tool calling, multi-turn continuity, usage fields, cache fields, malformed authentication, invalid model, rate-limit shape, and provider cancellation.
- Verify OpenCode 1.18.12 can load the provider through `@opencode-ai/ai/providers/openai-compatible`. Do not start the permanent service yet.
- Prove `muse-spark-1.2-contributor` is separately selectable and that OpenCode sends that exact ID. Do not send repository content during this step.

**Dependencies:** none. This is the gate for all later work.

**Verification gate:** You’ll know it worked when the redacted report proves `muse-spark-1.2-contributor` is available and used exactly, documents every response shape the wrapper needs, the fixture test replays without network access, and no secret-shaped string appears in `git diff` or the saved artifacts. If Contributor is unavailable, tool calling is unsupported, or OpenCode 1.18.12 cannot use it, mark the plan blocked and stop. Never substitute the standard model.

#### Step 2 — Extract a provider-neutral OpenCode core without changing GLM behavior

**Change:**

- Add `bin/lib/ai-opencode-harness.sh` for shared HTTP calls, authentication, session identity, locks, review preparation, strict completion, permission classification, redaction, reports, implementation records, abort/delete, incomplete artifacts, exact cleanup, and dead-owner reconciliation.
- Convert `bin/ai-glm` into a thin GLM profile and command entry point. Preserve every public command, environment variable, state path, message, report name, and doctor result unless a test proves the old output was not contractual.
- Add `tests/test-ai-opencode-harness.sh` with characterization fixtures copied from observed GLM behavior rather than invented abstractions.
- Extend `tests/test-ai-glm.sh` to prove the GLM profile cannot be overridden by Muse variables and that provider records cannot cross state directories.
- Run the existing optional paid GLM tests and save a redacted before/after parity report under `docs/verification/muse-opencode/<UTC>-glm-parity/README.md`.

**Dependencies:** Step 1, so the abstraction includes only measured shared facts.

**Verification gate:** You’ll know it worked when `bash tests/test-ai-opencode-harness.sh`, `bash tests/test-ai-glm.sh`, `bash tests/test-ai-review-sandbox.sh`, `bash tests/test-ai-review-packet.sh`, and `bash tests/test-windows-scripts.sh` pass, the live GLM sequence `doctor → new → ask → transcript → delete → implement → show → delete` still passes, and `git diff` shows no weakened GLM control. Do not proceed to Muse if any GLM parity check fails.

**Natural context cut:** update STATUS and §5, then use `fresh-session` before Phase B.

### Phase B — build the isolated Muse product

#### Step 3 — Add the pinned Muse provider configuration and safety profiles

**Change:**

- Create `config/opencode-muse/opencode.json` with sharing and automatic updates disabled, `muse-spark-1.2-contributor` pinned, and a custom Meta provider using the official base URL and `MODEL_API_KEY` environment variable.
- Create `config/opencode-muse/agent/muse-review.md` and `muse-implement.md` based on the measured GLM tool controls, with Muse-specific wording and exact model pin.
- Use the shared `config/opencode/version` unless Step 1 triggered the separate upgrade stop condition.
- Add configuration validation to `tests/test-ai-muse.sh`: valid JSON, exact provider/base/model, no literal key, no default fallback, review tools removed, implementation tools present only in its profile, sharing disabled, auto-update disabled.

**Dependencies:** Steps 1 and 2.

**Verification gate:** You’ll know it worked when offline tests reject any model other than `muse-spark-1.2-contributor`, missing `MODEL_API_KEY`, enabled review write/bash/web tools, enabled sharing/update, or literal credential, and accept only the exact Contributor configuration.

#### Step 4 — Build `ai-muse` with the proven lifecycle

**Change:**

- Add `bin/ai-muse` as a thin Muse profile over the shared core.
- Use state root `~/.local/state/ai-devops/muse`, port variable `AI_MUSE_PORT` defaulting to `4097`, caller variable `AI_MUSE_CALLER`, timeout `AI_MUSE_TIMEOUT`, and lock timeout `AI_MUSE_LOCK_TIMEOUT`.
- Preserve the `ai-glm` command meanings. User-visible messages must say Muse, name the exact recovery command, and never expose raw provider bodies.
- Store review reports as `.ai/reviews/muse-<name>-<UTC>.md` and implementation patches with a Muse prefix.
- Keep implementation job records private and free of prompt or credential content.
- Add exact model/provider checks to `doctor` and to session creation. A server that exposes another model is unhealthy even if the health endpoint answers.
- Add Muse-specific failure codes only where Step 1 proves a distinct provider response. Do not weaken the common classifier.

**Dependencies:** Step 3.

**Verification gate:** You’ll know it worked when `tests/test-ai-muse.sh` covers empty and malformed input, session separation by repo/caller/name, locks, server-down messages, wrong-model rejection, permissions, completion, timeouts, abort races, terminal records, partial artifacts, redaction, dead-owner reconciliation, linked worktrees, Windows long paths, and exact cleanup, with zero failures.

#### Step 5 — Add safe Ubuntu installation and service management

**Change:**

- Add `bin/setup-opencode-muse.sh`, reusing the pinned OpenCode installation but installing separate Muse configuration and runtime paths.
- Add `config/systemd/opencode-muse.service`, bound only to `127.0.0.1:4097` by default.
- Generate `~/.local/bin/opencode-muse-launch`. It must resolve `MODEL_API_KEY` from the one `mcp.env` environment through one serialized `op run`, guard an empty result and re-execution loop, then unset the generic source variable if the provider package expects another alias.
- Extend `install.sh`, `bin/setup-secrets.sh`, and machine verification so ordinary-user installation creates or repairs Muse without affecting GLM.
- Ensure service password, configuration, logs, data, state, and cache use Muse-specific paths.
- Add setup idempotence, rollback, loopback, authentication, permission-mode, no-secret, service-enabled, service-active, version, provider, and model doctor tests.

**Dependencies:** Step 4 and an existing 1Password item/key.

**Verification gate:** You’ll know it worked when two consecutive `bin/setup-opencode-muse.sh` runs succeed as the ordinary Ubuntu service owner, `ai-muse doctor` passes, unauthenticated health returns 401, nothing listens beyond loopback, GLM remains healthy on port 4096, and no secret appears in process arguments, unit files, logs, or Git.

#### Step 6 — Add safe Windows installation and service management

**Change:**

- Add ASCII-only `bin/setup-opencode-muse.ps1`, deriving the checkout from `$PSCommandPath` and user storage from `%USERPROFILE%`.
- Install `ai-muse.cmd`, `opencode-muse-launch`, and `opencode-muse-service` under `%USERPROFILE%\.local\bin`.
- Register `AiDevOps-OpenCodeMuse` at user logon, with the same measured user-owned access rules, bounded four-attempt wrapper, one-minute retry delay, 1 MiB log rotation, port-free wait, smoke test, and loopback ownership check used by the qualified GLM setup.
- Extend `bin/setup-machine.ps1`, `bin/verify-windows-dev.ps1`, and `tests/test-windows-scripts.sh` without changing Claude configuration or Codex configuration directly.
- Prove a normal, non-elevated PowerShell user can repair and restart the task. Do not use SSH as evidence because Windows SSH sessions are elevated on these machines.

**Dependencies:** Step 5’s file layout and Step 4’s command.

**Verification gate:** You’ll know it worked when two non-elevated setup runs succeed on `al8960ofc`, Task Scheduler shows the correct user-owned definition, `ai-muse doctor` prints every check and passes, the service survives a controlled child-process failure within its bounded policy, GLM stays healthy, PowerShell files pass the ASCII test, and no secret appears in launchers, logs, task arguments, or Git.

**Natural context cut:** update STATUS and §5, then use `fresh-session` before Phase C.

### Phase C — integrate, document, and qualify

#### Step 7 — Integrate shared reviewer services and add the delegation skill

**Change:**

- Add `ai-muse` and its setup dependencies to `config/machine-tools.tsv` and every installer/doctor path that uses that catalog.
- Add Muse to `bin/ai-review-preflight` and `bin/ai-review-scoreboard`, preserving their fail-closed and no-auto-selection rules.
- Add `skills/shared/ask-muse/SKILL.md` for both Claude and Codex. It must require the wrapper, preserve caller identity, continue named sessions instead of restarting, forbid direct OpenCode/API calls, and distinguish review from explicit implementation authorization.
- Add skill routing to `docs/skills-map.md`, `docs/skills-usage-guide.md`, `docs/codex-skills-usage-guide.md`, and trigger fixtures/evaluations.
- Run `bin/ai-install-skills` through its preview-first path. Never hand-copy the installed skill.

**Dependencies:** Steps 4 through 6.

**Verification gate:** You’ll know it worked when helper tests recognize Muse, a quarantined or unavailable Muse is rejected before a paid call, scoreboard records but does not select it, skill trigger evaluation passes the repository’s threshold, installed Claude and Codex skill copies match the source, and no other provider’s behavior changes.

#### Step 8 — Complete permanent documentation and restore routing

**Change:**

- Complete `docs/muse-opencode.md` with architecture, commands, Windows and Ubuntu setup, secret location, privacy tier, costs/rate limits, operations, diagnosis, rollback, upgrade, and known limitations.
- Update `AGENTS.md`, `README.md`, `docs/architecture.md`, `docs/configuration.md`, `docs/model-setup.md`, `docs/config-inventory.md`, `docs/deployment.md`, `docs/restore-from-zero.md`, and `templates/system/machine-atlas.md` only where Muse creates durable facts.
- Add a “hard-won constraints” section to the Muse doc, initially inheriting shared OpenCode facts by link and recording only Muse-specific measured differences. Do not duplicate the entire GLM history.
- Update `memory/ai-devops/muse-opencode-plan.md` to point at the completed topic doc and keep the instruction to read this plan’s STATUS first until issue #40 closes.

**Dependencies:** Steps 1 through 7, so documentation describes measured behavior.

**Verification gate:** You’ll know it worked when every named link resolves, a fresh reader can install and diagnose both platforms from the docs alone, no documentation claims an unmeasured cache/cost/permission behavior, and `rg` finds no stale statement that GLM is the only OpenCode provider.

#### Step 9 — Qualify live Windows behavior

**Change/test:**

- On `al8960ofc`, from ordinary PowerShell, run a sanitized live matrix covering `doctor`, exact model proof, new/ask continuity, service restart continuity, transcript, delete, read-only canary, outside-directory denial, linked-worktree review, exact-head invalidation, malformed permission, timeout, abort, rate-limit response if safely reproducible, usage/cache fields, implementation create/edit/test, incomplete implementation export, successful patch export, and cleanup.
- Protect canary files inside and outside the safe review directory with hashes before and after. The review must not alter either.
- Prove implementation changes only the disposable clone and exported patch; it must not change the source repository or have a remote.
- Save redacted evidence under `docs/verification/muse-opencode/<UTC>-windows/README.md`. Record commands, versions, model, timings, tokens, cache reads/writes if returned, and cost calculation from official pricing. Use “unavailable,” never zero, for missing provider fields.

**Dependencies:** Steps 1 through 8.

**Verification gate:** You’ll know it worked when every required case has observable evidence, all protected hashes match, exact model proof names `muse-spark-1.2-contributor`, continuity survives restart, failed/incomplete work stays nonzero and clearly labeled, successful implementation exports a reviewable patch, cleanup leaves no unexplained clone/session, and GLM still passes doctor.

#### Step 10 — Qualify live Ubuntu behavior and compare platforms

**Change/test:**

- Repeat the Step 9 matrix on the normal Ubuntu service owner at the canonical `/worksp/ai-devops` installation.
- Save equivalent evidence under `docs/verification/muse-opencode/<UTC>-ubuntu/README.md`.
- Add `docs/verification/muse-opencode/cross-platform-summary.md` comparing versions, behavior, time, tokens, cache, cost, failures, and any platform-only limitation.
- If behavior differs, encode the difference in tests and diagnosis. Do not describe unexplained divergence as acceptable parity.

**Dependencies:** Step 9, so both platforms use the same frozen matrix.

**Verification gate:** You’ll know it worked when Ubuntu passes the same release gates, the comparison cites both evidence bundles, any difference has a documented reason and guard, both Muse services are loopback-only and authenticated, and GLM remains healthy on both platforms.

**Natural context cut:** update STATUS and §5, then use `fresh-session` before landing.

### Phase D — independent review and landing

#### Step 11 — Review, land, install, and close

**Change/action:**

- Run the complete test set in §10 in the background with incremental logs.
- Run an independent read-only review against the exact final head using an already-qualified provider other than Muse. Require review of the shared-core extraction, permissions, clone ownership, secret handling, Windows task, Ubuntu service, cleanup, and rollback.
- Address every actionable finding and rerun affected tests plus the full suite.
- Update this STATUS table and §5 with artifact-backed evidence.
- Verify `git var GIT_COMMITTER_IDENT` is `Albert Hazan <u2giants@users.noreply.github.com>`.
- Stage only files owned by issue #40. Commit directly to `main`, pull/reconcile concurrent changes safely, push, and prove the commit is on `origin/main`.
- Run the installed `ai-glm doctor` and `ai-muse doctor` on Windows and Ubuntu after the final push.
- Close issue #40 only after both installations pass. Then retire this session’s handoff under the successor rule; keep or delete the plan according to the repository’s normal completed-plan convention and preserve its history in Git.

**Dependencies:** all prior steps.

**Verification gate:** You’ll know it worked when all tests pass, the independent exact-head review has no unresolved finding, the final SHA is on `origin/main`, installed GLM and Muse doctors pass on both operating systems, the two live services remain separate, issue #40 is closed with evidence links, and no mystery untracked or temporary files from this work remain.

## 10. Tests required

### New offline tests

- `tests/test-ai-opencode-harness.sh`
  - profile fields are complete and immutable;
  - provider state/locks/sessions cannot cross profiles;
  - shared permission, completion, redaction, report, abort, cleanup, and recovery logic matches existing GLM characterization fixtures;
  - unknown profile/action/response fails closed;
  - no secret-shaped value is persisted or printed.
- `tests/test-ai-muse.sh`
  - syntax, help, invalid options, empty prompts, bad names, non-Git paths;
  - exact provider/model/base URL and Contributor-only pin;
  - review agent lacks bash/write/edit/patch/web/sub-agent tools;
  - implementation clone has no remote and uses Windows long-path support;
  - new/ask/list/show/transcript/diff/abort/delete behavior;
  - repository/caller/name separation and lock collisions;
  - strict completion and idle polling;
  - permission transport retries only for local polls;
  - malformed/unknown/outside permission rejection with sanitized durable detail;
  - timeout, abort race, rate limit, provider failure, incomplete patch, export failure, dead owner, forged record, and exact cleanup;
  - linked-worktree snapshot and evidence packet on both new and resumed review;
  - wrong server/model/provider and unauthenticated health fail loudly;
  - `doctor` reports every failure and names the exact next command.
- `tests/test-windows-scripts.sh`
  - Muse PowerShell files are ASCII-only;
  - `%USERPROFILE%`, absolute Git Bash, correct escaping, port-free wait, smoke test, user-owned task access, bounded recovery, log rotation, real ACL checks, and platform-real secret checks.
- Extend `tests/test-ai-review-preflight.sh`, `tests/test-ai-review-scoreboard.sh`, `tests/test-ai-review-sandbox.sh`, `tests/test-ai-review-packet.sh`, `tests/test-machine-tools.sh` if present, installer tests, and skill trigger tests for Muse.

### Existing regression suites that must remain green

Run from repository root in Git Bash unless the filename is `.ps1`:

```bash
bash tests/test-ai-opencode-harness.sh
bash tests/test-ai-muse.sh
bash tests/test-ai-glm.sh
bash tests/test-ai-review-sandbox.sh
bash tests/test-ai-review-packet.sh
bash tests/test-ai-review-preflight.sh
bash tests/test-ai-review-scoreboard.sh
bash tests/test-windows-scripts.sh
bash tests/test-install.sh
```

Discover the repository’s current full suite from `docs/development.md` at execution time and run it in the background. Do not assume this dated list remains complete.

### Paid live tests

Provide explicit opt-in flags, parallel to `AI_GLM_LIVE=1`, for example `AI_MUSE_LIVE=1`. Paid tests must be sequential, visibly label approximate cost before starting, save redacted evidence, and stop on an unexpected model, privacy tier, or authentication target. Do not replay an ambiguous request.

## 11. Constraints, standing rules, and gotchas in force

- Work on `main` in `u2giants/ai-devops`. State the repo and branch before push.
- Several sessions share this checkout. Never use `git add -A`; stage only owned files/hunks. Preserve `.ai/`, `docs/claude-remote-control-hardening-v2.md`, and all unrelated changes.
- Before the first commit, `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- Read `docs/glm-opencode.md` §5 in full before every phase that changes shared OpenCode behavior. Its 33 measured constraints remain in force.
- Read the current STATUS and DRIFT blocks of `plan_reviewer-system-repair.md` before changing packets, preflight, scoreboard, or reviewer selection.
- Never point a reviewer at a raw linked worktree. Call `ai-review-sandbox ensure`.
- Only the agent `tools:` map is a measured OpenCode review control. Permission maps are not trusted.
- Implementation uses a disposable clone with its remote removed, never a worktree.
- Do not edit a Bash script while a copy of it is running.
- The installed Ubuntu command may be a link into the main checkout. Verify which file is actually running before live tests.
- PowerShell files must remain pure ASCII. Derive paths from `$PSCommandPath` and `%USERPROFILE%`; do not hard-code Albert’s current drive or username.
- Windows SSH sessions are elevated and cannot prove ordinary-user repair.
- One OpenCode version is shared, but GLM and Muse live services and state are separate. A Muse setup run must not restart or rewrite GLM.
- No silent fallback, no hard-coded model scattered across files, no empty success, no unbounded retry, and no paid retry after ambiguous delivery.
- All 1Password access is serialized. Never print or commit a secret, and never rotate a key without Albert’s approval.
- Use the `secrets-to-1password` skill for any creation or update of the `Meta Model API` item.
- Reviews are read-only. Implementation is allowed only when the calling user explicitly asks for implementation.
- Production/shared cloud is read-only. This plan requires no database, Terraform, gcloud mutation, NAS action, or deployment platform.
- No UI exists, so visual verification is N/A.

## 12. Access and environment

### Repository and tools

- Repository: `C:\repos\ai-devops` on Windows; `/worksp/ai-devops` on Ubuntu.
- Remote: `https://github.com/u2giants/ai-devops`.
- Branch: `main`.
- `gh`, Git, Git Bash, PowerShell 7, Node.js, `jq`, `curl`, OpenCode, and `op` are part of the existing setup. Verify each with a real call before claiming it is missing.
- On Windows, run Bash tests through Git Bash, not bare `bash` from PowerShell when injected environment variables are required. Bare `bash` is WSL and drops the Windows process environment.
- On Ubuntu, run services as the normal user that owns the existing OpenCode GLM service, not root.

### Required credential

- Vault: `vibe_coding` on `popcreations.1password.com`.
- Item title: `Meta Model API`.
- Field: `api key`.
- Environment name expected by Meta: `MODEL_API_KEY`, subject to Step 1 official verification.
- Never place the value in this plan, Git, OpenCode JSON, service files, task arguments, logs, or reports.

If the item or key does not exist, the implementing session must ask Albert once for access to Meta Model API and permission to store the resulting key, then use the `secrets-to-1password` skill. A correct access result is an authenticated, redacted model-list response containing `muse-spark-1.2-contributor`. Do not ask Albert to run shell commands if browser access can be granted to the session instead.

### Local service identities

- GLM remains `127.0.0.1:4096`, Ubuntu unit `opencode-glm.service`, Windows task `AiDevOps-OpenCodeGlm`.
- Muse uses `127.0.0.1:4097`, Ubuntu unit `opencode-muse.service`, Windows task `AiDevOps-OpenCodeMuse`.
- Both require HTTP Basic authentication and reject unauthenticated health checks with 401.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] All 11 STATUS rows are marked done with reproducible artifacts.
- [ ] One provider-neutral OpenCode core serves thin `ai-glm` and `ai-muse` profiles without changing GLM’s public behavior.
- [ ] `ai-muse` supports the full approved command lifecycle on Windows and Ubuntu.
- [ ] `muse-spark-1.2-contributor` is pinned and verified; no standard-model fallback exists.
- [ ] Review is proven unable to write inside or outside its safe directory.
- [ ] Implementation is proven confined to a remote-less disposable clone and exports truthful complete/incomplete artifacts.
- [ ] Linked worktrees, evidence packets, exact-head checks, preflight, quarantine, scoreboard, and the shared skill are integrated.
- [ ] Offline suites and paid live matrices pass on both operating systems.
- [ ] GLM remains healthy and passes its full regression/live parity checks.
- [ ] Docs cover setup, use, cost/privacy, diagnosis, upgrade, restore, and rollback.
- [ ] Independent exact-head review has no unresolved actionable finding.
- [ ] Commit identity is correct; owned changes are committed to `main`, pushed, and proven on `origin/main`.
- [ ] Installed Windows and Ubuntu commands pass `ai-glm doctor` and `ai-muse doctor` after the final push.
- [ ] Issue #40 is closed with evidence; the linked handoff is retired only when successor conditions are met.
- [ ] No secret, temporary clone, live probe, mystery untracked file, or unrelated change from this work remains.

### Main risks and controls

- **Shared-core regression:** extracting code could weaken GLM. Control: characterization tests and paid live parity before Muse work continues.
- **Provider behavior differs from GLM:** control: Step 1 fixtures and provider-specific adapters that cannot relax common safety.
- **Meta changes the catalog/default:** control: exact model pin and runtime doctor/session checks.
- **Wrong-tier mistake:** control: authenticated catalog evidence, Contributor-only tests, explicit standard-tier rejection, and visible disclosure of Contributor training terms.
- **Duplicate services collide:** control: separate paths, ports, task/unit names, doctor ownership checks, and tests that both run simultaneously.
- **Windows task becomes unrepairable:** control: ordinary-user live test and explicit task access inspection.
- **Paid request is replayed:** control: retry only local polls or provider-declared undelivered/rate-limited requests.
- **Incomplete work looks successful:** control: strict completion plus complete/incomplete artifact labeling and nonzero exit.
- **Documentation drifts:** control: router/topic/skill/memory links and plan STATUS updates in every executing session.

### Rollback

1. Stop only the Muse service/task: `ai-muse server stop`.
2. Export any needed Muse transcript or patch first.
3. Remove only Muse-owned installed launchers, task/unit, config, and state through the implemented uninstall path. Never delete GLM paths.
4. Revert the Muse landing commit on `main`. If the shared-core extraction must be reverted, use the pre-extraction commit recorded by Step 2 and rerun the full GLM suite before reinstalling.
5. Re-run the normal installer and `ai-glm doctor` to prove GLM remains healthy.
6. Preserve ambiguous records or clones and report their exact paths; never guess-delete them.

### Genuine open questions and decision criteria

- **Is `muse-spark-1.2-contributor` enabled for Albert's account?** Step 1 answers from the authenticated Meta catalog and a minimal live call. If not, the work blocks; standard Muse is not an acceptable substitute.
- **Does Meta expose reliable cache accounting through OpenCode?** Report it only if a live repeated-prefix test returns stable cache fields. Otherwise mark unavailable.
- **Does Muse use the same permission/tool event shapes as GLM?** Reuse the common classifier only for identical measured shapes; add a narrow Muse adapter for differences and fail closed on unknowns.
- **Does OpenCode 1.18.12 fully support Meta’s current API?** If not, stop. Do not upgrade OpenCode inside this plan without a separate GLM requalification plan.
- **Is native Muse Code materially better?** Out of scope. After `ai-muse` is stable, a separate plan may compare five identical tasks on quality, time, cost, corrections, and recoverability.

## Mandatory self-audit

### Checklist result

- [x] All 13 required sections are present.
- [x] The ultimate goal is in plain business English and says the goal wins over a conflicting step.
- [x] A fresh session can execute without this chat: repository, architecture, files, commands, credentials, gates, stop conditions, and platform roles are defined.
- [x] Rejected approaches and failure mechanisms are preserved in §7.
- [x] Every numbered step names concrete files and has a verification gate.
- [x] Locked and open decisions are separated in §8.
- [x] Out-of-scope work is explicit in §4.
- [x] Tests are specified by file and behavior in §10.
- [x] Uncommon terms, paths, ports, services, accounts, and identifiers are defined or linked.
- [x] The secret is referenced only by vault/item/field, never by value.
- [x] Definition of done includes tests, independent review, commit, push, installed-machine verification, issue closure, and cleanup.
- [x] This plan and its new handoff link directly to each other; root `HANDOFF.md` remains untouched.

### Three required questions

1. **Could a brand-new AI session execute this perfectly without asking Albert anything that is already knowable?** Yes. §§2, 5, 9, 10, and 12 define the repository, current components, exact phased work, tests, platforms, commands, and credential location. The only possible access gap is explicitly handled in §12 with one precise request and a measurable success result.
2. **Does the plan carry all current background, nuance, reasoning, and rejected options?** Yes. §§3, 6, 7, and 8 preserve why OpenCode was selected over WSL Muse Code, why one server and copied wrappers were rejected, how GLM’s measured controls constrain the design, and which privacy tier is allowed.
3. **Is the goal clear enough to guide a correct judgment if a step is wrong?** Yes. §1 defines the business result and the unacceptable failure states; §13 provides stop conditions and rollback. An implementer can change a mistaken mechanical step while preserving isolation, exact-model proof, cross-platform access, truthful failure, and GLM reliability.

**Self-audit result:** PASS on 2026-08-18. No checklist gap remains.
