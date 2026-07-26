---
name: feedback-terse
description: "User wants concise responses — no trailing summaries, no recap, no preamble"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b7861fed-538d-421b-b87c-a3f62725c39a
---

Do not summarize what was just done at the end of a response. Do not preface responses with "I'll continue" or similar meta-commentary. Keep output tight and direct.

**Why:** User explicitly requested text-only summary with no tool calls, indicating preference for clean, minimal responses. User's workflow is fast-moving trunk-based dev with no ceremony.

**How to apply:** Every response. State results and next steps only — no "here's what I did" wrap-up.
