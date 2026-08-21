---
name: gemini-code-delegation
description: Use Gemini 3.7 Flash through the ai-gemini wrapper for an independent read-only repository review. Trigger when the user says ask Gemini, use Gemini, Gemini review, run this by Gemini, or Gemini 3.7 Flash.
---

# Gemini code review

Gemini is quarantined and must not be used as an approval-capable reviewer until
both Windows and Ubuntu pass the live hostile qualification required by
`plan_gemini_reviewer_safety_repair.md`. Never bypass that quarantine by calling
`agy` directly. `ai-gemini doctor` deliberately reports `QUARANTINED`.

```bash
AI_GEMINI_CALLER=codex ai-gemini doctor
```

Until qualification finishes, stop after `doctor` and choose another governed
reviewer. An empty answer, wrong model or conversation, changed protected file,
committed or uncommitted source drift, interruption, or missing durable report
is always a failed review. Gemini remains review-only even after eventual
qualification.
