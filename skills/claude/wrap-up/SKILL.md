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

## The chain

1. **Docs** — run the `session-docs-update` skill: record what this session
   learned or changed in the right .md files (AGENTS.md / HANDOFF.md / docs/),
   mirror any shared-backend change to `u2giants/shared-db`. If nothing durable
   changed, state that explicitly.
2. **Secrets** — run the `secrets-to-1password` skill: sweep the session for
   any credential that appeared and store it in the `vibe_coding` vault with
   rich notes.
3. **Handoff-safe state** — every touched repo: no mystery untracked files,
   no half-done merges. If work is unfinished, create/update HANDOFF.md to the
   full `handoff-standard.md` and RUN ITS SELF-AUDIT GATE — a stranger who
   walked in off the street must be able to continue with no questions, as
   effectively as you can right now, including knowing what was tried and
   failed. A three-sentence handoff is a failure; expand until the audit
   passes (use the `handoff-writer` skill). Once it passes, if asked whether the
   handoff is comprehensive enough, answer "Yes" with evidence — do not
   reflexively answer "No, I'll fix it." If HANDOFF.md describes work that
   is now complete, delete it.
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
- Handoff: [HANDOFF.md present + why / absent because work is complete]
- Shipped: [commit SHAs, PR URLs, deploy verified yes/no]
- Loose ends: [anything Albert should know, or "none"]
```

If any step could not be completed (blocked push, failing test), say exactly
what and what the next session should do — do not end the report on "done".
