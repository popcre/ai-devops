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
git clone https://github.com/popcre/ai-devops.git /worksp/ai-devops
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
offline in `tests/test-ai-grok-review.sh`. Grok is pinned to one exact CLI build
in `config/provider-cli-versions.json`; the wrappers refuse paid work against any
other build, so a Grok CLI upgrade means changing that policy file and
re-qualifying, not relaxing the check. Do not add runtime parsing for
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

Start manual GitHub verification through `ai-verify-run start`, with the
originating task and purpose. It refuses an active exact-SHA duplicate and never
cancels as a side effect. GitHub serializes same-SHA manual requests without
cancelling the running one; after the lock is acquired, an already-successful
exact-SHA manual run is reused instead of repeating the expensive jobs.
Cancellation is a separate exact-run command with an explicit discard-proof
confirmation.

Run the complete declared offline suite on Windows with one command:

```powershell
pwsh -NoProfile -File tests/test-all.ps1
```

On Ubuntu, run `bash tests/test-all.sh`. The GitHub `verify` workflow runs the
same deterministic Bash set on Linux and the complete Bash plus PowerShell set
on Windows. A separate `windows-reviewer-safety` job repeats the Codex and Grok
reviewer suites in parallel so a Windows-only safety regression is reported
without waiting for the complete Windows matrix; the complete matrix remains
the authoritative all-test gate. New offline tests named `tests/test-*.sh` or
`tests/test-*.ps1` are discovered automatically in sorted order. Paid or live
provider qualification must live under `tests/probes/` and remains an explicit
release gate, never CI.

`tests/test-session-conduct-policy.sh` protects the bounded CI-waiting and
shared-infrastructure growth rules. Update that test with any deliberate change
to those standing rules; do not weaken it simply to shorten guidance.

### Running the suites concurrently on one machine

`tests/test-all.sh` and `tests/test-all.ps1` run one suite at a time, which is
correct but slow: the complete Windows set takes about 70 minutes, and the hosted
CI queue often adds more before a single test starts. For a local pre-check, run
the same suites, unchanged, across worker slots on this machine:

```bash
bin/ai-test-local
```

`--bash`, `--powershell` and `--reviewer` restrict it to one CI job's equivalent;
`-j N` sets the worker count. The Bash and PowerShell runners can also be called
directly as `tests/run-parallel.sh` and `tests/run-parallel.ps1`, and both accept
`--list` to show what would run.

On a machine that also hosts a CI runner, both entry points refuse to collide
with it. `bin/ai-test-local` checks once at start-up whether *this host's* runner
is busy and stops with exit 3 if it is; `--force` overrides and says so.
`tests/run-parallel.sh` additionally watches between suites and stops launching
more if a job arrives mid-series, because a 65-minute run started while idle will
otherwise be handed one. Both are per-host: a job on any other runner in the pool
never blocks you, and nothing here serialises the pool.

Measured on a 20-core desktop against current `main`: 58 Bash suites in 825
seconds of wall clock against 5560 seconds of suite time, and the 16 PowerShell
suites in 23 seconds instead of 38.

Three properties matter and are deliberate:

- **Nothing about the suites changes.** Same scripts, same assertions, same exit
  codes. Only the scheduling differs, so a local pass means the same thing a
  serial pass means. Assertions are never relaxed to make a parallel run green.
- **Every suite gets its own uniquely named log** under `.test-logs/`. A shared
  log once produced an interleaved file and a believed-but-false failure count;
  a unique log per suite is not optional.
- **Every suite gets its own short-pathed `TMPDIR`**, outside the log tree. This
  one cost an afternoon: temp directories were first placed under `.test-logs/`,
  which inside a worktree is already about 140 characters deep. Windows still
  caps most paths at 260 characters and the suites nest their own `mktemp` trees
  below `TMPDIR`, so writes failed silently and six healthy suites reported
  failures. The symptom looked exactly like load-induced flakiness and was not.
  `tests/test-ai-test-local.sh` now asserts the path budget.

### When a suite looks flaky

A suite that fails in a harness and passes on its own looks like a timing
problem, and that guess has been wrong here more often than right. Work these
checks in order before believing it.

1. **Reproduce with one suite alone.** Run the harness with `-p` narrowed to the
   single suite, nothing else running. If it still fails, it is not load, not
   concurrency and not a wall-clock budget, whatever the failure text implies.
   This one check would have saved an afternoon and a wrongly-filed issue
   (popcre/ai-devops#147, withdrawn).
2. **Compare the environment, not the timing.** Diff what the harness sets
   against a bare run: `TMPDIR`/`TMP`/`TEMP`, the working directory, whether
   stdout is a terminal, and any `AI_TEST_*` variable. Change one at a time.
3. **Check path length on Windows.** Most paths still cap at 260 characters and
   the suites build their own `mktemp` trees below `TMPDIR`. A temp root inside a
   worktree is already ~140 characters deep, which is enough to make writes fail
   silently and produce failure text that reads like anything but a path problem.
4. **Only then consider timing**, and fix the shape of the wait rather than the
   ceiling: derive the budget from a baseline measured on the machine running the
   test and poll for the condition (`tests/lib-test-timing.sh`, added by
   popcre/ai-devops#123 for issue #89).

Raising a timeout until nothing fails, marking a suite allowed-to-fail, or
deleting a check is symptom suppression, not a fix. A harness that invents
failures is worse than no harness, and a harness that hides them is worse again.

Failing suites are named at the end with their log path and their first `FAIL`
lines; rerun only those with `bash tests/run-parallel.sh --rerun-failed`. This is
a local pre-check, not a replacement for CI: GitHub remains the authority on
whether a branch is green, and the reviewer suites in particular must be proven
on the Windows runner.

Installer behavior has lightweight, dependency-free tests:

```bash
bash tests/test-ai-install-skills.sh
bash tests/test-ai-memory-sync.sh
bash tests/test-ai-qwen.sh
bash tests/test-codex-trigger-eval.sh
bash tests/test-installer-parity.sh
bash tests/test-ai-adopt-globals.sh
```

`tests/test-ai-adopt-globals.sh` covers `bin/ai-adopt-globals`, the wrapper that
replaces a machine's always-loaded globals **without losing its machine
section**. It proves the section is detected, saved and restored
byte-identically, that a machine with no section is handled without one being
invented, that `--dry-run` writes nothing, and that a timestamped copy of the
original is always recoverable.

`tests/test-installer-parity.sh` runs BOTH installers against one fixture and
compares the result: same files, byte-identical `.ai-devops-managed` markers, and
no phantom "local edits" when one installer refreshes the other's install. It
skips itself where `pwsh` is not installed. It is slower than the rest because it
hashes every installed file twice.

`tests/test-codex-trigger-eval.sh` is offline and calls no model. It pins the
Codex trigger runner's two hard rules (explicit `low`/`medium` effort, read-only
sandbox) and its trigger detection: an escaped Windows path in the event stream
must count, and the skill path appearing in a command's OUTPUT must not.

```powershell
pwsh -File tests/test-install-ai-devops-windows.ps1
pwsh -File tests/test-configure-claude-desktop-chrome-devtools.ps1
pwsh -File tests/test-configure-codex-chrome-devtools.ps1
pwsh -File tests/test-configure-codex-mcps.ps1
pwsh -File tests/test-mcp-env-launch.ps1
pwsh -File tests/test-memory-sync-scheduled-task.ps1
pwsh -NoProfile -File tests/test-context-audit.ps1
```

`tests/test-context-audit.ps1` also covers the context enforcement checks: each
of the eight locked safety categories failing on its own with a plain-English
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
