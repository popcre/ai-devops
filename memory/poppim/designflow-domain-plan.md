---
name: designflow-domain-plan
description: Permanent designflow.app URL scheme — pm/crm/dam are the human-facing frontend domains; data.designflow.app is the Directus backend API only
metadata: 
  node_type: memory
  type: project
  originSessionId: eb6e9caa-273d-4c51-8a14-15d06a231809
---

Permanent domain plan for the POP super-app (decided by Albert 2026-06-10):

- `pm.designflow.app` — PM frontend (`poppim-web`). **Always** the URL people use for project management.
- `crm.designflow.app` — CRM frontend (`popcmr-web`).
- `dam.designflow.app` — DAM frontend (`popdam-web`).
- `data.designflow.app` — the shared **Directus backend API only** (frontend→backend calls; Data Studio for admins). Humans don't use it day-to-day.

**Why:** one shared backend (one Postgres) serves all three apps; frontends hold no data. Never "retire" `pm` — it temporarily points at Directus only until `poppim-web` ships, then rebinds to the frontend container (Coolify sub-app `service_applications.id=16` holds the backend fqdn).

DNS: Cloudflare zone `designflow.app` (`921eb133…`); API token `CF_API_TOKEN` + `CF_ZONE_ID` in `/home/ai/.directus-deploy.env`. See [[platform-decision-directus]], [[entra-role-hub]].
