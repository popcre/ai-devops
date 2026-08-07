---
name: shared-db-orchestrator
description: Open and run a session as ONE orchestrator that does no work itself and dispatches every task to isolated sub-agents in their own git worktrees — and, for everyone who is NOT the orchestrator, how to REQUEST database work instead of starting it. Load it for THREE situations, before doing anything else. (0) ANYONE who needs shared-database work done — "I need a database change", "can you add a column", "we need a new table / view / RPC / index", "how do I request database work", "submit a request to the orchestrator", "who do I ask for a schema change", "it's only a small change" — the answer is a GitHub issue filed on `u2giants/shared-db` with the `db-work` label, never work started on the spot. (1) ANY request to run work with more than one agent or session — "run this with subagents", "spin up agents", "use subagents", "run these in parallel", "coordinate", "orchestrate", "coordinate multiple sessions", "several workstreams", "who is working on what", "what is each agent doing". (2) ANY work on the shared Supabase database or the `u2giants/shared-db` repo, even when neither is named — "add a migration", "write a migration", "make a schema change", "change the database", "update the shared database", "add a column", "change RLS", "add a view / RPC / trigger / seed", "promote to production", "work in shared-db", "start a new shared-db session", "start a shared-db orchestrator session", "start a orchestrator session", "start an orchestrator session", "be the orchestrator", "start a coordinator session", "be the coordinator", "hand over to the coordinator", "I want to run a orchestrator session", "open a orchestrator session", or any cross-app data-contract change. NOTE: the role is called ORCHESTRATOR as of 2026-08-07; "COORDINATOR" is the older word for exactly the same role and still appears in older issues, in `HANDOFF.d/` records and in git history. BOTH words must load this skill. Also load it before creating background task chips for database work — the chip pattern is what broke this repo. To END, wrap up, or hand over such a session, use `shared-db-handover` instead. If in doubt whether the work needs coordination, it does; load this skill.
---

# shared-db-orchestrator

> ## The role is called ORCHESTRATOR. "Coordinator" is the OLD word for the same thing.
>
> Standardised on **orchestrator** on 2026-08-07 by the owner's instruction. Everything in
> `u2giants/shared-db` now says orchestrator: `AGENTS.md`, `HANDOFF.md`, the skills, the
> marker label.
>
> **"Coordinator" still appears in three places, and it means exactly this role:**
> 1. **Older GitHub issues and their titles**, including any open orchestrator marker.
> 2. **`HANDOFF.d/` files**, which are write-once records of past sessions and were
>    deliberately NOT rewritten — editing another session's handover falsifies the record.
> 3. **Git history and merged PR titles**, which cannot be changed.
>
> **If you were asked to "start a coordinator session", or to "hand over to the
> coordinator", that is THIS skill and this role.** Do not go looking for a separate
> coordinator skill; there has never been one.
>
> ⚠️ **The marker label was renamed** `coordinator-marker` → **`orchestrator-marker`** on
> 2026-08-07. The rename carried existing issues with it. If a `gh issue list --label
> coordinator-marker` returns empty, that is the rename, **not an empty board** — query
> `orchestrator-marker`.
>
> The three `shared-db-*` skills, and which is which:
>
> | Skill | When |
> |---|---|
> | **`shared-db-orchestrator`** (this one) | **OPENING and running** a session. You are in charge and you dispatch; you do no work yourself. Also the skill for anyone who needs database work and must request it. |
> | `shared-db-change` | **AUTHORING** a schema change — the migration discipline itself |
> | `shared-db-handover` | **ENDING or STOPPING** a session |

`u2giants/shared-db` is the canonical repo for ONE Supabase Postgres database
shared by four applications: **Poppim** (in development), and **PopCRM**,
**PopDAM** and **DesignFlow PLM** (live). There is no "just this app" here. A bad
change breaks all four at once, and the damage is usually discovered days later
by a user, not by a test.

The single biggest source of that damage is not bad SQL. It is **multiple AI
sessions working the repo at the same time without a orchestrator.** Every
incident recorded in this skill traces back to two agents that did not know the
other existed.

Hence the shape of every shared-db session:

> **ONE ORCHESTRATOR. ALL WORK IN SUB-AGENTS. NOTHING OUTSIDE IT.**

This skill EXTENDS, and does not replace, `shared-db-change` (how to author a
correct migration), `handoff-writer` (the 9-section handoff standard) and
`session-docs-update` (end-of-session docs). Read `C:\repos\shared-db\AGENTS.md`
for the repo's own rules — §4 anti-collision, §5 merge protocol, §5.1 bounded
production promotion, §5.2 stale CI verdicts.

## If you need database work done: REQUEST it, do not start it

This is the most common — and most commonly skipped — path in this repo. It
applies to every session and every person who is **not** the current orchestrator.

**Anyone who needs any of the following must file a request rather than act:**
a schema change, a migration, an RLS policy, a view, an RPC or function, a
trigger, an index, a seed or data fix, a promotion to production, or any change
to a data contract shared between Poppim, PopCRM, PopDAM or DesignFlow PLM.

**Where it goes: a GitHub issue on `u2giants/shared-db`.** Not a file, not a PR,
not a chip.

```bash
gh issue create --repo u2giants/shared-db --label db-work   --title "<the outcome you need, in plain words>"   --body-file <a file you wrote>
```

Add `--label needs-albert` if it needs an owner decision. Use `--body-file`, not a
heredoc: this is a PowerShell-first shop and heredoc recipes have silently failed here.

Say, in the body: the outcome needed and why (business terms, not a schema design —
state the problem and let the orchestrator choose the shape); which applications depend
on it; whether it is blocking and how urgently; any deadline; what you already know
about the current schema **and whether you read it live or in a document**; and
explicitly **what you have NOT done** — no branch, no migration file, no push to
preview or production, no `supabase` CLI, no Supabase MCP call, no psql, no chip.
That last one is mandatory: if you did any of them, this is a handover, not a request,
and the path is `shared-db-handover`.

> ⚠️ **CHANGED 2026-08-07.** This used to say "append a block to the `## REQUEST QUEUE`
> section of `COORDINATOR_INTAKE.md`". **That file is retired.** It became a hand-built
> issue tracker in Markdown that several sessions edited at once, grew from 0 to 89 blocks
> in eight days, never once shrank, and had a retention rule that never fired because the
> directory it archived to was never created. Its 63 open work items are now GitHub issues.
> **Do not append to that file. If you find instructions telling you to, they are stale.**

**"It's only a small change" is exactly the case that has caused damage here.**
Every incident in the ledger began as something small enough that filing a request
felt like bureaucracy: a one-line `CREATE OR REPLACE`, a column add, a quick
version bump. Small changes are the dangerous ones precisely because they are the
ones people feel entitled to make directly, and this database is shared by four
applications that will not find out until a user does. Size is not the test —
whether it touches the shared database is the test.

**If you are an AI session and a user asks you for database work:** do not start
it, do not "just check", do not open a migration file, and do not create a
background task chip. Open the issue, tell the user in
plain English that it is queued for the orchestrator and give them the issue
link, and stop. Being asked directly by a user is not an exemption — the
orchestrator exists precisely because four sessions were each asked directly.

## The orchestrator's job — and the work it must refuse

The orchestrator session **reads reports, decides, asks Albert, dispatches.** That
is all. It performs **no** implementation work of its own:

- no file edits, no commits, no pushes, no merges
- no database calls of any kind
- no long file reads it can delegate

**Five exceptions, and only these — the orchestrator's own bookkeeping.** They are
the coordination surface itself, not work on the database. Do them yourself; do
not dispatch an agent to record a dispatch.
1. Open, re-check and close its **orchestrator marker** issue (step 0).
2. **A dispatch comment on the issue** it is dispatching, at dispatch time, and
   queue seeding at handover.
3. **Merge a docs-only handover PR** it finds open, or its own (step 2b).
4. The **handoff files** it writes at the end (`HANDOFF.d/`).
5. Moving intake blocks to `TAKEN OVER`.

Anything touching `supabase/`, application code, or the database is dispatched —
no exceptions, however small.

The reason is not purity, it is arithmetic. The orchestrator's context window is
the only place where the full picture of who-is-doing-what exists. Every token it
spends reading a 700-line migration is a token it cannot spend keeping two agents
from colliding. When the orchestrator runs out of context, the session loses the
map, and the map is the whole value.

If a task is small enough that delegating "feels like overkill" — delegate it
anyway. The exception that ate a orchestrator's context is the normal failure
mode, not a hypothetical.

**What the orchestrator does do:** maintain the live register (below), write
sub-agent briefs, read reports, spot contradictions between agents, escalate
owner decisions to Albert in plain English, and write the handoff.

## Where incoming handovers arrive: `COORDINATOR_INTAKE.md`

Other AI sessions running in this repo are told to stop and hand their work to
you. They file it into **`COORDINATOR_INTAKE.md` at the root of
`C:\repos\shared-db`** — that file is the live intake queue and the single source
of truth for the handover template they fill in. Check it at the start of your
session and whenever Albert says he has stopped another session.

**Verify every claim in a filed block against the live repo before acting on it**
(`git fetch --all`, `gh pr list`, `git worktree list`, the real maximum migration
version). After dispatching the work, move the block to the file's "TAKEN OVER"
section with the date instead of deleting it. Details live in the
`shared-db-handover` skill.

## At session start — the hygiene sweep (do this before dispatching anything)

A orchestrator that starts by trusting a document starts wrong. **Every startup is
a recovery startup** — always assume the previous orchestrator may have died
mid-handover, because one did (2026-08-05). There is no separate emergency mode.
Run all eight steps, **in this order**, before the first brief goes out:

0. **Claim the orchestrator marker — before anything else.** One orchestrator, on
   one machine, at a time. The marker is a GitHub issue in `u2giants/shared-db`
   labelled `orchestrator-marker` — a tracked file cannot serve, because branch
   protection puts it behind a PR and the orchestrator does not commit.
   `gh issue list --label orchestrator-marker --state open`, then:
   - **A failed `gh` call is UNKNOWN, never "none open".** Empty output from an
     unauthenticated or erroring `gh` reads exactly like a clear board. Confirm
     the command succeeded before believing zero results.
   - **An open marker that is not yours: STOP, do not dispatch.** Show Albert its
     session id, machine and start time, and ask whether to close it. A dead
     orchestrator's marker stays open **on purpose**.
   - **None open:** open `ORCHESTRATOR ACTIVE — <session id> — <machine>` with the
     start time, **list again**, and proceed only if exactly one is open and yours.
   - **Re-check before EVERY dispatch**, not only at startup — a stopped
     orchestrator can resume hours later on stale context and dispatch against live
     work. Workers carry no lease and check nothing; this is the orchestrator's
     obligation alone. Close the marker at handover.
1. **Establish ground truth from the repo, never from a Markdown file.**
   `git fetch --all --no-prune` — **not** `--prune=false`, which is not valid git
   and fails with `option 'prune' takes no value`, leaving you on stale refs
   while looking like you fetched; and **not** bare `--prune`, which
   `COORDINATOR_INTAKE.md` §B2.3 forbids while agents may be live, and at step 1
   you do not yet know whether any are. Then read `origin/main`'s **real** tip SHA and the
   **real** maximum 14-digit version in `supabase/migrations/` (and check for
   duplicate prefixes while you are there). `HANDOFF.md`, the cutover plan and
   this skill are all capable of being hours out of date; the repo is not.
   Stamp both facts with the time you checked them and put them in the register.
2. **Find the CURRENT handover — it is in `HANDOFF.d/`, not at the top of
   `HANDOFF.md`.** Handovers are write-once dated files under `HANDOFF.d/`; root
   `HANDOFF.md` is long-form history and its newest in-file section can be days
   older than the real handover (on 2026-08-05 it was five days older).
   - **Parse the timestamp, never sort the filename** — `HANDOFF.d/` mixes two
     formats and a text sort picks the **July** file (ledger §17).
   - **Search open PR heads too**: the newest handover may not be on
     `origin/main` yet (step 2b).
   Then read `HANDOFF.md` for the **`## BACKLOG`** section (the `B<n>` items) and
   the standing detail the handover points at.

   > **"An empty issue list does not mean there
   > is no work. `HANDOFF.md` is the authoritative record of outstanding work;
   > the queues track only incoming requests and handovers."**

   **No document wins because it is newer, and none wins by name.** Documents are
   pointers. Where any two disagree — queue vs handover vs `HANDOFF.md` vs this
   skill — **re-derive the fact from `git`/`gh` and believe that.** Do not rank
   the documents by date and pick a winner; that is document-shopping.

   **Never report the project idle on the strength of the queues alone** — on
   2026-07-31 a orchestrator did exactly that while ~20 jobs sat in the backlog
   (ledger §12).
2b. **Check open pull requests — `gh pr list --state open`.** For each one: who
   opened it, is it a handover, is it parked deliberately? **A previous session's
   entire handover can be sitting in an open PR** (2026-08-05, PR #451 — ledger
   §17). A docs-only handover PR is **merged before the session that wrote it
   ends**; if you find one open, read it, then merge it (AGENTS.md §5 docs-only
   merges promptly, §2 never leave an open PR behind).
3. **Read the open issues** — `gh issue list --repo u2giants/shared-db --label db-work` — work people need
   done that nobody has started. Triage it: what is ready to dispatch, what needs
   an Albert decision first, what is already obsolete. Reconcile it against the
   `HANDOFF.md` backlog you just read: **any outstanding item missing from the
   queue is a defect in the previous handover** — seed the missing entries (short,
   pointing at `HANDOFF.md`, never duplicating its detail) before dispatching.
4. **Read the handover issues** — the same list, titles starting `HANDOVER:`. These
   are workstreams other sessions started and stopped. Verify every claim against the
   live repo before acting on it (`gh pr list`, `git worktree list`, the real migration
   maximum), then dispatch and comment on the issue. Close it when the work lands.
5. **Run the branch/worktree hygiene check.** `git worktree list` and
   `git branch -vv`: every worktree is either live (say whose and what for) or
   finished; every finished branch should be merged. **A DIRTY worktree belonging
   to a dead agent is EVIDENCE — read it before retiring anything.** It may hold
   the only copy of work no report ever mentioned. Do not delete anything at
   session start — record it, and act at handover time under the rules in
   `shared-db-handover`.
6. **Preview state starts as `UNKNOWN`, and only a sub-agent can resolve it.**
   Preview is a live mutable database; nothing in `git` can tell you what is
   sitting on it, and the orchestrator makes no database calls. Dispatch a
   read-only **preview observer** and record `UNKNOWN` in the register until its
   report lands. **Dispatch no preview writer while it reads `UNKNOWN`.**
7. **Release stale object claims.** `gh issue list --label db-claim --state open`.
   Every open claim blocks its objects for every future dispatch, so a claim left
   behind by a dead agent silently freezes part of the schema. For each one,
   check whether its work actually landed:
   - **Its PR merged** → close the claim, noting the PR.
   - **The agent is gone and nothing merged** → close it and put the work back in
     the queue. Do **not** leave it open "just in case"; an open claim is a lock,
     not a note.
   - **Genuinely still live** → leave it, and name it in the register.

   This is the counterpart to the dispatch gate below. The gate is only as good
   as the claim list is honest, and the failure mode is asymmetric: a claim
   wrongly left open costs a delay, while one wrongly closed costs a collision.
   When you cannot tell, treat it as live and say so.

### Delegate the big reads

Steps 2–4 span ~9,500 lines and reading them inline burns the exact resource this
model exists to protect. Keep steps 0, 1, 2b and 5 inline — they are cheap
commands, not reads — and dispatch **one read-only summarizer** for the documents,
**pinned to exact SHAs: `origin/main` AND the head of every open handover PR**
(pinning to `main` alone misses the one place the 2026-08-05 handover actually
was). It returns **line anchors** for every claim, the
outstanding work items, the owner-decision gates, and any **contradictions
flagged, not resolved**. Then **verify each flagged contradiction yourself against
the repo**: a summary is a document like any other, so "re-derive from `git`/`gh`"
applies to it too.

**Lifecycle and retention for the queues live in `COORDINATOR_INTAKE.md`** —
how long blocks stay, when they move between sections, and when they are aged
out. Follow that file rather than any threshold restated elsewhere; do not
restate its numbers in a brief, point the agent at the file.

## The live register — rebuild it, don't store it

Maintain and restate this after every dispatch and every report. When it goes
stale, agents collide.

**Most of it is derivable, so never persist it.** The tip SHA, migration maximum,
branches, worktrees and open PRs are all seconds away from `git`/`gh` — a
committed register file would only manufacture another stale document, which is
the disease this skill treats. **Rebuild the derivable rows at every startup.**

What is **not** derivable is the assignment: which agent owns which files, which
is alive, and who holds preview. Record that in the **`IN PROGRESS` annotations of
`COORDINATOR_INTAKE.md`** at dispatch time (§B2.1) — that is its durable home, and
the next handover PR carries those commits. A gitignored local scratch copy
(`.claude/orchestrator-register.local.md`) is fine as **crash convenience only**:
it is a cache, never authority, it does not survive a change of machine, and
session start always re-derives rather than trusting it.

```text
main tip SHA:            <sha>            (re-verified <time>)
max migration version:   <YYYYMMDDHHMMSS> (re-verified <time>)
preview state:           <not clean / what is sitting on it / who put it there>
OWNER of supabase/migrations/ : <agent or NONE>
OWNER of HANDOFF.md           : <agent or NONE>
OWNER of AGENTS.md            : <agent or NONE>

AGENT   BRANCH/WORKTREE   SCOPE (files it may write)   PR    STATUS
-----   ---------------   --------------------------   ---   ------
```

**Single-writer rules — state the owner in every brief:**
- Only **one** agent at a time may write to `supabase/migrations/`.
- Only **one** agent may own `HANDOFF.md`.
- Only **one** agent may own `AGENTS.md`.

Everything else is assigned by explicit file list. An agent with no named owner
for a file does not touch that file.

## NEVER spawn background task chips for shared-db work

This is the rule that exists because ignoring it nearly corrupted a production
function.

`spawn_task` chips launch **independent sessions outside the orchestrator's
control**. They do not see the register, do not know about each other, and start
whenever the user clicks them — possibly days later, against a `main` that has
moved.

**What happened:** after one review, five follow-up chips were created. **Four of
them each authored a forward migration doing `CREATE OR REPLACE` on the SAME
function `plm.promote_coldlion_source_owned`**, and three of those picked the
identical version `20260731170000`. `CREATE OR REPLACE` replaces the whole
function body — it is last-writer-wins, so merging any two of those PRs would
have **silently erased** the others' fixes. Each PR passed CI on its own, because
the duplicate-version guard only ever sees one branch at a time.

**Since then the repo added a required `Cross-PR object collision` check**
(`AGENTS.md` §6.7) which does catch this shape — so do not repeat the old line
that "CI cannot catch it" and do not distrust a guard that works. It is **not**
complete cover: `strict` is `false`, so a check can pass against a `main` that has
since moved (§5.2). Treat it as a second pair of eyes, not as the orchestrator.

**Do instead:** write follow-ups to a backlog file in the repo (e.g.
`docs/backlog/<topic>.md`). A backlog entry is inert until a orchestrator reads it
and dispatches it with a current brief. If a chip is genuinely unavoidable, title
it `DO NOT START — <what it is>` so a human click cannot start uncoordinated work.

## The migration rules that silently lie to you

Read `references/incident-ledger.md` for the full incidents. The four that must be
in the orchestrator's head at all times:

1. **Duplicate 14-digit versions silently skip a migration.** Supabase's ledger
   keys on the version ALONE, not the filename. Two files sharing a version means
   one is never applied while the ledger reports success. Happened twice —
   `20260722220000` and `20260728160000`. `scripts/check-sql.sh` now has Guard A
   (duplicates) and Guard B (backdating).
2. **Never blindly follow Guard B's rename advice for an ALREADY-APPLIED
   migration.** Renaming re-applies the DDL under a new version and orphans the
   old ledger row. Keep the applied version; land a corrective **forward**
   migration on top.
3. **Never edit an applied migration — and know why it cannot work.** The ledger
   already records that version, so the CLI will never re-run the file. Editing
   changes nothing in the database and desynchronises file from ledger. The fix is
   always forward.
4. **"It applied successfully" proves nothing.** A migration installed cleanly
   whose `BEFORE` trigger read a `GENERATED ... STORED` column — which Postgres
   populates *after* before-triggers — so the value was always NULL, the guard
   never fired, and no error was ever raised. Assert the **behaviour**, and verify
   the OBJECT exists (`to_regclass`, `pg_trigger`, `pg_get_viewdef`), never just
   the ledger row.

## A red CI check can be a stale verdict — check the SHA, not the X

A guard can scan files that its workflow's `paths:` filter does not watch. So a
correct fix pushes, triggers **no re-run**, and the old red X stays.

PR #328 fixed the offending line and fired no run at all; unrelated PR #307 is
what actually turned `main` green. Before you believe a red check, open the run
and confirm which SHA it ran against. Documented as `AGENTS.md` §5.2 (PR #336).

## "Applied" is not "rehearsed" — and four other traps that have already fired

These are recent, and they all share one shape: something that *looked* verified
was not.

1. **Applying a migration to preview does not re-validate behaviour.** A session
   celebrated a "14/14 rehearsal PASS" for a function that had since been
   replaced by **four** further `CREATE OR REPLACE` migrations — the rehearsal had
   validated a body four versions out of date, and the suite had meanwhile grown
   to 18 cases, of which 4 had never been executed at all. **Rule: when a
   migration replaces a function that a rehearsal previously validated, that
   rehearsal MUST be re-run, and a dated evidence artifact produced** naming the
   function, the migration versions in effect, the case count, and the result.
   "It applied cleanly" is a statement about the ledger, not about behaviour.
2. **Evidence artifacts must name every migration by exact 14-digit version.**
   Three of four correction migrations appeared nowhere in `HANDOFF.md` or the
   cutover plan. Anyone building a production promotion list from that plan would
   have silently shipped a partial fix. Every rehearsal note, handoff and cutover
   plan lists **each** migration version it depends on, in full.
3. **Verify a sub-agent's "done" against the artefact, not the report.** An agent
   reported content added that existed only in its uncommitted working tree.
   Asked to check the actual diff, it found **four items uncommitted and one never
   written at all**. **Rule: for anything consequential, require the diff or PR
   URL and open it yourself.** A report is a claim; a commit is a fact.
4. **Timezone: this database runs `America/New_York`.** An approval timestamp
   recorded at midnight UTC reads back through `::date` as the **previous day**,
   misdating an owner ruling in the audit trail. **Pin approval timestamps to
   midday UTC**, and assert the resulting date in **both** UTC and server-local
   time in the test.
5. **Null-permissive privilege guards silently admit the call.** A check shaped
   `if not ( … or auth.role() = 'service_role' ) then raise …` never fires when
   `auth.role()` is NULL — which is exactly what it is inside a migration. The
   guard reads as strict and behaves as open. **Assert authority explicitly**
   (require a non-null role and a positive match), and test the NULL case.

## Database access: prove the target before every call

**The Supabase MCP server may be bound to PRODUCTION and takes no project
parameter.** Every `execute_sql` / `list_migrations` call hits whatever it is
bound to, regardless of what you intended. An agent nearly reported production
data as preview data on this basis.

- **Always call `get_project_url` first** and read the ref out loud in the report.
  Production is `<removed-protected-project-ref>`; preview is `<removed-protected-project-ref>`.
- For preview work, do **not** use the MCP. Use the Supabase CLI (or WSL `psql`)
  and verify `cat supabase/.temp/project-ref` reads the **preview** ref before
  **every** push — not once at the start of the session.
- Preview is a **Supabase branch**, so it does **not** appear in
  `supabase projects list`. Its absence is not a problem to debug.
- Preview pooler host is **`aws-0-us-east-1`**, not the `aws-1-…` documented for
  production.

**Preview is a shared mutable resource holding a full production data clone.** It
is rarely a clean baseline — assume someone else's unmerged rehearsal is sitting
on it. Announce in the register **before and after** writing to it, and treat its
data and credentials as production-sensitive.

**Rehearsal catches what tests cannot.** A two-cycle preview rehearsal found five
faults every automated test had missed — including a rule that would have
quarantined all **542 records (the entire feed)** while reporting itself healthy,
and an alert path that never recorded, so the circuit breaker could never trip.
Budget for the rehearsal; it is not ceremony.

## Credentials — reference only, fetch serially, never paste

1Password vault **`vibe_coding`** only. Fetch **serially** — never fan out `op`
reads in parallel.

| What | How to address it |
|---|---|
| Preview DB password | item `qbvfk7umc3n75ejekd65zwd4ty`, field `DB_PASSWORD` |
| Supabase CLI PAT | item `3t2xoqk5luyz7ffgdhj24gvtpq`, field `credential` |

Use the **item ID**, not the title: the preview item's title contains parentheses,
which are invalid in an `op://` reference (`op read` fails with
`invalid character in secret reference: '('`). Item IDs can be re-keyed by
1Password mid-session — if an ID 404s, re-resolve by title with
`op item list --vault vibe_coding --format json`.

Never write a credential value into a file, doc, commit, report, or chat.

## Dispatching a sub-agent

### STOP — run the collision check BEFORE you hand out the work

**This is a gate, not advice. Run it every time, before dispatching anything
that writes to the database.**

```bash
node scripts/check-dispatch-collision.mjs \
  --task "<what the agent will do>" \
  --objects "<every object it will WRITE, comma-separated>"
```

⚠️ **`--allocate-version` was withdrawn on 2026-08-07 and now exits `2`.** It
never reserved anything: it read the versions already in use and printed a
suggestion, so two orchestrators running it in the same minute were handed the
same number — the duplicate-timestamp incident it claimed to prevent. Pick a
version manually; duplicates are already blocked at merge by the `SQL migration
guards` check.

| Exit | Meaning | What you do |
| --- | --- | --- |
| `0` | The check completed and found **no overlap in the object classes it can read**. This is evidence, **not clearance** — it is blind to `alter table`, `create table`, `create index`, `grant`, `comment on` and `create type`, and it prints exactly what it did and did not check | Read the CHECKED / NOT CHECKED lists, satisfy yourself about the unchecked classes, file the claim it prints, **then** dispatch |
| `1` | Collision | **Do not dispatch.** Wait for the other work to merge, fold this into it, or narrow the task |
| `2` | Could not determine | **Do not dispatch as a write task.** Fix the cause, or dispatch READ-ONLY |

Then, and only then, file the claim — the command is printed for you. ⚠️ **That
printed command is a bash heredoc and does not work in PowerShell** (run it in
Git Bash, or save the block and use `gh issue create --body-file <path>`); plan
step 5 replaces it with the tool acquiring the claim itself. **The
claim is what makes the NEXT dispatch safe.** Skipping it does not fail
anything today; it just quietly restores the old behaviour for whoever
dispatches next.

**If the task cannot declare the objects it will write, dispatch it READ-ONLY.**
"Rewrite the promotion function" is declarable. "Investigate why the sync is
slow" is not. A read-only task cannot collide, so this is a routing decision,
not a gap. Never guess at an object list to get past the gate — a wrong
declaration is worse than none, because it reads as safety.

**Close the claim** when the agent's PR merges or the work is abandoned. An
open claim blocks that object for everyone else.

**Why this exists, and why your context window is not a substitute.** On
2026-07-31 four independent sessions each authored `create or replace function
plm.promote_coldlion_source_owned`. `create or replace` is last-writer-wins, so
merging any two would have silently erased the other. At the moment each was
dispatched **none of them had a pull request**, so the merge-time cross-PR guard
had nothing to compare — and three of those four sessions were wasted no matter
which guard caught it afterwards. A orchestrator reasoning over task summaries
does not reliably notice that two differently-worded tasks touch one function;
comparing exact object names across everything in flight is string matching, and
a script does it the same way every time, including on the days there is no
orchestrator at all.

Every sub-agent then gets:

1. **Its own git worktree** under `.claude/worktrees/` — never the shared main
   checkout, which other sessions churn between turns.
2. **The migration version you allocated above**, stated in the brief. Do **not**
   let the agent choose its own from `now()` — two agents dispatched in the same
   minute choose the same number, and a duplicate version means one migration is
   **silently skipped** (`AGENTS.md` rule 5; this has happened twice).
3. **An explicit anti-collision brief** naming the other live agents and the
   files/branches they own. This is the human-readable companion to the gate
   above, not a replacement for it.
4. **The standard hard-limits block.**

Use `references/sub-agent-brief-template.md` verbatim as the starting point.

**Facts go stale within the hour.** `origin/main` moved a dozen times in a single
day. Never let an agent act on a fact copied from its brief: the brief must tell
it to `git fetch` and re-verify the `main` tip, the maximum migration version, and
PR states **at the moment it acts**.

**Sub-agents die mid-run.** Several have been lost to connection errors and 600s
stalls — one part-way through applying a migration to preview. So: require
**incremental reporting** and forbid going silent. On resume, the first
instruction is always **assess and report the current state before continuing** —
never "carry on from where you left off," because it may not know where that was.

**Sub-agents must challenge a wrong constraint, not silently abandon work.** One
agent correctly pushed back when told to avoid `tools/` while four of its
requirements lived there. Say so explicitly in the brief: if a constraint makes
the task impossible or wrong, report and ask — do not quietly deliver less.

**Never let an agent rewrite another session's code while "adding" to a shared
file.** One agent's first commit restructured a colleague's guard logic before
self-correcting to a purely additive change. Require the agent to
**byte-compare** the other party's region before and after, and to state in its
report that it did.

## Review and merge protocol

- Anything non-trivial gets an **independent model review** before merge
  (`codex-second-opinion`, `ask-glm`, `qwen-code`).
- Merge **only on APPROVE with zero Critical/High** findings, and only when the
  `AGENTS.md` §5 checklist passes.
- On a **split verdict, do not merge through.** Verify the finding against the
  actual code, then report to Albert.

**Second-opinion models are useful but wrong sometimes — verify their findings.**
On one PR, GLM 5.2 raised two "High" findings: the first was factually wrong (it
guessed at how `app.has_role` resolves the caller — it reads the request JWT via
`auth.uid()`, not `current_user`) and contradicted GLM's own earlier conclusion in
the same session; the second had the right mechanism but the wrong impact. Check
every finding against the code before acting on it or blocking on it.

Also: **GLM hangs and dies on large exploratory briefs** (~40 minutes, exit 255).
Give it a compact, self-contained brief with the code pasted inline. Retry once,
tighter. Then fall back to your own review rather than stalling the session.

## Sequencing several PRs that each add migrations

Merge **one at a time**, and for each subsequent PR **re-derive its change from
the newly merged body** rather than resolving a text conflict. `CREATE OR REPLACE`
migrations carry the full function body — they are **not additive**, so a
three-way merge produces a plausible file that silently drops one side's fix.

And: **a PR whose migration version sorts EARLIER than another's must merge
FIRST.** Otherwise Guard B (backdating) strands it permanently, and the only
remaining fix is a forward migration under a new version.

## Owner gates — stop and ask Albert

Business judgements belong to Albert, not to an agent. Agents present evidence and
options and decide **nothing**. Gates include:

- which canonical Licensor/Property value is correct
- whether to switch a production feed on
- any drop, rename, or data deletion
- any promotion to production

**"Fix the feed" is not approval.** Albert must name the exact project and the
exact action. Put the ask in plain business English — one or two sentences on what
changes, what could break, and what it costs to undo.

## Handing over — use the `shared-db-handover` skill

Ending, wrapping up, or handing over a shared-db session is a separate skill:
**`shared-db-handover`**. Load it when the session ends, and do not write the
handoff from memory here.

The one thing to know while the session is still running: the orchestrator handoff
has **two halves** — (a) coordination state and (b) **one clearly headed block per
sub-agent**. A handoff missing (b) is incomplete no matter how long it is. So keep
the register current and record, per agent, what it was asked to do, what it
actually did, what it found, and what it deliberately did NOT do — the handover
skill needs all of it.

## Reference files

- `references/sub-agent-brief-template.md` — copy this to dispatch an agent.
- `references/incident-ledger.md` — the incidents behind each rule, with dates.
  Read it when you need to explain *why* a rule exists, or when a rule seems to be
  getting in the way.

## Related skills

- `shared-db-handover` — ending / wrapping up / handing over the session, and the
  end-of-session sweep of queue blocks, branches and worktrees.
- `shared-db-change` — how to author a correct migration.
- `cleanup-worktree` — the safe procedure for retiring a worktree or branch.
  Never force-remove a worktree that is dirty, locked, or held by a live process.
- `handoff-writer`, `session-docs-update` — the general handoff and docs rituals.
