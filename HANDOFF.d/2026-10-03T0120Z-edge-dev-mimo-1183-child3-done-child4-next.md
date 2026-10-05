---
issue: 1183
status: OPEN
owner: mimo/1183-process-children
created: 2026-10-03T01:20:00Z
updated: 2026-10-04T23:55:00Z
machine: edge-dev
agent: mimo
session: ses_ffe5f0c8401dffeRM9Gymq5wr
---

# Handoff — #1183 remainder (children 4–5): COORDINATOR ONLY

**This handoff is superseded in method by Albert's instruction (2026-10-04):**
the next session must **act only as coordinator** and **spin up subagents to
complete each step until the entire remaining job is finished**. Do not
implement child 4 or 5 in the coordinator turn itself.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**None blocking.** Albert already approved the Muse-agreed five-change order
and the coordinator/subagent delivery mode for the rest of #1183.

- **Settled — do NOT re-ask:** children 1–3 landed; capacity vs result labels;
  parallel merge critical path; waiters deleted as a class (explicit
  `--timeout-minutes` only; registration OUT); no path filters; never raise CI
  ceilings; one child per *delivery* stream, but this coordinator session owns
  **the whole remainder (children 4 and 5)** and drives it to completion via
  subagents until the parent is fully ticked.
- **Not needed now:** spend or capacity purchase.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow (reviewers, CI, GitHub traffic tools). Not a product app. Installation
is the deployment mechanism. Public repository — never commit secrets, raw
transcripts, or private paths.

## 2. What the next session must do (coordinator contract)

**Role:** coordinator only. You write the plan of steps, spawn subagents, verify
their evidence, merge their PRs through the queue, tick the parent, and keep
going until **both remaining children are landed and live-proved**.

**Entire job to finish (do not stop at child 4):**

- [ ] **4. Coord-deletion residuals (one-time, existing slice only).** Hetz/t16
  globals re-adopt, machine-tools duplicate rows, parked-issue tidy. No new
  programme. Owner: #1061 residual work (parent closed; residuals ride its
  PR-A…D slice).
- [ ] **5. Maintenance out of the hot path.** O(1) preflight, pin-only
  qualification, unowned reviewer doc table (reviewer → wrapper → pin →
  reroute), two named wrapper fixes (Qwen NODE_OPTIONS sandbox; Gemini headless
  blocks) with reroute-on-empty. Owner: #650 P6/P8 + reviewer wrapper issues.

Plan of record: `docs/process-bottlenecks-and-improvements-2026-09-29.md` §2b.
No new `plan_*.md`. Every child maps to an existing owner (#650 / #511 / #1061).

## 3. Current state — what is true right now

**On `origin/main`:**

| Child | Landed | Evidence |
|---|---|---|
| 1 Capacity labels | `6edee717` | #988 `capacity/infra` live proof |
| 2 Parallel merge path | `5c61060e` | PR #1205; P3/P5 live proofs ticked |
| 3 Delete waiters as a class | `419db12` | PR #1241; Codex APPROVE `633aff3`; ticked on #1183 |

- Parent #1183: children 1–3 `[x]`; **4–5 `[ ]`**.
- Wait policy now: `ai-pr-wait` / `ai-gh-wait` require `--timeout-minutes`;
  registration OUT; turn-end state = issue/PR is the card; bounded janitor
  re-surfaces stuck work.
- Shared-db orchestrator-marker **#3865** (`mimo-orch-queue-resume`) is
  **another session's** — never claim or close it from #1183 work.

## 4. How to run the coordinator (required method)

1. **Declare the task** (`ai-task-gates start --class …`) in your own worktree
   from current `origin/main`. You do not edit product code yourself.
2. **Split the remainder into subagent tickets** (one logical outcome each):
   - **C4a** — machine-tools duplicate rows in `config/machine-tools.tsv`
     (blocks `bin/ai-adopt-globals` launcher half on every host).
   - **C4b** — Hetz / t16 globals re-adopt + real adopt proof when reachable
     (t16 was offline 2026-09-30; re-check first).
   - **C4c** — parked-issue tidy (existing #1061 PR-A…D slice only; no new
     programme).
   - **C5a** — O(1) preflight + pin-only qualification (#650 P6/P8).
   - **C5b** — unowned reviewer doc table (reviewer → wrapper → pin → reroute).
   - **C5c** — Qwen `NODE_OPTIONS` sandbox fix + Gemini headless-block fix,
     each with reroute-on-empty.
3. **Spawn one subagent per step** (or tightly coupled pair). Each subagent
   prompt must be self-contained: goal, repo/worktree rules, exact files, test
   commands, PR title/body, "comment evidence on #1183 / owner issue", and
   "do not touch other sessions' files".
4. **Coordinator duties after each subagent returns:** review the diff, run the
   named tests yourself, open/verify the PR, `bin/ai-gh` + `bin/ai-pr-wait
   <pr> --timeout-minutes N`, merge through the queue, confirm `origin/main`,
   tick the matching child when **all** its slices are done, comment the next
   child, and **immediately spawn the next subagent**.
5. **Stop only when** both children 4 and 5 are ticked on #1183 with landed
   commit SHAs, CI green through `verification-closure`, and live proof where
   the child requires it. Then write YOUR own closeout handoff.

**Never** leave a child half-done for "the next session". The coordinator
session runs the whole remainder.

## 5. Everything we tried that did NOT work (carry these)

- Unquoted `rm -rf $TMP` with empty TMP wiped a worktree — always script
  cleanup with quoted paths.
- Merging an older `origin/main` silently reverted sibling work (StepFun
  Windows, WarpBuild advisory evidence). After any merge, `git diff origin/main
  --stat` and restore unintended reversions.
- Codex exact-head review REJECTs leftover registration/TTL/park language and
  deadline-free `ai-pr-wait` examples. Sweep `rg` before review:
  `REGISTERED with`, `ai-blocker-watch wait`, `bin/ai-pr-wait <pr>` without
  `--timeout-minutes`.
- Every `tests/test-*.sh` needs `config/ci-suites/<name>.json` or
  `fast-classifier / validate` fails.
- `ai-review --assert-head` needs the **full** SHA.
- Long waits get ChildProcess.kill (~10 min) — leave the PR as the card.

## 6. Constraints and gotchas in force

- Live proof before close. Exact-head independent review for reviewer-safety
  paths (`bin/ai-pr-wait`, review wrappers, safety tests).
- No path filters on required checks. Never raise CI ceilings.
- `bin/ai-gh` only for GitHub. Times EST/EDT, named.
- Public repo: no secrets, no raw transcripts.
- Canonical checkout landing-only. Subagents get their own worktrees.
- Do not edit another session's `HANDOFF.d/` file.
- Janitor bounds: 6h per-PR cooldown, comments only, never opens issues.

## 7. Access and environment

- Machine: **edge-dev** (Windows). Git Bash:
  `C:\Program Files\Git\bin\bash.exe`.
- Parent: https://github.com/popcre/ai-devops/issues/1183
- Owner issues: #650 (workflow-efficiency), #511 (session sizing),
  #1061 (coord-deletion residual).
- Secrets: 1Password vault `vibe_coding` only.

## 8. Open questions and risks

- t16 may still be unreachable — C4b needs a reachability check before proof;
  do not block C4a/C4c on it.
- Windows runner slowness is infra (#209 / #262), not process.
- Shared-db marker #3865 is another session's.

## 9. Success gate for the whole job

You're done only when:

1. #1183 shows **all five** children `[x]` with landed SHAs.
2. Parent comment names the final landing commit(s).
3. No child is left "for later"; leftover-proof mill stays deleted.
4. You write a new `HANDOFF.d/` closeout (or state the workstream is closed).

## Mandatory self-audit gate

- [x] Sections 0–9 present
- [x] Next session is coordinator-only with subagent steps C4a–C5c
- [x] Entire remainder (children 4 **and** 5) is in scope until finished
- [x] Failures in §5 are cold-actionable
- [x] No secrets
- [x] A stranger can run the coordinator without this chat

### Self-audit answers (handoff-writer)

1. **Comprehensive for a brand-new developer?** Yes — §2 is the coordinator
   contract; §3 state; §4 method.
2. **Detailed enough to continue?** Yes — §4 splits; §5 dead ends; §9 gate.
3. **Every relevant detail included?** Yes.
4. **Owner sees every decision from §0 alone?** Yes — method is owner-ordered.
