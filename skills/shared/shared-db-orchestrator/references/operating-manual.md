# Shared DB orchestrator operating manual

## Contents

1. Startup recovery
2. Author locks
3. Preview and merge locks
4. Release and recovery
5. Review and production
6. Dynamic queues and automatic refill
7. External review rotation

## Startup recovery

Fail closed if GitHub cannot be read. Confirm the sole open orchestrator marker,
then rebuild state from current `main`, open `db-work` and `db-claim` issues,
open pull requests, GitHub coordination refs and local worktrees. Documents and
local scratch registers are never authority.

Run the coordination audit before dispatch:

```bash
node scripts/manage-migration-author-lanes.mjs --audit
```

Audit must report malformed or orphaned records while still showing readable
records. Do not allocate while any malformed claim or lock exists.

## Author locks

Albert's 2026-08-14 ruling allows no more than three unrelated migration authors.
The manager acquires GitHub-backed object locks and one of three fixed author
slots across all computers. The readable GitHub issue mirrors the lock; it does
not create the lock.

```bash
node scripts/manage-migration-author-lanes.mjs --claim \
  --task "<issue and outcome>" --owner "<agent/session>" \
  --branch "<branch>" --worktree "<absolute isolated worktree>" \
  --objects "<every exact normalized database object>"
```

The manager must include open draft and ready pull requests, paginate all GitHub
reads, reject unreadable input, reserve a permanent unique migration version and
return success only after lock read-back. Older claims count until adopted or
explicitly released. A lease expiry is a warning, never permission to ignore its
objects or author slot.

Do not create migration files before acquisition succeeds. Do not choose a
version manually. Do not edit fenced claim blocks.

## Dynamic queues and automatic refill

Every open `db-work` issue must carry this machine-readable block:

````text
```db-work-scope
state: eligible
priority: 100
depends_on:
objects:
  - table schema.name
````
```

Allowed states are `eligible`, `blocked`, `owner-decision`, `data-only`, and
`non-structural`. Use exact normalized objects, including every whole-body
function or trigger the implementation replaces. Higher priority runs first.
Open dependencies make otherwise eligible work wait.

Run `node scripts/manage-migration-author-lanes.mjs --queue-audit` at startup,
after every merge, and immediately after every claim release. Exact-overlap
components form serial queues; unrelated components fill the three lanes.
Dispatch every `REFILL REQUIRED NOW` issue in the same turn. Do not ask Albert
to approve dispatch. Ask only for a genuine owner decision or material business
risk.

An empty lane is justified only by a complete audit with no eligible candidate.
Unclassified or malformed issues make that proof impossible and the command
fails. Blocked, owner-decision, data-only and non-structural issues are reported
but never consume a lane. Preview and merge remain globally serialized. An
author waiting for those stages keeps doing safe local work or prepares the next
issue without creating an overlapping migration.

## Preview and merge locks

Author permission never grants preview or merge permission. Acquire one exclusive
GitHub-backed stage lock bound to the exact pull request and head commit. Only one
preview and one merge operation may exist, and production blocks merge.

Before either stage, fetch `origin/main`, update the branch from the newest main,
and rerun version, object-collision, SQL and contract checks. Release the stage
lock explicitly after the operation. Required CI must connect every migration
file and parsed object to the branch-bound author lock and permanent version.

Never mechanically merge competing full-body `CREATE OR REPLACE` changes.
Re-derive the later body from the newly merged main.

## External review rotation

After an issue reaches its exact final head, run:

```bash
node scripts/manage-migration-author-lanes.mjs --assign-reviewer \
  --issue <issue> --pr <pr> --head-sha <exact-head>
```

The GitHub-backed cursor rotates Grok 4.6, GLM 5.2, Kimi K3, Qwen 3.8 Max, then
repeats across machines and restarts. Retrying the same issue/PR/head returns the
same assignment. Use only the returned persistent wrapper: `ai-grok-review`,
`ai-glm`, `ai-kimi`, or `ai-qwen`. Never override its model or reasoning pin;
record Qwen High as requested if applicable, while using the wrapper's qualified
fixed configuration.

Require the reviewer to re-read the current exact head and return `APPROVE` or
`REVISE` with evidence. Independently verify every claim. Reuse the same named
session for rebuttals and relay them with `templates/delegation/debate-turn.md`.
Stop at evidence-backed agreement or after the initial review plus three
rebuttals. If a material disagreement remains, stop merge and ask Albert one
concise decision. Never expose secrets or licensed rows.

After every review, append objective evidence to
`C:\repos\ai-devops\models_comparison_grok_kim_glm.md` through an ai-devops PR:
issue/PR, model/version requested and proven, verdict, confirmed and disproved
findings, defects caught, false positives, policy/tool adherence, continuity,
latency, turns, tokens/cache/cost only when reported, and final outcome. Kimi's
headless token/cache/cost/returned-model figures are unavailable and must remain
marked unavailable.

After approval, green checks, preview proof, and guarded merge, dispatch the
production workflow with the exact source PR, review run and digest, preview
apply run and digest, current-main SHA, and ordered allowlist. The workflow runs
`scripts/production_business_risk_gate.py` before and after its approval wait.
It independently reads the merged PR and required checks, verifies both pinned
artifacts, proves the preview ledger change, and conservatively inspects the
current-main SQL. Caller-written booleans and explanatory prose are never
evidence. Automatic production promotion is allowed only when the governed
records prove all five: no permanent data loss/rewrite, no expected downtime,
no material access change, tested credible recovery, and no unresolved material
objection. Ambiguous SQL stops. Ask Albert one plain business-risk question and
never ask him to approve migration numbers, project identifiers, SQL, or other
technical details.

Transition rule: this policy cannot authorize its own rollout.
`config/production-risk-policy-activation.json` starts inactive, so the older
exact approval and production-environment review remain binding. Activation is
a later governed change and must name the merged shared-db #1021 and ai-devops
#24 commits, record matching canonical and installed skill hashes, and pin the
forward-test proof hash. The gate re-reads both PRs and all hashes before it can
use the automatic path. A boolean such as `active: true`, an explanation, or a
caller assertion without the complete exact schema fails closed.

## Release and recovery

Release is explicit and owner-checked. Before deleting any GitHub ref, verify it
still points to the expected immutable ownership record. A changed owner or an
ambiguous network result stops cleanup. Never retry a delete without reading the
ref again.

Expired work remains protective until safe cleanup proves the branch, worktree
and pull request are finished. Close the mirror issue only after its temporary
author and object refs are released. Never delete the permanent version ref.

If a session dies mid-acquisition, audit the partial refs and use the manager's
owner-verified recovery command. Never delete refs by hand.

## Review and production

Require independent review with no unresolved Critical or High finding. Merge
one pull request at a time, close its claim, update the next branch from newly
merged main and repeat.

Production is separate and serialized. Apply the business-risk gate above,
freeze merges for the bounded promotion, verify the exact target before any
write, and verify the exact production result. Read
[incident-ledger.md](incident-ledger.md) when a safety rule appears unnecessary.
