# Codex skills usage guide

Codex now has repo-owned skills under `skills/codex/`. Install them on a
machine with:

```bash
./bin/ai-install-skills
```

The installer copies them to `~/.codex/skills/` when `~/.codex` exists and keeps
`templates/system/AGENTS-global-codex.md` as the global standing instruction
file.

## What replaces what

| You used to type | Now say |
|---|---|
| "push and commit" / "commit and push" / "is everything pushed and committed?" | "use `codex-github-ship`" or just "push and commit" |
| "sync this repo with github.com" / "pull latest repo from github.com" | "use `codex-github-ship`" |
| Long end-of-session documentation prompt | "use `codex-session-closeout`" or "wrap up" |
| "is HANDOFF.md comprehensive enough for a fresh developer?" | "use `codex-session-closeout`" |
| "read all docs and handoff, then keep only useful context" | "use `codex-context-optimizer`" |
| "reduce my token usage / stop making me paste the same prompt" | "use `codex-context-optimizer`" |
| "find all local Codex transcripts / analyze repeated prompts" | "use `codex-transcript-miner`" |

## Skill map

- `codex-github-ship`: GitHub sync, commit, push, PR, CI/deploy/live SHA
  verification.
- `codex-session-closeout`: docs update, handoff quality gate, secret hygiene,
  git state, and final evidence report.
- `codex-context-optimizer`: minimal context loading, prompt compression, and
  lower-cost model guidance.
- `codex-transcript-miner`: transcript discovery, safe analysis, repeated prompt
  mining, and skill recommendations.
- `ai-reviewer`: existing read-only Codex second-opinion review skill.

## Maintenance rule

When you notice yourself pasting the same Codex instruction for the third time,
turn it into one of three things: a Codex skill, a repo `AGENTS.md` rule, or a
machine-atlas fact. Do not let repeated prompt text remain only in chat history.

## Windows install/update

On any Windows computer, paste this into PowerShell:

```powershell
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/u2giants/ai-devops.git $p} else {git -C $p pull --ff-only}; powershell -ExecutionPolicy Bypass -File "$p\bin\install-ai-devops-windows.ps1"
```

That one command clones or pulls this repo, installs Claude and Codex skills,
and seeds global instruction files without overwriting local edits.
