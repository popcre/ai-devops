---
name: project_helper_storage_regions
description: "POP DAM Helper storage transport is region-based — Brazil=Seafile, USA=SMB to edgesynology1, no fallback"
metadata: 
  node_type: memory
  type: project
  originSessionId: c60620d0-ec82-4fc1-be0d-d07e405b9762
---

POP DAM Helper checkout transport is chosen **per-machine by region**, not by a global flag:
- **Brazil (WFH) users → Seafile/SeaDrive.** Seafile server: https://seafile.designflow.app (Linode VPS in Brazil; 100.92.1.120 on Tailscale, 172.233.14.233 public).
- **USA users → Synology `edgesynology1` over SMB** (direct SMB copy to the mounted share is the chosen check-in write path, replacing File Station HTTP API for USA).
- **Brazil DOES have Seafile→Synology fallback**: when SeaDrive is unavailable, fall back to Synology over **SMB across the Tailscale VPN** (Brazil reaches the NAS via Tailscale). `HELPER_SYNOLOGY_FALLBACK_ALLOWED = true` in admin_config. (Earlier "no fallback" assumption was reversed.)

Region selection (decided, not yet built): installer asks the user once, **prepopulated by IP geolocation**, and the region is **viewable/settable in the PopDAM admin panel** (implies a per-device region stored server-side on helper_devices + admin UI).

Only one PopDAM root exists: `SCAN_ROOTS=["/mnt/nas/mac/Decor"]` → root_id `Decor`. **A root holds multiple Seafile libraries as subfolders**, so a library is matched by **longest path-prefix on relative_path** (not by root_id). The two libraries under Decor (admin_config `HELPER_SEAFILE_LIBRARIES`, seeded 2026-06-07):
- `Decor/Character Licensed` → library `177cf9de-3066-482e-956a-7ae8d8786c6d`, SeaDrive folder `Character Licensed` (~95k assets)
- `Decor/Generic Decor` → library `1b116ab7-d66b-4411-a691-21f34eadb731`, SeaDrive folder `Generic Decor` (~7k assets)

`seaDriveFolder` = the Seafile library name (how SeaDrive mounts it under `~/SeaDrive/<name>`). In-library path = relative_path minus the `Decor/<Library>/` prefix (verified against the live Seafile API). Seafile libraries are a partial mirror of the NAS — unsynced files fall through to the Synology/Tailscale fallback. `HELPER_SEAFILE_SERVER_URL=https://seafile.designflow.app` also seeded (for obj_id/source_version lookups, which need per-designer Seafile tokens stored client-side).

The Seafile-aware first slice shipped in commits a568c33 / 81e2e24 (Helper v1.3.2). Still TODO: region automation (geolocation + admin-panel region + per-device region), USA direct-SMB write path, and capturing the Decor Seafile library UUID/name (needs a proper Seafile **user API token**, not DB/JWT secrets). See [[project_pending]].

**Why:** the transport topology is non-obvious from the code and drove the design away from a single global "preferred provider" flag.
**How to apply:** when touching Helper checkout/provider logic, treat provider as per-machine/region; never wire a Seafile→Synology fallback; keep preferredProvider local (installer/region-set), while the library catalog + fallback policy come from admin_config via helper-api /config.
