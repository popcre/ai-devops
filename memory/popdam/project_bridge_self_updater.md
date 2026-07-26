---
name: project_bridge_self_updater
description: "Bridge agent Docker self-updater is fragile — invariants that must not be broken, and the safe way to work around it"
metadata: 
  node_type: memory
  type: project
  originSessionId: addd8242-3b96-43fd-a2fe-e4fe8931f2b9
---

The Synology bridge agent's Docker self-update (`apps/bridge-agent/src/index.ts` `handleApplyUpdate` + `recreateViaDockerRun`) is **extremely fragile** — took ~50 iterations to stabilize and has been re-broken by later edits several times. The user has explicitly warned: do not break it. **Default stance: do NOT modify it.** Prefer making failures *observable* over changing the recreate logic.

**Why it's like this:** the agent runs inside a container on the NAS with no access to the host `docker-compose.yml`, so it drives Docker via the mounted socket. The container is `docker run`-managed by design (not compose-tracked) — so manual `docker compose down` won't see it ("Running 0/0"), and the recovery is `docker rm -f popdam-bridge && docker compose up -d`.

**Hard invariants (per docs/KNOWN_QUIRKS.md #26, docs/DEPLOYMENT.md ~145-151):**
1. New container MUST be named the canonical `POPDAM_CONTAINER_NAME || "popdam-bridge"` every cycle — never derived from the current (possibly-mutated) name. This is THE fix for name-accumulation (`popdam-bridge-old-123-old-456…`).
2. Ordering must not be reordered: inspect self → `docker rename` self to `-old-<ts>` (frees the name) → `docker run --name <canonical>` new → prune graveyard → suppress SIGTERM → `docker stop`+`rm` self → exit. New container must be up BEFORE self is removed.
3. SIGTERM must be suppressed (`removeAllListeners`+no-op) before stopping self, or node dies mid-cleanup and orphans the old container.
4. Self-update pulls `:stable` only — never repoint to `:latest`. Keep `:ro` stripped from cloned binds. `restart: unless-stopped` and `/var/run/docker.sock` mount must stay.

**Critical side effect:** ANY change under `apps/bridge-agent/**` triggers `publish-bridge-agent.yml` → new `:stable` → every agent self-updates. So editing the agent *forces* the risky update path to run fleet-wide. Avoid unless necessary.

**The safe alternative (built 2026-06-09):** detect drift instead of preventing it. The admin Settings → Bridge Agents panel now compares the agent's reported `build_sha` to `BRIDGE_LATEST_BUILD.sha` (via admin-api `get-latest-agent-build`, which now returns `sha`). "Up to date" is sha-based, and a stale/half-failed update shows a red "Build mismatch" badge with the manual fix. This replaced the old version-STRING comparison, which falsely showed "up to date" on a stale image. Related: [[project_checkin_verification]].

**KNOWN FALSE-POSITIVE in the sha drift detector (characterized 2026-06-21):** the "Build mismatch — reports vX but running sha:OLD, not published sha:NEW" badge fires even when the agent IS correctly running the new image. Root cause: `recreateViaDockerRun` (`index.ts` ~line 1705) clones the OLD container's *entire* `.Config.Env` as explicit `-e` flags onto the new container. Explicit `-e` beats the new image's baked `ENV`, so `POPDAM_BUILD_SHA`/`POPDAM_IMAGE_TAG` are FROZEN at the FIRST-ever image's values (e.g. stuck at 8340ef9/v1.16.0 while genuinely running a35414d/1.16.3) and re-inherited every update. The image is fine — verify true revision via `docker inspect <img> --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'` (correct) vs the container's `-e POPDAM_BUILD_SHA` (stale). This install has NO compose labels (`com.docker.compose.*` empty) so the updater ALWAYS takes this env-cloning `docker run` path; the stamp can never self-correct. Fix options: (a) filter `POPDAM_BUILD_SHA`/`POPDAM_IMAGE_TAG` out of the cloned env in `recreateViaDockerRun` — but that edits the sacred updater AND only clears one update cycle later (the buggy running updater does the next recreate); (b) make the detector trust the agent-reported `version` (correct from package.json) or the OCI revision label instead of `build_sha`. The agent's `version` field IS reliable; only `build_sha`/`image_tag` are frozen.
