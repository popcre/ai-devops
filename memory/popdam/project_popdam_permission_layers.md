---
name: project_popdam_permission_layers
description: PopDAM permissions have THREE axes across two schemas — public role + public app_access + the app-schema role system that gates core/api/dam; 18 of 35 popdam users have no app-schema role
metadata: 
  node_type: memory
  type: project
  originSessionId: 4725f056-9e52-4d86-9058-29ba2efd5051
  modified: 2026-07-27T02:34:16.149Z
---

Verified live against `qsllyeztdwjgirsysgai` on 2026-07-26 (Management API SQL).
Answering "what are PopDAM's permission systems?" from this repo's TypeScript
alone gives an **incomplete** picture — most of the third axis lives only in the
database.

**Axis 1 — privilege (`public.user_roles.role`, enum `public.app_role`):**
`admin | user`. Checked in the browser by `src/hooks/useIsAdmin.ts` and, in the
backend, by six edge functions (see [[project_popdam_admin_auth_consolidation]]).

**Axis 2 — tenancy (`public.app_access.app`, enum `public.app_name`):**
`popdam | styleguides`. Which app you may enter; enforced for sister apps by
`supabase/functions/verify-app-access/index.ts`.

**Axis 3 — the shared multi-app system in the `app` schema:** `app.profile` →
`app.user_role` → `app.role`, enum `app.app_role` =
`administrator, sales, licensing, designer, viewer, vendor`, plus
`app.app_access` with enum `app.app_name` = `dam, crm, pm, plm, admin`.
**This is what gates every `core.*`, `api.*` and `dam.*` object** — all 40
policies there are app-schema gated, e.g. `core.customer.shared_read` is
`app.has_any_role(ARRAY[...all six roles...])`.

**Why this matters in PopDAM specifically:** the browser hits those schemas
directly with the *user's* JWT — `src/pages/StylesPage.tsx` (many
`.schema("core")` / `.schema("api")` calls), `src/components/settings/
PackagingTypesTab.tsx`, `ApisTab.tsx`. Live counts:

| | count |
|---|---|
| users with `public.app_access('popdam')` | 35 |
| of those, with an active `app.user_role` (any role, `profile.status='active'`) | **17** |
| with none → `core.*`/`api.*` reads return empty/denied | **18** |

So a user can be fully provisioned in PopDAM and still see empty Styles data.
Provisioning in one schema does NOT provision the other. `designer`/`viewer`
tiers exist ONLY in the app schema — `public.app_role` has just `admin | user`.

**Gotcha:** `app` schema is not exposed through PostgREST (only `public`/`api`),
so read/write it via the Management API
`POST https://api.supabase.com/v1/projects/<ref>/database/query` with the vault's
"Supabase CLI Personal Access Token" (`SUPABASE_ACCESS_TOKEN` field). Any DDL
there is a shared-DB change → canonical `u2giants/shared-db`, never this repo.

**Open security gap (re-verified 2026-07-26, still unfixed):**
`public.style_tracker_rows` allows SELECT `using(true)`, INSERT
`with check(true)` and UPDATE `using(true) with check(true)` — **any
authenticated user can edit Master Data rows**; only DELETE requires
`has_role(auth.uid(),'admin')`.

Related: [[project_supabase_virginia_cutover]], [[project_secret_access_paths]],
[[project_service_role_key_mismatch]].
