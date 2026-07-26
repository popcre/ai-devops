---
name: openrouter-oracle-key-has-embedded-quotes
description: "The OpenRouter \"Oracle\" key in 1Password has literal quotes baked into the value (breaks Bearer auth)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: ebbda927-1665-4194-9210-de233ed43022
---

The 1Password item **"OpenRouter API Key - The Oracle (local .env.local)"** (vault `vibe_coding`, field `OPENROUTER_API_KEY`) stores the value with **literal double-quotes wrapping it** (`"sk-or-v1-..."`) — it was captured verbatim from a `.env.local` line. Used raw as `Authorization: Bearer <value>` it sends `Bearer "sk-or..."` → OpenRouter returns **HTTP 401 "Missing Authentication header"**.

Fix at use time: `.strip().strip('"').strip("'")` before building the header. Durable fix: edit the 1Password item to remove the surrounding quotes (not yet done — flagged to the user 2026-07-17).

Prefer `op_run` with an `op://` ref in env so the key never hits the transcript. For a Kimi K3 opinion, skip OpenRouter entirely and use the local CLI — see [[kimi-code-cli-local-second-opinion]].
