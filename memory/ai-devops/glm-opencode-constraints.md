---
name: glm-opencode-constraints
description: "GLM runs on a local OpenCode server via `ai-glm`; the constraints that keep it safe are counter-intuitive and documented in docs/glm-opencode.md section 5 - read it before touching GLM or Windows setup."
metadata: 
  node_type: memory
  type: project
  originSessionId: 2999cf37-e63c-489b-9508-a045f728ce11
  modified: 2026-08-04T13:46:11.755Z
---

GLM (2026-08-04 onward) runs as named persistent sessions on a loopback OpenCode
server, driven by `ai-glm`. The old `ai-glm-agent` (GLM inside Claude Code) is
deleted.

**Before changing anything GLM- or Windows-setup related, read
`docs/glm-opencode.md` section 5 "Hard-won constraints".** It lists 23 rules, each
of which cost a real failure. `AGENTS.md` routes there.

The two least obvious, because they look like things worth simplifying:

- In OpenCode 1.18.12 **only the agent-file `tools:` map enforces anything**. The
  session `permission` array and the agent `permission.bash` map are both no-ops
  (measured: an agent denying `git push*` ran it). `glm-implement` is allowed a
  shell ONLY because its sandbox is a clone with `git remote remove origin` - the
  missing remote is the control, not any deny rule. Never swap that clone back to
  a `git worktree` without also setting `bash: false`.
- Repo-owned `.ps1` files must be **pure ASCII**. Windows PowerShell 5.1 reads a
  BOM-less `.ps1` as Windows-1252, so a UTF-8 em dash becomes a smart quote and
  silently corrupts the rest of the file. Two em dashes aborted setup on all three
  Windows machines and stopped skills installing anywhere.

Related: [[4837-home-drive-z-trap]] (why Windows paths use `%USERPROFILE%`),
[[glm-agent-zai-field-and-forkbomb]] (the ZAI key field + re-exec guard, still
applies to `opencode-glm-launch`).
