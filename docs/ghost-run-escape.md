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

1. **Check whether anything is blocked.** A ghost on a merged or deleted branch blocks
   nothing. Leave it for GitHub Support and stop here.
2. **Drain.** Confirm no real (non-ghost) run is queued or in progress in the affected
   workflows (`gh run list -R popcre/ai-devops --status in_progress` and
   `--status queued`; ghosts are the ones with zero jobs). A bump while a real run is
   active lets the next run start beside it instead of after it.
3. **Bump.** Read the current value (`gh variable get LANE_EPOCH -R popcre/ai-devops`;
   unset means 0) and run
   `gh variable set LANE_EPOCH -R popcre/ai-devops --body <current+1>`.
4. **Prove it.** Re-run the blocked workflow and confirm it starts and completes.
5. **Record.** File a GitHub Support purge for the ghost run ids, and note the bump,
   the ghost ids and the proving run id on popcre/ai-devops#2367.

The sweeper stays red until Support purges the ghost; that alarm is intended. Do not
suppress it.
