---
name: codex-session-closeout
description: One-phrase Codex end-of-session closer. Use when the user says "wrap up", "update the .md files", "close out this session", "is everything pushed and committed?", or asks for docs, handoff, secrets, git, deploy state, worktree/branch cleanup, or a prompt for the next session before ending. In a shared-database or orchestrator session it first runs the `shared-db-handover` gate.
---

# Codex Session Closeout

Close the session in one pass. Do not make the user paste the long docs prompt,
ask whether the handoff is good enough, or separately ask for git/deploy status.

**Before any of that, run the closeout contract in the always-loaded global
(`~/.codex/AGENTS.md`, Response Style):** name the deliverables the request asked
for and check each against something real. Preparation is not delivery. If one is
unfinished and nothing blocks it, keep working — closing a session is not a way
to end a turn with authorized work outstanding. Codex has no mechanical backstop
for this the way Claude does, so on this client the contract is the only check
there is.

## Scope freeze — no new work after closeout starts

The moment a wrap-up is invoked, this session stops taking on new work. That is
the point of closing: everything after this line is either finishing what is
already in flight or writing it down for the next session.

- **Finish what is genuinely in progress** — a commit that is written but not
  pushed, a PR that is open but not merged, a test that is running, a file that
  is half-edited. Complete it, then stop.
- **Do NOT start anything new.** No new issue, no new fix, no "while I'm here"
  cleanup, no refactor you noticed on the way out, no follow-up you thought of
  yourself. This includes work Albert mentions in passing during the wrap-up and
  problems you discover while running the closing steps — they go in the
  handoff, not into this session.
- **A bug found during wrap-up is a handoff item, not a task.** Write it down
  with what you saw. Do not fix it. The one exception is a change that makes the
  session unsafe to leave — an exposed secret, a broken main branch, a
  half-applied migration — which is finishing, not starting.
- **This does not license leaving authorized work undone.** Work Albert asked
  for BEFORE the wrap-up and that is still unfinished is in progress: finish it.
  The freeze blocks NEW scope, never the original request.
- **Because nothing new gets done here, the handoff carries the whole load.**
  Everything deferred by this rule must appear in the handoff file with enough
  detail that the next session can act on it cold — what it is, where you saw
  it, why it was deferred, and the exact next step. A deferred item that is not
  written down is lost work, and that is the failure this rule exists to
  prevent.

## Step 0 — the shared-database gate (run this FIRST, before step 1)

Before anything else, answer this out loud in the session: **did this session
touch the shared Supabase database or `u2giants/shared-db`, dispatch sub-agents,
or hold an `orchestrator-marker` issue?**

Check rather than assume — `gh issue list --repo u2giants/shared-db --label
orchestrator-marker --state open` and the session's own history. If the answer
to ANY of those is yes, **stop and run the `shared-db-handover` skill now**; it
owns the whole close-out for this session, including the marker, the `db-work`
queue, and one handoff block per sub-agent. Come back to the procedure below
only for the parts that skill does not cover.

Bare "wrap up" is enough to trigger this gate. Albert never has to name the
shared-db skill, the issue commands, the labels, or a path letter — if he did,
this gate would be broken. A generic handoff from a shared-db session is
incomplete, and so is an orchestrator session that ends with its marker open.

## Procedure

1. **Summarize durable knowledge.** Update only markdown files that future
   sessions need: `AGENTS.md`, relevant docs under `docs/`, your own
   `HANDOFF.d/` file, or a focused fix note. Do not rebuild all docs unless the
   user asked.
2. **Handoff gate.** If work is unfinished, write **ONE NEW file of your own**:

   ```
   HANDOFF.d/<UTC-timestamp>-<machine>-<agent>-<slug>.md
   ```

   e.g. `HANDOFF.d/2026-07-29T2140Z-t16-codex-supabase-mcp-scoping.md`. Timestamp
   from `date -u +%Y-%m-%dT%H%MZ`; `<machine>` = short hostname lowercased;
   `<agent>` = `codex`; `<slug>` = 2–5 word kebab-case topic. All four fields are
   required — dropping one is what makes two sessions collide.

   Write all 9 sections of `templates/system/handoff-standard.md` so a fresh
   developer can continue without chat context: what was tried and failed, current
   branch/state, exact next steps, verification gates. Run the evidence-backed
   three-question audit in that standard: answer each question with supporting
   section references, close every gap found, and repeat until all answers are
   yes. A bare "yes" does not pass.

   The scope freeze above makes this gate load-bearing: every item you declined
   to start during this closeout must be written here, actionable cold.

   **Concurrency rules — other agents may be in this same checkout right now:**
   - **Never rewrite the root `HANDOFF.md`.** It is a short static pointer to
     `HANDOFF.d/`. If line 1 lacks `handoff-pointer: v1` it is a legacy full
     document: `git mv` it verbatim into `HANDOFF.d/` as one open workstream, then
     write the pointer (see `handoff-writer` for the exact pointer text).
   - **Never open, edit, tidy, or delete another session's `HANDOFF.d/` file.**
   - **Retention:** delete YOUR file when the work it describes is proven done —
     git history preserves the text. Presence of a file means the workstream is
     OPEN. Never treat the file COUNT as a problem and never cap it — 20 concurrent workstreams means 20 files and that is correct (owner ruling 2026-08-13). Warn about STALE files instead: ones whose issue is already closed. List those by name with the owner from their contract block; the target is zero.
   - **Never add `.gitattributes merge=union`** for handoffs; line-unioning
     Markdown yields a silently wrong document instead of a loud conflict.
3. **Secret hygiene.** Search this session and diffs for new credentials,
   tokens, connection strings, passwords, private URLs with embedded tokens, or
   `.env` changes. Never print secret values. Move durable secrets to
   1Password vault `vibe_coding` when available, or record the needed action in
   your own `HANDOFF.d/` file.
4. **Repo state.** Run `git status --short --branch`. Commit and push when the
   user asked to ship, when the repo's standing rules require it, or when the
   session changed durable project files. Use Albert's git author from global
   instructions.
5. **Verification.** Run the relevant tests/checks before commit if code
   changed. For deployed apps, verify the pushed SHA reached CI and the live
   app by the repo's documented deploy path. Do not report "done" from local git
   state alone.

6. **Close the workspace.** Leave no orphaned branch, worktree, or file.
   - **Uncommitted files:** make an explicit decision for every modified or
     untracked path — commit, ignore, or move out of the repo. Leaving one is
     allowed only if you name the file and the reason in the report. Never
     `git clean` and never discard a file you did not create this session.
   - **Branch:** delete local and remote branches only after proving the work
     landed (`gh pr view <n> --json state,mergedAt` shows `MERGED`, or the
     commits are reachable from `origin/main`). Squash merges rewrite SHAs, so
     verify by PR state or `git branch --merged origin/main`, never by SHA
     comparison. Not merged means keep the branch and say so.
   - **Worktree:** remove this session's worktree only when its tree is clean
     and its branch is merged or intentionally preserved. Follow the
     `cleanup-worktree` procedure — recover unique work first, and never treat
     age as proof that removal is safe. When anything is unmerged or uncertain,
     leave the worktree in place and name it in the report.
   - Never delete a branch, worktree, or checkout another session is using, and
     never delete unmerged work to make the report look clean.
7. **Next-session prompt.** End the report with a copy-paste prompt that lets a
   fresh session resume exactly here, in its own fenced block at the very
   bottom. It must stand alone without chat context: repo and branch, the
   one-sentence goal, what is already done, the exact next action, how to verify
   success, and a pointer to the `HANDOFF.d/` file from step 2. If the work is
   genuinely complete, write "No follow-up prompt — this workstream is closed".

## Closing Report

Return one short report:

```md
## Session closed
- Accomplished: ...
- Docs/handoff: ...
- Secrets: ...
- GitHub: branch, commit, push status
- Verification: commands/checks/live evidence
- Workspace: uncommitted files decided; branch deleted/kept + why; worktree removed/kept + why
- Deferred by the scope freeze: what came up during closeout that you did NOT do, and where it is written down / nothing came up
- Loose ends: none / ...
```

Then, as the last thing in the message, the fenced next-session prompt from
step 7 (or the single line saying the workstream is closed).

If any gate failed, report the blocker and the exact next action instead of
calling the session closed.
