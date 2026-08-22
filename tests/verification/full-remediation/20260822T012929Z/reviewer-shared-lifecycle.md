# Shared reviewer lifecycle verification

Date: 2026-08-22 UTC

Implemented:

- `ai-review-sandbox` builds into a private partial directory and publishes only
  after two matching whole-source digests.
- Diff generation and every untracked-file copy fail closed. A failed build
  preserves the last complete snapshot and removes partial output.
- Snapshot identity includes the committed tree, the complete binary tracked
  diff, and a NUL-safe inventory of every review-visible untracked file.
- `ai-review-packet` refuses a stale snapshot marker, binds the source digest in
  its manifest, and rechecks the source before sealing.
- `ai-review-lifecycle` owns normalized upstream identity, assignment locks,
  mandatory provider preflight, running and terminal state, stale-source
  rejection, report hashes, scoreboard accounting, and exact incident joins.
- `ai-review-scoreboard` records source/upstream/report identity and validates a
  lifecycle source digest before calling evidence current.
- `ai-reviewer-issue` accepts an exact lifecycle state and carries the source
  digest into metadata and scoreboard joins.

Focused evidence:

- `test-ai-review-sandbox.sh`: 62 passed, 0 failed.
- `test-ai-review-packet.sh`: 90 passed, 0 failed.
- `test-ai-review-lifecycle.sh`: 22 passed, 0 failed.
- `test-ai-review-preflight.sh`: 26 passed, 0 failed.
- `test-ai-review-scoreboard.sh`: 15 passed, 0 failed.
- `test-ai-reviewer-issue.sh`: 28 passed, 0 failed.
- `test-ai-memory-health.sh`: 17 passed, 0 failed.

The first real Linux CI run, `32542691543`, also exposed that six existing
shebang tools and the Muse setup script had been committed without executable
bits. That caused eight apparent provider/test failures through one shared
permission error. Their Git modes are now corrected; a new workflow run is the
remaining Step 8 proof.
