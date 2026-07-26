---
name: project-pending
description: "Unfinished work — auto-update cert blockers for popdam-helper, PopSG render backlog"
metadata: 
  node_type: memory
  type: project
  originSessionId: b7861fed-538d-421b-b87c-a3f62725c39a
---

**Auto-update + macOS notarization (blocked on certs):**
`electron-updater` is wired in `apps/popdam-helper/src/main/main.ts`. Blocked on external cert procurement:
- macOS: Apple Developer account ($99/yr) required for Gatekeeper + notarization
- Windows OV cert (~$60–$150/yr): SmartScreen warns on first install but updates work
- Windows EV cert (~$300–$500/yr): no SmartScreen warning

Once certs acquired, add to `publish-popdam-helper.yml`: `CSC_LINK`, `CSC_KEY_PASSWORD` (Windows), `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID` (macOS). Remove `CSC_IDENTITY_AUTO_DISCOVERY=false` from CI env block.

**Why:** No active Apple Developer account. Without it, macOS users must right-click → Open to bypass Gatekeeper. Documented in `HANDOFF.md`.

**PopSG render pass (operational, not dev work):**
Windows Agent is on v0.15.0 with render fixes. Render backlog not fully processed.
Steps: confirm v0.15.0 in Settings → Agents; run Retry All (500-file batches); queue EPS files via "Queue All Renderable" or `queue_sg_render_jobs_by_ids`; check with `select * from get_sg_preview_stats()`.

**How to apply:** Do not start either task without explicit user confirmation. They are tracked in `HANDOFF.md` at repo root.
