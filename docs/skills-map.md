# Skills map — every skill, what it does, when to use it

One-page reference. Say the trigger phrase naturally, or force a skill with
`/skill-name`. Skills marked ⚙ install automatically via `bin/ai-install-skills`;
the others live where noted.

## Session rituals (the everyday ones)

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `wrap-up` | **The one-phrase closer.** Chains docs update → secrets sweep → handoff-safe state → push & verify, then one closing report. | **"wrap up"** |
| ⚙ `session-docs-update` | Routine end-of-session .md update — records what THIS session learned/changed. Includes secrets sweep + handoff-safe-state closers. | "update the .md files" |
| ⚙ `repo-docs-overhaul` | FULL documentation rebuild per the AI TASK SPEC — AGENTS.md router, all 15 required sections, ignore files. For new apps or after big changes. | "do a full documentation overhaul" |
| ⚙ `secrets-to-1password` | Sweeps the session for credentials, stores them in the `vibe_coding` vault with rich notes. | "secrets sweep" / "any secrets not in 1password?" |
| ⚙ `handoff-writer` | Fresh-developer-grade HANDOFF.md / fix_*.md / next-session prompt per `handoff-standard.md`, with a mandatory self-audit gate so it's never skimpy. | "write the handoff" / "give me a prompt for a new session" |

## Project setup

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `new-app-setup` | One-time briefing for a brand-new project: access-first credential request, container naming, docs/CI-CD standards (cross-references repo-docs-overhaul and cicd-rules-audit), DB choice, and initial file-count/cleanup pass. | "new project" / "set up a brand new app" |

## dflow (DesignFlow PLM)

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `dflow-session-start` | Syncs develop → your sandbox branch across all six repos; loads the standing dflow rules (branch policy, AG-Grid MCP, unit tests). | "pull develop into sandbox-albert" — or it fires automatically at dflow session start |
| ⚙ `dflow-ship` | Tests → commit → push → PR to develop → watches the Cloud Build deploy → verifies the sandbox site. | "push and commit" / "ship it" |
| ⚙ `design-handoff-implement` | Implements a Claude Design zip in the real stack, phase by phase, with visual verification. | attach the zip + "read the README in full" |

## Infrastructure & deploys

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `deploy-and-verify` | Ships hetz apps (poppim/popcrm/popdam/monitor/hiclaw): Actions → GHCR → Coolify, with both known Coolify quirks baked in; verifies the live build SHA. | "push and commit" (in those repos) / "the live site didn't change" |
| ⚙ `cicd-rules-audit` | Audits a repo's CI/CD against your full operating rules (embedded verbatim); fixes violations. | "audit CI/CD against our rules" |
| ⚙ `shared-db-change` | The proper way to change the shared supabase backend: migration discipline, shared-db authoring, correct project refs, type regeneration. | fires on any shared-backend DB change; "make db changes the proper way" |
| `synology-sharesync-stuck-triage` | Diagnoses/repairs stuck Synology Drive ShareSync between the two NASes, including the move-rename-move-back unstick. | "check ShareSync health" / "a file is stuck syncing" (installed on 916; in the synology-monitor repo) |

## Quality & analysis

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `repo-bug-audit` | Whole-codebase sweep across repos: bugs, silent failures, hard-coded values, inefficiency; one subagent per repo; writes bugs.md. | "read the entire codebase and tell me if you find any bugs" |
| `designflow-e2e-tester` | AI-driven end-to-end/visual testing of the dflow app. | "run the E2E tester" (lives in designflow-frontend/.claude/skills) |

## Meta

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `claude-transcript-backup` | Finds all Claude Code transcripts on the machine, backs them up to claude_chats/<machine>. | "back up my Claude transcripts" |
| ⚙ `ai-development-pipeline` | The staged 7-step multi-model workflow (Opus plans/reviews, Codex implements/tests). | "run this through the pipeline" |
| ⚙ `codex-handoff` | Hand a build/ops/verification task to Codex (GPT-5.x): self-contained brief → run autonomously (background) → verify its work. Falls back to `codex exec` when the codex-cli MCP can't find the binary. | "use codex to…" / "have codex do X" |

## Codex-native skills

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `codex-github-ship` | Syncs with GitHub, commits, pushes, creates/updates PRs when appropriate, and verifies CI/deploy/live SHA. | "push and commit" / "sync this repo with github.com" |
| ⚙ `codex-session-closeout` | Codex wrap-up: durable docs, handoff quality gate, secret hygiene, git/deploy evidence. | "wrap up" / "update the .md files" |
| ⚙ `codex-docs-update` | Updates only durable markdown docs for an existing project/task/session, without closeout, secrets, git, or deploy steps. | "update only the .md files" / "document this" |
| ⚙ `codex-repo-docs-overhaul` | Creates/rebuilds the standard AGENTS.md + docs set for a new repo or big application change. | "create the standard .md files" / "full documentation overhaul" |
| ⚙ `codex-dflow-plm` | Codex rules for DesignFlow PLM: sandbox sync, AG-Grid rules, browser-proof gates for UI fixes, PR to develop for Uma. | "DesignFlow session" / "sandbox-albert" |
| ⚙ `codex-shared-db-change` | Proper way to change the shared supabase backend from an app repo: author in `u2giants/shared-db` (branch+PR, preview-first, AI merges), never app-repo migrations or direct DDL, correct project refs, regenerate types. | any shared-backend DB/schema change / "make db changes the proper way" / "all db work through shared-db" |
| ⚙ `codex-new-application` | New POP app bootstrap: repo, docs, tests, CI/CD, Hetz/Coolify deployment path when needed. | "set up a new application" |
| ⚙ `codex-cicd-pipeline` | Creates/audits GitHub → GHCR → deployment-platform pipeline rules. | "audit CI/CD" / "deploying from GitHub" |
| ⚙ `codex-context-optimizer` | Reduces token use by loading only needed docs, compressing repeated prompts, and creating reusable context. | "reduce my token usage" / "read only what you need" |
| ⚙ `codex-transcript-miner` | Finds/scrubs/analyzes Codex transcripts and promotes repeated prompts into skills/templates. | "analyze my Codex chats" / "find all Codex transcripts" |
| ⚙ `ai-reviewer` | Read-only Codex second-opinion review saved under `.ai/reviews/`. | "run a Codex review" |

## Always-on (not skills — loaded every session)

| Asset | What it covers |
|---|---|
| `~/.claude/CLAUDE.md` (from `templates/system/CLAUDE-global.md`) | Plain English, do-it-yourself, access-first, no band-aids, no silent failures, branch policies, verify-before-done, deprecated-systems list |
| Machine section (from `templates/system/machine-atlas.md`) | This machine's paths, quirks, SSH aliases, project refs, MCP endpoints |
| `~/.codex/AGENTS.md` (from `templates/system/AGENTS-global-codex.md`) | Same rules, Codex edition, with ritual summaries inline |
