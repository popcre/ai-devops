---
name: repo-docs-overhaul
description: Full documentation-system rebuild for a repo — the "AI TASK SPEC Repository Documentation Maintenance" spec. Use for NEW applications, after BIG changes, or when the user says "do a full documentation overhaul", "make AGENTS.md the canonical operating guide", or pastes the AI TASK SPEC. For routine end-of-session updates use session-docs-update instead.
---

# repo-docs-overhaul

The heavyweight documentation pass. Rebuilds the repo's whole doc system per
Albert's canonical spec — as opposed to `session-docs-update`, which only
records what one session learned.

## When THIS skill vs session-docs-update

| Situation | Use |
|---|---|
| End of a normal coding session; "update the .md files" | `session-docs-update` |
| Brand-new application getting its docs for the first time | **this skill** |
| Big refactor/migration changed how the repo fundamentally works | **this skill** |
| AGENTS.md is missing, stale, or was never made the router | **this skill** |
| "do a full documentation overhaul" / the pasted AI TASK SPEC | **this skill** |

## Procedure

Follow [TASK-SPEC.md](TASK-SPEC.md) — Albert's spec verbatim (the shared-db
variant; the shared-db section applies only when the repo touches the shared
supabase.com backend). The spec's core requirements:

- **AGENTS.md is the canonical operating guide and documentation router** —
  readable by a new senior engineer in under 5 minutes, and it must prevent
  future sessions from ingesting every .md file.
- Required AGENTS.md sections (use the spec's exact formats): project summary,
  multi-model AI note, documentation map, repository structure, prime
  directive/custom-code boundary, core modification inventory, task-to-file
  navigation, data model & external identifiers, container/service inventory,
  what to ignore, intentional quirks, credentials & environment (no values),
  deployment (the REAL path), critical incidents, pending work.
- Fixed file roles: README (orientation), CLAUDE.md (Claude-only, short,
  never duplicates AGENTS.md), docs/architecture|development|configuration|
  deployment.md, folder READMEs only when genuinely useful, HANDOFF.md only
  while work is unfinished.
- Derive everything from actual repo state; never invent; mark unknowns and
  how to verify them; no secrets; delete/consolidate stale docs.
- Maintain `.claudeignore` / `.cursorignore` (and `.copilotignore` if Copilot
  is used) matching the "What to ignore" section.
- Follow the spec's REQUIRED AI WORKFLOW order and VERIFICATION GATES; end
  with its FINAL COMPLETION REPORT format.
- Close with the handoff quality bar: HANDOFF.md (if present) must let a brand
  new developer pick up without skipping a beat.

Already applied to ~12 repos (ansible session, t16). When running on a new
repo, mirror the structure of a recently-overhauled repo for consistency.
