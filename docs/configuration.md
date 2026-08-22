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

There are **no secrets** in these files. Model access comes from the Claude/Codex
CLI login sessions (`~/.claude`, `~/.codex`), not from variables here.

## `models.env` variables

Command strings the scripts invoke per stage. See [`model-setup.md`](model-setup.md)
for how to adapt the exact flags to your installed CLIs (they may differ).

| Variable | Used by | Default |
|---|---|---|
| `AI_DEVOPS_HOME` | path resolution | `/worksp/ai-devops` |
| `OPUS48_HIGH_REASONING_CMD` | `ai-model-call plan`, `ai-model-call final` | `claude --model opus-4.8 --reasoning high` |
| `OPUS_REVIEW_CMD` | `ai-model-call plan-review`/`diff-review`/`security` | `claude --model opus-4.8 --reasoning high` |
| `GPT55_CMD` | `ai-model-call implement` | `codex exec --skip-git-repo-check` |
| `CODEX_CMD` | `ai-codex-review` | `codex exec --skip-git-repo-check` |
| `TESTER_CMD` | `ai-model-call test` | `codex exec --skip-git-repo-check` |

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
| `AI_MEMORY_REMOTE` | Canonical private Git remote | `https://github.com/u2giants/ai-devops-memory.git` |
| `AI_MEMORY_HUB` | Isolated private clone | `~/.cache/ai-devops-memory-private` |
| `AI_MEMORY_LOG` | Append-only status log | `~/.cache/ai-memory-sync.log` |

Production runs reject any remote other than the canonical private repository
and use GitHub's API to prove `private=true` before copying machine memory. Test
flags are accepted only by the behavioral fixture and must never appear in
machine configuration.

## Feature flags

None. There are no feature flags in this toolkit.

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
| `AI_GLM_CALLER` | Which agent owns the session (`claude` or `codex`) | `claude` |

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
