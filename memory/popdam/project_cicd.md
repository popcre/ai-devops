---
name: project-cicd
description: "Frontend deploy architecture — Coolify API trigger, no SSH; stable Traefik service name; sg.designflow.app routing"
metadata: 
  node_type: memory
  type: project
  originSessionId: b7861fed-538d-421b-b87c-a3f62725c39a
---

Frontend deploy uses Coolify API trigger (not SSH). `.github/workflows/publish-frontend.yml` calls `/api/v1/deploy?uuid=qxj8a0j3tpa9lq4q5rs6pezy&force=false`.

Coolify app UUID for `popdam-frontend`: `qxj8a0j3tpa9lq4q5rs6pezy`. Both `dam.designflow.app` and `sg.designflow.app` resolve to this container.

`dam.designflow.app` is routed via Coolify's Docker labels. `sg.designflow.app` is routed via Traefik file provider at `/data/coolify/proxy/dynamic/popdam-sg.yml` on the VPS host. File must use `service: "https-0-qxj8a0j3tpa9lq4q5rs6pezy@docker"` (the `@docker` suffix is required for cross-provider references in Traefik v3).

nginx must listen on `[::]:80` as well as `80` — Coolify's health check resolves `localhost` to `::1` on IPv6 hosts; without IPv6 listener the container is marked unhealthy and Traefik stops routing.

Required GitHub Secrets: `GHCR_PAT`, `COOLIFY_TOKEN`, `COOLIFY_APP_UUID` (`qxj8a0j3tpa9lq4q5rs6pezy`), `COOLIFY_URL` (`https://coolify.designflow.app`). `VPS_SSH_KEY` was removed (SSH deploy is prohibited).

**Why:** User's CI/CD Operating Rules prohibit GitHub Actions from SSH-ing into the production server. Coolify was already managing the container — CI was bypassing it. Migrated 2026-05-15.

**How to apply:** Never add SSH-based deploy steps. All production deploy triggers go through the Coolify API.
