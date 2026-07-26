---
name: call-limit-folklore
description: "The \"~10–15 call session-degradation limit\" is folklore; validator blocks are stateless and intentional."
metadata: 
  node_type: memory
  type: project
  originSessionId: 9f3e683d-d8db-47ad-bc6b-1954ca90287e
---

There is **no per-session "~10–15 call limit"** and no session-degradation effect that
blocks tool calls. Sessions keep reporting "the MCP validator blocked my log greps — the
session is degrading (~10–15-call limit)". That is a triple misdiagnosis.

The "~10–15" number in `app/AGENTS.md` refers to two **already-fixed, unrelated** things:
tool-schema context bloat (fixed by lazy-load) and undici socket-pool exhaustion (fixed by
`Connection: close`). Neither blocks commands.

What actually blocks a `grep` is `apps/nas-api/internal/validator/validator.go` →
`hardBlocked`: a **stateless, pure** pattern list. Recursive grep (`-r/-R`) + a Drive path
(`@synologydrive`/`@SynologyDriveShareSync`/`/var/packages/SynologyDrive`) is refused
identically on every call (incident: a `grep -R` ran 4d11h on prod). Same input → same
result, forever — no counter, no state.

**Why:** sessions hit the stateless grep block, misread it as degradation, and give up /
hand off instead of just running the right command.

**How to apply:** if a NAS command is *blocked*, it's the validator pattern list, not
degradation — don't retry, don't start a fresh session expecting success. For "deeper log
greps" use a bounded non-recursive grep of the specific log file, `search_file_access_audit`,
`check_backup_status`, or a Postgres query. Client-side `settings.json` permissions do NOT
affect this server-side validator.

The affected sessions are **MCP clients with no repo checkout** — they never read AGENTS.md,
so docs are not the fix for them. The fix that reaches them is the MCP response itself:
`validator.BlockExplanation()` (nas-api) now returns an actionable, "this is permanent &
stateless, not a rate limit" reason on a block (was just echoing the command), wired through
`handlePreview` → MCP `Blocked:` message; the `run_command` tool description also warns up
front. Changed 2026-06-03 in `apps/nas-api/internal/validator/validator.go`,
`apps/nas-api/cmd/server/main.go`, `apps/nas-mcp/src/index.ts`. NOT yet built/committed (no Go
toolchain in that session). Related: [[db-schema-reference]].
