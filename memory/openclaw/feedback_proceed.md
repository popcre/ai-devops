---
name: Always proceed without asking
description: User wants agent to proceed with all actions without asking for confirmation first
type: feedback
---

Always proceed with actions without asking "do you want to proceed?" or similar confirmation questions. The answer is always Yes.

**Why:** User explicitly stated this preference.

**How to apply:** For all tasks — including potentially risky ones like installing with --force flags, restarting containers, modifying configs — just do it and explain what was done afterward, rather than asking first. Never ask "do you want me to proceed", "shall I continue", "should I do X" — just do it. This includes waiting for the user to trigger things (like sending a chat message) — find a way to test it programmatically instead.
