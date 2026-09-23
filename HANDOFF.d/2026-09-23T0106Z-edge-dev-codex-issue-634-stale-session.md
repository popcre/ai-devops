---
issue: 634
status: OPEN
owner: codex/issue-634-shared-db-rename
---

# Issue #634 stale shared-db-name sweep session

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert. The next session should port the
still-valid edits onto current `origin/main`, preserve the compatibility aliases,
complete the repository gates, merge, install, verify, and close #634 without
asking Albert to choose between implementations.

Already settled — do not re-ask:

- 2026-09-18: `popcre/shared-db` is the canonical repository identity after the
  organization transfer; historical records remain unchanged.
- 2026-09-20 audit: keep the `u2giants/shared-db` compatibility entries in
  `config/repository-coverage.json`, `config/repository-policy.json`, and
  `config/task-gates.json`. Old clone URLs still resolve through GitHub's redirect,
  and these entries preserve the same branch and database safeguards.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and governance toolkit for
Claude, Codex, reviewer providers, repository routing, machine setup, and safety
gates. It is installed onto developer machines from GitHub; repository `main` is
the source of truth. This issue is repository-maintenance work, not a database
structure change and not shared-db orchestrator work.

## 2. What we set out to do this session, and why

Issue [#634](https://github.com/popcre/ai-devops/issues/634) asks for the live
references left behind by the 2026-09-18 `u2giants/shared-db` to
`popcre/shared-db` rename to be corrected through production. The intended result
is current routing, scripts, skills, templates, tests, and active plans naming the
canonical repository while dated evidence, completed decision records, and
intentional redirect compatibility remain intact.

## 3. Current state — what is true right now

- Live GitHub ground truth on 2026-09-23: #634 is OPEN with no comments. Current
  `origin/main` is `dd07790fe7c1c211790eb7d70a296c7deea4ed8b`.
- The unfinished implementation is local and uncommitted in
  `C:\Users\ahazan\.codex\worktrees\issue-634-shared-db-rename\ai-devops` on
  branch `codex/issue-634-shared-db-rename`, based on `5f6f5c52`. It changes 48
  files (108 insertions, 89 deletions) and has no commits beyond its base.
- That worktree replaces live canonical prose and comments, updates three active
  plans semantically, and adds old/new identity parity tests. It deliberately
  restored the three compatibility policy entries after the functional audit.
- `origin/main` advanced 18 commits after the implementation branch's base.
  Eleven edited files also changed on main: `AGENTS.md`, `bin/ai-grok-review`,
  `bin/setup-machine.ps1`, `docs/implementation-plan-index.md`,
  `docs/task-router.md`, `plan_blockerwatch-parked-work.md`,
  `plan_shared-db-complete-throughput-repair.md`, all three global instruction
  templates, and `tests/test-ai-grok-review.sh`. Do not commit or merge those
  stale versions. Port their narrow rename intent onto fresh main.
- No PR was opened, nothing was merged, nothing was installed, and production is
  unchanged.
- Test evidence: the local collision check was clear. `test-ai-glm.sh` reached
  361 passed / 1 failed at the UTC date rollover; the failing synthetic capacity
  fixture was then run directly with a fresh timestamp and returned the expected
  refusal code 3. The long Grok suite was still progressing when the session was
  interrupted. The remaining focused suites were not completed.

## 4. Everything we tried that did NOT work

- The first config edit removed the old repository alias and duplicate policy
  and task-gate entries. The functional audit showed that would weaken safety for
  existing clones whose remote still uses GitHub's redirected old URL. Those
  removals were restored; do not repeat them.
- Running Bash suites through the default `bash` executable invoked an empty WSL
  installation. Git Bash at `C:\Program Files\Git\bin\bash.exe` is the correct
  Windows route.
- The first full `test-ai-glm.sh` run crossed the UTC date boundary and treated
  its just-created timestamp as stale. The exact capacity function passed with a
  newly generated timestamp, so this was not evidence of a rename defect.
- The session began a long sequential test batch. It was interrupted before the
  Grok suite and later tests returned a final summary. Partial output is not a
  pass and must not be reported as one.
- Continuing to commit from the old worktree was rejected during stale-session
  reconciliation because main changed 11 of the same files. A blind rebase or
  broad conflict resolution could overwrite newer work.

## 5. Root causes and key findings

- The rename sweep is still genuinely outstanding: #634 remains open and current
  main still contains the old slug in the live files named by the issue.
- Current runtime routing had already gained the canonical identity in PR #609
  (`19acf49b`). Most remaining functional occurrences are comments or descriptions;
  `tools/context-audit/context-audit.py` also contains user-visible warning text.
- The old name has three intentional live compatibility uses, not cosmetic
  staleness: the repository-coverage alias, repository-policy match, and task-gate
  match. Tests should prove the old redirected identity receives the same policy
  and structural gates as `popcre/shared-db`.
- Live prose includes `AGENTS.md`, current docs, 21 skill files, five templates,
  and three active plans. Preserve `HANDOFF.d/`, `bugs.md`, dated analyses,
  verification evidence, completed/reference-only plans, the rename note in
  `config/blocker-watch.json`, and
  `docs/reviewer-wrapper-gitignore-false-warning.md` as history.
- In `plan_shared-db-complete-throughput-repair.md`, only the current repository
  heading, completed-transfer instruction, Step 8 wording, and current-environment
  identity should change. Completed evidence rows and historical snapshots retain
  the old identity.

## 6. Exact next steps

1. Create a new uniquely named worktree from current `origin/main`, verify its
   branch, and declare `reviewer-safety`. It worked when the base equals the live
   `origin/main` SHA and the task gate records that class.
2. Use the old worktree only as a patch/reference. Re-audit current main and port
   the still-valid narrow changes, resolving the 11 overlapping files against
   their new content rather than accepting either side wholesale. It worked when
   the diff contains only issue #634's canonical-name updates plus the two parity
   tests.
3. Confirm every remaining `u2giants/shared-db` match is historical evidence or
   one of the three compatibility policies (plus tests that intentionally name
   both identities). It worked when no current routing instruction points at the
   old canonical home.
4. Run JSON validation, PowerShell parsing/context tests, and the focused Git Bash
   suites for GLM, Grok, setup credentials, repository coverage/policy, task gates,
   phase-5 acceptance, and shared-db fast-close. It worked when every suite has a
   final zero-failure summary; do not reuse the interrupted partial run.
5. Self-audit all sibling links and trust points, then run
   `ai-task-gates check --before review` and obtain one read-only exact-head final
   review because reviewer wrappers, safety tests, and installed routing rules are
   touched. It worked only with an explicit APPROVE bound to the exact commit.
6. Verify Git identity, commit only owned files, push, open a signed PR, and wait
   with `bin/ai-pr-wait`. Merge through the queue after checks pass. It worked when
   GitHub reports the PR merged and the intended landing commit is on current main.
7. Follow `docs/deployment.md`, install from merged main through the supported
   route, and verify installed skills/global instructions use `popcre/shared-db`
   while compatibility tests remain green. Close #634 with signed evidence and
   delete this handoff in the closeout commit. It worked when source, installed
   state, live GitHub issue state, and origin/main all agree.

## 7. Constraints and gotchas in force

- Never edit the canonical checkout; use a current-upstream isolated worktree.
- Do not commit the old worktree wholesale, reset it, clean it, or resolve its
  overlaps by choosing one complete side. It contains useful uncommitted evidence.
- Preserve capability: redirected old remotes must keep feature-branch and
  shared-database gates. The rename is not permission to delete compatibility.
- Historical decision records must remain historically accurate.
- This is a protected reviewer-safety change. Exact-head independent review,
  focused tests, PR checks, merge queue, merged-main installation, and installed
  proof are completion gates.
- Use Git Bash, not WSL Bash, for Bash tests on this Windows machine.
- Sign every GitHub body with the current Codex thread ID and machine name.

## 8. Access and environment

- Host: `edge-dev` (Windows, PowerShell, Git Bash available).
- Canonical landing-only checkout: `C:\repos\ai-devops`.
- Stale implementation worktree: the path in section 3.
- This handoff was authored from a separate clean current-main worktree on branch
  `codex/issue-634-stale-session-handoff`.
- GitHub access works through `bin/ai-gh`; repository is
  `https://github.com/popcre/ai-devops`.
- Commit identity was verified as
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Secrets, if installation needs them, remain in 1Password vault `vibe_coding`;
  no secret values were read or recorded in this workstream.

## 9. Open questions and risks

- No owner question is open. The implementation risk is mechanical: later work
  changed 11 overlapping files, so a fresh session must port intent, not reuse
  stale whole-file versions.
- The parity tests added in the stale worktree were not fully run. Their intent is
  correct, but they must be re-read against current test helpers and proven green.
- The interrupted Grok suite has no final verdict. Treat it as unverified.
- A later main change may have added new live references after this handoff. The
  next session must search current main again before declaring the sweep complete.

## Sub-agent record — functional audit

Asked to classify functional/config/script/test occurrences without editing.
It audited fresh `origin/main` `5f6f5c52` and found 11 stale live occurrences in
eight functional areas. It identified the three compatibility policies that must
remain and recommended explicit old/new parity tests. It made no edits or commits.

## Sub-agent record — prose audit

Asked to classify current prose, skills, templates, plans, and historical records
without editing. It audited fresh `origin/main` `5f6f5c52`, named the live files to
update, isolated three active plans needing changes, and identified historical
records to preserve. It made no edits or commits.

## Sub-agent record — test audit

Asked to classify tests and recommend the smallest complete verification series.
The session was interrupted before it returned a final report. It made no known
edits or commits. Do not infer a verdict from its missing response; repeat the
current-main test audit in the successor session.

## Handoff self-audit

1. Yes. Sections 1–3 establish the project, goal, exact repository/worktree state,
   and delivery status; section 6 gives executable continuation steps.
2. Yes. Sections 4–5 preserve the failed attempts, compatibility finding, scope
   boundary, and historical-record classification; the sub-agent blocks preserve
   every returned audit conclusion.
3. Yes. Sections 0–9 cover decisions, background, goal, current state, failures,
   findings, constraints, access, risks, next actions, and verification gates.
4. Yes. A line-by-line sweep of sections 1–9 and the sub-agent blocks found no
   remaining owner decision. Section 0 states that explicitly and records the two
   settled decisions that must not be re-asked.
