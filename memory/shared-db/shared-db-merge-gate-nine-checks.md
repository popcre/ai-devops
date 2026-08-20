---
name: shared-db-merge-gate-nine-checks
description: "shared-db main requires 9 checks (~4 min) but no longer requires branches to be up to date; never propose paths: filters to speed it up"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 542c9c93-9e90-4a76-adc0-55abe2199ec7
  modified: 2026-08-20T11:23:18.060Z
---

`u2giants/shared-db` protects `main` with **9 required status checks** (~4 minutes) and
`enforce_admins: true`. Direct commits to `main` are refused, including via the GitHub
Contents API — always branch and open a PR.

**Since 2026-08-19, `required_status_checks.strict` is `false`** (owner-authorized). A
branch no longer has to be up to date to merge. Before that, every merge by another
session reset every waiting PR and restarted its checks; that cost ~50 minutes in one
day. Details, revert criteria and the exact restore command are in **issue #1286**.

**How to apply:**

- Do not loop on `gh pr merge`. If it will not merge, find the actually-failing check.
- **Never diagnose a stuck check from its name.** A check reported "pending" for 2 hours
  while its job had finished in 1 minute — the run was wedged on an unbounded `apt-get`
  step. Open the failing step:
  `gh api repos/u2giants/shared-db/actions/runs/<id>/attempts/1/jobs`.
- **Never propose `paths:` filters** to skip checks on docs-only PRs. AGENTS.md §5.2 and
  three workflow files forbid them. A path-filtered workflow creates no check run at all,
  so a required context stays pending forever; and repo-wide guards that scan more than
  their trigger watches report stale verdicts. `check-domain-ownership.mjs` reads every
  tracked text file including `docs/**`.

Related: [[shared-checkout-commits-can-land-elsewhere]], [[shared-db-apply-mechanics]]
