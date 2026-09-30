# edge-dev3 Remote Desktop over Tailscale — incident record (2026-09-28)

Status: **resolved** 10:05 AM EDT, September 28, 2026. Verified from two Windows
clients (`edge-dev`, on a different subnet, and Albert's home computer, on the
same subnet as edge-dev3). Both kept a desktop open via `edge-dev3:4837`.
Server logs showed `PAM authentication succeeded` and `Started Freedesktop
Portal session` for each connection.

## Setup

- `edge-dev3` is an Ubuntu KDE Plasma (Wayland) machine. KDE's packaged KRDP
  (`app-org.kde.krdpserver.service`, user unit) shares the live desktop over
  RDP on TCP **4837** and authenticates with PAM, so it checks the Linux login
  password of `ahazan`.
- Tailscale MagicDNS resolves `edge-dev3` to the machine's tailnet address.
  Clients connect with `mstsc /v:edge-dev3:4837`.

## Symptom

Connecting by LAN IP worked. Connecting by name either returned silently to
the RDP screen, or flashed a black window for about a second and closed.

## Root causes (two separate ones, found in order)

1. **UFW blocked Tailscale traffic.** UFW is active on edge-dev3 and allowed
   port 4837 only from the LAN. An attempt made by name left *no* KRDP log line
   at all, which means the traffic never reached the server.
   Fix, run by Albert with sudo:
   `sudo ufw allow in on tailscale0 to any port 4837 proto tcp`.
2. **Windows sent a wrong or empty saved credential.** `mstsc` offers no
   password field, and `/prompt` did not force a prompt. Windows silently
   submitted what it had stored for the target. The KRDP log showed either
   `pam_authenticate failure` (wrong saved password) or `Attempting
   authenticating user with PAM` followed immediately by `PostConnect ...
   failed` with no PAM line (no password sent). Credentials are stored per
   Windows computer, so each client needs its own fix. On each client:
   `cmdkey /generic:TERMSRV/edge-dev3 /user:ahazan /pass`. Enter edge-dev3's
   Linux login password at the hidden prompt, then run
   `mstsc /v:edge-dev3:4837`.

## Diagnostic that decided it

```bash
journalctl --user -b _COMM=krdpserver --since '-15min' --no-pager | grep -v -e 'suspend frame ack' -e 'Unable to listen'
```

- No lines at all during an attempt: the network or firewall is blocking it.
- `pam_authenticate failure`: the client sent the wrong password.
- `Attempting authenticating ... PostConnect failed`, with no PAM result: the
  client sent no password.
- `PAM authentication succeeded` + `Started Freedesktop Portal session`: the
  connection works.

KRDP logs do not record the peer IP. `ss -tn | grep 4837` shows who is currently
connected.

## Things that were wrong turns

- Treating DNS resolution as sufficient. It resolved correctly all along.
- Deleting a Credential Manager entry. None was visible under that name.
- Relying on `mstsc /prompt` to ask for a password. With KRDP it did not ask.

## Known leftover (resolved 2026-09-28)

The duplicate user unit `~/.config/systemd/user/krdp.service` (restarting every
few seconds with `Unable to listen ... 4837`) was retired at 10:12 AM EDT:
`systemctl --user disable --now krdp.service`, the unit file moved to
`~/krdp.service.bak-2026-09-28` (outside the unit path), then
`systemctl --user daemon-reload`. Afterwards `krdp.service` no longer exists,
`journalctl --user -u krdp.service` shows no new entries, and the packaged
`app-org.kde.krdpserver.service` (PID 6043) stays active and listening on
`*:4837`. To restore, move the backup back and re-enable it (not recommended).

---

# Second incident — RDP refused every password (2026-09-30)

Status: **RDP resolved** about 1:05 PM EDT, September 30, 2026. Albert confirmed a
working `mstsc` session. **ScreenConnect black screen is still open** (see the end).
The office network move at the same time was a coincidence. Tailscale, UFW
and DNS were fine throughout.

## Symptom

Every `mstsc` attempt gave "The logon attempt failed", both from the office LAN
and from home over Tailscale. The server log showed this for every user, including a
brand-new KRDP user:

```
[com.winpr.sspi.NTLM] ntlm_fetch_ntlm_v2_hash: Could not find user in SAM database
AcceptSecurityContext status SEC_E_NO_CREDENTIALS
```

## Actual root cause

An automatic update at 6:06 AM EDT on 2026-09-29 upgraded FreeRDP from
`3.31.0+dfsg-0ubuntu0.26.04.1` to `3.32.0+dfsg-0ubuntu0.26.04.1`. The packages
were `libwinpr3-3`, `libfreerdp3-3`, `libfreerdp-server3-3` and
`libfreerdp-client3-3`. KRDP only loads the new libraries after it restarts,
so it broke at the first reboot after the update. With 3.32, KRDP's
server-side login (NLA) never reaches KRDP's own user check (PAM or KRDP
users). Instead it looks up a nonexistent FreeRDP SAM file
(`/etc/FreeRDP/FreeRDP/SAM`, seen with `strace`), so every login fails.

**Proof, same machine and same user:** a second `krdpserver --port 4838` run with
`LD_LIBRARY_PATH` pointed at the extracted 3.31 libraries logged
`User "ahazan2" authenticated successfully`. The 3.32 server on 4837 gave the
SAM error for the same password.

## Fix applied (2026-09-30)

1. Downgraded the four packages to 3.31 and held them:
   `sudo dpkg -i` the 3.31 debs (three came from `/var/cache/apt/archives/`,
   `libfreerdp-server3-3` from
   `https://launchpad.net/ubuntu/+archive/primary/+files/libfreerdp-server3-3_3.31.0+dfsg-0ubuntu0.26.04.1_amd64.deb`),
   then `sudo apt-mark hold libwinpr3-3 libfreerdp3-3 libfreerdp-client3-3 libfreerdp-server3-3`.
   **Before unholding**, test a newer FreeRDP with the port-4838 method above.
2. After the downgrade, the login succeeded but the window flashed and closed
   (`PostConnect ... failed`). The cause was the KDE "Remote Control — Control
   input devices" approval popup, which had not been clicked yet. KRDP cannot
   start the portal session until someone approves it at the screen. Permanent fix:
   run KRDP with `--plasma` (it uses KWin's protocols directly, allowed by
   `X-KDE-Wayland-Interfaces` in `/usr/share/applications/org.kde.krdpserver.desktop`,
   so there is no popup). Drop-in:
   `~/.config/systemd/user/app-org.kde.krdpserver.service.d/plasma.conf` with
   `ExecStart=` then `ExecStart=/usr/bin/krdpserver --plasma`.
   Pending: after a reboot, confirm no popup and a working session.
3. The KRDP settings now have `SystemUserEnabled=false` and a dedicated KRDP user `ahazan2`
   (password in KWallet folder `KRDP`, set by Albert in System Settings → Remote
   Desktop). The PAM/system-password path was not retested on 3.31. It worked on
   2026-09-28 per the incident above.
4. Auto-login stays on (`User=ahazan` in `/etc/sddm.conf.d/kde_settings.conf`).
   It is needed so KRDP, a user service, starts without anyone at the keyboard.

## Fast diagnosis next time

```bash
grep -E ' (upgrade|install) ' /var/log/dpkg.log | grep -iE 'freerdp|winpr|krdp' | tail
journalctl --user -u 'app-org.kde.krdpserver*' --since '-10min' --no-pager | grep -vE 'deactivate_all|BIO|TRANSPORT'
```

- `Could not find user in SAM database` → FreeRDP regression; check versions and holds.
- `PostConnect ... failed` right after `New client connected` → the portal approval
  is missing. Check that `--plasma` is still in effect (`ps -o args= -C krdpserver`).
- `Unable to listen ... 4837` → another program owns the port (`ss -ltnp | grep 4837`).

## Wrong turns (do not repeat)

- Blaming the office network or the Windows `al8960ofc\` domain prefix. Both were irrelevant.
- Writing passwords into KWallet by hand, and trying `edge-dev3\` or `\` username prefixes.
- Turning auto-login off. KRDP then never starts until someone signs in locally.
  Also, `sddm` reads **every** file in `/etc/sddm.conf.d/`, so a `.bak` copy there
  overrides the real file. Keep backups outside that folder.
- Enabling the OpenSSL legacy provider (MD4) for KRDP. It had no effect and was removed.
- xrdp (installed 2026-09-24) sometimes took over port 4837 when KRDP was not running
  and showed its own "Login to edge-dev3" screen. It was **purged** 2026-09-30.
- Granting the portal permission in the PermissionStore did not stop the popup. `--plasma` did.

## Still open — ScreenConnect black screen

ScreenConnect (`connectwisecontrol-159806842ff2961f`, a system service) captures
`DISPLAY=:0`. On Plasma Wayland that display is Xwayland, which contains only X11 apps,
so the capture is black and input does not reach the desktop. Albert reports it
worked on the morning of 2026-09-30 in this same Wayland setup. The journal shows
Wayland sessions on every boot since 2026-09-28. **How it worked is not yet explained.**
Do not assume Wayland and X11 are mutually exclusive with KRDP until that is
investigated. The next step is to compare the ScreenConnect client version and
logs from before and after the 10:54 AM EDT reboot.
