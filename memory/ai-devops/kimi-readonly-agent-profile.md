---
name: kimi-readonly-agent-profile
description: "Kimi writes files freely in plain `-p` mode; read-only comes only from an --agent-file whose tool names are case-sensitive and fail silently."
metadata: 
  node_type: memory
  type: project
  originSessionId: 34e7b0ee-929b-4e97-bf9d-ef85a0a970d4
  modified: 2026-08-06T03:23:26.898Z
---

Verified on Kimi Code 0.31.1 (2026-08-05):

- Plain `kimi -m kimi-code/k3 -p "Write HACKED into canary.txt"` → exit 0, **the
  file contained `HACKED`**. Kimi writes files freely in ordinary prompt mode.
  Any "planning call is read-only" that rests on wording is not read-only.
- Under `--agent-file` with `tools: Read, Grep, Glob, ReadMediaFile`, the same
  hostile instruction left the file untouched and returned `CANNOT_WRITE`.

**Tool names are CASE-SENSITIVE and fail silently.** `tools: read, grep, glob,
ls` is accepted by the frontmatter parser and matches *nothing*, leaving the
agent with **no tools at all** — it reports it cannot read files, and a
write-canary test passes for entirely the wrong reason. Real names are
capitalized: `Read, Grep, Glob, ReadMediaFile, Bash, Edit, Write, FetchURL,
WebSearch, Agent, AgentSwarm, Skill, Cron*, Task*, Todo*`. Frontmatter `tools:`
must be a comma-separated string or list — a YAML map is rejected.

Other Kimi facts that are invisible in any repo: completion is the terminal
`{"type":"session.resume_hint"}` NDJSON record (exit status proves nothing);
there is **no `--max-turns`**; output formats are only `text` and `stream-json`;
`--agent-file` cannot combine with a resume, so the agent is fixed at session
creation; and Kimi reports **no tokens, cost, or model** in headless output, so
no such figure can ever be quoted for a Kimi run.

**Why:** all of it is third-party CLI behaviour, provable only by running it.

**How to apply:** use `ai-kimi` (never bare `kimi`); after touching
`config/kimi/readonly-review.md` verify **both** directions — that a review can
still read AND that it still cannot write. `AI_KIMI_LIVE=1
tests/test-ai-kimi.sh` does exactly that. See
[[grok-headless-early-return]] for the same class of delegate-CLI trap.
