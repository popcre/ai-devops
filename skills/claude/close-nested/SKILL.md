---
name: close-nested
description: "Close a coordinator session AND every nested subsession it started, then write ONE coordinator handoff whose prompt starts a fresh coordinator that re-spawns one nested subsession per still-open task. Use for \"close nested\", \"wrap up this session and all its subsessions\", \"close out the whole tree\", \"wrap up everything including the side sessions\", or \"hand the whole fleet to a new coordinator\". Plain single-session \"wrap up\" stays with `wrap-up`."
---

# close-nested

Closes a whole session tree in one pass: every nested subsession is wrapped up
first, their leftovers are merged with this session's own open work, and the
result is ONE handoff file plus ONE paste-ready prompt. Pasting that prompt into
an empty session creates a **pure coordinator** that does no task work itself
and starts one nested subsession per open task.

This skill is a superset of `wrap-up`. Load `wrap-up` and `handoff-writer` now;
their rules (scope freeze, shared-db gate, secrets, ship & verify, workspace
close, GitHub-URL-only paths, self-audit) apply unchanged to this session and
to every child. This file adds only the tree-specific steps.

## Scope freeze — whole tree

From invocation on, no session in the tree takes new work. Children finish what
is genuinely in flight (unpushed commit, open PR, running test), then stop.
Anything new becomes a task in the handoff, never work.

## Step 1 — inventory the tree

1. List linked sessions: `mcp__ccd_session_mgmt__list_sessions` with
   `{"linked": true}`. Recurse: for each child, ask it (step 2) to report its
   own linked sessions too, so grandchildren are included.
2. Also inventory subagents and background tasks this session launched that
   have not reported back. A subagent is not a session: wait for its result or
   stop it (`TaskStop`) and record its unfinished scope as a task.
3. Build a working table (scratch file under `$TMPDIR`, not chat):
   session id, title, state (working / idle / waiting on user / stopped /
   cloud), branch, worktree, PR, issue.
4. Cloud sessions never report back. Inspect their pushed branch/PR on GitHub
   directly; if nothing is visible, record the task as "state unknown — cloud
   session <link>" and carry it forward as open.

## Step 2 — wrap up each child (in parallel)

Send every live child the same message via `SendMessage` (`to` = its
`local_…` id), quoting Albert's words for authority:

```text
Albert said: "<exact words that invoked close-nested>".
Run the wrap-up skill on this session now (scope freeze applies: finish only
what is in flight, start nothing). If you started nested sessions, send them
this same message first and wait for theirs. Then reply with ONLY this block:

CLOSE-NESTED REPORT
session: <your local_ id + title>
repo/branch/worktree: <owner/repo, branch, landed|preserved|removed>
shipped: <PR URLs + merged yes/no, deploy verified yes/no>
handoff file: <GitHub URL of your HANDOFF.d file, or none>
open tasks (one per line): <goal> | <exact next action> | <done-when> |
  <issue/PR URL> | <branch to resume from or "fresh from main"> | <blockers>
child sessions: <their CLOSE-NESTED REPORTs, verbatim, or none>
claims/locks held: <must be none; else why>
```

Rules while waiting:
- Do not poll. The app wakes you when children end turns.
- A child waiting on Albert: answer it yourself if the answer is within
  existing authority; ask Albert only a business-meaning question.
- A child with no progress for 30 minutes is broken: stop it, inspect its
  worktree/branch/PR yourself, preserve unique work (commit to its branch and
  push, never discard), and record its remaining scope as a task.
- A report is a claim, not proof. Verify each "shipped/merged" against
  GitHub (`gh pr view <n> --json state,mergedAt`) and each handoff URL exists.

## Step 3 — wrap up this session

Run `wrap-up` steps 1–6 on this session itself (shared-db gate, docs, secrets,
ship & verify, workspace close). Skip its step 7 and closing report; this skill
writes them for the whole tree.

## Step 4 — merge the open-task list

Combine this session's open work with every verified child task:

- **Dedupe** tasks that share an issue, PR, or branch; keep the most recent,
  verified state.
- **Drop** tasks proven done (merged + verified) — list them under "landed".
- **Split** any task that two writers would share files on; **merge** tasks
  that must land in one change.
- Mark dependencies: a task that needs another's result is `after: <task>`.
- Every task names: goal, current state with evidence, exact next action,
  done-when (live proof), issue URL (one issue per application need; open one
  if missing and nothing else tracks it), resume branch, and owner machine if
  it matters.

## Step 5 — write ONE coordinator handoff

Use `handoff-writer` to write a single
`HANDOFF.d/<UTC>-<machine>-claude-close-nested-<slug>.md` that passes its full
self-audit. Required sections beyond the standard:

- **Tree closed:** every session (title, link, final state, branch disposition).
- **Landed:** verified merged PRs.
- **Open tasks:** the merged list from step 4, one numbered subsection each,
  actionable cold, with dependency order.
- **Child handoffs:** GitHub URLs of each child's `HANDOFF.d` file (do not copy
  or edit them; never touch another session's handoff file).

Ship the handoff through the repository's normal PR flow and verify it landed,
so the prompt's URLs resolve.

## Step 6 — the coordinator prompt

The closing message ends with one fenced block, self-contained and using only
GitHub URLs:

```text
You are the COORDINATOR for <repo>. Do no task work yourself.
Read <GitHub URL of the close-nested handoff> fully first.
For each open task in its "Open tasks" section whose dependencies are met,
start one nested session with mcp__ccd_session__start_session
(initiation "user_asked", context "fresh", use_worktree true, one per task,
brief = that task's subsection verbatim plus "commit to your own branch, open a
PR, prove done-when live, then run wrap-up"). Start dependent tasks only when
their prerequisite session reports verified completion.
Your job: answer children's questions within existing authority, verify each
report against GitHub, re-route any child idle 30 minutes, and when all tasks
are verified done, run close-nested again (or wrap-up if no children remain).
Albert's authority for this work: "<his exact words>".
```

If no task is open, replace the block with "No follow-up prompt — the whole
session tree is closed."

## Closing report

One message, in Albert's style rules: what landed across the tree in plain
words, how many tasks carry forward, then **Still open**, then the fenced
coordinator prompt last. Never end on "waiting" while a child is still
wrapping up — finish step 2 first or report that child `Blocked —` with its
preserved state.
