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
| **Any plan file** (`IMPLEMENTATION-PLAN.md`, `plan_<topic>.md`) the session worked against | **Always — see the plan-file gate.** A plan describes the world as it was when written; each executed step makes it lie a little more |

## Mandatory Plan-File Gate (never leave a plan you worked against stale)

**Trigger:** the session executed, partially executed, or invalidated any part of a
plan file (`IMPLEMENTATION-PLAN.md`, `plan_<topic>.md`, or any file whose job is to
tell a future session what to build). Locate them by listing the repo root and
`docs/` for `*PLAN*.md` / `plan_*.md`. The gate applies whenever you touched the
plan's subject matter, even if the user never mentioned the plan.

**Why mandatory.** A plan is present-tense about a world your work changes. Left
alone it becomes actively harmful: the next session reads "these files carry false
claims", believes it, and redoes finished work or re-fixes a fixed bug. Real case in
this repo, 2026-07-26: steps 1-4 of `plan_phase3-config-consolidation.md` were
executed while its "current state" section still described the pre-fix world. It was
caught only because Albert asked. Do not rely on that.

**Do all five:**

1. **STATUS table at the very top** - one row per step, marked done / partial / open,
   dated, plus one line naming where a fresh session should start. Create it if absent.
2. **De-stale the descriptive sections**, above all the "current state of the code"
   section, since that is what an implementer trusts. Mark rows FIXED/UPDATED with the
   date and say "do not redo" where it applies.
3. **Keep the reasoning, delete only the falsehood.** The why behind a step (what
   broke, what it cost, why the fix must not be weakened) stays, relabelled as
   history. A session that loses the why will cheerfully undo the fix.
4. **Mark verification that already ran** as passed, with its evidence, so nobody
   re-runs a proven check or assumes it never ran.
5. **Record what is still open and what it is blocked on** - approval, a powered-off
   machine, an owner decision. "Open" with no reason reads as "nobody got to it".

**Then make it discoverable** - a plan findable only by filename will be lost. Link it
from `AGENTS.md`, from `HANDOFF.md` when present, from the topic doc it belongs to, and
from any skill whose trigger leads there. Add a memory entry naming the plan and saying
"read its STATUS table first - do not re-derive or re-plan".

**Delete a plan file only when every step is genuinely done** (same rule as
`HANDOFF.md`), and say so in the final report.

## Mandatory HANDOFF.md Completeness Gate

Whenever `HANDOFF.md` exists or this skill creates it, do not report the
documentation update complete until this gate passes:

1. Reread `HANDOFF.md` and every related Markdown file it relies on as if the
   current conversation had been erased. Do not use chat context to fill gaps.
2. Write and answer these three questions, citing the handoff sections that
   support each answer:
   - Is `HANDOFF.md` comprehensive enough that a brand-new developer with no
     project knowledge and no session context could pick up where I left off and
     not skip a beat?
   - Is it detailed enough that they could continue as well as I could right
     now, with all my session knowledge and the relevant background and purpose?
   - Is every single relevant detail needed for flawless execution included:
     background, goals, intended outcome, current state, failures, decisions,
     constraints, risks, exact next actions, and verification evidence?
3. Do not accept a bare **yes**. Name the evidence and every gap found. If any
   answer is not an evidence-backed **yes**, revise
   `HANDOFF.md` and the appropriate related Markdown files to add every missing
   fact, decision, failed attempt, exact state, path, identifier, constraint,
   risk, and executable next step with a verification gate.
4. Reread and answer all three questions again. Repeat until every answer is an
   evidence-backed **yes**. Preserve the final answers in the closing report or
   at the end of `HANDOFF.md` so the audit is inspectable.

This is a revision loop, not a checklist acknowledgment. Never claim the docs
update is complete merely because the question was asked.

## Final Report

Report:

- docs changed,
- why each change matters for future sessions,
- docs intentionally not changed,
- verification source used.

When a plan file exists, state its updated STATUS line: which steps are now done,
where the next session starts, and what is blocked on whom - or say explicitly that
no plan file was touched.
When `HANDOFF.md` is present, also state that the mandatory completeness gate
passed.
