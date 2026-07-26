---
name: project_ai_routing
description: "PopDAM AI model routing — OpenRouter+Exacto default, live model config, and the GOOGLE_AI_API_KEY \"not dead\" trap"
metadata: 
  node_type: memory
  type: project
  originSessionId: eca34a18-14c7-4164-816f-367e92a793ec
---

How AI model calls are wired in PopDAM (as of 2026-07-14):

- **Worker (Railway) → OpenRouter only.** `apps/worker/src/openrouter.ts` is the
  single chat client. As of commit 7c91c66 every call is routed through the
  **Exacto** variant by default (`withExactoRouting` appends `:exacto` unless the
  slug already carries an explicit `:variant`). Exacto = free routing mode for
  best tool-calling accuracy; it is the fix for the cross-provider
  tool_choice/malformed-JSON failures, not the fallback ladders.
  **EXCEPTION (f532c08, 2026-07-15):** Exacto is NOT safe for every model — it
  regressed `minimax/minimax-m3` from ~14%→~89% failures (its only tool-capable
  endpoint truncates JSON). `MODEL_ROUTING_OVERRIDES` in openrouter.ts now
  hard-pins minimax-m3 to the `minimax` provider + excludes it from Exacto. Before
  trusting Exacto for a model, check its `/api/v1/models/<id>/endpoints`. Whether
  Exacto actually HELPS qwen/deepseek is still unmeasured. See KNOWN_QUIRKS #62.
- **Live production models** live in DB `admin_config.AI_TASK_MODELS` (NOT in
  code — the `DEFAULT_VISION_MODEL` constant is only a missing-row fallback):
  vision_tagging = `qwen/qwen3-vl-32b-instruct` (primary, stable),
  vision_tagging_fallback = `minimax/minimax-m3`,
  pdf_extraction = `deepseek/deepseek-v4-flash`,
  text_classification = `deepseek/deepseek-v4-pro`. No Google/Gemini model runs
  through the worker.

**TRAP — GOOGLE_AI_API_KEY is NOT dead.** The on-prem bridge/windows agents call
Google's generativelanguage API *directly* for PDF text extraction
(`apps/*-agent/src/pdf-text-sampler.ts`, `pdf-backfill.ts`), reading the key via
agent-api's `google_ai_api_key` passthrough, set through the admin ApisTab field.
Do not remove the ApisTab Google key field, the agent-api passthrough, or the
AI_MODELS google catalog entries. The now-deleted `ai-tag` edge function (direct
Gemini *tagging*) was a different, dead path and was correctly removed.
`toGeminiSchema` in the tag-asset contract is now unused (only that function used
it) — prune it once the contract mirror is no longer being concurrently edited.

Cost note: MiniMax direct API is ~2x OpenRouter for the same model, so keep it on
OpenRouter. See [[project_pdf_backfill_processor]], [[project_popdam_shared_env]].
