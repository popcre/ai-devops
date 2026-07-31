---
name: shared-db-handover
description: Hand over, wrap up, close out, or STOP any session working in `u2giants/shared-db` or on the shared Supabase database — whether or not that session is the coordinator. TWO paths. (A) You are NOT the coordinator — trigger on "stop work and hand over", "stop what you are doing on shared-db", "transfer your work to the coordinator", "hand your work to the coordinator", "hand your work to the orchestrator", "hand this off to the coordinator", "you are not the coordinator", "another session is coordinating this", "there is already a coordinator", "write your handover into COORDINATOR_INTAKE", or "fill in the intake template" — then stop all work and write a handover block into `COORDINATOR_INTAKE.md` at the repo root. (B) You ARE the coordinator — trigger on "hand this over", "hand this session over", "hand it to a new session", "wrap up", "wrap up this session", "close this out", "close out the session", "end of session", "we're done here", "write the handoff", "write the handoff for what the subagents did", "I'm out of context", "context window is full", "fresh session", or "give the next session a prompt" — then write the two-halves handoff. Applies whenever the work involved a database or schema change, a migration, RLS, a view, RPC, trigger, seed, a preview or production promotion, a cross-app data contract, the shared-db repo, or any dispatched sub-agents/worktrees. A coordinator handoff has TWO halves — coordination state AND a separate block per sub-agent — and one missing the second half is incomplete no matter how long it is, so prefer this skill over the generic `wrap-up` / `handoff-writer` whenever sub-agents or the shared database were involved. Pair with `shared-db-orchestrator`, which is how a coordinator session is opened and run.
---

# shared-db-handover

## FIRST: are you the coordinator? Answer this before anything else

`u2giants/shared-db` runs **ONE coordinator session at a time**, and that
coordinator dispatches every piece of work to sub-agents in isolated worktrees
(see `shared-db-orchestrator`). Handing over means something completely
different depending on which you are, so settle it first.

**You are the coordinator only if** this session was opened as the coordinator —
it has been maintaining the live register, writing sub-agent briefs, and reading
their reports. If you were started to *do* a piece of shared-db work, or you have
just realised you are working in this repo without being the coordinator, you are
**not** the coordinator. When in doubt, you are not.

Then take exactly one path:

- **NOT the coordinator → path (A) below.** Stop and file an intake block.
- **The coordinator → path (B), the rest of this skill.**

---

## (A) You are NOT the coordinator — stop, and file into the intake queue

**Stop working now.** Do not continue the task, and do not commit, push, merge,
apply, promote, or write anything further to any database. Do not create
background task chips. Do not delete or clean up your worktree or branch — the
coordinator may resume them, and an agent that tidies itself away destroys the
evidence.

**Do exactly one thing:** write a handover block into **`COORDINATOR_INTAKE.md`
at the root of the `shared-db` repo**, using **the fill-in template inside that
file**. That file is the single source of truth for both the queue and the
template — read it and follow it; do not invent your own format, and do not copy
a template from here.

Follow whatever the file says about how to land the change (normally: its own
branch, a PR, left OPEN and **not merged**).

Your block must cover, at minimum:

1. **What you were doing and why** — the task as you understood it, and who or
   what asked for it.
2. **What you actually DID** — commits with SHAs, branch names, PR numbers and
   their current states. Not intentions; actions.
3. **Anything applied to preview `rjyboqwcdzcocqgmsyel`** — **migrations AND
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

## (B) You ARE the coordinator — the two-halves handover

The end of a `u2giants/shared-db` session. This skill exists because the normal
handoff is not enough here: a shared-db session is run by a **coordinator** that
dispatched sub-agents (see the `shared-db-orchestrator` skill), and the next
coordinator has to be able to resume or retire **each agent individually**.

> **This skill does not replace `handoff-writer`.** Follow that skill's file
> convention (one write-once file at
> `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, never a rewrite of the shared
> root `HANDOFF.md`, never another session's file), its 9 required sections
> including the mandatory "what we tried that did NOT work", and its
> fresh-developer self-audit gate. This skill adds what shared-db needs on top.

## The handoff has TWO halves

A coordinator handoff that omits half (b) is **incomplete**, no matter how long
it is.

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

## Ingesting a block from `COORDINATOR_INTAKE.md`

Other sessions file their handovers into `COORDINATOR_INTAKE.md` at the repo root
(path A above). When you ingest one: **verify every claim against the live repo
rather than trusting it** — `git fetch --all`, `gh pr list`, `git worktree list`,
and the real current maximum migration version in `supabase/migrations/`.
Documents in this repo have gone stale within the hour, and multiple agents have
caught real errors exactly this way.

After you have dispatched the work, **move the ingested block to the file's
"TAKEN OVER" section with the date** rather than deleting it. The queue's history
is the audit trail of who touched what.

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
5. **Never merge on the way out.** A pending PR is handed over, not rushed
   through to tidy up the session.
6. **Run the closers:** `session-docs-update` for the documentation ritual and
   `secrets-to-1password` for the secrets sweep. Credentials are referenced by
   1Password item ID only — never a value in the handoff.
7. **Pass the gate:** could a developer who walked in off the street this morning
   continue with NO questions, as effectively as you can right now? If not,
   expand and re-grade.

## Related

- `COORDINATOR_INTAKE.md` at the root of `u2giants/shared-db` — the live intake
  queue and the **single source of truth for the handover template** used by
  path (A). Never duplicate that template here; it changes hourly.
- `shared-db-orchestrator` — how the session is opened and run (coordinator +
  sub-agents, single-writer ownership, the never-use-task-chips rule, and the
  incident ledger behind each rule).
- `handoff-writer` — the canonical 9-section handoff standard and file naming.
- `session-docs-update` — the end-of-session documentation ritual.
- `templates/system/handoff-standard.md` in `ai-devops` — the cross-tool standard.
