# Architecture

## Grok review concurrency safety

Grok reviews are not globally or repository-wide serialized. The wrapper uses
normalized upstream identity only as one input to two narrower controls:

- an exact-session ownership lock serializes mutation, continuation,
  cancellation, and finalization for one caller and named conversation;
- a digest-keyed exact-work record deduplicates one immutable provider call
  across equivalent clones and worktrees.

Stopped or cancellation-uncertain calls retain only their exact-work protection.
The metadata stores prompt and evidence digests, never raw prompt text, tokens,
credentials, environment values, or process command lines. Independent reviews
may run concurrently in the same logical repository.

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
| Approval review | `bin/ai-review`, `bin/ai-claude-review`, `bin/ai-codex-review` | Exact-source, lifecycle-accounted Claude Opus 5 or Codex approval |
| Model invocation | `bin/ai-model-call` | Runs one stage with validated arguments and atomic output; never shell-evaluates config |
| Task orchestrator | `bin/ai-run-task` | Immutable seven-stage manifest, artifact chain, fail-closed resume and retry |
| Lifecycle | `install.sh`, `update.sh`, `uninstall.sh` | Install/update/remove the toolkit on a host |
| Prompts | `templates/prompts/01..07` | One Markdown prompt per workflow stage |
| Config seed | `config/*.env.example` | Seeds `/etc/ai-devops/*.env` on install |

## The staged workflow

Seven stages, mapped to models via `/etc/ai-devops/models.env`:

1. **Plan** — GPT-5.6 / Codex, read-only, medium reasoning — `01-opus48-plan.md`
2. **Plan review** — Claude Opus 5 — `02-opus-plan-review.md`
3. **Implement** — GPT-5.6 / Codex, workspace-write, medium — `03-gpt55-implement.md`
4. **Diff review** — Claude Opus 5 — `04-opus-diff-review.md`
5. **Test** — GPT-5.6 / Codex, workspace-write, medium — `05-gpt55-test.md`
6. **Security review** — Claude Opus 5 — `06-opus-security-review.md`
7. **Final review** — Claude Opus 5 — `07-opus48-final-review.md`

Review stages receive only read/search tools in a complete disposable snapshot.
Implementation/test stages make the smallest safe change and add tests.

## Data flow of a task run

```
ai-run-task start "task"
  └─ creates .ai/runs/<ts>-<slug>/
       ├─ 00-user-request.md
       ├─ manifest.json             (source + artifact hashes, model roles, status)
       ├─ prompts/                  (exact per-stage prompt artifacts)
       └─ 01..07 outputs            (each consumes the prior named output)

ai-run-task run <run-directory>
  └─ stops on failure, source drift, changed artifacts, or non-APPROVE review
```

Run/review artifacts (`.ai/runs/`, `.ai/reviews/`) are created **inside the
target application repo**, not in this toolkit repo, and are git-ignored.

## Planned reviewer-assisted problem solving

Issue #198 will add a provider-neutral route for a Claude or Codex session that
has exhausted multiple evidence-based diagnostic attempts. The implementation
contract, safety boundaries, tests, and live-installation gates are in the
[`reviewer-assisted problem-solving plan`](../plan_reviewer-assisted-problem-solving.md).
Until its STATUS table proves completion, existing provider skills remain the
only implemented route; do not infer proactive selection from this pointer.

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

Windows review submission has a second, durable lifecycle. `start` preflights the
current process's access to the credential-bearing `KIMI_CODE_HOME`, writes an
allowlisted job record, and launches a hidden worker. `wait` is only an observer:
losing it does not cancel the worker. `status`, `logs`, `result`, `cancel`, and
`recover` operate on the same job record. Only a terminal `session.resume_hint`
allows `completed`; every other unproven worker exit is a failed or recovery-needed
state.

Every named read-only Kimi review uses one private self-contained snapshot, even when
the source is an ordinary clone. The same directory is refreshed and reused for later
turns because Kimi binds sessions to their creation directory. Source-checkout edits
during a review mark its evidence stale without being misreported as Kimi writes.
Callers select `diff`, `plan`, `architecture`, or `analysis`: only `diff` receives the
patch-verdict contract. Large Kimi patches are exposed as ordered 40 KB parts while the
complete sealed patch remains available.

All three delegate wrappers identify repositories from the normalized root path plus
the origin URL and keep caller names separate. Metadata files are atomic and private on
Unix. Legacy path-only Grok and Kimi records migrate when first opened.

## Configuration boundary

Scripts read machine-local config from `/etc/ai-devops/{models.env,server.env}`.
The repo only ships `*.env.example`. `install.sh` seeds the real files once and
never overwrites them. See [`configuration.md`](configuration.md).

## Constraints

## Shared reviewer evidence contract

Every active reviewer name—Grok, Kimi, GLM, Muse, Gemini, Qwen, Codex, and
DeepSeek—is registered with preflight and the scoreboard. Unsupported metadata
is represented as missing, never invented. Scoreboard evidence is
`current`, `stale`, or `unknown`; only a current verdict is usable. Packets seal
each relative file name, byte length, and digest. `ai-review-sandbox` publishes
only after the committed tree, tracked binary diff, and NUL-safe untracked-file
inventory produce the same whole-source digest before and after the copy.
`ai-review-lifecycle` owns normalized upstream identity, one assignment lock,
preflight, running/terminal state, stale-source rejection, report hashing, and
scoreboard append. Provider adapters own only their provider call and response
parsing. Incident reports consume that lifecycle state so copied evidence joins
the exact provider, repository, commit, source digest, run/session, and caller.

- Pure Bash + coreutils + `git`, `jq`, `rg`, `gh`, and the `claude`/`codex` CLIs.
- No network services, no database, no containers.
- Reviews must never mutate the repo.
- Host paths are fixed: `/worksp/ai-devops`, `/etc/ai-devops`,
  `/var/log/ai-devops`, `/usr/local/bin`. Never `/opt/ai-devops`.
