# Reviewer enforcement inventory (2026-10-29)

This is the checklist for phases B–F of the skinny review in [plan_simple-reviewer-rebuild.md](../plan_simple-reviewer-rebuild.md) (#2041).

- It is a read-only survey of `origin/main` in ai-devops, of shared-db, theoracle and popdam3 through `gh`, and of the globals installed on edge-dev3.
- Line numbers are approximate. Re-check each one before editing.

| # | Where | What it does | Switch-off | Resolution (2026-10-31) |
|---|---|---|---|---|
| 1 | shared-db ruleset 25808522 | Requires "Merge queue gate", "Migration guarded merge authorization" and "Migration author lease" | Remove these from the required checks | off — ruleset 25808522 deleted (404); live ruleset 26255167 is merge-queue only; branch protection requires only `SQL migration guards`, `supabase/tests against an ephemeral database`, `Destructive SQL outside migrations` (gh api 2026-10-31) |
| 2 | shared-db `.github/workflows/merge-queue-gate.yml` ~143-189 | Runs `scripts/check-exact-head-approval.mjs` | Remove the approval step | off — `merge-queue-gate.yml` has no approval step; `check-exact-head-approval.mjs` deleted (shared-db #5055, #5118) |
| 3 | shared-db `scripts/check-exact-head-approval.mjs` | Refuses a merge unless an exact-head APPROVE exists | Pass unconditionally, then delete | off — file deleted (shared-db #5118 92133262) |
| 4 | shared-db `.github/workflows/guarded-migration-merge.yml` ~382,438,489 | Re-checks approval | Remove | off — `guarded-migration-merge.yml` deleted from main |
| 5 | shared-db `.github/workflows/shared-supabase-migrations.yml` ~1238-1959 | Production promotion needs reviewer evidence | Owner authorization only | off — promotion is automatic: workflow writes its own evidence (`automatic_evidence`) and holds only on an open `review-finding` (ruling 2026-10-29 evening); live proof run 41186990442, #2075 comment 6551124566 |
| 6 | shared-db `.github/workflows/production-apply-review-evidence.yml` | Records production-apply verdicts | Disable | off — workflow deleted from main |
| 7 | shared-db `.github/workflows/migration-author-lease.yml` | Tests the approval and lease scripts | Trim | off — `migration-author-lease.yml` deleted from main |
| 8 | shared-db `scripts/lib/lanes/review-*.mjs`, `reviewer-doctor.mjs`, `reviewer-roster.mjs` | Allocator, leases and records | Delete (F) | off — no required check, merge or promotion step reads these; lane libs remain only as non-gating lane-tool code (F done-when grep 0, #2074) |
| 9 | shared-db `scripts/lib/review-verdict*.mjs`, `review-packet.mjs`, `reviewer-turn-budget.mjs`, `reviewer-draw-readiness.mjs`, `reviewer-capabilities.mjs`, `reviewer-caller-env.mjs` | Verdict, budget and draw logic | Delete (F) | off — same as row 8; `review-verdict*`, `reviewer-*` libs gate nothing |
| 10 | shared-db `scripts/db-flow/reviewer-allocation.mjs`, `run-governed-review.mjs`, `run-deepseek-evidence-review.mjs`, `check-review-parallelism-brief.mjs` | Governed review runner | Delete (F) | off — `run-governed-review.mjs`, `run-deepseek-evidence-review.mjs`, `check-review-parallelism-brief.mjs` deleted; `reviewer-allocation.mjs` has no caller |
| 11 | shared-db `scripts/production_review_allowlist.py`, `production_apply_review_evidence.py` | Production allowlist needs a verdict | Delete or bypass | off — bypassed: automatic route feeds machine-written evidence; only the review-finding hold applies (ruling 2026-10-29 evening; run 41186990442) |
| 12 | shared-db `config/owner-no-reviewer-policy.json` | Owner skip | Delete with #3 | off — deleted (shared-db #5118) |
| 13 | shared-db `config/review-carry-forward-stored-hashes-v1.json` | Carries verdicts forward | Delete with #3 | off — file only listed as a protected path in `production_business_risk_gate.py`; carries no verdict into any decision |
| 14 | shared-db `.github/workflows/reviewer-start-watch.yml` (every 5 minutes) | Reroutes reviewers | Disable | off — workflow deleted from main |
| 15 | shared-db `.github/workflows/review-verdict-auto-archive.yml` (hourly) | Archives verdict refs | Disable | off — workflow deleted from main; all `refs/db-review-*` archived and deleted (#2074) |
| 16 | shared-db `.github/workflows/lane-watchdog.yml` | May watch review slots | Check, then disable the review part | off — `lane-watchdog.yml` contains no review step (grep 2026-10-31) |
| 17 | shared-db `AGENTS.md` ~199,420-440,495 | "Exact-head APPROVE is the gate" | Rewrite | off — shared-db #5258 removed the remaining APPROVE-gate text (§1, ruling one-liners, §5.0-C) |
| 18 | shared-db `docs/agents/merge-protocol.md` | Merge needs an APPROVE | Rewrite | off — `merge-protocol.md` states review is advisory; the 2026-10-14 slot rule is marked superseded |
| 19 | shared-db `docs/agents/review-recovery-policy.md` | Redraw and replacement policy | Archive | off — archived with a superseded banner in shared-db #5258 |
| 20 | shared-db `docs/agents/owner-rulings.md` §6.27-6.28 | Review minimums | Add a superseding ruling | off — superseding ruling §0.0-R (2026-10-29) and lean checks (2026-10-30) in shared-db `docs/agents/owner-rulings.md` |
| 21 | shared-db `.ai-devops/task-gates.json` | Docs and skills classed as `reviewer-safety` | Reclassify | off — no path is classed `reviewer-safety`; that gate needs no review |
| 22-27 | ai-devops `config/task-gates.json` classes installation, reviewer-safety, deployment, infrastructure, production, plus the infrastructure/ansible repo rules | Require a reviewer approval | Remove those gates | off — no class requires a reviewer gate; `REVIEWER_GATE_RE` waives any listed one (stage B #2057); production/ansible use owner `--acknowledge`, not a verdict |
| 28 | ai-devops `config/task-gates.json` `reviewer_release` | Releases a protected class only through an APPROVE | Remove | off — `reviewer_release` key removed from `config/task-gates.json` |
| 29 | ai-devops `config/task-gates.json` `application_source_releases` | Designflow source release needs an APPROVE | Remove | off — `application_release_finish` records `no-reviewer-gate(#2041)` |
| 30 | ai-devops `config/task-gates.json` theoracle rule | `release-marker-review` | Remove | off — no `release-marker-review` rule remains; name is waived in `REVIEWER_GATE_RE` |
| 31 | ai-devops `bin/ai-task-gates` ~58-92 | Observation-week freeze and `MERGE-UNREVIEWED` | Delete | off — no observation-week or `MERGE-UNREVIEWED` code in `bin/ai-task-gates` |
| 32-36 | ai-devops `bin/ai-task-gates` ~581-680, 848-916, 1501-1711, 1784-1866, 2328-2455 | Approval summary, release, oracle and install checks | Remove the review demands | OPEN — scoped install fixed (PR #2231 e701c9fb); native fixture routes unreachable (designflow-backend declares no gate); `authorize-install` is optional. Remaining: theoracle `offline-private-capture-transform` still needs an APPROVE because `tools/oracle_native_alternate_profile.py` admission binds the reviewer report; needs redesign |
| 37 | ai-devops `.ai-devops/task-gates.json` | Reviewer bins, `install.sh` and `update.sh` classed as `reviewer-safety` | Reclassify as code | off — those paths are now class `code` (central rule 0) |
| 38 | theoracle and popdam3 `.ai-devops/task-gates.json` | Files classed as `reviewer-safety` | Reclassify | off — reclassified to `code`: theoracle #313 (59eaa3ae), popdam3 #621 (999e0432) |
| 39 | `/etc/ai-devops/observation-week.json` and `C:\ProgramData\ai-devops\observation-week.json` (5 hosts) | Freeze window; extended to 2026-11-12 | Delete after B | off — window file removed on all 5 hosts (ruling 2026-10-29 night; #2073 proof); absent on edge-dev3 2026-10-31 |
| 40 | `.git/hooks/post-merge` (from `install.sh` ~600 and `bin/ai-install-post-merge-hook`) | Reviewer requalification after every pull | Remove | off — installer stage retires the hook (`install.sh` ~590, Windows `Install-PostMergeHook`; #2073) |
| 41 | ai-devops `install.sh` ~119-189 and `update.sh` ~17-184 | `--reviewer-approval` required | Drop | off — no `--reviewer-approval` in `install.sh`/`update.sh` |
| 42 | ai-devops `install.sh` `protect_review_enforcement` | Protects the enforcement files | Remove | off — `protect_review_enforcement` gone from `install.sh` |
| 43 | Hourly cron `bin/ai-reviewer-logs-sync sync` (`install.sh` ~328) | Log sync | Unschedule and remove | off — `install.sh` only strips the old cron line; `bin/ai-reviewer-logs-sync` deleted (#2131) |
| 44 | ai-devops `config/local-watch.json` | Membership drift and credit-watch jobs | Remove the entries | off — no review entries in `config/local-watch.json` |
| 45 | ai-devops `config/machine-tools.tsv` | Windows reviewer watch tools | Remove the rows | off — no reviewer watch rows remain in `config/machine-tools.tsv` |
| 46 | ai-devops `config/reviewer-start-watch.json` | Start-watch host | Retire | off — start-watch workflow deleted; `config/reviewer-start-watch.json` has no code reader |
| 47 | ai-devops `bin/ai-review*`, `ai-reviewer-*`, `ai-*-review`, `ai-review-posthoc`, `ai-release-live-check` | Old toolchain | Partly resolved (F, #2113): `ai-review-posthoc`, `ai-release-live-check`, `ai-reviewer-membership-drift` deleted; the engine, doors and front door remain (second-opinion wrappers still depend on the sandbox and packet tools) | off — remaining tools are second-opinion support only and gate nothing (F #2131) |
| 48 | ai-devops `.github/workflows/reviewer-membership-drift.yml` | Weekly drift check | Resolved (F, #2113): workflow and tool deleted | off — deleted (#2113) |
| 49 | GitHub lists an `ai-review.yml` workflow before it is on main | It comes from PR #2044, the new workflow | No action | off — no action needed; `ai-review.yml` is on main |
| 50 | ai-devops `verify.yml` `windows-reviewer-safety` | Tests reviewer code | Resolved (F, #2112): lane removed | off — lane removed (#2112) |
| 51 | `templates/system/CLAUDE-global.md` (installed `~/.claude/CLAUDE.md`) | "Reviewers gate technical actions" | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 52 | `templates/system/AGENTS-global-codex.md` and the mimo/zcode variants | The same rules | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 53 | ai-devops `AGENTS.md` ~105-141 | APPROVE rules | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 54 | ai-devops `docs/reviewer-rotation-rules.md` | Rotation rules | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 55 | ai-devops `docs/owner-rulings.md` | Older reviewer rulings | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 56 | `templates/system/REVIEWER-global.md`, `plan_reviewer-observation-week.md` | Reviewer persona; observation-week plan | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 57 | skills `codex/ai-reviewer`, `claude/ai-development-pipeline`, `claude/deploy-and-verify` | Require reviews | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 58 | skills ask-glm, ask-muse, deepseek-second-opinion, stepfun, grok-cli, qwen-code, gemini-code-delegation, kimi-code-delegation, log-reviewer-issue, codex-second-opinion | Rotation wording | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |
| 59 | skill `secrets-to-1password` and the globals | Rotation needs an APPROVE | Resolved (D, #2085; verified empty grep 2026-10-30) | off — verified empty grep (D, #2085) |

## Not checked yet (resolve during C and E)

- The source of "Migration guarded merge authorization".
- shared-db `pr-guards.yml` "Agent work contract".
- shared-db `lane-watchdog.yml` in full.
- shared-db `.claude/skills/**`.
- shared-db `refs/db-review-*` refs.
- Windows scheduled tasks and installed globals on other hosts.
- Ansible-managed timers.
- theoracle and popdam3 CLAUDE.md and docs.
