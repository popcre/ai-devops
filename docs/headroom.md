# Headroom token-compression proxy

**What it is, where it runs, how our machines route through it, what was done to
fix it on 2026-07-14, how to measure it, and how to turn it off.**

Written for someone with **zero prior context**. Headroom is third-party
infrastructure that sits *outside* this toolkit's code — it is documented here
because it affects how every Claude session on our machines reaches Anthropic.

---

## 1. What Headroom is and why we have it

[Headroom](https://github.com/headroomlabs-ai/headroom) is an open-source
**context-compression proxy**. It sits between a Claude client (Claude Code /
Claude CLI) and Anthropic's API, compresses large tool outputs / logs / file
blobs *before* they are sent upstream, and forwards everything else untouched.
Goal: **fewer input tokens per request → lower Claude token usage.**

- Vendor claim: 15–20% fewer tokens for coding agents (60–95% for raw JSON).
- **Our measured reality so far: 0.27%** (see §6). Payoff is **unproven** on our
  workload — this is being run as a measured experiment, not a proven win.
- Installed version: **0.30.0** (pipx, Python).

> ⚖️ **Standing decision: if it is not clearly worth it, we pull it.** This is a
> trial. After real sessions run through it, read the savings (§6). If the token
> reduction is not clearly worth the extra network hop, the moving parts, and the
> unofficial "subscription-through-a-proxy" posture (§7), **remove it** (§8).
> There is no sunk-cost attachment here.

## 2. Where it lives

Everything Headroom is on the **hetz VPS** (the Hetzner box that also runs
Coolify). Nothing is installed on any Windows machine — the Windows machines only
*point at* it.

| Thing | Value |
|---|---|
| Host | hetz VPS — Tailscale name `hetz`, Tailscale IP `<removed-protected-address>`, public IP `<removed-protected-address>` |
| Install method | `pipx`, under Linux user **`ai`** |
| Binary | `/home/ai/.local/bin/headroom` |
| Data / logs dir | `/home/ai/.headroom/` |
| systemd unit | `/etc/systemd/system/headroom.service` |
| Listen address | **`<removed-protected-address>:8787`** — the **private Tailscale interface only** |

### The service

```ini
# /etc/systemd/system/headroom.service  (key lines)
[Unit]
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service      # waits for Tailscale on boot
[Service]
User=ai
ExecStart=/home/ai/.local/bin/headroom proxy --port 8787 --host <removed-protected-address>
Restart=on-failure
RestartSec=5
StandardOutput=append:/home/ai/.headroom/logs/proxy.log
StandardError=append:/home/ai/.headroom/logs/proxy.log
```

Health check (from any machine on the tailnet, or the VPS itself):

```bash
curl -s http://<removed-protected-address>:8787/health      # -> {"status":"healthy","ready":true,...}
```

## 3. Security posture (important)

- The proxy is bound to the **Tailscale IP only** — it is reachable from our own
  devices on the tailnet and **never from the public internet**.
- **It must NOT be bound to `0.0.0.0`.** The VPS host firewall has a
  **default-ACCEPT INPUT policy** and **no rule blocking port 8787**, so binding
  to all interfaces would expose the proxy — and therefore our Claude
  subscription / quota — to the entire internet. Verified 2026-07-14.
- The proxy forwards the client's own Anthropic auth (OAuth / key) upstream
  unchanged; it does **not** hold a separate API key.

## 4. How each workflow routes through it

There are two ways Albert codes, and each reaches Headroom differently. Both now
point at the same address: **`http://<removed-protected-address>:8787`**.

### Workflow A — Claude running **on the VPS** (remote/SSH mode)

"Claude for Windows connects via SSH to the Claude CLI running on the hetz VPS."
That CLI runs as the **`ai`** user, whose shell exports the proxy address:

```bash
# /home/ai/.bashrc  (line ~138)
export ANTHROPIC_BASE_URL=http://<removed-protected-address>:8787
```

The VPS reaches its own Tailscale IP locally, so this needs no tunnel. This is
the workflow that produced the only real savings we have so far (2026-07-07).

### Workflow B — Claude running **locally on a Windows machine** (clone-and-code mode)

The local Claude is redirected via its Claude Code settings:

```jsonc
// C:\Users\<user>\.claude\settings.json
"env": { "ANTHROPIC_BASE_URL": "http://<removed-protected-address>:8787" }
```

Because the Windows machine is on the tailnet, it reaches the VPS proxy directly
over Tailscale — **no SSH tunnel required**. The setting takes effect only after
**Claude Desktop is fully quit and reopened** (tray icon → Quit).

> **Optional fallback (SSH tunnel).** The `ssh vps2` host entry also carries
> `LocalForward 8787 <removed-protected-address>:8787`. If Tailscale-direct is ever undesirable,
> a local Claude can instead use `http://localhost:8787` while an `ssh vps2`
> session is open. This is a fallback, not the primary path.

### Which machines are actually wired (as of 2026-07-14)

| Machine | Wired? | Where |
|---|---|---|
| hetz VPS `ai` user (Workflow A) | ✅ yes | `/home/ai/.bashrc` |
| **AL8960OFC** (office Windows, Workflow B) | ✅ yes | `~/.claude/settings.json` — **needs a Claude Desktop restart to activate** |
| Other 2 local Windows machines | ❌ not yet | add the same `env` block to their `~/.claude/settings.json` to include them |

## 5. What was done on 2026-07-14 (incident + fix)

**Symptom found:** Headroom was installed but **useless and wasteful** —
saving nothing while burning CPU 24/7.

**Root cause:** the systemd service had **failed to start 35,859 times** in a
crash loop. A hand-started proxy (`pid 133277`, up 10 days) was holding port
8787, so the service could never bind — it loaded ML models for ~12s, died with
`[Errno 98] address already in use`, waited 5s, and repeated forever. Its own
counters showed the proxy handled real traffic only in a single ~10-minute
window on 2026-07-07 and nothing since.

**Fix applied (this repo's owner's machine + the VPS):**

1. Stopped the crash-looping service; `systemctl reset-failed` cleared the
   35,859 counter.
2. Killed the orphan hand-started proxy (`pid 133277`) and 7 stray
   `headroom mcp serve` leftovers.
3. Removed stale lock files (`.beacon_lock_8787`, `.rtk_poll_lock`).
4. Re-bound the proxy to the **private Tailscale IP** (`--host <removed-protected-address>`) so
   it is reachable by our machines but never the public internet.
5. **Hardened boot ordering** (`After=/Wants=network-online.target
   tailscaled.service`) so a VPS reboot cannot restart the crash loop by binding
   before Tailscale is up.
6. Wired the office Windows machine (Workflow B) via `settings.json`.
7. Repointed the VPS `ai` user (Workflow A) and the `ssh vps2` tunnel from the
   now-dead `127.0.0.1:8787` to `<removed-protected-address>:8787`.

Result: one healthy proxy, both workflows routed, reboot-safe, private-only.

## 6. How to see whether it is actually helping

On the VPS (`ssh hetzner`, or via the `devops-mcp` MCP):

```bash
cat /home/ai/.headroom/proxy_savings.json     # lifetime + per-request history
cat /home/ai/.headroom/savings_events.jsonl   # one line per compressed request
sudo -u ai /home/ai/.local/bin/headroom perf        # savings report
sudo -u ai /home/ai/.local/bin/headroom dashboard   # live savings screen
```

**Lifetime numbers at fix time (2026-07-14):**

| Metric | Value |
|---|---|
| Requests handled | 50 |
| Tokens saved | 594 of 217,845 input tokens (**0.27%**) |
| $ saved | ~$0.003 |
| Last real activity | 2026-07-07 |

The ground truth for total spend is always the Anthropic Console / Claude usage
screen — Headroom's own ledger only counts what actually flowed through it.

## 7. Known risks / trade-offs

- **Single point of failure.** If the VPS or the proxy is down, any wired Claude
  cannot connect until the redirect is removed (§8). Watch it for a few days
  after enabling.
- **Extra hop / latency.** Local-Windows requests now go
  laptop → VPS → Anthropic instead of straight to Anthropic.
- **Unofficial posture.** Routing a Claude *subscription* through a modifying
  third-party proxy is not an Anthropic-sanctioned path. It works technically and
  did before, but carries some non-zero breakage/account risk. Albert's account,
  Albert's call.
- **Unproven savings** (0.27% so far) — the whole reason for the "pull it if not
  worth it" stance above.

## 8. How to turn it OFF / revert

**Per Windows machine (Workflow B):** remove the `"env": { "ANTHROPIC_BASE_URL":
... }` block from that machine's `~/.claude/settings.json`, then fully quit and
reopen Claude Desktop. Claude goes straight back to Anthropic.

**VPS `ai` user (Workflow A):** comment out / remove the `export
ANTHROPIC_BASE_URL=...` line in `/home/ai/.bashrc`.

**Stop the proxy entirely on the VPS:**

```bash
ssh hetzner
systemctl stop headroom.service
systemctl disable headroom.service     # also prevent it starting on boot
```

**Remove it completely:** the above, plus `pipx uninstall headroom-ai` as the
`ai` user and `rm -rf /home/ai/.headroom /etc/systemd/system/headroom.service`.

## 9. Quick reference

| Item | Value |
|---|---|
| Proxy URL (all clients) | `http://<removed-protected-address>:8787` |
| Health endpoint | `http://<removed-protected-address>:8787/health` |
| VPS access | `ssh hetzner` (root) or `ssh vps2` (ai) or `devops-mcp` MCP |
| Service control | `systemctl {status,restart,stop} headroom.service` |
| Savings data | `/home/ai/.headroom/proxy_savings.json`, `savings_events.jsonl` |
| Off switch (this machine) | delete `env` block in `~/.claude/settings.json` + restart Claude Desktop |
