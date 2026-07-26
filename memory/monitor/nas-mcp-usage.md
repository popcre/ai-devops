---
name: nas-mcp-usage
description: "How to call the NAS MCP server from within this session — auth, endpoint, tool pattern, curl header requirements."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 118a8af4-fdfa-4e10-a2e2-0cd981dc2f73
---

The NAS MCP server runs at **https://nas-mcp.designflow.app/mcp** (port routed through Traefik on the VPS).

## Auth
Bearer token in `Authorization` header. Token is in the project env / was provided by user. The claude.ai connector wrapper requires OAuth; bypass it entirely by calling the HTTP endpoint directly with curl.

## Required curl headers
Both headers are mandatory — the server rejects requests missing `Accept`:
```
Authorization: Bearer <token>
Content-Type: application/json
Accept: application/json, text/event-stream
```

## Always-on tools (no tool_search needed)
- `tool_search` — find tools by keyword or group name
- `invoke_tool` — execute any tool by name
- `run_command` — free-form read-only shell on the NAS
- `check_disk_space` — disk usage freebie
- `restart_nas_api` — restart the NAS API container

## Pattern
1. Call `tool_search` with keywords (e.g. "sharesync", "restart", "storage", "btrfs")
2. Call `invoke_tool` with the exact name, target, and args

## Example
```bash
curl -s -X POST https://nas-mcp.designflow.app/mcp \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"tool_search","arguments":{"query":"sharesync","limit":10}}}'
```

## Tool registry
119 total tools, 80 read + 40 write enabled. Groups: system, performance, network, security, drive_sync, logs, storage, files, recovery, packages, backup, write_restart, write_storage, write_files, write_tasks, misc.

Write tools require `confirmed: true` in args after previewing.

## TODO: add MCP `instructions` field
In `apps/nas-mcp/src/index.ts`, pass `instructions` to `new McpServer({...})` so every MCP client receives the usage guide automatically via the `initialize` handshake. Also add a paragraph to project CLAUDE.md.
