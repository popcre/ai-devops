---
issue: 159
status: OPEN
owner: codex/repo-throughput-restructure-159
---

# HANDOFF — repository throughput restructure

## 0. Decisions only the owner can make

None. Albert authorized the holistic replacement plan, one parent, necessary children, retirement of #89/#98/#112, and completion of the reorganization on 2026-08-28.

Already settled — do not re-ask: #159 owns the outcome; #160–#169 own independently verifiable units; old issues/handoff are history; safety coverage cannot be quarantined, weakened, or timed out of relevance.

## 1. What this repository is

`popcre/ai-devops` is POP Creations' public restore and operations toolkit for Albert's multi-model AI workflow. It contains Bash/PowerShell commands, reviewer wrappers, skills, prompts, setup, and offline tests. Work lands on `main`; GitHub is source of truth; there is no application deployment.

## 2. What this session set out to do

Replace fragmented throughput work across the old plan, 2026-08-27 handoff, and #89/#98/#112 with one complete plan and connected parent/child issue structure. The business goal is that concurrent sessions finish and ship rather than spend hours rerunning, waiting, or rebuilding.

## 3. Current state

- Parent [#159](https://github.com/popcre/ai-devops/issues/159) and sub-issues #160–#169 are open.
- `plan_repo-throughput-restructure.md` is the complete live plan; read STATUS first.
- Start #165, then #160. #166 is last.
- #98/#112 were closed with successor links; #89 was already closed and received the successor record.
- The prior handoff retired only after all obligations, findings, rejections, and risks moved into the plan/issues.
- This session changed documentation and issue organization only; no throughput code or ruleset configuration changed.

## 4. What did not work before

- The three issues together omitted fast CI, local selection, conduct rules, cutover, and final measurement ownership.
- The old plan did not fully preserve Kimi acceptance, per-suite timing/cancellation/third-run requirements, or PR #102/p95 criteria.
- Quarantine could hide failures; sharding multiplied runners; a fast sibling's logs could remain blocked; faster tests alone do not remove queue starvation; classic protection API absence did not mean no rulesets.

## 5. Root causes and findings

- Reviewer tests confused readiness with correctness under load.
- Windows repeated Linux Bash work without per-suite evidence.
- PR, merge-group, and post-merge events could repeat exact-tree work.
- Queue rebuilds invalidate queued changes as `main` moves.
- Sessions lacked narrow selection and event-aware waiting.
- Renamed required checks can lock the repository.

Plan §§3, 6, and 7 preserve the evidence and rejected reasoning.

## 6. Exact next steps

1. Execute #165 and update STATUS with origin/main evidence.
2. Execute #160 after checking live reviewer work. Gate: ten serial loaded runs, defect injection, counts, green CI.
3. Record Phase B baseline; execute #161–#163. Gate: fast/docs targets, safe duplicate removal, local selection.
4. Execute #164 after runtime work. Gate: representative queue p95 at most 60 minutes and no indefinite overtaking.
5. Execute #167, #169, and #168 after their named dependencies. Gate: shared test/provider infrastructure preserves behavior and the plan backlog has evidence-backed ownership.
6. Execute #166 last. Gate: throwaway PR proves required contexts/queue; final measures land; children/#159 close; delete this handoff in completion commit.

Use `fresh-session` at plan context cuts.

## 7. Constraints and gotchas

- Preserve every assertion/capability. Work on `main`; stage owned files; verify identity; never force-push.
- Read live rulesets before writes and preserve admin bypass. Stale required contexts can block all merges.
- Keep `skills/` verified and scheduled complete Windows Bash.
- Run reliability repetitions serially. Use Git Bash and prove EOL.
- Update the plan with each child; issue state alone is not evidence.

## 8. Access and environment

- `https://github.com/popcre/ai-devops`, branch `main`; GitHub CLI authenticated for this reorganization.
- Offline tests need no secrets. Paid probes use 1Password vault `vibe_coding` by item title only.
- No production application, database, or URL is involved.

## 9. Open questions and risks

No owner decisions are open. Evidence-bounded questions: Windows suite classification, exact-tree post-merge duplication, least-risk queue lever, and similar races in other reviewer suites.

Main risks: stale required contexts, Windows coverage gap, over-broad cancellation, weakened reviewer safety. Plan §13 provides prevention and rollback.

### Handoff self-audit

1. **Newcomer continuation: yes.** §§1–3 identify repository, goal, plan, issues, state; §6 gives gates.
2. **Equivalent knowledge: yes.** §§4–5 preserve failed models and causes; §7 preserves traps.
3. **Every execution dimension: yes.** §§1–9 cover goal, state, failures, findings, steps, constraints, access, risks, evidence.
4. **All owner decisions in §0: yes.** §§1–9 contain no unresolved owner choice; §0 records authorization and settled decisions.
