---
name: prove-capability-with-a-live-call
description: Never report whether a tool/provider works from an indirect clue (file present, --version, PATH). Make it do the thing.
metadata:
  type: feedback
---

2026-08-20: asked whether Grok/Kimi/Qwen were signed in on hetz, I checked for a
login file at a guessed path, found none, and reported "not signed in" for all
three. All three were signed in — they authenticate from an environment variable
or a managed config that leaves no such file. Albert had to correct me.

**Why:** an indirect signal answers a different question than the one asked.
`--version` proves a binary exists, a file proves one auth method was used, PATH
proves reachability. None prove the thing works. Reporting a guess as a finding
is worse than saying "I don't know yet".

**How to apply:** to report on a capability, invoke it. `grok -p "reply with
exactly: OK"` settles in seconds what an hour of file archaeology cannot. Use
`ai-review-preflight check <grok|kimi|glm> <repo>` where it applies — it already
tells logged-out apart from out-of-credit. It does NOT cover qwen, gemini, muse
or deepseek (Albert declined extending it, 2026-08-20), so for those, call the
CLI directly with a trivial prompt and a `timeout`.

Related trap the same day: a provider can be installed, working, and still
reported "unavailable" because its directory never reached PATH. See
[[hetz-provider-path-trap]].
