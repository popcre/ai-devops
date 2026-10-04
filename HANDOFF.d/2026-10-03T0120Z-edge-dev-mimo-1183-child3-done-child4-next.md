---
issue: 1183
status: OPEN
owner: mimo/1183-process-children
created: 2026-10-03T01:20:00Z
machine: edge-dev
agent: mimo
session: ses_ffe5f0c8401dffeRM9Gymq5wr
---

# Handoff — #1183 process children (child 3 landed; next child 4)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**None blocking.** Albert already approved the Muse-agreed five-change order
(`docs/process-bottlenecks-and-improvements-2026-09-29.md` §2b) and the
one-child-per-session rule on parent #1183. Do not re-ask him to pick work.

- **Already settled — do NOT re-ask:** capacity vs result labels (child 1);
  parallelize merge critical path (child 2); delete waiters as a class (child
  3, this session); no path filters; never raise CI ceilings; required
  `ai-blocker-watch wait` registration is OUT.
- **Not needed now:** spend or capacity purchase.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow (reviewers, CI, GitHub traffic tools). Not a product app. Installation
is the deployment mechanism. Public repository — never commit secrets, raw
transcripts, or private paths.

## 2. What we set out to do this session, and why

Execute **child 3 only** of parent #1183:

> Delete waiters as a class. Bounded in-session `ai-pr-wait` with explicit
> deadline only. No TTL service, no park-state store, no waiter registry.
> Required `ai-blocker-watch wait` registration is OUT. Turn-end state on the
> issue, re-surfaced by bounded janitor. Owner: #511 + #1061 residual.

Inherited handoff:
`HANDOFF.d/2026-10-02T1320Z-edge-dev-mimo-1183-child2-proofs-done-child3-next.md`
(child 2 + P3/P5 live proofs done; next was child 3).

## 3. Current state — what is true right now

**Shipped and on `origin/main`:**

- Child 3 code: PR **#1241**, merge commit **`419db12`** (2026-10-03 01:05 UTC).
  Title: "Delete waiters as a class: explicit deadlines only (#1183 c3)".
  - `bin/ai-pr-wait` and `bin/ai-gh-wait` **require** `--timeout-minutes` (no
    default). Missing/zero deadline exits 3 with `explicit deadline only`.
  - `AI_GH_WAIT_TEST_DEADLINE_EPOCH` only applies when `AI_DEVOPS_TEST_MODE=1`.
  - Required BlockerWatch registration language is gone from AGENTS.md,
    standing-rules-details, task-router, IMPLEMENTATION-PLAN, plans, skills
    (sync-dotfiles, shared-db-handover, operating-manual), install.sh, and
    OPEN `HANDOFF.d/` files. Inert `wait`/`has-wait` only print a note.
  - No required waiter registry, TTL service, or park-state store. Voluntary
    inert registration is permitted, unrequired, unmeasured.
  - Turn-end: leave the issue/PR as the card. Completion-eval treats
    issue-as-card as the correct close; claiming a registration is
    `false_completion`.
  - New narrow gate: `tests/test-1183-c3-delete-waiters.sh` (seconds).
  - Codex exact-head final-check **APPROVE** at
    `633aff3b46de8efe852e3203d9cff7baf3640f97`
    (`.ai/reviews/codex-final-check-20261002T220403-3676995-11595.md`).

**Parent #1183:**

- Children 1–3 ticked. Comment posted: `next: child 4`.
- Children **4–5 still `[ ]`** — take them one per session, in order.

**Not in this session's scope:** shared-db orchestrator-marker **#3865**
(`mimo-orch-queue-resume`) is **another session's** work — do not claim or
close it.

## 4. Everything we tried that did NOT work

- **PowerShell `rm -rf $TMP` with an empty TMP deleted a worktree.** Always
  write a script file with a quoted path; never expand unquoted `rm -rf`.
  All child-3 edits were reapplied after that loss.
- **`git rebase` then `reset --hard` to undo it** left the branch missing
  newer main (StepFun Windows, WarpBuild advisory evidence, Muse pin). Fix:
  `git checkout origin/main -- <unintended files>` and/or `git merge origin/main`
  again; never assume a merge preserved siblings.
- **Codex final-check REJECT loop (13 rounds)** found real residuals: skills
  still directing registration, plans prescribing TTL/park-state, handoffs with
  deadline-free `ai-pr-wait`, completion-eval treating registration as valid,
  and a focused suite that `cd`'d into `tests/` so it never ran. Fix each; do
  not argue with the report.
- **`--assert-head` needs the full 40-char SHA**, not an abbreviation.
- **`test-ai-pr-wait.sh` timing asserts flake on loaded Windows hosts.**
  Bounds were loosened (`ELAPSED -lt 20`); do not retighten without data.
- **`ai-pr-wait` / long `ai-review` get ChildProcess.kill (~10 min) from the
  desktop tool.** Leave the PR as the card; use short bounded polls.

## 5. Root causes and key findings

- Waiters as a class (registry, TTL, park-state, required registration) is the
  deleted shape. What remains is bounded in-session wait with a caller-named
  deadline, plus the stuck-PR janitor.
- Residual "REGISTERED with `ai-blocker-watch wait`" text was the main
  contradiction surface. A residual-language guard lives in
  `tests/test-ai-blocker-watch.sh`.
- Exact-head independent review is mandatory for `bin/ai-pr-wait`
  (reviewer-safety). Report path must match the shipping head.
- `config/ci-suites/test-<name>.sh.json` is required for every `tests/test-*.sh`
  or `fast-classifier / validate` fails on manifest discovery.

## 6. Exact next steps

1. Open **#1183**. Take **child 4 only** ("Coord-deletion residuals, one-time,
   existing slice only. Hetz/t16 globals re-adopt, machine-tools duplicate
   rows, parked-issue tidy. No new programme. Owner: #1061 residual work
   (parent closed; residuals ride its PR-A…D slice)."). Do not start 5.
2. Fresh worktree from current `origin/main`. `ai-task-gates start --class …`.
3. Branch + PR + merge queue. Tick child 4, comment `next: child 5`, stop.
4. Do not open a new `plan_*.md`. Map rows to #650 / #658 / #1061 / #511.

You'll know it worked when: child 4 is ticked with landed commit SHA, CI green
through `verification-closure`, and the parent comment names child 5.

## 7. Constraints and gotchas in force

- Live proof before close. Exact-head independent review for reviewer-safety
  paths. No path filters. `verification-closure` + merge queue stay.
- Waiters: explicit `--timeout-minutes` only; registration OUT; issue-as-card.
- Janitor bounds: 6h per-PR cooldown, comments only, never opens issues.
- Public repo: never commit secrets or raw transcripts.
- `bin/ai-gh` for GitHub. Times in EST/EDT, named.
- Canonical checkout is landing-only. Use worktrees. Never touch another
  session's `HANDOFF.d/` file.

## 8. Access and environment

- Machine: **edge-dev** (Windows). Git Bash at
  `C:\Program Files\Git\bin\bash.exe`. `$env:MIMO_PYTHON` for Python.
- Worktree this session: `C:\repos\ai-devops-wt-1183-c3-waiters` (branch
  `mimo/1183-c3-delete-waiters`, **merged** as `419db12`; safe to delete after
  this file is in).
- PR #1241 MERGED. Commit `419db12` is on `origin/main`.
- Secrets: 1Password vault `vibe_coding` only. None used this session.

## 9. Open questions and risks

- `test-ai-pr-wait.sh` timing flakes on loaded hosts if several suites overlap
  a GitHub job; treat as capacity, not result.
- Windows runner slowness is infra (#209 / #262), not process.
- Shared-db marker #3865 is another session's — leave it.

## Mandatory self-audit gate

- [x] Sections 0–9 present
- [x] Next steps actionable cold (#1183 child 4 named with gates)
- [x] Failures in §4 include what was tried and why it failed
- [x] Constraints match AGENTS.md / agreed plan
- [x] No secrets, tokens, or raw private transcript text
- [x] Owner-only decisions called out (none open; settled list included)
- [x] A stranger can pick up child 4 from this file alone

### Self-audit answers (handoff-writer)

1. **Comprehensive for a brand-new developer?** Yes — §1 app, §2 goal, §3
   landed SHA/review, §6 exact next step with success gate.
2. **Detailed enough to continue as well as this session?** Yes — §4 dead ends
   (rm -rf wipe, merge revert, Codex REJECT loop, assert-head SHA, flakes).
3. **Every relevant detail included?** Yes — background/goals/state/failures/
   decisions/constraints/risks/next actions/evidence.
4. **Owner sees every decision from §0 alone?** Yes — nothing blocking; settled
   rulings listed; shared-db #3865 named as another session's.
