---
name: concurrent-session-clobber-hazards
description: "Two ways a concurrent AI session silently damaged this session's work in ai-devops on 2026-07-26: a broad `git add` swept my files into its unrelated commit, and a memory push from another machine reverted my corrections and shrank MEMORY.md"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c2b905f-9e65-49f5-b5bf-9d73bab09ead
  modified: 2026-07-27T00:46:48.332Z
---

Observed **2026-07-26** in `C:\repos\ai-devops` while another AI session was active
in the same checkout and on `albt16` at the same time.

**Hazard 1 — a concurrent session's broad `git add` steals your files.** Edits to
four skill files were committed by the other session inside
`45272ad "chore: purge deprecated Twenty CRM / Directus / plane vestiges"` — an
unrelated commit. Content survived byte-identical, but the change is now
un-findable by commit message. Detected by `git diff --cached --stat` showing only
one file staged when four were edited, then `git log --oneline -1 -- <file>`.

**Hazard 2 — `ai-sync-memory` from another machine reverts your memory edits.** The
`memory sync from albt16` commit (`c47af71`) overwrote a corrected
`op-account-migration-2026-07.md` description (put "SA is now read-only" back after
it had been fixed to READ-WRITE) **and dropped two freshly added index lines from
`MEMORY.md`**, which silently un-discoverable-ized a memory entry. A guard exists
(`182f9cd`, warns when a push would shrink a project's MEMORY.md index) but it only
**warns** and did not prevent this.

**How to apply:**
- Before committing in this repo, run `git log --oneline -3` and
  `git diff --cached --stat` — if your files are missing from the staged set, check
  whether another commit already absorbed them before re-editing.
- Stage only your own paths; never `git add -A` in a shared checkout.
- After any `ai-sync-memory pull`/`push`, **re-verify your own memory edits survived**
  — especially `MEMORY.md` index lines, which are the discoverability layer.
- Do not rewrite pushed history to fix a wrong commit message; record where the
  change actually landed in your own commit message instead.

See [[phase3-plan-location]] and [[op-account-migration-2026-07]].
