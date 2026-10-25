# Configuration

All machine-local configuration for the toolkit. Canonical guide:
[`../AGENTS.md`](../AGENTS.md). Model-command tuning specifics:
[`model-setup.md`](model-setup.md) (not duplicated here).

## Where config lives

| File | Seeded from | Purpose |
|---|---|---|
| `/etc/ai-devops/models.env` | `config/models.env.example` | Model command strings per stage |
| `/etc/ai-devops/server.env` | `config/server.env.example` | Machine-local paths and settings |

`install.sh` copies each example into `/etc/ai-devops/` **only if the real file
does not already exist**, so your edits survive `update.sh` and re-installs. The
repo only ever contains the `*.env.example` files — never the real ones.

`config/config-schema.json` versions the required secret-free keys. Every
install runs `ai-config-migrate`: it previews or adds only missing safe defaults,
preserves existing values, validates assignment/command syntax, writes a
restricted hash-verified backup before a change, and records the applied schema
and source SHA in `/etc/ai-devops/config-state.json`.

There are **no secrets** in these files. Model access comes from the Claude/Codex
CLI login sessions (`~/.claude`, `~/.codex`), not from variables here.

## `models.env` variables

Command strings the scripts invoke per stage. See [`model-setup.md`](model-setup.md)
for how to adapt the exact flags to your installed CLIs (they may differ).

| Variable | Used by | Default |
|---|---|---|
| `AI_DEVOPS_HOME` | path resolution | `/worksp/ai-devops` |
| `CLAUDE_REVIEW_CMD` | governed plan/diff/security/final review | Claude Opus 5, JSON output, `Read,Grep,Glob` only, plan permission mode, no ambient MCP |
| `CODEX_PLAN_CMD` | `ai-model-call plan` | `gpt-5.6-sol`, read-only sandbox, medium reasoning |
| `CODEX_IMPLEMENT_CMD` | `ai-model-call implement` | `gpt-5.6-sol`, workspace-write sandbox, medium reasoning |
| `CODEX_TEST_CMD` | `ai-model-call test` | `gpt-5.6-sol`, workspace-write sandbox, medium reasoning |
| `CODEX_CMD` | `ai-codex-review` | `gpt-5.6-sol`, read-only sandbox, medium reasoning |

Command values are parsed as argument lists, not evaluated by a shell. Shell
operators and expansions are rejected. Review commands cannot remove their
explicit model, tool, permission, sandbox, or reasoning protections.

## `server.env` variables

| Variable | Used by | Default | Notes |
|---|---|---|---|
| `AI_DEVOPS_HOME` | path resolution | `/worksp/ai-devops` | Never `/opt/ai-devops` |
| `AI_DEVOPS_ETC` | reference | `/etc/ai-devops` | Where these files live |
| `AI_DEVOPS_LOG_DIR` | reference | `/var/log/ai-devops` | Created on install; not yet written to by scripts |
| `WORKSPACE_ROOT` | reference | `/worksp` | Where app repos live (onboarding) |
| `DEFAULT_MAIN_BRANCH` | `ai-workspace-status` | `main` | Branch name used for the "on main" safety warning |
| `OWNER_NAME` | final-review prompt | `Albert` | Name used in plain-English summaries |

## Private portable-memory settings

`bin/ai-memory-sync` has safe built-in defaults and accepts these process-level
overrides for controlled tests or machine migration. They are not secrets.

| Variable | Purpose | Default |
|---|---|---|
| `AI_MEMORY_REMOTE` | Canonical private Git remote | SSH (`git@github.com:u2giants/ai-devops-memory.git`) when an SSH key exists, else HTTPS |
| `AI_MEMORY_HUB` | Isolated private clone | `~/.cache/ai-devops-memory-private` |
| `AI_MEMORY_LOG` | Append-only status log | `~/.cache/ai-memory-sync.log` |
| `AI_MEMORY_STAMP` | Last successful round trip, used by `sync-if-stale` | `~/.cache/ai-memory-sync.last-success` |
| `AI_MEMORY_MAX_AGE_HOURS` | Maximum age before `sync-if-stale` runs a full round trip | `24` |
| `AI_MEMORY_HEALTH_STATE` | Prior health report used to show the next audit trend | `~/.cache/ai-memory-health.trend` |
| `AI_MEMORY_CLAUDE_PROJECTS` | Physical `projects` path (set automatically after resolving a Windows junction) | `$CLAUDE_HOME/projects` via `bin/ai-winpath` |

Production runs reject any remote other than the canonical private repository
and prove it is private before copying machine memory: unauthenticated HTTPS
must not reach the hub, and the configured remote must. That works over SSH,
where Git Credential Manager's wincredman store cannot persist and gh OAuth is
session-isolated. Tests replace the visibility read through `ai-gh`. Test flags
are accepted only by the behavioral fixture and must never appear in machine
configuration.

On Windows, `~/.claude/projects` may be a junction to another volume (disk
housekeeping). Interactive Claude follows it; SSH sessions hit
`ERROR_UNTRUSTED_MOUNT_POINT`. `bin/ai-winpath` resolves the physical target so
sync, health, and Python tools see the same memory without a per-run override.

## Feature flags

None. There are no feature flags in this toolkit.

## Reviewer capacity checks

`config/reviewer-capacity.json` is the secret-free qualification policy for
non-generating capacity checks. The shared defaults are one request, no retry,
and a five-second maximum. Machine overrides may point
`AI_REVIEW_CAPACITY_CONFIG` at an equally strict policy and may lower
`AI_REVIEW_CAPACITY_TIMEOUT`; they may not turn an unqualified endpoint into
capacity truth. Unsupported interfaces return `unknown` without network access.
`AI_REVIEW_CAPACITY_MAX_AGE` defaults to 30 seconds. Optional
`AI_REVIEW_CAPACITY_EXPECTED_PROFILE` and `AI_REVIEW_CAPACITY_EXPECTED_MODEL`
make a supported adapter reject a result scoped to another account or model.

## Carried review questions

`AI_REVIEW_BRIEF_FILE` carries the caller's specific review question, including
the stage request supplied by `ai-model-call`. The approval pool forwards it
through the shared runner's existing prompt-file contract and includes it in
native GLM requests. It supplements the standard review instructions; source
identity, sandbox boundaries, accounting, and verdict checks remain mandatory.

Use a readable regular file containing nonempty UTF-8 text, without NUL bytes,
at most 2 MiB. The pool rejects missing, linked, non-regular, changing, or
invalid inputs before lifecycle/provider startup and captures a private snapshot
so later caller edits cannot change the question. Keep secrets and private or
licensed data out of review questions. A supplied question always requests a
fresh review; a generic passing report is never reused to answer it. Calls
without a question retain normal passing-report reuse.

## Kimi wrapper settings

These are process settings for `ai-kimi`, not entries to add to committed config:

| Variable | Purpose | Default |
|---|---|---|
| `KIMI_CODE_HOME` | Kimi OAuth, sessions, and logs. Treat as credential-bearing. | `~/.kimi-code` |
| `AI_KIMI_STATE_DIR` | Wrapper-owned session and durable job records. | `~/.local/state/ai-devops/kimi` |
| `AI_KIMI_WAIT_TIMEOUT` | Full wall limit for the exact Kimi child. Ending a foreground waiter does not end the durable worker. | `900` seconds |
| `AI_KIMI_STARTUP_TIMEOUT` | Startup diagnostic bound. | `60` seconds |
| `AI_KIMI_HEARTBEAT_INTERVAL` | Bounded job-status heartbeat interval. | `30` seconds |

Durable review records are under `AI_KIMI_STATE_DIR/jobs/`. They contain only
allowlisted job identity and status fields, never a prompt, environment dump,
OAuth value, or credential-file details.

## GLM coding-agent settings

The cross-platform GLM launcher reads these managed entries from
`~/.config/ai-devops/mcp.env`, seeded from `config/mcp.env.example`:

| Variable | Purpose | Default/source |
|---|---|---|
| `ZAI_API_KEY` | Coding Plan authentication. Exported as `ZHIPU_API_KEY` for OpenCode's built-in `zai-coding-plan` provider | 1Password reference only; never plaintext |
| `AI_GLM_PORT` | Loopback port for the OpenCode GLM server | `4096` |
| `AI_GLM_CALLER` | Which assistant owns the session (`mimo`, `claude`, `codex`, `zcode`, or another path-safe name) | Auto-detected from the running harness; required when detection is ambiguous |
| `AI_GLM_DIAGNOSTIC_HEALTH_TIMEOUT` | One bounded local health observation before a review. It preserves the prior launch tolerance. | `30` seconds |

The GLM model, agent, tools, and permissions are pinned in `config/opencode/`,
not in environment variables. See [glm-opencode.md](glm-opencode.md).

These settings do not alter normal Claude or Codex configuration. Change the
model or endpoint in the repo example and rerun machine setup; never hard-code
the key.

## Changing configuration

1. Edit the real file directly: `sudoedit /etc/ai-devops/models.env` (or
   `server.env`). Changes take effect on the next script run.
2. If you add a **new** variable, also add it to the matching
   `config/*.env.example` and to this doc, so fresh installs get it.
3. Never edit the `*.env.example` files with real per-machine values, and never
   commit a real `.env`.

Preview and validate a migration without changing the machine:

```bash
ai-config-migrate --dry-run
```
