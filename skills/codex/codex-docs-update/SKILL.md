---
name: codex-docs-update
description: Update only the markdown files that need durable knowledge from an existing project, task, or session. Use when the user says "update the .md files", "update only the markdown files", "document this", or wants docs updated without secrets sweep, handoff closeout, commit, push, deploy, or any other end-of-session ritual.
---

# Codex Docs Update

Update docs, and only docs. This is the doc-only version of the session closeout
ritual.

## Scope

Do:

- Update `AGENTS.md`, `README.md`, relevant `docs/*.md`, folder READMEs, or your
  own new `HANDOFF.d/` file only when the task created durable knowledge.
  **Never rewrite the root `HANDOFF.md`** — it is a static pointer to `HANDOFF.d/`.
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
| `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` | Temporary continuation state only when work is unfinished — **one NEW write-once file of your own**, never another session's |
| `HANDOFF.md` | **Never rewrite.** Static pointer to `HANDOFF.d/`; the only permitted write is legacy migration (see the handoff gate) |
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
from `AGENTS.md`, from your own `HANDOFF.d/` file, from the topic doc it belongs to, and
from any skill whose trigger leads there. Add a memory entry naming the plan and saying
"read its STATUS table first - do not re-derive or re-plan".

**Delete a plan file only when every step is genuinely done** (same rule as a
`HANDOFF.d/` file), and say so in the final report.

## Mandatory Handoff Gate (`HANDOFF.d/`, one write-once file per session)

Handoffs are **one file per session**, never a shared rewritten document. Several
AI agents work these repos concurrently — sometimes in the same working copy —
and a rewritten shared file loses one session's work with no merge to resolve.

**Where your handoff goes:** `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, e.g.
`HANDOFF.d/2026-07-29T2140Z-t16-codex-supabase-mcp-scoping.md`. Derive the fields:
`date -u +%Y-%m-%dT%H%MZ`; short hostname lowercased; `codex`; a 2-5 word
kebab-case topic slug. All four fields are required — dropping one is what makes
two sessions collide. Full rules and the exact static `HANDOFF.md` pointer text:
`templates/system/handoff-standard.md` / the `handoff-writer` skill.

Hard rules:

- **Never rewrite the root `HANDOFF.md`**, and **never open, edit, tidy, or delete
  another session's `HANDOFF.d/` file.**
- **Legacy repos:** if `HANDOFF.md` exists and line 1 lacks `handoff-pointer: v1`,
  it is an old full-document handoff — `git mv` it verbatim into `HANDOFF.d/` as
  one open workstream, then write the static pointer, then write your own file. If
  the marker is present, leave the file alone.
- **Retention:** delete YOUR file once its work is proven done; git history keeps
  the text. Presence = OPEN. Never treat the file COUNT as a problem and never cap it — 20 concurrent workstreams means 20 files and that is correct (owner ruling 2026-08-13). Warn about STALE files instead: ones whose issue is already closed. List those by name with the owner from their contract block; the target is zero.
- **Never add `.gitattributes merge=union`** for handoffs — line-unioning Markdown
  silently produces a wrong document instead of a loud conflict.

Whenever this skill creates or updates your `HANDOFF.d/` file, do not report the
documentation update complete until this gate passes:

1. Reread your `HANDOFF.d/` file and every related Markdown file it relies on as
   if the current conversation had been erased. Do not use chat context to fill gaps.
2. Write and answer these three questions, citing the handoff sections that
   support each answer:
   - Is it comprehensive enough that a brand-new developer with no
     project knowledge and no session context could pick up where I left off and
     not skip a beat?
   - Is it detailed enough that they could continue as well as I could right
     now, with all my session knowledge and the relevant background and purpose?
   - Is every single relevant detail needed for flawless execution included:
     background, goals, intended outcome, current state, failures, decisions,
     constraints, risks, exact next actions, and verification evidence?
3. Do not accept a bare **yes**. Name the evidence and every gap found. If any
   answer is not an evidence-backed **yes**, revise
   **your own** `HANDOFF.d/` file and the appropriate related Markdown files to add
   every missing fact, decision, failed attempt, exact state, path, identifier,
   constraint, risk, and executable next step with a verification gate.
4. Reread and answer all three questions again. Repeat until every answer is an
   evidence-backed **yes**. Preserve the final answers in the closing report or
   at the end of your own `HANDOFF.d/` file so the audit is inspectable.

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
When you wrote a `HANDOFF.d/` file, also state that the mandatory completeness
gate passed, name the file, and report the STALE files in `HANDOFF.d/` — those
whose issue is already closed — by name, or "none". The count is never a warning.
