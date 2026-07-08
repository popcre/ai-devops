---
name: new-app-setup
description: One-time briefing and setup ritual for a brand-new software project. Use when starting a new project, spinning up a new application/repo from scratch, or when the user says "new project", "new application", "set up a brand new app", "starting a new project", or pastes the "POP Creations — New Project Standard" prompt. Covers access-first credential requests, container naming, docs/CI-CD standards, DB choice, and the initial file-count-and-cleanup pass. For an existing repo that just needs Coolify/GHCR CI/CD hardened, use cicd-rules-audit instead; for rebuilding docs on an existing repo, use repo-docs-overhaul instead.
---

# new-app-setup

Albert pastes his "POP Creations — New Project Standard" prompt at the start
of every brand-new engagement. The complete canonical text is in
[NEW-PROJECT-STANDARD.md](NEW-PROJECT-STANDARD.md) — read it in full when this
skill triggers. This SKILL.md is the scannable summary and the procedure to
run; it does not repeat the docs or CI/CD rule sets verbatim (those live in
the `repo-docs-overhaul` and `cicd-rules-audit` skills — cross-reference them,
don't re-embed them).

## Trigger phrases

- "new project" / "new application" / "set up a brand new app"
- "starting a new project"
- Standing up a first deploy to Hetzner / "hetz" / the VPS for something that
  doesn't exist yet
- The user pastes the "POP Creations — New Project Standard" document
- A working directory with no `AGENTS.md`, no Dockerfile, and no git history
  beyond `git init`

## Who Albert is (baseline, applies to every project)

Albert is a business owner, not a programmer/DevOps engineer/sysadmin — see
`~/.claude/CLAUDE.md` for the standing global rules (plain English,
do-it-yourself, no band-aids). This skill layers project-*startup*-specific
rules on top of those.

- **Access-first rule:** before writing any code or docs, think through the
  whole project and ask for ALL access reasonably needed in one batch — not
  one credential at a time. Categories: source control, deployment platform,
  registry, database, third-party API keys, domain/DNS, email provider,
  storage, monitoring/logging, any project-specific service credentials.
- **Manual-action rule:** before asking Albert to run a command or click
  something, first ask for the access needed to do it yourself. If something
  genuinely requires his manual action, give one short exact instruction, not
  a multi-step runbook.
- Do not default to asking for SSH access. SSH is not the normal deployment
  path — only for initial setup, migration, emergency debugging, or when the
  deployment platform can't provide the needed visibility.

## Container naming standard

```text
[app-abbreviation]-[function-abbreviation]
```

- App abbreviation: 4-8 lowercase characters.
- Function abbreviation: short, obvious (`api`, `web`, `worker`, `db`,
  `proxy`, `cron`, `gate`, `mc`, `sync`).
- Hyphen separator only — no underscores, no capitals, no spaces.
- Document every container name in `AGENTS.md`.
- Once a container is in production, the name is permanent; don't rename
  without a documented migration reason.

Examples: `popcmr-api`, `popcmr-web`, `popdam-api`, `oclaw-gate`,
`dfflow-api`, `popcmr-db`.

## Documentation standard

New projects get the full documentation system from day one — the same "AI
TASK SPEC: Repository Documentation Maintenance" that `repo-docs-overhaul`
implements (AGENTS.md as canonical router, required sections, ignore files,
HANDOFF.md discipline). **Run that skill** (or follow
[NEW-PROJECT-STANDARD.md](NEW-PROJECT-STANDARD.md) section 4 directly) rather
than re-deriving the spec here.

## CI/CD standard

New projects get the full Coolify/GHCR pipeline discipline from day one —
GitHub is the source of truth for code/workflows, GHCR for build artifacts,
Coolify for runtime config; normal path is
`verify -> build -> publish -> trigger Coolify`; no routine SSH deploys. This
is the same rule set `cicd-rules-audit` audits against. **Run that skill** (or
follow [NEW-PROJECT-STANDARD.md](NEW-PROJECT-STANDARD.md) section 5 directly)
rather than re-deriving the rules here.

## Server folder structure (if a server workspace is used)

```text
/worksp/<app-name>/
├── app/            # git checkout — NOT the deploy source of truth
└── server -> /data/coolify/applications/<coolify-app-id>
```

The approved deploy path is always `GitHub -> Actions -> GHCR -> Coolify ->
production host`, never manual commands from `/worksp/<app-name>/app`. Only
create this workspace if there's a clear operational reason (inspection,
debugging, emergency ops); document it in `AGENTS.md` if it exists.

## Database standard — pick the one that applies

- **Supabase cloud-hosted Postgres**: numbered SQL migrations in
  `supabase/migrations/`, RLS explicitly set per table (never left undefined),
  Edge Functions in `supabase/functions/` deployed via CLI/workflow, service
  role keys server-side only, project ID recorded in `AGENTS.md`.
- **Internal database** (project-owned Postgres/MySQL/MariaDB/SQLite):
  container named `[app]-db` (never generic `postgres`/`db`), numbered
  migrations under `db/migrations/` via a real migration runner, data in a
  named volume (never container-only filesystem), scheduled backups
  documented, credentials as deployment-platform runtime env vars with a
  least-privilege app user.
- **No database**: state that explicitly in `AGENTS.md` (see
  [NEW-PROJECT-STANDARD.md](NEW-PROJECT-STANDARD.md) section 7.10c for the
  exact wording) so its absence reads as intentional, not an oversight.

## Code quality standards

- Project-owned code lives in a dedicated module/area (`src/modules/[name]/`,
  `src/features/[name]/`, etc.) — never scattered into third-party/framework
  directories. Keeps upstream merges clean.
- Prefer registry/plugin patterns over repeatedly editing the same core
  framework file for every new route/widget/tool/handler.
- Any UUID, DB ID, slug, external-system identifier, or app/project ID is
  permanent once used anywhere — record it once in `AGENTS.md`, never
  duplicate it inline across files.
- AI model calls go through OpenRouter (one endpoint, one key) unless Albert
  explicitly says otherwise; no per-provider keys; never in frontend code;
  document model IDs in `AGENTS.md` and `docs/configuration.md`.
- Never hand-patch a running container. Code change path is always
  code -> commit -> push -> workflow -> image -> deployment platform ->
  production.

## Multi-session documentation discipline

Every session that touches this project: update `AGENTS.md` with significant
changes, keep the container/service inventory and task-to-file map current,
log unusual fixes under Intentional Quirks immediately (don't wait), keep
Pending Work current, and run the new-developer test before ending — "would a
brand-new senior engineer have enough context in AGENTS.md to work
productively with zero questions?" If no, update it.

## Procedure — Immediate Action List on receiving this brief

Do these in order; don't skip or reorder.

1. **Inspect the project.** Report top-level directories, key files, package
   manager(s), framework, existing Dockerfiles/workflows/deployment docs,
   existing DB/migration setup, and obvious missing pieces.
2. **Ask Albert for all needed access, in one batch** (the access-first rule
   above). Separate required vs. possibly-needed access. Do not ask
   piecemeal as you discover gaps later.
3. **Count files and identify deletion candidates** if this is an existing
   codebase being brought under this standard (vendor bloat, unused samples,
   demo content, unused monorepo packages). Use a file-count pass per
   top-level directory.
4. **Propose deletions** with what/why-safe/risk/how-to-restore; wait for a
   quick approval before deleting anything significant.
5. **Delete approved items**, update `.gitignore`, update package workspaces,
   update docs to reflect the leaner codebase.
6. **Create ignore files**: `.claudeignore`, `.cursorignore`, and
   `.copilotignore` if Copilot is in use.
7. **Create project docs** via `repo-docs-overhaul`: `AGENTS.md`, `CLAUDE.md`,
   `docs/architecture.md`, `docs/development.md`, `docs/configuration.md`,
   `docs/deployment.md`.
8. **Set up or verify deployment** via `cicd-rules-audit`'s rule set:
   GitHub Actions -> GHCR -> Coolify, running quality gates, publishing
   immutable image tags, explicitly triggering the deployment platform, no
   routine SSH.
9. **Commit everything** through the repo's approved branch flow with a clear
   message (e.g. "Initialize project standards, docs, and deployment
   workflow").
10. **Report back**: file count before/after, what was deleted, what was
    documented, what workflow was created/changed, what deployment path is
    now active, what credentials are still needed, and what the first
    development task should be.

Full verbatim detail, including the exact access-request markdown template,
the Immediate Action List's shell snippets, and the "Lessons from Past
Projects" section, is in
[NEW-PROJECT-STANDARD.md](NEW-PROJECT-STANDARD.md).
