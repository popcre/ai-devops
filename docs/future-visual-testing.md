# Future: Visual Testing

Placeholder for the automated visual-testing harness. To be built out when UI
verification is wired into the workflow.

> Not built yet. Design sketch only. The per-repo companion doc is
> `templates/repo-docs/docs-ai-visual-testing.md`.

## Goal

Give the workflow a reliable way to answer: *"Does the UI still look and behave
correctly after this change?"* — automatically, as part of Stage 05 (Test) and
the `visual-review` gate.

## Intended stack

- **Playwright** to drive a real browser and capture screenshots.
- **Visual regression** comparison against committed baselines where practical.
- Runs headless in CI and locally.

## Planned flow

1. Stage 01 plan sets **"Visual testing needed? yes/no."**
2. If yes, Stage 05 runs the Playwright visual suite:
   - key states: default, loading, empty, error, success;
   - viewports: at least one mobile + one desktop.
3. `ai-codex-review visual-review` gives a read-only second opinion on what
   should have been verified.
4. Screenshots/diffs are attached to the PR / completion report.

## Open questions to resolve when building

- Where do baselines live (per-repo `tests/visual/` vs. artifact storage)?
- How are baselines updated safely (avoid rubber-stamping regressions)?
- Which flows are worth automating vs. manual spot-checks?
- How to keep flaky rendering (fonts, animations) from causing false diffs?

## Where it will live

A future `ai-visual-test` helper (and optional Playwright config templates) will
be added to the toolkit. Until then, follow the manual steps in
`templates/repo-docs/docs-ai-visual-testing.md`.

## Getting past login: preview a UI that needs a backend

The single biggest time-sink when verifying a frontend change is **reaching the
screen at all** — most of these apps gate everything behind a login that calls a
backend. Two dead ends waste a whole session if you don't know them up front:

1. **Plain `ng serve` / `npm run dev` alone fails at login.** The default dev
   environment points at a local backend (e.g. `localhost:5000`) that isn't
   running, so login dies with *"cannot reach server / HTTP status 0."*
2. **Pointing the browser straight at the deployed sandbox host fails CORS.** The
   deployed backend's allowlist rejects a `localhost` Origin, so the browser
   call dies with *"TypeError: Failed to fetch."*

**The fix that always works — a dev-server proxy to the deployed sandbox
backend:**

- Make the served app call **relative** API URLs (`/api/*`), not absolute.
- Add a dev-server **proxy** that forwards `/api` to the deployed sandbox host
  **server-side**. The browser then only ever talks to `localhost:<port>`, so
  there is no cross-origin request and CORS never applies.
- Result: your **local** code (with the change under test) runs against **real
  sandbox data**, and login/SSO works normally.

Make it a **committed one-command script** per app so nobody re-derives it each
session. Reference implementation (dflow / `designflow-frontend`):

```bash
yarn start:preview   # ng serve --configuration preview --port 4200
```

which is wired from three committed pieces:

- `src/environments/environment.preview.ts` — relative `/api/*` URLs;
- `proxy.conf.sandbox.json` — proxies `/api` → the sandbox host, `changeOrigin`;
- a `preview` build/serve configuration in `angular.json` tying them together.

For a **React/Vite** app the shape is the same: a `.env`/mode with relative
`/api` base + a `server.proxy` entry in `vite.config` (or a `vercel dev` /
framework proxy) pointing at the deployed sandbox.

Credentials for the login are in 1Password (`vibe_coding` vault) — read them at
run time, never hardcode. Treat the session as **read-through to real sandbox
data**: fine for viewing, but don't Save/Apply unless you mean to mutate sandbox
records.

> This is a read-only preview convenience, not the automated visual-regression
> harness described above — that still needs building.
