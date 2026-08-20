<!-- handoff-pointer: v1 — do not rewrite this file; add a file under HANDOFF.d/ instead -->
# HANDOFF

Active handoffs live in [`HANDOFF.d/`](HANDOFF.d/) — one write-once file per AI
session, named `<UTC-timestamp>-<machine>-<agent>-<slug>.md`.

**Starting a session:** list `HANDOFF.d/`, read the open files **newest first**.
Every file present is an OPEN workstream; finished ones are deleted (git history
keeps the text).

**Ending a session:** create your OWN new file in `HANDOFF.d/` following
`templates/system/handoff-standard.md` (all 9 sections). **Do not rewrite this
file, and do not edit another session's file.** Concurrent sessions rely on that.

## Known active tooling defects

Not handoffs — standing faults every session should know about before trusting a
tool's output.

- [**The false `.ai/reviews is not git-ignored` warning**](docs/reviewer-wrapper-gitignore-false-warning.md)
  — affects `ai-kimi`, `ai-grok-review`, `ai-gemini` and the save path around
  `ai-muse`. The warning is wrong, and its effect is that the wrapper **silently
  skips writing the review file**. That file is the recovery path when a wrapper
  mishandles its own output: on 2026-08-19 it is why a lost Kimi review was
  unrecoverable and a lost Muse review was not.
- [Reviewer trial, 2026-08-19](docs/reviewer-trial-2026-08-19-glm-gemini-muse.md) —
  GLM restored, Muse promising, Gemini not usable, with the measurements behind each.
