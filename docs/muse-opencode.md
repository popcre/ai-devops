# Muse Spark 1.2 OpenCode harness

This is the operating guide for `ai-muse`. It runs a direct, protected Muse review
inside a disposable self-contained repository copy. The former long-running OpenCode
server path was rejected because it failed provider authorization while the same pinned
binary and key worked in direct mode. GLM remains unchanged.

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

## Run a review

Run setup once, then verify the runner:

```bash
bin/setup-opencode-muse.sh
ai-muse doctor
```

From the repository being reviewed:

```bash
ai-muse review "$PWD" "Review the current changes. Report concrete findings with file paths and missing tests."
```

The command creates a disposable self-contained copy, builds its evidence packet
there, runs only `muse-spark-1.2-contributor`, and writes the result under
`.ai/reviews/` in the original repository. It never falls back to GLM or another model.

## Safety boundary

The review profile removes every write, shell, patch, web, and sub-agent tool. The
model receives only the disposable copy, whose remote is removed. These controls are
independent of OpenCode permission settings.

Contributor data-use terms were explicitly accepted by the owner on 2026-08-18. Do
not substitute another service tier. Confirm current pricing in the authenticated Meta
account before any broad paid qualification, because `/models` does not return a price.
