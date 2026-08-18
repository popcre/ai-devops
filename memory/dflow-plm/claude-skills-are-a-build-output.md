---
name: claude-skills-are-a-build-output
description: "~/.claude/skills is generated from the ai-devops repo and is rewritten on every sync; edit the repo, never the installed copy"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5f7586c7-ec02-4a0f-bbc6-bcbb6d5a76e8
  modified: 2026-08-18T21:44:16.430Z
---

`~/.claude/skills/<name>/` and `~/.codex/prompts/` are build outputs, not sources.
`C:\repos\ai-devops\bin\ai-install-skills` rewrites them from the ai-devops
**working tree** on every sync, stamping each skill with a `.ai-devops-managed`
fingerprint file. Any file whose fingerprint no longer matches is copied to
`<client>/skills-backup/<name>/` and then overwritten.

To change a skill: edit `C:\repos\ai-devops\skills\...`, commit, push, then sync.

**Why:** an edit made only under `~/.claude/skills` survives until the next time
any session on the machine runs `/sync-dotfiles`, then it is silently replaced. On
2026-08-18 a change to `session-docs-update` was lost this way twice in one
afternoon before the pattern was spotted. Each run also replaces the previous
backup, so a second sync erases the evidence of the first.

**How to apply:** never patch the installed copy, even for a one-line fix or a
quick test — treat `~/.claude/skills` as read-only. After pushing to ai-devops,
verify with `ai-install-skills --dry-run`, which reports each skill as up to date,
absent, update, local-edits or unmanaged and writes nothing.

Two traps:

- Windows line endings alone trigger the overwrite. Git stores these files LF and
  checks them out CRLF, so installing a file straight from `git show` never matches
  the fingerprint of the same file installed from the working tree — identical
  text, still flagged as a local edit.
- The install serves whatever the working tree holds at that instant. A concurrent
  session with the ai-devops clone on another branch, mid-rebase, or dirty makes
  the sync install that. See [[codex-concurrency-incident]] for the same
  one-clone-many-agents hazard in the dflow repos.

`ai-install-skills --log` (added 2026-08-18) prints this machine's append-only
install log at `~/.cache/ai-devops/install-log.tsv`: source revision, branch and
dirty state per run, plus every locally edited file that was overwritten and where
its backup went.

Nothing schedules this. Sessions run it via `/sync-dotfiles`. The only scheduled
ai-devops task is `ai-memory-sync` (every 30 minutes), which syncs memory only and
does not touch skills.
