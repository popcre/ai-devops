# Muse Spark 1.2 OpenCode harness

This is the evidence record and operating guide for `ai-muse`. The harness is not
installed yet. Its first contract gate passed on 2026-08-18; the remaining work is
tracked in [`../plan_muse-opencode-harness.md`](../plan_muse-opencode-harness.md).

## Frozen first-contract facts

- Exact model: `muse-spark-1.2-contributor`. Standard Muse is never an acceptable
  fallback.
- API endpoint: `https://api.meta.ai/v1`.
- Key environment variable: `MODEL_API_KEY`, resolved only at launch from the
  `vibe_coding / Meta ai Muse Spark API Key / api key` 1Password field.
- Meta is OpenAI-chat-compatible. Completion, streaming, tool calling, and multi-turn
  continuity were proved with harmless test text.
- The tested direct responses expose token counts but no cache fields. Treat cache and
  cost as unavailable unless a later qualified call provides them.
- The pinned OpenCode 1.18.12 build works with the API. It uses the legacy
  `provider` plus `@ai-sdk/openai-compatible` format, not the current OpenCode v2
  `providers` format.

The redacted evidence and replayable fixture are in
[`verification/muse-opencode/2026-08-18T2020Z-contract/`](verification/muse-opencode/2026-08-18T2020Z-contract/)
and [`../tests/fixtures/muse-opencode/`](../tests/fixtures/muse-opencode/).

## Safety boundary

The future review profile removes every write, shell, patch, web, and sub-agent tool.
The future implementation profile is allowed only in an isolated clone with no Git
remote. These controls are inherited from the already-qualified GLM harness; OpenCode
permission settings are not treated as a protection.

Contributor data-use terms were explicitly accepted by the owner on 2026-08-18. Do
not substitute another service tier. Confirm current pricing in the authenticated Meta
account before any broad paid qualification, because `/models` does not return a price.
