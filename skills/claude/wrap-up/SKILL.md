---
name: wrap-up
description: One-phrase end-of-session closer. Use when the user says "wrap up", "close out this session", "we're done here", or "end of session". Chains the four closing rituals: docs update, secrets sweep, handoff-safe state, and push verification — then gives a single plain-English closing report.
---

# wrap-up

One word closes the session properly. Runs the four closing rituals in order
and ends with a single consolidated report. Skip nothing silently — if a step
doesn't apply, say so in the report.

## Trigger phrases

- "wrap up" / "wrap it up"
- "close out this session" / "we're done here" / "end of session"

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
   passes (use the `handoff-writer` skill). If HANDOFF.md describes work that
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
