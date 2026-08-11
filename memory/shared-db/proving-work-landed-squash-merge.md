---
name: proving-work-landed-squash-merge
description: "How to prove a branch/worktree's work already landed — git cherry and merge-base both fail on squash merges; compare added lines to main's current file content"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0197336e-f10b-43fd-81c4-4963aa1c2e61
  modified: 2026-08-11T21:32:29.083Z
---

To decide whether a branch or worktree still holds unique work, compare its
**added lines against `origin/main`'s current file content**. That is the only
test that survives squash merges, rebases and rewordings.

```bash
git diff origin/main...HEAD -- "$f" | grep '^+' | grep -v '^+++' | sed 's/^+//;s/^[ \t]*//' | grep -v '^$' > /tmp/a.txt
git show "origin/main:$f" | sed 's/^[ \t]*//' > /tmp/m.txt
grep -Fxvf /tmp/m.txt /tmp/a.txt   # lines genuinely absent from main
```

**Why the obvious tests are wrong:**
- `git log origin/main..HEAD` / `merge-base --is-ancestor` — a squash-merged
  branch is never an ancestor, so all its commits read as unlanded.
- `git cherry origin/main HEAD` — detects a *single*-commit squash, but **not a
  multi-commit squash**. 13 commits collapsed into one PR commit match no
  individual patch ID, so all 13 read as unlanded.

Measured on `u2giants/shared-db` 2026-08-11 (issue #682): `cherry` reported 18
worktrees holding unlanded work; the line-content test proved 15 of them fully
landed. A dirty worktree is also not proof of unique work — `prod-lane` held 7
modified files and 555 added lines, every one already in `main`.

Gotchas: pass `export MSYS_NO_PATHCONV=1` in Git Bash on Windows or paths like
`origin/main:.github/...` get mangled. Whitespace-strip both sides or
indentation changes read as false positives.

See [[shared-db-apply-mechanics]], [[shared-db-read-only-is-open]].
