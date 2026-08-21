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
- **Our measured reality: 13.2%** on the last real session (2026-08-12), and
  ~5.7% lifetime across 845 requests (see §6). The old "0.27%" figure was
  measured BEFORE the 2026-07-14 crash-loop fix and is obsolete — do not quote
  it. On our workload the payoff now looks close to the vendor claim.
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
That CLI runs as the **`ai`** user. The redirect is set in **two** places, and
both matter:

```jsonc
// /home/ai/.claude/settings.json  — the reliable one
"env": { "ANTHROPIC_BASE_URL": "http://<removed-protected-address>:8787" }
```

```bash
# /home/ai/.bashrc  — ABOVE the non-interactive guard (see warning below)
export ANTHROPIC_BASE_URL=http://<removed-protected-address>:8787
```

> 🚨 **The non-interactive-shell trap (found 2026-08-21).** `~/.bashrc` opens
> with the stock Debian guard `case $- in *i*) ;; *) return;; esac`. A Claude
> Code SSH session runs a **non-interactive** shell, so it hits that `return`
> and every export below it is skipped. The proxy export used to sit at line
> ~138, far below the guard — so VPS sessions started from Claude Code silently
> went straight to Anthropic while everyone believed they were proxied. Only
> sessions launched from a real interactive terminal were ever compressed;
> `savings_events.jsonl` shows exactly that pattern (7 scattered days in a
> month, nothing between). The export is now above the guard, and
> `settings.json` carries it too so it no longer depends on shell type at all.
>
> Verify after any change to either file:
>
> ```bash
> ssh vps2-direct 'echo $ANTHROPIC_BASE_URL'   # non-interactive; must NOT be empty
> ```
>
> This is the same trap that bit the 1Password service-account token on
> 2026-07-23. Anything an AI session needs must live above that guard.

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

**Numbers as of 2026-08-21** (superseding the pre-fix 2026-07-14 reading of
50 requests / 0.27%, which was taken while the proxy was crash-looping):

| Metric | Value |
|---|---|
| Requests handled (lifetime) | 845 |
| Tokens saved (lifetime) | 1,997,341 of 35,298,425 input tokens (**~5.7%**) |
| $ saved (lifetime) | ~$9.99 |
| Last real session (2026-08-12) | 872,525 saved of 5,727,745 (**13.22%**), ~$4.36 |
| Last real activity | **2026-08-12** |

> ⚠️ **Traffic, not health, is the thing to check.** On 2026-08-21 the service
> was `active`, `enabled`, 16 days uptime, `NRestarts=0`, `/health` green — and
> had carried **zero** traffic for nine days, because only Workflow A (Claude
> running on the VPS itself) is still wired. A green health check proves nothing
> about whether anything is being saved. Always read `last_activity_at` in
> `proxy_savings.json`.

### Which machines are wired (re-checked 2026-08-21)

| Machine | Wired? | Evidence |
|---|---|---|
| hetz VPS `ai` user (Workflow A) | ✅ yes (repaired 2026-08-21) | `~/.claude/settings.json` `env` block + `.bashrc` export moved above the non-interactive guard. Was half-broken before: interactive terminals were proxied, Claude Code SSH sessions were not. |
| **edge-dev** (Workflow B) | ✅ yes (wired 2026-08-21) | `env` block added to `~/.claude/settings.json`; was previously unwired and bypassing the proxy |
| AL8960OFC, other Windows boxes | ❓ unverified since 2026-07-14 | re-check each machine's `~/.claude/settings.json` |

The ground truth for total spend is always the Anthropic Console / Claude usage
screen — Headroom's own ledger only counts what actually flowed through it.

## 7. Known risks / trade-offs

- **Single point of failure — this is the real cost of using it.** A wired
  Claude sends 100% of its traffic to the proxy and there is **no automatic
  fallback**: Claude Code has no "try the proxy, else go direct" behaviour. If
  the hetz VPS is down, the `headroom` service is stopped, or the machine's
  Tailscale link drops, **Claude stops working entirely** until the redirect is
  removed and Claude is restarted. Three separate things must all stay up.

  The escape hatch is the **`ai-headroom`** command. It is a normal command on
  PATH from any folder — no repo path to remember mid-outage:

  ```bash
  ai-headroom status   # what am I using, and is the proxy answering?
  ai-headroom off      # go straight to Anthropic
  ai-headroom on       # route through the proxy again
  ```

  `off` takes about ten seconds, plus a full quit-and-reopen of Claude. `on`
  refuses to run if the proxy is not answering, so it cannot strand you. Every
  change backs up `settings.json` first. Works on Windows (Git Bash) and Ubuntu.

  **How it reaches every machine:** `bin/ai-headroom` is registered in
  `config/machine-tools.tsv`, so `bin/install-machine-tools.ps1` (Windows) /
  `bin/install-machine-tools.sh` (Ubuntu) creates the launcher in
  `~/.local/bin` and puts that directory on PATH. On a machine that has not
  synced yet, run the `sync-dotfiles` skill — it pulls the repo and reruns the
  installer. Until then, `bash C:eposi-devopsini-headroom off`
  works directly from the clone.

  The VPS-side equivalent is `/home/ai/.claude/settings.json` plus the
  `.bashrc` export — remove both to go direct there.
- **Extra hop / latency.** Local-Windows requests now go
  laptop → VPS → Anthropic instead of straight to Anthropic.
- **Unofficial posture.** Routing a Claude *subscription* through a modifying
  third-party proxy is not an Anthropic-sanctioned path. It works technically and
  did before, but carries some non-zero breakage/account risk. Albert's account,
  Albert's call.
- **Savings now look real** (13.2% on the last measured session) but the sample
  is small, and the "pull it if it is not worth it" stance above still stands.
- **Silent disuse is the real failure mode**, not crashes. Nothing alerts when a
  machine stops routing through the proxy — it just quietly saves nothing while
  looking perfectly healthy. See the warning in §6.

## 8. How to turn it OFF / revert

**Per machine (Workflow B):** run `ai-headroom off`,
then fully quit and reopen Claude Desktop. (Manually: remove the
`"env": { "ANTHROPIC_BASE_URL": ... }` block from that machine's
`~/.claude/settings.json`.) Claude goes straight back to Anthropic.

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
| Off switch (any machine) | `ai-headroom off` + fully restart Claude |
| Check what I'm using | `ai-headroom status` |
| Off switch (VPS `ai`) | remove `env` from `/home/ai/.claude/settings.json` **and** the `.bashrc` export |

---

## 10. Does this work for ChatGPT / Codex?

**Yes — Headroom 0.30.0 has an OpenAI/Codex pipeline**, separate from the
Anthropic one. `headroom proxy --help` exposes
`--disable-kompress-openai / --enable-kompress-openai` ("OpenAI/Codex pipeline
only"), `--openai-api-url` (`OPENAI_TARGET_API_URL`) for the upstream target,
and Codex wire logging to `~/.headroom/logs/codex_wire`.

**But we have never used it.** Every one of the 433 recorded compression events
is `"client":"claude-code"` — zero Codex traffic, lifetime. So the capability is
documented by the vendor and present in our build, and **unproven here**.

Wiring Codex would mean pointing its API base at the proxy the same way Claude's
is pointed. Treat it as a fresh experiment with its own measurement, not as
something already known to work — and note that Codex sign-in flows are fussier
about a rewritten base URL than Claude's are.
