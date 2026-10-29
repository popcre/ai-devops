---
name: scaledown-compress
description: Compress pasted or retrieved documents with ScaleDown before an LLM call when the task is retrieval-style. Use when the user pastes a large doc, file dump, or boilerplate-heavy context and asks a question about it. Never use for secrets, private transcripts, review verdicts, or code to write/edit verbatim. Carries the measured trial record from docs/compression-and-process-fixes.md.
---

# scaledown-compress

Use ScaleDown Compress on **pasted/retrieved context** before a retrieval-style
LLM call. Do **not** use it for code the model must write or edit, safety-gate
evidence, review verdicts, secrets, or private transcripts.

## When

- User pastes a long document / log / rules block and asks a question about it
- Context is mostly boilerplate or repetition (measured ~85% cut on that class)
- Not: live coding turns (expect ~2% net after prompt cache — see Headroom)

## How

1. Resolve the key only from 1Password vault `vibe_coding`: the ScaleDown
   API key item (find it by searching item titles for "scaledown"; never
   write its exact title or id into this public repo). Never print the key.
   Prefer `op read` piped into env.
2. `POST https://api.scaledown.xyz/compress/raw/` with:
   - `context`: the pasted/retrieved text (after secret redaction)
   - `prompt`: the user's actual question (kept intact by the API)
   - `scaledown.rate`: `"auto"`
3. Header: `x-api-key: <key>`. Never put the key in a URL or commit it.
4. Use `results.compressed_prompt` as the LLM context. Keep the original on
   disk in session temp if reversibility matters.
5. Record `compression_ratio` and `original_prompt_tokens` /
   `compressed_prompt_tokens` in the session notes — that is the savings proof.

## Safety

- Redact API keys, tokens, JWTs, and passwords before send.
- This is third-party processing: code and conversations may leave the machine.
  Owner accepted that for ScaleDown; secrets still must not.
- Compression never replaces independent review or a safety gate.

## Transcripts

Questions about past AI sessions go to the transcript store first
(`transcript-query` skill, `ai-transcript-query`), which already holds
ScaleDown-labelled segments. Send raw transcript ranges to ScaleDown only when
the stored segments can't answer, and never to an LLM.

## Reference

Measured trial and Headroom caveat: `docs/compression-and-process-fixes.md`.
