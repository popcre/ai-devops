---
name: OpenClaw provider status
description: Status of each AI provider configured in OpenClaw and known issues
type: project
---

OpenClaw has three providers configured: Anthropic, OpenAI, and Google.

**Anthropic:** Works after user purchased credits at console.anthropic.com. API key in compose.yaml as ANTHROPIC_API_KEY.

**OpenAI:** Working. API key in compose.yaml as OPENAI_API_KEY.

**Google/Gemini:** API key is valid and models are reachable via direct curl, but OpenClaw's internal Google SDK returns 404 "Not Found" for all gemini models (gemini-2.5-flash, gemini-flash-latest, etc.). Root cause unknown — likely a bug in how OpenClaw constructs the Google API request. This provider is currently non-functional within OpenClaw.

**Why:** Google models were the default for the main agent, causing all chat messages to silently fail until we switched the default to Anthropic.

**How to apply:** If Google models stop working again, don't assume the API key is bad — test it directly with curl. The issue is OpenClaw's SDK, not the key.
