---
name: shared-db-handover
description: Hand over, wrap up, close out, or stop any shared-db or shared Supabase session. Handover is notes on the same issue — not a new ticket. Claim-first is the default; no orchestrator chat or marker is required. Use for database handoff after schema work, fresh-session transfer, or explicitly delegated work. Keep every safety disclosure (claims, preview writes, private artifacts).
---

# shared-db-handover

## FIRST: settle what you owe (claim-first — no orchestrator role)

`popcre/shared-db` structural work is **claim-first**: a session claims exact
objects on the existing issue and starts. No orchestrator chat and no marker are
required. This skill's job is to leave **notes on the same issue** — never a new
ticket — so the work can continue safely.

When you keep unfinished live-proof work, leave a checklist item on the **same**
GitHub issue (e.g. `- [ ] live proof`) and name it in your closing note. Do
**not** open a leftover-proof issue, an "unproven step" issue, or a second
ticket for that gap. One issue per application need; one named owner until the
app works live.

---

## (A) Hand over unfinished work — notes on the same issue

**Stop implementation now.** Do not continue the task, merge its implementation
PR, apply, promote, or write anything further to any database. Do not create
background task chips. Do not delete or clean up your worktree or branch —
another session may resume them, and an agent that tidies itself away destroys
the evidence. The native ownership operations below and a prose-only closeout PR
are allowed solely to complete a safe handover; they authorize no implementation.

**Finish ownership cleanup before ending.** The stop instruction freezes task
execution; supported claim/stage handoff metadata operations remain required.
A prose-only closeout PR may still be committed, pushed and normally merged;
this exception finishes closeout and authorizes no new implementation or database
write. Use claim-first rules below; historical marker examples are not live steps.
A note alone is not a release. Enumerate this actual session's claims, subagents
and exclusive stages, stop its writers, and verify each outcome:

- Completed and live-accepted work: use native release only after its delivery,
  source, recovery and closed-issue gates pass.
- Unfinished clean source: execute merged `--stop-author` with exact claim,
  issue, PR/head, owner, branch and worktree. Re-read the relinquished claim and
  create-only owner-issued handoff-ready receipt. A qualified successor can take
  over immediately without waiting for the former deadline or waking the old chat.
- Known successor: that actual recipient uses `--handoff-claim-author` with
  the exact ready receipt, declares its own identity, and verifies source,
  reservation, object protection, clean custody and its thirty-minute permission.
  Do not impersonate the predecessor or call cooperative handoff abandonment.
- Dirty, remote, legacy or ambiguous custody: preserve unique bytes through the
  governed route and record the precise refusal on the same issue. Never delete
  source/object/version protection or fake expiry. Release only finished stages
  this session owns; never claim readiness without the actual receipt.

These ownership flags require the native helper to be available from merged
shared-db source. Before reporting that they work, verify source change #4271 is
merged, and use a clean canonical `shared-db` tool worktree at the current merged
source. Inspect that source's CLI option definitions to confirm the exact
supported flags; this helper has no `--help` handler. Run supported flags from
that tool worktree and pass the preserved source worktree with `--worktree`. Verify
the tool's current source identity, supplied worktree/claim inputs, and native
readiness or operation receipts before claiming capability. Do not run an old
helper from, or overwrite, the source worktree. If the merged helper, its
documented flags, or its required readiness evidence is unavailable, report the
ownership action as blocked; do not claim live capability.

This is also the normal completion/stop rule; wrap-up repeats it as a fallback.
Before declaring closeout complete, freshly verify that no execution capacity
remains with the stopped session and every retained object claim has a verified
successor or immediately acceptable ready receipt. A refused gate leaves closeout
incomplete; AI owns its repair.

Active structural sessions explicitly confirm continued need using owner-bound
`--check-in-author` every ten minutes and before protected writes. New permissions
last at most thirty minutes. Do not renew merely because a process exists.
Missing confirmation stops execution while retaining source and permanent
version/object protection.

**If the unfinished work changes the database's shape, leave a handover block on
the existing GitHub issue** in `popcre/shared-db` describing what you were doing
and what state you left it in. **Do not open a new ticket.** If a `db-work-scope`
block already exists, extend it; never infer the route from the repository,
`db-work`, or `needs-albert`.

```bash
gh issue comment <existing-issue> --repo popcre/shared-db --body-file <a file you wrote>
```

Sign each GitHub post with the actual client engine: `Posted by <Codex or Claude>
chat <id> on <machine>`. Never attribute a post to an engine that did not make it.

Only structural work uses `route: claim-first`. Source-data decisions,
application data, documentation, repository maintenance, and security settings
keep their own routes. Outside-sourced writes into curated `core.*` Master Data
use `route: curated-master-data-governance`; they remain governed without entering
the structural migration-author queue.

> ⚠️ **CHANGED 2026-08-07.** This used to say "write a handover block into
> `COORDINATOR_INTAKE.md` using the template inside that file". **That file is
> retired** — it was a hand-built issue tracker in Markdown that several sessions
> edited at once and that never once shrank. **Do not append to it.** If you find
> instructions telling you to, they are stale.

**The nine things the note must say.** This replaces the template that used to live
in the file. Answer every one, including the ones that make you look bad — those are
the ones that save the next session a day:

1. What you were doing, and why.
2. What you have **actually done** — with PR numbers, commit SHAs and branch names.
3. What you applied to **preview**, and what to **production**. "Nothing" is a fine
   answer and is worth saying explicitly.
4. What is **half-finished or abandoned mid-way**.
5. What you **own right now** — branches, worktrees, open PRs, and explicitly delegated work.
6. What you were **about to do next**.
7. What you are **blocked on**.
8. **What you tried that did NOT work, and why. [MANDATORY]** Never leave this out.
   A handover without it makes the next session repeat your dead ends.
9. **Facts you believe that may already be stale** — anything you read more than an
   hour ago, and every count, SHA and version you are quoting.

**If the narrative is long, keep it a file and point at it.** Put the outstanding work
in the issue and leave a ten-page briefing in `HANDOFF.d/`. A ten-page briefing pasted
into an issue is a ten-page briefing nobody reads.

**A dependency you file is yours to own — never "a future session."** The session
that files or identifies "this cannot proceed until N closes" either leaves the
issue/PR as the card and ends its turn (registration is not required; the bounded
janitor re-surfaces stuck state), or names the owning session/owner in the issue. Deferring to an
unnamed future owner is the anti-pattern that left popcre/shared-db#3180 unregistered
for ~15 hours until Albert asked (ai-devops #596). The `depends_on:` line in the
`db-work-scope` block is the durable record — the watcher's tick derives the native
"blocked by" link from it automatically — but the WAIT belongs to a named session.

**Right path.** If you had **already started** structural work, this is a handover —
this path. If you have not started and need a database shape change, use the
existing issue that tracks that application need and follow the claim-first route:
claim the exact objects and begin in your own current-upstream worktree. If no issue
exists for a genuinely new application need, create one issue for that need with
`route: claim-first`; do not create a second issue for its handover or live-proof
gap. There is no orchestrator or marker step.

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
- **any data you wrote to the protected shared preview project while doing
  structural work** — point 3 below. Preview is a shared rehearsal environment, so
  the disclosure is about not poisoning the next rehearsal, not about permission.

Your block must cover, at minimum:

1. **What you were doing and why** — the task as you understood it, and who or
   what asked for it.
2. **What you actually DID** — commits with SHAs, branch names, PR numbers and
   their current states. Not intentions; actions.
3. **Anything applied to the protected shared preview project** — **migrations AND
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

## (B) Ending a structural session — the two-halves handover

The end of a `popcre/shared-db` structural session. A session that claimed exact
objects and explicitly delegated work must leave enough state for the next session
to resume or retire **each agent individually**. The authoring session remains
responsible for its claim, safety decisions, and verified closeout.

> **This skill does not replace `handoff-writer`.** Follow that skill's file
> convention (one write-once file at
> `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, never a rewrite of the shared
> root `HANDOFF.md`, never another session's file), its 9 required sections
> including the mandatory "what we tried that did NOT work", and its
> fresh-developer self-audit gate. This skill adds what shared-db needs on top.

## The handoff has TWO halves — and a REQUIRED outstanding-work note

A structural handoff that omits half (b) is **incomplete**, no matter how long
it is. **A handoff that leaves outstanding work with no note on the existing
issue is equally incomplete**, and carries exactly the same weight —
see "Keep unfinished work on its existing issue" below. *(Corrected 2026-08-09: this named the `REQUEST
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

## Keep unfinished work on its existing issue

Before closeout, verify that every outstanding action is recorded on the existing
issue for that application need, with its current owner, blocker, exact next step,
and live-proof checklist where acceptance remains incomplete. Do not create a
duplicate structural request, a per-phase ticket, or a leftover-proof ticket. If a
truly new application need has no issue, create one issue for that need and use
`route: claim-first`; this is not a reason to split its implementation, handover,
or live proof across tickets. Re-derive current state from the repository and the
issue rather than relying on historical backlog documents or retired intake files.

## Ingesting a handover note

Other sessions leave a handover note on the existing `db-work` issue (path A
above). ⚠️ They used to append to `COORDINATOR_INTAKE.md`; that file was
**RETIRED** on 2026-08-07 and is now a pointer. When you ingest one: **verify every
claim against the live repo rather than trusting it** — `git fetch --all`, `gh pr list`, `git worktree list`,
and the real current maximum migration version in `supabase/migrations/`.
Documents in this repo have gone stale within the hour, and multiple agents have
caught real errors exactly this way.

After you have taken up the work, **comment on the same issue** with the date and
what you took up. The issue history is the audit trail of who touched what.
*(Corrected 2026-08-09: this said "move the ingested block to the file's TAKEN
OVER section", which was the retired `COORDINATOR_INTAKE.md` workflow.)*

## The sweep — do this BEFORE you write the handover, not after

The handover describes the state you leave behind, so tidy the state first.
Three passes, and then a fourth that is just honesty:

1. **Update the existing issue you handled.** Add a dated, signed comment with
   what happened; close it only after its outcome and live acceptance are verified.
   Never delete an issue or create a second ticket for a handover or proof gap.
2. **Verify each finished branch is actually merged, then retire its worktree.**
   For each agent you are calling finished: confirm the PR is merged
   (`gh pr view`), confirm the commits are in `origin/main`, and only then retire
   the worktree.

   ⚠️ **`git branch --merged` CANNOT see a squash-merged branch.** `main` is
   squash-merged, which rewrites the commit. Measured 2026-08-13: **74 of 130
   branches looked unmerged to git while their pull request was merged.** Every
   cleanup keyed on git ancestry therefore reports live work and cleans nothing —
   which is exactly why 29 worktrees and 130 branches accumulated. **Ask GitHub
   whether the PULL REQUEST merged.** Use the current `shared-db` worktree-recovery
   procedure and its ownership, clean-custody, and recoverability proofs.
   `popcre/shared-db/scripts/reap-merged-worktrees.mjs` identifies merged-PR candidates (dry-run
   by default); apply cleanup only after the current `cleanup-worktree` checks
   prove ownership, clean custody and recoverability. It has no marker predicate
   and does not authorize removal by itself. Preserve dirty or unproven bytes and
   resolve the exact ownership refusal before any cleanup.

   Remote branches now delete themselves — `delete-branch-on-merge` was turned on
   for `popcre/shared-db` on 2026-08-13.

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
2b. **Verify every outstanding item remains on its existing work issue.** This
   is not optional tidying: a handover that leaves outstanding work only in a
   handoff file is incomplete. Do not open or refresh a second `db-work` issue for
   the same application need, implementation phase, handover, or live-proof gap.
   A genuinely new need without an issue gets one claim-first issue, as described
   above.

3. **Flag anything you deliberately left.** A worktree you chose not to touch, a
   branch you left alive, a request you left unstarted — each gets one
   line saying it was a decision, not an oversight. Unexplained leftovers get
   treated as abandoned by the next session and deleted.

**The deletion rules — narrow on purpose:**

- **A local branch label is deleted only when it is fully merged into
  `origin/main` AND checked out in no worktree.** Both conditions, verified, not
  assumed.
- **Remote branches are deleted by the merge itself, never by hand.**
- **A worktree is NEVER removed if it is dirty, locked, or held by a live
  process.** Uncommitted work in a worktree is the only copy of that work. Verify
  its claim owner, exact source, and recovery custody before acting; age or a stale
  marker never proves that unique bytes are disposable.

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

## Fast close — nothing unfinished: no PR, under 5 minutes (#498)

Marker #3004's closeout on 2026-09-16 took **47 minutes and four refused guarded
merges** for one handoff file whose required checks were all green 80 seconds
after it opened. Every refusal was self-inflicted. Use this route instead.

**1. No unfinished work → no handoff file and no pull request.** When the sweep
shows no open work issue you own, no live sub-agent or claim, no open PR of
yours, and no dirty worktree, do NOT write a `HANDOFF.d/` file (a handoff is only
for unfinished work — `handoff-writer`'s own rule). Instead:

- Post the closeout record as **one comment on the existing work issue**: `main` tip
  SHA and time checked, maximum migration version, each open PR you touched with
  its state, the secrets-sweep result, the docs-pass result, and "no follow-up".
- Create or close no marker. Close the existing work issue only after its actual
  delivery and live-acceptance gates pass. Secrets sweep and docs pass report a result,
  but "n/a — no credential appeared; no durable fact changed" is a complete
  result when true; do not open files to look busy.

**2. Unfinished work → one prose-only PR, merged through the normal route.** Keep
the PR to handoff and documentation files only; do not include code, tests,
scripts, workflows, or configuration. The stop instruction freezes implementation
work, while this docs-only PR is the closeout deliverable. Under the shared-db
`AGENTS.md`, prose-only PRs do not wait for CI: merge promptly through the normal
repository path, using the merge queue where configured. Never use `--admin` or
another bypass.
Do not merge the unfinished implementation PR. If any non-prose file is included,
the docs-only exception does not apply; follow the full required review and bounded
PR-wait route for that change. Record the handoff PR on the same existing work
issue. Open no marker or leftover-proof issue.

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
   says never leave an open PR behind. Merge it through the normal repository path
   in "Fast close" above, including the merge queue where configured; with nothing
   unfinished there is no PR at all.

   This split exists because the old blanket "never merge on the way out" is what
   stranded the **2026-08-05** handover in open PR #451. The next session read
   `main`, saw a five-day-old handover, and concluded the session had been lost.
   Nothing was lost; it was parked by the rule. A handover nobody can find is not
   a handover.
5b. **Do not create, resolve, or close markers.** The claim-first route has no
   marker. A historical marker is neither a lock nor a cleanup blocker; leave it
   untouched. Merges follow the normal repository path, with protected stage
   leases enforced by the shared-db tools.
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
7. **Confirm the sweep above was actually run** — every
   "finished" branch confirmed merged and its worktree retired, and everything
   you deliberately left behind flagged as a decision. This is a checklist item,
   not a nicety: an unswept repo is how the next session inherits phantom
   worktrees and branches nobody dares delete.
8. **Confirm outstanding work is on its existing application issue.** Verify
   actions against the issue, including any older agenda or backlog note. **Do not
   create a ticket per backlog item**; create one claim-first issue only for a
   distinct new application need that has no issue. Historical queues and handoff
   prose are not current issue state.
9. **Pass the gate:** could a developer who walked in off the street this morning
   continue with NO questions, as effectively as you can right now? If not,
   expand and re-grade.
10. **End with the next-session prompt — REQUIRED, and a closeout without it is
    INCOMPLETE.** The very last thing in the closing reply to Albert is a fenced,
    copy-paste prompt he can drop into a fresh session. It must be
    self-contained: a session with no chat context must be able to continue from
    it alone. It states the repository, the successor's claim-first responsibility
    and actual session identity, the path of the `HANDOFF.d/` file and the PR that
    carries it (and whether that PR is merged), the ordered next actions with
    issue and PR numbers, what must not be touched, and any standing owner
    instruction still in force. If the handover PR could not be merged, the
    prompt's first action is to resume its normal docs-only merge path. If nothing
    is outstanding, say
    "No follow-up prompt — this workstream is closed" instead of inventing one.
    *(Added 2026-09-11: this skill tells sessions not to run `wrap-up`, which is
    where the prompt requirement lived, so marker #2689's closeout ended with no
    prompt and Albert had to ask for one.)*

## This skill is the WHOLE closeout — do not send Albert to a second skill

**`shared-db-handover` is all-encompassing for a shared-db session.** When it is
done, every loose end is tied: swept, documented, committed, pushed, merged, and
ownership verified through native release, handoff-ready consent or succession.

**Do NOT run `wrap-up` after this skill.** They overlap, and `wrap-up`'s ship step
is already owned here — steps 5 and 5b merge the docs-only handover PR and finish
claim-first ownership verification. Running it afterwards duplicates work and invites a second, competing
handover document.

`wrap-up`'s next-session prompt is NOT dropped by this rule: step 10 above
requires it, and the closing reply is unfinished without it.

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
  `popcre/shared-db` with the `db-work` label are the queue**, and the nine
  things a handover issue must say are listed in path (A) of this skill. Corrected
  2026-08-09.
- `AGENTS.md` at the root of `popcre/shared-db` — **the live rulebook, and it
  WINS over this skill wherever the two disagree.** This file is a portable
  summary; §12 "Standing facts an incoming session must know" is the canonical
  version of the safety rules restated here.
- `shared-db-orchestrator` — optional historical safety reference. Current
  structural work is claim-first; do not route requests to an orchestrator, wait
  for dispatch, create a marker, or use a marker as a lock.
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
