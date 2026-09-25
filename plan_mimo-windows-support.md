# IMPLEMENTATION PLAN — Xiaomi MiMo (MiMo Desktop / MiMoCode) parity in ai-devops (2026-09-23)

Paired handoff: [`HANDOFF.d/2026-09-23T1856Z-edge-dev-mimo-client-integration.md`](HANDOFF.d/2026-09-23T1856Z-edge-dev-mimo-client-integration.md)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Freeze the MiMo Windows baseline (qualification facts) | ✅ done | 2026-09-23 | `tests/verification/mimo-windows-2026-09-23/README.md` — Desktop path, CLI-absent fact, MCP array-command schema, no-hooks fact, session/memory layout. `mimo run` flag qualification completed 2026-09-25 after the CLI install (#829): `tests/verification/mimo-cli-2026-09-25/README.md` (D10 LOCKED). |
| 2. Install policy and presence checks | ✅ done | 2026-09-23 | `bin/setup-machine.ps1` MiMo presence block (`$MiMoAppExe` / `Get-Command mimo`); `bin/verify-windows-dev.ps1` `app:MiMo` check. Desktop presence-only. |
| 3. `mimo` launcher shim + `bin/ai-mimo` governed wrapper | ✅ done | 2026-09-23 | `bin/ai-mimo` (ask/doctor/version; yolo refused; wall-clock ceiling; `local_dependency_unavailable` when CLI missing) + `bin/ai-mimo.cmd`, `config/machine-tools.tsv` row. Offline: `tests/test-ai-mimo.sh` 14/14. |
| 4. Managed skills: `skills/mimo/` tree + installer | ✅ done | 2026-09-23 | `skills/mimo/mimo-transcript-backup/`; `bin/install-ai-devops-windows.ps1` installs `skills/mimo`+`skills/shared` to `~/.config/mimocode/skills/`; collision assert includes `mimo`. `tests/test-install-ai-devops-windows.ps1` PASS. |
| 5. Global instructions: `AGENTS-global-mimo.md` template + seeding | ✅ done | 2026-09-23 | `templates/system/AGENTS-global-mimo.md`; installer seeds `~/.config/mimocode/AGENTS.md`; `bin/ai-adopt-globals` fourth target. `tests/test-ai-adopt-globals.sh` ALL PASS; `tests/test-client-globals-required-phrases.sh` PASS. |
| 6. MCP wiring: `bin/configure-mimocode-mcps.ps1` + catalog membership | ✅ done | 2026-09-23 | Array-command writer (type/command/env/enabled/timeout); `$MimoMcpNames = @("1password")`; `instructions` ensure. `tests/test-configure-mimocode-mcps.ps1` 23/23. |
| 7. Hooks: completion-check hook | ⛔ N/A | 2026-09-23 | MiMoCode has no Claude/ZCode-style config hooks (permissions cannot be modified by custom tools/hooks — `mimocode-docs` permissions.md). Completion-honesty rules live in the global template instead. No `--client mimo`. |
| 8. Transcript backup + SQL mining cookbook | ✅ done | 2026-09-23 | `skills/mimo/mimo-transcript-backup/SKILL.md` + `queries.md` (copy-never-live-open; private repo only; SQL schema marked provisional until first mine). |
| 9. Reviewer wrapper `bin/ai-mimo-review` | ⛔ out of scope | 2026-09-23 | MiMo is the fourth INTERACTIVE client, not a formal reviewer or pipeline stage (ZCode pattern). |
| 10. Doctor and machine verification surface | ✅ done | 2026-09-23 | `bin/ai-devops` doctor MiMo section (warn-only on Desktop absence); `ai-mimo doctor` (14/14 fixture tests). `tests/test-ai-devops-doctor-install-state.sh` PASS. |
| 11. Documentation (README, task router, model setup, config inventory) | ✅ done | 2026-09-23 | `docs/model-setup.md` MiMo section; `docs/config-inventory.md` MiMoCode-home row; `AGENTS.md` task-router row; `README.md` mention. `tests/test-markdown-links.sh` PASS (377 files). |
| 12. Land: tests green, merge, install, verify | ⬜ open | — | Offline suites green (ai-mimo 14/14, configure-mimocode 23/23, adopt-globals, install-windows, installer-parity, client-globals, machine-tools, doctor-install-state, markdown-links, context-audit, blocker-watch). Merge through the queue; leftover-proof issue if live install is not proven in the landing session. |

**Fresh-session starting point:** begin at the first ⬜ row. Re-read §§5–8 before changing any code, and re-read the phase heading before starting each phase.

Phases: **A** = Steps 1–3 (foundations), **B** = Steps 4–7 (managed configuration; 7 is N/A), **C** = Step 8 (transcripts), **D** = Steps 10–12 (verification and landing).

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert now uses **Xiaomi MiMo Desktop** (product "Xiaomi MiMo AI", embedded MiMoCode engine) as a daily coding and office assistant on Windows, alongside Claude Code, Codex, and ZCode. When a Windows machine is set up by ai-devops, Claude, Codex, and ZCode come out fully managed: verified presence, managed skills, global instructions, MCP servers wired through the 1Password secret launchers, doctor checks, transcript backup guidance, and (for headless clients) a governed wrapper. MiMo today gets **none** of that. Its only ai-devops integration is incidental: some shared skills already appear under `~/.agents/skills` (a read-only compat root), and `1password` is already hand-wired in `~/.config/mimocode/mimocode.jsonc`.

When this plan is done, a Windows machine rebuilt by `bootstrap-windows-dev.ps1` + `setup-machine.ps1` gives MiMo the same managed treatment Claude, Codex, and ZCode receive, and a session in any tool can drive MiMo headlessly through one governed wrapper with honest failure modes — so that:

- MiMo's skills, global instructions, and MCP servers are **installed and reconciled by the toolkit**, not hand-copied, and survive re-runs without drift.
- Secrets reach MiMo's MCP servers the same way they reach Claude, Codex, and ZCode — through the shared `mcp-launch.cmd` 1Password launcher — never as plaintext in config files.
- `bin/ai-devops doctor` and `verify-windows-dev.ps1` tell the truth about MiMo (installed? config valid? MCP present? skills managed?).
- MiMo session state can be backed up to the private transcripts repository AND mined by direct SQL query against the copy.
- **No MiMo-based formal reviewer is built.** MiMo is an interactive client (ZCode pattern). Formal review stays with Claude and Codex.

**If any step below conflicts with this goal, the goal wins — stop and flag the conflict.**

## 2. What this application is

**ai-devops** ([`popcre/ai-devops`](https://github.com/popcre/ai-devops), local canonical checkout `C:\repos\ai-devops`) is Albert Hazan's public, restore-from-zero toolkit for a multi-model AI coding workflow. It contains Bash and PowerShell commands under `bin/`, tests under `tests/`, machine setup scripts, skills under `skills/`, templates, and operating documentation. It is not a hosted application; **installation is its deployment mechanism** (see [`docs/deployment.md`](docs/deployment.md)).

It manages Windows development machines (edge-dev, al8960ofc/4837) and Ubuntu servers.

Clients it manages today: **Claude Code** (CLI), **Claude Desktop**, **Codex**, **ZCode** (Z.AI GLM-5.3 desktop agent). Reviewer/implementer CLIs: Grok Build, Kimi Code, Qwen Code, Gemini, GLM (OpenCode), Muse, DeepSeek.

**MiMo** is the next interactive client. Two surfaces exist on edge-dev (2026-09-23):

| Surface | Path / identity | Notes |
|---|---|---|
| **MiMo Desktop** (Xiaomi MiMo AI) | `C:\Program Files\Xiaomi MiMo AI\Xiaomi MiMo AI.exe` | Electron desktop app; self-updates; machine-wide. Engine is embedded MiMoCode. |
| **MiMoCode CLI (`mimo`)** | on PATH since 2026-09-25 (`@mimo-ai/cli` 0.1.15 via npm; #829) | Fork of OpenCode. Headless entry is `mimo run`. Absent on edge-dev until 2026-09-25 — only the Desktop embed was present. |
| User config | `~/.config/mimocode/mimocode.jsonc` | JSONC. `mcp` map, `instructions`, `permission`, `skills.paths`, providers. |
| Data | `~/.local/share/mimocode/` | `mimocode.db` (SQLite sessions, ~120 MB observed), `memory/`, `log/`, `builtin_skills/`. |
| Skills write roots | `~/.config/mimocode/skills/`, project `.mimocode/skills/` | Desktop **installs/imports only** here. |
| Skills read-only compat | `~/.agents/skills` (default), optionally `~/.claude/skills`, `~/.codex/skills` | Never write here for MiMo; copy into a MiMoCode root instead. |

## 3. What triggered this work

Albert's request, 2026-09-23 (this session): *bring Xiaomi Mimo fully into our ai-devops system.*

The gap is concrete. MiMo Desktop is daily-use on edge-dev with hand-made state: `1password` MCP already in `mimocode.jsonc` (good shape — launcher via `mcp-launch.cmd`, token-free), shared skills visible only through the `~/.agents/skills` compat scan, no managed `~/.config/mimocode/skills/` tree, no seeded MiMo edition of Albert's standing rules, no doctor, no wrapper, no transcript-backup skill, no BlockerWatch harness entry, no docs. Hand-made state does not survive a machine rebuild and cannot be reconciled.

## 4. Scope — in and out

**IN this plan (Windows only):**

- MiMo Desktop + `mimo` CLI presence/install policy (`setup-machine.ps1` probe, `verify-windows-dev.ps1` check). Desktop is presence-only (self-updating, never pinned).
- A `mimo` launcher on PATH (shims) and the governed headless wrapper `bin/ai-mimo` (+ `machine-tools.tsv` row, `.cmd` stub).
- Managed skills: `skills/mimo/` client tree + `skills/shared/`, installed to a real managed `~/.config/mimocode/skills/` directory.
- Global instructions: `templates/system/AGENTS-global-mimo.md` seeded to `~/.config/mimocode/AGENTS.md` (seed-only / adoptable), referenced via the `instructions` config key, with `ai-adopt-globals` support.
- MCP wiring: `bin/configure-mimocode-mcps.ps1` writing `~/.config/mimocode/mimocode.jsonc` → `mcp` from the shared catalog, 1Password entry through `mcp-launch.cmd`.
- Transcript backup + mining: `mimo-transcript-backup` skill for `mimocode.db` (+ sidecars) and `memory/`, private transcripts repo only.
- Doctor and verification: `bin/ai-devops` doctor section, `ai-mimo doctor`, `verify-windows-dev.ps1`.
- BlockerWatch harness entries (`harness.mimo`, `harness_fresh.mimo`, `transcript_glob.mimo`).
- Documentation and offline tests for all of the above.

**NOT in this plan:**

- **Ubuntu/Linux MiMo support.** Windows-only, matching ZCode.
- **Any MiMo-based formal reviewer.** Interactive client only (ZCode pattern). Formal review stays Claude/Codex.
- **Completion-check hook registration.** MiMoCode has no config-file hook surface equivalent to Claude `hooks` or ZCode `hooks.events` (permissions cannot be modified by custom tools/hooks). N/A — not deferred.
- **Desktop Personalization / appearance settings.** Those are product UI (`set_desktop_setting`); not toolkit-managed.
- **Browser Use / Computer Use / Voice plugins.** Product features; install through Desktop Settings.
- **Replacing or relocating existing hand-wired `1password` MCP.** Reconcile it into the managed set in the same shape (already correct); do not churn.
- **Provider/API key management beyond the shared 1Password launcher.** MiMo account login is interactive (`mimo account login` / `/login`).

## 5. Current state of the code

Exists and works (do not break):

- ZCode client parity is complete (`plan_zcode-windows-support.md` STATUS all ✅). Copy that pattern; do not redesign it.
- Shared MCP launcher: `~/.config/ai-devops/mcp-launch.cmd` → `bin/mcp-secret-launch.ps1`.
- `bin/configure-zcode-mcps.ps1` + `tests/test-configure-zcode-mcps.ps1` — the strict-schema writer pattern.
- `bin/install-ai-devops-windows.ps1` installs Claude/Codex/ZCode skills and seeds three global templates.
- `bin/ai-adopt-globals` TARGETS list has Claude/Codex/ZCode.
- `bin/ai-blocker-watch` + `config/blocker-watch.json` already carry `harness.{claude,codex,zcode}` and `transcript_glob`.
- `config/machine-tools.tsv` has `ai-zcode`; missing `ai-mimo`.
- `bin/ai-devops` doctor has a ZCode section; missing MiMo.
- Live MiMo state on edge-dev (this session, read-only observation):
  - Desktop: `C:\Program Files\Xiaomi MiMo AI\Xiaomi MiMo AI.exe` present.
  - `mimo` CLI: **not** on PATH (`Get-Command mimo` empty).
  - `~/.config/mimocode/mimocode.jsonc` — valid JSONC, `mcp.1password` local server via `mcp-launch.cmd` + 1password-mcp.cmd, `enabled: true`, `timeout: 120000`.
  - `~/.local/share/mimocode/mimocode.db` present (large SQLite).
  - `~/.local/share/mimocode/memory/sessions/<id>/` present.
  - `~/.agents/skills` present (open-standard compat root).

Untouched: everything named in §4 IN list.

## 6. Key findings and root cause

file:line evidence and non-obvious discoveries:

1. **MiMo MCP `command` is an ARRAY of argv strings**, not a string + args (live file `~/.config/mimocode/mimocode.jsonc`). ZCode's writer requires a string command — **do not reuse `ConvertTo-ZCodeMcpEntry`**. Timeout key is `timeout` (ms), not ZCode's `timeoutMs`.
2. **Skills write authority is only MiMoCode roots** (`~/.config/mimocode/skills/`, `.mimocode/skills/`). Brand roots (`~/.claude/skills`, `~/.codex/skills`, `~/.agents/skills`) are optional **read-only**. Installing shared skills into `~/.agents/skills` would not be "MiMo-managed" and Desktop would not treat them as installable/uninstallable. Therefore install to `~/.config/mimocode/skills/` (source: `engine-config/skills/mimo-desktop-guide/SKILL.md` §7).
3. **No hooks system.** `mimocode-docs` permissions.md: "Permissions cannot be modified by custom tools/hooks." There is no `ai-install-completion-check-hook --client mimo` surface. Step 7 is N/A with reason, not a gap to fill later.
4. **Headless is `mimo run`**, with `--dangerously-skip-permissions` / `--yolo` for unattended allow-all. The wrapper must **never** pass those from caller input (ZCode yolo-default trap analogue). Default to the `plan` agent (read-only) and a wall-clock ceiling.
5. **Standalone `mimo` CLI is not installed on edge-dev 2026-09-23.** Only the Desktop embed is present. Wrapper must fail closed with `local_dependency_unavailable` and name how to get the CLI; doctor treats Desktop-present + CLI-absent as a warn, not a hard fail (Desktop is still fully managed for skills/MCP/globals).
6. **Global always-loaded instructions** are not a single well-known file like `~/.zcode/AGENTS.md`. Reliable mechanism is the `instructions` config key (extra instruction files/globs) plus a seeded `~/.config/mimocode/AGENTS.md`. Desktop "Personalization" custom instructions are a separate product surface — out of scope.
7. **Session identity** looks like `ses_<id>`; memory lives at `~/.local/share/mimocode/memory/sessions/<id>/`. Transcripts for mining are the SQLite `mimocode.db` (+ `-wal`/`-shm`) and optionally `log/`. Same "copy, never live-open" rule as ZCode.
8. **JSONC caveat:** `windows-json-file.ps1` parses with `ConvertFrom-Json` and writes pure JSON. Comments in `mimocode.jsonc` would be stripped on rewrite. Today's file has none. The writer must back up first (it already does) and docs must say comments are not preserved.
9. **BlockerWatch resume** is unproven for MiMo. Documented TUI flags include `--session` / `--continue`. Headless `mimo run` session-resume flags are **not qualified**. Harness argv is a best-effort documented shape; first live wake must re-qualify (Step 1 leftover).

## 7. Approaches considered and REJECTED, and why

| Approach | Why rejected |
|---|---|
| Install shared skills into `~/.agents/skills` only | That root is read-only compat; Desktop cannot manage/uninstall those copies. Write authority is MiMoCode roots. |
| Reuse `configure-zcode-mcps.ps1` with a flag | Schema is different (array command, `timeout`, `type`). A shared writer would be a schema lie; a thin MiMo writer matches the per-client pattern (Claude JSON, Codex TOML, ZCode JSON, MiMo JSONC). |
| Register a completion-check hook like Claude/ZCode | No hook surface exists. Fake registration would be a silent no-op — worse than documenting N/A. |
| Build `ai-mimo-review` | Out of scope; MiMo is interactive-only (ZCode pattern). |
| Drive the Desktop Electron app headlessly via `Xiaomi MiMo AI.exe` | That launches the GUI. Headless needs `mimo run` from the CLI. Fail closed rather than start a GUI. |
| Put Albert's standing rules only in Desktop Personalization | Not file-managed, not `ai-adopt-globals`-able, not machine-section-preserving. Seed a file + `instructions` key instead. |
| Pin a Desktop/CLI version | Desktop self-updates (ZCode policy). Never pin. |

## 8. Design decisions already made (dated)

| ID | Decision | Locked? |
|---|---|---|
| D1 | MiMo is the fourth INTERACTIVE client (Desktop + CLI), not a reviewer and not a pipeline stage. | **LOCKED** 2026-09-23 |
| D2 | Managed skills install to `~/.config/mimocode/skills/` only (MiMoCode write root). | **LOCKED** 2026-09-23 |
| D3 | MCP catalog membership starts at `@("1password")` only — same minimal default as Claude/ZCode (unproven-value criterion). | **LOCKED** 2026-09-23 |
| D4 | Wrapper is `bin/ai-mimo` with `ask` / `doctor` / `version` and no wrapper state dir (MiMo owns its sessions). | **LOCKED** 2026-09-23 |
| D5 | `ask` defaults to agent `plan` (read-only) + wall-clock ceiling; never pass `--yolo` / `--dangerously-skip-permissions` from caller input. | **LOCKED** 2026-09-23 |
| D6 | No completion-check hook for MiMo (no hook surface). | **LOCKED** 2026-09-23 |
| D7 | Global template is `templates/system/AGENTS-global-mimo.md` → `~/.config/mimocode/AGENTS.md`, adopted by `ai-adopt-globals`, referenced via `instructions`. | **LOCKED** 2026-09-23 |
| D8 | Desktop presence-only; never version-pin; absence is a warning. CLI absence is a warning for managed-config surfaces and a hard fail only for `ai-mimo ask`. | **LOCKED** 2026-09-23 |
| D9 | Windows-only. | **LOCKED** 2026-09-23 |
| D10 | Exact `mimo run` flag set qualified live 2026-09-25 (mimo 0.1.15, #829): `-m/--model provider/model`, `--agent`, `--dir` (never `--cwd`), `--format`, `--yolo` aliasing skip-permissions. Wrapper pins only documented flags and fail-closes on unknown ones. Evidence: `tests/verification/mimo-cli-2026-09-25/README.md`. | **LOCKED** 2026-09-25 |
| D11 | BlockerWatch resume argv is **OPEN** until first live wake; ship a documented best-effort shape and re-qualify. | **OPEN** |
| D12 | Whether `instructions` paths are absolute or config-relative is **OPEN**; prefer absolute path to `~/.config/mimocode/AGENTS.md`. | **OPEN** |

## 9. The plan — numbered, ordered steps

### Phase A — Foundations (Steps 1–3)

**Step 1. Freeze the MiMo Windows baseline (qualification facts).**
- Target: `tests/verification/mimo-windows-2026-09-23/README.md` (new).
- Record: Desktop exe path + ProductVersion; presence/absence of `mimo` on PATH; `mimocode.jsonc` schema facts (array `command`, `timeout`, `type`); skills roots; no-hooks fact; session/memory layout; `mimo run --help` output **when CLI exists** (currently absent — record that and the repro command).
- Done when: every claim carries its reproducing command; a reader can re-probe without this chat.
- Verify: file exists and names edge-dev probe commands.

**Step 2. Install policy and presence checks.**
- Target: `bin/setup-machine.ps1` — `Get-MiMoInstall` (Desktop exe + optional `mimo` CLI), warn-only on absence; `bin/verify-windows-dev.ps1` — `app:MiMo` check.
- Behavior: Desktop path `C:\Program Files\Xiaomi MiMo AI\Xiaomi MiMo AI.exe` (overridable for tests). Never winget-fabricate. Note first-run `mimo account login` when CLI appears.
- Done when: `verify-windows-dev.ps1` reports `app:MiMo` on edge-dev with the ProductVersion.
- Depends on: Step 1 paths.

**Step 3. `mimo` launcher shim + `bin/ai-mimo` governed wrapper.**
- Target: `bin/ai-mimo` (bash, STEP 0 header), `bin/ai-mimo.cmd`, `config/machine-tools.tsv` row (`ai-mimo	bin/ai-mimo	bash+cmd	none	mimo	install-machine-tools.ps1`), `tests/test-ai-mimo.sh`.
- Behavior:
  - `ai-mimo ask "<prompt>" [--agent plan|build] [--cwd DIR] [--json-output]` — headless `mimo run`; default agent `plan`; wall-clock `AI_MIMO_ASK_TIMEOUT` (default 900s); refuse `--yolo` / `--dangerously-skip-permissions` / `--allow-shell`-style flags from caller.
  - `ai-mimo doctor [--live]` — presence (Desktop + CLI), config parse, MCP names, skills markers, shim, `instructions` pointer.
  - `ai-mimo version`.
  - Missing CLI → `local_dependency_unavailable` naming the exact missing program; never start the Desktop GUI.
- Done when: `tests/test-ai-mimo.sh` green offline with a mock `mimo`; `ai-mimo doctor` runs on edge-dev (CLI-absent may warn).
- Depends on: Step 1 flag facts (partial OK — fail-closed until D10).

### Phase B — Managed configuration (Steps 4–7)

**Step 4. Managed skills.**
- Target: `skills/mimo/mimo-transcript-backup/`; `bin/install-ai-devops-windows.ps1` — install `skills/mimo` + `skills/shared` into `~/.config/mimocode/skills/`; extend `Assert-NoSharedSkillCollisions` clients list with `mimo`; orphan pruning source roots.
- Done when: installer dry-run lists MiMo skill counts; markers `.ai-devops-managed` appear under `~/.config/mimocode/skills/`.
- Parallel with Step 5 after Step 2.

**Step 5. Global instructions.**
- Target: `templates/system/AGENTS-global-mimo.md` (Response Style + Albert standing rules + MiMo-specific traps from §6); installer seed to `~/.config/mimocode/AGENTS.md` (seed-only); `bin/ai-adopt-globals` TARGETS entry `MiMo|$BASE_HOME/.config/mimocode/AGENTS.md|$REPO_ROOT/templates/system/AGENTS-global-mimo.md`; `configure-mimocode-mcps.ps1` (Step 6) ensures `instructions` references that file.
- Done when: adopt-globals fixture test covers MiMo; seeded file exists after install.
- Depends on: Step 2 home paths.

**Step 6. MCP wiring.**
- Target: `bin/configure-mimocode-mcps.ps1` (new), `tests/test-configure-mimocode-mcps.ps1` (new); `bin/setup-machine.ps1` `$MimoMcpNames = @("1password")` + call site; `config/ci-suite-manifest.json` entries.
- Behavior: write `mcp.<name>` under `~/.config/mimocode/mimocode.jsonc`. Canonical local keys only: `type`, `command` (string array), `env`, `enabled`, `timeout`. Managed names not selected are removed; foreign entries and all other keys (`instructions`, `permission`, `plugin`, `provider`, …) are preserved. Atomic write + timestamped backup + idempotent. Also ensure `instructions` contains the absolute path to `~/.config/mimocode/AGENTS.md` when that file exists (or leave untouched if the user cleared it — **OPEN** D12: default is to ensure it).
- Done when: tests 10+ green; live `1password` entry still launches through `mcp-launch.cmd` with no token in config.
- Depends on: nothing (parallel with 4–5).

**Step 7. Hooks.** — **N/A** (D6). Do not implement.

### Phase C — Transcripts (Step 8)

**Step 8. Transcript backup + SQL mining cookbook.**
- Target: `skills/mimo/mimo-transcript-backup/SKILL.md` + `queries.md`.
- Copy (never live-open) `~/.local/share/mimocode/mimocode.db{,-wal,-shm}` and optionally `log/` into private `u2giants/ai-devops-transcripts` under `mimo_chats/<machine>/` after `ai-transcript-destination-check`. Mine the copy with Python `sqlite3`. Do not put transcript bytes in the public repo.
- Done when: skill exists with dry-run first, destination check, and at least sessions/tools/token queries validated against a scratch copy (or marked unvalidated until first copy).
- Depends on: Phase B install path.

### Phase D — Verification and landing (Steps 10–12)

**Step 10. Doctor surface.**
- Target: `bin/ai-devops` doctor MiMo section (presence/versions/login/config/MCP/skills/shims/instructions; warn-only on Desktop absence; platform-honest on Linux); `ai-mimo doctor` already from Step 3.
- Done when: `ai-devops doctor` shows MiMo section on edge-dev.

**Step 11. Documentation.**
- Target: `docs/model-setup.md` MiMo section (role, wrapper, traps, transcript pointer); `docs/config-inventory.md` MiMo-home row; `README.md` mention beside ZCode; `AGENTS.md` task-router row; `docs/task-router.md` if a specialized row is needed (prefer AGENTS.md row only — ZCode used that).
- Done when: `bin/ai-doc-reachability --base origin/main` PASS.

**Step 12. Land.**
- Tests green (`tests/test-ai-mimo.sh`, `tests/test-configure-mimocode-mcps.ps1`, install/adopt fixture suites, `test-ai-devops-doctor*` if present).
- Worktree branch → PR → merge queue → confirm `origin/main`.
- Install on edge-dev from the merged commit (or open exactly one leftover-proof issue if live install cannot run in the landing session — **one unproven outcome per session**).
- BlockerWatch: add `mimo` harness entries in the same PR; first live wake is a separate live-proof if not done here.

## 10. Tests required

| Test | What it proves |
|---|---|
| `tests/test-ai-mimo.sh` (new) | Wrapper: yolo refusal, default plan agent, timeout path, missing-CLI `local_dependency_unavailable`, JSON contract check when `--json-output`, doctor structure. Mock `mimo` like `test-ai-zcode.sh` mocks `zcode.cjs`. |
| `tests/test-configure-mimocode-mcps.ps1` (new) | Writer: array command, `timeout` default, foreign-entry preserve, managed retire, idempotent re-run, backup created, refuses unknown keys on selected servers, `instructions` ensure. |
| `tests/test-install-ai-devops-windows.ps1` | Extend: MiMo skills install into `~/.config/mimocode/skills/`, collision assert includes `mimo`, global seed path. |
| `tests/test-ai-adopt-globals.sh` | Extend: MiMo target in TARGETS, machine-section preserve. |
| `tests/test-ai-blocker-watch.sh` | Extend: `harness` / `harness_fresh` / `transcript_glob` have `mimo` keys. |
| `tests/test-bin-cmd-launchers.sh` | `ai-mimo.cmd` exists and launches. |
| Existing suites | Stay green: `test-ai-zcode.sh`, `test-configure-zcode-mcps.ps1`, doctor tests, ci-suite-manifest validation. |

Register every new test in `config/ci-suite-manifest.json`.

## 11. Constraints, standing rules, and gotchas in force

- Branch policy: worktree from `origin/main`, never push to protected `main` directly; PR + merge queue. Documentation-only PRs may use owner override after verifying every changed file is prose.
- Canonical checkout is landing-only; this work lives in its own worktree.
- `git var GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- No secrets in the public repo. 1Password via `op://` references and `mcp-launch.cmd` only.
- Destructive actions need a recoverable backup first (`windows-json-file.ps1` already backs up).
- PowerShell must stay compatible; run Bash tests through **Git Bash** (`C:\Program Files\Git\bin\bash.exe`), not WSL `bash`.
- JSONC comments are **not** preserved by the atomic JSON writer — say so in the writer header and docs.
- Never write skills into `~/.agents/skills` for MiMo-managed installs.
- Never start the Desktop GUI as a headless fallback.
- Never pass `--yolo` / `--dangerously-skip-permissions` from caller input into `mimo run`.
- One unproven outcome per session: if live `mimo run` is not proven in the landing session, open exactly one leftover-proof issue.

## 12. Access and environment

- Machine: edge-dev (Windows 11), Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- Authenticated: GitHub (`bin/ai-gh`), 1Password vault `vibe_coding` (service account; never print values).
- MiMo account login is interactive (`mimo account login` / Desktop `/login`) — not automated.
- Local run: from the worktree, Git Bash for `tests/*.sh`, PowerShell 7 for `tests/*.ps1`.
- Secrets by title only: `vibe_coding` / *"vibe_coding-service-account"*; 1Password MCP uses the shared launcher, no raw token in `mimocode.jsonc`.

## 13. Definition of done + risks and open questions

**Definition of done:**

- [ ] Steps 1–6, 8, 10–12 have artifacts named in STATUS.
- [ ] Step 7 and 9 remain N/A/out-of-scope with reasons.
- [ ] Offline tests green; ci-suite-manifest updated.
- [ ] PR merged to `origin/main`; merge commit reported.
- [ ] Docs updated; `ai-doc-reachability` PASS.
- [ ] Either live install verified on edge-dev, **or** exactly one leftover-proof issue opened in the landing session.
- [ ] BlockerWatch `mimo` keys present; live wake either proven or included in that one leftover-proof issue.

**Risks:**

| Risk | Rollback / mitigation |
|---|---|
| `mimo run` flags differ from docs | Wrapper fail-closed; re-qualify (Step 1) before loosening. |
| JSONC comment loss on MCP write | Backup + docs; do not rewrite if only foreign keys would change (idempotent no-op). |
| BlockerWatch wrong resume argv | First wake is a live proof; fix argv in a follow-up. |
| Skills collide with shared names | `Assert-NoSharedSkillCollisions` extended for `mimo`. |
| Desktop auto-update moves paths | Presence probe uses documented path + env override; doctor names the missing path. |

**Open questions:**

- ~~D10 exact `mimo run` flag set (needs CLI).~~ Resolved 2026-09-25: qualified live, `tests/verification/mimo-cli-2026-09-25/README.md`; one-time interactive `mimo providers login -p xiaomi` (browser) still pending before end-to-end runs.
- D11 BlockerWatch resume argv (needs live wake).
- D12 whether `instructions` should be force-ensured or only seeded once (default: ensure).
- Whether a `mimo` shim should wrap only the CLI or also print "use Desktop for interactive" when CLI is missing (default: shim requires CLI; doctor explains Desktop).

---

## Self-audit (implementation-plan-writer Mode A)

1. **Could a brand-new AI session execute this without asking?** Yes — §2 defines MiMo surfaces and paths, §5–6 carry live edge-dev facts and schema traps, §8 locks decisions D1–D9, §9 names files and verification gates, §11–12 name Git Bash, worktree, and secret rules. Remaining unknowns are explicitly OPEN (D10–D12) with fail-closed defaults.
2. **Does the plan carry background, nuance, and rejected approaches?** Yes — §3 trigger, §6 nine findings (array command, write-roots, no hooks, yolo trap, CLI absent, instructions key, session layout, JSONC, BlockerWatch), §7 seven rejected approaches.
3. **Is the ultimate goal clear enough for judgment calls?** Yes — §1 states managed parity without a MiMo reviewer, and says the goal wins on conflict.

Checklist: all 13 sections present; goal first; rejected approaches listed; steps name files + gates; locked/open labeled; out-of-scope explicit; tests named; secrets by location; DoD includes merge; handoff linked above.
