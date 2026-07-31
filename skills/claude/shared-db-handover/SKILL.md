---
name: shared-db-handover
description: Hand over, wrap up, or close out a session that used sub-agents or touched the shared Supabase database (`u2giants/shared-db`). Trigger on "hand this over", "hand this session over", "hand it to a new session", "wrap up", "wrap up this session", "close this out", "close out the session", "end of session", "we're done here", "write the handoff", "write the handoff for what the subagents did", "I'm out of context", "context window is full", "fresh session", or "give the next session a prompt" — whenever the work involved a database or schema change, a migration, RLS, a view, RPC, trigger, seed, a preview or production promotion, a cross-app data contract, the shared-db repo, or any dispatched sub-agents/worktrees. A handoff from such a session has TWO halves — coordination state AND a separate block per sub-agent — and one missing the second half is incomplete no matter how long it is, so prefer this skill over the generic `wrap-up` / `handoff-writer` whenever sub-agents or the shared database were involved. Pair with `shared-db-orchestrator`, which is how the session was opened and run.
---

# shared-db-handover

The end of a `u2giants/shared-db` session. This skill exists because the normal
handoff is not enough here: a shared-db session is run by a **coordinator** that
dispatched sub-agents (see the `shared-db-orchestrator` skill), and the next
coordinator has to be able to resume or retire **each agent individually**.

> **This skill does not replace `handoff-writer`.** Follow that skill's file
> convention (one write-once file at
> `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, never a rewrite of the shared
> root `HANDOFF.md`, never another session's file), its 9 required sections
> including the mandatory "what we tried that did NOT work", and its
> fresh-developer self-audit gate. This skill adds what shared-db needs on top.

## The handoff has TWO halves

A coordinator handoff that omits half (b) is **incomplete**, no matter how long
it is.

**(a) Coordination state**

- live workstreams and what each is for
- who owns which file (migrations / HANDOFF.md / AGENTS.md / everything else)
- open PRs, their state, and their merge order
- what is blocked on Albert, and the exact question he owes an answer to
- current `main` SHA and maximum migration version, **with the time they were
  checked** — these go stale within the hour
- **preview's actual state** — what is sitting on it, whose it is, and why it is
  not clean

**(b) Every sub-agent's work, SEPARATED BY SUB-AGENT**

One clearly headed block per agent — never merged into a single narrative:

```markdown
### Agent: <name / worktree path>
- **Asked to do:** …
- **Actually did:** … (commits, SHAs)
- **Found:** … (including anything that contradicts another agent)
- **PR / branch:** …
- **Worktree:** live (resumable) | finished (safe to clean)
- **Deliberately did NOT do, and why:** …
```

That last line matters most. Without it the next session redoes abandoned work
or, worse, undoes a deliberate omission.

## Before you call the handover done

1. **Re-verify the moving facts at write time**, not from memory: `git fetch`,
   the `main` tip SHA, the maximum migration version, and every open PR's state.
   Stamp each with the time it was checked.
2. **State preview's state honestly.** "Clean" is almost never true; say what is
   sitting on it and whose it is.
3. **Leave no worktree unexplained.** Every worktree under `.claude/worktrees/`
   is either live (say what it is mid-way through) or finished (say it is safe to
   clean). A sibling session may be auditing worktrees — an unexplained one gets
   treated as abandoned.
4. **No mystery untracked files** in the repo. Either commit them under the
   repo's branch/PR rules or list them in the handoff with what they are and the
   exact next action.
5. **Never merge on the way out.** A pending PR is handed over, not rushed
   through to tidy up the session.
6. **Run the closers:** `session-docs-update` for the documentation ritual and
   `secrets-to-1password` for the secrets sweep. Credentials are referenced by
   1Password item ID only — never a value in the handoff.
7. **Pass the gate:** could a developer who walked in off the street this morning
   continue with NO questions, as effectively as you can right now? If not,
   expand and re-grade.

## Related

- `shared-db-orchestrator` — how the session is opened and run (coordinator +
  sub-agents, single-writer ownership, the never-use-task-chips rule, and the
  incident ledger behind each rule).
- `handoff-writer` — the canonical 9-section handoff standard and file naming.
- `session-docs-update` — the end-of-session documentation ritual.
- `templates/system/handoff-standard.md` in `ai-devops` — the cross-tool standard.
