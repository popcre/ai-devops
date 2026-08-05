# Claude Code Remote Control on `hetz` — What Was Changed, How to Verify, How to Undo

**Server:** `hetz` (Hetzner VPS, <removed-protected-address>)
**Date:** 2026-08-05
**Made by:** Claude, via `devops-mcp` `run_command`, as root
**Ansible status:** ⚠️ NOT committed to `/worksp/ansible`. These are direct host edits and will be lost on an Ansible rebuild. See "Outstanding" at the bottom.

---

## 1. Summary of what exists now

Six `systemd` services, each running `claude remote-control` as user `ai` in a specific
directory. Each is a *server* that accepts up to 32 concurrent Claude Code sessions,
reachable from Claude for Windows / claude.ai/code / the Claude mobile app.

| Service unit | Working directory | Shows in GUI as |
|---|---|---|
| `claude-rc@dflow.service` | `/home/ai/dflow` | `dflow` |
| `claude-rc-worksp@ai-devops.service` | `/worksp/ai-devops` | `ai-devops` |
| `claude-rc-worksp@shared-db.service` | `/worksp/shared-db` | `shared-db` |
| `claude-rc-worksp@popcrm-web.service` | `/worksp/popcrm-web` | `popcrm-web` |
| `claude-rc-worksp@poppim-web.service` | `/worksp/poppim-web` | `poppim-web` |
| `claude-rc-worksp@popdam.service` | `/worksp/popdam` | `popdam` |

All are **enabled**, meaning they start automatically on boot.

---

## 2. Every file created or modified

### 2.1 `/etc/systemd/system/claude-rc@.service` (NEW)

Template unit for directories under `/home/ai`. `%i` is the instance name.

```ini
[Unit]
Description=Claude Code Remote Control server (%i)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ai
Group=ai
Environment=HOME=/home/ai
Environment=PATH=/home/ai/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=/home/ai/%i
ExecStart=/home/ai/.local/bin/claude remote-control --name %i
Restart=always
RestartSec=10
StandardOutput=append:/home/ai/logs/claude-rc-%i.log
StandardError=append:/home/ai/logs/claude-rc-%i.log

[Install]
WantedBy=multi-user.target
```

### 2.2 `/etc/systemd/system/claude-rc-worksp@.service` (NEW)

Identical except `WorkingDirectory=/worksp/%i`.

### 2.3 `/usr/local/bin/cc` (NEW — now redundant)

A tmux attach-or-create helper written during an earlier approach that the
systemd services replaced. **Harmless but no longer needed.** Safe to delete.

### 2.4 `/usr/local/bin/ccls` (NEW — now redundant)

Wrapper around `tmux ls`. Also safe to delete.

### 2.5 `/home/ai/logs/` (NEW DIRECTORY, owned `ai:ai`)

Holds `claude-rc-<name>.log` for each service. **These are not rotated.**
See "Known gaps" — this is a real long-term disk risk.

### 2.6 Symlinks created by `systemctl enable`

```
/etc/systemd/system/multi-user.target.wants/claude-rc@dflow.service
/etc/systemd/system/multi-user.target.wants/claude-rc-worksp@ai-devops.service
/etc/systemd/system/multi-user.target.wants/claude-rc-worksp@shared-db.service
/etc/systemd/system/multi-user.target.wants/claude-rc-worksp@popcrm-web.service
/etc/systemd/system/multi-user.target.wants/claude-rc-worksp@poppim-web.service
/etc/systemd/system/multi-user.target.wants/claude-rc-worksp@popdam.service
```

**Nothing else on the server was modified.** No packages installed, no existing
config edited, no files deleted, no firewall or network changes. Remote Control
makes only outbound HTTPS connections — no ports were opened.

---

## 3. ⚠️ KNOWN GAPS IN THE CURRENT DEPLOYMENT

These are real defects in what was deployed. Fix before relying on this long-term.

### 3.1 No memory limit (HIGH RISK)

`MemoryMax` is unset. A leaking process can consume all 30 GB. Six services
multiply the exposure.

### 3.2 No restart-loop limit (HIGH RISK)

`Restart=always` + `RestartSec=10` with no `StartLimitBurst`. A service that
crashes on startup restarts **forever, every 10 seconds**. This is the classic
zombie-respawn pattern that takes servers down.

### 3.3 No task/process cap

Each server spawns MCP subprocesses (Playwright, ag-mcp, etc.). Unbounded.

### 3.4 No log rotation

`/home/ai/logs/*.log` grow without limit. The remote-control TUI redraws its
status line continuously, so these files grow **fast** — they accumulate ANSI
escape sequences every few seconds. This will fill the disk over weeks.

### 3.5 Not in Ansible

Violates the standing rule (code to GitHub first, then deploy). Lost on rebuild.

---

## 4. THE HARDENING PATCH (apply this)

Replaces the `[Service]` section in **both** template files. Run as root:

```bash
for f in /etc/systemd/system/claude-rc@.service /etc/systemd/system/claude-rc-worksp@.service; do
  cp "$f" "$f.bak-$(date +%F)"
done

# Add limits to the [Unit] and [Service] sections of both templates
for f in /etc/systemd/system/claude-rc@.service /etc/systemd/system/claude-rc-worksp@.service; do
  sed -i 's/^Wants=network-online.target$/Wants=network-online.target\nStartLimitIntervalSec=300\nStartLimitBurst=5/' "$f"
  sed -i 's/^RestartSec=10$/RestartSec=30/' "$f"
  sed -i 's/^Restart=always$/Restart=on-failure/' "$f"
  sed -i '/^\[Install\]/i MemoryHigh=1500M\nMemoryMax=2G\nTasksMax=512\nOOMPolicy=stop\n' "$f"
done

systemctl daemon-reload
systemctl restart claude-rc@dflow.service
for r in ai-devops shared-db popcrm-web poppim-web popdam; do
  systemctl restart "claude-rc-worksp@$r.service"
done
```

**What each setting does:**

| Setting | Effect |
|---|---|
| `MemoryMax=2G` | Hard ceiling. Kernel kills *only this service* if exceeded. Other services and the host are protected. |
| `MemoryHigh=1500M` | Soft throttle applied before the hard kill — usually lets it recover on its own. |
| `TasksMax=512` | Caps runaway subprocess spawning. |
| `StartLimitBurst=5` / `StartLimitIntervalSec=300` | After 5 failures in 5 minutes, systemd **gives up permanently** instead of looping. This is the anti-zombie guard. |
| `Restart=on-failure` | Won't restart after a clean shutdown (e.g. you stopped it deliberately). |
| `RestartSec=30` | Slower retries; less thrash. |
| `OOMPolicy=stop` | If the kernel OOM-kills it, stop cleanly rather than thrash. |

### Log rotation (also needed)

```bash
cat > /etc/logrotate.d/claude-rc <<'EOF'
/home/ai/logs/claude-rc-*.log {
    daily
    rotate 3
    maxsize 50M
    compress
    missingok
    notifempty
    copytruncate
    su ai ai
}
EOF
logrotate -d /etc/logrotate.d/claude-rc   # dry run to verify
```

---

## 5. Verification / health checks

```bash
# Are they running?
systemctl list-units 'claude-rc*' --no-pager

# Memory per service (bytes)
for s in $(systemctl list-units 'claude-rc*' --no-legend --no-pager | awk '{print $1}'); do
  printf '%-40s ' "$s"; systemctl show "$s" -p MemoryCurrent --value | numfmt --to=iec
done

# Confirm limits actually applied
systemctl show claude-rc@dflow.service -p MemoryMax -p TasksMax -p StartLimitBurst -p Restart

# Host memory
free -h

# Recent failures / restart counts
systemctl show claude-rc@dflow.service -p NRestarts
journalctl -u 'claude-rc*' --since '1 hour ago' --no-pager | tail -50

# Log sizes
du -sh /home/ai/logs/*.log
```

**A healthy service:** `active (running)`, `NRestarts` near 0, memory well under 2 G,
and `Connected` in its log file.

---

## 6. FULL UNDO — return the server to its prior state

### 6.1 Stop and disable everything

```bash
systemctl disable --now claude-rc@dflow.service
for r in ai-devops shared-db popcrm-web poppim-web popdam; do
  systemctl disable --now "claude-rc-worksp@$r.service"
done
```

### 6.2 Remove the unit files

```bash
rm -f /etc/systemd/system/claude-rc@.service
rm -f /etc/systemd/system/claude-rc-worksp@.service
rm -f /etc/systemd/system/claude-rc@.service.bak-*
rm -f /etc/systemd/system/claude-rc-worksp@.service.bak-*
rm -f /etc/systemd/system/multi-user.target.wants/claude-rc*.service
systemctl daemon-reload
systemctl reset-failed
```

### 6.3 Remove the redundant helper scripts

```bash
rm -f /usr/local/bin/cc /usr/local/bin/ccls
```

### 6.4 Remove log rotation config (if applied)

```bash
rm -f /etc/logrotate.d/claude-rc
```

### 6.5 Optional — logs and conversation transcripts

```bash
# Service logs (safe to delete)
rm -rf /home/ai/logs/claude-rc-*.log

# DO NOT delete this unless you mean it — these are your conversation transcripts:
#   /home/ai/.claude/projects/
```

### 6.6 Verify clean

```bash
systemctl list-units 'claude-rc*' --no-pager   # should list nothing
ls /etc/systemd/system/ | grep claude           # should return nothing
ps -ef | grep '[r]emote-control'                # should return nothing
```

### Undo just one repo

```bash
systemctl disable --now claude-rc-worksp@popdam.service
```

The template stays; only that instance goes away.

---

## 7. Adding another repo later

```bash
# Anything under /worksp:
systemctl enable --now claude-rc-worksp@monitor.service

# Anything directly under /home/ai:
systemctl enable --now claude-rc@synology-monitor.service
```

Remaining `/worksp` candidates: `monitor`, `infra`, `hiclaw`, `seafile`,
`albert-standards`, `ansible`.
Remaining `/home/ai` candidates: `synology-monitor`, `devops-mcp`,
`restore-wizard`, `compshop`, `favicon`, `novnc-desktop`.

Budget roughly **630 MB of RAM per additional service** at idle. With 30 GB total
and ~13 GB already in use by other workloads, do not exceed roughly 12 services.

---

## 8. Outstanding items

1. **Apply the hardening patch in section 4.** Currently unguarded.
2. **Apply log rotation.** Logs grow fast and are unrotated.
3. **Commit all of this to `/worksp/ansible`** and deploy via PR, per the standing
   rule that code goes to GitHub before deployment. Until then a rebuild wipes it.
4. **Resolve the duplicate designflow checkouts** — `/home/ai/dflow/designflow-*`
   vs `/worksp/designflow-*`. Determine which is canonical before working in either.
   (Investigation was interrupted by an MCP timeout and is incomplete.)
5. **Recover the 2026-08-05 morning session** — transcript at
   `/home/ai/.claude/projects/-home-ai-dflow/17b6dd26-5482-49a4-8ce3-7aedfd57e826.jsonl`
   (652 KB), not currently reachable from the GUI. Can be surfaced with:
   `claude remote-control --session-id 17b6dd26-5482-49a4-8ce3-7aedfd57e826 --spawn=session`
