---
name: codex-portable-facts
description: Search Albert's protected portable Markdown memory with ai-facts. Use when a Codex task needs a prior cross-machine fact, earlier project decision, known machine fact, or remembered fix that is not already in the current repository context. Never read or synchronize Codex SQLite memory.
---

# Portable facts

Use the client-neutral, read-only command:

```bash
ai-facts search --json "specific phrase"
```

Start with a narrow phrase. Read only the matching Markdown files needed for the
task. `ai-facts index` reports coverage without exposing fact contents.

If the private hub is absent or rejected, run `ai-sync-memory` through the normal
private-memory procedure. Never point `ai-facts` at public `ai-devops`, raw
transcript archives, or Codex's machine-local SQLite store. This skill retrieves
facts; it does not update or synchronize memory.
