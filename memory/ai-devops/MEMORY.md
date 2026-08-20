# Memory index — C:\repos\ai-devops

- [op service-account token field](op-service-account-token-field.md) — the token is in `op_service_account_token`, NOT the empty `credential` field; verify resolved secrets are non-empty.
- [GLM agent Z.ai field + fork bomb](glm-agent-zai-field-and-forkbomb.md) — GLM key is in the "api key" field (id vup42…), not `credential`; empty key fork-bombed the launcher; fixed with field-id ref + re-exec guard.
- [vibe_coding vault reprovisioned](vibe-coding-vault-reprovisioned.md) — 2026-07-22 SA token rotation moved to a new account; vault + all item UUIDs changed, breaking old op:// UUID refs; new UUIDs + token locations recorded.
- [1Password MCP launcher storm](mcp-1password-launcher-storm.md) — per-launch `op run` MCP launcher overran the shared SA's hourly cap and locked it; fix is the single-flight DPAPI cache; don't re-add per-launch op run, `--`, or drop Position=0.
- [4837 home-drive Z: trap](4837-home-drive-z-trap.md) — 4837 interactive Git Bash $HOME=Z: (roaming profile) sent $HOME-based installs to a network drive apps never read; fixed by pinning HOME=C: + ai-install-skills using %USERPROFILE%.
- [remote-shell CWD trap](remote-shell-cwd-trap.md) — remote `bash -lc` over SSH starts in $HOME not the repo; use `git -C`/absolute paths, not relative. Includes the `4837` ssh alias (100.123.87.44, key 916-alien).
- [GLM on OpenCode: hard-won constraints](glm-opencode-constraints.md) — `ai-glm` replaced `ai-glm-agent`; read docs/glm-opencode.md §5 before touching GLM or Windows setup. Only the agent `tools:` map enforces anything; `.ps1` files must be pure ASCII.
- [Claude MCP config file](claude-mcp-config-file.md) — local MCP servers must live in ~/.claude.json; ai-devops setup writes them to the ignored settings.json.
- [Claude Desktop MCP wipe](claude-desktop-mcp-wipe.md) — the app deletes the mcpServers block from claude_desktop_config.json; restore is on trial as of 2026-08-20.
