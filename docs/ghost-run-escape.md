# Ghost-run escape (LANE_EPOCH)

Tracking: popcre/ai-devops#2367. Ported from popcre/shared-db `docs/ghost-run-escape.md`
(popcre/shared-db#6426).

## What a ghost is

A GitHub dispatch failure can leave a workflow run record that the runs list shows
`queued` forever with zero jobs. GET/DELETE on it return 404/403 and cancel is refused.
It still holds its workflow's `concurrency` group, so every later run in that group
waits forever. The ghost sweeper (`.github/workflows/ghost-run-sweep.yml`) reaps the
removable ones every 30 minutes and goes red, naming this page, on any it cannot remove.

## Why the escape works

Every concurrency group in `.github/workflows/` ends with
`-${{ vars.LANE_EPOCH || '0' }}` (enforced by `tests/test-concurrency-epoch.sh`).
Group names are evaluated per run, so bumping the one repository variable
`LANE_EPOCH` renames every group at once; new runs no longer queue behind the ghost.
Never hand-rename a single group — that can split a group two workflows share.

## Procedure

1. **Confirm a live blockage.** Match the ghost to the concurrency group of a
   run or expected check that is still needed. A queued record with zero jobs
   alone is insufficient evidence. Leave unrelated ghosts for GitHub Support.
2. **Drain before renaming a held group.** The setting affects every workflow
   using it. Confirm no legitimate run is queued or in progress in those
   workflows (`gh run list -R popcre/ai-devops --status in_progress` and
   `--status queued`). A bump while legitimate work is active can let runs
   overlap. Keep the change manual and leave the group names alone when the
   fresh run already uses a free group.
3. **Bump if the fresh run would reuse the held group.** Read the current value
   (`gh variable get LANE_EPOCH -R popcre/ai-devops`;
   unset means 0) and run
   `gh variable set LANE_EPOCH -R popcre/ai-devops --body <current+1>`.
4. **Trigger a fresh run and verify the expected checks.** Use the original
   event type. For a pull request, push a fresh commit to the same PR after any
   required bump. Verify groups PR runs by PR number, so a push alone can
   reuse a held group. For a merge-queue check, let the queue create a fresh
   entry through normal queue handling. For a scheduled check, observe the
   next scheduled run. A manual dispatch verifies only the manual event.
   Confirm the new run ID, its event and target, and the expected check results.
5. **Record.** Note the ghost IDs, any bump, and the proving run ID and check
   results on [popcre/ai-devops#2367](https://github.com/popcre/ai-devops/issues/2367).
   Request a purge from GitHub Support separately. This procedure restores
   blocked checks while GitHub handles the underlying records.

The sweeper stays red until Support purges the ghost; that alarm is intended. Do not
suppress it.
