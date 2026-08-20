---
name: ask-muse
description: Start or continue a persistent protected Muse Spark 1.2 Contributor review or debate. Use when the user says "review with Muse", "ask Muse", "debate Muse", "Muse review", or requests a Muse Spark second opinion.
---

# Persistent Muse review and debate

Use `ai-muse` only. Do not call OpenCode, the Meta API, or 1Password directly.

Muse uses named persistent conversations in a disposable, self-contained copy of the
target repository. It has no write or shell tools. No other model is used if Muse fails.

First check the runner:

```bash
ai-muse doctor
```

Start once from the repository root:

```bash
ai-muse new <stable-name> --prompt-file <brief-file>
```

Continue the exact conversation for objections, rebuttals, or new evidence:

```bash
ai-muse ask <stable-name> --prompt-file <follow-up-file>
```

Codex is the default caller. In Bash, Claude uses `AI_MUSE_CALLER=claude ai-muse ...`.
In PowerShell, use `$env:AI_MUSE_CALLER='claude'` before `ai-muse ...`. Never create a replacement
session when the named one can be continued. Read the report path printed after each
turn; use `ai-muse transcript <stable-name>` for the full conversation.

If `ask` says reconciliation is required, inspect that transcript first, then run
`ai-muse reconcile <stable-name>` only when you deliberately accept the recorded
provider state. Never bypass or silently replace an uncertain session.

For a code review, tell Muse to read the manifest in its evidence packet first.
The packet directory is named after the session (`.ai-review-muse-<caller>-<name>`),
not a fixed `.ai-review`, so two reviewers working from one checkout cannot
overwrite each other's evidence. Take the exact name from the path the wrapper
prints. For a focused debate that does not need repository inspection, do not
force a packet read.

A turn is valid only when the wrapper proves OpenCode's structured stop event, the
exact session ID, and non-empty response text. Do not substitute GLM, another model,
or your own opinion without stating that Muse did not complete.
