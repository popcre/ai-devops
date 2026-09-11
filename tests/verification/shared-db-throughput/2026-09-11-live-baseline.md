# Shared-db throughput live baseline — 2026-09-11

This is the redacted Step 0 ledger for `popcre/ai-devops#401`. It records coordination and repository state only. It contains no raw transcript, licensed row, credential, database write, or production authorization.

## Exact source state

- `popcre/ai-devops` `origin/main`: `b6922ea8e2de41726c6cd55958555921cc4a6629`.
- `u2giants/shared-db` `origin/main`: `f3eff56d26dcdec29bba42a209e1d51fbc3a2689`.
- Both implementation folders were created as fresh linked worktrees from those then-current tips. Re-fetch before any later phase because these repositories are active.

Reproduce:

```text
git fetch --prune origin
git rev-parse origin/main
```

## Programme and prerequisites

| Item | Live state at capture | Owner / integration rule |
|---|---|---|
| `popcre/ai-devops#401` | OPEN | This programme ledger. |
| `u2giants/shared-db#2530` | OPEN; transfer-plan Steps 0–11 open | Separate repository-maintenance plan; exact transfer/settings action remains its Step 0 gate. |
| `u2giants/shared-db#2705` / PR `#2717` | OPEN / OPEN at `1f686f0eaebd933c2432be94d14d54ceb4fc6cbb`; its own active Codex task exists | Consume its merged proof; do not duplicate or take its branch. |
| `u2giants/shared-db#2709` / `popcre/ai-devops#402` | CLOSED / MERGED as `b6922ea8e2de41726c6cd55958555921cc4a6629`; all required checks succeeded | Verify the real merge-base behavior, then consume it. Its active completion task retains live-proof ownership. |
| `u2giants/shared-db#2715` | OPEN; no landed repair at capture | Separate shared-db repository-maintenance owner. |
| `u2giants/shared-db#2716` | OPEN; no landed repair at capture | Separate cross-repository policy/workflow owner; no database or production write is part of implementation. |
| `popcre/ai-devops#159` / `#166` / `#337` | OPEN / OPEN / OPEN | Existing throughput and reviewer owners; integrate rather than recreate their work. |

Reproduce issue and pull-request state:

```text
gh issue view <number> --repo <owner/repo> --json number,state,updatedAt,url
gh pr view <number> --repo <owner/repo> --json number,state,headRefOid,baseRefOid,mergeCommit,mergedAt,statusCheckRollup,url
```

## Live ownership and shared stages

- Sole orchestrator marker: shared-db issue `#2714`, declaring a live Codex route. This programme did not open or replace the marker.
- Author capacity audit: `4/8` active-author leases, four protected claims, zero relinquished, zero expired at capture.
- Reviewer-active refs existed for six durable reviewer identities. Their presence is protection/history, not proof that six reviewers are currently working.
- No preview, merge, or production stage-lock ref matched the audited lock prefixes at capture.
- The orchestrator reported three production-applied structural candidates with direct catalog/security proof (`#2579`, `#2496`, and `#2507`), one production run in progress (`#2501`), one failed runtime outcome requiring forward repair (`#2506`), and two application-side acceptance waits (`#2576`, `#2482`). These are candidate evidence only; Step 10 still requires five consecutive outcomes under the activated model and direct live application proof.

Reproduce:

```text
node scripts/check-orchestrator-marker.mjs --resolve
node scripts/manage-migration-author-lanes.mjs --audit
node scripts/manage-migration-author-lanes.mjs --queue-audit
git ls-remote origin "refs/db-review-active/*" "refs/db-preview-lock/*" "refs/db-merge-lock/*" "refs/db-production-lock/*"
```

## Repository protections and runners

- `u2giants/shared-db` remained repository id `1275568548`, public, under `u2giants`; `main` branch protection was strict `false`, enforced for administrators, and required the twelve existing contexts including `Migration guarded merge authorization`.
- `popcre/ai-devops` remained repository id `1289642575`, public. Active ruleset `main: pull request + merge queue` required `linux-offline` and configured the native queue; ordinary branch-protection REST returned 404 because rulesets are authoritative there.
- Visible self-hosted runners were `EDGE-ALIEN` (paused label, idle), `edge-dev-win` (idle), and `EDGE-RUNN-ENVY` (qualified, busy). Runner state is drift-prone; re-read before dispatch.
- Open-PR inventory at capture included 13 shared-db PRs and 10 ai-devops PRs. Relevant heads were enumerated before work; later gates must query again rather than trust this count.

Reproduce:

```text
gh api repos/<owner>/<repo>
gh api repos/<owner>/<repo>/branches/main/protection
gh api repos/<owner>/<repo>/rulesets
gh api repos/<owner>/<repo>/actions/runners --paginate
gh pr list --repo <owner/repo> --state open --limit 100 --json number,title,headRefOid,isDraft,updatedAt,url
```

## Step map and duplicate-owner guard

- Steps 0, 9, and the ai-devops half of the programme ledger are owned by `popcre/ai-devops#401`.
- Step 1 consumes `#2705/#2709` and delegates `#2715/#2716` only to their natural repository/policy owners.
- Steps 2–7 are shared-db repository-maintenance changes. They must not acquire migration-author or shared-stage claims merely because they change orchestrator tooling.
- Step 8 is exclusively `u2giants/shared-db#2530`; this programme must not create a second transfer/queue implementation owner.
- Actual structural outcomes remain with marker `#2714` and its dispatched application/database owners.
- Step 10 consumes outcome evidence but does not reclassify application verification as orchestrator work.

Every later issue or successor must classify its own proposed change from behavior. A sender assertion, `db-work` label, handoff, repository path, or predecessor route is not admission evidence.
