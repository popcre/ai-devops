---
name: feedback_db_migration_protocol
description: "AI is the operator — write the SQL migration file and commit it first, then apply it directly. Never apply before committing."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8e087743-fbb3-492e-a8bc-202b9fb69f45
---

AI is the operator for this repo. The user is NOT a programmer and runs NOTHING manually —
now or in the future. AI does everything end-to-end: commit, push, apply migrations, deploy,
verify. Never hand the user a command to run.

**The SQL-to-prod rule (refined 2026-05-29):** Don't apply SQL directly to prod if the change
*can/should be reflected in code on github.com* (our source of truth) — those go through a
committed migration file first, then apply. If a change does NOT affect GitHub being the source
of truth (one-off operational state with no code representation), applying it directly is fine.
In practice schema/data migrations live as numbered files and are committed before applying;
applying a committed migration is documented, not drift.

**Why:** User explicitly said "I can't do anything. I'm not a programmer. You need to do
everything, now and in the future." Earlier: "I'm not running anything myself. Not now, not ever."

**How to apply:**
1. Write SQL as a numbered file in `packages/twenty-server/src/modules/pop-creations/migrations/`
2. Commit and push to `main`
3. Apply it immediately:
   ```bash
   docker exec -i twenty-postgres psql -U twenty -d twenty \
     < packages/twenty-server/src/modules/pop-creations/migrations/NNN_name.sql
   ```

The rule is: commit first, apply second. Never apply undocumented SQL — the migration file is the permanent record of what changed and why.
