---
name: grok-headless-early-return
description: "Grok's headless CLI returns before it finishes (exit 0 + 0-byte file); use ai-grok-review, never bare `grok`, and never trust exit status."
metadata: 
  node_type: memory
  type: project
  originSessionId: 34e7b0ee-929b-4e97-bf9d-ef85a0a970d4
  modified: 2026-08-06T02:44:57.679Z
---

Grok CLI 0.2.118 headless: **the command returning does not mean Grok finished.**
Observed 2026-08-05 on hetz — the launcher exited ~25–30s in while the sandboxed
child kept working 1–3 minutes, leaving exit status 0 and a zero-byte output
file. One *completed* run delivered zero bytes to its caller while its own log
said `handle_prompt.done ok:true`. That log is not a completion oracle either:
it reported `ok:true` for two runs whose `stopReason` was `cancelled`.

Believing exit status cost ~1.9M tokens / ~$1.28 in one sitting — the session
thought Grok had died and launched duplicate full-price reviews.

**Always use `ai-grok-review` (added 2026-08-05); never hand-compose `grok` for a
review.** It proves completion from a terminal `stopReason` in the parsed JSON,
always passes `--max-turns` (without it a review dies as a bare `cancelled` after
~250k tokens), freezes the read-only permission set, and refuses a second
concurrent review in one repo.

Two traps worth remembering separately:

- **`grok doctor` is not an auth check** — it tests terminal/clipboard/color
  support. It reported "not authenticated" while `grok models` and real calls
  worked. Use `grok models`.
- **A denied tool does not cancel a run.** Grok says "Shell is blocked, so I'll
  stick to file reads and greps" and finishes. If a review ends with no verdict
  the cause is the turn limit, not permissions — never broaden permissions
  chasing it.

**Why:** these are properties of Grok's leader/child process architecture and
its result schema, not of any repo, so they are invisible in code and git
history.

**How to apply:** run `ai-grok-review doctor` first; use `new` once then `ask`;
read `bin/ai-grok-review`'s STEP 0 VERIFICATION header before changing anything,
and re-run that verification on any Grok version bump. See
[[glm-agent-zai-field-and-forkbomb]] for the same class of delegate-CLI trap.
