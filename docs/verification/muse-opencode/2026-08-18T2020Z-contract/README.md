# Muse Model API contract probe

Checked on 2026-08-18 using a redacted account probe. No repository content, API key,
authorization header, prompt, completion, or raw provider error was retained.

## Result

`muse-spark-1.2-contributor` was present in the authenticated model list and every
successful direct and OpenCode call reported that exact model. The Meta endpoint is
`https://api.meta.ai/v1`; the API uses `MODEL_API_KEY` as a bearer token.

| Check | Result |
| --- | --- |
| Model listing | 200; Contributor, standard 1.2, and 1.1 were listed |
| Completion | 200; response has choices and usage |
| Streaming | 200; server-sent events included the exact model |
| Tool call | 200; `finish_reason` was `tool_calls` |
| Multi-turn continuity | 200 with `reasoning_effort: low`; `finish_reason` was `stop` |
| Invalid key | 401 with structured `error` object |
| Invalid model | 404 with structured `error` object |
| Cache fields | Not returned in the tested usage object |
| Rate limit / cancellation | Not deliberately forced; the future wrapper must fail closed on either |

OpenCode 1.18.12 loaded the isolated Meta provider and completed a harmless turn. Its
log recorded `providerID=meta-model-api` and `modelID=muse-spark-1.2-contributor`.
That pinned release uses the legacy `provider` / `@ai-sdk/openai-compatible` configuration
shape. The current OpenCode documentation uses a later `providers` configuration shape,
so it must not be copied into the pinned service.

## Sources

- Meta's [Model API cookbook](https://github.com/meta-models/meta-model-cookbook) documents
  the OpenAI-compatible endpoint, `MODEL_API_KEY`, streaming, tools, caching, and OpenCode use.
- OpenCode's [custom provider documentation](https://opencode.ai/v2/docs/providers) documents
  the current compatible-provider format. It is context only, not the 1.18.12 configuration.

The Contributor data-use terms and current price are an owner-approved operating decision in
the implementation plan. The authenticated `/models` response does not expose either value,
so this evidence does not invent a price or claim a cache discount.
