---
name: git-commit-identity
description: How to commit in the dflow repos — git user.* is unset; use per-command -c flags
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0057598e-90ba-4bdd-939a-d204b1cf673b
---

In the dflow repos, git `user.name`/`user.email` are **not configured in any scope** (local/global/system all empty). Set identity per-commit:

```
git -c user.name="Albert Hazan" -c user.email="u2giants@users.noreply.github.com" commit ...
```

**Use the GitHub noreply email `u2giants@users.noreply.github.com`** — it matches recent `designflow-frontend` history (`Albert Hazan <u2giants@users.noreply.github.com>`) and pushes cleanly. Pushing with `u2giants@gmail.com` (or `albert@popcre.com`) is **rejected with `GH007: Your push would publish a private email address`** because the account has email-privacy protection on. If you committed with the wrong email, fix with `git -c user.email=...noreply... commit --amend --reset-author --no-edit` then push.

End commit messages with the `Co-Authored-By: Claude ...` trailer. See [[user-albert]] and [[dflow-delivery-workflow]].
