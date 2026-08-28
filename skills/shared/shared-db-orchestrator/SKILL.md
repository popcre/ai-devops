---
name: shared-db-orchestrator
description: Open or run the single u2giants/shared-db orchestrator and route structural database work through its governed issues. Use for shared-db sessions, migrations, schema changes, promotion, database handovers, parallel database agents, or curated Master Data loads.
---

# Shared DB Orchestrator

> Replacement work is planned in [`../../../plan_shared-db-finish-first-delivery.md`](../../../plan_shared-db-finish-first-delivery.md). Read its STATUS table before changing this skill or the lane model. Until that plan is implemented, the safety rules below remain binding; do not partially remove them.

Coordinate only. Dispatch implementation to agents in isolated worktrees. Keep the full map of claims, branches, preview state, merges and owner decisions.

## Scope

- Govern database structure: migrations, schemas, tables, columns, views, functions, triggers, policies, indexes, constraints and shared contracts.
- Do not gate read-only inspection.
- Do not gate ordinary application-owned row writes.
- Gate outside-sourced writes into curated Master Data.
- Use `shared-db-handover` to stop or close the session.

## Operational blockers are orchestration work

Never sit silently idle behind a blocker. Resolving it is part of orchestration,
even when the repair belongs to repo maintenance, documentation, tooling, or
another repository. Immediately start the appropriate separate task or session;
do not perform non-structural work in the orchestrator context. Keep every
independent structural stream moving, disclose the blocker and owner-facing
consequence immediately, and follow the repair task until the capability is
restored. Record any required owner authorization at once in plain business
language with one exact request; never park it silently.

Treat reviewer, allocator, tooling, and rate-limit failures as urgent operational
blockers. Preserve the capability, use bounded API calls, read the provider's
rate-limit status, and report the reset time in Eastern Time. Do not repeatedly
invoke a path already known to be unsafe. The reviewer-allocator redesign is
tracked in [u2giants/shared-db#1767](https://github.com/u2giants/shared-db/issues/1767).

## The admission test — protect your own context window (AGENTS.md 0.0-C)

Before opening, accepting, or acting on ANY item, ask one question: **does this change the SHAPE
of the database** (schema, table, column, type, view, function/RPC, trigger, RLS policy, grant,
index, constraint, extension, publication, storage policy, or a migration shipping one of those)?

- **Yes -> accept.** Queue it as `work_type: structural`, `route: shared-db-orchestrator`, and
  dispatch it to a sub-agent in an isolated worktree.
- **No -> FOUR exits, and `accept` is never one of them.** (Corrected 2026-08-26 to match the
  owner ruling of 2026-08-21 now recorded in `AGENTS.md` §0.0-C, which **wins**. This skill still
  taught the superseded three-exit model where repository maintenance, documentation and security
  settings all exited by FORK — i.e. as orchestrator assignments. The ruling made them **not**
  orchestrator work at all. Found by independent Codex GPT-5.6 review during shared-db #1605.)
  - **REJECT** — `application-data`, `source-data`. The work belongs to another repository and
    must leave this queue, forwarded to it (see below).
  - **FORK** — **`curated-master-data` ONLY.** Genuinely this repo's work, dispatched to a FRESH
    sub-agent with an empty context window, exactly as a migration is. It forks rather than leaves
    because `AGENTS.md` §6.4 governs it inside this repo, and forks rather than being accepted
    because it must not occupy a migration-author lane. Do not extend this exit to anything else.
  - **REPO-SESSION** — `repo-maintenance`, `documentation`. **Not an orchestrator assignment.**
    An independent repository session owns these; the orchestrator neither implements nor
    dispatches them.
  - **RETURN-TO-OWNER** — `security-settings`. It needs authority the orchestrator does not have.

**A REJECT forwards the task; it never merely closes it.** Each reject-exit issue carries
`return_to: owner/repo` in its scope block. Return it with
`node scripts/manage-migration-author-lanes.mjs --return-issue <n>` — that files the issue in the
owning repository FIRST, then comments the new URL here, then closes this one, so a failure at any
step leaves the issue open rather than losing the task. Never close a rejected issue by hand. A
reject with no `return_to` is reported as `NO RETURN ADDRESS` and makes `--queue-audit` exit 2.
FORK items are not lost either: they stay open and dispatched until the work is done.

No fifth exit and no size exemption. `db-work` is an intake label, never proof that an item passed
this test. Your own window is for triage, dispatch, review, merge and promotion — nothing else.
`--queue-audit` prints a `NOT ORCHESTRATOR WORK` block listing every open issue that fails the
test, stamped REJECT or FORK; clear it, do not carry it.

Read `C:\repos\shared-db\AGENTS.md` before dispatch. It is the authoritative rulebook. Read [references/operating-manual.md](references/operating-manual.md) only when startup recovery, incidents, credentials, promotion, or detailed exception handling is needed.

## Start

1. Check the open `orchestrator-marker` issue in `u2giants/shared-db`. Fail closed if GitHub cannot be read. Never open a second active orchestrator. If `gh` reports `GitHub CLI\\config.yml: Access is denied`, report a **Codex task-profile configuration failure**, not “GitHub is unavailable.” Run `pwsh -NoProfile -File C:\\repos\\ai-devops\\bin\\repair-codex-github-cli-access.ps1`, then retry the same read. This grants the Codex sandbox read-only access to that settings folder and does not expose or copy a token.

   **Run the check rather than eyeballing the issue list** — `node scripts/check-orchestrator-marker.mjs`. Hand-querying the label has printed empty while a marker existed, and an empty result reads as permission to start.

1a. **Claim your marker with a routing block, and name your session `shared-db.orch…`** (shared-db `AGENTS.md` §11c, issue #1605, owner instruction 2026-08-26). The marker is how every other session finds you; without a routable address it proves only that *someone* is running, and a session with no address falls back to a handoff or conversation history — which is how an authorized request reached an orchestrator that had already closed.

   Set your session display name to begin with `shared-db.orch`, then open the marker containing:

   ````
   ```orchestrator-routing
   status: active
   identifier: shared-db.orch
   engine: codex            # or `claude`
   session_name: shared-db.orch <machine> <short label>
   route_id: <YOUR OWN routable id — see below>
   owner: u2giants
   machine: <MACHINE>
   started: <ISO-8601, e.g. 2026-08-26T14:39:25Z>
   handover_issue: <predecessor marker number, or `none`>
   briefing: <HANDOFF.d/... path, or `none`>
   ```
   ````

   `route_id` is **your own** id, never the predecessor's. The guard catches the common copy — a
   numeric `handover_issue` whose marker is readable and carries the same id — but it is a **trap,
   not a proof**: it cannot catch an id reused from an older ancestor, a wrong predecessor number,
   a `handover_issue: none` that is a lie, or a fabricated id of the right shape. Recording your
   real id is your obligation.
   - **Codex:** your thread UUID, the `session_id` in your rollout under `~/.codex/sessions/…`. Another session reaches you with `codex-reply` on that `threadId`.
   - **Claude:** your own `sessionId` (e.g. `local_<uuid>`), which another Claude session messages directly.

   Every field is required and **blank is never a default** — state a value or `none`. Verify before you dispatch anything:

   ```bash
   node scripts/check-orchestrator-marker.mjs --resolve
   ```

   It must print **your** `route_id`. If it does not, no other session can even ADDRESS you, and
   you are not ready to run. Printing it proves only that the marker declares your address — not
   that anyone can reach you. Nothing here can prove liveness or delivery.
2. Fetch current `main`, audit open routed issues, `db-claim` issues, PRs, worktrees and open handoffs. `db-work` is an intake label, never proof of orchestrator ownership.
3. Record every active workstream and exact claimed database objects.
4. Warn if more than five open handoffs exist.

## Dispatch structural work

Albert approved concurrent migration authoring on 2026-08-14.

- Allow at most `MAX_AUTHOR_LANES` active-author leases simultaneously — five until the separately governed reviewer-capacity gate permits eight. Protected blocked claims do not consume active-author capacity, but keep every object and version lock. Clock expiry releases neither protection nor capacity. Read the constant in `scripts/manage-migration-author-lanes.mjs`; the cap is throughput, never isolation.
- Relinquish capacity only with `--relinquish-author-lease --claim <n> --owner <owner> --blocked-on issue:#<n>` after clean-worktree and stage-holder proof. Resume only with `--resume-author-lease --claim <n> --owner <owner> --lease-hours <hours>`; resume renews the time lease and rechecks capacity, collision, and permanent version truth.
- Give each author an isolated worktree and branch.
- Require exact, parseable database-object claims.
- Reserve a unique 14-digit migration version atomically before any migration file is created.
- Keep preview application, PR merges and production promotion strictly one at a time.
- Do not count read-only analysis, application code, tests or planning against the author lanes.
- Distinguish an actively running author from a reserved claim. Claims protect
  objects and versions; they are never reported as working slots without live
  worker evidence.
- Maintain one dynamic queue per lane, grouped by exact object overlap. Recompute them after every merge.
- When any author lane frees, run a live queue audit immediately. Close stale
  already-delivered issues instead of duplicating them, then dispatch the next
  genuinely eligible issue in an isolated worktree. Maintain explicit successor
  queues and report truthfully when no eligible successor exists. Never wait for
  Albert to request status or say start.
- Dispatch only issues whose machine block says `status: ready`, `work_type: structural`, and `route: shared-db-orchestrator` and lists exact objects.
- Skip every other status, work type, and route. Never infer a route from `db-work` or `needs-albert` labels.
- Classify every new or successor issue from its own requested work. Never
  inherit `work_type`, `route`, or database objects from a predecessor issue.
  A successor that performs offline analysis or application work remains
  non-structural even when its predecessor changed the database.
- Outside-sourced writes into curated `core.*` Master Data remain governed through `route: curated-master-data-governance`, but they never consume a migration-author lane.
- Assign each exact-head issue one external reviewer from the durable round robin.

Acquire a lane from the shared-db checkout:

```bash
node scripts/manage-migration-author-lanes.mjs --claim \
  --task "<issue and outcome>" --owner "<agent/session>" \
  --branch "<branch>" --worktree "<absolute isolated worktree>" \
  --objects "<every exact object written, comma-separated>"
```

The command acquires GitHub-backed exact-object locks and one of the fixed
author slots across computers. It must include open pull requests and refuse
unreadable claims, overlapping objects, unavailable GitHub state, failed version
reservation, or an author beyond the cap. Older claims count. Never choose a version
manually and never hand-edit fenced claim blocks.

Audit and cleanup:

```bash
node scripts/manage-migration-author-lanes.mjs --audit
node scripts/manage-migration-author-lanes.mjs --queue-audit
node scripts/manage-migration-author-lanes.mjs --cleanup-stale
```

`--queue-audit` must classify every open `db-work` issue across independent status,
work type, and route fields. Its `NOT ORCHESTRATOR WORK` block lists every open issue that failed
the admission test above, stamped REJECT or FORK — act on each one rather than leaving it parked.
Dispatch every
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

## Phase 2 preview and reviewer lifecycle

Phase 2 is shadow-first. Protected claims never disappear when author capacity is relinquished, and preview dependencies are waits rather than successful checks. Before manual preview dispatch, resolve the live marker, run `node scripts/manage-migration-author-lanes.mjs --prepare-preview-dispatch <issue>`, rerun the read-only selector with a fresh preview-ledger read, and use only the matching stored instruction. Historical recovery is apply-only; a historical dry-run proves nothing. Use `--repair-preview-ready <ready-id> --issue <n>` only for a v2-bound stale wrong digest; a corrupt live digest stops for an owner decision without mutation. Reviewer reservations serialize provider/wrapper execution keys, prefer active reviewers to overflow, and create durable ordered waits when all keys are busy.

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
or prose as evidence. Derived risks are DISCLOSED in the evidence; they do not
block. See the operating manual. Freeze merges for the bounded promotion and
verify the exact production result.

**Do NOT ask Albert to sign off on technical risk (owner ruling 2026-08-18).**
He is not a programmer and cannot evaluate the SQL a risk flag refers to. Asking
him to paste an approval block an agent composed produces a signature on
something unread plus an audit trail claiming oversight happened — worse than no
gate, because it is believed. The block is retired as a blocker; it is verified
only if someone supplies one.

The general rule, which applies beyond this gate: **never gate on a human
judgement the human cannot actually make.** If whoever is being asked cannot
evaluate the check, it is theatre. Make the machine decide it, or make the
machine refuse and escalate to an engineer. Do not route it through a rubber
stamp. `incident-ledger.md` records why.

This does NOT retire genuine owner questions. "Which property should the Coco
style guide point at" is a real business judgement only Albert can make. "Do you
accept `material_access_change`" is not.

## Owner decisions

Ask Albert one question at a time in plain business English when business judgment is required. Name the recommendation and one exact request. Disclose it immediately with the business consequence; never silently park it. Do not ask him to manage branches, PRs or claims.

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

## Misrouted work

If an issue is not structural and is not the curated Master Data exception,
refuse shared-db implementation before assigning an agent or lane. Preserve any
private artifact in its approved private repository, record the correct route,
and hand the work to that owning application session. Never publish or copy a
private artifact into a public shared-db issue to make the handoff easier.
