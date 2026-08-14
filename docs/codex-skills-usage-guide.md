# Codex skills usage guide

Codex now has repo-owned skills under `skills/codex/`, plus cross-client skills
under `skills/shared/`. Install them on **Ubuntu or Git Bash** with:

```bash
./bin/ai-install-skills
```

On **Windows** use the native PowerShell installer instead — see
[Windows install/update](#windows-installupdate) below.

The installer copies them to `~/.codex/skills/` when `~/.codex` exists and keeps
`templates/system/AGENTS-global-codex.md` as the global standing instruction
file. It **never replaces an existing `~/.codex/AGENTS.md`** — to do that, run
`bash bin/ai-adopt-globals`, which preserves that machine's own facts and proves
it with a diff. See
[skills-usage-guide.md](skills-usage-guide.md#replacing-an-installed-global-that-already-exists--use-binai-adopt-globals).

If you are deciding **where a rule or fact should live** (global vs machine vs
repo vs topic doc vs skill vs memory vs plan vs handoff), read the context
ownership map in
[`context-engineering.md`](context-engineering.md) before adding it here.

## What replaces what

| You used to type | Now say |
|---|---|
| "push and commit" / "commit and push" / "is everything pushed and committed?" | "use `codex-github-ship`" or just "push and commit" |
| "sync this repo with github.com" / "pull latest repo from github.com" | "use `codex-github-ship`" |
| "update the .md files, but do not close out / commit / deploy" | "use `codex-docs-update`" |
| Long end-of-session documentation prompt | "use `codex-session-closeout`" or "wrap up" |
| `update_.md.docx` / "create the standard .md files for this repo" | "use `codex-repo-docs-overhaul`" |
| `uma_designflow_prompt.docx` / DesignFlow sandbox start/end workflow | "use `codex-dflow-plm`" |
| `new application one big prompt.docx` / "set up a brand-new app" | "use `codex-new-application`" |
| `devops procedure deploying from github.docx` / CI/CD rules | "use `codex-cicd-pipeline`" |
| "is HANDOFF.md comprehensive enough for a fresh developer?" | "use `handoff-writer`" |
| "read all docs and handoff, then keep only useful context" | "use `codex-context-optimizer`" |
| "reduce my token usage / stop making me paste the same prompt" | "use `codex-context-optimizer`" |
| "find all local Codex transcripts / analyze repeated prompts" | "use `codex-transcript-miner`" |
| "branch is already used by worktree" / "clean up stale Codex and Claude worktrees" | "use `cleanup-worktree`" |
| "write the plan for this — but the session implementing it won't have any of this context" | "use `implementation-plan-writer`" |

## Skill map

- `codex-github-ship`: GitHub sync, commit, push, PR, CI/deploy/live SHA
  verification.
- `codex-docs-update`: doc-only durable markdown update, with no closeout side
  effects.
- `codex-repo-docs-overhaul`: standard new-repo/big-change documentation system.
- `codex-dflow-plm`: DesignFlow PLM sandbox branch, AG-Grid, browser-proof
  verification for UI fixes, and Uma PR rules.
- `codex-new-application`: brand-new app setup, docs, CI/CD, and optional
  Hetz/Coolify deploy path.
- `codex-cicd-pipeline`: GitHub/GHCR/Coolify CI/CD creation and audit rules.
- `codex-session-closeout`: docs update, handoff quality gate, secret hygiene,
  git state, and final evidence report.
- `codex-context-optimizer`: minimal context loading, prompt compression, and
  lower-cost model guidance.
- `codex-transcript-miner`: transcript discovery, safe analysis, repeated prompt
  mining, and skill recommendations.
- `ai-reviewer`: existing read-only Codex second-opinion review skill.
- `synology-sharesync-triage`: proves and narrowly repairs Synology Drive
  ShareSync stalls using NAS state, logs, and SQLite evidence.
- `kimi-code-delegation`: delegates scoped coding tasks to Kimi Code CLI in
  headless mode. Write sessions keep the exact Kimi conversation and one
  cumulative patch while rebuilding a disposable worktree for every turn.
  `ask` is a write run for an implementation session. Complete and incomplete
  patches require local review and are never applied automatically.
- `grok-cli`: locates the installed Grok Build CLI, reads its version-matched
  local docs, and delegates read-only reviews or explicitly authorized edits.
- `implementation-plan-writer`: writes (or judges) an implementation plan a
  brand-new session with zero context can execute perfectly — ultimate goal in
  plain English first, full background, rejected approaches, locked-vs-open
  decisions, per-step files and verification gates, per
  `templates/system/implementation-plan-standard.md`.
- `handoff-writer`: writes or judges a fresh-developer-grade handoff with the
  canonical nine-section structure and mandatory self-audit gate.
- `design-handoff-implement`: implements a Claude Design export in the existing
  application stack and requires source-driven visual verification.
- `repo-bug-audit`: audits one or more complete repositories for correctness,
  silent failures, hard-coded configuration, and inefficient code.
- `cleanup-worktree`: safely inventories, recovers, and removes stale Codex,
  Claude, and delegated-agent worktrees or temp clones across Windows and
  POSIX systems without losing unique work.
- `deepseek-second-opinion`: runs a genuine bounded debate through
  `ai-deepseek-agent`. DeepSeek receives only the text and files explicitly
  attached by the parent. A Codex custom-provider path was cancelled on
  2026-08-10 because Codex 0.145.0 requires the Responses API wire format and
  DeepSeek documents tool calls through Chat Completions.

The installer fails before copying when a shared skill name collides with a
client-specific skill. Quarantine of an obsolete managed skill is **automatic and
recoverable**; `--migrate-obsolete` is still accepted but is now a no-op, kept
only so older commands do not break. See `docs/design-decisions.md`.

## Maintenance rule

When you notice yourself pasting the same Codex instruction for the third time,
turn it into one of three things: a Codex skill, a repo `AGENTS.md` rule, or a
machine-atlas fact. Do not let repeated prompt text remain only in chat history.

## Windows install/update

On any Windows computer, paste this into PowerShell:

```powershell
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/u2giants/ai-devops.git $p} else {git -C $p pull --ff-only}; powershell -ExecutionPolicy Bypass -File "$p\bin\install-ai-devops-windows.ps1"
```

That one command clones or pulls this repo, installs Claude and Codex skills,
and seeds global instruction files without overwriting local edits.
