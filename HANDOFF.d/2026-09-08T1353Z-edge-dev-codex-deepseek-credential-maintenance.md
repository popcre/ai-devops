---
issue: 326
status: BLOCKED
owner: codex/deepseek-rotation-handoff-326
---

# 0. Decisions only the owner can make

None. Albert already authorized rotating the DeepSeek credential on September 8,
2026 only if he does not have to perform any step himself. Do not ask him to log
in, copy a value, or revoke the old credential. If no approved private automated
authentication path becomes available, keep issue #326 blocked rather than
weakening that condition.

Already settled — do not re-ask: credential values stay private; use 1Password
vault `vibe_coding`; preserve the working DeepSeek capability throughout rotation;
Albert performs no manual action.

# 1. What this application is

`popcre/ai-devops` is POP Creations' public backup-and-restore toolkit for local
AI reviewer commands on Windows and Ubuntu. EDGE-DEV uses the landing-only checkout
at `C:\repos\ai-devops`; installed commands are under the user's `.local\bin`.
Credentials are machine-local and belong in 1Password vault `vibe_coding`, never
in this public repository, a GitHub issue, command arguments, or logs.

# 2. What we set out to do this session, and why

The main task implemented reviewer lifecycle diagnostics and quota preflight from
plan `plan_reviewer-diagnostics-quota-preflight.md`. Albert separately authorized
rotation of the existing DeepSeek credential, provided he would not need to do
anything. Rotation matters because the prior session classified that credential
as exposed and therefore potentially compromised.

# 3. Current state — what is true right now

The reviewer-diagnostics work is complete: code PR #324 merged as
`a570069a95d06c271895a33565785c2784e32a8b`; evidence PR #325 merged as
`0f65898345bea98e29fbee40f85ac62220ab1d88`; issue #312 is closed; all Linux and
Windows CI jobs in run `34218291867` passed; exact-head independent review
approved; installed Kimi, Grok and GLM canaries returned terminal APPROVE.

DeepSeek rotation is not complete. No authenticated DeepSeek provider-console
session or saved login was available, so no replacement credential was created
and the existing credential remains active. No credential value was printed,
committed, or copied into this handoff.

The canonical checkout is clean at `a570069a...`, one documentation-only commit
behind `origin/main` (`0f658983...`). It was deliberately not fast-forwarded during
closeout because a separate shared-db task had resumed eight reviewer processes
using the installed toolkit. The installed functional code already matches the
code merge; only the closeout Markdown is absent locally.

# 4. Everything we tried that did not work

An automated DeepSeek rotation was attempted through the available provider path.
It could not reach credential management because the machine had no authenticated
provider-console session and no saved login suitable for private automation.
Creating a new credential by guessing endpoints, exposing credentials in browser
automation, or asking Albert to complete a manual login would violate the approved
scope, so none was attempted.

During workspace cleanup, permanent recursive deletion of the synthetic reviewer
canary folder was rejected by the safety layer. The exact verified temp folder was
instead moved to the Windows Recycle Bin, which succeeded and remained recoverable.

# 5. Root causes and key findings

The blocker is authentication state, not repository code and not a failed
DeepSeek reviewer command. Rotation requires an authenticated credential-management
session that this machine does not currently have. 1Password can store and deliver
the replacement privately once created, but it cannot create or revoke a provider
credential without provider authorization.

The main reviewer-diagnostics implementation needs no follow-up. Capacity is
honestly `unknown` when a provider lacks a qualified non-generating quota endpoint;
that state preserves working reviewer access rather than disabling it.

# 6. Exact next steps

1. Confirm no local reviewer process is using `C:\repos\ai-devops`, then
   fast-forward that clean canonical checkout to `origin/main`. Success means
   both resolve to `0f65898345bea98e29fbee40f85ac62220ab1d88` and status is clean.
2. Load the `secrets-to-1password` skill and verify a private, already-authenticated
   DeepSeek credential-management route exists without displaying auth material.
   Success means the provider console/API can list credential metadata privately.
3. Create one replacement credential, pipe it directly into the existing DeepSeek
   item in 1Password vault `vibe_coding`, and never place it in argv, chat, logs,
   repository files, or clipboard. Success means 1Password reports the item update
   without revealing the value.
4. Run the repository-owned DeepSeek doctor/live verification through its supported
   wrapper using the replacement. Success means the original capability completes
   normally with no secret in output.
5. Revoke the prior credential through the same authenticated private route and
   verify it is inactive while the replacement still works. This ordering prevents
   loss of capability.
6. Add private-safe evidence to issue #326, close it, and delete this handoff in
   the same documentation-only PR. Success means issue #326 is CLOSED, the PR is
   merged, and this file is absent from `origin/main`.

# 7. Constraints and gotchas in force

Use an isolated current-upstream worktree for repository writes. Never expose a
credential value, inspect raw transcripts, put secrets in command arguments, or
publish provider-console details. Serialize 1Password access. Create and verify
the replacement before revoking the old credential. Do not disable or replace the
DeepSeek capability to make rotation appear complete. Do not update the canonical
checkout while another session is using installed reviewer files. Do not touch the
shared-db orchestrator marker; it belongs to the separate `shared-db.orch` task.

# 8. Access and environment

Host: EDGE-DEV, Windows, PowerShell and Git Bash. GitHub CLI is authenticated for
`popcre/ai-devops`. Repository source of truth is `origin/main` at
`0f65898345bea98e29fbee40f85ac62220ab1d88`. Credential storage is 1Password vault
`vibe_coding`; item names and values must be resolved through current authorized
configuration, not guessed. DeepSeek provider-console authentication is unavailable.

# 9. Open questions and risks

As of September 8, 2026, it is unknown when an approved private authenticated
DeepSeek management session will become available. Until rotation succeeds, the
existing credential remains active and should be treated as potentially compromised.
Do not claim rotation or revoke first. The public issue and handoff intentionally
contain no credential value or private provider URL.

## Mandatory self-audit

1. Yes: sections 1–9 define the toolkit, purpose, exact merged state, blocker,
   failed attempt, next commands in outcome terms, constraints, access, and risks.
2. Yes: sections 3–6 preserve every relevant commit, run, blocker, dead end, and
   ordered verification gate needed to continue without this chat.
3. Yes: sections 2–9 cover background, goal, intended outcome, current state,
   failures, findings, constraints, risks, next actions, and completion evidence.
4. Yes: a line-by-line owner-decision sweep found only the already-settled
   no-manual-action condition; section 0 states it and instructs the next session
   not to re-ask. No other sentence in sections 1–9 requires Albert's judgement.
