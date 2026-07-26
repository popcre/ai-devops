---
name: kimi-code-cli-local-second-opinion
description: How to get a Kimi (incl. real K3) second opinion locally via the authenticated ~/.kimi-code CLI
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9731c810-5856-419a-8d5b-bb12127f33c5
---

There is an authenticated **Kimi Code CLI** on this machine at `~/.kimi-code/bin/kimi`
(v0.27.0), OAuth-logged-in to Moonshot directly (`api.kimi.com`, config in
`~/.kimi-code/config.toml`). Use it for a Kimi second opinion — it reaches the **real
K3** model, which the OpenRouter path does **not** (that account's data-policy guardrail
404s `moonshotai/kimi-k3`; `kimi-latest` there silently falls back to K2.6).

Non-interactive one-shot (what you want for an opinion):
```bash
~/.kimi-code/bin/kimi -m kimi-code/k3 -p "<your full prompt>"
```
- Model aliases (from config.toml): `kimi-code/k3` (display "K3", efforts low/high/max,
  default max), `kimi-code/kimi-for-coding` ("K2.7 Coding", the default), and a
  `-highspeed` variant. All 256k context on this managed coding endpoint.
- `-p` prints the response and exits; it also prints the model's visible thinking, then
  the answer, then a `kimi -r <session>` resume hint. For opinion requests, add
  "OPINION ONLY — do not run commands or use tools" since it is a full agent CLI (has
  tools; `-y`/`--yolo` auto-approves — do NOT use that for an opinion).
- Other capabilities: `kimi server` (local REST/WS/web UI), `kimi web`, `kimi acp`
  (Agent Client Protocol over stdio), `kimi provider` (manage providers), `kimi export`,
  `kimi doctor`. `--add-dir` / `--skills-dir` extend a session.

Contrast with [[verify-mcp-availability-via-claude-mcp-list]]: this is a *local CLI*, not
an MCP server, so it won't show in `claude mcp list`. The Codex second-opinion path is
separate (see the codex-second-opinion skill). Prefer this CLI over the OpenRouter key in
1Password ("OpenRouter API Key - The Oracle") when you specifically need K3.
