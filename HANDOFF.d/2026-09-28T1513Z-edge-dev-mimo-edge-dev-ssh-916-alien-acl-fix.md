---
issue: none
status: OPEN
owner: mimo/edge-dev-ssh-916-alien-acl-fix
---

# HANDOFF — edge-dev SSH login from edge-dev3 (2026-09-28, edge-dev/MiMo)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

**Already settled — do NOT re-ask**

- 2026-09-28: Albert said "916-alien is the correct key to use" for SSH into `edge-dev`. Do not swap keys.
- 2026-09-28: Albert asked only to fix the edge-dev3 → edge-dev login so a Windows test could run. That request is done on the server side.

**Blocking**

- None for the SSH fix itself — login is restored and verified.

**A wrong guess is recoverable**

- **edge-dev3 retry method.** Recommend: `ssh -i ~/.ssh/916-alien ahazan@100.75.135.31` (or `ssh edge-dev` after the private SSH config is synced). Wrong username was a real failure mode (`u2giants` / `Albert` / `albert` were tried). Blocks nothing on edge-dev; blocks the Ubuntu session only if it still uses the wrong account.
- **Ship the private SSH-config alias.** The `Host edge-dev` block is committed in `u2giants/ai-devops-private-config`. Recommend: let the next install/sync pick it up; no extra action unless edge-dev3 still lacks the alias. Blocks only convenience (`ssh edge-dev` short name).

**Not part of this workstream and nobody on it**

- **Broad Windows firewall rule `OpenSSH-Server-In-TCP` is still enabled (Any/Any)** beside the Tailscale-only rule. Repo docs (`docs/windows-openssh-tailscale.md`) say the broad rule should stay disabled. Recommend: a Windows host-maintenance session disable it and keep only `OpenSSH Server - Tailscale only` (LocalAddress `100.75.135.31`, RemoteAddress `100.64.0.0/10`). Not fixed here under wrap-up scope freeze.
- **`popcre/shared-db` orchestrator-marker #3653** is OPEN and owned by the edge-dev3 claude route (successor of 3570). This session did not hold it and must not claim it. Non-orchestrator issue **#3662** (Supabase MCP Windows live proof) is already CLOSED; the proof was done on edge-dev itself.

**Instruction to the next session:** put the whole of section 0 to the owner in ONE message before starting work.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public recovery and machine-setup toolkit for multi-model AI coding clients. Installation is the release mechanism; it is not a hosted app. Albert is a business owner, not a programmer.

Machines in this story:

| Host | OS | Tailscale IPv4 | Role |
|---|---|---|---|
| `edge-dev` | Windows 11 | `100.75.135.31` | This session's host. Windows CI / dev box. Local admin account `ahazan`. |
| `edge-dev3` | Ubuntu (KDE) | `100.66.9.69` | Linux planning/coding host. Source of the failed SSH attempts. |
| `edge-alien` | Windows | `100.65.60.70` | Other Windows CI runner. |
| `edge-runn-envy` | Windows | `100.104.201.6` | Other Windows CI runner. |

Private SSH aliases live in `u2giants/ai-devops-private-config` → `ssh/ssh-config.template`, installed as `~/.ssh/ai-devops.conf` and included from `~/.ssh/config`. Public repo stores only a stub (`config/ssh-config.template`).

## 2. What we set out to do this session, and why

Albert reported: a session on Ubuntu `edge-dev3` could not run Windows test work (shared-db **#3662**, non-orchestrator). Quote from that session: *edge-dev is online, but it refused to let this machine log in. Neither of the keys I have is accepted there.* Albert asked to fix it.

Goal: restore SSH public-key login from `edge-dev3` to `edge-dev` so a Windows machine test can run.

Related issue (already closed before we finished): [popcre/shared-db #3662](https://github.com/popcre/shared-db/issues/3662) — live-prove the Supabase MCP launcher on Windows. Success criteria were met **on edge-dev itself** (another MiMo session posted the proof comment and closed the issue). The Ubuntu login was still worth fixing for future Windows work.

## 3. Current state — what is true right now

**Done and verified on edge-dev (2026-09-28, approx. 9:50–10:15 AM EDT):**

1. `C:\ProgramData\ssh\administrators_authorized_keys` contains the 916-alien public key (`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDzgWGrKmHE0Tgds2DDQWN7AwFCBkY6mpRZhinc6Wv0C`).
2. File ACLs fixed to exactly: `NT AUTHORITY\SYSTEM:(F)` + `BUILTIN\Administrators:(F)`, inheritance removed. `icacls` reports "Successfully processed 1 files".
3. `sshd` is Running (Automatic). Restarted after the ACL fix.
4. Live logins succeeded:
   - `ssh -i ~/.ssh/916-alien ahazan@127.0.0.1 whoami` → `edge-dev\ahazan`
   - `ssh -i ~/.ssh/916-alien ahazan@100.75.135.31 whoami` → `edge-dev\ahazan`
   - `ssh edge-dev whoami` → `edge-dev\ahazan` (after Host alias)
5. Key fingerprint matches the log successes: `SHA256:l5pvpZxu4y8J+yCFoQCcL1pbNLsqE5PvD9dkvIgyooc` (ED25519).
6. New `Host edge-dev` block added to:
   - `~/.ssh/ai-devops.conf` (live on this machine) — **not a git file**
   - `C:\Users\ahazan\.local\share\ai-devops-private-config\ssh\ssh-config.template` — **committed on `main` of `u2giants/ai-devops-private-config`** (see §6 for SHA)

**Not started / not done:**

- edge-dev3 has not been retried from this side (this host cannot SSH to edge-dev3: connection refused).
- Broad firewall rule `OpenSSH-Server-In-TCP` still enabled (Any/Any). Deferred — see §0 and §6.
- Public `popcre/ai-devops` tree was **not** modified by this session's fix (except this handoff file). Pre-existing dirty files belong to other sessions (see §7).

## 4. Everything we tried that did NOT work

1. **`bin/ai-task-gates start --class 4` via PowerShell with `| head`** — failed (`head` is not a PowerShell cmdlet; gates script path also failed once). Not needed for a host SSH repair. Do not block on task gates for machine-local SSH ACL work.
2. **`bin/ai-gh.cmd` invoked as `bin\ai-gh.cmd ...` from PowerShell** — returned "The system cannot find the path specified." The `.cmd` launcher is fine; call it as `cmd /c C:\repos\ai-devops\bin\ai-gh.cmd ...` or `bin/ai-gh` from Git Bash. GitHub lookups work that way (we read shared-db #3662 successfully).
3. **Non-elevated `icacls` / `Get-Content` on `administrators_authorized_keys`** — "Access is denied". Expected after a correct ACL fix: non-elevated admins lose Administrators rights on the filtered token. `sshd` runs as SYSTEM and can still read the file. Do not "fix" this by loosening ACLs.
4. **First elevated ACL attempt** — wrote a dump file but the follow-up `icacls` in the same elevated command did not leave a readable result; a second elevated pass with output redirected to `C:\Users\ahazan\ssh-acl-dump.txt` confirmed and repaired ACLs. If UAC is ignored, `Start-Process -Verb RunAs` hangs until timeout.
5. **SSH from edge-dev → edge-dev3 (`ahazan@100.66.9.69`)** — `banner exchange: Connection to UNKNOWN port -1: Connection refused`. edge-dev3 does not accept inbound SSH from here (or not on 22). Cannot repair edge-dev3's client config remotely.
6. **What edge-dev3 itself tried (from OpenSSH logs + issue #3662 comments):**
   - Usernames `u2giants`, `Albert`, `albert` → `Invalid user` (this Windows box only has local `ahazan` for this role).
   - `ahazan` with keys when ACLs were broken → `Connection closed by authenticating user ahazan` (key offered, not accepted).
   - Same host earlier the same morning (9:15–9:16 AM EDT) **succeeded** as `ahazan` with fingerprint `SHA256:l5pvpZxu4y8J+yCFoQCcL1pbNLsqE5PvD9dkvIgyooc` — proving the key and network path were fine when ACLs were healthy.
   - Issue comment also records `u2giants@100.75.135.31: Permission denied (publickey,keyboard-interactive)` with the 1Password item "916-alien SSH key".

## 5. Root causes and key findings

1. **Primary root cause — broken ACLs on `C:\ProgramData\ssh\administrators_authorized_keys`.** Windows OpenSSH for local Administrators uses that file (`sshd_config` `Match Group administrators`). If ACLs are not exactly SYSTEM+Administrators full control with inheritance off, **sshd silently refuses every key** (`Permission denied (publickey)` / connection closed in preauth). The 916-alien pubkey was already present the whole time; the ACL was the gate. Documented in `docs/windows-openssh-tailscale.md` (lines ~152–155).
2. **Secondary root cause — wrong account name from edge-dev3.** The Ubuntu session authenticated as `u2giants` / `albert` / `Albert`. This host's SSH admin account is **`ahazan`** (`edge-dev\ahazan`). GitHub user `u2giants` is not a Windows local account here.
3. **Missing SSH alias.** `ai-devops.conf` had `edge-alien`, `edge-runn-envy`, `4837`, `916` — but **no `Host edge-dev`**. Clients had no canonical user/key/hostname for this machine, which encouraged ad-hoc usernames and keys. Now added: user `ahazan`, HostName `100.75.135.31`, IdentityFile `~/.ssh/916-alien`, HostKeyAlias `100.75.135.31`.
4. **ACL "denial" after repair is normal.** Non-elevated `ahazan` cannot read `administrators_authorized_keys`. That is success, not failure. Use an elevated PowerShell dump if you must inspect it.
5. **Fingerprint is the ground truth.** Working key = ED25519 `SHA256:l5pvpZxu4y8J+yCFoQCcL1pbNLsqE5PvD9dkvIgyooc` = `~/.ssh/916-alien.pub` on edge-dev (comment `916-alien`).
6. **OpenSSH logs** (`Get-WinEvent -LogName OpenSSH/Operational`) are enough to diagnose: look for `Accepted publickey`, `Invalid user`, `Connection closed by authenticating user`.
7. **shared-db #3662** required a Windows live proof of the Supabase MCP launcher. It was completed on edge-dev (MCP connected, `select 1 as ok` → `[{\"ok\":1}]`, space-in-profile quoting safe) and the issue is CLOSED. Do not re-run that proof unless the launcher changes.

## 6. Exact next steps

1. **Ship the private SSH-config alias** (if not already pushed when you read this): in `/c/Users/ahazan/.local/share/ai-devops-private-config`, confirm `ssh/ssh-config.template` is clean on `origin/main` with the `Host edge-dev` block.  
   **You'll know it worked when** `git status` is clean and `git log -1 --oneline` on origin shows the `ssh: add Host edge-dev` commit.
2. **From edge-dev3 (or any client that has 916-alien), test login:**  
   `ssh -i ~/.ssh/916-alien ahazan@100.75.135.31 whoami`  
   expect `edge-dev\ahazan`. Optional: sync private config and use `ssh edge-dev whoami`.  
   **You'll know it worked when** the command returns the Windows account and does not ask for a password.
3. **If edge-dev3 still rejects keys:** on edge-dev, re-read `Get-WinEvent -LogName OpenSSH/Operational -MaxEvents 20`. If ACLs broke again, re-apply: `icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant *S-1-5-18:F /grant *S-1-5-32-544:F` from elevated PowerShell, then `Restart-Service sshd`. Confirm the 916-alien line is still in the authorized_keys file (elevated read).
4. **Deferred (needs owner nod in §0): disable broad firewall rule** `OpenSSH-Server-In-TCP`; keep only `OpenSSH Server - Tailscale only`.  
   **You'll know it worked when** `Get-NetFirewallRule -DisplayName 'OpenSSH*'` shows the Tailscale rule Enabled and the OpenSSH-Server-In-TCP rule Disabled, and `ssh edge-dev` still works.
5. **Do not re-open or re-prove shared-db #3662** unless the launcher code changes. Marking: #3662 is non-orchestrator (closed). #3653 is orchestrator-marker for another route.

## 7. Constraints and gotchas in force

- **Never loosen `administrators_authorized_keys` ACLs** to make them readable as a normal user. sshd rejects loose ACLs. Elevated inspect only.
- **Never re-enable `PasswordAuthentication`** or the broad `OpenSSH-Server-In-TCP` rule to "fix" a login. See `docs/windows-openssh-tailscale.md`.
- **Correct SSH identity into edge-dev is `ahazan` + 916-alien only.** Do not authorize random Ubuntu agent keys without an owner ruling.
- **Concurrent checkout (C:\repos\ai-devops):** do not touch `scripts/ai-housekeeping/move-bulk-to-d.ps1` (modified by another session) or `HANDOFF.d/2026-09-20T0029Z-edge-dev-kimi-grok-trap-exit-status.md` (another session's handoff). Stage only this file if you commit it.
- **Do not rewrite root `HANDOFF.md`** (already the v1 pointer).
- **Wrap-up scope freeze was in force** at the end of this session: no new issues, no firewall repair, no "while we're here" cleanups. Those live in §0/§6.
- **This repository is public.** Never commit transcripts, private addresses beyond the Tailscale `100.x` already used in repo docs, or private key material. 916-alien **public** key is already published in-repo; the private key stays in 1Password / `~/.ssh/916-alien` with tight ACLs.
- **Times in human notes are EST (America/New_York).** Filenames may stay UTC.

## 8. Access and environment

- Host: `edge-dev`, user `edge-dev\ahazan`, elevated PowerShell needed for ProgramData ssh ACL work.
- Repo checkout: `C:\repos\ai-devops` (canonical landing tree). `origin` = `https://github.com/popcre/ai-devops.git`. Was **behind origin/main by 7** at wrap-up; do not assume local main is tip.
- Private config: `C:\Users\ahazan\.local\share\ai-devops-private-config` → `u2giants/ai-devops-private-config`, branch `main`. Resolved via `bin/ai-private-config path ssh_config`.
- SSH: `sshd` Running; Tailscale online as `edge-dev` / `100.75.135.31`. Client identity file `C:\Users\ahazan\.ssh\916-alien` (+ `.pub`).
- GitHub: use `bin/ai-gh` (Git Bash) or `cmd /c C:\repos\ai-devops\bin\ai-gh.cmd`. Authenticated.
- Git committer identity verified: `Albert Hazan <u2giants@users.noreply.github.com>`.
- Secrets: 1Password vault `vibe_coding` holds the `916-alien SSH key` item (private key). **Never print the private key.** This session did not read it.
- shared-db orchestrator marker **#3653** exists and is **not** this session's. Non-orchestrator **#3662** closed.

## 9. Open questions and risks

- **Why did ACLs break between ~9:16 AM and ~9:41 AM EDT on 2026-09-28?** Something on edge-dev changed the file ACL (installer, sync tool, other AI session). Unknown. If it recurs, treat as a host-maintenance incident and find the writer (file USN / installer logs). Dated: 2026-09-28.
- **Is 916-alien present and unencrypted on edge-dev3?** The issue comment says that machine tried "the only 1Password SSH key, 916-alien SSH key" and still failed as `u2giants`. After ACL fix, retry as `ahazan`. If edge-dev3 lacks the on-disk `~/.ssh/916-alien`, restore from vault item `916-alien SSH key` — do not invent a new key.
- **Host-key verification from edge-dev3:** older handoffs noted host-key failures when connecting by raw name/IP. Use HostKeyAlias/IP from the new `Host edge-dev` block, or `ssh-keyscan` the accepted host keys from a trusted channel. The accepted server fingerprint for the working client path was not re-dumped this session (host key files need elevation).
- **Firewall broad rule** remains a hygiene risk until step 6.4 is done (owner gate in §0).
- **#3662 close comment** on GitHub is the path `C:\Users\ahazan\AppData\Local\Temp\issue-3662-close.md` instead of the intended closing sentence. Cosmetic; not worth reopening the issue. Dated: 2026-09-28.

---

## Self-audit (handoff-writer Mode A)

1. **Could a brand-new developer continue without a question?** Yes — §3 states the verified end state and exact commands; §4 lists every failed path; §6 is ordered with gates; §8 defines host, account, key file, and repos.
2. **As effective as this session?** Yes — ACL trap, wrong-username trap, fingerprint, log queries, and private-config path are all written (§5, §7).
3. **Every relevant detail?** Yes — goal (§2), successes (§3), dead ends (§4), root causes (§5), steps (§6), constraints (§7), access (§8), risks (§9).
4. **Section 0 complete?** Yes — settled key choice (Albert 2026-09-28), ship/retry recommendations, deferred firewall with recommendation, shared-db marker ownership called out. Sweep of §1–§9 found no further owner-only decisions.
