# Muse Spark persistent conversations

`ai-muse` gives Codex and Claude named, persistent Muse Spark 1.3 Contributor
conversations. It uses OpenCode's proven direct-session mode rather than a background
server: server mode previously failed Meta authorization, while direct mode supports
an exact session ID and survives separate command calls.

## Commands

```bash
AI_MUSE_CALLER=codex ai-muse doctor
AI_MUSE_CALLER=codex ai-muse new architecture-debate --prompt-file brief.md
AI_MUSE_CALLER=codex ai-muse ask architecture-debate --prompt-file follow-up.md
AI_MUSE_CALLER=codex ai-muse list
AI_MUSE_CALLER=codex ai-muse show architecture-debate
AI_MUSE_CALLER=codex ai-muse transcript architecture-debate
AI_MUSE_CALLER=codex ai-muse reconcile architecture-debate
AI_MUSE_CALLER=codex ai-muse delete architecture-debate
```

`new` records the exact OpenCode session ID. `ask` must resume that same ID and fails
if OpenCode returns another one. Sessions are separated by repository, caller, and
name. Codex uses `AI_MUSE_CALLER=codex`; Claude uses `AI_MUSE_CALLER=claude`.
Replace `codex` with `claude` when Claude owns the conversation. If a provider turn or local check leaves the outcome uncertain, `ask` stops. Inspect
the transcript, then run `reconcile` to finalize an exact retained completion locally.
It verifies the original process result, session, packet, and response bytes without
contacting the provider. A session ID alone cannot clear an uncertain turn. Missing
or ambiguous terminal evidence stays blocked. If the source moved, reconciliation
retains a clearly non-authorizing report and permits a fresh same-session `ask`.
An unchanged existing report is reused; different bytes are never overwritten.

The older `ai-muse review [repository] [request]` command remains available. It now
creates a timestamped named conversation, so the result is not trapped in a one-off
call.

## Safety and evidence

- Exact model: `meta-model-api/muse-spark-1.3-contributor`. No fallback is accepted.
- Live qualification on 2026-09-03 confirmed that the unchanged
  `https://api.meta.ai/v1` endpoint lists and returns that exact model.
- The review profile removes write, edit, patch, shell, web, and sub-agent tools.
- Each turn runs in a disposable self-contained copy with no GitHub remote.
- Each turn refreshes the verified evidence packet to the current repository state.
- Completion requires OpenCode's structured `step_finish` reason `stop`, a session
  ID, and non-empty response text. Exit status or text alone is not success.
- Reports are written under `.ai/reviews/`; local metadata contains no prompt or key.
- The key is read at launch from `vibe_coding / Meta ai Muse Spark API Key / api key`
  and is never stored in Git or session metadata.

Contributor data-use terms were accepted by the owner on 2026-08-18. Do not
substitute the standard tier. A measured follow-up call reused the exact session and
recalled the prior turn; it also reported a large cache read. Provider cost is still
reported only when OpenCode supplies it.

## Context window and prompt caching

Set on 2026-09-05 and enforced byte-for-byte by `ai-muse` at every turn:

- The provider package is `@ai-sdk/openai`, matching Meta's own OpenCode catalog
  entry. The generic OpenAI-compatible package silently drops the caching options.
- Context limit 1,048,576 tokens, output 65,536 — Meta's published maximum.
- Compaction keeps history instead of pruning it: `prune` off, `tail_turns` 8,
  `reserved` 32,768.
- An explicit cache key `ai-devops-muse-review` with 24-hour retention, plus
  `cache_read` pricing so cached tokens are accounted for.

Meta already served implicit prefix caching before this change; a same-config A/B
confirmed it. What the change adds is the stable key, the retention window, and cost
visibility. A verified follow-up turn reported 15,473 cached read tokens out of 15,560.

## Why there is no Muse service

Persistent conversation does not require a permanent process. OpenCode 1.18.12
supports `run --session <exact-id>` in direct mode. This keeps the working Meta path,
avoids another port, password, task, service, and crash-recovery loop, and still gives
Codex the same everyday `new` then `ask` debate flow as GLM.
