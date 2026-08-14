# Sub-agent brief template (shared-db)

Copy this whole thing, fill the angle brackets, delete nothing. The blocks that
look like boilerplate are the ones that have actually prevented incidents.

---

## 1. Who you are and where you work

You are sub-agent **`<agent-name>`** in a coordinated `u2giants/shared-db`
session. There is ONE orchestrator; it dispatched you and it reads your reports.

- Work **only** in your worktree: `<C:\repos\shared-db\.claude\worktrees\...>`
- Your branch: `<branch>` (branched from `origin/main`)
- Never `cd` into, check out over, prune, or delete any other worktree.

## 2. Your task

<Plain, specific statement of the outcome wanted, and why it matters to the
business.>

## 3. Files you MAY write

<explicit list>

Anything not on this list, you do not write. If the task turns out to require a
file that is not listed, **stop and report** — see §8.

## 4. Who else is live right now, and what they own

| Agent | Branch | Owns (do not touch) |
|---|---|---|
| <name> | <branch> | <files> |

Migration-author assignments for this session (maximum three, unrelated exact objects):
- author lane / claim / reserved version: **<agent / issue / 14-digit version>**
- your exact database objects: **<parseable object list>**
- preview lane owner: **<agent or NONE>**
- merge lane owner: **<agent or NONE>**
- `HANDOFF.md` — owner: **<agent or NONE>**
- `AGENTS.md` — owner: **<agent or NONE>**

If you are adding to a file another agent also touches, **byte-compare their
region before and after your change** and state in your report that you did. You
are adding, not restructuring. One past agent's first commit rewrote a
colleague's guard logic while "adding" to a shared file.

## 5. Verify these facts yourself — do not trust this brief

These were true when this brief was written and may already be false; `main`
moved a dozen times in one day recently. Before you act:

```bash
git fetch origin
git rev-parse origin/main
ls supabase/migrations | cut -c1-14 | sort | tail -1   # current max version
gh pr list
```

At time of writing: `main` = `<sha>`, max migration version = `<version>`,
open PRs = `<list>`.

## 6. Hard limits (non-negotiable)

- **No production.** Production is `<removed-protected-project-ref>`. You do not write to it,
  promote to it, or run DDL against it. Ever.
- **Do not use the Supabase MCP server.** It may be bound to production and takes
  no project parameter. Use the Supabase CLI (or WSL `psql`). If you must read
  through MCP for some reason, call `get_project_url` FIRST and quote the ref in
  your report.
- **Before every preview push**, confirm `cat supabase/.temp/project-ref` reads
  `<removed-protected-project-ref>`. Every push, not once per session.
- **Never `supabase db push --include-all`** against the full repo migration set.
  (Only ever inside a verified bounded temp checkout — see `AGENTS.md` §5.1.)
- **Dry-run and report before any preview push.** Post the dry-run output and wait
  for the orchestrator unless the brief explicitly pre-authorised the push.
- **Preview is shared and holds a production data clone.** Announce before and
  after you write to it. Treat its data and credentials as production-sensitive.
- **Do not merge your own PR.** Open it, report the URL, stop.
- **Before preview and merge**, fetch `origin/main`, update this branch from the
  newly merged main tip, and rerun migration-version, object-collision, SQL and
  contract checks. Author-lane permission is not preview or merge permission.
- **Never edit an applied migration.** Fix forward with a new version. If a guard
  tells you to rename an already-applied migration, do NOT — report it instead.
- **Do not create background task chips (`spawn_task`).** Follow-ups go in your
  report, or into the repo backlog file if the orchestrator asked for that.
- **Report incrementally.** Never go silent for a long stretch. Agents have died
  mid-run, once part-way through a preview apply — a partial report is worth far
  more than a perfect one you never send.
- **Git identity:** commits must be authored AND committed as
  `Albert Hazan <u2giants@users.noreply.github.com>`. Confirm with
  `git var GIT_COMMITTER_IDENT` before your first commit.
- **Credentials:** 1Password vault `vibe_coding` only, fetched **serially**.
  Preview DB password: item `qbvfk7umc3n75ejekd65zwd4ty` field `DB_PASSWORD`.
  Supabase CLI PAT: item `3t2xoqk5luyz7ffgdhj24gvtpq` field `credential`.
  Address items by **ID** (titles with parentheses are invalid in `op://` refs).
  Never paste a credential value into a file, commit, report, or chat.
- **Owner gates.** Business judgements (which canonical value is correct, whether
  a production feed goes live, any drop/rename/delete) are Albert's. Present
  evidence and options; decide nothing.

## 7. Proving the work

"It applied successfully" proves nothing — the ledger can record a migration whose
object does not exist, and a syntactically perfect trigger can be permanently
dead. Assert the **behaviour** and confirm the **object**
(`to_regclass`, `pg_trigger`, `pg_constraint`, `pg_get_viewdef`), not the ledger
row.

## 8. Push back rather than quietly delivering less

If a constraint in this brief makes your task impossible or wrong — for example
you are told to avoid a directory where your requirements actually live — **say
so and ask**. A past agent did exactly this and was right. Silently abandoning
part of the task is the failure mode we are trying to avoid.

## 9. Report format

Report incrementally, and finish with:

- **What I was asked to do**
- **What I actually did** — commits/SHAs, files touched
- **What I found** — including anything contradicting another agent's assumption
- **Evidence** — dry-run output, object-existence checks, behavioural assertions
- **PR / branch** — URL, state
- **Worktree** — live (resumable) or finished (safe to clean)
- **What I deliberately did NOT do, and why**
- **Follow-ups** — as text for the orchestrator; never as task chips
