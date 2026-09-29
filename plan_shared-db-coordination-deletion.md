# IMPLEMENTATION PLAN — delete shared-db coordination layer (C by deletion) (2026-09-29)

**Session handoff:** [HANDOFF.d/2026-09-29T1635Z-edge-dev-mimo-c-by-deletion.md](HANDOFF.d/2026-09-29T1635Z-edge-dev-mimo-c-by-deletion.md)  
**Full background (why these deletions):** [`docs/shared-db-delivery-failure-background-2026-09-29.md`](docs/shared-db-delivery-failure-background-2026-09-29.md)  
**External reviews:** Grok consensus C-by-deletion · Opus plan-review REJECT (thin brief) · StepFun REVISE (applied) · BlockerWatch: Grok DELETE / StepFun SHRINK → **SHRINK**.

## STATUS — read first

| Step | State | Date | Evidence / completion gate |
|---|---|---|---|
| 0. Freeze decision + register plan | ✅ done | 2026-09-29 | This file + `HANDOFF.d/2026-09-29T1635Z-edge-dev-mimo-c-by-deletion.md` + `AGENTS.md` task-router row |
| 1. Rename `orchestrator-claim` → `claim-admission` (keep required) | ✅ done | 2026-09-29 | PR-A (this PR) ships #1065+#1066; `config/task-gates.json` + `config/repository-coverage.json` renamed; `rg -n orchestrator-claim` zero live hits (plan/handoff prose only); `bash tests/test-ai-task-gates.sh` 215 passed / 5 pre-existing Windows install-authority failures identical on clean `origin/main` baseline (no gate-name tests red); `bash tests/test-client-globals-required-phrases.sh` PASS |
| 2. Delete leftover-proof ticket mill; update required-phrase tests | ✅ done | 2026-09-29 | PR-A (this PR) ships #1065+#1066; four globals carry checklist-on-same-issue rule (no leftover-proof minting); `tools/context-audit/context-audit.py` PARITY_RULES now `Live proof is required before an outcome is closed` + `One issue per application need`; `bash tests/test-client-globals-required-phrases.sh` PASS; `pwsh tests/test-context-audit.ps1` PASS (12/12) |
| 3. Self-service claim = default; demote orchestrator role | ⬜ open | | Skills + `docs/task-router.md`; `bash tests/test-shared-db-routing-rules.sh` green |
| 4. Re-point stuck-work watchdog (per-PR comment, no marker) | ⬜ open | | `tools/stuck-work/watchdog.mjs` + rewritten `tests/test-stuck-work-watchdog.mjs` conductor test; `node --test tests/test-stuck-work-watchdog.mjs` green |
| 4B. SHRINK BlockerWatch (delete registration; keep tick+janitor) | ⬜ open | | Standing-rule text gone; `bash tests/test-ai-blocker-watch.sh` green for remaining paths |
| 5. Stop chat merge conductors | ⬜ open | | Skill text; `rg -n "MERGE CONDUCTOR" skills/` has no required-role instruction |
| 6. No path filters on required checks | ⬜ open | | `bash tests/test-workflow-policy.sh` green |
| 7. Out-of-repo hold: shared-db freshness until #2530 | ✅ done | 2026-09-29 | Hold recorded in Phase E Step 7 paragraph of this plan (no ai-devops code edit required) |
| 8. Supersede leftover-proof-minting plan STATUS rows | ✅ done | 2026-09-29 | PR-D docs-only: supersession notes in `plan_live-proof-session-sizing.md`, `plan_mimo-windows-support.md`, `plan_cut-unneeded-github-traffic.md`, `plan_agent-self-cleanup.md`, `plan_tool-and-skill-scoping.md`, `plan_model_tier_delegation.md`, `plan_repo-throughput-restructure.md`, `plan_typesafe-jev-spend-reduction.md`, `plan_reviewer-investigation-mode-option-b.md`, `plan_self-healing-locks-and-settings-drift.md`; `rg -n "leftover-proof issue" plan_*.md` only in superseded/historical sections with a note pointing here |
| 9. Fleet re-adopt globals | ⬜ open | | Per-machine adopt proof (Step 9) |
| 10. Measure 14d/30d + stop rule | ⬜ open | | `tests/verification/shared-db-coordination-deletion/<UTC>.md` |

**Where a fresh session starts:** first `⬜ open` row (currently Step 1). Re-read §8 LOCKED and §11 before any edit.

---

## How to execute this plan (read this second)

You are a **new session with no chat history**. Follow this runbook exactly.

### Repo and branch rules
- Canonical checkout `C:\repos\ai-devops` (Windows) or `/home/ahazan/repos/ai-devops` (Linux) is **landing-only**. Do not edit it for feature work.
- Before your first commit run `git var GIT_COMMITTER_IDENT` — must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- For each phase, create a worktree from `origin/main`:

```bash
# Git Bash on Windows, or bash on Linux
cd /c/repos/ai-devops   # or /home/ahazan/repos/ai-devops
git fetch origin
git worktree add ../ai-devops-wt-coord-del-<phase> -b <your-initials>/coord-del-<phase> origin/main
cd ../ai-devops-wt-coord-del-<phase>
```

- Stage **only** files this plan names for that phase. Never `git add -A`.
- Open one PR per phase. Docs-only PRs (if a phase is pure prose) may use `gh pr merge --squash --admin` after checks; **any** code/test/config change needs normal checks + merge queue.
- Use `bin/ai-gh` for GitHub API calls (not raw `gh`) unless `docs/development.md` says otherwise for a specific command.

### PR slicing (do not merge phases into one mega-PR)
| PR | Steps | Why separate |
|---|---|---|
| **PR-A** | 1 + 2 | Gate rename + rule deletion + the tests that assert the old rules. Must be atomic or CI goes red. |
| **PR-B** | 3 + 5 | Skill/docs routing and merge-conductor language. |
| **PR-C** | 4 + 4B + 6 | Watchdog re-point + BlockerWatch shrink + workflow-policy (no path filters). |
| **PR-D** | 8 | Plan STATUS supersessions (docs only). |
| Later | 9 + 10 | Fleet adopt + measurement (not one PR). |

### Test commands (Git Bash on Windows)
```bash
bash tests/test-ai-task-gates.sh
bash tests/test-client-globals-required-phrases.sh
pwsh tests/test-context-audit.ps1    # or: powershell -File tests/test-context-audit.ps1
bash tests/test-shared-db-routing-rules.sh
bash tests/test-skill-trigger-policy.sh
bash tests/test-workflow-policy.sh
node --test tests/test-stuck-work-watchdog.mjs
bash tests/test-ai-blocker-watch.sh
```
Full local series: `bin/ai-test-local --check-collision` first, then the suite named in `docs/development.md` / `config/ci-suite-manifest.json`. Never overlap a full local series with a GitHub job on the same physical Windows host.

### Definition of a "flawless" step
1. Edit the named files only.
2. Run the step's verification gate command until green.
3. Update this plan's STATUS row for that step with an **artifact path or command**, not a feeling.
4. Commit only your hunks; push branch; open PR; wait with `bin/ai-pr-wait`; merge per repo policy.

---

## 1. The ultimate goal — what we are trying to achieve

When an application needs a shared-database change, safe work starts promptly and one owner carries it until the application works live. Albert (business owner, not a programmer) should see a predictable delivery time and only genuine decisions — not a week of queue movement, reviewer recovery, handoffs, and "still waiting" checks.

Today that is not true: sessions wait on helpers they spawned; every unfinished step mints a new issue; a merge helper lives in a chat and dies on restart. This plan **deletes the coordination layer** that causes that, and **keeps the machine-enforced safety engine** that prevents database collisions (exact-object claims + permanent version reservation in GitHub + stage leases + independent exact-head review + live proof).

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

| Name | What | Where |
|---|---|---|
| `popcre/ai-devops` | Public AI workflow toolkit: installed rules (globals), skills, reviewer wrappers, task gates, plans | `C:\repos\ai-devops` / `/home/ahazan/repos/ai-devops`; GitHub `popcre/ai-devops`; branch `main` via PR + merge queue |
| `popcre/shared-db` | Shared Supabase/Postgres structure; **safety engine** `scripts/manage-migration-author-lanes.mjs` (claims, `refs/db-claims/<version>`, `refs/db-coordination/author-acquisition`, stage leases) | `C:\repos\shared-db`; **do not edit structure or the claim engine in this plan** |

Albert works on **3 computers × 4 AI harnesses** (Claude, Codex, and others). Collision state is GitHub-backed already.

**Terms:** *claim* = fenced `db-claim` block on a `db-claim` issue listing exact objects to write + a 14-digit migration version. *Leftover-proof issue* = extra ticket opened when live proof is missing (this plan deletes that rule). *Orchestrator* = required coordinating chat for shared-db work (this plan deletes that role). *Janitor* = `tools/stuck-work/watchdog.mjs` that comments on stuck PRs.

## 3. What triggered this work

2026-09-29 Albert: the shared-db orchestrator process has gotten progressively worse since it was instituted to prevent database collisions, until almost no work gets done; every fix made it worse (band-aid upon band-aid). Asked: scrap the system or modify?

Evidence (private scratch `.ai/tmp/` — **never commit raw transcripts**):
- 942 sessions / week; Jev filter discarded 150 as unrelated; remainder is the stall pattern.
- 24h churn: ~48 issue opens vs ~26 closes; 155 leftover-proof and 308 unproven-step mentions.
- "5 currently-active claude sessions each waiting on 3–5 other things… nothing is getting done."
- #401 (`plan_shared-db-complete-throughput-repair.md`) closed complete 2026-09-20; same stall classes returned by 2026-09-28/29.
- **Albert 2026-09-29:** "blockerwatch hasn't been working. despite repeated attempts to fix it, sessions were never registering anything with blockerwatch."

## 4. Scope — in and out

**In scope:** deleting coordination *rules and roles* in ai-devops; re-pointing the stuck-work watchdog; shrinking BlockerWatch registration; updating tests that assert deleted rules; plan STATUS supersessions; fleet re-adopt; measurement.

**NOT in this plan:**
- Rebuilding `manage-migration-author-lanes.mjs` or any shared-db migration.
- GitHub Actions quota, ~20 workflows per push, Windows runner slowness, reviewer-wrapper bugs (capacity lane).
- New locks, schedulers, watchdogs, issue types, or a "duplicate need" review question.
- Reopening #401 as a programme.
- Shared-db merge-queue activation (#2530) or dropping its freshness conditions.
- Key rotation (owner ruled no rotation 2026-09-29).
- Implementing the train cutover in `migration-train.mjs` (separate capacity/cutover work).

## 5. Current state of the code

### Keep as-is (safety engine — do not "clean up")
- `shared-db/scripts/manage-migration-author-lanes.mjs` — claims (`claimBody` ~:1359), version reservation, `EXCLUSIVE_REFS` preview/merge/production, fail-closed overlap. Closing a claim **requires an exact stated reason** (`requireClaimCloseReason` ~:1913).
- `shared-db/supabase/migrations/*.sql` — the change log (timestamped migration files).
- `shared-db` PRs + `db-claim` issues — human "why".
- `shared-db/docs/agents/anti-collision-summary.md`, `section-4-anti-collision-rules.md`.
- `shared-db/docs/agents/orchestrator.md` — already-shipped `self-service-additive` lane (model for default path).
- ai-devops reviewer wrappers (`bin/ai-claude-review`, `bin/ai-grok-review`, `bin/ai-qwen`, …).

### Delete or re-point (coordination)
- Required leftover-proof / "one unproven live-behavior outcome" **as a ticket mill** in four globals + parity rules (see Step 2 for exact strings).
- Required orchestrator role in `skills/shared/shared-db-orchestrator/`, `skills/shared/shared-db-handover/`.
- Chat merge-conductor role text.
- `tools/stuck-work/watchdog.mjs` conductor/marker coupling (`mode:'conductor'` :47, `REPOS` :46-49, marker upsert :290-306, "nobody (no open orchestrator marker)" :293). File is byte-identical from `289406b2` through `635749c`.
- BlockerWatch **registration** path (wait/wake/`has-wait`/`--park`) — never adopted (Albert fact + `plan_blockerwatch-reliability-repair.md` STATUS all open).

### Will break if you delete rules without updating tests (same PR mandatory)
| File | Exact current requirement |
|---|---|
| `tests/test-client-globals-required-phrases.sh:39-40` | `"one unproven live-behavior outcome"` and `"Never save several unproven steps"` in all four globals |
| `tools/context-audit/context-audit.py:130-131` | PARITY_RULES keys `one unproven outcome per session` → regex `one unproven live-behavior outcome`; `do not defer live-proof dumps` → `Never save several unproven steps` |
| `tests/test-context-audit.ps1:41-42` | Same two phrases |
| `config/task-gates.json:224` | Gate name `orchestrator-claim` (also `config/repository-coverage.json:107`) |
| `tests/test-stuck-work-watchdog.mjs:121-132` | Test *"shared-db is conductor-only…"* asserts `POST /repos/popcre/shared-db/issues/3821/comments` and `!rerun` |
| `tests/test-shared-db-routing-rules.sh:8-24` | Asserts `shared-db-orchestrator` route |
| `config/skill-trigger-policy.json:20-21` | Protected skills `shared-db-handover`, `shared-db-orchestrator` |

### Untouched
- Reviewer rotation, 1Password, production access, shared-db SQL.

## 6. Key findings and root cause

1. **Safety engine is not the failure** — claims/versions/leases refuse overlapping writers (#401 live proofs). State is GitHub refs (cross-machine).
2. **Coordination volume is the failure** — leftover-proof minting (~2:1 opens/closes), marker succession, handoffs, chat conductor dying on restart, 31 self-created waiters.
3. **#401 closed complete; same stalls returned in ~10 days** because the process *shape* remained.
4. **Opus C1:** path-filtered required checks forbidden (`bin/ai-merge-queue-drift:160-161`, `config/merge-queue-expected.json:10-12`, `tests/test-workflow-policy.sh:42`). Legal substitute: aggregate `verification-closure` (`config/merge-queue-expected.json:39-47`).
5. **Opus C2:** watchdog posts to `orchestrator-marker` and treats conductor as decider.
6. **Opus C3:** required-phrase tests demand the leftover-proof wording.
7. **Opus H1:** `orchestrator-claim` is a **safety** gate — rename, do not delete.
8. **StepFun:** Step 4 must rewrite the whole conductor test; aggregation = **per-PR comments**; Step 7 is out-of-repo; use `tests/test-ai-task-gates.sh` (there is **no** `tests/test-task-gates.sh`); PARITY_RULES at **130-131** not 128.
9. **BlockerWatch:** registration never adopted; janitor is **driven by the BlockerWatch tick** (`#1051`, `bin/ai-blocker-watch:1103-1137`) after GitHub dropped `schedule:` on the workflow — so **SHRINK**, not full delete of the binary.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| A. Keep orchestrator bones, cut band-aids | #401 did that; stalls returned. |
| B. Rebuild safety engine | Weeks of zero delivery; version-migration is where collisions happen. |
| Single-flight lock / replacement scheduler | Re-creates the orchestrator. |
| "Duplicate need?" review question | New process (queue-wide search). Grok struck it. |
| Path-filtered required checks | Forbidden; hangs merge group. Use `verification-closure`. |
| New watchdog / map-watcher | Monitoring-as-fix. |
| Force BlockerWatch registration (repair step 5) | More process after adoption failed. |
| Delete BlockerWatch binary entirely | Janitor trigger lives in its tick (`#1051`); would require re-platforming (forbidden new process). |
| Reopen #401 | Closed decision record. |

## 8. Design decisions (dated)

**LOCKED:**
- 2026-09-29 — **C by deletion** (keep engine, delete coordinator, no new scheduler).
- 2026-09-29 — Card = **existing GitHub issue**; proof gaps = checklist on that issue.
- 2026-09-29 — No single-flight lock; no new issue type; no new watchdog as the fix.
- 2026-09-29 — No "duplicate need" review question.
- 2026-09-29 — Capacity items out of scope.
- 2026-09-29 — **No path filters** on required checks; use `verification-closure`.
- 2026-09-29 — `orchestrator-claim` → rename `claim-admission`, still required.
- 2026-09-29 — Shared-db freshness/behind-branch stays until #2530 (out-of-repo hold).
- 2026-09-29 — **BlockerWatch SHRINK:** delete registration/`has-wait`/`--park`; keep automatic tick + re-pointed janitor. Do not enforce registration. **`fixer_enabled: false`** (no auto session-spawn). Omit extra daily lists. No cron to “fix” single-heartbeat.
- 2026-09-29 — **Do not rename** route string `shared-db-orchestrator` (Qwen) — only demote required-ness. Keep non-ticket session-sizing honesty; delete only leftover-proof **issue** minting.
- 2026-09-29 — Watchdog posts **one comment per stuck PR**; @-mention assignee if set; **never** invent an owner; **never** fixer-issue or marker-ping.

**OPEN (criteria in parentheses):**
- Exact `claim-admission` string if `ai-task-gates` rejects it (shortest name that still matches; update every mirror in the same PR).
- **Do not fold or delete `shared-db-orchestrator` SKILL.md** until you prove every machine-checked safety sentence it carries is preserved elsewhere (claim locks, lease flags, clock-expiry, pinned auto-migration commits). Prefer: keep the skill file, demote the *role* (no required marker/orchestrator chat), leave safety bullets intact. `tests/test-shared-db-routing-rules.sh` guards routing/role text — re-read it before editing and keep its actual invariants green.
- Whether to keep a **read-only** daily stuck-PR list for Albert (status only, never a work ticket). **DECIDED (Qwen): omit.**
- Watchdog comment **idempotence**: one comment per stuck PR **per head SHA** (or edit a single sticky comment on that PR). Do not post a new comment every tick. Fetch `assignees` in the GraphQL/REST payload before any @-mention.

## 9. The plan — numbered steps

### Phase A — PR-A (Steps 1–2)

#### Step 1. Rename `orchestrator-claim` → `claim-admission`
**Files:** `config/task-gates.json:224`, `config/repository-coverage.json:107`, then `rg -n orchestrator-claim` and fix any other live hit (scripts/tests/docs). Historical plan prose may keep the old name.

**Behavior:** `ai-task-gates` still refuses shared-db work without a successful claim; the name no longer implies an orchestrator role. Gate stays `required: true` for class `shared-db`.

**Exact edit:** replace the JSON string `"orchestrator-claim"` with `"claim-admission"` (keep surrounding structure and required flags unchanged).

**Depends on:** none.  
**Verification:** `bash tests/test-ai-task-gates.sh` green. Also run `bash tests/test-task-gates-phase5-acceptance.sh` and `bash tests/test-ai-task-gates-bulk.sh` if they mention the gate name. `rg orchestrator-claim` → zero live hits. **There is no `tests/test-task-gates.sh`.**

#### Step 2. Delete leftover-proof ticket mill (wording + tests, one PR)
**Intent:** live proof gaps stay as **unchecked checklist items on the same issue**. Sessions do **not** open leftover-proof or "unproven step" issues.

**Files to edit (same PR):**

1. **Four globals** — `templates/system/CLAUDE-global.md` and the parallel blocks in `AGENTS-global-codex.md`, `AGENTS-global-zcode.md`, `AGENTS-global-mimo.md`. Find the sentences containing the exact phrases:
   - `one unproven live-behavior outcome`
   - `Never save several unproven steps`
   - `open exactly one leftover-proof issue` (and nearby leftover-proof wording)

   **Replace that policy block with this exact intent (adapt surrounding grammar, keep client parity across all four files):**

   > Live proof is required before an outcome is closed. If live proof is not yet done, leave a checklist item on the **same** GitHub issue (e.g. `- [ ] live proof`) and name it in the session's closing note. Do **not** open a leftover-proof issue, an "unproven step" issue, or a second ticket for that gap. One issue per application need; one named owner until the app works live.

   Keep any *safety* sentence that forbids claiming an outcome complete without proof — only the **ticket-minting** rule goes.

2. **`tools/context-audit/context-audit.py:130-131`** — PARITY_RULES. Current:
   ```python
   "one unproven outcome per session": r"one unproven live-behavior outcome",
   "do not defer live-proof dumps": r"Never save several unproven steps",
   ```
   Replace both keys/regexes so they match the **new** checklist wording (pick one short sentence from the replacement block above and use it consistently). Update the test that asserts PARITY_RULES if it hardcodes the old strings.

3. **`tests/test-context-audit.ps1:41-42`** — remove or replace the two phrase entries to match the new rules (keep `non-orchestrator work` if still required).

4. **`tests/test-client-globals-required-phrases.sh:39-40`** — replace:
   ```bash
   "one unproven live-behavior outcome"
   "Never save several unproven steps"
   ```
   with the new required phrases (must appear in all four globals).

**Depends on:** none (parallel with Step 1, but **ship together in PR-A**).  
**Verification:**
```bash
bash tests/test-client-globals-required-phrases.sh
pwsh tests/test-context-audit.ps1
bash tests/test-ai-task-gates.sh
rg -n "leftover-proof issue|one unproven live-behavior outcome|Never save several unproven steps" templates/ AGENTS-global-*.md
# last command: only historical/plan text, not the live rule blocks
```

**— Phase A cut: update STATUS 1–2 with PR number + green CI run. Fresh-session: re-read §8 before Phase B. —**

### Phase B — PR-B (Steps 3, 5)

#### Step 3. Self-service claim is the default structural path
**Files (including the four globals — do not skip these):**
- **`templates/system/CLAUDE-global.md`, `AGENTS-global-codex.md`, `AGENTS-global-zcode.md`, `AGENTS-global-mimo.md`** — today they still make the **orchestrator a required role**. In the same PR-B, change that to **optional reference / claim-first default**. Without this, Step 9 re-adopts "required" onto every machine. Keep every **production-safety** sentence (claims, stage leases, clock-expiry, pinned auto-migration commits, never-terraform-without-approval). Only the **required orchestrator role / marker** language goes.
- `skills/shared/shared-db-orchestrator/SKILL.md` + `references/operating-manual.md` — **keep the file** and its safety bullets; demote the *role* (no "you are the orchestrator / open a marker"). Do **not** fold/delete until safety sentences are proven portable (§8 OPEN).
- `skills/shared/shared-db-handover/SKILL.md`
- `docs/task-router.md`, `AGENTS.md` (shared-db rows)
- `docs/standing-rules-details.md` (leftover-proof / one-outcome wording — same checklist rule as Step 2)
- `templates/system/implementation-plan-standard.md:160-164` and `skills/shared/implementation-plan-writer/SKILL.md` (~:222)
- `tests/test-shared-db-routing-rules.sh` — **read first**; it guards routing/role invariants, not the whole skill body. Keep its real invariants green; adjust only the required-role assertion.
- `config/skill-trigger-policy.json:20-21` + `tests/test-skill-trigger-policy.sh` if skill set changes

**Behavior when done:**
- New structural work starts when a session successfully **claims exact objects** on the **existing** issue (model: `shared-db/docs/agents/orchestrator.md` `self-service-additive`).
- No marker, no orchestrator chat required. Installed globals say the same as the skills.
- Handover = notes on the same issue, not a new ticket.

**Suggested skill header change (orchestrator SKILL.md):** keep safety bullets (claims, versions, stage leases, review, live proof); replace "you are the orchestrator / open a marker" with "not required; claim-first is the default; this document is reference only".

**Depends on:** Step 2 (same checklist wording).  
**Verification:**
```bash
bash tests/test-shared-db-routing-rules.sh
bash tests/test-skill-trigger-policy.sh
bash tests/test-codex-github-cli-access.ps1   # if present and reads those skills
rg -n "exactly one leftover-proof|open your OWN orchestrator-marker" skills/
```

#### Step 5. Stop chat merge conductors
**Files:** same skills as Step 3 + any `docs/agents/merge-protocol.md` pointer in ai-devops.

**Exact intent for any "MERGE CONDUCTOR" paragraph:** delete the role. Merges are dispatched by guarded-merge / train tooling and stage leases (`EXCLUSIVE_REFS` in `manage-migration-author-lanes.mjs`). Do **not** edit `shared-db/scripts/orchestrator-flow/migration-train.mjs` here.

**Depends on:** Step 3.  
**Verification:** `rg -n "MERGE CONDUCTOR|merge conductor" skills/ docs/` — no required-role instruction (historical plans OK).

**— Phase B cut: STATUS 3+5 —**

### Phase C — PR-C (Steps 4, 4B, 6)

#### Step 4. Re-point stuck-work watchdog
**Behavior contract (locked):**
1. Input: stuck **PRs** (from `listPulls` / GraphQL — **select `assignees`**; without that field the @-mention is unimplementable).
2. Output: **one comment per stuck PR per head SHA** (idempotence key = PR number + head SHA). Prefer editing one sticky comment on that PR over spamming every 15-minute tick. If the PR has an assignee **from the fetched assignees list**, @-mention them; if unassigned, comment without inventing an owner.
3. **Preserve:** `!rerun` / no fixer issue for shared-db. `REPOS` map: shared-db must **not** take the ai-devops `fixer`/`else` branch.
4. **Remove:** `orchestrator-marker` upsert/ping; "nobody (no open orchestrator marker)"; any "the conductor decides" wording.
5. Keep quota/runner **one re-run per head on the same PR** if that already exists (capacity, not process).

**Files:**
- `tools/stuck-work/watchdog.mjs` — `mode`/`REPOS` :46-49; marker block :290-306; strings :184, :293.
- `.github/workflows/stuck-work-watchdog.yml:6-8` — stale conductor doc-comment.
- `tests/test-stuck-work-watchdog.mjs:121-132` — **rewrite the whole test** *"shared-db is conductor-only: no re-run, no fixer issue, one marker comment"*. Today :130 asserts `POST /repos/popcre/shared-db/issues/3821/comments`. New assertions:
  - comment target is the **stuck PR number** (not a marker issue),
  - **no** `orchestrator-marker` create/update,
  - **no** fixer issue for shared-db,
  - still `!rerun` unless the existing quota re-run path is intentionally kept (then assert at most one re-run).
- Cross-check callers (do not break): `bin/ai-blocker-watch:1103-1137`, `config/blocker-watch.json` `stuck_watchdog_*`, `bash tests/test-ai-blocker-watch.sh`.

**Depends on:** Phase B preferred (marker language already demoted).  
**Verification:** `node --test tests/test-stuck-work-watchdog.mjs && bash tests/test-ai-blocker-watch.sh`

#### Step 4B. SHRINK BlockerWatch
**DELETE:**
- Standing rule / `AGENTS.md` / **all four globals** / `docs/standing-rules-details.md`: "**register a wait and end the turn**" and **`ai-blocker-watch wait`** as a **required** delivery step → replace with: use bounded `ai-pr-wait` while you remain in the turn; otherwise leave the **existing issue/PR** as the card and return later (GitHub notifications are the reminder).
- Closeout **`has-wait`** completeness gate **and** the completion-check hook / dispatcher path that enforces it (`bin/ai-completion-check-hook` or equivalent — find every caller of `has-wait` / `ai-blocker-watch wait` before deleting). **Delete the gate. Do not invent a replacement guard.** Target: turn-end may close with an unchecked checklist on the issue; it must not fail closed solely because no BlockerWatch wait exists.
- `--park` (creates a new issue if you have none).
- Session `wake`/resume as a **delivery** dependency.
- Do **not** start `plan_blockerwatch-reliability-repair.md` step 5 (enforced registration).

**Also edit the four globals here if PR-B did not already** (they still say `ai-blocker-watch wait` is required). Same checklist wording as Step 2/3.

**KEEP:**
- Tick/scheduler that runs the janitor (`bin/ai-blocker-watch` stuck_watchdog path).
- **Set `fixer_enabled: false`** (StepFun): the tick also runs `fixer_scan()` which auto-spawns sessions — delete that fan-out. Keep only janitor **report** (per-PR comment + fetched assignee @-mention + session-less once-per-head re-run + the existing daily notice). **Omit** any extra daily list.
- Watchdog per Step 4.
- `bin/ai-pr-wait` (not BlockerWatch).
- **Residual (record only):** one-host tick heartbeat; fails safe. **Do not add cron** to “fix” it (re-creates coordinator).

**Implementation note:** prefer making wait/wake/park commands print a short "registration is no longer required" and exit 0 **or** removing them from the help surface; do not leave a required closeout hook calling `has-wait`. Update `tests/test-ai-blocker-watch.sh` to match remaining behavior.

**Depends on:** Step 4 in the same PR if possible.  
**Verification:**
```bash
bash tests/test-ai-blocker-watch.sh
rg -n "ai-blocker-watch wait|--park|has-wait" templates/ AGENTS-global-*.md docs/standing-rules-details.md
# no REQUIRED registration rule remains
```

#### Step 6. Merge-queue: never path-filter a required check
**Files:** only if a required workflow currently has `paths:`/`paths-ignore:`. Otherwise **non-edit** and record that you checked.

**Rule:** if a suite must not run on every push, fold it into aggregate `verification-closure` per `config/merge-queue-expected.json:39-47` and `tests/test-workflow-policy.sh`. Follow `bin/ai-merge-queue-drift:160-161`.

**Depends on:** none.  
**Verification:** `bash tests/test-workflow-policy.sh` green; `bash bin/ai-merge-queue-drift` if runnable locally reports no path-filtered required check.

**— Phase C cut: STATUS 4, 4B, 6 —**

### Phase D — PR-D (Step 8)

#### Step 8. Supersede plan STATUS rows (docs only)
Do **not** reopen #401. Edit STATUS / rule notes only:
- `plan_live-proof-session-sizing.md` — leftover-proof **rule** superseded by this plan.
- `plan_mimo-windows-support.md`, `plan_cut-unneeded-github-traffic.md`, `plan_agent-self-cleanup.md`, `plan_tool-and-skill-scoping.md` — steps that require a leftover-proof issue → checklist on the same issue.
- Parent/child programmes (`plan_tool-and-skill-scoping.md`, `plan_model_tier_delegation.md`, `plan_repo-throughput-restructure.md`, `plan_typesafe-jev-spend-reduction.md`, `plan_reviewer-investigation-mode-option-b.md`) — note parent/child issue trees are deleted as process.

**Verification:** `rg -n "leftover-proof issue" plan_*.md` only in superseded/historical sections with a note pointing at this plan.

### Phase E — not a PR (Steps 7, 9, 10)

#### Step 7. Out-of-repo hold (record only)
Shared-db behind-branch / "not based on current main tip" / dependency-closure live in **`popcre/shared-db`** merge-queue conditions (#2530). ai-devops `config/merge-queue-expected.json` has only `verification-closure`. **Do not drop shared-db freshness.** This step is satisfied by this paragraph + STATUS row 7.

#### Step 9. Fleet re-adopt
On each managed machine × harness, run the supported adopt (`bin/ai-adopt-globals` / `docs/deployment.md`). Do not live-edit installed copies. Record machine, command, timestamp in `tests/verification/shared-db-coordination-deletion/adopt-<machine>-<UTC>.md`.

#### Step 10. Measure and stop rule
After 14 days: shared-db issue open/close ratio (document the query). After 30 days: exact-object collisions and applied duplicate-need migrations. **Stop rule:** ≥1 applied duplicate-need or production break from that class → put a **named assignee on that issue**. Do **not** rebuild an orchestrator.

### Adversarial-cases table (external inputs)

| External input | Hostile case | Test / proof |
|---|---|---|
| Four global rule files | Parity drift | `tools/context-audit/context-audit.py` + `tests/test-context-audit.ps1` |
| Old required phrases | Tests still demand deleted rules | `tests/test-client-globals-required-phrases.sh` (updated same PR) |
| Unassigned stuck PR | Watchdog invents an owner / marker | `tests/test-stuck-work-watchdog.mjs` (rewritten) |
| Path-filtered required workflow | Merge group never reports context | `tests/test-workflow-policy.sh` + `bin/ai-merge-queue-drift` |
| Stale branch behind main | Green on own base, fail at apply | shared-db freshness (Step 7 hold) + dependency closure |
| Protected skill deleted | Trigger policy fails | `tests/test-skill-trigger-policy.sh` |
| 3×4 harnesses same need | Two tickets, non-overlapping objects | Accepted residual; Step 10 measure + named-assignee stop |
| Session never registers a wait | (Historical) BlockerWatch unused | Step 4B deletes that requirement |

## 10. Tests required

**Same PR as the rule change (never follow-up):**
- `tests/test-client-globals-required-phrases.sh` — new phrases.
- `tools/context-audit/context-audit.py` PARITY_RULES + `tests/test-context-audit.ps1`.
- `tests/test-shared-db-routing-rules.sh` — claim-first.
- `tests/test-skill-trigger-policy.sh` — if skills change.
- `tests/test-stuck-work-watchdog.mjs` — full conductor-test rewrite (Phase C).
- `tests/test-ai-blocker-watch.sh` — registration paths removed/inert (Phase C).

**Must stay green:**
- `bash tests/test-ai-task-gates.sh` (+ phase5/bulk if name-related)
- `bash tests/test-client-globals-required-phrases.sh`
- `pwsh tests/test-context-audit.ps1`
- `bash tests/test-workflow-policy.sh`
- `bash tests/test-shared-db-routing-rules.sh`
- `bash tests/test-skill-trigger-policy.sh`
- `node --test tests/test-stuck-work-watchdog.mjs`
- `bash tests/test-ai-blocker-watch.sh`

No new test framework. PowerShell-compatible; Bash via Git Bash on Windows.

## 11. Constraints, standing rules, and gotchas

- Never push `main`; feature branch + PR + merge queue. `git var GIT_COMMITTER_IDENT` = Albert before commit.
- Stage only task-owned files. No `git add -A`. No destructive resets.
- Shared-db **structure** and the claim engine are **out of this plan** (shared-db repo / orchestrator lane).
- No band-aids, no silent failures, nothing hard-coded. Prefer deletion.
- **No path filters on required checks.**
- **Do not delete claim-admission safety** — rename only (Opus H1).
- **Do not drop shared-db freshness** until #2530 (Step 7).
- Protected-file serialization (`install.sh:204`, `bin/ai-private-config:38`) ≠ reviewer allocator (`docs/reviewer-rotation-rules.md`) (Opus H3).
- Transition (Step 9) is mandatory (Opus H4).
- Private transcripts/secrets never enter this public repo. 1Password vault `vibe_coding` only; never values.
- Do not reopen #401.
- Windows: run Bash tests in Git Bash; `pwsh` for `.ps1` tests.

## 12. Access and environment

| Need | How |
|---|---|
| GitHub | `bin/ai-gh` (authenticated); repos `popcre/ai-devops`, `popcre/shared-db` |
| Worktrees | `git worktree add … origin/main` (see runbook) |
| Tests | Git Bash + Node as pinned by `config/tool-versions.json` / repo docs |
| Globals install | `bin/ai-adopt-globals` per `docs/deployment.md` |
| Secrets | 1Password vault `vibe_coding` (locations only; this plan needs none) |
| Prior reviews | Worktree `ai-devops-wt-debate-20260929/.ai/reviews/` (local) |
| edge-dev3 SSH (if needed) | `ssh -i ~/.ssh/916-alien ahazan@edge-dev3` (Tailscale) |

## 13. Definition of done + risks and open questions

### Done when
- [ ] PR-A–D merged to `origin/main` with green CI; commits named in STATUS.
- [ ] Every STATUS row `✅` cites a path/command/CI run (never a bare count).
- [ ] Step 9 adopt proofs for in-scope machines.
- [ ] Step 8 supersessions applied.
- [ ] `rg` checks in Steps 2–5 show no **required** leftover-proof / MERGE CONDUCTOR / BlockerWatch registration rules.
- [ ] No new orchestrator role, ticket mill, path-filtered required check, or replacement lock.
- [ ] Step 10 measurement file started or scheduled.

### Rollback
Revert the PR(s); re-adopt globals from previous commit. Claims engine and production data untouched.

### Risks
- Mixed-rule fleet window until Step 9 (mitigate: adopt immediately after PR-A/B merge).
- Residual duplicate-need tickets at 3×4 (accepted; Step 10).
- Watchdog regression (mitigate: rewritten test is the contract).
- External skill consumers still expect orchestrator routing (mitigate: optional reference wording).

### Open questions
See §8 OPEN — rename string if `claim-admission` is rejected; fold vs optional skill; optional daily status list.

---

## Self-audit (mandatory)

1. **Could a brand-new AI session execute this without asking anything?** Yes — runbook (branch/test/PR slice), §2 terms, §5 exact strings and file:line, §9 exact edits and gates, §10 named tests, §12 access. No chat context required.
2. **Does it carry background, nuance, and rejections?** Yes — §3 evidence including Albert's BlockerWatch fact, §6 findings (Opus/StepFun), §7 rejection table, §8 LOCKED/OPEN.
3. **Is the goal clear enough for a wrong-step judgment?** Yes — §1 "goal wins"; implementer can refuse a step that re-adds coordination.

**Checklist:** 13 sections · goal up top · standalone · rejections · files+gates · adversarial table · locked/open · out-of-scope · named tests · terms defined · secrets by location · DoD with CI · HANDOFF.d linked · STATUS table · exact replacement strings.

**Self-audit passed** for implementation-plan-standard.md (2026-09-29).
