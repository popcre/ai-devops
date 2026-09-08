# Issue #168 — root plan backlog consolidation

Date: 2026-09-08
Repository baseline: `9682ec00062619261a545c25188da50195b1a807`

## Result

All 48 root `plan_*.md` files are classified in
[`docs/implementation-plan-index.md`](../../../docs/implementation-plan-index.md):
9 active, 26 completed decision records, and 13 superseded or reference-only
records. Count reduction was deliberately not used as a success measure.

One real orphaned obligation was preserved instead of discarded:
`plan_reviewer-cache-efficiency.md` now has live owner issue #333. Its two
rejected designs remain rejected; only truthful provider-returned cache usage
reporting is active.

## Live-state checks

- Open pull requests and registered worktrees were inspected before selection.
  No branch or PR owned issue #168. PR #332 owns the concurrent router rewrite;
  this child does not edit its source files before reconciliation.
- GitHub issues #35, #62, #131, #159, #187, #198, #249, #253, and #333 are the
  live owners of the nine executable plans.
- Completed plans are not routed as executable work. Stale incomplete tables
  are explicitly subordinated to their named successor in the index.
- The open-issue body inventory was searched for every root plan filename. No
  issue points only to a deleted plan because this child deletes no plan record.
- Existing handoffs were treated as protected write-once records. No other
  session's handoff was edited or deleted.

## Preservation proof

Every completed or superseded plan remains in Git, so its decisions, evidence,
and rejected approaches remain available. The index names a current successor
where one exists and warns that historical presence is not authority to restart
work. This follows the repository's existing completed-plan retention rule and
the cleanup procedure's requirement to preserve uncertain or separately owned
artifacts.

## Acceptance mapping

| Gate | Evidence |
|---|---|
| Every executable plan has live ownership, current restart state, and discoverability | Active table in `docs/implementation-plan-index.md` |
| Every retirement has evidence and preserved decisions | Completed and superseded tables; original files and Git history retained |
| No issue points only to a deleted plan | No plan was deleted; open issue bodies were searched by exact filename |
| Count is an outcome, not a target | 48 plans remain; classification and routing changed, not the count |
| Parent plan updated with durable evidence | `plan_repo-throughput-restructure.md` links this record in its #168 STATUS row |
