# Shared-db structural work safety rules (reference)

Formerly the `shared-db-orchestrator` skill (retired 2026-10-20, #1881). Read
when structural work needs the detailed checklist, promotion rules, or
exception handling; `shared-db-change` points here.

> **Owner ruling, Albert Hazan, 2026-10-02: "there is no longer an orchestrator."**
> No session is the orchestrator. Never route work to one, open a HANDOVER issue and
> stop, resolve or open a marker, wait for dispatch, or label tickets orchestrator /
> non-orchestrator. Structural work is claim-first: claim exact objects on the
> existing issue and start, per `shared-db-change`. The session doing the structural work owns its claim and delivery;
> optional delegation never creates a required orchestrator role.

> The completed [`shared-db throughput programme`](../../../plan_shared-db-complete-throughput-repair.md) is a decision record, not a restart plan. Its safety invariants remain binding; retiring a role never removes claims, version reservations, stage leases, or live proof.

**Not required. Claim-first is the default. This document is reference only.**
New structural work starts when a session claims exact objects on the existing
issue and begins — no orchestrator chat and no marker. The safety rules below
(claims, versions, stage leases, repository-enforced approval, live proof) stay binding
whenever shared-db structural work runs.

**Reporting to Albert.** Every status, queue, audit and delegation record
in this skill is written into GitHub issues, plans and handoffs — never into the
chat reply. Replies to Albert obey the global 120-word limit. Business-meaning
questions only he can answer and every pending issue, agent, check or merge
appear only in the closing `**Still open**` block. Never paste a queue listing,
marker block, audit result or per-agent status roll-up into chat.

## Scope

- Govern database structure: migrations, schemas, tables, columns, views, functions, triggers, policies, indexes, constraints and shared contracts.
- Do not gate read-only inspection.
- Do not gate ordinary application-owned row writes.
- Gate outside-sourced writes into curated Master Data.
- Use `shared-db-handover` to stop or close the session.

## Operational blockers remain owned

Never sit silently idle behind a blocker. Resolving it is part of delivery,
even when the repair belongs to repo maintenance, documentation, tooling, or
another repository. Immediately start the appropriate separate task or session;
classify non-structural repairs separately and use their repository workflow. Keep every
independent structural stream moving, disclose the blocker and owner-facing
consequence immediately, and follow the repair task until the capability is
restored. Never request owner authorization for a technical step (owner ruling 2026-09-28): get an assigned AI reviewer's APPROVE instead, or report it `Blocked —`; never park it silently.

Treat reviewer, allocator, tooling, and rate-limit failures as urgent operational
blockers. Preserve the capability, use bounded API calls, read the provider's
rate-limit status, and report the reset time in Eastern Time. Do not repeatedly
invoke a path already known to be unsafe. The reviewer-allocator redesign is
tracked in [popcre/shared-db#1767](https://github.com/popcre/shared-db/issues/1767).

## Admission and routing

Read the target shared-db checkout's current `AGENTS.md` before claiming work.
Does the requested work change database SHAPE (schema, tables, columns, types,
views, functions/RPCs, triggers, RLS, grants, indexes, constraints, extensions,
publications, storage policies, or migrations shipping them)?

- Structural work uses `work_type: structural`, `route: claim-first`, exact
  objects, and an isolated current-upstream worktree. Claim and begin directly.
- Outside-sourced curated Master Data loads keep their governed route and exact
  claims. They do not become ordinary application row writes.
- Application data and source-data work stays with its owning application or
  private repository. Repository maintenance, docs and security settings use
  their appropriate non-structural session and gates, without database claims.
  Security-settings work must stop if the installed lane tool still returns it
  to an owner-only gate; preserve that refusal until the supported repair
  (popcre/shared-db#3675) is verified, and never ask Albert for technical approval.
- Classify each successor from its own work; never inherit a predecessor issue's
  work type, route or objects. Read-only inspection needs no claim or dispatch.

A legacy `shared-db-orchestrator` route may remain parseable for compatibility;
never write it into new scopes or interpret it as a required session or marker.
For misrouted work preserve its existing issue and private artifacts, record the
correct owner/route, and use supported forwarding only when work truly belongs
in another repository. Its scope must carry `return_to: owner/repo`; use
`node scripts/manage-migration-author-lanes.mjs --return-issue <n>` to create the
owning-repository issue first, comment its URL here, then close the original.
A missing return address is `NO RETURN ADDRESS` and fails `--queue-audit` with
exit 2. Never close an unresolved need manually or guess its destination. Never close an unresolved application need or create a
second handover or live-proof ticket merely to change sessions.

Read [references/operating-manual.md](references/operating-manual.md) only when
startup recovery, incidents, credentials, promotion, or exception handling is needed.

## Start (claim-first — no marker)

A marker and an orchestrator chat are **not required**. Structural work starts
when a session claims exact objects on the existing issue and begins (model:
`shared-db/docs/agents/orchestrator.md` `self-service-additive`).

If `gh` reports `GitHub CLI\\config.yml: Access is denied`, that is a **Codex
task-profile configuration failure**, not "GitHub is unavailable." Run
`pwsh -NoProfile -File C:\\repos\\ai-devops\\bin\\repair-codex-github-cli-access.ps1`,
then retry the same read. This grants the Codex sandbox read-only access to that
settings folder and does not expose or copy a token.

1. Fetch current `main`, audit open routed issues, `db-claim` issues, PRs, worktrees and open handoffs. `db-work` is an intake label, never proof of ownership.
2. Record every active workstream and exact claimed database objects.
3. Warn if more than five open handoffs exist.

## Claim structural work; delegate only when useful

Albert approved concurrent migration authoring on 2026-08-14.

- There is no numeric ceiling on concurrent authors, sub-agents, or runners (Albert, 2026-09-16; plan Step 7A, decisions 20–21). Admit every author whose exact objects do not overlap a live claim; isolation comes from exact-object locks, permanent version reservations, and the serialized preview/merge/production stage leases, never from a count. Back off and reroute only on a real provider or machine refusal (rate limit, quota, out-of-memory). Protected blocked claims keep every object and version lock; clock expiry releases no protection.
- Relinquish an author lease only with `--relinquish-author-lease --claim <n> --owner <owner> --blocked-on issue:#<n>` after clean-worktree and stage-holder proof. Resume only with `--resume-author-lease --claim <n> --owner <owner> --lease-hours <hours>`; resume renews the time lease and rechecks collision and permanent version truth.
- Give each author an isolated worktree and branch.
- Require exact, parseable database-object claims.
- Reserve a unique 14-digit migration version atomically before any migration file is created.
- Keep preview application, PR merges and production promotion strictly one at a time.
- Distinguish an actively running author from a reserved claim. Claims protect
  objects and versions; they are never reported as working slots without live
  worker evidence.
- Maintain dynamic queues grouped by exact object overlap only; unrelated work never queues behind other work. Recompute them after every merge.
- Run a live queue audit BEFORE every allocation, not only after one. An audit
  run afterwards describes a decision already taken; the audit is what the
  decision is supposed to be made from.
- Continue authorized eligible, non-overlapping work in isolated worktrees;
  optional subagents are not an admission prerequisite. Never wait for a lane or slot to free. Close stale
  already-delivered issues instead of duplicating them. Maintain explicit successor
  queues and report truthfully when no eligible successor exists. Never wait for
  Albert to request status or say start.
- Claim only issues whose machine block says `status: ready`, `work_type: structural`, and `route: claim-first` and lists exact objects. Existing compatible legacy scopes follow current repository admission rules.
- Skip every other status, work type, and route. Never infer a route from `db-work` or `needs-albert` labels.
- Classify every new or successor issue from its own requested work. Never
  inherit `work_type`, `route`, or database objects from a predecessor issue.
  A successor that performs offline analysis or application work remains
  non-structural even when its predecessor changed the database.
- Outside-sourced writes into curated `core.*` Master Data remain governed through `route: curated-master-data-governance`, and are admitted like any other non-overlapping work.
- Follow the current repository-enforced exact-head approval policy. When an
  external reviewer is required, use its durable allocator, excluding the
  implementing engine. The current pool is Muse, DeepSeek, GLM and StepFun;
  membership and usable preflight must both pass. Never edit the registry to
  unblock allocation. The committed `popcre/shared-db` policy
  (`config/owner-no-reviewer-policy.json`) and its `owner_no_reviewer` path is scoped to the
  repository enforcing it and does not bypass any other delivery gate. An absent,
  inactive or invalid policy never grants an exemption.
  Report an `OUT OF CREDIT:` refusal promptly and replace through the supported
  allocator rather than retrying an unavailable provider.
- One reviewer provider may run any number of independent reviews at once, each in
  its own session, worktree, and verdict record (decision 21). "Reviewer busy" is
  never a reason to wait or reroute; only a real provider refusal (quota, rate
  limit, auth, crash) or a review that fails to start triggers reroute. A review
  never reuses another review's session, and one head still needs distinct
  reviewers where policy requires them.

Acquire a lane from the shared-db checkout:

```bash
node scripts/manage-migration-author-lanes.mjs --claim \
  --task "<issue and outcome>" --owner "<agent/session>" \
  --branch "<branch>" --worktree "<absolute isolated worktree>" \
  --objects "<every exact object written, comma-separated>"
```

The command acquires GitHub-backed exact-object locks across computers. It must
include open pull requests and refuse unreadable claims, overlapping objects,
unavailable GitHub state, or failed version reservation; it never refuses on an
author count. Older claims count. Never choose a version
manually and never hand-edit fenced claim blocks.

Audit and cleanup:

```bash
node scripts/manage-migration-author-lanes.mjs --audit
node scripts/manage-migration-author-lanes.mjs --queue-audit
node scripts/manage-migration-author-lanes.mjs --cleanup-stale
node scripts/manage-migration-author-lanes.mjs --abandonment-audit
```

`--abandonment-audit` is the read-only report that the `Author Lane Abandonment
Audit` workflow also runs hourly. It writes nothing anywhere and cannot: the
reconciler's write hooks are removed before it runs. Exit 0 is a clean lane set,
exit 2 means at least one lease has EXPIRED, and exit 3 means the state could not
be read and must never be treated as clean.

An expired lease is not an abandoned one. Expiry is a clock running out;
abandonment is a fact somebody recorded in an `abandonment-audit` issue naming the
exact claim, pull request, head and owner. Never delete a claim, a lock, a
reservation or a ref to free a lane, and never relinquish on expiry alone. Open
the abandonment-audit issue first, then run the guarded
`--relinquish-author-lease` command the report prints, with the observed worktree
state. The owning session may retire work only where the worktree is `clean` or
proven `absent`; `dirty` or `remote` work is potentially recoverable: preserve a rescue branch or
patch, leave the claim protective, and report it `Blocked —` until
popcre/shared-db#3675 replaces the lane tool's `--owner-decision` with an assigned
AI reviewer's APPROVE. Never bypass that gate and never ask Albert (owner ruling
2026-09-28).

`--queue-audit` classifies every open `db-work` issue across independent status,
work type, and route fields. Act on misrouting or malformed scope without
assuming a central dispatcher. Continue authorized ready work when exact-object
and dependency checks permit it. A session is working only with current worker
evidence, not because its claim exists. See
[references/operating-manual.md](references/operating-manual.md).

When current repository policy requires external review, assign it with `--assign-reviewer --issue <n> --pr <n> --head-sha <sha>`.
Use the returned approved wrapper and one persistent named session. Read
[references/operating-manual.md](references/operating-manual.md) for the bounded
debate, evidence log, and production boundary.

Release a claim explicitly when its PR merges or work is safely abandoned.
Expiry never removes collision protection. Cleanup must prove ownership and
finished branch/worktree/PR state before removing temporary refs. The reserved
version remains permanently unavailable because it may already exist in preview.

## Quarantine, recovery, and terminal retirement

Once a lane is recorded as abandoned there are exactly two endings, and the
difference is whether the work can still come back. Choosing the wrong one is
expensive in opposite directions: retiring recoverable work throws away a
reserved version and a reviewed branch, while quarantining truly dead work leaves
a lane permanently half-held.

**Quarantine and recovery — the work may still come back.** Open a durable
abandonment audit issue from shared-db's
`.github/ISSUE_TEMPLATE/author-lane-abandonment.md`, and let the
`--abandonment-audit` output be its first piece of evidence, so the record starts
from the machine's reading rather than from someone's recollection. Then
relinquish the author lease with the observed worktree state:

```bash
node scripts/manage-migration-author-lanes.mjs --relinquish-author-lease \
  --claim <n> --owner <owner> --blocked-on issue:#<audit issue>
```

Change nothing else. The pull request, the claim, the exact-object locks, the
version reservation, the branch and the worktree all stay exactly as they are —
relinquishing releases the lease, not the work. No ref, branch, claim or worktree is
ever deleted, because those are the only durable evidence that the migration was ever authored. Recover the
work, record the recovery evidence on the audit issue, and resume atomically:

```bash
node scripts/manage-migration-author-lanes.mjs --resume-author-lease \
  --claim <n> --owner <owner> --lease-hours <hours>
```

Resume is not a reversal of the relinquish; it re-runs every current collision
and version check, because the world moved while the work was parked.

**Terminal retirement — the work cannot or should not return.** Record the
terminal evidence on the audit issue first, so the decision is auditable before
anything closes. Where the work is potentially recoverable — a `dirty` or `remote` worktree —
preserve a rescue branch or patch, leave the claim protective, and report it
`Blocked —` until popcre/shared-db#3675 lands; never bypass `--owner-decision` and
never ask Albert; `clean` or proven
`absent` work the owning session retires through the supported guarded operation. Close the pull
request through the normal authenticated operator flow, never deleting its branch
or refs, so the history survives the closure. Retire the claim with the
tombstoning form:

```bash
node scripts/manage-migration-author-lanes.mjs --release-claim <n> --owner <owner>
```

That write is deliberately not a deletion: it writes an immutable tombstone and
reads it back before the claim closes, so a later reader can tell a retired claim
from one that silently vanished. A successor takes a fresh claim tuple and a
fresh migration version; a retired version can never be reissued, because it may
already exist in a preview database.

**What the record must contain.** The abandonment record must identify the claim,
the pull request and its exact head, the recorded owner, the branch, the
migration version, the last known worktree and machine, the expiry, the evidence
that the author is terminal or unreachable, the observed worktree state, and the
recovery or successor references. All of these are recorded as identifiers only —
never personal paths, account names, credentials, tokens or message contents,
because the audit issue is a durable shared artifact and an identifier is all a
successor needs to reconstruct the lane.

The audit issue's `db-work-scope` fence carries an empty `objects:` on purpose.
Claiming an object there would collide with the very claim being investigated,
and the investigation would block itself.

## Phase 2 preview and reviewer lifecycle

Phase 2 is active. Protected claims never disappear when an author lease is relinquished, and preview dependencies are waits rather than successful checks. Before manual preview dispatch, re-audit live claims, run `node scripts/manage-migration-author-lanes.mjs --prepare-preview-dispatch <issue>`, rerun the read-only selector with a fresh preview-ledger read, and use only the matching stored instruction. Historical recovery is apply-only; a historical dry-run proves nothing. Use `--repair-preview-ready <ready-id> --issue <n>` only for a v2-bound stale wrong digest; a corrupt live digest stops without mutation and goes to an assigned AI reviewer, never to Albert. Reviewer reservations record one review per exact head and session under the current repository policy; they never serialize independent reviews by the same provider and never create a wait because a provider is already reviewing.

## Before preview and merge

For each PR separately:

1. Acquire the exclusive GitHub-backed preview lock for the exact PR head.
2. Fetch `origin/main` and update the branch from the newly merged main tip.
3. Re-run version, object-collision, SQL and contract checks.
4. Apply and prove the migration on preview.
5. Satisfy current repository-enforced exact-head approval policy. Where external
   review is required, obtain it with no unresolved Critical or High finding.
   The scoped `popcre/shared-db` `owner_no_reviewer` path is valid only when that repository
   enforces its committed owner policy; it grants no preview or production bypass.
6. Release preview, acquire the exclusive merge lock, revalidate the head/base,
   and merge one PR through the guarded path.
7. Release merge and the author claim, then repeat from the new main tip.

Never resolve full-body `CREATE OR REPLACE` conflicts mechanically. Re-derive the later change from the newly merged body.

Production remains a separate single lane. After review, green checks, preview,
and guarded merge, the successful merged-main preview workflow automatically
qualifies and dispatches the production workflow's governed business-risk gate.
It reads the exact merged PR/checks, immutable review artifact, pinned preview
apply proof, the one open linked structural work issue independently admitted
from current scope plus actual migration files, current-main SQL, and activation
record. Never supply risk booleans
or prose as evidence, and never manually reconstruct version or artifact inputs
for the automatic path. All five derived business-risk conclusions must be clear;
any one blocks automatic v2 promotion for an engineer. Missing, stale,
multi-source, or ambiguous evidence stops for an engineer
without dispatch. See the operating manual. The dispatched lane freezes merges
for the bounded promotion and verifies the exact production result.

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

## Optional agent brief

When delegation is authorized and useful, start from [references/sub-agent-brief-template.md](references/sub-agent-brief-template.md). Include:

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
