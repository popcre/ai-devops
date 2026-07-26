---
name: entra-role-hub
description: "Entra ID is the cross-app role hub (Model B); Directus is the single writer, CRM/DAM are read-only consumers"
metadata: 
  node_type: memory
  type: project
  originSessionId: eb6e9caa-273d-4c51-8a14-15d06a231809
---

POP Creations centralizes user roles in **Microsoft Entra ID security groups** so a person's role is defined once and read by every app (PM, CRM, DAM). Decided 2026-06-10.

**Model B (single writer):** roles are edited in **Directus** (the PM app, https://data.designflow.app); Directus mirrors them **outbound to Entra** hourly. Other apps (CRM = forked Twenty; DAM = popdam) are **read-only consumers** of the Entra groups. Only promote a second app to writer deliberately — multi-writer sync loops are the failure mode Albert explicitly wanted avoided.

- Six Entra security groups named `POP PIM · <Role>` (Administrator/Sales/Licensing/Designer/Viewer/Vendor) mirror the six Directus roles.
- Write credential = a dedicated Entra app **`POP PIM — Graph Role Sync`** (appId `a645fc70-fea9-4703-871c-900b97f898d7`, perms `GroupMember.ReadWrite.All` + `User.Read.All`). Secret lives ONLY in `/home/ai/.directus-deploy.env` (mode 600), never in the repo or the public Directus container.
- Sync = `pm-system/sync/entra-role-sync.mjs` in the directus repo, dry-run by default (`SYNC_APPLY=1` to write), run hourly by host systemd timer `directus-entra-sync.timer`.
- This **superseded** the earlier "pull roles from Designflow PLM" idea.

Full detail in the directus repo `AGENTS.md` §11 ("Entra is the role hub"). Tenant `1caeb1c0-a087-4cb9-b046-a5e22404f971`. See [[platform-decision-directus]].
