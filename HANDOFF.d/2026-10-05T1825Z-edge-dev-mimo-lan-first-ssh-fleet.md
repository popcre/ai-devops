---
issue: 1302
status: OPEN
owner: mimo/lan-first-ssh-fleet
---

# LAN-first SSH fleet deploy — residual edge-alien + spare-PC recipe

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner. The only open item (issue #1302) is a mechanical redeploy when edge-alien's SSH accepts connections again; no judgement call is required.

Already settled — do NOT re-ask:
- 2026-10-05: route policy is **LAN first, Tailscale fallback** for dual-homed hosts (Albert's request this session). Cloud VPS hosts keep Tailscale → Cloudflare.
- 2026-10-05: concrete IPs live only in `u2giants/ai-devops-private-config`, never in the public repo.

## 1. What this application is

Albert's multi-model AI DevOps toolkit (`popcre/ai-devops`, public) plus protected machine topology (`u2giants/ai-devops-private-config`, private). This session is **networking/ops only**: SSH host aliases, the `916-alien` key, and known_hosts so machines can reach each other by name over LAN with Tailscale fallback. Not an application change.

Fleet (AI-devops managed hosts): `edge-dev` (this Windows box), `4837`/`al8960ofc`, `916`/`916-alien`, `edge-runn-envy`, `edge-alien`, `edge-dev3`, `edgesynology1/2`, `hetz`/`vps`/`coolify`.

## 2. What we set out to do this session, and why

Albert reported edge-dev's LAN IP changed and asked that (1) the setup hold the correct addresses, and (2) **every** managed computer resolve names **LAN first, Tailscale second**. He also asked for a short recipe to give Claude on spare PCs that need networking only, not the full toolkit.

## 3. Current state — what is true right now

**Done and verified (2026-10-05):**

| Host | LAN | Tailscale | SSH config deployed | Live SSH proved |
| --- | --- | --- | --- | --- |
| edge-dev | <private-config> | <private-config> | yes (this box) | ssh -G + self |
| 4837 | <private-config> | <private-config> | yes | `hostname` → al8960ofc |
| 916 | <private-config> | <private-config> | yes | ssh -G proved |
| edge-runn-envy | <private-config> | <private-config> | yes (created ~/.ssh/config Include) | `hostname` → edge-runn-envy |
| edge-dev3 | <private-config> | <private-config> | yes | `hostname` → edge-dev3 |
| edgesynology1 | <private-config> | <private-config> | yes (client on others) | `hostname` → edgesynology1 |
| edgesynology2 | <private-config> | <private-config> | (same template) | alias edge2 |
| hetz root + ai | — | <private-config> | yes (Include prepended both users) | ssh -G proved |
| **edge-alien** | <private-config> | **<private-config>** (was <private-config>) | **NOT deployed** | SSH port 22 times out |

**Private config commits (already on origin/main of u2giants/ai-devops-private-config):**
- `52f4314` — LAN-first template + atlas fleet map + IP refresh
- `bded77a` — `ssh/deploy-ssh-config.sh` fleet installer

Public `ai-devops` working tree was untouched (clean). IPs must stay out of it.

**Spare-PC recipe (given to Albert in chat; keep here):**
```text
Networking only — do NOT run setup-machine.ps1 or install skills/MCP/hooks.
1. Clone https://github.com/popcre/ai-devops (branch main) to C:\repos\ai-devops (Windows) or ~/repos/ai-devops (Linux/Mac).
2. Run: bin/ai-private-config sync   (needs gh auth to u2giants/ai-devops-private-config)
3. Run: bin/ai-ssh-setup
   Installs the 916-alien key from 1Password and ~/.ssh/ai-devops.conf
   (LAN first, Tailscale fallback) with "Include ai-devops.conf" first in ~/.ssh/config.
4. Merge known_hosts from: bin/ai-private-config path ssh_known_hosts
   into ~/.ssh/known_hosts (use bin/sync-ssh-known-hosts.ps1 on Windows).
5. Verify: ssh -G edge-dev prints a hostname, and ssh -o BatchMode=yes 4837 hostname works.
```

## 4. Everything we tried that did NOT work

1. **Ran `bin/ai-private-config` via bare `bash`** → WSL error ("Windows Subsystem for Linux has no installed distributions"). On this machine bare `bash` is WSL; must use `C:\Program Files\Git\bin\bash.exe`. (Same trap is already in the private atlas.)
2. **Nested-quote remote one-liners** (scp + ssh with embedded quotes) → `unexpected EOF while looking for matching`. Fixed by `ssh/deploy-ssh-config.sh` (scp template, then simple ssh checks).
3. **`sh /tmp/ensure-include.sh` on Windows remotes** → `/tmp` not shared / no such file. Windows default shell on envy is cmd.exe; paths must be `%USERPROFILE%\.ssh\...`.
4. **`grep` in ssh command on 4837** → `'grep' is not recognized` (cmd.exe). Use PowerShell or findstr on those hosts.
5. **edge-alien SCP** → `Connection timed out` on both Tailscale <private-config> and LAN <private-config>. Tailscale says the node is online; nothing accepts TCP/22 (same shape as historical t16).

## 5. Root causes and key findings

- **Route policy inversion:** Match blocks must come BEFORE Host blocks (OpenSSH takes the first value). Pattern for dual-homed hosts: `Match host X !exec "ping <LAN>"` sets `HostName <TAILSCALE>`; `Host X` has `HostName <LAN>`. Probe: `ping -c 1 -W 1 <ip> || ping.exe -n 1 -w 800 <ip>` (Linux first — see template comments about the NUL file and 800s hang).
- **HostKeyAlias** stays on the Tailscale IP (or a stable name) so known_hosts matches regardless of LAN vs Tailscale dial. edge-alien keeps `HostKeyAlias <private-config>` on purpose (historical known_hosts key) even though HostName is now <private-config>.
- **edge-dev3 LAN is <private-config>**, not the atlas's old <private-config>. **edge-alien Tailscale is <private-config>**, not <private-config>.
- **LAN is not fully bridged:** 192.168.0.x (edge-dev) cannot ping <private-config> (envy) or <private-config> (alien); 4837 (<private-config>) reaches 192.168.3.x but not edge-dev's <private-config>. The ping probe is the right per-client decider.
- **envy's LAN does not answer ICMP** even from 4837 (same subnet) — LAN-first will always fall back to Tailscale for envy unless ICMP is opened. Still correct behaviour.
- **`ssh -G`** is the cheap verify for which address a name resolves to on that client; then one real `ssh <host> hostname` for the live proof.
- Fleet installer: `u2giants/ai-devops-private-config` → `ssh/deploy-ssh-config.sh <host>`.

## 6. Exact next steps

1. When edge-alien answers on SSH (or someone at the keyboard fixes sshd / firewall):
   - `scp /c/Users/ahazan/.local/share/ai-devops-private-config/ssh/ssh-config.template edge-alien:.ssh/ai-devops.conf`
   - Ensure `Include ai-devops.conf` is first in that user's `~/.ssh/config`.
   - Verify: `ssh -G edge-dev` from edge-alien prints a hostname; `ssh -o BatchMode=yes edge-alien hostname` returns `edge-alien` (or its Windows hostname).
   - **You'll know it worked when** both checks pass and the live SSH round-trip uses the new template (e.g. `ssh -G 4837` from edge-alien shows either <private-config> or <private-config>, not a bare name).
   - Tick and close [popcre/ai-devops#1302](https://github.com/popcre/ai-devops/issues/1302).
2. Optional spare-PC work: paste the recipe in §3 to Claude on any machine that should join the fleet network without the full toolkit. Verify with the recipe's step 5.

## 7. Constraints and gotchas in force

- Concrete IPs, keys, and topology stay in `u2giants/ai-devops-private-config` only — never commit them to public `ai-devops`.
- Do not edit another session's `HANDOFF.d/` file. Root `HANDOFF.md` is a static pointer.
- Match blocks before Host blocks; never add `>NUL 2>&1` to ping probes (creates a junk `NUL` file).
- On Windows remotes the default shell may be cmd.exe; Git Bash is `C:\Program Files\Git\bin\bash.exe`, not bare `bash` (WSL).
- `-direct` aliases are Tailscale-only on purpose (simple SSH clients cannot run Match probes).
- Commits to the private config repo used `Albert Hazan <u2giants@users.noreply.github.com>` and were pushed to `main` (that repo allows it; public ai-devops does not).

## 8. Access and environment

- Machine: `edge-dev` (Windows 11), user `ahazan`, Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- GitHub: `gh` authenticated as `u2giants`.
- Private config checkout: `C:\Users\ahazan\.local\share\ai-devops-private-config` (main, clean, pushed).
- SSH key: `~/.ssh/916-alien` — restored from 1Password vault `vibe_coding`, item `916-alien SSH key` (never print the value).
- Installed SSH aliases: `~/.ssh/ai-devops.conf` (Include first in `~/.ssh/config`).
- Tailscale is up on edge-dev (`<private-config>`).

## 9. Open questions and risks

- **edge-alien SSH is dead** (2026-10-05, 1:25 PM EST): Tailscale node online, TCP/22 times out on both LAN and Tailscale. Unknown whether sshd is down, firewalled, or the host is in a weird state. Same failure shape as historical t16. Risk: it stays unreachable and keeps the old config indefinitely — tracked as #1302.
- **916 / edge-alien intermittently powered** — do not assume either is online; check `tailscale status` first.
- **HostKeyAlias <private-config> on edge-alien** is a deliberate stale-looking alias so known_hosts keeps working. If known_hosts is rebuilt from scratch, use the Tailscale IP consistently instead.
- If a future LAN renumber happens (as edge-dev's did), update `ssh/ssh-config.template` + `machines/machine-atlas.md` in the private repo and re-run `ssh/deploy-ssh-config.sh` across the fleet.

---

Self-audit (handoff-writer Mode A): all 10 sections present; §0 sweep ran (nothing needs the owner); street-newcomer has fleet table, dead ends, exact redeploy steps, constraints, and access. Checklist passes.
