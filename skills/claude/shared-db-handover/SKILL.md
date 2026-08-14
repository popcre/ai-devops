---
name: shared-db-handover
description: Hand over, wrap up, close out, or STOP any session working in `u2giants/shared-db` or on the shared Supabase database — whether or not that session is the orchestrator. TWO paths. (A) You are NOT the orchestrator — trigger on "stop work and hand over", "stop what you are doing on shared-db", "transfer your work to the orchestrator", "hand your work to the orchestrator", "hand your work to the orchestrator", "hand this off to the orchestrator", "hand your work to the coordinator", "hand this off to the coordinator", "you are not the coordinator", "there is already a coordinator" (COORDINATOR is the older word for the ORCHESTRATOR role, still used in older issues and in git history, and must trigger this skill too), "you are not the orchestrator", "another session is coordinating this", "there is already a orchestrator", "write your handover into COORDINATOR_INTAKE", or "fill in the intake template" — then stop all work and open a GitHub issue on `u2giants/shared-db` (the `COORDINATOR_INTAKE.md` file was retired on 2026-08-07). (B) You ARE the orchestrator — trigger on "hand this over", "hand this session over", "hand it to a new session", "wrap up", "wrap up this session", "close this out", "close out the session", "end of session", "we're done here", "write the handoff", "write the handoff for what the subagents did", "I'm out of context", "context window is full", "fresh session", or "give the next session a prompt" — then write the two-halves handoff. Applies whenever the work involved a database or schema change, a migration, RLS, a view, RPC, trigger, seed, a preview or production promotion, a cross-app data contract, the shared-db repo, or any dispatched sub-agents/worktrees. A orchestrator handoff has TWO halves — coordination state AND a separate block per sub-agent — and one missing the second half is incomplete no matter how long it is, so prefer this skill over the generic `wrap-up` / `handoff-writer` whenever sub-agents or the shared database were involved. Pair with `shared-db-orchestrator`, which is how a orchestrator session is opened and run.
---

# shared-db-handover

## FIRST: are you the orchestrator? Answer this before anything else

`u2giants/shared-db` runs **ONE orchestrator session at a time**, and that
orchestrator dispatches every piece of work to sub-agents in isolated worktrees
(see `shared-db-orchestrator`). Handing over means something completely
different depending on which you are, so settle it first.

**You are the orchestrator only if** this session was opened as the orchestrator —
it has been maintaining the live register, writing sub-agent briefs, and reading
their reports. If you were started to *do* a piece of shared-db work, or you have
just realised you are working in this repo without being the orchestrator, you are
**not** the orchestrator. When in doubt, you are not.

Then take exactly one path:

- **NOT the orchestrator → path (A) below.** Stop and open a `db-work` issue.
- **The orchestrator → path (B), the rest of this skill.**

---

## (A) You are NOT the orchestrator — stop, and open a handover issue

**Stop working now.** Do not continue the task, and do not commit, push, merge,
apply, promote, or write anything further to any database. Do not create
background task chips. Do not delete or clean up your worktree or branch — the
orchestrator may resume them, and an agent that tidies itself away destroys the
evidence.

**Do exactly one thing: open a GitHub issue** on `u2giants/shared-db` describing
what you were doing and what state you left it in.

```bash
gh issue create --repo u2giants/shared-db --label db-work   --title "HANDOVER: <what you were doing>"   --body-file <a file you wrote>
```

> ⚠️ **CHANGED 2026-08-07.** This used to say "write a handover block into
> `COORDINATOR_INTAKE.md` using the template inside that file". **That file is
> retired** — it was a hand-built issue tracker in Markdown that several sessions
> edited at once and that never once shrank. **Do not append to it.** If you find
> instructions telling you to, they are stale.

**The nine things the issue must say.** This replaces the template that used to live
in the file. Answer every one, including the ones that make you look bad — those are
the ones that save the next session a day:

1. What you were doing, and why.
2. What you have **actually done** — with PR numbers, commit SHAs and branch names.
3. What you applied to **preview**, and what to **production**. "Nothing" is a fine
   answer and is worth saying explicitly.
4. What is **half-finished or abandoned mid-way**.
5. What you **own right now** — branches, worktrees, open PRs, dispatched agents.
6. What you were **about to do next**.
7. What you are **blocked on**.
8. **What you tried that did NOT work, and why. [MANDATORY]** Never leave this out.
   A handover without it makes the next session repeat your dead ends.
9. **Facts you believe that may already be stale** — anything you read more than an
   hour ago, and every count, SHA and version you are quoting.

**If the narrative is long, keep it a file and point at it.** Put the outstanding work
in the issue and leave a ten-page briefing in `HANDOFF.d/`. A ten-page briefing pasted
into an issue is a ten-page briefing nobody reads.

**Right path.** If you had **already started** work, this is a handover — this path.
If you had **not** started and simply need a database **change** made, that is a
**request**, and the skill is `shared-db-orchestrator`. Filing one as the other sends
it to the wrong triage.

**Read-only inspection is neither.** If all you did was *look* — schemas, tables,
columns, keys, indexes, views, functions/RPCs, triggers, RLS policies, migration
history, generated types, safe sample data — and compare it to your app's data
shape, you have nothing to hand over and nothing to request. Reading the shared
schema is allowed from every application repo, always, with no issue and no
dispatch. Say what you learned and carry on. A handover is only owed once you
mutated something (DDL, `apply_migration`, a migration file, a branch, a
preview or production push).

**Ordinary application data writes are not a handover trigger either** (owner ruling
2026-08-13, `AGENTS.md` §0.0-B). An application session that inserted, updated, or
deleted its own rows — a feature, a bug fix, its own ingest tables, a backfill of data
the app produced, preview fixtures, job/queue/audit rows — owns those writes and owes
this repo nothing for them. Two things still do trigger a handover:

- **any bulk or ad-hoc load of outside-sourced content into curated Master Data**
  (`core.licensor`, `core.property`, `core.character`, `core.customer`, `core.factory`,
  `*_ext`) — the §6.4 carve-out, unchanged; and
- **any data you wrote to preview `<removed-protected-project-ref>` while running as, or dispatched
  by, the orchestrator** — point 3 below. Preview is a shared rehearsal environment, so
  the disclosure is about not poisoning the next rehearsal, not about permission.

Your block must cover, at minimum:

1. **What you were doing and why** — the task as you understood it, and who or
   what asked for it.
2. **What you actually DID** — commits with SHAs, branch names, PR numbers and
   their current states. Not intentions; actions.
3. **Anything applied to preview `<removed-protected-project-ref>`** — **migrations AND
   data rows.** Data writes count and are the thing sessions routinely forget to
   mention. Preview holds a full production data clone and is shared; an
   unannounced write there is how the next rehearsal gets a false result.
4. **Anything half-finished or abandoned mid-way** — say so plainly rather than
   rushing to finish it. A half-applied migration disclosed is recoverable; one
   concealed is an incident.
5. **What you own** — which files, branches and worktrees, and whether any of
   them are **dirty** (uncommitted changes, untracked files).
6. **What you were ABOUT to do next** — the very next action, in enough detail
   that someone else could take it.
7. **What you are blocked on**, and which kind of block it is: another
   workstream, or a decision only Albert can make. If it is Albert's, state the
   question in one or two plain-English sentences.
8. **What you tried that did NOT work, and why — MANDATORY.** This is the
   section that stops the next session burning hours re-walking a dead end. A
   block without it is not a handover. Include approaches abandoned, commands
   that failed, and assumptions that turned out false.
9. **Facts you believe that may already be stale** — anything you read early in
   the session and have not re-checked (a `main` SHA, a max migration version, a
   PR state). Documents in this repo have gone stale within the hour.

**Then stop and report** that you have filed the block, with the PR link if you
opened one. Do not start anything else, and do not "just finish this one thing".

---

## (B) You ARE the orchestrator — the two-halves handover

The end of a `u2giants/shared-db` session. This skill exists because the normal
handoff is not enough here: a shared-db session is run by a **orchestrator** that
dispatched sub-agents (see the `shared-db-orchestrator` skill), and the next
orchestrator has to be able to resume or retire **each agent individually**.

> **This skill does not replace `handoff-writer`.** Follow that skill's file
> convention (one write-once file at
> `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, never a rewrite of the shared
> root `HANDOFF.md`, never another session's file), its 9 required sections
> including the mandatory "what we tried that did NOT work", and its
> fresh-developer self-audit gate. This skill adds what shared-db needs on top.

## The handoff has TWO halves — and a REQUIRED queue seed

A orchestrator handoff that omits half (b) is **incomplete**, no matter how long
it is. **A orchestrator handoff that leaves outstanding work with no open
`db-work` issue is equally incomplete**, and carries exactly the same weight —
see "Seed the queue" below. *(Corrected 2026-08-09: this named the `REQUEST
QUEUE` in `COORDINATOR_INTAKE.md`, retired 2026-08-07.)*

**(a) Coordination state**

- live workstreams and what each is for
- who owns which file (migrations / HANDOFF.md / AGENTS.md / everything else)
- open PRs, their state, and their merge order
- what is blocked on Albert, and the exact question he owes an answer to
- current `main` SHA and maximum migration version, **with the time they were
  checked** — these go stale within the hour
- **preview's actual state** — what is sitting on it, whose it is, and why it is
  not clean

**(b) Every sub-agent's work, SEPARATED BY SUB-AGENT**

One clearly headed block per agent — never merged into a single narrative:

```markdown
### Agent: <name / worktree path>
- **Asked to do:** …
- **Actually did:** … (commits, SHAs)
- **Found:** … (including anything that contradicts another agent)
- **PR / branch:** …
- **Worktree:** live (resumable) | finished (safe to clean)
- **Deliberately did NOT do, and why:** …
```

That last line matters most. Without it the next session redoes abandoned work
or, worse, undoes a deliberate omission.

## Seed the queue — REQUIRED, and a handover without it is INCOMPLETE

**Before you call the handover done, the outgoing orchestrator MUST seed or
open or update an issue for EVERY outstanding
item** — everything in `HANDOFF.md`'s opening agenda, its "waiting on Albert"
list, and its `## BACKLOG` section, plus anything you dispatched that did not
finish. Nothing outstanding may exist only in `HANDOFF.md` prose.

**Why this rule exists — 2026-07-31.** A fresh orchestrator opened a session, read
the `REQUEST QUEUE`, `INTAKE QUEUE` and `IN PROGRESS` sections of
`COORDINATOR_INTAKE.md` exactly as `shared-db-orchestrator` instructs, found all
three empty, and reported **"there is no pending work"** while roughly **twenty
real jobs** sat in `HANDOFF.md`'s `## BACKLOG`. Every word of that report was
true and the conclusion was completely wrong. The cause was not the incoming
session: the **outgoing** orchestrator had written a long narrative handover and
never populated the queue, because nothing in this standard required it. It does
now.

How to do it correctly:

- **Short entries only** — a heading, one or two sentences of what outcome is
  needed, and a pointer to the section of `HANDOFF.md` that holds the detail.
  Open an issue with the `db-work` label; see `shared-db-orchestrator`.
- **Never duplicate content.** Detail copied into the queue is detail that will
  drift out of date; the two documents have already drifted apart repeatedly in
  this repo. **No document wins by name or by date.** Where the queue and
  `HANDOFF.md` (or the newest `HANDOFF.d/` file) disagree, **re-derive the fact
  from `git`/`gh` and believe that** — do not rank the documents and pick one.
- **Every `HANDOFF.md` `## BACKLOG` item `B<n>` gets an entry**, titled so the
  B-number is visible in the heading (`### REQUEST — Backlog B7 — …`).
- **Refresh, do not restart.** Issues already open and still outstanding stay
  open; issues whose work has landed get a closing comment naming the PR and are
  then closed. Never delete an issue. *(Corrected 2026-08-09: this pointed at
  lifecycle rules owned by the retired `COORDINATOR_INTAKE.md`.)*

## Ingesting a handover issue

Other sessions open a GitHub issue titled `HANDOVER: …` with the `db-work` label
(path A above). ⚠️ They used to append to `COORDINATOR_INTAKE.md`; that file was
**RETIRED** on 2026-08-07 and is now a pointer. When you ingest one: **verify every
claim against the live repo rather than trusting it** — `git fetch --all`, `gh pr list`, `git worktree list`,
and the real current maximum migration version in `supabase/migrations/`.
Documents in this repo have gone stale within the hour, and multiple agents have
caught real errors exactly this way.

After you have dispatched the work, **comment on the issue** with the date and
who you dispatched it to, and close it once the work lands — never delete it. The
issue history is the audit trail of who touched what. *(Corrected 2026-08-09:
this said "move the ingested block to the file's TAKEN OVER section", which was
the retired `COORDINATOR_INTAKE.md` workflow.)*

## The sweep — do this BEFORE you write the handover, not after

The handover describes the state you leave behind, so tidy the state first.
Three passes, and then a fourth that is just honesty:

1. **Close out the issues you handled.** Every `db-work` issue you dispatched and
   every `HANDOVER:` issue you ingested gets a dated comment saying what happened
   and, where the work has landed, a close referencing the merged PR — never
   deleted. *(Corrected 2026-08-09: this instructed moving blocks between sections
   of `COORDINATOR_INTAKE.md`, retired 2026-08-07.)*
2. **Verify each finished branch is actually merged, then retire its worktree.**
   For each agent you are calling finished: confirm the PR is merged
   (`gh pr view`), confirm the commits are in `origin/main`, and only then retire
   the worktree.

   ⚠️ **`git branch --merged` CANNOT see a squash-merged branch.** `main` is
   squash-merged, which rewrites the commit. Measured 2026-08-13: **74 of 130
   branches looked unmerged to git while their pull request was merged.** Every
   cleanup keyed on git ancestry therefore reports live work and cleans nothing —
   which is exactly why 29 worktrees and 130 branches accumulated. **Ask GitHub
   whether the PULL REQUEST merged.** `scripts/reap-merged-worktrees.mjs` in
   `shared-db` does this: dry run by default, `--apply` to act, and it refuses
   while any `orchestrator-marker` issue is open because a clean worktree on a
   merged branch is indistinguishable from one a live sub-agent just pushed from.

   Remote branches now delete themselves — `delete-branch-on-merge` was turned on
   for `u2giants/shared-db` on 2026-08-13.

2a. **Retire the `HANDOFF.d/` file of every workstream you finished, in the same
   pull request that closes its issue.** You are the session that did the work and
   the only one who can tell it is really done; a later session can only guess, and
   that guessing is what left 27 finished files in the directory (issue #658).
   Every handoff file opens with a contract block naming its issue:

   ```
   ---
   issue: 925
   status: OPEN            # OPEN or BLOCKED — never DONE
   owner: <branch/session>
   ---
   ```

   The `Handoff Contract Guard` enforces this on every pull request. It fails only
   for handoff files **your** pull request touches, never for anybody else's.

   ⛔ **Never report the file COUNT as a problem and never add a cap.** Twenty
   concurrent workstreams means twenty files and that is correct (owner ruling,
   2026-08-13). Report **stale** files — those whose issue is already closed —
   by name, with the owner from their contract block.
2b. **Open or refresh a `db-work` issue for every outstanding item** — the
   section above. This is not optional tidying: a handover that leaves outstanding
   work unqueued is **incomplete**, in exactly the same way as one missing the
   per-sub-agent blocks. On 2026-07-31 an un-seeded queue caused a fresh
   orchestrator to report "there is no pending work" over a twenty-item backlog.

3. **Flag anything you deliberately left.** A worktree you chose not to touch, a
   branch you left alive, a request you decided not to dispatch — each gets one
   line saying it was a decision, not an oversight. Unexplained leftovers get
   treated as abandoned by the next session and deleted.

**The deletion rules — narrow on purpose:**

- **A local branch label is deleted only when it is fully merged into
  `origin/main` AND checked out in no worktree.** Both conditions, verified, not
  assumed.
- **Remote branches are deleted by the merge itself, never by hand.**
- **A worktree is NEVER removed if it is dirty, locked, or held by a live
  process.** Uncommitted work in a worktree is the only copy of that work.

Use the **`cleanup-worktree`** skill as the safe procedure for any of this. Do
not improvise `git worktree remove --force` or `git branch -D`.

## Evidence obligations at handover time

The handover is where unverified claims become someone else's false assumptions.

- **"Applied" is not "rehearsed."** If a migration replaced a function that an
  earlier rehearsal validated, that rehearsal is **void** until re-run. Either
  re-run it and attach a dated evidence artifact, or state plainly in the handoff
  that the rehearsal is stale and which migration invalidated it. A "14/14 PASS"
  was carried forward across four `CREATE OR REPLACE` migrations while the suite
  had grown to 18 cases with 4 never executed.
- **Name every migration by exact 14-digit version.** Three of four correction
  migrations were missing from `HANDOFF.md` and the cutover plan, so a promotion
  list built from that plan would have shipped a partial fix. List them all.
- **Verify each sub-agent's "done" against the artefact, not its report.** Before
  writing an agent's block, open its diff or PR. One agent's "added" content lived
  only in its uncommitted working tree — four items uncommitted, one never
  written. Record what the diff shows, not what the agent said.
- **Timezone in audit trails.** The database runs `America/New_York`; a
  midnight-UTC approval timestamp reads back through `::date` as the previous day
  and misdates an owner ruling. Pin approvals to **midday UTC** and assert the
  date in both UTC and server-local time.
- **Null-permissive guards.** `if not ( … or auth.role() = … )` never fires when
  `auth.role()` is NULL, as it is inside a migration — the guard silently admits
  the call. If one shipped, say so in the handoff; authority must be asserted
  explicitly.

## Before you call the handover done

1. **Re-verify the moving facts at write time**, not from memory: `git fetch`,
   the `main` tip SHA, the maximum migration version, and every open PR's state.
   Stamp each with the time it was checked.
2. **State preview's state honestly.** "Clean" is almost never true; say what is
   sitting on it and whose it is.
3. **Leave no worktree unexplained.** Every worktree under `.claude/worktrees/`
   is either live (say what it is mid-way through) or finished (say it is safe to
   clean). A sibling session may be auditing worktrees — an unexplained one gets
   treated as abandoned.
4. **No mystery untracked files** in the repo. Either commit them under the
   repo's branch/PR rules or list them in the handoff with what they are and the
   exact next action.
5. **Merge your OWN docs-only handover PR before the session ends. Hand over
   only work PRs.** A schema/code PR mid-review is handed over, not rushed
   through to tidy up the session — that is what this rule was for. But a
   **docs-only** PR (the handover itself, queue entries, notes) is merged by the
   session that wrote it: `AGENTS.md` §5 says docs-only merges promptly and §2
   says never leave an open PR behind.

   This split exists because the old blanket "never merge on the way out" is what
   stranded the **2026-08-05** handover in open PR #451. The next orchestrator read
   `main`, saw a five-day-old handover, and concluded the session had been lost.
   Nothing was lost; it was parked by the rule. A handover nobody can find is not
   a handover.
5b. **Close your orchestrator marker** — the open GitHub issue labelled
   `orchestrator-marker` you opened at step 0 of the orchestrator sweep.

   > ⚠️ **"Last" means AFTER STEP 9, not here at 5b.** This step is numbered 5b for
   > readability — it sits next to the PR merge it depends on — but **do not perform
   > it in numbered order.** Steps 6 through 9 (secrets sweep, docs pass, sweep
   > confirmation, queue check, the fresh-developer gate) all still run, and step 6b
   > says its output "goes in the handover PR". Closing the marker at 5b would drop
   > the single-orchestrator lock with five steps of closeout still to go, and would
   > tell the next orchestrator the board is clear while you are still working.
   > **Close the marker as the final external action of the session, after step 9
   > passes.** *(Ordering contradiction found 2026-08-11 by an independent Codex
   > GPT-5.6 review, shared-db issue #530.)*

   Close it **last**, after the handover PR is merged. Leaving it open makes the next
   orchestrator stop and ask Albert about a session that ended cleanly; that stop
   is the correct behaviour for a *dead* orchestrator and pure noise for a clean
   handover. If you are handing over without ending (a fresh session continues
   immediately), say so in the issue and leave it open deliberately.
6. **The secrets sweep — DO IT, do not delegate it to a skill the user has to
   invoke.** This step is part of the handover, not a follow-on ritual. Albert
   should never have to run a second closing skill because this one stopped short.

   Sweep the session for anything that should be in 1Password and is not: a
   credential that appeared mid-session, a token pasted into chat, a connection
   string in a scratch file, an `.env` written "just for now". Check the diff and
   any untracked files too, not only your memory of the session.

   - Store what you find per the **`secrets-to-1password`** skill — vault
     `vibe_coding` only, descriptive title, tags, and notes detailed enough for a
     future session that has never seen the entry. Fetch and write **serially**;
     never fan out `op` calls in parallel.
   - **A clean sweep is a RESULT, not a skip.** Say "swept, nothing new" in the
     handover. "I don't think any secrets came up" is not a sweep.
   - Credentials are referenced in the handoff by **1Password item ID only** —
     never a value, in any file, doc, commit, report or chat.

6b. **The documentation pass — DO IT here too, and keep it narrow.** Run the
   substance of **`session-docs-update`** as part of this handover rather than
   asking for it separately. In this repo that means asking four questions and
   acting on the answers:

   - Did this session change how something WORKS in a way `AGENTS.md` now
     mis-states? Standing facts and numbered rules go stale silently and are what
     the next session reads first.
   - Did it **disprove** something a live doc still teaches? Add a dated
     supersession pointer at the old claim. **Supersede, never rewrite** — the
     originals are the audit trail, and this repo has already shipped a reversal
     recorded in only one of the three places that taught the old behaviour.
   - Is any rehearsal or evidence artifact now **void** because a migration
     replaced what it validated? Say so, and name the migration that voided it.
   - Is the only record of a durable lesson your handover file? If so, that is
     usually correct — resist the urge to spray it across five documents.

   **Scope guard:** the handover file is the primary record. If nothing outside it
   is now WRONG, say "docs pass: nothing outside the handover is stale" and move
   on. Churning docs to look thorough is a cost, not a deliverable. State the
   conclusion either way — a silent skip is indistinguishable from an oversight.

   Both 6 and 6b go in the handover PR with the handover file, so the whole
   closeout is one docs-only PR and one merge.
7. **Confirm the sweep above was actually run** — queue blocks moved on, every
   "finished" branch confirmed merged and its worktree retired, and everything
   you deliberately left behind flagged as a decision. This is a checklist item,
   not a nicety: an unswept repo is how the next orchestrator inherits phantom
   worktrees and branches nobody dares delete.
8. **Confirm the queue is seeded.** Run
   `gh issue list --repo u2giants/shared-db --label db-work --state open` and
   check that every outstanding item — the opening agenda, the waiting-on-Albert
   list, and **every `B<n>` in `HANDOFF.md`'s `## BACKLOG`** — has an open issue
   pointing back at `HANDOFF.md`. **A handover without this is INCOMPLETE**, the
   same as one missing half (b). *(Corrected 2026-08-09: this told you to open
   `COORDINATOR_INTAKE.md`, which has been a 37-line pointer since 2026-08-07 —
   following it would have shown an empty queue over a live backlog, the exact
   2026-07-31 failure this step exists to prevent.)*
9. **Pass the gate:** could a developer who walked in off the street this morning
   continue with NO questions, as effectively as you can right now? If not,
   expand and re-grade.

## This skill is the WHOLE closeout — do not send Albert to a second skill

**`shared-db-handover` is all-encompassing for a shared-db session.** When it is
done, every loose end is tied: swept, documented, committed, pushed, merged, and
the marker closed.

**Do NOT run `wrap-up` after this skill.** They overlap, and `wrap-up`'s ship step
is already owned here — steps 5 and 5b merge the docs-only handover PR and close
the marker. Running it afterwards duplicates work and invites a second, competing
handover document.

The secrets sweep (step 6) and the documentation pass (step 6b) are **performed
inside this skill**, not delegated. A closeout that ends with "you should also run
X" has failed: Albert asked for one step, and one step is the standard.

**This absorption is scoped to the shared-db handover and nothing else.**
`secrets-to-1password` and `session-docs-update` are full skills in their own
right and are unaffected outside this file. `secrets-to-1password` still governs
**every** create or update in the `vibe_coding` vault, at any time, in any repo,
including mid-session when a credential appears — it is not a closing ritual.
`session-docs-update` is still the documentation closer for every other repo and
is still invoked directly whenever docs need updating. Both remain the authority
on *how* to do the work well; what changes here is only *who invokes them* during
a shared-db handover. Do not read this section as a demotion, and do not skip
either skill elsewhere on the strength of it.

**Corollary for the report:** state the outcome of both, even when both are empty
("swept, nothing new"; "docs pass: nothing outside the handover is stale"). A
silent skip and a clean result look identical, and only one of them is finished.

## Related

- ⚠️ **`COORDINATOR_INTAKE.md` is RETIRED (2026-08-07)** and is now a 37-line
  pointer; a required `Intake pointer guard` check fails any PR that regrows it.
  This entry used to call it the live REQUEST/INTAKE queue and "the single source
  of truth for both templates". It is neither. **GitHub issues on
  `u2giants/shared-db` with the `db-work` label are the queue**, and the nine
  things a handover issue must say are listed in path (A) of this skill. Corrected
  2026-08-09.
- `AGENTS.md` at the root of `u2giants/shared-db` — **the live rulebook, and it
  WINS over this skill wherever the two disagree.** This file is a portable
  summary; §12 "Standing facts an incoming session must know" is the canonical
  version of the safety rules restated here.
- `shared-db-orchestrator` — how the session is opened and run (the request path
  for anyone who needs a database change, the session-start hygiene sweep,
  orchestrator + sub-agents, single-writer ownership, the never-use-task-chips
  rule, and the incident ledger behind each rule).
- `cleanup-worktree` — the safe procedure for retiring worktrees and branches;
  never improvise a forced removal.
- `handoff-writer` — the canonical 9-section handoff standard and file naming.
- `session-docs-update` — the end-of-session documentation ritual, and a
  first-class skill in its own right: it is the closer for every other repo and is
  invoked directly whenever docs need updating. **Inside a shared-db handover you
  do not invoke it as a separate step** — step 6b performs its pass here so the
  closeout stays one step. Read it for the detail; it remains the authority on
  *how*.
- `secrets-to-1password` — the standing skill for EVERY create or update in the
  1Password vault, secret or not, used constantly outside handovers. **Inside a
  shared-db handover you do not invoke it as a separate step** — step 6 performs
  the sweep here. It remains the authority on how to write a vault entry a future
  session can use without asking a question.
- `wrap-up` — the general-purpose closer for OTHER repos. **Not used for
  shared-db**; this skill owns the shared-db closeout end to end.
- `templates/system/handoff-standard.md` in `ai-devops` — the cross-tool standard.
