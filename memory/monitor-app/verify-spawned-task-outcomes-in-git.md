---
name: verify-spawned-task-outcomes-in-git
description: "A spawned/background session reporting \"not running\" tells you nothing about whether its work landed — check git branches, commits, and worktree status instead."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ebbda927-1665-4194-9210-de233ed43022
  modified: 2026-07-20T21:06:16.322Z
---

When reporting on background/spawned task sessions, verify outcomes against **git**,
not session metadata. `list_sessions` shows `isRunning: false` and sometimes a
`closed.` title prefix — neither means the work was committed, merged, or shipped.

Check, per follow-up: `git rev-list --count origin/main..<branch>` (commits ahead,
i.e. done but unmerged) and `git -C <worktree> status --porcelain` (uncommitted
work sitting in the worktree).

**Why:** on 2026-07-20 three spawned hardening tasks all showed "not running". Two
were complete but unmerged; the third — the most important — had found the same
root RCE in ~23 more tools and written a fully tested fix (49→116 tests green) that
was **100% uncommitted** in its worktree, with the session stopped. It would have
been lost with the worktree, and the live system was still exposed. Session status
would have led me to report "finished".

**How to apply:** before summarizing follow-up work, run the two git checks above for
each branch/worktree, and treat uncommitted-but-tested work as an active risk to
capture in `HANDOFF.md` immediately. Related: [[prove-nas-tools-by-running-not-reading]].
