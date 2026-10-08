## Promotion attempt #3947 / PR #4047 — 6:44 PM EDT Oct 7 2026

**Goal this session:** Muse fence APPROVE at PR head `e35c1ecde901b55e7ed3a343da685d5f2c4c7a37` with `production-risk-assessment` `main_sha` = LIVE `origin/main`, then fire `3947-fire-production-apply-fwd.sh` for `20261007190954` only.

### Done

- Muse governed review, slot 4 (replacement sequence 5712), reviewer `muse-spark-1.3-contributor`.
- Durable APPROVE recorded: `refs/db-review-verdict-replacements/3947-4047-e35c1ecde901b55e7ed3a343da685d5f2c4c7a37-slot4-5712` (`a8e41d2f92c75bb272b5ee5908c047232d693fbb`).
- Fence carries `main_sha=e181f5a06e5711f3c044ba2de92d1fc335f215a9`, `ordered_allowlist=["20261007190954"]`, `source_pr=4047`.
- Findings comment: https://github.com/popcre/shared-db/pull/4047#issuecomment-6048266087

### Blocked — durable reviewer refusal at this exact head

`check-exact-head-approval` refuses:

> head `e35c1ecde…` carries a durable reviewer refusal

Slot 3 carries a **StepFun REVISE**:

- verdict ref `refs/db-review-verdicts/3947-4047-e35c1ecde901b55e7ed3a343da685d5f2c4c7a37-slot3` (`30db52b63ce17819b55ea701cf9a92f3e87a4c68`)
- reviewer `stepfun-step-5-preview`, assignment sequence **5718** (assigned 6:29 PM EDT, after this session's Muse draw)
- findings: https://github.com/popcre/shared-db/pull/4047#issuecomment-6048262075

The REVISE is **not a source finding**. StepFun's gated shell was non-functional on this Windows host (`NotFound: ChildProcess.spawn`); it read no files and stated "Nothing in this review is verified against source." Per handoff constraints, StepFun must not be drawn for #3947.

A durable REVISE at a **merged** head cannot be answered by a new commit. Replacement is refused while a verdict exists. `--archive-old-review-verdicts` keeps merged-migration verdicts for promotion. Same class of pin as DeepSeek REVISE on `f8b8b321` / original `20261007020907`.

### Not done (depends on production apply)

- Ledger proof of `20261007190954` on production
- `3947-live-proof-queries.sql` on production

### Path forward (needs a decision)

Forward replacement of `20261007190954` (same SQL, new version, hard-block the stranded version) — #3911 precedent — or a governed recovery that disregards a non-reading reviewer's REVISE without forging refs.

HARD_BLOCKED remains `20261007020907`. Do not promote it.

Posted by MiMo chat unknown on edge-dev
