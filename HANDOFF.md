# HANDOFF — machine configuration and minimum-touch provisioning (updated 2026-07-22)

> Read this whole file before continuing. It is written for a developer with
> ZERO prior context — every path, alias, and identifier is defined. If anything
> here would make you ask a question, the answer is somewhere below.


## Current priority: minimum-touch Windows + Ansible provisioning

### 1. What this repository is

`u2giants/ai-devops` is Albert's private, Git-backed source of truth for AI
coding-machine setup and recovery. It contains installers and managed
configuration for Claude/Codex skills, global instructions, SSH/MCP wiring,
machine memory, and the staged multi-model workflow. The companion
`C:\repos\ansible` / `u2giants/ansible` repository enforces desired state across
Windows and Ubuntu computers after a secure first connection exists.

### 2. Goal and reason for this work

Albert rejected continuing to juggle brittle one-off scripts for packages,
SSH, MCP servers, dotfiles, and skills. The goal is the fewest-touch design: one
Windows entrypoint builds the first local machine, establishes
Tailscale/OpenSSH, installs a WSL Ansible controller, retrieves secrets only
from 1Password at runtime, and enables Ansible to enforce the same state across
other computers.

### 3. Exact current state

`ai-devops` source is **committed and pushed** to `main`
([3e1d5d3](https://github.com/u2giants/ai-devops/commit/3e1d5d3)). `ansible`
source is still **uncommitted, unpushed**. Neither is **applied end-to-end**.
The main entrypoint is `bin/bootstrap-windows-dev.ps1`;
`.config/configuration.winget` declares Windows packages/settings; internal
scripts reconcile package exceptions, Tailscale/OpenSSH/WinRM, WSL/Ansible, AI
configuration, and verification. `config/916-alien.pub` contains only the
public key. The old batch/helper pair is transitional and must not receive new
behavior.

The Ansible repo has `dev_windows` and `dev_ubuntu` roles,
`playbooks/dev-computers.yml`, a static test playbook, opt-in inventory, and
`docs/dev-computers.md`. Real hosts remain commented out, secret application
defaults off, and no target was contacted.

Read-only/static evidence on 4837: every new PowerShell file parses; native
WinGet validation returned `Validation found no issues`; the Windows
direct-assertion structural test reported PASS; Ansible YAML parsed with
PyYAML; and `git diff --check` plus secret-pattern scans passed in both repos.
4837's older Pester wrapper reports zero formal cases even though the direct
assertions ran. This proves source structure, not clean-machine integration or
second-run idempotency.

### 4. What did not work and why

- WinRM HTTPS was initially configured. Literal IP listener addresses are
  invalid, its IP filter requires a range rather than CIDR, and authentication
  still needed Windows credentials instead of `916-alien`. WinRM was rejected
  in favor of SSH over Tailscale.
- `Add-WindowsCapability` appeared hung for over ten minutes installing OpenSSH
  on 4837 and remained `NotPresent` after interruption. A later/manual install
  succeeded. Windows servicing remains a live risk; fallback is Settings >
  System > Optional features.
- Ansible cannot run natively on Windows or create its own first connection.
  The local bootstrap now installs WSL Ansible and Tailscale/OpenSSH first.
- WinGet schema v3 validation failed on WinGet 1.29.280 because built-in
  resources were not discovered. Schema 0.2 validates and remains intentional.
- Pester's `-Output Detailed` was unsupported on 4837. An older-compatible
  invocation ran the direct-assertion test successfully.

### 5. Root causes and durable findings

- Minimum touch needs two layers: local bootstrap breaks the first-connection
  cycle; WinGet/DSC and Ansible enforce desired state afterward.
- Idempotent by design is not proven safe. Normal mode may update versions or
  repair owned state; a working but noncompliant setting can change.
- GitHub access, Tailscale enrollment, 1Password authorization, and possibly a
  Windows reboot are unavoidable identity/OS boundaries.
- Administrator SSH keys belong in
  `C:\ProgramData\ssh\administrators_authorized_keys` with SYSTEM and
  Administrators ACLs. SSH passwords stay off; WinRM stays disabled.
- Secrets remain in 1Password vault `vibe_coding` and runtime storage. Git may
  contain the public key and `op://` references, never private keys/tokens.

### 6. Exact next steps and gates

1. `ai-devops` is committed and pushed. `ansible` still needs review and
   commit/push (only when Albert asks). **Gate:** author is
   `Albert Hazan <u2giants@users.noreply.github.com>` and GitHub contains the
   reviewed source before a fresh machine clones it.
2. Run the README bootstrap on a disposable clean Windows 11 VM/PC. Complete
   only GitHub, Tailscale, and 1Password authentication; reboot/rerun if asked.
   **Gate:** PASS report, key-only Tailscale SSH, WinRM off, working WSL
   Ansible, and AI tools/skills/MCPs working without secret output.
3. Immediately rerun without changes. **Gate:** no unintended changes,
   duplicate blocks/keys, service/firewall churn, or failed checks. Otherwise
   restore the clean snapshot, fix source, and repeat.
4. From WSL run Galaxy installation, `ansible-lint`, syntax/static checks, and
   prove both roles on disposable Windows and Ubuntu targets. **Gate:** all
   checks exit zero and second applies have zero unintended changes.
5. Only then run `bootstrap-windows-dev.ps1 -TestOnly` on 4837. **Gate:** Albert
   reviews every difference and explicitly approves owned changes before apply.
6. Retire Dropbox launchers after proving no shortcut depends on them. **Gate:**
   GitHub + 1Password recover a new machine without another setup source.

### 7. Constraints and gotchas

- Do not trial applying mode on 4837; it is the working reference machine.
- Do not claim live success from static checks or continue after DRIFT/nonzero.
- Do not overwrite dirty repos, enable SSH passwords, broaden firewall rules,
  re-enable WinRM, manufacture Tailscale auth keys, or commit secrets.
- Ansible runs in Ubuntu/WSL, never native Windows. Real inventory stays
  commented until disposable proof succeeds.
- OpenSSH/WSL capabilities may require the Optional Features UI and/or reboot.
- Normal mode may update packages/repos; `-TestOnly` inspects established PCs.

### 8. Access and environment

- Current source machine: Windows 11 `AL8960OFC` / 4837, user
  `IML\ahazan2`, Tailscale IPv4 `<removed-protected-address>`.
- Checkouts: `C:\repos\ai-devops` and `C:\repos\ansible`; private `u2giants`
  repos, main-only under standing rules.
- 4837 has working OpenSSH over Tailscale using `916-alien`; WinRM is disabled.
- Secrets: 1Password vault `vibe_coding`, scoped runtime access only.

### 9. Open questions and risks

- Clean-machine integration and second-run behavior remain the largest risks.
- Root-first WSL Ubuntu automation can vary by OS release and is unproven.
- Package IDs/installers may change; revalidate all managers during live proof.
- Tailscale ACL policy is external; the firewall allows tailnet sources within
  `100.64.0.0/10` that Tailscale policy permits.

The older consolidation history below remains relevant. Where it calls
SSH/MCP/one-command onboarding future Phase 2/3 work, this section supersedes
it: source now exists locally, while live proof and rollout remain unfinished.

## Security incident workstream — transcript exposure (updated 2026-07-20)

### S1. What this system is and why this incident exists

`https://mon.designflow.app/` is the live Synology Monitor application. Its web
and MCP components run through Coolify on the Hetzner server (`hetz`); NAS agents
run on `edgesynology1` and `edgesynology2`. The private repository
`u2giants/ai-devops-transcripts` is mounted in this checkout as the `transcripts/`
submodule and preserves historical AI transcripts. Before it became private,
production credentials appeared in public `u2giants/synology-monitor` history
and transcript history. Making the repository private stopped new public access
but did not invalidate values that had already escaped. The intended outcome is
to inventory every exposed credential, identify its owner and consumers, rotate
each approved atomic group without downtime, prove the old value is rejected,
and request removal of unreachable secret-bearing GitHub history.

### S2. Completed and verified rotations — do not repeat

All six originally confirmed-live Synology Monitor values were rotated in three
approved atomic groups. Every replacement was created in 1Password vault
`vibe_coding` before propagation; raw values never belong in Git or this file.

1. **Edge1 NAS API secret + signing key:** updated the canonical
   `nas-monitor-secrets` item, Coolify production/preview values for
   `nas-monitor-web` and `nas-mcp`, and the Edge1 NAS agent. New bearer returned
   HTTP 200 and old bearer 401; the harmless signed check returned 200 with the
   new signing key and 403 with the old one. Both Coolify deployments and the
   NAS health check passed. The NAS env file is `root:root`, mode 600.
2. **Edge2 NAS API secret + signing key:** updated the same consumer classes and
   recreated only the Edge2 `nas-api` container. New bearer returned 200 and old
   bearer 401; new signing returned 200 and old signing 403. Albert's constrained
   manual compose command produced `SAFE CHECK PASSED: nas-api recreated; health
   HTTP 200`. Both Coolify deployments and relay health/catalog/preview passed.
3. **Relay bearer + admin secret:** updated canonical 1Password fields and the
   relay runtime. Health, authenticated catalog, and read-only preview returned
   200; the old bearer returned 401. The admin secret has no safe read-only admin
   endpoint, so it was verified by protected canonical/runtime equality and by
   proving it differed from the old value; no write was performed merely to test
   it.

Full consumer names, deployment IDs, permissions, cleanup evidence, and exact
test results are in
[`docs/security-incident-credential-rotation-2026-07.md`](docs/security-incident-credential-rotation-2026-07.md).
Direct root SSH remains disabled. The approved `916-alien` key works for NAS
users `ahazan` and `ai`; no DSM scheduled task named "Temporary Codex edge1
rotation access" ever existed or ran.

### S3. Wider transcript audit — exact current state

The audit is **open**. It scanned 1,281 transcript files. A deliberately broad
first pass produced 836 candidates and is not a verdict. Exact in-memory
comparison of 89 concealed fields across 47 scoped 1Password items found 61
current fields represented in the archive. The authoritative classification is
[`docs/transcript-leak-audit-2026-07-19.md`](docs/transcript-leak-audit-2026-07-19.md),
not the raw candidate count.

Confirmed live and exposed:

- Six MCP credentials: `designflow-mcp/devops_token`,
  `designflow-mcp/nas_token`, and the `codex`, `chatgpt`, `gemini`, and `claude`
  fields in `devops-mcp-client-tokens`. Each returned HTTP 200 to a non-mutating
  MCP initialization request.
- Current OpenAI, DeepSeek, and DashScope provider keys.
- Five historical OpenRouter keys were found: four returned HTTP 200 and one
  returned 401. The four live keys are associated by transcript context with
  Restore Wizard, Hiclaw, Synology Monitor, and Railway production, but none
  matches the current Oracle OpenRouter item in 1Password. Ownership must be
  proved before rotation.
- Three historical Google-shaped keys were found: one is still accepted and two
  are rejected. The live one does not match the current Gemini field.
- The active `1Password Service Account Token - hetzner_vps` appears exactly in
  the archive and is active. A standing rule forbids casually rotating or even
  suggesting rotation of this bootstrap credential. This is an explicit owner
  exception: Albert must decide how to reconcile that rule with confirmed
  exposure before anyone changes it.
- Current Cloudflare fields appear in the archive and back active tunnels:
  `cloudflare-tunnel-tokens/cloudflare_tunnel_token`,
  `cloudflare-tunnel-tokens/cf_gw_tunnel_token`, and
  `cf-tunnel-hetz/password`. Treat them as live pending a provider-side status
  check and rotate them only as a coordinated Cloudflare/Coolify group.

Confirmed rejected or not current: four GitHub-shaped tokens returned 401; the
Vercel candidate returned 403; two Trigger PAT candidates do not match the
current 1Password management PAT; current Anthropic and Gemini values are
present but return 401; one OpenRouter and two Google candidates are rejected;
the current `916-alien` private key does not exactly match archive private-key
material. Rejection evidence does not erase Git history; keep the Support
cleanup open.

Current vault fields present in the archive but still awaiting safe service-side
verification include ClickUp account/API/MCP and Cloudflare D1 credentials;
Coldlion ERP API; Coolify application/database passwords; DesignFlow sandbox DB,
PLM master-data API, and frontend test login; `hetz-ai-ssh` password; npm publish
token; POP CRM live login and worker Supabase service role; Recall.ai; Brevo;
Oracle current/old Supabase database URLs and passwords; Synology Monitor
Supabase database password; shared POP production service role; shared-DB preview
branch URLs/JWT/service role; and concealed fields in the
`vibe_coding-service-account` item. Supabase anonymous keys and the Logo.dev
publishable key are public-by-design and need classification, not blind
rotation. `nas-monitor-secrets/mcp_bearer_token_LEAKED_DO_NOT_USE` is an
intentional dead quarantine field. Deprecated Directus entries must be proved
unused and deleted, never reactivated.

Eleven archive files contain private-key blocks. The current `916-alien` key is
not an exact match, but the other keys still require in-memory fingerprint and
authorized-host mapping. Never write raw private keys to a report. The `popdam`
NAS SSH password remains **UNKNOWN**; do not test it by attempting a login. Find
an authoritative safe source or perform an approved precautionary reset.

Safe report copies exist on `hetz` under `/home/ai/rotation/`, owned by `ai` and
mode 600: `transcript-leak-audit.md`, `vault-exposure-inventory.json`,
`transcript-candidate-index.md`, and `rotation-completion-report.md`.
`codex-verification-report.md` and `ROTATION-HANDOFF.md` also exist there but
were previously mode 664/644; confirm whether they still need to exist and
tighten or remove them through the authorized path if they contain sensitive
metadata. Do not copy raw candidate contexts into Git.

### S4. Failed approaches and traps — do not repeat

- A database-URI metadata parser overran escaped JSON newlines and exposed
  neighboring environment text in tool output. Its temporary output
  `C:\tmp\metadata-inventory.txt` was deleted immediately and none of its
  database classifications are trusted. Compare only known item/field values in
  memory and emit identifiers/verdicts, never values or surrounding context.
- A 1Password `item_get` on an SSH-key item returned the private key plaintext
  because the field type itself is secret-bearing. Do not fetch SSH-key items
  wholesale. Use a protected operation that derives only public fingerprints.
- The broad 836-candidate scanner intentionally over-matches. Do not interpret
  that count as 836 live secrets or hand raw candidate JSON to another model.
- The first Edge2 relay replacement produced malformed environment formatting
  and a restart loop. Recovery used a protected Docker-inspect snapshot before
  promotion. Future rotations must stage `_next`, validate exact formatting,
  snapshot current runtime references, and have rollback ready.
- The first Edge2 signing check had a CRLF construction error; fixing line
  endings made the harmless signed check pass. Do not conclude a key is bad from
  an unvalidated request-construction script.
- The stale Edge2 sudo password prevented automation. Albert ran one constrained
  `docker-compose ... --force-recreate nas-api` command; do not broaden this into
  persistent root SSH or an invented DSM task.

### S5. Exact next steps — approval-gated, in this order

No additional rotations were authorized by the completed audit. Before each
wave, present Albert one atomic group, its consumers, rollback, and verification
plan, and obtain explicit approval. New values must enter 1Password first.

1. **Finish classification without mutation.** Safely verify every one of the 61
   matched current fields, identify the owners/consumers for four live
   OpenRouter keys and the one live historical Google key, derive public
   fingerprints for the 11 private-key blocks in memory, and resolve the source
   of the unknown `popdam` password without authentication probing. **Gate:**
   every field has one verdict—live, rejected, public-by-design, deprecated and
   unused, or unknown with a named owner/action—and no raw value is in a report.
2. **MCP wave.** Rotate the five `devops-mcp` client tokens as one coordinated
   group, then rotate the independent `nas-mcp` bearer. Stage replacements in
   1Password, update Coolify/server consumers, refresh each client from `op://`,
   verify non-mutating initialization, then revoke old values. **Gate:** every
   new client gets HTTP 200, every old token gets 401/403, and canonical/runtime
   protected equality passes.
3. **Billable-provider wave.** After ownership mapping, separately rotate
   OpenAI, DeepSeek, DashScope, the four live OpenRouter keys, and the live
   historical Google key at their providers. Put each replacement in a `_next`
   1Password field before updating applications, Trigger jobs, Coolify, and
   Railway; promote only after a harmless provider request. **Gate:** new keys
   work in every mapped consumer, old keys are rejected, billing/error telemetry
   is normal, and `_next`/rollback artifacts are removed.
4. **Cloudflare wave.** Map each of the three exposed fields to its tunnel and
   container, create scoped replacements, update Coolify consumers, verify all
   public routes, then revoke old tokens. **Gate:** tunnel health and every
   mapped URL pass on new values and old tokens no longer authenticate.
5. **Database/service-role wave.** Group credentials by database and consumer;
   for the shared Supabase backend, follow the `u2giants/shared-db` governance
   procedure before application changes. Rotate passwords/service roles without
   mixing unrelated databases. **Gate:** all applications pass read/write smoke
   tests appropriate to their role, old credentials are rejected, and generated
   types/contracts remain synchronized where applicable.
6. **Business-service wave.** Rotate ClickUp, Coldlion, Brevo, Recall.ai, npm,
   DesignFlow PLM/application logins, and other confirmed-live business fields
   as separate owner-aware groups. Delete unused Directus vestiges. **Gate:**
   each service's harmless API/login/publish dry-run succeeds with the new value,
   the old value is rejected or the unused integration is deleted, and consumers
   match 1Password.
7. **SSH/password cleanup.** Map private-key fingerprints to authorized hosts,
   revoke only identified compromised keys, and resolve/reset `popdam` with an
   approved recovery path. Preserve `916-alien` as the only intended key for
   `ahazan`, `root`, and `ai` where policy allows, but do not enable direct root
   SSH merely for convenience. **Gate:** authorized users connect using intended
   keys, compromised fingerprints are absent from `authorized_keys`, and no
   password guessing occurred.
8. **Bootstrap exception — DONE 2026-07-22.** Albert rotated the exposed
   1Password service-account token, and the rotation **moved to a new 1Password
   account** (`popcreations.1password.com`, off `my.1password.com`). Because the
   vault items were re-created under new UUIDs, all UUID-pinned `op://` references
   were re-pointed to name-based form (UUID kept only for the parenthesised
   Trigger PAT), the GLM ref was fixed to the `api key` field, and the token was
   re-synced into every machine-local store (`op-service-account` file, env var,
   and the literal-token MCP configs) on al8960ofc; vault backup fields refreshed.
   The new SA is read-write (Integration ID `OEO2NT4575H6XPSVHZE7AQXPZM`); an
   earlier read-only token and a since-deleted SA caused a detour (see the
   `op whoami`-decodes-locally gotcha). Runbook: `docs/onboarding-secrets.md`
   "Rotating the bootstrap service-account token"; full record:
   `op-account-migration-2026-07` memory + `docs/config-inventory.md`.

   **Per-machine rollout status (as of 2026-07-23):**
   - **al8960ofc (this Windows box)** — DONE: token re-synced into the
     `op-service-account` file, the `OP_SERVICE_ACCOUNT_TOKEN` User env var, and the
     literal-token MCP configs (`~/.claude/settings.json`, `~/.codex/config.toml`,
     Claude Desktop). **Still needs an app restart** so the MCP processes reload it.
   - **hetz / vps2 (`ai@hetz`)** — DONE 2026-07-23: its token file held the
     *deleted* SA (403); replaced with the live token, `/worksp/ai-devops` pulled,
     `bin/setup-secrets.sh` re-run, all six `op://` refs verified resolving.
   - **4837** — DONE by Albert (2026-07-23).
   - **916** — PENDING: powered off until ~2026-07-28; Albert will re-sync it when
     it is back. Follow the runbook (token file/env + `bin/setup-machine.ps1`).
   - Other Ubuntu servers (seafile, comp, backupwiz, …) — re-sync on next setup run
     if/when they use the token; not yet checked.
9. **GitHub residue.** Continue GitHub Support sensitive-data removal requests
   for unreachable `u2giants/ai-devops` history and secret-bearing
   `u2giants/synology-monitor` history. **Gate:** Support confirms removal or
   provides a documented alternative, while both repositories remain private
   where required.
10. **Close the incident only after proof.** Rerun the exact-match audit against
    current canonical fields and the historical corpus, then update both incident
    docs. **Gate:** no accepted credential remains represented in reachable
    history; every old rotated value is rejected; unknown/private-key cases are
    resolved; temporary artifacts are gone; and the final report contains only
    identifiers and evidence, never secret values.

### S6. Access, constraints, and risks

- GitHub CLI is authenticated. Remote operational access is through the existing
  authenticated tooling and SSH aliases described in §8; use Git's SSH binary on
  Windows because the PowerShell sandbox cannot capture normal OpenSSH output.
- Secrets live only in 1Password vault `vibe_coding`. Never put a value in chat,
  commands, files, Git, or reports. Use protected injection/equality checks.
- Rotation always requires Albert's explicit approval for the exact atomic
  group. Minimize Albert's work: ask him only for a browser/provider action that
  authenticated automation genuinely cannot perform, and give exact clicks.
- Production checks must be non-mutating unless a separately approved operation
  requires a write. Never perform a destructive admin action solely as a test.
- The largest risks are unidentified owners for historical provider keys,
  downtime from rotating shared consumers out of order, disabling the bootstrap
  path before a replacement exists, and treating a public identifier as a secret
  or a rejected secret as removed from history.

### S7. Incident Git/deploy state

The three Synology Monitor rotation groups are live and verified; no application
code change was required for those rotations. The audit and rotation records are
durable Markdown in this repository and are included in the 2026-07-20 closeout
commit that contains this statement (the final closeout report records its SHA).
No further credential waves have been started or deployed.

---

## ⭐ 0. RESUME HERE (2026-07-17) — finish the Codex "silent no-op" rollout to **916** (and diagnose **4837**)

> **This section is self-contained.** You can do the 916 job from this section
> alone; the rest of the file is background. A scheduled cloud reminder fires
> **Mon 2026-07-20 19:15 America/New_York** pointing you here.

### 0.1 The bug, in one paragraph (you have zero context — read this)

**Codex** is the OpenAI CLI (`codex`), used as this shop's implementation/second-
opinion engine. On these machines it hit a nasty failure: **`codex exec` silently
writes nothing while `codex --version` and `codex login status` both succeed and
exit 0.** So every "is codex ok?" check said yes while codex was actually dead. It
bit **two Windows machines two different ways**, so **do not assume a cause —
diagnose**:
- **t16:** PATH resolved `codex` through a **junction** (`…\AppData\Local\Programs\OpenAI\Codex\bin`) that Windows can't traverse to reach codex's sandbox helper (`codex-windows-sandbox-setup.exe`). Fixed by putting the **real** package bin (`%USERPROFILE%\.codex\packages\standalone\current\bin`) first on the user PATH.
- **4837:** codex was simply **too old** (`0.142.5`) to run its configured model (`gpt-5.6-terra` → error *"requires a newer version of Codex"*). Upgraded to `0.144.5`. **But it STILL fails** — see §0.5.

### 0.2 Where every machine stands RIGHT NOW (2026-07-17)

| Machine | Tailscale name / IP | Codex sandbox works? | `codex-cli` MCP wired? | Notes |
|---|---|---|---|---|
| **t16** (`albt16`, this session's box) | `albt16` / 100.96.221.71 | ✅ **YES, verified** (real `workspace-write` wrote a file, in an interactive session) | ✅ yes — Claude Desktop config now has `codex-cli` (9→10 servers). **Restart Claude Desktop to load it.** | Fully done. |
| **hetz** (Ubuntu VPS, `ssh vps`) | — | ✅ **YES, verified** via `ai-devops doctor` | ✅ yes | Fixed via Ansible (`u2giants/ansible` PR **#5** AppArmor + **#6** standalone-canonical, both merged+applied). Linux cause was different: bubblewrap blocked by `kernel.apparmor_restrict_unprivileged_userns=1`. |
| **4837** (`al8960ofc`, domain acct `iml\ahazan2`) | `al8960ofc` / <removed-protected-address> | ❌ **NO — still broken after upgrade+PATH fix.** See §0.5. | ❌ not wired | Reachable now: **SSH port 22 open**, auth with the `916-alien` key (no password). Version + PATH fixed; sandbox write is **denied** even interactively. |
| **916** (`916-alien`) | `916-alien` / <removed-protected-address> | ❓ **UNKNOWN — never checked.** As of 2026-07-16 it was **OFFLINE** (Tailscale "last seen ~1d ago"). | ❌ not wired | **This is the 916 job.** Do §0.4. |

### 0.3 What is DONE and must NOT be re-litigated

- **op_run 1Password MCP hardened → `@u2giants/1password-mcp` v2.6.0**, released to npm. (Separate but same-night workstream; full handoff in repo `u2giants/1Password-MCP` → `handoff.md`. One small open defect there: the `wsl` shell token can't execute — planned 2.6.1.)
- **`ai-devops doctor` now proves the sandbox** with a real `--sandbox workspace-write` write (`bin/ai-devops` → `check_codex_sandbox()`), instead of trusting `--version`. **Use it** — it is the honest health check. It found the hetz problem on its first run.
- **`bin/setup-machine.ps1`** (Windows) contains `Get-CodexBin` (picks the sandbox-capable bin) + a "Codex PATH" step that prepends it, and wires the `codex-cli` MCP to the **absolute** `codex.exe` + `mcp-server` (native, not the third-party `@cexll/codex-mcp-server` wrapper).
- **`bin/setup-secrets.sh`** (Ubuntu) wires `codex-cli` into `~/.claude/settings.json` and strips the raw OP token out of it.
- **Upstream is filed, not ours to fix:** [openai/codex#32655](https://github.com/openai/codex/issues/32655) (we confirmed 0.144.5 reproduces the junction bug). The 4837 write-denial (§0.5) may be a *different* upstream bug — cf. openai/codex **#26438** (`SetTokenInformation(TokenDefaultDacl) failed: 1344 — every command fails before start in workspace-write`).

### 0.4 The 916 job — exact steps (each with a "you'll know it worked when")

**Precondition:** 916 must be **powered on** (it was offline). Confirm with
`tailscale status | grep 916-alien` from any on machine → must show *not* "offline".
**Access note:** t16 will likely be **OFF** when you do this (Albert said so). The
`916-alien` SSH private key lives at `C:\Users\ahazan2\.ssh\916-alien` **on t16**,
and also in **1Password** `vibe_coding` → item **"916-alien SSH key"**. So either
work **at 916's own keyboard** (simplest, and required for the real sandbox test —
see the ⚠️ below), or SSH in from whatever machine is on using that key.

1. **Reach 916 and get a shell.** At the keyboard, or:
   `ssh -i <916-alien key> ahazan2@<removed-protected-address>` (user is likely `ahazan2`; on a
   domain box it may present as `iml\ahazan2`).
   ✅ *Worked when:* `hostname` returns the 916 host.
2. **Diagnose codex — do NOT assume t16's or 4837's cause.** Run (native PowerShell):
   - `codex --version` → is it **≥ 0.144.5**? (If older → step 3.)
   - `(Get-Command codex).Source` → does it resolve to a junction/npm shim, or the real bin?
   - `Test-Path $env:USERPROFILE\.codex\packages\standalone\current\bin\codex.exe` → is the real standalone present?
   ✅ *Worked when:* you can state which of the two causes (old version / bad PATH / both / neither) applies.
3. **If too old:** upgrade with the **official installer in NATIVE PowerShell** (the Git-Bash `codex update` path is broken — see §4):
   `$env:CODEX_NON_INTERACTIVE=1; irm https://chatgpt.com/codex/install.ps1 | iex`
   ✅ *Worked when:* `codex --version` (via the real bin) prints ≥ 0.144.5.
4. **Fix the PATH** so bare `codex` resolves to a sandbox-capable bin. Easiest is to
   run the repo script (it contains `Get-CodexBin` + the PATH step):
   `pwsh -ExecutionPolicy Bypass -File C:\repos\ai-devops\bin\setup-machine.ps1 -RepoPath C:\repos\ai-devops`
   ⚠️ **This script BLOCKS on a `Read-Host` for the 1Password token if the token
   file is missing** (`%USERPROFILE%\.config\ai-devops\op-service-account`). Check
   first. If missing and you're an AI session, **do not** hang: either pass
   `-Token <ops_… from 1Password vibe_coding>` or **skip the full script** and just
   prepend the PATH manually:
   `[Environment]::SetEnvironmentVariable("PATH", "$env:USERPROFILE\.codex\packages\standalone\current\bin;" + [Environment]::GetEnvironmentVariable("PATH","User"), "User")`
   ✅ *Worked when:* in a **new** shell, `(Get-Command codex).Source` is the
   `…\.codex\packages\standalone\current\bin\codex.exe` path.
5. **VERIFY THE SANDBOX — interactively, at 916's keyboard, NOT over SSH.** ⚠️ Codex's
   Windows sandbox manipulates logon tokens and behaves differently under an SSH
   *network* logon than an interactive desktop session; a failure over SSH is **not**
   proof of a real bug (this cost this session hours on 4837). Run:
   `codex exec --sandbox workspace-write --skip-git-repo-check "create a file called ok.txt containing OK"`
   ✅ *Worked when:* `ok.txt` actually appears in the cwd. If yes → **916 is DONE for the codex fix.**
   ❌ *If it says "workspace write operation was denied" / "Failed to write file"* → 916 has the **same deeper bug as 4837** → go to §0.5.
6. **Wire the `codex-cli` MCP** (only after step 5 is green). Running
   `setup-machine.ps1` without `-SkipDesktopMcp` does it; or verify the
   `codex-cli` entry appears in `…\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`
   pointing at the absolute `codex.exe` + `mcp-server`. **Restart Claude Desktop** after.
   ✅ *Worked when:* the config is valid JSON, `codex-cli` present, prior servers intact, backup `*.aidevops.bak` made.
7. **Record the outcome** in this §0.2 table (flip 916's row) and, if 916 also hits
   the write-denial, add its evidence to §0.5.

### 0.5 OPEN, UNSOLVED — the 4837 (and maybe 916) sandbox **write-denial**

**Symptom (reproduced by Albert INTERACTIVELY on 4837, 2026-07-17 — not an SSH
artifact):**
```
apply patch: failed
C:\Users\ahazan2\ok.txt
ERROR codex_core::tools::router: error=Exit code: 1
Failed to write file C:\Users\ahazan2\ok.txt
codex: I couldn't create `C:\Users\ahazan2\ok.txt`: the workspace write operation was denied.
```
This is **after** the version upgrade (0.144.5) and PATH fix both succeeded, so it
is a **third, distinct** failure from t16's junction and hetz's bubblewrap. **Not
yet diagnosed.** Leads for the next session (in priority order):
1. **Read the real sandbox log right after a failed run:**
   `Get-Content $env:USERPROFILE\.codex\.sandbox\sandbox.<today>.log -Tail 40`.
   On 4837 an earlier run's log showed the helper resolving fine (no "program not
   found"), so this is a **write/ACL denial**, not a missing helper.
2. **Domain-profile hypothesis:** 4837's account is **domain** (`iml\ahazan2`).
   Codex's sandbox grants write ACLs to a restricted local sandbox user on the
   workdir; that may fail when the workdir is a domain user's profile
   (`C:\Users\ahazan2`). Test by running codex from a **local, non-profile** dir
   the sandbox user can own (e.g. `C:\codex-scratch`).
3. **EDR/AV hypothesis:** corporate endpoint protection on 4837 blocking the
   sandbox helper's write. Check Windows Defender / any EDR quarantine logs around
   the run time.
4. **Upstream match:** compare the exact log error against openai/codex issues,
   especially **#26438** (TokenDefaultDacl 1344) and the Windows-sandbox family
   linked from #32655. If it matches, it's upstream — file/confirm, don't hand-hack.
⚠️ **Do NOT** "fix" this by disabling the sandbox (`--dangerously-bypass-approvals-and-sandbox`)
as a default — that removes the protection on a work machine. Diagnose it.

### 0.6 Traps this session fell into (so you don't) — see §4 for the full list

- **Presence ≠ capability.** `--version`/`login status`/exit 0 were all green while
  codex was dead. Only a real sandbox **write** proves it. Use `ai-devops doctor`.
- **An empty result is not proof a tool is broken.** Establish platform / resolved
  exe / shell / cwd / logon-type BEFORE concluding. Testing codex's sandbox over
  SSH gave false "BROKEN" readings for hours — the SSH network logon was the
  confound, not codex.
- **`find -type f` does not traverse Windows junctions** — it shows an "empty" dir
  and reads as "files missing." Use `Get-Item <dir> | Select LinkType,Target`.
- **`codex update` from Git Bash fails** (msys `tar` vs `C:` path). Use the native
  PowerShell installer (§0.4 step 3).
- **`setup-machine.ps1` needs pwsh 7** and has no `#requires`, so under Windows
  PowerShell 5.1 it dies with cryptic parse errors, not a clear message.

## 1. What this application is

`ai-devops` (GitHub `u2giants/ai-devops`, **private**) is **not** an app — it's
Albert's personal **toolkit for backing up and distributing his AI coding setup**
across his machines:

- **Machines:** 3 Windows 11 dev boxes — `916` ("916-alien"), `t16` (`albt16`,
  the usual checkout for this repo), `4837` — and Ubuntu server(s) (`hetz`,
  `seafile`, `comp`, …) where Albert also codes via the Claude/Codex CLI over SSH.
- **What it is:** Bash CLI scripts + Markdown + skill/prompt scaffolding. Installed
  per machine by `install.sh` (Ubuntu) / `bin/install-ai-devops-windows.ps1`
  (Windows) / `bin/ai-install-skills`.
- **What it already distributes:** Claude+Codex **skills**
  (`skills/claude/*`, `skills/codex/*` → `~/.claude/skills`, `~/.codex/skills`),
  **global instructions** (`templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`;
  `AGENTS-global-codex.md` → `~/.codex/AGENTS.md`), and **workflow config**
  (`config/*.env.example` → `/etc/ai-devops/`, never clobbered).
- **Size:** ~1.5 GB, almost all in `claude_chats/` (~662 MB) + `codex_chats/`
  (~398 MB) transcript archives — excluded from AI context, may contain secrets.

Read `AGENTS.md` first for the full repo picture; it's the canonical guide.

## 2. What we set out to do this session, and why

Albert felt his machine config was "scattered across a lot of places." **Goal:**
make `ai-devops` the **single hub** that configures every machine on both OSes,
and add a "sync my dotfiles" capability — WITHOUT a new tool. **Trigger:** a dflow
UI task (making a Save control a button) led to setting gcloud defaults, which led
to "can I sync this across machines?", which surfaced the scatter.

The full current-state map is [`docs/config-inventory.md`](docs/config-inventory.md);
the phased plan is [`docs/config-consolidation-proposal.md`](docs/config-consolidation-proposal.md).
This handoff is the **live state + next steps**; those docs are the reference.

## 3. Current state — what is true right now

> **2026-07-15 update (read first).** Since this section was first written, **Phase 2
> was built and pushed** on 2026-07-14 afternoon (commits `5868f19`→`26c176f`) and
> then **adopted + verified on machine `t16` on 2026-07-15**. The Phase-1-era text
> below is kept for history; the authoritative Phase-2 state is in **§3a** just under it.

### 3a. Phase 2 state (authoritative, 2026-07-15)

**Built and committed (2a/2b/2c):**
- **[`bin/setup-machine.ps1`](bin/setup-machine.ps1)** — one-script Windows onboarding:
  base tools, skills/globals, service-account **token file**
  (`~/.config/ai-devops/op-service-account`, user-only), **`mcp.env`** (`op://`
  refs), MCP **launchers**, **916-alien key** restored from 1Password, **SSH
  aliases** (`~/.ssh/ai-devops.conf`, `Include`d), Claude Desktop MCP wiring
  (`-SkipDesktopMcp` skips it), memory-sync scheduled task.
- **[`bin/setup-secrets.sh`](bin/setup-secrets.sh)** — Ubuntu secret-plumbing half.
- **[`config/mcp.env.example`](config/mcp.env.example)** + **[`config/ssh-config.template`](config/ssh-config.template)** — committed, secret-free (`op://` refs / public host data only).
- **1Password:** the `916-alien SSH key` item now exists in `vibe_coding` (added 2026-07-14).

**Adopted + VERIFIED on t16 (2026-07-15):** token installed straight from vault →
locked-down file (never materialized in the session); `mcp.env` matches repo;
secrets resolve from the token file; `~/.ssh/config` includes `ai-devops.conf`;
**`ssh vps whoami` → `root`**. Ran with `-SkipDesktopMcp`, so **t16's Claude
Desktop MCP config was deliberately NOT changed** (pending Albert's go-ahead).

**Still open in Phase 2:**
- **t16 Claude Desktop MCP migration** — held for explicit approval (it rewrites
  the live daily-driver MCP config; the script backs up to `*.aidevops.bak` first).
- **2d token rotation** — the two MCP bearers look already rotated (`designflow-mcp`
  item tagged `mcp-rotation`, updated 2026-07-14 17:20); the **Trigger PAT** looks
  NOT yet rotated (last updated 2026-07-09). Needs Albert's approval to rotate.
- **Rollout to 916, 4837, and the Ubuntu servers** — not yet done.

The rest of this file (Phase-1 history) is unchanged below.

---

**Phase 1 implementation and the first real memory push are DONE, committed,
and pushed.** Relevant commits on `main`:
- `28c44bc` — Phase 1 build (skill, gcloud helper, memory sync, docs)
- `e64c7cf` — this HANDOFF + AGENTS.md "HANDOFF present" notes
- `28d23d1` — comprehensive config-consolidation docs and handoff pass
- `c6c6ee3` — first real memory push from `916-alien` into `memory/`
- `1c7df3b` — mandatory fresh-session completeness loop added to both the Claude
  and Codex Markdown-update skills

**Files this session created/changed in ai-devops:**
| File | What |
|---|---|
| `skills/claude/sync-dotfiles/SKILL.md` | "sync my dotfiles" (Claude) — installed on t16 |
| `skills/codex/codex-sync-dotfiles/SKILL.md` | Codex twin — installed on t16 |
| `bin/ai-gcloud-dflow` | sets dflow gcloud defaults (project `lithe-breaker-323913`, region `us-east4`) |
| `bin/ai-sync-memory` | two-way memory sync w/ per-machine slug canonicalization |
| `memory/README.md`, `memory/project-map.tsv` | memory tree docs + slug overrides |
| `docs/config-inventory.md` | the full scatter map (paths, SSH aliases, MCP list, 1Password item titles) |
| `docs/config-consolidation-proposal.md` | the 3-phase plan w/ implementation detail |
| `AGENTS.md` | structure/commands/pending-work rows + HANDOFF-present notes |
| `skills/claude/session-docs-update/SKILL.md` | Claude docs updater now must reread and revise handoffs until the fresh-session completeness question passes |
| `skills/codex/codex-docs-update/SKILL.md` | Codex twin of the same mandatory revision loop |

**Verified:** `ai-gcloud-dflow --dry-run` prints the 5 correct commands;
`ai-sync-memory push --dry-run` maps this machine's 4 projects (dflow, oracle,
ansible, 1password-mcp) → `memory/<project>/`; `ai-install-skills` installed the
new skills to `~/.claude/skills` + `~/.codex/skills` without clobbering globals.

**Verified on 2026-07-14:** `memory/` now contains real project memory from
`916-alien` (commit `c6c6ee3`); the Windows installer refreshed all 16 Claude
skills and 12 Codex toolkit skills on machine `AL8960OFC`; both installed docs
skills exactly match their repository sources; both skill packages pass
`quick_validate.py`.

**NOT done (as of the Phase-1 writing; see §3a for the current Phase-2 truth):**
propagation and memory collection on every remaining machine; Phase 3. *(Phase 2
was subsequently built + verified on t16 — §3a.)*

**Script git mode note:** `bin/ai-gcloud-dflow` and `bin/ai-sync-memory` are
tracked `100644` (not `+x`). This MATCHES the existing `bin/ai-install-skills`
(Windows-authored; execution handled by `install.sh`/git-bash). Not a bug — do
not "fix" it in isolation.

### 3b. Codex PATH + `codex-cli` MCP state

> ⚠️ **Superseded by §0 (2026-07-17) for live machine status.** §0's table is the
> current truth (t16 ✅ incl. MCP; hetz ✅ fixed+verified; 4837 upgraded but
> sandbox-denied; 916 unknown/offline). The rows below are the 2026-07-16 snapshot,
> kept for the reasoning; where they disagree with §0, **§0 wins.**

Separate workstream, same consolidation goal: Codex is now set up **by these
scripts**, not by hand or by the Dropbox scripts.

| Thing | State |
|---|---|
| Codex PATH (Windows) | **Fixed on t16 only.** `bin/setup-machine.ps1` step "Codex PATH" prepends `%USERPROFILE%\.codex\packages\standalone\current\bin` (real package bin) ahead of the broken `…\Programs\OpenAI\Codex\bin` junction, then verifies with a real sandboxed write. **916 and 4837 still need the script run.** |
| `codex-cli` MCP (Windows) | Wired by `setup-machine.ps1` to the **absolute** `codex.exe` + `mcp-server`. Replaces the third-party `@cexll/codex-mcp-server` npx wrapper that was previously in-flight here. |
| `codex-cli` MCP (Ubuntu) | **DONE on hetz 2026-07-16.** `bin/setup-secrets.sh` ran clean there: `codex-cli MCP -> native mcp-server (/usr/local/bin/codex)`, all 4 op refs PASS. Verified in `~/.claude/settings.json`: `codex-cli` key, `mcp-server` arg, absolute command, `MCP_TOOL_TIMEOUT`. `mcpServers` was empty beforehand, so nothing was displaced. |
| ⚠️ **§3a "rollout to the Ubuntu servers — not yet done" was STALE** | Checked 2026-07-16: `~/.config/ai-devops/{mcp.env,op-service-account,shellrc}` all already existed on hetz and `.bashrc` already sourced the snippet — setup-secrets.sh had **already run** there. The re-run was therefore idempotent, not a first install. Don't trust that §3a line for 916/4837 either without checking. |
| hetz codex sandbox | **BROKEN, fix pending in [`u2giants/ansible` PR #5](https://github.com/u2giants/ansible/pull/5).** Different root cause from Windows: Codex's Linux sandbox uses `/usr/bin/bwrap`, and Ubuntu 24.04's `kernel.apparmor_restrict_unprivileged_userns=1` blocks unprivileged user namespaces, so `codex exec` silently writes nothing. Proven fix = an AppArmor profile scoped to bwrap (NOT the global sysctl). Host/OS layer ⇒ Ansible, never hand-applied. |
| `ai-devops doctor` | Now proves the Codex sandbox with a real `--sandbox workspace-write` write (`check_codex_sandbox`). Tested both ways: passes on a good install, fails with cause+fix on the broken junction path. |
| Upstream | Not our bug to fix. [openai/codex#32655](https://github.com/openai/codex/issues/32655) — we commented confirming 0.144.5 reproduces. |

**Verified on t16:** bare `codex` resolves to the real package bin and
`codex exec --sandbox workspace-write` writes files; the native MCP `codex` tool
was called end-to-end and wrote a file. **Not verified:** the MCP entries as seen
by a restarted Claude Desktop / Claude Code (requires an app restart), and
anything on 916 / 4837 / `hetz`.

### 3c. Skill distribution — audited 2026-07-16 (`hetz` was 4 commits stale)

Triggered by a plain question ("is a new skill automatically on all my machines?").
The answer is **no**, and the audit found real drift. Durable rules are now in
`docs/skills-usage-guide.md` ("How skills reach each machine") and the
`ai-install-skills` quirk in `AGENTS.md`; the state as of this session:

| Machine | State on 2026-07-16 |
|---|---|
| `t16` | Current with `origin/main` (`ceafd1b`, this session's last docs commit); 18 repo skills + `designflow-e2e-tester` = 19 installed, + 12 Codex skills. |
| `hetz` | **Was 4 commits behind** at `b0f368b` — skills last installed **2026-07-09**, missing `secrets-to-1password` and `sync-dotfiles` entirely. **Fixed this session:** pulled to `ceafd1b` and re-ran `ai-install-skills` as user `ai`; verified `git rev-list --count HEAD..origin/main` = 0. Now 18 repo skills + 3 orphans = 21. |
| `916`, `4837` | **Not checked, not synced — assume stale.** Nobody has verified them. To check without touching anything: compare `git -C <repo> rev-list --count HEAD..origin/main` and `ls ~/.claude/skills` against `ls skills/claude` in the repo. |

**Mechanism (verified, not assumed):** no cron entry and no systemd timer on
`hetz` touches skills; `git pull` + `bin/ai-install-skills` only ever run when a
human/session triggers them (usually via the `sync-dotfiles` skill). Adding a skill
needs **no wiring** — the installer globs `skills/claude/*/` — but a commit reaches
a machine only when that machine syncs.

**Orphan finding (`hetz`):** `/home/ai/.claude/skills` carries 3 skills that have
**never existed in this repo** — `codex-consult`, `codex-code-review`,
`codex-plan-review` (all dated 2026-07-04, predating the repo's skill tree).
`ai-install-skills` never prunes, so they survive every sync. **`codex-consult` is
broken**: its `allowed-tools` shells out to a `codex-consult` binary that is **not
on PATH**, so the skill fails the moment anything triggers it. It also overlaps
semantically with `codex-second-opinion`, so a session on `hetz` could match the
broken skill instead of the working one. The other two are unowned duplicates of
`ai-codex-review` modes.

#### The alternate path — what replaces the 3 orphans, and proof it works

Nothing is lost by deleting them: every capability has a maintained,
repo-tracked replacement. **Verified end-to-end on `hetz` (as user `ai`) on
2026-07-16** — this is the gate that had to pass before removal became a to-do.

| Orphan (machine-local, unowned) | Replacement (repo-tracked) | Verified on `hetz` |
|---|---|---|
| `codex-consult` — "ask Codex for read-only advice" | **`codex-second-opinion`** skill (installed there now). Strictly better: Claude commits to its own position first, then a rebuttal round. | ✅ Full loop ran: `codex exec -s read-only` returned an opinion (header showed `sandbox: read-only`, `model: gpt-5.6-sol`), then `codex exec resume <sid> -c sandbox_mode="read-only"` continued **the same session** (resume echoed back the identical session id) and Codex answered the rebuttal. |
| `codex-code-review` | **`ai-codex-review diff-review`** | ✅ `/usr/local/bin/ai-codex-review` present (symlink → `/worksp/ai-devops/bin/ai-codex-review`); `diff-review` listed in its modes. |
| `codex-plan-review` | **`ai-codex-review plan-review`** | ✅ Same binary; `plan-review` listed in its modes. |

Supporting facts confirmed on `hetz` at the same time: `codex` resolves to
`/usr/local/bin/codex` (→ `/opt/codex/codex`), reports `codex-cli 0.144.5`, and
`codex login status` returns **"Logged in using ChatGPT"** — so the replacement
path has working auth and is not theoretical.

**Reproduce the check before deleting** (it is cheap, ~2 small model calls, and
leaves nothing behind). Pipe a script rather than nesting quotes through
SSH→sudo→bash — nested quoting mangles the `awk` that extracts the session id
(that bit us this session; the fix is `ssh vps 'sudo -u ai -H bash -s' < script.sh`).

**Conclusion: the gate passed.** Removal is now a real to-do — see §6 step 0b.
Still pending **Albert's explicit go-ahead**, because these are files this session
did not create.

#### ✅ FIXED 2026-07-16: every `ssh vps` from Git Bash littered a `NUL` file

**Symptom:** a junk file named `NUL` (~294 bytes, containing Windows `ping`
output) keeps appearing in whatever directory you run `ssh` from — including this
repo root, where it shows up as `?? NUL` in `git status` and looks like a mystery
artifact. Delete it and it comes straight back.

**Root cause (reproduced, not guessed):** [`config/ssh-config.template`](config/ssh-config.template)
— committed in `d29af7a`, installed to `~/.ssh/ai-devops.conf`, which
`~/.ssh/config` pulls in via `Include ai-devops.conf` on line 1 — probes the
Tailscale route with:

```
Match host coolify,vps,hetzner !exec "ping -n 1 -w 800 <removed-protected-address> >NUL 2>&1"
```

`>NUL` discards output **only in cmd.exe**. Git Bash's ssh
(`C:\Program Files\Git\usr\bin\ssh.exe`) runs `Match exec` through msys `/bin/sh`,
where `NUL` is an ordinary filename — so the redirect *creates a file* instead of
discarding. Every aliased host (`vps`, `edge1/2`, `wiz`, `comp`, `seafile`,
`auth`, `vps2`) has the same line, so any of them triggers it. Verified: a clean
temp dir + one `ssh vps true` → a `NUL` file appears.

Note the machine atlas mandates Git's ssh for automation (the Windows-MCP
PowerShell sandbox can't capture SSH output — ConPTY exit 255), so the
file-creating path is the **normal** path here, not an edge case.

**The fix: the redirect was deleted outright — it was suppressing nothing.**
The premise that it silenced ping was simply wrong. **OpenSSH already sends
`Match exec` stdin/stdout/stderr to the null device and keeps only the exit
status**, so the redirect bought zero noise reduction while creating junk under
sh. Proven before changing anything: a probe containing an explicit
`echo LEAKED_STDOUT_MARKER` produced **no output at all** through ssh. Codex
independently confirmed the same, citing OpenSSH's `readconf.c` — which also
extends the guarantee to Ubuntu's portable OpenSSH, not just this Git Bash build.

Applied to [`config/ssh-config.template`](config/ssh-config.template) (all 8
probe lines) **and** to the live `~/.ssh/ai-devops.conf` on `t16`
(backup: `~/.ssh/ai-devops.conf.pre-nulfix.bak`). **Verified after the change:**
`ssh vps` connects as `root`; **no** `NUL` file appears; captured stdout is
exactly the remote command's output with no ping noise; `ssh -G edge1` still
resolves to the Tailscale IP `<removed-protected-address>`, so Tailscale-first routing is
intact. A header comment now explains why the redirect must never come back.

**Not yet applied to `916`/`4837`** — their `~/.ssh/ai-devops.conf` still has the
old redirect and will keep littering until `bin/setup-machine.ps1` re-runs there
(or the one-line `sed` below is applied):
`sed -i 's/ >NUL 2>&1"$/"/' ~/.ssh/ai-devops.conf`

#### ⚠️ Landmine this uncovered: the ping probe is Windows-only syntax

Found by the Codex second opinion, missed on the first pass, then **verified on
`hetz`**. The probe flags mean different things per OS:

| | `-n 1` | `-w 800` |
|---|---|---|
| **Windows** | one echo request | 800 **millisecond** timeout |
| **Linux** | `-n` = no reverse DNS; it takes **no** number (count is `-c`) | 800 **second** deadline |

So `ping -n 1 -w 800 <ip>` on Ubuntu does **not** probe quickly — it **hangs**
(verified: killed by a `timeout` after 12s, exit 124, no output). The correct
Linux form is `ping -n -c 1 -W 1 <ip>`.

**Currently latent, and must stay that way until fixed:** `ai-devops.conf` is
**not installed** on `hetz` (verified absent for both `root` and `ai`), so nothing
is broken today. But **"rollout to the Ubuntu servers" is pending work (§3a)** —
installing this template on Ubuntu as-is would stall **every ssh connection on
that box for up to 800 seconds** before it even chose a route. That is a
lock-yourself-out-shaped bug.

**Before any Ubuntu rollout:** have the installer emit the Linux probe form
(`ping -n -c 1 -W 1 <ip>`) rather than shipping this file verbatim. `Match exec`
has no OS conditional, so the per-OS installers are the right place to branch:
`bin/setup-machine.ps1` (Windows) and `bin/setup-secrets.sh` (Ubuntu, which does
not install any ssh config today). Do **not** "fix" it by making one line serve
both — the flags are genuinely incompatible.

**Gotcha for anyone driving `hetz` over SSH:** you land as `root`, but the repo is
`ai:ai` at `/worksp/ai-devops` and skills belong to `/home/ai/.claude/skills`. Run
`sudo -u ai -H bash -lc '…'`, or the install silently targets `/root` and git
refuses with `dubious ownership`.

**Two harmless-looking states on `hetz` that are NOT bugs — don't "fix" them:**
- `git status` in `/worksp/ai-devops` is permanently dirty with **mode-only**
  changes (`100644 → 100755`) on `bin/ai-install-skills` and
  `bin/install-ai-devops-windows.ps1`, from `install.sh` chmod'ing them on Ubuntu.
  The repo tracks these `100644` **intentionally** (see the "Script git mode note"
  above). Mode changes don't block `git pull --ff-only`. Leave them; do not commit
  the mode flip from `hetz`.
- **A machine having more skills than the repo is not automatically drift.** `t16`
  carries 19 (repo's 18 + `designflow-e2e-tester`), which is *legitimately*
  machine-local. This is the concrete reason a blind prune in `ai-install-skills`
  would be destructive. Judge orphans case by case; `hetz`'s 3 are orphans because
  they're broken and unowned, not merely because they're extra.

**Self-inflicted trap, recorded so the next session doesn't repeat it:** running
`git fetch` on `/worksp/ai-devops` **as root** (even with `-c
safe.directory=…`) writes root-owned objects into `.git/objects`, after which
every `sudo -u ai git pull` dies with `insufficient permission for adding an
object to repository database`. It happened this session (48 root-owned objects)
and was repaired with `chown -R ai:ai /worksp/ai-devops/.git`. `safe.directory`
silences the ownership *warning* but does not make root's writes `ai`-owned — the
two are unrelated. **Never run git as root in that checkout;** always
`sudo -u ai -H bash -lc '…'`.

**Unchanged by this session:** the `codex-cli` MCP is still **NOT** wired on `hetz`
(§3b) — `bin/setup-secrets.sh` has still never run there. Only skills were synced.

**Trade-off recorded:** dropping the third-party wrapper loses `changeMode`
(structured OLD/NEW patch output), `fetch-chunk`, `batch-codex` (parallel task
delegation) and `brainstorm`. All are reproducible by prompting the native `codex`
tool. If a future session needs structured patch output, this is the decision to
revisit — see AGENTS.md → Intentional quirks.

## 4. Everything we tried that did NOT work (don't repeat these)

- **Trusting `codex --version` / `codex login status` as proof Codex works.** Both
  pass, and exit 0, on a machine where **every** sandboxed write silently fails.
  This is the single most expensive mistake of 2026-07-16. Presence is not
  capability — only a real `workspace-write` write proves it (now what
  `ai-devops doctor` does).
- **Concluding "the helpers are missing" from a directory listing.** `find -type f`
  showed `…\Programs\OpenAI\Codex\bin` as empty, so the helpers looked absent. They
  were not — `find` does not traverse the **junction**. The package was complete all
  along. Use `Get-Item <dir> | Select LinkType,Target` (PowerShell) to see what a
  Windows dir really is.
- **Concluding the 1Password MCP `op_run` "env injection is broken".** It is not.
  `argv:["bash",…]` on Windows spawns **WSL** bash, and WSL does not inherit the
  injected Windows env, so vars arrive empty. Native children (cmd `%VAR%`,
  PowerShell `$env:VAR`, `node`) get them fine, and `op://` refs resolve and are
  redacted correctly. One `pwd` (→ `/mnt/c/...`) would have shown this in seconds.
- **`codex update` from Git Bash.** Fails on an msys `tar` vs `C:` path clash. Use
  the official PowerShell installer in **native** PowerShell
  (`irm https://chatgpt.com/codex/install.ps1 | iex`).
- **Backgrounding codex with `nohup … &` inside an already-backgrounded task.** The
  wrapper exits instantly, the harness reports "completed, exit 0", and codex is
  orphaned having done nothing. An exit code is not evidence work happened — check
  the working tree.
- **Trusting PowerShell 5.1's legacy `PSParser` as a syntax check.** It reported 25
  errors in `setup-machine.ps1`; the real parser reports **0**. The script is
  pwsh-7-only by design (HEAD already failed 5.1 the same way). Use
  `[System.Management.Automation.Language.Parser]::ParseFile`.
- **Guarding on `command -v python3`.** On Windows that matches the Store *stub*,
  which satisfies presence and then fails on use. `setup-secrets.sh` now probes
  `python3 -c 'import json'` instead. (Same lesson as the `--version` trap, found in
  our own code.)
- **Filing a fresh upstream issue without searching first.** The bug already had 8+
  open reports on `openai/codex`. A 9th adds noise; a comment confirming a newer
  version adds signal.

- **Verifying the dflow deploy via GLOBAL gcloud.** `gcloud builds triggers list`
  returned `[]` and `gcloud builds list` showed only stale 2024 builds → looked
  like "sandbox-albert isn't deployed via Cloud Build." **WRONG.** The
  triggers/builds are **2nd-gen REGIONAL**; you must pass
  `--project=lithe-breaker-323913 --region=us-east4`. Then triggers + live builds
  appear. This wasted real time — it's why `ai-gcloud-dflow` and the inventory doc
  exist.
- **gcloud default project was `dflow-plm`** — a stale/empty project that doesn't
  really exist. Caused "Cloud Build API not enabled." Wiped everywhere; the ONLY
  real project is `lithe-breaker-323913`.
- **Guessing the Cloud Run region from the URL** — the `-uk` in the `.run.app`
  host suggested `europe-west2`; actual region is `us-east4`. Get region from
  `gcloud run services list`, don't infer.
- **chezmoi** — investigated as the dotfiles tool, then rejected: duplicates
  ai-devops's installer machinery and would need a 1.5 GB clone as a subfolder.
  **Do not revisit it.**
- **`yarn` not on PATH** (Windows, both bash and PowerShell) — use `corepack yarn`.
- **Git initially auto-selected `albert@popcre.com` for the 2026-07-14 skill
  commit.** That violates this repo's noreply-author rule. The commit was amended
  before push, repo-local `user.name`/`user.email` were corrected, and the pushed
  commit `1c7df3b` has author `Albert Hazan
  <u2giants@users.noreply.github.com>`. Do not reintroduce the old identity.

## 5. Root causes and key findings

- **Config lives in THREE overlapping systems + gaps** (full map in
  `docs/config-inventory.md`):
  (a) **ai-devops** — skills, global instructions, workflow config, transcripts;
  (b) **Dropbox `\vibe coding\ssh keys\master_setupsshwindows.ps1`** — writes
  `~/.ssh/config` (host aliases: `coolify`/`vps`/`vps2`, `seafile`, `edge1`/`edge2`,
  `backupwiz`, `comp`, `auth`, `vpn`, …) + the `916-alien` private key;
  (c) **Dropbox `\vibe coding\…MCP servers\`** — `setup-claude-mcps.ps1` /
  `setup-codex-mcps.ps1` → MCP config (servers: ag-grid, devops-mcp, synology,
  playwright, vercel, trigger, 1password) with tokens.
  Synced by **nothing** before this session: auto-memory, gcloud defaults,
  portable Codex prefs.
- **Per-machine memory slugs differ** — same project is `C--repos-dflow` on one
  box, `D--repos-dflow` on another. `ai-sync-memory` canonicalizes (drop through
  last `repos-`; overrides in `memory/project-map.tsv`).
- **Two plaintext-secret landmines** (why naive git-sync is unsafe):
  `master_setupsshwindows.ps1` embeds the `916-alien` private key in plaintext;
  `~/.claude/settings.json` holds live tokens in plaintext (the 1Password
  service-account token, a Trigger PAT `tr_pat_…`, two MCP bearer tokens). Phase 2
  sources all secrets from 1Password instead. Those tokens were also visible in an
  archived transcript → rotate them (Phase 2d).

## 6. Exact next steps (in order, each with a verification gate)

0. **Roll the Codex fix out to the 3 remaining machines** (t16 is done; `916`,
   `4837`, and `hetz` are NOT). This is first because until it runs, `codex exec`
   on those boxes may silently do nothing.
   - **Windows (`916`, `4837`):** pull ai-devops, then run
     `bin/setup-machine.ps1 -RepoPath C:\repos\ai-devops` (pwsh 7 — the script does
     **not** parse under Windows PowerShell 5.1 and has no `#requires` to tell you
     so). It prepends the real Codex package bin to the user PATH, wires the
     `codex-cli` MCP to the absolute `codex.exe` + `mcp-server`, and self-verifies.
   - **Ubuntu (`hetz`):** pull ai-devops, run `bin/setup-secrets.sh`. Its new
     `codex-cli` step is **untested on the real server** — it was only logic-tested
     in Ubuntu 26.04 under WSL. If `codex` is not installed there, the step warns
     and skips by design.
   ✅ *Worked when:* on each machine, in a **new** terminal, `ai-devops doctor`
   prints `ok codex sandbox can write (workspace-write verified end-to-end)` — not
   merely `codex responds to --version`, which proves nothing (see §4). Then
   restart Claude Desktop / Claude Code and confirm `codex-cli` shows connected.
   ⚠️ *If doctor prints `codex sandbox CANNOT write`:* it will name the resolved
   binary and the fix; do not "fix" it by copying helpers into the shim `bin` —
   that must be redone on every Codex upgrade. Put the real package bin first on
   PATH instead.
0b. ✅ **DONE 2026-07-16 — `hetz`'s 3 orphaned skills are deleted.** Albert gave
   the go-ahead after the alternate path was verified. Removed
   `codex-consult`, `codex-code-review`, `codex-plan-review` from
   `/home/ai/.claude/skills`. **Gate passed:** the directory now holds **18**
   skills and `diff` against `skills/claude/` in the repo is **identical**;
   `codex-second-opinion` is present and working there. Nothing below needs doing
   — kept for the reasoning and for the blind-prune warning, which still stands.

   The replacement path was **verified working on `hetz` on
   2026-07-16** — the full evidence table is in **§3c → "The alternate path"**.
   Nothing was lost by removing them:
   `codex-consult` → `codex-second-opinion` (already installed there; the whole
   opinion+rebuttal loop was run end-to-end), `codex-code-review` →
   `ai-codex-review diff-review`, `codex-plan-review` → `ai-codex-review plan-review`.
   `codex-consult` is **actively broken** (calls a `codex-consult` binary that is
   not on PATH) and competes for triggers with `codex-second-opinion`, so leaving
   it is the riskier option.
   - **Run (after Albert says go):**
     ```bash
     ssh vps 'sudo -u ai rm -rf \
       /home/ai/.claude/skills/codex-consult \
       /home/ai/.claude/skills/codex-code-review \
       /home/ai/.claude/skills/codex-plan-review'
     ```
   - **Optional re-prove first** (~2 small model calls, ~1 min): re-run the §3c
     check. Pipe a script — `ssh vps 'sudo -u ai -H bash -s' < test.sh` — do not
     nest quotes.
   ✅ *Worked when:* `ssh vps 'ls /home/ai/.claude/skills | wc -l'` returns **18**,
   matching `ls skills/claude | wc -l` in the repo, and a `hetz` session asking
   "run this by codex" matches `codex-second-opinion`.
   ↩️ *Rollback:* none needed — they are unowned, untracked, and reproducible from
   nothing. If one turns out to be wanted, author it properly in `skills/claude/`
   in this repo, where `ai-install-skills` distributes it; do **not** recreate it
   machine-local, or the next audit flags it again.
   ⚠️ *Do not* "solve" this by adding a blind prune to `ai-install-skills` — it
   would also delete legitimately machine-local skills (`t16` has
   `designflow-e2e-tester`; 916 has `synology-sharesync-stuck-triage`). Any prune
   must be opt-in (`--prune`).
1. **Propagate Phase 1 to each remaining machine and collect its memory.** On
   each machine, pull ai-devops; run `./update.sh` on Ubuntu or
   `bin/install-ai-devops-windows.ps1` on Windows; run `bin/ai-sync-memory pull`,
   then `bin/ai-sync-memory push`; review and commit only new secret-free memory.
   Do not assume the old "other 4 machines" count is still exact: record each
   completed machine in this handoff as rollout proceeds.
   ✅ *Worked when:* the sync skill exists in both installed skill directories,
   `bin/ai-gcloud-dflow --dry-run` prints the five expected commands on Windows,
   machine-only memory is present on `origin/main`, and `git status` is clean.
2. **Phase 2** — 2a/2b/2c DONE (see §3a). Remaining:
   (a) **Migrate t16's Claude Desktop MCP config** — re-run
   `bin/setup-machine.ps1 -RepoPath C:\repos\ai-devops` *without* `-SkipDesktopMcp`
   (needs Albert's OK; it backs up the config first). Then fully quit + reopen
   Claude Desktop and confirm supabase, devops-mcp, synology-monitor connect.
   (b) **2d token rotation** — verify/rotate the Trigger PAT (the MCP bearers
   appear already rotated); Albert-approved, click-through.
   (c) **Roll out** to 916, 4837, Ubuntu servers.
   ✅ *Worked when:* a fresh machine is fully configured from ai-devops alone,
   secrets pulled from 1Password, `git grep` finds no token in the repo. *(Verified
   on t16 2026-07-15: `ssh vps whoami`→root, all `mcp.env` refs resolve from the
   token file, repo secret-free.)*
3. **Phase 3** — retire the Dropbox scripts (stub → point at ai-devops), one-command
   onboarding docs, track the ~5 portable `config.toml` prefs.
   ✅ *Worked when:* Dropbox is no longer a config source and this HANDOFF can be
   deleted (project complete).

## 7. Constraints and gotchas in force

- **Commit only when asked** (repo rule). Commits use noreply email
  (`u2giants@users.noreply.github.com`) + `Co-Authored-By: Claude Opus 4.8`
  trailer. This repo commits directly to `main` (no PR flow).
- **Never commit a secret.** `memory/` is secret-free by policy.
- **No chezmoi.** ai-devops is the one hub.
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`, then
  `ai-install-skills` distributes them. A local edit in `~/.claude/skills` is lost
  on next install.
- Bash `bin/` tools run via git-bash on Windows.
- **Never `git push --force` or `reset --hard`** to resolve a hub conflict —
  surface it.

## 8. Access and environment

- **GitHub:** `gh` CLI authed as `u2giants`. Repo `u2giants/ai-devops`, branch
  `main`, checkout `C:\repos\ai-devops` on Windows machine `AL8960OFC` during
  the 2026-07-14 closeout. Do not infer the marketing nickname from the hostname;
  the shared Windows atlas section covers `916`, `t16`, and `4837`.
- **gcloud:** authed as `u2giants@gmail.com`; defaulted on t16 to project
  `lithe-breaker-323913` / region `us-east4` (via `ai-gcloud-dflow`). Cloud Build
  is 2nd-gen regional — always pass `--region=us-east4`.
- **Secrets:** 1Password vault **`vibe_coding`** (scoped MCP service account) —
  NEVER the values. Item titles referenced in `docs/config-inventory.md`. This is
  the intended source for Phase 2 secret plumbing.
- **Related repo touched this session:** `designflow-frontend` (the DesignFlow PLM
  Angular app), branch `sandbox-albert`, checkout `C:\repos\dflow\designflow-frontend`.
  The Save-button UI change (`ed80a38c`) is in PR #144 → `develop`, **not merged**
  (Uma, GitHub `devopswithkube`, reviews/merges). That repo's tree is clean and
  pushed; its `AGENTS.md` now documents the gcloud deploy-verification trap.

## 9. Open questions and risks

- **Decided (2026-07-10):** memory → straight into `ai-devops/memory/` (not a
  separate repo); Phase 2 secrets from the `vibe_coding` 1Password SA (incl. SSH
  keys); Phase 1 only for now.
- **Open:** do the 2 Ubuntu servers need the full SSH alias set (Phase 2b)?
  `op` CLI vs service-account token for the 2a helper (Phase 2a)?
- **Risk — token exposure:** the plaintext tokens in `settings.json` were visible
  in this session's transcript, and transcripts archive to `claude_chats/`.
  Rotate the Trigger PAT + the two MCP bearer tokens (Phase 2d).
- **Watch — parallel sessions:** `C:\repos\dflow` was edited by parallel
  Claude/Codex sessions this session; working trees moved mid-task. Not a blocker
  here, but for multi-session work use git worktrees to avoid collisions.

---
_Mandatory completeness gate passed after rereading this handoff with the linked
docs and no reliance on chat context. Honest answer: **yes** to: "If I were to
erase this session and start a brand new one with no knowledge of what we
discussed and no context here it would be able to pick up where you left off
with ALL the relevant knowledge you have about this session and application from
handoff.md and related .md files? Nothing relevant is left out?" Failed
approaches are in §4, exact current state is in §3, and every next step in §6 has
a verification gate. Delete this file only when all three phases are complete._

### 2026-07-20 completeness audit — credential incident

After rereading this entire handoff and both incident reports without relying on
chat context, the mandatory documentation gate passes:

1. **Is `HANDOFF.md` comprehensive enough that a brand-new developer with no
   knowledge of this project and no context about what we did or what remains
   could pick up where I left off and not skip a beat? Yes.** Incident §S1
   defines the product, repositories, hosts, URL, exposure, and intended outcome;
   §S2 records completed work and proof; §S3 gives the full open inventory and
   report locations; the original machine-consolidation workstream remains fully
   documented in §§0–9. No gap was found in the final reread.
2. **Is it detailed enough that they could continue as well as I could right
   now, with all my knowledge from this session and all relevant background about
   what we are trying to accomplish? Yes.** Incident §S3 preserves counts,
   classifications, owners known and unknown, rejected values, key/password
   unknowns, and safe artifacts. §S4 preserves every material failure and why;
   §S6 preserves access, approval, secret-handling, and production constraints.
   The two linked incident reports supply deployment IDs and test evidence. No
   gap was found in the final reread.
3. **Is every single relevant detail—background, goals, intended outcome,
   current state, failed attempts, decisions, constraints, risks, exact next
   actions, and verification evidence—present for the implementing agent to
   execute flawlessly? Yes.** Incident §§S1–S7 cover each dimension explicitly;
   §S5 contains ten ordered actions and a concrete success gate for every one.
   Raw credentials and hashes are intentionally excluded as required, not
   missing. The audit is correctly marked open until all §S5 gates pass. No gap
   was found in the final reread.

---

## Shared-skill installer safety completion — 2026-07-20

### 1. What this application is

`u2giants/ai-devops` is Albert's private, main-branch toolkit for restoring and
distributing AI coding configuration across Windows development computers and
Ubuntu coding servers. It is not a hosted application. The affected components
are the Bash and PowerShell skill installers, repo-owned Claude/Codex skill
packages, machine setup guidance, and dependency-free installer tests. Skills
install into each user's `~/.claude/skills` and `~/.codex/skills` directories.

### 2. What this session set out to do, and why

The working tree contained a useful but unfinished shared-skills feature plus two
bad root-level artifacts. The goal was to make `skills/shared/` safely install
into both Claude and Codex without breaking machine-local skills, correct an
inaccurate Kimi delegation skill, preserve the new evidence-first Synology
ShareSync workflow, and make the behavior testable on both supported platforms.
Albert explicitly asked Codex and Kimi to debate the recommendations until they
agreed, then asked Codex to implement that consensus.

### 3. Current state

Implementation is complete in the feature commit containing this section on
`main`. It was built from incident-documentation commit `b446ed2`, then rebased
without conflict over concurrent memory-sync commit `c224dc3` before push.

- `bin/ai-install-skills` installs and accurately counts client-specific plus
  shared skills, fails before copying on source-name collisions, supports
  `--dry-run`, and supports recoverable `--migrate-obsolete` quarantine.
- `bin/install-ai-devops-windows.ps1` implements the same safeguards with
  `-ClaudeHome`, `-CodexHome`, `-SkillsDryRun`, and `-MigrateObsolete`.
- Default installation never moves or deletes the retired machine-local
  `synology-sharesync-stuck-triage`; it warns until the owner opts in. Opt-in
  migration is gated on the new `synology-sharesync-triage` source existing and
  moves the old directory outside the active scan root into `skills-quarantine`.
- `skills/shared/kimi-code-delegation/SKILL.md` now matches Kimi Code CLI 0.27.0
  and the current official docs: prompt mode rejects `--auto`, `-y`, and
  `--plan`, already handles regular approvals, resumes with `-c`/`-S`, and uses
  explicit read-path instructions instead of asserting headless `@path`
  injection.
- `skills/shared/synology-sharesync-triage/` contains the evidence-first workflow,
  UI metadata, and five focused references. Database row deletion remains
  approval-gated and backup-first.
- `tests/test-ai-install-skills.sh` and
  `tests/test-install-ai-devops-windows.ps1` exercise the real installers in
  temporary repositories/homes. Both passed all five groups: absent shared tree,
  dual-client install/counts, zero-change preview, Claude and Codex collision
  failure before mutation, and warn/preview/opt-in quarantine migration.
- Both skill folders passed `quick_validate.py`; Bash syntax, PowerShell parser,
  live Bash `--dry-run`, live Windows `-SkillsDryRun`, and `git diff --check`
  passed. The optional `shellcheck` binary is not installed, so no shellcheck
  result is claimed.
- The untracked duplicate `setup-ssh-windows-fixed.ps1` and junk `NUL` file were
  removed after proving nothing referenced the duplicate. The canonical
  `config/ssh-config.template` remains the only SSH alias source.
- No credentials were rotated, no external system or machine skill directory was
  changed, and no deployment was performed as part of this feature repair.

### 4. Everything tried that did not work

1. The original root `setup-ssh-windows-fixed.ps1` looked like a repaired helper
   but reintroduced `>NUL 2>&1` in every Windows OpenSSH `Match exec` probe. Git
   Bash treats `NUL` as an ordinary filename, and the existing junk `NUL` file
   contained the probe output. The duplicate was discarded; the canonical
   template already documents and fixes the root cause.
2. The original Kimi skill recommended `kimi --auto -p`, `-C`, `--thinking`, and
   `--system-prompt`. Kimi 0.27.0 rejected the permission/plan combinations and
   did not expose the latter flags. The skill was rewritten from current CLI
   help and official command/interaction documentation.
3. A first attempt to combine `kimi --plan -p` during the review failed with
   `Cannot combine --prompt with --plan`. This proved that headless planning
   requires two prompt-mode calls, which is now documented.
4. The initial PowerShell unit test used array splatting for named parameters;
   PowerShell treated values positionally and rejected `CodexHome`. It was
   corrected to hashtable splatting, after which the full suite passed.
5. PowerShell could not remove the reserved `NUL` pathname with an ordinary
   `Remove-Item`, and `apply_patch` could not treat it as a normal file. Git
   Bash removed the exact verified repo-root path successfully.
6. Full-script PowerShell `-WhatIf` was considered and rejected: partial support
   would falsely imply git pulls, tool installation, global-file writes, and
   login work were all simulated. `-SkillsDryRun` is deliberately scoped and
   skips those phases instead.

### 5. Root causes and key findings

- Shared skills were copied after client-specific skills into the same
  destination with no collision preflight, so a future duplicate name could
  silently replace client-specific behavior. Both installers now compare
  `skills/shared` against `skills/claude` and `skills/codex` before any skill
  destination mutation.
- The installer intentionally does not prune machine-local skills. Replacing the
  old Synology name in documentation would therefore leave both old and new
  triggers active on 916. The solution is warning by default plus explicit,
  recoverable quarantine—not silent deletion or general pruning.
- Kimi's current official command reference says `--prompt` cannot combine with
  `--yolo`, `--auto`, or `--plan`, and prompt mode already uses automatic
  permissions with static deny rules. The old skill's approval-stall guidance
  was backwards for 0.27.0.
- Working-copy LF/CRLF warnings were not a defect: `git diff --check` passed.
  Broad normalization was correctly avoided to keep the change minimal.

### 6. Exact next steps

1. On each target machine, pull `origin/main` and preview skill installation:
   Bash/Git Bash: `ai-install-skills --dry-run`; Windows PowerShell installer:
   `bin/install-ai-devops-windows.ps1 -RepoPath C:\repos\ai-devops -SkillsDryRun`.
   **Gate:** output reports shared counts and says no files changed.
2. On 916, preview the exact obsolete-skill quarantine by adding
   `--migrate-obsolete` or `-MigrateObsolete` to the preview command.
   **Gate:** output names only `synology-sharesync-stuck-triage`, the replacement
   source exists, and the old directory is still present after preview.
3. After Albert approves that machine-local migration, run the corresponding
   real installer with the migration flag once.
   **Gate:** the old directory exists under `skills-quarantine`, is absent from
   the active `skills` root, and `synology-sharesync-triage/SKILL.md` is installed
   for both configured clients.
4. Continue the older machine-config consolidation and credential-incident next
   steps in the main handoff sections above; this feature does not complete or
   supersede those workstreams.

### 7. Constraints and gotchas

- Never generalize `--migrate-obsolete` into automatic pruning. Unknown local
  skills belong to the machine owner.
- A quarantine destination collision is a loud error; do not overwrite the
  preserved copy.
- `-SkillsDryRun` previews only skill work by design. It is not an alias for
  whole-script `-WhatIf`.
- Kimi flags are version-sensitive; run `kimi --help` before changing the shared
  skill again and use current official documentation.
- ShareSync database repair remains destructive and requires explicit approval,
  exact-path proof, verified backups, and restart-on-failure handling.

### 8. Access and environment

- Work occurred in `C:\repos\ai-devops`, repo `u2giants/ai-devops`, branch
  `main`, with git author `Albert Hazan <u2giants@users.noreply.github.com>`.
- GitHub `origin/main` advanced from incident commit `b446ed2` to independent
  memory-sync commit `c224dc3` during implementation. The feature commit was
  rebased over it; the file sets did not overlap.
- Local Kimi Code CLI 0.27.0 was authenticated and used read-only for the design
  debate. Official docs checked: `kimi-command.html` and `interaction.html` on
  `www.kimi.com/code/docs`.
- PowerShell 7 and Git for Windows Bash ran the two test suites. No 1Password,
  NAS, VPS, Supabase, Coolify, or other production access was needed.

### 9. Open questions and risks

- Rollout to 916 is intentionally still pending because it changes a real
  machine-local skill directory and requires the explicit migration choice.
- Kimi's CLI may change; the skill is correct for verified 0.27.0/current docs,
  not guaranteed forever.
- The broader credential incident and machine-config consolidation remain open
  exactly as documented above. This feature introduced no new credential action.

### Shared-skill handoff self-audit

Passed on 2026-07-20 after rereading this section against the implementation and
test output: a fresh developer can identify the application, purpose, exact
state, failed approaches, root causes, verification evidence, remaining rollout,
access boundary, and risks without this chat. Every remaining step has a concrete
success gate, and no secret value or unexplained path is required.

Evidence-backed checklist:

1. **Could a street-newcomer continue without asking a question? Yes.** Sections
   1–3 define the toolkit, affected components, reason for the work, exact
   behavior shipped, commit relationship, and verification evidence.
2. **Could they continue as effectively as this session? Yes.** Sections 4–5
   preserve every material failure, the reasoning behind rejected approaches,
   and the non-obvious Kimi, OpenSSH, collision, and orphan-skill findings.
3. **Are failed attempts and their causes included? Yes.** Section 4 records the
   broken duplicate SSH script, invalid Kimi flags, rejected prompt/plan
   combination, PowerShell splatting failure, reserved `NUL` deletion failures,
   and rejected partial `-WhatIf` design.
4. **Is every next step concrete and verifiable? Yes.** Section 6 gives four
   ordered rollout steps; each ends with an explicit gate describing the
   expected no-change preview or installed/quarantined filesystem state.
5. **Are unfamiliar terms, identifiers, paths, and access explained? Yes.**
   Sections 1, 3, 7, and 8 define both clients' install paths, quarantine,
   repository/branch/commits, Kimi version/docs, tools used, and systems that
   were deliberately not accessed.

Final synthesis audit:

1. **Is `HANDOFF.md` comprehensive enough that a brand-new developer with no
   knowledge of this project and no context about what we did or what remains
   could pick up where I left off and not skip a beat? Yes.** Shared-skill
   sections 1–9 supply the complete standalone background, implementation state,
   failures, findings, rollout procedure, constraints, environment, and risks;
   no gap was found.
2. **Is it detailed enough that they could continue as well as I could right
   now, with all my knowledge from this session and all relevant background about
   what we are trying to accomplish? Yes.** Sections 3–6 preserve the tested
   behavior, all dead ends and design decisions, and exact next commands/gates;
   no gap was found.
3. **Is every single relevant detail—background, goals, intended outcome,
   current state, failed attempts, decisions, constraints, risks, exact next
   actions, and verification evidence—present for the implementing agent to
   execute flawlessly? Yes.** Those dimensions map respectively to sections
   1–2, 2, 3, 4, 5 and 7, 9, 6, and 3. The only unfinished activity is the
   explicitly approval-gated machine rollout; no gap was found.

---

## GLM-5.2 coding-agent integration — 2026-07-22

### 1. What this application is

`u2giants/ai-devops` is Albert's private, Git-backed toolkit for installing and
restoring a multi-model AI coding workflow on three Windows 11 computers and an
Ubuntu server named Hetz. Albert works through Claude Desktop/Claude Code and
Codex Desktop/CLI; he does not use an IDE or administer the machines manually.
The new component, `ai-glm-agent`, lets either Claude or Codex delegate work to
Z.ai GLM-5.2 while preserving the repository search, terminal, testing, editing,
and multi-step tools supplied by Claude Code. It is a local command and shared
skill, not a hosted application or production service.

### 2. What we set out to do, and why

Albert wanted GLM-5.2 as a genuine third coding agent because routing GLM through
Qwen Code was unreliable. The goal was one natural-language trigger—“ask GLM”—
with no per-machine settings to remember, no loss of coding-agent capability,
and no replacement of the existing Anthropic Claude or OpenAI Codex models. The
Z.ai Coding Plan key already existed in 1Password item `GLM z.ai API`; Albert
explicitly directed this session to find and test it before implementation.

### 3. Current state

Implementation was committed and pushed to `main` as `f6a413b`; a follow-up
installer-hardening commit containing the final state in this section follows.
No production application or shared-cloud resource was modified.

- `bin/ai-glm-agent` and `bin/ai-glm-agent.ps1` are Bash and PowerShell launchers.
  Both default to exact model `glm-5.2`, use Z.ai's Anthropic-compatible Coding
  Plan endpoint, isolate `CLAUDE_CONFIG_DIR`, clear inherited Anthropic API
  credentials and `CLAUDECODE`, use read-only Claude Code `plan` permissions for
  reviews, use `auto` only for explicitly requested implementation, disable
  session persistence, and reject any returned-model mismatch.
- `config/mcp.env.example` contains only the Z.ai `op://` reference plus the
  non-secret model and endpoint. No resolved API key was printed, written, or
  committed. Windows and Ubuntu secret setup copy this managed file.
- `skills/shared/ask-glm/` installs into both Claude and Codex and triggers on
  “ask GLM,” “run this by GLM,” GLM-5.2 review, analysis, or explicit delegation.
- `bin/setup-machine.ps1` and `bin/setup-secrets.sh` now perform a real
  `GLM_AGENT_OK` end-to-end capability probe after 1Password wiring. This proves
  the API, exact model, Claude Code agent host, and output validation rather than
  merely checking that commands exist.
- Live protected evidence on this Windows machine: both Z.ai model-list routes
  returned `glm-5.2`; a Coding Plan chat-completion request requested and
  returned `glm-5.2`; an isolated Claude Code request reported only
  `modelUsage.glm-5.2`; and GLM used repository tools to read `README.md` and
  returned its exact H1, `# AI DevOps Toolkit`.
- `tests/test-ai-glm-agent.ps1` and `.sh` passed. They prove review/implementation
  permission modes, positional prompt handling, inherited-key clearing, endpoint
  isolation, and strict fallback rejection. The real shared-skill Bash and
  PowerShell installer suites passed all five existing behavior groups. The
  skill validator, PowerShell parsers, Bash syntax checks, and `git diff --check`
  also passed.
- The pre-existing dirty `transcripts` submodule belongs to another workstream
  and was not modified or staged by this work.
- Focused rollout is complete on this Windows machine and Hetz. Both local
  Claude/Codex skill roots contain `ask-glm`; Hetz resolves
  `/usr/local/bin/ai-glm-agent`; and both machines passed exact GLM-5.2
  repository-tool probes. The remaining two Windows computers are pending.

### 4. Everything tried that did not work

1. The first Claude Code→Z.ai test returned HTTP 401 even though the same key had
   just succeeded against Z.ai's raw API. This machine already exposed an
   `ANTHROPIC_API_KEY`; Claude Code preferred it over `ANTHROPIC_AUTH_TOKEN`.
   Clearing only the process environment was insufficient because normal user
   Claude settings reintroduced provider state. The durable fix is both clearing
   inherited credentials and using a dedicated `CLAUDE_CONFIG_DIR` with only
   project/local setting sources. The next agent test succeeded.
2. The first PowerShell launcher tool-use test failed with “Prompt is empty.” A
   `ValueFromRemainingArguments` parameter without an explicit position dropped
   positional prompt text after named options. Adding `Position = 0` fixed it;
   the regression suite now covers the exact invocation.
3. The first Bash implementation used `jq` for result validation. Git Bash on
   this machine lacks `jq`, despite Ubuntu having it. The launcher was changed to
   use the Python dependency already managed on both platforms.
4. Windows exposes a broken Microsoft Store `python3` alias ahead of the working
   Python executable. Selecting by `command -v` alone chose the broken alias.
   The launcher now capability-tests `python --version`, then `python3`, instead
   of trusting path presence.
5. Windows Python emitted CRLF metadata into Bash `mapfile`; exact boolean/model
   comparisons treated `false\r` as a mismatch. The parser output is normalized
   before validation.
6. The skill validator could not decode smart quotation marks under its Windows
   code page. The shared skill now uses portable ASCII punctuation.
7. Hetz `update.sh` exposed two pre-existing Ubuntu installer gaps. `install.sh`
   duplicated old skill-copy logic and omitted `skills/shared`, then skipped
   secret refresh during non-interactive SSH despite an existing protected token
   file. The immediate rollout used `ai-install-skills` plus `setup-secrets.sh`;
   the permanent fix makes `install.sh` delegate to the canonical tested skill
   installer and treats an existing token file as sufficient for non-interactive
   secret refresh.
8. Focused Windows bootstrap verification tried to parse `op whoami` JSON, but
   that output contains both `url` and `URL`, which PowerShell treats as duplicate
   case-insensitive keys. Plain-text `SERVICE_ACCOUNT` matching verified the
   identity without ambiguous JSON parsing.
9. The first Hetz secret-refresh SSH command used Bash-style backslash escaping
   for `$(cat ...)` inside a PowerShell string. PowerShell expanded it locally
   and found no Windows `C:\home\...` path, so remote setup did not run. A
   backtick-escaped dollar sign preserved remote Bash substitution; setup and
   the GLM probe then passed.
10. The first final Hetz reconciliation found multiple Windows-only files dirty
    by mode after an otherwise successful update. `install.sh` had run
    `chmod +x bin/*` and symlinked every file, including `.ps1` and `.bat` files.
    The permanent fix commits the Bash GLM launcher as executable and links only
    files already executable in Git; it never mutates source modes at install.

### 5. Root causes and key findings

- A raw OpenAI-compatible API wrapper would provide text generation but not a
  coding-agent tool loop. Hosting GLM inside Claude Code preserves repository,
  terminal, tests, editing, and multi-step behavior with fewer moving parts.
- Provider isolation is mandatory. Merely setting `ANTHROPIC_BASE_URL` and an
  auth token can be defeated by inherited or user-setting credentials. See the
  explicit environment cleanup and config isolation in both launchers.
- Z.ai's public documentation lagged its live service: documentation listed
  GLM-5.1, while both live endpoints on 2026-07-22 listed and successfully served
  `glm-5.2`. Runtime exact-model verification is therefore the authority and
  silent fallback is forbidden.
- The Coding Plan does not use consumer OAuth. Its API key can still be
  maintenance-free for Albert because 1Password remains canonical and setup
  injects the key at runtime on every machine.

### 6. Exact next steps

1. Roll the final GitHub commit to the remaining two Windows computers through
   their normal ai-devops setup. **Gate:** each prints the live capability pass
   and both Claude and Codex respond to “ask GLM” by invoking exact GLM-5.2.
2. Forward-test the installed skill from a fresh Claude or Codex session on a
   harmless repository question. **Gate:** the parent clearly distinguishes
   GLM's answer from its own judgment and review mode leaves `git status`
   unchanged.

### 7. Constraints and gotchas

- Never put the Z.ai key in Git, Claude settings, Codex config, prompts, reports,
  command arguments, or transcripts. Only its `op://` reference belongs here.
- Never globally redirect the normal `claude` command to Z.ai. GLM variables
  belong only to the isolated child process.
- Reviews remain read-only. Use implementation mode only when Albert explicitly
  delegates editing, then independently inspect and test the diff.
- Do not accept a model fallback. A request for GLM-5.2 must return GLM-5.2 or
  fail loudly.
- Do not run the still-unproven minimum-touch Windows bootstrap on an established
  computer merely to roll out GLM.
- Production/shared-cloud access remains read-only unless Albert explicitly
  names an exact resource and mutation in the current chat.

### 8. Access and environment

- Repo: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, branch `main`.
- Current Windows machine has Claude Code 2.1.217, PowerShell 7, Git Bash,
  Python 3.14, and the 1Password MCP connector.
- Secret source: 1Password vault `vibe_coding`, item `GLM z.ai API`, concealed
  field `credential`. The protected connector resolved it only inside test
  processes; plaintext never entered model context.
- Z.ai Coding endpoint: `https://api.z.ai/api/coding/paas/v4`; Claude Code agent
  endpoint: `https://api.z.ai/api/anthropic`. The latter is the launcher route.
- Hetz was updated as user `ai` through `/worksp/ai-devops`; `setup-secrets.sh`
  printed `GLM-5.2 coding agent verified through Claude Code and Z.ai`.

### 9. Open questions and risks

- Z.ai may change Coding Plan model availability or Claude Code protocol
  compatibility. Exact-model and live capability checks are the protection;
  update the repo-owned model setting only after a verified replacement exists.
- Claude Code permission semantics can evolve. The tests assert the selected
  modes, while a live harmless tool-use test verifies real behavior.
- Remaining rollout depends on each machine having its normal ai-devops
  1Password service-account wiring and Claude Code installed. Setup fails loudly
  or warns when either prerequisite is absent.

### GLM handoff self-audit

Passed on 2026-07-22. A street-new developer can identify the system and user,
the exact objective, files and security model, verified live state, every failed
approach and root cause, concrete rollout commands/gates, constraints, access,
and remaining risks without this chat. Every next step has an observable gate;
no secret value or unexplained external dependency is required.

---

## Grok Build CLI shared skill — 2026-07-23

### 1. What this application is

`u2giants/ai-devops` is Albert's private backup-and-restore toolkit for a
multi-model coding workflow. It distributes scripts, global instructions, and
skills to Claude and Codex on Windows and Ubuntu; it is not a hosted service.
This change adds a shared `grok-cli` skill so either parent agent can locate and
safely invoke xAI's Grok Build coding CLI as an independent reviewer or,
only when explicitly authorized, an implementation agent.

### 2. What we set out to do, and why

Albert asked where Grok CLI was installed, requested a reusable skill explaining
how to find and use it, and required the implementation to be based on Grok's
documentation. The goal was to eliminate future rediscovery and prevent unsafe
assumptions about model names, permission flags, or Windows sandbox support.

### 3. Current state

- The installed command resolves to
  `C:\Users\ahazan2\.grok\bin\grok.exe`; `%USERPROFILE%\.grok\bin` is first on
  the User PATH. `grok --version` reports `0.2.111 (94172f2aa4) [stable]`.
- This is Grok's managed native install, not npm, winget, or a registered MSI.
  `~/.grok/config.toml` records `[cli] installer = "internal"`;
  `~/.grok/downloads/grok-windows-x86_64.exe` is the downloaded binary.
- Version-matched docs live at `~/.grok/README.md` and
  `~/.grok/docs/user-guide/`. The implementation was checked against getting
  started, project rules, headless mode, subagents, sessions, sandbox, plan
  mode, and permissions/safety chapters plus live command help.
- `skills/shared/grok-cli/SKILL.md` now documents executable discovery, local
  doc routing, `grok inspect`, dynamic model discovery, a deny-based read-only
  invocation, session resume, and isolated-worktree implementation.
  `agents/openai.yaml` supplies the Codex UI metadata.
- The map and inventory docs now list the new shared skill and machine-local
  `~/.grok` state. The canonical skill was installed into both
  `~/.claude/skills/grok-cli` and `~/.codex/skills/grok-cli`.
- `grok doctor` reported zero issues. `grok inspect` proved this repository is
  trusted and that project/global instructions are loaded. `grok models`
  reported the available live model rather than the skill hard-coding one.
- The skill validator and both Bash and PowerShell shared-skill installer suites
  passed. Grok itself reviewed the skill against its bundled docs and returned
  `PASS` with no factual correction.
- The feature is committed and pushed to `origin/main` as `f149c9e`.
- The pre-existing modification to `templates/system/CLAUDE-global.md` belongs
  to another workstream and was not edited or staged for this work.

### 4. Everything tried that did not work

1. The first read-only Grok review exceeded the two-minute process timeout and
   was terminated without stdout. It had created session
   `019f8f77-da68-75c1-8afb-a2bbed39822c` and made no repository change. Resuming
   that exact session with a one-turn "return findings now" instruction produced
   the complete `PASS` result in 27 seconds. This demonstrates why an exact
   session ID is safer than retrying from scratch or using ambiguous
   `--continue`.
2. A Claude-only `~/.claude/skills/grok-cli` file already appeared on the
   machine during investigation. It was not repository-owned, was absent from
   Codex, and oversimplified permission-mode behavior. The canonical
   `skills/shared/grok-cli` source replaced it through the normal dual-client
   installer.
3. Grok emitted a non-fatal automatic-worktree-GC warning that neither
   `GROK_HOME` nor the process environment's `HOME` was set. PowerShell's
   `$HOME` variable still resolved the actual install and all requested commands
   succeeded. No global environment change was justified for this skill task.

### 5. Root causes and key findings

- Grok ships its complete, version-matched documentation locally. The skill
  therefore directs agents to `~/.grok/docs/user-guide/` and live `--help`
  instead of copying a large, quickly stale command reference.
- Grok's OS sandbox guide lists Linux and macOS enforcement, not Windows.
  A Windows read-only review must not claim protection from
  `--sandbox read-only`; the tested command instead uses explicit
  `--deny Edit --deny Bash`, disables subagents, memory, and web access, and
  allows only read/search operations.
- The headless `--permission-mode` parser accepts several compatibility values,
  but the bundled permissions guide says only `default` and
  `bypassPermissions` change policy through that CLI flag. The read-only recipe
  uses `default` plus explicit denials rather than relying on `dontAsk`.
- `--worktree=<name>` must use the equals form when paired with positional
  prompting so the worktree option cannot swallow prompt text. Explicit
  implementation defaults to this isolated path and still requires independent
  diff and test verification.
- `~/.grok/auth.json` contains credentials. The skill names it only as a file
  never to read or print; no credential value entered the repository or chat.

### 6. Exact next steps

1. Roll out through the normal ai-devops installer on the remaining machines.
   **Gate:** both Claude and Codex skill roots contain `grok-cli`; where the CLI
   is installed, `grok --version`, `grok doctor`, and a harmless deny-based
   read-only prompt succeed.
2. If Grok flags change in a future release, read that machine's bundled
   headless and permissions chapters before updating the shared skill. **Gate:**
   the skill validator, both installer suites, and a Grok self-review pass.

### 7. Constraints and gotchas

- Never read, print, copy, sync, or commit `~/.grok/auth.json`.
- Never hard-code a Grok model; run `grok models`.
- Never use `--always-approve` for reviews. Use it only after explicit
  implementation delegation, preferably inside a Grok-managed worktree.
- Do not claim the Grok OS sandbox protects Windows.
- Preserve other sessions' dirty files and verify every Grok-authored diff.
- Grok may load both `AGENTS.md` and compatible Claude instruction files; use
  `grok inspect` to see the effective set before delegation.

### 8. Access and environment

- Work occurred in `C:\repos\ai-devops`, repo `u2giants/ai-devops`, branch
  `main`, using PowerShell 7 and Git for Windows Bash.
- Grok Build 0.2.111 is authenticated with grok.com through its existing local
  credential cache. No login, logout, credential rotation, 1Password access,
  cloud resource, database, NAS, VPS, or production system was used.
- Grok's home is `C:\Users\ahazan2\.grok`; repository-owned shared skills are
  installed through `bin/ai-install-skills`.

### 9. Open questions and risks

- Grok's flags and permission behavior can change with updates; bundled docs and
  live help remain the authority.
- Windows lacks the documented kernel sandbox enforcement. Explicit permission
  denials reduce the agent tool surface but are not an OS security boundary.
- The source of the transient Claude-only Grok skill was not established. It is
  no longer authoritative because the normal installer replaced it from Git.
- Automatic worktree GC's missing-environment warning remains non-fatal and was
  not expanded into a machine-configuration change without evidence of impact.

### Grok skill handoff self-audit

Passed on 2026-07-23. A developer with no chat context can identify the toolkit,
the Grok install and docs, the requested outcome, exact implemented and
installed state, the timed-out review and recovery, all safety findings,
verification evidence, remaining rollout, access boundaries, and risks. Every
next step has an observable gate, all unfamiliar paths and controls are
explained, and no credential value is required.
