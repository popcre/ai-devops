# POP Creations — New Project Standard

This is the one-prompt briefing for every new software project.

Give this entire document to any AI agent at the start of any new engagement.

This is a living document. Update it after every project when better practices are discovered.

---

## 1. Who You Are Working With

My name is Albert.

I am not a programmer, not a DevOps engineer, and not a sysadmin. I am a business owner who works with AI to build and operate software. I describe what I need in plain business terms and rely on you to translate that into code, infrastructure, deployment, documentation, and decisions.

### What this means for how you work

- Take ownership of the full technical job.
- Write the code.
- Set up the repo.
- Configure the workflow.
- Configure the deployment platform.
- Run the migrations through the approved migration path.
- Check logs through the approved platform or access method.
- Update documentation as you work.
- Do not hand me a runbook and call the job done.
- Execution is part of the job.

### Access-first rule

Before writing a single line of code or documentation, think through the entire project and ask me for all access you reasonably expect to need.

Do not ask for one credential at a time as you discover needs. Think ahead.

Ask for everything upfront:

- source control access
- deployment platform access
- registry access
- database access
- third-party API keys
- domain/DNS access
- email provider access
- storage provider access
- monitoring/logging access
- any project-specific service credentials

### Manual-action rule

Before asking me to run a command or click something, first ask me to give you the access needed to do it yourself.

If you genuinely cannot do something without my manual action, explain exactly what I need to do in one short instruction.

Do not give me a long multi-step procedure unless there is no realistic way for you to do the work directly.

---

## 2. First Task: Ask for Everything You Need

Before writing code, documentation, workflow files, migrations, or configuration, respond with a project-specific access request.

Use this format:

```markdown
To fully set up and operate this project autonomously, I need:

## Required access

- [ ] GitHub access or GitHub Personal Access Token with permission to create repos, manage secrets, and trigger workflows
- [ ] Deployment platform access, such as Coolify base URL and API token or deploy webhook
- [ ] Container registry access if not using the repo's built-in GitHub Actions token
- [ ] Database access or database project credentials
- [ ] Domain/DNS access if this project needs a public hostname
- [ ] Any third-party API keys specific to this project

## Possibly needed access

- [ ] Server SSH access only if needed for initial server setup, migration, emergency debugging, or verifying server state
- [ ] Email provider credentials if the app sends email
- [ ] Object storage credentials if the app stores files
- [ ] Payment provider credentials if the app takes payments
- [ ] Monitoring/logging credentials if the app needs observability

Please provide as many of these as you can now.
```

Adapt the list to the actual project.

Do not ask for SSH access as the default deployment method. SSH is not the normal deployment path. It is only for initial setup, migration, emergency debugging, or situations where the deployment platform cannot provide the needed visibility.

---

## 3. Container Naming Standard

Every container must be named so it is immediately recognizable months later in a list of many containers on the server.

Random or auto-generated names are not acceptable for project-owned services.

### Format

```text
[app-abbreviation]-[function-abbreviation]
```

### Examples

| Container name | What it is |
|---|---|
| `popcmr-api` | POP CRM — backend API service |
| `popcmr-web` | POP CRM — frontend web app |
| `popcmr-worker` | POP CRM — background job worker |
| `popdam-api` | PopDAM — backend API service |
| `popdam-web` | PopDAM — frontend web app |
| `oclaw-gate` | OpenClaw — AI gateway |
| `oclaw-mc` | OpenClaw — Mission Control coordinator |
| `dfflow-api` | DesignFlow — backend API |

### Rules

- Abbreviate the application name to 4-8 lowercase characters.
- Abbreviate the function to a short, obvious word.
- Good function names: `api`, `web`, `worker`, `db`, `proxy`, `cron`, `gate`, `mc`, `sync`.
- Use a hyphen as the separator.
- Do not use underscores.
- Do not use capitals.
- Do not use spaces.
- Document the container name in `AGENTS.md`.
- Once a container is in production, treat the name as permanent.
- Do not rename running production containers unless there is a documented migration reason.

---

## 4. Standard Documentation and Markdown Maintenance — Every Project

This section replaces the older documentation checklist with the updated repository-documentation maintenance rules. Documentation must be created and maintained as part of the work, not as a final cleanup step.

This is the same "AI TASK SPEC: Repository Documentation Maintenance" that the `repo-docs-overhaul` skill implements in full — see `skills/claude/repo-docs-overhaul/TASK-SPEC.md` for the complete verbatim spec (required AGENTS.md sections, file roles, ignore-file rules, HANDOFF.md rule, required AI workflow, verification gates, and final completion report format). For a brand-new project, run that skill (or follow its spec directly) rather than re-deriving it here.

Summary of what it requires:

- `AGENTS.md` is the canonical operating guide and documentation router — a new senior engineer or AI session must understand the repo from it in under 5 minutes, and it must prevent future sessions from ingesting every `.md` file.
- Fixed file roles: `README.md` (orientation), `AGENTS.md` (canonical guide), `CLAUDE.md` (Claude-only, never duplicates AGENTS.md), `docs/architecture.md`, `docs/development.md`, `docs/configuration.md`, `docs/deployment.md`, folder-level `README.md` only where genuinely useful, `HANDOFF.md` only while work is unfinished.
- Everything documented must be derived from actual repository state — never invented, with unknowns marked and how to verify them explained, and no secrets ever written.
- `.claudeignore` / `.cursorignore` (and `.copilotignore` if Copilot is used) must match the "What to ignore" section.

---

## 5. Standard DevOps Pipeline and CI/CD Operating Rules — Every Project

This section replaces the older deployment, GitHub Actions, quality-gate, and CI/CD operating-rule material with the updated Coolify/GitHub/GHCR deployment procedure.

This is the same rule set the `cicd-rules-audit` skill audits repos against — see `skills/claude/cicd-rules-audit/CICD-RULES.md` for the complete verbatim rules (system of truth, branch policy, deployment-platform pattern, image tagging, rollback, deploy triggers, enforcement, secrets, compose/infrastructure ownership, forbidden AI actions, and repo-specific override process). For a brand-new project, run that skill (or follow its rules directly) rather than re-deriving them here.

Summary of what it requires:

- **System of truth:** GitHub owns code, Dockerfiles, Compose files, IaC files, deployment docs, and GitHub Actions workflows. The container registry owns published build artifacts. The deployment platform (Coolify) owns runtime environment variables, domains, health checks, restart policy, and deployment execution. Production servers are runtime hosts only, never configuration sources.
- **Normal release path:** `verify -> build -> publish image -> trigger deployment platform`. GitHub Actions must not SSH into the production server, edit production files, run `docker run`/`docker compose up` on the server, or change runtime configuration directly as part of the normal path.
- **Branch policy:** follow the repo's actual branch policy; treat `main` as the only release branch unless the repo already documents a real promotion model.
- **Image tags:** publish explicit, traceable tags (`main`, `sha-<commit-sha>`, optionally a semantic version). Rollback happens by redeploying a previous immutable image tag through the deployment platform, not by hand-editing the server.
- **Enforcement over documentation:** remove routine SSH deploy steps and now-unused SSH keys/credentials from GitHub Actions and Secrets so the wrong path is hard to reintroduce; make the deploy job depend on verification/build/publish via native `needs`.
- **SSH is exception-only:** allowed for debugging a production incident, one-time migration off an old deployment path, emergency break-glass repair, log collection the platform can't provide, or verifying server state during migration — never as the normal deployment method. Any emergency SSH fix must be committed back to the repo (or recorded in the deployment platform) immediately afterward.
- **Secrets split:** GitHub Secrets hold CI/CD and build-time secrets (registry credentials, deployment-platform API token/webhook secret, project ID if needed). The deployment platform holds production runtime environment variables. The server holds no manually maintained app secrets.
- **Deployment platform ownership:** Coolify (or equivalent) directly owns runtime env vars, feature flags/behavior switches, domain/port bindings, health checks, restart policy, resource limits, and deployment target settings — AI may modify these directly in Coolify since GitHub has no meaningful representation for pure runtime state. Coolify must never own application source code, Dockerfile changes, Compose/IaC changes, or GitHub Actions workflow changes — those always go through GitHub.
- **Database migrations:** committed through the repo's approved migration path; never hidden inside one-off production server commands.

---

## 6. Server Folder Structure

Production should not depend on manually maintained server folders.

If a `/worksp/` structure is used, treat it as an operator convenience, not the production deployment source of truth.

The approved deployment path is still:

```text
GitHub -> GitHub Actions -> GHCR -> Coolify -> production runtime host
```

Not:

```text
/worksp repo checkout -> manual docker commands -> production
```

### Optional server workspace convention

If a workspace is maintained on the server for inspection, debugging, or emergency operations, use this structure:

```text
/worksp/<app-name>/
├── app/
│   ├── .git/
│   ├── src/
│   ├── Dockerfile
│   └── ...
└── server -> /data/coolify/applications/<coolify-app-id>
    ├── .env
    ├── docker-compose.yaml
    └── README.md
```

### Rules

- `/worksp/<app-name>/app` is not the production deployment source.
- Do not deploy by manually running commands from `/worksp/<app-name>/app`.
- Do not edit `/worksp/<app-name>/server/.env` as the normal way to change runtime configuration.
- Runtime configuration belongs in Coolify.
- If the server workspace exists, document it in `AGENTS.md`.
- If the server workspace does not exist, do not create it unless there is a clear operational reason.

### Optional setup commands

Only use these for initial server organization or emergency/operator convenience:

```bash
mkdir -p /worksp/<app-name>
git clone <your-git-repo-url> /worksp/<app-name>/app
ln -s /data/coolify/applications/<coolify-app-id> /worksp/<app-name>/server
```

### Finding the Coolify app ID

Prefer the Coolify UI or API.

If server shell access is already available and appropriate, the app ID may be inspected from the Coolify container.

Document the final app ID or UUID in `AGENTS.md`.

---

## 7. Database and Schema Standards

Not every project uses a database.

Not every project uses Supabase.

Apply only the section that matches this project.

### 7.10a. Supabase cloud-hosted Postgres

Use this when the project is connected to a Supabase project.

All schema changes go into numbered SQL migration files.

Never apply schema changes directly to the production database outside the approved migration path.

**Migration workflow**

- All schema changes go into numbered SQL files in `supabase/migrations/`.
- Commit the migration file to `main`.
- The approved migration workflow applies it.
- Do not run migrations directly against the production database as the normal path.
- Never modify a migration file after it has been applied to any environment.
- If rollback capability is needed, create a new migration that reverses the change.

**Supabase-specific rules**

- Row-level security must be explicitly enabled or disabled for every table.
- Do not leave row-level security in an undefined state.
- Supabase Edge Functions live in `supabase/functions/`.
- Deploy Edge Functions through the approved CLI/workflow path, not by editing the cloud console directly.
- Service role keys are server-side only.
- Never expose service role keys to frontend code.
- Never commit service role keys to the repo.
- Reference secrets through GitHub Secrets or Coolify environment variables as appropriate.
- Record the Supabase project ID in `AGENTS.md`.

### 7.10b. Internal database

Use this when the project manages its own database container rather than using Supabase.

Examples:

- Postgres
- MySQL
- MariaDB
- SQLite
- another project-owned database

**Container naming**

The database container follows the standard naming convention:

```text
[app]-db
```

Examples:

```text
popcmr-db
popdam-db
dfflow-db
```

Do not use generic names like:

```text
postgres
database
db
```

unless it is inside a local-only development Compose stack and cannot be confused with production.

**Migration workflow**

- Migrations live in `db/migrations/` or `migrations/`.
- Migration files are numbered sequentially.
- Example: `001_init.sql`, `002_add_users.sql`.
- Use a migration runner.
- Acceptable tools include Flyway, Liquibase, golang-migrate, Prisma migrations, Alembic, Rails migrations, Django migrations, or a framework-native equivalent.
- Do not apply schema changes manually as the normal path.
- Every migration is forward-only unless the framework has a clear rollback model.
- If rollback capability is needed, write a separate rollback migration file.
- Migration files, once committed and applied, are never modified.

**Backup and persistence**

- Database data must be stored in a named Docker volume or managed database storage.
- Do not store production database data only inside the container filesystem.
- Containers are ephemeral.
- Volumes and managed database storage are persistent.
- Document the volume name or managed database project in `AGENTS.md`.
- For production databases, set up scheduled backups.
- Document where backups go.

**Credentials**

- Database connection strings and passwords are stored as deployment-platform runtime environment variables.
- Do not hardcode credentials.
- Use a dedicated application user with minimum necessary privileges.
- Do not connect as root or superuser from application code.

### 7.10c. No database

If this project has no database, explicitly record that in `AGENTS.md`.

Use this wording:

```markdown
## Data model

This project currently has no database.

That is intentional. Do not add a database unless a feature clearly requires persistence.
```

This prevents future developers from treating the absence of a database as an oversight.

---

## 8. Code Quality Standards

### Custom code belongs in custom directories

Never scatter project-specific logic into third-party framework directories.

Create a dedicated module or project-owned area.

Examples:

```text
src/modules/[project-name]/
src/features/[feature-name]/
app/[project-owned-routes]/
packages/[project-owned-package]/
```

The goal is to make upstream merges clean and make project ownership obvious.

### Registry/plugin patterns over repeated core modifications

When a framework needs to know about custom components, routes, handlers, widgets, or tools, prefer a registry pattern.

Good pattern:

```text
custom registry file -> imported once by framework extension point
```

Bad pattern:

```text
edit the same core framework file repeatedly for every new feature
```

Design for this from the first custom extension point.

### Identifiers are permanent

Any UUID, database ID, slug, external-system identifier, Coolify app UUID, Supabase project ID, webhook ID, or registry name assigned to an entity must be treated as permanent once used in any environment.

Record identifiers in one place:

- `AGENTS.md`
- or a dedicated identifier map file

Do not duplicate identifiers inline across many files.

### AI API calls

When the project needs AI model calls, use OpenRouter unless Albert explicitly says otherwise.

Rules:

- Use one endpoint.
- Use one API key.
- Do not add provider-specific keys such as separate OpenAI, Anthropic, or Google keys unless the project has a documented reason.
- Store the OpenRouter API key in the deployment platform as a runtime secret.
- Do not expose AI API keys in frontend code.
- Document model IDs in `AGENTS.md` and `docs/configuration.md`.

Preferred model configuration should be centralized.

Do not scatter model IDs throughout the codebase.

### Never modify a running container

Code change path:

```text
code change -> commit -> push -> workflow -> image -> deployment platform -> production
```

Do not patch production containers manually.

Do not hot-edit files inside containers as a final fix.

If emergency debugging requires manual inspection, convert the permanent fix into a repo commit immediately afterward.

---

## 9. Multi-Session Documentation Discipline

Multiple developers, AI agents, and AI sessions will work on every project.

Documentation discipline prevents them from undoing each other's work.

### Rules for every session

1. Update `AGENTS.md` with every significant change.
2. If a new service is added, update the container inventory.
3. If a new route is added, update the task-to-file map or decision tree.
4. If a bug is fixed with an unusual approach, add it to Idiosyncratic Decisions.
5. Document every non-obvious decision at the time it is made.
6. Do not wait until later.
7. The next AI session will not remember your reasoning.
8. Before closing a session, run the new-developer test.
9. Keep Pending Work current.
10. Mark completed items done.
11. Add newly discovered incomplete items.
12. After any upstream merge or dependency upgrade, update the Core Modification Inventory.

### The new-developer test

Before ending any session, ask:

```text
If a brand new senior developer opened this repo right now with no prior context, would AGENTS.md give them enough information to work productively without asking questions?
```

If the answer is no, update `AGENTS.md`.

### Highest-priority documentation

Idiosyncratic decisions are the highest priority.

Anything that looks wrong but is intentional must be documented with full context before the session ends.

---

## 10. Immediate Action List on Receiving This Prompt

When you receive this prompt in any project context, do the following in order.

Do not skip steps.

Do not reorder them.

### Step 1: Inspect the project

Read the existing project structure.

Report:

- top-level directories
- key files
- package managers
- framework
- existing Dockerfiles
- existing workflows
- existing deployment docs
- existing database/migration setup
- obvious missing pieces

### Step 2: Ask Albert for all needed access

Ask for a comprehensive list of credentials and access.

Do not ask piecemeal.

Include only access that is relevant to the project.

Clearly separate required access from optional access.

### Step 3: Count files and identify deletion candidates

For existing projects, count files and identify irrelevant third-party bloat before building new features.

Use commands appropriate to the environment.

Example:

```bash
find . -type f | grep -v node_modules | grep -v .git | wc -l

find . -maxdepth 2 -type d | while read d; do
echo "$(find "$d" -type f 2>/dev/null | grep -v node_modules | wc -l) $d"
done | sort -rn | head -20
```

### Step 4: Propose deletions

Report back with a deletion proposal.

List:

- what you would remove
- why it appears safe
- what risk exists
- how it could be restored

Wait for a quick approval before deleting anything significant.

### Step 5: Delete approved items

After approval:

- delete approved items
- update `.gitignore`
- update package workspaces if needed
- update docs to reflect the leaner codebase

### Step 6: Create ignore files

Create:

- `.claudeignore`
- `.cursorignore`
- `.copilotignore` if appropriate

### Step 7: Create project docs

Create or update:

- `AGENTS.md`
- `CLAUDE.md`
- `docs/architecture.md`
- `docs/development.md`
- `docs/configuration.md`
- `docs/deployment.md`

### Step 8: Set up or verify deployment

Set up or verify:

```text
GitHub Actions -> GHCR -> Coolify/deployment platform
```

The workflow must:

- run quality gates
- build the Docker image
- publish immutable image tags
- explicitly trigger the deployment platform
- avoid routine SSH deployment

### Step 9: Commit everything

Commit to the repo through the approved branch flow.

Use a clear message.

Example:

```text
Initialize project standards, docs, and deployment workflow
```

### Step 10: Report back

Report:

- file count before and after
- what was deleted
- what was documented
- what workflow was created or changed
- what deployment path is now active
- what credentials are still needed
- what the first development task should be

---

## 11. Codebase Optimization — Existing Projects

When onboarding an AI to an existing codebase, optimize the codebase before building new features.

This is especially important for AI coding efficiency.

Large irrelevant codebases waste context, increase mistakes, and raise cost.

### Step 1: Count and categorize

Total file count excluding common build artifacts:

```bash
find . -type f | grep -v node_modules | grep -v .git | wc -l
```

Per-directory breakdown:

```bash
find . -maxdepth 2 -type d | while read d; do
echo "$(find "$d" -type f 2>/dev/null | grep -v node_modules | wc -l) $d"
done | sort -rn | head -20
```

### Step 2: Identify deletion candidates

Ask of each large directory:

```text
Is this part of what we actively build and deploy?
```

Common safe deletion candidates in third-party framework forks:

- vendor documentation website packages
- sample apps
- example apps
- framework test suites unrelated to our project
- CLI scaffolding tools we do not use
- integrations with third-party services we do not use
- desktop companion apps when not building a desktop app
- old build approaches that have been superseded
- generated demo content
- unused packages from a monorepo

Restoring deleted content from upstream is usually straightforward:

```bash
git checkout upstream/main -- path/to/deleted/thing
```

Do not be afraid to propose deletion.

It is usually reversible.

But do not delete significant directories without approval.

### Step 3: Create AI ignore files

For packages kept in git but not relevant to active development, add them to:

- `.claudeignore`
- `.cursorignore`
- `.copilotignore` if appropriate

### Step 4: Build `AGENTS.md`

Build `AGENTS.md` after deletion and cleanup.

The map should describe what remains, not what was removed.

---

## 12. Lessons from Past Projects

These practices proved their value and should be applied everywhere from day one.

### The Prime Directive works

Defining a clear "our code lives here" boundary makes upstream merges far cleaner.

Do this from day one.

Do not wait until the project is already messy.

### Registry patterns save repeated work

Widget registries, route registries, tool registries, and integration registries prevent repeated edits to framework core files.

Design for registries from the first custom extension point.

### File count matters for AI cost and quality

Start lean.

Delete vendor extras before writing code.

It is cheaper and safer for AI to understand one good file than to repeatedly read thousands of irrelevant files.

### `AGENTS.md` is a force multiplier

A strong `AGENTS.md` saves thousands of tokens per session.

It prevents each new AI session from rediscovering the codebase from scratch.

Time spent writing documentation pays back immediately.

### Centralize all identifiers

Any ID that must match between code, database, deployment platform, registry, or external system belongs in one place.

Never duplicate important identifiers inline across many files.

This prevents a large class of "worked locally, broke in production" bugs.

### Document the why of every environment variable

Do not document only the variable name.

Document:

- what it does
- what breaks if it is missing
- where to get it
- whether it is needed in dev
- whether it is needed in production
- whether it is build-time or runtime
- where it should be stored

### Enforce deployment rules in the workflow

Rules written in a document are not enough.

The workflow must enforce the approved path.

If the workflow still has SSH deploy steps, the system still has an SSH deployment path.

Remove obsolete deployment paths.

Remove obsolete deployment credentials.

Make the correct path the easiest path.

---

## 13. File Location

Save the canonical version of this prompt here:

```text
/home/ai/Albert-AI-Standards/NEW-PROJECT-PROMPT.md
```

When this document is improved, update the canonical file.

Do not let multiple conflicting versions drift across projects.
