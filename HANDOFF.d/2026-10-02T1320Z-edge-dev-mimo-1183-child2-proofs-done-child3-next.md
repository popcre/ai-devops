---
issue: 1183
status: OPEN
owner: mimo/1183-process-children
created: 2026-10-02T13:20:00Z
machine: edge-dev
agent: mimo
session: ses_ffe5f0be4b2b2ffeA4hXmqY4b1
---

# Handoff — #1183 process children (child 2 + live proofs done; next child 3)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**None blocking.** Albert already approved the Muse-agreed five-change order and
explicitly asked this session to exercise every remaining live proof and finish
child 2. Do not re-ask him to pick technical work.

- **Already settled — do NOT re-ask:** capacity vs result labels (child 1,
  2026-09-30); parallelize merge critical path + finish P3/P5/P6 (child 2,
  2026-10-02); no path filters; never raise CI ceilings; Windows stays gating
  off `merge_group`; `ai-blocker-watch wait` registration is OUT.
- **Not needed now:** spend or capacity purchase (new runner / second host).
  If a later child needs one, name it and ask then.

**If anything later needs the owner, put the whole list to him in ONE message
before starting work.**

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow (reviewers, CI, GitHub traffic tools). Not a product app. Installation
is the deployment mechanism. Public repository — never commit secrets, raw
transcripts, or private paths.

## 2. What we set out to do this session, and why

Execute **child 2 only** of parent #1183, then capture every remaining live
proof so child 2 acceptance is complete:

> Parallelize the merge critical path + fast-fail. Finish P3/P5/P6 acceptance.
> Required verification-closure and merge queue survive. Windows stays gating
> (parallel lanes). No path filters. Never raise ceilings. Owner: #650.

Inherited handoff: `HANDOFF.d/2026-09-30T2042Z-edge-dev-mimo-1183-child2-and-live-proof.md`
(child 1 landed `6edee717`; next was child 2 + live proof).

## 3. Current state — what is true right now

**Shipped and on `origin/main`:**

- Child 2 code: PR **#1205**, squash commit **`5c61060e`**
  (2026-10-01). Title: "Parallelize hosted reviewer proofs with per-suite
  fallback (#1183 c2)".
  - Hosted Codex/Grok are independent jobs
    (`windows-reviewer-fallback-codex`, `windows-reviewer-fallback-grok`).
  - Preferred stays serial on one qualified host (same-host exclusion).
  - Fallback is per unproved suite after preferred termination
    (`fallback_codex` / `fallback_grok`).
  - Stable `windows-reviewer-safety` aggregate still fails closed per suite.
  - `bin/ai-merge-group-evidence` accepts **both** hosted fallback jobs as the
    identical-reviewer-suites substitute (replaces the old single
    `windows-reviewer-fallback` name).
  - Live on PR #1205: both fallbacks started together; Codex finished in ~8 min
    while Grok continued (~34+ min). Wall ≈ max, not sum. `verification-closure`
    and `windows-reviewer-safety` succeeded.

**Live proofs — all ticked on #1183:**

- Child 1: issue **#988** carries label `capacity/infra` from
  `tools/ci/report-scheduled-failure.sh` (deliberate invocation of the same
  script the scheduled job runs; timeout-style conclusions on run
  `36921908061`). Scheduled cron is `17 6 * * 1` (Mondays 6:17 UTC) — a natural
  incident would have taken until Monday.
- Child 2 / P3: negative run **`37003387555`** (PR #1226, closed) —
  `tests/p3-invalid-candidate.sh` with an unclosed quote; `fast-classifier /
  validate` failed; `linux-offline-shard`, `windows-offline-section`, and
  reviewer fallbacks **skipped**; `verification-closure` failed closed.
  Positive run **`37007389909`** — repaired successor; `validate` success;
  `linux-offline` and `windows-offline` success. (Grok fallback was still
  finishing when the checklist was written.)
- Child 2 / P5: leaf PR **#1231** (closed) run **`37004653826`** —
  `bin/ai-gemini-usage` comment-only; shard 2 `selected=1 of 113`,
  `test-ai-gemini-usage.sh (1 of 1)`; other shards `selected=0`.
  Complete backstop **`37004696131`** (`workflow_dispatch` on main) —
  `every Bash suite`, shard 1 `selected=27 of 113`, `tests=27 failures=0`;
  `linux-offline` success.

**Parent #1183:**

- Children 1 and 2 ticked with evidence. Live-proof items for child 1 and
  child 2 (P3/P5) ticked.
- Comment posted: `next: child 3`.
- Children **3–5 still `[ ]`** — take them one per session, in order.

**Not merged (intentionally):** branches `mimo/1183-p3-fast-fail-proof` and
`mimo/1183-p5-leaf-selection-proof` (proof PRs #1226/#1231 closed). Keep or
delete after the run IDs are no longer needed; they are not required for main.

## 4. Everything we tried that did NOT work

- **First P3 invalid candidate was not a parse error.** `if [ true` / `then`
  is a *runtime* failure of `[`, not a `bash -n` syntax error. `fast-classifier
  / validate` **passed** and long jobs started (run `37002917819`, later
  cancelled). Fix: use a real parse error (unclosed quote). Always verify with
  `bash -n` locally before pushing a "invalid" candidate.
- **P3 successor attempt `37003948662` died on an unrelated flake** in
  `test-ai-memory-sync.sh` (`FAIL: private hub proof altered the repository`).
  Not caused by the probe file. Cancelled and retried as `37007389909`, which
  was green on Linux and Windows offline lanes.
- **PowerShell + `bash -lc` + nested quotes** repeatedly broke one-liners
  (Python `-c`, `jq` filters, `echo EXIT:$?`). Write a temp script file and run
  it; delete before commit. `$?` in a PowerShell-expanded string becomes
  `True`/`False`, not an exit code.
- **Long `ai-pr-wait` / sleep loops get ChildProcess.kill from the desktop tool
  (≈10 min).** Use short bounded checks; leave the PR as the card if still
  running. `AI_GH_NO_WAIT=1` makes `ai-gh` fail fast when another call holds
  the throttle lock — useful for status polls, not for merge.
- **`bin/ai-gh issue list --label …` can return `[]` with no output** when
  nothing matches; that is empty, not an error.
- **`gh pr view` JSON field `isInMergeQueue` does not exist** in this gh
  version; use `state` / `mergeStateStatus` / `autoMergeRequest`.

## 5. Root causes and key findings

- Capacity timeout/kill/rate-limit must not be diagnosed as broken code; the
  reporter labels them `capacity/infra` (child 1, proved on #988).
- P6 split is real parallelism on separate hosted machines. Preferred remains
  serial on one host. Per-suite fallback avoids re-running a suite the
  preferred host already proved.
- Fast-fail (P3) is `validation_result == failure` stopping every expensive
  job; `verification-closure` must still fail closed (run `37003387555`).
- PR selection (P5) is conservative: leaf `bin/ai-gemini-usage` → only
  `test-ai-gemini-usage.sh` (1 of 113). Unknown/shared paths still select
  everything. Manual/schedule runs stay complete (`37004696131`).
- Merge-queue evidence job names must match the workflow. After the P6 rename,
  `equivalent_fallback_proven` requires **both**
  `windows-reviewer-fallback-codex` and `windows-reviewer-fallback-grok`.

## 6. Exact next steps

1. Open **#1183**. Take **child 3 only** ("Delete waiters as a class. Bounded
   in-session `ai-pr-wait` with explicit deadline only. No TTL service, no
   park-state store, no waiter registry. Required `ai-blocker-watch wait`
   registration is OUT. Turn-end state on the issue, re-surfaced by bounded
   janitor. Owner: #511 + #1061 residual."). Do not start 4–5 in the same
   session.
2. Work in a fresh worktree from current `origin/main` (canonical checkout is
   landing-only). `ai-task-gates start --class …` before edits.
3. Implement child 3 with branch + PR + merge queue. If the change set touches
   `bin/ai-pr-wait` or another reviewer-safety path (see
   `.ai-devops/task-gates.json`), declare `--class reviewer-safety` and get
   exact-head independent review (`ai-review <provider> final-check
   --implementer mimo`).
4. Tick child 3 on #1183, comment `next: child 4`, stop.
5. Do not open a new `plan_*.md`. Map rows to #650 / #658 / #1061 / #511.

You'll know it worked when: child 3 is ticked with landed commit SHA, CI green
through `verification-closure`, and the parent comment names child 4.

## 7. Constraints and gotchas in force

- Live proof before close. Exact-head independent review for reviewer-safety
  paths. No path filters on required checks. `verification-closure` + merge
  queue stay. #401 and #204 stay closed. Leftover-proof mill stays deleted.
- Required `ai-blocker-watch wait` registration is OUT (Muse-agreed).
- Windows runner slowness is infra (#209 / #262), not process. Never raise CI
  ceilings to hide capacity.
- Mixed capacity+result incidents label **result**.
- Janitor bounds: 6h per-PR cooldown, comments only, never opens issues, no
  comment after human activity in 24h, kill switch on #1061 lineage.
- Public repo: never commit raw transcript text, secrets, or private paths.
- `bin/ai-gh` for GitHub. Times in EST/EDT, named.
- Canonical checkout is landing-only. Use worktrees. Never touch another
  session's `HANDOFF.d/` file.

## 8. Access and environment

- Machine: **edge-dev** (Windows). Git Bash at
  `C:\Program Files\Git\bin\bash.exe`. `$env:MIMO_PYTHON` for Python.
- Session worktrees (remove only when clean and merged/abandoned):
  - `C:\repos\ai-devops-wt-1183-c2-mergepath` — branch
    `mimo/1183-c2-merge-critical-path` (**merged** as `5c61060e`; safe to
    delete after confirming `origin/main` contains it).
  - `C:\repos\ai-devops-wt-1183-p3-proof` — branch
    `mimo/1183-p3-fast-fail-proof` (**not merged**; proof only, PR #1226 closed).
  - `C:\repos\ai-devops-wt-1183-p5-proof` — branch
    `mimo/1183-p5-leaf-selection-proof` (**not merged**; proof only, PR #1231
    closed).
- Labels `capacity/infra` and `result` exist. Issue #988 is the live labeled
  incident.
- Secrets: 1Password vault `vibe_coding` only. No new credentials this session.

## 9. Open questions and risks

- P3 positive run `37007389909` had `windows-reviewer-fallback-grok` still in
  progress when the checklist was written; `linux-offline` and `windows-offline`
  were already success. If a later audit needs `verification-closure` green on
  that run, finish watching it or re-run. The routing outcome (invalid stops
  long jobs / valid runs them) is already proved by both run IDs.
- `test-ai-memory-sync.sh` ("private hub proof altered the repository") flaked
  on `37003948662`. Treat as a separate reliability item if it recurs; do not
  fold it into child 3.
- `warpbuild-win2022-canary` jobs can sit queued and hold a workflow
  `status=queued` even after required checks are done. Do not read that as
  "stuck forever"; check named job conclusions.
- Open shared-db orchestrator-marker **#3865** (`mimo-orch-queue-resume`) is
  **another session's** work — do not claim or close it from #1183 work.

## Mandatory self-audit gate

- [x] Sections 0–9 present
- [x] Next steps actionable cold (#1183 child 3 named with gates)
- [x] Failures in §4 include what was tried and why it failed
- [x] Constraints match AGENTS.md / agreed plan
- [x] No secrets, tokens, or raw private transcript text
- [x] Owner-only decisions called out (none open; settled list included)
- [x] A stranger can pick up child 3 from this file alone

### Self-audit answers (handoff-writer)

1. **Comprehensive for a brand-new developer?** Yes — §1 app, §2 goal, §3
   landed SHAs/run IDs, §6 exact next step with success gate, §8 worktrees.
2. **Detailed enough to continue as well as this session?** Yes — §4 dead ends
   (non-parse "syntax error", memory-sync flake, PowerShell quoting, tool
   kill), §5 findings, §3 evidence IDs.
3. **Every relevant detail included?** Yes — background/goals/state/failures/
   decisions/constraints/risks/next actions/verification evidence are each in
   a named section.
4. **Owner sees every decision from §0 alone?** Yes — §0 says none blocking and
   lists already-settled rulings so they are not re-asked; nothing in §1–§9
   requires a new owner judgement (shared-db marker #3865 is another session's).
