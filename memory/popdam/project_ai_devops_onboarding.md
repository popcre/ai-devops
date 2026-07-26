---
name: project-ai-devops-onboarding
description: "ai-devops is the home for unified new-machine secrets/onboarding; scoped-SA-token model, key constraints & Windows-Desktop gotchas"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6d0cf98b-c944-45be-883d-6ef8e6745f2c
---

`/worksp/ai-devops` (GitHub u2giants/ai-devops, `origin` only — no `github`
remote) is the single home for unified new-machine setup + secret resolution.
Shipped 2026-07-14 (commit "Add unified new-machine secrets & onboarding").

**Architecture** (see repo `docs/onboarding-secrets.md`):
- One source of truth = 1Password vault `vibe_coding`, referenced via `op://`
  only, never values. Central refs file: `config/mcp.env.example` → installed to
  `~/.config/ai-devops/mcp.env`. One shared Supabase PAT item for ALL apps
  (`op://vibe_coding/ujkouj7hatka2xyfbgvzyu4344/SUPABASE_ACCESS_TOKEN`); MCP
  tokens `op://vibe_coding/designflow-mcp/{devops_token,nas_token}`.
- Ubuntu (`bin/setup-secrets.sh`): shell-EXPORT model (resolves refs into the
  login shell) — chosen over an `op run` wrapper because it's what already works
  on hetz and authorizes every CLI, not just claude. Stores the one bootstrap
  secret (service-account token) at `~/.config/ai-devops/op-service-account`
  chmod 600; wires POSIX-safe `~/.config/ai-devops/shellrc` sourced by .bashrc/
  .profile; neutralizes legacy raw tokens in .bashrc by replacing with `true`
  (NOT bare comments — they can sit inside if/then/fi and would break sourcing).
- Windows (`bin/setup-machine.ps1`): Claude DESKTOP app uses `op run` at
  MCP-launch (shell-export impossible for a GUI app).

**User constraints (drove the design):** user is NOT a programmer; on Windows
they "click the icon" = Claude Desktop (MSIX), not Claude Code CLI. They refuse
the PERSONAL `op` sign-in (exposes all vaults) but APPROVED a vault-scoped
SERVICE-ACCOUNT token (can only read `vibe_coding`). Optimize for fewest steps +
plain English. [[feedback_terse]] [[project_vps_1password_mcp_secrets]]

**Windows-Desktop gotchas (verified):** Claude Desktop does NOT expand `${VAR}`
in claude_desktop_config.json; MSIX sandbox ignores setx env vars & may strip
`env` blocks on restart; remote/HTTP MCPs (devops-mcp, nas-mcp) must be added
via Settings→Connectors UI, not the config file; npx needs `cmd /c`. The
setup-machine.ps1 Desktop-config step was authored on Linux and is UNVERIFIED on
a real Windows box — needs first-run validation.

**Done live on hetz:** removed the two raw `OP_SERVICE_ACCOUNT_TOKEN=ops_...`
lines from `/home/ai/.bashrc` (backup `.bashrc.aidevops.bak.*`); token now only
in the 600 file.

**SSH turnkey:** `config/ssh-config.template` (non-secret host aliases) installed
to `~/.ssh/ai-devops.conf` and `Include`d from `~/.ssh/config` at the END (so
existing entries win; adds `vps2` alias = same hetz box). Uses cloudflared as
PRIMARY for tunnel-backed hosts (portable, no Tailscale, same on Win/Linux —
avoids the Win-vs-Linux ping syntax in Match-exec fallback). setup-machine.ps1
installs cloudflared + the config. Windows-only by default (key/config not seeded
on Ubuntu servers to avoid spreading the master key).

**Memory sync ("always in sync"):** `bin/ai-memory-sync` wraps the consolidation
effort's `bin/ai-sync-memory`, adds: isolated clone `~/.cache/ai-devops-memory`
(never the live checkout), a SECRET GATE (aborts upload if ops_/ghp_/AKIA/JWT/
PRIVATE KEY patterns found), upload-before-download + file-level union (each fact
= own file, cp never deletes), rebase-retry push of only memory/. Scheduled: cron
30min (Ubuntu install.sh) + Scheduled Task (Windows). Verified vs throwaway repo.
NOTE: consolidation effort kept commit MANUAL on purpose (secret review); the
secret gate is the automated substitute. NOT yet activated on hetz (needs go).

**916-alien SSH key** is now in 1Password: item "916-alien SSH key" (id
`hqbakq2k5wheapo2t4xx74cltm`, category SSH_KEY, vibe_coding), fingerprint
SHA256:l5pvpZxu4y8J+yCFoQCcL1pbNLsqE5PvD9dkvIgyooc; public half authorized on
hetz as comment "916-alien". `setup-machine.ps1` restores it to
`~\.ssh\916-alien` (+.pub). NOTE: `op item edit` CANNOT edit SSH_KEY items ("not
yet supported" in CLI) — use the 1Password MCP `item_edit` instead.

**Known follow-up:** `monitor/app/.mcp.json` still has a RAW NAS token — should
become `${NAS_MCP_TOKEN}` (app-repo change). A parallel "config consolidation"
effort exists in the same repo (HANDOFF.md, docs/config-inventory.md).
