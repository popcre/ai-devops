---
name: delegated-sandboxes-get-no-credentials
description: "ai-glm implement sandboxes do not inherit the caller's environment, so a delegated model can never run a credentialed gate; the owner session must run it."
metadata: 
  node_type: memory
  type: project
  originSessionId: f002c731-d877-4ed7-b6bf-629d76f51f05
  modified: 2026-08-14T16:21:06.938Z
---

`ai-glm implement` runs in a throwaway clone that does NOT inherit the calling
shell's environment. On 2026-08-14 two jobs were launched with `PROD_DB_URL`
resolved in the parent process via 1Password `op_run`; both reported the variable
missing and could not run the database-backed gate.

**Why:** the wrapper deliberately isolates the sandbox. Injecting the value into
the parent shell does not cross that boundary.

**How to apply:** never brief a delegated model to run a credentialed check — it
will build the check and report it unrun. Have it write the check, then run the
credentialed pass yourself in the real checkout with `op_run` injecting the
secret as an env var. Two related traps from the same session: `op_run` caps
`timeout_ms` at 600000 while these jobs take 25-35 minutes, so launch them
detached with `Start-Process` and poll `ai-glm list`; and `ai-glm show <name>`
only works from the job's recorded repository root.

Related: [[no-hardcoded-model-names-in-adapters]]
