---
summary: Placeholder README for a future MCP wrapper exposing toolkit scripts as typed tools; nothing implemented yet.
kind: living
status: current
read-when: Considering an MCP server wrapper for the toolkit
---

# mcp/ — Future MCP Wrapper

Placeholder for exposing the AI DevOps toolkit as an **MCP (Model Context
Protocol) server**, so Claude/Codex can call the workflow as typed tools instead
of shelling out to the `bin/` scripts.

> Nothing is implemented here yet. This directory reserves the space and records
> the intent. See [`../docs/future-mcp-wrapper.md`](../docs/future-mcp-wrapper.md)
> for the design sketch.

## Planned tools

| MCP tool | Wraps | Safety |
|----------|-------|--------|
| `workspace_status` | `ai-workspace-status` | read-only |
| `codex_review` | `ai-codex-review <mode>` | read-only |
| `run_task_scaffold` | `ai-run-task` | creates run dir only |
| `model_call` | `ai-model-call` | invokes a stage model |
| `doctor` | `ai-devops doctor` | read-only |

## Non-negotiable constraints

- Read-only by default; write-capable tools require an approved plan + feature
  branch and must refuse `main`/`master`.
- Never read or return secrets, `.env`, tokens, or auth files.
- Reuse config from `/etc/ai-devops/` (`models.env`, `server.env`).

## Layout (when built)

```
mcp/
  README.md          # this file
  server.*           # MCP server implementation (language TBD)
  package/pyproject  # dependencies
```
