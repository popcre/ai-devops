# DietCode proxy header patch (2026-10-14)

**Why.** Claude Desktop failed with
`BrotliDecompressionError fetching "http://127.0.0.1:8788/v1/messages?beta=true"`.
DietCode's proxy used undici `fetch`, which decodes the upstream body but left
`content-encoding: br` on the forwarded response. The Claude client then tried
to Brotli-decode plain JSON.

**Patch** in `dietcode@0.5.0` `dist/src/proxy/server.js` on edge-dev3 at
`/home/ahazan/.local/lib/node_modules/dietcode/dist/src/proxy/server.js`:

1. Outbound `headers["accept-encoding"] = "identity"` (after `outboundHeaders`).
2. In `pipeUpstream`, skip `content-length`, `content-encoding`, and
   `transfer-encoding` when copying upstream response headers.

**Re-apply** after an npm upgrade of `dietcode` (this file is not upstream):

```text
# see tests/verification/compression/2026-10-14-slm-history-compaction-pilot.md
```

**Proof (all on edge-dev3, 2026-10-14):**

| Test | Result |
|---|---|
| Mock upstream returns `content-encoding: br` + brotli body; client reads JSON | `PASS_NO_BROTLI_BREAK` (`test_brotli_intercept.py`) |
| Same shape via undici (Claude Code's fetch stack) | `PASS_UNDICI_NO_BROTLI_BREAK` (`test_brotli_undici.mjs`) |
| Real `https://api.anthropic.com` through proxy (unauthenticated) | `PASS_REAL_UPSTREAM_JSON` (clean 401 JSON, no encoding leak) |
| Wrapped `claude --version` | `2.1.295 (Claude Code)` |

**Still required:** one live Claude Desktop session after the wrap to confirm
auth + DietCode transform together (cannot be driven headless).
