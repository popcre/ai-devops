# Memory index — C:\repos\ai-devops

- [op service-account token field](op-service-account-token-field.md) — the token is in `op_service_account_token`, NOT the empty `credential` field; verify resolved secrets are non-empty.
- [GLM agent Z.ai field + fork bomb](glm-agent-zai-field-and-forkbomb.md) — GLM key is in the "api key" field (id vup42…), not `credential`; empty key fork-bombed the launcher; fixed with field-id ref + re-exec guard.
- [vibe_coding vault reprovisioned](vibe-coding-vault-reprovisioned.md) — 2026-07-22 SA token rotation moved to a new account; vault + all item UUIDs changed, breaking old op:// UUID refs; new UUIDs + token locations recorded.
- [1Password MCP launcher storm](mcp-1password-launcher-storm.md) — per-launch `op run` MCP launcher overran the shared SA's hourly cap and locked it; fix is the single-flight DPAPI cache; don't re-add per-launch op run, `--`, or drop Position=0.
- [4837 home-drive Z: trap](4837-home-drive-z-trap.md) — 4837 interactive Git Bash $HOME=Z: (roaming profile) sent $HOME-based installs to a network drive apps never read; fixed by pinning HOME=C: + ai-install-skills using %USERPROFILE%.
- [remote-shell CWD trap](remote-shell-cwd-trap.md) — remote `bash -lc` over SSH starts in $HOME not the repo; use `git -C`/absolute paths, not relative. Includes the `4837` ssh alias (100.123.87.44, key 916-alien).
- [Phase 3 plan location](phase3-plan-location.md) — remaining config-consolidation work is in `plan_phase3-config-consolidation.md`; open its STATUS table when Albert asks what's left, don't re-derive or re-plan.
- [Trigger PAT: CLI whoami lies](trigger-pat-cli-whoami-false-negative.md) — post-2026-07-26 Trigger PATs fail `trigger.dev whoami` on 4.5.7/4.4.1 but are valid via the REST API and the trigger MCP; verify with the API.
- [Concurrent-session clobber hazards](concurrent-session-clobber-hazards.md) — another session's broad `git add` swept my files into its commit, and an albt16 memory push reverted my edits + shrank MEMORY.md; stage only your own paths and re-verify memory after every sync.
