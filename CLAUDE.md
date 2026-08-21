# CLAUDE.md — Claude Code adapter

Read [`AGENTS.md`](AGENTS.md) first. It is the canonical repository contract and
task router. This file contains only Claude-specific differences.

- `.claudeignore` controls Claude Code's excluded paths. Keep it aligned with
  the transcript, secret, generated-output, and dependency exclusions routed by
  `AGENTS.md`; do not bulk-load Markdown or raw transcript archives.
- New skills belong in `skills/shared/` unless they truly require a
  Claude-only tool or behavior. The installer rejects a skill name duplicated
  between shared and client-specific trees.
- Finished Claude changes are committed and pushed under Albert's verified Git
  identity. Add the repository's current Claude co-author trailer when its
  documented workflow requires one.
- Use Git Bash for Bash suites and PowerShell for PowerShell suites on Windows.
  Installation is local machine setup, not an application deployment.

All repository layout, model setup, reviewer restrictions, deployment details,
secrets handling, and task-specific reading now live behind the pointers in
`AGENTS.md`; do not duplicate them here.
