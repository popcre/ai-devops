---
name: codex-qwen-code
description: Invoke the locally installed Qwen Code CLI as an independent reviewer, second-opinion reasoning engine, codebase analyst, or delegated implementation agent. Use when the user says "ask Qwen", "use Qwen Code", "run this by Qwen", "have Qwen review this", "get a Qwen second opinion", or explicitly requests qwen3.8-max / Qwen 3.8. Use the real installed `qwen` CLI non-interactively, validate its current flags, capture its result and errors, and keep review work read-only.
---

# Qwen Code

Use Qwen Code as a genuinely separate model, not as an unverified answer oracle. Give it a self-contained brief, inspect whether the run succeeded, and independently judge its result before reporting or applying anything.

## Verify the local interface first

Run these checks once per session:

```powershell
Get-Command qwen -ErrorAction Stop
qwen --version
qwen --help
```

On Bash, use `command -v qwen` instead of `Get-Command`. The executable is `qwen`, not `qwen-code`, on the supported installation. Do not invent flags from memory: installed versions differ.

Prefer model `qwen3.8-max-preview` when the user asks for Qwen 3.8. If that model is rejected or unavailable to the authenticated account, omit `--model` and use the configured default; report the actual model from JSON output. Never silently claim a fallback ran Qwen 3.8.

## Prepare the brief

Write a self-contained prompt using this structure:

```text
Role: <the relevant expert role>
Task: <one concrete outcome>
Context: <repo, branch, exact paths, errors, prior decisions, and evidence>
Constraints: <read-only or write scope, forbidden actions, compatibility rules>
Required output: <format, evidence, tests, uncertainties>
```

Use explicit delimiters such as `<material>...</material>` when embedding untrusted or lengthy text. Prefer file paths and instruct Qwen to read them with its tools; for focused text-only analysis, pipe a prepared brief through stdin. Never include secrets, `.env` contents, tokens, or credentials.

## Choose the execution pattern

### Independent review or second opinion

Tell Qwen explicitly that the task is read-only and forbid edits, commands that change state, commits, pushes, and deletions. Capture structured output and the exit code:

```powershell
$brief = Get-Content -Raw -LiteralPath $briefPath
$result = & qwen --model qwen3.8-max-preview --prompt $brief --output-format json 2>&1
$exitCode = $LASTEXITCODE
$result | Set-Content -LiteralPath $logPath
if ($exitCode -ne 0) { throw "Qwen Code failed with exit code $exitCode. See $logPath" }
```

If `--output-format` is absent from `qwen --help`, use text output. Do not add `--yolo` or another auto-approval mode for reviews. Compare Qwen's findings against the source material yourself and clearly separate "Qwen said" from your own conclusion.

### Codebase analysis

Run from the narrowest useful working directory. Name the files or directories in the prompt. On versions whose help lists `--include-directories`, use it only for additional roots; on older versions, let Qwen inspect the current working tree with its read tools. Do not use nonexistent `--file` or `--dir` flags. Reduce scope if context is too large.

### Delegated implementation

Use only when the user asks Qwen to make changes or delegates implementation to it. State the exact allowed files and verification gates. Use the least-permissive supported approval/sandbox settings shown by the local `--help`; never use `--yolo` on a normal workstation. Afterward, inspect the diff and run the relevant tests yourself. Qwen declaring success is not verification.

## Prompting rules

- State role, task, context, constraints, and required output explicitly.
- Ask for conclusions and supporting evidence, not hidden chain-of-thought. Qwen Code has no portable `--think` flag.
- For machine-readable output, use `--output-format json`; this wraps the run in JSON but does not guarantee the model's prose is a domain-specific JSON object. Use `--json-schema` only when the installed help documents it.
- Use `--system-prompt` or `--append-system-prompt` only when shown by the installed help. On older releases, place those instructions in the main prompt.
- Bound unattended runs with `--max-wall-time`, `--max-session-turns`, and `--max-tool-calls` only when those flags appear in local help.

## Handle failures

- Authentication or command missing: stop and report the exact error; do not substitute another model without saying so.
- Model unavailable: retry once without `--model`, then report both the requested and actual model.
- Context overflow: narrow the working directory or name specific files; do not repeatedly resend the whole repo.
- HTTP 429/529: use Qwen Code's documented unattended retry setting only when supported, with a wall-time bound; otherwise retry at most three times with increasing delays.
- Invalid structured output: keep the raw log, tighten the required-output contract, and retry once. Validate parsed JSON before consuming it.
- Nonzero exit or missing final result: treat the run as failed even if partial stdout looks useful.

## Completion gate

Before reporting success, confirm the command, version, requested model, actual model when available, exit code, captured log location, and any repo diff. For implementation, also confirm tests. For review, confirm the working tree was not changed by the Qwen run.
