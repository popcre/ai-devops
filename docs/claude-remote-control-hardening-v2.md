# Corrected hardening patch — claude-rc Remote Control services on `hetz`

Supersedes section 4 of `docs/claude-remote-control-vps-changes.md`.

## Host facts (measured 2026-08-05)

- 30 GB RAM, 11 GB swap. 14 GB used, ~15 GB available. Load ~1.9.
- Six `claude-rc*` services `active (running)`, uptime 7 days, no OOM kills in `dmesg`.
- Measured RSS per service at idle: 631M, 639M, 646M, 701M, 711M, 751M (~4.1 GB total).
- Measured `TasksCurrent` per service at idle: **121**.
- Measured `MemorySwapCurrent` per service: **0**. Host swap use 309 MB of 11 GB.
- cgroup **v2** (`cgroup2fs`), systemd **255**, logrotate **3.21.0**.
- `logrotate.timer` is **daily only** (`OnCalendar=*-*-* 00:00:00`).
- Disk: 226 GB total, 64 GB free (71% used).
- `/home/ai/logs` is `drwxrwxr-x ai:ai`, but the log files inside are
  **`-rw-r--r-- root:root`** — systemd opens `StandardOutput=append:` as root before
  dropping to `User=ai`. Measured: user `ai` **cannot** write them.
- Log growth: ~6.4 MB per service in 4h50m ≈ **1.3 MB/hour**, so ~32 MB/day each.
- Current fd limits on a running unit: `LimitNOFILE=524288` (hard),
  **`LimitNOFILESoft=1024`**. So the soft limit really is the legacy 1024 and raising it
  is not a no-op.
- `ExecStart` uses `/home/ai/.local/bin/claude` → `2.1.222` (current).
  A stale second install exists at `/usr/bin/claude` → `2.1.160`. Not used by the units.

## What changed versus the original patch, and why

| Original | Corrected | Reason |
|---|---|---|
| `sed -i` edits in place | Hand-written unit files | Original inserts duplicate directives on every re-run, and a same-day re-run overwrites the `.bak` with the already-patched file, destroying the rollback. |
| `MemoryMax=2G` per service | No per-service `MemoryHigh`; `MemoryMax=8G` per service backstop; `MemoryHigh=10G` + `MemoryMax=12G` on a shared slice | 2G is sized for idle. These services run builds and test suites; a single `popcrm-web` Playwright/Jest run can exceed 2G on its own. A per-service hard 2G would create OOM kills that do not happen today. A shared slice lets one bursting service borrow from five idle ones and only kills when the group is genuinely exhausted. A per-service `MemoryHigh` is deliberately omitted: `MemoryHigh` throttles rather than kills, so a low value produces silently very slow builds, which is harder to diagnose than a clean failure. The throttle belongs on the group, where it only engages as the group nears its ceiling. |
| `Restart=on-failure` | `Restart=always` (unchanged from current) | The original justification is wrong: an admin `systemctl stop` suppresses restart under `always` too. `on-failure` only adds the risk of staying down after a clean self-exit, on a service whose purpose is to always be reachable. `StartLimitBurst` is what caps restart loops, and it works identically under `always`. |
| `OOMPolicy=stop` | `OOMPolicy=continue` (systemd default) | Each server hosts up to 32 sessions. `stop` deliberately tears down the whole unit when any process in it is OOM-killed. `continue` leaves the rest running. This **reduces** the blast radius; it does not guarantee sessions survive — the kernel may still pick the main `claude` process, in which case `Restart=always` restarts the unit and every session on it is lost anyway. |
| (absent) | `MemorySwapMax=2G` on the slice | Swap thrash is a realistic host-killer, so the group needs a swap ceiling. But `0` is too strict: it removes the cushion that lets a short spike survive and converts it into a kill. Measured swap use by these services is currently 0, so 2 GB is headroom they are not using today, not a budget they will lean on. |
| (absent) | `TasksMax=2048` per service, `4096` on the slice | Measured idle is **121 tasks** per service. `TasksMax` counts threads, not just processes: Chromium, Playwright, Node workers and MCP tools are thread-heavy, so 512 is only ~4x idle and a single real Playwright run could reach it. |
| (absent) | `LimitNOFILE=8192:524288` | Raises the 1024 **soft** limit, which is what build tooling actually hits, while preserving systemd's usual 524288 hard limit. A bare `LimitNOFILE=8192` would set both, *lowering* the hard limit. Note this is a per-process limit, not an aggregate one — the "32 sessions exhaust 1024" framing was wrong. |
| logrotate `daily` | logrotate `daily`, `rotate 7`, `maxsize 200M` | Measured growth is ~1.3 MB/hour per service, so ~32 MB/day — daily rotation never reaches `maxsize`. Hourly rotation would have required a `logrotate.timer` drop-in (the host timer is daily-only) to solve a problem the measurements say does not exist. `rotate 7` keeps a week of history instead of six hours. |
| `su ai ai` | `su root root` | **Blocking bug in the original.** The log files are `root:root` mode 644 because systemd opens `StandardOutput=append:` as root before dropping to `User=ai`. Verified: user `ai` cannot write them. Rotating as `ai` would fail to truncate. `su` is still required because `/home/ai/logs` is non-root-owned, but it must name root. |
| (absent) | Documented `systemctl reset-failed` recovery | When `StartLimitBurst` is exhausted the unit parks in `failed` and stays down until a human clears it. The original verification section never says this. |

Kept from the original, unchanged, because they were correct:
`StartLimitIntervalSec=300` + `StartLimitBurst=5` (anti-zombie guard), `RestartSec=30`,
and the logrotate `copytruncate` choice. Everything else in the original `[Service]`
block changed; where this document and the original disagree, this document wins.

`copytruncate` is specifically correct here: `StandardOutput=append:` opens the log once
at service start and never reopens it, so logrotate's default `create` mode would leave
systemd writing to the rotated inode and the active log permanently empty. The `O_APPEND`
descriptor makes truncation safe (next write seeks to the new EOF, no sparse file).

Deliberately NOT added: `ProtectSystem`, `ProtectHome`, `NoNewPrivileges`,
`RestrictAddressFamilies`, `SystemCallFilter`. These services run arbitrary user-directed
build and test tooling; sandboxing them would break the workload.

## Files

### `/etc/systemd/system/claude-rc.slice` (NEW)

```ini
[Unit]
Description=Claude Code Remote Control services (shared resource budget)
Before=slices.target

[Slice]
MemoryAccounting=yes
MemoryHigh=10G
MemoryMax=12G
MemorySwapMax=2G
TasksAccounting=yes
TasksMax=4096
```

### `/etc/systemd/system/claude-rc@.service` (REPLACE)

```ini
[Unit]
Description=Claude Code Remote Control server (%i)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=ai
Group=ai
Slice=claude-rc.slice
Environment=HOME=/home/ai
Environment=PATH=/home/ai/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=/home/ai/%i
ExecStart=/home/ai/.local/bin/claude remote-control --name %i
Restart=always
RestartSec=30
MemoryAccounting=yes
MemoryMax=8G
TasksAccounting=yes
TasksMax=2048
LimitNOFILE=8192:524288
OOMPolicy=continue
StandardOutput=append:/home/ai/logs/claude-rc-%i.log
StandardError=append:/home/ai/logs/claude-rc-%i.log

[Install]
WantedBy=multi-user.target
```

### `/etc/systemd/system/claude-rc-worksp@.service` (REPLACE)

Identical to the above except:

```ini
WorkingDirectory=/worksp/%i
```

### `/etc/logrotate.d/claude-rc` (NEW)

```
/home/ai/logs/claude-rc-*.log {
    daily
    rotate 7
    maxsize 200M
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su root root
}
```

`su root root` is required and is not a typo. The directory `/home/ai/logs` is owned by
`ai`, so logrotate refuses to rotate inside it without an explicit `su`. But the log
files themselves are `root:root` mode 644, so the `su` target must be root or
`copytruncate` cannot truncate them.

Daily is sufficient at the measured 1.3 MB/hour. No `logrotate.timer` drop-in is needed,
which matters because the host timer is daily-only.

**This config was tested on the host before being written down**, because the ownership
layout is unusual enough that reasoning about it was not trusted:

- `su root root` against the real `/home/ai/logs`: `logrotate -d` considers all six logs,
  no skip, no error.
- **No `su` directive at all**: `logrotate -d` fails on every file with
  `skipping … because parent directory has insecure permissions (It's world writable or
  writable by group which is not "root")`. So `su` is mandatory here, not optional.
- End-to-end functional test on a throwaway directory replicating the exact layout
  (`ai:ai` mode 775 containing a `root:root` mode 644 file): `logrotate -f` produced
  `claude-rc-fake.log.1.gz` and truncated the original to 0 bytes. `copytruncate` under
  `su root root` works.

## Apply

Restarting the services interrupts every in-flight coding session across all six repos.
Do this when nothing is running.

```bash
# 1. Back up the existing templates, without clobbering an earlier backup
ts=$(date +%Y%m%dT%H%M%S)
for f in /etc/systemd/system/claude-rc@.service /etc/systemd/system/claude-rc-worksp@.service; do
  cp -n "$f" "$f.bak-$ts"
done

# 2. Write the four files above (slice, two templates, logrotate config)

# 3. Reload, then restart ONE service and let it prove itself
systemctl daemon-reload
systemctl restart claude-rc-worksp@popcrm-web.service

#    Run a real build and a Playwright suite in that repo from claude.ai/code, then:
systemctl show claude-rc-worksp@popcrm-web.service \
  -p MemoryPeak -p TasksCurrent -p NRestarts -p Result
#    Proceed only if it stayed active, MemoryPeak is well under 8G, and TasksCurrent
#    never approached 2048.

# 4. Restart the remaining five
systemctl restart claude-rc@dflow.service
for r in ai-devops shared-db poppim-web popdam; do
  systemctl restart "claude-rc-worksp@$r.service"
done

# 5. Verify logrotate before trusting it
logrotate -d /etc/logrotate.d/claude-rc
#    Then force one real rotation and confirm the service keeps writing:
logrotate -f /etc/logrotate.d/claude-rc
sleep 30 && ls -l /home/ai/logs/ && tail -3 /home/ai/logs/claude-rc-popcrm-web.log
```

## Verify

```bash
# All six back up
systemctl list-units 'claude-rc*' --no-pager

# Limits actually applied (not silently ignored)
systemctl show claude-rc@dflow.service \
  -p Slice -p MemoryMax -p TasksMax -p LimitNOFILE -p LimitNOFILESoft \
  -p Restart -p OOMPolicy -p StartLimitBurst

# Slice budget in force
systemctl show claude-rc.slice \
  -p MemoryHigh -p MemoryMax -p MemorySwapMax -p TasksMax -p MemoryCurrent

# Aggregate usage across the group
systemctl status claude-rc.slice --no-pager | head -20

# Per-service usage and task counts (idle baseline: ~650M, 121 tasks)
for s in $(systemctl list-units 'claude-rc*' --no-legend --no-pager | awk '{print $1}'); do
  printf '%-42s mem=%-6s tasks=%s\n' "$s" \
    "$(systemctl show "$s" -p MemoryCurrent --value | numfmt --to=iec)" \
    "$(systemctl show "$s" -p TasksCurrent --value)"
done

# Restart churn
for s in claude-rc@dflow claude-rc-worksp@ai-devops; do
  printf '%-42s ' "$s"; systemctl show "$s.service" -p NRestarts --value
done
```

Healthy: all six `active (running)`, `NRestarts` near 0, slice `MemoryCurrent` around
4-5 GB, and `Connected` in each log file.

## Recovery: service parked in `failed` after repeated crashes

After 5 failures in 300 seconds systemd stops retrying and leaves the unit `failed`.
It will not come back on its own.

```bash
systemctl reset-failed claude-rc-worksp@popcrm-web.service
systemctl start claude-rc-worksp@popcrm-web.service
journalctl -u claude-rc-worksp@popcrm-web.service --since '1 hour ago' --no-pager | tail -50
```

## Rollback

```bash
for f in /etc/systemd/system/claude-rc@.service /etc/systemd/system/claude-rc-worksp@.service; do
  cp "$f.bak-<timestamp>" "$f"
done
rm -f /etc/systemd/system/claude-rc.slice /etc/logrotate.d/claude-rc
systemctl daemon-reload
systemctl restart claude-rc@dflow.service
for r in ai-devops shared-db popcrm-web poppim-web popdam; do
  systemctl restart "claude-rc-worksp@$r.service"
done
```

## Review trail

- **GLM 5.2** reviewed the original sed-based patch. It caught the two blocking issues
  (`MemoryMax=2G` sized for idle, and the false premise behind `Restart=on-failure`) and
  proposed the shared-slice model. Report: `.ai/reviews/glm-claude-rc-hardening-review-20260805T184426Z.md`.
- **Codex (gpt-5.6, medium effort)** reviewed this corrected version independently. It
  confirmed the systemd semantics and the slice design, and rejected four of the numbers:
  per-service `MemoryHigh=2G` (throttles rather than kills → silently slow builds),
  `MemorySwapMax=0` (needlessly strict), `TasksMax=512` (threads, not processes), and
  `LimitNOFILE=8192` (lowers the hard limit; the stated rationale was also wrong). It
  also asked for a one-service canary. All four accepted; all are reflected above.
- **GLM 5.2, second pass** on this revised document accepted all four Codex changes and
  confirmed the slice design. It raised one blocking objection — that `su root root`
  would make logrotate skip the directory entirely because `/home/ai/logs` is `ai:ai`
  mode 775 — and recommended `chown root:root` + `chmod 755` and dropping `su`.
  **That objection was tested on the host and is wrong, and its recommended fix is the
  actual failure mode:** with `su root root` logrotate processes all six logs cleanly,
  while removing `su` produces exactly the "insecure permissions" skip GLM predicted for
  the opposite case. No directory ownership change is needed. Evidence is in the
  logrotate section above. GLM's other findings (the stale summary paragraph, and the
  unmeasured `LimitNOFILE` baseline) were valid and are both resolved here.
  Report: `.ai/reviews/glm-claude-rc-hardening-review-20260805T193705Z.md`.
- **Direct measurement on the host** then caught one thing neither model could see: the
  log files are `root:root`, so the original `su ai ai` would have made rotation fail
  silently. Fixed to `su root root`. Measurement also showed log growth is ~1.3 MB/hour,
  which made the hourly-rotation change unnecessary, and idle task count is 121, which
  confirmed Codex's objection to `TasksMax=512`.

## Still outstanding after this patch

1. Not in Ansible. A rebuild wipes all of it.
2. Stale `/usr/bin/claude` (2.1.160) shadows nothing today but will confuse the next
   person. Remove it or update it.
3. Redundant `/usr/local/bin/cc` and `/usr/local/bin/ccls` from the earlier tmux
   approach. Safe to delete.
