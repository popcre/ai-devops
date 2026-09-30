# edge-dev3 ScreenConnect black screen (open)

**Owner:** Claude session on edge-dev3, 2026-09-30. **Waiting on:** ConnectWise support case #03766621.

## Background
edge-dev3 (Ubuntu 26.04, KDE Plasma 6.6 on Wayland, SDDM auto-login as `ahazan`) is reached
remotely two ways. KRDP (RDP on port 4837) is **working**. ScreenConnect is **broken**:
it shows a black screen and does not pass input. Albert reports ScreenConnect worked on the
morning of 2026-09-30 and earlier, in this same Wayland setup.

## Full record
Read `docs/edge-dev3-rdp-over-tailscale-2026-09-28.md` first. It holds the RDP root cause
(FreeRDP 3.32 regression, now held at 3.31), the popup fix, all wrong turns, and the
ScreenConnect findings.

## Current state
- RDP: working. The FreeRDP libraries are held at 3.31, KRDP user `ahazan2`, auto-login on,
  and xrdp purged.
- ScreenConnect: the console shows Logged On User `root`, and the agent captures Xwayland `:0`.
  The cause is unknown.

## Next actions
1. When ConnectWise replies to case #03766621 (Albert forwards it, or look under
   ConnectWise Home → Service & Support → My Cases), apply their guidance.
   Verify: Join edge-dev3 from the ScreenConnect console. The real desktop must be visible
   and the console must show user `ahazan`.
2. Do not switch to a Plasma X11 session without Albert's approval. It risks the working RDP.
3. Before changing anything, confirm RDP still works: the log shows
   `User "ahazan2" authenticated successfully` and then `Started Freedesktop Portal session`.

## Completeness gate
- New developer could continue? Yes. The background, the record doc, and the exact console
  path and case number are above.
- As well as the author? Yes. All findings and dead ends are in the record doc's
  "Still open" and "Wrong turns" sections.
- Every detail? Yes. Current state, constraint (keep RDP working), next steps with checks,
  and the vendor dependency are all listed. There are no secrets.
