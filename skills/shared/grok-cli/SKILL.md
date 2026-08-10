---
name: grok-cli
description: Use xAI's Grok CLI (`grok`, branded Grok Build) as an independent coding agent via the `ai-grok-review` wrapper — read-only reviews, repository analysis, second opinions, session continuation, and the explicit implementation path. Use when the user says "use Grok", "ask Grok", "run this by Grok", "Grok CLI", "Grok Build", requests a Grok second opinion, asks where Grok is installed, or explicitly delegates coding work to Grok.
---

# Grok CLI

## Use `ai-grok-review`. Never call `grok` directly for a review.

```bash
ai-grok-review new <name> --prompt-file "$brief"     # start a review session
ai-grok-review ask <name> --prompt-file "$next"      # continue that same session
ai-grok-review list | show <name> | transcript <name> | delete <name>
ai-grok-review doctor
```

The wrapper owns the model pin, the read-only permission set, the turn bound, the
completion rule, the session bookkeeping, and the cost reporting. Every one of those
exists because getting it wrong cost real money: on 2026-08-05 a hand-composed Grok
delegation burned **~1.9M tokens and ~$1.28** across five sessions, two of which returned
nothing at all.

Do **not** run `grok --single`, `grok -p`, or `grok --resume` yourself for review work,
and do not try to reproduce the wrapper's flags by hand. It deliberately refuses to
forward arbitrary `grok` flags. **If it seems to be missing a capability you need, say so
— do not route around it.** That request is useful information; a hand-composed command
is a repeat of a known failure.

The command is identical on Windows and Ubuntu. On Windows run it from Git Bash (it is a
Bash script, like `ai-glm`).

## Continue a session. Do not start a new one per question.

Run `ai-grok-review list` first. If a session already covers this topic and repository,
continue it with `ask`. Measured on Grok 0.2.118: a resumed turn read **22,912 tokens
from cache** and answered from the earlier turn's context; a fresh session pays for all
of it again *and* gets context-free answers.

Name sessions after the work — `auth-rotation-review`, `grok-review-wrapper-plan` — never
`review` or `grok`.

Claude and Codex keep separate sessions. The session key includes the calling agent, so
both can use the same short name in one repo. **Set `AI_GROK_CALLER=codex` when running
from Codex**; it defaults to `claude`, so without this both clients collide on one record.

## Writing the brief

- Make it self-contained: the task, the repo and branch, relevant paths or errors, the
  constraints, and the evidence you want back. Tell Grok to read the repo's own
  `AGENTS.md`.
- **Do not paste file contents.** Grok reads files itself, and pasted text is prefix that
  changes every turn — the worst case for caching.
- Keep the opening of the brief stable across a workstream; put the new instruction last.
- Never include secrets, `.env` contents, credential files, or unrelated private data.
- Prefer `--prompt-file` over `--prompt` so quoting can never mangle a long brief.
- The wrapper appends a formatting instruction asking Grok to put its conclusion under a
  `## Verdict` heading, and extracts from there. You do not need to ask for that.

## Run a bounded debate

Use `templates/delegation/debate-turn.md` as the one provider-neutral message contract.
Run `ai-grok-review list`, reuse the exact named session with `ask`, and keep its opening
and headings stable. On each turn, faithfully relay the other model's actual reasoning,
point to the current plan or diff, add only changed evidence and objections, and require
Grok to re-read those paths before checking each claim as confirmed, unsupported, or
wrong. Keep the consensus ledger in the artifact current.

The default bound is the initial review plus at most three rebuttal turns. The default
total Grok ceiling is $1.50, including the initial turn. The parent skill enforces this
planning ceiling; the wrapper cannot stop a turn mid-spend. Measured on Grok 0.2.112 on
2026-08-10, resumed `total_cost_usd` is per-call, not cumulative. Add the reported value
after every turn exactly once. Estimate the next turn using the largest observed
per-turn cost in this session, or $0.46 before the first resume. Stop before the estimate
would cross the ceiling and report unresolved objections plainly.

Stop early only when Grok has re-read the current files and evidence and says no material
objection remains. Also stop at the turn bound or cost ceiling. Agreement by itself is
not consensus. Never broaden permissions, change the frozen prefix, start a new session,
or run an unbounded loop to force convergence.

## Reading the result

`ai-grok-review` prints the extracted answer on stdout and a usage line on stderr
(`tokens: … cached: … turns: … cost: $… model: …`). Grok is the only delegate CLI that
reports real money — **record the cost in your report**. `--json` gives the raw result.
A review is also saved under `.ai/reviews/` when that path is git-ignored.

Expect real reviews to cost **250,000–530,000 tokens and $0.12–$0.46 per turn**. If you
have seen a figure like "43k tokens per review," that came from a one-question probe and
is an order of magnitude low.

## When a run stops without an answer

The wrapper tells you which case you are in and what to do. The one thing to internalise:

> **A denied tool does not cancel a run.** With Bash denied, Grok says "Shell is blocked,
> so I'll stick to file reads and greps" and finishes using its other tools. If a review
> ends with no verdict, the cause is almost always the **turn limit**, not permissions.
> Never broaden permissions chasing it — that is the wrong lever and it also throws away
> the cached prefix.

Recovery is an `ask` on the same session with a higher `--max-turns`, which the error
message spells out for you. Cancellation is different: an empty resumed run after a
cancellation is a known 0.2.112/0.2.118 behaviour, so start a fresh session rather than
retrying that one.

## Verifying the install

`ai-grok-review doctor` resolves the binary, prints the version, and checks auth for free.

**`grok doctor` is not an auth check.** It checks "terminal, clipboard, color, and input
support" — which is why it once reported "You are not authenticated" while `grok models`
and real calls worked. Never tell Albert to log in based on `grok doctor` alone.

Grok's home is `~/.grok/` — config, docs, sessions, logs, credentials. **Never read or
print `~/.grok/auth.json`.** The installed docs match the installed version and are worth
consulting for anything below: `~/.grok/README.md`,
`~/.grok/docs/user-guide/14-headless-mode.md`, `17-sessions.md`,
`22-permissions-and-safety.md`, `18-sandbox.md`, `~/.grok/CHANGELOG.md`. Also
`grok --help` — the CLI surface changes between versions, so re-verify rather than
trusting any statement here, **including this one**.

## Implementation runs — the one path still driven by hand

`ai-grok-review` is read-only by design. Use implementation mode **only when the user
explicitly asks Grok to edit code**, and drive it directly:

```bash
grok --cwd "$repo" --worktree=grok-task --model grok-4.5 --prompt-file "$brief" \
     --max-turns 20 --permission-mode auto --output-format json --no-memory > "$out"
```

Record `git status` first and preserve unrelated work. Use `--worktree=<name>` with `=`.
Repeat every branch, database, production, destructive-action, and test constraint inside
the prompt. Because you are hand-composing here, the wrapper's protections do **not**
apply: pass `--max-turns` yourself, and do not trust exit status — wait for valid JSON
carrying a terminal `stopReason` before believing the run finished.

**Cleanup is a gate, not a suggestion.** In the same task, after extracting the diff:

```bash
grok worktree remove grok-task            # Grok's own command, not `git worktree`
grok worktree list                        # MUST no longer list grok-task
```

If it still appears, say so loudly and stop; do not report the task finished. Do not
assume `git worktree prune` clears Grok's bookkeeping.

On Windows, do not claim `--sandbox read-only` protects a run: the installed docs list OS
sandbox enforcement for Linux and macOS only. Permission rules are the control there.

## Reporting

Label Grok's conclusions separately from your own judgment. For implementation, report the
files actually changed and test results **you** verified. Treat a nonzero exit, auth
error, missing response, permission violation, or unexpected working-tree change as
failure — and never let Grok commit, push, merge, deploy, alter shared databases, or touch
production unless the user separately authorized that exact action.
