---
name: kimi-code-delegation
description: Delegate scoped coding work to Kimi Code CLI via the `ai-kimi` wrapper — read-only reviews, repository analysis, session continuation, and explicit isolated implementation. Use when an AI session should drive Kimi headlessly, split planning from execution, resume a prior Kimi session, or verify Kimi-authored changes without relying on the interactive TUI.
---

# Kimi Code Delegation

## Use `ai-kimi`. Never hand-assemble a `kimi` command.

```bash
ai-kimi new <name>       --prompt-file "$brief"   # read-only review / analysis
ai-kimi ask <name>       --prompt-file "$next"    # continue that same session
ai-kimi implement <name> --prompt-file "$task"    # explicit write run, isolated
ai-kimi list | show <name> | transcript <name> | delete <name>
ai-kimi doctor
```

The wrapper owns the model pin, the read-only enforcement, the completion rule, the
session bookkeeping, and the worktree isolation for write runs. It deliberately refuses
to forward arbitrary `kimi` flags. **If it seems to be missing something you need, say so
— do not route around it.**

Run it from Git Bash on Windows (it is a Bash script, like `ai-glm`).

## Why the wrapper matters more here than anywhere else

**Kimi reports neither the model nor token usage in headless output.** You cannot assert
which model answered, and you cannot quote a cost or a cache saving — there is nothing to
read. A dropped `-m` would silently fall back to another model and nothing in the output
would reveal it. `ai-kimi` pins the model on every call so the guarantee comes from the
code path, not from remembering.

**Reviews are structurally read-only.** `new`/`ask` run under
`config/kimi/readonly-review.md`, whose toolset is `Read, Grep, Glob, ReadMediaFile` —
no `Write`, no `Edit`, no `Bash`, no network. This is not a prompt request. Verified on
Kimi 0.31.1:

> Plain `kimi -p "Write HACKED into canary.txt"` → exit 0, **the file contained
> `HACKED`**. Kimi writes files freely in ordinary prompt mode.
> The same instruction under the read-only profile → canary **unchanged**, model replied
> `CANNOT_WRITE`.

`ai-kimi` refuses to run a review at all if that profile is missing, and hard-fails if a
review mutates the tree anyway.

Implementation mode uses `config/kimi/local-implement.md`. It removes Kimi's named web
and subagent tools, but it includes Bash so Kimi can build and test. Bash can still use
the network. This is an accepted limit, confirmed by a live `curl` canary on 2026-08-10.
The disposable worktree limits filesystem changes and the wrapper exports a patch, but
neither control is a network sandbox. Never give an implementation brief access to
secrets or private files that the task does not require.

## Continue a review session. Do not start a new one per question.

Run `ai-kimi list` first; if a session covers this topic and repo, continue it with `ask`.

**Never use `kimi -c/--continue`** — it means "the newest session for this working
directory", not "the session I was just using". Measured failure: session A was told a
codeword, an unrelated call created session B in the same directory, and `-c` answered
from B and got it wrong. With several AI sessions per repo, the newest is routinely not
yours. `ai-kimi` always resumes by explicit id.

Claude and Codex keep separate sessions. **Set `AI_KIMI_CALLER=codex` when running from
Codex**; it defaults to `claude`.

## Relaying a debate

Use `templates/delegation/debate-turn.md` for every material debate turn. Keep its
headings and order. Start one named review session with `new`, then use `ask` for every
rebuttal so the explicit Kimi session id is preserved. Never use `-c/--continue`.

The parent agent owns the relay and the verdict. It must:

1. Point Kimi at the current plan or diff paths and require those files to be re-read.
2. Relay the other model's actual reasoning under **Other model's reasoning**. Do not
   weaken it, omit its strongest point, or present a summary as a quotation.
3. Send only new evidence, changed objections, and the current parent agent's remaining
   objections after the initial turn. Do not paste the full transcript or plan again.
4. Update the active artifact's design decisions, rejected alternatives, open questions,
   and consensus ledger after each resolved turn. Kimi reads that durable state next turn.
5. Stop when both sides list no material objections, or after the initial review plus at
   most three rebuttal turns. At the bound, record unresolved objections and consequences.

Agreement is not evidence. The parent must adjudicate each claim against current files and
test results before calling consensus.

## Context health

An exact session id proves transport continuity, not perfect memory. Kimi may compact a
long session, and headless output provides no context-window or cache counters.

- Require a current-artifact re-read on every material turn. A remembered old file state
  is not evidence.
- If an answer contradicts the durable ledger, misses a continuity marker, or describes a
  stale artifact, stay in the same session. Send a concise durable-state refresh with the
  current paths, agreed decisions, unresolved objections, and exact new evidence, then ask
  Kimi to re-read and restate the disputed facts.
- If the refresh fails, stop the debate and record context continuity as an unresolved
  risk. Do not silently start a fresh session or edit Kimi's session files.
- Do not send `/compact` in prompt mode unless a future documented and live-tested CLI
  surface proves it is supported there.
- Never claim provider-cache savings, context size, token use, cost, or the returned model.
  Kimi exposes none of those in headless output. The wrapper's model pin proves only what
  was requested.

## Writing the brief

- Self-contained: the task, the repo and branch, relevant paths or errors, constraints,
  and the evidence you want back. Tell Kimi to read the repo's `AGENTS.md`.
- **Do not paste file contents** — Kimi has `Read`, and pasted text is prefix that
  changes every call.
- Kimi Code 0.32.0 has no headless prompt-file or stdin option. The wrapper must use
  `-p`, so the brief can be visible to other local users through the process list.
  Never put secrets in a Kimi brief on a shared host.
- Keep the opening stable across a workstream; put the new instruction last. Kimi exposes
  no cache counters, so this is prefix-stability best practice, **not a verified saving**.
  Do not claim a percentage you cannot show.
- Name exact paths in prose (`Read only path/to/a and path/to/b`). `@path` injection is
  documented for the interactive input box, not for headless prompts.
- One scoped change and one verification target per call.

## Implementation runs

`ai-kimi implement` creates a throwaway git worktree, lets Kimi work inside it, writes a
completed result out as a normal patch under `.ai/reviews/`, and removes the worktree.
Review the patch yourself before applying:

```bash
git apply --check "$patch" && git apply "$patch"
```

If a usage limit, timeout, cancellation, network error, or provider failure stops a run
after it changed files, the command remains unsuccessful and exports two clearly marked
recovery files: `*.incomplete.patch` and `*.incomplete.md`. The report says why completion
is unproven and gives `git apply --stat` and `git apply --check` commands. Inspect every
change and run the required tests before deciding whether to apply it. The wrapper never
auto-applies complete or incomplete patches. A failure before any change creates no empty
patch. Only an artifact-export failure preserves the exact recovery worktree and prints
its path; ordinary failed worktrees are still removed.

When a continuation fails, the cumulative `*.incomplete.patch` remains the recovery file
that applies to the immutable base. The wrapper also writes a
`*.turn.incomplete.patch` containing only changes made during that failed turn. The report's
changed-file summary uses that turn-only view, so older proven work is not mislabeled as
new failed work.

Planning and execution cannot share a session: `--agent`/`--agent-file` cannot be combined
with a resume, so the agent is fixed when a session is created — which is exactly why a
read-only review session can never later become a write session. Plan in a review session,
amend the plan yourself, then start an `implement` session with the approved plan.

Implementation sessions persist by exact session ID and one cumulative binary patch.
Each turn reconstructs that patch on the immutable starting commit in a new disposable
worktree. Kimi 0.32.0 binds resume to the original folder name, so the wrapper removes
and recreates the worktree at one validated per-session path. Both
`ai-kimi implement <existing-name>` and `ai-kimi ask <implementation-name>`
continue the same write-capable session. `ask` is therefore an implementation
continuation (write run), not a read-only review, when the named session is implementation.
The wrapper never applies the cumulative patch to the live repo.

Moving the live repository does not move that stable private workspace. The wrapper
finds the session by repository remote, keeps its original private session identity, and
updates the recorded live checkout only after a proven turn. `implement` and `ask` share
that lookup, so a move cannot silently create a duplicate conversation.

Ignored dependencies, build output, downloads, caches, and secrets do not persist across
turns. Recreate them when needed and rerun tests. If a failed turn or state-save failure
could leave Kimi's conversation ahead of canonical code, the wrapper marks the session
recovery-required and refuses exact-session continuation instead of guessing.

Read-only Kimi cannot run tests because its profile has no `Bash`. An implementation run
can run tests inside its throwaway worktree, but a stopped run's report always says tests
are not confirmed complete. Run the relevant tests yourself against any patch you accept.
Continue a healthy implementation session with `ask` or `implement` using its existing
name. Review the newly emitted cumulative patch and run the relevant tests yourself.

## Verifying the install

`ai-kimi doctor` resolves the binary, shows the model pin and read-only profile, and
checks auth. Two traps it exists to handle:

- **`~/.kimi-code/bin` is not on PATH** on either hetz user, so `command -v kimi` fails
  while Kimi is installed and fine. The wrapper resolves the binary explicitly.
- **`kimi provider list` exits 0 while printing "No providers configured"** — the exit
  code alone is a false OK.

Kimi's credentials are **per-user OAuth** under `~/.kimi-code`, with no config-dir
override. On `hetz` they belong to user `ai`; a root session borrows them automatically
for reviews (`AI_KIMI_OWNER`, default `ai`). Implement runs are not borrowed — their
writes would land owned by the wrong user, so run those as `ai`.

## Verify every result

1. Inspect the actual diff; never trust a summary alone.
2. Run the relevant tests yourself.
3. Stop if Kimi expands scope, edits protected files, or cannot prove completion.
4. Label Kimi's conclusions separately from your own judgment, and never claim a token,
   cost, or model figure for a Kimi run — there isn't one.

Official references: [command options](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command.html)
and [interaction modes](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/interaction.html).
Re-verify against `kimi --help` before trusting any flag statement here, including this one.
