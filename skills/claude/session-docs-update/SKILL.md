---
name: session-docs-update
description: End-of-session documentation ritual. Use when the user says "update the .md files", pastes the "AI Session Documentation Update Prompt", or at the end of any session that changed code, deployment behavior, data flow, configuration, or project knowledge. Replaces the 2-page prompt Albert pasted manually 30+ times across machines.
---

# session-docs-update

Record what this session learned or changed so future developers and future AI
sessions do not have to rediscover it. Update ONLY the Markdown files that need
durable knowledge from this specific session — do not rebuild the doc system.

## When to run

- User says: "update the .md files", "do any .md files need to be updated?",
  "update all the affected .md files", "document this so every future ai session knows"
- User pastes the "AI Session Documentation Update Prompt"
- Proactively offer it at the end of any session that changed code/config/deploys

## Procedure

Follow the full spec in [DOC-SPEC.md](DOC-SPEC.md) (Albert's canonical prompt,
recovered verbatim from his transcripts). Summary of the file-role table:

| File | Update when |
|---|---|
| `AGENTS.md` | Only high-signal guidance future sessions must see fast: new quirks, critical warnings, task routing, identifiers, "do not repeat this mistake" notes |
| `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` | Only if work is unfinished/blocked/partially deployed — **one NEW write-once file of your own**, never another session's. Delete YOUR file when the work it describes is truly complete. See the handoff gate below |
| `HANDOFF.md` | **Never rewrite it.** It is a short static pointer to `HANDOFF.d/`. The only write allowed is creating it (or replacing a legacy full document with it) during migration — see the handoff gate below |
| **Any plan file** (`IMPLEMENTATION-PLAN.md`, `plan_<topic>.md`) the session did work against | **Always — see the plan-file gate below.** A plan describes the world as it was when written; every step you execute makes it lie a little more |
| `docs/<topic>.md` | Topic detail for the affected area |
| `README.md` | Only if quick-start or top-level orientation changed |
| `CLAUDE.md` | Only Claude Code-specific workflow rules; general guidance goes in AGENTS.md |

Hard rules:
- Derive every update from code, config, migrations, or verified session findings. Never document guesses as facts.
- Never add secrets, tokens, passwords, or credential values.
- If nothing needs updating, say so explicitly — do not invent updates.

## Mandatory plan-file gate (a plan you worked against MUST NOT be left stale)

**Trigger:** the session executed, partially executed, or invalidated any part of a
plan file — `IMPLEMENTATION-PLAN.md`, `plan_<topic>.md`, or any file whose job is to
tell a future session what to build. Find them: `ls` the repo root and `docs/` for
`*PLAN*.md` / `plan_*.md`. If one exists and you touched its subject matter, this
gate applies even when the user did not mention the plan.

**Why this is mandatory.** A plan is written in the present tense about a world that
your work then changes. Left alone it becomes an actively harmful document: the next
session reads "these skill files carry false claims" or "AGENTS.md still says open",
believes it, and **redoes finished work or re-fixes a fixed bug**. This happened in
this repo on 2026-07-26 — steps 1–4 of `plan_phase3-config-consolidation.md` were
executed and its §5 "current state" table still described the pre-fix world. It was
caught only because Albert asked the right question. Do not rely on that.

**Do all five:**

1. **STATUS table at the very top of the plan** — one row per step, each marked
   ✅ done / 🟡 partial / ⬜ open, dated, plus one line naming **where a fresh session
   should start**. Create the table if the plan lacks one.
2. **De-stale the descriptive sections.** Anything that says a file/system is in a
   state your work changed must be corrected — especially the "current state of the
   code" section, which is exactly what an implementer trusts. Mark the row
   ✅ FIXED/UPDATED `<date>` and say **"do not redo"** where that applies.
3. **Keep the reasoning, delete only the falsehood.** The *why* behind a step (what
   broke, what it cost, why the fix must not be weakened) stays — relabel it as
   history rather than deleting it. A future session that loses the why will
   cheerfully undo the fix.
4. **Mark verification that already ran** (test IDs, gates) as passed with the
   evidence, so nobody re-runs a proven check or, worse, assumes it never ran.
5. **Record what is still open and what it is blocked on** — approval needed, a
   machine that is powered off, a decision the owner owes you. "Open" with no reason
   reads as "nobody got to it".

**Then make it discoverable, so nobody has to memorize a path.** A plan only findable
by its filename is a plan that will be lost. Link it from `AGENTS.md` (the router),
from your own `HANDOFF.d/` file, from the topic doc it belongs to, and from any skill
whose trigger would lead someone to it. Add a memory entry naming the plan and saying
"read its STATUS table first — do not re-derive or re-plan".

**Delete a plan file only when every step is genuinely done** — same rule as a
`HANDOFF.d/` file. If it is finished, say so in the final report and remove it.

## Mandatory handoff gate (`HANDOFF.d/`, one write-once file per session)

Handoffs are **one file per session**, never a shared rewritten document —
several AI agents work these repos concurrently, sometimes in the same working
copy, and a rewritten shared file loses one session's work with no merge to
resolve.

**Where your handoff goes:** `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, e.g.
`HANDOFF.d/2026-07-29T2140Z-t16-claude-supabase-mcp-scoping.md`
(`date -u +%Y-%m-%dT%H%MZ`; short hostname lowercased; `claude`; 2–5 word
kebab-case topic). All four fields required. Full rules, including the exact
static `HANDOFF.md` pointer text: the `handoff-writer` skill /
`templates/system/handoff-standard.md`.

Hard rules:

- **Never rewrite the root `HANDOFF.md`** and **never edit, tidy, or delete
  another session's `HANDOFF.d/` file.**
- **Legacy repos:** if `HANDOFF.md` exists and line 1 lacks `handoff-pointer: v1`,
  it is an old full-document handoff. `git mv` it verbatim into `HANDOFF.d/` as one
  open workstream, then write the static pointer, then write your own file. If it
  already has the marker, leave it alone.
- **Retention:** delete YOUR `HANDOFF.d/` file once its work is proven done — git
  history keeps the text. Presence = OPEN. If `HANDOFF.d/` holds **more than 5**
  files, warn loudly in the final report, list them oldest-first with dates, and
  ask which are finished.

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

## Shared backend rule

If the session touched the shared supabase.com backend in ANY way (schema,
migration, RLS, API contract, workers, generated types), also update the
canonical repo `u2giants/shared-db` — even when the code change was in an app
repo. See DOC-SPEC.md for the required shared-db documentation shape.

If the session ran inside `shared-db` with a coordinator and sub-agents, run the
**`shared-db-handover`** skill as well (the session was opened under
`shared-db-orchestrator`): that handoff has two halves, and the second — a
separate block for **each sub-agent's** work — is mandatory. The handoff
completeness gate above does not pass without it.

## Closers (always run after the doc update)

1. **Secrets sweep** — run the `secrets-to-1password` skill.
2. **Handoff-safe state** — no repo may be left with mystery untracked files
   (especially shared-db). If work is complete: run checks, commit/push per repo
   rules, confirm a clean tree. If not complete: write your own `HANDOFF.d/` file
   listing every changed/untracked file, what it's for, and the exact next action
   (stage only your own hunks — never sweep in another session's work). Never say
   "done" if anything still needs commit/merge/apply.

## Final report

End with the report format from DOC-SPEC.md: a Documentation Updates table,
Handoff status (which `HANDOFF.d/` file you wrote + reason, or none because the
work is complete; any file you deleted as done; a loud warning if `HANDOFF.d/` now
holds more than 5 open files), and Verification summary.
When you wrote a `HANDOFF.d/` file, state that the mandatory completeness gate passed.
When a plan file exists, state its updated STATUS line — which steps are now done,
where the next session starts, and what is blocked on whom — or say explicitly that
no plan file was touched.
