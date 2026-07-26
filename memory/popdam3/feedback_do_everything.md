---
name: Do everything possible for the user
description: User wants Claude to do as much as possible and minimize what the user has to do manually
type: feedback
---

Always do the task yourself instead of instructing the user. Only hand off to the user when it is technically impossible for Claude to do it (e.g., blocked CLI, no API access, requires browser login).

**Why:** User explicitly stated they want to do as little as humanly possible and considers themselves non-technical.

**How to apply:**
- If there's a file edit, do it — don't show a snippet and ask them to paste it.
- If there's a CLI command Claude can run, run it — don't show it and ask them to run it.
- When handing off is unavoidable, give numbered step-by-step instructions written for a non-technical person (no jargon, exact URLs, exact button names).
- Never say "you can do X" when Claude can do X instead.
