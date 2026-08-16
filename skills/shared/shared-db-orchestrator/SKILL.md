---
name: shared-db-orchestrator
description: Open and run the single orchestrator for u2giants/shared-db, coordinate concurrent structural database work, or route a requested shared-database structure change into the governed issue workflow. Use for shared-db sessions, migrations, schema changes, preview or production promotion, database-change handovers, multiple database agents, or requests to coordinate parallel database work. Reading schema and ordinary application-owned row writes do not trigger this skill; outside-sourced writes into curated Master Data do.
---

# Shared DB Orchestrator

Coordinate only. Dispatch implementation to agents in isolated worktrees. Keep the full map of claims, branches, preview state, merges and owner decisions.

## Scope

- Govern database structure: migrations, schemas, tables, columns, views, functions, triggers, policies, indexes, constraints and shared contracts.
- Do not gate read-only inspection.
- Do not gate ordinary application-owned row writes.
- Gate outside-sourced writes into curated Master Data.
- Use `shared-db-handover` to stop or close the session.

Read `C:\repos\shared-db\AGENTS.md` before dispatch. It is the authoritative rulebook. Read [references/operating-manual.md](references/operating-manual.md) only when startup recovery, incidents, credentials, promotion, or detailed exception handling is needed.

## Start

1. Check the open `orchestrator-marker` issue in `u2giants/shared-db`. Fail closed if GitHub cannot be read. Never open a second active orchestrator. If `gh` reports `GitHub CLI\\config.yml: Access is denied`, report a **Codex task-profile configuration failure**, not “GitHub is unavailable.” Run `pwsh -NoProfile -File C:\\repos\\ai-devops\\bin\\repair-codex-github-cli-access.ps1`, then retry the same read. This grants the Codex sandbox read-only access to that settings folder and does not expose or copy a token.
2. Fetch current `main`, audit open routed issues, `db-claim` issues, PRs, worktrees and open handoffs. `db-work` is an intake label, never proof of orchestrator ownership.
3. Record every active workstream and exact claimed database objects.
4. Warn if more than five open handoffs exist.

## Dispatch structural work

Albert approved concurrent migration authoring on 2026-08-14.

- Allow at most three migration authors simultaneously.
- Give each author an isolated worktree and branch.
- Require exact, parseable database-object claims.
- Reserve a unique 14-digit migration version atomically before any migration file is created.
- Keep preview application, PR merges and production promotion strictly one at a time.
- Do not count read-only analysis, application code, tests or planning against the three author lanes.
- Maintain three dynamic queues grouped by exact object overlap. Recompute them after every merge.
- Refill every free lane in the same turn. Never wait for Albert to request status or say start.
- Dispatch only issues whose machine block says `status: ready`, `work_type: structural`, and `route: shared-db-orchestrator` and lists exact objects.
- Skip every other status, work type, and route. Never infer a route from `db-work` or `needs-albert` labels.
- Outside-sourced writes into curated `core.*` Master Data remain governed through `route: curated-master-data-governance`, but they never consume a migration-author lane.
- Assign each exact-head issue one external reviewer from the durable round robin.

Acquire a lane from the shared-db checkout:

```bash
node scripts/manage-migration-author-lanes.mjs --claim \
  --task "<issue and outcome>" --owner "<agent/session>" \
  --branch "<branch>" --worktree "<absolute isolated worktree>" \
  --objects "<every exact object written, comma-separated>"
```

The command acquires GitHub-backed exact-object locks and one of three fixed
author slots across computers. It must include open pull requests and refuse
unreadable claims, overlapping objects, unavailable GitHub state, failed version
reservation, or a fourth author. Older claims count. Never choose a version
manually and never hand-edit fenced claim blocks.

Audit and cleanup:

```bash
node scripts/manage-migration-author-lanes.mjs --audit
node scripts/manage-migration-author-lanes.mjs --queue-audit
node scripts/manage-migration-author-lanes.mjs --cleanup-stale
```

`--queue-audit` must classify every open `db-work` issue across independent status,
work type, and route fields. Dispatch every
`REFILL REQUIRED NOW` result immediately. An empty lane is acceptable only when
the complete audit proves no eligible work exists. See
[references/operating-manual.md](references/operating-manual.md) for the issue
block and refill rules.

Assign review with `--assign-reviewer --issue <n> --pr <n> --head-sha <sha>`.
Use the returned approved wrapper and one persistent named session. Read
[references/operating-manual.md](references/operating-manual.md) for the bounded
debate, evidence log, and production boundary.

Release a claim explicitly when its PR merges or work is safely abandoned.
Expiry never removes collision protection. Cleanup must prove ownership and
finished branch/worktree/PR state before removing temporary refs. The reserved
version remains permanently unavailable because it may already exist in preview.

## Before preview and merge

For each PR separately:

1. Acquire the exclusive GitHub-backed preview lock for the exact PR head.
2. Fetch `origin/main` and update the branch from the newly merged main tip.
3. Re-run version, object-collision, SQL and contract checks.
4. Apply and prove the migration on preview.
5. Obtain an independent review. Merge only with no unresolved Critical or High finding.
6. Release preview, acquire the exclusive merge lock, revalidate the head/base,
   and merge one PR through the guarded path.
7. Release merge and the author claim, then repeat from the new main tip.

Never resolve full-body `CREATE OR REPLACE` conflicts mechanically. Re-derive the later change from the newly merged body.

Production remains a separate single lane. After review, green checks, preview,
and guarded merge, use the production workflow's governed business-risk gate.
It reads the exact merged PR/checks, immutable review artifact, pinned preview
apply proof, current-main SQL, and activation record. Never supply risk booleans
or prose as evidence. Automatically promote only when all five business risks
are proven absent; otherwise ask Albert one plain business-risk question. See
the operating manual. Freeze merges for the bounded promotion and verify the
exact production result.

## Owner decisions

Ask Albert one question at a time in plain business English when business judgment is required. Name the recommendation and a short acceptable answer range. Do not ask him to manage branches, PRs or claims.

`needs-albert` and `status: owner-decision` identify who must answer, not who owns
the eventual work. Record work type and route before asking. After Albert answers,
change status only; never promote or rewrite the work type or route automatically.
For example, NBCU rights classification stays `source-data` routed to the
`source-data-session` after its answer and can never become structural by status change.

## Agent brief

Start from [references/sub-agent-brief-template.md](references/sub-agent-brief-template.md). Include:

- issue, outcome and exact object claim
- reserved migration version
- branch and isolated worktree
- other active authors and collision boundaries
- no preview, merge or production permission unless explicitly granted
- requirement to update from current main and re-run checks before preview/merge
- incremental status and exact blockers

Read [references/incident-ledger.md](references/incident-ledger.md) when a safety rule seems unnecessary or contradictory.
