# Skills usage guide

How the skills in `skills/claude/` map to the things Albert used to type
manually, and how to install them. Built from an analysis of ~1,790 prompts
across 179 archived sessions (six machines) in `claude_chats/`.

## Install

On each machine, after cloning/pulling this repo:

```bash
./bin/ai-install-skills          # Linux/macOS/Git Bash
```

This copies every skill to `~/.claude/skills/` and seeds the global standing
instructions (`templates/system/CLAUDE-global.md`) to `~/.claude/CLAUDE.md` if
absent. Then append the machine's section from
`templates/system/machine-atlas.md` to that CLAUDE.md.

Windows (PowerShell): run the same script via Git Bash
(`bash ./bin/ai-install-skills`), or ask any Claude Code session to
"install the skills from ai-devops" — the script is self-explanatory.

## What replaces what

| You used to type… | Now covered by |
|---|---|
| The 2-page "AI Session Documentation Update Prompt" (pasted 30+ times) | `session-docs-update` — say "update the .md files" |
| "pull develop into sandbox-albert, then pull into local…" + 4 standing rules | `dflow-session-start` — automatic at dflow session start |
| "push and commit… update the PR for sandbox-albert with develop" | `dflow-ship` — say "ship it" or "push and commit" |
| "is everything pushed? the live site is still running the old commit" | `deploy-and-verify` (hetz apps) — deploy verification with the Coolify quirks baked in |
| "pull the repo and re-read the .md files for the proper way to make db changes" | `shared-db-change` — automatic for any shared-backend change |
| "are there any secrets not in 1password? put them in with good notes" | `secrets-to-1password` — say "secrets sweep" (also runs inside session-docs-update) |
| "make it comprehensive enough that a brand new fresh developer…" | `handoff-writer` — say "write the handoff" |
| "@design.zip read the README in full… recreate these screens in our stack" | `design-handoff-implement` — attach the zip |
| "read the entire codebase and tell me if you find any bugs" | `repo-bug-audit` — say "audit the codebase" |
| "find all Claude Code transcripts on this machine → claude_chats/<machine>" | `claude-transcript-backup` |
| The full "CI/CD/DevOps Operating Rules" paste (8+ times) | `cicd-rules-audit` — say "audit CI/CD against our rules" |
| The "AI TASK SPEC: Repository Documentation Maintenance" paste (new apps / big changes) | `repo-docs-overhaul` — say "do a full documentation overhaul" |
| The full "POP Creations — New Project Standard" paste at the start of a brand-new engagement | `new-app-setup` — say "new project" / "set up a brand new app" |
| "I'm not a programmer… plain English… you do it… no band-aids… verify before done" | `templates/system/CLAUDE-global.md` — always loaded, no trigger needed |
| Re-explaining hosts, paths, quirks, NAS facts, Coolify quirks each session | `templates/system/machine-atlas.md` appended to each machine's CLAUDE.md |

## Related existing assets

- `synology-sharesync-stuck-triage` skill (NAS ShareSync repair) — already
  deployed on 916; referenced by the machine atlas.
- The 7-stage pipeline (`skills/claude/ai-development-pipeline`,
  `templates/prompts/01–07`) is unchanged and complements these: these skills
  automate the *rituals around* coding sessions; the pipeline governs staged
  plan/implement/review flows.

## Maintenance

When a standing rule changes (new quirk discovered, infra migrated, a rule
proves wrong), update the skill or atlas here and re-run `ai-install-skills`
on each machine — treat this repo as the single source of truth for AI
behavior, exactly like the rest of the toolkit.
