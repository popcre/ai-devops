---
issue: 2041
status: OPEN
owner: claude/skinny-review
---

# HANDOFF — skinny advisory review (edge-dev3/claude, 2026-10-29)

Albert's ruling (2026-10-29 afternoon): review is advice only and never blocks a merge. One reviewer per PR, rotating through Muse, GLM, DeepSeek and StepFun. One look per PR. No review for docs-only PRs. Remove all of the old reviewer machinery.

- **Plan:** [plan_simple-reviewer-rebuild.md](../plan_simple-reviewer-rebuild.md). Read its STATUS table and REVISION section first.
- **Checklist:** [docs/reviewer-enforcement-inventory-2026-10-29.md](../docs/reviewer-enforcement-inventory-2026-10-29.md) (59 rows).
- **Evidence:**
  - [docs/reviewer-observation-week-2026-10-22.md](../docs/reviewer-observation-week-2026-10-22.md)
  - [docs/review-value-by-repo-vs-work-2026-10-29.md](../docs/review-value-by-repo-vs-work-2026-10-29.md)

## State at about 4:45 PM EDT, 2026-10-29

- **PR #2044** adds `bin/ai-review-simple` and `.github/workflows/ai-review.yml`. It is in the merge queue. One earlier queue run failed on a flaky `test-ai-install-skills.sh`, which passes locally, and the PR was re-queued.
  - Its workflow still uses the blocking 4-reviewer rule. Phase A makes it advisory: pass/neutral only, one rotating reviewer, runs on `opened`/`ready_for_review`, skips docs-only PRs.
- **Freeze window:** extended to 2026-11-12T14:56Z on edge-dev3, hetz, edge-dev, 4837 and 916. This keeps code and prose merges unblocked until phase B lands. Delete it in phase E.
- **Phase B** (ai-devops `ai-task-gates` review gates): a subagent was opening a PR. Check `gh pr list -R popcre/ai-devops --search 2041`.
- **Phase C** (shared-db merge gate): a subagent was opening a shared-db issue and PR. Check `gh issue list -R popcre/shared-db --search 2041`.
- **StepFun:** Albert topped up its credit at about 4:00 PM EDT.
- **#1996** (the paused-work list) was triaged. Most of its items are superseded by #2041.

## Next steps

1. Merge #2044, then do phase A on a new branch.
   - Done when: a code PR gets one reviewer comment and a green or neutral check, and a docs-only PR shows "not needed".
2. Finish B and C, then do D, E and F, using the inventory.
3. Close #1948 and #2041 when the inventory is empty and the window file is deleted.

## Constraints

- Prose PRs: `bin/ai-doc-safety .`, then `gh pr merge --squash --admin`.
- Code PRs go through the merge queue.
- Never write a sleep loop on PRs; a hook blocks it. Use `bin/ai-pr-wait`.
- Sign GitHub posts with `$AI_GH_SIGNATURE`.

## Completeness check

- **Can a newcomer continue?** Yes: the plan's REVISION section, the inventory and this file give the state, rules and next steps.
- **Is it detailed enough?** Yes: PR numbers, the window-file path and date, and how to find the B and C work are listed.
- **Is every detail included?** Yes, with one known gap: the B and C PR numbers were not yet known when this was written. The search commands above find them.
