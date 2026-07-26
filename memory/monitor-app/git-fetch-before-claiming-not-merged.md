---
name: git-fetch-before-claiming-not-merged
description: "Run `git fetch` before concluding a commit/PR isn't merged — local main and worktrees go stale and I once blocked a task on a false \"not on main\"."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f53acafd-df82-4687-ae97-e35068197383
---

Never conclude a commit, fix, or PR "is not on main / is unmerged / has no PR" from
local refs alone. **Run `git fetch` (or check `origin/main`, not `main`) first.**
Worktree branches and local `main` go stale silently.

On 2026-07-16 I told Albert that security fix `ff4c8c0` was "not on main, no open PR,
sitting unmerged" and stopped the task on that basis. It had in fact landed on
`origin/main` (rebased as `da9bcf9`), plus two later commits I never saw. My local
`main` was pinned at `d8a7196` and I never fetched. Codex fetched, caught it in
minutes, and rebased. The worktree genuinely lacked the code — that part was real —
but my *diagnosis* of why was wrong, and it cost a turn.

**Why:** this is the same species of error as [[verify-mcp-availability-via-claude-mcp-list]] —
asserting something is absent from a check that cannot actually see it. A stale ref
and a negative tool search fail the same way: they return a confident, wrong "no".

**How to apply:** before any claim about merge/branch/PR state, run `git fetch` and
compare against `origin/*`, or `gh pr list --state all` (not just `--state open` — a
merged PR is not open). State which ref you checked. If a fact would block or redirect
the user's task, verify it against the remote before reporting it as a blocker.
