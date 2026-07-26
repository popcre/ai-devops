---
name: directus-access-model
description: "Directus 11 access model — app roles use policies; non-admin users currently get a shared \"All Access (temp)\" policy granting full data access until gating is added."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3e4ef769-b9b9-4773-a58f-e7a497115a75
---

Directus 11.17 uses **policies**, not direct role permissions. Each role links to one or more policies; permissions belong to policies. The **Public** policy (`role: null` on permission rows) only applies to *unauthenticated* requests — logged-in users do NOT inherit it. So a role with an app policy that has zero permission rows = its users see nothing (this was the original Jessica/Designer bug, fixed 2026-06-16).

Current app roles (data.designflow.app): Administrator (admin_access), plus non-admin app roles **Designer, Vendor, Sales, Licensing, Viewer**. Admin users: svc@popcre.com, albert@popcre.com. Jessica Cortazar (jcortazar@popcre.com) and Adam Dweck (adweck@popcre.com) are Designers.

**"All Access (temp)" policy** (id `54009e87-44e1-416f-8f5b-cfdc324eb701`) is attached to all 5 non-admin roles. It grants full CRUD on all 37 business collections + directus_files (CRUD), directus_users/roles (read), presets/comments/notifications/shares (CRUD). 178 permission rows. This is intentional blanket access during setup — gating comes later.

**Why:** User decision (2026-06-16): "let all users see all data. we can institute gating later on when the system is up and running." All users are trusted popcre.com internal staff. Delete is included (accidental-data-loss risk flagged, user accepted blanket access for now).

**How to apply:** To unwind for gating later, detach/delete this single policy and build per-role policies. To inspect/modify, log in as svc@popcre.com (password in Coolify service `directus` env `DX_ADMIN_PASSWORD`, also in [[product-image-storage]]'s deploy env file) and use the `/policies`, `/permissions`, `/access` REST endpoints. Note: querying `directus_permissions.role`/`directus_roles.admin_access` fails for non-root token contexts — use the policy-based endpoints. Related: [[platform-decision-directus]], [[entra-role-hub]].
