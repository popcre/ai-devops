---
name: codex-docs-update
description: Update only the markdown files that need durable knowledge from an existing project, task, or session. Use when the user says "update the .md files", "update only the markdown files", "document this", or wants docs updated without secrets sweep, handoff closeout, commit, push, deploy, or any other end-of-session ritual.
---

# Codex Docs Update

Update docs, and only docs. This is the doc-only version of the session closeout
ritual.

## Scope

Do:

- Update `AGENTS.md`, `README.md`, relevant `docs/*.md`, folder READMEs, or
  `HANDOFF.md` only when the task created durable knowledge.
- Derive every statement from code, config, scripts, migrations, deployment
  files, or verified session findings.
- Keep `AGENTS.md` as the fast router: rules and pointers future sessions must
  see quickly.
- Put detail in the right topic doc instead of duplicating it everywhere.
- Say explicitly when no docs need updating.

Do not:

- Run secrets sweep unless separately asked.
- Commit, push, deploy, or close out the session unless separately asked.
- Invent architecture, deployment behavior, identifiers, credentials, or intent.
- Write secret values, tokens, passwords, private keys, or production credential
  values.

## File Roles

| File | Use for |
|---|---|
| `AGENTS.md` | Canonical operating guide, doc router, high-signal warnings |
| `README.md` | Quick entry point and setup orientation |
| `docs/architecture.md` | System design, components, data flow, constraints |
| `docs/development.md` | Local setup, run/test/lint/debug workflow |
| `docs/configuration.md` | Env vars, config files, feature flags, no values |
| `docs/deployment.md` | Deploy/release/environment/rollback workflow |
| `HANDOFF.md` | Temporary continuation state only when work is unfinished |

## Mandatory HANDOFF.md Completeness Gate

Whenever `HANDOFF.md` exists or this skill creates it, do not report the
documentation update complete until this gate passes:

1. Reread `HANDOFF.md` and every related Markdown file it relies on as if the
   current conversation had been erased. Do not use chat context to fill gaps.
2. Ask yourself exactly:

   > If I were to erase this session and start a brand new one with no knowledge
   > of what we discussed and no context here it would be able to pick up where
   > you left off with ALL the relevant knowledge you have about this session and
   > application from handoff.md and related .md files? Nothing relevant is left
   > out?

3. Answer honestly. If the answer is not an unqualified **yes**, revise
   `HANDOFF.md` and the appropriate related Markdown files to add every missing
   fact, decision, failed attempt, exact state, path, identifier, constraint,
   risk, and executable next step with a verification gate.
4. Reread and ask the question again. Repeat until the answer is **yes**.

This is a revision loop, not a checklist acknowledgment. Never claim the docs
update is complete merely because the question was asked.

## Final Report

Report:

- docs changed,
- why each change matters for future sessions,
- docs intentionally not changed,
- verification source used.

When `HANDOFF.md` is present, also state that the mandatory completeness gate
passed.
