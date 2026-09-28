# HANDOFF — edge-dev3 Remote Desktop over Tailscale (September 28, 2026, 7:38 AM EDT; edge-dev3/Codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

- BLOCKING: Albert must perform the next Windows Remote Desktop connection attempt himself because the Linux-side session cannot enter his password or see the Windows credential prompt. He must report whether `mstsc /v:edge-dev3:4837 /prompt` displays a credentials dialog and whether the desktop remains open after entering the working LAN credentials. He must never send the password in chat.
- RECOVERABLE: None. No server or Tailscale configuration change is justified by current evidence.
- NOT PART OF THIS WORK, AND NOBODY IS ON IT: A duplicate user-level `krdp.service` repeatedly fails because KDE's packaged `app-org.kde.krdpserver.service` already owns port 4837. It was observed but not changed. It may merit separate maintenance after the connection issue is resolved; it has not been shown to cause the hostname failure.

## 1. What this application is

This is a machine connectivity issue, not an ai-devops application change. `edge-dev3` is this Linux KDE Plasma machine. KDE KRDP serves its existing graphical desktop to Windows Remote Desktop Connection (`mstsc`) on TCP port 4837. Tailscale MagicDNS names the machine `[private tailnet domain in protected machine atlas]` and maps it to `[private address in protected machine atlas]`; the LAN address is `[private address in protected machine atlas]`. The public `popcre/ai-devops` repository only holds this continuation handoff; no runtime source in the repository was changed.

## 2. What we set out to do this session, and why

Albert wants machines on the Tailscale network to reach this machine by `edge-dev3`, particularly via Windows Remote Desktop. Connecting by LAN IP works. Connecting with the hostname produced a silent return to the Windows Remote Desktop screen, later a brief black screen before closing. Success means a Windows client can enter `edge-dev3:4837`, authenticate, and keep the desktop open over Tailscale.

## 3. Current state — what is true right now

- Tailscale reports this host as `edge-dev3`, IP `[private address in protected machine atlas]`, MagicDNS enabled tailnet-wide. Direct lookup against Tailscale DNS `[private address in protected machine atlas]` resolves `edge-dev3` to `[private address in protected machine atlas]`. The fully qualified name resolves the same way. A screenshot provided by Albert showed the correct target `edge-dev3:4837` in the Windows Computer box.
- KDE's packaged `app-org.kde.krdpserver.service` is active with PID 1629 as observed September 28, 2026, 7:38 AM EDT. Its listener is `*:4837`, and local TCP probes to both `[private address in protected machine atlas]:4837` and `[private address in protected machine atlas]:4837` succeeded. These local probes do not prove a remote tailnet client can connect.
- A LAN RDP connection from `[private address in protected machine atlas]` to `[private address in protected machine atlas]:4837` was established at 7:38 AM EDT. Albert confirms LAN access works. Its mere presence does not establish whether concurrent connections are supported or relevant.
- At 12:26:35 AM EDT on September 28, a Windows client connected and KRDP attempted PAM authentication for `ahazan`. The Linux log says `pam_unix(login:auth): authentication failure` and `pam_authenticate failure: Authentication failure` at 12:26:38 AM EDT, then closed the session. At 12:26:49 AM EDT another Windows connection authenticated `ahazan` successfully, initialized video, and started the desktop portal. The temporal sequence aligns with Albert's reported failing hostname attempt followed by working LAN connection, but the KRDP log does not include the peer IP for each attempt; do not claim the source mapping as certain without a client-side test.
- No secret value appeared in chat. No source code, Tailscale setting, firewall rule, or server configuration was changed. No GitHub issue was opened because Albert invoked wrap-up, whose scope freeze forbids starting a new issue.

## 4. Everything we tried that did NOT work

- The initial diagnosis said hostname resolution was enough. It was not: Albert repeatedly reported a silent RDP disconnect.
- Asking Albert to close the LAN session did not resolve the reported hostname behavior. The Linux side still showed an established LAN socket afterward, so the exact state of the Windows session was unclear.
- Asking Albert to set username `ahazan` in the Remote Desktop window did not by itself fix the reported connection. Subsequent server logs showed `ahazan` with a rejected password during one attempt.
- Advising removal of a saved `edge-dev3` entry from Windows Credential Manager was inapplicable: Albert checked and found no such entry. The Remote Desktop main window does not offer a password field.
- An SSH attempt to another Tailscale peer failed host-key verification; no bypass was used. No remote Windows DNS or credential state was inspected.
- An ai-devops `ai-task-gates check --before infrastructure` refused infrastructure mutation because concurrently changing protected repository files were observed in the shared canonical checkout. No infrastructure mutation was attempted. This repository gating result is not evidence that Tailscale or KRDP itself is blocked.

## 5. Root causes and key findings

Name resolution and port selection are correct. The latest detailed failure reached KRDP and failed PAM password authentication for the correct account, while a nearby LAN connection authenticated successfully. The most likely next discriminator is forcing a fresh Windows credential prompt for the hostname. Microsoft's `mstsc` documentation confirms that `/prompt` requests credentials when connecting. It is not yet proven whether Windows had reused an incorrect credential, Albert typed a different password, or another client setting changed the submitted secret. Do not treat the brief black screen as proof that authentication succeeded; the server log disproves that for the observed failing attempt.

The separate duplicate service problem is real: `krdp.service` from `/home/ahazan/.config/systemd/user/krdp.service` continually tries to bind port 4837 while the KDE packaged service owns it. That is an observed maintenance issue, not the demonstrated cause of authentication failure. Preserve the working service when addressing it in a later, separately scoped task.

## 6. Exact next steps

1. Ask Albert to press Win+R on the Windows client and run `mstsc /v:edge-dev3:4837 /prompt`. Microsoft documents `/prompt` at https://learn.microsoft.com/windows-server/administration/windows-commands/mstsc. He should use account `ahazan` and the password that succeeds against the LAN IP. Do not request or record the password itself. Ask him to report whether a credential prompt appears and whether the desktop stays open.
2. Immediately after that attempt, read `journalctl --user -b _COMM=krdpserver --since '<attempt time in America/New_York>' --no-pager` and look for `PAM authentication succeeded`, `pam_authenticate failure`, `Started Freedesktop Portal session`, and closure reason. Capture the Windows client source only through safe, read-only connection diagnostics if needed.
3. If authentication still fails, inspect Windows client credential behavior and the exact username format entered, without exposing the password. Compare a forced-prompt LAN attempt with a forced-prompt hostname attempt. If both authenticate but only the hostname disconnects after video starts, investigate the RDP session/transport separately; do not continue treating it as DNS or password failure.
4. Verify completion with an observed Windows desktop staying connected via `edge-dev3:4837`, plus server log evidence of successful authentication and portal session over the same attempt. If a repository handoff issue is needed for retirement tracking, open it in the successor session rather than during this wrap-up scope freeze. Retire this file only after the verified outcome is durable and the handoff successor rule permits it.

## 7. Constraints and gotchas in force

- Albert is a business owner; keep user-facing instructions short. Never ask him to paste a password. No credentials appeared in this session, so there is nothing to store in 1Password.
- Preserve the already working LAN RDP access. Do not restart or disable services to chase an unproven cause. A local probe of `[private address in protected machine atlas]` runs through the local kernel route and does not verify a remote Tailscale path.
- Use `ai-task-gates start` and a valid `check --before infrastructure` gate before any actual machine setting change. The earlier refusal arose from the shared ai-devops checkout's concurrent protected changes; worktree isolation does not itself authorize bypassing a protected gate.
- This repository is public. Keep passwords, private logs, and raw user data out of commits. The only repository write from this wrap-up is this handoff.

## 8. Access and environment

- Local shell is on Linux host `edge-dev3`, user `ahazan`, in `/home/ahazan/repos/ai-devops`. Tailscale CLI and systemd user journal are available. Root commands require interactive sudo and were not used.
- The independent documentation worktree for this handoff is `/home/ahazan/repos/ai-devops-edge-dev3-rdp-handoff` on branch `codex/edge-dev3-rdp-handoff`, based on `origin/main` commit `a6db379` at creation. Check its final PR/merge state before resuming.
- Windows client is operated by Albert; there is no confirmed authenticated automation path to it. A screenshot of its Remote Desktop Computer field was supplied in the prior chat, not committed to this public repository.

## 9. Open questions and risks

- Does `/prompt` display a fresh credentials dialog for the hostname, and does the same known-good LAN password then work?
- What exact Windows client source and server-side result correspond to the next forced-prompt attempt? Existing KRDP logs omit peer addresses, so previous source attribution is temporal inference.
- Is the duplicate user service causing resource churn or a future reboot race? This is separate maintenance; do not alter it before preserving and proving the existing LAN capability.
- No GitHub issue number is recorded because wrap-up scope freeze barred creating one. A successor should use a single tracking issue if repository work remains and close it only after live proof.

## Self-audit

1. Yes: §§1–3 establish purpose, identities, addresses, service, and observed results; §6 gives the first executable action without chat context.
2. Yes: §§3–5 preserve the timestamps, exact authentication evidence, failed theories, and uncertainty about source mapping.
3. Yes: §4 records unsuccessful steps and §5 explains which evidence supports or limits the leading diagnosis.
4. Yes: §6 has a concrete Windows command, log checks, alternate branches, and observable success criteria.
5. Yes: §§1 and 8 define KRDP, Tailscale, addresses, paths, and access boundaries; §6 links the primary command reference.
6. Yes: §0 captures the only owner-held action and the separate unowned maintenance candidate from §§1–9.

Synthesis: Yes to comprehensiveness (§§1–9); yes to effective continuation (§§3–6); yes to evidence, constraints, risks, and verification (§§3–9); and yes, §0 exposes every owner decision found in §§1–9. No gap remained after rereading this file.
