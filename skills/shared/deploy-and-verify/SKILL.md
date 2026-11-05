---
name: deploy-and-verify
description: "Ship and verify a deploy for the hetz/Coolify/GHCR apps (poppim-web, popcrm-web, popdam3, monitor, hiclaw) and the Vercel web of theoracle. Use for \"push and commit\", \"is everything pushed and committed?\", \"the live site is still running the old commit\", \"site looks exactly like it did before\", or \"there are no new actions on github.com\" IN THOSE REPOS. DesignFlow repos use `dflow-ship`. Shared by Claude, Codex, ZCode and MiMo."
---

# deploy-and-verify

The u2giants apps deploy GitHub → Actions → GHCR → Coolify (theoracle's web
deploys GitHub → Vercel). **A deploy is not done until the running version on
the live site matches the merged commit** — a green pipeline alone does not
mean the site runs the new version. This skill bakes in the proof step and the
known deploy quirks.

## Trigger phrases

**Only when the working copy is a hetz/Coolify app repo** (poppim-web,
popcrm-web, popdam3, monitor, hiclaw — deploy via GHCR + Coolify on branch
`main`) **or theoracle's web** (GitHub → Vercel). If it's a dflow repo
(`popcre/designflow-*`, branch `sandbox-albert`), use `dflow-ship` instead —
same phrases, different pipeline. When in doubt, check `git remote -v`.

- "push and commit" / "is everything pushed and committed?"
- "the live site is still running the old commit <sha>"
- "site looks exactly like it did before" / "no visual change"
- "there are no new actions on github.com"

## Procedure

1. **Commit to `main`** (single-branch policy for all u2giants app repos).
   Author: `Albert Hazan <u2giants@users.noreply.github.com>`.
2. **Push and wait for Actions.** Wait with `ai-gh-wait` or `ai-pr-wait` (at most one
   GitHub call every 5 minutes, always with a deadline); never `gh run watch` (#401). A local-only
   commit that was never pushed has burned sessions before — verify the SHA is
   on origin/main.
3. **Verify GHCR** published the image (`ghcr.io/u2giants/<app>` with a
   `sha-<commit>` tag).
4. **Pin and trigger Coolify with an immutable tag.** Never deploy `latest` or
   `main` — pin the app to `sha-<full-commit-sha>` first, fail closed if the
   pin refuses, then trigger the deploy.
   - **QUIRK-1:** poppim-web (and any Coolify *service*, vs *application*) must be
     restarted via `GET /api/v1/services/{uuid}/restart`, with its
     `docker_compose_raw` patched to the `sha-<full-sha>` image first. The
     `/api/v1/deploy?uuid=` endpoint silently no-ops for services.
   - Coolify *applications* pin via
     `PATCH /api/v1/applications/{uuid}` with `docker_registry_image_tag`.
   - Coolify API: use the authenticated `https://coolify.designflow.app` endpoint;
     token in 1Password (`vibe_coding`). Never send the token over plaintext.
5. **Verify the live version — the deploy is not done until this passes.**
   - Read the running version from the app's **known version path** (below) and
     compare its `git_sha` with the merged commit:
     `scripts/verify-live-version.sh --url <known-path> --expected <merged-commit>`.
     It polls with a deadline, fails closed on an unreadable document, and a
     mismatch exits 1 with `LIVE VERSION MISMATCH` naming both values.
   - **QUIRK-2 (updated):** `/version.json` IS the known path for the apps
     below — it is served `no-store` ahead of any SPA fallback. The old
     HTML-grep for `<meta name="build-sha">` remains only for apps with no
     version endpoint yet (hiclaw). Never say "live" without the check passing.
   - Each app also carries `scripts/test-verify-live-version.sh` (fixture-only,
     no network): a matching version passes and a deliberately stale check
     fails. Run it before shipping any change to the check itself.
6. **Report:** commit SHA, Actions run URL, image tag, the live version read,
   all in plain English. If any gate failed, say which and what you're doing
   about it. If an app cannot expose a version or has no deploy workflow to
   fail (see below), say so honestly — never fake a passing check.

## Known version paths

| App | Known path | Notes |
|---|---|---|
| poppim-web | `https://pm.designflow.app/version.json` | baked by the image; Coolify *service* (QUIRK-1) |
| popcrm-web | `https://crm.designflow.app/version.json` | baked by the image |
| popdam3 | `https://dam.designflow.app/version.json` | baked at build |
| synology-monitor (web) | `https://mon.designflow.app/version.json` | baked by the image; served past the auth middleware |
| theoracle (web) | `https://oracle.designflow.app/version.json` | Vercel builds from GitHub (`VERCEL_GIT_COMMIT_SHA`); the check is the `verify-live-version` workflow. `theoracle-i0o6ilexa-popcre.vercel.app` is behind Vercel SSO — do not use it for checks |
| hiclaw | none yet | fall back to the HTML grep (QUIRK-2) until it gains an endpoint |
| theoracle (brain) | none | deploys MANUALLY via Coolify `BRAIN_IMAGE_TAG` ("a separate, reviewed action") — there is no deploy workflow to fail; its image already publishes immutable `sha-<sha>` tags. Verify by hand before reporting a brain deploy live |

## Domains

pm=poppim-web, crm=popcrm-web, dam=popdam, mon=synology-monitor,
sg=PopSG (same image as dam, mode by hostname) — all `.designflow.app`;
theoracle web = `oracle.designflow.app`.
