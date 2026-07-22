---
name: ask-glm
description: Delegate a coding task, repository analysis, implementation, test run, or independent second opinion to Z.ai GLM through the isolated ai-glm-agent launcher. Use when the user says "ask GLM," "run this by GLM," "get GLM's opinion," requests GLM-5.2, wants an independent GLM review, or explicitly delegates repository work to GLM.
---

# Ask GLM

Run GLM as a separate Claude Code coding agent. Preserve the parent Claude or
Codex session as supervisor and independently evaluate GLM's result.

## Choose the mode

- Default to `review` for opinions, analysis, planning, debugging, and reviews.
  This uses Claude Code plan permissions and must not change files.
- Use `implement` only when the user explicitly asks GLM to edit or implement.
  State exact allowed files and verification gates in the prompt, then inspect
  the resulting diff and run tests independently.

## Prepare the prompt

Give GLM a self-contained brief with role, task, repository/branch, relevant
paths and errors, constraints, and required output. Tell it to inspect the repo
with its tools instead of pasting large files. Never include secrets or `.env`
contents.

For review mode, explicitly forbid edits, commits, pushes, deletions, and other
state changes. For implementation mode, repeat all production, branch, database,
and destructive-action constraints that apply to the parent session.

## Run the agent

Prefer the installed command on Ubuntu:

```bash
ai-glm-agent --mode review --prompt-file "$brief" --output "$report"
```

On Windows, run the repo-owned PowerShell launcher:

```powershell
$aiDevOps = if ($env:AI_DEVOPS_HOME) { $env:AI_DEVOPS_HOME } else { "C:\repos\ai-devops" }
& "$aiDevOps\bin\ai-glm-agent.ps1" `
  -Mode review -PromptFile $brief -Output $report
```

If the repo is elsewhere, locate it from the current checkout or
`AI_DEVOPS_HOME`; do not assume a different path. Store review reports under
`.ai/reviews/`. The launcher defaults to `glm-5.2`, obtains its key from
1Password at runtime, isolates Z.ai from normal Claude authentication, and
rejects silent model fallback.

## Verify

Treat any nonzero exit, authentication error, missing result, or returned-model
mismatch as failure. Confirm the report exists and is substantive. For reviews,
confirm the working tree did not change. For implementation, inspect every
change and run the relevant tests before accepting it. Clearly separate GLM's
conclusions from the parent agent's judgment.
