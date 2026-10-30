issue: none
status: OPEN
owner: mimo/edge-dev-gate-trim-plan

Reason: proposal only; no implementation tracker has been created yet. The implementation session must create it in `popcre/shared-db` and replace `none` with its full issue URL before stage 1.

# Handoff — shared-db gate-trim implementation plan (published, awaiting approval)

Session: MiMo chat on `edge-dev`, 2026-10-30.
Plan file: [`plan_shared-db-gate-trim.md`](../plan_shared-db-gate-trim.md) — **read its STATUS table first; do not re-derive or re-plan.**

## State

- Analysis complete; the plan is written and published. **No rule, gate, or workflow has been changed.** Implementation is not authorized until Albert approves the plan.
- Measured basis: 28 merged migration PRs in `popcre/shared-db` (2026-10-18→30); median open→merge 147 min, median CI 8 min, 80% of failed runs are paperwork classes. Durable aggregates live in plan §6; the raw per-PR table is scratch at `popcre/shared-db/.ai/gate-trim-pr-timings.md` (gitignored, may vanish).
- Gate map: 18 gates inventoried from `.github/workflows/**` and `scripts/**` this session; duplicate-invocation evidence is in plan §5.

## Next exact action

1. Albert reviews/approves `plan_shared-db-gate-trim.md` (target: median open→merge ≤25 min).
2. On approval: implementation session first creates the tracker in `popcre/shared-db`, records its full issue URL here and in the plan, and satisfies the durable baseline evidence prerequisite in plan §6. Only then open work on **stage 1** (one-shot claim preflight) as one PR in `popcre/shared-db`, ordinary maintenance route — see plan §9. Each stage is one PR, merged before the next.
3. The newly recorded tracker carries the per-stage `- [ ] live proof` checklist items. The scratch timing table is not durable evidence; recover or reconstruct it with run IDs before any coverage cut.

## Boundaries (do not cross)

- Do not touch the production apply path (plan stage 9 is verify-only).
- Do not redo `plan_shared_release_hold_reduction.md` (#3779) steps 3/8a (merged); coordinate on its steps 4–5 (same `guarded-migration-merge.yml` files).
- Do not implement `plan_narrow_promotion_freezes.md` (#4039) — proposal only, not authorized.
- Review stays advisory (owner ruling 2026-10-29); never reintroduce a required AI-review gate.
