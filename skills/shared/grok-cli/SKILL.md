---
name: grok-cli
description: Locate and use xAI's installed Grok CLI (`grok`, branded Grok Build) as an independent coding agent, including read-only reviews, repository analysis, explicit implementation delegation, session continuation, and local documentation lookup. Use when the user says "use Grok", "ask Grok", "run this by Grok", "Grok CLI", "Grok Build", requests a Grok second opinion, asks where Grok is installed, or explicitly delegates coding work to Grok.
---

# Grok CLI

Drive Grok headlessly and keep the calling Claude or Codex session responsible
for scope, safety, and verification.

## Locate and verify the CLI

1. Resolve the executable instead of assuming an install method:

   ```powershell
   Get-Command grok -All
   grok --version
   grok doctor
   ```

   On this Windows machine, the managed install is normally
   `C:\Users\ahazan2\.grok\bin\grok.exe`, and the user PATH contains
   `C:\Users\ahazan2\.grok\bin`.

2. Treat `~/.grok/` as Grok's home. It contains configuration, version metadata,
   documentation, sessions, logs, and credentials. Never read or print
   `~/.grok/auth.json`.
3. Run `grok inspect` in the target repository to confirm the project root,
   loaded `AGENTS.md`/`CLAUDE.md` instructions, permissions, skills, and config.
4. Run `grok models` before selecting a model. Do not hard-code a remembered
   model ID.

## Read the installed documentation

Prefer the documentation bundled with the installed binary because it matches
the local version:

- `~/.grok/README.md`: complete reference
- `~/.grok/docs/user-guide/01-getting-started.md`: installation and basic use
- `12-project-rules.md`: instruction discovery and `grok inspect`
- `14-headless-mode.md`: `-p`, output formats, scripting, and exit codes
- `16-subagents.md`: child-agent behavior and isolation
- `17-sessions.md`: resume, continue, and session storage
- `18-sandbox.md`: OS sandbox profiles and platform support
- `19-plan-mode.md`: interactive plan workflow
- `22-permissions-and-safety.md`: permission modes and rule matching
- `~/.grok/CHANGELOG.md`: version-specific changes

Read the matching chapter before relying on a feature or flag. Also run
`grok --help` or `grok help <subcommand>` because the CLI surface may change.

## Prepare the delegation

Give Grok a self-contained brief containing the task, repository and branch,
relevant paths or errors, constraints, and required evidence. Tell Grok to read
the repository's instructions. Never include secrets, credential files, `.env`
contents, or unrelated private data.

Default to a read-only call for questions, planning, debugging, audits, and
second opinions. Use implementation mode only when the user explicitly asks
Grok to edit or implement.

## Headless permission trap (the #1 delegation failure)

In headless mode (`--single`/`-p`, `agent`), a tool call that would prompt is
**cancelled and reported to the model — it never pauses for input**. So Grok's
read-only context pass succeeds (reads/searches auto-approve), then the first
repo/git command is cancelled and the run dies mid-task.

Compounding trap: the `--permission-mode` flag only honors `bypassPermissions`
and `default`. Passing `auto`, `dontAsk`, `acceptEdits`, or `plan` to that flag
is **accepted but silently does nothing** — you fall back to `default`
(prompt-for-everything), which in headless mode cancels every non-read-only call.
`--permission-mode auto` is NOT a working way to grant tool execution.

To let a headless run actually execute commands, use ONE of: narrow `--allow`
rules (e.g. `--allow 'Bash(git *)'`), `--always-approve` (only for explicit
implementation, ideally inside `--worktree`), or `defaultMode: "dontAsk"` in
`.claude/settings.json` **plus** allow rules. See
`~/.grok/docs/user-guide/22-permissions-and-safety.md` and `14-headless-mode.md`.

## Run a read-only review

Use headless mode with explicit tool denials:

```powershell
grok --cwd $repo --single $prompt --output-format json `
  --permission-mode default `
  --allow Read --allow Grep `
  --deny Edit --deny Bash `
  --no-subagents --no-memory --disable-web-search
```

This intentionally prevents file writes and shell execution. On Windows, do not
claim that `--sandbox read-only` protects the run: the installed documentation
lists OS sandbox enforcement for Linux and macOS, not Windows. Permission rules
are the applicable control on this machine.

For a multi-turn read-only investigation, capture `sessionId` from JSON output
and continue with `--resume <session-id>`. Use `--continue` only when selecting
the newest session for the current directory is unambiguous.

## Run explicit implementation

Record `git status` first and preserve unrelated work. Prefer an isolated Grok
worktree:

```powershell
grok --cwd $repo --worktree=grok-task --single $prompt `
  --always-approve --output-format json --no-memory
grok worktree list
```

Use `--worktree=<name>` with `=`. Repeat all branch, database, production,
destructive-action, allowed-file, and test constraints inside the prompt.
Never use `--always-approve` for a review or merely because headless mode would
otherwise reject a tool call.

After Grok finishes, inspect the reported worktree and every diff, run the
relevant tests independently, and deliberately apply only the accepted changes.
Do not let Grok commit, push, merge, deploy, alter shared databases, or touch
production unless the user separately authorized that exact action.

## Verify and report

Treat a nonzero exit, authentication error, missing response, permission
violation, or unexpected working-tree change as failure. Clearly label Grok's
conclusions separately from the calling agent's judgment. For implementation,
report the actual files changed and independently verified test results.
