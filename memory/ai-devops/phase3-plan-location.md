---
name: phase3-plan-location
description: "Remaining config-consolidation work lives in ai-devops/plan_phase3-config-consolidation.md — Albert will not remember the path, so surface it whenever he asks what's left"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c2b905f-9e65-49f5-b5bf-9d73bab09ead
  modified: 2026-07-26T19:15:03.972Z
---

The remaining **config-consolidation Phase 3** work is specified in
`plan_phase3-config-consolidation.md` at the root of the `u2giants/ai-devops`
clone (`C:\repos\ai-devops` on Windows, `/worksp/ai-devops` on Linux; self-contained, 13
sections, has a STATUS table at the top). Phases 1 and 2 are complete
(Phase 2 adopted on `t16` and `al8960ofc`; `916` and Ubuntu servers beyond `hetz`
still need `git pull` + `bin/setup-machine.ps1` / `bin/setup-secrets.sh`).

**Why this memory exists:** Albert asked, fairly, *"you expect me to memorize a
file path 3 months from now?"* He should not have to. When he asks anything like
"what's left on the config consolidation", "did we finish the dotfiles work",
"is Dropbox retired yet", or resumes this topic at all — **open that plan file and
read its STATUS table first**, then answer. Do not re-derive the state from git or
re-plan it.

Discovery paths already wired (any one of them finds it): `AGENTS.md` §Pending work,
`HANDOFF.md` header, `docs/config-consolidation-proposal.md` §Phase 3, and the
`Related` section of both `sync-dotfiles` skills.

**Next open step is 5** (stub the three current Dropbox scripts — needs his
confirmation, they sit outside the repo). The un-negotiable finding in there:
`C:\Dropbox\vibe coding\ssh keys\916-alien` is the **916-alien private key in
plaintext**, and 16 files in the Dropbox MCP-setup folder carry token-shaped
literals. Inventory/report only — never delete or rotate without his approval.

See [[trigger-pat-cli-whoami-false-negative]] and [[op-account-migration-2026-07]].
