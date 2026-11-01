# Plan — lean required checks (keep only data-safety gates)

- **Parent issue:** popcre/ai-devops#2172. Model: popcre/ai-devops#2041 ([plan_skinny-review.md](plan_skinny-review.md)).
- **Owner request (2026-10-30):** "can we bypass/eliminate some or all of the automatic checks?" then "yes. and do it in a permanent way in the ai-devops repo so that it hits all apps/harnesses on all machines".

## STATUS (read first)

| Stage | State (2026-10-30) | Evidence |
|---|---|---|
| A Standing rule + owner ruling in ai-devops | ✅ done | PR #2174 |
| B shared-db required checks cut to core; queue-gate collision/lease re-checks removed; "one licensor per change" killed | ✅ done; live ruleset + classic protection = 5 contexts | shared-db #5171 (8dd0e9b2) |
| C shared-db claim / lease / evidence-pair / guarded-authorization chain retired | 🟡 C1 + C2 done: promotion keys on the merged PR's merge commit on main + preview evidence, admission not enforced; queue gate = identity / version order / preview hold; production gate needs only the two core exact-head checks; guarded-merge, author-lease and Agent work contract workflows deleted; required = 3 core contexts in code, ruleset 26255167 and classic protection. Open: move the preview/production exclusive locks out of `manage-migration-author-lanes.mjs`, then delete the claim/lane code and `refs/db-contracts` | shared-db #5221, #5226, #5234, #5240 (flake fix); work issue #5228 |
| D Other toolkit repos audited to the same core | ✅ audited; ai-devops producer merged and live-proved | Other popcre/u2giants repos have no required checks. [#2191](https://github.com/popcre/ai-devops/pull/2191) merged as `d1bc598ab860609455fca487135ce3e488016228`. Its independent secret-boundary [required job](https://github.com/popcre/ai-devops/actions/runs/41124163899/job/124298229440) passed in seven seconds on exact source `7cf9afa49dad64ba696ae36ae262854824ec662e`; eight broad-suite jobs were still running when observed, and the PR merged without waiting for them. The previous full truth evaluator remains advisory. |
| E Live proof: fresh shared-db migration PR merges on core checks only | 🟡 merge proved: comment-only migration #5233 merged 2026-10-31 on the 3 core checks (no guarded authorization). Automatic production promotion not yet observed: the candidate trigger is head-of-line blocked by PR #5104 (4 failed attempts) | shared-db #5233 (ef9a3e1a), issue #5225 |

## The rule

A required (merge-blocking) check must directly stop damage to production data
or leaked secrets. Everything else — process, ownership, handoff, claim,
lease, evidence-pair, coverage, review, hygiene and contract-test suites —
runs advisory or is deleted. A required check that hangs or flakes is
removed from the required set first and repaired afterwards.

## Kept core

| Repo | Required checks |
|---|---|
| shared-db | `SQL migration guards` (migration lint, applied-migration edit refusal, duplicate/ordering of versions, production sidecars), `Destructive SQL outside migrations`, `supabase/tests against an ephemeral database`. Stage C2 removed `Merge queue gate` and `Migration guarded merge authorization` (2026-10-31); the queue gate still runs, advisory. |
| ai-devops | `verification-closure`: the existing public-boundary secret scanner on the exact candidate, independently of general tests. Context name and live ruleset remain unchanged. |

The earlier stage-D audit counted required context names without examining
their dependencies. `verification-closure` still waited for every general
Windows/Linux suite, so it did not implement the owner's rule. The correction
keeps the secret check required and preserves the previous full verification
aggregate as advisory `verification-report`. Broad tests, their platform
results, Markdown checks, classification and queue evidence continue to run;
they do not block this toolkit's merge. Shared-db's production-data gates are
unchanged by this correction.

Post-merge production promotion keeps its own safety: preview rehearsal, tests,
no open `review-finding` issue (owner ruling 2026-10-29).

## Removed from required (shared-db, stage B)

`Cancelled work guard`, `Cross-PR object collision`, `Domain ownership`,
`Handoff contract`, `Intake pointer guard`, `Migration author lease`,
`Promotion contract tests (offline)`, `Tools offline tests`,
`Queue-sensitive checks (aggregate)`. The queue gate stops re-running the
cross-PR collision and migration-lease checks. Both the ruleset and the classic
branch protection list must match.

## Stage C outline

1. Promotion (`shared-supabase-migrations.yml` automatic-production-promotion)
   stops reading `Migration guarded merge authorization` and the admitted-issue
   resolver; the merged PR's merge commit on main plus the preview evidence is
   the source of truth.
2. Merge queue gate keeps only: single-PR identity, ascending migration
   versions, and the "preceding migration finished preview rehearsal" hold.
3. Retire `guarded-migration-merge.yml`, `migration-author-lease.yml`, the
   evidence-pair contract (`.agent/work/<issue>/<gen>/`) and author-lane claim
   mechanics; drop both contexts from required.
4. Each step proves itself with a real migration PR before the next.
