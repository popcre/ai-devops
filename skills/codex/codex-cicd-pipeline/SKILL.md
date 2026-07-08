---
name: codex-cicd-pipeline
description: >-
  Create, audit, or repair the standard CI/CD pipeline: GitHub as code truth,
  GHCR as build artifact registry, deployment platform/Coolify as runtime and
  deploy owner, no routine SSH production deploys. Use when the user references
  devops procedure deploying from github.docx, CI/CD rules, pipeline setup,
  GitHub Actions, GHCR, Coolify, hetz, deploy verification, or production drift.
---

# Codex CI/CD Pipeline

Use this when creating or auditing deployment flow.

## Full Rules

Read `references/cicd-rules.md` when this skill triggers. Summary:

- GitHub is source of truth for code, Dockerfiles, Compose, workflows, and
  deployment docs.
- GHCR/container registry is source of truth for build artifacts.
- Coolify/deployment platform owns runtime env vars, domains, health checks,
  restart policy, deployment target settings, and deploy execution.
- Production servers are runtime hosts, not configuration sources.
- Normal path: lint/test/build -> publish immutable image -> deploy through the
  deployment platform -> verify live state.
- Routine SSH deploys, manual server file edits, and server-side `docker run`
  release paths are forbidden except documented break-glass recovery.

## Create Or Audit

1. Read `.github/workflows/*`, Dockerfile/Compose files, deployment docs, and
   repo `AGENTS.md`.
2. Check the full rules in `references/cicd-rules.md`.
3. Fix or propose fixes for violations.
4. Ensure deploy inputs are explicit and secrets are in the right place:
   GitHub Actions for CI/build-time needs; deployment platform for runtime env.
5. Publish immutable image tags, normally `sha-<commit>`.
6. Add rollback instructions using previous immutable artifacts.
7. Document the app-specific path in `docs/deployment.md`.

## Verify

Report:

- workflow files inspected/changed,
- build/test status,
- image tag,
- deployment trigger and status,
- live app version/SHA or health evidence,
- remaining manual actions, such as deleting obsolete GitHub Actions secrets.
