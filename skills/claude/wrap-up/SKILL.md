---
name: wrap-up
description: One-phrase end-of-session closer. Use when the user says "wrap up", "wrap it up", "dflow wrap up", "wrap up dflow", "close out this session", "we're done here", or "end of session" — ANY "wrap up" variant, including project-prefixed ones like "dflow wrap up", routes HERE, not to a ship-only skill. In a shared-database or orchestrator session it first runs the `shared-db-handover` gate. Chains the four closing rituals: docs update FIRST, then secrets sweep, handoff-safe state, push verification, workspace close-out (uncommitted files, branch, worktree), and a next-session prompt — then gives a single plain-English closing report. This skill OWNS "wrap up"; it delegates the ship step to the project ship skill (dflow → dflow-ship) but never the other way around.
---

# wrap-up

One word closes the session properly. Runs the four closing rituals in order
and ends with a single consolidated report. From this point on the session takes
on no new work — see the scope freeze below. Skip nothing silently — if a step
doesn't apply, say so in the report.

## Scope freeze — no new work after "wrap up"

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

## Trigger phrases

- "wrap up" / "wrap it up"
- "dflow wrap up" / "wrap up dflow" / "dflow wrap-up" (project-prefixed — still THIS skill)
- "close out this session" / "we're done here" / "end of session"

> Any message containing "wrap up" belongs to this skill, even when a project
> name is attached. Do NOT route "dflow wrap up" to `dflow-ship` — `dflow-ship`
> is only Step 4 (ship & verify) of this skill's chain, and it does not update
> the .md docs. Running it alone silently skips the docs step. This skill runs
> docs FIRST, then calls `dflow-ship` for the ship step.

## Step 0 — the shared-database gate (run this FIRST, before step 1)

Before anything else, answer this out loud in the session: **did this session
touch the shared Supabase database or `u2giants/shared-db`, dispatch sub-agents,
or hold an `orchestrator-marker` issue?**

Check rather than assume — `gh issue list --repo u2giants/shared-db --label
orchestrator-marker --state open` and the session's own history. If the answer
to ANY of those is yes, **stop and run the `shared-db-handover` skill now**; it
owns the whole close-out for this session, including the marker, the `db-work`
queue, and one handoff block per sub-agent. Come back to the chain below only
for the parts that skill does not cover.

Bare "wrap up" is enough to trigger this gate. Albert never has to name the
shared-db skill, the issue commands, the labels, or a path letter — if he did,
this gate would be broken. A generic handoff from a shared-db session is
incomplete, and so is an orchestrator session that ends with its marker open.

## The chain

1. **Docs** — run the `session-docs-update` skill: record what this session
   learned or changed in the right .md files (AGENTS.md / docs/ / your own
   `HANDOFF.d/` file), mirror any shared-backend change to `u2giants/shared-db`.
   If nothing durable changed, state that explicitly.
2. **Secrets** — run the `secrets-to-1password` skill: sweep the session for
   any credential that appeared and store it in the `vibe_coding` vault with
   rich notes.
3. **Handoff-safe state** — every touched repo: no mystery untracked files,
   no half-done merges. If work is unfinished, write **ONE NEW file of your own**:
   `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` (e.g.
   `HANDOFF.d/2026-07-29T2140Z-t16-claude-supabase-mcp-scoping.md`) to the full
   `handoff-standard.md` — all 9 sections — and RUN ITS SELF-AUDIT GATE. A
   stranger who walked in off the street must be able to continue with no
   questions, as effectively as you can right now, including knowing what was
   tried and failed. A three-sentence handoff is a failure; expand until the
   audit passes (use the `handoff-writer` skill, which owns the naming rules,
   the static `HANDOFF.md` pointer, legacy migration, and retention). Once it
   passes, if asked whether the handoff is comprehensive enough, answer "Yes"
   with evidence — do not reflexively answer "No, I'll fix it."

   The scope freeze above makes this section load-bearing: every item you
   declined to start during this wrap-up must be written here, actionable cold.

   Concurrency rules, non-negotiable — other agents may be working the same
   checkout right now:
   - **Do NOT rewrite the root `HANDOFF.md`.** It is a static pointer to
     `HANDOFF.d/`. If it is still a legacy full document (line 1 lacks
     `handoff-pointer: v1`), migrate it per `handoff-writer`: `git mv` it verbatim
     into `HANDOFF.d/` as one open workstream, then write the pointer.
   - **Do NOT open, edit, tidy, or delete another session's `HANDOFF.d/` file.**
   - **Retention:** delete YOUR `HANDOFF.d/` file when the work it describes is
     proven done (git history keeps the text). If `HANDOFF.d/` holds **more than
     5** files, warn loudly in the closing report — list them oldest-first with
     dates and ask which are actually finished.
4. **Ship & verify** — commit and push everything per each repo's rules
   (dflow → `dflow-ship`: PR to develop; hetz apps → `deploy-and-verify`:
   Actions/GHCR/Coolify + live SHA check; everything else → main). Confirm
   working trees are clean and pushes landed. Never report "done" on
   unverified evidence.

5. **Close the workspace** — leave no orphaned branch, worktree, or file.
   Order matters; each gate must pass before the next.
   - **Uncommitted files:** every modified/untracked path gets an explicit
     decision — commit it, add it to `.gitignore`, or move it out of the repo.
     "I'll leave it" is only allowed if you name the file and the reason in the
     closing report. Never `git clean`, never `git checkout --` over unreviewed
     work, and never touch a file you did not create this session (another
     session may own it — see `concurrent-session-clobber-hazards`).
   - **Branch:** delete the local and remote branch ONLY after proving the work
     landed — `gh pr view <n> --json state,mergedAt` shows `MERGED`, or the
     commits are reachable from `origin/main`. A squash merge rewrites SHAs, so
     test with `git branch --merged origin/main` or by confirming the PR state,
     not by comparing SHAs. If it is not merged, keep the branch and say so.
   - **Worktree:** remove this session's worktree only when its tree is clean
     AND its branch is merged or intentionally preserved. Use the
     `cleanup-worktree` skill — it owns the safety audit, recovers unique work,
     and never treats age as proof that deletion is safe. If anything is
     unmerged or uncertain, LEAVE THE WORKTREE and name it in the report.
   - **Never** delete a branch, worktree, or checkout that another session is
     using, and never delete unmerged work to make the report look clean.

6. **Next-session prompt** — end with a copy-paste prompt Albert can drop into a
   fresh session to resume exactly here. Put it in its own fenced block at the
   very bottom of the closing report, and make it self-contained: a stranger
   pasting it into an empty session must be able to continue with no chat
   context. It states the repo and branch, the one-sentence goal, what is
   already done, the exact next action, how to verify success, and a pointer to
   the `HANDOFF.d/` file written in step 3. If the work is genuinely complete,
   say "No follow-up prompt — this workstream is closed" instead of inventing one.

## Closing report (plain English, one message)

```md
## Session closed
- What we accomplished: [1-3 sentences, business language]
- Docs updated: [files, or "nothing durable changed"]
- Secrets: [stored/none found]
- Handoff: [new HANDOFF.d/<file> written + why / none because work is complete;
  files deleted as done. Report STALE files — ones whose issue is already closed —
  by name with their owner. Never report the file COUNT as a problem: 20 concurrent
  workstreams means 20 files and that is correct (owner ruling 2026-08-13)]
- Shipped: [commit SHAs, PR URLs, deploy verified yes/no]
- Loose ends: [anything Albert should know, or "none"]
- Deferred by the scope freeze: [what you found or were asked during wrap-up and
  did NOT do, and where it is written down — or "nothing came up"]
- Workspace: [uncommitted files decided; branch deleted/kept + why; worktree
  removed/kept + why]

Then, as the last thing in the message, the fenced next-session prompt from
step 6 (or the single line saying the workstream is closed).
```

If any step could not be completed (blocked push, failing test), say exactly
what and what the next session should do — do not end the report on "done".
