---
name: synology-nas
description: Reach Albert's Synology NAS (edgesynology1, edgesynology2) from any repository when the synology-monitor connector is not loaded. Use for any NAS question or task — disk space, shares, files, Drive/ShareSync, logs, containers, "check the NAS", "what's on edgesynology" — in a session that has no synology-monitor tools.
---

# Synology NAS on demand

The `synology-monitor` connector is always loaded only in the
synology-monitor repository. Everywhere else, call it on demand with
`ai-nas`; it opens one connection, runs one request, and closes.

1. If this session already has `synology-monitor` tools, use them instead.
2. `ai-nas tools` lists the always-on tools.
3. Discover before acting: `ai-nas call tool_search '{"query":"<keywords>"}'`,
   then `ai-nas call get_capability_details '{"name":"<op>"}'`.
4. Run: `ai-nas call invoke_tool '{"name":"<op>","target":"edgesynology1","args":{}}'`
   (`target` is `edgesynology1`, `edgesynology2`, or `both`). Quick reads:
   `ai-nas call check_disk_space '{"target":"both"}'` and
   `ai-nas call run_command '{"target":"edgesynology1","command":"<read-only>"}'`.
5. Write operations are preview-first: run once without `confirmed`, review the
   preview, then repeat with `"confirmed": true` and the preview's
   `approved_hash` inside `args`.

Exit codes: 0 ok, 1 tool or server error, 2 usage, 3 connection or timeout
(`--timeout SECONDS`, default 180). A 401 means the server token and the
1Password `nas_token` have drifted; the vault value is the source of truth.
Reads that run longer belong to `synology-long-running-operations`; ShareSync
faults to `synology-sharesync-triage`. Never print or pass the bearer token.
