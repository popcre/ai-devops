---
name: always-delegate-work-to-subagents
description: "In multi-workstream sessions, the main chat is for coordination only — always spawn a sub-agent to do actual work"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0169440c-dc84-42ec-b27b-2b4c00ac02c4
  modified: 2026-07-29T11:40:11.716Z
---

Never do actual implementation work in the main chat session. ALWAYS spawn a sub-agent
for it — including small verification commands, file reads for analysis, and git/gh
inspection beyond a one-line status check.

**Why:** Albert runs several parallel workstreams through one coordinating chat (see
[[shared-db-parallel-workstreams]]). The main context window is the coordination layer;
if it fills up with implementation detail, the coordinator loses the thread across all
workstreams at once, which is far more expensive than any single sub-agent restarting.

**How to apply:** In the main chat, do only: read sub-agent reports, decide what happens
next, ask Albert for decisions, and launch sub-agents. Give each sub-agent an isolated
git worktree and explicit anti-collision instructions naming the other concurrent agents
and the files/branches they own. Relay only the conclusions to Albert, not the file dumps.
