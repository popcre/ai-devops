---
name: wrap-up
description: One-phrase end-of-session closer. Use when the user says "wrap up", "wrap it up", "dflow wrap up", "wrap up dflow", "close out this session", "we're done here", or "end of session" — ANY "wrap up" variant, including project-prefixed ones like "dflow wrap up", routes HERE, not to a ship-only skill. Chains the four closing rituals: docs update FIRST, then secrets sweep, handoff-safe state, and push verification — then gives a single plain-English closing report. This skill OWNS "wrap up"; it delegates the ship step to the project ship skill (dflow → dflow-ship) but never the other way around.
---

# wrap-up

One word closes the session properly. Runs the four closing rituals in order
and ends with a single consolidated report. Skip nothing silently — if a step
doesn't apply, say so in the report.

## Trigger phrases

- "wrap up" / "wrap it up"
- "dflow wrap up" / "wrap up dflow" / "dflow wrap-up" (project-prefixed — still THIS skill)
- "close out this session" / "we're done here" / "end of session"

> Any message containing "wrap up" belongs to this skill, even when a project
> name is attached. Do NOT route "dflow wrap up" to `dflow-ship` — `dflow-ship`
> is only Step 4 (ship & verify) of this skill's chain, and it does not update
> the .md docs. Running it alone silently skips the docs step. This skill runs
> docs FIRST, then calls `dflow-ship` for the ship step.

> **Shared-database sessions:** if this session touched the shared Supabase
> database / `u2giants/shared-db`, or dispatched sub-agents, also run the
> **`shared-db-handover`** skill for the handoff step. That handoff has two
> halves and the second — one block per sub-agent — is mandatory; a generic
> handoff is incomplete.

## The chain

1. **Docs** — run the `session-docs-update` skill: record what this session
   learned or changed in the right .md files (AGENTS.md / docs/ / your own
   `HANDOFF.d/` file), mirror any shared-backend change to `u2giants/shared-db`.
   If nothing durable changed, state that explicitly.
2. **Secrets** — run the `secrets-to-1password` skill: sweep the session for
   any credential that appeared and store it in the `vibe_coding` vault with
   rich notes.
3. **Handoff-safe state** — every touched repo: no mystery untracked files,
   no half-done merges. If work is unfinished, write **ONE NEW file of your own**:
   `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` (e.g.
   `HANDOFF.d/2026-07-29T2140Z-t16-claude-supabase-mcp-scoping.md`) to the full
   `handoff-standard.md` — all 9 sections — and RUN ITS SELF-AUDIT GATE. A
   stranger who walked in off the street must be able to continue with no
   questions, as effectively as you can right now, including knowing what was
   tried and failed. A three-sentence handoff is a failure; expand until the
   audit passes (use the `handoff-writer` skill, which owns the naming rules,
   the static `HANDOFF.md` pointer, legacy migration, and retention). Once it
   passes, if asked whether the handoff is comprehensive enough, answer "Yes"
   with evidence — do not reflexively answer "No, I'll fix it."

   Concurrency rules, non-negotiable — other agents may be working the same
   checkout right now:
   - **Do NOT rewrite the root `HANDOFF.md`.** It is a static pointer to
     `HANDOFF.d/`. If it is still a legacy full document (line 1 lacks
     `handoff-pointer: v1`), migrate it per `handoff-writer`: `git mv` it verbatim
     into `HANDOFF.d/` as one open workstream, then write the pointer.
   - **Do NOT open, edit, tidy, or delete another session's `HANDOFF.d/` file.**
   - **Retention:** delete YOUR `HANDOFF.d/` file when the work it describes is
     proven done (git history keeps the text). If `HANDOFF.d/` holds **more than
     5** files, warn loudly in the closing report — list them oldest-first with
     dates and ask which are actually finished.
4. **Ship & verify** — commit and push everything per each repo's rules
   (dflow → `dflow-ship`: PR to develop; hetz apps → `deploy-and-verify`:
   Actions/GHCR/Coolify + live SHA check; everything else → main). Confirm
   working trees are clean and pushes landed. Never report "done" on
   unverified evidence.

## Closing report (plain English, one message)

```md
## Session closed
- What we accomplished: [1-3 sentences, business language]
- Docs updated: [files, or "nothing durable changed"]
- Secrets: [stored/none found]
- Handoff: [new HANDOFF.d/<file> written + why / none because work is complete;
  files deleted as done. Report STALE files — ones whose issue is already closed —
  by name with their owner. Never report the file COUNT as a problem: 20 concurrent
  workstreams means 20 files and that is correct (owner ruling 2026-08-13)]
- Shipped: [commit SHAs, PR URLs, deploy verified yes/no]
- Loose ends: [anything Albert should know, or "none"]
```

If any step could not be completed (blocked push, failing test), say exactly
what and what the next session should do — do not end the report on "done".
