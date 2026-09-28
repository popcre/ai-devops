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

## Known leftover (not fixed)

A duplicate user unit `~/.config/systemd/user/krdp.service` restarts every few
seconds (over 2,000 restarts). It fails with `Unable to listen ... 4837` because
the packaged KRDP service already owns the port. It is harmless to RDP but
noisy. Retire it only in a separate change that keeps the packaged service
running.
