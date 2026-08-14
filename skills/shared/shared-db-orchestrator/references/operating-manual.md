# Shared DB orchestrator operating manual

## Contents

1. Startup recovery
2. Author locks
3. Preview and merge locks
4. Release and recovery
5. Review and production

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

Production is separate, owner-approved and serialized. Freeze merges for the
bounded promotion, verify the exact target before any write, and verify the exact
production result. Read [incident-ledger.md](incident-ledger.md) when a safety
rule appears unnecessary.
