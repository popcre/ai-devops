# AI Session Documentation Update Prompt

Use this at the end of an AI coding session when the session changed code, deployment behavior, data flow, configuration, operational assumptions, or important project knowledge.

Your job is not to rebuild the entire documentation system. 

-----------------------------------------------------------------------------------------------------------------------------------

Update only the Markdown files that need durable knowledge from this specific session.

## Goal

Record what this session learned or changed so future developers and future AI sessions do not have to rediscover it.

Focus on:
- Information from this session that will still matter later.
- Idiosyncrasies that may look wrong but are intentional.
- Mistakes, dead ends, or assumptions from this session that future sessions should avoid.
- Architecture, data flow, deployment, configuration, or workflow changes.
- New operational steps, rollback notes, feature flags, identifiers, limits, or dependencies.
- Any temporary/incomplete work that needs a handoff.

## Rules

- Derive every doc update from code, config, migrations, workflows, commands run, or verified session findings.
- Do not document guesses as facts. Mark unknowns clearly and say how to verify them.
- Do not add secrets, tokens, passwords, private keys, or credential values.
- Do not duplicate large explanations across multiple docs. Put the short routing/context note in `AGENTS.md` only if future AI sessions need to see it early; put topic detail in the relevant doc under `docs/`.
- If the change does not require documentation updates, say so explicitly in the final report.

## What To Update

- `AGENTS.md`: only for high-signal guidance future AI sessions must see quickly, including new quirks, critical warnings, task routing, identifiers, or "do not repeat this mistake" notes.
- `HANDOFF.md`: create or update only if work is unfinished, blocked, partially deployed, or requires continuation context. Delete it only when the unfinished work it describes is truly complete.
- Topic docs under `docs/`: update the specific doc for the affected area, such as architecture, deployment, configuration, schema, worker logic, PopSG, Helper, Seafile, auth, bulk jobs, or known quirks.
- `README.md`: update only if the quick-start or top-level orientation changed.
- `CLAUDE.md`: update only for Claude Code-specific workflow rules. General AI/developer guidance belongs in `AGENTS.md`.

## Shared supabase.com Database / Backend Changes

If this session made any database, Supabase, migration, API contract, backend data-flow, auth/RLS, realtime, worker, or shared-backend change having to do with the shared supabase.com backend, also update the canonical shared database repo:

```text

u2giants/shared-db

https://github.com/u2giants/shared-db

```

This applies even when the code change was made inside an app repo. App repos may contain generated types, frontend adapters, workers, or local notes, but durable backend truth belongs in `shared-db`.

At minimum, document in `u2giants/shared-db`:

- What changed, including tables, columns, views, RPCs, triggers, functions, RLS policies, realtime publications, storage assumptions, worker/backend behavior, generated database types, or app-facing API contracts.

- Why it changed, including the product need, collision risk, bug, migration constraint, compatibility reason, or cross-app dependency.

- Which app or apps are affected: CRM, DAM, PM/PIM, PLM, workers, scripts, or shared admin tooling.

- Where the durable implementation lives: migration filenames, SQL files, scripts, API views/RPC names, worker files, generated type files, and relevant app repo commits if known.

- What was verified: local checks, `scripts/check-sql.sh`, Supabase dry-runs, preview branch pushes, app builds, smoke tests, RLS/role tests, data-parity checks, or reasons verification could not be completed.

- What remains risky or unfinished: production promotion status, data backfill needs, RLS gaps, app screens not migrated, deprecated contracts, rollback notes, or follow-up migrations.

Use the existing `shared-db` documentation structure:

- Put cross-app operating rules or urgent warnings in `AGENTS.md` only when future AI sessions must see them immediately.

- Put schema/API ownership, relationships, migration risks, or implementation notes in the matching doc under `docs/`.

- Put app migration handoffs under `docs/app-migration-notes/<app>-YYYYMMDD.md`.

- Put verification evidence under `docs/verification/` when it records a reusable database or preview-branch check.

- Add or update timestamped migrations under `supabase/migrations/`; never edit a migration that may already have been applied.

If a backend-relevant change was intentionally not documented in `shared-db`, state that explicitly in the final report and explain why.

## Required Session Note Shape

When adding session-derived knowledge, prefer concise entries like:

```md
### [Short decision or warning name]

What changed:
[One or two sentences.]

Why:
[Constraint, incident, bug, user decision, or operational reason.]

Future sessions should:
[Concrete instruction: what to do, what to avoid, where to verify.]
```

For unfinished work, include:

```md
## [Workstream name]

Status:
[done / partial / blocked / not started]

Done:
[Verified completed items.]

Next action:
[Exact next step.]

Risks / watchouts:
[Anything future sessions must not miss.]
```

## Verification Before Final Response

- Docs changed are limited to files that actually needed updates.
- New claims match the repository or verified session findings.
- No secrets were added.
- `HANDOFF.md` exists only if continuation context is needed.
- Any new quirk or warning explains why it exists and what would break if ignored.

## Final Report

Reply with:

```md
## Documentation Updates
| File | Change |
|---|---|
| `path/to/file.md` | Short summary |

## Handoff
- `HANDOFF.md`: present/absent
- Reason: ...

## Verification
- Docs verified against session findings: yes/no
- Secrets added: yes/no
- Unknowns remaining: ...
```
