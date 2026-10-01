# edge-dev3 ScreenConnect: waiting on owner's Wayland-vs-X11 decision (open)

**Owner:** Claude session on edge-dev3, 2026-10-01. **Waiting on:** Albert's choice (below).
This supersedes the next step in `2026-09-30T1738Z-edge-dev3-claude-screenconnect-black-screen.md`:
ConnectWise has now replied to case #03766621.

## Read first
`docs/edge-dev3-rdp-over-tailscale-2026-09-28.md`, especially its last two sections
(the 2026-10-01 faults and the ConnectWise reply).

## Current state (verified 2026-10-01)
- RDP (KRDP, port 4837, login `ahazan2`): working, using a software encoder (libx264) drop-in.
  Albert confirmed it.
- Lock screen Switch User is disabled. That stops the overnight VT1 lockup. Albert confirmed it.
- `ahazan` password: Albert's original. The 1Password item is marked STALE, and AI has no sudo password.
- ScreenConnect: still a black screen. ConnectWise says Wayland is unsupported.

## Decision owed by Albert
A) Keep Wayland: RDP shows the real desktop, and ScreenConnect stays black. **Recommended.**
B) Switch to X11: ScreenConnect works, and RDP becomes xrdp with a separate desktop.

## Next actions
- If A: delete this file and the 2026-09-30 ScreenConnect handoff's owner should close it.
  Nothing else to do.
- If B: run `apt install plasma-session-x11`, set `Session=plasmax11` under SDDM
  `[Autologin]`, install `xrdp` on port 4837, and remove the KRDP autostart.
  This needs sudo, which AI does not have; that is `Blocked —` until Albert provides it.
  Never reset his password. Verify: the ScreenConnect console shows user `ahazan` and
  the real desktop, and an RDP login works.

## Completeness gate
- New developer could continue? Yes. The state, decision, and both paths with checks are above, and the doc has the evidence.
- As well as the author? Yes. Every fault, log line, fix, and wrong turn is in the doc section dated 2026-10-01.
- Every detail? Yes. It covers constraints (keep RDP, no sudo, no password resets), risks (xrdp gives a separate desktop), and verification. There are no secrets.
