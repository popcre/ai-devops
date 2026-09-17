# Handoff — programme #401 live-proof routing, Step 9 closed, #498 shipped

- **Created:** 2026-09-16T20:00Z, machine `edge-dev`, agent Claude Code (Opus 5)
- **Tracking issue:** [popcre/ai-devops #401](https://github.com/popcre/ai-devops/issues/401) — **OPEN, deliberately.**
- **Plan:** [`../plan_shared-db-complete-throughput-repair.md`](../plan_shared-db-complete-throughput-repair.md). Its STATUS table is the source of truth; each unproven row links its live-proof owner.
- **Predecessor:** `2026-09-16T0030Z-edge-dev-claude-programme-401-final-acceptance.md` (left in place; its owner decision question is now answered, below).

## 1. Goal
Close #401 only when every STATUS row is ✅ on `main` with live behavior evidence and the Step 10 five-outcome trial has passed.

## 2. Owner rulings in force (Albert, 2026-09-16, chat)
- Keep #401 OPEN until live proof of every step. Do not re-ask.
- Only work that changes database structure goes to the shared-db orchestrator. Proofs, tooling, docs, scripts never do.
- Every u2giants/shared-db issue number in a reply says orchestrator or non-orchestrator.
- EDGE-ALIEN and EDGE-RUNN-ENVY are runners (no Claude/Codex): out of scope. t16 is "insignificant": out of scope.
- The chat named **"Issues #3027, #3028, #3029 to production"** owns shared-db #3027–#3029. Stay off them.

## 3. Done this session (verified merged)
- ai-devops PR #497 `ece11e45` — live-proof owner link on each unproven STATUS row.
- ai-devops #499 `db8babb3`, #503 `f7dc7fea`, and the Step 9 close PR (`7139115f`) — Step 9 ✅; #496 closed.
- #498 (review recording, branch refresh, guarded merge speed) closed: ai-devops #505 `e706eeed`; shared-db #3051 `638fef44`, #3063 `a5e14ea1` (AI_MUSE_CALLER default + live-head injection). Live proof: shared-db close-out PR #3067 merged in 1:21 with no retries.
- #507 follow-ups (merge waits on running checks, one-step branch refresh, production-apply dispatch helper) built, merged, live-proven.
- shared-db #3028 (non-orchestrator) closed; PR #3031 `d53d4746` merged.
- shared-db #3039 (non-orchestrator) auto-promotion defect fixed by PR #3047 `4e32da47`.
- Nothing applied to preview or production by this session directly.

## 4. Remaining — each row, owner, next action
| Step | State | Owner | Next action |
|---|---|---|---|
| 1, 2, 3, 6 | Tooling live; need a real production database change to exercise | other chat via shared-db #3027 (non-orch) | wait for a genuine structural PR to flow; record evidence |
| 2A, 7 | Proven live (PR #3056 `25722fb2`; 10.4-min reroute) | — | mark ✅ when #3027 report lands |
| 4 | Alarm installed; cannot fire without an open orchestrator session | #3027 owner | prove when an orchestrator is next open |
| 5 | Registry merged, but proof stubbed 7/9 preflight checks locally | unassigned — **not** fully proven | a real delivery through the registry; open PRs shared-db #2872, #2869 may need registry entries |
| 8 | moved out to shared-db #2530 (non-orch) | #2530 | none for #401 |
| 10 | trial | shared-db #3029 (non-orch), other chat | blocked on the rows above |
| #3039 live | fix merged, unobserved | unassigned | watch next low-risk auto-promotion succeed |
| #507 wrong-owner messages | blocked | shared-db #3049, #3066 (non-orch, other sessions) | resume when those land |

## 5. Merge-queue question (answered to Albert)
A native merge queue on shared-db would stop main moving under PRs; owned by shared-db #2530 (non-orch). Re-review would need tying to change content rather than one head SHA.

## 6. What did NOT work
- Putting `db-work` on #3027–#3029 sent proofs to the orchestrator. Wrong; labels removed and rerouted.
- `gh pr merge --delete-branch` fails in popcre/ai-devops (merge queue on). Merge without it.
- Subagents leaked duplicate wait loops (11 tasks, one 3.5h). Kill hung `ai-task-gates start` processes; check task list before reporting counts.
- The #3028 agent re-polled already-green checks for hours; the real block was unrecorded governed reviews (missing `AI_MUSE_CALLER=claude`, stale head in the prompt) plus main moving. Fixed in #3063.
- t16 SSH timed out; now out of scope.

## 7. Workspace
- This worktree `shared-db-repair-401-89d530`: clean, branches merged; safe to clean.
- `agent-ac0a3d8b54b21596e` (branch `claude/step9-t16-496`): Step 9 agent, work merged via #499/#503; safe to clean after a clean-tree check.

## 8. Possibly stale
All SHAs/PR states read 2026-09-16 between 12:00Z and 20:00Z. `main` at write time: `bad2d4f4`.

## 9. Resume
Read #401's STATUS table, then check shared-db #3027 and #3029 progress (other chat's). Your only own job: a live Step 5 registry delivery, and #3039's live confirmation — one per session.
