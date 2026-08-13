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
| ⚙ `secrets-to-1password` | **The quality gate on every 1Password MCP write** — secret or plain info note. Sweeps the session for credentials, or stores/updates a single entry you hand it, in the `vibe_coding` vault: searchable title, mandatory tags, and notes detailed enough for a future context-free session to find it, know what it's for, and use it. Checks for an existing entry first, and never stores a truncated value or reveals a live one to compare. Shared by Claude and Codex/ChatGPT. | "secrets sweep" / "any secrets not in 1password?" / "save this key" / "add this note to the vault" |
| ⚙ `handoff-writer` | Fresh-developer-grade handoff per `handoff-standard.md`: **one write-once file per session** at `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` (never a rewrite of the shared root `HANDOFF.md`, which is a static pointer), with a mandatory self-audit gate so it's never skimpy. Also owns legacy-`HANDOFF.md` migration and the delete-when-done retention rule. Shared by Claude and Codex. | "write the handoff" / "give me a prompt for a new session" |
| ⚙ `implementation-plan-writer` | Writes (or judges) an implementation plan a brand-new session with zero context can execute perfectly: ultimate goal in plain English first, all background, rejected approaches, locked-vs-open decisions, per-step files + verification gates, per `implementation-plan-standard.md`, with a mandatory self-audit gate. Every new plan gets a matching `HANDOFF.d/` entry, and the two files link to each other. Shared by Claude and Codex. | "write an implementation plan" / "plan how we'll build X" / "give another session a plan to implement this" |
| ⚙ `fresh-session` | Between phases of a plan: decides whether to cut over to a NEW session with a clean context window, grades the handoff + plan against ALL remaining phases (not just the next), and verifies the outgoing spec tells the implementer to re-read downstream phases for drift. Delegates the document to `handoff-writer`. Shared by Claude and Codex. Forward-looking counterpart to `close-old-session`. | "fresh session?" / "should this be a new session?" / "new context window?" |
| ⚙ `close-old-session` | Resuming a stale/abandoned session whose in-context "todo" list can't be trusted: verifies each pending doc/merge/commit item against ground truth (git + current .md + code) BEFORE acting, then delegates the actual work to `session-docs-update` / `wrap-up` / `dflow-ship`. Backward-looking counterpart to `fresh-session`. Shared by Claude and Codex. | "this chat is a week old" / "did we ever finish this?" / "picking this back up" |
| ⚙ `cleanup-worktree` | Audits, recovers, and safely removes stale linked worktrees and temporary repository copies created by Codex, Claude, or delegated agents on Windows, Linux, WSL, and macOS. Protects live sessions and unique uncommitted work; also explains and fixes “branch already used by worktree” errors. Shared by Claude and Codex. | "cleanup worktree" / "branch is already used by worktree" / "why is this under C:\tmp?" / "clean up old AI working folders" |

## Project setup

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `new-app-setup` | One-time briefing for a brand-new project: access-first credential request, container naming, docs/CI-CD standards (cross-references repo-docs-overhaul and cicd-rules-audit), DB choice, and initial file-count/cleanup pass. | "new project" / "set up a brand new app" |

## dflow (DesignFlow PLM)

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `dflow-session-start` | Syncs develop → your sandbox branch across all six repos; loads the standing dflow rules (branch policy, AG-Grid MCP, unit tests). | "pull develop into sandbox-albert" — or it fires automatically at dflow session start |
| ⚙ `dflow-ship` | Tests → commit → push → PR to develop → watches the Cloud Build deploy → verifies the sandbox site. | "push and commit" / "ship it" |
| ⚙ `design-handoff-implement` | Implements a Claude Design zip in the real stack, phase by phase, with visual verification. Shared by Claude and Codex. | attach the zip + "read the README in full" |

## Infrastructure & deploys

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `deploy-and-verify` | Ships hetz apps (poppim/popcrm/popdam/monitor/hiclaw): Actions → GHCR → Coolify, with both known Coolify quirks baked in; verifies the live build SHA. | "push and commit" (in those repos) / "the live site didn't change" |
| ⚙ `cicd-rules-audit` | Audits a repo's CI/CD against your full operating rules (embedded verbatim); fixes violations. | "audit CI/CD against our rules" |
| ⚙ `shared-db-change` | The proper way to change the shared supabase backend's STRUCTURE: migration discipline, shared-db authoring, correct project refs, type regeneration. Rule 0 = reading is open; Rule 0.5 = DATA is the app session's own (except bulk outside-sourced loads into curated Master Data). | fires on any shared-backend schema/structure change; "make db changes the proper way" |
| ⚙ `shared-db-orchestrator` | **Scope: STRUCTURE only** (owner ruling 2026-08-13, `AGENTS.md` §0.0-B) — schema/design changes. An app session's own row writes are NOT orchestrator work and must not be queued; the one data carve-out is bulk outside-sourced loads into curated Master Data (§6.4). Two audiences. **Anyone who NEEDS structural database work:** file it in the `## REQUEST QUEUE` of `COORDINATOR_INTAKE.md` instead of starting it — including "it's only a small change", which is the case that has caused the damage. **The coordinator:** OPENS and runs the `u2giants/shared-db` session — the five-step session-start hygiene sweep (real `origin/main` tip and max migration version from the repo, never a document; **read `HANDOFF.md`'s latest handover + `## BACKLOG` BEFORE the queues — an empty queue does NOT mean there is no work, and `HANDOFF.md` wins where they disagree**; then both queues; branch/worktree check), one coordinator that does no work itself, every task dispatched to an isolated sub-agent worktree, single-writer ownership of `supabase/migrations/`, never background task chips, plus the migration traps, the incident ledger, and the verification traps (applied ≠ rehearsed, name every migration version, verify an agent's "done" against the diff, `America/New_York` timestamps, null-permissive guards). | "I need a database change" / "can you add a column" / "how do I request database work" / "submit a request to the coordinator" / "work in shared-db" / "add a migration" / "run this with subagents" / "spin up agents" / "who's working on what" |
| ⚙ `shared-db-handover` | ENDS / hands over ANY shared-db session, two paths. **(A) not the coordinator:** stop all work and file a handover block into `COORDINATOR_INTAKE.md` at the repo root (that file owns the template). **(B) the coordinator:** the pre-handover sweep (move queue blocks along the lifecycle, confirm each finished branch is merged before retiring its worktree, flag anything deliberately left; delete a local branch only when merged and checked out nowhere, never delete remote branches by hand, never remove a dirty/locked/live worktree — use `cleanup-worktree`), the two-halves handoff — coordination state **and** one block per sub-agent — **plus the required queue seed: a handover is INCOMPLETE unless the `REQUEST QUEUE` in `COORDINATOR_INTAKE.md` has a short entry for every outstanding item (including every `HANDOFF.md` backlog `B<n>`), pointing at `HANDOFF.md` rather than duplicating it**, verify-then-move when ingesting an intake block, and the evidence obligations (re-run any rehearsal a later migration invalidated, name every migration version, check an agent's diff not its report). Extends `handoff-writer`; `wrap-up` routes here for database sessions. Work you have *not* started is a REQUEST, not an intake — see `shared-db-orchestrator`. | (A) "stop work and hand over" / "you are not the coordinator" / "transfer your work to the coordinator" / "write your handover into COORDINATOR_INTAKE" · (B) "hand this over" / "wrap up this session" / "write the handoff for what the subagents did" |
| ⚙ `synology-sharesync-triage` | Diagnoses and narrowly repairs Synology Drive ShareSync stalls using pairing, log, hash, and queue evidence. Shared by Claude and Codex/ChatGPT. | "check ShareSync health" / "a file is stuck syncing" |
| ⚙ `synology-long-running-operations` | Runs safe NAS reads that exceed Synology Monitor MCP's 25-second command budget as durable, low-priority background work without weakening the timeout. Shared by Claude and Codex/ChatGPT. | "scan all of /volume1" / "this NAS command will take longer than 25 seconds" / "run a long read-only NAS audit" |
| ⚙ `wb-starlabs-scrape` | Captures Warner STARLABS property-to-character source truth from the Product submission page and style-guide/file metadata from Art Assets without submitting jobs. Shared by Claude and Codex/ChatGPT. | "scrape Warner STARLABS" / "refresh Warner properties and characters" |

## Quality & analysis

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `repo-bug-audit` | Whole-codebase sweep across repos: bugs, silent failures, hard-coded values, inefficiency; uses parallel review agents when available and writes bugs.md. Shared by Claude and Codex. | "read the entire codebase and tell me if you find any bugs" |
| `designflow-e2e-tester` | AI-driven end-to-end/visual testing of the dflow app. | "run the E2E tester" (lives in designflow-frontend/.claude/skills) |

## Meta

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `claude-transcript-backup` | Finds all Claude Code transcripts on the machine, backs them up to claude_chats/<machine>. | "back up my Claude transcripts" |
| ⚙ `ai-development-pipeline` | The staged 7-step multi-model workflow (Opus plans/reviews, Codex implements/tests). | "run this through the pipeline" |
| ⚙ `codex-handoff` | Hand a build/ops/verification task to Codex (GPT-5.x): self-contained brief → run autonomously (background) → verify its work. Falls back to `codex exec` when the codex-cli MCP can't find the binary. | "use codex to…" / "have codex do X" |
| ⚙ `codex-second-opinion` | A debate, not a delegation: Claude commits to its own position first, Codex judges the material independently (read-only), Claude reports both and where it agrees — and on real disagreement argues back for one round and reports who moved. Ends in Agreed / Codex conceded / Claude conceded / Still split (with the crux). | "run this by codex and tell me if you agree" / "what does codex think" |
| ⚙ `kimi-code-delegation` | Delegates scoped coding tasks to Kimi Code CLI in headless mode. Reviews are structurally read-only. Write sessions resume the exact ID and cumulative code in a new disposable worktree each turn. Failed changed work stays nonzero and is never auto-applied. Shared by Claude and Codex/ChatGPT. | "use Kimi" / "delegate this to Kimi" |
| ⚙ `grok-cli` | Locates xAI's Grok Build CLI, routes questions to its installed version-matched documentation, and delegates read-only reviews or explicitly authorized implementation with Windows-aware safety controls. Shared by Claude and Codex/ChatGPT. | "ask Grok" / "use Grok CLI" / "where is Grok installed?" |
| ⚙ `qwen-code` | Invokes the installed Qwen Code CLI for an independent review, codebase analysis, or explicitly delegated implementation using the real local flags, captured output, and read-only review guardrails. Shared by Claude and Codex/ChatGPT. | "ask Qwen" / "run this by Qwen" / "use Qwen Code" |
| ⚙ `ask-glm` | Runs Z.ai GLM-5.2 as an isolated Claude Code coding agent with repository search, terminal/tests, multi-step work, read-only review defaults, 1Password key injection, and strict model verification. Shared by Claude and Codex. | "ask GLM" / "run this by GLM" / "use GLM-5.2" |
| ⚙ `sync-dotfiles` | Syncs this machine's AI config with the ai-devops hub: pulls the latest skills, global instructions and memory and installs them, sets the dflow gcloud defaults, and pushes local memory changes back. No chezmoi — ai-devops is the single hub. | "sync my dotfiles" / "pull the latest skills" |

## Codex-native skills

| Skill | What it does | Say this |
|---|---|---|
| ⚙ `codex-github-ship` | Syncs with GitHub, commits, pushes, creates/updates PRs when appropriate, and verifies CI/deploy/live SHA. | "push and commit" / "sync this repo with github.com" |
| ⚙ `codex-session-closeout` | Codex wrap-up: durable docs, handoff quality gate, secret hygiene, git/deploy evidence. | "wrap up" / "update the .md files" |
| ⚙ `codex-docs-update` | Updates only durable markdown docs for an existing project/task/session, without closeout, secrets, git, or deploy steps. | "update only the .md files" / "document this" |
| ⚙ `codex-repo-docs-overhaul` | Creates/rebuilds the standard AGENTS.md + docs set for a new repo or big application change. | "create the standard .md files" / "full documentation overhaul" |
| ⚙ `codex-dflow-plm` | Codex rules for DesignFlow PLM: sandbox sync, AG-Grid rules, browser-proof gates for UI fixes, PR to develop for Uma. | "DesignFlow session" / "sandbox-albert" |
| ⚙ `codex-shared-db-change` | Proper way to change the shared supabase backend's STRUCTURE from an app repo: author in `u2giants/shared-db` (branch+PR, preview-first, AI merges), never app-repo migrations or direct DDL, correct project refs, regenerate types. Does NOT gate DATA — app sessions own their own row writes (§0.0-B), except bulk outside-sourced loads into curated Master Data. | any shared-backend schema/structure change / "make db changes the proper way" / "all db work through shared-db" |
| ⚙ `codex-new-application` | New POP app bootstrap: repo, docs, tests, CI/CD, Hetz/Coolify deployment path when needed. | "set up a new application" |
| ⚙ `codex-cicd-pipeline` | Creates/audits GitHub → GHCR → deployment-platform pipeline rules. | "audit CI/CD" / "deploying from GitHub" |
| ⚙ `codex-context-optimizer` | Reduces token use by loading only needed docs, compressing repeated prompts, and creating reusable context. | "reduce my token usage" / "read only what you need" |
| ⚙ `codex-transcript-miner` | Finds/scrubs/analyzes Codex transcripts and promotes repeated prompts into skills/templates. | "analyze my Codex chats" / "find all Codex transcripts" |
| ⚙ `ai-reviewer` | Read-only Codex second-opinion review saved under `.ai/reviews/`. | "run a Codex review" |
| ⚙ `codex-sync-dotfiles` | Codex edition of `sync-dotfiles`: pulls the latest skills, global instructions and memory from the ai-devops hub and installs them, then pushes local memory back. | "sync my dotfiles" / "sync my config" |

## Always-on (not skills — loaded every session)

| Asset | What it covers |
|---|---|
| `~/.claude/CLAUDE.md` (from `templates/system/CLAUDE-global.md`) | Plain English, do-it-yourself, access-first, no band-aids, no silent failures, branch policies, verify-before-done, deprecated-systems list |
| Machine section (from `templates/system/machine-atlas.md`) | This machine's paths, quirks, SSH aliases, project refs, MCP endpoints |
| `~/.codex/AGENTS.md` (from `templates/system/AGENTS-global-codex.md`) | Same rules, Codex edition, with ritual summaries inline |
