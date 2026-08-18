# Incident ledger — why each shared-db orchestration rule exists

Read this when a rule seems to be getting in the way, or when you need to explain
one to Albert or to another agent. Every rule below was written after something
broke or nearly broke.

## 1. Background task chips fan out uncontrolled work (2026-07-31)

After a review, **five follow-up task chips** were created. **Four** of them each
authored a forward migration doing `CREATE OR REPLACE` on the SAME function
`plm.promote_coldlion_source_owned`; **three** picked the identical version
`20260731170000`.

- `CREATE OR REPLACE` carries the entire function body. It is last-writer-wins, so
  merging any two of those PRs **silently erases** the others' fixes — no conflict,
  no error, no test failure.
- Each PR passed CI **alone**, because the duplicate-version guard only ever sees
  one branch. CI structurally cannot catch this.

**Rule:** never spawn chips for shared-db work. Follow-ups go into a repo backlog
file, inert until a orchestrator dispatches them with a fresh brief. If a chip is
unavoidable, title it `DO NOT START — …`.

## 2. Duplicate migration versions silently skip a migration (2026-07-22, 2026-07-28)

Supabase's ledger (`supabase_migrations.schema_migrations`) keys on the 14-digit
**version alone**, not the filename. Whichever file applies first claims the
version; the other is treated as already-applied and **never runs**, while the
ledger reports success.

- `20260722220000` — used by both the PopSG trigram-index migration and the
  Sample Tracking `restore_dflow_sample_shipment_item` migration. Production
  recorded the PopSG one and skipped the table restore, so
  `dflow.sample_shipment_item` never existed in production and every dependent
  feature was unbuildable — while the ledger claimed success.
- `20260728160000` — used by both `clickup_incremental_task_import` and
  `popdam_user_tables_foreign_keys`. Second-order effect: every future
  `supabase db push` aborted with
  `duplicate key value violates unique constraint "schema_migrations_pkey"`.

Guards now live in `scripts/check-sql.sh`: **Guard A** rejects duplicate versions,
**Guard B** rejects backdating. Manual check: `ls supabase/migrations | cut -c1-14
| sort | uniq -d` must print nothing.

## 3. Guard B's rename advice is wrong for an ALREADY-APPLIED migration

Guard B suggests re-timestamping a backdated migration. That is correct **only**
while the file has not been applied anywhere. If it is already applied, renaming
re-applies the DDL under a new version and **orphans the old ledger row** — the
CLI then reports remote versions with no local file and suggests
`supabase migration repair --status reverted`, which must not be run.

**Rule:** keep the applied version; land a corrective **forward** migration on top.

## 4. Editing an applied migration cannot work

The ledger already records that version, so the CLI will never re-run the file.
The edit changes nothing in the database and desynchronises file from ledger — you
now have a file that no longer describes what is deployed. Every fix is forward.

## 5. A red CI check can be a stale verdict (PR #328 / PR #307, documented by PR #336)

A guard may scan files that its workflow's `paths:` filter does not watch. PR #328
fixed the offending line, triggered **no re-run at all**, and kept its red X.
Unrelated PR #307 is what actually turned `main` green.

**Rule:** open the run and check which **SHA** it executed against. Never read the
X alone. Now `AGENTS.md` §5.2.

## 6. The Supabase MCP may be bound to PRODUCTION and takes no project parameter

Every `execute_sql` / `list_migrations` call hits whatever the server is bound to,
regardless of intent. An agent nearly reported **production** data as preview data.

**Rule:** call `get_project_url` first and quote the ref. For preview work use the
Supabase CLI / WSL `psql`, and verify `cat supabase/.temp/project-ref` reads
`<removed-protected-project-ref>` before **every** push.

Related facts: preview is a Supabase **branch**, so it does not appear in
`supabase projects list`; the preview pooler host is **`aws-0-us-east-1`**, not the
`aws-1-…` documented for production.

## 7. Preview is a shared mutable resource holding a production data clone

It is rarely a clean baseline — another workstream's unmerged rehearsal is often
sitting on it, which can block everyone's dry-runs (seen 2026-07-27: 17 PopPIM
migrations blocked all preview dry-runs until PR #271 landed).

**Rule:** announce in the register before and after writing to preview; treat its
data and credentials as production-sensitive; never run
`supabase migration repair --status reverted` to clear someone else's rows.

## 8. Rehearsal catches what tests cannot

A two-cycle preview rehearsal found **five** faults that every automated test had
missed, including:

- a collision rule that would have quarantined **542 of 542 records — the entire
  feed** — while reporting itself healthy, because the approved mapping
  deliberately fans 542 source rows into 271 canonical rows;
- an alert path that never recorded, so the circuit breaker could never trip.

## 9. A migration that installs cleanly can still be dead

A `BEFORE` trigger read a `GENERATED ... STORED` column. Postgres populates those
**after** before-triggers run, so the value was always NULL, the guard never fired,
and no error was ever raised.

**Rule:** "it applied successfully" proves nothing. Assert the behaviour; confirm
the object exists (`to_regclass`, `pg_trigger`, `pg_get_viewdef`), not just the
ledger row.

## 10. Second-opinion models are useful but sometimes wrong

On one PR, **GLM 5.2** raised two "High" findings:

- The first was **factually wrong** — it guessed at how `app.has_role` resolves
  the caller. It reads the request JWT via `auth.uid()`, not `current_user`. The
  finding also contradicted GLM's own earlier conclusion in the same session.
- The second had the right mechanism but the **wrong impact**.

**Rule:** verify every finding against the actual code before acting on it or
blocking a merge on it. A split verdict goes to Albert with the evidence; it is
never merged through.

**Operational note:** GLM hangs and dies (~40 minutes, exit 255) on large
exploratory briefs. Give it a compact, self-contained brief with the code pasted
inline; retry once, tighter; then fall back to your own review rather than
stalling the session.

## 11. Sub-agents die mid-run

Several were lost to connection errors and 600-second stalls — one part-way
through applying a migration to preview, leaving an unknown state on a shared
resource.

**Rule:** require incremental reporting; forbid going silent. On resume, the first
instruction is **assess and report the current state**, never "continue from where
you left off."

## 12. Facts go stale within the hour

`origin/main` moved a dozen times in a single day. A brief written at 10:00 is
misleading by 10:40.

**Rule:** every brief instructs the agent to `git fetch` and re-verify the `main`
tip, the max migration version, and PR states **at the moment it acts** — never
from the brief.

## 13. Sub-agents must challenge a wrong constraint

One agent was told to avoid `tools/` while four of its requirements lived there.
It correctly pushed back instead of silently delivering less. Encourage this
explicitly in every brief.

## 14. "Adding" to a shared file can rewrite someone else's work

One agent's first commit restructured a colleague's guard logic while nominally
adding to a shared file, then self-corrected to a purely additive change.

**Rule:** byte-compare the other party's region before and after, and say in the
report that you did.

## 15. Owner gates

Business judgements are Albert's: which canonical Licensor/Property value is
correct, whether a production feed goes live, any drop/rename/delete, any
production promotion.

**"Fix the feed" is not approval.** He must name the exact project and the exact
action. Related standing rule: `--include-all` against the full repo migration set
promotes every pending migration, including work other teams have deliberately
kept off production (`AGENTS.md` §5.1).

## 16. Sequencing PRs that each add migrations

- Merge **one at a time**; for each subsequent PR, **re-derive** its change from
  the newly merged body instead of resolving a text conflict. `CREATE OR REPLACE`
  migrations carry full function bodies and are **not additive** — a three-way
  merge yields a plausible file that silently drops one side's fix.
- A PR whose migration version sorts **earlier** than another's must merge
  **first**, or Guard B strands it permanently.

## 17. The handover nobody could find (2026-08-05)

A orchestrator session was cut off mid-handover. The incoming orchestrator ran the
five-step sweep exactly as written and concluded the session had been lost.
Nothing had been lost. Five separate defects in the skills produced that verdict:

- **`shared-db-handover` §"never merge on the way out" stranded it.** The finished
  handover sat in open **PR #451** (docs-only, +1063/-0, all checks green), which
  the rule told the outgoing session to leave open. `AGENTS.md` §2 and §5 say the
  opposite. The rule now splits: work PRs are handed over, docs-only PRs merge
  before the session ends.
- **The sweep never checked open PRs at all**, so the PR was invisible.
- **The sweep pointed at root `HANDOFF.md`**, whose newest in-file section was
  **five days older** than the real handover in `HANDOFF.d/`.
- **"Take the newest `HANDOFF.d/` file" would have picked the OLDEST.** The
  directory mixes `2026-08-05T1827Z-…` and `20260731T231155Z-…`; a text sort puts
  the July file last. Parse the timestamp, never sort the filename.
- **Step 1's `git fetch --all --prune=false` is not valid git.** It exits with
  `option 'prune' takes no value`, so the sweep proceeded on stale refs while
  appearing to have fetched.

Two further rules came out of the review (Kimi K3, then Codex GPT-5.6, which
conceded the heavier design):

- **"`HANDOFF.md` wins" is deleted, in all four places it appeared** — both skills
  and twice in `COORDINATOR_INTAKE.md`. No document wins by name or date;
  re-derive from `git`/`gh`.
- **A committed register file was proposed and rejected.** Most of the register is
  derivable in seconds, so persisting it only manufactures another stale document;
  and branch protection would put a PR between every dispatch. Replaced by the
  orchestrator marker (issue-based, cross-machine, stop-and-ask) plus, for the
  non-derivable assignment state, a **dispatch comment on the `db-work` issue**.
  *(Corrected 2026-08-09: this said `IN PROGRESS` annotations, which lived in
  `COORDINATOR_INTAKE.md`, retired 2026-08-07.)*

## The owner-decision block became a rubber stamp (2026-08-18)

Sample Tracking Release A reached the production business-risk gate with every
machine-verifiable check green. The gate stopped and demanded an "owner decision":
a JSON block, in an exact schema, posted as an unedited GitHub comment
authenticated to Albert, listing the risk keys to be accepted.

Albert's objection, and it is correct:

> "I didn't decide anything, i just followed what you told me to do. i'm not
> posting anything on an issue and making believe that protects us."

He is not a programmer. He cannot evaluate the SQL a risk flag refers to. The
block was composed by the agent and handed to him to paste. What that produces is
not human oversight — it is a signature on something unread, plus an audit trail
asserting that oversight happened. **Manufactured assurance is worse than no gate,
because it is believed.**

It was also guarding the wrong thing. The classifier grepped raw SQL for bare
keywords, and on this batch reported *"existing production data may be lost or
permanently altered"* for a migration that only CREATES tables on a target holding
none of them. What it had actually matched:

- `ON UPDATE CASCADE` / `ON DELETE RESTRICT` — referential actions in a foreign
  key, not statements that touch data
- `DROP TRIGGER IF EXISTS x` immediately before recreating `x` — how every
  idempotent migration in this repo is written
- `BEFORE UPDATE ON` — a trigger timing clause
- `UPDATE` inside a function body — runtime behaviour, not the apply-time effect

So the ritual was collecting rubber stamps for false alarms. A gate that cries
wolf is not a cautious gate: it teaches everyone to wave the warning through, and
it spends the reader's attention so none is left when a real warning arrives.

**Rule:** never gate on a human judgement the human cannot actually make. If a
check cannot be evaluated by whoever is being asked, it is theatre — either make
the machine decide it, or make the machine refuse and escalate to an engineer.
Do not route it through a rubber stamp.

**What changed:** the owner-decision block no longer blocks (it is still verified
when supplied, and derived risks are recorded as `disclosedRisks`); the classifier
was narrowed to stop firing on the four false-positive shapes above.

**What still protects the lane, none of it removed:** exact-main pinning,
immutable independent review evidence, the byte-bound preview rehearsal proof,
bounded allowlists that refuse unrelated drift, exact production project proof
immediately before every write, single-writer locks, post-apply verification.

**What is genuinely given up:** there is no longer a human stop between a green
evidence chain and a production write. That is an accepted owner decision, not an
oversight, and it is written here so nobody later mistakes it for one.

## Two gate defects found the same day, both by independent review (2026-08-18)

Worth reading together, because they show what review is actually for.

**Commit identity is not content identity.** The gate proved a preview rehearsal
by comparing the run's commit SHA to the PR head. A generated-types commit landing
after the rehearsal — which this repo *requires*, since types are generated FROM
the repaired preview — permanently stranded the promotion, because an applied
version can never be re-rehearsed. Meanwhile, for non-atomic migrations, it
compared only the migration FILENAME, so a file edited on main after the rehearsal
passed. Fixed in #1157 by binding to migration BYTES plus provenance.

**Enumerating an execution closure by hand does not work.** The first fix accepted
a rehearsal from any commit of the PR. Independent review showed that admits a
complete forgery: `workflow_dispatch` runs the workflow as it exists at the
dispatched ref, so a commit carrying a doctored workflow can fabricate the whole
evidence bundle, and a follow-up commit restoring it leaves the reviewed diff
clean. Pinning the producing files was then found incomplete twice more — the lane
script that runs first, then a pinned script's unpinned import. **One unpinned
executed file breaks custody for every pinned one**, because executed code can
rewrite the workspace while the gate compares committed blobs. The list is now
WALKED, not written, and the walk asserts it reached the previously-missed hops.

**Rule:** a reviewer must not review its own design. The rotation assigned the
same model that had recommended the approach; a different reviewer was used
instead, and it found three Criticals in that design. Both roles were recorded.
