---
issue: 161
status: OPEN
owner: codex/issue-161-fast-ci
---

# HANDOFF — issue #161 fast change-aware CI

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in #161 currently needs Albert. Do not ask him to re-approve
ordinary branch, test, review, merge-queue, or merge work.

Already settled:

- Preserve every assertion and fail-closed capability; do not hide failures,
  inflate timeouts, or mark safety work allowed to fail.
- Required-check cutover remains issue #166 and runs last.
- Smart App Control stays Off on EDGE-DEV; durable setup is separate issue #200.
- Issue #209 owns independent Windows hosts and issue #210 owns bounded Windows
  sections. #161 owns the fast classifier, coarse routing and suite manifest.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public restore and multi-model AI workflow
toolkit. GitHub is source of truth; installation is deployment. It has no hosted
application or application database. Windows CI currently uses two GitHub runner
registrations on the same physical `EDGE-DEV` computer.

## 2. What we set out to do, and why

Parent issue #159 aims to let concurrent AI sessions finish without hour-long
verification loops. Issue #160 made reviewer safety deterministic and merged as
`08269a1`. Issue #161 now needs to provide useful required feedback in minutes,
let a narrow prose-only allowlist avoid the long matrix, and keep code, skills,
scheduled and manual coverage fail-closed.

## 3. Current state — exact live facts

- Start from current `origin/main` after the documentation closeout merge that
  adds this handoff and marks #160 done.
- #160 is closed. PR #193 merged as
  `08269a1f10ec349c55a17a5afddf9c9255b7dcc7` after a clean isolated full run:
  61 Bash suites, 17 PowerShell suites, Grok 199/199 and Kimi 207/207.
- Exact-head Codex review `20260901T163440-2838537-1161` approved commit
  `8a6533c` with no findings. The administrator bypass was used because Windows
  jobs remained queued behind structurally duplicated work; GitHub records the
  merge actor and commit.
- Issue #161's live body is authoritative and already includes the
  always-reporting classifier, no top-level `paths-ignore`, EDGE-DEV
  serialization before #209, independent hosts after #209, and the 61+17 suite
  manifest.
- Issues #209 and #210 were added during the downstream drift audit. #209 may
  proceed independently; #161 must not pretend two registrations on EDGE-DEV
  are independent capacity. #210 depends on #161's manifest, #162's timings and
  #209's hosts.
- Required contexts remain `linux-offline` and `windows-offline`; do not rename
  or repoint them before #166.

## 4. What did not work

1. Waiting for both EDGE-DEV registrations to become idle did not converge.
   New pull-request, push and merge-group jobs continuously consumed the slots.
2. A local full run started in an apparent idle window five seconds before a
   merge-group run. Both sides became invalid; the local tree was terminated by
   exact PID and neither Windows result was accepted.
3. Merge-queue regrouping repeatedly cancelled hour-long jobs. Documentation
   merges also moved the queue base and restarted speculative work.
4. Calling every delay “another session” was inaccurate. Some jobs came from
   AI branches, others from automatic `main` pushes or GitHub merge groups.
5. Smart App Control blocked runner startup; an unsigned supplemental policy was
   rejected. Turning the authorized base state Off restored both listeners.

Full evidence and corrections are in
`docs/windows-runner-interruptions-2026-09-01.md`.

## 5. Root causes and key findings

- Two logical runners on one physical host are one shared failure domain.
- The workflow creates more Windows runner-minutes than EDGE-DEV can supply;
  duplicated pull-request, `main` and merge-group events amplify the backlog.
- Required checks must always report. Top-level path exclusion can leave a
  required context pending forever.
- Coarse classification comes before per-suite selection. #161 owns an exact
  manifest first; #162/#163 use its evidence rather than inventing mappings.
- Merge groups need a short compatibility proof designed with #162/#164, not an
  automatic replay of the full pull-request matrix.
- Parallel Windows sections are unsafe until #209 qualifies independent hosts;
  #210 owns the later split and aggregate gate.

## 6. Exact next steps

1. Re-read `AGENTS.md`, issue #161, and the STATUS/Phase B sections of
   `plan_repo-throughput-restructure.md`. Verify #209/#210 state and active
   handoffs before editing. Gate: ownership and dependencies agree live.
2. Capture current workflow/job timing baselines and exact suite inventory.
   Gate: every one of 61 Bash and 17 PowerShell suites appears once in a checked
   manifest, with no omissions or duplicates.
3. Add a separate hosted-Ubuntu fast classifier that always reports under three
   minutes and emits coarse change categories. Gate: prose, skills, code,
   workflow, PowerShell and test fixtures classify as specified.
4. Route the narrow prose-only allowlist around long jobs using classifier
   output, never top-level `paths-ignore`. Gate: required context reports in
   under five minutes and no long job starts for the prose fixture.
5. Keep scheduled and manual matrices complete. Implement only the merge-group
   compatibility shape already proven with #162/#164; do not guess that design
   inside #161. Gate: policy tests prove each event's intended coverage.
6. Until #209 lands, serialize every EDGE-DEV Windows job through one shared
   job-level group with cancellation disabled. After #209, use only qualified
   independent hosts. Gate: different PRs cannot overlap on EDGE-DEV.
7. Run focused workflow-policy/manifest tests, complete relevant offline proof,
   and obtain exact-head independent review for safety-routing changes. Gate:
   all assertions pass and review returns APPROVE on the final commit.
8. Push a branch/PR, monitor with `bin/ai-pr-wait`, merge it, verify
   `origin/main`, update issue/plan evidence, and close #161 only when all live
   acceptance gates agree.
9. At #161 closeout, re-read every downstream phase through #166, including
   #209/#210, report drift, update specs, and use a fresh session if the next
   phase is independent. #166 remains last.

## 7. Constraints and gotchas

- Branch and pull request only; no direct push to `main`.
- Never run local reviewer suites while EDGE-DEV CI is active.
- Use `C:\Program Files\Git\bin\bash.exe` for Bash checks on Windows.
- Preserve check names until #166; an old required name that stops reporting can
  lock every pull request.
- Do not cancel other sessions' jobs merely to gain capacity.
- Do not treat cancelled, queued, stale or partial runs as proof.
- Public repository: preserve `all_external_contributors` approval for fork PRs.
- Stage only task-owned files; never reset, clean, force-push or broadly stage.

## 8. Access and environment

Authenticated `gh`, Git Bash, PowerShell 7 and repository reviewer wrappers are
available. Git identity must remain
`Albert Hazan <u2giants@users.noreply.github.com>`. Offline tests need no
secrets. Provider credentials remain in 1Password vault `vibe_coding`; never
print or commit them.

## 9. Open questions and risks

- #209 may be active in another session; inspect before claiming or changing its
  files. #161 can build the hosted classifier and manifest independently, but
  cannot claim parallel-host acceptance before #209 proves it.
- #162/#164 must define and prove the short merge-group compatibility gate.
  Until then, preserve complete coverage rather than guessing a reduced gate.
- Current backlog data can drift quickly; remeasure before claiming timing wins.

## Fresh-session start prompt

Open the new issue #161 worktree from current `origin/main`. Read `AGENTS.md`,
then `HANDOFF.d/2026-09-01T1709Z-edge-dev-codex-issue-161-fast-ci.md`, issue
#161, and the STATUS/Phase B sections of `plan_repo-throughput-restructure.md`.
Implement the always-required hosted-Ubuntu classifier, coarse prose routing,
61+17 suite manifest, and safe EDGE-DEV serialization without changing required
context names. Respect #209 independent-host and #210 bounded-parallel ownership;
keep #166 last. Finish with tests, exact-head review, PR/merge, live evidence,
downstream drift audit, and issue closure.

## Handoff self-audit

1. **New developer continuity: yes.** Sections 1–3 define the repository,
   completed predecessor, current GitHub state and new dependencies.
2. **Full session knowledge: yes.** Sections 4–5 preserve failed approaches,
   runner mechanics, queue amplification and corrected ownership boundaries.
3. **Flawless execution detail: yes.** Sections 6–9 give ordered gates,
   constraints, access, risks and the whole-plan reciprocal audit through #166.
4. **Owner-decision sweep: yes.** Sections 1–9 contain no unresolved owner
   choice; Section 0 says so explicitly and lists settled decisions.
