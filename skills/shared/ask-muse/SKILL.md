---
name: ask-muse
description: Start or continue a persistent protected Muse Spark 1.2 Contributor review or debate. Use when the user says "review with Muse", "ask Muse", "debate Muse", "Muse review", or requests a Muse Spark second opinion.
---

# Persistent Muse review and debate

Use `ai-muse` only. Do not call OpenCode, the Meta API, or 1Password directly.

Muse uses named persistent conversations in a disposable, self-contained copy of the
target repository. It has no write or shell tools. No other model is used if Muse fails.

First select the actual current client. Never reuse the other client's value:

```bash
# Use exactly one of these in the current shell.
export AI_MUSE_CALLER=codex   # Codex only
export AI_MUSE_CALLER=claude  # Claude only
```

Then check the runner:

```bash
AI_MUSE_CALLER="$AI_MUSE_CALLER" ai-muse doctor
```

Start once from the repository root:

```bash
AI_MUSE_CALLER="$AI_MUSE_CALLER" ai-muse new <stable-name> --prompt-file <brief-file>
```

Continue the exact conversation for objections, rebuttals, or new evidence:

```bash
AI_MUSE_CALLER="$AI_MUSE_CALLER" ai-muse ask <stable-name> --prompt-file <follow-up-file>
```

Caller identity is mandatory. In Bash, use `AI_MUSE_CALLER=codex ai-muse ...` or
`AI_MUSE_CALLER=claude ai-muse ...`. In PowerShell, set `$env:AI_MUSE_CALLER` to
`codex` or `claude` before `ai-muse ...`. Never create a replacement
session when the named one can be continued. Read the report path printed after each
turn; use `AI_MUSE_CALLER="$AI_MUSE_CALLER" ai-muse transcript <stable-name>` for the full conversation.

If `ask` says reconciliation is required, inspect that transcript first, then run
`AI_MUSE_CALLER="$AI_MUSE_CALLER" ai-muse reconcile <stable-name>` only when you deliberately accept the recorded
provider state. Never bypass or silently replace an uncertain session.

Muse can read ONLY the disposable review copy it is given. The wrapper prints that
directory as `Muse review boundary:` and the packet as `Muse evidence packet:` before
each turn. Name files relative to the review boundary. Never put a path from the
source repository, a linked worktree, or a scratch directory in a Muse prompt: those
are outside the boundary and OpenCode refuses them with
`The user rejected permission to use this specific tool call.` — no user is ever
prompted, and Muse then stops after a sentence of preamble having read nothing.
Copy any external material into the prompt text itself instead of pointing at it.

For a code review, tell Muse to read the manifest in its evidence packet first.
The packet directory is named after the session (`.ai-review-muse-<caller>-<name>`),
not a fixed `.ai-review`, so two reviewers working from one checkout cannot
overwrite each other's evidence. Take the exact name from the path the wrapper
prints. For a focused debate that does not need repository inspection, do not
force a packet read.

A turn is valid only when the wrapper proves OpenCode's structured stop event, the
exact session ID, and non-empty response text. Do not substitute GLM, another model,
or your own opinion without stating that Muse did not complete.
