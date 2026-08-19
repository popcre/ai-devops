---
name: shared-checkout-commits-can-land-elsewhere
description: "In C:\\repos\\shared-db other AI sessions switch the working tree mid-session; your commits can attach to their branch and `git push` still reports success"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 542c9c93-9e90-4a76-adc0-55abe2199ec7
  modified: 2026-08-19T19:41:27.707Z
---

`C:\repos\shared-db` is a **shared checkout**. Other concurrent AI sessions run
`git checkout` in it while you are working. On 2026-08-19 this happened twice in one
session: two commits authored after a silent branch switch attached to the *other*
session's HEAD, never reached the intended branch, and `git push` still reported success.

**Why:** the branch shown in your prompt and the branch the working tree is actually on
are different facts. Nothing warns you when they diverge.

**How to apply:**

- After every commit, verify what actually landed:
  `gh pr view <n> --repo u2giants/shared-db --json changedFiles` — the file count is the
  proof, not the push output.
- Recover misplaced commits from `git reflog`, then graft them without touching the
  working tree: set `GIT_INDEX_FILE` to a scratch path, `git read-tree <target>`,
  `git update-index --add --cacheinfo` each file from the lost commit, then
  `git write-tree` + `git commit-tree` + push the resulting SHA to the branch ref.
- Prefer the GitHub Contents API for doc edits on a branch you own — it never races the
  working tree.
- Never `git add -A`, and never `git checkout` to update a branch. Use
  `gh api -X PUT repos/u2giants/shared-db/pulls/<n>/update-branch` instead.

Related: [[shared-db-apply-mechanics]], [[shared-db-merge-gate-nine-checks]]
