---
name: ask-muse
description: Run an independent protected code review with Muse Spark 1.2 Contributor. Use when the user says "review with Muse", "ask Muse", "Muse review", or requests a Muse Spark review.
---

# Review with Muse

Use `ai-muse` only. Do not call OpenCode, the Meta API, or 1Password directly.

Muse runs one read-only review in a disposable, self-contained copy of the target
repository. It has no write or shell tools. The original repository is not supplied
to the model, and no other model is used if Muse fails.

First check the runner:

```bash
ai-muse doctor
```

Then run the review from the repository root:

```bash
ai-muse review "$PWD" "Review the current changes. Report concrete findings with file paths, severity, and missing tests."
```

Read the report path printed by the command. Treat a failed command as a failed Muse
review. Do not substitute GLM, another model, or your own opinion without stating that
Muse did not complete.
