# Implementation plan — Config consolidation **Phase 3**

## ⏱ STATUS (read this first) — updated 2026-07-26

| Step | State |
|---|---|
| 1–2 · Fix the `sync-dotfiles` gap (both twins) | ✅ **DONE 2026-07-26.** Both skills now check Phase 2 wiring every run (new step 2) and can no longer report success while it is absent. Stale "Dropbox scripts for now" claims removed. |
| 3 · Reinstall + prove the loop | ✅ **DONE.** Installed copies `diff` clean vs repo; drift test passed both ways (quiet when current → `RESULT: Phase 2 wiring already current`; caught a moved `mcp-launch.cmd`; restored). Shape-based token check produced **zero** false positives on this machine's three configs. |
| 4 · Commit + push Phase A | ✅ **DONE.** |
| 5 · Stub the 3 current Dropbox scripts | ✅ **DONE 2026-08-10.** Master work order supplied approval. Active files are repo pointer stubs; sensitive originals remain beside them as `.pre-phase3.bak`. |
| 6 · Dropbox credential inventory doc | ✅ **DONE 2026-08-10.** `docs/dropbox-credential-inventory.md` records counts and locations without values. |
| 7 · Rewrite `docs/restore-from-zero.md` (both OSes) | ✅ **DONE 2026-08-10.** Windows and Ubuntu single-source restore paths are explicit. |
| 8 · Portable Codex prefs template | ✅ **DONE 2026-08-10.** `config/codex-portable.toml` tracks safe new-machine defaults without hard-coding a model. Established configs are never overwritten. |
| 9 · `machine-atlas.md` + status rows | ✅ **DONE 2026-08-10.** Atlas points to repo setup and identifies al8960ofc/4837 as one machine. |

**All Phase 3 rows are complete.** Future sessions use this plan only as the
verification and decision record.

**Written:** 2026-07-26 · **Repo:** `u2giants/ai-devops` (private) · **Branch:** `main` (main-only, no branches)
**Companions — read alongside, not instead:** [`docs/config-consolidation-proposal.md`](docs/config-consolidation-proposal.md) (the 3-phase plan; Phase 3 table is §"Phase 3"), [`docs/config-inventory.md`](docs/config-inventory.md) (the scatter map), [`HANDOFF.md`](HANDOFF.md) (live machine state), [`AGENTS.md`](AGENTS.md) (canonical repo guide).

> **You are the implementer and you have no prior context.** Everything you need is
> in this file. You do **not** need to read the planning conversation, and you should
> not need to ask a single question. Where a judgment call is genuinely yours, the
> plan says so and gives the criteria.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert Hazan (business owner, POP Creations — explicitly **not** a programmer) codes
with AI sessions across five-ish computers. Today, setting up or repairing a machine
means remembering which of several places holds the real instructions: this repo, a
Dropbox folder of hand-edited PowerShell scripts, or someone's memory.

**When Phase 3 is done, three things are true that are not true today:**

1. **One place configures a machine.** `ai-devops` alone. Dropbox is no longer a
   configuration source — its scripts are inert stubs that point here.
2. **A machine can be brought to full, current state with one command** (and the
   "sync my dotfiles" phrase does the same thing), so no machine can silently sit on
   old wiring or plaintext credentials.
3. **Albert never has to wonder whether a machine is really up to date.** Whatever
   reports success has actually checked everything that matters.

**If any step below conflicts with that goal, the goal wins — stop and flag it**
rather than completing the step as written. In particular: if you find that a step
would leave a machine *reporting* success while still carrying plaintext tokens or
stale wiring, that is the exact failure this phase exists to kill. Fix the honesty
of the report first.

---

## 2. What this application is

`ai-devops` is **not an app.** It is Albert's private toolkit for backing up and
distributing his AI coding setup across machines. 100% owned Bash + PowerShell +
Markdown — no database, no container, no CI/CD. Do not go looking for them and do
not scaffold them.

- **Toolkit home on Ubuntu:** always `/worksp/ai-devops`. Never `/opt/ai-devops`.
- **Windows checkouts:** `C:\repos\ai-devops` (this machine, `al8960ofc`) and
  `D:\repos\ai-devops` on some boxes.
- **Real config** lives in `/etc/ai-devops/*.env` on Ubuntu — never in the repo.
  Only `*.env.example` belongs in git.
- **Size:** ~1.5 GB, almost all transcript archives (`claude_chats/`, `codex_chats/`,
  and the `transcripts/` submodule). Excluded from AI context; **may contain secrets**.
- **Machines:**
  - `hetz` — Hetzner VPS, Ubuntu, the production server. Reach with `ssh vps`
    (lands as `root`; the repo is `ai:ai` at `/worksp/ai-devops`, so use
    `sudo -u ai -H bash -lc '…'` or installs silently target `/root`).
  - `al8960ofc` — Windows 11 dev box, user `ahazan2` (domain `IML\ahazan2`),
    Tailscale `<removed-protected-address>`. **This box is the same machine HANDOFF sometimes
    calls "4837"** — one machine, two names. Do not chase it as two targets.
  - `t16` (`albt16`) — Windows 11 dev box.
  - `916` (`916-alien`, `<removed-protected-address>`) — Windows 11 dev box, **powered off until
    roughly 2026-07-28**.
  - Other Ubuntu servers: `seafile`, `comp`, `backupwiz`, `auth`.
- **Two client tools are configured by this repo:** Claude (Claude Code CLI, Claude
  Desktop) and Codex (OpenAI's `codex` CLI). Skills install to `~/.claude/skills`
  and `~/.codex/skills`; global instructions to `~/.claude/CLAUDE.md` and
  `~/.codex/AGENTS.md`.

### Vocabulary you will need

| Term | Meaning |
|---|---|
| **The hub** | This repo. The single source of truth for machine config. |
| **`op` / 1Password** | The `op` CLI. All secrets live in 1Password vault **`vibe_coding`** (account `popcreations.1password.com` since 2026-07-22). Vault id `pimcaogmxxzoafh7lsluj6uxkq`. |
| **Service account (SA)** | A vault-locked 1Password service account. Its token lives at `~/.config/ai-devops/op-service-account` (user-only ACL / chmod 600) and **nowhere else on disk**. It can read only `vibe_coding`. |
| **`op://` reference** | A pointer like `op://vibe_coding/<item>/<field>` — safe to commit; resolves to the secret only at runtime. |
| **`mcp.env`** | `~/.config/ai-devops/mcp.env`, installed from `config/mcp.env.example`. Contains **only** `op://` references. |
| **The launchers** | `~/.config/ai-devops/mcp-launch.cmd` + `mcp-remote-launch.cmd` (Windows) or `mcp-launch.sh` + `mcp-remote-launch.sh` (Ubuntu). Every MCP server is started through one, so secrets resolve at launch and never sit in a config file. |
| **MCP** | Model Context Protocol server — the tool integrations (supabase, devops-mcp, synology-monitor, recall-ai, trigger, 1password, playwright, ag-grid, vercel, codex-cli). |
| **The Dropbox scripts** | Hand-edited setup scripts under `C:\Dropbox\vibe coding\…`. The thing Phase 3 retires. |

---

## 3. What triggered this work

Phase 1 (2026-07-10) gave the repo a `sync-dotfiles` skill, gcloud defaults, and
memory sync. Phase 2 (built 2026-07-14, adopted on `t16` 2026-07-15 and on
`al8960ofc` 2026-07-26, `2d` closed 2026-07-26) moved SSH + MCP + secret plumbing
into the repo. **Phase 3 is the closeout** the proposal always planned: retire
Dropbox, make onboarding one command, track portable Codex prefs, refresh the atlas.

**Plus one gap found on 2026-07-26 that is not in the original Phase 3 table**, and
is the highest-value item here:

> Albert asked: *"is me saying 'sync the dotfiles' in a Claude or Codex session the
> same as running `git pull` + `setup-machine.ps1` / `setup-secrets.sh`?"*
> **It is not.** `sync-dotfiles` runs only `git pull`, `ai-sync-memory pull`,
> `ai-install-skills`, `ai-gcloud-dflow`, `ai-sync-memory push`. It does **not**
> install the token file, `mcp.env`, the launchers, token-free MCP wiring, the
> SSH aliases, the 916-alien key, the Codex PATH fix, or the memory-sync task.

**Why that is dangerous, not merely incomplete:** a machine where Albert has only
ever said "sync my dotfiles" will be told it is synced while it still has
**plaintext service-account tokens inside its MCP config files** and the pre-fix
**"storming" launcher** that re-resolved ~11 `op://` refs on every MCP start and
got the shared 1Password service account rate-limit-locked (full story:
[`docs/mcp-1password-rate-limit-hardening.md`](docs/mcp-1password-rate-limit-hardening.md)).
Both skill files said *"SSH config / MCP tokens — **NOT here yet — Phase 2** —
Dropbox scripts for now"* — true when written, false once Phase 2 shipped.

> ✅ **FIXED 2026-07-26 (commit `d592a9f`), steps 1–3.** Both twins now carry a
> mandatory step 2 that checks the wiring and installs it when missing, and the false
> claims are gone. **The background above is kept because it is the *reason* the check
> must never be weakened or made optional** — not because the bug is still live. If
> you are starting at step 5, treat §3 as history.

**Reproduce the gap (read-only, takes a minute):** open
[`skills/claude/sync-dotfiles/SKILL.md`](skills/claude/sync-dotfiles/SKILL.md) and
compare its 7-step "Procedure" against the step list printed by
[`bin/setup-machine.ps1`](bin/setup-machine.ps1). The skill never invokes
`setup-machine.ps1` or `setup-secrets.sh`. On a machine that has only ever synced:
`ls ~/.config/ai-devops/` shows no `mcp-launch.*`, and
`grep -c 'ops_' ~/.claude/settings.json` returns a hit that is a real token
(distinguish carefully — see the false-positive warning in §11).

---

## 4. Scope — in and out

### IN scope

1. **S1 — Close the `sync-dotfiles` gap.** Make the skill (both twins) actually
   bring a machine to full Phase 2 state, or refuse to claim it did.
2. **S2 — Retire the Dropbox scripts** to inert stubs pointing at the hub, and
   **inventory the credentials sitting in that Dropbox folder** (report only;
   removal/rotation is approval-gated — see §4 OUT and step 6).
3. **S3 — One-command onboarding docs**, covering Windows *and* Ubuntu, including
   the secret plumbing that `docs/restore-from-zero.md` currently omits entirely.
4. **S4 — Portable Codex prefs**: track the ~5 genuinely portable `config.toml`
   lines as a template and apply them without clobbering per-install runtime paths.
5. **S5 — Refresh `templates/system/machine-atlas.md`** so it describes the single
   path (it currently instructs "MCP servers are added via the two Dropbox
   scripts — never hand-edit configs", which now sends a session to the wrong place).
6. **S6 — Status bookkeeping**: `AGENTS.md` pending-work rows, the proposal's Phase 3
   section, and `HANDOFF.md`.

### NOT in this plan (do not let scope grow into these)

- **Ubuntu SSH alias rollout.** `bin/setup-secrets.sh` deliberately installs no SSH
  config. Open decision #3 in the proposal, and it is **booby-trapped**: the
  committed probe line `ping -n 1 -w 800 <ip>` means "1 echo, 800 ms" on Windows but
  on Linux `-n` takes no number and `-w 800` is an **800-second deadline** — shipping
  the template as-is to Ubuntu would stall every SSH connection on that box for up
  to 800 seconds. Correct Linux form is `ping -n -c 1 -W 1 <ip>`. Leave it alone here.
- **Linux cache parity.** Windows launchers have a 15-minute DPAPI cache
  (`bin/mcp-secret-launch.ps1`); the Ubuntu launchers in `bin/setup-secrets.sh` have
  `flock` single-flight but **no cache** (see `setup-secrets.sh:243`). Real asymmetry,
  deliberately deferred. Note it in docs; do not build it here.
- **Rotating or deleting any credential** found in Dropbox. Inventory and report;
  Albert decides. Rotation is approval-gated per atomic group (see `HANDOFF.md` §S5).
- **The `bootstrap-windows-dev.ps1` / Ansible minimum-touch workstream** and its
  clean-VM proof (`HANDOFF.md` §§2–7). Different workstream. Do not trial applying
  mode on a working machine to satisfy this plan.
- **chezmoi or any second sync system.** Decided against 2026-07-10; do not revisit.
- **Deleting `HANDOFF.md`.** It closes only when the whole project is done, and the
  security-incident workstream in it is still open.
- **Rolling Phase 2 out to `916`** (powered off until ~2026-07-28) or other Ubuntu
  servers. Phase 3 makes that a one-liner; performing it is separate.

---

## 5. Current state of the code

Everything below is **committed and pushed on `main`** unless stated. Latest relevant
commits: `8033ddd` (2d closed + `al8960ofc` adoption recorded), `2349f4a` (memory),
`6303b0b` (al8960ofc ≡ "4837" correction).

### Exists and works

| File | What it does | Notes for you |
|---|---|---|
| [`bin/setup-machine.ps1`](bin/setup-machine.ps1) (685 lines) | **The** Windows onboarding script: base tools, skills + globals, SA token file, `mcp.env`, both launchers, full MCP server set for Claude Code + Codex + Claude Desktop, 916-alien key, SSH aliases, Codex PATH, Kimi check, memory-sync scheduled task, Codex 1Password routing, GLM probe. | **Requires pwsh 7** and has no `#requires`, so under PowerShell 5.1 it dies with cryptic parse errors. **Blocks on `Read-Host`** for the SA token if the token file is missing — pass `-Token` or ensure the file exists. `-SkipDesktopMcp` skips the Claude Desktop rewrite. Verified end-to-end on `al8960ofc` 2026-07-26. |
| [`bin/setup-secrets.sh`](bin/setup-secrets.sh) (521 lines) | Ubuntu half: token file, `mcp.env`, managed `shellrc` sourced from `.bashrc`/`.profile`, both launchers, full MCP set merged into `~/.claude/settings.json`, legacy raw-token cleanup in `.bashrc`, PASS/FAIL verification. Has `--dry-run`, `--no-legacy`. | Installs **no** SSH config, no skills, no gcloud. Prompts for the token unless `OP_SERVICE_ACCOUNT_TOKEN` is in the env. |
| [`bin/mcp-secret-launch.ps1`](bin/mcp-secret-launch.ps1) | The shared Windows launcher: single-flight mutex + **15-minute DPAPI cache** at `~/.config/ai-devops/mcp-secrets.dpapi.json`; `Ensure-Cache` refuses to cache/start if any secret resolves EMPTY (`:34`). | **Do not regress:** never restore a per-launch `op run --env-file`; keep `CommandArgs` at `Position = 0`; keep the generated `.cmd` files passing `%*` with **no** `--` separator. |
| [`install.sh`](install.sh) | Ubuntu one-command install. Already delegates skills to `bin/ai-install-skills` (`:116`) **and calls `bin/setup-secrets.sh`** (`:137`, warns rather than failing). | So Ubuntu one-command onboarding largely exists — it is the **docs** that don't say so. |
| [`bin/bootstrap-windows-dev.ps1`](bin/bootstrap-windows-dev.ps1) | Newer Windows entrypoint; delegates to `setup-machine.ps1` (`:125`). Part of the separate minimum-touch workstream, not live-proven. | Don't make it a Phase 3 dependency. |
| [`bin/ai-install-skills`](bin/ai-install-skills), [`bin/ai-sync-memory`](bin/ai-sync-memory), [`bin/ai-gcloud-dflow`](bin/ai-gcloud-dflow) | Phase 1 tools. Skills route by folder: `skills/claude/` → Claude only, `skills/codex/` → Codex only, `skills/shared/` → **both**. | `ai-install-skills` **never prunes**, and seeds global instructions **only if absent** (prints a diff hint instead of overwriting). |
| [`config/mcp.env.example`](config/mcp.env.example) | The committed reference file — `op://` refs only. Updated 2026-07-26 to point `TRIGGER_ACCESS_TOKEN` at the **admin-level** PAT field. | |
| [`config/ssh-config.template`](config/ssh-config.template) | Managed host aliases, installed as `~/.ssh/ai-devops.conf` and `Include`d first from `~/.ssh/config`. | Windows-only probe syntax — see §4 OUT. |

### Half-done / stale — the actual work surface

| Thing | Exact state |
|---|---|
| [`skills/claude/sync-dotfiles/SKILL.md`](skills/claude/sync-dotfiles/SKILL.md) | ✅ **FIXED 2026-07-26 — do not redo steps 1–3.** Now a 9-step procedure whose **step 2** verifies the Phase 2 wiring (token file, both launchers, `mcp.env` vs repo, shape-based plaintext-token check, SSH include / shellrc), runs the per-OS installer when anything is missing, refuses to invoke it when the token file is absent, and must state the verdict. The old "Phase 1"/"Dropbox scripts for now" claims are gone. |
| [`skills/codex/codex-sync-dotfiles/SKILL.md`](skills/codex/codex-sync-dotfiles/SKILL.md) | ✅ **FIXED 2026-07-26** in the same commit, kept behaviorally identical to the Claude twin (only tool-specific wording differs). |
| [`docs/restore-from-zero.md`](docs/restore-from-zero.md) | Ubuntu-only, 8 steps, and **zero** mentions of `setup-secrets.sh`, MCP, 1Password, or Windows. Says "Secrets, tokens, SSH keys — none of these live in this repo", which is true but now incomplete: they are *restorable from 1Password by the installer*. |
| [`templates/system/machine-atlas.md`](templates/system/machine-atlas.md) | Lines ~84–86 still teach the Dropbox path as authoritative. Heading at line 57 is `## 916 ("916-alien") and t16 and 4837 — Windows 11 dev machines` — and "4837" is `al8960ofc`, the same box, which reads as a fourth machine. |
| [`AGENTS.md`](AGENTS.md) `## Pending work` (line 633) | ✅ **UPDATED 2026-07-26:** Phase 2 row = `done` with the outstanding-rollout caveat (`916`, Ubuntu beyond `hetz`); Phase 3 row now links this plan. `HANDOFF.md` header and `docs/config-consolidation-proposal.md` §Phase 3 also link it — so the plan is reachable without anyone remembering its path. |
| Codex `~/.codex/config.toml` | Portable lines 1–9 on this machine: `model = "gpt-5.6-sol"`, `model_reasoning_effort = "low"`, `sandbox_mode = "workspace-write"`, `approval_policy = "never"`, `[windows] sandbox = "elevated"`. **Not portable:** `notify = [...]` (an absolute per-install path) and dozens of `[projects.'…'] trust_level` blocks (per-machine paths). No template tracks any of this. |
| Dropbox folder | **Not yet stubbed. Contains live-shaped credentials — see §6.** |

---

## 6. Key findings and root cause

**F1 — The gap is a *documentation-of-capability* gap, not a missing feature.**
Phase 2 built the plumbing; nothing wired it to the phrase Albert actually uses. The
skill is the interface he touches, so the skill is where "fully configured" must be
enforced. Root cause: the skill was written during Phase 1 and never revised when
Phase 2 shipped — exactly the drift the skill's own step 4 exists to catch for
*global instructions*, with no equivalent for *itself*.

**F2 — Dropbox is a live credential-exposure surface, and this is bigger than the
Phase 3 table implies.** Measured 2026-07-26 by pattern-count only (no values read):

- `C:\Dropbox\vibe coding\ssh keys\916-alien` — **the 916-alien OpenSSH private key in
  plaintext**, plus a `.pub`. Three older script variants
  (`master_setupsshwindows.ps1.before headroom`, `.before refactor`,
  `.seafileDidntWork`) each embed a private-key block too. The **current**
  `master_setupsshwindows.ps1` (Jul 24) does **not** — it was already refactored.
- `C:\Dropbox\vibe coding\set up synology and VPS MCP servers in claude windows\` —
  18 files; **16 carry secret-shaped literals** (8–12 hits each), including
  `setup-claude-mcps.ps1`, `setup-codex-mcps.ps1`, a stray
  `claude_desktop_config.json`, `setup 1password on ubuntu in claude and codex.txt`,
  and nine `.bak`-style variants (`.broken`, `.expired token`, `.before 1password`,
  `worked without recall.ai`, …).

Dropbox is a **cloud-synced** folder, so these are not merely local files. This is
why S2 is not cosmetic. It also intersects the open transcript-leak workstream
(`HANDOFF.md` §S3), which already tracks the `916-alien` key as *"the current key
does not exactly match archive private-key material"* — the Dropbox copy is a
**separate** instance and must be reported, not assumed identical.

**F3 — Ubuntu one-command onboarding already works; only the docs lag.**
`install.sh:137` already calls `setup-secrets.sh`. So S3 is mostly writing down
what exists plus adding the Windows half. Do not rebuild the Ubuntu path.

**F4 — Two verification traps that have already burned sessions here.**
1. **Presence ≠ capability.** `codex --version` / `login status` / exit 0 were all
   green while `codex exec` silently wrote nothing. Only a real sandboxed **write**
   proves Codex. `bin/ai-devops doctor` does this (`check_codex_sandbox`) — use it.
2. **A grep for `ops_` in a config file produces false positives.** The string
   `op://vibe_coding/designflow-mcp/devops_token` contains `ops_`. On 2026-07-26 a
   `grep -c ops_` "found plaintext tokens" in two already-clean configs. Distinguish
   by shape, not substring — see §11 for the correct check.

**F5 — `ai-install-skills` never prunes, and a machine having *more* skills than the
repo is not automatically drift.** `t16` legitimately carries a machine-local
`designflow-e2e-tester`. `hetz` carries three genuine orphans that never existed in
this repo (`codex-consult`, `codex-code-review`, `codex-plan-review`); `codex-consult`
is **broken** (its `allowed-tools` shells out to a binary not on PATH) and overlaps
`codex-second-opinion`, so a `hetz` session can match the broken one. Replacements
are verified. Removal is a separate approval-gated to-do (`HANDOFF.md` §6 step 0b) —
**not** part of this plan.

---

## 7. Approaches considered and REJECTED

| Rejected | Why | Status |
|---|---|---|
| **chezmoi** (or any second sync system) | Would duplicate this repo's installer machinery, force every machine including servers to clone **1.5 GB** for a few KB of dotfiles, can't auto-resolve cross-machine conflicts, and would happily commit a secret. This repo already does per-machine config, both OSes, never-clobber semantics. | **Locked, decided 2026-07-10. Do not revisit.** |
| **Duplicating the Phase 2 steps inside the `sync-dotfiles` skill** (so the skill installs launchers/SSH/MCP itself) | Two implementations of the same wiring drift instantly — precisely how this gap was born. The scripts must stay the single implementation; the skill *calls* them. | **Locked.** |
| **Having the skill silently run the full setup script every time** | `setup-machine.ps1` re-checks winget packages, rewrites the **live** Claude Desktop MCP config, and runs a GLM network probe. Running all that on every "sync my dotfiles" is slow, noisy, and rewrites a daily-driver config unasked. Hence the **drift-detect first** design in step 1. | **Locked.** |
| **Deleting the Dropbox files outright in this phase** | They are the documented Phase 2 rollback path ("keep using Dropbox"), they are files this session did not create, and several hold credential material whose live/dead status is unresolved in the open incident workstream. Deleting destroys evidence and the rollback in one move. Stub the *current* scripts; **inventory** the rest and let Albert decide. | **Locked.** |
| **Rotating the credentials found in Dropbox as part of "cleanup"** | Rotation without a consumer map takes production down. `HANDOFF.md` §S5 mandates one approved atomic group at a time with staged replacement and rollback. | **Locked.** |
| **Shipping `config/ssh-config.template` to Ubuntu to finish "SSH parity"** | The `ping -n 1 -w 800` probe is Windows syntax; on Linux it is an **800-second** deadline and would stall every SSH connection on that host. Verified on `hetz` (killed by `timeout` at 12s, exit 124). | **Locked out of scope**; fix belongs in the per-OS installer when someone does Ubuntu SSH. |
| **Also fixing the missing 15-minute cache on Ubuntu launchers** | Real gap, but it is a behavioral change to the production server's secret path, needs its own verification, and Phase 3 is meant to be low-risk closeout. | Deferred, documented. |
| **Making `sync-dotfiles` reconcile global-instruction *wording*** | The skill deliberately only **appends missing rule sections** and never rewrites the local file, which carries each machine's own atlas section and hand edits. Config edits are append-only. | **Locked.** |

---

## 8. Design decisions already made

All **locked** unless marked open.

1. **The hub is `ai-devops`; Dropbox becomes inert.** (2026-07-10)
2. **Secrets are pulled from 1Password at install/launch time and never committed.**
   Repo may contain the **public** key and `op://` refs only. (2026-07-10)
3. **Never clobber machine-local values.** Same semantics as `config/*.env.example`
   → `/etc/ai-devops/`: seed if absent, never overwrite. Config edits are
   **append-only**. (2026-07-10)
4. **Portable-only sync.** Sync prefs and shared config; leave per-install runtime
   paths alone. This is why Codex `notify` and `[projects.*]` blocks stay untracked.
5. **Idempotent + `--dry-run` on every new script.** (2026-07-10)
6. **The skill calls the scripts; it does not reimplement them.** (2026-07-26, this plan)
7. **`sync-dotfiles` must never report success while Phase 2 wiring is absent.**
   Either it fixes the machine or it says loudly what is missing and how to fix it.
   Silence is the failure mode being eliminated. (2026-07-26, this plan)
8. **New skills go in `skills/shared/` by default** (installs to BOTH clients). A
   name may live in `shared/` **or** a client tree, never both — the installer fails
   closed on the collision. `sync-dotfiles` is an existing **split pair**
   (`skills/claude/sync-dotfiles` + `skills/codex/codex-sync-dotfiles`); **keep the
   split** — merging them into `shared/` is a rename that would break the Codex
   trigger name and is not this plan's job.
9. **OPEN (your judgment, criteria given):** whether the drift-detect step in the
   skill should offer to run the setup script *automatically* or always ask Albert
   first. Criteria: if the machine has **plaintext tokens or a missing launcher**,
   that is a security/regression condition — run it (after confirming the token file
   exists). If the only drift is cosmetic (e.g. a scheduled task missing), report and
   let him choose. When in doubt, ask; he prefers "recommend one and do it" over a
   menu, but never a surprise rewrite of a live config.
10. **OPEN:** whether to stub the Dropbox `.bak`-style variants too, or only the
    three current scripts. Criteria: stub what a human might still double-click;
    leave historical variants untouched pending Albert's decision, since they are
    credential-bearing evidence.

---

## 9. The plan — ordered, executable steps

**Two phases.** Phase A (steps 1–4) is the high-value, low-risk work. Phase B
(steps 5–9) is cleanup and bookkeeping. They are independent enough that a fresh
session can start at step 5 — **but re-read steps 5–9 before starting Phase B** to
check nothing drifted (see `fresh-session` skill). No step needs a git branch:
this repo is **main-only**.

---

### Step 1 — Add drift detection + Phase 2 invocation to `skills/claude/sync-dotfiles/SKILL.md`

**File:** [`skills/claude/sync-dotfiles/SKILL.md`](skills/claude/sync-dotfiles/SKILL.md)

**Changes:**

1. **Delete the two false claims.** The line beginning *"This is **Phase 1** of the
   config-consolidation plan …"* and the table row *"SSH config / MCP tokens | NOT
   here yet — Phase 2 | Dropbox scripts for now"*. Replace the row with a truthful
   one: SSH config, MCP wiring and secret plumbing are repo-owned and installed by
   `bin/setup-machine.ps1` (Windows) / `bin/setup-secrets.sh` (Ubuntu), invoked by
   the new step below.
2. **Insert a new procedure step (make it step 2, right after the `git pull`)** named
   **"Check Phase 2 wiring (secrets, MCP, SSH)."** It must check, and report each:
   - `~/.config/ai-devops/op-service-account` exists.
   - Both launchers exist (`mcp-launch.cmd`/`.sh` and `mcp-remote-launch.cmd`/`.sh`).
   - `~/.config/ai-devops/mcp.env` exists **and matches** `config/mcp.env.example`
     (a plain diff; a mismatch means the machine is on an older reference set — the
     `TRIGGER_ACCESS_TOKEN` pointer changed on 2026-07-26, so this is live).
   - **No real plaintext token** in `~/.claude/settings.json`, `~/.codex/config.toml`,
     or the Claude Desktop config, using the shape-based check in §11 — **not** a
     bare `grep ops_`.
   - Windows only: `~/.ssh/ai-devops.conf` exists and `~/.ssh/config` Includes it.
   - Ubuntu only: `~/.config/ai-devops/shellrc` exists and is sourced from `.bashrc`.
3. **If anything is missing:** run the per-OS script —
   `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\setup-machine.ps1 -RepoPath <repo>`
   or `<repo>/bin/setup-secrets.sh`. Before running, **verify the SA token file
   exists**; if it does not, do **not** invoke the script (it blocks forever on
   `Read-Host` / a token prompt, and an AI session will hang). Instead tell Albert
   exactly what to do: the token is in 1Password `vibe_coding` →
   `vibe_coding-service-account` → field `op_service_account_token`, and it can be
   passed as `-Token <value>` or `OP_SERVICE_ACCOUNT_TOKEN=<value>`. Also record the
   pwsh-7 requirement (the script dies with cryptic parse errors under 5.1).
4. **If everything is present:** say so explicitly in the final report — "Phase 2
   wiring already current, nothing to install" — so the report distinguishes
   *checked and fine* from *not checked*.
5. **Update the closing report instructions** so the skill states the Phase 2 wiring
   status and stops telling Albert that SSH/MCP are on the Dropbox scripts.
6. Note in the skill that after any rewrite of MCP config, **Claude Desktop must be
   fully quit and reopened** (MCP servers only re-read config on a full restart), and
   that clearing `~/.config/ai-devops/mcp-secrets.dpapi.json` forces a fresh secret
   resolve.

**Intent (so a slightly-wrong edit still lands right):** after this step, saying
"sync my dotfiles" on any machine either brings it to full current state or tells
Albert precisely what is missing and why. It must be impossible to get a clean
"synced!" report from a machine holding plaintext tokens.

**You'll know it worked when:** on this machine (already fully wired),
running the skill's new step reports *"Phase 2 wiring already current"* and does
**not** invoke `setup-machine.ps1`. Then simulate drift safely:
`mv ~/.config/ai-devops/mcp-launch.cmd /tmp/` and re-run the check — it must now
report the missing launcher and propose the script. **Restore the file afterwards.**

---

### Step 2 — Mirror the same changes into the Codex twin

**File:** [`skills/codex/codex-sync-dotfiles/SKILL.md`](skills/codex/codex-sync-dotfiles/SKILL.md)
(false claims at lines ~11–12, ~26, ~74).

Same six changes as step 1, in Codex's voice and with Codex-appropriate command
syntax. Keep the two files behaviorally identical — a difference between them is a
future bug where Albert gets different results depending on which tool he asks.

**Dependency:** do step 1 first, then port; don't write both from scratch.

**You'll know it worked when:** `diff` of the two procedures shows only
tool-specific wording — no difference in *what gets checked or run* — and neither
file contains the strings `Phase 1`-as-current-status or `Dropbox scripts for now`:
`grep -rn "Dropbox scripts for now\|NOT here yet" skills/` returns nothing.

---

### Step 3 — Reinstall the edited skills and prove the loop end-to-end

**Command (this machine's `$HOME` trap applies — see §11):**
```bash
CLAUDE_HOME=/c/Users/ahazan2/.claude bin/ai-install-skills
```

**You'll know it worked when:** `sync-dotfiles` and `codex-sync-dotfiles` are listed
as installed, and the installed copies match the repo sources
(`diff ~/.claude/skills/sync-dotfiles/SKILL.md skills/claude/sync-dotfiles/SKILL.md`
→ no output). Then invoke the skill for real in a session and confirm its report
names the Phase 2 wiring status.

---

### Step 4 — Commit + push Phase A

Author `Albert Hazan <u2giants@users.noreply.github.com>` (any other email fails
GitHub's email-privacy check), message ending with the
`Co-Authored-By: Claude Opus 4.8` trailer. `git status` first: the `transcripts`
submodule shows as modified almost always — **do not** stage it, and expect
"Filename too long" warnings from `claude_chats/` (harmless, pre-existing).

**You'll know it worked when:** `git log -1` shows your commit,
`git rev-list --count HEAD..origin/main` is `0`, and `git status --short` shows
nothing but the usual `transcripts` line.

---

### Step 5 — Stub the three current Dropbox scripts (Phase B starts here)

**Targets (exact paths):**
- `C:\Dropbox\vibe coding\ssh keys\master_setupsshwindows.ps1`
- `C:\Dropbox\vibe coding\set up synology and VPS MCP servers in claude windows\setup-claude-mcps.ps1`
- `C:\Dropbox\vibe coding\set up synology and VPS MCP servers in claude windows\setup-codex-mcps.ps1`

**Do this:** copy each to `<name>.pre-phase3.bak` **in place** first, then replace the
body with a stub that (a) prints that this script is retired and the hub is
`ai-devops`, (b) names the exact replacement command
(`pwsh -File C:\repos\ai-devops\bin\setup-machine.ps1 -RepoPath C:\repos\ai-devops`),
(c) exits non-zero so an unattended double-click cannot silently do nothing, and
(d) contains **no** credentials. Add a short `README-RETIRED.md` in each folder
pointing at `docs/restore-from-zero.md` and this plan.

⚠️ **Confirm with Albert before writing** — these files are outside the repo, in his
personal Dropbox, and overwriting them is the irreversible-ish part of this plan.
The `.pre-phase3.bak` copies are the rollback.

**You'll know it worked when:** running each stub prints the redirect and exits
non-zero; the `.pre-phase3.bak` copies exist; and a secret-shape scan of the three
stubs returns zero hits.

---

### Step 6 — Inventory (do NOT delete) the credential material left in Dropbox

Produce `docs/dropbox-credential-inventory-2026-07.md`: one row per file, with
**path, what kind of secret it appears to contain, and hit count — never a value.**
Use the counting technique from §11. Cover both folders from §6/F2, including the
`916-alien` private key, the three script variants embedding key blocks, and the 16
token-bearing MCP files.

For each, state one of: **superseded** (an equivalent now lives in 1Password —
name the item, e.g. the `916-alien SSH key` item added to `vibe_coding` 2026-07-14),
**unknown** (needs a live/dead check before anyone can act), or **public-by-design**
(e.g. `.pub` keys, `known_hosts`).

Then cross-link it from `HANDOFF.md` §S3, because the transcript-leak audit already
tracks the `916-alien` key and must not treat this as a duplicate finding.

**End the doc with a "Recommended next actions — needs Albert's approval" section**
and stop there. No deletion, no rotation.

**You'll know it worked when:** the doc lists every file from §6/F2 with a verdict,
`git diff` shows **no secret values added** (run the §11 scan over your own diff),
and `HANDOFF.md` links to it.

---

### Step 7 — Rewrite `docs/restore-from-zero.md` as true one-command onboarding, both OSes

**File:** [`docs/restore-from-zero.md`](docs/restore-from-zero.md) (currently
Ubuntu-only and silent on secrets/MCP/Windows).

Structure it as: **Ubuntu** (clone → `./install.sh` → interactive logins → verify),
explicitly noting that `install.sh` already calls `bin/setup-secrets.sh` (`:137`) and
what happens if the SA token isn't available (it warns and continues — you then run
`setup-secrets.sh` by hand or with `OP_SERVICE_ACCOUNT_TOKEN=…`); and **Windows**
(clone to `C:\repos\ai-devops` → `pwsh -File bin\setup-machine.ps1 -RepoPath …` →
the validation checklist that script already prints). Both sections must state:

- The one thing a human must supply: the scoped `vibe_coding` SA token (1Password
  item `vibe_coding-service-account`, field `op_service_account_token`).
- The interactive logins nothing can automate: `gh auth login`, `claude login`,
  `codex login`.
- **pwsh 7 required** on Windows; the `Read-Host` block if the token file is absent.
- The manual leftovers `setup-machine.ps1` itself reports: install the **Windows-MCP
  Claude Desktop extension** from Settings → Extensions (it is an extension, not a
  config entry), and **fully restart Claude Desktop**.
- Verification: `ai-devops doctor` (it proves the Codex sandbox with a real
  workspace write — see §6/F4), and the launcher cold/warm cache check from
  `docs/mcp-1password-rate-limit-hardening.md` §Verifying.
- Correct the stale "What is NOT restored" section: secrets are not *in* the repo,
  but the installer *restores them from 1Password*. Both facts, plainly.

**You'll know it worked when:** a reader who has only this doc, a fresh machine, and
the 1Password token can bring up either OS without opening another file — and the
doc's commands are copy-paste literal, with no placeholders.

---

### Step 8 — Portable Codex prefs template

**New file:** `templates/system/codex-config-portable.toml` containing **only**:
`model`, `model_reasoning_effort`, `sandbox_mode`, `approval_policy`, and
`[windows] sandbox`. **Exclude** `notify` (absolute per-install path) and every
`[projects.'…'] trust_level` block (per-machine paths) — decision 4 in §8.

⚠️ **Hard rule that governs the value you write:** `model_reasoning_effort` must be
`low` or `medium` — **never `high`, never `none`/`minimal`.** This is Albert's
standing directive (2026-07-16) on every machine and in every session, and an *unset*
effort has been observed starting a run at `none`, so the template must set it
explicitly. This machine's current value is `low`.

**Application:** extend `bin/setup-machine.ps1`'s existing Codex step (or add one
beside `bin/configure-codex-1password.ps1`, which already surgically edits
`config.toml` while preserving `.tools.*` guards — read it and follow its pattern)
to **seed missing keys and leave existing values alone**, append-only, never
rewriting the file or reordering it. Must not touch `notify` or `[projects.*]`.
Support `--dry-run`.

**You'll know it worked when:** on this machine (which already has all five keys)
a dry run reports **no changes**; after temporarily removing one key from a **copy**
of `config.toml`, the dry run reports exactly that one key as missing; and a real
run restores it while every `[projects.*]` block and `notify` line survives byte-identical.

---

### Step 9 — Update `machine-atlas.md`, `AGENTS.md`, the proposal, `HANDOFF.md`; commit + push

- [`templates/system/machine-atlas.md`](templates/system/machine-atlas.md): replace
  the Dropbox instruction at ~84–86 with the repo path (`bin/setup-machine.ps1` owns
  Claude Desktop MCP wiring; the Store/MSIX config path
  `…\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`
  stays — it is still correct and non-obvious). Fix the line-57 heading so **`4837`
  is identified as `al8960ofc`, not a fourth machine.** Keep the never-hand-edit rule
  and the "Claude scripts must never touch Codex config" rule.
- [`AGENTS.md`](AGENTS.md) `## Pending work` (line 633): flip Phase 2 to `done`
  (2026-07-26, machines t16 + al8960ofc; rollout to `916`/other Ubuntu outstanding)
  and set Phase 3's status from what you actually completed. Don't mark Phase 3 done
  if any step above is unfinished.
- [`docs/config-consolidation-proposal.md`](docs/config-consolidation-proposal.md)
  `## Phase 3` section: mark each of the four original rows plus the S1 gap-closure,
  and record that Dropbox files were **stubbed and inventoried, not deleted**.
- [`HANDOFF.md`](HANDOFF.md): update the Phase 2/3 status block and link the new
  inventory doc. **Do not delete `HANDOFF.md`** (§4 OUT).

**You'll know it worked when:** `grep -rn "Dropbox" --include="*.md" .` (excluding
`transcripts/`, `claude_chats/`, `codex_chats/`) returns only *historical* or
*retired-pointer* mentions — no instruction anywhere tells a session to use a Dropbox
script as the way to configure a machine. Then commit + push per step 4's gates.

---

## 10. Tests required

**T1–T4 already ran and passed on 2026-07-26** (marked ✅) as part of steps 1–3 —
re-run them only if you touch the skills again. T5–T10 remain for steps 5–9.

This repo has **no test framework** — it is Bash + PowerShell + Markdown, and that is
deliberate (`CLAUDE.md`). "Add unit tests for the code you create" (standing rule 13)
applies to the code you touch; here that means these concrete, runnable checks. Record
the output of each in your final report.

| # | Check | Command / method | Pass condition |
|---|---|---|---|
| T1 ✅ | Skill files parse and install | `CLAUDE_HOME=/c/Users/ahazan2/.claude bin/ai-install-skills` | Both sync-dotfiles skills listed; no collision error; installed copies `diff` clean vs repo |
| T2 ✅ | Drift detection catches a missing launcher | Move `mcp-launch.cmd` aside, run the skill's check, **restore it** | Reports the missing launcher and proposes the setup script; does not report "synced" |
| T3 ✅ | No-drift path is quiet | Run the skill's check on this fully-wired machine | Reports "Phase 2 wiring already current"; does **not** run `setup-machine.ps1` |
| T4 ✅ | No false "plaintext token" positives | §11 shape-based scan on this machine's three configs | Zero hits (they are token-free as of 2026-07-26), proving the check doesn't fire on `devops_token` |
| T5 | Launcher cache still healthy after any edit | Delete `mcp-secrets.dpapi.json`, cold launch, note mtime, warm launch | Cold writes cache; warm launch leaves mtime **unchanged** (zero `op` calls) |
| T6 | Secret plumbing intact end-to-end | `op run --env-file ~/.config/ai-devops/mcp.env -- <trivial cmd>` , or a launcher run | Succeeds; the launcher fails closed on any empty secret, so success proves all refs resolve |
| T7 | Codex prefs applier is non-destructive | Step 8 dry-run on a **copy** with one key removed | Reports exactly that key; `notify` + all `[projects.*]` blocks untouched |
| T8 | Codex still actually works | `bin/ai-devops doctor` | Codex sandbox check passes with a real workspace write (presence ≠ capability, §6/F4) |
| T9 | No secret enters git | §11 scan over `git diff` before every commit | Zero hits |
| T10 | Dropbox stubs are inert and clean | Run each stub | Prints redirect, exits non-zero, no credentials present |

---

## 11. Constraints, standing rules, and gotchas in force

**Repo/process rules**
- **Main-only, no branches** for `u2giants` app repos including this one. State repo
  and branch before any push.
- **Commit only when asked** (this repo's `CLAUDE.md`) — but a task is not "done"
  while work sits local-only. Ask, then push; don't leave a local-only commit and
  call it finished.
- Commit author **must** be `Albert Hazan <u2giants@users.noreply.github.com>`; end
  messages with the `Co-Authored-By: Claude Opus 4.8` trailer.
- Before pulling/merging, check for uncommitted work from concurrent AI sessions;
  never clobber it silently. Stage only your own hunks.
- **No band-aids** — root-cause fixes only; if a workaround is unavoidable, label it
  TEMPORARY in `HANDOFF.md` with the permanent fix described.
- **No silent failures** — every fallback must alert loudly. When you find one, sweep
  for the same pattern.
- **Nothing hard-coded** that should be configurable (model choices above all).
- **Config file edits are append-only.** Never replace system binaries. **Claude setup
  scripts must never touch Codex config, and vice versa.**
- Docs: `AGENTS.md` is the canonical router — read it first, and don't bulk-load every
  `.md`. Update docs at session end (`session-docs-update` skill).
- **Never mention or use Fable** in this repo's model roles.

**Secrets**
- All secrets live in 1Password vault **`vibe_coding`** only. Never print, persist, or
  commit a value. Never rotate an existing credential without approval, and **never
  suggest rotating the bootstrap SA token**.
- **Serialize 1Password reads.** Never fan out `op read`/`op run`/1Password MCP calls
  in parallel — a parallel storm is what locked the SA out (`docs/mcp-1password-rate-limit-hardening.md`).
- **The correct plaintext-token check** (shape-based, avoids the `devops_token` false
  positive from §6/F4):
  ```bash
  grep -oE '\bops_[A-Za-z0-9_-]{20,}' <file>
  ```
  A real SA token is ~866 characters. `op://…/devops_token` will not match this.
  For a JSON config, the rigorous version is to walk the parsed values and flag any
  string that both contains `ops_` and does **not** start with `op://`.
- Anything found in Dropbox is **reported, never deleted or rotated** here (§7).

**Production safety**
- AI sessions are **read-only for production and shared cloud infrastructure by
  default**, regardless of repo. No `terraform apply`/`destroy` against prod under
  Albert's personal credentials. In project `lithe-breaker-323913` never touch a
  `*-prod` Cloud Build trigger unless Albert names the exact resource and action in
  the current chat.
- **Database = `u2giants/shared-db`, always** — irrelevant to this plan (no DB here),
  but if you somehow reach for a schema change, stop and use the `shared-db-change` skill.

**Machine gotchas that will bite you on this box**
- **`Z:` trap.** On `al8960ofc`, `Z:` is a NAS-mapped network drive and **Git Bash's
  `$HOME` resolves to `Z:`**, not `C:\Users\ahazan2`. Claude Code reads
  `C:\Users\ahazan2\.claude` (USERPROFILE). So when running repo installers from Bash,
  set `CLAUDE_HOME=/c/Users/ahazan2/.claude` or skills land on the NAS where no app
  reads them.
- **PowerShell vs Bash are separate shells** with separate syntax here. PowerShell has
  no `<<<` here-strings; use a file. `setup-machine.ps1` needs **pwsh 7**.
- **`setup-machine.ps1` blocks on `Read-Host`** for the token if the token file is
  missing — an AI session will hang. Check the file first.
- **Use Git's ssh** (`C:\Program Files\Git\usr\bin\ssh.exe`) for automation; the
  Windows-MCP PowerShell sandbox cannot capture SSH output (ConPTY exit 255). Never
  copy that binary out (msys DLLs) and never overwrite system OpenSSH.
- **`>NUL` in an ssh `Match exec` probe creates a junk file** under msys `sh`.
  OpenSSH already discards `Match exec` output, so the redirect suppresses nothing.
  `config/ssh-config.template` carries a header comment warning against re-adding it —
  the two `>NUL` strings in that file are *that comment*, not live probes. Don't
  "fix" them.
- **Mode-only dirt on `hetz`** (`100644 → 100755` on `bin/ai-install-skills` and
  `bin/install-ai-devops-windows.ps1`) is expected and intentional; leave it, don't
  commit the flip.
- **Long-path warnings** from `claude_chats/` during git operations are pre-existing noise.
- Deprecated systems — delete vestiges on sight, never build on them: retired CRM/CMS
  stacks, the pre-rename PM repo, openmanus.

---

## 12. Access and environment

- **Repo:** `C:\repos\ai-devops` on this machine, branch `main`, remote
  `u2giants/ai-devops` (private).
- **Authenticated CLIs on Albert's machines** (verify with a real call before ever
  claiming a capability is missing): `gh` (account `u2giants`, keyring), `gcloud`,
  `az`, `supabase`, `op` (2.34.1 here), `cloudflared`, `node`/`npx`, `uv`, `kimi`,
  `claude`, `codex`. **Note:** the `vercel` CLI's stored token is currently invalid
  (`vercel projects ls` → "The specified token is not valid"); the Vercel **MCP**
  works. Don't chase that here.
- **MCPs wired on this machine (token-free):** supabase, devops-mcp,
  synology-monitor, recall-ai, trigger, 1password, playwright, ag-grid, vercel,
  codex-cli.
- **Secrets by location only, never value:**
  - SA token → 1Password `vibe_coding` → item `vibe_coding-service-account` → field
    **`op_service_account_token`** (⚠️ **not** the empty `credential` field — that
    silent-empty trap has burned sessions; always verify a resolved secret is non-empty).
  - 916-alien SSH key → item `916-alien SSH key` (added 2026-07-14).
  - Machine-local SA token file → `~/.config/ai-devops/op-service-account`, user-only.
- **Ubuntu access:** `ssh vps` → `hetz` as `root`; repo at `/worksp/ai-devops` owned
  by `ai:ai`; use `sudo -u ai -H bash -lc '…'`.
- **How to "run" this thing:** there is no app to serve. Verification is running the
  `bin/` scripts, `bin/ai-devops doctor`, and the launcher cache check.
- **Local sanity:** don't traverse network drives (`P:` Images SMB, `Z:`
  Documentation) uninvited — they are large mounts.

---

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Both `sync-dotfiles` skills check Phase 2 wiring, invoke the per-OS setup script
      when it's missing, never hang on the token prompt, and never report success
      while wiring is absent (steps 1–2).
- [ ] `grep -rn "Dropbox scripts for now\|NOT here yet" skills/` → nothing.
- [ ] Skills reinstalled; installed copies match repo sources (step 3, T1).
- [ ] Drift-detect proven both ways: catches a missing launcher, stays quiet when
      current (T2, T3).
- [ ] The three current Dropbox scripts are inert stubs with `.pre-phase3.bak`
      rollbacks, **after Albert's confirmation** (step 5, T10).
- [ ] `docs/dropbox-credential-inventory-2026-07.md` exists, every §6/F2 file has a
      verdict, no values, linked from `HANDOFF.md` (step 6).
- [ ] `docs/restore-from-zero.md` covers both OSes with copy-paste-literal commands,
      the SA-token requirement, pwsh 7, Windows-MCP extension, and Desktop restart (step 7).
- [ ] `templates/system/codex-config-portable.toml` exists with the five portable keys
      and `model_reasoning_effort` explicitly `low`/`medium`; the applier is
      append-only, has `--dry-run`, and leaves `notify`/`[projects.*]` untouched (step 8, T7).
- [ ] `machine-atlas.md` no longer teaches the Dropbox path and identifies `4837` as
      `al8960ofc`; `AGENTS.md` Phase 2 = done and Phase 3 accurate; proposal and
      `HANDOFF.md` updated (step 9).
- [ ] T1–T10 all recorded with their actual output.
- [ ] Committed **and pushed** to `main`; `git rev-list --count HEAD..origin/main` = 0;
      `git status` clean apart from the usual `transcripts` line. No CI/deploy exists
      in this repo, so push + the checks above are the deploy gate.
- [ ] No secret in any diff (T9). Nothing left needing commit/merge/apply.
- [ ] `HANDOFF.md` reflects reality; this plan file is deleted **only** when every box
      above is ticked.

### Risks and rollback

| Risk | Likelihood | Mitigation / rollback |
|---|---|---|
| The skill's new step runs `setup-machine.ps1` unasked and rewrites a live Claude Desktop config | Medium | Drift-detect gates it; the script backs up to `*.aidevops.bak`; decision 9 in §8 tells you when to ask first. Restore from the backup. |
| An AI session hangs forever on the token `Read-Host` | Medium — it has happened | Step 1 requires checking the token file *before* invoking; never invoke blind. |
| Overwriting a Dropbox script Albert still relies on | Low | `.pre-phase3.bak` in place + explicit confirmation before writing. |
| The credential inventory leaks a value into git | Low, high impact | Counts and verdicts only; run the §11 scan over your own diff before committing (T9). |
| Someone "finishes SSH parity" by shipping the Windows ping probe to Ubuntu | Low, severe (lock-yourself-out shaped) | Called out in §4 OUT and §7 with the correct Linux form. |
| Editing the launcher and regressing the rate-limit fix | Low, severe | You have no reason to touch `mcp-secret-launch.ps1`. If you do: keep `Position = 0`, no `--` in the `.cmd`, never restore per-launch `op run`; verify with T5. |
| Phase 3 declared done while `916`/Ubuntu servers still carry old wiring | Medium | Out of scope by §4, but say so explicitly in the status rows — "shipped, rollout outstanding on named machines", never a bare "done". |

### Open questions (with the criteria to decide them)

1. **Auto-run vs ask** in the skill's drift step → §8 decision 9's criteria. Yours to
   settle; document what you chose in the skill file itself.
2. **Stub the Dropbox `.bak` variants too?** → §8 decision 10. Needs Albert; ask when
   you present step 5.
3. **Ubuntu 15-minute cache parity** → deferred. If you believe it belongs in Phase 3,
   raise it as its own approval-gated item; do not fold it in silently.
4. **Whether `916` gets included** in this pass → it is powered off until ~2026-07-28.
   If it is on when you reach step 9, running `git pull` + `setup-machine.ps1` there is
   the whole rollout; otherwise record it as outstanding.

---

## Self-audit (run before this plan was shown — preserved per the standard)

**1. Could a brand-new session with no project knowledge execute this to perfection
without asking anything?** Yes. §2 defines the repo, machines, and every term
including `op://`, MCP, launchers, and the hub; §5 gives file-by-file current state
with line refs (`install.sh:137`, `setup-secrets.sh:243`, `mcp-secret-launch.ps1:34`,
`bootstrap-windows-dev.ps1:125`, AGENTS.md lines 633/643/644); §9 names every target
file with a verification gate; §11 lists the traps that cost prior sessions time
(the `Z:` `$HOME` trap, the pwsh-7 requirement, the `Read-Host` hang, the `ops_`
false positive, the `>NUL` non-bug); §12 gives access and secret locations by name.
The two genuinely judgment-based points are labeled OPEN with decision criteria
rather than left implicit.

**2. Does it carry every piece of background and nuance, including what was ruled
out?** Yes. §7 records eight rejected approaches with reasons and lock status —
chezmoi, duplicating steps inside the skill, always-run, deleting Dropbox files,
rotating found credentials, shipping the SSH template to Ubuntu, Linux cache parity,
and reconciling instruction wording. §6 records the four findings that cost real
time, including the two that are counter-intuitive (presence ≠ capability; the
`devops_token` grep false positive) and the Dropbox exposure measurement that the
original Phase 3 table never anticipated. §3 states the triggering question verbatim
and how to reproduce the gap read-only.

**3. Is the ultimate goal clear enough to make a correct judgment call when a step is
wrong?** Yes. §1 states it in plain business English before any technical wording,
names the three conditions that must become true, and instructs explicitly that the
goal outranks any step — with the specific failure mode (a machine *reporting*
success while carrying plaintext tokens) called out so the implementer can recognize
a bad step when they see one.

**Gap found during the audit and fixed:** the first draft's step 1 said "check for
plaintext tokens" without specifying how — which would have reproduced the exact
`grep ops_` false positive that misfired on 2026-07-26. §11 now carries the
shape-based check and T4 tests that it does *not* fire on `devops_token`.
