# CLAUDE.md — Claude Code notes

**Read [`AGENTS.md`](AGENTS.md) first.** It is the canonical operating guide and
documentation router for this repo. This file only holds Claude Code-specific
notes; it does not repeat AGENTS.md.

## Context / ignore

- `.claudeignore` controls what Claude Code ignores here. Keep it aligned with the
  "What to ignore" section of `AGENTS.md`.
- Do not load every `.md` file. Use the **Documentation map** in `AGENTS.md` to
  pull only the docs a task needs.

## Repo-specific behaviors

- This repo is 100% owned Bash + Markdown. There is no app, database, container,
  or CI/CD — do not go looking for them or scaffold them unprompted.
- The toolkit home is always `/worksp/ai-devops`. Never use `/opt/ai-devops`.
- Real config lives in `/etc/ai-devops/*.env` (never in the repo). Never commit
  real `.env` files or secrets; only `*.env.example` belongs in git.
- Model roles: Opus 4.8 (high reasoning) plans + final-reviews; Opus reviews the
  gates; Codex/GPT-5.5 implements + tests. **Do not mention or use Fable.**

## New skills go in `skills/shared/` by default (installs to BOTH Claude and Codex)

- `bin/ai-install-skills` routes by folder: `skills/claude/` → Claude only,
  `skills/codex/` → Codex only, `skills/shared/` → **both**. So **every new skill
  is authored in `skills/shared/` unless it is genuinely client-specific** (uses
  a tool only one client has, or drives the other client — e.g. `codex-handoff`).
  Do not put a general skill in `skills/claude/` and force Albert to ask for it in
  Codex later. Default = shared, no exceptions unless you can name the
  client-specific reason. A name may live in `shared/` OR a client tree, never
  both (the installer fails closed on the collision).

## Commits

- Commit only when asked.
- This repo pushes with a GitHub `@users.noreply.github.com` email (email-privacy
  protection blocks the private gmail address). Keep using the noreply email.
- End commit messages with the `Co-Authored-By: Claude Opus 4.8` trailer.

## SSH / deployment

- There is no deploy automation. Installation is a local operation (`install.sh`)
  run on the target host over an ordinary SSH login. SSH is not a special deploy
  path here.
