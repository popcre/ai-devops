---
issue: pending — plan step 0.2 files it
status: OPEN
owner: kimi/review-packet-race-plan
---

# HANDOFF — review-packet race + slow-evidence plan (2026-09-18 16:06 UTC, edge-dev, Kimi)

The executable plan is
[`../plan_review-packet-race-and-evidence-speed.md`](../plan_review-packet-race-and-evidence-speed.md).
**Read its STATUS table first.** All steps are open; no implementation has
started.

## What this workstream is

Three fixes after a 2026-09-17/18 incident in which four reviewer rejections
and two destroyed review rounds (~2 h) hit a money-handling change: (A) the
evidence tool must warn when `--tests` attaches a slow suite instead of the
focused one; (B) a sealed review packet must survive the target ref moving
FORWARD (recorded base still an ancestor) while still refusing rewrites, HEAD
moves, and tree changes — plus a per-tag private base ref so a rewrite cannot
GC the base out from under sealed evidence; (C) the implementation-plan
standard gains a mandatory adversarial-cases table for trust-boundary work,
mirrored into the shared skill and the task router.

## Next exact action

Plan §9 Phase 0 in a fresh worktree cut from then-current `origin/main`:
overlap re-check via `bin/ai-gh`, file or adopt the tracking issue (0.2), then
`bin/ai-task-gates start --class reviewer-safety` before touching
`bin/ai-review-packet`. PR-C (prose, Fix C) and PR-AB (reviewer-safety,
Fixes A+B) may proceed in parallel after the plan PR lands.

## Decisions only the owner can make

None outstanding. Locked in the plan (§8): HEAD/digest/merge-base checks stay
strict; the slow-evidence signal is advisory only; two implementation PRs, with
the reviewer-safety PR getting the mandatory independent exact-head review.

## Traps for whoever continues

- `tests/test-ai-review-packet.sh` line ~278 (`identity_rejects_target_movement`)
  currently expects a FORWARD ref move to fail — re-scope it to a rewrite; never
  delete the coverage (the file header names tests that must not be weakened).
- Issue #393 (source identity) is CLOSED and locked "mid-run base/head movement
  invalidates authorization" — Fix B touches only the target-ref tip check and
  stays compatible; do not relitigate base/head immutability.
- Do not touch `bin/ai-review-sandbox`. The local-only branch
  `claude/review-snapshot-base-refs` (`0fa5c724`) is already fully upstream per
  `git cherry` — stale #393 remnant, leave it to the normal cleanup route.
- On edge-dev Kimi shells, jq and gh are installed but off PATH:
  `export PATH="/c/Program Files/jq:/c/Program Files/GitHub CLI:$PATH"` before
  `bin/ai-task-gates` / `bin/ai-gh`.
