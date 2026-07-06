---
name: cicd-rules-audit
description: Audit a repo's CI/CD against Albert's operating rules (GitHub = code truth, GHCR = artifacts, Coolify = runtime config, no SSH deploys, single-branch main). Use when the user pastes the "CI/CD/DevOps Operating Rules", asks "does this conform to our ci/cd pipeline rules", or requests CI/Coolify hardening.
---

# cicd-rules-audit

Albert pasted his full CI/CD rules document 8+ times across sessions. The
complete canonical text is in [CICD-RULES.md](CICD-RULES.md) — read it when this
skill triggers. Core summary:

- **System of truth:** GitHub = code/workflows/compose files; container
  registry (GHCR) = build artifacts; deployment platform (Coolify) = runtime
  env vars, domains, health checks, deploy execution. Production servers are
  runtime hosts, never configuration sources.
- **Normal path:** Actions verifies → builds → publishes to GHCR → triggers
  Coolify via API/webhook → Coolify pulls and runs. Pipeline shape
  `lint → test → build → publish → deploy` using native `needs` dependencies.
- **Forbidden in the normal path:** Actions SSH-ing into prod, editing server
  files, `docker run`/`docker compose up` on the server, restarting services
  directly, runtime config in workflow shell steps. SSH deploys are break-glass
  only.
- **Images:** publish immutable `sha-<commit>` tags alongside `main`.
  Rollback = redeploy a previous immutable tag through Coolify.
- **Branch policy:** single-branch `main` for all u2giants app repos
  (exception: shared-db uses branch+PR, Claude merges).
- **Enforcement over documentation:** remove SSH deploy steps and stale SSH
  keys from Actions secrets so the wrong path is hard to reintroduce.

## Audit procedure

1. Read `.github/workflows/*`, Dockerfile/compose files, and the repo's deploy
   docs.
2. Check each rule in CICD-RULES.md; list violations with file:line.
3. Fix the violations (workflow edits, secret cleanup recommendations).
4. Write the app-tailored subset of the rules into the repo's docs
   (`docs/deployment.md` or AGENTS.md routing note) so future sessions comply
   without the paste.
5. Report in plain English: conforms / violations found+fixed / anything
   needing Albert (e.g. deleting an Actions secret).
