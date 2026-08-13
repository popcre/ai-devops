---
name: hts-rag-pilot
description: "State of the HTS AI-classification RAG work — plan-only parent, plus the multi-model distillation pilot"
metadata: 
  node_type: memory
  type: project
  originSessionId: dd2f4ab8-0a3d-4487-9421-175480787aab
  modified: 2026-07-22T01:50:02.857Z
---

**HTS RAG = building a local database of AI HTS (customs) classifications for dflow.**

- `designflow-backend/HTS_RAG.md` — the parent design (~1800 lines). **Plan only,
  ZERO code**: no tables, no `helpers/hts-rag/`, no routes. Git history shows only
  `docs(...)` commits. Codex critiqued it (over-engineered; AI-agreeing-with-AI
  isn't validation; confidence score is false precision).
- `designflow-backend/HTS_RAG_PILOT.md` — companion pilot plan (written 2026-07-21):
  a one-time admin "HTS Classification Lab" that runs a product past **9 models**
  (4 frontier judges + 5 cheap/Chinese candidates) to (a) distill the reasoning/
  prompts (the "brain") and (b) pick the cheap production model via scorecard. A
  ruling **verifier** crawls CBP to catch hallucinated ruling numbers (−15 each).
  Two eval tracks: Research (find/narrow rulings) + Judgment (classify same set).
  Model roster is Albert-specified and REAL — find exact IDs, never substitute.
- Runtime target (parent plan): classifier hits RAG FIRST; strong match → use it,
  else fall back to live CROSS+AI, then ingest. Shadow/suggest-only first.

Current-state facts (verified in code): the live classifier feeds the model only
CROSS **search metadata** (ruling number + one-line subject + assigned HTS), NOT
ruling bodies — any deeper "ruling content" it states is model MEMORY (hallucination
risk). CBP exposes full body at `GET rulings.cbp.gov/api/ruling/{number}` (plain
JSON, no headless browser). Added `cross.fetchRuling()` + `/api/cross/ruling/:n`,
and stopped the frontend dropping revocation data (now flags REVOKED/MODIFIED to
the model). Storage pipeline is now BUILT end-to-end (2026-07-21): `hts_rag_rulings` table live
in Supabase (shared-db migration 20260721203000, promoted to prod). Backend:
`HtsRagRuling` model (public schema), `services/hts-rag.service.js`
(buildRulingRecord/upsertRuling/ingestRulings) + `POST /api/hts-rag/ingest`.
Frontend: `HtsRagService.ingestRulings` + `selectChosenRulingNumbers` fire from
`duty_rate_dialog.applyClassification` on accept (rulings matching the accepted
code's 6-digit subheading). Verified against Supabase preview (live CRUD round-trip).
Shadow-safe **precheck** now built too (`POST /api/hts-rag/precheck` +
`helpers/hts-rag-precheck.js` deterministic scoring, confidence capped 75, never
auto-recommends) — built by Qwen qwen3.8-max-preview, verified by Claude. STILL TODO:
the 9-model distillation pilot Lab (Angular admin UI + 9-provider fan-out + ruling
verifier + scoring) per HTS_RAG_PILOT.md. Delegation CLIs available on al8960ofc:
Codex, Kimi (`kimi -p`, no --auto/-y), Qwen (`qwen --approval-mode yolo -m qwen3.8-max-preview`;
its settings.json has a PLAINTEXT api key — flagged, not yet moved to 1Password).
The ingest/frontend pieces were built by Kimi K3, reviewed+verified by Claude. See
[[dflow-db-supabase-migration]] and [[dflow-delivery-workflow]].
