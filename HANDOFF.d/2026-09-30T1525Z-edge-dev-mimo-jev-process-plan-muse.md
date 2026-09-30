---
handoff: v1
status: open
owner: mimo/jev-ci-ratelimit-muse-plan
created: 2026-09-30T15:25:00Z
machine: edge-dev
agent: mimo
session: ses_ffe5f0ffd2db9ffe6HH0V6Goyl
issue: 1183
---

# Handoff — Jev CI/rate-limit study, process plan, Muse-agreed five changes

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None open on this workstream. Albert already approved the direction (less process,
cut rules, daily merge tax first). Do not re-ask him to pick technical work.
If a child of #1183 needs a spend or capacity purchase (new runner, second host),
that is an owner decision — name it, do not decide it.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow (reviewers, CI, GitHub traffic tools). It is not a product app.
Installation is the deployment mechanism.

## 2. What we set out to do this session, and why

Albert asked to:
1. Use Jev (TypeSafe, key via 1Password) to identify transcripts from the last
   two weeks in `C:\Users\ahazan\Dropbox\ai\chat_transcripts` that are NOT about
   CI failures and GitHub rate-limiting (confidence > 90%), disregard those, and
   deep-read the remainder into a comprehensive report of what is going wrong
   and why. Ship that report to GitHub.
2. Produce a process-bottlenecks / improvements decision document (what we are
   doing wrong, bottlenecks, unnecessary process, how to stop sessions waiting
   on CI).
3. Have Muse audit that plan and debate until both sides agree on the best plan.
4. Confirm the agreed changes are children under one parent issue.
5. Wrap up.

## 3. Current state — what is true right now

**Shipped and on `origin/main`:**
- `docs/ci-failures-and-github-rate-limit-report-2026-09-29.md` — PR #1148,
  merge commit `deb9a3e8`. Nine failure-mode clusters, paraphrased proof.
- `docs/process-bottlenecks-and-improvements-2026-09-29.md` — PR #1173
  (`12f0c8d6`) then Muse-agreed §2b via PR #1182 (`21611289`).
- Parent issue **#1183** — five children, agreed order, binding constraints.
  This is the card for all remaining work. Take first unticked child only.

**Muse audit (session `process-plan-audit-20260930`, engine muse-code):**
- Four turns: BLOCKED (missing files) → ACCEPT WITH CHANGES → COUNTER on one
  carve-out → AGREE.
- Single disagreement resolved: required `ai-blocker-watch wait` registration is
  OUT as a standing rule (owner-reported non-adoption; locked deletion under
  #1061). Voluntary use unrequired. Re-admit only on 14-day measured wake evidence.
- Reorder accepted: daily merge tax leads; coord-deletion residuals trail.

**Measurement facts (edge-dev local `~/.ai-devops/gh-throttle/`):**
- Jev: 949 unique digests (2026-09-15..29), 640 disregarded at topic_p < 0.10
  (>90% confidence non-match), 309 remainder. 39 priority sessions deep-read.
- GitHub rate-limit refusals: last at 2026-09-28T16:59:49Z. Zero after stagger
  (PR #999) + `pop-ai-watchers` app (PR #1006). Quota wall is NOT the active pain.
- #1001/#1002 are CLOSED and did not undo stagger/app. App helped enough; do not
  add another GitHub App first.

**Parent #1183 children (unticked as of this handoff):**
1. Label capacity vs result; empty verdict fails review step (owner #650 P7)
2. Parallelize merge path + fast-fail P3/P5/P6 (owner #650)
3. Delete waiters as a class; BlockerWatch registration out as rule (owner #511 / #1061 residual)
4. Coord-deletion residuals one-time in existing slice (owner #1061 residual)
5. O(1) preflight, pin-only qual, doc table, two wrapper fixes (owner #650 P6/P8)

## 4. Everything we tried that did NOT work

- First `ai-muse new` hit a harness `ChildProcess.kill` after the turn actually
  completed — session existed; used `ai-muse ask` thereafter. Always redirect
  Muse output to a log file and treat a 10-minute tool timeout as "check the log".
- Muse first turn was BLOCKED: review sandbox had no plan docs. Copied target
  markdown into the sandbox workspace root + `docs/`, then continued. Do not
  expect the evidence packet to contain arbitrary repo docs.
- PowerShell wrapping `bash -c` mangles loops and `python -c` quoting. Use one
  command per call, or write a script file and run it.
- PR #1181 (same doc change) hit merge conflicts after main moved; superseded by
  fresh branch `mimo/muse-agreed-plan-20260930` → PR #1182. #1181 is CLOSED.

## 5. Root causes and key findings

See the two shipped reports. Highest-signal:
- CI "failures" are often timeout/kill/capacity, not broken code.
- Secondary GitHub rate limits came from synchronized watcher ticks, not empty quota.
- Process minted more work than it closed (leftover-proof ticket mill — now deleted).
- Waiters outlived their targets; required BlockerWatch registration never adopted.
- Maintenance (preflight sweeps, full re-qual) sat in the hot path of every review.

## 6. Exact next steps

1. Open **#1183**. Take child **1** only (label capacity vs result / empty-verdict
   reroute under #650 P7). Do not start 2–5 in the same session.
2. Implement with branch + PR + merge queue. Prose-only changes may admin-merge;
   code changes take normal checks and independent review if they touch reviewer
   safety paths.
3. Tick child 1 on #1183, comment `next: child 2`, stop.
4. Later sessions walk children 2–5 the same way.
5. Do not open a new `plan_*.md`. Map every row to #650 / #658 / #1061 / #511.

## 7. Constraints and gotchas in force

- Live proof before close. Exact-head independent review for reviewer-safety paths.
- No path filters on required checks. `verification-closure` + merge queue stay.
- #401 and #204 stay closed. Leftover-proof mill stays deleted. No orchestrator
  return.
- Required `ai-blocker-watch wait` registration is OUT (agreed with Muse).
- Windows runner slowness is infra (#209 / #262), not process. Never raise CI
  ceilings to hide capacity.
- Janitor bounds: 6h per-PR cooldown, comments only, never opens issues, no
  comment after human activity in 24h, kill switch on #1061 lineage.
- Public repo: never commit raw transcript text, secrets, or private paths.
  Jev digests and private notes stay in `%TEMP%` / private stores.
- `bin/ai-gh` for GitHub. Times in EST/EDT, named.
- Canonical checkout is landing-only. Use worktrees. Never touch another
  session's `HANDOFF.d/` file.

## 8. Access and environment

- Machine: edge-dev (Windows). Git Bash for bash tools. `$env:MIMO_PYTHON` for Python.
- TypeSafe key: `op://vibe_coding/typesafe.ai API/credential` via 1Password
  `op_run` only — never argv, chat, or git.
- Muse: `AI_MUSE_CALLER=mimo bin/ai-muse …` from repo root. Session
  `process-plan-audit-20260930` is the audit conversation (reuse, do not recreate).
- Private transcript root (read-only): `C:\Users\ahazan\Dropbox\ai\chat_transcripts`.
- Session worktree (may be removed after cleanup): `C:\repos\ai-devops-wt-ci-ratelimit-report-20260929`.
- Private notes (do not commit): `%TEMP%\jev_*.jsonl`,
  `%TEMP%\jev_ci_ratelimit_private_notes.md`,
  `%TEMP%\jev_process_improvements_private_notes.md`.
- Muse audit reports: `C:\repos\ai-devops\.ai\reviews\muse-process-plan-audit-20260930-*.md`.

## 9. Open questions and risks

- Coord-deletion residuals (child 4) need a live owner inside the #1061 residual
  slice; parent #1061 is CLOSED — confirm the residual owner before starting.
- Issues #1001/#1002 were finished; another session was to close them out —
  verify they are closed before treating that thread as done.
- GitHub App `pop-ai-watchers` write permissions (statuses/PRs) may still need
  UI acceptance — see `HANDOFF.d/2026-09-28T2218Z-edge-dev-mimo-pop-ai-watchers-write-permissions.md`.
- Selection bias: Jev remainder overweights CI/rate-limit talk; frequencies are
  in-corpus only.
- Do not add another GitHub App until a measured quota wall returns.

## Mandatory self-audit gate

- [x] Sections 0–9 present
- [x] Next steps are actionable cold (issue #1183 + child 1 named)
- [x] Failures in §4 include what was tried and why it failed
- [x] Constraints match AGENTS.md / agreed plan (no path filters, live proof, no new plan_*.md)
- [x] No secrets, tokens, or raw private transcript text in this file
- [x] Owner-only decisions called out (none open; capacity spend would be one)
- [x] Someone who has never seen this chat can pick up #1183 child 1 from this file alone
