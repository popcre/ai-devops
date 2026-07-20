---
name: kimi-code-delegation
description: Delegate scoped coding work to Kimi Code CLI (`kimi`) in non-interactive prompt mode from Windows PowerShell or Ubuntu bash. Use when an AI session should drive Kimi headlessly, split planning from execution, resume a prior Kimi session, constrain exploration, or verify Kimi-authored changes without relying on the interactive TUI.
---

# Kimi Code Delegation

Drive Kimi headlessly and treat the calling session as planner, reviewer, and quality gate.

## Verify the local CLI

1. Run `kimi --version` and `kimi --help`; prefer the installed CLI over remembered flags.
2. Verify authentication with `kimi -p "reply with OK"`. If it fails, run `kimi login` or complete the interactive login flow once.
3. Read the target repository's `AGENTS.md` before delegating.
4. Keep the working tree reviewable and record its starting status.

Kimi Code CLI 0.27.0 rejects `-p/--prompt` combined with `--plan`, `--auto`, or `-y/--yolo`. Prompt mode already handles regular approvals automatically while retaining static deny rules. Do not add interactive permission flags to a `-p` command.

## Plan, approve, then execute

Use two prompt-mode calls for non-trivial work because native `--plan` cannot be combined with headless `-p`.

Planning call:

```text
kimi -p "Produce a read-only implementation plan for <task>. Read only <paths>. Do not modify files. List steps, files, risks, and verification gates."
```

Review and amend the plan in the calling session. Then make a separate execution call:

```text
kimi -p "Implement exactly this approved plan: <plan>. Do not expand scope. Run <tests> and report the actual results."
```

For dependent follow-ups, resume with `-c/--continue` for the previous working-directory session or `-S/--session <id>` for an explicit session. Combine the resume option with `-p` for another headless instruction.

## Keep each call bounded

- Give one scoped change and one verification target per execution call.
- Name exact paths in prose: `Read only path/to/a and path/to/b`. `@path` injection is documented for the interactive input box, not guaranteed for headless prompt strings.
- State when editing should begin and forbid unrelated exploration.
- State the build or test command and the done condition.
- Decompose dependent multi-file work and inspect the diff after each call.

On Windows, invoke Kimi from PowerShell and account for `C:\...` versus Git-Bash `/c/...` paths. If Kimi cannot find its internal shell, verify Git for Windows and `KIMI_SHELL_PATH`. On Ubuntu, use normal bash quoting and protect `$`, backticks, and embedded quotes.

## Verify every execution

1. Inspect the actual diff; never trust the summary alone.
2. Run the relevant tests independently when Kimi's result is incomplete or ambiguous.
3. Feed exact failures back in a new bounded prompt.
4. Stop if Kimi expands scope, edits protected files, or cannot prove completion.

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Long analysis, no edits | Prompt is too broad | Split planning from execution and name exact paths |
| Repeats repository exploration | Fresh session lacks context | Resume with `-c` or `-S <id>` and narrow the instruction |
| Authentication error | Login is missing or expired | Run `kimi login`, then repeat the trivial prompt check |
| Windows shell/path error | Git Bash is missing or mislocated | Verify Git for Windows and `KIMI_SHELL_PATH` |
| Flag rejected | CLI surface changed | Run `kimi --help` and update the invocation |

Official references: [command options](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command.html) and [interaction modes](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/interaction.html).
