# Memory Index

- [Project: ai-devops onboarding/secrets](project_ai_devops_onboarding.md) — unified new-machine setup; vault-scoped SA token; Ubuntu shell-export vs Windows-Desktop op-run; ${VAR}-not-expanded gotcha

- [Project: CI/CD deploy architecture](project_cicd.md) — Coolify API trigger, no SSH; Coolify app UUID; sg.designflow.app file provider
- [Project: pending work](project_pending.md) — Auto-update cert blockers, PopSG render pass
- [Project: Helper storage by region](project_helper_storage_regions.md) — Brazil=Seafile, USA=SMB edgesynology1, no fallback; region via geolocation+admin panel
- [Feedback: terse responses](feedback_terse.md) — User wants concise output; no trailing summaries
- [Project: DB backfill batching](project_db_backfill_batching.md) — Big single-statement backfills on assets time out/crash compute; batch ~20k
- [Project: git/dist root ownership](project_git_root_ownership.md) — .git & dist revert to root; fix with sudo chown -R ai:ai
- [Project: check-in receipt verification](project_checkin_verification.md) — Seafile verify-on-Synology, deployed DARK behind CHECKIN_VERIFICATION_ENABLED; activation steps
- [Project: bridge self-updater fragility](project_bridge_self_updater.md) — DON'T modify the agent self-updater; invariants + why; detect drift via build_sha instead; KNOWN false-positive "Build mismatch" (env-clone freezes build_sha)
- [Project: Supabase Virginia cutover](project_supabase_virginia_cutover.md) — LIVE project = qsllyeztdwjgirsysgai (Virginia); default mcp__supabase__* still points at OLD Ohio .old (stale-data trap)
- [Project: VPS 1Password/MCP secrets](project_vps_1password_mcp_secrets.md) — vibe_coding vault via vault-scoped op SA in /root/.bashrc; .mcp.json placeholders + op run; MCP→Coolify token mapping; held-docker fix for proxy socket failure
- [Project: PDF backfill processor](project_pdf_backfill_processor.md) — full-library text extraction runs on an on-prem agent (Windows render agent, bridge fallback), not cloud; trigger/total/handover gotchas
- [Project: Style Guide Sources scope](project_style_guide_sources_scope.md) — sku_files_used now only from licensing/tech-pack PDFs; source column; 863 legacy_ungated rows to purge after review
- [Feedback: no workarounds](feedback_no_workarounds.md) — fix root cause or ask for what's missing; don't silently downgrade to best-effort
- [Feedback: handoff "comprehensive?" → Yes](feedback_handoff_comprehensive_yes.md) — answer Yes when the handoff genuinely passes the checklist; don't reflexively say "No, I'll fix it"
- [Project: PopDAM shared/concurrent env](project_popdam_shared_env.md) — repo checkout is concurrently edited; supabase MCP token wiring gap + fix
- [Project: secret/DB access paths](project_secret_access_paths.md) — when supabase MCP is unauthorized: op no-print path (op run --env-file), service role via PostgREST, psql/CLI; OpenRouter key in admin_config; account data-policy gotcha
- [Project: AI model routing](project_ai_routing.md) — OpenRouter+Exacto-by-default; live models in admin_config.AI_TASK_MODELS (qwen/minimax/deepseek, no Gemini); TRAP: GOOGLE_AI_API_KEY still live for on-prem agent PDF text extraction — not dead
- [Feedback: cacheable batch → direct API not OpenRouter](feedback_caching_direct_api.md) — repeated-prompt-prefix high-volume LLM work uses direct provider (DeepSeek auto prompt caching ~1/10 price); stable-prefix-first; never OpenRouter for that
- [Project: PopSG vs PopDAM search paths](project_popsg_search_paths.md) — PopSG library search is a SEPARATE path (style_guide_file_groups raw ILIKE in PopSGLibraryPage), not the dam_search_documents RPCs; check the network tab before fixing
- [Project: PopSG tag matching baseline](project_popsg_tag_matching_baseline.md) — exact-match coverage on 216k files: licensor 49% / property 83% unmatched; licensor head=16 (WB→Warner Bros etc), property tail=300; parent-child conformance perfect (0 violations); reconcile GUI needs alias+create-row; CLI-token→Mgmt-API is the working DB path
- [Project: PopSG AI tester login](project_popsg_tester_login.md) — ai-tester@popcre.com in 1Password (vibe_coding); invitation-gated signup; how to create/inject-session/teardown
