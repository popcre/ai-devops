# Development

How to work on the toolkit itself (the Bash scripts and docs). For system design
see [`architecture.md`](architecture.md); for the canonical guide see
[`../AGENTS.md`](../AGENTS.md).

## Prerequisites

- Bash, `git`, `curl`, `jq`, `ripgrep` (`rg`), `gh`.
- `node`/`npm`, `python3`/`pip3` (checked by `install.sh`; optional for most work).
- `claude` and `codex` CLIs for exercising the workflow (optional for editing
  scripts).
- Optional: `shellcheck` for linting (`sudo apt-get install -y shellcheck`).

## Local setup

```bash
git clone https://github.com/u2giants/ai-devops.git /worksp/ai-devops
cd /worksp/ai-devops
./install.sh          # seeds /etc/ai-devops, symlinks bin/*, runs doctor
```

`install.sh` is idempotent and safe to re-run. It never overwrites
`/etc/ai-devops/*.env`.

## Edit / check / run loop

Editing a tool in `bin/` takes effect immediately — `/usr/local/bin/ai-*` are
**symlinks** into this checkout, so there is no rebuild step.

Check your changes:

```bash
bash -n bin/<tool>            # syntax check (no execution)
shellcheck bin/<tool>         # lint, if installed (optional)
ai-devops doctor             # full health check
ai-workspace-status          # exercise the git snapshot tool
```

Add a new tool: drop an executable script in `bin/`, then re-run `./install.sh`
(the symlink loop picks up any file in `bin/` automatically). Update `AGENTS.md`
and `README.md` to list it.

For Grok, GLM, or Kimi debate changes, keep the shared field contract in
`templates/delegation/debate-turn.md`. Test headings and safety guidance
offline in `tests/test-ai-grok-review.sh`. Do not add runtime parsing for
semantic fields: missing evidence is a skill review failure, while the wrapper
continues to enforce terminal completion, fixed permissions, session reuse,
cache reporting, and cost reporting.

Kimi is the exception to metrics reporting: its headless output exposes no context,
cache, token, cost, or returned-model values. Test exact-id session reuse, current-file
re-reading, and same-session durable-state recovery instead. Never inspect or edit its
raw session files.

Kimi 0.32.0 also has no prompt-file or stdin option for headless prompts, so `-p` puts
brief text in the local process arguments. Never put secrets in a Kimi brief. Its
implementation profile removes named web and subagent tools, but Bash still has network
access by owner decision. Test the disposable-worktree, patch-recovery, and cleanup
controls instead of claiming a network sandbox.

A failed Kimi implementation remains nonzero. If Git proves that the disposable
worktree changed, the wrapper exports a binary `.incomplete.patch` and adjacent
`.incomplete.md` report, then removes the worktree. It creates no empty patch for a
failure before changes and preserves the exact worktree only when safe artifact export
fails. Tests must cover usage limits, generic provider failures, deadlines, cancellation,
binary changes, bounded secret-safe reports, failed export, forged ownership, and
idempotent finalization. No complete or incomplete patch is ever auto-applied.

Windows GLM service changes need both offline suites and a controlled live crash test.
`tests/test-windows-scripts.sh` proves the generated recovery is bounded and observable;
`tests/test-ai-glm.sh` protects the client. The live gate kills only the OpenCode child,
waits for the same task to restore one loopback listener, then resumes the exact named
session. A `Ready` task is not healthy.

GLM implementation jobs use a v3 record written before clone creation and an atomic
directory lock held until terminal cleanup. Tests must pause the owner at the record,
clone, and server-session boundaries and prove `list`, duplicate rejection, exact abort,
terminal truth, and cleanup from another shell. Never make a test sweep an unrecorded
scratch directory. Dead-owner reconciliation requires a valid record, canonical clone,
dead PID, matching stale lock, and exact server state; ambiguous evidence is a warning,
not permission to delete. A terminal job name is reusable only after explicit
`ai-glm delete <name>`.

OpenCode 1.18.12 TodoWrite is allowed only in its measured permission form:
normalized action `todowrite` with exactly `resources:["*"]` and `save:["*"]`.
That wildcard names the session-internal todo store, not files or general tool access.
Tests must reject every altered shape and every unknown action. An implementation
permission failure must write its safe summary and first-observed time to the v3 record
on the first poll that exposes the request. If Git proves the remote-less clone changed,
finalization exports a binary `.incomplete.patch` and `.incomplete.md` before cleanup
and keeps the command nonzero. No-change failures make no empty patch. Export failure
preserves only the exact validated clone. Tests cover every bounded outcome,
unavailable rather than invented usage, exact ownership, atomic export failure, abort
races, and idempotent finalization.

## Testing

Installer behavior has lightweight, dependency-free tests:

```bash
bash tests/test-ai-install-skills.sh
bash tests/test-ai-memory-sync.sh
```

```powershell
pwsh -File tests/test-install-ai-devops-windows.ps1
pwsh -File tests/test-mcp-env-launch.ps1
pwsh -File tests/test-memory-sync-scheduled-task.ps1
pwsh -NoProfile -File tests/test-context-audit.ps1
```

`tests/test-context-audit.ps1` also covers the context enforcement checks: each
of the six locked safety categories failing on its own with a plain-English
reason, cross-client global parity plus its divergence allowlist, duplicated
startup text between a global and a skill description, and the warning budgets
in `tools/context-audit/budgets.json`. **Budgets warn and never fail a run**,
even under `--strict`; ratchet a budget down only after a measured reduction has
landed, and never raise one to silence a warning.

The tests use temporary repositories and temporary Claude/Codex homes. They
cover shared-skill installation, counts, dry-run safety, source-name collisions,
and automatic quarantine of the retired ShareSync skill. Also verify manually:

- `bash -n` on every changed script (fast syntax gate).
- `ai-devops doctor` should stay green for required checks (warnings are OK when
  Claude/Codex/gh are not logged in — doctor must not fail on those).
- For git-aware tools (`ai-workspace-status`, `ai-codex-review`, `ai-run-task`),
  run them inside a scratch git repo to confirm behavior on clean, dirty, and
  no-commits states.

## Conventions

- Scripts start with `set -uo pipefail` and a top comment block describing usage.
- Reviews and status tools are **read-only** — never add commit/push/delete to
  them.
- Match the existing style: `info`/`warn` helpers, colorized headings, clear
  usage text on `-h`/`--help`.
- Keep machine-specific values in `/etc/ai-devops/*.env`, never hard-coded.

## Debugging

- Run a script directly (`bash -x bin/<tool>`) for a trace.
- Confirm config resolution with `ai-devops paths`.
- If a symlink looks stale, re-run `./install.sh`; to remove symlinks use
  `./uninstall.sh` (see [`deployment.md`](deployment.md)).
