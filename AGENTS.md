# AGENTS.md — AI DevOps Toolkit operating guide

Canonical operating guide and documentation router for this repository. Read this
first. It is written so a new senior engineer or AI session can understand the
repo in under 5 minutes without prior chat context.

## Project summary

This repo is a **backup-and-restore toolkit for a multi-model AI coding
workflow**. It is a small set of Bash CLI scripts, prompt templates, docs, and
skill/MCP scaffolding — **not** an application, service, or web app.

- **What it does:** installs CLI helpers (`ai-devops`, `ai-workspace-status`,
  `ai-codex-review`, `ai-model-call`, `ai-run-task`, `ai-glm`, `ai-grok-review`, `ai-grok-implement`, `ai-kimi`, `ai-qwen`) that drive a staged coding
  workflow: plan → plan-review → implement → diff-review → test → security-review
  → final-review.
- **Who uses it:** the repo owner (Albert, GitHub `u2giants`) and AI coding
  sessions (Claude/Opus for planning + review, Codex/GPT-5.5 for implementation +
  testing).
- **Key moving parts:** `bin/` scripts (the tools), `config/*.env.example`
  (seed for machine-local config at `/etc/ai-devops/`), `templates/prompts/`
  (the seven stage prompts), and `docs/` (restore/setup/onboarding).
- **Outcome that matters:** the whole workflow can be **restored from zero** on a
  fresh Ubuntu server if the current one dies. See
  [`docs/restore-from-zero.md`](docs/restore-from-zero.md).

This toolkit does **not** modify application repos automatically. Onboarding an
app repo is a separate, manual, opt-in process.

## Multi-model AI note

There is no universal ignore-file standard across AI coding tools.

`.claudeignore` works for Claude Code.

When using any other AI tool, paste this file as your first message and follow the instructions in the "What to ignore" section.

## Documentation map: what to read for each task

Always start with:

- `AGENTS.md`

Then load additional docs only when relevant:

| Task / question | Read these docs | Usually do not need |
|---|---|---|
| Quick repo orientation | `README.md`, `AGENTS.md` | Deep docs under `docs/` unless task requires them |
| Install a vendor AI CLI (Grok, Kimi, Qwen) on a machine, or explain `<provider> provider unavailable` | `bin/install-ai-provider-clis.sh` (Linux/macOS), `bin/install-windows-ai-provider-clis.ps1` (Windows), `docs/config-inventory.md` | That message is informational, not a failure: the repo's wrappers are installed, the vendor CLI is not. Run the installer as the AI-session user, never root — the vendor installers write into `$HOME`. Logins stay interactive; never automate one. |
| Reduce always-loaded AI context, decide where a rule or fact lives, or work the context-engineering consolidation | `AGENTS.md`, [`docs/context-engineering.md`](docs/context-engineering.md), `plan_context-engineering-consolidation.md` | Global and skill source files unless the task requires them |
| Fix or continue dotfiles-sync reconciliation of local Grok/Kimi/GLM commands | `AGENTS.md`, [`plan_sync-machine-wrapper-reconciliation.md`](plan_sync-machine-wrapper-reconciliation.md) STATUS first, both sync skills, platform installer, related tests | Do not re-plan from chat or add another per-skill command checklist |
| Modify a `bin/` script or workflow behavior | `AGENTS.md`, `docs/architecture.md`, `docs/development.md` | `docs/deployment.md` unless install/symlink behavior changes |
| Add or change configuration, env vars, or model commands | `AGENTS.md`, `docs/configuration.md`, `docs/model-setup.md` (model commands) | Unrelated architecture docs |
| Understand where machine config lives (skills, SSH, MCP, gcloud, memory, secrets) | `AGENTS.md`, `docs/config-inventory.md` | Unrelated architecture docs |
| **MCP servers "keep disappearing" / a server is configured but Claude cannot see it** | [`docs/critical-incidents.md`](docs/critical-incidents.md) (→ 2026-08-20). Claude Code reads `~/.claude.json` ONLY — an `mcpServers` block in `~/.claude/settings.json` is silently ignored. Verify with `claude mcp list`, never by reading the file back. | Reinstalling the servers before checking WHICH file they landed in |
| **Codex "works" but `codex exec` changes nothing / sandbox helper not found / wiring the `codex-cli` MCP** | [`docs/critical-incidents.md`](docs/critical-incidents.md) (→ 2026-07-16) and [`docs/design-decisions.md`](docs/design-decisions.md), `docs/config-inventory.md` (→ "Codex: PATH + MCP"), `templates/system/machine-atlas.md` (→ junction trap), `bin/setup-machine.ps1` (Windows), `bin/setup-secrets.sh` (Ubuntu) | Model/prompt docs |
| Anything about the Headroom token-compression proxy (find it, fix it, route a machine through it, see savings, turn it off) | `AGENTS.md`, `docs/headroom.md` | Unrelated architecture docs |
| Plan/track converging all machine config onto ai-devops | `AGENTS.md`, `docs/config-consolidation-proposal.md`, `docs/config-inventory.md` | Unrelated docs |
| Change install/update/uninstall or restore flow | `AGENTS.md`, `docs/deployment.md`, `docs/restore-from-zero.md`, `install.sh`/`update.sh`/`uninstall.sh` | Local-only dev docs unless the dev workflow also changes |
| Install/update AI DevOps on a Windows coding computer | `AGENTS.md`, `.config/configuration.winget` (packages/settings), `bin/bootstrap-windows-dev.ps1` (single entry point), `bin/configure-windows-bootstrap-access.ps1` (Tailscale/OpenSSH), `bin/configure-wsl-ansible-controller.ps1`, `bin/setup-machine.ps1` (AI/secret wiring), `bin/verify-windows-dev.ps1`, `docs/windows-winget-configuration.md` | `bin/run_me_setup_dev_comp.bat` and `bin/setup_dev_computer_internal.ps1` are transitional only; Linux restore docs unless also touching server install |
| Set up a new machine's secrets / 1Password / MCP tokens / `claude` launcher | `AGENTS.md`, `docs/onboarding-secrets.md`, `config/mcp.env.example`, `bin/setup-secrets.sh` (Ubuntu), `bin/setup-machine.ps1` (Windows) | Model/prompt docs unless also changing the workflow |
| Enable secure Windows remote setup over Tailscale / SSH | `AGENTS.md`, `docs/windows-openssh-tailscale.md` | Do not enable LAN/public SSH, password logins, broad default firewall rules, or WinRM |
| Edit the staged prompt templates | `AGENTS.md`, `templates/prompts/*`, `docs/architecture.md` | Deployment/config docs |
| Onboard an application repo to the workflow | `AGENTS.md`, `docs/repo-onboarding.md`, `templates/repo-docs/*` | Deployment docs |
| Back up / sync Claude Code transcripts | `AGENTS.md`, `skills/claude/claude-transcript-backup/SKILL.md` | Transcripts live in the PRIVATE `transcripts/` submodule. Never commit them here. Do not open the `.jsonl` files themselves |
| Touch GLM, `ai-glm`, the OpenCode server, or the Windows GLM setup | **`docs/glm-opencode.md` section 5 "Hard-won constraints" FIRST — 33 constraints, each guarding a measured failure**, then `bin/ai-glm`, `bin/setup-opencode-glm.sh` / `.ps1`, `config/opencode/*`, `skills/shared/ask-glm/SKILL.md`, `tests/test-ai-glm.sh`, `tests/test-windows-scripts.sh` | Do not "simplify" the job lifecycle, completion rule, remote-less clone, ASCII-only `.ps1` rule, or agent `tools:` maps without re-measuring; section 5 says why. **There is no open GLM plan** — `plan_glm-implementation-job-tracking.md`, `plan_ai-glm-permission-deadlock.md`, and `plan_ai-glm-permission-failures.md` are all CLOSED (2026-08-12) and are records only |
| Build or continue the Muse Spark 1.2 protected conversation runner | **[`plan_muse-opencode-harness.md`](plan_muse-opencode-harness.md) STATUS first**, then `docs/muse-opencode.md`, `tests/test-ai-muse.sh`, and `skills/shared/ask-muse/SKILL.md` | Muse uses persistent named direct-mode sessions in a disposable self-contained copy. Continue with `ai-muse ask`; never substitute standard Muse or fall back to another model. GLM remains its separate persistent service. |
| Run, debug, or change a delegated review or its private snapshot | **The header of `bin/ai-review-sandbox` FIRST**, then `tests/test-ai-review-sandbox.sh` and the `review_boundary` block in `bin/ai-glm`, `bin/ai-kimi`, `bin/ai-qwen`, `bin/ai-grok-review` | Every directory-based reviewer gets one fixed, self-contained private snapshot per session, including reviews started from ordinary clones, so the live checkout cannot move underneath it (issue #53). A linked worktree's `.git` also points outside the allowed directory and cannot be reviewed raw (observed 2026-08-17, GLM). Do not recompute a live session's boundary, point a reviewer at a raw checkout, or widen its boundary. `ai-codex-review` and `ai-deepseek-agent` send the diff as text and are deliberately not wired. |
| Touch Grok, `ai-grok-review`, `ai-grok-implement`, or the Grok skill | **The STEP 0 VERIFICATION header at the top of `bin/ai-grok-review` and of `bin/ai-grok-implement` FIRST**, then `skills/shared/grok-cli/SKILL.md`, `tests/test-ai-grok-review.sh`, `tests/test-ai-grok-implement.sh` | Completion is a terminal `stopReason` in the JSON, NEVER exit status. Do not remove `--max-turns`, broaden permissions, add a flag passthrough, or "simplify" the wait loop or per-repo lock, and never "restore" `--worktree` or `--permission-mode auto` — each guards a measured failure documented in those headers |
| Fix Grok clone concurrency, cancellation truth, active-run visibility, mid-turn progress, or issue #56 | **[`plan_grok-review-concurrency-cancellation-observability.md`](plan_grok-review-concurrency-cancellation-observability.md) STATUS first**, then issue #56, its two local reviewer records, the Grok STEP 0 header/skill/tests, and `tests/test-ai-reviewer-issue.sh` | Keep checkout-bound session identity separate from normalized upstream cost-lock identity. Never claim a local kill cancelled the provider, and never attach an unrelated newest record as incident evidence. |
| Add, implement, change, or test `ai-gemini`, Gemini 3.7 Flash review, or Antigravity reviewer integration | **[`plan_ai-gemini-wrapper.md`](plan_ai-gemini-wrapper.md) STATUS first while issue #38 is open**, then [`docs/ai-gemini-wrapper-investigation.md`](docs/ai-gemini-wrapper-investigation.md), the future `bin/ai-gemini` verification header, shared Gemini skill, and `tests/test-ai-gemini.sh` | Antigravity exact model/resume works, but plan mode is not read-only, Windows terminal sandboxing is unavailable, workspace writes are allowed by default, and JSON `SUCCESS` can be empty. Do not implement until a dedicated isolated permission profile and hostile-write canaries pass. Never change global Antigravity settings around a run or use `--dangerously-skip-permissions`. |
| Fix delegated-review latency, no-verdict runs, provider health, failure handling, exact-head invalidation, or non-database work consuming shared-db agents | **[`plan_reviewer-system-repair.md`](plan_reviewer-system-repair.md) FIRST — its STATUS table and newest DRIFT RECORDED block**, then [`fix_reviewer_system.md`](fix_reviewer_system.md), [`docs/reviewer-issues.md`](docs/reviewer-issues.md), `skills/shared/log-reviewer-issue`, `bin/ai-review-preflight`, `bin/ai-review-scoreboard`, `bin/ai-reviewer-issue`, and the affected wrapper instructions above | The evidence packet shipped. Preflight/quarantine and failure-specific guidance address independent failure modes; the scoreboard records outcomes but never auto-selects a provider. When Albert says "log the reviewer error," use `log-reviewer-issue` to infer complete details from the session and run `ai-reviewer-issue`; never make him type options or repeat the problem. Preserve fail-closed safety and never broaden permissions. |
| Repair findings from the 2026-08-20 all-reviewer audit | [`bugs.md`](bugs.md) first, then the affected provider plan linked under its **Implementation plans** section; shared packet/snapshot/incident/scoreboard defects start with [`plan_reviewer_shared_evidence_integrity.md`](plan_reviewer_shared_evidence_integrity.md) | Do not re-plan from the audit chat or treat an existing passing test count as proof against a missing hostile case. Read the selected plan's STATUS table first and update it as work lands. |
| Build, change, or debug a review evidence packet | **The header of `bin/ai-review-packet` FIRST**, then `tests/test-ai-review-packet.sh` and `prepare_review()` in `bin/ai-grok-review`, `bin/ai-glm`, `bin/ai-kimi` | The packet is **ADDITIVE**: reviewers keep full read and grep over the whole directory and the manifest says so. Do NOT turn it into a sealed room — `reviewer_retains_access_outside_the_packet` guards that. A fact belongs in the packet only if a reviewer could not get it without a shell; policy files are referenced by path, never inlined. Nothing is ever silently truncated. The packet directory is named after the SESSION TAG (`.ai-review-<tag>`), never a fixed `.ai-review`: two reviewers started from one checkout used to overwrite each other's evidence mid-review and the resulting verdict looked normal (shared-db#1296). Do not collapse that back to one name, and do not soften the foreign-owner refusal into a warning |
| Understand or replace the shared-db orchestrator after application database requests crossed sessions or remained unfinished | [`plan_shared-db-finish-first-delivery.md`](plan_shared-db-finish-first-delivery.md) STATUS first, then [`shared-db_orchestrator_failure_analysis.md`](shared-db_orchestrator_failure_analysis.md), and [`fix_reviewer_system.md`](fix_reviewer_system.md) for the reviewer-specific subset | The replacement plan retires the perpetual coordinator while preserving durable safety gates. Do not implement from the postmortem alone or restore automatic lane refill. |
| Touch Kimi, `ai-kimi`, or the Kimi skill | **Read [`plan_kimi-review-failure-recovery.md`](plan_kimi-review-failure-recovery.md) STATUS first while issue #46 is open**, then `plan_kimi-windows-execution-reliability.md` history, the STEP 0 VERIFICATION header at the top of `bin/ai-kimi`, `config/kimi/readonly-review.md`, `skills/shared/kimi-code-delegation/SKILL.md`, `tests/test-ai-kimi.sh`, `plan_kimi-persistent-implementation-sessions.md`, and `plan_kimi-incomplete-implementation-recovery.md` | Kimi remains quarantined until issue #46 passes merged installed live qualification. Reviews are read-only ONLY because of the agent profile; plain `kimi -p` writes files freely, and its tool names are case-sensitive and fail silently to no-tools-at-all. Preserve concurrent wrapper work, fail closed, recover partial output only as `INCOMPLETE — NO VERDICT`, and never quote Kimi token, cost, cache, or returned-model figures. Credentialed Windows Kimi execution belongs in the Full Access main task, not a restricted delegated task. |
| Analyze Codex transcripts or repeated Codex prompts | `AGENTS.md`, `docs/codex-chat-analysis.md`, `docs/codex-skills-usage-guide.md`, `skills/codex/codex-transcript-miner/SKILL.md` | Raw transcript `.jsonl` unless the analysis task requires them |
| Install or update Claude/Codex skills / global instructions on a machine | `AGENTS.md`, `docs/skills-usage-guide.md`, `docs/codex-skills-usage-guide.md`, `bin/ai-install-skills`, `templates/system/*` | Transcript data |
| Replace a machine's always-loaded globals with the repo copies | `bin/ai-adopt-globals` (NOT `ai-install-skills --adopt-globals` by hand) | The installed globals usually end with a MACHINE SECTION that exists nowhere in the repo. `--adopt-globals` alone destroys it — it only prints a NOTE. `ai-adopt-globals` saves it, re-appends it, and **diffs it back**; the diff is the gate, never the exit code |
| Add or update Codex workflow skills | `AGENTS.md`, `docs/codex-skills-usage-guide.md`, affected `skills/codex/*/SKILL.md`, `docs/skills-map.md` | Raw chat/docx prompt sources unless needed |
| Write a skill `description:`, or check whether a skill actually fires on real prompts | `AGENTS.md`, `docs/skill-trigger-eval.md`, `tools/skill-trigger-eval/` | skill-creator's bundled `scripts/run_loop.py` — it is Unix-only AND tests a mechanism that no longer triggers; see the doc |
| Check whether the installed always-loaded globals still change behaviour on a machine | `AGENTS.md`, `tools/context-probes/` | A trigger score is not a probe: it proves selection, never obedience. Score the tool calls a probe session made, never the wording of its answer |
| Create a NEW skill, or decide where an existing one belongs | `AGENTS.md`, `docs/skills-map.md`, `docs/skills-usage-guide.md`, then ONE of `skills/shared/<name>/` (serves Claude **and** Codex — the default when both should follow the rule) or `skills/claude/<name>/` / `skills/codex/<name>/` (genuinely client-specific only) | **Do not write two near-identical copies under `skills/claude/` and `skills/codex/`** — that is the drift trap; put it in `skills/shared/` instead. A name may exist in `shared/` **or** a client tree, never both: `ai-install-skills` fails closed on the collision |
| Read, add, change, reconcile, or audit POP business rules | `skills/shared/pop-business-rules/SKILL.md`, then the canonical `u2giants/shared-db/docs/business-rules/application-map.md`; while issue #35 is open, read [`plan_pop-business-rules-skill.md`](plan_pop-business-rules-skill.md) STATUS first | The Skill is a procedure and router only. Never copy business rules into `ai-devops`, the Skill body, or application-specific rulebooks. |
| Write a handoff, or an implementation plan for another session to execute | `templates/system/handoff-standard.md` (past-facing; skill `handoff-writer`) or `templates/system/implementation-plan-standard.md` (forward-facing; skill `implementation-plan-writer`), `docs/skills-map.md` | Do not write a plan that assumes the implementing session has this session's context — that is the exact failure both standards exist to prevent |
| Improve GLM, Grok, or Kimi debate continuity and reliability | `plan_delegate-wrapper-hardening.md` first, then `plan_glm-service-reliability.md`, `plan_grok-debate-continuity.md`, `plan_kimi-debate-context-continuity.md`, and the integration-specific docs/skill named by the active plan | Read each plan's STATUS table first; the three older plans are complete, while `plan_delegate-wrapper-hardening.md` owns the current GLM-review follow-up |
| Change a standing AI behavior rule (branch policy, plain-English, verify-before-done, etc.) | `templates/system/CLAUDE-global.md`, `templates/system/AGENTS-global-codex.md`, `templates/system/machine-atlas.md`, affected `skills/shared/*/SKILL.md` (cross-client rules) or `skills/claude/*/SKILL.md` / `skills/codex/*/SKILL.md` | Unrelated docs |
| Work on future MCP wrapper | `AGENTS.md`, `docs/future-mcp-wrapper.md`, `mcp/README.md` | Unrelated docs |
| Work on future visual testing | `AGENTS.md`, `docs/future-visual-testing.md`, `templates/repo-docs/docs-ai-visual-testing.md` | Unrelated docs |
| Investigate a bug in a tool | `AGENTS.md`, `docs/development.md`, the specific `bin/` script, the OPEN handoffs (see the handoff note below), then [`docs/critical-incidents.md`](docs/critical-incidents.md) | Unrelated docs |
| A behavior looks like a bug, or you are about to "fix"/simplify something odd | [`docs/design-decisions.md`](docs/design-decisions.md) | Do not change any behavior listed in "Intentional quirks" below until you have read its entry there |
| A tool reports success but changed nothing, Codex sandboxing fails on Windows, or 1Password rate-limits | [`docs/critical-incidents.md`](docs/critical-incidents.md) (Codex sandbox FAIL from doctor → also check for an expired `codex login`; → 2026-08-20) | Unrelated docs |
| About to run `git reset --hard`, `git checkout --`, or `git clean` in a repo another agent may be using | [`docs/critical-incidents.md`](docs/critical-incidents.md) (→ 2026-08-18) | **Run `git status --short` first. Any ` M` line is a hard stop — a hard reset destroyed another session's uncommitted work on 2026-08-18 and it was unrecoverable** |
| A commit you pushed is missing from `main`, or a file you deleted has reappeared | [`docs/critical-incidents.md`](docs/critical-incidents.md) (→ 2026-08-19) | **A force-push dropped it. The commits are recoverable — `git merge --no-ff <tip-sha>`. Never force-push a shared branch** |
| Continue unfinished work | `AGENTS.md`, `HANDOFF.md` → the OPEN files in `HANDOFF.d/` (newest-first), docs named inside them | Docs unrelated to the handoff scope |
| Claude Code session | `CLAUDE.md`, then `AGENTS.md` | Other docs unless the task requires them |
| Documentation-only cleanup | `AGENTS.md`, `README.md`, affected docs under `docs/` | Source files except as needed to verify accuracy |

### How handoffs work now (one write-once file per session)

Because several AI agents work these repos concurrently — sometimes in the same
working copy — **no session ever rewrites a shared handoff document.** Each session
writes exactly ONE new file:

```
HANDOFF.d/<UTC-timestamp>-<machine>-<agent>-<slug>.md
```

e.g. `HANDOFF.d/2026-07-29T2140Z-t16-claude-supabase-mcp-scoping.md`. In a migrated
repo the root `HANDOFF.md` is a one-screen **static pointer** (line 1 carries the
marker `handoff-pointer: v1`) and is never rewritten; **session start** lists
`HANDOFF.d/` and reads the OPEN files newest-first — every file present is one open
workstream, and a finished workstream's file is **deleted** (git history preserves
the text). A repo whose root `HANDOFF.md` lacks that marker is still the **legacy**
full-document form: read it as one open workstream and migrate it per
`handoff-writer`. Canonical rules: `templates/system/handoff-standard.md`; skill:
`skills/shared/handoff-writer/`. **This repo was migrated 2026-07-30**: its root
`HANDOFF.md` is now the static pointer, and the two former legacy documents were moved
verbatim into `HANDOFF.d/` as open workstreams.

The OPEN files in `HANDOFF.d/` are required reading — each one means work is in
progress. Never hard-code their count here; list the directory at session start
and read every current file newest-first. Do not apply an unproven bootstrap to
an established workstation merely as a test.

## Repository structure

The toolkit code is **project-owned and hand-written** (no generated code, no
vendor/third-party code, no framework, no build artifacts). The one large
non-code area is `transcripts/` - a PRIVATE submodule holding session transcripts.

| Path | What it is | Category |
|---|---|---|
| `bin/` | The five CLI tools (Bash) | project-owned code |
| `install.sh`, `update.sh`, `uninstall.sh` | Lifecycle scripts (Bash) | project-owned scripts |
| `config/*.env.example` | Seed templates copied to `/etc/ai-devops/` on install | project-owned config templates |
| `templates/prompts/` | The seven staged prompt templates (01–07) | project-owned templates |
| `templates/repo-docs/` | Doc add-ons to drop into onboarded app repos | project-owned templates |
| `templates/system/` | Global standing instructions (`CLAUDE-global.md`, `AGENTS-global-codex.md`) + per-machine environment atlas, installed to each machine's AI config | project-owned templates |
| `docs/` | Restore, setup, onboarding, and future-feature docs | docs |
| `skills/` | Claude + Codex skill scaffolding (`SKILL.md`) | project-owned scaffolding |
| `tests/` | Dependency-free Bash and PowerShell installer behavior tests | project-owned tests |
| `memory/` | Cross-machine Claude auto-memory (per-project `MEMORY.md` + fact files), synced by `bin/ai-sync-memory`. **Secret-free** — see `memory/README.md` | project-owned data (git-tracked) |
| `mcp/` | Future MCP wrapper placeholder | project-owned scaffolding |
| `transcripts/` | Session transcripts, in the PRIVATE submodule `u2giants/ai-devops-transcripts`. This repo is PUBLIC; transcripts must never be committed into it. | archived data (sensitive) |
| `codex_chats/` | Archived Codex session transcripts (`.jsonl`) across machines, plus its own `README.md` | archived data (scrubbed, still sensitive — see below) |
| `README.md`, `AGENTS.md`, `CLAUDE.md` | Top-level docs | docs |

`transcripts/` is a cross-machine backup of `~/.claude/projects/`, kept in the
PRIVATE repo `u2giants/ai-devops-transcripts` as a git submodule. **This repo
(`u2giants/ai-devops`) is PUBLIC.** Transcripts routinely contain live secrets, so
they must never be committed here; `.gitignore` blocks `claude_chats/` and
`codex_chats/`. Do not open the `.jsonl` files themselves.

There are **no** migrations, `Dockerfile`, `docker-compose`, CI/CD workflows
(`.github/workflows`), `package.json`, or database files in this repo. If you go
looking for them, they genuinely do not exist — do not assume they are hidden.

## Prime Directive: custom-code boundary

Our custom code lives here:

- `bin/` — the CLI tools
- `install.sh`, `update.sh`, `uninstall.sh`
- `config/` — `*.env.example` templates
- `templates/` — prompt templates and repo-doc add-ons
- `docs/` — documentation
- `skills/`, `mcp/` — skill/MCP scaffolding
- `tests/` — dependency-free installer behavior tests
- `transcripts/` - private submodule (owned, but data - edit only
  the script/README, never hand-edit transcript `.jsonl` files)

Everything else requires justification before touching.

Because this repo is 100% owned code, the boundary is really about **runtime
side-effects on the host**: `install.sh` writes to `/etc/ai-devops/`,
`/var/log/ai-devops/`, and `/usr/local/bin/` (symlinks). Those are outside the
repo. Changing what the scripts write to those locations requires care and a
`docs/deployment.md` update.

## Core modification inventory

No files outside the project-owned areas exist in this repo (there is no vendor,
generated, or framework code to modify). This section is intentionally empty.

| File | Change made | Why it was necessary | Risk during upgrades |
|---|---|---|---|
| _(none)_ | — | — | — |

Host side-effects (not repo files) that `install.sh` creates, for awareness:
`/etc/ai-devops/models.env`, `/etc/ai-devops/server.env`,
`/var/log/ai-devops/`, and symlinks under `/usr/local/bin/ai-*`.

## Task-to-file navigation: what to edit for common changes

(What **source/config** files to edit — distinct from the documentation map above.)

| Task | Files to touch | Files not to touch |
|---|---|---|
| Change a tool's behavior | `bin/<tool>` | `/etc/ai-devops/*.env` (machine-local, not in repo) |
| Add a new CLI tool | `bin/<new-tool>`, `install.sh` (symlink loop picks it up automatically), `AGENTS.md`, `README.md` | Existing tools unless related |
| Change what `doctor` checks | `bin/ai-devops` (`cmd_doctor`) | — |
| Add/rename a model command variable | `config/models.env.example`, `bin/ai-model-call` (stage→var map), `docs/configuration.md`, `docs/model-setup.md` | Real `/etc/ai-devops/models.env` (edit per-machine, never commit) |
| Add a server/config setting | `config/server.env.example`, the consuming script, `docs/configuration.md` | Real `/etc/ai-devops/server.env` |
| Edit a workflow stage prompt | `templates/prompts/0X-*.md` | Other stages unless intentionally aligning them |
| Change install/symlink logic | `install.sh` (and mirror in `uninstall.sh`), `docs/deployment.md` | — |
| Change the restore procedure | `docs/restore-from-zero.md`, `docs/deployment.md` | — |
| Back up session transcripts | see `skills/claude/claude-transcript-backup/SKILL.md` (PRIVATE `transcripts/` submodule) | Transcript `.jsonl` files (never hand-edit) |

## Data model and external identifiers

There is **no database** and **no external cloud system** (no Coolify, Supabase,
container registry, or webhooks) wired to this repo. The "identifiers" that
matter are stable paths, the GitHub repo, and the workflow's stage/variable
names.

| Entity/System | Identifier | Where defined | Notes |
|---|---|---|---|
| GitHub repo | `u2giants/ai-devops` (private) | GitHub | Origin remote; push uses noreply email for privacy |
| Toolkit home | `/worksp/ai-devops` | fixed convention | **Never** `/opt/ai-devops`. Referenced by all scripts/docs |
| Machine config dir | `/etc/ai-devops/` | `install.sh`, `server.env` | Holds real `models.env` + `server.env` (not in repo) |
| Log dir | `/var/log/ai-devops/` | `install.sh`, `server.env` | Created on install; currently unused by scripts |
| Installed commands | `/usr/local/bin/ai-*` | `install.sh` symlinks; sync reconciliation catalog in `config/machine-tools.tsv` | `ai-devops`, `ai-workspace-status`, `ai-codex-review`, `ai-model-call`, `ai-run-task`, `ai-glm`, `ai-grok-review`, `ai-grok-implement`, `ai-kimi`, `ai-qwen`, `ai-deepseek-agent`, `ai-review-preflight`, `ai-review-scoreboard`, `ai-reviewer-issue`, `ai-machine-tools-doctor`, `ai-install-skills`, `ai-gcloud-dflow`, `ai-sync-memory` |
| Workflow stages | `plan`, `plan-review`, `implement`, `diff-review`, `test`, `security`, `final` | `bin/ai-model-call`, `templates/prompts/` | Stage → prompt → model-command mapping |
| Model command vars | `OPUS48_HIGH_REASONING_CMD`, `OPUS_REVIEW_CMD`, `GPT55_CMD`, `CODEX_CMD`, `TESTER_CMD` | `config/models.env.example` → `/etc/ai-devops/models.env` | Non-secret command strings |
| Run/review artifacts | `.ai/runs/`, `.ai/reviews/` (inside onboarded app repos) | `ai-run-task`, `ai-codex-review` | Git-ignored; created in the target repo, not here |
| Transcript archive machines | `hetz`, `compshop`, `t16`, `seafile` | `transcripts/<machine>/` (PRIVATE submodule) | Backup of each machine's `~/.claude/projects/` |

Do not casually rename or regenerate these identifiers — scripts and docs assume
them verbatim.

## Container and service inventory

**There are no containers or long-running services.** This toolkit is a set of
CLI scripts symlinked into `/usr/local/bin`. Nothing runs as a daemon, container,
or hosted service.

| Container/service | Purpose | Managed by | App/project ID | Image/source |
|---|---|---|---|---|
| _(none)_ | — | — | — | — |

The closest thing to a "service" is the set of installed CLI commands listed in
**Data model and external identifiers** above.

## What to ignore

Apart from the `transcripts/` submodule, this repo is small and text-only. Keep these aligned
with `.claudeignore` / `.cursorignore`.

- **`transcripts/`** - session transcripts, in the PRIVATE submodule
  `u2giants/ai-devops-transcripts`. Untracked here and gitignored: this repo is
  PUBLIC and transcripts routinely embed live secrets.
- **`codex_chats/`** — archived Codex session transcripts. Scrubbed before
  commit, but still large and sensitive. Never load it into AI context.
- `.git/` — version-control internals
- `.ai/runs/`, `.ai/tmp/`, `.ai/reviews/` — run/review artifacts (generated inside
  target repos; never source-of-truth here)
- `node_modules/`, `dist/`, `.cache/`, `coverage/` — do not exist here, but ignore
  if ever generated
- `*.env` (real config) — lives at `/etc/ai-devops/`, never committed; only
  `*.env.example` belongs in git

Note: real config and secrets are **not in the toolkit code** — they live under
`/etc/ai-devops/` and in the Claude/Codex CLI login state (`~/.claude`,
`~/.codex`). The exception is the `transcripts/` submodule, whose raw transcripts may embed
secrets that were visible during those sessions — see below.

## Intentional quirks and non-obvious decisions

Ten behaviors here look like bugs and are deliberate. Each line is the rule. The
full "looks like / actually / why / do not change" reasoning lives in
[`docs/design-decisions.md`](docs/design-decisions.md) — **open it before you
change, simplify, or "fix" any of them.**

| Looks wrong | The rule |
|---|---|
| Real `*.env` config is missing from the repo | Config lives in `/etc/ai-devops/`; `install.sh` seeds it only when absent, so machine-local edits are never clobbered. Never commit a real `.env`. |
| Model CLI commands look wrong for the installed CLI | They are per-machine defaults in `/etc/ai-devops/models.env`. Do not hard-code flags into scripts. |
| No Fable model slot | Fable is deliberately absent. Planning and final review use Opus 4.8 at high reasoning. |
| `codex-cli` MCP uses Codex's own `mcp-server`, not a richer third-party wrapper | Deliberate: no supply chain, no `npx` in the hot path, and a wrapper re-resolves `codex` from PATH, which reintroduces the Windows junction bug. |
| `ai-devops doctor` spends a real model call on Codex | It runs a real sandboxed write. `--version` cannot see the failure mode that cost a full session on 2026-07-16. Do not downgrade it. |
| `ai-install-skills` pruned nothing, and updating wiped local files | Both fixed: `.ai-devops-managed` quarantine (unmarked dirs untouched), then preview-first sync that keeps unowned files, backs up edits. `docs/deployment.md` |
| `codex exec resume` rejects flags that `exec` accepts | Upstream behavior. `resume` refuses `-s/--sandbox`, `-C/--cd`, `--color`; a mistyped `-c` key silently falls back to the config default, so always confirm the run header. |
| Review stages never fix what they find | Reviews are read-only by design; they write a report under `.ai/reviews/` and nothing else. |
| The MCP secret launcher caches secrets | Required. A per-launch `op run` locked the shared 1Password account. Never re-add `--`, never drop `Position = 0`, never re-resolve per launch. |
| The memory hub clone sets `core.longpaths` again | Its clone is separate from this checkout, and transcripts produce 400+ character paths. Long-path support must be set before the first checkout. |

## Credentials and environment

No secrets live in this repo. The variables below are **non-secret** command
strings and paths. Real values live in `/etc/ai-devops/*.env` (machine-local) and
are seeded from `config/*.env.example`. Claude/Codex/gh login sessions are stored
by those CLIs (`~/.claude`, `~/.codex`, `~/.config/gh`). The GLM Coding Plan key
lives only in 1Password item `GLM z.ai API`; the repo distributes its `op://`
reference and injects it only into the OpenCode GLM server that `ai-glm` talks to.

> ⚠️ **1Password account = `popcreations.1password.com` (since 2026-07-22).** The
> scoped service account was migrated off `my.1password.com`; the `vibe_coding`
> vault re-created every item under **new UUIDs**. All `op://` references are now
> **name-based** (`op://vibe_coding/<title>/<field>`). Two deliberate UUID
> exceptions remain — do **not** "fix" them to name-based: (1) the Trigger PAT
> (parentheses in the title, which `op` rejects in a reference); (2) the
> **recall-ai** ref in `bin/setup-machine.ps1` / `bin/setup-secrets.sh`, which is
> passed **inline** through the mcp-remote launcher (a space in the ref breaks the
> launcher's arg/`op read` parsing). Name-based is safe only for refs resolved via
> `op run --env-file` (the mcp.env path). The GLM key is in the `api key` field,
> not `credential` (empty →
> silent-empty). Rotating the bootstrap `OP_SERVICE_ACCOUNT_TOKEN` does **not**
> auto-propagate — update the machine-local token file/env var/embedded configs by
> hand and restart the apps. `op whoami` decodes the token locally, so it can
> report a **deleted** SA while real calls return `(403) Service Account Deleted` —
> prove a token with a real `op item create`/`delete`, never `whoami`. Full detail:
> `docs/onboarding-secrets.md`, `docs/config-inventory.md`.

| Variable | Purpose | Stored where | Required in dev | Required in prod |
|---|---|---|---|---|
| `AI_DEVOPS_HOME` | Toolkit checkout path (`/worksp/ai-devops`) | `models.env`, `server.env` | yes | yes |
| `AI_DEVOPS_ETC` | Machine config dir (`/etc/ai-devops`) | `server.env` | yes | yes |
| `AI_DEVOPS_LOG_DIR` | Log dir (`/var/log/ai-devops`) | `server.env` | no | no |
| `WORKSPACE_ROOT` | Where app repos live (`/worksp`) | `server.env` | no | no |
| `DEFAULT_MAIN_BRANCH` | Branch name for safety warnings | `server.env` | no | no |
| `OWNER_NAME` | Name used in plain-English final summaries (`Albert`) | `server.env` | no | no |
| `OPUS48_HIGH_REASONING_CMD` | Command for plan + final-review stages | `models.env` | yes | yes |
| `OPUS_REVIEW_CMD` | Command for plan/diff/security reviews | `models.env` | yes | yes |
| `GPT55_CMD` | Command for the implement stage | `models.env` | yes | yes |
| `CODEX_CMD` | Command for `ai-codex-review` | `models.env` | yes | yes |
| `TESTER_CMD` | Command for the test stage | `models.env` | yes | yes |

There are **no** API keys, tokens, or passwords in the **toolkit code or config
templates**. Model access comes from the Claude/Codex CLI login sessions, not
from env vars here.

All direct 1Password access is serialized. Agents and scripts must never fan
out `op read`, `op run`, or 1Password MCP calls in parallel. Shared MCP secrets
are resolved as one environment and reused; Windows launchers enforce this with
an OS mutex and DPAPI-encrypted short-lived cache, while Ubuntu resolves once in
the login shell and locks any fallback refresh.

> **Transcripts may contain live secrets.** They live in the PRIVATE submodule
> `transcripts/` (`u2giants/ai-devops-transcripts`), never in this repo, which is
> PUBLIC. `claude_chats/` and `codex_chats/` are gitignored so they cannot be
> committed here again, and both are excluded from AI context in `.claudeignore` /
> `.cursorignore`. Do not open the raw `.jsonl` files.

## Deployment

"Deployment" here means **installing the toolkit onto a machine**, not a cloud
release. There is **no CI/CD pipeline, no container image, no hosting platform,
and no GitHub Actions workflow** in this repo.

- **Install / update mechanism:** run `./install.sh` (verify deps, create
  `/etc/ai-devops` + `/var/log/ai-devops`, seed config without overwriting,
  symlink `bin/*` into `/usr/local/bin`, run `ai-devops doctor`). `./update.sh`
  does `git pull --ff-only` then re-runs `install.sh`. `./uninstall.sh` removes
  the symlinks (keeps config unless `--purge`, keeps the checkout unless
  `--remove-repo`).
- **GitHub Actions workflow name:** none (no `.github/workflows`).
- **Image/package names, tag pattern, registry:** not applicable — nothing is
  built or published.
- **Deployment platform / app/project ID:** not applicable — installs directly on
  an Ubuntu host.
- **Deploy trigger:** manual — run `install.sh`/`update.sh` on the target host.
- **Rollback:** `git checkout <previous-sha>` in `/worksp/ai-devops` then re-run
  `./install.sh`; or `./uninstall.sh` to remove symlinks. Config in
  `/etc/ai-devops/` is preserved.
- **Runtime environment variables:** in `/etc/ai-devops/models.env` and
  `server.env` on each host (not in the repo).
- **SSH:** SSH is how you reach the host to run the scripts; there is no
  SSH-based deploy automation. It is the normal (and only) access path, since
  installation is a local operation on the box.

Full first-time / disaster restore steps:
[`docs/restore-from-zero.md`](docs/restore-from-zero.md). Overview:
[`docs/deployment.md`](docs/deployment.md).

## Critical incidents

Two incidents cost real sessions. Full narrative, root cause, and the lessons that
made each one slow to diagnose:
[`docs/critical-incidents.md`](docs/critical-incidents.md) — **open it when a tool
reports success but changes nothing, when Codex sandboxing fails on Windows, or on
any 1Password rate-limit or lockout.**

- **2026-07-16 — Codex on Windows looked healthy and wrote nothing.** Every
  sandboxed `codex exec` silently did nothing while `--version`, `login status`,
  and exit code all read green. Cause was an upstream PATH junction. `ai-devops
  doctor` now proves the sandbox with a real write; run it after any Codex
  install or upgrade.
- **2026-07-23 — the shared 1Password service account locked out.** The MCP
  launcher re-resolved every `op://` reference on every server start, across five
  machines, and blew the per-hour request cap. Fixed by resolving once behind a
  machine-wide mutex into a 15-minute encrypted cache. Full hardening detail:
  [`docs/mcp-1password-rate-limit-hardening.md`](docs/mcp-1password-rate-limit-hardening.md).

Other incident records: [`docs/cloud-build-prod-trigger-incident-2026-07-20.md`](docs/cloud-build-prod-trigger-incident-2026-07-20.md),
[`docs/security-incident-credential-rotation-2026-07.md`](docs/security-incident-credential-rotation-2026-07.md),
[`docs/transcript-leak-audit-2026-07-19.md`](docs/transcript-leak-audit-2026-07-19.md).

## Pending work

| Status | Item | Owner/next action |
|---|---|---|
| open | Orchestrate stages end-to-end | `ai-run-task` / `ai-model-call` are v0.1 scaffolds; full pipeline automation is future work |
| open | MCP wrapper | Design sketched in `docs/future-mcp-wrapper.md` + `mcp/README.md`; not implemented |
| open | Automated visual testing (Playwright) | Design sketched in `docs/future-visual-testing.md`; manual for now |
| open | App-repo onboarding helper | `docs/repo-onboarding.md` describes manual steps; `ai-onboard-repo` helper not built |
| done | Initial toolkit scaffold + install + doctor green | Completed in commit `f39315d` |
| done | Config-consolidation **Phase 1** | `sync-dotfiles` skill (Claude + Codex), `bin/ai-gcloud-dflow`, `bin/ai-sync-memory` + `memory/` tree. See `docs/config-consolidation-proposal.md`. |
| done | Config-consolidation **Phase 2** | Shipped 2026-07-14, `2d` closed 2026-07-26. Secret plumbing, MCP launchers with the 15-min cache, token-free MCP configs, SSH aliases, 916-alien key — all repo-owned (`bin/setup-machine.ps1`, `bin/setup-secrets.sh`). **Adopted on `t16` + `al8960ofc`; rollout still outstanding on `916` (off until ~2026-07-28) and Ubuntu servers beyond `hetz`** — one `git pull` + per-OS script each. |
| done | Config-consolidation **Phase 3** | Completed 2026-08-10. Active Dropbox setup scripts are retired pointer stubs with sensitive recovery backups preserved; both-OS restore docs, credential inventory, portable Codex defaults, and machine atlas are current. See [`plan_phase3-config-consolidation.md`](plan_phase3-config-consolidation.md). |

Config consolidation is complete. The July credential-cleanup workstream was
closed by owner decision on 2026-08-10 without further rotations; its durable
evidence remains in `docs/security-incident-credential-rotation-2026-07.md` and
`docs/transcript-leak-audit-2026-07-19.md`. The only current machine rollout is
the powered-off `916` computer, recorded in the newest open file under
`HANDOFF.d/`. [`plan_phase3-config-consolidation.md`](plan_phase3-config-consolidation.md)
is retained as the completed implementation and verification record.
