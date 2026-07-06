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
| `HANDOFF.md` | Only if work is unfinished/blocked/partially deployed. Delete it when the work it describes is truly complete |
| `docs/<topic>.md` | Topic detail for the affected area |
| `README.md` | Only if quick-start or top-level orientation changed |
| `CLAUDE.md` | Only Claude Code-specific workflow rules; general guidance goes in AGENTS.md |

Hard rules:
- Derive every update from code, config, migrations, or verified session findings. Never document guesses as facts.
- Never add secrets, tokens, passwords, or credential values.
- If nothing needs updating, say so explicitly — do not invent updates.

## Shared backend rule

If the session touched the shared supabase.com backend in ANY way (schema,
migration, RLS, API contract, workers, generated types), also update the
canonical repo `u2giants/shared-db` — even when the code change was in an app
repo. See DOC-SPEC.md for the required shared-db documentation shape.

## Closers (always run after the doc update)

1. **Secrets sweep** — run the `secrets-to-1password` skill.
2. **Handoff-safe state** — no repo may be left with mystery untracked files
   (especially shared-db). If work is complete: run checks, commit/push per repo
   rules, confirm a clean tree. If not complete: update HANDOFF.md listing every
   changed/untracked file, what it's for, and the exact next action. Never say
   "done" if anything still needs commit/merge/apply.

## Final report

End with the report format from DOC-SPEC.md: a Documentation Updates table,
Handoff status (HANDOFF.md present/absent + reason), and Verification summary.
