---
name: grok-cli
description: Use xAI's Grok CLI (`grok`, branded Grok Build) as an independent coding agent via the `ai-grok-review` wrapper — read-only reviews, repository analysis, second opinions, session continuation, and the explicit implementation path. Use when the user says "use Grok", "ask Grok", "run this by Grok", "Grok CLI", "Grok Build", requests a Grok second opinion, asks where Grok is installed, or explicitly delegates coding work to Grok.
---

# Grok CLI

While [ai-devops issue #56](https://github.com/u2giants/ai-devops/issues/56) is open, read the STATUS table in `plan_grok-review-concurrency-cancellation-observability.md` before changing concurrency, cancellation, active-run listing, progress output, or reviewer-issue evidence capture.

## Use `ai-grok-review`. Never call `grok` directly for a review.

```bash
ai-grok-review new <name> --prompt-file "$brief"     # start a review session
ai-grok-review ask <name> --prompt-file "$next"      # continue that same session
ai-grok-review list | show <name> | transcript <name> | delete <name>
ai-grok-review doctor
```

`list` shows paid Grok work across every clone on the computer, while completed
sessions remain limited to the current checkout. Equivalent GitHub HTTPS, SSH,
case, `.git`, and local-clone origins share one paid-work lock. If a local wrapper
is interrupted, do not start another review: provider cancellation is unconfirmed
and the retained lock deliberately blocks another charge until a human reconciles it.
The configured wait ceiling also stops a hung local Grok process; because that
still does not prove remote cancellation, the same paid-work block remains.
`delete` refuses an active session and never deletes Grok's provider-side history.
Long turns print elapsed-time heartbeats; these prove only that the local wrapper is
still waiting, not that the provider is active.

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

> **A denied tool does not cancel a run.** With Bash denied, Grok can finish using its
> read and search tools. If a review reaches the turn ceiling without a verdict, do not
> broaden permissions and do not automatically raise `--max-turns`. Diagnose a vague
> brief, an oversized change, or reviewer wandering; then start a fresh session with a
> smaller exact scope. Cancellation is different: an empty resumed run after a
> cancellation is a known 0.2.112/0.2.118 behaviour, so start a fresh session rather than
> retrying that one.

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

## Implementation runs — use `ai-grok-implement`. Never hand-compose one.

`ai-grok-review` is read-only by design. When the user **explicitly asks Grok to edit
code**, use the companion wrapper:

```bash
ai-grok-implement run <name> --repo <path> --prompt-file "$brief" [--ref <ref>] [--max-turns 20]
ai-grok-implement cleanup <name> [--force]
ai-grok-implement list | doctor
```

It creates the isolated worktree itself with `git worktree add`, bases it on `origin/main`
by default, converts every path to native Windows form, keeps the brief inside the
worktree, validates the JSON, exports the diff to a location that outlives the worktree,
proves the primary checkout is unchanged, verifies removal in both ledgers, and reports
the cost. On success it exits 0 and prints the raw JSON; on any failure it exits nonzero
and **preserves the worktree** so unique work is never silently deleted.

### Why hand-composing is banned

`grok --worktree=<name>` is **accepted and silently ignored in headless mode**
(measured on Grok 0.2.112, Windows, 2026-08-12). No error, no warning, no exit-status
signal. Grok then runs in whatever `--cwd` points at — the primary checkout. On
2026-08-12 that checkout was on a stale detached HEAD, so `read_file` and `list_dir`
returned ordinary `NotFound` errors for paths that only existed on `origin/main`, and
three runs died for ~$0.59 with no changes.

Three more facts that make hand-composed commands wrong:

- **`--cwd` takes a NATIVE path.** `grok --cwd /c/repos/x` fails with
  `Failed to set working directory ... (os error 3)`. Git Bash usually rewrites a lone
  `/c/...` argument, but that is a heuristic, not a contract.
- **`--permission-mode auto` can end a run.** An auto-cancelled `run_terminal_command`
  produces `stopReason: "Cancelled"` and no diff. An explicit `--deny` does not — Grok
  reports it and works around it. The wrapper uses `acceptEdits` plus explicit
  allow/deny rules, never `auto`.
- **`grok worktree remove` does not exist.** The subcommand is `grok worktree rm <IDS>...`.
  And `grok worktree list` only ever lists worktrees Grok itself created, so after a
  headless run it is always empty — its emptiness proves nothing on its own. The wrapper
  checks the git ledger and the directory too.

Repeat every branch, database, production, destructive-action, and test constraint inside
the prompt. Never trust exit status: only valid JSON with a terminal `stopReason` counts.

On Windows, do not claim `--sandbox read-only` protects a run: the installed docs list OS
sandbox enforcement for Linux and macOS only. Permission rules are the control there.

## Reporting

Label Grok's conclusions separately from your own judgment. For implementation, report the
files actually changed and test results **you** verified. Treat a nonzero exit, auth
error, missing response, permission violation, or unexpected working-tree change as
failure — and never let Grok commit, push, merge, deploy, alter shared databases, or touch
production unless the user separately authorized that exact action.

## Private review snapshots

Just run it. Every new review session uses a fixed private snapshot, including
sessions started from ordinary clones. This prevents a pull, branch switch,
commit, test run, or another session from moving the tree underneath Grok.

Background, so nobody "fixes" it back: a delegated reviewer is given exactly ONE
directory, and in a linked worktree `.git` is a FILE pointing at
`<main-repo>/.git/worktrees/<name>` — outside that directory. Pointing a
reviewer at the raw worktree kills the run on its first git-adjacent read,
before any code is read. No reviewer we drive accepts a second directory, so the
boundary cannot be widened. The wrapper therefore hands over a self-contained
disposable snapshot built by `bin/ai-review-sandbox`: its own `.git`, the
worktree's HEAD, its uncommitted edits, and its untracked files.

What this means for you:

- Paths in the reviewer's report are relative to the snapshot and are identical
  in the real worktree. Quote them unchanged.
- The reviewer never sees an absolute path from your machine as the source of
  truth; do not ask it to edit files there, and never commit from the snapshot.
- The snapshot path is recorded at session creation, refreshes on every turn,
  and is deleted with the session. Pre-existing sessions keep their old path and
  warn once so a live conversation is never silently moved.
