---
name: popdam-two-permission-systems
description: "PopDAM has two parallel permission systems (public vs app schema); a user provisioned in only one fails the other's checks"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c2fb38ad-dde0-459e-9563-443c4d2c38e1
  modified: 2026-07-26T17:29:50.486Z
---

`dam.designflow.app` (PopDAM) enforces **two independent permission systems** on
the shared backend `qsllyeztdwjgirsysgai`. Provisioning a user in one does NOT
satisfy the other:

**1. PopDAM's own (public schema)** — gates the DAM app's own tables
(`assets`, `style_groups`, `style_tracker_rows`) and the UI.
- `public.user_roles.role` → `public.app_role` = **only `admin` | `user`**
- `public.app_access.app` → `public.app_name` = **only `popdam` | `styleguides`**
- Signup is **invitation-gated**: a `public.invitations` row (email, role, apps)
  must exist first, then the `handle_new_user` trigger auto-provisions
  `public.profiles`, `public.user_roles`, `public.app_access`, and `app.profile`.

**2. Shared multi-app (app schema)** — gates the shared `api.*` / `core.*` /
`dam.*` contracts (e.g. `api.dam_customer_list`, `dam.customer_ext` RLS).
- `app.user_role` → `app.role.slug` → `app.app_role` =
  `administrator, sales, licensing, designer, viewer, vendor`
- `app.app_access.app` → `app.app_name` = `dam, crm, pm, plm, admin`
- Keyed by `app.profile.id` (resolved from `auth.uid()` via
  `app.current_profile_id()`, which requires `app.profile.status='active'`).
- `app.has_app_access(x)` returns true for anyone with role `administrator`.

So **"designer"/"viewer" do not exist in PopDAM's own role enum** — those tiers
only exist in the app schema. A full role-tiered tester needs rows in both.

**Security gap found 2026-07-26:** `public.style_tracker_rows` UPDATE policy is
`USING(true) WITH CHECK(true)` — **any authenticated user can edit Master Data
rows**, including a "viewer". By contrast `assets`/`style_groups` correctly
require `has_role(auth.uid(),'admin')`. Not yet fixed.

Writing to the `app` schema is not possible via PostgREST (only `public`/`api`
are exposed) and the Supabase MCP is read-only — use the Management API
`POST https://api.supabase.com/v1/projects/<ref>/database/query` with the PAT.
See [[shared-db-apply-mechanics]].
