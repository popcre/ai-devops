# Handoff: two open plans (manifest split, self-healing locks/settings)

Written 2026-09-28 1:55 PM EDT by Claude on edge-dev3. No implementation started.

- [plan_split-ci-suite-manifest.md](../plan_split-ci-suite-manifest.md): split
  `config/ci-suite-manifest.json` so tool fixes stop serializing. Start at its Step 0,
  which proves the collision first.
- [plan_self-healing-locks-and-settings-drift.md](../plan_self-healing-locks-and-settings-drift.md):
  stale-lock recovery plus a live merge-queue settings drift check. Start at Step 1.

Each plan has one owner issue in popcre/ai-devops, named in its header. Read each plan's
STATUS table first.

Related completed work: PR #999 staggered BlockerWatch ticks per machine to stop GitHub
rate-limit bursts. edge-dev3 is at minute offset 3 and edge-dev at offset 9. hetz was
unreachable over SSH ("Host key verification failed"), so whether hetz runs the watcher
is unverified.
