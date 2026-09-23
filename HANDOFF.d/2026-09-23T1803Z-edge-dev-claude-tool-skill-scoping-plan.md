---
issue: 707
status: OPEN
owner: u2giants
---

# HANDOFF — Tool and skill scoping plan opened (2026-09-23 18:03Z, edge-dev/claude)

Plan: [`plan_tool-and-skill-scoping.md`](../plan_tool-and-skill-scoping.md) — read its STATUS table first.
Issues: #707 (tracking) with sub-issues #703, #704, #705, #706.

## What this session did
- Found that per-project MCP scoping (PR #114) never landed and that
  per-repository skill installation was never built; corrected a memory that
  claimed otherwise.
- Found live drift on edge-dev: Claude Desktop runs 10 MCP servers against 6
  declared; `designflow-human-qa` lost its manual-only flag in PR #479.
- Folded `2026-09-06T0048Z-edge-dev-claude-mcp-gateway-evaluation.md` into the
  plan's Phase 4 and retired that file (recoverable from git history).

## Next
Start Phase 1 (#703). Nothing was changed on any machine.
