---
name: shared-db-orchestrator
description: Open and run a session as ONE coordinator that does no work itself and dispatches every task to isolated sub-agents in their own git worktrees — and, for everyone who is NOT the coordinator, how to REQUEST database work instead of starting it. Load it for THREE situations, before doing anything else. (0) ANYONE who needs shared-database work done — "I need a database change", "can you add a column", "we need a new table / view / RPC / index", "how do I request database work", "submit a request to the coordinator", "who do I ask for a schema change", "it's only a small change" — the answer is a request filed in the REQUEST QUEUE of `COORDINATOR_INTAKE.md`, never work started on the spot. (1) ANY request to run work with more than one agent or session — "run this with subagents", "spin up agents", "use subagents", "run these in parallel", "coordinate", "orchestrate", "coordinate multiple sessions", "several workstreams", "who is working on what", "what is each agent doing". (2) ANY work on the shared Supabase database or the `u2giants/shared-db` repo, even when neither is named — "add a migration", "write a migration", "make a schema change", "change the database", "update the shared database", "add a column", "change RLS", "add a view / RPC / trigger / seed", "promote to production", "work in shared-db", "start a new shared-db session", or any cross-app data-contract change. Also load it before creating background task chips for database work — the chip pattern is what broke this repo. To END, wrap up, or hand over such a session, use `shared-db-handover` instead. If in doubt whether the work needs coordination, it does; load this skill.
---

# shared-db-orchestrator

`u2giants/shared-db` is the canonical repo for ONE Supabase Postgres database
shared by four applications: **Poppim** (in development), and **PopCRM**,
**PopDAM** and **DesignFlow PLM** (live). There is no "just this app" here. A bad
change breaks all four at once, and the damage is usually discovered days later
by a user, not by a test.

The single biggest source of that damage is not bad SQL. It is **multiple AI
sessions working the repo at the same time without a coordinator.** Every
incident recorded in this skill traces back to two agents that did not know the
other existed.

Hence the shape of every shared-db session:

> **ONE COORDINATOR. ALL WORK IN SUB-AGENTS. NOTHING OUTSIDE IT.**

This skill EXTENDS, and does not replace, `shared-db-change` (how to author a
correct migration), `handoff-writer` (the 9-section handoff standard) and
`session-docs-update` (end-of-session docs). Read `C:\repos\shared-db\AGENTS.md`
for the repo's own rules — §4 anti-collision, §5 merge protocol, §5.1 bounded
production promotion, §5.2 stale CI verdicts.

## If you need database work done: REQUEST it, do not start it

This is the most common — and most commonly skipped — path in this repo. It
applies to every session and every person who is **not** the current coordinator.

**Anyone who needs any of the following must file a request rather than act:**
a schema change, a migration, an RLS policy, a view, an RPC or function, a
trigger, an index, a seed or data fix, a promotion to production, or any change
to a data contract shared between Poppim, PopCRM, PopDAM or DesignFlow PLM.

**Where it goes:** the **`## REQUEST QUEUE`** section of
**`COORDINATOR_INTAKE.md`** at the root of `u2giants/shared-db`. That file owns
the request template, the lifecycle, and the rules for landing it — **read it and
follow it verbatim. Do not copy a template from here; this skill deliberately
does not carry one, because the file changes and the file wins.**

Note the two queues in that one file, and use the right one:

- **REQUEST QUEUE** — "here is work that needs doing" (you have *not* started it).
- **INTAKE QUEUE** — "here is work I was already doing, take it over" (you *have*
  started it, and must stop). That path is `shared-db-handover` (A).

**"It's only a small change" is exactly the case that has caused damage here.**
Every incident in the ledger began as something small enough that filing a request
felt like bureaucracy: a one-line `CREATE OR REPLACE`, a column add, a quick
version bump. Small changes are the dangerous ones precisely because they are the
ones people feel entitled to make directly, and this database is shared by four
applications that will not find out until a user does. Size is not the test —
whether it touches the shared database is the test.

**If you are an AI session and a user asks you for database work:** do not start
it, do not "just check", do not open a migration file, and do not create a
background task chip. File the request in the REQUEST QUEUE, tell the user in
plain English that it has been queued for the coordinator and give them the PR
link, and stop. Being asked directly by a user is not an exemption — the
coordinator exists precisely because four sessions were each asked directly.

## The coordinator's job — and the work it must refuse

The coordinator session **reads reports, decides, asks Albert, dispatches.** That
is all. It performs **no** implementation work of its own:

- no file edits, no commits, no pushes, no merges
- no database calls of any kind
- no long file reads it can delegate

The reason is not purity, it is arithmetic. The coordinator's context window is
the only place where the full picture of who-is-doing-what exists. Every token it
spends reading a 700-line migration is a token it cannot spend keeping two agents
from colliding. When the coordinator runs out of context, the session loses the
map, and the map is the whole value.

If a task is small enough that delegating "feels like overkill" — delegate it
anyway. The exception that ate a coordinator's context is the normal failure
mode, not a hypothetical.

**What the coordinator does do:** maintain the live register (below), write
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

A coordinator that starts by trusting a document starts wrong. Run all four
steps, in order, before the first brief goes out:

1. **Establish ground truth from the repo, never from a Markdown file.**
   `git fetch --all --prune=false`, then read `origin/main`'s **real** tip SHA
   and the **real** maximum 14-digit version in `supabase/migrations/` (and check
   for duplicate prefixes while you are there). `HANDOFF.md`, the cutover plan and
   this skill are all capable of being hours out of date; the repo is not.
   Stamp both facts with the time you checked them and put them in the register.
2. **Read the `## REQUEST QUEUE`** in `COORDINATOR_INTAKE.md` — work people need
   done that nobody has started. Triage it: what is ready to dispatch, what needs
   an Albert decision first, what is already obsolete.
3. **Read the `## INTAKE` sections** of the same file — work other sessions
   started and handed over. Verify every claim against the live repo before
   acting on it (`gh pr list`, `git worktree list`, the real migration maximum),
   then dispatch and move the block on.
4. **Run the branch/worktree hygiene check.** `git worktree list` and
   `git branch -vv`: every worktree is either live (say whose and what for) or
   finished; every finished branch should be merged. Do not delete anything at
   session start — record it, and act at handover time under the rules in
   `shared-db-handover`.

**Lifecycle and retention for the queues live in `COORDINATOR_INTAKE.md`** —
how long blocks stay, when they move between sections, and when they are aged
out. Follow that file rather than any threshold restated elsewhere; do not
restate its numbers in a brief, point the agent at the file.

## The live register — keep this current in the coordinator's own message

Maintain and restate this after every dispatch and every report. When it goes
stale, agents collide.

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

`spawn_task` chips launch **independent sessions outside the coordinator's
control**. They do not see the register, do not know about each other, and start
whenever the user clicks them — possibly days later, against a `main` that has
moved.

**What happened:** after one review, five follow-up chips were created. **Four of
them each authored a forward migration doing `CREATE OR REPLACE` on the SAME
function `plm.promote_coldlion_source_owned`**, and three of those picked the
identical version `20260731170000`. `CREATE OR REPLACE` replaces the whole
function body — it is last-writer-wins, so merging any two of those PRs would
have **silently erased** the others' fixes. Each PR passed CI on its own, because
the duplicate-version guard only ever sees one branch at a time. CI cannot catch
this class of bug; only a coordinator can.

**Do instead:** write follow-ups to a backlog file in the repo (e.g.
`docs/backlog/<topic>.md`). A backlog entry is inert until a coordinator reads it
and dispatches it with a current brief. If a chip is genuinely unavoidable, title
it `DO NOT START — <what it is>` so a human click cannot start uncoordinated work.

## The migration rules that silently lie to you

Read `references/incident-ledger.md` for the full incidents. The four that must be
in the coordinator's head at all times:

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
  Production is `qsllyeztdwjgirsysgai`; preview is `rjyboqwcdzcocqgmsyel`.
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

Every sub-agent gets:

1. **Its own git worktree** under `.claude/worktrees/` — never the shared main
   checkout, which other sessions churn between turns.
2. **An explicit anti-collision brief** naming the other live agents and the
   files/branches they own.
3. **The standard hard-limits block.**

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

The one thing to know while the session is still running: the coordinator handoff
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
