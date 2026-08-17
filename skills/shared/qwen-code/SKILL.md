---
name: qwen-code
description: Delegate repository reviews, analysis, debates, and explicitly authorized implementation to Qwen Code through the persistent `ai-qwen` wrapper. Use when the user says "ask Qwen," "use Qwen Code," "run this by Qwen," requests Qwen 3.8, wants a Qwen second opinion, asks to resume a Qwen session, or delegates coding work to Qwen.
---

# Qwen Code

## Always use the wrapper

```bash
AI_QWEN_CALLER=codex ai-qwen new <name>       --prompt-file "$brief"
AI_QWEN_CALLER=codex ai-qwen ask <name>       --prompt-file "$followup"
AI_QWEN_CALLER=codex ai-qwen implement <name> --prompt-file "$task"
AI_QWEN_CALLER=codex ai-qwen list | show <name> | transcript <name> | delete <name>
AI_QWEN_CALLER=codex ai-qwen doctor --live
```

Use `AI_QWEN_CALLER=claude` from Claude. Never hand-compose `qwen` calls. The
wrapper owns the model pin, exact-session resume, safety modes, run budgets,
completion proof, locks, durable records, and disposable implementation
worktrees. It deliberately rejects arbitrary flag forwarding.

Run the command from Git Bash on Windows.

## Reviews are read-only

`new` and review-mode `ask` combine:

- Qwen safe mode, which disables local hooks, extensions, skills, and MCP servers.
- Plan approval mode.
- Built-in shell, write, and edit tools excluded.
- A before/after content hash of the complete tracked diff and every untracked
  file, so edits inside already-dirty paths also fail loudly.

Do not weaken any layer. If a Qwen release changes a flag, stop and re-qualify
the wrapper against `qwen --help` and a hostile write canary.

## Continue the exact named session

Run `ai-qwen list` before creating another session. Use `ask` for every follow-up.
Never use Qwen's `--continue`, which means the newest session for that project and
can select another agent's conversation. The wrapper stores and resumes the exact
session ID, separated by repository and calling agent.

An exact ID proves conversation transport, not perfect memory. On material turns,
tell Qwen to re-read the current files. If it describes stale state, stay in the
same session, provide only the durable decisions and new evidence, and require a
fresh file read.

## Debates and second opinions

Commit to your own evidence-based position first. Use
`templates/delegation/debate-turn.md` for each material turn. Start one named
session with `new`, then use `ask` for every rebuttal.

The parent agent must:

1. Point Qwen to current plan or diff paths and require a fresh read.
2. Relay the other model's strongest reasoning faithfully.
3. Send only changed evidence and remaining objections after the first turn.
4. Update the durable plan or decision ledger as questions are resolved.
5. Stop at agreement or after the initial review plus three rebuttals. Record any
   unresolved objection and its consequence.

Agreement is not evidence. Check every claim against current files and tests.

## Write efficient briefs

Use this shape:

```text
Role: <relevant expert>
Task: <one concrete outcome>
Context: <repo, branch, exact paths, errors, prior decisions, evidence>
Constraints: <read-only or allowed files, forbidden actions, compatibility rules>
Required output: <verdict, evidence, tests, uncertainties>
```

- Point to files instead of pasting them. Qwen can read the repository.
- Keep stable background at the top and put the new request last.
- Never include secrets, tokens, `.env` contents, or transcript data.
- Ask for conclusions and evidence, never hidden reasoning.
- Use one scoped decision or implementation target per turn.

## Implementation runs

Use implementation only when the user explicitly delegates changes to Qwen.
`ai-qwen implement` creates a wrapper-owned disposable Git worktree, requires
Qwen's sandbox, runs with bounded turns/tool calls/time, exports a binary patch
under the Git-ignored `.ai/reviews/`, and removes the worktree. It never applies
the patch to the live checkout.

Inspect and apply an accepted patch yourself:

```bash
git apply --check "$patch" && git apply "$patch"
```

Implementation sessions preserve both the exact Qwen conversation ID and one
cumulative binary patch. Each turn reconstructs the immutable base plus that
patch at the same stable private path. `ask` on an implementation name is a
write-capable continuation. Review and implementation names cannot cross modes.

If a limit, timeout, cancellation, provider error, or missing terminal result
occurs after changes, the command stays unsuccessful and writes clearly marked
`*.incomplete.patch` and `*.incomplete.md` recovery files. Never treat them as
finished. Inspect every change and rerun tests. If artifact export itself fails,
the wrapper preserves the exact recovery worktree and prints its path.

Ignored dependencies, downloads, caches, build output, and secrets do not persist
between implementation turns. Recreate what is needed and rerun tests.

## Completion and usage

Exit status alone is not completion. Qwen must emit a terminal stream record with
`type: result`, `subtype: success`, and `is_error: false`. The wrapper records its
session ID, result, turn count, usage, timing, and permission denials.

Every run has maximum session turns, tool calls, subagent depth, and wall time.
Never remove those bounds or silently retry forever. Provider retry behavior must
remain bounded by the wrapper wall time.

## Verify the installation and every result

Run `ai-qwen doctor --live` after installation or a Qwen version change. A version
string is not enough. The live proof must return the terminal success record.

For every review or implementation:

1. Confirm the requested model and terminal success evidence.
2. Confirm a review left the working tree unchanged.
3. Inspect Qwen's cited files and claims yourself.
4. Inspect any patch and run the relevant tests yourself.
5. Keep Qwen's conclusion separate from your final judgment.

Official references: [headless mode](https://qwenlm.github.io/qwen-code-docs/en/users/features/headless/),
[configuration](https://github.com/QwenLM/qwen-code/blob/main/docs/users/configuration/settings.md),
and [installation](https://github.com/QwenLM/qwen-code/blob/main/docs/users/overview.md).

## Running from a linked Git worktree

Just run it. Since 2026-08-17 the wrapper handles this itself and you do not
have to think about it.

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
- The snapshot refreshes on every turn and is deleted with the session.
