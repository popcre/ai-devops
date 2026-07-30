---
name: codex-session-closeout
description: One-phrase Codex end-of-session closer. Use when the user says "wrap up", "update the .md files", "close out this session", "is everything pushed and committed?", or asks for docs, handoff, secrets, git, and deploy state to be made safe before ending.
---

# Codex Session Closeout

Close the session in one pass. Do not make the user paste the long docs prompt,
ask whether the handoff is good enough, or separately ask for git/deploy status.

## Procedure

1. **Summarize durable knowledge.** Update only markdown files that future
   sessions need: `AGENTS.md`, relevant docs under `docs/`, your own
   `HANDOFF.d/` file, or a focused fix note. Do not rebuild all docs unless the
   user asked.
2. **Handoff gate.** If work is unfinished, write **ONE NEW file of your own**:

   ```
   HANDOFF.d/<UTC-timestamp>-<machine>-<agent>-<slug>.md
   ```

   e.g. `HANDOFF.d/2026-07-29T2140Z-t16-codex-supabase-mcp-scoping.md`. Timestamp
   from `date -u +%Y-%m-%dT%H%MZ`; `<machine>` = short hostname lowercased;
   `<agent>` = `codex`; `<slug>` = 2–5 word kebab-case topic. All four fields are
   required — dropping one is what makes two sessions collide.

   Write all 9 sections of `templates/system/handoff-standard.md` so a fresh
   developer can continue without chat context: what was tried and failed, current
   branch/state, exact next steps, verification gates. Run the evidence-backed
   three-question audit in that standard: answer each question with supporting
   section references, close every gap found, and repeat until all answers are
   yes. A bare "yes" does not pass.

   **Concurrency rules — other agents may be in this same checkout right now:**
   - **Never rewrite the root `HANDOFF.md`.** It is a short static pointer to
     `HANDOFF.d/`. If line 1 lacks `handoff-pointer: v1` it is a legacy full
     document: `git mv` it verbatim into `HANDOFF.d/` as one open workstream, then
     write the pointer (see `handoff-writer` for the exact pointer text).
   - **Never open, edit, tidy, or delete another session's `HANDOFF.d/` file.**
   - **Retention:** delete YOUR file when the work it describes is proven done —
     git history preserves the text. Presence of a file means the workstream is
     OPEN. If `HANDOFF.d/` holds **more than 5** files, warn loudly in the closing
     report, list them oldest-first with dates, and ask which are finished.
   - **Never add `.gitattributes merge=union`** for handoffs; line-unioning
     Markdown yields a silently wrong document instead of a loud conflict.
3. **Secret hygiene.** Search this session and diffs for new credentials,
   tokens, connection strings, passwords, private URLs with embedded tokens, or
   `.env` changes. Never print secret values. Move durable secrets to
   1Password vault `vibe_coding` when available, or record the needed action in
   your own `HANDOFF.d/` file.
4. **Repo state.** Run `git status --short --branch`. Commit and push when the
   user asked to ship, when the repo's standing rules require it, or when the
   session changed durable project files. Use Albert's git author from global
   instructions.
5. **Verification.** Run the relevant tests/checks before commit if code
   changed. For deployed apps, verify the pushed SHA reached CI and the live
   app by the repo's documented deploy path. Do not report "done" from local git
   state alone.

## Closing Report

Return one short report:

```md
## Session closed
- Accomplished: ...
- Docs/handoff: ...
- Secrets: ...
- GitHub: branch, commit, push status
- Verification: commands/checks/live evidence
- Loose ends: none / ...
```

If any gate failed, report the blocker and the exact next action instead of
calling the session closed.
