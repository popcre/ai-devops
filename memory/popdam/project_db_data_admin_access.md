---
name: project_db_data_admin_access
description: "How to grant a person access to the DB Data Admin app (data-dev / data.designflow.app) — two grants in the app schema, admin-only by design, dev runs on the PREVIEW Supabase project"
metadata: 
  node_type: memory
  type: project
  originSessionId: 29c7387f-a3f7-4fed-9ad3-dee7091a5aec
  modified: 2026-07-28T20:22:54.575Z
---

Verified 2026-07-28 against preview `rjyboqwcdzcocqgmsyel`.

DB Data Admin is a **separate app** from PopDAM/PopSG. Its code and docs live in
`/worksp/shared-db` (`docs/db-data-admin-*.md`, `DB_Data_Admin.md`), not in the
popdam repo. Dev = `https://data-dev.designflow.app` and runs against the
**preview** project `rjyboqwcdzcocqgmsyel`. Prod = `https://data.designflow.app`,
project `qsllyeztdwjgirsysgai` — as of 2026-07-28 it returns **503, no server
running**, so prod access cannot be granted yet.

**Granting a person access takes three steps, in this order:**

1. They must sign in ONCE at the dev URL with "Continue with Microsoft".
   `app.handle_new_auth_user` then creates `app.profile` + `app_access('crm')`.
   Nothing can be pre-seeded: `app.profile` needs `auth_user_id`, which only
   exists after first login. They will see "Data could not be loaded" — expected.
2. Insert `app.user_role` → role slug `administrator`.
3. Insert `app.app_access (profile_id, 'admin')`.

Both 2 and 3 are required: every `db_data_admin_*` RPC calls
`app.require_db_data_admin_access()`, which ANDs `app.has_role('administrator')`
with `app.has_explicit_app_access('admin')` — and `has_explicit_app_access` has
**no administrator short-circuit**. One grant alone gives HTTP 403
`db_data_admin: not authorized`. The trigger only auto-grants the administrator
role to `u2giants@gmail.com` / `albert@popcre.com`.

**There is no lower tier.** The app is administrator-only by design, and
`administrator` is the top role across the whole shared `app` schema, so it also
unlocks CRM/PLM reach. Confirm with Albert before granting. Everyone else at
popcre.com sits at `viewer`/`designer` with `crm` access only.

**Verify without impersonating** (Management API SQL, one statement batch):

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"<auth uid>","role":"authenticated"}';
select app.has_role('administrator'), app.has_explicit_app_access('admin');
```

Tell the user to sign out and back in — grants are read at login.

Holders as of 2026-07-28 (preview): `albert@popcre.com`,
`ai-tester@data-dev.designflow.app`, and `umeka@popcre.com` (granted this
session, Albert approved the full administrator role).

DB path: the `app` schema is not exposed via PostgREST and the `mcp__supabase__*`
tools are unauthorized here — use the Management API
`POST https://api.supabase.com/v1/projects/<ref>/database/query` with the
vibe_coding item "Supabase CLI Personal Access Token" field
`SUPABASE_ACCESS_TOKEN`. See [[project_popdam_permission_layers]],
[[project_secret_access_paths]], [[project_supabase_virginia_cutover]].
