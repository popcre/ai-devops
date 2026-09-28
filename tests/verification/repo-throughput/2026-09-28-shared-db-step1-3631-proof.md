# Shared-db Step 1 live proof — issue #3631

**Date:** September 28, 2026, 8:47 AM EDT (America/New_York)
**Worker:** Step 1 live-proof worker, MiMo chat `ses_ffe5f18244baaffe5u2M2rZ2qA` on `windows-dev`
**Coordinator authority:** ai-devops #903 completion; shared-db #3631 (non-orchestrator work)
**Constraint honored:** READ-ONLY on GitHub. No shared-db PR merged. No plan STATUS updated. No issue closed.

---

## 1. Outcome under test

Prove Step 1 of #3306: two genuine, unrelated shared-db code pull requests with
distinct work issues use their own evidence generations and land sequentially
without an evidence-only conflict or unnecessary substantive re-review, with
negative fail-closed behavior preserved under the merged implementation (#3445,
`8b35d64e10ab351909aa434d1840acd6b5cb5e98`, merged 12:20 AM EDT).

Candidate pair documented: **PR #3611** (issue #2492) then **PR #3615** (issue #3614).

---

## 2. Timeline (America/New_York)

| Time (EDT) | Event |
|---|---|
| 12:20 AM | PR #3445 merges as `8b35d64e` — immutable generation lineage implementation |
| 1:44 AM | Issue #3614 opened (restore pinned read-only observer for #2870) |
| 2:23 AM | PR #3615 first governed review: REVISE at `b46d4203` |
| 2:22 AM | PR #3611 governed APPROVE at `a73152c7` |
| 2:57 AM | PR #3611 final refreshed head `4725594d` — APPROVE carry-forward under #2758 |
| 3:03 AM | **PR #3611 merges** as `ddd67972` |
| 3:15 AM | PR #3615 exact-head slot 1 APPROVE at `471bbadf` |
| 3:37 AM | PR #3615 exact-head slot 2 APPROVE at `471bbadf` |
| 3:56 AM | Issue #3631 opened |
| 4:37 AM | Prior #3631 audit (correct at that instant: only #3611 had landed) |
| 5:02 AM | **PR #3615 merges** as `4b91483c` |
| 8:47 AM | This proof report |

The prior audit at 4:37 AM EDT predates the #3615 merge (5:02 AM EDT). At its
timestamp no complete pair existed. The pair completed 25 minutes later.

---

## 3. Positive requirements

### 3.1 PR #3611 — first of the pair

| Field | Value |
|---|---|
| PR | [popcre/shared-db#3611](https://github.com/popcre/shared-db/pull/3611) — "Fix Grok review turn budget for large migrations (#2492)" |
| Work issue | [#2492](https://github.com/popcre/shared-db/issues/2492) (non-orchestrator) |
| Exact merged head | `4725594d1cc194ccc0e0965312b54efa568a0f3e` |
| Merge commit | `ddd679728993a2fbc5833db7794e3ac1f86cea21` at 3:03 AM EDT |
| Evidence generation/path | `.agent/work/2492/1/` — schema v2, generation 1, `evidence_parent: null` (root) |
| Branch | `codex/2492-grok-turn-budget` |

**Changed files (8):**

- `.agent/work/2492/1/completion.json`, `.agent/work/2492/1/contract.json` (evidence pair)
- `scripts/lib/reviewer-turn-budget.mjs` (new, 156 lines) — turn-budget policy for Grok reviews of large migration diffs
- `scripts/lib/reviewer-turn-budget.test.mjs` (new, 124 lines)
- `scripts/run-governed-review.mjs` (modified, +16/−2) — budget injection + refusal diagnostic
- `scripts/run-governed-review.test.mjs` (modified, +65)
- `.github/workflows/migration-author-lease.yml` (modified, +1/−1) — adds turn-budget test to suite
- `docs/verification/throughput-dispositions/scripts~run-governed-review.mjs.json` (disposition offsets)

**Required CI (all SUCCESS or expected SKIPPED at head):** Agent work contract,
Migration author lease, Tools offline tests, Cross-PR object collision, Merge queue
gate, SQL migration guards, Database contract applicability, Domain ownership,
Orchestrator marker guard, Public data venue guard, Queue-sensitive checks
(aggregate), Cancelled work guard, Handoff contract, Intake pointer guard,
Promotion contract tests (offline), Historical MG reclassification offline tests,
Email-address forward guard, Documents fast CI route, Documents-only merge
authorization, Destructive SQL outside migrations, supabase/tests against an
ephemeral database. Status contexts: Documents-only merge advisory (SUCCESS),
Migration guarded merge authorization (SUCCESS). Production/preview jobs SKIPPED
(no migrations).

**Governed verdict:** `VERDICT: APPROVE a73152c79f15d4e74c4f4f96756a211739900f44`
(Two-reviewer exact-head slots; one voided recording then re-recorded). Final head
`4725594d` carries forward under #2758 — non-`.agent/` patch byte-identical to the
approved head (SHA-256 `267ca2342cab0ce7e34cb80d82364776222067889d57031d49cf7c21610ccf47`).

### 3.2 PR #3615 — second of the pair

| Field | Value |
|---|---|
| PR | [popcre/shared-db#3615](https://github.com/popcre/shared-db/pull/3615) — "Restore pinned read-only observer for #2870 acceptance" |
| Work issue | [#3614](https://github.com/popcre/shared-db/issues/3614) (non-orchestrator, repo-maintenance) |
| Exact merged head | `8cdc489c551f8d1e6a22c7093bdbd44248a2fdec` |
| Merge commit | `4b91483c85da7bac3421219b40252c169a455087` at 5:02 AM EDT |
| Evidence generation/path | `.agent/work/3614/5/` — schema v2, generation 5, `evidence_parent` = generation 4, `contract_sha256` `1eb167d9c85d65a18b6c53017a39d4231293af0663820b59b002ccf331543bab` |
| Branch | `codex/2870-observer-restore` |

**Changed files (9):**

- `.agent/work/3614/5/completion.json`, `.agent/work/3614/5/contract.json` (evidence pair)
- `.github/workflows/shared-db-2870-observation.yml` (new, 52 lines) — read-only, main-only, dispatch-only
- `scripts/proofs/shared-db-2870-observation.mjs` (new, 197 lines) — catalog observer
- `scripts/proofs/shared-db-2870-observation.test.mjs` (new, 209 lines) — 13 focused tests
- `scripts/proofs/2870-catalog.sql` (new, 15 lines) — pg_catalog shape query
- `scripts/proofs/2870-contract.json` (new, 10 lines)
- `docs/verification/2870-observer-restore-evidence.md` (new, 35 lines) — four SHA-256 pin record
- `docs/verification/throughput-dispositions/scripts~proofs~shared-db-2870-observation.mjs.json`

**Required CI (all SUCCESS or expected SKIPPED at head):** same governed set as
#3611, plus `tests` under workflow "Shared DB 2870 Catalog Observation" (SUCCESS;
13 focused tests). Agent work contract SUCCESS (machine-proves the 7+2
implementation/evidence split). Migration guarded merge authorization SUCCESS at
5:02:30 AM EDT, merge at 5:02:35 AM EDT.

**Governed verdict:** `VERDICT: APPROVE 471bbadf2d6462a722ca265c465d274e49c1f1b2`
from two independent exact-head slots (slot 1 durable APPROVE; slot 2 after a
failed DeepSeek draw that omitted `## Verdict`, replaced via the supported
allocator route). One earlier REVISE at `b46d4203` (F1–F4) was resolved in
generation 3; one reviewer line was voided by the governed runner and did not
authorize.

### 3.3 Genuinely unrelated, independent code changes — YES

Disjoint file sets, no overlapping paths:

| | #3611 | #3615 |
|---|---|---|
| Feature | Grok review turn budget for large migration diffs | Restore pinned read-only catalog observer |
| Code surface | `scripts/lib/reviewer-turn-budget*`, `scripts/run-governed-review*`, `migration-author-lease.yml` | `scripts/proofs/2870-*`, `shared-db-2870-observation.*` |
| Work issue | #2492 | #3614 |
| Evidence path | `.agent/work/2492/1/` | `.agent/work/3614/5/` |
| DB writes | none | none |

Distinct work issues, distinct evidence-generation namespaces, no shared code.
#3615 was opened at 1:44 AM EDT, **before** #3631 (3:56 AM EDT) — it is genuine
independent work, not manufactured for this proof.

### 3.4 Sequential landing without evidence-only conflict — YES

- #3611 merged 3:03 AM EDT (`ddd67972`); #3615 merged 5:02 AM EDT (`4b91483c`).
- #3615 integrated current main (including #3611) via `a876b5ec8` ("Merge current
  main; observer implementation head without prior evidence") and rebound its own
  evidence as **generation 5** (append-only, parent generation 4) at `8cdc489c5`.
- Evidence paths never collide: `2492/1` vs `3614/5`. No evidence-only conflict
  occurred or was resolved.

### 3.5 Second PR review-equivalence / CI trace — recorded

After main moved (carrying #3611), the second PR did **not** draw a fresh
substantive re-review. The exact-head gate carried the `471bbadf` approvals
forward via content-preserving refresh (#2758).

Verified in a disposable worktree of `popcre/shared-db` `origin/main`
(`067420b11`, which contains #3445):

```
isContentPreservingRefresh({ approvedHead: 471bbadf…, head: 8cdc489c…, mainRef: 4b91483c^1 })
= { ok: true,
    reason: "the pull request's own diff is identical at 471bbadf… and 8cdc489c…
             (.agent evidence and verified script-hash re-pins aside)",
    implementation_digest: '60b90d64a6d7632124004b1a85aa974dbbd2be832a6e36cdafc7bead1a93ef89' }

prContentDigest(471bbadf) = prContentDigest(8cdc489c)
= 9b1b9a911c5c350750c71552dd89f8592e6af3238254a7a0f883a1fb7d76cac2
```

All seven implementation file blobs are identical across the two heads (workflow,
observer, test, catalog SQL, contract JSON, evidence doc, disposition JSON).
The gen-5 contract states the rule it relied on: *"The prior exact-head approvals
may carry only if the approved implementation diff remains byte-identical under
the repository equivalence guard."* Machine enforcement: Agent work contract
SUCCESS and Migration guarded merge authorization SUCCESS at the merged head.

**Trace summary:** APPROVE `471bbadf` (2 slots) → main merge + gen-5 evidence
rebind → implementation blobs identical → `isContentPreservingRefresh` ok →
exact-head carry-forward → guarded merge `4b91483c`.

---

## 4. Negative requirements (fail-closed preserved)

Command context: disposable worktree `shared-db-wt-3631-proof` at
`popcre/shared-db` `origin/main` `067420b116cbfe53b851ea460a11190607b9b699`.
#3445 (`8b35d64e`) confirmed an ancestor of that HEAD — negatives are bound to the
merged implementation, not to fixtures alone.

### 4.1 Wrong-task or inherited evidence fails closed — PASS

```
node --test scripts/lib/evidence-generation-lineage.test.mjs   → 21 pass, 0 fail
node --test scripts/agent-work-contract-git-evidence.test.mjs  → 26 pass, 0 fail
```

Named refusals that carry this negative:

- `evidence_parent never crosses issues`
- `evidence_parent rejects malformed digests and shapes`
- `evidence_parent refuses extra keys — name exists is not right object`
- `verifyPredecessorBinding refuses a forged parent digest`
- `planSuccessor ignores published refs from other issues`
- `arbitrary .agent/ metadata is not inert evidence`
- `#2708: a pull request may not carry another pull request keyed evidence pair`
- `evidence pair classification distinguishes inherited, current, and half-written evidence`
- `#3380: a forged evidence_parent digest is refused in the gate (Major 1)`
- `#3380: a v2 contract whose parent contract is unavailable is refused`
- `#3380: a missing predecessor ref fails closed with a structured error, not an unhandled throw`
- `real Git-history negative fixtures: in-place record edit, fake parent, highest-filename`

### 4.2 Genuine implementation conflict / implementation change fails closed — PASS

```
node --test scripts/agent-work-contract-git-evidence.test.mjs  → 26 pass, 0 fail
node --test scripts/check-exact-head-approval.test.mjs         → 93 pass, 0 fail
```

Named refusals:

- `code changed after the reported head is refused`
- `a self-reported file list cannot hide a changed file`
- `both ancestry links and full SHAs are required`
- `#2845: a pair anchored to a superseded base is refused`
- `#2845: a rebound base is still held to the exact-SHA and ancestry rules`
- `#3380: an unknown .agent/ path in the implementation diff is refused`
- `#3505: a code PR with only the advisory status is refused at merge-authorization audit`

### 4.3 Committed-record mutation still refused — PASS

Same suites as above (mutation cases live in both):

- `committed-record mutation is refused`
- `#3380: a committed-record content mutation reaches refuseCommittedMutation in the gate`
- `#3380: a committed-generation identity mutation is refused with successor guidance`
- `real Git-history negative fixtures: in-place record edit, fake parent, highest-filename`
- `assertGenerationWriteAllowed binds write target to contract identity`
- `the checked-in contract must match its exact immutable published ref`

Totals bound to merged #3445 on `origin/main`: **140 tests, 140 pass, 0 fail**
across the three suites (21 + 26 + 93).

---

## 5. Considerations recorded (not disqualifying)

1. **#3615's character.** It restores pinned observer code whose *purpose* is to
   unblock orchestrator #2870 acceptance. It still qualifies as a normal
   independent code PR under the acceptance text: issue #3614 is labeled
   non-orchestrator / repo-maintenance, it carries real implementation (9 files,
   13 focused tests), its own evidence generation, and is disjoint from #3611.
   It was created before #3631, so it is not proof-manufactured.
2. **No in-thread "Final refreshed head" equivalence comment on #3615** (unlike
   #3611). The equivalence is still machine-enforced at merge time and was
   independently recomputed above; the merge-authorization status context is the
   gate's own record.
3. **Intermediate generations 2–4 of #3614 are not in the final tree** — the
   refresh pattern is merge main → implementation-only head (`a876b5ec8`) →
   append generation 5. Prior generations remain reachable in history and as
   `refs/db-contracts/3614/*`; in-place mutation is refused by the gate. This is
   the designed append-only lineage, not a silent rewrite.

---

## 6. VERDICT

**ACCEPTED**

Both positive and negative requirements pass against real landed PRs on
`popcre/shared-db` `main` after merged implementation #3445:

1. Two genuine unrelated PRs — #3611/#2492 and #3615/#3614 — with independent,
   disjoint code changes and their own evidence generations (`2492/1`, `3614/5`).
2. Exact heads, issues, evidence paths, changed-file sets, required CI, and
   governed verdicts recorded for each.
3. They landed sequentially (3:03 AM and 5:02 AM EDT) with no evidence-only
   conflict and no unnecessary substantive re-review of the second.
4. Merge commits `ddd67972` and `4b91483c` recorded with the second PR's
   review-equivalence/CI trace (content-preserving refresh `ok:true`, identical
   implementation digests, guarded-merge authorization SUCCESS).
5. Wrong-task/inherited evidence, implementation conflict, and committed-record
   mutation all fail closed — 140/140 tests pass bound to merged #3445.

Posted by MiMo chat ses_ffe5f18244baaffe5u2M2rZ2qA on windows-dev —
September 28, 2026, 8:47 AM EDT (America/New_York)
