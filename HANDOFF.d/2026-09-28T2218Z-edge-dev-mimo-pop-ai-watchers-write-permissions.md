---
issue: none                          # no GitHub issue; wrap-up scope freeze blocked opening one
status: OPEN
owner: mimo/pop-ai-watchers-write-permissions
---

# Handoff — pop-ai-watchers write permissions (statuses + pull requests)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking**

1. **Accept the new GitHub App permissions on both installations** (clicks only; no code).
   - popcre org installation: https://github.com/organizations/popcre/settings/installations/165894752
   - u2giants user installation: https://github.com/settings/installations/165895025
   - Why: the app registration now requests write on Statuses and Pull requests, but both installs are still on the old read-only grant. Write APIs stay 403 until each account accepts.
   - Recommendation: accept both now (two clicks). Success looks like `gh api orgs/popcre/installations` and the app JWT list showing `statuses: write` and `pull_requests: write` on those two installs.

2. **Open a tracking issue for this workstream** (recommended, one minute).
   - Why: the handoff contract wants an issue that proves the work finished; wrap-up scope freeze forbade opening it in this session.
   - Recommendation: open `popcre/ai-devops` issue titled “Accept pop-ai-watchers statuses/PR write on both installations”, then paste its number into the `issue:` field at the top of this file.

**Already settled — do NOT re-ask**

- 2026-09-28: App-level write on **Pull requests** and **Statuses** was granted in the GitHub UI by the owner. Do not redo the app registration edit.
- 2026-09-28: `gh` CLI / public REST **cannot** change GitHub App permissions. Do not spend another session searching for an API.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan’s public AI development-operations toolkit (review wrappers, BlockerWatch, installers, skills). It is not a deployed app.

The object in this workstream is the **GitHub App** `pop-ai-watchers` (slug `pop-ai-watchers`, app id `5112061`), owned by the **popcre** organization. Background jobs (BlockerWatch scheduled ticks via `bin/ai-blocker-watch` → `bin/ai-gh-app-auth`) authenticate as this app so they do not burn Albert’s personal GitHub API quota.

- Public app page: https://github.com/apps/pop-ai-watchers
- Org app settings: https://github.com/organizations/popcre/settings/apps/pop-ai-watchers
- Permissions UI tab: https://github.com/organizations/popcre/settings/apps/pop-ai-watchers/permissions
- Installations: popcre `165894752`, u2giants `165895025`

## 2. What we set out to do this session, and why

**Business goal:** let `pop-ai-watchers` post commit statuses and work with pull requests (create/comment/label as needed) instead of only reading them.

**Trigger:** explicit owner request — “use gh cli to give the pop-ai-watchers connection permission to write statuses and pull requests.”

**Technical objective:** raise GitHub App permissions `statuses` and `pull_requests` from `read` to `write`, and make that grant live on both installations.

## 3. Current state — what is true right now

| Layer | statuses | pull_requests | Evidence |
|---|---|---|---|
| App registration (definition) | **write** | **write** | `gh api apps/pop-ai-watchers` at wrap-up |
| popcre install `165894752` | read | read | app JWT `GET /app/installations`; also listed `?outdated=true` |
| u2giants install `165895025` | read | read | same |

- Owner completed the app-registration edit in the UI (Permissions & events → Repository permissions). Pull requests was confirmed first; Statuses was later present on the registration (`statuses: write`).
- **The grant is NOT live.** Both installations are outdated relative to the app. A real write probe failed:

```text
POST /repos/popcre/ai-devops/statuses/<HEAD>  as popcre install token
→ HTTP 403 {"message":"Resource not accessible by integration"}
```

- `GET /app/installation-requests` is empty — permission *updates* on existing installs are not that queue; they are accepted per-account in the UI/email.
- No repository code was changed this session. Nothing to deploy.

## 4. Everything we tried that did NOT work

1. **`PATCH /apps/pop-ai-watchers`** (user token `u2giants`, JSON body `default_permissions` / name-only) → **HTTP 404**. Same with `PATCH /apps/5112061`, `PATCH /orgs/popcre/apps/pop-ai-watchers`, `PATCH /app`, app JWT. GitHub’s current public OpenAPI lists only **`GET /apps/{app_slug}`** — update is not a public endpoint anymore. Docs for “Changing the permissions of a GitHub App” describe the **web UI** path only (Permissions & events).
2. **GraphQL mutations** — enumerated; no app-permission update mutation.
3. **Installation access token with `permissions: {statuses:write, pull_requests:write}`** → rejected: “The level of access for permissions requested are not granted to this installation.” Tokens cannot exceed the install grant.
4. **Scoped user token** (`POST /applications/{client_id}/token/scoped`) cannot grant permissions the app/install was not granted — not used as a workaround.
5. **Wrong UI page first:** `…/settings/apps/pop-ai-watchers` is Basic information. Controls are under **Permissions & events** (`…/apps/pop-ai-watchers/permissions`). **Statuses** is a long Repository-permissions row near the bottom (commit statuses) — distinct from **Checks**. Owner did not see it at first until told to scroll.

## 5. Root causes and key findings

- App registration vs installation are separate grants. Changing the registration does **not** lift existing installs; each account must accept. Until then tokens stay at the old ACL and 403.
- GitHub removed/withdrew the public “Update a GitHub App” REST method from the current API description; `gh` cannot do this job. UI is the supported path (`docs.github.com` → Modifying a GitHub App registration → Changing the permissions of a GitHub App).
- `bin/ai-gh-app-auth` already has the app key on this machine (`~/.ai-devops/github-app/pop-ai-watchers.pem`) and can mint install tokens; it is fine for verification probes. Key material is also in 1Password `vibe_coding` / item title `GitHub App - pop-ai-watchers`.
- App is org-owned by `popcre`; `u2giants` is an org **admin**. Still no API update path.

## 6. Exact next steps

1. Open the two installation pages (already opened in this session’s browser):
   - https://github.com/organizations/popcre/settings/installations/165894752
   - https://github.com/settings/installations/165895025  
   Accept / update the app to the new permissions if prompted.  
   *You’ll know it worked when* the page shows Statuses and Pull requests as Read and write.

2. Verify from this machine (Git Bash):

```bash
gh api apps/pop-ai-watchers --jq .permissions
# expect statuses=write, pull_requests=write (already true)

# installation JWT (same recipe as bin/ai-gh-app-auth)
# GET /app/installations  → both installs show statuses/write and pull_requests/write
```

   *You’ll know it worked when* both install permission objects list `statuses: write` and `pull_requests: write`, and neither shows under `?outdated=true`.

3. Live write probe (safe, reversible): create a throwaway commit status on `popcre/ai-devops` HEAD with context `pop-ai-watchers/permission-probe`, then delete nothing (statuses are append-only; a success status is harmless) or use a non-default SHA.  
   *You’ll know it worked when* `POST …/statuses/…` returns **201** not 403.

4. Optional PR write probe: comment on a test PR with the app token or open/close a draft PR.  
   *You’ll know it worked when* the comment/PR appears authored by `pop-ai-watchers` / the app.

5. Open the tracking issue from §0 item 2 and put its number in the `issue:` block of this file, then commit this file alone (docs-only).

6. When both installs are verified write-capable and the issue is closed, delete this `HANDOFF.d/` file (successor rule).

## 7. Constraints and gotchas in force

- `popcre/ai-devops` `main` is protected: branch + PR + merge queue. Docs-only PRs may be squash-merged immediately (`gh pr merge --squash --admin`) if every changed file is prose. Stage **only** this file; this checkout has other sessions’ dirty paths.
- Never edit another session’s `HANDOFF.d/` file; never rewrite root `HANDOFF.md` (static pointer, already `handoff-pointer: v1`).
- Do not “fix” installation permissions by recreating the app or rotating keys — that breaks BlockerWatch.
- Do not retry `PATCH /apps/...`; it 404s.
- GitHub App permission names in the UI: **Statuses** (commit statuses) ≠ **Checks** (check runs). Both are useful; this request was **Statuses** and **Pull requests**.
- BlockerWatch already falls back to the personal login if the app has no key (`ai-gh-app-auth` exit 3). Unrelated.

## 8. Access and environment

- Machine nickname: **edge-dev** (hostname `edge-dev`).
- `gh` logged in as **u2giants** (scopes `admin:org`, `gist`, `repo`, `workflow`). Org role on popcre: **admin**.
- App key on this host: `~/.ai-devops/github-app/pop-ai-watchers.pem` via `bin/ai-gh-app-auth install` (1Password vault **`vibe_coding`**, item **`GitHub App - pop-ai-watchers`**). Never print or commit the PEM or tokens.
- Verification helper: `bin/ai-gh-app-auth token popcre` / `token u2giants`.
- No new secrets were created this session.

## 9. Open questions and risks

- **(2026-09-28)** If the installation pages do not show an accept/update control, use the email GitHub sends to the org owner / user (“would like to update its permissions”) or Organization settings → GitHub Apps → POP AI Watchers → update/accept. If nothing is offered within a day, GitHub may need the app saved once more from the Permissions & events tab to emit the request.
- **(2026-09-28)** `issues: write` is already granted; adding write on pull requests may allow the app to close/label PRs. Owner accepted that breadth in the UI already.
- **(2026-09-28)** Repo working tree also has unrelated dirty paths from other sessions (`scripts/ai-housekeeping/move-bulk-to-d.ps1`, `HANDOFF.d/2026-09-20T0029Z-edge-dev-kimi-grok-trap-exit-status.md`). Do not stage, revert, or “clean” them.

---

## Self-audit (Mode A)

1. **New developer cold start?** Yes — §1 names the app/ids/URLs; §3 table is live state; §6 is click/verify ordered.
2. **As effective as this session?** Yes — §4 dead ends stop repeats; §5 explains registration vs install; exact HTTP evidence recorded.
3. **Every relevant detail?** Yes — goal, state, failures, constraints, access (vault name only), risks, verification gates on each next step.
4. **Owner reading only §0?** Yes — the only owner actions are accept-both-installs and open-issue; both appear with URLs and a one-word recommendation. Nothing else in §1–§9 needs a ruling.
