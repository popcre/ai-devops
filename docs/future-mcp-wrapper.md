---
summary: Placeholder design sketch for an MCP server wrapping the toolkit workflow; not built.
kind: plan
status: open
read-when: Considering an MCP wrapper for the toolkit
---

# Future: MCP Wrapper

Placeholder for wrapping this toolkit's capabilities as an MCP (Model Context
Protocol) server, so Claude/Codex can call the workflow directly as tools instead
of shelling out to the `bin/` scripts.

> Not built yet. This is a design sketch to guide the future implementation.

## Why

Today the workflow is driven by CLI scripts (`ai-run-task`, `ai-codex-review`,
`ai-workspace-status`, …). An MCP server would expose these as first-class tools
with typed inputs/outputs, so an agent can orchestrate the full staged workflow
without brittle shell parsing.

## Candidate tools to expose

| MCP tool | Wraps | Notes |
|----------|-------|-------|
| `workspace_status` | `ai-workspace-status` | read-only |
| `codex_review` | `ai-codex-review <mode>` | read-only |
| `run_task_scaffold` | `ai-run-task` | creates run dir only |
| `model_call` | `ai-model-call` | invokes a stage model |
| `doctor` | `ai-devops doctor` | health check |

## Design constraints

- **Read-only by default.** Review/status tools must never mutate the repo.
- **Explicit write scope.** Any write-capable tool (implementation) must require
  an approved plan and a feature branch, and must refuse `main`/`master`.
- **No secrets.** The server must never read or return `.env`, tokens, or auth
  files.
- **Config from `/etc/ai-devops`.** Reuse the same `models.env` / `server.env`.

## Where it will live

Implementation will go under `mcp/` in this repo. See [`mcp/README.md`](../mcp/README.md).
