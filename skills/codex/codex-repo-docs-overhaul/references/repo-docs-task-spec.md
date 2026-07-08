AI TASK SPEC: Repository Documentation Maintenance
ROLE
You are an AI coding agent updating Markdown documentation for a software repository.
Your documentation must help future developers and future AI coding sessions understand the actual current state of the repository without relying on prior chat context.
Documentation is part of the work. It is not optional and not a final cleanup step.

PRIMARY OBJECTIVE
Make AGENTS.md the canonical operating guide and documentation router for future developers and AI coding sessions.
AGENTS.md MUST let a new senior engineer or AI session understand the repository in under 5 minutes.
AGENTS.md MUST prevent future AI sessions from ingesting every .md file unnecessarily.

ABSOLUTE RULES
MUST derive documentation from the actual repository state.
MUST inspect relevant code, config, scripts, workflows, migrations, deployment files, and existing docs before editing docs.
MUST NOT invent architecture, intent, future plans, deployment behavior, credentials, identifiers, business rules, or undocumented conventions.
MUST NOT document guesses as facts.
MUST mark unknowns clearly.
MUST explain how unknowns can be verified.
MUST NOT include secrets, tokens, passwords, private keys, or production credential values.
MUST keep documentation high-signal and specific.
MUST remove or fix stale, misleading, redundant, or vague documentation.
MUST avoid duplicating the same guidance across multiple docs.
MUST update docs in the same commit as code when the code change affects docs.
MUST explicitly say when a change does not require documentation updates.
SHARED DATABASE / BACKEND SOURCE OF TRUTH
If the session made any database, Supabase, migration, API contract, backend data-flow, auth/RLS, realtime, worker, or shared-backend change, MUST also update the canonical shared database repo:
```text
u2giants/shared-db
https://github.com/u2giants/shared-db
```
This applies even when the implementation happened inside an app repo. App repos may contain generated types, frontend adapters, workers, or local notes, but durable backend truth belongs in `u2giants/shared-db`.
For backend-relevant work, MUST document in `u2giants/shared-db`:
- What changed: tables, columns, views, RPCs, triggers, functions, RLS policies, realtime publications, storage assumptions, worker/backend behavior, generated database types, app-facing API contracts, or data-flow changes.
- Why it changed: product need, collision risk, bug, migration constraint, compatibility reason, operational assumption, or cross-app dependency.
- Who is affected: CRM, DAM, PM/PIM, Directus/PLM, workers, scripts, shared admin tooling, or more than one app.
- Where the durable implementation lives: migration filenames, SQL files, scripts, API view/RPC names, worker files, generated type files, and relevant app repo commits if known.
- What was verified: `scripts/check-sql.sh`, Supabase dry-runs, preview branch pushes, app builds, smoke tests, RLS/role tests, data-parity checks, worker tests, or why verification could not be completed.
- What remains risky or unfinished: production promotion status, data backfills, RLS gaps, app screens not migrated, deprecated contracts, rollback notes, open questions, or follow-up migrations.
Use the existing `shared-db` structure:
- Put cross-app operating rules or urgent warnings in `AGENTS.md` only when future AI sessions must see them immediately.
- Put schema/API ownership, relationships, migration risks, and implementation notes in the matching doc under `docs/`.
- Put app migration handoffs under `docs/app-migration-notes/<app>-YYYYMMDD.md`.
- Put reusable database or preview-branch verification evidence under `docs/verification/`.
- Add or update timestamped migrations under `supabase/migrations/`; never edit a migration that may already have been applied.
If a backend-relevant change was intentionally not documented in `u2giants/shared-db`, MUST state that explicitly in the final report and explain why.

REQUIRED DOCUMENTATION FILE ROLES
Use these roles exactly:
File
Role
README.md
Quick entry point and orientation
AGENTS.md
Canonical AI/developer operating guide
CLAUDE.md
Claude Code-specific instructions only
docs/architecture.md
System design, components, data flow, constraints
docs/development.md
Local setup, run/test/lint/debug workflow
docs/configuration.md
Environment variables, config files, feature flags
docs/deployment.md
Deploy/release/environment/rollback workflow
folder-level README.md
Local context for that folder only, when genuinely useful
HANDOFF.md
Temporary continuation document for unfinished work
Create missing docs only when useful.
Delete, rewrite, or consolidate docs that are obsolete, misleading, duplicated, or too vague to help future sessions.

REQUIRED AGENTS.md CONTENT
AGENTS.md MUST contain the sections below.
Use actual repository paths, commands, identifiers, and deployment details.
Do not leave generic placeholders unless the value is truly unknown.
If unknown, write unknown and explain how to verify it.

1. Project summary
MUST include one short business/technical summary.
The summary MUST explain:
what the project does
who uses it
key moving parts
the outcome that matters
Keep this brief.

2. Multi-model AI note
MUST include this text near the top:
## Multi-model AI note

There is no universal ignore-file standard across AI coding tools.

`.claudeignore` works for Claude Code.

When using any other AI tool, paste this file as your first message and follow the instructions in the "What to ignore" section.

3. Documentation map: what to read for each task
MUST include this section near the top.
Purpose: prevent future AI sessions from loading every .md file.
Use this structure:
## Documentation map: what to read for each task

Always start with:

- `AGENTS.md`

Then load additional docs only when relevant:

| Task / question | Read these docs | Usually do not need |
|---|---|---|
| Quick repo orientation | `README.md`, `AGENTS.md` | Deep docs under `docs/` unless task requires them |
| Modify app behavior or project-owned code | `AGENTS.md`, relevant folder-level `README.md`, `docs/architecture.md` if system design is affected | `docs/deployment.md` unless deploy behavior changes |
| Add or change configuration, env vars, feature flags, secrets, or runtime settings | `AGENTS.md`, `docs/configuration.md`, `docs/deployment.md` if prod/runtime env is affected | Unrelated architecture docs |
| Change local setup, dev scripts, test/lint/debug workflow, package scripts, or tooling | `AGENTS.md`, `docs/development.md`, relevant package/config files | `docs/deployment.md` unless CI/CD changes |
| Change deployment, Docker, CI/CD, hosting, release flow, rollback, or runtime environment | `AGENTS.md`, `docs/deployment.md`, `docs/configuration.md`, relevant workflow/deployment files | Local-only development docs unless needed |
| Change database schema, migrations, models, external IDs, or data flow | `AGENTS.md`, `docs/architecture.md`, `docs/configuration.md` if env/config is affected, relevant migration/model docs | Deployment docs unless rollout/deploy behavior changes |
| Investigate bugs or incidents | `AGENTS.md`, relevant docs based on affected area, `HANDOFF.md` if present, Critical incidents section in `AGENTS.md` | Unrelated folder-level READMEs |
| Continue unfinished work | `AGENTS.md`, `HANDOFF.md`, relevant docs named inside `HANDOFF.md` | Docs unrelated to the handoff scope |
| Work in a subfolder with its own README | `AGENTS.md`, that folder-level `README.md`, and only broader docs referenced there | Other folder-level READMEs |
| Claude Code session | `CLAUDE.md`, then `AGENTS.md` | Other docs unless task requires them |
| Documentation-only cleanup | `AGENTS.md`, `README.md`, affected docs under `docs/`, folder-level READMEs only where relevant | Source files except as needed to verify accuracy |
Rules:
MUST be task-based.
MUST NOT become a flat list of every Markdown file.
MUST distinguish always-read docs from task-relevant docs.
MUST identify docs that are usually unnecessary.
MUST mention HANDOFF.md as required reading when it exists.
MUST be updated when documentation files are added, removed, renamed, or repurposed.
MUST reduce context bloat.

4. Repository structure
MUST describe important directories.
MUST separate:
project-owned code
generated code
third-party/vendor/framework code
build artifacts
docs
scripts
migrations
deployment files
Use real paths.

5. Prime Directive: custom-code boundary
MUST explicitly list where project-owned custom code belongs.
Use this format and adapt paths to the repo:
## Prime Directive: custom-code boundary

Our custom code lives here:

- `src/modules/[project-name]/`
- `src/app/[project-owned-routes]/`
- `docs/`
- `.github/workflows/`

Everything else requires justification before touching.
Purpose: prevent AI agents from scattering project logic into unrelated framework, vendor, generated, or third-party files.

6. Core modification inventory
MUST list any modified files outside project-owned areas.
MUST keep the section even if empty.
Use this format:
## Core modification inventory

| File | Change made | Why it was necessary | Risk during upgrades |
|---|---|---|---|
| `path/to/file` | Short description | Specific reason | What to check later |
If no files outside project-owned areas were modified, write that explicitly.

7. Task-to-file navigation: what to edit for common changes
This is NOT the same as the documentation map.
Documentation map = what docs to read.
Task-to-file navigation = what source/config/deployment files to edit or avoid.
Use this format:
## Task-to-file navigation: what to edit for common changes

| Task | Files to touch | Files not to touch |
|---|---|---|
| Change login screen | `src/...` | `vendor/...` |
| Add database field | `db/migrations/...`, `src/models/...` | Existing applied migrations |
| Add new setting | `src/config/...`, `docs/configuration.md` | Production `.env` directly |
MUST use actual repo paths when known.

8. Data model and external identifiers
MUST document important:
entities
fields
UUIDs
container names
project IDs
webhook names
deployment targets
external-system IDs
Use this format:
## Data model and external identifiers

| Entity/System | Identifier | Where defined | Notes |
|---|---|---|---|
| Customer | `customer_id` | database | UUID |
| Coolify app | `[uuid]` | Coolify | Production deploy target |
| Supabase project | `[project-id]` | Supabase | Database backend |
MUST NOT casually rename, regenerate, or replace documented identifiers.

9. Container and service inventory
MUST list every relevant runtime service/container.
Use this format:
## Container and service inventory

| Container/service | Purpose | Managed by | App/project ID | Image/source |
|---|---|---|---|---|
| `app-web` | Frontend web app | Coolify | `[uuid]` | `ghcr.io/...` |
| `app-db` | Database | Compose/Coolify | `[uuid]` | postgres |
If there are no containers/services, say so.

10. What to ignore
MUST list files/directories that exist but should not consume AI context.
Include relevant examples such as:
node_modules/
dist/
.cache/
coverage/
generated SDKs
vendor examples
third-party docs
build artifacts
MUST match ignore-file entries where appropriate.

11. Intentional quirks and non-obvious decisions
MUST document anything that looks wrong, duplicated, overcomplicated, unusual, or counterintuitive but is intentional.
Use this exact format:
### [Decision name]

Looks like:
[How a new developer or AI session might misread it.]

Actually:
[What it really is.]

Why:
[Constraint, incident, requirement, or tradeoff.]

Do not change because:
[What would break or become worse.]
MUST NOT invent quirks.

12. Credentials and environment
MUST list required variables without secret values.
Use this format:
## Credentials and environment

| Variable | Purpose | Stored where | Required in dev | Required in prod |
|---|---|---|---|---|
| `DATABASE_URL` | Database connection | Coolify env | yes | yes |
| `OPENROUTER_API_KEY` | AI model calls | Coolify env | yes | yes |
MUST NOT include actual secret values.
MUST include variables found in:
example env files
code
config files
deployment files
workflows
docs

13. Deployment
MUST document the real deployment path.
Include:
GitHub Actions workflow name
image/package names
tag pattern
deployment platform/app/project ID
deploy trigger method
rollback method
where runtime environment variables live
whether SSH is allowed
whether SSH is routine or exceptional
MUST NOT describe an ideal deployment process unless it is the real process.

14. Critical incidents
MUST document disasters, near-misses, migrations, broken deploys, data loss risks, or important recovery lessons.
MUST keep the section even if empty.
Use this format:
## Critical incidents

### [YYYY-MM-DD] [Incident title]

What happened:
...

Impact:
...

Root cause:
...

Recovery:
...

Rule added to prevent recurrence:
...
If there are no known incidents, write that directly.

15. Pending work
MUST keep pending work current.
Use this format:
## Pending work

| Status | Item | Owner/next action |
|---|---|---|
| open | Add email sending | Needs SMTP credentials |
| blocked | Deploy production | Waiting for Coolify app ID |
| done | Initial Dockerfile | Completed in commit `[sha]` |
MUST remove completed stale items or mark them done.
MUST NOT leave stale pending work.

CLAUDE.md RULES
CLAUDE.md MUST stay short.
CLAUDE.md MUST NOT duplicate AGENTS.md.
CLAUDE.md MAY include only:
Read AGENTS.md first
Claude Code-specific memory/context notes
.claudeignore guidance
allowed operations/tools/APIs
SSH permissions, if any
explicit note that SSH is not the normal deployment path unless actually true
commit style preferences
Claude-specific behaviors to enable or suppress
If guidance applies to all AI agents or all developers, put it in AGENTS.md, not CLAUDE.md.

IGNORE-FILE RULES
MUST create or update these files when appropriate:
.claudeignore
.cursorignore
MUST use matching content unless there is a tool-specific reason not to.
Standard entries:
dist/
node_modules/
.cache/
coverage/
MUST add generated, third-party, vendor, build, or cache directories that should not consume AI context.
MUST create .copilotignore if the repository uses GitHub Copilot and ignore rules matter there.
Ignore files MUST align with the “What to ignore” section of AGENTS.md.

HANDOFF RULE
IF any work is unfinished, blocked, or in progress:
MUST create HANDOFF.md in repo root.
MUST make it comprehensive enough for a new developer or AI session to continue without prior chat context.
MUST mention HANDOFF.md in AGENTS.md as required reading for continuation work.
HANDOFF.md MUST include:
what was being built or fixed and why
what is fully done
what is partially done and exact current state
future plans discussed during the session
what has not been started
decisions made and why
dead ends or abandoned approaches
exact next action
known risks, blockers, or unknowns
session context that would otherwise be lost
IF the work described in HANDOFF.md is complete:
MUST delete HANDOFF.md.

REQUIRED AI WORKFLOW
Follow this sequence:
Inspect repository structure.
Identify owned code, generated code, vendor/framework code, docs, scripts, migrations, deployment files, and build artifacts.
Inspect existing Markdown docs.
Determine which docs are stale, missing, redundant, or misleading.
Update AGENTS.md first.
Update supporting docs only where topic-specific detail belongs.
Update README.md only for quick orientation.
Update CLAUDE.md only for Claude-specific notes.
Update folder-level README.md files only where local folder context is useful.
Update .claudeignore, .cursorignore, and .copilotignore if applicable.
Create, update, or delete HANDOFF.md according to the handoff rule.
Verify documentation against actual repository files.
Check that no secrets were added.
Commit and push documentation changes to GitHub.
Provide final completion report.

VERIFICATION GATES
Before final response, verify:
AGENTS.md exists.
AGENTS.md contains the required sections.
AGENTS.md includes the documentation map.
Documentation map routes tasks to docs instead of telling agents to read everything.
CLAUDE.md does not duplicate AGENTS.md.
Ignore files match documented ignore guidance where appropriate.
Env vars are listed without secret values.
Deployment docs describe actual deployment, not guesses.
HANDOFF.md exists if and only if work is unfinished, blocked, or in progress.
No secrets were written.
Stale docs were removed, corrected, or clearly marked.

FINAL COMPLETION REPORT
After committing and pushing, final response MUST include:
## Documentation changes

| File | Change |
|---|---|
| `path/to/file.md` | Summary of change |

## Ignore files

| File | Change |
|---|---|
| `.claudeignore` | Summary of change |

## Handoff status

- `HANDOFF.md`: present/absent
- Reason: ...

## Verification

- Docs verified against actual repo: yes/no
- Secrets added: yes/no
- Unknowns remaining: ...

## Remaining documentation gaps

- ...
If no documentation changes were required, final response MUST say so and explain why.
Is Handoff.md comprehensive enough that a brand new fresh developer with no knowledge of this project and no context into what we did and what’s left to do would be able to pick up where you left off and not skip a beat? Is it detailed enough that they would be able to continue as well as you with all you knowledge from this session?