---
name: project_checkin_verification
description: "Seafile check-in receipt verification — deployed dark behind a flag, pending activation"
metadata: 
  node_type: memory
  type: project
  originSessionId: addd8242-3b96-43fd-a2fe-e4fe8931f2b9
---

Seafile check-in **receipt verification** shipped 2026-06-09 (commit 8340ef9, bridge-agent v1.16.0). Seafile-sourced check-ins park in `asset_checkouts.status='verifying'` (lock held) until the bridge agent on the NYC Synology confirms the uploaded file landed intact via **size + quick-hash** (head+tail+size, ~128KB read — chosen to keep Synology I/O low). Stuck check-ins: flag at 30m, re-drive the helper's retained snapshot up to 2×, auto-resolve at 2h by releasing the lock into `error` with diagnostics (no work lost — snapshot retained). Deadlines freeze while the verifier is offline.

**ACTIVE** as of 2026-06-09 ~22:43 EDT: `admin_config.CHECKIN_VERIFICATION_ENABLED = true` (jsonb true). Flag read in `helper-api` `complete-checkin`. To roll back: set it to `false` — Seafile check-ins then complete immediately again, no redeploy. The bridge agent on **edgesynology2** (`synology-bridge-1`) is confirmed running v1.16.0 (build_sha 8340ef9, image_tag v1.16.0).

**Bridge agent update gotcha (hit during this rollout):** the agent's self-update left an orphaned `popdam-bridge` container that `docker compose down` couldn't remove (it had drifted out of the compose project / relabeled), so a pulled image silently never became the running container — DB showed `version=1.16.0` but `image_tag/build_sha` stuck at the old v1.9.6. Fix is manual on the NAS: `sudo docker rm -f popdam-bridge && sudo docker compose up -d --remove-orphans` in `/volume1/docker/popdam`. Verify the swap via `agent_registrations.metadata->'version_info'` — version AND image_tag AND build_sha must all match the intended commit. Docker is blocked on the synology-monitor MCP, so this step needs the user's sudo SSH.

**Old helper caveat:** old helpers call `progressCallback(100)` unconditionally and mark the checkout locally complete even when the server returns `status:'verifying'` — lock is still held + verified server-side (safe), but those helpers won't show the verifying state or perform re-drives (stuck check-ins fall back to the 2h auto-resolve). New helpers handle it fully.

Tuning knobs are plain constants: `VERIFY_FLAG_MS` (30m), `VERIFY_RESOLVE_MS` (2h) in helper-api; `VERIFY_MAX_REDRIVE` (2), `VERIFY_FREEZE_GAP_MS` (90s) in agent-api. Related: [[project_helper_storage_regions]] (Brazil=Seafile).

**Heads-up for editors:** this repo's working tree was observed silently reverting uncommitted changes mid-session (external `git` reset/format). Verify edits are still on disk right before committing, especially large files like `supabase/functions/agent-api/index.ts`.
