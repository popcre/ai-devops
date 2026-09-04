---
issue: 261
status: OPEN
owner: codex/gemini-38-activation
---

# HANDOFF — Gemini 3.8 reviewer activation closeout (2026-09-04 16:13Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream currently needs Albert's decision. The next
session should not pause to ask permission for the ordered work below.

Already settled — do NOT re-ask:

- 2026-09-03: finish Gemini 3.8 Flash activation, not merely live qualification.
- 2026-09-03: never cancel, restart, supersede, or interrupt active Windows work.
- 2026-09-04: the no-competition rule is per host. An idle EDGE-DEV may run local
  work while EDGE-RUNN-ENVY or GitHub-hosted Windows is busy, provided EDGE-DEV is
  checked immediately before the work and remains unassigned.
- 2026-09-04: Qwen may remain quarantined under issue #259 and must not block
  Gemini activation.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public, restorable toolkit for governed AI
reviewers. It supplies read-only reviewer wrappers, safety tests, installation
scripts, model routing, evidence packets, and offline verification. Installation
onto a host is deployment; there is no web application. This work activates the
exact Antigravity model `gemini-3.8-flash-high` through `bin/ai-gemini` as a
governed read-only reviewer.

The local continuation checkout is
`C:\Users\ahazan\.codex\worktrees\gemini-38-release\ai-devops`. The shared
checkout `C:\repos\ai-devops` contains unrelated concurrent Muse and Grok edits
and must not be cleaned, reset, staged, or used for this work.

## 2. What we set out to do this session, and why

Issue #261 requires Gemini 3.8 Flash to become genuinely operational: current
source reconciled with `main`, complete tests, independent exact-head approval,
protected PR/merge, installation, `available` status, and one real read-only
review with unchanged source. The session resumed from local commit `bc88f505`
and the earlier handoff
`HANDOFF.d/2026-09-04T0211Z-edge-dev-codex-gemini-38-activation.md`.

## 3. Current state — what is true right now

- The isolated checkout is clean on branch `codex/gemini-38-activation` at
  `bc88f5056b1e4492203c6cb6cf0bb0cbe319348c`. Nothing from this branch is pushed;
  no PR exists.
- Current `origin/main` is
  `8716d7da17d55c766e6948bf0aeae9287352940d`, 22 commits ahead and six commits
  behind by raw ancestry. Cherry comparison showed only three locally unique
  commits: `bc88f505` (old handoff), `93fd96fc` (Gemini plan corrections), and
  `8fda7fca` (older Qwen installer work). Related Gemini/Qwen preparation has
  otherwise landed independently on `main`; rebase and inspect the actual diff.
- Issue #246 landed as `e41666ab`; current policy protects manual Windows runs.
  Issue #267 landed as `8716d7da` and clarifies local/CI work is per-host.
- Focused verification passed: Gemini 62/62, shared preflight 51/51, sandbox
  80/80, packet 92/92, Qwen 92/92, and the Windows provider-installer check.
- One complete Bash gate ran for 6,461 seconds. It completed all 53 Bash suites,
  but `test-ai-grok-review.sh` failed four concurrency/timing assertions after a
  604-second stall; summary: `BASH SUITE ... failed=1`. The failing Grok/Muse
  source belongs to other sessions in the shared checkout, not this branch. Do
  not rerun the unchanged full gate until current `main` and those repairs are
  reconciled. Full PowerShell verification was not run.
- Gemini previously reported `available` with `agy` 1.1.25 and wrapper SHA-256
  `dac5862e5f12b75ff3f8b00075c339e404b62db8b55441012d2fcde6f3ca1f9e`.
  Antigravity has since upgraded to 1.1.26 with runtime SHA-256
  `17a09d8c8b5a0bc3cc36904deed78126a56d5c47ccf28186743acb848f5f780d`.
  `bin/ai-gemini doctor` and preflight now truthfully report `QUARANTINED` /
  `live-qualification-required`. The old paid qualification cannot be reused.
- Git identity is correct: `Albert Hazan <u2giants@users.noreply.github.com>`.
- At 16:13Z, no GitHub Actions run was active. Re-check rather than relying on
  this snapshot.
- Issue #261 is OPEN. Qwen remains quarantined under issue #259. No installation,
  final real Gemini review, issue update, handoff retirement, or closure exists.

## 4. Everything we tried that did NOT work

1. The session initially treated any active Windows job as a global prohibition.
   Albert corrected this: the boundary is per host. EDGE-DEV can work while ENVY
   or hosted Windows is busy if EDGE-DEV itself is idle and unassigned.
2. A complete local Bash gate was started after EDGE-DEV was confirmed idle. It
   took almost two hours because reviewer suites deliberately exercise long
   timeout/interruption/concurrency cases. Grok alone took 2,595 seconds and
   failed four timing assertions after extreme stalls. The full run therefore
   does not satisfy release acceptance and must not be repeated unchanged.
3. Continuing that already-failed full suite consumed EDGE-DEV resources while
   other sessions were repairing Muse and Grok in the shared checkout. It was
   stopped/reaped at closeout after the complete Bash summary had been emitted;
   no GitHub runner job was cancelled.
4. The earlier Gemini qualification cannot authorize the current runtime. The
   model and wrapper remained exact, but `agy` changed from 1.1.25 to 1.1.26, so
   the hash-bound gate correctly returned Gemini to quarantine.
5. The earlier branch was once current with `main`, but `main` moved by 22
   commits during this session. Any review, test, or branch comparison made
   before a new rebase is stale for landing.

## 5. Root causes and key findings

- Qualification is bound to wrapper bytes, exact model, CLI version, and CLI
  bytes. A provider runtime upgrade correctly invalidates prior proof even when
  the model name is unchanged; current evidence is from `bin/ai-gemini doctor`.
- Local-suite safety is host-specific, not pool-wide. Check the repository runner
  API for `edge-dev-win` and confirm no local `Runner.Worker` before local work.
- The shared checkout's modifications to `bin/ai-muse` and
  `bin/ai-grok-review` are not part of issue #261. This session only read their
  status; it did not open, edit, stage, or commit those changes.
- A focused green Gemini gate is necessary but not sufficient. The deliverable
  still requires current-main full gates, exact-head independent approval,
  protected merge, installation, current runtime qualification, availability,
  and a real governed review.
- `main` now contains the protected Windows-dispatch repair and per-host wording,
  resolving the workflow-policy concern raised by the earlier independent review.

## 6. Exact next steps

1. Start in the isolated checkout above. Read this file, the earlier `T0211Z`
   Gemini handoff, current `AGENTS.md`, `docs/deployment.md`, and the STATUS tables
   in both Gemini plans. Fetch `origin` and inspect status/diff without touching
   the shared checkout. You will know it worked when the isolated checkout is
   clean and the exact current `origin/main` SHA is recorded.
2. Inspect every active GitHub run job-by-job and the three runner records. Apply
   the per-host rule: do not compete on EDGE-DEV if `edge-dev-win` is busy or a
   local `Runner.Worker` exists; do not cancel or restart any job anywhere. You
   will know it worked when EDGE-DEV is proven idle immediately before local work.
3. Rebase `codex/gemini-38-activation` onto current `origin/main`. Resolve only
   issue #261 conflicts. Compare with `git diff origin/main...HEAD` and drop
   commits/hunks already superseded on `main`, especially older Qwen work, while
   preserving Qwen quarantine. You will know it worked when the branch is clean
   and contains only still-needed Gemini activation/docs/closeout changes.
4. Recompute `bin/ai-gemini` SHA and run non-live doctor/preflight. Because `agy`
   is now 1.1.26, expect quarantine. Do not manually edit qualification state.
   You will know it worked when the reason is exact runtime identity drift rather
   than an ambiguous failure.
5. Run focused Gemini, preflight, sandbox, packet, installer, and any actually
   touched Qwen tests quietly. Then run the repository-required complete Bash and
   PowerShell gates against the reconciled head. Do not rerun the old failing
   commit unchanged; current-main reconciliation is the required change. You will
   know it worked when both complete summaries exit zero with no failed suite.
6. On idle EDGE-DEV, run exactly one governed Gemini live qualification for
   `gemini-3.8-flash-high` through the wrapper/preflight path, never `agy` directly.
   Require exact model, resume, containment, unchanged sentinels, durable report,
   and the 1.1.26 identity. You will know it worked when preflight reports
   `available` and the current record matches wrapper/runtime/model hashes.
7. Run `ai-codex-review final-check` against the exact clean branch head. Ensure
   its report names the current SHA and ends `APPROVE`. Repair actionable findings
   and repeat affected tests; if code changes, run one final complete gate. You
   will know it worked when exact-head approval is durable and current.
8. Immediately re-check active Windows jobs. Verify Git identity, stage only
   issue #261 files, push the feature branch once, open the protected PR, and use
   the merge queue. Never cancel existing work to make room. You will know it
   worked when the PR is merged with required exact-head checks green and no
   pre-existing Windows job was interrupted.
9. From verified `main`, install the toolkit on each intended Gemini reviewer
   host only while that host is idle, following `docs/deployment.md`. Confirm
   installed wrapper/runtime hashes and `ai-review-preflight status gemini`.
   You will know it worked when each supported installed host reports `available`
   with its own valid current identity; leave an unqualified host quarantined.
10. Run one governed read-only Gemini review on a harmless public target. Capture
    the exact model, durable verdict/report, and before/after source hashes. You
    will know it worked when the review succeeds and source is unchanged.
11. Update issue #261 with commit, PR, CI, installation, qualification, and real
    review evidence. Remove Gemini's no-new-work restriction, retire both Gemini
    handoffs only after every obligation is carried into durable records, remove
    the `resume-reviewer-3-8-safely` heartbeat if it still exists, and close #261.
    You will know it worked when Gemini can receive assignments, Qwen remains
    quarantined if #259 is unresolved, issue #261 is closed, and no Gemini
    continuation handoff or stale automation remains.

## 7. Constraints and gotchas in force

- Do not cancel, restart, supersede, or interrupt any active Windows job.
- Local concurrency is per host: an idle EDGE-DEV may work while another host is
  busy, but re-check immediately before suites, push, merge, install, or live use.
- Never bypass Gemini quarantine or call `agy` directly.
- Never weaken safety assertions or raise timeouts to obtain green output.
- Do not rerun a deterministic failure without a relevant source/test/diagnostic
  change. The old complete gate is stale after the required rebase.
- Preserve the shared checkout and its Muse/Grok changes. Work only in the
  isolated checkout until reconciliation and shipping are complete.
- Qwen is a separate issue. Do not rerun paid Qwen qualification or claim it is
  active; issue #259 owns its blocker.
- Exact-head review becomes stale after any relevant source change.
- Use the protected PR/merge queue despite older repo wording that says direct
  `main`; live rules and the issue #261 handoff govern this safety-path change.
- Do not expose provider output, credentials, session contents, or private paths
  beyond the non-secret paths already documented here.

## 8. Access and environment

- Host: `EDGE-DEV`; PowerShell shell; Git Bash at
  `C:\Program Files\Git\bin\bash.exe`.
- Isolated checkout and branch are in §1 and §3.
- GitHub CLI is authenticated for `popcre/ai-devops`; issue #261 is
  `https://github.com/popcre/ai-devops/issues/261`.
- Antigravity authentication exists on EDGE-DEV. Current CLI identity is in §3.
- Secrets, if needed, belong only in 1Password vault `vibe_coding`; never place
  values in commands, logs, chat, commits, or the public issue.
- The shared checkout is dirty with unrelated work and is not the release
  location. The private Gemini worktree is the only continuation location.

## 9. Open questions and risks

- No owner question is open. Runtime requalification is evidence-driven and
  already authorized by the goal.
- `origin/main` can move again. Rebase before testing/review and re-check before
  pushing; never carry stale exact-head evidence across a changed head.
- Antigravity may change again after qualification. If its version or bytes move,
  quarantine is correct and the new exact identity needs one fresh governed gate.
- Current Muse/Grok repairs may change the full-suite outcome. Reconcile only
  landed `main`; never take uncommitted shared-checkout bytes into Gemini work.
- Installation is per host. Do not infer fleet-wide availability from EDGE-DEV.
- The heartbeat automation was reported active in the earlier handoff but was
  not re-verified in this closeout; the successor must inspect and retire it only
  after completion.

## Mandatory self-audit

1. Yes. Sections 1–3 define the product, exact checkout/branch/SHAs, live state,
   tests, qualification invalidation, and every unfinished deliverable, so a new
   developer can begin without chat context.
2. Yes. Sections 4–5 preserve the global-vs-per-host correction, two-hour Grok
   failure, shared-checkout ownership, runtime drift, and stale-base discovery,
   giving the successor the same non-obvious knowledge available now.
3. Yes. Sections 1–9 cover background, goal, intended outcome, exact state,
   failures, findings, ordered actions with success gates, constraints, access,
   and risks. Secrets are referenced only by vault name.
4. Yes. A line-by-line sweep of §§1–9 found no new decision requiring Albert.
   Every owner-set instruction is consolidated in §0 under “Already settled,”
   and the remaining uncertainties are evidence-driven worker actions.
