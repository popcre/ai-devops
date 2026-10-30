# Plan — lean required checks (keep only data-safety gates)

- **Parent issue:** popcre/ai-devops#2172. Model: popcre/ai-devops#2041 ([plan_skinny-review.md](plan_skinny-review.md)).
- **Owner request (2026-10-30):** "can we bypass/eliminate some or all of the automatic checks?" then "yes. and do it in a permanent way in the ai-devops repo so that it hits all apps/harnesses on all machines".

## STATUS (read first)

| Stage | State (2026-10-30) | Evidence |
|---|---|---|
| A Standing rule + owner ruling in ai-devops | in PR | this PR |
| B shared-db required checks cut to core; data-integrity guards retained; multi-licensor load controls verified | pending | |
| C shared-db claim / lease / evidence-pair / guarded-authorization chain retired | pending | |
| D Other toolkit repos audited to the same core | pending | |
| E Live proof: fresh shared-db migration PR merges on core checks only | pending | |

This plan supersedes [the earlier shared-db gate-trim proposal](plan_shared-db-gate-trim.md)
for gate selection and sequencing. Its historical steps are not a second execution
route. Implementation remains pending in `popcre/shared-db`; this PR changes no
ruleset or workflow.

## The rule

A required (merge-blocking) check must directly stop damage to production data
or leaked secrets. Everything else — process, ownership, handoff, claim,
lease, evidence-pair, coverage, review, hygiene and contract-test suites —
runs advisory or is deleted unless it directly protects data integrity. Existing
required contexts remain blocking until the repository ruleset is changed. Repair
hanging or flaky checks; never remove the only data-safety or secret check until
an equivalent required replacement is active and passing.

## Kept core

| Repo | Required checks |
|---|---|
| shared-db | `SQL migration guards` (migration lint, applied-migration edit refusal, duplicate/ordering of versions, production sidecars), `Destructive SQL outside migrations`, `supabase/tests against an ephemeral database`, `Cross-PR object collision`, `Domain ownership`. Until stage C: `Merge queue gate` + `Migration guarded merge authorization`, because automatic production promotion and the shared-preview ordering hold still read them. |
| ai-devops | `verification-closure` remains required until a separate ruleset change replaces it with proven data-safety/secret checks; it is a broad suite, not reclassified as data-safety. |

Post-merge production promotion keeps its own safety: preview rehearsal, tests,
no open `review-finding` issue (owner ruling 2026-10-29).

## Removed from required (shared-db, stage B)

`Cancelled work guard`,
`Handoff contract`, `Intake pointer guard`, `Migration author lease`,
`Promotion contract tests (offline)`, `Tools offline tests`,
`Queue-sensitive checks (aggregate)`. The queue gate retains collision and domain-ownership validation against the
current base under serialization: concurrent or out-of-scope migrations can damage
data. Lease removal must preserve these protections independently of author leases.
Both the ruleset and the classic branch protection list must match.

## Stage C outline

1. Promotion (`shared-supabase-migrations.yml` automatic-production-promotion)
   stops reading `Migration guarded merge authorization` and the admitted-issue
   resolver; the merged PR's merge commit on main plus the preview evidence is
   the source of truth.
2. Merge queue gate keeps single-PR identity, ascending migration versions,
   serialized current-base collision and domain-ownership validation, and the
   "preceding migration finished preview rehearsal" hold.
3. Retire `guarded-migration-merge.yml`, `migration-author-lease.yml`, the
   evidence-pair contract (`.agent/work/<issue>/<gen>/`) and author-lane claim
   mechanics only after independent required collision and domain-ownership
   controls are active and passing without those dependencies; then drop both
   contexts from required.
4. Each step proves itself with a real migration PR before the next.

## Curated loads

The reported removal of the one-licensor limit is not a waiver of data integrity.
Before multi-licensor loads proceed, prove per-licensor authorization, row scoping,
uniqueness, referential integrity, and transactional rollback in required checks
and preview rehearsal for the exact load. Retain existing protections until those
controls are active and passing; this plan does not authorize an unguarded load.
