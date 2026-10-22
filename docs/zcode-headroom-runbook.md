# Z-code + Headroom HTTPS lane — incident and runbook

**Date:** 2026-10-19  
**Machines:** edge-dev (Windows Z-code desktop) · hetz VPS (Headroom)  
**Status:** working; this file is the durable record and operating procedure.

Read [`headroom.md`](headroom.md) for the Claude compression proxy itself.
This file is only about the **Z-code / Z.ai** lane and why HTTPS was required.

**Addresses.** `$HEADROOM_HOST` is the hetz VPS Tailscale address. Resolve it from protected config (`ai-private-config value headroom_proxy_url` and take the host part). Concrete topology is not stored in this public repository.

---

## 1. What went wrong

### 1.1 The break

Z-code was pointed at a new Headroom instance on the hetz VPS over **plain HTTP**
(`http://$HEADROOM_HOST:8788`). Every model turn failed with:

```text
Model request failed
provider=account:zai-individual-coding-plan model=GLM-5.3
reason=unknown retryable=false
Client signing handshake requires HTTPS.
```

### 1.2 Why HTTPS is mandatory for Z-code

Z.ai client request signing (not used by Anthropic/Claude) does a signing
handshake on the provider baseURL origin:

- Handshake URL: `{baseUrl.origin}/api/paas/c1f3a7e2/v2/client`
- The client **refuses** a non-HTTPS origin unless an internal
  `allowInsecureHttp` flag is set (it is not set in the shipped client).
- Source of truth in the vendor bundle: `zcode.cjs` builds the handshake URL
  from `baseURL.origin` and throws
  `Client signing handshake requires HTTPS.` when the scheme is `http:`.

Claude’s Anthropic API has **no** such handshake. That is why the Claude lane
can use `http://$HEADROOM_HOST:8787` and Z-code cannot use HTTP at all.

### 1.3 Timeline of the bad setup (2026-10-19)

| Local time (EDT) | What happened |
|---|---|
| ~14:20 | `provider_config.json.bak-pre-headroom-20261019` saved (good baseline) |
| ~15:30 | `headroom-zcode.service` started on hetz `:8788`, `--anthropic-api-url https://api.z.ai/api/anthropic`; Z-code `provider_config.json` rewritten to `baseUrl: http://$HEADROOM_HOST:8788` |
| 15:30+ | Every Z-code turn: `Client signing handshake requires HTTPS.` |

Root cause of the product error: **HTTP baseURL + Z.ai client signing**.
Root cause of the experiment: a Headroom lane that was only designed for
Claude’s unauthenticated-HTTP posture was applied to a client that requires
TLS on its provider origin.

---

## 2. What fixed it (correct architecture)

```text
Z-code desktop (edge-dev)
  provider baseUrl = https://$HEADROOM_HOST:8443/v1
        │  TLS (private CA)
        ▼
zcode-headroom-tls.service  (hetz, $HEADROOM_HOST:8443)
  /api/paas/*  ──────────────► https://api.z.ai   (signing handshake, path kept)
  everything else ──────────► http://$HEADROOM_HOST:8788
        │
        ▼
headroom-zcode.service  (hetz, $HEADROOM_HOST:8788)
  --anthropic-api-url https://api.z.ai/api/anthropic
        │
        ▼
https://api.z.ai/api/anthropic   (real GLM-5.3)
```

Why `/v1` on the Z-code baseUrl: Z-code’s anthropic-messages client calls
`{baseUrl}/messages`. Headroom’s Anthropic route serves **`/v1/messages`**.
With `baseUrl = https://$HEADROOM_HOST:8443/v1`, the model call is
`https://$HEADROOM_HOST:8443/v1/messages`. The signing handshake still uses
**origin only**, so it stays `https://$HEADROOM_HOST:8443/api/paas/...` and is
routed straight to Z.ai.

### 2.1 Pieces that must all be true

| Piece | Value |
|---|---|
| TLS front process | `/home/ai/zcode-headroom-tls/zcode_headroom_tls.py` via `zcode-headroom-tls.service` |
| Listen | `$HEADROOM_HOST:8443` only (tailnet) — never `0.0.0.0` |
| TLS material | `/etc/ai-zcode-headroom/tls/` (`ca.crt`, `server.key`, `server-chain.crt`) |
| Chain served | `server-chain.crt` = leaf + CA |
| Compression lane | `headroom-zcode.service` → `$HEADROOM_HOST:8788`, isolated `HOME=/home/ai/.headroom-zcode-home` |
| Upstream | `--anthropic-api-url https://api.z.ai/api/anthropic` |
| Z-code config | `~/.zcode/v2/provider_config.json` → `baseUrl: https://$HEADROOM_HOST:8443/v1` |
| CA bundle on Windows | `C:\Users\<user>\.config\ai-devops\zcode-ca-bundle.crt` (**combined** — see §3.2) |
| Trust for Z-code | `ZCODE_AGENT_CA_CERT`, `AGENT_CA_CERT`, `NODE_EXTRA_CA_CERTS` = combined bundle; `~/.zcode/cli/config.json` → `network.caCertFile` = same file |
| Optional extra | CA in `Cert:\CurrentUser\Root` (`certutil -addstore -user Root`) |

### 2.2 Second failure after the first fix (TLS validation)

Once HTTPS was in place, Z-code still failed with:

```text
TLS validation failed for the provider request.
provider_code=MODEL_TLS_VALIDATION_FAILED
```

Vendor code wraps **any** error whose code contains `CERT` or `TLS` into that
message. The underlying cause was untrusted private CA on the model transport.

A second footgun appeared while fixing it: pointing `SSL_CERT_FILE` /
`REQUESTS_CA_BUNDLE` at **only** the private CA **replaces** the default
public trust store (OpenSSL replacement semantics). That broke unrelated
Z.ai HTTPS (MCP `unable to get local issuer certificate`).

**Fix:** one **combined** CA file = private CA **plus** the public root bundle
(`C:\Program Files\Git\mingw64\etc\ssl\certs\ca-bundle.crt` on edge-dev).
Point `ZCODE_AGENT_CA_CERT` / `AGENT_CA_CERT` / `network.caCertFile` /
`NODE_EXTRA_CA_CERTS` at that combined file. Do **not** set `SSL_CERT_FILE` to
the private CA alone.

---

## 3. What a future session must avoid

1. **Never give Z-code an `http://` provider baseURL.** Signing will refuse
   every turn. (`allowInsecureHttp` is not exposed in product config.)
2. **Never point `SSL_CERT_FILE` / `REQUESTS_CA_BUNDLE` at a private-CA-only
   file.** Use a combined bundle (private + public) or only additive
   `NODE_EXTRA_CA_CERTS` / `ZCODE_AGENT_CA_CERT`.
3. **Never bind Headroom or the TLS front to `0.0.0.0`.** The hetz host
   firewall is default-ACCEPT; public bind exposes the coding-plan quota
   (see [`headroom.md`](headroom.md) §3).
4. **Do not share one Headroom `HOME` / savings ledger between two proxy
   processes.** The Z-code lane uses `/home/ai/.headroom-zcode-home` for that
   reason.
5. **Do not assume Tailscale Serve or `tailscale cert` works.** This account
   cannot issue ts.net certs and Serve is not enabled. The private CA is
   required until that changes.
6. **Do not edit vendor bytes** under `C:\Program Files\ZCode`.
7. **Do not use `NODE_TLS_REJECT_UNAUTHORIZED=0`** as a fix. It disables all
   TLS verification and still is not a supported product setting.
8. **Do not “fix” Claude by copying the Z-code HTTPS design.** Claude does
   not need it and the Claude lane is a separate process, port, and switch.

---

## 4. Correct path for a future session (checklist)

### 4.1 Health check

```bash
# On any tailnet machine
curl -sS --cacert ~/.config/ai-devops/zcode-ca-bundle.crt \
  https://$HEADROOM_HOST:8443/health
# Handshake path must reach Z.ai (auth error without credentials is OK)
curl -sS --cacert ~/.config/ai-devops/zcode-ca-bundle.crt -o /dev/null -w '%{http_code}\n' \
  -X POST https://$HEADROOM_HOST:8443/api/paas/c1f3a7e2/v2/client -d '{}'
# Model path must reach Headroom then Z.ai (401 without auth is OK)
curl -sS --cacert ~/.config/ai-devops/zcode-ca-bundle.crt -o /dev/null -w '%{http_code}\n' \
  -X POST https://$HEADROOM_HOST:8443/v1/messages -H 'Content-Type: application/json' -d '{}'
```

On hetz:

```bash
systemctl is-active headroom-zcode.service zcode-headroom-tls.service
ss -lntp | grep -E '8788|8443'
```

On edge-dev (PowerShell):

```powershell
# Provider must name the HTTPS lane
(Get-Content "$env:USERPROFILE\.zcode\v2\provider_config.json" -Raw)
# Combined CA must exist and be the one Z-code is configured to use
Get-Item "$env:USERPROFILE\.config\ai-devops\zcode-ca-bundle.crt"
```

### 4.2 Rebuild the TLS front on hetz (if the host is lost)

Templates in `config/zcode-headroom/`:

- `zcode_headroom_tls.py` — stdlib HTTPS reverse proxy (path routing in §2)
- `install-zcode-headroom-tls.sh` — CA, leaf and `server-chain.crt`
  generation, key owned by the `ai` service user, systemd unit. Run it from
  the repository with `sudo HEADROOM_TAILNET_IP=<ip> HEADROOM_TAILNET_HOST=<magicdns-name> bash
  config/zcode-headroom/install-zcode-headroom-tls.sh`.

Systemd units: `headroom-zcode.service`, `zcode-headroom-tls.service` under
`/etc/systemd/system/`. Certs under `/etc/ai-zcode-headroom/tls/`.

### 4.3 Rebuild Windows trust

```powershell
# Combined bundle = private CA then public roots (Git bundle is fine)
# Private CA comes from hetz:/etc/ai-zcode-headroom/tls/ca.crt
$combined = "$env:USERPROFILE\.config\ai-devops\zcode-ca-bundle.crt"
[Environment]::SetEnvironmentVariable('ZCODE_AGENT_CA_CERT', $combined, 'User')
[Environment]::SetEnvironmentVariable('AGENT_CA_CERT', $combined, 'User')
[Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $combined, 'User')
# Do NOT set SSL_CERT_FILE / REQUESTS_CA_BUNDLE to the private CA alone
certutil -addstore -user Root "$env:USERPROFILE\.config\ai-devops\zcode-headroom-ca.crt"
# ~/.zcode/cli/config.json → network.caCertFile = $combined
# Fully quit Z-code (tray) and reopen so child processes inherit env
```

### 4.3b Per-machine trust on Linux (proven 2026-10-22, hetz VPS itself)

§4.3 is Windows-only, and the trust it builds is **per machine**. A Linux box
whose Z-code `provider_config.json` points at `https://$HEADROOM_HOST:8443/v1`
fails every model turn with `provider_code=MODEL_TLS_VALIDATION_FAILED` until
its own trust is set up. Diagnosed and fixed live on the hetz VPS
(`~/.zcode` of user `ai`), accepted by an owner chat turn through the lane:

```bash
# 1. Combined bundle = private CA first, then public roots (never private-only).
#    On a remote machine, copy ca.crt from hetz:/etc/ai-zcode-headroom/tls/ first.
mkdir -p ~/.config/ai-devops
cat /etc/ai-zcode-headroom/tls/ca.crt /etc/ssl/certs/ca-certificates.crt \
  > ~/.config/ai-devops/zcode-ca-bundle.crt

# 2. Exports ABOVE the `case $- in` non-interactive guard in ~/.bashrc —
#    SSH-launched Z-code chats run NON-interactive shells and never see
#    anything below the guard.
export ZCODE_AGENT_CA_CERT="$HOME/.config/ai-devops/zcode-ca-bundle.crt"
export AGENT_CA_CERT="$HOME/.config/ai-devops/zcode-ca-bundle.crt"
export NODE_EXTRA_CA_CERTS="$HOME/.config/ai-devops/zcode-ca-bundle.crt"

# 3. Env-independent path the app reads directly — ~/.zcode/cli/config.json:
#    { "network": { "caCertFile": "/home/<user>/.config/ai-devops/zcode-ca-bundle.crt" } }

# 4. Proofs before declaring done:
NODE_EXTRA_CA_CERTS=~/.config/ai-devops/zcode-ca-bundle.crt node -e \
  "https.get('https://$HEADROOM_HOST:8443/health',r=>{console.log('HTTP',r.statusCode);process.exit(r.statusCode===200?0:1)}).on('error',e=>{console.error(e.code);process.exit(1)})"
ssh <host> 'echo $NODE_EXTRA_CA_CERTS'   # must print the bundle path (non-interactive)
```

Acceptance is the same as §4.4: one real chat turn on that machine. The env is
inherited at process start, so any chat opened before the fix must be closed
and reopened. Do not set `SSL_CERT_FILE`/`REQUESTS_CA_BUNDLE` here either —
the §2.2 footgun is platform-independent.

### 4.4 Live proof (required before calling it done)

Send one Z-code message that completes a model turn. CLI `ai-zcode ask` may
still fail earlier on `project_token_login_failed` (separate auth path; see
§6). Desktop turn success is the acceptance test for this lane.

---

## 5. Headroom implementation review (Z-code lane)

### 5.1 What is sound

- Isolated ledger `HOME` for the Z-code proxy (avoids dual-writer corruption
  of `proxy_savings.json`).
- Tailnet-only bind on both 8788 and 8443.
- Handshake and model paths split: signing stays end-to-end to Z.ai; only
  model traffic is compressed.
- `server-chain.crt` presents leaf + CA (avoids “unable to get local issuer”
  when the client already has the CA in an extra-CA list).

### 5.2 Issues / gaps found in review

| Severity | Issue | Notes |
|---|---|---|
| Medium | TLS front is a small custom Python proxy, not an established product (no tests in `ai-devops`) | Acceptable for tailnet; needs toolkit packaging before a new machine (§7) |
| Medium | Private CA lifetime 10y / leaf 825d with no renewal job | Calendar a leaf renew before 2028-11; store a reminder |
| Low | `HEADROOM_ALLOW_UNAUTHENTICATED_BIND=1` on both Headroom units | Relaxes an internal bind guard; bind address is still tailnet-only — do not widen bind |
| Low | Claude and Z-code Headroom versions can drift if `pipx` upgrades one box | Same binary today; pin/record version on upgrade |
| Low | TLS front forwards all methods; no auth on 8443 beyond the tailnet | Consistent with 8787/8788 posture; never publish this port |
| Info | Tailscale Serve / `tailscale cert` unavailable on this account | Blocks the “no private CA” path until the Tailscale plan enables certs |

### 5.3 Headroom product note

Measured savings on the Claude lane in `cache` mode are ~2% (see
[`headroom.md`](headroom.md)). The standing rule remains: if it is not clearly
worth it, pull it. The Z-code lane should be judged the same way after real
sessions (`/home/ai/.headroom-zcode-home/.headroom/proxy_savings.json`).

---

## 6. Claude lane — will it have the same issue?

**No — not the same failure mode.**

| | Claude lane | Z-code lane |
|---|---|---|
| Client auth signing | None (API key / OAuth passthrough) | Z.ai client signing handshake |
| Scheme required | HTTP is fine | **HTTPS required** on provider origin |
| Windows switch | `ANTHROPIC_BASE_URL` user env via `ai-headroom on/off` | `provider_config.json` baseUrl |
| Port on hetz | 8787 (`headroom.service`) | 8788 + 8443 TLS front |
| Failure if proxy down | Claude errors or `ai-headroom off` escapes | Z-code errors; off-ramp in §8 |

### 6.1 Claude-specific risks (do not take Claude down)

1. **`ai-headroom off` is the escape hatch.** It clears the user
   `ANTHROPIC_BASE_URL` and restores direct Anthropic after a full Claude
   restart. Verify with `ai-headroom status`.
2. **Non-interactive `.bashrc` trap** is documented in [`headroom.md`](headroom.md) §4:
   the `ANTHROPIC_BASE_URL` export must stay **above** the `case $- in *i*)`
   guard or SSH-launched Claude silently bypasses the proxy.
3. **Do not enable HTTPS-only or client-signing experiments on 8787.**
   Claude does not need it; changing that stack risks the working path.
4. **Do not stop `headroom.service` to debug Z-code.** They are separate
   processes. Debug `headroom-zcode` / `zcode-headroom-tls` only.
5. **Proxy down behavior:** if 8787 is unreachable, new Claude sessions fail
   until `ai-headroom off` + restart. Keep that command memorized
   (`bash /c/repos/ai-devops/bin/ai-headroom off` or `ai-headroom off` from Git Bash).
6. **Windows `settings.json` env blocks do not route Claude** (measured
   2026-08-21). Only the user environment variable works. `ai-headroom`
   manages that; do not “fix” it in `settings.json`.

Claude operational health today (2026-10-19): `headroom.service` active,
bound `$HEADROOM_HOST:8787`, Windows `ANTHROPIC_BASE_URL` set, `ai-headroom
status` reports healthy. **Do not change this to solve Z-code problems.**

---

## 7. Is this in standard ai-devops tooling?

**Yes for the Windows switch and rebuild assets; VPS services are still installed from the templates on first bring-up. Default state: OFF.**

| Artifact | In `popcre/ai-devops`? | On hetz? | On edge-dev? |
|---|---|---|---|
| `ai-headroom` on/off/status (Claude) | **Yes** (`bin/ai-headroom`) | n/a | installed |
| `docs/headroom.md` (Claude) | **Yes** | n/a | yes |
| `headroom-zcode.service` | No | **Yes** | n/a |
| `ai-zcode-headroom` on/off/status (Z-code) | **Yes** (`bin/ai-zcode-headroom`) | n/a | installed |
| `zcode-headroom-tls.service` + Python front | **Yes** (templates in `config/zcode-headroom/`) | **Yes** | n/a |
| Private CA / combined bundle | No (secrets/infra) | `/etc/ai-zcode-headroom/tls/` | `~/.config/ai-devops/zcode-*.crt` |
| Z-code `provider_config.json` override | No | n/a | live user config |

**A new computer does not turn the lane on automatically.** The switch and
TLS-front templates ship with the toolkit; `headroom-zcode.service` and the
private CA are still set up by hand. Rebuild using §4.2–4.3 (Windows) and
§4.3b (Linux).

---

## 7b. `ai-zcode-headroom` vs `headroom wrap` / `unwrap zcode`

| | `ai-zcode-headroom on/off/status` (this toolkit) | `headroom wrap zcode` / `unwrap zcode` (vendor) |
|---|---|---|
| What it changes | Writes `~/.zcode/v2/provider_config.json` (durable) | Prints UI settings; **writes no Z-code config** |
| Endpoint | Hetz HTTPS lane (satisfies Z.ai signing) | Local proxy URL printed for the settings UI |
| Z.ai signing | Works (https:// baseUrl required) | Easy to mis-set http:// and hit the signing failure |
| Off switch | `off` restores direct Z.ai (no network needed) | Stops the local proxy only |
| Default after install | **OFF** | n/a (user runs wrap) |

Use the toolkit tool for the persistent lane. Use vendor `wrap` only for a
throwaway local proxy experiment.

## 7c. Claude needs no HTTPS — why

Claude talks to Anthropic with OAuth/API keys and **no client-signing
handshake**. The Claude lane is allowed to use `http://$HEADROOM_HOST:8787`
on the tailnet. Z-code is different: Z.ai signs every request and the client
refuses a non-HTTPS provider origin. Do not “fix” Claude by adding the TLS
front; do not “fix” Z-code by using HTTP.

## 8. Off-ramp — back to native Z.ai (if Headroom fails)

Use this whenever Z-code is broken and you need it working **now**.

### 8.1 Fastest path (keeps Claude on Headroom)

```text
ai-zcode-headroom off
```

Then fully quit and reopen Z-code. Equivalent manual steps if the tool is
not installed yet:

1. On edge-dev, restore Z-code to the default HTTPS Z.ai provider:

```powershell
Copy-Item "$env:USERPROFILE\.zcode\v2\provider_config.json" `
          "$env:USERPROFILE\.zcode\v2\provider_config.json.bak-headroom-$(Get-Date -Format yyyyMMdd)" -Force
Copy-Item "$env:USERPROFILE\.zcode\v2\provider_config.json.bak-pre-headroom-20261019" `
          "$env:USERPROFILE\.zcode\v2\provider_config.json" -Force
# Expected: providerRules: []  (empty = vendor default https://api.z.ai/api/anthropic)
```

2. Fully quit Z-code (tray icon → Quit) and reopen.
3. Send one Z-code message. Should work with **no** Headroom in the path.
4. Claude is untouched.

If the `bak-pre-headroom` file is missing, write a minimal config instead:

```json
{
  "schemaVersion": 1,
  "config": {
    "providerConfigRules": { "providerRules": [] },
    "modelConfigRules": { "providerModelRules": [], "manualProviderModelRules": [] },
    "defaultModelSelection": {
      "providerId": "account:zai-individual-coding-plan",
      "modelId": "GLM-5.3"
    }
  }
}
```

### 8.2 Optional — stop the Z-code Headroom processes (frees RAM)

Only after Z-code is confirmed on the native path:

```bash
ssh vps2-direct 'sudo -n systemctl stop headroom-zcode.service zcode-headroom-tls.service'
```

Leave `headroom.service` (Claude) **running**.

### 8.3 Claude off-ramp (if Headroom itself is down)

```text
ai-headroom off
```

Then fully quit and reopen Claude. Reverse with `ai-headroom on`. Details in
[`headroom.md`](headroom.md) §8.

---

## 9. MiMoCode Desktop and Headroom

**Not in the same way as Claude or Z-code, with current product surfaces.**

- Headroom speaks **Anthropic Messages** and **OpenAI-compatible** HTTP APIs
  (and Codex WebSocket). Compression is defined on those wire formats.
- MiMo Desktop is Xiaomi’s client with its own engine/provider stack. It does
  not expose `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL` style provider override
  in the way Claude or Z-code do (config surface is `mimocode.jsonc` + engine
  model settings).
- Putting MiMo behind Headroom would require either (a) MiMo gaining a
  supported “custom Anthropic/OpenAI base URL” mode, or (b) a Headroom route
  for MiMo’s actual protocol — neither exists today.
- Claude’s savings measurement was ~2% in cache mode. Even if MiMo became
  wire-compatible, the economics must be re-measured before investing.

**Conclusion:** do not wire MiMo into Headroom now. Revisit only if Headroom
gains a documented MiMo/Xiaomi provider or MiMo gains an Anthropic-compatible
base-URL override.

---

## 10. Quick reference — switches

| Goal | Action |
|---|---|
| Z-code through Headroom (current) | `provider_config.json` baseUrl `https://$HEADROOM_HOST:8443/v1` + combined CA + three env keys + restart Z-code |
| Z-code native Z.ai | restore `provider_config.json.bak-pre-headroom-20261019` (empty `providerRules`) + restart Z-code |
| Claude through Headroom | `ai-headroom on` + restart Claude |
| Claude native Anthropic | `ai-headroom off` + restart Claude |
| Health: Z-code lane | `https://$HEADROOM_HOST:8443/health` with combined CA |
| Health: Claude lane | `ai-headroom status` |
| Logs: Z-code TLS front | hetz `/home/ai/.headroom-zcode-home/.headroom/logs/tls-front.log` |
| Logs: Z-code Headroom | hetz `/home/ai/.headroom-zcode-home/.headroom/logs/proxy.log` |
| Logs: Claude Headroom | hetz `/home/ai/.headroom/logs/proxy.log` |
| Logs: Z-code client | edge-dev `~/.zcode/cli/log/zcode-YYYY-MM-DD.jsonl` |

---

## 11. Incident sign-off

Live proof 2026-10-19 (EDT): Z-code desktop turn completed through
`https://$HEADROOM_HOST:8443/v1` → `headroom-zcode` → `https://api.z.ai/api/anthropic`
after the combined-CA fix. Owner confirmed: “that worked.”

Related earlier session notes remain in the session scratchpad; this file is
the durable project record.

