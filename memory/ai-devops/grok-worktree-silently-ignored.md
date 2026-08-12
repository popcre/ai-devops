---
name: grok-worktree-silently-ignored
description: "Grok 0.2.112 accepts and silently ignores --worktree in headless mode; use ai-grok-implement, never a hand-composed grok command."
metadata: 
  node_type: memory
  type: project
  originSessionId: bd58a75c-005a-4035-bf8f-ad552d30afc6
  modified: 2026-08-12T16:43:26.814Z
---

Measured 2026-08-12 on al8960ofc against Grok 0.2.112 (Windows): `grok --worktree[=NAME]`
is accepted and **silently ignored** in headless mode (`--prompt-file` / `-p`). No error,
no warning, no exit-status signal. Grok edits whatever `--cwd` points at. Also: `--cwd`
needs a native Windows path (`/c/...` fails with os error 3), `--permission-mode auto`
auto-cancels tools and yields `stopReason: "Cancelled"`, and `grok worktree remove` does
not exist (the subcommand is `rm`).

**Why:** three shared-db implementation runs cost ~$0.59 and produced nothing because Grok
was writing in the primary checkout, which was on a stale detached HEAD.

**How to apply:** run implementation work through `bin/ai-grok-implement` (commit 506d180),
which creates the worktree with git, bases it on `origin/main`, and validates the JSON,
diff, and cleanup. Never hand-compose a `grok --worktree` command. See [[grok-opencode-constraints]]
for the sibling GLM rules.
