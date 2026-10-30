# Plan — lean required checks (keep only data-safety gates)

- **Parent issue:** popcre/ai-devops#2172. Model: popcre/ai-devops#2041 ([plan_skinny-review.md](plan_skinny-review.md)).
- **Owner request (2026-10-30):** "can we bypass/eliminate some or all of the automatic checks?" then "yes. and do it in a permanent way in the ai-devops repo so that it hits all apps/harnesses on all machines".

## STATUS (read first)

| Stage | State (2026-10-30) | Evidence |
|---|---|---|
| A Standing rule + owner ruling in ai-devops | ✅ done | PR #2174 |
| B shared-db required checks cut to core; queue-gate collision/lease re-checks removed; "one licensor per change" killed | ✅ done; live ruleset + classic protection = 5 contexts | shared-db #5171 (8dd0e9b2) |
| C shared-db claim / lease / evidence-pair / guarded-authorization chain retired | 🟡 C1 done: guarded merge no longer re-runs collision or lease checks. C2 (retire claim-first contracts, version lanes, preview leases, guarded authorization) open | shared-db #5183 (835b4491) merged on the 5-check set |
| D Other toolkit repos audited to the same core | ✅ done: no other popcre/u2giants repo has required checks; ai-devops keeps only `verification-closure` | audit 2026-10-30 |
| E Live proof: fresh shared-db migration PR merges on core checks only | 🟡 non-migration proof done (#5171 switch, #5183 merged on core set); first migration PR on the core set still to land | |

## The rule

A required (merge-blocking) check must directly stop damage to production data
or leaked secrets. Everything else — process, ownership, handoff, claim,
lease, evidence-pair, coverage, review, hygiene and contract-test suites —
runs advisory or is deleted. A required check that hangs or flakes is
removed from the required set first and repaired afterwards.

## Kept core

| Repo | Required checks |
|---|---|
| shared-db | `SQL migration guards` (migration lint, applied-migration edit refusal, duplicate/ordering of versions, production sidecars), `Destructive SQL outside migrations`, `supabase/tests against an ephemeral database`. Until stage C: `Merge queue gate` + `Migration guarded merge authorization`, because automatic production promotion and the shared-preview ordering hold still read them. |
| ai-devops | `verification-closure` (unchanged). |

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
