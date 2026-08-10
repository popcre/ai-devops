# Handoff: finish the ai-devops rollout on 916

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for installing and
restoring his AI coding setup. It manages Claude and Codex skills, global
instructions, MCP tool wiring, SSH aliases, protected 1Password launchers,
Codex preferences, and the hidden memory-sync task. It is scripts and Markdown,
not a hosted application. The repository is `C:\repos\ai-devops` on Windows and
uses `main` only.

`916` is the Windows 11 development computer also called `916-alien`. Its
Tailscale address is `<removed-protected-address>`. The Windows user is `ahazan2` and the
repo should be at `C:\repos\ai-devops`.

## 2. What we set out to do, and why

The wider all-open-work project is complete except for applying the current
repo-owned machine setup to `916`. The same setup is already proven on the other
reachable Windows computers. Albert asked to preserve the remaining `916` work
as a separate handoff so it can be completed when he turns that computer on.

## 3. Current state

- Repository work, tests, documentation, and the other machine rollouts are
  complete and pushed to `origin/main`.
- The last coordination commit before this handoff was
  `aa395ec30ca7e0c8bfbe58a5dc9c4bb0b010e4c9`.
- On 2026-08-10 at 11:29 UTC, Git for Windows SSH to
  `<removed-protected-address>:22` timed out after eight seconds. No remote command ran and
  no file on `916` was changed.
- `916` therefore has no current verified rollout state. Do not infer that its
  installed skills, Codex path, MCP launchers, or memory task are current.
- No production, cloud, database, or credential change is part of this work.

## 4. Everything tried that did not work

1. A normal TCP/SSH reachability check on 2026-08-10 produced no connection.
2. A direct Git for Windows SSH call with `BatchMode=yes` and an eight-second
   connection timeout returned `connect to host <removed-protected-address> port 22:
   Connection timed out`.
3. Repeating setup from another machine is impossible while `916` is powered
   off. Do not treat the timeout as an authentication or setup-script defect.

## 5. Root causes and key findings

- The blocker is machine availability, not missing repository code.
- The canonical Windows setup is `bin/setup-machine.ps1`; the retired Dropbox
  scripts are pointer stubs and must not be used.
- A successful `codex --version` is not proof that Codex can edit. The real gate
  is the sandboxed write performed by `bin/ai-devops doctor`.
- The setup script requires PowerShell 7. It can wait for input if the protected
  1Password service-account token file is absent, so check that prerequisite
  before unattended execution.

## 6. Exact next steps

1. Turn on `916` and confirm it has joined Tailscale. You will know this worked
   when `<removed-protected-address>:22` accepts an SSH connection and `hostname` identifies
   the `916` computer.
2. Inspect `C:\repos\ai-devops` for uncommitted work from another session before
   pulling. Preserve anything unrelated. You will know this worked when the
   current branch and every local change have been classified.
3. On `main`, pull `origin/main` with a fast-forward-only update. You will know
   this worked when local `HEAD` equals `origin/main`.
4. Confirm PowerShell 7 is running and that
   `%USERPROFILE%\.config\ai-devops\op-service-account` exists. Never print its
   contents. If it is absent, restore it through the repo's normal 1Password
   setup path using vault `vibe_coding`; do not place the value in chat or Git.
   You will know this worked when the file exists with user-only access.
5. Run `bin/setup-machine.ps1` from the current repo checkout. Let the script
   reconcile skills, global instructions, protected MCP launchers, SSH aliases,
   the real Codex package path, portable Codex preferences, and the memory-sync
   task. You will know this worked when the script completes without a failed
   verification step.
6. Run the repo's Windows memory-task test and inspect the registered task. You
   will know this worked when it uses hidden `wscript.exe`, has a 15-minute
   execution limit, uses `IgnoreNew`, finishes with result 0, and writes a new
   successful log entry.
7. Run `bin/ai-devops doctor`. You will know this worked when the Codex sandbox
   creates its real workspace-write canary and every required check passes.
8. Verify the installed Claude and Codex copies of the repo-owned shared skills
   hash-match their source copies. Fully quit and reopen Claude Desktop so MCP
   processes reload. You will know this worked when the expected MCP tools
   connect and no repo-owned skill differs from source.
9. Record the live evidence in durable docs, delete this handoff only after every
   gate above passes, verify Albert's author and committer identity, commit, and
   push `main`. You will know this worked when the worktree is clean and local
   `HEAD` equals `origin/main`.

## 7. Constraints and gotchas

- Preserve concurrent work. Do not reset, overwrite, or stage unrelated files.
- Use `main`; this repository has no branch or PR flow.
- Before committing, author and committer must both be
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Use PowerShell 7, not Windows PowerShell 5.1.
- Never print, copy into chat, or commit a secret. Secrets stay in 1Password
  vault `vibe_coding` and protected machine-local storage.
- Never rotate a credential as part of this rollout.
- Do not use the retired Dropbox setup scripts.
- Do not weaken the Codex sandbox or any delegate's read-only controls to make a
  test pass.
- Codex GPT-5.6 reasoning effort must be explicitly `low` or `medium`.
- Do not run Terraform or mutate production/shared-cloud resources.

## 8. Access and environment

- GitHub: `https://github.com/u2giants/ai-devops`, branch `main`.
- Target: `916-alien`, Tailscale `<removed-protected-address>`, Windows user `ahazan2`.
- Expected checkout: `C:\repos\ai-devops`.
- SSH key location is managed by the repo and 1Password item
  `916-alien SSH key`; never expose the private key.
- Machine setup secret source: 1Password account
  `popcreations.1password.com`, vault `vibe_coding`.
- Use Git for Windows SSH for remote automation when Windows PowerShell cannot
  capture normal OpenSSH output.

## 9. Open questions and risks

- Availability is the only known blocker as of 2026-08-10. Recheck from current
  evidence after the machine starts because its local state may have changed.
- A prior interactive-only Codex sandbox issue was historically suspected on
  some Windows systems. If SSH setup passes but the sandbox check fails, repeat
  the harmless canary at the local Windows desktop before declaring an upstream
  defect. Never bypass the sandbox.
- The machine may contain uncommitted work from another AI session. Classify and
  preserve it before pulling or running setup.

## Mandatory self-audit

1. Yes, a new developer can continue without questions. Sections 1-3 define the
   toolkit, target, repository, verified state, commit, and blocker; section 6
   gives the complete ordered rollout with a gate for every step.
2. Yes, they can continue as effectively as this session. Sections 4-5 preserve
   the exact failed reachability checks and the non-obvious PowerShell, Codex,
   Dropbox, and token-file findings.
3. Yes, every execution detail is present. Sections 6-9 cover actions,
   verification, branch and identity rules, access, secret locations, risks,
   and the condition for deleting this handoff. No secret value is included.

Self-audit passed on 2026-08-10.
