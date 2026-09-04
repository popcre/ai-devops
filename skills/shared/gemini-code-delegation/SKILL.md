---
name: gemini-code-delegation
description: Use Gemini 3.8 Flash through the ai-gemini wrapper for an independent read-only repository review. Trigger when the user says ask Gemini, use Gemini, Gemini review, run this by Gemini, or Gemini 3.8 Flash.
---

# Gemini code review

Gemini 3.8 Flash is available as a governed read-only reviewer when the local
hash-bound qualification remains current. Never call `agy` directly or bypass a
quarantine. Check the installed wrapper before assigning work:

```bash
AI_GEMINI_CALLER=codex ai-gemini doctor
```

Proceed only when `doctor` reports `PASS` for exact model
`gemini-3.8-flash-high`. If it reports `QUARANTINED`, stop and choose another
governed reviewer until one governed requalification succeeds. An empty answer,
wrong model or conversation, changed protected file, committed or uncommitted
source drift, interruption, or missing durable report is always a failed review.
Gemini is review-only.
