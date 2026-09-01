---
issue: 161
status: OPEN
owner: codex/issue-161-fast-ci
---

# HANDOFF — issue #161 CI timeout and completion

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream currently needs Albert. The next session must
continue the authorized diagnosis, repair, verification, exact-head review,
merge, evidence update, and issue closure without asking for permission again.

Already settled — do not re-ask:

- Never rerun the same failing 75-minute Windows command unchanged. A rerun must
  follow a specific repair or added diagnostic evidence.
- Preserve all 61 Bash and 17 PowerShell suites and every paid-reviewer safety
  assertion. Do not hide a failure, weaken coverage, or merely inflate a timeout.
- Issue #161 owns the fast classifier, coarse prose routing, complete suite
  manifest, and pre-#209 physical-host serialization. Issue #209 owns qualified
  independent Windows hosts; #210 owns later measured sharding.
- Required-check cutover is issue #166 and remains the last phase.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public restore and operations toolkit for
Albert's multi-model AI workflow. It contains Bash and PowerShell commands,
reviewer safety wrappers, machine setup, skills, prompts, and offline tests.
GitHub is the source of truth; installation is deployment. There is no hosted
application or application database.

Work is in the Windows worktree
`C:\Users\ahazan\.codex\worktrees\0bda\ai-devops` on branch
`codex/issue-161-fast-ci`. Pull request #213 is
<https://github.com/popcre/ai-devops/pull/213>.

## 2. What we set out to do this session, and why

Parent issue #159 repairs a repository operating model in which concurrent AI
sessions can spend hours rerunning or waiting without shipping. Issue #161 must
provide an always-reporting hosted-Ubuntu classifier, let only a narrow
prose-only allowlist skip the long matrix, preserve full code/skills/manual/
scheduled coverage, prove the exact 61+17 suite inventory, and serialize work on
the shared EDGE-DEV physical host until #209 qualifies independent hosts.

The prior handoff
`HANDOFF.d/2026-09-01T1709Z-edge-dev-codex-issue-161-fast-ci.md` describes the
starting state. This file records the implementation and the new blocking
evidence discovered after that handoff.

## 3. Current state — what is true right now

- Branch head is `fff13585a82ad67b71f4b03b8bdc8573d0fb4301`, pushed to PR
  #213. The worktree was clean before this handoff was added. Current
  `origin/main` observed at cutover was
  `30e1b0cad4d624f9f32d22636a3fd60769ca5dfe`; re-fetch before any rebase,
  review, or merge because main is moving.
- PR #213 is OPEN and `UNSTABLE`. Exact run `33541520697` proved:
  `fast-classifier / classify` passed in 7 seconds; `linux-offline` passed in
  9m39s; `windows-reviewer-safety` passed in about 25m41s; `windows-offline`
  failed after about 75m26s. The exact failing job is `99972563663`.
- The failure was the new guard, not a named suite assertion:
  `Serialized EDGE-DEV command exceeded its execution limit.` The wrapper
  terminated the owned process tree and returned exit 1. Therefore full Windows
  acceptance is absent; do not merge or call #161 complete.
- `.github/workflows/fast-classifier.yml` is the separate reusable hosted-Ubuntu
  classifier. `.github/workflows/verify.yml:24-29` calls it and routes long jobs
  fail-closed. `.github/workflows/verify.yml:75` currently gives the complete
  Windows body 75 minutes; this is the immediate diagnosis point.
- `tools/ci/classify-changes.sh` implements the narrow prose allowlist and coarse
  categories. It treats non-PR events as full verification and uses both sides
  of renames so a skills-to-docs rename cannot bypass checks.
- `config/ci-suite-manifest.json` and `tests/test-workflow-policy.sh:50-56`
  account for exactly 61 Bash and 17 PowerShell suites with no omissions or
  duplicates.
- `tools/ci/edge-dev-serialization.ps1:6-67` uses a machine-global named mutex,
  a 90-minute wait bound, an owned child process, a body bound, descendant-tree
  termination with `taskkill /T`, and waits for termination before releasing the
  mutex. `tests/fixtures/ci/test-edge-dev-serialization.ps1` behaviorally proves
  serialization, wait timeout, execution timeout, descendant kill, and
  reacquisition.
- Focused local policy, YAML, Bash syntax, manifest, classifier, and PowerShell
  mutex tests passed before push. This is supporting evidence only; the red
  exact-head Windows job controls acceptance.
- Multiple read-only exact-head reviews found and drove fixes for rename bypass,
  lossy concurrency, scheduled failure reporting, timeout envelopes,
  descendant cleanup, classifier failure routing, and cross-platform policy
  tests. No final APPROVE exists for the present completion state; obtain a new
  exact-head final review after the CI fix.
- Related runner PR #214 is
  <https://github.com/popcre/ai-devops/pull/214>, currently at head
  `fa46a1f336f8c34182ff7201742a141cde9c6a54`. At cutover its Linux check had
  passed, qualification was running, and Windows jobs were queued. Its earlier
  EDGE-RUNN-ENVY run exposed five Grok concurrency failures under realistic
  load. Do not add that machine to `edge-dev` routing before #209 proves full
  qualification.
- No application deployment occurred. No secrets were read or changed.

## 4. Everything we tried that did NOT work

1. The first PR run accidentally routed Windows work to the still-unqualified
   #209 machine EDGE-RUNN-ENVY because it briefly carried the `edge-dev` label.
   It lacked `pwsh`, so both jobs failed before testing. The #209 owner removed
   the label; do not treat that attempt as product evidence.
2. After PowerShell was installed on EDGE-RUNN-ENVY, restoring the label early
   was rejected because dependency parity and reviewer behavior were not yet
   proven. PR #214 remains the owner of qualification.
3. Rerunning PR #213 unchanged after removing the premature runner label did
   produce useful exact-head evidence, but the complete Windows body exceeded
   the new 75-minute bound. A third unchanged rerun would only repeat the same
   failure and is prohibited.
4. Simply raising or deleting the 75-minute body limit is not yet justified.
   Historical full Windows runtime was about 64 minutes, but the current run
   exceeded 75. First identify whether serialization/process launch added time,
   whether a suite was still making healthy progress, or whether a suite hung.
5. A prior local full sweep cannot substitute for GitHub proof: EDGE-DEV hosts
   either CI or a local series, never both, because shared process names allow
   one to cancel or inflate the other.
6. The earlier idea of parallel Windows sections is deliberately not a #161
   shortcut. It belongs to #210 after #161's manifest, #162's timings, and
   #209's independent hosts exist.

## 5. Root causes and key findings

- The safety wrapper worked exactly as coded: at 75 minutes it killed the owned
  child tree before releasing the host mutex. That proves cleanup, not suite
  success.
- The job log emitted buffered suite output immediately before the timeout, but
  the current aggregate command does not record per-suite elapsed time or a
  durable progress marker precise enough to identify the consumer. The next
  change needs evidence, not another aggregate rerun.
- The complete Windows job runs `tests/test-all.ps1`, which includes Bash plus
  PowerShell and historically repeats Linux work. #162 owns evidence-based
  duplicate removal; do not silently narrow it inside #161.
- #210's approved design is to balance explicit Windows-required sections only
  across qualified independent hosts, with no section p90 above 20 minutes
  absent a named exception. It cannot be used until #209 and #162 prerequisites
  land.
- PR #214's five Grok failures on EDGE-RUNN-ENVY indicate runner qualification
  and realistic-load reviewer behavior are still active evidence questions.
  They reinforce the rule that a machine passing security/dependency setup is
  not automatically safe CI capacity.

## 6. Exact next steps

1. Refresh `origin/main`, PR #213, PR #214, issues #161/#209/#210, active
   handoffs, and live runner labels before editing. Coordinate with the #209
   owner; do not claim or modify their work. **Gate:** exact heads, job states,
   runner ownership, and dependencies are recorded and non-conflicting.
2. Download job `99972563663` from run `33541520697` and reconstruct the last
   completed suite/progress point. Inspect `tests/test-all.ps1`, its Bash child,
   and existing summary/progress output. Add the smallest task-owned timing or
   progress instrumentation needed to name the slow or hung segment without
   weakening assertions. **Gate:** a future timeout identifies the active suite
   and elapsed time instead of only reporting the aggregate cutoff.
3. Decide from evidence whether the 75-minute body bound is below healthy
   current runtime or caught a hang. If healthy progress genuinely requires a
   different bound, document measured rationale and preserve a finite fail-
   closed limit. If one suite stalled, repair the wait/readiness cause rather
   than increasing the limit. **Gate:** the change explains and tests the exact
   observed failure mode.
4. Rebase safely onto current main, rerun only focused local tests that do not
   contend with live EDGE-DEV CI, and push the repaired exact head. Never reset,
   clean, force-push, or broadly stage. **Gate:** focused policy, manifest,
   classifier, YAML, and mutex/progress tests pass at the pushed SHA.
5. Use `bin/ai-pr-wait 213`; do not hand-roll polling. **Gate:** classifier,
   Linux, focused Windows, and complete Windows all pass on the same exact head,
   or a named failure returns immediately for diagnosis.
6. Run `bin/ai-codex-review final-check` on that exact green head and require
   APPROVE. Any head change invalidates approval and CI evidence. **Gate:** the
   recorded review names the exact SHA and returns no blocking finding.
7. Merge PR #213 through the repository queue, verify the intended commit on
   `origin/main`, and then obtain live prose-only evidence: required classifier
   under five minutes with long jobs skipped, plus enough recorded classifier
   samples to calculate p50 and p90 under three minutes. Do not duplicate a full
   matrix for an already-proven exact tree. **Gate:** live Actions URLs and
   timings satisfy every #161 acceptance item.
8. Update `plan_repo-throughput-restructure.md` STATUS and #161 with commit,
   runs, review, classifier percentiles, docs-only proof, manifest proof, and
   serialization evidence; close #161 only when all are real. Retire this and
   the prior #161 handoff only under the handoff successor rule. **Gate:** issue
   closed, evidence on `origin/main`, and no #161 obligation exists only in a
   deleted handoff.
9. At #161 closeout, reread every downstream phase through #166 and report any
   drift. Preserve the current order: #162, #163, #210 after its prerequisites,
   #164, #167/#169/#168 by dependencies, and #166 last. Update downstream phase
   specs if this diagnosis changes their assumptions. **Gate:** reciprocal drift
   audit is recorded before starting the next independent phase.

## 7. Constraints and gotchas in force

- Repository policy is branch plus pull request; never push directly to main.
- Git identity was verified as
  `Albert Hazan <u2giants@users.noreply.github.com>` at cutover.
- Stage only task-owned files. Existing user/session changes must be preserved.
- Use `C:\Program Files\Git\bin\bash.exe` for Bash tests on Windows.
- EDGE-DEV may host CI or one local reviewer/full series, never both. Check live
  Actions before starting any long local run.
- Required contexts remain `linux-offline` and `windows-offline` until #166.
- Cancelled, queued, partial, stale-head, or timed-out CI is not acceptance.
- Never verify the same exact commit twice without a named failed check or new
  diagnostic purpose. The merge queue already tests the landing tree.
- Public repository: do not commit machine-private inventory, transcripts,
  credentials, or raw paid-provider artifacts.
- Reviewer wrappers protect paid work. Locks, uncertain-remote state, terminal
  checks, counts, and deliberate defect failures are safety capabilities.
- Use issue #209 for runner qualification and #210 for later sharding; do not
  absorb their scope to make #161 look green.

## 8. Access and environment

- Worktree: `C:\Users\ahazan\.codex\worktrees\0bda\ai-devops`
- Branch/PR: `codex/issue-161-fast-ci`, PR #213
- Shell: PowerShell 7; Git Bash at
  `C:\Program Files\Git\bin\bash.exe`
- GitHub CLI is authenticated as `u2giants` with repository/workflow access.
- Reviewer command: repository `bin/ai-codex-review final-check`; use only after
  the final exact head is ready.
- Offline tests need no secrets. Paid-provider credentials, if a later focused
  proof requires them, live in 1Password vault `vibe_coding`; reference item
  titles only and never expose values.
- No production infrastructure, application URL, or database is in scope.

## 9. Open questions and risks

- It is not yet known whether 75 minutes interrupted healthy slow progress or a
  stuck suite. Resolve from logs/instrumentation; do not guess.
- Main and PR #214 are moving. Re-fetch immediately before rebase, exact-head
  review, or merge.
- PR #214 may change runner qualification facts, but it does not remove #213's
  obligation to prove the complete Windows path.
- Adding instrumentation to shared test harness files can overlap future #162
  or #167 ownership. Keep it diagnostic and minimal, or coordinate before
  expanding scope.
- A prose-only follow-up used for live acceptance must not accidentally include
  code/configuration, or the long-matrix skip would be invalid evidence.
- The prior #161 handoff remains because its successor work is not on main and
  its obligations are not finished. The next completing session may delete both
  only after verifying all obligations are preserved and landed.

## Fresh-session start prompt

Continue issue #161 in
`C:\Users\ahazan\.codex\worktrees\0bda\ai-devops`. Read `AGENTS.md`, then
`HANDOFF.d/2026-09-01T2353Z-edge-dev-codex-issue-161-ci-timeout.md`, issue #161,
and `plan_repo-throughput-restructure.md` STATUS plus Phase B through plan-end.
Refresh PRs #213/#214 and issues #209/#210. Diagnose exact Windows job
`99972563663` from run `33541520697`; do not rerun its unchanged 75-minute
aggregate command. Add the smallest evidence-based progress/timing repair, make
PR #213 pass its complete exact-head matrix, obtain exact-head final approval,
merge, prove live prose-only/classifier timing acceptance, update plan/issue
evidence, close #161, retire eligible handoffs, and perform the downstream drift
audit through #166. Nothing currently needs Albert.

## Handoff self-audit

1. **Brand-new developer continuity: yes.** Sections 1–3 define the repository,
   goal, worktree, branch, PRs, SHAs, implementation, and exact live checks.
2. **Equivalent session knowledge: yes.** Sections 4–5 preserve every material
   failed route, the 75-minute evidence, runner qualification boundary, and why
   unchanged reruns, timeout inflation, and premature sharding are wrong.
3. **Flawless execution detail: yes.** Sections 6–9 cover ordered actions with
   gates, exact commands/identifiers, constraints, access, risks, landing proof,
   live acceptance, closeout, and every downstream phase through #166.
4. **Owner-decision sweep: yes.** Sections 1–9 were reread for `owner`,
   `approve`, `decide`, `waiting`, `ruling`, and authorization language. They
   contain no unresolved owner decision; Section 0 explicitly records that and
   consolidates every already-settled boundary.

