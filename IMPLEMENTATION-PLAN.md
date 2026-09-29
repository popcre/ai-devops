# IMPLEMENTATION PLAN — CI fast-fail + reviewer timeout diagnosis + orphan reap (2026-09-29)

> **Revision 2026-09-29 (after owner challenge + StepFun re-rank).** The first draft
> led with a small doctor spawn guard. That under-shot the transcript losses
> (6h suite ×25 reruns; 30 queued runs; slow reviewers marked broken). Priority
> is now hours saved. Doctor orphan guard drops to a small residual (step D1).

| Step | Status | Evidence |
|---|---|---|
| 0. Plan written and registered | ✅ done 2026-09-29 | this file + `HANDOFF.d/2026-09-29T2148Z-edge-dev-mimo-doctor-orphan-guard.md` |
| **A1. P3: stop long suites after a known failure + no-progress detector** | ⬜ open | **top hours: 10–20/wk** |
| **A2. P7: timeout ≠ broken reviewer (bounded first probe + retry/cooldown)** | ⬜ open | **5–12/wk** |
| **B1. Session/task TTL + reap (14h orphans) under BlockerWatch** | ⬜ open | **3–8/wk** |
| C1. Correct handoff §5a lines (lease TTL; 10s window) | ⬜ open | |
| C2. Decision ledger: items 3/9 not done (correct citations) | ⬜ open | |
| C3. Index the 18 unlisted root `plan_*.md` | ⬜ open | |
| C4. Fold-routing lines for findings 5/6/7/8 | ⬜ open | |
| D1. Doctor orphan spawn guard + reconcile residual (small) | ⬜ open | after A1; keep |
| 7. Independent exact-head review per code PR | ⬜ open | |
| 8. Merge via queue + live proof per PR | ⬜ open | |

**Fresh session starts at step 1.** Re-read this STATUS table first. Do not re-derive or re-plan.

Companion handoff: [`HANDOFF.d/2026-09-29T2148Z-edge-dev-mimo-doctor-orphan-guard.md`](HANDOFF.d/2026-09-29T2148Z-edge-dev-mimo-doctor-orphan-guard.md)

---

## 1. The ultimate goal — what we are trying to achieve

Albert Hazan (non-technical owner of POP Creations) loses real money when his multi-model AI toolkit stops working. In September 2026 the toolkit's own **review health-check** ("doctor") started taking so long that every AI code review failed before it began. That outage is fixed for the worst path, but **one leftover scan in the same health-check can still grow without a bound** and recreate the same outage.

When this plan is done:

1. **A known failure stops the expensive test run** (no more six-hour suites re-run twenty-five times after we already knew the answer).
2. **A slow reviewer is not treated as a broken reviewer** (timeouts get a bounded retry, not "this provider is dead").
3. **Orphan background work is reaped** instead of living 14 hours and locking the machine.
4. Small leftovers (doctor orphan scan, index drift, rejected-item ledger) are cleaned up without a new planning book.

Owner position (2026-09-29): he is unqualified to choose technical work; the parent agent and one independent reviewer pick by **hours saved**, not by smallest diff. He was right that a doctor spawn guard alone would not "speed everything up."

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is Albert's public recovery and operating toolkit for a multi-model AI workflow. It is **not** an app, service, or database. It contains:

- Reviewer wrappers (`ai-glm`, `ai-muse`, `ai-grok-review`, `ai-gemini`, `ai-qwen`, …)
- Evidence tools (`bin/ai-review-sandbox`, `bin/ai-review-packet`)
- Task gates (`bin/ai-task-gates`), install scripts, skills, and docs

**Repos / branches**

| Item | Value |
|---|---|
| GitHub | `https://github.com/popcre/ai-devops.git` |
| Protected branch | `main` (merge queue; never push directly) |
| Feature branch for this work | `mimo/doctor-orphan-scan-guard` |
| Worktree | `C:\repos\ai-devops-wt-doctor-orphan-guard` |
| Canonical checkout (landing only) | `C:\repos\ai-devops` |
| Host | `edge-dev` (Windows; Git Bash at `C:\Program Files\Git\bin\bash.exe`) |

**Stack:** Bash + PowerShell installers + Node/Python helpers. Tests are Bash suites under `tests/`. No UI.

## 3. What triggered this work

A session classified ~1,346 private chat digests (2026-09-08→09-29) and deep-read 22 transcripts. Nine process findings came out (full text in `HANDOFF.d/2026-09-29T1357Z-edge-dev-mimo-digest-fix-and-process-plan.md` §5a). Four independent advisors (GLM, Gemini, StepFun, Qwen 3.8 Max) plus the parent agent debated the re-cut on 2026-09-29.

**Albert accepted (chat, 2026-09-29):** one small doctor-safety PR, no new plan book, drop the "easier tool upgrades" item.

**Incident that makes step 1 urgent:** `ai-glm doctor` once blew a governed preflight window so **every** GLM review failed. The worst path (per-record prune/reconcile sweep) was already moved out of doctor. The window is **10 seconds**, not 60 (`bin/ai-review-preflight` `CHECK_TIMEOUT`, default 10). Two cost centers remain inside that window (see §6).

## 4. Scope — in and out

### In scope

1. Spawn-count regression guard + batching for `glm_orphan_sandbox_report` in `bin/ai-glm`.
2. Bound `reconcile_implementation_records`' open-record path **or** name it as a dated residual with an owner (step 2 decides which).
3. Two handoff corrections in the existing digest-fix handoff (lease TTL wording; 10s window).
4. A short decision-ledger note: why findings 3 and 9 are **not** being done (with evidence).
5. Register 18 root `plan_*.md` files missing from `docs/implementation-plan-index.md`.
6. One written routing line per folded finding (4/5/6/7/8) on its existing owner plan or issue.

### NOT in this plan

- **No** new `plan_*.md` process programme (owner ruled this out; there are already 72 root plan files).
- **No** item 3 "pin-only qualification lane" — it contradicts owner ruling 2026-09-23 (see §7).
- **No** item 9 `ai-ci-status` tool or queue auto-cancel.
- **No** loss ledger (hours-lost table).
- **No** lease TTL / age-based slot release (design forbids it).
- **No** re-run of issue #168 plan-backlog consolidation as new work (it completed 2026-09-08).
- **No** changes to `bin/ai-review-sandbox` / packet digest logic (already landed as PR #1060 / `9d99ad24`).
- **No** Docker/podman install; Qwen reviews already work without Docker via `~/.qwen/settings.json` (`tools.sandbox: false`).

## 5. Current state of the code

### Already shipped (do not rebuild)

| What | Where | Notes |
|---|---|---|
| Doctor is "Report, never act" | `bin/ai-glm` doctor command comments; prune only on explicit `ai-glm prune` | Sweep removed from check path |
| Chunked record index | `bin/ai-glm` `glm_record_index` (batches ~100 files) | Replaces per-record spawns for the index |
| Spawn-cap test on record scan | `tests/test-ai-glm.sh` (~:844-848): stub `jq`/`stat`/`date`, assert spawn count `-le 6` for 270 records | **This is the instrument to extend** |
| Empty-report fail-closed | `bin/ai-review-pool` (~:288-298) | Invalid envelope / unbound verdict die |
| Lease liveness (reclaim, no TTL) | `plan_reviewer_lease_liveness.md` — STATUS Complete 2026-09-05 | Never free a slot on age alone |
| Grok version floor (not pin) | `config/provider-cli-versions.json` grok `version_match: "minimum"` | Owner ruling 2026-09-23 |
| Gemini hash-pin + auto re-qual | `bin/ai-review-preflight` live-qualification | Existing design; do not generalize to Grok |
| Digest fix (`--full-index`) | PR #1060 merged `9d99ad24` on `origin/main` | Unrelated to this plan except context |
| Packet symlink test | Pre-existing Windows Git Bash `ln -s` copies files | Explained failure; out of scope |

### Open cost centers inside the 10s doctor window

1. **`glm_orphan_sandbox_report`** (`bin/ai-glm` ~:2177-2200), called from doctor (~:2749).
   Per unrecorded candidate directory: `stat -c %Y` + `sed -nE` (2 spawns). No cap. **No spawn-count test.** Only behavioural test (`tests/test-ai-glm.sh` ~:855-869) with 4 sandboxes.
   The set grows monotonically (nothing automatic sweeps unrecorded sandboxes).

2. **`reconcile_implementation_records` / `reconcile_implementation_record`** still runs in doctor.
   Settled records are skipped, but `implementation:open` (or `?`) records pay many `jq` reads, `canonical_path` (on Windows: `cygpath` + `tr` per call), and more. Documented cost: **>10 seconds per record on a loaded Windows host** (comment near the function). One open record can kill a 10s window.

### Untouched by this plan

Reviewer wrappers other than `ai-glm`'s doctor path; shared-db; installers; CI workflows.

## 6. Key findings and root cause

| Finding | Evidence | Consequence |
|---|---|---|
| Preflight check window is 10s | `bin/ai-review-preflight` `CHECK_TIMEOUT` default 10; wrapper `timeout "${CHECK_TIMEOUT}s"` | Any doctor path that can exceed 10s is a fleet-wide review outage |
| Worst sweep already removed | `bin/ai-glm` comments: prune clears backlog; doctor only reports | Do not "fix" doctor by re-adding sweeps |
| Orphan report is linear in unrecorded dirs | `bin/ai-glm` ~:2177-2200 | Unbounded cost on the same class of host |
| Reconcile open-record path is the larger per-record cost | Comments: ">10 seconds per record on a loaded Windows host" | Guarding only the orphan loop leaves the incident class open (Qwen, debate 2026-09-29) |
| Spawn-count is the right instrument | `tests/lib-test-timing.sh` header: spawn cost differs idle vs contended Windows; `budget()` is a ceiling scaler with a floor and **cannot detect per-record cost regression** | Use the existing spawn-stub pattern at `tests/test-ai-glm.sh:844-848` |
| Wall-clock asserts flake | `docs/development.md`; issue #89; `tests/lib-test-timing.sh` written as the remedy | Do not make the first PR a raw wall-clock test |
| Item 3 re-creates a live outage | Owner ruling 2026-09-23 on #686: exact pin "blocked every review whenever Grok updated itself"; now `version_match: "minimum"` | **Never implement a pin-only lane for auto-updating providers** |
| Hash-pin already exists where safe | `bin/ai-review-preflight` binds wrapper/agy/model hashes and re-qualifies | Do not re-propose "hash pin everything" |
| No lease TTL by design | `plan_reviewer_lease_liveness.md`: "never free a slot on age alone" | Handoff wording "lease TTL" is wrong and must be fixed at source |
| #168 backlog work is done | `tests/verification/repo-throughput/issue-168-plan-backlog.md` (2026-09-08, 48 files classified) | Do not re-run; the gap is **new** drift (18 plans added 2026-09-28/29 missing from the index) |
| Item 9 has no legal home / owner | `AGENTS.md` reuse rule; `plan_workflow-efficiency.md` P9 (queue median 7 min, lower priority) | Not a keep in any form. **Do not** cite P8 "status index" line as a tooling ban — that sentence is about document proliferation |

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| Write a 40th/73rd `plan_process-improvements.md` covering all nine findings | Owner + four advisors: reuse rule; overlaps five existing plans; self-inflicted registry rot |
| Keep item 3 (pin-only qualification) | **Owner ruling 2026-09-23** already replaced exact pins for Grok because they blocked every review on auto-update. A hash-pin lane is the same failure |
| First PR = `budget()` wall-time assertion on doctor | `budget()` cannot see per-record spawn regressions; wall-clock flake class is what `lib-test-timing.sh` exists to prevent. Spawn-count is deterministic |
| Guard only `glm_orphan_sandbox_report` | Qwen (debate): reconcile open-record path is the larger unguarded cost in the same 10s window |
| Implement item 9 as new `ai-ci-status` | No owner issue; reuse rule needs an owner + reason the shared home cannot serve; P9 names existing homes (`ai-pr-wait`, `ai-review-packet`, `tools/ci/verify-closure.sh`); auto-cancel risks exact-head evidence |
| Loss ledger (hours lost per incident class) | Evidence is single-source uncounted; `plan_workflow-efficiency.md` forbids making a measurement platform a prerequisite |
| Lease TTL / free slots on age | Explicitly forbidden by the completed lease-liveness design |
| Re-run #168 consolidation | Already done; re-running is "pay twice" (Qwen). Fix is index Maintenance-rule compliance for **new** plans |
| Full fleet doctor at session start | Re-creates the preflight sweep bug (GLM risk) |
| Hard CI gate on unclaimed diffs | #131 already chose advisory-first then measure |

## 8. Design decisions already made

### Locked (do not relitigate)

| Decision | Date | Reason |
|---|---|---|
| No new process `plan_*.md` | 2026-09-29 | Owner accept after GLM/Gemini/StepFun/Qwen |
| Drop item 3 entirely | 2026-09-29 | Owner ruling 2026-09-23 + shipped Gemini hash-pin design |
| Drop item 9 entirely (not even optional keep) | 2026-09-29 | AGENTS.md reuse rule + P9 measured priority |
| Drop loss ledger | 2026-09-29 | Advisors + evidence quality |
| Item 1 is closed (no new registry work) | 2026-09-29 | Empty-report fail-closed + lease liveness already merged |
| No lease TTL | 2026-09-05 (design) | Never free a slot on age alone |
| First instrument = spawn-count, not wall-clock | 2026-09-29 | Deterministic; matches existing `tests/test-ai-glm.sh` guard |
| Independent exact-head review required for the doctor PR | standing | `bin/ai-glm` is a reviewer wrapper; AGENTS.md reviewer-safety path |

### Open (implementer judgment)

| Question | Criteria |
|---|---|
| Bound reconcile open-record path **in this PR** vs name as next residual | If a cheap batch/bound fits without touching reviewer routing, do it here. If it needs a schema or lifecycle change, name a dated residual with an owner in the decision ledger and stop |
| Exact spawn ceiling in the new orphan guard | Mirror the existing pattern (`-le 6` for 270 records); measure once with a seeded backlog if unsure; prefer a generous ceiling that still catches "per-directory spawn" |
| Whether to fix `plan_live-proof-session-sizing.md` index row (says Completed; plan STATUS says partial) | Only if a live session can resolve remote state; otherwise leave a one-line note in the index maintenance row |

## 9. The plan — numbered, ordered, executable steps

**Phase A — the safety PR (steps 1–2). Context cut after step 2 if needed.**

### Step 1 — Spawn-count guard + batching for `glm_orphan_sandbox_report`

**What to change**

1. In `bin/ai-glm` (`glm_orphan_sandbox_report`, ~:2177-2200):
   - Replace per-candidate `sed -nE` name parsing with a bash regex (e.g. `[[ $name =~ ^(glm-.+)-[0-9a-f]{12}$ ]]`) — `compgen -G` is already a builtin.
   - Replace per-candidate `stat -c %Y` with **one** batched call over all candidates (same batching shape already used in `glm_record_index` ~:2014).
   - Keep the function's reporting output identical (same lines, same meaning).
2. In `tests/test-ai-glm.sh`, extend the existing spawn-stub pattern (`:844-848` area):
   - Seed N unrecorded orphan sandbox directories (reuse the fixture style at `:855-869`).
   - Stub `stat`/`sed`/`jq`/`date` (or whatever the new code still spawns) and **assert total spawn count is bounded** and **independent of N** (or grows in documented batch steps, not per directory).
   - Name the test like the existing one: `scanning N orphan sandboxes costs a bounded number of spawns`.

**Behavior when done:** doctor's orphan report still lists the same sandboxes with the same ages; cost is O(1) or O(batches) in process spawns, not O(N directories).

**Depends on:** nothing.

**Verification gate:** `bash tests/test-ai-glm.sh` — new case `ok`, whole file green (`362 passed, 0 failed` was the baseline at `698b2ea`; re-measure). Manually: seed 20 fake orphan dirs and run `ai-glm doctor` — completes inside 10s on edge-dev.

### Step 2 — Bound or residual-name `reconcile_implementation_records`

**What to change (choose one, criteria in §8):**

- **2a (preferred if cheap):** batch the Windows `canonical_path` calls or skip already-validated settled/open records in one pass so one open record cannot cost >10s. Add a spawn-count or batch-count test beside the new orphan guard.
- **2b (if 2a needs lifecycle/schema work):** do **not** implement here. Add one dated paragraph to the decision ledger (step 4): "reconcile open-record path remains unbounded inside CHECK_TIMEOUT=10; owner: …; next action: …". Open one leftover-proof style issue **only if** code lands without live proof.

**Verification gate:** either new test green under `bash tests/test-ai-glm.sh`, **or** the decision ledger names the residual with owner + next action (grep the ledger for the sentence).

**Depends on:** step 1 (same PR, same file family).

**Context cut:** after step 2, a fresh session may land Phase A only.

---

**Phase B — documentation and routing (steps 3–6). Can run after Phase A or in parallel on docs-only commits.**

### Step 3 — Correct the digest-fix handoff

**File:** `HANDOFF.d/2026-09-29T1357Z-edge-dev-mimo-digest-fix-and-process-plan.md` (on `origin/main` after #1060).

1. §5a item 1 residual: replace "lease TTL" wording. Correct fact: lease liveness is complete; **there is no TTL** (design forbids age-only release). Residual if any: empty-report → mark provider unavailable in the capacity record (`bin/ai-review-preflight` closed `reason` enum — small schema addition, not prose).
2. §5a item 2 / incident text: replace "60s governed preflight" with **10s** (`CHECK_TIMEOUT` default). This is load-bearing (one open record >10s is fatal).

**Verification gate:** `grep -n "lease TTL\|60s" HANDOFF.d/2026-09-29T1357Z-…` shows no stale claims; `grep -n "10s\|CHECK_TIMEOUT" ` shows the correction.

### Step 4 — Decision ledger: why 3 and 9 are not done

**Where:** a short section in **this** plan file (or the companion handoff) — **not** a new `plan_*.md`.

Must record:

1. **Finding 3 rejected** with both precedents:
   - Owner ruling 2026-09-23 (`config/provider-cli-versions.json` grok notes): exact pin blocked every review on auto-update; floor (`version_match: "minimum"`) is the chosen design.
   - Hash-pin + re-qualify already exists for Gemini (`bin/ai-review-preflight` live qualification) — so "hash pin everything" is also already designed narrowly.
2. **Finding 9 rejected** with the **correct** grounds:
   - `AGENTS.md` reuse rule (owner + reason the shared home cannot serve + retirement path).
   - `plan_workflow-efficiency.md` P9: queue reuse only after measured savings; baseline queue median seven minutes; existing homes named.
   - **Do not** cite P8 "Do not add a new general-purpose status index" as a ban on `bin/` tools — that sentence is about document proliferation.

**Verification gate:** reading the ledger, a newcomer can explain why 3 and 9 will not return.

### Step 5 — Index the 18 missing root plans

**File:** `docs/implementation-plan-index.md`.

1. List root `plan_*.md` (`ls plan_*.md` | count is 72 at last measure).
2. Diff against index names. Qwen's measure: **54** indexed, **18** missing (all added 2026-09-28/29), 0 stale links. Re-measure; do not trust 27.
3. Add each missing file to the correct table (Active / Completed / Superseded) per the index's own Maintenance rule ("Add it to Active plans in the same commit" — we are retro-fixing the breach).
4. If `plan_live-proof-session-sizing.md` is listed Completed but its STATUS says partial, either fix the row with evidence or add one "resolve live state" note. Do not invent closure.

**Verification gate:** script or `comm` showing every `plan_*.md` appears in the index; `bash tests/test-doc-reachability.sh` or equivalent still green if this file is gated.

### Step 6 — Written fold-routing lines for findings 4/5/6/7/8

One dated line each (STATUS bullet or issue comment). **No** new plan files.

| Finding | Owner home | Line to add (intent) |
|---|---|---|
| 4 wall-clock / suite budgets | `plan_workflow-efficiency.md` P3/P6/P7 (#650) | Transcript finding 4: no-progress detector + per-suite cancel remain; ban on exact timing asserts must **exempt** generous upper-bound checks |
| 5 GitHub quota | `plan_github-request-reduction.md` P5 (#658) | Finish P5 (BlockerWatch → existing App) before any multi-App split; lint direct `gh`; show remaining quota |
| 6 session orphans | `plan_blockerwatch-reliability-repair.md` (#632) | TTL/reap + wake-resume live here — **not** in `plan_live-proof-session-sizing.md` (frozen) |
| 7 collisions | `plan_ai-devops-work-claims.md` (#131) | Advisory-first already chosen; hard gate only after 30-day measure. Handoff condition-free "do not" ban does **not** apply to owner rulings |
| 8 install drift | `bin/ai-machine-tools-doctor` (cached/scheduled) | Extend existing doctor; never a full sweep in the check path |

**Verification gate:** each of the five files (or issues) contains the dated line; `grep` for "2026-09-29 transcript finding".

**Phase C — land (steps 7–8).**

### Step 7 — Independent exact-head review

- Declare task class: `ai-task-gates start --class reviewer-safety` (this touches `bin/ai-glm` + safety tests).
- From a **clean** worktree at the PR tip: `ai-review <provider> final-check --assert-head <tip> --implementer <engine> --base origin/main --tests 'bash tests/test-ai-glm.sh'`.
- Store the APPROVE report under `.ai/reviews/`. Pin the SHA in the PR body.

**Verification gate:** durable APPROVE naming the exact tip SHA.

### Step 8 — Merge and live proof

- `bin/ai-gh pr merge` / queue; `bin/ai-pr-wait <pr>`.
- Confirm squash/merge commit on `origin/main`.
- Live proof: `ai-glm doctor` on edge-dev with a **seeded** orphan backlog (e.g. 20 fake dirs) finishes inside the 10s window; paste timing into the PR or handoff.
- Update STATUS rows in **this plan** (mandatory `session-docs-update` / plan-file gate). Mark step 8 done only with the live artifact named.

## 10. Tests required

| Test | File | Must prove |
|---|---|---|
| `scanning N orphan sandboxes costs a bounded number of spawns` (new) | `tests/test-ai-glm.sh` | Spawn count does not grow per directory (or grows in batches) |
| Reconcile cost guard (if step 2a) | `tests/test-ai-glm.sh` | One open implementation record cannot exceed a spawn/batch bound |
| Existing doctor guards stay green | `tests/test-ai-glm.sh` (`doctor never runs a prune pass`, `doctor builds the index once`, `scanning 270 records costs a bounded number of spawns`) | No regression |
| Full focused suite | `bash tests/test-ai-glm.sh` | All pass (baseline ~362 passed, 0 failed) |
| Broader suite if touching shared helpers | `bash tests/test-ai-review-lifecycle.sh`, `bash tests/test-ai-review-sandbox.sh` | Stay green |

Never write "add tests" without the names above.

**Adversarial / hostile cases** (trust boundary: filesystem names and directories that look like sandboxes):

| External input | Hostile case | Test |
|---|---|---|
| Directory name without `glm-`/suffix pattern | Must not be counted as orphan or spawn per-name tools | Orphan report test with a `not-a-sandbox` dir |
| Name matching prefix but wrong hash width | Regex must not false-positive into per-dir `sed` | Unit case with `glm-foo-zz` / `glm-foo-123` |
| Thousands of candidate dirs | Cost must stay bounded (batch), not O(N) spawns | Spawn-stub with N=50 vs N=5; assert same spawn bound |
| Symlink / broken dir | Must not crash doctor; must not spawn unbounded retries | Seed one broken link in the orphan fixture |
| Windows `stat`/`sed`/`cygpath` cost | Guard must count spawns, not wall-clock (contended host) | Existing stub pattern (no `sleep`-based asserts) |

## 11. Constraints, standing rules, and gotchas in force

- **Never push to `main`.** Feature branch + PR + merge queue.
- `git var GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Stage only task-owned files. Canonical `C:\repos\ai-devops` is **landing-only**.
- **Reviewer-safety path:** `bin/ai-glm` and `tests/test-ai-glm.sh` need **one read-only exact-head independent APPROVE** before merge (`ai-task-gates check --before review|ship`).
- All GitHub calls through `bin/ai-gh`. Waits via `bin/ai-pr-wait` / `ai-blocker-watch`. No open-ended `until` loops. Waits >~10 minutes are registered, then the turn ends.
- Windows: wrappers need Git Bash (`C:\Program Files\Git\bin\bash.exe`), not WSL `bash`.
- Do not add a new root `plan_*.md`. Do not re-run #168. Do not implement item 3 or item 9.
- Do not use raw wall-clock asserts. Do not re-add prune/reconcile sweeps to doctor's check path.
- One unproven live-behavior outcome per session (`plan_live-proof-session-sizing.md`).
- Private transcripts never enter the public repo or reviewer packets.
- `docs/doc-reachability.md` may gate new Markdown — run the reachability tool if the index edit is large.

## 12. Access and environment

| Need | Location |
|---|---|
| Host | `edge-dev` (Windows) |
| Worktree | `C:\repos\ai-devops-wt-doctor-orphan-guard` branch `mimo/doctor-orphan-scan-guard` |
| Git Bash | `C:\Program Files\Git\bin\bash.exe` |
| Test command | `bash tests/test-ai-glm.sh` from the worktree |
| GitHub | `bin/ai-gh` (never bare `gh` for API) |
| Task gates | `bin/ai-task-gates start --class reviewer-safety` |
| Review | `ai-review <provider> final-check …` (Gemini/Muse/Grok usable; Qwen works without Docker) |
| 1Password | vault `vibe_coding` — names only, never values. Reviews do not call 1Password |
| Prior debate reports | `.ai/reviews/qwen-jev-plan-debate-qwen-2-*.md`, StepFun log in session notes |
| Related handoff | `HANDOFF.d/2026-09-29T1357Z-edge-dev-mimo-digest-fix-and-process-plan.md` |

No local server. No UI.

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Step 1 code + named spawn test green in `tests/test-ai-glm.sh`
- [ ] Step 2a implemented **or** step 2b residual written with owner
- [ ] Steps 3–6 docs landed (handoff corrections, decision ledger, index, fold lines)
- [ ] Task class declared; independent exact-head APPROVE on the PR tip
- [ ] CI green; merged via queue; commit on `origin/main`
- [ ] Live `ai-glm doctor` with seeded orphan backlog completes inside 10s (artifact named)
- [ ] This plan's STATUS table updated (every done row cites an artifact)
- [ ] Handoff updated or superseded per `session-docs-update`

### Risks

| Risk | Mitigation |
|---|---|
| Spawn ceiling too tight → flaky test | Use generous bound like existing `-le 6`; count only the tools the new code still spawns |
| Batching changes report output | Keep printed lines identical; behavioural test at `:855-869` must stay green |
| Reconcile bound breaks implementation lifecycle | Prefer residual (2b) over a risky lifecycle change in the first PR |
| Someone re-proposes item 3 or 9 | Decision ledger with owner-ruling citation (step 4) |
| Index edit floods doc-reachability CI | Follow `docs/doc-reachability.md`; keep edits as index rows only |
| 10s window still blown by unknown cost | Live proof step 8 with seeded backlog is the acceptance test |

### Open questions

1. Exact spawn ceiling after batching — measure once; criteria in §8.
2. Whether `plan_live-proof-session-sizing.md` index row needs live-state resolution before marking (cannot be done remote-less).
3. If step 2b is chosen, who is the named residual owner (propose: whoever next touches `bin/ai-glm` doctor; do not leave unowned).

---

## Self-audit (mandatory)

1. **Could a brand-new AI session with no project knowledge execute this without asking?**  
   Yes. §2 defines the repo/hosts; §5–6 give file:line current state and root cause; §7–8 lock every decision that must not be relitigated; §9 names files, behavior, and verification gates; §10 names tests; §11–12 give constraints and how to run; §13 defines done. Gaps found in draft (leaseline, 10s vs 60s, item-9 citation, reconcile scope) are explicit in §6–9.

2. **Does the plan carry every piece of background, nuance, and reasoning currently held?**  
   Yes — including rejected approaches (§7), locked vs open (§8), the four-advisor debate outcomes, the owner's accept sentence (§3), and the out-of-scope list (§4) that matches what Albert accepted ("one small safety PR, nothing else new").

3. **Is the ultimate goal clear enough for judgment calls?**  
   Yes (§1): keep the 10s review health-check cheap and bounded; finish the nine-finding re-cut as documented rejection + routing, not as new work. "If a step conflicts with this goal, the goal wins."

**Self-audit: PASS.**
