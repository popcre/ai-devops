---
name: codex-repo-docs-overhaul
description: Create or rebuild the full markdown documentation set for a new repo/application or after a big application change using Albert's AI TASK SPEC. Use when the user asks to create AGENTS.md/docs exactly the standard way, pastes update_.md.docx, says "full documentation overhaul", or wants AGENTS.md to become the canonical operating guide and documentation router.
---

# Codex Repo Docs Overhaul

Use this for a new repo/application or a major change that makes the existing
docs structurally stale. For routine session notes, use `codex-docs-update`.

## Procedure

Read `references/repo-docs-task-spec.md` and follow it. Key points:

- `AGENTS.md` is the canonical operating guide and documentation router.
- A new senior engineer or AI session must understand the repo in under five
  minutes from `AGENTS.md`.
- The docs must prevent future sessions from loading every markdown file.
- Required docs normally include `README.md`, `AGENTS.md`,
  `docs/architecture.md`, `docs/development.md`, `docs/configuration.md`, and
  `docs/deployment.md`.
- `HANDOFF.md` is a short STATIC pointer to `HANDOFF.d/` and is never rewritten;
  handoffs are one write-once `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` file
  per session, existing only while that session's work is unfinished. Never edit
  another session's file. Migrate a legacy full-document `HANDOFF.md` (line 1
  lacks `handoff-pointer: v1`) into `HANDOFF.d/` verbatim, then write the pointer.
- `.claudeignore` / `.cursorignore` should match the "What to ignore" guidance
  where relevant.
- Never invent unknown facts; mark unknowns and explain how to verify them.
- Never include secret values.

## Verification

Before reporting done:

1. Confirm docs match actual repo state.
2. Confirm `AGENTS.md` has a task-based documentation map.
3. Confirm stale/duplicated docs were removed or routed.
4. Confirm no secrets were added.
5. Confirm your own `HANDOFF.d/` file is present only if unfinished work remains,
   that the root `HANDOFF.md` was not rewritten, that no other session's
   `HANDOFF.d/` file was touched, and that no `HANDOFF.d/` file points at an
   already-closed issue (warn loudly about those by name; the file COUNT is never a
   finding — owner ruling 2026-08-13).
