---
issue: 1678
status: OPEN
owner: mimo/edge-dev-reviewer-repair-impl
---

# HANDOFF — edge-dev reviewer repair implementation (steps 0–3 landed)

Machine: edge-dev · Agent: MiMo · Written: 2026-10-19 3:40 PM EDT
GitHub signature: `Posted by MiMo chat unknown on edge-dev`
Plan: [plan_edge-dev-reviewer-repair-no-review.md](https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md)
Prior planning handoff (do not edit): [2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already decided (do not re-ask):**
  - Albert, 2026-10-15 — implementation of the no-review plan must not need AI reviewers as a gate.
  - Albert, 2026-10-16 — **path 1** for step 3: a separate reviewed workstream may edit protected wrappers (`bin/ai-review-pool`, `bin/ai-glm`, `bin/ai-review-lifecycle`, `tools/reviewer_events.py`) with exact-head independent review as the gate. That is outside the no-review bootstrap rule.
  - Albert, 2026-10-19 — stop the finding-by-finding review loop; Medium/Low do not hold the merge.
- **Still his:** nothing pending for this handoff.
- **Not Albert's call:** door/profile fixes, capability names, test fixtures.

## 1. What this application is

`popcre/ai-devops` on **edge-dev** (Windows, Git Bash / MINGW). Recovery toolkit for a multi-model AI workflow. Sibling programme: [plan_reviewer-recurrence-repair.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-recurrence-repair.md) (edge-dev3) — do not rewrite it.

## 2. What we set out to do this session

Implement `plan_edge-dev-reviewer-repair-no-review.md` starting at step 0 then step 1, in a fresh worktree from `origin/main`, without using AI reviewers as a gate. After owner chose path 1, also land the GLM REVISE warm-follow-up (step 3) as a reviewed workstream.

## 3. Current state

| Outcome | State | Evidence |
|---|---|---|
| Step 0 class contract | **Done** | PR bodies carried `effective class: code`, `required gates: <none>` for steps 0–2 |
| Step 1 inventory | **Done** | [tests/verification/edge-dev-reviewer-repair/README.md](https://github.com/popcre/ai-devops/blob/main/tests/verification/edge-dev-reviewer-repair/README.md) merged (PR #1805, `bba1bcfe`) |
| Step 2 StepFun Windows spawn | **Code landed** | PR #1807 `0be8ffa5`; fixture `stepfun_windows_shell_spawn_resolves` 62/62. **Live shell proof is still step 6** |
| Step 3 GLM REVISE follow-up | **Done (path 1)** | PR #1819 `b5cfa876`; DeepSeek APPROVE on `f0cd29e2`; fixture `glm_revise_followup_reuses_bound_turn` 13/13 |
| Steps 4–7 | **Not started** | see §6 |
| Local incidents | **OPEN** | `20261014T203826Z-edge-dev-stepfun-2686842`, `20261014T201712Z-edge-dev-glm-2563781` — dispose in step 6 |
| Issue #1678 | **OPEN** | keep the checklist here; no proof-only ticket |

## 4. Everything we tried that did NOT work

- **Eight DeepSeek exact-head passes.** Every fix moved the head and invalidated APPROVE. Lesson: treat only High/blocking as merge-holding; do not churn on Medium/Low.
- **Provider-name gate for REVISE** (`provider != glm` in `bin/ai-review-pool`). Forbidden by `tests/test-pool-dispatch-doors.sh` (`shared_review_layers_have_no_converted_name_gates`). Replaced with capability `revise_verdict` in `config/review-runner-doors.json` + `tools/lib/review-capabilities.sh`.
- **Fail-open formal route parse** (`|| echo general`). Replaced with fail-closed dies (activation invalid / invalid route / missing pinned runner).
- **Empty-base wildcard** in follow-up probe (a REVISE with no recorded base stole any `--base` dispatch). Now requires a recorded base match when `--base` is set.
- **Lifecycle `finish` rejected REVISE** → every REVISE became `accounting-failed` with lock held. Fixed in `bin/ai-review-lifecycle`.
- **Rebase after `main` moved** invalidated an APPROVE (`fe075dfc` → `b621dae7`) and flipped the verdict. Prefer merge-in or land before more `main` traffic when a review is already green.
- **Full `tests/test-glm-pool-dispatch.sh` hangs on this Windows host** (pre-existing; reproduces on `origin/main`). Named suite is `tests/test-glm-revise-followup.sh`.
- **`bash tests/test-ai-stepfun.sh` dies in PowerShell ACL setup** on edge-dev (pre-existing; same on `origin/main`).

## 5. Root causes and key findings

- StepFun spawn: the review door launched OpenCode without PATH shims for `bash`/`bash.exe` (PATHEXT). `bin/ai-stepfun` already installed them; the door did not. Fix: `sf_install_windows_shell_shims` in [tools/lib/review-doors/stepfun.sh](https://github.com/popcre/ai-devops/blob/main/tools/lib/review-doors/stepfun.sh).
- GLM REVISE: `bin/ai-review-pool` always ran `ai-glm new` with a RUN_ID tag and no `--repo`, so a REVISE could not continue the paid conversation. Path 1 allows pool/glm/lifecycle edits with DeepSeek exact-head review.
- REVISE is a real terminal verdict now: pool brief (via `revise_verdict`), `bin/ai-review-lifecycle` `finish`, `tools/reviewer_events.py` supersede set (REVISE overturns older APPROVE), and `bin/ai-glm` format text all accept it.
- Warm follow-up is one-shot per REVISE (`*.followup-armed` marker, cleared only on ask success), newest `last_activity_at` wins, base-bound, cold fallback on failure.
- **Shared review layers must not branch on provider name** for evidence/receipt/record/cleanup/qualification steps. Use a named capability in `config/review-runner-doors.json` (rule #1834). Inventory: [docs/reviewer-harness-consolidation.md](https://github.com/popcre/ai-devops/blob/main/docs/reviewer-harness-consolidation.md).

## 6. Exact next steps

1. **Step 4** — durable report publish + foreign-orphan non-interference on Windows paths. Targets: `tools/lib/review-lifecycle-core.sh`, sandbox self-cleanup tests. Cases: `durable_report_publish_survives_process_exit`, `foreign_orphans_do_not_block_fresh_review`. Align with sibling plan step 2; do not fork its receipt protocol.
2. **Step 5** — Git Bash discovery when `ProgramFiles` is empty ([#1701](https://github.com/popcre/ai-devops/issues/1701)). `.cmd` launchers are `code` class but the owner rule said do not edit `bin/ai-*` entrypoints — confirm with Albert if `.cmd` files may change, else escalate per plan §8. Named suite: `tests/test-windows-bash-selection.sh` (note: that suite is about CI lane selection, not bash.exe lookup — the plan text and the suite name diverge).
3. **Step 6** — live smoke on edge-dev (no paid blast): StepFun starts a shell; GLM warm follow-up after REVISE (disposable source); durable report path. Then `bin/ai-reviewer-issue resolve` (or `partially-resolved`) for `20261014T203826Z-edge-dev-stepfun-2686842` and `20261014T201712Z-edge-dev-glm-2563781` with merged SHAs `0be8ffa5` / `b5cfa876` and evidence paths. Update [#1678](https://github.com/popcre/ai-devops/issues/1678) on the **same** issue.
4. **Step 7** — code-only install via the supported installer (never `git pull` the canonical checkout); verify launcher hashes; re-run step 6 smoke; update plan STATUS.

**Verify success:** both incidents disposed with evidence; named tests green; smoke shows a starting StepFun shell and a durable report; installed hashes match merged source.

## 7. Constraints and gotchas in force

- No-review plan steps stay `prose`/`code` with **no** `ai-review` gate. Path 1 (already used for step 3) is the only reviewed-workstream exception and is closed for further steps unless Albert re-opens it.
- Never edit `bin/ai-*` bash entrypoints, `tools/reviewer_*.py`, or `config/task-gates.json` under the no-review plan (path 1 covered the specific files listed in §5).
- Branch + PR + merge queue; never `--admin`; never push `main`; never force-push except `--force-with-lease` after a rebase on your own branch.
- Worktree-based; canonical `C:/repos/ai-devops` is landing-only. Fresh worktree from `origin/main` per task.
- Invoke Git Bash as `"C:\Program Files\Git\bin\bash.exe" -c "..."` (plain `bash` is a WSL stub). Long `ai-review` runs need a detached `Start-Process` wrapper script.
- Times EST. Secrets: 1Password `vibe_coding` only. Stage only owned files.
- Reuse [#1678](https://github.com/popcre/ai-devops/issues/1678) / [#1467](https://github.com/popcre/ai-devops/issues/1467) / [#1701](https://github.com/popcre/ai-devops/issues/1701) / [#1370](https://github.com/popcre/ai-devops/issues/1370); no proof-only tickets.
- Shared review layers: no provider-name behaviour gates (#1834). Use capabilities.

## 8. Access and environment

- edge-dev (Windows). Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- Canonical `C:/repos/ai-devops` landing-only.
- Implementation worktree used: `C:/repos/ai-devops-wt-1678-edge-dev-repair` (branch `mimo/1678-step3-glm-revise-followup`, merged — safe to remove after confirm).
- Local incident store: `bin/ai-reviewer-issue` (private; never copy raw bodies into the public repo).
- DeepSeek rotation reviewer for path 1 (`ai-review deepseek final-check --implementer mimo`). Muse unusable here; StepFun was out-of-credit; GLM never reviews GLM-orchestrated work.

## Self-audit

1. **Could a brand-new AI session execute from this file with no chat context?** Yes — §6 names each remaining step, targets, and verification; §3 has merged SHAs; §7 has the constraints that blocked us.
2. **Does it carry background and failed attempts?** Yes — §4 lists every dead end (review loop, provider-name gate, fail-open, empty base, REVISE terminal gap, rebase invalidation).
3. **Is the goal clear?** Yes — dispose the two incidents with evidence after steps 2–7 complete; goal wins over any step.
