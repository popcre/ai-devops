---
name: gemini-code-delegation
description: Use Gemini 3.7 Flash through the ai-gemini wrapper for an independent read-only repository review. Trigger when the user says ask Gemini, use Gemini, Gemini review, run this by Gemini, or Gemini 3.7 Flash.
---

# Gemini code review

Use `ai-gemini`, never `agy` directly, for a repository review. The wrapper uses
a disposable copy, enables containment, checks that the copy did not change, and
verifies the exact Gemini model before accepting its response.

```bash
AI_GEMINI_CALLER=codex ai-gemini doctor
AI_GEMINI_CALLER=codex ai-gemini new <work-name> --prompt-file <brief-file>
AI_GEMINI_CALLER=codex ai-gemini ask <work-name> --prompt-file <follow-up-file>
```

Use a specific name such as `payment-review`, not `gemini`. Reuse the same name
for follow-up questions. Gemini is review-only: do not ask it to edit, commit,
push, deploy, change a database, or access secrets.

Write a short brief that names the change, relevant paths, constraints, and the
decision required. Do not paste secrets or file contents. Treat an empty answer,
wrong model, changed review copy, or stale checkout as a failed review, not an
approval. The report is written under `.ai/reviews/`.
