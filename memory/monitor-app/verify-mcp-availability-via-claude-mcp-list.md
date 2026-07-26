---
name: verify-mcp-availability-via-claude-mcp-list
description: "Never conclude an MCP server is unavailable from a negative ToolSearch — check `claude mcp list` first"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9731c810-5856-419a-8d5b-bb12127f33c5
---

A negative `ToolSearch` result does not mean an MCP server is unconnected. It only
means no matching tool schema is loaded in this session. Run `claude mcp list`
before telling the user a capability is missing.

**Why:** On 2026-07-16 I searched ToolSearch for "synology NAS run_command", got only
devops-mcp hits, and concluded the NAS MCP was not connected. I then made a real
engineering decision (removing a capability rather than porting it) and justified it
to the user with "I cannot verify live." The user corrected me: the server was
connected the whole time. `claude mcp list` showed it in one command. The justification
was wrong even though the decision survived on other merits — and I had told the user
something false about my own capabilities.

**How to apply:** When a tool seems absent and it matters to a decision, check
`claude mcp list`, then the relevant `.mcp.json` / `~/.claude.json`. If a server is
configured but its tools are absent from the session, diagnose that gap explicitly
(see [[nas-mcp-is-named-synology-monitor]]) rather than reporting the capability as
unavailable. A connected HTTP MCP server can also be called directly with `curl` using
its configured URL + bearer token when its tools are not loaded in-session.
