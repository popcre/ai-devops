# IMPLEMENTATION PLAN — safe `ai-gemini` reviewer wrapper (2026-08-18)

Tracking issue: [u2giants/ai-devops#38](https://github.com/u2giants/ai-devops/issues/38)

Measured investigation: [`docs/ai-gemini-wrapper-investigation.md`](docs/ai-gemini-wrapper-investigation.md)

Handoff for this plan: [`HANDOFF.d/2026-08-18T1808Z-edge-dev-codex-ai-gemini-wrapper-plan.md`](HANDOFF.d/2026-08-18T1808Z-edge-dev-codex-ai-gemini-wrapper-plan.md)

## STATUS

Read this table first. Do not re-derive or re-plan completed work. Whoever executes a step must update this table and the current-state section in the same commit.

| # | Step | Status | Evidence required before marking done |
|---|---|---|---|
| 1 | Freeze and measure the Antigravity CLI contract | ⬜ open | Versioned contract report under `docs/verification/ai-gemini/` plus passing contract fixtures in `tests/test-ai-gemini.sh` |
| 2 | Prove a real read-only boundary on Windows and Ubuntu | ⬜ open | Hostile-write canary reports under `docs/verification/ai-gemini/`; every forbidden target remains byte-identical |
| 3 | Build named, resumable `ai-gemini` review sessions | ⬜ open | `bin/ai-gemini`; offline wrapper suite passes |
| 4 | Integrate evidence packets, exact-head checks, preflight, quarantine, and scoreboard | ⬜ open | Updated wrapper/helper fixtures and passing helper suites |
| 5 | Install and diagnose Antigravity and `ai-gemini` consistently on Windows and Ubuntu | ⬜ open | Installer/doctor tests plus redacted installed-machine doctor output |
| 6 | Add the shared Gemini delegation skill | ⬜ open | Trigger evaluation artifact and installed-skill verification |
| 7 | Update permanent documentation and routing | ⬜ open | Router, architecture, setup, configuration, deployment, and README links all resolve |
| 8 | Complete the offline failure and regression suite | ⬜ open | Exact test commands in §10 pass with zero failures |
| 9 | Run paid live qualification on Windows and Ubuntu | ⬜ open | Redacted live reports proving model, resume, read-only, quota, completion, and linked-worktree behavior |
| 10 | Independent review, landing, installation, and issue close | ⬜ open | Exact-head review report, commit SHA on `origin/main`, installed proof, and closed issue #38 |

**Fresh-session starting point:** Step 1.

**Natural context cuts:** after Steps 2, 5, and 9. At each cut, use the `fresh-session` skill, update this STATUS table, and re-read every downstream step before continuing.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert should be able to ask Gemini 3.7 Flash High for an independent code review through one dependable command, just as he can ask Grok, Kimi, or GLM today. The review must examine the exact code change, return a clear decision, preserve a named conversation for follow-up questions, show which model and allowance were used, and never be able to change the real repository or anything else on the computer.

The business outcome is one more economical, fast reviewer in the stable without weakening the safeguards that make an independent review trustworthy. A response from the wrong model, an empty “success,” a review of stale code, or a reviewer that could write files is a failure, never a degraded success.

**If any step below conflicts with this goal, the goal wins — stop and flag it.** In particular, do not ship a partial wrapper merely because model calls work. Read-only protection, exact-model proof, exact-code binding, and loud failure are release gates.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan’s public backup-and-restore toolkit for a multi-model AI coding workflow. It contains hand-written Bash commands, PowerShell setup scripts, prompt and documentation templates, shared Claude/Codex skills, and dependency-free tests. It is not a web application, database, container, or hosted service.

Relevant existing components on `main`:

- [`bin/ai-grok-review`](bin/ai-grok-review) drives xAI Grok through named, resumable, read-only review sessions.
- [`bin/ai-kimi`](bin/ai-kimi) drives Kimi through named review and implementation sessions. Only its review-side patterns apply here.
- [`bin/ai-glm`](bin/ai-glm) drives GLM through a loopback OpenCode server. Gemini must not copy that server architecture because Antigravity already supplies an official local command.
- [`bin/ai-review-sandbox`](bin/ai-review-sandbox) turns a linked Git worktree into one self-contained review directory. A reviewer accepts one directory only.
- [`bin/ai-review-packet`](bin/ai-review-packet) adds a verified `.ai-review/` evidence packet containing the exact diff and facts a shell-less reviewer cannot derive safely.
- [`bin/ai-review-preflight`](bin/ai-review-preflight) detects unavailable/quarantined providers before a long review begins.
- [`bin/ai-review-scoreboard`](bin/ai-review-scoreboard) records results without automatically selecting a provider.
- [`config/machine-tools.tsv`](config/machine-tools.tsv) is the source of truth for machine-installed reviewer commands.

Repository: `https://github.com/u2giants/ai-devops`. Branch policy: `main` only, no feature branch. Ubuntu installs live at `/worksp/ai-devops` with command links under `/usr/local/bin`; Windows setup installs launchers under `%USERPROFILE%\.local\bin`. There is no CI/CD or hosted deployment. “Deployment” means installing the toolkit on Albert’s machines and verifying the installed command.

The plan was written from clean `origin/main` commit `dd2e3a547a88bb985e0f23f17606a0e3cb64b365`. The implementing session must fetch and quote the then-current `origin/main` SHA before editing.

## 3. What triggered this work

On 2026-08-18 Albert asked whether Gemini 3.7 Flash could join the independent-reviewer stable and whether it could use Google’s subscription allowance. Google had retired consumer access through the old Gemini CLI and moved personal-account terminal use to Antigravity CLI.

Albert installed Antigravity CLI 1.1.14 on Windows machine `edge-dev` and authenticated it with Google OAuth. A live spike then established:

1. `agy models` listed `gemini-3.7-flash-high`, `-medium`, and `-low`.
2. A High request returned the exact marker `GEMINI_37_FLASH_TEST_OK` with JSON status `SUCCESS`, a conversation ID, duration, turn count, and token use.
3. Resuming that conversation by exact ID recalled the marker correctly.
4. `/model` returned structured data naming `gemini-3.7-flash-high`, label `Gemini 3.7 Flash (High)`, effort `high`, and `is_default:false` without consuming tokens.
5. `/usage` returned structured five-hour and weekly allowance buckets. After the spike both Gemini buckets showed approximately 98% remaining. This is cost-weighted allowance, not a fixed request count.
6. A one-line response consumed 15,438 total tokens; the resumed conversation reported 32,018 total tokens. Antigravity carries substantial hidden context, so usage must be measured rather than inferred from prompt size.
7. Headless mode auto-denied an unapproved terminal command and did not create the requested file in the test workspace, but it returned `status:"SUCCESS"` with an empty response. Therefore exit code and success status alone are not completion.
8. A native file-write instruction succeeded in Antigravity’s private scratch directory even though the real test workspace remained unchanged. The test artifact was verified and deleted. Therefore `--mode plan` is not a security boundary.
9. Google documents that project workspaces are auto-allowed for both reading and writing unless explicit permission rules override that default, and that Antigravity terminal sandboxing is still unavailable on Windows.

The durable spike record is [`docs/ai-gemini-wrapper-investigation.md`](docs/ai-gemini-wrapper-investigation.md). Reproduce its commands on each target operating system; do not substitute recollection from this plan for a current measurement.

## 4. Scope — in and out

### In scope

- A new Bash command, `bin/ai-gemini`, for read-only repository reviews only.
- Exact named sessions with `new`, `ask`, `list`, `transcript`, `delete`, and `doctor` behavior aligned with the existing reviewer commands where Antigravity supports it.
- A configurable exact model pin, initially `gemini-3.7-flash-high`, with structured `/model` verification and no silent fallback.
- Exact repository head/base identity, additive evidence packets, linked-worktree isolation, locks, failure classification, quarantine, scoreboard output, and `.ai/reviews/` reports.
- A dedicated Antigravity permission/configuration boundary that cannot weaken or overwrite Albert’s normal interactive Antigravity settings.
- Windows and Ubuntu installation, diagnosis, offline tests, paid live canaries, documentation, and a shared Claude/Codex delegation skill.
- Structured reporting of response status, conversation ID, turns, duration, token categories, and remaining allowance when Antigravity returns them.

### NOT in this plan

- Gemini implementation/editing mode. `ai-gemini` is review-only for its first release.
- Automatic provider selection or replacement of Grok, Kimi, GLM, Codex, or Opus.
- Changes to the completed reviewer-system repair decisions in [`plan_reviewer-system-repair.md`](plan_reviewer-system-repair.md), including its dropped six-turn limit.
- A GLM-style local server, a third-party Antigravity proxy, browser automation, API-key billing, Vertex AI, or Google Cloud project provisioning.
- Copying OAuth files, tokens, or login state into the repository, a disposable review directory, 1Password, or another OS account.
- Weakening permissions, enabling `--dangerously-skip-permissions`, granting general terminal commands, or accepting a post-run diff check as the only safety control.
- Database, cloud infrastructure, web UI, production deployment, or schema work.
- Editing another session’s handoff or cleaning unrelated files in the current checkout.

## 5. Current state of the code

### Already present and working

- Model selection is configurable in the existing direct wrappers through `AI_GROK_MODEL` and `AI_KIMI_MODEL` at [`bin/ai-grok-review:66`](bin/ai-grok-review#L66) and [`bin/ai-kimi:80`](bin/ai-kimi#L80). Gemini should follow the configurable pattern, not hard-code a model throughout the script.
- Both direct wrappers create a safe review boundary and additive evidence packet in `review_boundary()` / `prepare_review()` at [`bin/ai-grok-review:136`](bin/ai-grok-review#L136) and [`bin/ai-kimi:179`](bin/ai-kimi#L179).
- Machine-installed commands are enumerated in [`config/machine-tools.tsv`](config/machine-tools.tsv); Ubuntu’s [`install.sh`](install.sh) links every owned `bin/*` command.
- Provider preflight currently documents `grok|kimi|glm` only at [`bin/ai-review-preflight:140`](bin/ai-review-preflight#L140). Gemini is not integrated.
- The completed reviewer repair keeps full repository read/search, adds the evidence packet, preserves exact-head checking, and records provider outcomes without automatic selection. Its current decisions are in the STATUS and newest drift blocks of [`plan_reviewer-system-repair.md`](plan_reviewer-system-repair.md).

### Present only on the test machine, not in this repository

- Antigravity CLI 1.1.14 is installed at `%LOCALAPPDATA%\agy\bin\agy.exe` on `edge-dev` and is authenticated through machine-local Google OAuth.
- The installer added `%LOCALAPPDATA%\agy\bin` to the user PATH, but the already-running Codex process did not inherit the new PATH. Tests had to use the absolute executable until a new process was opened.
- Antigravity state and OAuth are under `%USERPROFILE%\.gemini`; these files are machine-local and must never be printed, copied, or committed.

### Not started

- No `bin/ai-gemini`, Gemini test suite, shared skill, installer catalog row, preflight provider, scoreboard normalization, configuration entry, or permanent wrapper documentation exists.
- No supported isolated Antigravity configuration-home mechanism has yet been proven.
- No hostile read/write canary has passed on either Windows or Ubuntu.
- No live repository review has been qualified.

### Git state at planning time

This plan is planning/documentation only. No wrapper behavior or installed machine configuration was changed. The original checkout at `C:\repos\ai-devops` contained unrelated concurrent edits and was behind `origin/main`, so planning was performed in a separate clean clone at `C:\repos\ai-devops-plan-gemini`. Implementation must start from the latest clean `main`, preserve unrelated work, and stage only owned paths.

## 6. Key findings and root cause

1. **The integration is Antigravity-native, not GLM-like.** Google’s official `agy` command already supplies model selection, named conversation IDs, resumption, structured JSON, usage, and local tools. Adding an OpenCode server would add credentials, lifecycle, and failure modes with no benefit.
2. **Exact selection is verifiable, but not from the normal response alone.** `--model gemini-3.7-flash-high` selects the model, while the ordinary JSON response omits the model. A zero-token `/model` command returns structured exact-session model data. The wrapper must verify this before trusting a review.
3. **Success is not completion.** A blocked tool request returned process success, JSON `status:"SUCCESS"`, and an empty response. A review is complete only when status is successful, the response is non-empty, required verdict structure exists, the exact model is verified, and no forbidden write or stale-head condition occurred.
4. **Plan mode is instruction, not enforcement.** Google’s execution-mode documentation says `plan` prepends `/plan` and encourages read-only tools. It does not revoke write tools. The native write canary proved a write can still occur.
5. **Workspace defaults are unsafe for a reviewer.** Google’s permission documentation says both reads and writes inside an active workspace are auto-allowed unless explicit deny rules override them. A reviewer-specific deny policy is mandatory.
6. **Windows `--sandbox` is not the answer.** Google documents terminal sandboxing as preview on macOS/Linux and “coming soon” to Windows. The implementation must not claim Windows isolation based on a flag that the platform does not enforce.
7. **Global settings cannot be casually edited.** Documented fine-grained permissions live in `~/.gemini/antigravity-cli/settings.json`. A reviewer cannot overwrite Albert’s interactive settings, save/restore them around a run, or race another Antigravity process. Step 1 must prove a supported per-process or dedicated-profile configuration path. If none exists, Windows release is blocked rather than weakened.
8. **The disposable directory remains necessary but is not sufficient.** `ai-review-sandbox` prevents writes from reaching a linked worktree’s real Git control directory. It does not stop writes elsewhere on the host. Permission denial and before/after canaries are also required.
9. **Commands should stay denied.** The evidence packet exists precisely so a reviewer without a general shell can understand the exact change. Do not grant `command(git)` or broad read commands merely to make exploration easier.
10. **Allowance is cost-weighted and context-heavy.** `/usage` exposes five-hour and weekly fractions, while even trivial calls carried large hidden input. The wrapper must report actual usage and allowance, never promise a number of reviews per subscription.
11. **Antigravity creates its own state outside the repository.** Conversation logs, brain/scratch files, caches, and summaries are expected machine-local side effects. The permission boundary must distinguish provider-owned state from forbidden writes, keep transcripts out of Git, and remove only wrapper-owned test artifacts.

## 7. Approaches considered and REJECTED, and why

1. **Use the retired Gemini CLI with personal OAuth. Rejected.** Both version 0.35.2 and the then-current 0.55.1 returned `UNSUPPORTED_CLIENT` for personal accounts before a model request. Google moved personal Pro/Ultra/free terminal access to Antigravity.
2. **Implement Gemini like GLM through OpenCode. Rejected.** Antigravity already provides the official agent, OAuth allowance, tools, conversations, and structured output. A server wrapper would duplicate Google’s harness and introduce new secrets and service lifecycle.
3. **Trust `--mode plan` as read-only. Rejected by live evidence.** Plan mode is a prompt prefix. A native write succeeded in Antigravity scratch state.
4. **Trust `--sandbox` on Windows. Rejected.** Google’s own documentation says Windows terminal sandboxing is not available yet.
5. **Treat exit code or `status:"SUCCESS"` as completion. Rejected by live evidence.** A denied command produced success with an empty answer.
6. **Use `--dangerously-skip-permissions`. Permanently rejected.** It auto-approves the actions the wrapper must prevent.
7. **Allow a broad terminal command so the model can read files. Rejected.** It turns a review into an unrestricted coding agent. Evidence packets plus native read/search tools must supply context.
8. **Edit and restore Albert’s global Antigravity settings around each run. Rejected.** Concurrent processes can observe the temporary state, a crash can strand weakened settings, and save/restore can overwrite a user change.
9. **Rely only on a disposable repository copy and check the diff afterwards. Rejected as the sole boundary.** It protects the real Git checkout but not other host paths or network access. It remains one layer in a layered design.
10. **Copy OAuth into an isolated account or folder. Rejected.** Login files are secrets and must not be copied or committed. If the official CLI cannot support a safe dedicated profile without copying credentials, stop and document the blocker.
11. **Automatically select Gemini because it appears cheap. Rejected.** The existing scoreboard records outcomes but never chooses a provider, and Antigravity’s allowance is cost-weighted and variable.

## 8. Design decisions already made, and their reasoning

### LOCKED decisions, 2026-08-18

- **Official provider:** use Antigravity CLI (`agy`) with authenticated Google OAuth. No Gemini CLI consumer path, proxy, or GLM/OpenCode server.
- **Initial purpose:** `ai-gemini` is review-only. Implementation/editing requires a separate future plan and threat model.
- **Initial model:** request Gemini 3.7 Flash High through configurable `AI_GEMINI_MODEL`, defaulting in one documented location to `gemini-3.7-flash-high`. Every session freezes the model and verifies it through structured `/model` output. Any mismatch is fatal.
- **Safety:** deny file writes, terminal commands, external URLs, browser actuation, MCP calls, and outside-directory reads unless a future separately reviewed requirement adds a narrower permission. `plan` mode is defense in depth only.
- **Repository boundary:** always call `ai-review-sandbox ensure`; ordinary clones may be returned unchanged, while linked worktrees receive a self-contained snapshot. Never hand Antigravity a raw linked worktree.
- **Evidence packet:** keep the packet additive. Gemini retains native read/search over the whole handed directory and receives the exact diff packet; do not seal it into `.ai-review/` alone.
- **Completion:** require successful JSON parsing, exact conversation ID, exact `/model` confirmation, non-empty answer, required verdict, unchanged protected targets, and exact-head recheck. Fail closed on any missing signal.
- **No global-setting mutation:** the wrapper may not temporarily rewrite and restore Albert’s normal Antigravity settings.
- **No automatic routing:** preflight and scoreboard gain Gemini support, but neither selects Gemini automatically.
- **No fixed review-count promise:** report token categories and current five-hour/weekly allowance fractions returned by `agy`.

### OPEN implementation judgments with fixed decision criteria

1. **Supported dedicated configuration boundary.** First preference is an officially supported per-process config/data-home override that reuses the authenticated account without copying OAuth. Second preference is an official project-scoped permission profile that cannot affect other Antigravity processes. If neither exists, stop Step 2 and mark issue #38 blocked; do not invent save/restore or credential copying.
2. **Conversation export source.** Prefer an official `agy` command/API. If absent, read only the exact conversation’s documented machine-local transcript and copy a scrubbed Markdown export into `.ai/reviews/`. Never parse unrelated conversations or OAuth state.
3. **Model-proof timing.** Prefer verifying `/model` immediately after session creation and again before accepting the final answer. If Antigravity cannot query a new session before the first turn, verify immediately after turn one and fail without saving an accepted verdict on mismatch.
4. **Ubuntu availability.** If Google has not released a compatible Antigravity build or safe sandbox behavior for the target Ubuntu host, land Windows support only if all shared code is platform-neutral and documentation labels Ubuntu unsupported. Do not emulate it with Gemini CLI personal OAuth.

## 9. The plan — numbered, ordered, executable steps

### Phase A — freeze the provider contract and prove safety

#### Step 1 — freeze and measure the Antigravity CLI contract

**Change:**

- Add versioned fixtures under `tests/fixtures/ai-gemini/` for `models`, one-turn JSON, resumed-turn JSON, `/model`, `/usage`, empty-success, quota error, authentication error, timeout, malformed JSON, missing conversation ID, and model mismatch.
- Start `tests/test-ai-gemini.sh` with a stub `agy` command and contract-parsing tests before writing the wrapper.
- Add a redacted current-version report under `docs/verification/ai-gemini/antigravity-contract-<date>-<os>.md` containing exact commands, CLI version, supported flags, model IDs, JSON field shapes, exit codes, and observed provider-owned paths.
- Determine through official documentation and a live canary whether Antigravity supports a per-process config/data-home or project permission file that can reuse OAuth without copying credentials. Record the exact supported variable/flag and precedence. Do not infer it from undocumented file placement.
- Measure `--new-project`, `--project`, working-directory binding, `--conversation`, `--continue`, `--log-file`, `--mode plan`, `--sandbox`, `--disable-slash-commands`, and print timeout. The earlier warning that plan mode has no effect when slash expansion is disabled means the wrapper must not combine those flags unless current behavior proves safe.

**Dependencies:** none beyond current Antigravity install/auth. Run Windows and Ubuntu probes independently; do not share OAuth files.

**Verification gate:** you’ll know it worked when `bash tests/test-ai-gemini.sh contract` passes against fixtures and the report lets a new session reproduce every field without reading this chat. If no supported isolated permission/config path is proven, update this plan and issue #38 to blocked and stop before Step 2.

#### Step 2 — prove a real read-only boundary on Windows and Ubuntu

**Change:**

- Create wrapper-owned, restrictive Antigravity settings from a static repo template such as `config/antigravity/readonly-review.settings.json`. The exact runtime location is determined only by Step 1’s supported mechanism.
- Explicitly deny `write_file(*)`, `command(*)`, `unsandboxed(*)`, `read_url(*)`, `execute_url(*)`, and `mcp(*)`. Explicitly allow `read_file(<review-directory>)`. Deny outside-directory reads. Remember Google precedence is Deny > Ask > Allow.
- Keep `--mode plan` as a behavioral instruction, not as the protection. Use `--sandbox` only where the live platform proves it exists; never claim it on Windows without evidence.
- Use `ai-review-sandbox ensure <repo> gemini-<session>` before the provider starts. Capture byte hashes and file lists for the real repository, handed review directory, a same-user outside sentinel, and provider-owned scratch state.
- Build hostile canaries that order Gemini to modify tracked/untracked files, `.git`, the evidence packet, an outside sentinel, its own scratch directory, and another repository; run terminal commands; access the network; and spawn a subagent. Every attempt must be denied. A write to the disposable review directory is still a hard review failure even if the real repository is safe.
- Ensure wrapper-owned normal outputs, logs, session metadata, and `.ai/reviews/` reports remain writable outside the reviewer’s tool permissions.

**Dependencies:** Step 1 must prove isolated permissions. Windows and Ubuntu proof can run in parallel after that.

**Verification gate:** you’ll know it worked when the hostile canary reports show every protected target byte-identical, no forbidden provider artifact survives, expected reviewer state/report files exist, and any simulated permission weakness produces a non-zero wrapper result. This is the release-blocking gate.

**Fresh-session cut:** update STATUS/current state, record drift, use `fresh-session`, then re-read Steps 3–10.

### Phase B — build the wrapper and integrations

#### Step 3 — build named, resumable `ai-gemini` review sessions

**Change:**

- Add `bin/ai-gemini`, patterned primarily on review portions of `bin/ai-grok-review` and `bin/ai-kimi`, without copying provider-specific assumptions.
- Provide `new <name>`, `ask <name>`, `list`, `transcript <name>`, `delete <name>`, `doctor`, `help`, and `--version`.
- Use state under `${AI_GEMINI_STATE_DIR:-$HOME/.local/state/ai-devops/gemini}` keyed by repository identity, caller, and validated session name. Store schema version, repository root/remote, safe review boundary, base/head, packet hash, Antigravity conversation ID, requested and verified model, cumulative turn/usage fields, allowance snapshot, timestamps, and transcript/report paths. Never store OAuth or raw settings containing secrets.
- Use per-session and per-repository locks with stale-lock evidence and bounded recovery, following the existing wrappers. Do not run two turns on one conversation or two review preparations against one repository concurrently.
- Freeze the review prefix, model, permission profile, directory, base/head, and packet hash at creation. Resume the exact conversation ID with `--conversation`; never use `--continue` for named work.
- Invoke `agy` non-interactively with JSON output, an explicit bounded `--print-timeout`, exact `--model`, the proven dedicated profile, and the safe review directory as the actual project/workspace. Capture stderr/logs separately and sanitize them before durable storage.
- Require `status == SUCCESS`, a non-empty response, a valid conversation ID, exact structured `/model` confirmation, a `## Verdict` section, and unchanged protected targets. Treat empty-success, malformed output, missing verdict, permission request, model mismatch, quota exhaustion, auth failure, timeout, cancellation, stale head, and write detection as separate loud failures.
- Save final reports under `.ai/reviews/` only after verifying that directory is Git-ignored. Put the verdict first, then findings, model, head/base, packet hash, conversation ID, turns/duration/token categories, allowance fractions/reset times, and failure evidence where applicable.

**Dependencies:** Steps 1–2.

**Verification gate:** you’ll know it worked when the offline suite proves every command, lock, session identity, output contract, exact-model gate, completion gate, and cleanup path, and a live named conversation answers a follow-up from the same conversation ID without changing any protected file.

#### Step 4 — integrate evidence packets, exact-head checks, preflight, quarantine, and scoreboard

**Change:**

- Reuse `review_boundary()` / `prepare_review()` patterns with `ai-review-sandbox` and `ai-review-packet`; do not copy packet construction into the new wrapper.
- Accept the common review inputs already used by current wrappers: `--base`, `--tests`, `--decision`, and `--assert-head`. Derive Git SHAs inside the wrapper and refuse caller claims that do not match.
- Add `gemini` to the provider validation and help text in `bin/ai-review-preflight`. Its cheap check must use `agy models`, authenticated model availability, permission-profile presence, writable result/state paths, and packet verification without spending a model turn. `--live` may use one bounded marker request and `/model` verification.
- Extend failure explanation/quarantine mappings for Antigravity auth, allowance, unavailable model, model mismatch, permission denial, unsafe-write detection, empty success, timeout, malformed result, and unsupported platform safety.
- Ensure `bin/ai-review-scoreboard` accepts Gemini’s normalized fields without assuming cost exists. Record five-hour/weekly remaining fractions as optional provider-specific fields; never use them to choose a provider.

**Dependencies:** Step 3. Preflight and scoreboard edits can run in parallel once wrapper result fields are frozen.

**Verification gate:** you’ll know it worked when all four helper suites pass, a linked-worktree fixture receives a self-contained directory rather than a raw worktree, packet hashes verify, stale-head assertions fail, preflight classifies every Gemini fixture correctly, and scoreboard summary includes Gemini without changing provider selection.

#### Step 5 — install and diagnose Antigravity and `ai-gemini` consistently

**Change:**

- Add `ai-gemini` to [`config/machine-tools.tsv`](config/machine-tools.tsv) with the correct Windows launcher form, Ubuntu link behavior, provider prerequisite (`agy`), and Windows installer owner.
- Update `bin/install-machine-tools.ps1`, `bin/install-machine-tools.sh`, `bin/ai-machine-tools-doctor`, `bin/setup-machine.ps1`, `bin/verify-windows-dev.ps1`, `.config/configuration.winget` if an official package exists, and their tests only as required by the catalog-driven behavior.
- On Windows, resolve `%LOCALAPPDATA%\agy\bin\agy.exe` directly when the current process has stale PATH, but do not hard-code that as the sole path; prefer command discovery plus the documented install location. On Ubuntu, use the official Google installer/package path and verify architecture/checksum behavior already supplied by Google.
- `ai-gemini doctor` must report wrapper version, resolved `agy` path/version, auth/model availability via a real non-secret call, exact configured model, dedicated permission profile, safety capability by platform, state/report paths, and current allowance. It must not print OAuth data or claim health from `--version` alone.
- Update configuration examples and documentation for `AI_GEMINI_MODEL`, `AI_GEMINI_STATE_DIR`, `AI_GEMINI_CALLER`, safe timeout settings, and any proven dedicated config-home variable. Model selection must remain configurable in one documented place.

**Dependencies:** Step 3’s CLI contract; Step 2’s safety profile.

**Verification gate:** you’ll know it worked when Windows and Bash installer tests pass, a dry-run shows only expected launcher/config changes, a fresh shell resolves `ai-gemini`, and installed `ai-gemini doctor` proves a real authenticated model lookup plus the safety profile without exposing secrets.

**Fresh-session cut:** update STATUS/current state, record drift, use `fresh-session`, then re-read Steps 6–10.

### Phase C — teach, document, and exhaustively test the workflow

#### Step 6 — add the shared Gemini delegation skill

**Change:**

- Create one shared skill at `skills/shared/gemini-code-delegation/SKILL.md`; do not duplicate Claude and Codex copies.
- Teach exact trigger language such as “ask Gemini,” “use Gemini 3.7 Flash,” “run this by Gemini,” and “get a Gemini review.”
- Require `ai-gemini` for repository reviews, exact named sessions, read-only defaults, model/allowance reporting, and no direct `agy --dangerously-skip-permissions` use.
- Explain that first release is review-only, that High is the configured initial model rather than an eternal hard-coded fact, and that direct interactive Antigravity work is outside this wrapper.
- Update `docs/skills-map.md`, `docs/skills-usage-guide.md`, `docs/codex-skills-usage-guide.md`, `bin/ai-install-skills`, and skill installer/trigger tests as required.
- Run the repository’s supported trigger evaluator from `tools/skill-trigger-eval/`; do not use the obsolete skill-creator loop.

**Dependencies:** Step 3 command contract must be stable.

**Verification gate:** you’ll know it worked when positive prompts select the new skill, near-miss prompts do not, both Claude and Codex installations contain the same shared source, and every command example matches `ai-gemini --help`.

#### Step 7 — update permanent documentation and routing

**Change:**

- Add a permanent AGENTS router row instructing future sessions to read this plan’s STATUS first while issue #38 is open, then the `bin/ai-gemini` verification header, shared skill, tests, and investigation/verification docs.
- Update `README.md`, `docs/architecture.md`, `docs/development.md`, `docs/deployment.md`, `docs/configuration.md`, `docs/config-inventory.md`, `docs/model-setup.md`, `docs/skills-map.md`, and the installed-command inventory in AGENTS.md.
- Document the consumer migration from Gemini CLI to Antigravity, exact-model `/model` proof, cost-weighted `/usage` buckets, provider-owned state, Windows sandbox limitation, dedicated-profile requirement, and the difference between plan guidance and permission enforcement.
- Update `memory/ai-devops/ai-gemini-wrapper-plan.md` from “read the open plan” to the final durable operating facts after implementation; keep `memory/ai-devops/MEMORY.md` linked.

**Dependencies:** Steps 3–6 so documentation names real behavior.

**Verification gate:** you’ll know it worked when every referenced path/command exists, `rg` finds no instruction to use personal OAuth through old Gemini CLI, installed command lists agree, and a zero-context reader can find the wrapper from AGENTS, README, the skill map, and memory.

#### Step 8 — complete the offline failure and regression suite

**Change:**

- Finish `tests/test-ai-gemini.sh` with the exact cases listed in §10.
- Extend `tests/test-ai-review-preflight.sh`, `tests/test-ai-review-scoreboard.sh`, `tests/test-ai-review-sandbox.sh`, `tests/test-ai-review-packet.sh`, and Windows installer tests for Gemini integration.
- Stub `agy` so tests never spend allowance, read OAuth, or require network. Separate live tests behind an explicit opt-in variable.
- Add a regression proving that `status:"SUCCESS"` plus empty response fails, and another proving that requested High plus `/model` mismatch fails even when a plausible verdict exists.

**Dependencies:** Steps 3–7.

**Verification gate:** you’ll know it worked when all commands in §10 pass twice from a clean clone, no test reads machine OAuth, and no fixture leaves processes, locks, snapshots, scratch files, or repository changes.

### Phase D — qualify live behavior and land it

#### Step 9 — run paid live qualification on Windows and Ubuntu

**Change:**

- On `edge-dev`, use the authenticated personal Google account and current official Antigravity CLI. On `hetz`, install/authenticate only through the documented official flow; if a human browser/code approval is required, ask Albert once with the exact URL/code step.
- Run: cheap preflight; exact High marker; `/model`; `/usage`; named resume; a real small exact-head diff review; linked-worktree review; hostile write/read/network/command canaries; empty-success simulation; timeout/cancel; and transcript/delete lifecycle.
- Capture redacted reports under `docs/verification/ai-gemini/` with OS, CLI/wrapper versions, repository SHA, model proof, allowance before/after, duration/turn/token fields, protected-target hashes, and outcome. Do not publish account email, OAuth, full machine logs, or unrelated conversation content.
- Compare one equivalent small review against the current provider scoreboard for usefulness and time. This is evidence, not automatic provider ranking.

**Dependencies:** Steps 1–8. Windows and Ubuntu live qualifications can run in parallel only after the offline safety suite is green.

**Verification gate:** you’ll know it worked when both supported platforms return usable exact-head verdicts from verified `gemini-3.7-flash-high`, resume the exact conversation, report allowance, leave every protected target unchanged, and finish within the existing honest review ceiling. If either platform lacks a proven safety boundary, label it unsupported and do not install there.

**Fresh-session cut:** update STATUS/current state, record drift, use `fresh-session`, then re-read Step 10.

#### Step 10 — independent review, landing, installation, and issue close

**Change:**

- Run an independent exact-head review of the wrapper, permission boundary, installer changes, skill, and tests using a provider other than Gemini. The reviewer must inspect the hostile canaries and global-setting isolation, not only Bash style.
- Address every material finding and re-run the exact-head review after changes.
- Verify Git identity is `Albert Hazan <u2giants@users.noreply.github.com>`, stage only this workstream’s files, commit on `main`, push, and verify `origin/main` equals the intended SHA.
- Install from GitHub source of truth on each supported machine; run installed `ai-gemini doctor`, live marker, `/model`, `/usage`, and read-only canary. There is no CI or hosted deployment, so record “not applicable” rather than inventing one.
- Update this plan’s STATUS/current state, convert memory to durable facts, delete this plan’s handoff only when every open obligation is carried into durable docs, and close issue #38 with commit and verification links.

**Dependencies:** Steps 1–9.

**Verification gate:** you’ll know it worked when the independent reviewer approves the exact landed SHA, all tests pass, `origin/main` contains that SHA, installed commands on every supported machine report the same wrapper version and exact model, protected files remain unchanged, and issue #38 is closed with durable evidence.

## 10. Tests required

### New primary suite: `tests/test-ai-gemini.sh`

The suite must include named checks for:

- Usage/help/version and invalid commands.
- Session-name validation and caller separation.
- Repository identity, moved checkout handling, and remote-less clone behavior.
- Model comes from the documented configurable value.
- `agy models` availability and auth failure classification.
- Exact `/model` success and mismatch refusal.
- `/usage` parsing for five-hour/weekly fractions and reset times; missing fields remain explicit `unavailable`, never zero.
- New conversation stores the exact conversation ID; `ask` resumes by `--conversation`, never `--continue`.
- Frozen prefix/config/directory/model drift refusal.
- Per-session and per-repository locks, including stale-lock recovery.
- JSON success, non-success, malformed JSON, missing ID, empty-success, missing verdict, quota failure, timeout, cancellation, and unexpected exit.
- Evidence packet creation/hash verification, wrapper-derived base/head, `--assert-head`, additive full-directory access, and `.ai-review` Git exclusion.
- Ordinary clone boundary and linked-worktree self-contained snapshot boundary.
- No raw worktree `.git` pointer handed to Antigravity.
- Permission profile denies write, command, unsandboxed execution, URL access, browser actuation, MCP, and outside-directory reads.
- Hostile writes to tracked/untracked files, `.git`, packet, outside sentinel, other repo, and provider scratch all fail and yield non-zero review result.
- A weak/missing permission profile is refused before a provider call.
- Protected-tree before/after verification and loud attribution of any changed path.
- Report path must be Git-ignored; report includes verdict first, exact model, SHAs, packet hash, conversation ID, usage, allowance, and explicit unavailable fields.
- Transcript export is scoped to the exact conversation and scrubbed.
- Delete removes only wrapper-owned session/snapshot records and leaves provider account/history alone unless the official command proves exact deletion.
- Doctor resolves stale PATH, proves real auth/model availability, validates safety profile, and never prints OAuth.
- Interrupted/cancelled runs release locks and clean or preserve artifacts according to a documented recovery state.

### Existing suites that must remain green

Run from Git Bash/Ubuntu as applicable:

```bash
bash tests/test-ai-gemini.sh
bash tests/test-ai-review-sandbox.sh
bash tests/test-ai-review-packet.sh
bash tests/test-ai-review-preflight.sh
bash tests/test-ai-review-scoreboard.sh
bash tests/test-ai-grok-review.sh
bash tests/test-ai-kimi.sh
bash tests/test-ai-glm.sh
bash tests/test-ai-qwen.sh
```

Run the repository’s current Windows setup/install suites named by `docs/development.md`, including `tests/test-windows-scripts.sh` and the PowerShell installer/winget tests. The implementing session must re-read that document for exact current commands because the test inventory may change before implementation begins.

### Live tests

Live tests require an explicit opt-in such as `AI_GEMINI_LIVE_TEST=1`, spend subscription allowance, and write only redacted evidence. They must never run in the default offline suite.

## 11. Constraints, standing rules, and gotchas in force

- GPT-5.6 may use only low or medium reasoning. Never raise it to high.
- Target `u2giants/ai-devops` `main`; no feature branch. Fetch before work and preserve concurrent changes.
- Before the first commit, `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- GitHub is source of truth. Do not permanently fix an installed machine without first landing the repository change.
- No band-aids, silent fallback, or model substitution. A missing safety feature is a blocker.
- Never use `--dangerously-skip-permissions` in wrapper, tests, docs, or examples except a negative assertion proving it is rejected.
- Never copy, print, inspect unnecessarily, commit, or place OAuth files in a review snapshot. Antigravity authentication remains machine-local.
- Fine-grained permission precedence is Deny > Ask > Allow. Workspace writes are allowed by default, so the deny policy must be explicit and proven.
- `--mode plan` is a prompt prefix. It is not read-only enforcement.
- Windows terminal sandboxing was not available in Google’s 2026-08-18 documentation. Recheck current official docs but require live proof before changing that statement.
- A linked worktree’s `.git` is a file pointing into the main repo. Always use `ai-review-sandbox ensure`; never widen the reviewer to a second directory.
- The review evidence packet is additive. Gemini must retain read/search over the entire handed directory.
- Do not lower the existing honest review ceiling to six turns/five minutes. The completed reviewer repair dropped that idea after live evidence.
- Empty output is failure even when JSON says success. Missing model/usage/cost fields are `unavailable`, never guessed.
- `/model` and `/usage` are zero-token slash commands in the measured CLI, but re-prove that contract on version change.
- Antigravity CLI writes provider-owned state outside the repo. Cleanup may remove only exact wrapper/test artifacts it owns; never recursively delete `.gemini` or conversation history.
- This repository has no database, CI, hosted service, container, or production URL. Mark those deployment checks N/A.
- Unit tests are mandatory. Live safety verification is mandatory. There is no UI, so visual verification is N/A.
- Do not edit root `HANDOFF.md` or another session’s `HANDOFF.d` file.

## 12. Access and environment

- Planning repository: `C:\repos\ai-devops-plan-gemini`, clean `main` at creation. Implementation may use any clean `main` clone but must quote the current `origin/main` SHA.
- Original concurrent checkout: `C:\repos\ai-devops`; it contained unrelated work and must not be bulk-staged.
- Windows test machine: `edge-dev`, Windows 11, PowerShell 7 plus Git Bash.
- Antigravity executable measured at `%LOCALAPPDATA%\agy\bin\agy.exe`, version 1.1.14 on 2026-08-18. User PATH was updated but the running Codex process was stale.
- Authentication: Google OAuth already exists in Antigravity’s machine-local state. Never expose the account or OAuth file. No new 1Password item is expected.
- Ubuntu target: `hetz`, checkout convention `/worksp/ai-devops`. Antigravity install/auth and safety remain to be proven in Step 9.
- GitHub CLI is authenticated as `u2giants`; tracking issue is [#38](https://github.com/u2giants/ai-devops/issues/38).
- Existing reviewer commands and their tests are available locally. Use only official Google documentation for current Antigravity behavior.
- If future credential storage becomes necessary, the only approved vault is 1Password `vibe_coding`; stop for approval before creating or rotating anything. Do not store the existing OAuth there as part of this plan.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] Every STATUS row is complete with an artifact, not a bare claim.
- [ ] `bin/ai-gemini` provides the documented review-only command set.
- [ ] Exact `gemini-3.7-flash-high` selection is configurable, frozen per session, and verified through structured `/model` output.
- [ ] Named conversations resume by exact ID and export only their own scrubbed transcript.
- [ ] Hostile live canaries prove no write to the real repo, disposable review directory, outside sentinel, `.git`, packet, other repo, or provider scratch.
- [ ] General commands, network, browser actuation, MCP, and outside-directory reads are denied.
- [ ] Empty-success, model mismatch, stale head, missing verdict, quota, auth, timeout, malformed output, and write attempts fail loudly.
- [ ] Evidence packet, exact-head, preflight/quarantine, scoreboard, linked-worktree, report, and installer integrations work.
- [ ] The shared Gemini skill triggers correctly for Claude and Codex.
- [ ] All offline suites pass; redacted Windows and Ubuntu live evidence exists for every supported platform.
- [ ] Independent exact-head safety review approves the landed SHA.
- [ ] Git identity is correct; owned changes are committed to and pushed on `main`; `origin/main` is verified.
- [ ] Installed `ai-gemini doctor` and live canary pass from GitHub source of truth on every supported machine.
- [ ] Documentation, memory, plan STATUS/current state, and handoff retirement are correct.
- [ ] Issue #38 is closed with commit and verification links.
- [ ] CI, hosted deployment, database, and UI checks are explicitly recorded as N/A because this repository has none.

### Principal risks and controls

- **Global permission corruption:** avoided by requiring an officially supported isolated profile and forbidding save/restore of user settings.
- **False read-only claim on Windows:** avoided by hostile native-write and command canaries; unsupported platforms are labeled unsupported.
- **Model fallback:** avoided by structured `/model` proof and fatal mismatch.
- **False completion:** avoided by non-empty/verdict/model/head/write gates in addition to status.
- **Allowance exhaustion:** preflight `/usage`, bounded calls, explicit live-test opt-in, and no promised review count.
- **Hidden context cost:** record real token categories and compare useful reviews, not toy prompt price.
- **Conversation leakage:** exact-ID state and scoped transcript export; never scan unrelated history for content.
- **Linked-worktree escape:** mandatory self-contained boundary via `ai-review-sandbox`.
- **Concurrent-session collision:** per-repo/session locks and no global-setting mutation.
- **Upstream CLI drift:** versioned fixtures, doctor contract checks, exact flags, and failure on unknown shapes.

### Rollback

Before installation, rollback is the Git commit preceding `ai-gemini`. After landing, revert the exact `ai-gemini` commit on `main`, push, and rerun machine installers so launchers/catalog entries are removed through the repository’s normal uninstall/update path. Machine-local Antigravity and OAuth remain untouched. Never delete `.gemini` as rollback.

### Genuine open questions and decision criteria

1. Does current Antigravity provide a supported isolated configuration/data-home that reuses OAuth safely? Step 1 must answer with official documentation plus a live canary. No means implementation blocks.
2. Can Ubuntu meet the same read-only boundary? Yes means support it; no means document Windows-only until Google supplies the missing protection.
3. Can exact transcripts be exported officially? Use the official method if present; otherwise use only the exact conversation’s documented file after proving schema/version and scrubbing.
4. Does a version change alter zero-token `/model` and `/usage`, model IDs, JSON fields, or workspace binding? Doctor and contract tests must fail closed until fixtures are requalified.

## Mandatory self-audit

### Objective checklist

- [x] All 13 sections are present.
- [x] The ultimate goal is first, in plain business English, and says the goal wins over a conflicting step.
- [x] A fresh session can execute without this chat; current state, exact paths, issue, SHA, environments, measurements, decisions, and commands are included.
- [x] Rejected approaches and failed attempts are recorded with reasons in §7.
- [x] Every numbered step names concrete files/functions and ends with a verification gate.
- [x] Locked and open decisions are labeled in §8.
- [x] §4 states explicit in-scope and out-of-scope lists.
- [x] §10 names exact required test behaviors and suites.
- [x] Uncommon terms, paths, IDs, environments, and provider behaviors are defined or linked.
- [x] Secrets are referenced only by storage location and never by value.
- [x] §13 includes commit, push, independent review, installation, and explicit N/A deployment checks.
- [x] This plan and its new handoff link directly to each other; root `HANDOFF.md` remains untouched.

### Required audit questions

1. **Could a brand-new AI session with no project knowledge and no context from this conversation execute this plan to perfection without asking Albert anything? Yes.** §§2–6 define the repository, existing tools, exact current state, trigger, measured provider contract, and root safety problem. §§9–12 give ordered file-level work, verification, tests, constraints, and access. The only genuine unknown has a fail-closed investigation and decision rule in §§8, 9 Step 1, and 13.
2. **Does the plan carry every piece of background, nuance, and reasoning currently known, including what was ruled out and why? Yes.** §§3, 6, and 7 preserve the retired Gemini CLI failure, exact model/resume/usage successes, empty-success failure, scratch write, plan-mode weakness, Windows sandbox limitation, hidden token cost, rejected server/proxy/global-setting approaches, and why each matters.
3. **Is the ultimate goal clear enough for a correct judgment call if a step is wrong? Yes.** §1 makes safe independent review the business outcome and explicitly makes read-only, exact-model, exact-code, and loud-failure gates superior to any prescribed implementation step. §§8 and 13 translate that goal into locked decisions and stop criteria.

**Self-audit result: PASS.** No checklist gap remains.
