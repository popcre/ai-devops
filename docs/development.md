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

## Testing

Installer behavior has lightweight, dependency-free tests:

```bash
bash tests/test-ai-install-skills.sh
```

```powershell
pwsh -File tests/test-install-ai-devops-windows.ps1
```

The tests use temporary repositories and temporary Claude/Codex homes. They
cover shared-skill installation, counts, dry-run safety, source-name collisions,
and opt-in quarantine of the retired ShareSync skill. Also verify manually:

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
