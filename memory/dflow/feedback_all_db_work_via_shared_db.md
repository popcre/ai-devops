---
name: feedback_all_db_work_via_shared_db
description: All shared-Supabase DB changes must be authored/applied through the u2giants/shared-db repo
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5398de33-e7ff-49c8-a5a3-1529add38755
---

**All DB work must go through `https://github.com/u2giants/shared-db`** (local clone `C:\repos\shared-db`). The user corrected me after I fixed a bug by (a) running a direct `ALTER` on the shared sandbox DB via psycopg and (b) adding an inline migration to `designflow-backend/models/db.js`. Both are wrong as the canonical path — even the legacy `dflow` schema now goes through shared-db (a concurrent session added `20260710140000_dflow_product_user_assignment.sql` there).

**Why:** the shared Supabase project `qsllyeztdwjgirsysgai` backs CRM/DAM/PIM/PM/PLM; ad-hoc DDL or app-repo-only migrations cause drift and can break other apps.

**How to apply (see the `shared-db-change` skill + `C:\repos\shared-db\AGENTS.md`):**
- shared-db is branch + PR, and the AI merges once §4 checklist passes (all app repos are main-only; shared-db is the exception).
- New `YYYYMMDDHHMMSS_*.sql` migration file; additive/idempotent; never edit an applied migration.
- Apply via the Supabase CLI: `supabase login --token "$SUPABASE_ACCESS_TOKEN"` (env-only token FAILS — must `login --token`), then `supabase link --project-ref <ref>`, `supabase db push --dry-run`. Preview ref `xjcyeuvzkhtzsheknaiu` first, then prod `qsllyeztdwjgirsysgai`. Creds in 1Password vibe_coding: "Supabase CLI Personal Access Token", "Supabase DB Password - shared POP database".
- The CI workflow `shared-supabase-migrations.yml` applies only via manual `workflow_dispatch`; merging to main just syncs the `shared-db/` folder into app repos (no DB apply). **CI apply is currently broken**: it passes the PAT as env only to `supabase link`, which returns Unauthorized — it should `supabase login --token` first.

**Gotcha hit 2026-07-10:** `db push --dry-run` on prod errored "Remote migration versions not found in local migrations directory" (`20260710093340`) — pre-existing history drift + concurrent in-flight work. Per AGENTS.md §3.1/§5, serialize and do NOT run `migration repair`/`db pull`/`db push` to reconcile someone else's work; surface and ask.

**Enforcement + delivery now in place (2026-07-10):**
- **CI guard** `.github/workflows/shared-db-guard.yml` (template in `u2giants/ai-devops` `templates/ci/`) fails any PR making app-side DB/DDL/migration changes outside the vendored `shared-db/` folder; override label `db-change-approved`. Wired into all 6 designflow repos (on sandbox-albert; active on develop after Uma merges). Other app repos (popcrm-web, poppim-web, popdam, directus): install via the curl one-liner in `ai-devops/templates/ci/README.md`.
- **Codex skill** `codex-shared-db-change` added to `ai-devops/skills/codex/` (Codex previously had none). Claude has `shared-db-change`. Skills force-update on every `ai-devops` install/update run → reach all machines/both tools.
- **Global seed templates** `ai-devops/templates/system/{CLAUDE-global,AGENTS-global-codex}.md` now carry the explicit hard rule (never app-repo migrations / direct DDL). NOTE: the installer seeds `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` **only-if-missing**, so existing machines get the rule via the skill + repo AGENTS.md, not a global overwrite.
- Root cause of misses = app-repo docs that taught the legacy inline-migration pattern (e.g. designflow-backend CLAUDE.md/AGENTS.md — since fixed) + no enforcement. Docs alone lose to a contradictory local doc; the CI guard is the real fix.
- **Canonical CI guard = `.github/workflows/forbid-shared-db-bypass.yml`** (identical across all 6 designflow repos; documented in designflow-backend AGENTS.md §324). DO NOT add a second guard (I mistakenly added `shared-db-guard.yml` and removed it). Change it in all 6 repos together per the shared-db-gatekeeper cross-repo rule. It blocks: app-repo `supabase/migrations/*.sql`, Supabase mutation commands in workflow/scripts/package files, and — as of 2026-07-10 — **NEW inline SQL DDL added to `.js/.ts` source** (e.g. `sequelize.query('ALTER TABLE…')` in models/db.js). Override for legacy retirement/emergency: put `[shared-db-approved]` in a commit message.
- **grep ERE gotcha (bit me here):** in GNU grep `-E`, `\+` is the one-or-more QUANTIFIER, not a literal `+`. `grep -v '^\+\+\+'` therefore strips EVERY `+` line, silently no-opping a diff scan. Use character classes: `grep -E '^[+]' | grep -vE '^[+][+][+]'`. Always test a CI guard end-to-end (block + override + false-positive) before trusting it.
- **ai-devops delivery was Windows-only for skills**: `install-ai-devops-windows.ps1` copies skills to ~/.claude/skills + ~/.codex/skills, but the Ubuntu `install.sh` did NOT (only deps/config/bin symlinks). Fixed 2026-07-10 — `install.sh` now installs skills + seeds globals like the Windows one, so `update.sh` delivers skills on Ubuntu too. To deliver on any machine: Windows → rerun `bin/install-ai-devops-windows.ps1`; Ubuntu → `cd /worksp/ai-devops && git pull && ./update.sh` (as the normal user, not sudo).
- **Directus is deprecated** — do not list it as a shared-db consumer. Consumers = designflow (PLM, 6 repos), popcrm-web (CRM), poppim-web (PM/PIM), popdam (DAM). shared-db/AGENTS.md still references directus (stale, ~5 places) — needs a docs PR.

Related: [[project_dflow_local_frontend_testing]], [[project_seeded_item_images]].
