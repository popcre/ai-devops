---
name: feedback_changes_via_ai_devops
description: "Skills, dotfiles, memories and global instructions must be changed in the u2giants/ai-devops hub so they roll out to every machine — never edited only locally"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4725f056-9e52-4d86-9058-29ba2efd5051
  modified: 2026-07-27T02:06:51.551Z
---

Any modification to **skills, dotfiles, memories, or instructions** must be made
in `https://github.com/u2giants/ai-devops` (local checkout `/worksp/ai-devops`)
in a way that rolls out to all of Albert's machines. Stated 2026-07-26.

**Why:** Albert works across several machines (Ubuntu hetz VPS, Windows). A
change made only in this machine's `~/.claude/` is invisible everywhere else and
is silently lost on the next sync or reinstall. The hub is the single source of
truth; local files are installed copies.

**How to apply:**
- **Memories** — write the file locally under
  `~/.claude/projects/<slug>/memory/`, then run `ai-memory-sync` to push it to
  the hub. Do NOT hand-edit `/worksp/ai-devops/memory/**`: the script syncs
  through an isolated clone at `~/.cache/ai-devops-memory`, canonicalizes
  per-machine project slugs via `memory/project-map.tsv`, and aborts the push if
  a file looks like it contains a credential. Editing the dev checkout directly
  bypasses all of that.
- **Skills** — edit under `/worksp/ai-devops/skills/`, commit, push, then
  `install.sh` / `update.sh` rolls it to `~/.claude/skills/`. The `sync-dotfiles`
  skill does the pull+install+push round trip.
- **Global instructions** — `templates/system/CLAUDE-global.md` (and
  `AGENTS-global-codex.md` for Codex) in the hub, NOT `~/.claude/CLAUDE.md`
  directly.
- **Per-repo `CLAUDE.md` / `AGENTS.md`** (e.g. `/worksp/popdam/CLAUDE.md`) are a
  different thing: they are project files checked into that project's own repo
  and already reach every machine through it. Confirm with Albert before moving
  any of that content into the hub.

Related: [[project_ai_devops_onboarding.md]].
