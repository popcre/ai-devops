---
name: close-old-session
description: >-
  Safely pick up an abandoned or stale AI session — one that's hours, days, or
  weeks old — where this session's in-context memory of "what still needs doing"
  can no longer be trusted because other sessions ran in the meantime. Use when
  the user says "this chat is a week old", "is there anything to update in the
  .md files?", "should I merge / commit this?", "did we ever finish this?", "I
  abandoned this session", "picking this back up", or otherwise resumes a session
  after a gap AND asks whether pending doc/merge/commit work still stands. The
  ONE job it adds: verify against ground truth (git + current .md files + code)
  that each pending item wasn't already done or superseded by intervening
  sessions BEFORE acting — then delegate the actual doc/ship work to
  session-docs-update, wrap-up, or dflow-ship.
---

# close-old-session

Albert runs many short AI sessions in the same repos and sometimes abandons one
mid-thought, coming back hours to weeks later. By then **dozens of other sessions
may have touched the same repo.** The danger is that *this* session still
"remembers" pending work — a .md file to update, a branch to merge, a commit to
push — that a later session already did, did differently, or made obsolete.
Acting on that stale memory re-does work, reverts newer changes, or commits a
now-wrong edit. This skill exists to stop that.

The rule is simple: **this session's memory is a to-do list of *suspects*, not
*facts*. Confirm each against the current repo before doing anything.**

## Step 1 — List the suspects, don't act on them

Read back what this session thinks is still outstanding, as a plain list:
uncommitted edits, .md files that "need updating", a merge/PR that was pending, a
commit that was never pushed, a decision that was never written down. Do **not**
commit, merge, or edit yet. These are claims to verify, not tasks to run.

## Step 2 — Establish ground truth (the intervening sessions left tracks)

Before believing any suspect, look at what actually happened since:

- `git log --oneline -30` and `git log --since="<when the session went quiet>"`
  — did a later session already commit the thing this session meant to? Is the
  work already on `main` / the sandbox branch?
- `git status` and `git diff` — are the "uncommitted edits" this session
  remembers still present, or were they committed/reverted/overwritten? Untracked
  files this session created may already be gone or superseded.
- **Open the actual .md files** this session wanted to update and read the
  relevant sections. Someone may have already documented it — possibly better, or
  in a different file. Check the git history of that file
  (`git log -p -- path/to/FILE.md`) if unsure who last touched it.
- For code changes: read the current code, not this session's memory of it. The
  function/config/schema may already differ.
- Check `HANDOFF.md` if one exists — a later session may have recorded the state.

## Step 3 — Classify each suspect

For every item from Step 1, decide which it is and say so plainly:

- **Already done** — a later commit/edit covers it. Drop it. Don't re-do it.
- **Superseded** — the repo moved on and this session's version would now be
  *wrong* (stale schema, renamed file, changed decision). Discard the stale
  edit; do not force it in. Flag loudly if this session had uncommitted work that
  is now obsolete.
- **Still genuinely outstanding** — nobody did it and it's still correct. This is
  the only bucket that becomes real work.
- **Conflicting** — this session and a later one both changed the same thing
  differently. Do not silently pick one. Surface both to Albert with a
  recommendation (per the no-silent-failures / never-clobber-concurrent-work
  rules).

## Step 4 — Hand the surviving work to the close-out chain

This skill's job ends once the suspects are reconciled. Only the "still
outstanding" items proceed, and they go to the existing close-out owner — do
**not** re-implement docs/ship/secrets logic here:

- Full close-out (docs → secrets → handoff-safe → ship) → run **`wrap-up`**,
  which owns the chain and delegates ship per repo (dflow → `dflow-ship`, hetz
  apps → `deploy-and-verify`, else main).
- If Albert only wants the docs touched, not a full close-out → run
  **`session-docs-update`** (`codex-docs-update` in Codex) directly.

Feed `wrap-up` the reconciled picture from Steps 2–3 so it records/ships only
what actually survived — never the stale edits this skill just discarded.

## Output

Give Albert a short reconciled report, not a narration of git internals:

1. What this session *thought* was pending.
2. What ground truth showed — done / superseded / still open / conflicting, with
   the commit SHA or file that proves it.
3. What you did about the still-open items (with evidence: SHA, PR URL, file), or
   which skill you handed them to.
4. Any conflict that needs his call, stated plainly with your recommendation.

The whole point: he should never have to wonder whether resuming this old chat
quietly clobbered newer work. You already checked, and you say so.

## Related

- `session-docs-update` / `wrap-up` / `dflow-ship` — this skill reconciles first,
  then hands the actual doc/ship work to these.
- `fresh-session` — the forward-looking counterpart: when *leaving* a session
  mid-plan, it decides whether to cut over to a clean context window and grades
  the handoff. This skill is the backward-looking half (safely picking one up).
