---
name: codex-new-application
description: Set up a brand-new POP Creations application repo, documentation, CI/CD, and optional Hetzner/Coolify deployment path. Use when starting a new application, creating a new repo, applying the "new application one big prompt", or deciding how a new app should be deployed to hetz/Hetzner/VPS.
---

# Codex New Application

This is the reusable version of Albert's "new application one big prompt".
Use it to create the app and the operating system around the app: repo, docs,
CI/CD, deployment, secrets handling, and handoff.

## Start With Access

Before building, identify access needed and ask once:

- GitHub org/repo permissions.
- Deployment platform access, usually Coolify on hetz when requested.
- Container registry access, usually GHCR through GitHub Actions.
- Domain/DNS access if a public URL is needed.
- Database/storage/provider access if the app needs it.
- Third-party API credentials, stored as secrets, never pasted into code.

## Repo Setup

1. Create or clone the GitHub repo.
2. Choose the simplest stack that satisfies the product need.
3. Add project-owned code in obvious locations.
4. Add `.gitignore` and ignore build artifacts, dependencies, local config, and
   secret files.
5. Add tests and a normal local verification command.

## Documentation

Use `codex-repo-docs-overhaul` to create the standard docs:

- `README.md`
- `AGENTS.md`
- `docs/architecture.md`
- `docs/development.md`
- `docs/configuration.md`
- `docs/deployment.md`
- `HANDOFF.md` only if work remains unfinished

## CI/CD

Use `codex-cicd-pipeline` for the release path:

- GitHub is code/workflow truth.
- GHCR is the build-artifact truth when containerized.
- Deployment platform owns runtime config and deploy execution.
- Normal path is lint/test/build/publish/deploy with traceable artifacts.

## Hetz / VPS / Coolify Deployment

When the app will deploy to the Hetzner VPS:

1. Prefer GitHub Actions -> GHCR -> Coolify.
2. Store runtime environment variables in Coolify, not server scripts or repo
   files.
3. Use immutable image tags such as `sha-<commit>`.
4. Document the Coolify app/service UUID, domain, image, health check, env var
   names without values, and rollback path in `docs/deployment.md`.
5. Verify deploy by CI status, image/tag existence, Coolify deployment status,
   and the live app's served build SHA or equivalent health/version endpoint.

## Final Report

Report repo URL, stack, docs created, CI/CD path, deployment target, secrets
locations by name only, verification results, and next steps.
