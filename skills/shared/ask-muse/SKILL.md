---
name: ask-muse
description: Start or continue a persistent protected Muse Spark 1.3 Contributor review, debate, or implementation. Use when the user says "review with Muse", "ask Muse", "debate Muse", "Muse review", "have Muse implement/build/fix X", or requests a Muse Spark second opinion.
---

# Ask Muse

Use `ai-muse` only. Do not call OpenCode, the Meta API, or 1Password directly.
Review is advice only (owner ruling 2026-10-29, #2104).

`ai-muse` is a thin entry to `bin/ai-second-opinion muse`, the same OpenCode
path the advisory CI reviewer uses. Every call runs on a private copy of the
repository (HEAD plus uncommitted changes, no git remote); your checkout is
never touched. Named sessions keep their conversation.

```bash
ai-muse doctor [--live]
ai-muse new <stable-name> --prompt-file <brief-file>
ai-muse ask <stable-name> --prompt-file <follow-up-file>
ai-muse review --repo . --base origin/main [--prompt-file <brief>]
ai-muse implement <name> --prompt-file <brief>    # private writable copy; prints the diff
ai-muse diff <name> | git apply
ai-muse transcript <stable-name>
ai-muse list | show <name> | abort <name> | delete <name>
ai-muse store-key [--if-missing]                  # installer use: key from 1Password to the private store
```

Report Muse's view, say whether you agree, and push back with evidence when
you do not. Exit code 3 means Muse was unavailable; use another second-opinion
tool instead of retrying in a loop. The implementer edits files but cannot run
commands, so run the tests yourself after applying its diff.
