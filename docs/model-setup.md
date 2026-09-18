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
- **Grok Build 4.6** — optional independent review through `ai-grok-review`
  (read-only) and isolated edits through `ai-grok-implement`. Advisory
  look-into-this work uses `ai-grok-implement investigate`; that is not a formal
  pass.

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

## Grok Build

Grok is pinned to one exact CLI build in `config/provider-cli-versions.json`
(currently 1.0.13). Both wrappers refuse paid work against any other build.

- Formal review: `ai-grok-review`. Bash and web search stay denied. Investigation
  is not added to this command.
- Isolated edits: `ai-grok-implement run`. Bash stays denied unless you pass
  `--allow-shell`.
- Look-into-this: `ai-grok-implement investigate <name> --repo <path> --prompt-file <f>`.
  This reuses the isolated copy with the shell allowed. The report is labeled
  `INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL`. It is not issue #249.
  On pin 1.0.13, live Windows headless Bash currently returns cancelled for
  both this command and `run --allow-shell`. Offline tests prove the flags.

Never call `grok` directly for these jobs.

## ZCode (Windows)

ZCode is the third INTERACTIVE client (a Z.AI GLM-5.3 desktop agent, winget
`ZhipuAI.ZCode`), not a reviewer and not a pipeline stage. It receives the
Claude/Codex per-client treatment on Windows only: managed skills
(`~/.zcode/skills` from `skills/zcode` + `skills/shared`), a seeded
`~/.zcode/AGENTS.md` (`ai-adopt-globals` replaces it with machine-section
preservation), MCP servers in `~/.zcode/cli/config.json` via
`bin/configure-zcode-mcps.ps1`, and the completion-check hook via
`bin/ai-install-completion-check-hook --client zcode`.

- **Headless driving:** `ai-zcode ask "<prompt>"` — the governed wrapper
  (`bin/ai-zcode`). Never call the zcode.cjs bundle directly: without the
  provider-env assembly every headless run dies before the model call, and
  `--prompt` defaults to yolo mode. Health: `ai-zcode doctor [--live]`.
- **No ZCode reviewer, ever** (owner ruling 2026-09-17: GLM never reviews
  GLM-orchestrated work; ZCode's engine is GLM-5.3). GLM review capacity for
  Claude/Codex-orchestrated work stays with the `glm` OpenCode wrapper.
- **Traps:** the MCP schema is strict (one unknown key silently drops a
  server; `command` is a string, absolute paths only, no `${...}` expansion);
  config-file hooks never run unless `hooks.enabled: true`; the CLI's
  `--help` advertises flags its own parser rejects (`--max-turns`,
  `--settings`, `--allowed-tools` on 0.16.5) — the wrapper pins what is
  proven; two version numbers exist (desktop app + CLI core) and it
  self-updates, so nothing is pinned. Qualification facts:
  `tests/verification/zcode-windows-2026-09-17/README.md`.
- **Transcripts:** ZCode keeps sessions in SQLite (`~/.zcode/cli/db/`) +
  rollout JSONL; back them up and mine them by SQL with the
  `zcode-transcript-backup` skill (private repo destination only).

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
