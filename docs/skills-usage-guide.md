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

## How skills reach each machine (there is no automatic push)

Adding a skill needs **no wiring**: `bin/ai-install-skills` globs
`skills/claude/*/` plus `skills/shared/*/` and installs any directory containing a `SKILL.md`. Commit it
and every machine picks it up **the next time that machine runs the installer**.

That last clause is the whole story. Distribution is **pull-based and manually
triggered** — audited 2026-07-16:

- **No cron job, no systemd timer, no CI step** anywhere pushes skills to a
  machine. `crontab -l` and `systemctl list-timers` on `hetz` show nothing
  skill-related.
- A machine only updates when someone says **"sync my dotfiles"** (the
  `sync-dotfiles` skill: `git pull --ff-only` → `bin/ai-install-skills`) or runs
  the installer by hand.
- **Machines drift silently.** On 2026-07-16 `hetz`'s `/worksp/ai-devops` was **4
  commits behind** `origin/main` and its skills had last been installed
  **2026-07-09** — it was missing `secrets-to-1password` and `sync-dotfiles`
  entirely. Nothing surfaced that; it had to be checked.

So: **"is it integrated?" = yes. "Is it automatic?" = no.** Publishing a skill and
assuming it's live on a machine is a mistake — verify, or run the sync there.

Per-machine notes:

| Surface | How it gets skills | Gotcha |
|---|---|---|
| Windows dev boxes (916 / t16 / 4837) | `bash bin/ai-install-skills` via Git Bash | — |
| `hetz` (Ubuntu) | Runs as user **`ai`**, not root: repo is `ai:ai`-owned at `/worksp/ai-devops`, skills land in `/home/ai/.claude/skills`. Root has **no** `~/.claude/skills`. | `sudo -u ai -H bash -lc '…'` when driving it over SSH as root, or the install lands in `/root` and does nothing useful. **Never run `git` as root there** — it writes root-owned objects into `.git/objects` and every later `sudo -u ai git pull` fails with `insufficient permission…`; repair with `chown -R ai:ai /worksp/ai-devops/.git`. `-c safe.directory` hides the ownership warning but does **not** prevent this. |

Orphaned skills are never pruned — see the `ai-install-skills` quirk in
`AGENTS.md`.

Shared/client name collisions fail before anything is copied. The retired
`synology-sharesync-stuck-triage` skill is detected but left active by default;
use `--migrate-obsolete` to move only that exact directory into recoverable
quarantine after reviewing a `--dry-run`.

## What replaces what

| You used to type… | Now covered by |
|---|---|
| The 2-page "AI Session Documentation Update Prompt" (pasted 30+ times) | `session-docs-update` — say "update the .md files" |
| "pull develop into sandbox-albert, then pull into local…" + 4 standing rules | `dflow-session-start` — automatic at dflow session start |
| "push and commit… update the PR for sandbox-albert with develop" | `dflow-ship` — say "ship it" or "push and commit" |
| "is everything pushed? the live site is still running the old commit" | `deploy-and-verify` (hetz apps) — deploy verification with the Coolify quirks baked in |
| "pull the repo and re-read the .md files for the proper way to make db changes" | `shared-db-change` — automatic for any shared-backend change |
| "are there any secrets not in 1password? put them in with good notes" | `secrets-to-1password` — say "secrets sweep" (also runs inside session-docs-update and wrap-up) |
| "save this key / put these credentials in 1password with notes a future session can use" | `secrets-to-1password` — same skill, single-entry mode |
| "make it comprehensive enough that a brand new fresh developer…" | `handoff-writer` — say "write the handoff" |
| "@design.zip read the README in full… recreate these screens in our stack" | `design-handoff-implement` — attach the zip |
| "read the entire codebase and tell me if you find any bugs" | `repo-bug-audit` — say "audit the codebase" |
| "run all of this by codex and tell me what it says and if you agree — if you disagree, give it your reasoning and see if it changes its opinion" | `codex-second-opinion` — say "run this by codex" |
| "find all Claude Code transcripts on this machine → claude_chats/<machine>" | `claude-transcript-backup` |
| The full "CI/CD/DevOps Operating Rules" paste (8+ times) | `cicd-rules-audit` — say "audit CI/CD against our rules" |
| The "AI TASK SPEC: Repository Documentation Maintenance" paste (new apps / big changes) | `repo-docs-overhaul` — say "do a full documentation overhaul" |
| The full "POP Creations — New Project Standard" paste at the start of a brand-new engagement | `new-app-setup` — say "new project" / "set up a brand new app" |
| "I'm not a programmer… plain English… you do it… no band-aids… verify before done" | `templates/system/CLAUDE-global.md` — always loaded, no trigger needed |
| Re-explaining hosts, paths, quirks, NAS facts, Coolify quirks each session | `templates/system/machine-atlas.md` appended to each machine's CLAUDE.md |

## Related existing assets

- `synology-sharesync-triage` (NAS ShareSync diagnosis and targeted repair) is
  repo-owned under `skills/shared/`, so the same source installs into Claude and
  Codex/ChatGPT on every configured machine.
- `kimi-code-delegation` (headless Kimi Code CLI delegation) is repo-owned under
  `skills/shared/`. It is a skill/instruction package, not an MCP server or
  Ansible role; the dev-machine setup scripts install the skill and check whether
  the local `kimi` CLI is available.
- The 7-stage pipeline (`skills/claude/ai-development-pipeline`,
  `templates/prompts/01–07`) is unchanged and complements these: these skills
  automate the *rituals around* coding sessions; the pipeline governs staged
  plan/implement/review flows.

## Maintenance

When a standing rule changes (new quirk discovered, infra migrated, a rule
proves wrong), update the skill or atlas here and re-run `ai-install-skills`
on each machine — treat this repo as the single source of truth for AI
behavior, exactly like the rest of the toolkit.
