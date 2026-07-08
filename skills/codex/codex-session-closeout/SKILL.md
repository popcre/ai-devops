---
name: codex-session-closeout
description: One-phrase Codex end-of-session closer. Use when the user says "wrap up", "update the .md files", "close out this session", "is everything pushed and committed?", or asks for docs, handoff, secrets, git, and deploy state to be made safe before ending.
---

# Codex Session Closeout

Close the session in one pass. Do not make the user paste the long docs prompt,
ask whether the handoff is good enough, or separately ask for git/deploy status.

## Procedure

1. **Summarize durable knowledge.** Update only markdown files that future
   sessions need: `AGENTS.md`, relevant docs under `docs/`, `HANDOFF.md`, or a
   focused fix note. Do not rebuild all docs unless the user asked.
2. **Handoff gate.** If work is unfinished, write or update `HANDOFF.md` so a
   fresh developer can continue without chat context. Include what was tried and
   failed, current branch/state, exact next steps, and verification gates. If
   work is complete and `HANDOFF.md` is obsolete, delete it.
3. **Secret hygiene.** Search this session and diffs for new credentials,
   tokens, connection strings, passwords, private URLs with embedded tokens, or
   `.env` changes. Never print secret values. Move durable secrets to
   1Password vault `vibe_coding` when available, or record the needed action in
   `HANDOFF.md`.
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
