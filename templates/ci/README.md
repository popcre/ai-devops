# CI templates

Drop-in GitHub Actions workflows for the app repos. Self-contained (no cross-org
reusable-workflow dependency, since the consuming repos span the `popcre` and
`u2giants` orgs).

## `shared-db-guard.yml` — enforce "all DB work goes through shared-db"

Fails a PR that makes a database/schema change **inside an app repo** instead of
in the canonical [`u2giants/shared-db`](https://github.com/u2giants/shared-db).
It catches new migration files and added DDL/RLS/policy SQL outside the vendored
`shared-db/` folder — regardless of whether Claude, Codex, or a human authored
it, on any machine/OS. This is the enforcement layer that a documented rule alone
can't provide.

### Install into a consuming repo

```bash
mkdir -p .github/workflows
curl -fsSL https://raw.githubusercontent.com/u2giants/ai-devops/main/templates/ci/shared-db-guard.yml \
  -o .github/workflows/shared-db-guard.yml
git add .github/workflows/shared-db-guard.yml
git commit -m "ci: enforce shared-db as the source of DB changes"
```

(Or copy the file from `templates/ci/shared-db-guard.yml` in this repo.)

Consuming repos: `designflow-backend`, `designflow-bff`, `designflow-frontend`,
`designflow-item-master`, `designflow-tracking`, `designflow-data-syncing`,
`popcrm-web`, `poppim-web`, `popdam`. (Directus is deprecated — do not include it.)

### Override

For a legitimate exception (retiring legacy inline DDL, or an owner-approved
emergency repair that is immediately re-authored in shared-db), add the PR label
`db-change-approved`. The job then passes but still prints what it flagged.

### Pair with

- The `shared-db-change` (Claude) / `codex-shared-db-change` (Codex) skills.
- Each consuming repo's `AGENTS.md` (+ `CLAUDE.md`) DB section, which must point
  DB work to shared-db and must NOT teach an app-local migration pattern.
