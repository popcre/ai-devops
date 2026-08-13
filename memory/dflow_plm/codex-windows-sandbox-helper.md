---
name: codex-windows-sandbox-helper
description: "Codex `-s workspace-write` fails with missing sandbox helper — call the fully-provisioned codex.exe, not the Programs\\ copy"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 91ae39e2-3137-4971-88f9-4ed8217e3c3d
---

Running `codex exec -s workspace-write` can fail with **"codex-windows-sandbox-setup.exe not found"**. Cause: the `codex.exe` at `C:\Users\ahazan2\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe` is a standalone copy with **no co-located `codex-resources/`** (the folder holding the sandbox helper), so the sandbox can't launch.

Fix: invoke the fully-provisioned install instead —
`C:\Users\ahazan2\AppData\Local\OpenAI\Codex\bin\codex.exe`
(that `bin` has `codex.exe`, `codex-command-runner.exe`, `codex-windows-sandbox-setup.exe`, `node.exe`, `rg.exe` all together). Then `-s workspace-write` works and the auto-mode classifier permits it — no need for `--dangerously-bypass-approvals-and-sandbox` (which the classifier blocks in auto mode anyway).

Use `workspace-write` for purely-local Codex tasks (source edits + running installed tests, no network). See [[codex-concurrency-incident]] — don't run Codex on repos another agent is editing.
