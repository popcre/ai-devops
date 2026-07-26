---
name: feedback-caching-direct-api
description: "For cacheable repeated-prompt batch LLM workloads, prefer the direct provider API (auto prompt caching) over OpenRouter"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 89ad4e7a-d3a1-4265-be80-b3ecd14266f2
---

For high-volume LLM workloads with a large repeated prompt prefix (e.g. a fixed
instruction block + strict JSON schema sent on every call, only a small variable
tail differing), **use the direct provider API, never OpenRouter.**

**Why:** direct providers (DeepSeek especially) do automatic prefix-based context
caching — cache-hit input tokens bill at ~1/10 the miss price. OpenRouter adds a
routing margin, does not reliably pass provider auto-caching through, and PopDAM's
OpenRouter account data-policy guardrails have blocked models mid-task. The user
explicitly asked "is there repeated submissions that can be cached to save money?
if so we never want to use OpenRouter for that."

**How to apply:**
- Check for a repeated prefix before choosing routing. If present + high volume →
  direct provider API.
- Structure messages **stable-prefix-first** (instructions + schema), variable
  content **last**, so the cacheable prefix is shared across calls.
- Direct keys live in 1Password `ai-provider-api-keys` (`deepseek`, `dashscope`,
  `openai`, `gemini`, `anthropic` fields).
- OpenRouter/Exacto is still fine for low-volume, non-cacheable, or
  routing-diversity needs (see [[project_ai_routing]]). This is about batch cost.

Applies to the §5.15 rich-PDF extraction backfill (~19k tech-pack/licensing PDFs,
direct DeepSeek chosen). See `docs/RICH_PDF_EXTRACTION.md`.
