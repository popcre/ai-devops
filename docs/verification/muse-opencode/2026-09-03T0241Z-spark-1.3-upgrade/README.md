# Muse Spark 1.3 Contributor upgrade qualification

Checked live against Albert's authenticated Meta Model API account on
2026-09-03. The probe printed only response structure and status; it did not
print or store the credential, authorization header, prompt, completion text,
or raw response body.

- Endpoint remained `https://api.meta.ai/v1`.
- `GET /models` returned 200 and included
  `muse-spark-1.3-contributor`.
- `POST /chat/completions` returned 200 and identified the response model as
  `muse-spark-1.3-contributor`.
- An invalid credential returned 401.
- An invalid model returned 404.
- The response exposed the expected completion, prompt, total, and detailed
  token usage fields; no cache-specific usage field was returned.
- The protected OpenCode profile passed `ai-muse doctor --live` with Spark 1.3.
  Its reviewer-aligned health prompt completed with the required final
  `VERDICT: APPROVE`, proving the real wrapper path rather than only the direct
  API contract.
- A protected `ai-muse new` turn used its read-only repository tools to read a
  committed fixture file and returned its exact `ORCHID-731` continuity token.
- `ai-muse ask` resumed that same named provider session and repeated
  `ORCHID-731` without rereading the file. Both turns completed with structured
  stop events and final `VERDICT: APPROVE` lines, proving tool calling and
  persistent-session continuity through the real wrapper.

The prior 2026-08-18 Spark 1.2 qualification remains unchanged as historical
evidence. Active runtime configuration and tests now require Spark 1.3
Contributor without a fallback.
