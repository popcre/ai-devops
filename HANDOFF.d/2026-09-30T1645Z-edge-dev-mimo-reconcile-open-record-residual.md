---
issue: 1116
status: OPEN
owner: mimo/reconcile-open-record-handoff
---

# HANDOFF — reconcile open-record residual (#1116 plan step 2b)

## 0. Decisions only the owner can make

None — nothing in this workstream needs the owner.

Already settled — do NOT re-ask:

- 2026-09-29: no new process `plan_*.md`; no item 3 pin-only lane; no item 9 `ai-ci-status`; no loss ledger; **no lease TTL** (reviewer slots never freed on age).
- 2026-09-29: first instrument is spawn-count, not wall-clock (generous upper-bound timing is the only timing exception).
- 2026-09-28 / standing: never ask a human to approve technical actions; assigned AI reviewers gate them. Never push `main`; branch + PR + merge queue only.
- 2026-09-30: D1 landed `852dd7e3`; the reconcile path was **deliberately** left as a named residual (step 2b), not an oversight. Do not reopen D1.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public recovery toolkit for a multi-model AI workflow (GLM, Claude, Codex, Qwen, etc.). Not an app or service. GitHub: https://github.com/popcre/ai-devops. Work happens on branches + PRs; `main` is protected by a merge queue.

The relevant piece is `bin/ai-glm` — the GLM reviewer wrapper. Its `doctor` health-check runs inside a **10-second** governed-review preflight (`bin/ai-review-preflight` `CHECK_TIMEOUT`, default 10). If doctor overruns that window, every GLM review fails before it starts. That incident class is why parent issue #1116 exists.

## 2. What we set out to do this session, and why

Parent https://github.com/popcre/ai-devops/issues/1116 — process re-cut children A1, A2, B1, C1–C4, D1. This session's goal was **land D1** (the last child): batch orphan-sandbox spawns in `glm_orphan_sandbox_report` and name the remaining cost as a residual.

D1 is done. The residual below is the unfinished remainder of that same cost problem — the other half of the 10s window that D1 did **not** fix, on purpose.

## 3. Current state — what is true right now

**Done and on `origin/main` (do not redo):**

| Item | Evidence |
|---|---|
| A1 CI fast-fail | PR #1134 `f8f032ed` |
| A2 timeout ≠ broken reviewer | PR #1136 `cbe08f5d` |
| B1 orphan TTL + reap | PR #1129 `c12470a5` |
| C1–C4 docs | PRs #1123 `b0779156`, #1124 `ff28e561` |
| D1 orphan spawn guard | PR #1149 `852dd7e3`; Qwen APPROVE exact-head `d43df6c1`; `tests/test-ai-glm.sh` 364/0 |
| Public-boundary unblock for D1 | PR #1180 `343c9771` (redacted LAN IP #1178 reintroduced) |
| Plan STATUS rows A1/A2/B1/C/D1/7/8 | branch `mimo/doctor-orphan-scan-guard` tip `2ab9f813` |

**The residual (NOT started) — plan `IMPLEMENTATION-PLAN.md` §8, dated 2026-09-29, step 2b:**

> reconcile open-record path remains unbounded inside CHECK_TIMEOUT=10. One `implementation:open` record still pays ~10 `jq` reads plus `canonical_path` (Windows: `cygpath` + `tr` per call) inside shared validation functions (`implementation_record_path_valid`, `implementation_meta_valid`); batching those needs changes to code shared with the implementation lifecycle.

Exact code sites (as of `852dd7e3`):

- `bin/ai-glm:495` `implementation_record_path_valid` — calls `canonical_path` twice.
- `bin/ai-glm:504` `implementation_meta_valid` — many `jq` field reads; `canonical_path` at :554 and :558.
- `bin/ai-glm:668` `canonical_path` — on Windows runs `cygpath` + `tr` per call.
- `bin/ai-glm:2288` `reconcile_implementation_record` — per-record path that calls the two validators.
- `bin/ai-glm:2341` `reconcile_implementation_records` — the loop doctor still runs (also `:2740`).
- `bin/ai-review-preflight:13` `CHECK_TIMEOUT` default 10.

Named residual owner: **whoever next touches `bin/ai-glm` doctor** (this handoff's successor).

Named next action (from the plan): batch the `jq` field reads in `reconcile_implementation_record` into a single call and cache `canonical_path` results across the two validators — without changing validation semantics or reviewer routing.

Committed/pushed: yes for all landed children. Residual: not started. No deploy step (this repo is a toolkit, not a service).

## 4. Everything we tried that did NOT work

**Not this session, but the next session must not repeat them:**

1. **Guard only `glm_orphan_sandbox_report`.** Qwen (2026-09-29 debate): the reconcile open-record path is the *larger* unguarded cost in the same 10s window. D1 fixed the orphan loop; the incident class stays open until this residual is done.
2. **Bound reconcile inside the first D1 PR.** Rejected: batching needs changes to validation functions shared with the whole implementation lifecycle. Plan §9 step 2b: if it needs schema/lifecycle work, name a dated residual and stop. Prefer residual over a risky lifecycle change in the first PR.
3. **Wall-clock asserts as the primary guard.** Locked out. Use spawn-count (the D1 tests show the pattern: N=5 and N=50 both cost 7 spawns).
4. **Docs-only merges can silently break the merge queue.** #1178 landed without checks and reintroduced a concrete `192.168.*` address; every full-CI PR then failed `test-public-boundary.sh`. Fixed by #1180 `343c9771`. If CI says `BOUNDARY FAIL: protected private-network topology found`, run `bin/ai-public-boundary-check` and redact — do not chase test flakes first.

## 5. Root causes and key findings

- Doctor's preflight window is **10 seconds**, not 60 (`bin/ai-review-preflight:13` `CHECK_TIMEOUT`). Two cost centers sit inside it: orphan sandbox report (now batched in D1) and reconcile open-record (this residual).
- One `implementation:open` record pays ~10 separate `jq` reads plus repeated `canonical_path` (each `cygpath`+`tr` on Windows) inside `implementation_record_path_valid` / `implementation_meta_valid`.
- Those two validators are shared with the implementation lifecycle (`write_incomplete_artifacts` at `bin/ai-glm:1440`, lock paths, recovery). Changing their *semantics* is the risk; batching reads / caching path results is not.
- D1's spawn-bound tests are the model for this work: `tests/test-ai-glm.sh` "scanning 5 orphan sandboxes costs a bounded number of spawns" / "scanning 50 … same spawn bound as 5" (both 7).
- `bin/ai-glm` is a **reviewer wrapper** — reviewer-safety class. Independent exact-head APPROVE required before merge. Run review with `ai-review --implementer <engine>` (Qwen or whoever is in rotation; never the implementer).
- Subagents cannot use the bash tool in this environment (permission denied). Shell work stays in the parent session.

## 6. Exact next steps

1. Create a worktree from current `origin/main` (never edit the canonical `C:\repos\ai-devops` landing checkout — it is dirty with other sessions' files). Branch e.g. `mimo/1116-reconcile-open-record-batch`.
2. In `bin/ai-glm` `reconcile_implementation_record` / the two validators: batch `jq` field reads into one call per record; cache `canonical_path` results across `implementation_record_path_valid` and `implementation_meta_valid`. **Do not change validation semantics or reviewer routing.**
3. Add a spawn-count guard in `tests/test-ai-glm.sh` mirroring the D1 orphan pattern: stub `jq`/`stat`/`sed`/`cygpath`/`tr`, count spawns for 1 open record vs N open records, assert the same bound (per-record cost is O(1) batches, not O(fields)).
   - You'll know it worked when: `bash tests/test-ai-glm.sh` is green and the new check shows equal spawn counts for 1 vs 25 open records.
4. Declare `ai-task-gates start --class reviewer-safety` in the worktree (touches `bin/ai-glm`). Get independent exact-head APPROVE at the PR tip (Qwen via `ai-review`, or current rotation — check `docs/reviewer-rotation-rules.md`). Never approve your own work.
5. Open PR, merge via the queue (`bin/ai-gh pr merge <n> --repo popcre/ai-devops`). If `test-public-boundary.sh` fails, redact private IPs first (see §4.4).
   - You'll know it worked when: merge-group is green and the commit is on `origin/main`.
6. Live proof in the same session: seed several open implementation records and run the doctor path; show it finishes inside the 10s preflight budget (or that spawn count is bounded). Name the artifact in the PR / issue comment. If code lands without live proof, leave a checklist item on #1116 — never a leftover-proof ticket.
7. Update `IMPLEMENTATION-PLAN.md` §8: mark the 2026-09-29 residual resolved (or partially resolved with exact evidence). Commit on `mimo/doctor-orphan-scan-guard` like prior STATUS rows (`2ab9f813` pattern).
8. Delete this handoff file in the same commit that finishes the work (successor rule), and tick/close any #1116 note you add.

## 7. Constraints and gotchas in force

- Locked (do not relitigate): no new root `plan_*.md`; no item 3 pin-only; no item 9 `ai-ci-status`; no loss ledger; **no lease TTL**; no wall-clock asserts as the first instrument.
- `bin/ai-glm` is reviewer-safety: independent exact-head APPROVE before merge. A protected class cannot be acknowledged away.
- Branch + PR + merge queue only. Never push `main`. Stage only your files.
- `bin/ai-gh` for all GitHub calls (not raw `gh`). Git Bash (`C:\Program Files\Git\bin\bash.exe`), not WSL.
- `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- Sign GitHub comments: `Posted by MiMo chat <id> on <machine>`.
- One unproven live outcome per session. Live proof before claiming done.
- Public repo: never commit transcripts, concrete private host IPs (`192.168.*`, `10.*`, Tailscale `100.64–100.127.*` host addresses), or secrets. `bin/ai-public-boundary-check` is the gate.
- Do not re-add prune/reconcile sweeps to doctor's *report* path beyond what already runs; the goal is to make the existing reconcile cheaper, not to call it more.
- Canonical checkout `C:\repos\ai-devops` is landing-only and dirty. Use your own worktree.

## 8. Access and environment

| Need | Location |
|---|---|
| Repo | `https://github.com/popcre/ai-devops` |
| Plan of record | `IMPLEMENTATION-PLAN.md` on `mimo/doctor-orphan-scan-guard` (worktree `C:\repos\ai-devops-wt-doctor-orphan-guard`, tip `2ab9f813`) |
| Residual text | `IMPLEMENTATION-PLAN.md` §8 "2026-09-29 residual (step 2b)" |
| Code under change | `bin/ai-glm` (`implementation_record_path_valid` :495, `implementation_meta_valid` :504, `canonical_path` :668, `reconcile_implementation_record` :2288) |
| Preflight timeout | `bin/ai-review-preflight:13` `CHECK_TIMEOUT` default 10 |
| D1 test pattern | `tests/test-ai-glm.sh` orphan spawn-bound checks |
| Live proof example (D1) | issue #1116 comment (20 orphans / 420 ms) |
| Git Bash | `C:\Program Files\Git\bin\bash.exe` |
| Secrets | 1Password vault `vibe_coding` only (never paste values) |
| Machine | edge-dev |

## 9. Open questions and risks

- **Risk:** batching `jq` reads or caching `canonical_path` could change validation edge cases (path canonicalization for not-yet-existing paths is in `canonical_path` :668). Mitigation: keep semantics identical; the spawn-count test plus the existing `tests/test-ai-glm.sh` suite (364 checks) is the safety net. Prefer a generous spawn ceiling that still catches per-field spawns.
- **Risk:** touching the shared validators can break the implementation lifecycle (`write_incomplete_artifacts` :1440, lock ownership). Run the full `bash tests/test-ai-glm.sh` and, if you touch preflight-adjacent paths, `tests/test-ai-review-lifecycle.sh`.
- **Open (non-blocking):** exact spawn ceiling after batching — measure once with a seeded backlog; mirror D1's `-le` generous bound style.
- **Open (non-blocking):** `plan_live-proof-session-sizing.md` index row says Completed while its STATUS says partial. Fix only with live evidence; otherwise leave a one-line note. Do not invent closure.
- Merge-group evidence "reports no jobs" flake has been seen; requeue before treating it as a product bug (same class as #1168 eject, later passed).

---

### Self-audit (handoff-writer gate)

1. **Comprehensive for a brand-new developer?** Yes — §1 defines the product and the 10s window; §3 names the residual with `file:line`; §6 is an ordered checklist with gates.
2. **As effective as the writer right now?** Yes — §4–5 carry the failed approaches and the D1/unblock history; §7 lists every lock and trap hit this month.
3. **Every relevant detail included?** Yes — background (§1–2), state (§3), dead ends (§4), root cause (§5), exact actions (§6), constraints (§7), access (§8), risks (§9).
4. **Section 0 complete?** Yes — "None" is explicit; the already-settled list prevents re-asking locked decisions. Sweep of §1–9 found no owner-only judgement left.
