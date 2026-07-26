---
name: git-identity-silent-guess
description: Git has no default identity — with none configured it silently invents one from the Windows/AD account (albert@popcre.com) instead of failing. That put 231 wrong-identity commits into merged dflow develop+main. Fixed machine-wide via bin/ai-git-identity + useConfigOnly.
metadata: 
  node_type: memory
  type: project
  originSessionId: c51bced3-6465-4ace-8a9e-9a740c750c7d
  modified: 2026-07-26T18:06:20.561Z
---

**The failure:** Git does not require an identity to be configured, and when one
is missing it does **not** stop. It derives `user.name`/`user.email` from the OS
account — on Windows, the AD profile — and stamps that on every commit with no
warning. On al8960ofc there was **no global identity at all** (no `--global`, no
`--system`, no `EMAIL`/`GIT_AUTHOR_EMAIL`), so every repo lacking a local
override committed as `Albert Hazan <albert@popcre.com>` instead of the required
`u2giants@users.noreply.github.com`.

**Damage found 2026-07-26:** 231 commits with the wrong email were already merged
into **both `develop` and `main`** across the dflow repos (184 frontend, 41
backend, 6 tracking). Those are unfixable in practice — correcting them means
force-pushing shared release history to the whole team. Only ~8 commits were
still unmerged; those were rewritten (identity only; trees byte-identical) and
force-pushed with `--force-with-lease`.

**The fix (hub, commit `734a283`):** `bin/ai-git-identity` sets
`user.name`, `user.email`, and crucially `user.useConfigOnly=true` — which makes
Git **fail loudly** instead of guessing if the config is ever lost. Wired into
`install.sh`, `bin/setup-machine.ps1`, and BOTH sync-dotfiles skills, plus
standing rule 20b in both global instruction templates.

**How to apply:**
- This is **per-machine, never per-agent.** Claude, Codex, GLM, Grok and Kimi all
  shell out to the same `git` binary, so one global setting covers every agent.
  Do not add per-agent identity config — it is the wrong shape.
- Before the first commit in an unfamiliar repo, run
  `git var GIT_COMMITTER_IDENT`. Fix it BEFORE committing; afterwards means
  rewriting history.
- Only rewrite wrong-identity commits **not yet merged into a shared branch**.
  Verify with `git merge-base --is-ancestor <sha> origin/develop`.
- A repo-local `user.email` silently overrides the global one — `ai-git-identity`
  reports those; check for them before assuming the global fix applied.
- On Windows, setting `--global` from Git Bash can land in the wrong file when
  `$HOME` is a network drive ([[4837-home-drive-z-trap]]); the script detects
  that and writes to `%USERPROFILE%` instead.

**Still outstanding:** only al8960ofc/4837 is fixed — and note that
[[4837-is-this-machine]] means that is a single computer, not two. Machine `916`
still needs `sync my dotfiles` when it is next online.
