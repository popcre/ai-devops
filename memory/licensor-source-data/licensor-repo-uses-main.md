---
name: licensor-repo-uses-main
description: licensor-source-data commits go straight to main, overriding the wb-starlabs-scrape skill's branch-and-PR instruction.
metadata:
  type: feedback
---

Work in `u2giants/licensor-source-data` is committed directly to `main`. No branch,
no pull request.

The `wb-starlabs-scrape` skill says to clone fresh, work on a dedicated Warner branch
and open a PR. Albert overrode that on 2026-08-20: "main is fine". His standing
main-only rule wins.

**Why:** he is the only reviewer, so a PR adds a step and no safety.

**How to apply:** commit and push to `main` in this repo without asking. Still never
touch another session's licensor folder. See [[orchestrator-is-structure-only]].
