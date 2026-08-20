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

Read the report path printed by the command. A Muse result is valid only when it
carries a final `VERDICT: <word>` line. The wrapper accepts whatever verdict word the
review asked for, so a brief may set its own vocabulary (`APPROVE` / `REVISE` is
common); if your brief does not name one, the wrapper asks for `VERDICT: FINDINGS` or
`VERDICT: NO FINDINGS`. Write the verdict wording into your brief once, not twice —
the wrapper leaves a brief that already says `VERDICT:` alone.

A stop with no verdict line at all is a genuinely incomplete review and is saved
separately as `muse-incomplete-*.md`. Do not substitute GLM, another model, or your own
opinion without stating that Muse did not complete.

The report header records the verdict the wrapper extracted, so you can confirm what
was detected without re-reading the whole review.
