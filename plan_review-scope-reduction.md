# Plan — shrink AI review to shared-db work and a four-reviewer pool

Owner issue: [popcre/ai-devops#1714](https://github.com/popcre/ai-devops/issues/1714)
Handoff: [`HANDOFF.d/2026-10-13T2200Z-edge-dev3-claude-review-scope-reduction.md`](HANDOFF.d/2026-10-13T2200Z-edge-dev3-claude-review-scope-reduction.md)
Evidence: [`docs/review-waste-recommendation-2026-10-13.md`](docs/review-waste-recommendation-2026-10-13.md), [`docs/review-waste-analysis-2026-10-13.md`](docs/review-waste-analysis-2026-10-13.md)
Written 2026-10-13 by Claude chat `81cdf50d-ed3a-40d2-a846-988d73f7ae7e` on edge-dev3.

## STATUS (read first)

| Step | State | Evidence |
|---|---|---|
| 0. Inventory every place that requires or routes review | ✅ done 2026-10-13 | Inventory on issue #1714 (GATED stays; DISCRETIONARY/MEMBERSHIP/FREEZE surfaces listed) |
| 1. shared-db allocator: quarantine qwen + gemini | ✅ done 2026-10-13 | popcre/shared-db PR [#4272](https://github.com/popcre/shared-db/pull/4272) — `QUARANTINED_REVIEWERS=['grok-4.6','qwen-3.8-max','gemini-3.8-flash-high']`; `scripts/manage-migration-author-lanes.test.mjs` 849/849 |
| 2. ai-devops registry mirror + drift check | 🟡 code landed | `config/reviewer-registry.json` gemini+qwen absent; `tests/test-ai-review-doctor.sh` asserts the four-name pool; drift green after #4272 merges |
| 3. Review-required policy: discretionary review only for shared-db | 🟡 code landed | `AGENTS.md`, `docs/reviewer-rotation-rules.md` 13–14, `docs/model-setup.md`, `docs/task-router.md`, `docs/standing-rules-details.md` |
| 4. Freeze non-pool reviewer tooling (CI suites, preflight, doctor) | 🟡 code landed | `config/ci-suite-manifest.json` suspends grok-implement/qwen/gemini/claude-review suites; `test-ai-grok-review.sh` and `test-ai-codex-review.sh` stay running (GLM debate contract + Codex approval gate) |
| 5. Docs and skills updated in the same change | 🟡 code landed | rotation rules, model-setup, AGENTS.md, task-router, standing-rules, plan-index; qwen/grok/gemini/codex-reviewer skills FROZEN 2026-10-13 (frontmatter + body banner) |
| 6. Live proof | ⬜ open | — |

**Start at Step 6** (live proof) once this PR merges and shared-db #4272 is on main.

---

## Part 1 — Why

### 1. Ultimate goal

Albert pays for AI code reviews, and 92% of them found nothing. He wants to
stop paying for those reviews, and stop paying engineering time to keep ten
reviewer integrations working, while keeping the reviews that do catch real
problems. When this is done:

- AI review runs by default **only on shared-db work** plus the safety gates
  that already require it (installation, reviewer-safety, deployment,
  infrastructure, production).
- The rotation pool is exactly **Muse, DeepSeek, GLM, StepFun**.
- Every other reviewer (Grok, Qwen, Gemini, Kimi, Codex as reviewer, Claude
  as reviewer) stays **installed on the machines and callable by name**, but
  ai-devops changes no longer have to keep their wrappers, tests, or CI green.

**If a step conflicts with this goal, the goal wins: stop and flag it on #1714.**

### 2. What this application is

`popcre/ai-devops` (public, branch `main`, merge queue) is Albert's AI
toolkit: wrappers under `bin/` for each AI reviewer (`ai-muse`,
`ai-deepseek`, `ai-glm`, `ai-stepfun`, `ai-grok-review`, `ai-qwen`,
`ai-gemini`, `ai-kimi`, `ai-codex-review`, `ai-claude-review`), the review
front door `bin/ai-review`, the task-gate tool `ai-task-gates`
(`config/task-gates.json`), installers, and skills. Reviewer *membership*
is owned by `popcre/shared-db` file `scripts/lib/lanes/reviewer-roster.mjs`
(`REVIEWERS`, `RETIRED_REVIEWERS`, `QUARANTINED_REVIEWERS`,
`ACTIVE_REVIEWERS`). `config/reviewer-registry.json` in ai-devops mirrors it,
and `bin/ai-reviewer-membership-drift` (workflow
`.github/workflows/reviewer-membership-drift.yml`) fails on any mismatch.
Rules: [`docs/reviewer-rotation-rules.md`](docs/reviewer-rotation-rules.md).

### 3. What triggered this

The Jev full-archive analysis (2026-10-13) scored 2,290 paid reviews.
Discretionary reviews: 92% added nothing; real findings sat almost entirely
on shared-db work. Codex final-checks on tooling/dflow/oracle produced ~0%.
Albert's decisions in chat, 2026-10-13 (verbatim where quoted):

- Only review shared-db work (safety gates kept, per the agreed recommendation).
- Pool = Muse, DeepSeek, GLM, plus a fourth. "Grok got expensive. use Stepfun as the 4th."
- Remove the other reviewers from the maintained reviewer system, but "leave
  the harnesses/wrappers installed on the computers so i can call out a
  reviewer by name but not do the heavy maintenance".

### 4. Scope

In: allocator quarantine, registry mirror, review-required policy text and
gate config, CI/test freeze for non-pool wrappers, doctor/preflight output,
docs/skills.

**NOT in this plan:**
- Deleting any wrapper from `bin/` or uninstalling anything from machines.
- Removing any `REVIEWERS` row (rows stay forever; durable verdicts depend on them).
- Weakening `reviewer-safety`, installation, deployment, infrastructure,
  production, or shared-db promotion gates.
- Any database structure change.
- Re-tuning Codex as an *implementer*; only its use as a reviewer is in scope.

---

## Part 2 — What we already know

### 5. Current state (2026-10-13, ai-devops `origin/main` 7ac43715)

- shared-db roster `ACTIVE_REVIEWERS` today: `glm-5.3`, `qwen-3.8-max`,
  `muse-spark-1.3-contributor`, `gemini-3.8-flash-high`,
  `deepseek-v4.1-flash`, `stepfun-step-5-preview`.
- `QUARANTINED_REVIEWERS = ['grok-4.6']` (quarantined earlier today, out of credit).
- `RETIRED_REVIEWERS` = `glm-5.2`, `muse-spark-1.2-contributor`,
  `deepseek-chat`, `codex-gpt-5.6-sol`, `kimi-k3`.
- `config/reviewer-membership-scope.json` lists `codex` as outside the
  allocator (approval-gate wrapper).
- Qwen allowance is out until 2026-11-01 anyway (preflight already defers it).
- Per-wrapper CI suites are declared in `config/ci-suite-manifest.json`
  (e.g. `tests/test-ai-kimi.sh`, `test-ai-qwen*.sh`, `test-ai-gemini*.sh`,
  `test-ai-grok-*.sh`, `test-ai-codex-review.sh`, `test-ai-claude-review.sh`,
  Windows `test-kimi-windows-execution.ps1`, `test-windows-ai-kimi-shim.ps1`,
  `test-gemini-door-*.sh`). Doors in `config/review-runner-doors.json`;
  capacity probes in `config/reviewer-capacity.json`.

### 6. Key findings

Yields from the analysis (discretionary, real-finding rate): DeepSeek 50%
(n=12), Muse 26% (n=35), GLM 22% (n=9), Qwen 17%, Grok 16%, Gemini 14%,
Codex-as-reviewer 1% (n=344), Kimi 0%. StepFun was not in enough of the
archive to score; it is chosen on owner preference and cost. Mode
final-check / diff-review / plan-review = 1–3%.

### 7. Rejected approaches

- **Retiring** qwen/gemini (`RETIRED_REVIEWERS`): rejected — retirement is
  permanent; owner wants them callable and revivable. Use quarantine.
- **Deleting wrappers/tests from the repo**: rejected — owner wants them
  still installed and callable; deletion would also break installers.
- **Keeping Grok as the 4th**: rejected by owner 2026-10-13 (cost).
- **Skipping review everywhere except shared-db including safety gates**: rejected; safety gates are assurance.
- **Codex-only skip rule** (recommendation option 1): superseded by the
  broader owner decision "only review shared-db".

### 8. Decisions

Locked (owner, 2026-10-13): pool of four; shared-db-only discretionary
review; safety gates untouched; non-pool tooling frozen, not deleted.
Open (implementer judgment): exact mechanism for freezing CI suites (Step 4
criteria); exact wording in docs.

---

## Part 3 — How to build it

### 9. Steps

**Step 0 — inventory.** `grep -rn` ai-devops for `final-check`,
`diff-review`, `plan-review`, `exact-head-independent-review`,
`assigned-ai-reviewer-approval`, and reviewer names in `AGENTS.md`,
`docs/standing-rules-details.md`, `config/task-gates.json`,
`config/repository-policy.json`, `skills/shared/**`, `templates/system/**`,
`bin/ai-review`, `bin/ai-review-pool`, `bin/ai-review-preflight`. Record the
list on #1714. *Done when* every rule that tells a session "get a review
before landing" is listed with file:line and classified gated vs discretionary.

**Step 1 — shared-db allocator (popcre/shared-db PR).** In
`scripts/lib/lanes/reviewer-roster.mjs` add `'qwen-3.8-max'` and
`'gemini-3.8-flash-high'` to `QUARANTINED_REVIEWERS` (keep `'grok-4.6'`),
with a dated comment quoting Albert. Follow `shared-db-change` skill rules for
that repo's tooling PR lane and its reviewer. *Done when* `ACTIVE_REVIEWERS`
names are exactly glm-5.3, muse-spark-1.3-contributor, deepseek-v4.1-flash,
stepfun-step-5-preview, proven by the repo's roster tests and a node one-liner
printing `ACTIVE_REVIEWERS.map(r=>r.name)`.

**Step 2 — ai-devops mirror.** Update `config/reviewer-registry.json` to
match; leave `codex` in `reviewer-membership-scope.json` only if Codex stays
an approval-gate helper (it does for gated classes). *Done when*
`bin/ai-reviewer-membership-drift` exits 0 after Step 1 merges, and
`ai-review doctor` lists only the four as rotation.

**Step 3 — review-required policy.** Change every *discretionary* rule found
in Step 0 so a review is required only when the change touches
`popcre/shared-db`, or the task class's gate already demands one
(installation, reviewer-safety, deployment, infrastructure, production,
shared-db promotion). Everything else: review optional, available on request
by name. Do not edit gate requirements in `config/task-gates.json` for those
gated classes. *Done when* a docs-only or tooling ai-devops PR can land with no
review under the written rules, and `ai-task-gates check` for a gated class
still demands one (run both; paste output on #1714).

**Step 4 — freeze non-pool tooling.** For grok, qwen, gemini, kimi,
codex-review (as reviewer), claude-review: remove their suites from required
CI in `config/ci-suite-manifest.json` / `config/reviewer-ci-paths.txt` (or
mark them non-required) so changes to shared code no longer have to keep them
green; drop them from `ai-review-preflight` rotation status and
`ai-review-credit-watch`/start-watch if those page on them. Leave `bin/`
wrappers, installers, and skills in place, labeled "frozen 2026-10-13 —
best-effort, not maintained" in each skill's description. Judgment criterion:
if removing a suite would also drop coverage of shared code used by a pool
reviewer, keep that part. *Done when* full CI is green on the PR and the
removed suites no longer run on an unrelated change.

**Step 5 — docs.** Update `docs/reviewer-rotation-rules.md`,
`docs/standing-rules-details.md`, `AGENTS.md` router, and the four pool
skills plus frozen skills, in the same PR as Steps 2–4 (rotation rule 3:
policy lands everywhere at once). Add this plan to
`docs/implementation-plan-index.md`.

**Step 6 — live proof.** One real shared-db review allocated to a pool
member returns a well-formed VERDICT; one by-name call to a frozen reviewer
(e.g. `ai-gemini`) still runs on edge-dev3. Record on #1714 and tick
`live proof`.

Order: 0 → 1 → 2–5 (one ai-devops PR, after Step 1 merges) → 6.

### 10. Tests

- shared-db: existing roster/allocator tests must pass; add an assertion that
  `ACTIVE_REVIEWERS` equals the four names.
- ai-devops: `bin/ai-reviewer-membership-drift` green; existing suites for
  `ai-muse`, `ai-deepseek`, `ai-glm`, `ai-stepfun`, `ai-review`,
  `ai-review-engine`, `ai-task-gates` stay green; add a check (in the
  ai-review-pool or doctor test) that rotation output is the four names.

### 11. Constraints and gotchas

- Never push to `main`; branch + PR + merge queue. Merge it yourself.
- Membership changes start in shared-db; the drift workflow will fail if
  ai-devops lands first.
- Quarantine, never retire; never delete `REVIEWERS` rows.
- Reviewer for the ai-devops PR: pick an in-rotation engine different from
  yours via `ai-review`. Safety gates still apply to this change because it
  touches reviewer-safety tooling.
- Times in EST. Sign GitHub posts with chat id and machine.

### 12. Access

`gh` authenticated as u2giants on edge-dev3; reviewer keys come from the
per-user protected store (rotation rule 6), never `op` during a review.

---

## Part 4 — Landing

### 13. Done, risks, open questions

Done: shared-db PR merged; ai-devops PR merged with CI green; drift check
green; live proof on #1714; STATUS table and plan index updated.
Risks: a pool member outage leaves three (acceptable; owner chose four);
frozen wrappers rot (accepted). Rollback: remove names from
`QUARANTINED_REVIEWERS` and revert the ai-devops PR.
Open: whether Codex stays the approval-gate helper for gated classes — default
yes (no change), flag on #1714 if Step 0 shows otherwise. Re-measure yields in
30 days (by 2026-11-12).

## Self-audit

1. Fresh session can execute without asking? Yes — §2, §5, §9 name files,
   names, and checks.
2. Carries background and rejected options? Yes — §3, §6, §7.
3. Goal clear enough for judgment calls? Yes — §1 and the Step 4 criterion.
