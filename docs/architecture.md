# Architecture

System design of the AI DevOps toolkit. For the canonical operating guide and
documentation router, see [`../AGENTS.md`](../AGENTS.md).

## What this is

A set of Bash CLI tools that orchestrate a **staged, multi-model coding
workflow**. There is no server, database, or long-running process — every tool is
a script you run from the shell (installed as symlinks in `/usr/local/bin`).

## Components

| Component | File(s) | Responsibility |
|---|---|---|
| Control command | `bin/ai-devops` | `doctor` (health checks), `version`, `paths` |
| Workspace safety | `bin/ai-workspace-status` | Read-only git/branch/PR/dirty snapshot + warnings |
| Second-opinion review | `bin/ai-codex-review` | Read-only Codex review; writes `.ai/reviews/<ts>-<mode>.md` |
| Model invocation | `bin/ai-model-call` | Maps a stage name → `*_CMD` from `models.env`, pipes a prompt in, writes output (v0.1) |
| Task scaffold | `bin/ai-run-task` | Creates `.ai/runs/<ts>-<slug>/`, records request + workspace status (v0.1, no code edits) |
| Lifecycle | `install.sh`, `update.sh`, `uninstall.sh` | Install/update/remove the toolkit on a host |
| Prompts | `templates/prompts/01..07` | One Markdown prompt per workflow stage |
| Config seed | `config/*.env.example` | Seeds `/etc/ai-devops/*.env` on install |

## The staged workflow

Seven stages, mapped to models via `/etc/ai-devops/models.env`:

1. **Plan** — Opus 4.8 (high reasoning) — `01-opus48-plan.md`
2. **Plan review** — Opus — `02-opus-plan-review.md`
3. **Implement** — GPT-5.5 / Codex — `03-gpt55-implement.md`
4. **Diff review** — Opus — `04-opus-diff-review.md`
5. **Test** — GPT-5.5 / Codex — `05-gpt55-test.md`
6. **Security review** — Opus — `06-opus-security-review.md`
7. **Final review** — Opus 4.8 (high reasoning) — `07-opus48-final-review.md`

Review stages are **read-only**; implementation/test stages make the smallest
safe change and add tests. (Fable is not used anywhere — planning and final
review use Opus 4.8 high reasoning.)

## Data flow of a task run

```
ai-run-task "task"
  └─ creates .ai/runs/<ts>-<slug>/
       ├─ 00-user-request.md        (the task)
       └─ 01-workspace-status.txt   (ai-workspace-status snapshot)

per stage:
  ai-model-call <stage> <prompt-file> <out-file>
       └─ reads models.env → picks *_CMD → pipes prompt on stdin → writes <out-file>

review gates:
  ai-codex-review <mode>
       └─ gathers git diff / plan → CODEX_CMD (read-only) → .ai/reviews/<ts>-<mode>.md
```

Run/review artifacts (`.ai/runs/`, `.ai/reviews/`) are created **inside the
target application repo**, not in this toolkit repo, and are git-ignored.

## Delegate debate continuity

Grok, GLM, and Kimi debates use the provider-neutral
`templates/delegation/debate-turn.md` contract. The parent agent reuses one
named provider session, points it to current files, relays the other model's
actual reasoning, and keeps a consensus ledger. The wrapper keeps provider
identity, permissions, and cache-relevant settings stable; ordinary turn text
carries only changed evidence and objections. A debate stops on verified
consensus, its turn bound, or its cost bound, with unresolved objections stated
plainly.

Kimi resumes an explicit named session but reports no context, cache, token, cost,
or returned-model data in headless mode. Its parent therefore treats session reuse
as transport continuity only. Every material turn re-reads current artifacts, and
the plan's consensus ledger is the durable source after automatic context compaction.
Kimi implementation runs use a wrapper-owned disposable worktree with an owner record,
export the final tree against the original base even if Kimi commits, and clean up from
one lifecycle trap. The implementation profile removes named web and subagent tools,
but its Bash tool can reach the network. That is a documented accepted limit, not a
network sandbox.

All three delegate wrappers identify repositories from the normalized root path plus
the origin URL and keep caller names separate. Metadata files are atomic and private on
Unix. Legacy path-only Grok and Kimi records migrate when first opened.

## Configuration boundary

Scripts read machine-local config from `/etc/ai-devops/{models.env,server.env}`.
The repo only ships `*.env.example`. `install.sh` seeds the real files once and
never overwrites them. See [`configuration.md`](configuration.md).

## Constraints

- Pure Bash + coreutils + `git`, `jq`, `rg`, `gh`, and the `claude`/`codex` CLIs.
- No network services, no database, no containers.
- Reviews must never mutate the repo.
- Host paths are fixed: `/worksp/ai-devops`, `/etc/ai-devops`,
  `/var/log/ai-devops`, `/usr/local/bin`. Never `/opt/ai-devops`.
