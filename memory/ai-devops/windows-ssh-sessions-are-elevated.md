---
name: windows-ssh-sessions-are-elevated
description: "SSH into the Windows machines (4837, 916) lands in an ELEVATED session, so remote \"can a normal user do this?\" tests pass for the wrong reason."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5d0b845c-0ed3-4c34-8e5a-80dd00816fc8
  modified: 2026-08-06T19:32:41.996Z
---

An SSH session into Albert's Windows machines (`4837`, `916`) runs **elevated**.
Those hosts authenticate admin users through
`%ProgramData%\ssh\administrators_authorized_keys`, so the session holds the full
administrator token — unlike a normal interactive PowerShell window, which does not.

**Why:** on 2026-08-06 this produced a confidently wrong answer. Testing whether an
ordinary user could redefine the `AiDevOps-OpenCodeGlm` scheduled task on 4837
succeeded over SSH, and was reported as "4837 is fine". Reading the task's actual
DACL showed the opposite: Full Access to `Administrators`, read-only for the user.
The write had succeeded because the session was elevated, not because permissions
were correct.

**How to apply:** never test a permission question by attempting the operation over
SSH. Read the permission directly (`icacls`, or `Schedule.Service` →
`GetSecurityDescriptor(4)` for tasks) and compare against a known-good machine.
If an elevation-sensitive test is unavoidable, first print
`([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')`
and state that context in the finding. Related: [[remote-shell-cwd-trap]].
