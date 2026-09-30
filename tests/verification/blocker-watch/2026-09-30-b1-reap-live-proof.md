# B1 live proof — task/orphan TTL + reap (2026-09-30)

Machine: edge-dev. Command: `ai-blocker-watch reap` (branch `mimo/1116-b1-orphan-reap`).

## Result

| Metric | Value |
|---|---|
| Terminal records reaped | 18 |
| Waiting records kept | 21 |
| Unique-work preserves logged | 9 |
| Audit log | `~/.ai-devops/blocker-watch/reap.log` |
| Archive | `~/.ai-devops/blocker-watch/reaped/` (18 JSON files, recoverable) |

## What was reaped (states and ages, paths redacted)

- 9 × `woken` records idle 26–290 h
- 9 × `failed` records idle 27–266 h
- 0 × `waiting` records (wake/resume intact)
- 0 × reviewer leases (never touched)

## Unique-work preserves

Nine reaped records pointed at worktrees with uncommitted changes. Each was
logged `preserved unique work at <path>` and the worktree was left alone
(cleanup-worktree rules). The wait record alone was archived.

## Audit line format

`<UTC ISO> reaped <id> state=<state> age=<N>h reason=terminal state '<state>' idle <N>h (ttl 24h) [preserved unique work at <path>]`

## Named gates proven live

1. Orphaned tasks past TTL reaped: 18 records archived.
2. Live/recent not reaped: 21 `waiting` records untouched; recent terminals kept.
3. Reviewer lease never freed on age alone: no lease state read, written, or released.

Posted by MiMo chat ses_ffe5f109076cdffezkdxImMKg3 on edge-dev
