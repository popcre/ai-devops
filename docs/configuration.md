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

## Feature flags

None. There are no feature flags in this toolkit.

## GLM coding-agent settings

The cross-platform GLM launcher reads these managed entries from
`~/.config/ai-devops/mcp.env`, seeded from `config/mcp.env.example`:

| Variable | Purpose | Default/source |
|---|---|---|
| `ZAI_GLM_MODEL` | Exact model required from Z.ai | `glm-5.2` |
| `ZAI_ANTHROPIC_BASE_URL` | Isolated Claude Code provider endpoint | `https://api.z.ai/api/anthropic` |
| `ZAI_API_KEY` | Coding Plan authentication | 1Password reference only; never plaintext |

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
