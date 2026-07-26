---
name: project-bizanalysis
description: "bizanalysis interview system — Cloudflare Worker, D1 database, OpenRouter AI, personal interview links for 18 employees at POP Creations"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8a4c6027-c562-4589-b4b4-7ba86c007a97
---

AI-powered employee interview system for POP Creations / Spruce Line. Fully deployed on Cloudflare Workers (not Coolify).

**Why:** Albert wants deep intelligence on how all 18 employees actually do their work before designing a new PM system to replace ClickUp.

**Live URL:** https://bizanalysis-interviews.u2giants.workers.dev
**Admin URL:** https://bizanalysis-interviews.u2giants.workers.dev/ai-interview/admin?admin_token=0a87ad178ce77503bd9ee3425a0948727183a9b305ba38cd
**Admin token:** 0a87ad178ce77503bd9ee3425a0948727183a9b305ba38cd

**Infrastructure:**
- Cloudflare Worker: `bizanalysis-interviews` (account: 8303d11002766bf1cc36bf2f07ba6f20)
- Cloudflare D1: `bizanalysis` (UUID: 708de46c-5dc4-4cb3-96dd-5192f1ec8b36)
- AI: OpenRouter API (key stored as Worker secret and GitHub secret)
- Default model: anthropic/claude-sonnet-4.6

**Repo:** u2giants/bizanalysis
**Server workspace:** /worksp/bizanalysis/app (no server symlink — Cloudflare, not Coolify)

**How to apply:** This is separate from the plane/ClickUp project. No Coolify container.

**Personal links for 18 employees** (get fresh list any time via POST /ai-interview/admin/setup):
- Jessica: token=be2814139c184f73bdb4752fb994388ac6d7ca0bedc8443cbc705992ac5e36ad
- Liz: token=049a80b0fcec4bd4b72ca3f36dc10211d2b94767d3954cf09f274bdc1d987a44
- Jen: token=870c34c8386f4dc2be94120873de8161dd7ceea03a404b6bb64d4917dcf39970
- Albert (owner): token=97393d11511f480bbc82a299f86bc297989a284e56954b53aa5745071c4b672a
(full list in D1 — query: SELECT name, token FROM respondents)
