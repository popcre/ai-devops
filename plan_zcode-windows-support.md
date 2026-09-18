# IMPLEMENTATION PLAN — ZCode for Windows parity in ai-devops (2026-09-17)

Planning issue: [popcre/ai-devops#558](https://github.com/popcre/ai-devops/issues/558)
Paired handoff: [`HANDOFF.d/2026-09-17T1955Z-edge-dev-zcode-zcode-windows-support-plan.md`](HANDOFF.d/2026-09-17T1955Z-edge-dev-zcode-zcode-windows-support-plan.md)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Freeze the ZCode Windows baseline (qualification facts) | ✅ done | 2026-09-17 | `tests/verification/zcode-windows-2026-09-17/README.md` — every claim carries its reproducing command; live-probed on edge-dev (env-assembly mandatory; parser rejects `--max-turns`/`--settings`/`--allowed-tools`; plan-mode + denylist write-denial; hooks inert headlessly; junction + 111-skill leak inventoried). D9 decided (winget `ZhipuAI.ZCode` confirmed), D13 decided (env set required). |
| 2. Install policy and presence checks | ✅ done | 2026-09-17 | `.config/configuration.winget` (unpinned `ZhipuAI.ZCode` — self-updating, never pinned); `bin/setup-machine.ps1` `Get-ZCodeInstall` probe (both version numbers, fixture-testable). |
| 3. `zcode` launcher shims + `bin/ai-zcode` governed wrapper | ✅ done | 2026-09-17 | `bin/ai-zcode` (STEP 0 header; ask/doctor/version; yolo refused; wall-clock ceiling; env assembly) + `bin/ai-zcode.cmd`, `config/machine-tools.tsv` row, setup-machine shim stage. Offline: `tests/test-ai-zcode.sh` 30/30 (caught a real errexit-suppression bug). Live on edge-dev: `ai-zcode ask` answered, `ai-zcode doctor` runs. |
| 4. Managed skills: `skills/zcode/` tree + installer + junction migration | ✅ done | 2026-09-17 | `bin/install-ai-devops-windows.ps1` (`Remove-ZCodeSkillsJunction`, zcode+shared install calls, orphan pruning, collision assert extended); `skills/zcode/zcode-transcript-backup/`; manifest scan in `bin/ai-install-manifest`. `tests/test-install-ai-devops-windows.ps1` §9 proves junction→dir migration leaves the junction TARGET untouched. |
| 5. Global instructions: `AGENTS-global-zcode.md` template + seeding | ✅ done | 2026-09-17 | `templates/system/AGENTS-global-zcode.md`; installer seeds `~/.zcode/AGENTS.md` (seed-only); `bin/ai-adopt-globals` third target (installs a still-missing non-bash target itself — the Bash installer does not own the Windows-only client). Fixture-proven in both suites. |
| 6. MCP wiring: `bin/configure-zcode-mcps.ps1` + catalog membership | ✅ done | 2026-09-17 | Strict-schema JSON writer (canonical keys only, string command, explicit `timeoutMs`, backups, idempotent, foreign-preserving); `tests/test-configure-zcode-mcps.ps1` 19/19. Membership `$ZCodeMcpNames = @("1password")` — the plan's illustrative `1password+codex-cli` predates PR #573's codex-cli suspension; D10's unproven-value criterion decides (expand later by one line). |
| 7. Hooks: completion-check hook under `hooks.events` | ✅ done | 2026-09-17 | `bin/ai-install-completion-check-hook --client zcode` (merges `hooks.events`, sets `hooks.enabled: true`, preserves mcp/plugins; `--check` drift mode). Fixture-proven; live firing NOT provable in 0.16.5 (hooks never dispatch headlessly — recorded in the facts file), so verification is structural, per the amended Step 7 reality. |
| 8. Transcript backup + SQL mining cookbook (SQLite + rollout store) | ✅ done | 2026-09-17 | `skills/zcode/zcode-transcript-backup/` (SKILL.md: copy db.sqlite+wal/shm+rollout to `zcode_chats/<machine>/` gated by `ai-transcript-destination-check`; queries.md: recipes validated live against a copy 2026-09-17 — epoch-ms timestamps, `completed/error/running` vocabulary). |
| ~~9. Reviewer wrapper `bin/ai-zcode-review`~~ | ⛔ removed 2026-09-17 | — | Owner ruling: GLM never reviews GLM-orchestrated work; ZCode's engine is GLM-5.3. See §7.9. Never built; no registry entry. |
| 10. Doctor and machine verification surface | ✅ done | 2026-09-17 | `bin/ai-devops` doctor zcode section (presence/versions/login/config parse/mcp/hooks/markers/shim, warn-only on absence, platform-honest on Linux); `bin/verify-windows-dev.ps1` `app:ZCode` check; installer login note (`zcode login --no-browser`, URL-truncation warning). `tests/test-ai-devops-doctor-install-state.sh` green. |
| 11. Documentation (README, task router, model setup) | ✅ done | 2026-09-17 | `docs/model-setup.md` ZCode section (role, wrapper, traps, transcript pointer); `docs/config-inventory.md` ZCode-home row; `README.md` mention; AGENTS.md task-router row already present (PR #569). `bin/ai-doc-reachability --base origin/main` PASS. |
| 12. Land: tests green, merge, install, verify | ✅ done | 2026-09-18 | Merged: PR #584 (`473007a4`, queue-verified) + follow-up fix PR #586 (`b964fb41`, shim here-string bug found on the first real run). edge-dev installed state verified 2026-09-18: `install-ai-devops-windows.ps1` + `setup-machine.ps1` + `ai-install-completion-check-hook --client zcode` re-run from the canonical checkout; `~/.zcode/skills` a real managed dir (36 markers; junction gone; Claude skills intact at 48 before/after; fixture leftover quarantined), `~/.zcode/AGENTS.md` seeded, `~/.zcode/cli/config.json` carries exactly `[1password]` strict-schema via the launcher with `hooks.enabled: true` and timestamped `.aidevops.*.bak` backups from the writer's first run, `~/.local/bin/zcode{,.cmd}` live (`zcode --version` -> 0.16.5), `ai-zcode doctor` all checks green, `ai-devops doctor` ZCode section all OK, public repo clean of transcript bytes. |

**Fresh-session starting point:****Fresh-session starting point:** begin at Step 1. Re-read §§5–8 before changing any code,
and re-read the phase heading before starting each phase — steps drift once reality moves.
Phases: **A** = Steps 1–3 (foundations), **B** = Steps 4–7 (managed configuration),
**C** = Step 8 (transcripts; the former Step 9 was removed 2026-09-17),
**D** = Steps 10–12 (verification and landing).
Each phase boundary is a natural context cut point: finish the phase, update this table with a
reproducible artifact, and let the next session start from a clean context.

**Amendment 2026-09-17 (owner review of the drafted plan):** the ZCode reviewer step was
removed **permanently** — owner ruling "I never want GLM reviewing GLM code", and ZCode's
engine is GLM-5.3 (§7.9). The memory-index hook port was dropped in favor of ZCode's
native memory feature (§7.11). The `zcode-config-repair` skill was killed (§7.10).
Step 8 was redesigned around SQL mining of the copied session database, which is better
than the Claude/Codex JSONL approach for ZCode's relational store. Leanness details were
then settled by a Grok 4.6 consultation (session `zcode-plan-leanness-558`, 2026-09-17,
$0.20): the wrapper ships `doctor`+`ask` with no state dir, the `provider-cli-versions.json`
entry is deferred until a consumer exists, and documentation lands as a
`docs/model-setup.md` section with no standalone guide.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert now uses **ZCode** — a Z.AI GLM-powered desktop coding agent — as a third daily coding
tool on Windows, alongside Claude Code and Codex. When a Windows machine is set up by
ai-devops, Claude and Codex come out fully managed: verified presence, managed skills,
global instructions, MCP servers wired through the 1Password secret launchers, safety hooks,
doctor checks, transcript backup, and a governed headless wrapper that other sessions can
call for reviews and delegation. ZCode today gets **none** of that. Its only ai-devops
integration is the blocker-watch wake harness (already shipped).

When this plan is done, a Windows machine rebuilt by `bootstrap-windows-dev.ps1` +
`setup-machine.ps1` gives ZCode the same managed treatment Claude and Codex receive, and a
session in any tool can drive ZCode headlessly through one governed wrapper with honest
failure modes — so that:

- ZCode's skills, global instructions, MCP servers, and hooks are **installed and
  reconciled by the toolkit**, not hand-copied, and survive re-runs without drift.
- Secrets reach ZCode's MCP servers the same way they reach Claude and Codex — through the
  shared `mcp-launch.cmd` 1Password launcher — never as plaintext in config files.
- `bin/ai-devops doctor` and `verify-windows-dev.ps1` tell the truth about ZCode
  (installed? logged in? config valid? MCP present? hooks enabled?).
- ZCode session transcripts can be backed up to the private transcripts repository AND
  mined by direct SQL query — better than the Claude/Codex JSONL-mining approach,
  because ZCode's store is already relational.
- **No ZCode-based reviewer is ever built.** ZCode's engine is GLM-5.3 and the owner's
  standing rule is that GLM never reviews GLM-orchestrated work. GLM reviewer capacity
  for Claude- and Codex-orchestrated work continues through the existing `glm` OpenCode
  wrapper, which this plan does not touch.

**If any step below conflicts with this goal, the goal wins — stop and flag the conflict.**

## 2. What this application is

**ai-devops** ([`popcre/ai-devops`](https://github.com/popcre/ai-devops), local canonical
checkout `C:\repos\ai-devops`) is Albert Hazan's public, restore-from-zero toolkit for a
multi-model AI coding workflow. It contains Bash and PowerShell commands under `bin/`,
tests under `tests/`, machine setup scripts, skills under `skills/`, templates, and
operating documentation. It is not a hosted application; **installation is its deployment
mechanism** (see [`docs/deployment.md`](docs/deployment.md)).

It manages two Windows development machines (and Ubuntu servers, out of scope here):

- **edge-dev** — the machine this plan is written on; ZCode is installed and in daily use here.
- **al8960ofc** — the other established Windows box (referred to as 4837 in some docs).

The clients it manages today: **Claude Code** (CLI, winget `Anthropic.ClaudeCode`),
**Claude Desktop** (MSIX app), **Codex** (desktop app + standalone CLI under
`~/.codex/packages/standalone/current/bin`), plus reviewer/implementer CLIs Grok Build,
Kimi Code, Qwen Code, Gemini, GLM (via OpenCode), Muse, DeepSeek.

**ZCode** is the third interactive client. It is an Electron desktop application installed
machine-wide at `C:\Program Files\ZCode` (observed desktop ProductVersion `3.12.3.7463`).
Its agent/CLI core is a Node bundle at `C:\Program Files\ZCode\resources\glm\zcode.cjs`
(observed CLI version `0.16.5`), which the app runs as
`ELECTRON_RUN_AS_NODE=1 ZCode.exe …\zcode.cjs <args>`. It has no `zcode` command on PATH
today. It authenticates through Z.AI OAuth (`zcode login`) and defaults to the **GLM-5.3**
model via Albert's Z.AI coding-plan subscription. Note the two version numbers (desktop app
and CLI core) — both must be recorded when qualifying a build.

## 3. What triggered this work

Albert's request, 2026-09-17 (this session): *extend what ai-devops does for Claude for
Windows and Codex for Windows to ZCode for Windows.*

The gap is concrete. ZCode is already wired into exactly one ai-devops surface — the
blocker-watch wake harness (`bin/ai-blocker-watch` detects `ZCODE_SESSION_ID` first of the
three harnesses; `config/blocker-watch.json` ships a full `zcode` wake argv) — while every
other surface (skills sync, global instructions, MCP, hooks, doctor, transcripts, wrapper,
reviewer registration) treats it as nonexistent. Meanwhile the machine carries hand-made,
unmanaged state for ZCode: an NTFS junction `~/.zcode/skills` → `~/.claude/skills` and a
junction `~/.agents/skills` → `~/.codex/skills`, both created outside the toolkit, plus no
`~/.zcode/cli/config.json` at all (ZCode runs on defaults). Hand-made state is exactly what
this toolkit exists to replace: it does not survive a machine rebuild, it cannot be
reconciled, and nobody can tell managed from unmanaged content.

## 4. Scope — in and out

**IN this plan (Windows only):**

- ZCode presence/install policy in the toolkit (`setup-machine.ps1` presence probe,
  optionally the winget DSC file if a real package exists — **no**
  `provider-cli-versions.json` entry until something consumes it, D5).
- A `zcode` launcher on PATH (shims) and the governed headless wrapper `bin/ai-zcode`
  (+ `machine-tools.tsv` row, `.cmd` stub, doctor subcommand).
- Managed skills: a new `skills/zcode/` client tree, installed to a real managed
  `~/.zcode/skills` directory, replacing the hand-made junction.
- Global instructions: `templates/system/AGENTS-global-zcode.md` seeded to
  `~/.zcode/AGENTS.md` (seed-only), with `ai-adopt-globals` support.
- MCP wiring: `bin/configure-zcode-mcps.ps1` writing `~/.zcode/cli/config.json`
  → `mcp.servers` from the shared catalog, 1Password entry through `mcp-launch.cmd`.
- Hooks: registering the existing completion-honesty hook under ZCode's `hooks` config
  with `hooks.enabled: true` (completion hook only — no memory hook, §7.11).
- Transcript backup + mining: a `zcode-transcript-backup` skill that copies ZCode's
  SQLite + rollout-JSONL session store to the private transcripts repository and mines
  it by SQL query against the copy.
- Doctor and verification: `bin/ai-devops` doctor checks and `verify-windows-dev.ps1`.
- Documentation and tests for all of the above.

**NOT in this plan:**

- **Ubuntu/Linux ZCode support.** ZCode support here is Windows-only; `install.sh`
  stages, `bin/ai-install-skills` (bash installer), and Ubuntu symlinks are untouched
  except where a parity test demands a documented exception (see Step 4).
- **Any ZCode-based reviewer, ever.** Owner ruling 2026-09-17: *"I never want GLM
  reviewing GLM code."* ZCode's engine is GLM-5.3, so a ZCode reviewer is GLM reviewing
  GLM-orchestrated work by construction — permanently out of scope, not merely deferred.
  No wrapper, no registry entry, no `ai-review-lifecycle` provider. GLM reviewer capacity
  for Claude- and Codex-orchestrated work continues through the existing `glm` OpenCode
  wrapper, which this plan does not touch.
- **A `zcode-config-repair` skill.** Killed by the owner 2026-09-17: ZCode ships its own
  `zcode-guide` plugin documenting exactly that content (it is the source of this plan's
  config facts); a second copy can only drift out of date.
- **Porting Claude's memory-index hook.** ZCode has its own native memory feature
  (`memoryEnabled`, currently `false` in `~/.zcode/v2/setting.json`); the correct path is
  enabling that (owner decision, one setting), not indexing ZCode edits into a foreign
  store nobody reads.
- **Making ZCode an orchestrator stage engine** (`ai-model-call` / `ai-run-task` roles).
- **ZCode memory sync** to the private memory repository (ZCode's `memoryEnabled` is
  `false` in `~/.zcode/v2/setting.json`; enabling and syncing it is a separate decision).
- **Managing ZCode's own auto-update** (electron-updater self-manages; its config points at
  a placeholder URL — leave it alone) or editing anything inside `C:\Program Files\ZCode`
  (never touch `app.asar` or bundled resources).
- **ZCode plugin/marketplace management** beyond leaving the official marketplace as-is.
- **Re-pointing the `~/.agents` junction tree** for other tools (only the ZCode-facing
  decision in §8 is in scope).
- Any change to Claude's, Codex's, or any other client's configuration.

## 5. Current state of the code

Everything in this section was verified on 2026-09-17 against `origin/main` at `c9a92ce9`
and the live machine `edge-dev`. Line numbers are that commit's.

**Shipped ZCode support (the only piece that exists):**

- `bin/ai-blocker-watch:18,24,97-100` — `ZCODE_SESSION_ID` env detection (checked FIRST,
  before `CODEX_THREAD_ID` and `CLAUDE_CODE_SESSION_ID`); `--harness zcode` accepted.
- `bin/ai-blocker-watch:170-177` — `{zcode_builtin}` placeholder resolves the newest
  `~/.zcode/v2/runtime/provider/*/*/*/zcode-builtin.json` at wake time (cygpath-mixed on
  Windows), plus `{home}` substitution.
- `config/blocker-watch.json:29-43` — full shipped `zcode` wake argv:
  `env ELECTRON_RUN_AS_NODE=1 ZCODE_BUILTIN_PROVIDER_CONFIG_FILE={zcode_builtin}
  ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG_FILE=C:/Program Files/ZCode/resources/config/provider/zcode-builtin.json
  ZCODE_PERSONAL_PROVIDER_CONFIG_FILE={home}/.zcode/v2/provider_config.json
  C:/Program Files/ZCode/ZCode.exe C:/Program Files/ZCode/resources/glm/zcode.cjs
  --resume {session} --cwd {cwd} --prompt {prompt}`. Its comment records that ZCode
  headless needs a one-time `zcode.cjs login`.
- `tests/test-ai-blocker-watch.sh:36-39` — asserts the shipped config has `claude`,
  `codex`, AND `zcode` harnesses (this test must stay green).
- `templates/system/CLAUDE-global.md:346` and
  `templates/system/AGENTS-global-codex.md:230` — global instructions already tell
  sessions the watcher "resumes this exact session (Claude, Codex, or ZCode)".
- Open branch `feat/blocker-watch-coverage-549` (commit `a9cb0ea0`, expected to merge)
  extends blocker-watch with a ZCode login-URL-truncation note (Windows `start` truncates
  at `&`) and portable scheduling. **Rebase onto main before starting if it has landed.**

**Everything else — absent.** No `zcode` in `.config/configuration.winget`
(`:57-64` pins ClaudeCode `Anthropic.ClaudeCode` 2.1.229 and CodexDesktop
`9PLM9XGG6VKS`), none in `config/provider-cli-versions.json` (grok pinned `1.0.13`;
kimi/qwen presence-only `null`), no `bin/ai-zcode*`, no row in
`config/machine-tools.tsv`, no `skills/zcode/` tree (trees today:
`skills/claude/` 11 skills, `skills/codex/` 11, `skills/shared/` 37), no ZCode template in
`templates/system/`, no ZCode checks in `bin/ai-devops` doctor or
`bin/verify-windows-dev.ps1` (`:13` checks `claude`, `:15-21` the CodexDesktop
AppxPackage), no `zcode` provider in `config/reviewer-registry.json`, and
`bin/ai-review-lifecycle:34` enumerates
`claude|codex|deepseek|gemini|glm|grok|kimi|muse|qwen` — no `zcode`.

**The Claude/Codex pattern this plan replicates (the precedent machinery):**

- `bin/setup-machine.ps1` — Codex portable config seed-only copy at `:131-140`; MCP
  catalog `$McpServerCatalog` `:391-524`; per-client membership lists
  `$ClaudeCodeMcpNames = @("1password","codex-cli")` `:527` and the broader
  `$ClaudeDesktopMcpNames` `:528`; `Select-McpServers` `:530,538-539`; Claude Desktop
  config write `:622-664`; Codex PATH repair + live sandbox write probe `:677-714`;
  machine launcher generation `:719-726`; Claude Code MCP into `~/.claude.json` with
  stale-block strip from `~/.claude/settings.json` `:769-813`; Codex MCP wiring via
  `bin/configure-codex-mcps.ps1` `:881-920`.
- `bin/install-ai-devops-windows.ps1` — `Assert-NoSharedSkillCollisions` `:164`;
  `Install-SkillFolder` `:359` (5-state reconciliation — absent/identical/update/
  local-edits/unmanaged — via `.ai-devops-managed` hash markers, quarantine to
  `~/.claude/skills-quarantine/`, orphan pruning `:438`); the four install calls
  (claude, shared→claude, codex, shared→codex) `:572-605`; `Install-GlobalFile` `:493`
  seeding `CLAUDE-global.md` → `~/.claude/CLAUDE.md` and `AGENTS-global-codex.md` →
  `~/.codex/AGENTS.md` seed-only `:608-611`; login notes `:628-690`.
- `bin/configure-codex-mcps.ps1` — the TOML writer precedent: hand-rolled segmenter
  `:85-96`, `New-McpBlock` `:55-83`, timestamped `.aidevops-<stamp>.bak` backup, stale
  entry removal, preservation of foreign content. Tests:
  `tests/test-configure-codex-mcps.ps1`.
- `bin/ai-claude-review` — the JSON-config reviewer precedent: pinned
  `CLAUDE_REVIEW_CMD` `:20`, `validate_command()` `:34-43`, `doctor [--live]` `:45-55`,
  `## Verdict` parsing `:140-141`, reports to `.ai/reviews/<provider>-<mode>-<runid>.md`,
  shared `ai-review-sandbox`/`ai-review-packet`/`ai-review-lifecycle` machinery.
- `bin/ai-codex-review` — the TOML-world twin (`CODEX_CMD` `:21`, validator `:54-88`).
- `bin/install-windows-ai-provider-clis.ps1` — installer catalog `:171-196`,
  SHA256-pinned installers `Invoke-PinnedProviderInstaller` `:134-158`, versions from
  `config/provider-cli-versions.json`.
- `bin/ai-install-completion-check-hook` / `bin/ai-install-memory-hook` — register the
  two hooks into `~/.claude/settings.json` (jq merge, strictly additive); the hook
  scripts live in `~/.config/ai-devops/`.
- `bin/ai-adopt-globals:66,165-166` — machine-section-preserving adoption of the Claude
  and Codex globals from the same templates.
- `config/reviewer-registry.json` — `providers.<name>.registry_state` + `reason`; kimi
  shows the `absent` precedent ("re-entry requires a reviewed registry change backed by a
  live well-formed verdict").
- `skills/claude/claude-transcript-backup/SKILL.md` — transcript-backup precedent, gated
  by `bin/ai-transcript-destination-check`, destination
  `claude_chats/<machine>/` in the private repo `u2giants/ai-devops-transcripts`.

**Live machine state (edge-dev, user `ahazan`) — the unmanaged baseline to migrate:**

- `C:\Program Files\ZCode\ZCode.exe` installed; no `zcode` on PATH anywhere.
- `~/.zcode/cli/config.json` **does not exist** (ZCode runs on defaults — no user MCP
  servers, no hooks, no plugin overrides).
- `~/.zcode/AGENTS.md` does not exist.
- `~/.zcode/skills` is an NTFS **junction** → `C:\Users\ahazan\.claude\skills`
  (hand-made). `~/.agents/skills` is a separate junction → `~/.codex/skills`.
- ZCode is authenticated (`~/.zcode/v2/credentials.json` exists with Z.AI OAuth keys);
  default model selection `GLM-5.3` under `account:zai-individual-coding-plan` in
  `~/.zcode/v2/provider_config.json`.
- Session store: `~/.zcode/cli/db/db.sqlite` (+wal/shm), raw model I/O
  `~/.zcode/cli/rollout/model-io-sess_<uuid>.jsonl`, tool-call logs
  `~/.zcode/cli/exec/sess_<uuid>/`.
- Official plugins marketplace cache under `~/.zcode/cli/plugins/cache/zcode-plugins-official/`
  (includes the `zcode-guide` plugin, whose skills are the authoritative local
  documentation of ZCode's config surface).

Nothing in this plan has been started; no ZCode branch exists. Issue #558 was filed
2026-09-17 to carry this work.

## 6. Key findings and root cause

There is no defect: ZCode was never onboarded. The root cause of the gap is that ZCode
arrived as a desktop app rather than a CLI, so it never passed through the
provider-onboarding pattern (issue #31 for Kimi, #251 for Grok) that adds a version-policy
entry, an installer row, a wrapper, a TSV row, a skill, tests, and doctor wiring. The
blocker-watch work (#546/#549) was the first time ZCode's headless surface was qualified,
and it proved the launch pattern this plan reuses.

Non-obvious discoveries that cost real investigation (all verified 2026-09-17; the
ZCode-side facts come from the installed `zcode-guide` plugin skills at
`~/.zcode/cli/plugins/cache/zcode-plugins-official/zcode-guide/0.1.0/skills/` and from
probing the CLI directly):

1. **ZCode has a complete headless CLI surface.** `ELECTRON_RUN_AS_NODE=1 ZCode.exe
   …\zcode.cjs --help` reports `zcode 0.16.5` with: `-p, --print` (positional one-shot
   prompt), `--prompt <text>`, `--mode build|edit|plan|yolo` (**default `yolo` for
   `--prompt` — a reviewer MUST pin `--mode plan` or an allowlist**), `--allowed-tools` /
   `--disallowed-tools`, `--max-turns <n>`, `--json`, `--cwd <path>`, `--resume <sessionId>`,
   `-c/--continue`, `--settings <path>` (isolated config for a run), `--no-browser`
   (print the OAuth URL instead of opening it), `--verbose`; subcommands
   `app-server`, `commands`, `doctor`, `login`, `logout`, `plugins`, `skills`, `tui`,
   `version`. This is everything `ai-claude-review` needs from its Claude counterpart.

2. **User configuration file:** `~/.zcode/cli/config.json` holds MCP servers
   (`mcp.servers`, nested), hooks (`hooks`), plugin enable/disable, and skill/command
   overrides. Workspace config lives in `<repo>/.zcode/config.json` or `<repo>/zcode.json`.
   `~/.agents/mcp.json` (top-level `mcpServers`) is a **fallback only** — read for a scope
   only if that scope's `.zcode` file defines zero servers.

3. **Global instruction file:** `~/.zcode/AGENTS.md` is the user-scope instruction file,
   injected before the workspace `AGENTS.md` (workspace can narrow user defaults). This is
   the direct analog of `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.

4. **MCP schema is STRICT — an unknown key silently drops the server.** stdio servers:
   `command` (string), `args[]`, `cwd`, `env`, `enabled`, `timeoutMs`; http/sse: `url`,
   `headers`, `enabled`, `timeoutMs`. No `type` needed (inferred), but mixing shapes kills
   the entry. `${...}` template expansion happens **only for plugin servers** —
   config-file servers need absolute paths. Default timeout 30000 ms. All scopes
   auto-connect (trusted) at session start. Same-named server precedence:
   CLI override → environment → user → workspace → system.

5. **Hooks exist, mirror Claude's contract, and are OFF by default.** Exactly seven
   events — `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`,
   `PostToolUse`, `PostToolUseFailure`, `Stop` (no `Notification`/`SubagentStop`/
   `PreCompact`). Config shape: `hooks: { enabled: true, events: { <Event>: [ { matcher?,
   hooks: [...] } ] } }` and **config-file hooks never run unless `hooks.enabled: true`**.
   Matcher is a case-sensitive regex over the tool name (`bash` will not match `Bash`);
   aliases `Task`↔`Agent` and `Write`/`Edit`←`ApplyPatch` exist, so the memory hook's
   `Write|Edit` matcher survives ZCode's ApplyPatch. Hook types: `command` (shell string;
   `timeout` in SECONDS, `timeoutMs` ms) and `process` (exe + `args[]`, no shell — the
   portable choice on Windows). Exit codes 0 pass / 2 block. Template vars
   `${CLAUDE_PROJECT_DIR}`/`${ZCODE_PROJECT_DIR}`, `${CLAUDE_SESSION_ID}`.

6. **Skills discovery:** configured roots → `~/.zcode/skills` → `~/.agents/skills` →
   workspace `.zcode/skills` → workspace `.agents/skills` → enabled plugins; first
   same-named skill wins. Skill format is identical to Claude's (directory + `SKILL.md`
   with `name`/`description` frontmatter). Plugins namespace their skills
   (`plugin:skill`).

7. **Auth and transcripts are unlike Claude/Codex.** Auth is Z.AI OAuth stored in
   `~/.zcode/v2/credentials.json` (flat JSON key-value store; `zcode login` performs it;
   `--no-browser` prints the URL — relevant because Windows auto-open truncates login
   URLs at `&`, per the blocker-watch #549 finding). Sessions live in **SQLite**
   (`~/.zcode/cli/db/db.sqlite`) plus per-session raw model I/O
   (`~/.zcode/cli/rollout/model-io-sess_<uuid>.jsonl`), not per-project JSONL folders.

8. **Two version numbers, and self-updates.** Desktop `3.12.3.7463` vs CLI core `0.16.5`;
   the app self-updates via electron-updater (its config currently points at a
   placeholder `http://localhost:8081` URL — do not rely on or "fix" it). Consequence:
   version pinning is unreliable; presence-only policy (kimi/qwen style) is correct, and
   the wrapper must re-verify the CLI contract per qualification, not trust a pin.

9. **The blocker-watch argv is the proven provider-env assembly.** Wakes pass
   `ZCODE_BUILTIN_PROVIDER_CONFIG_FILE` (newest runtime copy),
   `ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG_FILE`, and
   `ZCODE_PERSONAL_PROVIDER_CONFIG_FILE` before launching `zcode.cjs`. Whether plain
   headless runs need these is UNVERIFIED — `--help` works without them; Step 1 must
   prove which env set headless `-p` actually needs for auth/model selection, and the
   shims/wrapper then mirror the proven set.

## 7. Approaches considered and REJECTED

1. **Hand-editing `~/.zcode/cli/config.json` per machine (no writer script).** Rejected:
   the exact failure mode `configure-codex-mcps.ps1` exists to prevent — unreconciled
   drift, no backups, retired entries that never leave, and JSON corruption that makes
   ZCode silently drop every MCP server (strict schema). Every managed write goes through
   a tested idempotent writer with timestamped backups.

2. **Keeping the `~/.zcode/skills` junction to `~/.claude/skills` as the managed
   mechanism.** Rejected: it is invisible to the installer's 5-state reconciliation,
   cannot carry ZCode-specific skills, leaks Claude-only skills (e.g.
   `claude-transcript-backup`) into ZCode, and survives no rebuild. The junction was a
   reasonable hand-made shortcut; it is not managed state. (Migration FROM it is Step 4;
   junction removal must be non-recursive.)

3. **Adding a winget DSC entry for ZCode before verifying a package exists.** Rejected as
   an assumption: no winget package for this app has been confirmed. Step 2 must discover
   the real channel (winget catalog, vendor installer with stable URI, or
   presence-check-only like Codex Desktop's MS Store entry) and only then wire it.

4. **Exact version pinning in `provider-cli-versions.json`.** Rejected: the desktop app
   self-updates and carries two version numbers; a pin would either strand machines on
   stale builds or fail closed on every auto-update. Revised 2026-09-17 after the Grok
   4.6 consultation: even the presence-only entry is deferred — nothing consumes it,
   and the fully managed clients (Claude, Codex) are not in that file either (D5).

5. **Reusing `bin/ai-glm` (OpenCode harness) for ZCode because both run GLM.** Rejected:
   different harness, different CLI contract, different failure modes; the wrapper
   STEP 0 qualification is per-build and per-binary. The registry keeps `glm` (OpenCode)
   and `zcode` as distinct providers.

6. **Registering ZCode as a `registered` reviewer on landing.** Rejected: kimi precedent —
   membership requires a live well-formed verdict, and the registry is a guard ("never
   flip a provider to registered to make an allocation succeed"). The entry lands
   `absent` with the promotion path written in its reason.

7. **Driving ZCode MCP servers without the 1Password launcher (plaintext env tokens).**
   Rejected: same rule as every other client; the `1password` entry routes through
   `~/.config/ai-devops/mcp-launch.cmd` with `op://` references only.

8. **Editing ZCode's bundled resources or intercepting its updater.** Rejected outright:
   `app.asar` and everything under `C:\Program Files\ZCode\resources\` are vendor bytes.

9. **A ZCode reviewer wrapper (was draft Step 9).** Rejected **permanently** by owner
   ruling 2026-09-17: *"I never want GLM reviewing GLM code."* ZCode's engine is
   GLM-5.3, so a ZCode reviewer would be GLM reviewing GLM-orchestrated work by
   construction. The draft's `registry_state: "absent"` treatment was still speculative
   build-out of a provider that could never be promoted; the whole step is removed.
   This rejection also creates a duty recorded in D6: ZCode-orchestrated shared-db work
   must exclude the `glm` reviewer via the orchestrator marker's engine declaration.

10. **A `zcode-config-repair` skill.** Killed by owner instruction 2026-09-17. ZCode
    ships its own `zcode-guide` plugin (installed by default) that documents config
    locations, the strict MCP schema, and hooks — the very facts in §6. Duplicating
    vendor-shipped docs violates the repo's "reuse before adding" rule and creates a
    second copy that silently drifts when ZCode updates.

11. **Porting Claude's memory-index hook to ZCode.** Rejected: the hook feeds Claude's
    memory model, while ZCode has native per-project memory
    (`~/.zcode/cli/memories/projects/`) gated by its own `memoryEnabled` setting, today
    `false`. Indexing ZCode edits into a foreign store before ZCode's own memory is even
    enabled would be machinery with no reader. Enable the native feature instead
    (the owner enabled it on 2026-09-17; see §13 open question 3, settled).

## 8. Design decisions already made (2026-09-17)

**LOCKED — do not relitigate:**

- **D1 (managed real skills directory).** ZCode gets a real managed `~/.zcode/skills`
  installed from `skills/zcode/` + `skills/shared/` by
  `install-ai-devops-windows.ps1`, exactly as Claude and Codex do. The hand-made junction
  is migrated away in the same change. The no-collision rule
  (`Assert-NoSharedSkillCollisions`) extends to the zcode tree.
- **D2 (seed-only global instructions).** New `templates/system/AGENTS-global-zcode.md`
  seeded to `~/.zcode/AGENTS.md` only when absent (`Install-GlobalFile` semantics);
  replacement goes through `bin/ai-adopt-globals` with machine-section preservation.
- **D3 (a dedicated PowerShell JSON writer for MCP).** New
  `bin/configure-zcode-mcps.ps1` using the shared atomic-write helpers
  (`bin/windows-json-file.ps1`), emitting ONLY canonical strict-schema keys, absolute
  paths, explicit `timeoutMs`, timestamped backups, idempotent merge, stale managed-entry
  removal, preservation of foreign-but-valid user entries.
- **D4 (wrapper-first headless access).** `bin/ai-zcode` is the only supported way for
  any session to drive ZCode headlessly (Kimi/Grok precedent). Raw `zcode` shims exist
  for interactive convenience and for the wrapper's own use.
- **D5 (no version-policy entry until a consumer exists — revised 2026-09-17).**
  `provider-cli-versions.json` is a paid-work pin, not a tool catalog: Grok is the exact
  pin; kimi/qwen rows exist because the Windows provider installer's
  `Get-RequiredProviderVersion` reads them; Claude and Codex — the fully managed
  clients ZCode is joining — are absent from it. ZCode presence lives in
  `setup-machine.ps1` and `ai-zcode doctor`; a `zcode` key is added only in the same
  PR as its first real consumer. (Grok 4.6 consultation concurred; original draft's
  presence-only entry was unlocked.)
- **D6 (no ZCode reviewer — permanent).** Owner ruling 2026-09-17: GLM never reviews
  GLM-orchestrated work, and ZCode's engine is GLM-5.3. No ZCode reviewer wrapper,
  registry entry, or lifecycle provider is built — now or later. **Duty this ruling
  creates elsewhere:** when a ZCode session orchestrates shared-db structural work, the
  orchestrator marker must declare engine `glm` so the independence filter excludes the
  glm reviewer. Verified 2026-09-17 against
  `u2giants/shared-db/scripts/manage-migration-author-lanes.mjs`: the filter
  (`reviewersForOrchestrator`, ~line 553) excludes only rows whose `orchestratorEngine`
  equals the marker's declared engine, and the `glm-5.3` reviewer row (~line 274) carries
  **no** `orchestratorEngine` at all — so nothing excludes glm today, and the marker
  vocabulary has no `zcode` engine. Closing that gap is shared-db work under its own
  issue (§13, open question 2); this plan only records it.
- **D7 (Windows-only).** No `install.sh`/Ubuntu changes except a documented parity-test
  exception if `tests/test-installer-parity.sh` demands one.
- **D8 (completion hook only; memory is native).** Only the completion-honesty hook is
  ported — its registration under ZCode's `hooks.events` with `hooks.enabled: true` is
  new; the script itself is reused unchanged. ZCode's memory is its own native feature,
  **enabled by the owner on 2026-09-17**, and **no** Claude memory-index hook is ported
  (§7.11).

**OPEN — implementer's judgment within the stated criteria:**

- **D9 (install route).** Winget DSC resource, pinned vendor installer in
  `install-windows-ai-provider-clis.ps1`, or presence-check-only. Criteria: only add a
  winget ID that `winget search` positively confirms; only add an installer row if a
  stable vendor URI + SHA256 workflow exists; otherwise presence-check with an honest
  "install ZCode manually" doctor message (Codex Desktop precedent: the toolkit checks
  the MS Store app, it does not vendor its installer).
- **D10 (ZCode MCP membership list).** Recommended default mirrors Claude Code's minimal
  set — `@("1password","codex-cli")` — expanding later by registry change. Criteria: the
  default must not include servers whose value is unproven for a coding agent; expansion
  is a one-line membership change later.
- **D11 (`~/.agents/skills` junction disposition).** Leave as-is initially (ZCode
  documents `.agents` as the cross-tool convention and dedups first-wins). If Step 4's
  testing shows the codex-view leak via `.agents` confuses ZCode sessions, a follow-up
  may repoint `~/.agents/skills` to a real shared-only root — separate change, separate
  tests, not required for this plan's done.
- **D12 (hook registration mechanism).** Extend the existing
  `ai-install-completion-check-hook` with a `--client zcode` mode, or add one
  `bin/ai-install-zcode-hooks`. Criteria: one command a dotfiles sync can call
  idempotently; `--check` mode required.
- **D13 (raw `zcode` shim env assembly).** Mirror the blocker-watch provider-env argv by
  default (it is the proven-working assembly) unless Step 1 proves plain invocation
  sufficient; record the answer in the facts file either way.

## 9. The plan — numbered, ordered steps

Work in an isolated worktree cut from `origin/main`
(`git worktree add /c/repos/ai-devops-worktrees/<slug> -b <branch> origin/main`), one
branch per phase-cluster or one branch for the whole plan — implementer's choice, but
each PR must pass its task-gate class (see §11). Re-run
`ai-task-gates start --class <class>` per PR with the honest class.

### Phase A — Foundations (Steps 1–3)

**Step 1. Freeze the ZCode Windows baseline (qualification facts).**
Create `tests/verification/zcode-windows-2026-09-17/README.md` (date-directory precedent:
Kimi's `tests/verification/kimi-windows-2026-08-18/`) recording, each with the exact
command that reproduces it:

- Desktop ProductVersion and CLI-core version (`--help` banner) and their discovery
  commands.
- Install-source discovery: `winget search` result (or its confirmed absence), the
  registry uninstall key under
  `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`, and the contents listing
  of `C:\Program Files\ZCode` — enough to decide D9.
- Headless proof: a bounded `ELECTRON_RUN_AS_NODE=1 …zcode.cjs -p "Reply with the single
  word OK" --max-turns 2 --json` run WITHOUT the provider env vars, and one WITH the
  blocker-watch env set (`config/blocker-watch.json:29-43`). Record which authenticated
  and which model answered — this decides D13 and the wrapper's env assembly.
- Write-denial proof: the same one-shot with `--mode plan` asked to create a file, and
  with `--allowed-tools "Read Grep Glob"`; confirm no file appears (decides the
  wrapper's safe-mode pinning).
- The actual stdin payload shape ZCode feeds hooks (run with a probe hook registered in
  a THROWAWAY `--settings` config — never the user config — capture one
  `PostToolUse`/`Stop` payload). Confirms D8's compatibility assumption.
- The `--json` output document shape for headless runs (keys the wrapper will parse).
- Inventory of the unmanaged state to migrate (junctions, absent config files) with
  `cmd /c dir /AL` output.

*Dependencies:* none. *Verification gate:* the facts file exists, every claim carries its
reproducing command, and a second session on edge-dev can re-run three of them with
identical results. Nothing else in the plan starts before this lands.

**Step 2. Install policy and presence checks.**
No `provider-cli-versions.json` entry — that file is a paid-work pin, not a tool
catalog, and the fully managed clients (Claude, Codex) are not in it either; add a
`zcode` key only in the same PR as the first real consumer (D5, Grok 4.6 consult
2026-09-17). Apply D9's outcome: a winget DSC resource in `.config/configuration.winget`
only if Step 1 positively identified the package; else a presence check. Add the
presence probe to `bin/setup-machine.ps1` (near the kimi/qwen presence notes
`:727-752`): resolve `C:\Program Files\ZCode\ZCode.exe` + `resources\glm\zcode.cjs`,
warn honestly when absent, and never fabricate an install. If (and only if) a stable
vendor installer exists, add the catalog row to
`bin/install-windows-ai-provider-clis.ps1` with SHA256 pinning per
`Invoke-PinnedProviderInstaller` `:134-158`.

*Dependencies:* Step 1 (D9 decided). *Verification gate:* on edge-dev, a `pwsh`
invocation of the presence probe reports ZCode present with both version numbers; with
the app path renamed in a `-TestOnly` fixture, it reports absent and exits non-zero
without touching anything.

**Step 3. Launcher shims + `bin/ai-zcode` governed wrapper.**
Create `bin/ai-zcode` (Bash, Git-Bash-compatible) — the only supported headless
ZCode driver, modeled on the Kimi/Grok wrapper essentials, not their full surface:

- Subcommands: `ask "<prompt>"` (one-shot headless, `--json` parsed, bounded
  `--max-turns`), `doctor [--live]` (presence, versions, login state via
  `~/.zcode/v2/credentials.json` **existence only — never read or print values**, config
  schema sanity, MCP entries, hooks-enabled state), and `version`. No session
  management in v1; `--resume` passthrough may be added when a need is real.
- A "STEP 0 VERIFICATION" header block (Kimi precedent `bin/ai-kimi:31-60`) recording
  the qualified build, the exact flag contract, the env assembly from Step 1/D13, and
  the `--json` keys parsed.
- Command validation in the wrapper's spirit of `bin/ai-claude-review:34-43`: the
  internal argv is pinned; env overrides refused where they would weaken bounds
  (`--mode` never `yolo` from caller input; `--max-turns` ceiling enforced).
- Binary resolution mirroring `Get-CodexBin`'s caution (`bin/setup-machine.ps1:92-108`):
  resolve the app path once, fail closed with the exact missing path.
- **No state directory and no `--resume`** (Grok 4.6 consult 2026-09-17): ZCode
  persists sessions in its own SQLite store and blocker-watch already owns interactive
  `--resume`; an empty wrapper state dir has no owner and no retirement path. If a
  later feature needs state, create it in that feature's PR.
- Add the `machine-tools.tsv` row
  (`ai-zcode  bin/ai-zcode  bash+cmd  none  zcode  install-machine-tools.ps1`) and the
  `bin/ai-zcode.cmd` Git-Bash stub.
- Raw shims: `setup-machine.ps1` step (near the Codex PATH repair `:677-714`) writes
  `~/.local/bin/zcode` + `zcode.cmd` that exec the resolved app argv (D13 env set),
  prepends `~/.local/bin` if needed — giving PATH parity with `claude`/`codex`.

*Dependencies:* Steps 1–2. *Verification gate:* `tests/test-ai-zcode.sh` (Step 10 list)
passes offline against a mock `zcode.cjs`; live on edge-dev, `ai-zcode doctor` exits 0
with login state reported, `ai-zcode ask "Reply OK"` returns within bounds, and a bare
`zcode --version` works from a fresh Git Bash window.

**— context cut point: Phase A complete; update the STATUS table with artifacts before
continuing —**

### Phase B — Managed configuration (Steps 4–7)

**Step 4. Managed skills: `skills/zcode/` tree + installer + junction migration.**
`skills/zcode/` starts **empty** — its first occupant is the transcript skill from Step 8.
(No `zcode-config-repair` skill: the vendor-shipped `zcode-guide` plugin already documents
ZCode's config surface, and duplicating it would only drift — §7.10.) Extend
`bin/install-ai-devops-windows.ps1`:

- Junction migration BEFORE install: if `~/.zcode/skills` is a reparse point
  (`(Get-Item …).LinkType -eq 'Junction'`), remove it NON-recursively
  (`cmd /c rmdir` — a recursive delete would destroy the Claude skills it points at),
  then create the real directory. Record the migration in the installer output.
- A new `Install-SkillFolder` call (`skills/shared` → `~/.zcode/skills`) alongside the
  existing four (`:572-605`), plus a `skills/zcode` call that activates when Step 8 adds
  the tree's first skill (skip gracefully while the source dir is absent); the 5-state
  reconciliation, `.ai-devops-managed` markers, quarantine, and orphan pruning then
  apply to ZCode unchanged.
- Extend `Assert-NoSharedSkillCollisions` coverage to the zcode tree (`:164`).
- Extend `bin/ai-install-manifest` to scan `~/.zcode/skills` markers alongside
  `~/.claude/skills` and `~/.codex/skills` (`:47`).
- Check `tests/test-installer-parity.sh`: if it enforces bash/PowerShell installer
  equality, add the documented Windows-only exception for zcode (D7) rather than
  touching the Ubuntu installer.

*Dependencies:* Step 1 (junction inventory). *Verification gate:*
`tests/test-install-ai-devops-windows.ps1` (extended with a junction-fixture migration
case and a zcode-target case) passes; on edge-dev, a real installer run migrates the
junction without deleting any Claude skill (verify `~/.claude/skills` count before/after),
leaves a real `~/.zcode/skills` with managed markers, and `zcode skills list` (or the
session's skill listing) shows the shared skills.

**Step 5. Global instructions: template + seeding.**
Create `templates/system/AGENTS-global-zcode.md` — start from
`templates/system/AGENTS-global-codex.md` and adapt the client-specific sections to
ZCode (its config paths, `zcode` command, hook/permission behaviors, the strict-schema
warning, and the existing "watcher resumes this exact session" wording already at
`CLAUDE-global.md:346`/`AGENTS-global-codex.md:230`). Wire `Install-GlobalFile` seeding
in `install-ai-devops-windows.ps1` (after `:608-611`), and extend
`bin/ai-adopt-globals` (`:66,165-166`) to adopt the zcode global with the same
machine-section preservation.

*Dependencies:* none inside Phase B (parallelizable with Step 4). *Verification gate:*
against a temp `HOME` fixture, seeding creates `~/.zcode/AGENTS.md` only when absent; a
modified-file adoption backs up, replaces, and preserves a marked machine section;
`tests/test-install-ai-devops-windows.ps1` covers both.

**Step 6. MCP wiring: `bin/configure-zcode-mcps.ps1` + membership.**
New writer script (JSON sibling of `configure-codex-mcps.ps1`): build entries from the
shared catalog via a `$ZCodeMcpNames` membership list added to `bin/setup-machine.ps1`
next to `:527-528` (D10 default `@("1password","codex-cli")`), with ZCode-specific
transforms — `1password` routed through `~/.config/ai-devops/mcp-launch.cmd` (absolute
path; no `op://` value ever lands in the file, only the launcher), `codex-cli` with its
absolute exe and generous `timeoutMs` (mirror the Codex adjustments at
`:881-920`), explicit `timeoutMs` on every entry (default 30000 is too low for cold MCP
starts). The writer must: emit ONLY canonical keys (§6 finding 4 — an unknown key drops
the server), write atomically with `.aidevops-<stamp>.bak` backup, merge idempotently,
remove retired managed entries, and preserve foreign-but-valid user entries. Call it
from `setup-machine.ps1` as a new stage after the Codex MCP stage. Also seed
`hooks.enabled` is NOT this step's concern (Step 7) — the writer must merge into an
existing config without disturbing a `hooks` block it did not write.

*Dependencies:* Step 1 (schema facts). *Verification gate:*
`tests/test-configure-zcode-mcps.ps1` passes (fixtures: fresh config, existing foreign
server preserved, stale managed entry removed, unknown-key emission refused by
construction, backup created, idempotent second run is a no-op diff); live on edge-dev,
a `zcode` session (or `ai-zcode ask` with a tool probe) can list the connected servers
and `~/.zcode/cli/config.json` contains exactly the membership set with absolute paths.

**Step 7. Hooks: register the completion-honesty hook under `hooks.events`.**
Per D8 — completion hook ONLY (no memory hook; see §7.11). One idempotent installer
(extend the existing `ai-install-completion-check-hook` with a `--client zcode` mode, or
add `bin/ai-install-zcode-hooks`) that merges into `~/.zcode/cli/config.json`:

```json
{ "hooks": { "enabled": true, "events": {
    "UserPromptSubmit": [ { "hooks": [ { "type": "command",
      "command": "<absolute path> completion-check-hook", "timeoutMs": 30000 } ] } ],
    "Stop":         [ { "hooks": [ { "type": "command",
      "command": "<absolute path> completion-check-hook", "timeoutMs": 30000 } ] } ] } } }
```

(exact event set per what the Claude registration writes and Step 1's payload findings —
adjust if the script needs a shell wrapper on Windows, using the documented
`bash "<path>"` invocation form). Registration must set `hooks.enabled: true` (the
silent default-off trap) and merge additively without touching `mcp`. A `--check` mode
reports drift. Wire the installer into the dotfiles-sync skill's client steps
(`skills/claude/sync-dotfiles/SKILL.md` step-6 pattern) for zcode.

*Dependencies:* Steps 1 (payload facts) and 6 (config writer conventions). *Verification
gate:* on edge-dev, after registration, one `ai-zcode ask` session shows the hook fire
once per prompt; the ZCode daily-log (`~/.zcode/cli/log/zcode-*.jsonl`) records hooks
fired, not failed; `--check` exits 0 clean and 2 on a deliberately removed entry.

**— context cut point: Phase B complete —**

### Phase C — Workflow depth (Step 8; Step 9 removed 2026-09-17)

**Step 8. Transcript backup + SQL mining cookbook for the SQLite + rollout store.**
Albert mines Claude and Codex transcripts to find better ways of working and wants the
same for ZCode. ZCode's store is **better suited to mining than Claude/Codex JSONL**
because it is already relational — so do NOT convert it into a JSONL pile; query it.

Create `skills/zcode/zcode-transcript-backup/SKILL.md` with two halves:

- **Backup:** copy — never live-open — `~/.zcode/cli/db/db.sqlite` **plus its `-wal` and
  `-shm` sidecars** (a copy without them can be missing recent commits) and the
  `~/.zcode/cli/rollout/model-io-sess_*.jsonl` raw model-I/O captures into
  `zcode_chats/<machine>/` in the private repo `u2giants/ai-devops-transcripts`, gated
  by `bin/ai-transcript-destination-check` (it refuses any non-canonical remote). If
  ZCode is running, snapshot via copy-while-open is still safe for SQLite in WAL mode,
  but prefer running the backup with ZCode closed when convenient.
- **Mining cookbook (`queries.md` inside the skill):** ready-to-run recipes against the
  COPIED database using Python's stdlib `sqlite3` (no dependencies, `python` is already
  installed by the toolkit): sessions per project over time; most-used and
  most-failing tools (tables `tool_usage`, `session`); model/token spend per session
  (`model_usage`, `turn_usage`); longest sessions and their prompts
  (`session`, `message`, `part`); plus one JSONL recipe for prompt-shape analysis on the
  rollout files. Every recipe names its tables and is re-runnable — per the §4.3
  live-reading rule, no measured counts are pasted into the skill.

Public-repo discipline: nothing from the store is ever committed here; the skill names
the private destination only.

*Dependencies:* Step 4 (the tree exists). *Verification gate:* a dry run on edge-dev
produces a listing of exportable sessions (count + newest title) without copying; a real
run pushes to the private repo only when its remote is the canonical one (the
destination check refuses otherwise); two cookbook queries run against the copy and
return sensible results; no path under `popcre/ai-devops` gains transcript bytes
(`git status` clean after a run).

**Step 9. REMOVED FROM SCOPE (2026-09-17).** The drafted reviewer wrapper
(`bin/ai-zcode-review`, registry entry, lifecycle provider) was removed permanently by
owner ruling — GLM never reviews GLM-orchestrated work, and ZCode's engine is GLM-5.3
(§7.9, D6). Do not build it, do not "prepare" it, and do not re-add a registry entry.
The one live duty the ruling creates lives in shared-db, not here: ZCode-orchestrated
structural work must exclude the glm reviewer via the orchestrator marker's engine
declaration (D6; §13 open question 2).

**— context cut point: Phase C complete —**

### Phase D — Verification and landing (Steps 10–12)

**Step 10. Doctor and machine verification surface.**
Extend `bin/ai-devops` doctor (Claude precedent `:295-304`) with a zcode section:
presence (both version numbers), login state (credentials-file existence only), config
sanity (`~/.zcode/cli/config.json` parses; managed MCP entries present; `hooks.enabled`
true), skills markers count, shim on PATH. Extend `bin/verify-windows-dev.ps1` (after
`:13-21`) with the same presence checks. Add the login note to
`install-ai-devops-windows.ps1` (`:628-690` pattern): one-time `zcode login`, and on
headless machines `zcode login --no-browser` — printing the URL because Windows
auto-open truncates login URLs at `&` (blocker-watch #549 finding).

*Dependencies:* Steps 3–7. *Verification gate:* `bin/ai-devops doctor` prints a zcode
block that is green on edge-dev and honestly red (with the exact missing element) when
each fixture is withdrawn; `tests/test-ai-devops-doctor-install-state.sh` stays green
and gains zcode cases if it fixtures doctor states.

**Step 11. Documentation.**
No standalone usage guide (Grok 4.6 consult 2026-09-17 — the unique toolkit content is
20–40 lines, and `docs/codex-skills-usage-guide.md` is a skill-trigger dictionary, not
a client manual; ZCode's own config surface is documented by the vendor's in-app
`zcode-guide` plugin). Instead: a ZCode section in `docs/model-setup.md` (role:
interactive client, engine GLM-5.3; how to run `ai-zcode doctor`/`ask`; the yolo,
strict-schema, and `hooks.enabled` traps; transcript backup pointer), a managed-paths
row in `docs/config-inventory.md`, the `README.md` tool-list mention, and the router
row already in `AGENTS.md`/`docs/task-router.md`. Every claim links to the artifact
that proves it (facts file, tests).

*Dependencies:* Steps 3–10 (docs describe landed behavior). *Verification gate:* the
Markdown reachability gate (`bin/ai-doc-reachability`) passes for new/moved files; a
fresh session reading only the usage guide can correctly run `ai-zcode doctor` and
explain what ai-devops manages in `~/.zcode`.

**Step 12. Land: tests, merge, install, verify.**
Register every new test in `config/ci-suite-manifest.json`. Run the full local suites —
Bash tests through Git Bash, PowerShell tests through `pwsh` — after checking
`bin/ai-test-local --check-collision`. Land by PR through the merge queue
(`bin/ai-pr-wait`, all `gh` calls via `bin/ai-gh`). After `origin/main` carries the work:
re-run `install-ai-devops-windows.ps1` and `setup-machine.ps1` on edge-dev, verify the
installed state (`ai-install-manifest` clean, `bin/ai-devops doctor` zcode block green,
`~/.local/bin/zcode` live), and only then update this plan's STATUS table with commit
SHAs and run IDs. Machines beyond edge-dev get the same re-run when their owners ask.

*Dependencies:* all prior steps. *Verification gate:* merge commit on `origin/main`; CI
green on that SHA (not a stale verdict — read the run's commit); installed-state checks
green on edge-dev; STATUS table rows cite artifacts (file paths, SHAs, run IDs), never
bare counts.

## 10. Tests required

New tests (all registered in `config/ci-suite-manifest.json`):

- `tests/test-ai-zcode.sh` — offline wrapper contract: STEP 0 env assembly, argv pinning
  (refuses `yolo`, enforces max-turns ceiling, fails closed on missing app), `doctor`
  offline mode, `ask` output parsing against a mock `zcode.cjs` fixture. Model:
  `tests/test-ai-kimi.sh`'s offline sections.
- `tests/test-configure-zcode-mcps.ps1` — fixtures per Step 6's gate: fresh write,
  foreign-preservation, stale-managed removal, no-unknown-keys by construction, backup
  creation, idempotence. Model: `tests/test-configure-codex-mcps.ps1`.
- `tests/test-install-ai-devops-windows.ps1` (extend) — zcode skill targets, junction→dir
  migration fixture (asserts the junction's TARGET is untouched), collision-assert
  coverage, global seeding/adoption fixtures for `AGENTS-global-zcode.md`.
- `tests/test-ai-blocker-watch.sh` — existing; must stay green (it already asserts the
  zcode harness).
- `tests/test-installer-parity.sh` — existing; must stay green or carry the documented
  D7 exception.

Existing suites that must stay green: the full `tests/` tree per
`docs/development.md`, `tests/test-ai-install-manifest.sh`,
`tests/test-ubuntu-install-stages.sh` (unchanged by D7),
`tests/test-ai-devops-doctor-install-state.sh`.

Live qualifications (NOT CI; recorded as artifacts, not test files): Step 1's facts file
under `tests/verification/zcode-windows-2026-09-17/`. No live reviewer qualification is
planned or permitted — the reviewer step was removed permanently (§7.9).

## 11. Constraints, standing rules, and gotchas in force

**Repository contract (from `AGENTS.md` — binding on every implementing session):**

- Branch + PR only; never push to `main`; the protected branch uses a **merge queue**.
- Verify `git var GIT_COMMITTER_IDENT` shows `Albert Hazan <u2giants@users.noreply.github.com>`
  before committing. Work in your own worktree cut from `origin/main`; stage only
  task-owned files.
- **Task gates:** declare `ai-task-gates start --class <class>` per PR. After the
  2026-09-17 amendment this plan touches ONE protected class: `installation` (globs
  cover `install-*`, `setup-machine.ps1`, `machine-tools.tsv` — gates:
  `recoverable-config-backup`, `installed-command-smoke-proof`). The drafted
  reviewer-safety step was removed (§7.9), so no `bin/ai-*-review` or lifecycle file is
  touched and no independent exact-head review is required. A docs-only PR (like the
  one landing this plan) is class `prose`.
- All GitHub calls through `bin/ai-gh`; wait on CI through `bin/ai-pr-wait`; never
  open-ended `gh` loops.
- Never overlap a local full test series with a GitHub job on the same host:
  `bin/ai-test-local --check-collision` first.
- Public repo: no secrets, no raw transcripts, no personal identifiers beyond the
  existing convention. 1Password references by **location only** (vault + item + field),
  never values.
- Installation changes may write outside the repository — read
  [`docs/deployment.md`](docs/deployment.md) before touching install behavior.
- "Reuse before adding": this plan adds exactly one plan, one wrapper family, one
  config writer, one template, one skill tree — each justified by issue #558 and each
  with a retirement path (they follow the same consolidation targets as the Kimi/Grok
  precedents).

**ZCode-specific traps (each one silently fails — test for it):**

- **Strict MCP schema:** one unknown key drops the whole server, silently. The writer
  emits only canonical keys; never paste a Claude/OpenCode-shaped entry into ZCode's
  JSON (`command` must be a string, not an array).
- **No `${...}` expansion in config-file MCP servers:** absolute paths only.
- **`hooks.enabled: true` or nothing runs:** config-file hooks are OFF by default.
- **Matcher case-sensitivity:** `"bash"` does not match `Bash`; invalid regex never
  matches, silently.
- **`--prompt` defaults to `yolo` mode:** every headless invocation must pin
  `--mode plan` (or an allowlist) — this is the single most dangerous default in the
  CLI surface for wrapper work.
- **Timeout units:** hook `timeout` is seconds, `timeoutMs` is milliseconds; MCP default
  timeout is 30000 ms.
- **Junction deletion:** removing `~/.zcode/skills` must be non-recursive or it deletes
  the Claude skills behind it. Test with the fixture before running on a real machine.
- **SQLite session store:** copy `db.sqlite` + `-wal` + `-shm` before reading; never
  open the live DB.
- **Two version numbers + self-update:** never pin; record both; re-qualify per build.
- **Credentials:** `~/.zcode/v2/credentials.json` is checked by existence only; never
  read, print, or commit its contents.
- **`app.asar` and everything under `C:\Program Files\ZCode\resources\` is vendor
  bytes** — read-only reference, never modified.
- **The blocker-watch zcode harness is already shipped** — do not duplicate or "fix"
  `config/blocker-watch.json`; Step 3's shims must not shadow the wake argv
  (the wake path resolves its own env; shims are for interactive/wrapper use).

## 12. Access and environment

- **Repo:** `popcre/ai-devops`, canonical checkout `C:\repos\ai-devops` (landing-only);
  write work in `/c/repos/ai-devops-worktrees/<slug>` worktrees. Target: `main` via PR +
  merge queue. Planning issue: #558.
- **Machines:** edge-dev (ZCode installed, authenticated, daily use); al8960ofc (apply
  later per its owner). Windows 11, Git Bash + pwsh 7.
- **ZCode on edge-dev:** app `C:\Program Files\ZCode\ZCode.exe`; CLI core
  `C:\Program Files\ZCode\resources\glm\zcode.cjs`; headless probe pattern:
  `ELECTRON_RUN_AS_NODE=1 "/c/Program Files/ZCode/ZCode.exe" "/c/Program Files/ZCode/resources/glm/zcode.cjs" -p "<prompt>" --max-turns 2 --json`.
  Auth: already signed in (Z.AI OAuth, GLM-5.3 coding plan). Headless login when needed:
  `zcode login --no-browser` (URL prints; auto-open truncates at `&`).
- **1Password (locations only):** service-account token — vault `vibe_coding`, item
  `vibe_coding-service-account`, field `op_service_account_token` (the bootstrap secret
  behind `mcp-launch.cmd`); MCP server secrets live as `op://` references in
  `~/.config/ai-devops/mcp.env` — never resolved into ZCode's config file.
- **Private repositories (destinations, never committed here):** transcripts →
  `u2giants/ai-devops-transcripts` (`zcode_chats/<machine>/`); protected machine config →
  `u2giants/ai-devops-private-config`.
- **Authenticated CLIs on edge-dev:** `gh` (GitHub), `op` (1Password CLI), `git` with the
  pinned identity; `claude`, `codex`, grok/kimi/qwen wrappers installed via
  `~/.local/bin` shims.
- **Running things locally:** Bash tests `bash tests/test-ai-zcode.sh` from the worktree
  in Git Bash; PowerShell tests `pwsh -File tests/test-configure-zcode-mcps.ps1`; the
  installer against a temp HOME fixture (never the live profile first);
  `ai-task-gates explain` to confirm a PR's resolved class before review/merge.

## 13. Definition of done + risks and open questions

**Definition of done** (all required; each row lands in the STATUS table with an
artifact — file path, commit SHA, or CI run ID):

1. Steps 1–12 complete; every STATUS row cites a reproducible artifact.
2. All new tests registered in `config/ci-suite-manifest.json` and green in CI on the
   merged `main` SHA; existing suites green on the same SHA.
3. Installation-class PRs carry their backup + smoke-proof evidence. (No
   reviewer-safety class is touched — the reviewer step was removed permanently, §7.9.)
4. edge-dev installed state verified: `bin/ai-devops doctor` zcode block green,
   `~/.local/bin/zcode` live, `~/.zcode/skills` a real managed directory (junction
   gone, Claude skills intact), `~/.zcode/AGENTS.md` seeded, `~/.zcode/cli/config.json`
   carrying exactly the membership MCP servers plus enabled hooks with timestamped
   backups present from the writer's first run.
5. Plan and handoff updated; handoff retired only if no implementation work remains.
6. No secrets, transcripts, or private artifacts anywhere in the public repo (verify the
   PR diff against §11's public-repo rule).

**Risks and rollback:**

- **ZCode app self-update changes the CLI contract** (flags, JSON keys, hook payload).
  Mitigation: wrapper STEP 0 re-verification + doctor probes + presence-only versioning.
  Rollback: the wrapper fails closed on contract drift — no partial drive; re-qualify.
- **Strict-schema drift in ZCode releases** (schema change drops managed servers
  silently). Mitigation: doctor checks managed entries exist in the file (cheap) and the
  facts file records the schema version qualified; a schema change surfaces as a doctor
  red, not a silent loss.
- **Junction migration on a real profile.** Mitigation: fixture test first; the
  migration is non-recursive and logs before/after skill counts; worst case the real
  `~/.claude/skills` is untouched and `~/.zcode/skills` can be re-created by re-running
  the installer.
- **Hooks misbehaving in daily sessions** (double-firing, blocking). Mitigation: hooks
  fail-open by design (completion hook), `--check` mode reports drift, and removing the
  `hooks` block via the writer's backup restores the pre-hooks file. The memory hook's
  matcher aliases are verified in Step 1 before registration.
- **`codex-cli` MCP membership inside ZCode surprises someone** (an agent-inside-agent
  tool). Mitigation: D10 keeps the default minimal; membership is a one-line change.
- **Rollback overall:** every managed write keeps a timestamped backup; the shims, TSV
  rows, wrapper, and doctor additions are additive; uninstalling the ZCode treatment =
  remove managed entries with the writer, delete the two shims, re-run the installer
  without the zcode targets. Nothing in this plan mutates vendor bytes or other
  clients' config, so blast radius is confined to `~/.zcode` and `~/.local/bin`.

**Open questions (owner decisions, none blocking Steps 1–8):**

1. **MCP membership final set** (D10): is `1password` + `codex-cli` the right ZCode
   default, or should it carry the broader Desktop set? Criteria: demonstrated need by a
   ZCode session; expand by one-line membership change. (Context from the owner's
   2026-09-17 review: cross-engine delegation is a valued pattern — GLM-in-OpenCode
   exists precisely so Claude and Codex can use GLM — so `codex-cli`-inside-ZCode is
   consistent with how he works.)
2. **GLM-exclusion for ZCode-orchestrated shared-db work** (a shared-db issue, not this
   repo's). Owner ruling 2026-09-17 — *"I never want GLM reviewing GLM code"* — is not
   yet enforced for ZCode orchestrators: shared-db's reviewer filter
   (`reviewersForOrchestrator`, `scripts/manage-migration-author-lanes.mjs` ~:553)
   excludes only rows whose `orchestratorEngine` matches the marker's declared engine,
   the `glm-5.3` row declares none, and the marker vocabulary has no `zcode` engine.
   Before the first ZCode-orchestrated structural change in shared-db, this must land:
   filed 2026-09-17 as
   [u2giants/shared-db#3232](https://github.com/u2giants/shared-db/issues/3232) —
   (a) give the glm rows `orchestratorEngine: 'glm'` and (b) map a ZCode
   orchestrator marker to engine `glm` (the marker engine vocabulary
   `ENGINES = { codex, claude }` accepts neither today). Criteria: a read-only
   re-check proves a zcode-orchestrated draw can never include glm.
3. **ZCode native memory — SETTLED 2026-09-17: the owner enabled it.** ZCode's
   per-project memory (`memoryEnabled`) is now ON, matching how the owner works (he
   mines transcripts for better ways of working; memory is the in-band version of
   that). The only remaining memory decision is a separate later one: whether to sync
   accumulated memory to the private memory repository. No Claude memory hook is ported
   either way (§7.11).
4. **`~/.agents/skills` junction** (D11): keep as compatibility, or later repoint to a
   real shared-only root? Decide after Step 4's testing shows whether the codex-view
   leak matters in practice.

---

## Self-audit (mandatory gate — preserved per the standard)

**1. Could a brand-new AI session with no project knowledge and no context from this
conversation execute this plan to perfection, without asking anything?**
Yes. §2 defines every machine, path, and client; §5 gives the exact current state with
`file:line` anchors for every piece of precedent machinery and the live machine's
unmanaged baseline; §6 records every non-obvious ZCode discovery (strict schema,
hooks-enabled, yolo default, junctions, two version numbers) with its source; §9's steps
each name target files, intended behavior, dependencies, and a concrete verification
gate; §10 names the tests by file and behavior; §11 carries the repo's binding rules and
the ZCode-specific traps; §12 gives the access map including the exact headless probe
command. The four phase cut points tell a multi-session run where to stop and re-read.

**2. Does the plan carry every piece of background, nuance, and reasoning currently
held — including what was ruled out and why?**
Yes. §7 records all eight rejected approaches with their failure reasons (hand-editing,
junction-as-mechanism, assumed winget entry, version pinning, ai-glm reuse, premature
registration, plaintext tokens, vendor-byte edits). §8 separates eight LOCKED decisions
(quoted with rationale) from six OPEN ones with decision criteria, so the implementer
neither redesigns locked choices nor freezes on open ones. §3 preserves the trigger and
the hand-made-state problem; §6 finding 9 flags the one deliberately-unverified fact
(headless env requirements) and routes it to Step 1 rather than guessing.

**3. Is the ultimate goal stated clearly enough that the implementer could make a
correct judgment call if a step turns out to be wrong?**
Yes. §1 states the business outcome (a rebuilt Windows machine gives ZCode the same
managed treatment as Claude and Codex, with secrets via the shared launcher, honest
doctor, transcript backup, and an evidence-gated reviewer path) and the explicit
"goal wins over a wrong step — stop and flag" instruction. Every phase's gates trace
back to that outcome, and §13's definition of done restates it as a verifiable
checklist.

---

**Amendment note (2026-09-17, later the same day):** after owner review of the drafted
plan, the scope was narrowed — the reviewer step was removed permanently (§7.9; ruling:
GLM never reviews GLM-orchestrated work, and ZCode's engine is GLM-5.3), the
memory-index hook port was dropped in favor of ZCode's native memory (§7.11), the
`zcode-config-repair` skill was killed (§7.10), and Step 8 was redesigned around SQL
mining of the copied session database. Sections 1, 4, 7, 8, 9, 10, 11, and 13 were
updated together so no removed item is still referenced as active; the phrase
"evidence-gated reviewer path" in the self-audit answer above is historical and no
longer part of the goal. The audit questions were re-checked against the narrowed scope
and still hold.
