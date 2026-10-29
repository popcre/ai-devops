# Shared OpenCode reviewer plugins

`verdict-stop.js` is copied into the per-run OpenCode config home of every
OpenCode reviewer: the StepFun, DeepSeek and Muse (OpenCode engine) review
doors, `bin/ai-stepfun`, `bin/ai-deepseek` and `bin/ai-muse`, on Windows and
Linux. The one installer is `reviewer_opencode_verdict_stop` in
`tools/lib/reviewer-instructions.sh`; no reviewer keeps its own copy.

Their profiles keep `compaction.auto` on with pinned OpenCode 1.18.12. After an
automatic compaction OpenCode injects a synthetic "Continue if you have next
steps" message; once the model has written its final verdict the plugin
declines that continue, so a finished review ends instead of running on.
Compaction before the verdict still continues as before. The plugin recognises
the verdict shapes the doors record (a `## Verdict` heading block, or a
terminal bare / `VERDICT:` line).

GLM is not covered: its formal profile (`tools/glm_formal_profile.py`) forbids
every plugin by design.

`tests/test-opencode-verdict-stop.sh` checks the installer, every entry point,
the plugin behaviour, and the hook contract against the installed pinned
binary when present.
