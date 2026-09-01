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
- **Our measured reality: ~2.2%** over the trailing 7 days to 2026-08-31, and
  ~4.1% lifetime across 1,756 requests (see §6). The old "0.27%" figure was
  measured BEFORE the 2026-07-14 crash-loop fix and is obsolete — do not quote
  it. Higher per-session figures quoted earlier (13.2%) were single favourable
  sessions, not a trend. **All of these are `token`-mode / 0.30.0 numbers and
  must be re-measured** — see §5b and §5c.
- It does **not** break the prompt cache; that was measured, not assumed (§5b).
- Installed version: **0.37.0** (pipx package `headroom-ai`, upgraded from
  0.30.0 on 2026-08-31).

> ⚖️ **Standing decision: if it is not clearly worth it, we pull it.** This is a
> trial. After real sessions run through it, read the savings (§6). If the token
> reduction is not clearly worth the extra network hop, the moving parts, and the
> unofficial "subscription-through-a-proxy" posture (§7), **remove it** (§8).
> There is no sunk-cost attachment here.

## 2. Where it lives

Everything Headroom is on the **hetz VPS** (the Hetzner box that also runs
Coolify). Nothing is installed on any Windows machine — the Windows machines only
*point at* it.

Concrete addresses are protected. Resolve the reviewed endpoint when following
this guide:

```bash
HEADROOM_URL="$(ai-private-config value headroom_proxy_url)"
HEADROOM_HOST="${HEADROOM_URL#http://}"; HEADROOM_HOST="${HEADROOM_HOST%%:*}"
```

| Thing | Value |
|---|---|
| Host | hetz VPS; concrete addresses are in the protected machine atlas |
| Install method | `pipx`, under Linux user **`ai`** |
| Binary | `/home/ai/.local/bin/headroom` |
| Data / logs dir | `/home/ai/.headroom/` |
| systemd unit | `/etc/systemd/system/headroom.service` |
| Listen address | **`$HEADROOM_HOST:8787`** — the **private Tailscale interface only** |

### The service

```ini
# /etc/systemd/system/headroom.service  (key lines)
[Unit]
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service      # waits for Tailscale on boot
[Service]
User=ai
ExecStart=/home/ai/.local/bin/headroom proxy --port 8787 --host $HEADROOM_HOST
Restart=on-failure
RestartSec=5
StandardOutput=append:/home/ai/.headroom/logs/proxy.log
StandardError=append:/home/ai/.headroom/logs/proxy.log
```

Health check (from any machine on the tailnet, or the VPS itself):

```bash
curl -s "$HEADROOM_URL/health"      # -> {"status":"healthy","ready":true,...}
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
point at the same protected address, **`$HEADROOM_URL`**.

### Workflow A — Claude running **on the VPS** (remote/SSH mode)

"Claude for Windows connects via SSH to the Claude CLI running on the hetz VPS."
That CLI runs as the **`ai`** user. The redirect is the `export` in
`/home/ai/.bashrc`, placed **above the non-interactive guard**:

```bash
# /home/ai/.bashrc  — ABOVE the non-interactive guard (see warning below)
export ANTHROPIC_BASE_URL="$HEADROOM_URL"
```

> A `settings.json` `env` block is **not** a second source and never was — see
> the measurement in Workflow B below. `ai-headroom on` / `off` manage this
> `export` line and delete any stale `settings.json` entry they find.

> 🚨 **The non-interactive-shell trap (found 2026-08-21).** `~/.bashrc` opens
> with the stock Debian guard `case $- in *i*) ;; *) return;; esac`. A Claude
> Code SSH session runs a **non-interactive** shell, so it hits that `return`
> and every export below it is skipped. The proxy export used to sit at line
> ~138, far below the guard — so VPS sessions started from Claude Code silently
> went straight to Anthropic while everyone believed they were proxied. Only
> sessions launched from a real interactive terminal were ever compressed;
> `savings_events.jsonl` shows exactly that pattern (7 scattered days in a
> month, nothing between). The export is now above the guard, and
> (An earlier fix also added it to `settings.json` "for safety" — that entry is
> inert and has since been removed; see the measurement in Workflow B.)
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

> **`settings.json` DOES NOT WORK for this, and never did.** Measured on Claude
> Code 2.1.234 (2026-08-21): an `"env": {"ANTHROPIC_BASE_URL": ...}` block in
> `~/.claude/settings.json` is accepted, displayed by every settings reader, and
> **completely ignored** -- a fresh `claude` process sent **zero** requests to
> the proxy. The identical test with the variable in the real environment routed
> immediately (proxy inbound count 352 -> 356). Claude resolves its base URL
> before settings `env` is applied.
>
> This is why the proxy sat idle for weeks while every status check reported it
> was in use. A setting that is accepted but ignored is worse than one that
> errors.

The redirect must be a **persistent Windows USER environment variable**:

```powershell
$headroomUrl = & ai-private-config value headroom_proxy_url
[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL',$headroomUrl,'User')
```

Prefer `ai-headroom on` / `ai-headroom off` over setting it by hand: the tool
writes the variable, reads it back to prove it took, and deletes the misleading
`settings.json` entry if one is present. Only Claude sessions started **after**
the change are affected -- neither mechanism reaches an already-running process,
so a full quit and reopen is required.

Because the Windows machine is on the tailnet, it reaches the VPS proxy directly
over Tailscale — **no SSH tunnel required**. The setting takes effect only after
**Claude Desktop is fully quit and reopened** (tray icon → Quit).

> **Optional fallback (SSH tunnel).** The `ssh vps2` host entry also carries
> the protected SSH template's Headroom forward. If Tailscale-direct is ever undesirable,
> a local Claude can instead use `http://localhost:8787` while an `ssh vps2`
> session is open. This is a fallback, not the primary path.

### Which machines are actually wired (as of 2026-07-14)

| Machine | Wired? | Where |
|---|---|---|
| hetz VPS `ai` user (Workflow A) | ✅ yes | `/home/ai/.bashrc` |
| **AL8960OFC** (office Windows, Workflow B) | ❓ recheck | was wired via `settings.json`, which is INERT — treat as NOT wired until `ai-headroom status` says otherwise |
| Other Windows machines | ❌ not yet | run `ai-headroom on` on each (sets the persistent USER environment variable — a `settings.json` block does nothing) |

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
4. Re-bound the proxy to the **private Tailscale address** (`--host "$HEADROOM_HOST"`) so
   it is reachable by our machines but never the public internet.
5. **Hardened boot ordering** (`After=/Wants=network-online.target
   tailscaled.service`) so a VPS reboot cannot restart the crash loop by binding
   before Tailscale is up.
6. Wired the office Windows machine (Workflow B) via `settings.json` — **which
   we now know does nothing**; that machine was never actually proxied. See
   Workflow B.
7. Repointed the VPS `ai` user (Workflow A) and the `ssh vps2` tunnel from the
   now-dead loopback endpoint to the protected Tailscale endpoint.

Result: one healthy proxy, both workflows routed, reboot-safe, private-only.

## 5b. Prompt-cache safety and optimization mode (settled 2026-08-31)

**The concern.** A widely circulated criticism says compression proxies destroy
your prompt cache: because Anthropic discounts a re-read prefix by ~90%, any
tool that rewrites earlier turns invalidates the cache from the edit point
onward, and every token after it re-bills at full rate. Trading a ~90% native
discount for a few percent of compression would be a net loss.

**It is a real mechanism, and Headroom has a switch for it.** `headroom proxy`
takes `--mode [token|cache]`:

- `token` — "prior turns may be rewritten for max savings" (cache-unsafe)
- `cache` — "freeze prior turns to maximise provider prefix-cache hit rate"

Until 2026-08-31 our `headroom.service` passed **no `--mode` flag**, so it ran
the then-default `token` mode — the cache-unsafe one.

**What we measured.** `proxy.log` records `cache_read`, `cache_write` and
`cache_hit_pct` per request, so the question was answerable from history with no
API spend. On deep conversations (`msgs >= 10`), comparing requests Headroom
compressed against requests it left untouched:

| Group | Requests | Avg cache hit | Avg cache_write | Avg tokens saved |
|---|---|---|---|---|
| Compressed | 718 | **92.5%** | 6,199 | 2,444 |
| Untouched | 16 | 86.1% | 25,599 | 0 |

Compression correlated with **better** cache performance and 4x less cache
rewriting — the opposite of the criticism. The reason is visible in the
`transforms=` field: the router is conservative, and most entries are
`router:excluded:tool`, `router:protected:*` or `router:noop`. The only genuine
edits are `router:tool_result:text` — the newest tool output, not history.

**What we changed anyway.** Relying on a cache-unsafe mode choosing to behave is
not a control. On 2026-08-31 the unit was backed up to
`headroom.service.bak-2026-08-31` and `--mode cache` was added explicitly. The
proxy now logs at startup:

```
Mode: cache
  Prefix freeze: strict (all prior turns immutable)
  Mutations: latest turn only
```

**Vendor agreement.** Headroom 0.37.0 changed its own default to `cache`. Our
explicit flag is now belt-and-braces rather than a deviation.

> ⚠️ **All savings figures in §6 predate this change.** They were measured in
> `token` mode on 0.30.0. 0.37.0 also enables code-aware (AST) compression that
> was not previously active. The percentages must be re-measured before being
> quoted as current.

## 5c. Durable performance recording (added 2026-08-31)

`proxy.log` rotates at ~10 MB keeping 5 files, so the evidence above was on a
path to being overwritten. Metrics are now extracted to a permanent CSV.

| Item | Path |
|---|---|
| Recorder | `/home/ai/headroom-perf/record.py` |
| Data | `/home/ai/headroom-perf/perf.csv` |
| Cron log | `/home/ai/headroom-perf/record.log` |
| Schedule | `17 * * * *` in the `ai` user crontab |

The recorder parses every `PERF` line from `proxy.log` and its rotations into
`ts, reqid, model, msgs, tok_before, tok_after, tok_saved, cache_read,
cache_write, cache_hit_pct, transforms`. It is **idempotent** — it dedupes on the
`hr_` request id, so re-running it adds nothing. Run it by hand any time:

```bash
sudo -u ai python3 /home/ai/headroom-perf/record.py
```

The `token`-mode baseline is preserved: **1,706 requests, 2026-07-15 to
2026-08-28.** Compare `cache` mode against that window rather than against the
narrative figures in §6.

> Watch out: the log timestamp uses a comma for milliseconds
> (`18:11:53,213`). A naive CSV split on commas shifts every column and silently
> drops rows — the first version of this recorder lost a third of the data while
> looking correct. The current parser anchors on a full regex.

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
| Requests handled (lifetime) | 1,020 |
| Tokens saved (lifetime) | 2,328,077 of 41,771,171 input tokens (**~5.6%**) |
| $ saved (lifetime) | ~$11.52 |
| Most recent session | 60,423 saved of 1,285,497 (**4.49%**) |
| Last real activity | **2026-08-26** |

Read live with the commands above; these are a snapshot, re-checked 2026-08-27.

> **These numbers are `token`-mode / 0.30.0 figures and are now historical.**
> See §5b. The durable per-request record in §5c is the source to re-measure
> from. Live lifetime as of 2026-08-31: 1,756 requests, 2,854,228 tokens saved
> (~$14.15) against $200.66 of input; trailing 7 days 668,804 saved on
> 30,253,311 sent = **2.21%**.

> ⚠️ **Traffic, not health, is the thing to check.** On 2026-08-21 the service
> was `active`, `enabled`, 16 days uptime, `NRestarts=0`, `/health` green — and
> had carried **zero** traffic for nine days, because only Workflow A (Claude
> running on the VPS itself) is still wired. A green health check proves nothing
> about whether anything is being saved. Always read `last_activity_at` in
> `proxy_savings.json`.

### Which machines are wired (re-checked 2026-08-21)

| Machine | Wired? | Evidence |
|---|---|---|
| hetz VPS `ai` user (Workflow A) | ✅ yes (repaired 2026-08-21) | `.bashrc` export moved above the non-interactive guard. Was half-broken before: interactive terminals were proxied, Claude Code SSH sessions were not. |
| **edge-dev** (Workflow B) | ✅ yes (2026-08-21) | persistent USER environment variable, set by `ai-headroom on`; proven routing (proxy count 362 → 366) |
| 4837 (this Windows box) | ✅ yes (verified 2026-08-27) | `ai-headroom status` shows the persistent Windows user env var routing to the proxy; proxy healthy. |
| AL8960OFC, other Windows boxes | ❓ unknown | run `ai-headroom status` on each; wire with `ai-headroom on`. Do not assume unwired — 4837 turned out to be wired despite this table. |

### What Headroom does NOT explain (measured 2026-08-27)

Headroom is a ~5% effect and cannot account for large differences between
tools or plans. Measured over the same two-day window on 4837:

- Claude handled ~1.9B tokens of context and produced 5.4M output tokens.
- Codex handled ~1.5B tokens of context and produced 2.0M output tokens.
- Codex was nonetheless at **61% of its weekly allowance** after those two days
  (full limit in ~3.2 days of a 7-day window).

Claude did more work and was not the thing running out. The gap is plan
allowance, not compression. Separately, Codex cost concentrates in long turns:
the 20% of sessions with the most model calls account for **88%** of all input
tokens, **67%** of full-price tokens and **72%** of output. Session *count* is
not the driver — session *turn depth* is.

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
  change backs up the file it touches first. Works on Windows (Git Bash) and Ubuntu.

  **How it reaches every machine:** `bin/ai-headroom` is registered in
  `config/machine-tools.tsv`, so `bin/install-machine-tools.ps1` (Windows) /
  `bin/install-machine-tools.sh` (Ubuntu) creates the launcher in
  `~/.local/bin` on Windows, `/usr/local/bin` on Ubuntu, and puts it on PATH.
  On a machine that has not synced yet, run the `sync-dotfiles` skill — it
  pulls the repo and reruns the installer. Until then, run it from the clone:

  ```bash
  bash /c/repos/ai-devops/bin/ai-headroom off
  ```

  On the VPS the switch is the `export` line in `/home/ai/.bashrc`; on Windows
  it is the persistent USER environment variable. `ai-headroom` manages whichever
  applies, deletes any stale `settings.json` entry, and warns when the shell you
  are standing in has drifted from the persistent setting.
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

**Per machine (Workflow B):** run `ai-headroom off`, then fully quit and reopen
Claude.

Manually, if the command is unavailable — note that **removing the
`settings.json` block does nothing**, because that block was never the switch:

```powershell
[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL',$null,'User')
```

Then open a **new** terminal (existing ones keep the old value) and restart Claude.

**VPS `ai` user (Workflow A):** run `ai-headroom off`, or comment out the
`export ANTHROPIC_BASE_URL=...` line in `/home/ai/.bashrc` by hand.

**Stop the proxy entirely on the VPS:**

```bash
ssh hetzner
systemctl stop headroom.service
systemctl disable headroom.service     # also prevent it starting on boot
```

**Remove it completely.** `/home/ai/.headroom` holds the entire savings ledger
and proxy logs — the only record of whether this experiment paid off. Archive it
before deleting, so a later "was Headroom worth it?" question is still answerable:

```bash
tar czf /home/ai/headroom-final-$(date +%Y%m%d).tar.gz /home/ai/.headroom
cp /etc/systemd/system/headroom.service /home/ai/headroom.service.bak
```

Then, and only then: `pipx uninstall headroom-ai` as the `ai` user, and
`rm -rf /home/ai/.headroom /etc/systemd/system/headroom.service`.

## 9. Quick reference

| Item | Value |
|---|---|
| Proxy URL (all clients) | `ai-private-config value headroom_proxy_url` |
| Health endpoint | the protected proxy URL plus `/health` |
| VPS access | `ssh hetzner` (root) or `ssh vps2` (ai) or `devops-mcp` MCP |
| Service control | `systemctl {status,restart,stop} headroom.service` |
| Savings data | `/home/ai/.headroom/proxy_savings.json`, `savings_events.jsonl` |
| Durable perf record | `/home/ai/headroom-perf/perf.csv` (hourly cron, §5c) |
| Optimization mode | `cache` (prefix freeze strict) — set in the unit, §5b |
| Unit backup | `/etc/systemd/system/headroom.service.bak-2026-08-31` |
| Off switch (any machine) | `ai-headroom off` + fully restart Claude |
| Check what I'm using | `ai-headroom status` |
| Off switch (VPS `ai`) | `ai-headroom off` (or comment out the `.bashrc` export) |

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
