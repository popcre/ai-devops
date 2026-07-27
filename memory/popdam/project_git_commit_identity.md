---
name: project_git_commit_identity
description: Pushes to u2giants repos are rejected for email privacy unless the commit author is the noreply address
metadata: 
  node_type: memory
  type: project
  originSessionId: 480d4875-231f-47a5-928b-952f0dac48f8
  modified: 2026-07-27T22:08:58.639Z
---

Committing in a **fresh `git worktree`** of a `u2giants` repo (shared-db,
popdam3, …) and then pushing fails with:

```
! [remote rejected] <branch> (push declined due to email privacy restrictions)
```

**Why:** GitHub's "block command line pushes that expose my email" setting is on
for the account. A worktree does not inherit the parent checkout's local
`user.email`, so a commit made with `-c user.email=u2giants@gmail.com` (or the
global default) is rejected at push time, after the commit already exists.

**How to apply:** author commits in any u2giants repo/worktree as
`55610577+u2giants@users.noreply.github.com`. If you only notice after the
rejected push, `git -c user.email=55610577+u2giants@users.noreply.github.com
commit --amend --no-edit --reset-author` fixes it without redoing the work.
The main `/worksp/shared-db` checkout already has this configured locally;
worktrees created off it do not. Verified 2026-07-27.

Related: [[project_popdam_shared_env]], [[project_secret_access_paths]].
