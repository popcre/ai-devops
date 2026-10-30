# Implementation plan — trim shared-db migration gates to minutes

Related handoff: [`HANDOFF.d/2026-10-30T1512Z-edge-dev-mimo-gate-trim-plan.md`](HANDOFF.d/2026-10-30T1512Z-edge-dev-mimo-gate-trim-plan.md). Do not rewrite root `HANDOFF.md`.
Tracker issue: popcre/shared-db — see "Definition of done" (§13). Implementation happens in `popcre/shared-db`; this plan file lives in `popcre/ai-devops` per owner instruction.

## STATUS

**Proposal only. No gate, rule, or workflow has been changed.** This session ended at the plan. Implementation is not authorized until Albert approves it.

Planning baseline: **2026-10-30**, `popcre/shared-db` @ `af8bd6b8f6ff3b75b1e4067c0ad38701e35ac90d`, `popcre/ai-devops` @ `43f5e608`. Planning session: MiMo chat on `edge-dev`.

| Step | Independently verifiable outcome | Status | Updated | Acceptance artifact |
|---|---|---|---|---|
| 1 | One-shot claim preflight: `--claim` prints **every** rejection reason in one run; no sequential guess-and-retry | ⬜ open | 2026-10-30 | — |
| 2 | `Migration author lease` PR check stops running the 40-file meta-test battery; it proves the lease in seconds | ⬜ open | 2026-10-30 | — |
| 3 | Work-contract + completion pair is auto-generated from the claim; authors never hand-write it | ⬜ open | 2026-10-30 | — |
| 4 | Deterministic static guards run **once** per `(head, base)`; later stages re-run only on drift | ⬜ open | 2026-10-30 | — |
| 5 | Guarded Merge runs each coordination guard **once** per lock hold (today lease ×3, live-proof ×3) | ⬜ open | 2026-10-30 | — |
| 6 | Predecessor preview-rehearsal wait moves out of the merge queue into the preview/production lane | ⬜ open | 2026-10-30 | — |
| 7 | Documents-only authorization no longer takes the global mutex for claimed migration PRs | ⬜ open | 2026-10-30 | — |
| 8 | Replay bound to the migrations tree hash — evidence-only pushes stop re-running the 5.6-min replay | ⬜ open | 2026-10-30 | — |
| 9 | Production path unchanged (keep list verified: nothing on it was cut) | ⬜ open | 2026-10-30 | — |

**Target total time:** median open→merge for a routine migration PR falls from **147 minutes to ≤25 minutes** (measured on 28 merged PRs, 2026-10-18→30; see §6). Per-stage target: claim+paperwork ≤2 min with zero rejections, CI ≈8 min (replay kept), Guarded Merge under lock ≤6 min, merge queue ≤5 min. Preview rehearsal and production promotion are **not** targets — they stay as they are.

**Where a fresh session starts:** step 1. Re-read §6 (why each cut is safe) and the adversarial table in §9 before each stage. Each stage is one PR in `popcre/shared-db`, merged one at a time.

---

## Part 1 — Why

### 1. Ultimate goal

A structural database migration should take **minutes of gating, not hours**, without losing the safety that protects the shared production database and the ordering of applies.

What is true when this is done that is not true today: a session authors a migration, opens its PR, and the machine decides in about 25 minutes — because checks run once instead of three or four times, paperwork is generated rather than hand-authored, and the merge queue stops waiting on things that belong to the apply lane. No gate that catches a real defect is removed. Production applies keep every proof they have today.

**If a step conflicts with this goal, the goal wins — stop and flag it.** Do not buy speed by skipping a production-data guard, an ordering guard, or the only check that catches real defects (the ephemeral replay + contract tests). If a stage turns out to need one of those to be weaker, stop and report it instead of merging the stage.

### 2. What this application is

`popcre/shared-db` is the canonical repository for the **shape** of POP Creations' shared Supabase database (the shared production Supabase project — its ref is the deliberate constant `PRODUCTION_PROJECT_REF` in `scripts/production_business_risk_gate.py`) used by CRM, DAM, PM/PIM and DesignFlow PLM. It holds timestamped SQL migrations (`supabase/migrations/`), contract tests (`supabase/tests/`), GitHub Actions workflows (`.github/workflows/`), Node coordination tooling (`scripts/`), and the operating rulebook (`AGENTS.md` + `docs/agents/`). A "structural migration" here means a change to the database's shape — table, column, view, function, trigger, RLS, index — landed as a new migration file and then applied to preview and production through automated lanes.

This plan is **repository maintenance** in that repo (workflows + scripts + docs), not a schema change. The plan file itself lives in `popcre/ai-devops` (this repo), which is the shared AI-toolkit repo where `plan_*.md` implementation plans are published.

Relevant identities: protected branch `main` on both repos; merge via pull request only; preview project comes from repository variable `PREVIEW_PROJECT_REF` (never hard-code a preview ref — it is rebuilt from time to time); the production project ref is a deliberate constant, not configuration (`PRODUCTION_PROJECT_REF` in `scripts/production_business_risk_gate.py`, read it from there — this plan deliberately does not repeat the value).

### 3. What triggered this work

Albert reported, 2026-10-30, the path a session just took to ship one structural migration (verbatim structure of the report):

> reserve exact objects + a permanent version number (paperwork rejected twice, ~40 min); static SQL guards; replay of every migration + contract tests on a throwaway database (~7 min/attempt); signed work-contract + evidence pair; Guarded Merge that re-proves everything under a lock (~20 min); merge queue (~30 min); preview rehearsal; automatic production promotion.

Goal given: *"a structural migration should take minutes of gating, not ~2 hours, without losing real safety."* The reported experience is confirmed by measurement — see §6 for the 28-PR sample where median open→merge is 147 minutes while actual CI execution is only 8 minutes.

AI review is already out of the critical path: owner ruling 2026-10-29 made review advisory (`docs/agents/merge-protocol.md` "Review is advisory"), and `scripts/check-exact-head-approval.mjs` no longer exists on `main` (only stale copies in scratch worktrees). This plan therefore does **not** touch review.

### 4. Scope

**IN** (what this plan changes): the pre-merge gating path of a structural migration PR in `popcre/shared-db` — claim paperwork, the work-contract evidence pair, duplicate static-guard executions, the merge queue's blocking waits, and the documents-only authorization mutex. Eight stages, each one small PR.

**NOT in this plan:**
- Any change to the production apply path: preview rehearsal, automatic production qualification, production dry-run, production apply review (business-risk gate), the serial production lane, promotion freezes, post-apply catalog verification, ledger checks, live proof. Stage 9 only *verifies* they are untouched.
- Any change to the database, a migration, RLS, or curated Master Data governance.
- Review policy (already advisory as of 2026-10-29 — do not relitigate).
- The release-hold duration program (`plan_shared_release_hold_reduction.md`, tracker #3779) — that plan shortens *lock hold times*; this one removes *duplicate gates*. They are complementary; do not redo its steps 3/8a (already merged) and coordinate on its steps 4–5 (they touch the same `guarded-migration-merge.yml` prepare/merge split).
- Narrow promotion freezes (`plan_narrow_promotion_freezes.md`, #4039) — separate proposal, not authorized, do not implement here.
- Reviewer assignment holds (`plan_reviewer_assignment_hold_reduction.md`, #4414) — already done and closed 2026-10-19.
- GitHub Actions *billing* reduction (`plan_actions-minutes-reduction.md`, ai-devops #1464) — cancelled by owner 2026-10-07 ("if it's just pennies, i don't really care"); different goal (cost vs wall clock).
- Deleting migration history, claims, or the version reservation mechanism.
- Changing consumer repos or `sync.yml` propagation.

---

## Part 2 — What we already know

### 5. Current state of the code

Everything below is on `popcre/shared-db` `main` @ `af8bd6b8f` (2026-10-30). Nothing in this plan has been implemented; every stage is open.

The pipeline a structural migration takes today, in order (full gate map with file references was derived this session from the workflows and scripts; condensed here):

| # | Gate | Where | Measured cost | Verdict |
|---|---|---|---|---|
| 1 | Author claim: exact-object claim + permanent 14-digit version reservation (`scripts/manage-migration-author-lanes.mjs --claim`) + `db-work-scope` block on the issue | pre-PR | reported ~40 min incl. 2 rejections | **Make automatic** (stages 1) |
| 2 | Static SQL guards (`scripts/check-sql.sh`, `check-production-verification-sidecars.mjs`, `check-applied-migration-edit.mjs`) | `shared-supabase-migrations.yml` `validate` job + 3 more places | 83 s median, run ≥4× per PR | **Merge** (stages 4, 5) |
| 3 | Ephemeral replay + contract tests (full migration replay on a throwaway DB, then every `supabase/tests/*.sql`) | `database-contract-tests.yml` | 337 s median (the "~7 min") | **KEEP** — the only real-defect catcher |
| 4 | PR static guards in `pr-guards.yml` (destructive SQL, cross-PR object collision, PII guard, domain ownership, …) | `pr-guards.yml` | 64–198 s per job | **KEEP** (collision re-checks stay under the lock; see stage 4 for which are deterministic) |
| 5 | Tools offline tests (guard self-test battery) | `tools-offline-tests.yml` | 59 s median | **Merge** into one place (stage 2) |
| 6 | Documents-only merge authorization (legacy required status; takes a **global coordination mutex**) | `documents-only-merge-authorization.yml` | 10-min budget; **15 failed runs across 12 of 28 PRs — the single largest failure source** | **Make automatic / skip** (stage 7) |
| 7 | Migration author lease (`check-migration-pr-lease.mjs`) — preceded by a ~40-file meta-test battery | `migration-author-lease.yml` | 65 s median; 7 failed runs across 5 PRs | **Keep the proof, cut the battery** (stages 1, 2) |
| 8 | Agent work-contract + completion pair (`.agent/work/<issue>/<generation>/contract.json` + `completion.json`), mode `enforced` since 2026-09-07 (`config/agent-work-contract-activation.json`) | `pr-guards.yml` `agent-work-contract` (runs on `merge_group`) | part of queue | **Make automatic** (stage 3) |
| 9 | Guarded Merge: `prepare` (outside lock) then `merge` under the exclusive `refs/db-coordination/merge` lease — re-runs every coordination guard under the lock | `guarded-migration-merge.yml` (prepare budget 30, merge budget 35 min) | reported ~20 min; lock contention | **Merge duplicates** (stages 4, 5) |
| 10 | Merge queue gate: re-runs check-sql + collisions + lease + live-proof probe, then **waits for the preceding migration's preview rehearsal** (up to 25 min) | `merge-queue-gate.yml` (verify budget 40 min) | 34 min median green→merged | **Merge duplicates + move wait** (stages 4, 6) |
| 11 | Preview rehearsal (exclusive preview lane, bounded apply) | `shared-supabase-migrations.yml` `preview` job (90 min budget) | off the PR path | **KEEP** |
| 12–17 | Automatic production qualification → dry-run → apply review (business-risk gate) → serial production apply + freeze + post-apply catalog verification | `shared-supabase-migrations.yml` production jobs (90 min budgets each) | off the PR path | **KEEP — no cuts** (stage 9) |
| 18 | Live proof probe (`.github/live-proofs/<issue>.sql`) | `check-live-proof-probe.mjs` | seconds | **KEEP** (presence checked 4× today; stage 5 makes it 1× per lock hold) |

Exact wiring references for the duplicate work (verified this session):
- `check-sql.sh` is invoked in `migration-ledger-drift.yml`, `pr-guards.yml`, `guarded-migration-merge.yml` (under lock, `guarded-migration-merge.yml:375-383` and again at `:431-433`), `merge-queue-gate.yml` (`merge-queue-gate.yml:184-189`), and `shared-supabase-migrations.yml` (3 sites) — **up to 7 invocation sites for one deterministic proof**.
- `check-migration-pr-lease.mjs` runs 3× inside one Guarded Merge run (twice in the `merge` job) plus once per `migration-author-lease.yml` run plus once in `merge-queue-gate.yml`.
- `check-live-proof-probe.mjs` runs 3× inside one Guarded Merge run plus `merge-queue-gate.yml` plus `migration-author-lease.yml`.
- `check-required-checks-preflight.mjs` runs twice in one Guarded Merge run (prepare + under lock) and a third time for the queue-retirement path.
- The meta-test battery (≈40 `*.test.mjs` files including the 959 KB `manage-migration-author-lanes.test.mjs` suite) runs in **three** workflows: `migration-author-lease.yml`, `tools-offline-tests.yml`, and partly `shared-supabase-migrations.yml` `validate`.
- `merge-queue-gate.yml:191-205` requires the latest preceding migration merge to have completed preview rehearsal before this group may merge (the "up to 25 minutes" bounded wait).
- `documents-only-merge-authorization.yml` creates/deletes a **global coordination mutex ref** to publish a per-PR status ("The base-only manager creates and deletes the global coordination mutex ref" — workflow header); every migration PR takes this path and 15 failed runs landed there in the sample.

### 6. Key findings and root cause (measured)

**Sample:** 28 merged PRs touching `supabase/migrations/` (PRs #4476–#5098, 2026-10-18 → 2026-10-30), collected 2026-10-30 via `gh` check-run history. Full per-PR table kept in this session's scratch at `popcre/shared-db/.ai/gate-trim-pr-timings.md` (gitignored); aggregates below are the durable copy.

| Metric | Median | Mean | Min | Max |
|---|---|---|---|---|
| Open→merge wall clock | **147 min (~2.5 h)** | 413 min | 35 min | 3,238 min (~54 h) |
| CI wall time (checks actually running) | **8 min** | 18 min | 4 min | 289 min |
| Ephemeral replay + contract tests | 337 s (~5.6 min) | 334 s | 227 s | 409 s |
| SQL migration guards | 83 s | 89 s | 59 s | 175 s |
| Migration author lease | 65 s | 70 s | 47 s | 105 s |
| Cross-PR object collision | 84 s | 89 s | 64 s | 198 s |
| Tools offline tests | 59 s | 59 s | 33 s | 144 s |
| Merge queue wait (all checks green → merged) | **34 min** | 92 min | 5 min | 443 min |

**Failure census — 40 failed workflow runs across 21 of 28 PRs (75% had ≥1 failure):**

| Class | Failed runs | PRs | What it means |
|---|---|---|---|
| Paperwork — Documents-only merge authorization | 15 | 12 | A required legacy status re-proving "this is not prose" under a global mutex; failed at the mutex, not on content |
| Paperwork — Migration author lease (claim/branch binding) | 7 | 5 | Claim not set up, not branch-bound, or version reservation missing at check time |
| Paperwork — SQL migration guards | 6 | 5 | Static lint rejections of the migration text (format/derived-from/EOL rules) |
| **Real defect** — Database contract tests | **7** | **6** | Actual SQL/contract breakage caught by the replay + `supabase/tests` |
| Infra — preview dry-run lock contention | 1 | 1 | 22 s refusal, re-run cleared it |

**Root cause of the ~2 hours, in one sentence each:**
1. **Waiting, not checking.** 95% of wall clock is idle: median CI is 8 minutes, median green→merge is 34 minutes, and the mean open→merge (413 min) is dominated by queue/lock waits and re-push cycles (outliers #4700 at 54 h and #4702 at 43 h had 7–9 min CI).
2. **Paperwork causes 80% of failures and each failure costs a full re-push cycle** (new head → all checks rerun → queue again): 32 of 40 failed runs are docs-auth / lease / static-guard paperwork, not defects. A PR with 3 paperwork failures (e.g. #4984, #4966, #5018) burns 30+ minutes of cycles.
3. **Deterministic proofs are re-executed serially at three or four stages** (CI, guarded merge under the lock, merge queue) even though the inputs — the head tree and base tree — have not changed. The only reason to re-run under a lock is *drift* (base moved, or GitHub-side state changed). Non-drift re-runs add minutes inside the exclusive merge lane and minutes inside the queue.
4. **The merge queue blocks on an apply-lane ordering fact** (`--require-preview-rehearsal`, up to 25 min) even though merging SQL text into git writes no database. The ordering that protects data lives in the preview and production lanes, which are already serialized with exclusive leases.
5. **The documents-only route takes a global mutex to publish a per-PR status**, and it is a required context on every PR — so migration PRs queue behind an irrelevant lock 15 times in the sample.
6. **The work-contract pair is hand-authored paperwork** (mode `enforced` since 2026-09-07) whose content is derivable from the claim that was already validated; each mismatch costs another rejection cycle. With review advisory since 2026-10-29, this pair no longer gates any human decision.

**What is genuinely protecting something (do not cut):** the ephemeral replay + contract tests (7 of 7 real defects caught there; 0 real defects caught by any paperwork gate in the sample); exact-object claims + permanent version reservation (prevents the 2026-07-31 four-way duplicate-version silent-skip incident); cross-PR object collision; the exclusive preview/merge/production leases and the production freeze; main-tip freshness under the lock; the business-risk gate and post-apply catalog verification; ledger and live-proof requirements.

### 7. Approaches considered and REJECTED, and why

- **REJECTED: cut the ephemeral replay (5.6 min) or run only "affected" tests.** It is the only gate that caught a real defect in the sample (7 runs / 6 PRs). A partial replay loses the from-empty apply proof (the replay exists because a migration can fail to apply from empty while linting green — the 170 intentional `ci-bootstrap/` marker files mean clean-slate replay is subtle). Not worth it at 5.6 minutes.
- **REJECTED: drop Guarded Merge entirely and merge from the queue alone.** The under-lock freshness + collision + lease re-check is the guard against TOCTOU between "checks green" and "merge" (the 2026-08-11 pin-refusal incident class; `check-main-tip-freshness.mjs`). What is wasteful is re-running *deterministic* proofs there, not the lock itself. Keep the lock and the live GitHub-state checks under it.
- **REJECTED: delete the work-contract pair outright.** It is the only written record of what an agent was authorized to touch (`scripts/agent-work-contract.mjs` header explains the forgery limits honestly). Deleting it reopens unbounded scope drift in *non-object* files (workflows, scripts, docs). The cut is *auto-generation* from the claim (stage 3), which keeps the record and removes the authoring.
- **REJECTED: let migration PRs skip the docs-only authorization check entirely with no replacement status.** It is a legacy required context; removing a required context is a branch-protection change with its own blast radius. The cut is (a) stop taking the global mutex for it and (b) skip-with-success for PRs that carry an open claim (whose lease check already proves they are not prose) — stage 7. The classifier itself stays for unclaimed PRs.
- **REJECTED: parallel production applies or removing the production freeze.** Out of scope; the 2026-08-11 incident (merges landing mid-apply) is exactly what the freeze prevents.
- **REJECTED: speeding up by relaxing exact-object claims or version reservation.** These two are what stopped the 2026-07-31 silent-skip class. They are kept; only their *authoring UX* changes (one-shot validation, stage 1).
- **REJECTED: merging the queue's predecessor-rehearsal wait into "just check it didn't fail".** A pass/fail check that returns immediately would silently allow the un-rehearsed predecessor case the wait exists for. The wait is *moved*, not weakened: it becomes a precondition of the preview lane and of production promotion, where the ordering fact actually matters (stage 6).
- **REJECTED: one giant "make CI faster" PR.** Eight stages are deliberately separate so each merges one at a time and each is individually revertable (§9).

### 8. Design decisions already made (locked vs open)

**LOCKED (do not relitigate):**
- Review stays advisory (owner ruling 2026-10-29). No gate may require an AI verdict before merge or production promotion.
- The ephemeral replay + full `supabase/tests` suite stays a required check on migration PRs, at full breadth.
- Exact-object claims, permanent 14-digit version reservation, cross-PR object collision, and the three exclusive lanes (preview, merge, production) stay.
- Production apply keeps: preview rehearsal evidence, the business-risk gate deriving its own conclusions (never caller-written booleans), bounded allowlists, exact-target proof before every write, the serial lane, promotion freeze, post-apply catalog verification, live proof.
- One stage = one PR = one revertable unit. No combined gate changes in a single PR.
- This plan authorizes no implementation by itself. Albert approves; then stages merge in order.

**OPEN (implementer's judgment, with criteria):**
- Whether stage 3 auto-generates the pair via a workflow step at PR-open time or via the claim tool at author time. Criterion: the author must never hand-write either file, and the validator (`--validate-contract` / `--validate-completion`) must still reject a pair that contradicts the claim.
- Whether stage 4 stores the deterministic verdict as a commit status or as a small artifact. Criterion: the later stage can prove "same (head, base) already proven by job X run Y" without network fan-out; and an absent record always fails closed (re-run).
- Whether stage 6 leaves a non-blocking advisory signal in the queue for visibility. Criterion: it must not acquire the preview lane and must not block the merge.
- Which guards are truly non-deterministic and therefore always re-run under the lock even after stage 4 (expected: anything reading GitHub API state or quota — `check-pr-object-collisions.mjs`, `check-migration-pr-lease.mjs`, `check-required-checks-preflight.mjs`, `check-actions-quota.mjs`, `check-main-tip-freshness.mjs`). Criterion: the plan's adversarial table (§9) must name each guard exactly once as deterministic or live.

---

## Part 3 — How to build it

### 9. The plan — stages, steps, verification gates

All stages are **repository maintenance** in `popcre/shared-db` (workflows/scripts/docs only — no migrations). Route: ordinary maintenance route (`docs/agents/current-workflow.md`), own worktree per `docs/agents/worktrees-and-handoffs.md`, branch + PR, guarded merge as usual. Each stage below is one PR, merged before the next starts. Re-read this section before each stage (drift check).

#### Stage 1 — One-shot claim preflight (cut the paperwork loop at the source)

**What to change:**
- `scripts/manage-migration-author-lanes.mjs` (entry) and `scripts/lib/lanes/claims.mjs` / `queue-routing.mjs`: add a `--claim-preflight` (or `--claim --dry-run`) mode that runs **every** admission validation and prints **all** rejection reasons in one pass — scope block parse (`db-work-scope`: `status`/`work_type`/`route`/`priority`/`depends_on`/`writes:`/`reads:`), work-type↔route matrix (`ROUTES_BY_WORK_TYPES` in `queue-routing.mjs`), writes-vs-reads overlap refusal, legacy `objects:` mixing refusal, "structural must declare at least one write", object syntax (`table schema.name` etc.), branch/worktree absolute-path checks, version-reservation syntax, issue-binding. Today these fire one at a time across retries; preflight must aggregate them (collect-then-throw, not throw-on-first).
- Keep the enforcement path unchanged — preflight must call the **same** validators (one source of truth), so preflight success ⇒ claim success unless GitHub state changed between the two calls.

**Behavior when done:** a session runs one preflight command, gets a complete list of what is wrong (or `OK`), fixes them all, then claims once. Zero claim rejections on correctly authored input.

**Verification gate:** `node --test scripts/lib/lanes/claims.test.mjs scripts/manage-migration-author-lanes.test.mjs` gains `claim_preflight_reports_all_reasons_at_once` (feed a scope block with 3 simultaneous faults; assert all 3 appear in one output and nothing was written) and `claim_preflight_ok_then_claim_succeeds` (happy path). Live proof on the tracker issue: one real claim through preflight with no retry.

**Risk each cut reopens:** a preflight that drifts from the enforcement path (preflight says OK, claim refuses). Mitigated by both calling the same functions; the adversarial row below names the test.

#### Stage 2 — Slim the Migration author lease check

**What to change:**
- `.github/workflows/migration-author-lease.yml`: remove the big `node --test …` meta-battery step (the ~40-file list starting `scripts/db-flow/*.test.mjs` etc. — the step named "Run coordination and db-flow tests"). Keep: quota check, the `Require a valid branch-bound claim and permanent version reservation` step (`check-migration-pr-lease.mjs`), status publication. Target job time: seconds, not a minute-plus.
- The meta-battery stays exactly once, in `tools-offline-tests.yml` (it already runs there). Do **not** delete any test.

**Behavior when done:** `Migration author lease` is a fast, single-purpose proof of the claim; guard self-tests run in one place.

**Verification gate:** workflow run on a test PR shows `Migration author lease` completing with only the lease steps; `tools-offline-tests.yml` still green on the same head; `node --test scripts/check-migration-pr-lease.test.mjs` unchanged and green.

**Risk reopens:** a broken guard self-test is discovered later (at tools-offline or on main) instead of on every PR push. Accepted: tools-offline is itself a required check on the same PR, so the discovery still pre-dates merge.

#### Stage 3 — Auto-generate the work-contract + completion pair

**What to change:**
- `scripts/agent-work-contract.mjs` + a new small generator (e.g. `scripts/generate-work-contract.mjs`) or a `--generate` mode: from the open claim (issue number, generation, `writes:`/`reads:`, branch, head SHA) emit `.agent/work/<issue>/<generation>/contract.json` and a matching `completion.json` skeleton whose validation the existing `--validate-contract` / `--validate-completion` paths accept. Generation happens either in the claim tool run (author time) or as a trusted-base workflow step at PR open (see OPEN decision in §8).
- Keep `config/agent-work-contract-activation.json` mode `enforced` and keep the validator rejecting hand-written pairs that contradict the claim. Remove the need for a human/AI to author the JSON.

**Behavior when done:** no session hand-writes contract/completion JSON; the pair is always present, always valid, always consistent with the claim. The `Enforced mode requires this pull request to change both …` failure (`pr-guards.yml` around the `agent-work-contract` job) can still fire only when someone bypasses generation.

**Verification gate:** tests `scripts/agent-work-contract.test.mjs` gain `generated_pair_validates` and `generated_pair_mismatching_claim_is_rejected`; live proof: one migration PR where the pair appears without being hand-authored and `Agent work contract` is green at merge-group time.

**Risk reopens:** a generated contract is too permissive (wider than the claim). Mitigated: generator copies the claim's object lists verbatim; the validator still enforces claim-consistency; test names the hostile case.

#### Stage 4 — Deterministic-guard verdict binding (run once per head+base)

**What to change:**
- Introduce a tiny shared helper (e.g. `scripts/lib/guard-verdict-binding.mjs`): a commit status or artifact keyed by `(guard name, head_sha, base_sha)` recording "guard G passed for this pair at run R".
- Deterministic guards (pure functions of the checked-out tree + diff): `check-sql.sh`, `check-production-verification-sidecars.mjs`, `check-applied-migration-edit.mjs`, `check-live-proof-probe.mjs`, and the static halves of the pr-guards jobs. These: run once in PR CI; the later stages (`guarded-migration-merge.yml`, `merge-queue-gate.yml`) **skip re-running** them when a recorded green verdict exists for the same `(head, base)` and **re-run when base moved** (no verdict for the current base) or when no verdict exists. Fail closed on any unreadable record.
- Live GitHub-state guards are exempt and always run at every stage (the TOCTOU guards): `check-pr-object-collisions.mjs`, `check-migration-pr-lease.mjs`, `check-required-checks-preflight.mjs`, `check-main-tip-freshness.mjs`, `check-actions-quota.mjs`, and anything reading ledgers or API state.

**Behavior when done:** one deterministic proof per (head, base); lock-time and queue-time only prove what can actually have changed.

**Verification gate:** unit tests for the binding helper (`verdict_for_same_pair_is_reused`, `verdict_for_moved_base_is_not_reused`, `missing_verdict_fails_closed`, `tampered_verdict_fails_closed`); workflow-level proof: a Guarded Merge run on an unmoved base logs "skipped (proven at run R)" for check-sql.sh; a second run after a base push logs a fresh execution.

**Risk reopens:** a guard that is not actually deterministic silently skips a needed re-run. Mitigated by the explicit live-vs-deterministic classification table in this plan (§9 adversarial table) and the fail-closed default.

#### Stage 5 — One execution per guard per lock hold

**What to change:**
- `guarded-migration-merge.yml` `merge` job: today `check-migration-pr-lease.mjs` and `check-live-proof-probe.mjs` each run in both the `Require current main and rerun every applicable coordination guard` step (`:375-383`) and again in `Re-prove the head and merge` (`:431-433`), and `check-required-checks-preflight.mjs` runs in the under-lock preflight and again in `prove_retained_all14`. Collapse to **one** invocation each per lock hold, in a single under-lock step, after the lock is acquired and after freshness is proven. Keep every guard; remove only the repeats within the same hold on the same head.

**Behavior when done:** the lock is held for a shorter time with identical proof coverage; the log shows each guard exactly once per hold.

**Verification gate:** `scripts/guarded-merge-preparation-split.test.mjs` (existing) extended with `each_coordination_guard_runs_once_per_hold`; live run log grep proving 1× occurrences.

**Risk reopens:** none to coverage — the same guards run in the same hold; the only loss is a second execution of an idempotent read within seconds of the first. Named anyway per instructions: a guard whose second run could catch a mid-hold state change (GitHub state changing between the two runs inside one hold). Accepted: the first run is the authoritative under-lock read; mid-hold changes are absorbed by the freshness/authorization re-checks that follow.

#### Stage 6 — Move the predecessor-rehearsal wait out of the merge queue

**What to change:**
- `merge-queue-gate.yml` (`:191-205`, `Require the latest preceding migration merge to have completed preview rehearsal`): stop failing/waiting the merge group on this. Merge of SQL text into git writes no database.
- Move the ordering precondition to where the data lives: the preview lane (`shared-supabase-migrations.yml` `preview` job) and the automatic production qualification job must refuse to start a rehearsal/promotion while the immediately preceding merged migration version lacks a completed preview rehearsal. The existing serialized preview lane and `preview-ledger-predecessor-not-on-main` graph logic already encode the same ordering; this stage makes the *merge* path not re-implement it.

**Behavior when done:** migration B may merge while migration A's rehearsal is still running; B's own rehearsal and B's promotion still wait behind A's. The rehearsal sequence on the shared preview ledger stays contiguous.

**Verification gate:** `scripts/merge-queue-contract.test.mjs` gains `queue_group_merges_without_predecessor_rehearsal` and the preview side gains `preview_rehearsal_refuses_unrehearsed_predecessor`; live proof on the tracker: two sequential migration PRs, second merges before first's rehearsal completes, second's rehearsal starts only after the first's completes.

**Risk reopens:** the "preview-ledger-predecessor-not-on-main" class — a preview rehearsal whose predecessor is merged-but-unrehearsed. That is exactly what the moved precondition refuses at the preview lane; the risk is real only if the move is implemented in one lane and not the other. The stage is not done until **both** sides (queue no longer waits, preview/production refuse) are in the same PR.

#### Stage 7 — Documents-only authorization without the global mutex

**What to change:**
- `documents-only-merge-authorization.yml` + `scripts/check-documents-only-merge-authorization.mjs` / `scripts/repository-maintenance-authorization.*`: publish the per-PR status **without** taking the global coordination mutex (the classifier is a pure read of the PR diff; the status write is per-PR and the workflow already has a per-PR concurrency group). Reserve the mutex for operations that actually mutate shared refs.
- Additionally: if the PR carries a valid branch-bound claim (the lease check's fact), the job concludes "not documents-only — claimed structural/migration work" immediately and exits success without further machinery.

**Behavior when done:** migration PRs never queue behind this status; prose PRs still get the documents-only path; a structural change with no claim still cannot ride the prose fast lane (classifier + lease check both refuse).

**Verification gate:** `scripts/check-documents-only-merge-authorization.test.mjs` gains `claimed_pr_authorizes_without_mutex`; live proof: two PRs opened simultaneously (one migration, one prose) both publish their statuses without serialization.

**Risk reopens:** two simultaneous publishes of the same status racing. Mitigated: per-PR concurrency group already serializes within a PR; cross-PR races touch different statuses.

#### Stage 8 — Replay bound to the migrations tree hash

**What to change:**
- `database-contract-tests.yml`: record a verdict keyed by the tree hash of `supabase/migrations/**` + `supabase/tests/**` + `supabase/ci-bootstrap/**` (and the workflow itself) against `base_sha`. If a new push changes only files outside that set (e.g. `.agent/**` evidence pairs), skip the replay with a truthful "not applicable — SQL surface unchanged" result citing the proven run. Any change inside the set reruns the full replay.

**Behavior when done:** evidence-only pushes (the common consequence of stage 3 and of paperwork fixes) do not burn 5.6 minutes.

**Verification gate:** `scripts/check-sql.test.mjs`-style test for the hashing (`tree_hash_unchanged_skips`, `test_file_change_reruns`, `migration_change_reruns`); live proof: a push touching only `.agent/` files shows the replay skipped with the citation.

**Risk reopens:** a file outside the hashed set influencing replay results (e.g. `scripts/` used by the replay runner). Mitigated: include the runner entry points in the hash; default is re-run.

#### Stage 9 — Production path: verify, do not touch

**What to change:** nothing. A read-only audit run that lists the production-path gates (preview rehearsal, automatic production qualification + business-risk gate, production dry-run, production apply review, serial apply + freeze, post-apply catalog verification, ledger drift, live proof) and confirms none of stages 1–8 altered their workflows, scripts, or evidence requirements. Publish the list in the tracker issue. If any stage diff touched a production-path file, that stage is reverted or re-scoped — not merged.

**Verification gate:** `git diff <baseline>..main -- .github/workflows/shared-supabase-migrations.yml scripts/production_*.py scripts/production_migration_guard.py` is empty of semantic changes across stages 1–8 (stage 6 legitimately touches the preview-queue precondition inside this workflow — that one line is expected and must be the only change, with the ordering refusal living there).

**Adversarial-cases table** (trust-boundary inputs; every row names its test):

| External input | Hostile case | Guard / test that proves it |
|---|---|---|
| Claim scope block (`db-work-scope`) | 3+ simultaneous faults; preflight must list all, write nothing | stage 1: `claim_preflight_reports_all_reasons_at_once` |
| Claim scope block | Preflight says OK but enforcement refuses (drift) | stage 1: `claim_preflight_ok_then_claim_succeeds` |
| Claim scope block | `objects:` mixed with `writes:`, or same object in writes and reads | existing refusals in `queue-routing.mjs`/`claims.mjs` — must stay green |
| Work-contract pair | Generated pair wider than the claim (extra objects) | stage 3: `generated_pair_mismatching_claim_is_rejected` |
| Work-contract pair | Hand-written pair that contradicts the claim | existing `--validate-completion` refusal — must stay green |
| Guard verdict record | Missing record at a later stage | stage 4: `missing_verdict_fails_closed` |
| Guard verdict record | Tampered / reused for a different (head, base) | stage 4: `tampered_verdict_fails_closed`, `verdict_for_moved_base_is_not_reused` |
| Guard verdict record | Non-deterministic guard misclassified as deterministic | stage 4 classification table; live guards listed in §8 OPEN and re-run always |
| GitHub state (collisions) | Another PR claims the same object between green and merge | always re-run under lock (kept in stage 4/5 live list) |
| GitHub state (lease) | Claim released/expired between green and merge | always re-run under lock (kept) |
| Base branch | Main moves after CI green | `check-main-tip-freshness.mjs --contains` under lock (kept) |
| Predecessor migration | Merged but un-rehearsed predecessor | stage 6: preview/production refusal test `preview_rehearsal_refuses_unrehearsed_predecessor` |
| Replay tree hash | Test file changed but hash set forgot `supabase/tests/` | stage 8: `test_file_change_reruns` |
| Documents-only status | Concurrent publish for the same PR | per-PR concurrency group (existing) + stage 7 test |
| Production dispatch | Any stage-1–8 diff on a production-path file | stage 9 audit gate |

### 10. Tests required

Named tests to add (each in the stage that introduces it):
- Stage 1: `claim_preflight_reports_all_reasons_at_once`, `claim_preflight_ok_then_claim_succeeds` (`scripts/manage-migration-author-lanes.test.mjs` or `scripts/lib/lanes/claims.test.mjs`).
- Stage 2: no new unit test (workflow-level assertion); existing `scripts/check-migration-pr-lease.test.mjs` must stay green unchanged.
- Stage 3: `generated_pair_validates`, `generated_pair_mismatching_claim_is_rejected` (`scripts/agent-work-contract.test.mjs`).
- Stage 4: `verdict_for_same_pair_is_reused`, `verdict_for_moved_base_is_not_reused`, `missing_verdict_fails_closed`, `tampered_verdict_fails_closed` (new `scripts/lib/guard-verdict-binding.test.mjs`).
- Stage 5: `each_coordination_guard_runs_once_per_hold` (`scripts/guarded-merge-preparation-split.test.mjs`).
- Stage 6: `queue_group_merges_without_predecessor_rehearsal` (`scripts/merge-queue-contract.test.mjs`), `preview_rehearsal_refuses_unrehearsed_predecessor` (preview lane tests).
- Stage 7: `claimed_pr_authorizes_without_mutex` (`scripts/check-documents-only-merge-authorization.test.mjs`).
- Stage 8: `tree_hash_unchanged_skips`, `test_file_change_reruns`, `migration_change_reruns` (new small test next to the classifier).

Existing suites that must stay green on every stage PR: `bash scripts/check-sql.sh`; `node --test scripts/check-migration-pr-lease.test.mjs scripts/agent-work-contract.test.mjs scripts/merge-queue-contract.test.mjs scripts/guarded-merge-preparation-split.test.mjs`; the `tools-offline-tests.yml` battery; the full `database-contract-tests.yml` replay + `supabase/tests`.

### 11. Constraints, standing rules, and gotchas in force

- **Branch policy:** `popcre/shared-db` and `popcre/ai-devops` are both feature-branch + PR repos (`config/repository-policy.json`); never push to `main` directly; the AI merges its own PRs once checks pass (owner is not a technical reviewer — `AGENTS.md` §1). Sign every GitHub comment/body: `Posted by MiMo chat <id> on <machine>`.
- **Worktrees only** for edits (`docs/agents/worktrees-and-handoffs.md` §2.1-W): own current-upstream worktree per session; canonical checkouts are landing-only.
- **These changes are repository maintenance, not structural DB work** — no author lane, no migration version, no `db-work` claim is needed for the stage PRs themselves (they touch workflows/scripts/docs only). If a stage turns out to need a migration, stop: that is structural work and takes the claim-first route.
- **Never edit a merged migration file**; never add `apt-get` to SQL-guard jobs (AGENTS.md §5.2-A); every job keeps a `timeout-minutes` budget.
- **Rulebook files are NOT documents-only** (`scripts/lib/documents-only-change.mjs`) — a stage that touches `AGENTS.md`/`docs/agents/**` gets full engineering treatment.
- **Do not reintroduce a required AI-review gate** (owner ruling 2026-10-29). Do not recreate `check-exact-head-approval.mjs` (deleted from main; docs citations in `AGENTS.md` §5.0-C are historical).
- **Two platforms:** Windows (edge-dev) and Linux (hetz, edge-dev3) run reviewer/agent tooling; shared workflow scripts run on Linux runners but are often edited from Windows — LF endings, no GNU-only assumptions in `scripts/` that Windows sessions must run.
- **Gotcha — eventual consistency:** posting a commit status then immediately acting on it is a self-inflicted deadlock (observed PR #1175, documented in `guarded-migration-merge.yml`); any stage 4 status write must read back before dependents trust it.
- **Gotcha — merge_group checkouts:** on `merge_group` the checkout ref is the synthetic group commit and `origin/<base>` may not exist; fetch base explicitly (pattern already in `merge-queue-gate.yml` / `shared-supabase-migrations.yml` validate job).
- **Gotcha — a required check with a `paths:` filter goes stale** (AGENTS.md §5.2); none of the stage changes may reintroduce path filters on required contexts.
- **Do not `git pull` the installed `ai-devops` checkout**; work in a worktree cut from `origin/main` (as this plan was).

### 12. Access and environment

- `gh` CLI authenticated on the working machine (`edge-dev`); repos `popcre/shared-db`, `popcre/ai-devops`.
- Node 22 and Python 3.12 as pinned in the workflows; local tests run with `node --test <file>`.
- Secrets (locations only, never values): 1Password vault `vibe_coding` — "Supabase CLI Personal Access Token", "Supabase DB Password - shared POP database" (production), the preview DB password item. CI secrets referenced by the workflows (`SYNC_TOKEN`, `POP_AI_WATCHERS_*`, `MERGE_QUEUE_ADMISSION_*`, `SUPABASE_ACCESS_TOKEN`) exist in repository settings; this plan never needs to read them locally.
- Preview identity: repository variable `PREVIEW_PROJECT_REF` only. Production project ref is the constant in `scripts/production_business_risk_gate.py`.
- No local database is needed for stages 1–5, 7, 8 (unit tests only). Stage 6's preview-lane test runs in CI. Stage 9 is read-only diff audit.

---

## Part 4 — Landing it

### 13. Definition of done, risks, open questions

**Definition of done (whole plan):**
- [ ] Stages 1–8 each merged to `popcre/shared-db` `main` as its own PR, each with its named tests green.
- [ ] Stage 9 audit published on the tracker issue: production-path diff summary proving no semantic change (stage 6's single ordering line excepted and named).
- [ ] Measured outcome recorded on the tracker: on ≥5 migration PRs after stage 8, median open→merge ≤25 min and zero paperwork-class failures (docs-auth/lease/work-contract), with the per-PR table as evidence — citing run IDs, not counts alone.
- [ ] `- [ ] live proof` checklist items on the tracker issue completed per stage (this plan's STATUS rows cite artifacts when marked done; no bare numbers).
- [ ] `plan_shared-db-gate-trim.md` STATUS table updated by whoever executes each stage (mandatory plan-file gate — a plan goes stale the moment a stage lands).
- [ ] Nothing on the production path changed semantically (stage 9 verdict attached).

**Target total time (the number to judge success by):** median open→merge for a routine structural migration PR: **147 min today → ≤25 min**. Component budgets: claim+paperwork ≤2 min (zero retries), CI ≈8 min (replay kept), Guarded Merge ≤6 min under lock, merge queue ≤5 min.

**Risks and rollback:**
- Any stage is one PR and one revert. If post-merge behavior regresses (a paperwork failure returns, or a real defect slips where a cut was made), revert that PR first — do not patch forward blindly.
- The systemic risk is misclassifying a live guard as deterministic (stage 4). Rollback: mark that guard "always run" in the classification table and ship a one-line fix; the fail-closed default already covers unknown cases.
- The ordering risk in stage 6 is contained by implementing both sides in one PR; if only one side lands, revert it.
- The biggest residual unknown: the sample is 28 PRs over 12 days. If a quieter class of defect (rare SQL shapes) exists, only the replay catches it — which is exactly why the replay is kept.

**Open questions (with decision criteria):** the three items listed as OPEN in §8 (contract generation placement; verdict record medium; advisory signal in queue). None blocks stage 1.

**Routed assumptions made this session (state them, and what would change them):**
- The tracker issue is opened in `popcre/shared-db` (where the implementation lives and where gate-program trackers like #3779/#4039 live), while the plan file lives in `popcre/ai-devops` as instructed. If Albert wants the issue in `popcre/ai-devops` instead, move it; nothing else changes.
- "Minutes of gating" is interpreted as median open→merge ≤25 min for a routine migration PR. If Albert meant only the *active* gating time (checks actually running), today's median is already ~8 min and the cuts then target the lock/queue overhead instead — same stages, different headline number.

---

## Self-audit (implementation-plan-writer Mode A)

1. **Could a brand-new AI session with no project knowledge execute this plan to perfection without asking anything?** Yes — §2 defines the repos/identities, §5 gives the current gate map with file and line references, §9 names exact files and functions per stage with verification gates and an adversarial table, §11 names the standing rules (worktrees, no direct-to-main, sign-off, no apt-get, no review gate), §12 names access/secret locations. Gap found and fixed during drafting: stage 6 initially named only the queue side; both sides (queue + preview/production refusal) are now required in the same PR.
2. **Does the plan carry every piece of background and reasoning held this session, including rejected approaches?** Yes — §6 carries the measured 28-PR table and failure census (the durable copy of scratch data), §7 records all seven rejected approaches with reasons, §8 separates locked from open decisions. Gap found and fixed: the overlap with `plan_shared_release_hold_reduction.md` was implicit; §4 now states the boundary explicitly so a future session does not redo #3779's steps.
3. **Is the ultimate goal stated clearly enough for judgment calls when a step turns out wrong?** Yes — §1 states the goal in plain English with the explicit "goal wins — stop and flag it" rule, and names the non-negotiables (production guards, ordering guards, the replay). The two routed assumptions at the end of §13 state exactly what would change them.

Self-audit passed 2026-10-30.
