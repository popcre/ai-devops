---
name: platform-decision-directus
description: "The chosen platform for the PM/CRM/DAM super-app is Directus (not Plane, not Twenty), built solo + AI, Data-Studio-first"
metadata: 
  node_type: memory
  type: project
  originSessionId: eb6e9caa-273d-4c51-8a14-15d06a231809
---

After evaluating Plane, Twenty, OpenProject, NocoDB, Baserow, Teable, Huly, and Directus, the decision (2026-06-09) is to build a unified **PM + CRM + DAM "super-app" on self-hosted Directus** as the single shared backend (one source of truth). The user was **awarded the Directus Open Innovation Grant** (free, no caps, SSO + field-level policies; eligibility <$5M revenue & <50 employees — they have 9 employees).

**Why not the others:** Plane paywalls its data model in a closed-source Commercial Edition, has no field-level permissions, and no plugin system (would require forking + paying). Twenty (they run a production fork at crm.designflow.app) hits a hard wall: its frontend can't be customized without forking. Directus is the only option where all customization (UI, backend, views, field-level permissions) is no-fork, and it's the natural backbone for unifying PM+CRM+DAM.

**Who's building:** one **non-programmer + AI agents (Claude Max + Codex Pro)**. Optimize for fewest breakable moving parts / on-rails paths. **Never hand-roll auth/permissions/CRUD** — let Data Studio or Refine own it.

**Front-end:** **Data-Studio-first** (configure, don't code; it gives Kanban/Calendar/forms/field-level perms/views for free). A bespoke **single React app via Refine** is a Phase-2 polish layer, per role, only if Data Studio's UX isn't friendly enough for sales/designers. NOT reusing PopDAM's React UI; only the Directus backend is shared. No AgencyOS.

**Phasing:** Phase 1 = greenfield PM on Directus (replace ClickUp, lowest risk); Phase 2 = consolidate CRM off the Twenty fork; Phase 3 = move PopDAM's backend (Supabase) to Directus, keeping its NAS/render/checkout/bulk agents (rewired to Directus's API).

**Phase-1 backend BUILT & VERIFIED (2026-06-09 overnight):** `pm-system/` in the poppim repo — a deployable Directus project (`apply-schema.mjs` + `docker-compose.yml` + `seed-and-verify.mjs`). 14 collections (POP 2-tier + Spruce 3-tier), 26 relations, the Designer field-level pricing-hide policy, and the stage-history Flow. All 3 core proofs pass. Built/tested locally on the VPS via short-lived SQLite Directus (the VPS is shared with live Twenty+PopDAM and OOM-prone — do NOT run heavy stacks there; deploy via Coolify). Next: M2M relations, remaining Flows, ClickUp→Directus migration import, then the bespoke UI (react-admin + ra-directus; NOT Refine — its Directus connector is dormant). SSO: MS/Google config-only; WeChat needs custom work.

Full detail: `docs/platform-decision-report.md` (why) and `docs/directus-execution-plan.md` (how, incl. the Phase-1 spike runbook). Requirements: `docs/pm-system-design.md` (still written against Plane — needs re-targeting) and `docs/business-process.md`. Open items: verify Refine↔Directus connector, WeChat SSO path, OIG renewal mechanics. See [[interview-system-popdam-twenty-stack]] if present.

**DEPLOYED & LIVE (2026-06-10):** Directus PM system at **https://pm.designflow.app** — Coolify service `poppim` (uuid nzli85mk3luzb6u7cnq5fidu) on the 32GB Hetzner VPS: directus/directus:11 + postgres:16-alpine, OIG-licensed, Microsoft Entra SSO, Let's Encrypt. Schema applied + verified in prod (field-level pricing hide, stage-history Flow). Repo renamed to u2giants/poppim, folder /worksp/poppim. Full deployment identifiers/quirks in the repo's AGENTS.md. Next: repo cleanup (legacy docs), Postgres backups, M2M relations + remaining Flows, ClickUp→Directus migration import.
