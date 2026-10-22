---
issue: 1948
status: OPEN
owner: unclaimed — next session claims on the owner issue
---

# Handoff — reviewer observation week (fast-fail, per-session skip, non-blocking reviews)

Machine: edge-dev3 · Agent: Claude · Written: 2026-10-21 4:40 PM EDT · Chat `92999f3c-c10c-45bc-8f1e-9bb6afb2bbc8`
Plan: [plan_reviewer-observation-week.md](../plan_reviewer-observation-week.md) — read its STATUS table first; do not re-plan.

## 0. Business decisions only the owner can make

- **Already decided (Albert, 2026-10-21, verbatim in plan §1 and §3):** sessions must sense a reviewer failure quickly, move on, and not retry that reviewer in the session; keep sending reviews but do not wait on them and do not require approval for ordinary repos during the week; log every failure. Two tiers: production and shared-db keep the full gate. Routine operations (restart, credit, key reset) stay allowed during the freeze.
- **Still his:** nothing until plan step 9 (what to keep after the week).

## 1. What this application is

`popcre/ai-devops`: Albert's public toolkit that gives AI coding sessions an independent AI review (Muse, DeepSeek, GLM, StepFun) on five hosts. Plan §2 names every relevant file.

## 2. What we set out to do this session

Diagnose why the reviewer system has never stayed green 24 h in ten months, then write the plan Albert asked for. Both done. No code changed. No install run.

## 3. Current state

- Diagnosis (this chat, 2026-10-21): the repair loop is the largest outage source; strict verdict parsing voids real approvals; sessions wait up to two hours and retry the same reviewer. Numbers and sources are in plan §3 and §6.
- Plan written and self-audited; registered in `docs/pending-work.md` and `docs/task-router.md` (this PR).
- Nothing implemented. Fresh session starts at plan step 0.

## 4. What was tried that did not work

- A plain seven-day freeze with reviews still gating merges: Albert rejected it because all four reviewers can be down at once and work cannot stop.
- The transcript-mining method that worked (local prefilter, then ScaleDown) is recorded in memory `scaledown-transcript-extract-2026-10-21`; it is not the week's evidence source.

## 5. Root causes and key findings

Plan §6.

## 6. Next steps

Plan §9, in order. Steps 1–4 are the last reviewed reviewer-code change before the freeze; then step 6 installs and declares the freeze; then seven daily tallies.

## 7. Gotchas

Plan §11. Owner constraint: no new CI jobs, Windows CI runs, or test suites.

## 8. Related

- Diagnosis evidence of record: `ai-reviewer-issue list` on edge-dev3 and edge-dev; `~/.local/state/ai-devops/review-scoreboard/reviews.jsonl`.
- Sibling programmes paused for the week: #1783, #1822, #1678.
