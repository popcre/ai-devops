---
name: globals-machine-section-trap
description: "Replacing an installed global destroys that machine's own facts unless saved; use bin/ai-adopt-globals, never --adopt-globals by hand, and expect drift 2 (not 0) on a machine with a machine section."
metadata: 
  node_type: memory
  type: project
  originSessionId: 8efc08d3-86fd-4cc2-b590-c87c04e93bf9
  modified: 2026-08-14T14:48:52.277Z
---

The installed globals (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) end with a
MACHINE SECTION that exists nowhere in the repo. `ai-install-skills
--adopt-globals` replaces the file and only PRINTS a note about it, so doing it
by hand loses facts that exist in exactly one place. Use `bin/ai-adopt-globals`
(added 2026-08-14): it saves the section, re-appends it, and DIFFS it back.

Three things that are not guessable from the code:

- **A machine section is not always named after its machine.** `albt16`'s
  headings are `# Machine atlas - 916 ("916-alien") and t16 and 4837 …` and
  `# Local standing addition retained from previous AGENTS.md`. Hostname
  matching alone reports "no machine section" on a file with 166 lines of them.
- **The tail can be interleaved** — real machine facts, then blocks pasted in by
  older template syncs whose text the current global already carries inline.
  Re-appending verbatim duplicates kilobytes in an always-loaded file.
- **`installed source drift: 2` is SUCCESS** on a machine carrying a machine
  section, and **0** on one without (`hetz` has none). The gate is "only the
  globals may differ", never a fixed number. Also: the audit reports 0 unless
  `--claude-home` / `--codex-home` are passed, which silently means "not
  measured".

Rollout state, 2026-08-14: trimmed globals live on `al8960ofc`, `hetz` (user
`ai`, reach it as `ssh vps2` — `ssh vps` is root) and `albt16` (unreachable over
SSH; port 22 closed, run it at the keyboard). `916-alien` excluded, powered off.

Related: [[git-identity-silent-guess]], [[concurrent-session-clobber-hazards]],
[[machine-tool-sync-catalog]], [[remote-shell-cwd-trap]].
