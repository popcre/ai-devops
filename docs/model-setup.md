# Model Setup

How to adapt the model **commands** to your machine. For the full list of
`models.env` variables and where config lives, see
[`configuration.md`](configuration.md) — that is the canonical config reference
and is not duplicated here. This doc focuses on the model-specific concerns:
roles, adapting CLI flags, and how the scripts use the commands.

## The model workflow (roles)

- **GPT-5.6-Sol / Codex (medium reasoning)** — planning, implementation, testing,
  and fixing. Only implementation and testing receive workspace write access.
- **Claude Opus 5** — independent plan, diff, security, and final approval
  reviews through a tool-limited, digest-bound adapter.
- **GLM-5.3** — optional independent second opinion invoked by either Claude or
  Codex through `ai-glm`, in named persistent sessions; defaults to read-only review.

## GLM configuration

GLM is deliberately separate from the staged `models.env` commands. The model
and agent behaviour are pinned in `config/opencode/agent/*.md`; the only GLM
entry in the managed `~/.config/ai-devops/mcp.env` (copied from
`config/mcp.env.example`) is the key reference:

- `ZAI_API_KEY=op://vibe_coding/GLM z.ai API/api key`

That is a 1Password reference, not a key. Do not put the resolved value in this
repo or in Claude/Codex settings. `bin/setup-opencode-glm.sh` installs a
launcher that resolves it at exec time and exports it as `ZHIPU_API_KEY`, which
is what OpenCode's built-in `zai-coding-plan` provider reads. `ai-glm` refuses a
silently substituted model.

There is no local GLM server on Windows. Windows Claude and Codex sessions run
`ai-glm` on the Ubuntu host over the normal SSH workflow.

## Kimi Code on Windows

`ai-kimi` uses `KIMI_CODE_HOME` for Kimi's own data. That directory holds both
OAuth sign-in material and Kimi sessions, so it is credential-bearing. Keep its
normal user-only permissions. Do not point it into a repository, worktree, or
shared writable folder.

Before any Kimi review, the wrapper tests its own state folder, the effective
Kimi home, the read-only review profile, and provider availability. A restricted
task that cannot pass receives `execution-context-denied` and must send the same
request to the Full Access main task. It must not retry, change permissions, or
copy credentials.

## Important: the exact flags may differ on your machine

The Claude/Codex CLIs evolve. The installed configuration is validated against
the safety contract before use; do not remove an explicit sandbox, allowed
reasoning level, Claude model pin, or Claude tool restriction.

To find the right flags:

```bash
claude --help
codex --help
```

Then update the `*_CMD` variables to whatever actually works, e.g. swapping the
model id or the reasoning flag. The scripts always read the real file at
`/etc/ai-devops/models.env`, so your edits take effect immediately.

## How the scripts use these

- `ai-run-task start "task"` creates an immutable run; `ai-run-task run <dir>`
  executes all seven stages and `resume` verifies every prior artifact first.
- `ai-model-call <stage> <prompt> <out>` runs one atomic stage without shell
  evaluation.
- `ai-review claude <mode>` and `ai-review codex <mode>` are the only supported
  approval front doors. Other provider tools remain advisory or quarantined.
- `ai-codex-review <mode>` uses `CODEX_CMD` for read-only reviews and refuses
  configuration that does not explicitly retain `--sandbox read-only` plus
  `model_reasoning_effort=low` or `medium`.

Live capability probes on 2026-08-21 proved `claude-opus-5` and
`gpt-5.6-sol`. The rejected generic `gpt-5.6` identifier is not used.
