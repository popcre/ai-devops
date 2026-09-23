# ai-housekeeping

Machine hygiene scripts for AI debris on Albert's workstation (EDGE-DEV).

Tracked by issues [#714](https://github.com/popcre/ai-devops/issues/714) (these scripts) and [#711](https://github.com/popcre/ai-devops/issues/711) (make agents clean up after themselves).

| Script | Purpose |
|--------|---------|
| `cleanup-ai-debris.ps1` | Daily backup sweep. Windows task `AI-Debris-Housekeeping` at 03:30. Deletes old review sandboxes, clean worktree groups, archived sessions, temp debris. Never touches dirty work or items on its preserve list. |
| `move-bulk-to-d.ps1` | Move growth folders to `D:\ai-data` and leave directory junctions on C: so every tool keeps working. Run only when Codex/opencode and other coding tools are **closed**. |

Policy (owner, 2026-09-23): the run that creates a temporary copy deletes it before returning. This daily sweep is **backup only**. Do not retire it until self-cleanup has been live-proven for 14 days.

See `plan_agent-self-cleanup.md` and `prompt_fix-review-full-history.md` on this repo.
