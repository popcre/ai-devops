# Handoff — preamble trim: roll out to machines

## 1. Goal
Cut the tokens every AI session carries. Code is merged; the remaining step is
getting the new globals and skills onto every machine.

## 2. Done (verified MERGED on GitHub)
- https://github.com/popcre/ai-devops/pull/1933 — Claude global 11,237 → 8,598 bytes (−23%); procedure moved to
  https://github.com/popcre/ai-devops/blob/main/docs/standing-rules-details.md ("Procedures moved from the Claude
  global"); new fresh-session rule (≈300 turns / 150k tokens).
- https://github.com/popcre/ai-devops/pull/1936 — 11 long skill descriptions 6,302 → 3,657 bytes.

## 3. Not done
Installed globals are still the old text (`~/.claude/CLAUDE.md` = 11,237 bytes
on edge-dev3 at close). The installer only seeds globals when missing; adoption
is via the `sync-dotfiles` skill / `ai-adopt-globals`.

## 4. Why deferred
Two sibling sessions (fix-ignored-rules, fix-rediscovery, spawned 2026-10-21
from the transcript-analysis session) were still editing the same global
templates. Syncing now would need a second sync after they land.

## 5. Next action
1. Confirm those sibling PRs on popcre/ai-devops are merged (search open PRs
   touching `templates/system/CLAUDE-global.md`).
2. Run the `sync-dotfiles` skill on each dev machine (see
   https://github.com/popcre/ai-devops/blob/main/templates/system/machine-atlas.md; Envy and EDGE-ALIEN are
   excluded).

## 6. Verify
On each machine the installed Claude global byte size equals
https://github.com/popcre/ai-devops/blob/main/templates/system/CLAUDE-global.md, and it contains
"Start fresh before a session gets long".

## 7. Tried / failed
The one-third global cut was not reachable: tests pin the coordinator contract,
task-class list, and production exception verbatim in all four client globals
(https://github.com/popcre/ai-devops/blob/main/tests/test-session-conduct-policy.sh,
https://github.com/popcre/ai-devops/blob/main/tests/test-client-globals-required-phrases.sh). Trigger-protected
skills (https://github.com/popcre/ai-devops/blob/main/config/skill-trigger-policy.json) were not shortened.

## 8. Further savings (optional, not started)
Codex/ZCode/MiMo globals did not get the same trim; doing so needs the pinned
passages kept identical across all four.

## 9. Owner
Unowned until a session picks it up; retire this file once all machines verify.
