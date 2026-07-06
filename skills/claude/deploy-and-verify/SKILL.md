---
name: deploy-and-verify
description: Ship and verify a deploy for the Coolify/GHCR apps on the hetz VPS (poppim-web, popcrm-web, popdam3, monitor, hiclaw). Use when the user says "push and commit", "the live site is still running the old commit", "site looks exactly like it did before", or "there are no new actions on github.com".
---

# deploy-and-verify

The u2giants apps deploy GitHub → Actions → GHCR → Coolify. Two known quirks
have repeatedly made deploys *look* broken; this skill bakes in the fixes.

## Trigger phrases

- "push and commit" / "is everything pushed and committed?"
- "the live site is still running the old commit <sha>"
- "site looks exactly like it did before" / "no visual change"
- "there are no new actions on github.com"

## Procedure

1. **Commit to `main`** (single-branch policy for all u2giants app repos).
   Author: `Albert Hazan <u2giants@users.noreply.github.com>`.
2. **Push and watch Actions.** `gh run watch` (or poll) until green. A local-only
   commit that was never pushed has burned sessions before — verify the SHA is
   on origin/main.
3. **Verify GHCR** published the image (`ghcr.io/u2giants/<app>` with a
   `sha-<commit>` tag).
4. **Trigger/verify Coolify.**
   - **QUIRK-1:** poppim-web (and any Coolify *service*, vs *application*) must be
     restarted via `GET /api/v1/services/{uuid}/restart`. The
     `/api/v1/deploy?uuid=` endpoint silently no-ops for services.
   - Coolify API: `http://<removed-protected-address>:8000` / https://coolify.designflow.app;
     token in 1Password (`vibe_coding`).
5. **Verify the live SHA.**
   - **QUIRK-2:** don't fetch `version.json` — Caddy/Traefik `try_files`
     intercepts it. Instead grep the served HTML for `<meta name="build-sha">`.
   - Confirm it matches the pushed commit before saying anything is live.
6. **Report:** commit SHA, Actions run URL, image tag, deployed SHA, all in
   plain English. If any gate failed, say which and what you're doing about it.

## Domains

pm=poppim-web, crm=popcrm-web, dam=popdam, mon=synology-monitor,
sg=PopSG (same image as dam, mode by hostname) — all `.designflow.app`.
