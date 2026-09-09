---
issue: 335
status: OPEN
owner: claude/cross-repo-routing-gates-0bafa0 (landed; Phase 3 is unowned)
---

# HANDOFF — Issue #335 Phases 1-2 landed, Phase 3 pilots open (2026-09-09T0833Z, edge-dev/claude)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Put all of these to Albert in ONE message before starting work. Do not trip
over them one at a time.**

**Albert answered all four of these on 2026-09-09. They are settled. Do not
re-ask them; the answers are recorded below with what they oblige you to do.**

Blocking:

- **None.** Nothing blocks Phase 3. Start it.

A wrong guess is recoverable, but wasteful:

1. **ANSWERED — the parallel Codex work is named, and it has NOT finished.**
   Albert asked which Codex session it was and whether it was done. The answer,
   read off GitHub on 2026-09-09:

   - The Codex work ran on branch **`codex/issue-335-routing-gates`**. It landed
     two pull requests: **#340** "feat: add task-gate routing baseline"
     (merged 2026-09-09T00:10:56Z) and **#342** "docs: hand off Issue #335
     Phase 0" (merged 2026-09-09T00:29:30Z). #340 is the merge that collided
     with this session's work across five files.
   - It then opened a **second** branch, **`codex/issue-335-gate-contracts`**,
     as pull request **#343** "Define cross-repository task-gate contract",
     created 2026-09-09T00:34Z. **#343 is still OPEN and has not been touched
     since it was created.** So: no, that Codex session did not finish.
   - **#343 is now duplicate, superseded work.** It claims "Closes #335 phase 1"
     and changes eleven files — the central policy, its schema, the fixtures, the
     plan file, the workflow-policy test — every one of which this session's #345
     already delivered and merged. It cannot merge as it stands.

   **What the next session must do about it, before any Phase 3 work:** put
   #343 to Albert with a recommendation to **close it unmerged**, saying plainly
   that everything in it now exists on the main line, and that leaving it open
   invites a third collision. Then confirm with Albert that **one agent owns
   #335 from here** — the answer to the original question — and check for any
   live Codex task still running against these branches before starting.
   *You'll know it worked when* #343 is closed or explicitly kept, and Albert
   has named the single owner in writing.
2. **Phase 3 touches four repositories on four separate branches, one of which is
   DesignFlow.** DesignFlow goes to `develop` and is never self-merged, so that
   pilot ends with a pull request somebody else merges. Recommendation: **do the
   three self-mergeable pilots first** (`ai-devops`, `shared-db`, `theoracle`)
   and open the DesignFlow one last, so a wait on another person does not hold
   up the rest. **ANSWERED 2026-09-09: Albert agreed. Do the three
   self-mergeable pilots first and open the DesignFlow pull request last.** This
   is now an instruction, not a suggestion; step 6 below already runs in that
   order.

Not part of this work, and nobody is on it:

3. **Three closeout-contract phrases are missing from the Claude global
   template.** `templates/system/AGENTS-global-codex.md` carries "Account for the
   whole job", "Preparation is not delivery", and "Ending the turn is the error";
   `templates/system/CLAUDE-global.md` does not, so the strict context audit
   reports three failures on a clean tree. In plain terms: the rule that stops a
   session from quitting early is enforced for one AI and not the other.
   Recommendation: **add the three phrases to the Claude template**, as its own
   small change, not inside #335. It predates this work. **ANSWERED 2026-09-09:
   Albert said yes. Do it — as a separate pull request of its own, not folded
   into #335.** *You'll know it worked when* the strict context audit reports
   zero failures on a clean tree.
4. **The pull-request wait command misreports its own timeout.** After a
   transient read failure it announces it gave up on a 180-minute deadline that
   had not remotely elapsed — it did this twice today, seconds after starting.
   The wait itself worked and merged correctly; only the message is wrong, and it
   would make a future session believe a pull request had stalled for three hours
   when it had not. Recommendation: **open a small issue** to fix the message.
   **ANSWERED 2026-09-09: Albert said yes — open the issue.** Repair the message
   so it reports the real cause and the real elapsed time; do not remove or
   weaken the deadline itself. *You'll know it worked when* an induced transient
   read failure prints a retry notice and no timeout claim.

Already settled — do NOT re-ask:

- #335 covers all 17 canonical repositories (2026-09-08).
- Central enforcement lives in `popcre/ai-devops`; consumer repositories get thin
  declarations only (2026-09-08).
- A local policy may strengthen a gate and can never weaken one (2026-09-08).
- Raw transcripts and licensed source rows are never inspected (2026-09-08).
- All four §0 items above were answered by Albert on 2026-09-09; the answers are
  written into the items themselves. Do not put them to him again.
- #335 stays OPEN until Phase 5 acceptance passes. It was closed once by mistake
  after Phase 0 and had to be reopened. Do not use a closing keyword in a pull
  request body before then (2026-09-09).

## 1. What this application is

`popcre/ai-devops` is POP Creations' public toolkit for running several AI coding
models reliably across the company's repositories. It is a set of command-line
tools plus the shared instruction files that tell an AI session how to work in
each repository. It is not a deployed application: it installs onto a developer
machine and into GitHub Actions. Albert Hazan owns it. GitHub identities are
`u2giants` (personal) and `popcre` (DesignFlow and this toolkit).

The 17 repositories in scope are listed in `config/repository-coverage.json`.

## 2. What we set out to do this session, and why

Owner issue popcre/ai-devops#335, under parent outcome #159 and blocking #166.

The business problem: an AI session reads far more instruction than its task
needs, and nothing stops a small task from turning into an expensive or risky
one. A documentation cleanup could trigger a paid model review, an hour-long wait
for automated checks, a deployment, or a production action — and the only thing
preventing it was prose in a file asking the session not to.

The plan (`plan_cross_repo_routing_and_gate_enforcement.md`) has six phases. This
session was asked to implement it and took Phases 1 and 2: the shared policy
contract, and the central engine that enforces it.

## 3. Current state — what is true right now

**Landed on `main` and verified.**

- Phase 0 (inventory) landed 2026-09-08 as `d613926a` via PR #340, by the Codex
  session. Phases 1 and 2 landed 2026-09-09 as merge commit `fc107fd6` via
  https://github.com/popcre/ai-devops/pull/345, by this session, through the
  merge queue with all four check lanes green.
- Phase 3, 4 and 5 are **not started**. The plan's STATUS table on `main` is
  accurate.
- #335 is OPEN and must stay open.

**What now exists and works:**

- `bin/ai-task-gates` — the engine. `start` declares what a task is, `check
  --before <action>` recomputes the real change set and allows or refuses,
  `explain` shows the classification, `status` and `end` manage the declaration.
- `config/task-gates.json` — the central policy: which paths mean which class of
  work, and which proofs and refusals each class carries.
  `config/task-gates.schema.json` and `tools/ci/validate-task-gates.py` keep it
  honest.
- Enforcement runs in exactly three places, each of them before any money or
  time is spent: `bin/ai-review` (the reviewer front door),
  `bin/ai-review-lifecycle` (which the provider wrappers call), and
  `bin/ai-pr-wait`.
- A repository may add `.ai-devops/task-gates.json` with extra rules. Resolution
  takes the strongest class across every match, so a local file can only make a
  gate stricter. Weakening one is impossible by construction, not by policy.
- Some classes are protected: they cannot be acknowledged or owner-requested
  past at all.
- The engine fails closed. It refuses when it cannot find its policy, its
  library, or the repository identity — including when installed on the system
  path through a symlink, which is how `install.sh` puts it there.

**Test counts at the merged head**, all run locally on this Windows host:
`test-ai-task-gates.sh` 70/0, `test-ai-review-lifecycle.sh` 49/0,
`test-ai-pr-wait.sh` 26/0, `test-ai-claude-review.sh` 33/0,
`test-ai-codex-review.sh` 41/0, `test-review-preflight.sh` 78/0,
`test-workflow-policy.sh` PASS, `test-repository-coverage.sh` PASS. The complete
offline Bash suite (69 suites) and PowerShell suite (18 suites) were run
sequentially, not concurrently — see §7.

Evidence is committed at `tests/verification/task-gates/phase-2-central-engine.md`,
including all four independent review rounds.

**Nothing is half-done.** The worktree at
`C:\repos\ai-devops\.claude\worktrees\edge-dev-powershell-interruptions-7d3025`
is clean and its branch is merged; it can be removed.

## 4. Everything we tried that did NOT work

Read this section before writing any code. It is four rounds of a reviewer
finding real defects in work that already passed its own tests.

- **Round 1 — the gate was not executable.** `bin/ai-task-gates` was committed
  mode `644`. `tools/lib/task-gates.sh` had `[ -x "$bin" ] || return 0`, so on
  Linux the entire gate would have silently allowed everything while every test
  passed on Windows, where the executable bit is not enforced. Fixed with `git
  update-index --chmod=+x`. **The shape that caused it still exists** — that
  `|| return 0` line, and the matching one for a missing `jq`, are deliberate
  and commented, but they are the two remaining ways the gate can be absent
  rather than refuse.
- **Round 1 — a refusal trapped in a subshell.** The check for a corrupt local
  policy file ran inside a command substitution, so its exit ended only the
  subshell and the run continued on the central rules alone — dropping exactly
  the stricter local rules a corrupt file should have stopped for. The check now
  runs in the main shell, in `resolve_repo()`.
- **Round 2 — every new caller resolved its repository from the wrong place.**
  `install.sh` symlinks each `bin/*` into `/usr/local/bin`, and bash reports the
  symlink path, so all four callers would have looked for the repository inside
  `/usr/local` and found nothing. On an installed Linux machine this would have
  killed the reviewer front door and the reviewer lifecycle outright, not just
  the gate. The pattern that fixes it (`readlink -f`) was already in
  `bin/ai-review-preflight:18-22` and had simply not been copied.
- **Round 2 — the front door was not covered by its own rule.** The policy glob
  `bin/ai-review-*` compiles to a pattern that does not match `bin/ai-review`
  itself, so the one file that gates every review was unprotected. Added
  explicitly.
- **Round 3 — the plan-review exemption was in the wrong layer, and the owner
  override never arrived.** A plan review has to run before the work exists, so
  it cannot be gated on the class of that work. The exemption was put in
  `bin/ai-review` — but both provider wrappers call `ai-review-lifecycle begin`
  for every mode, and the lifecycle could not see the mode, so it refused the
  plan review anyway. `--owner-request` was lost the same way, which meant the
  documented way to get a review of a documentation change did not exist on any
  real path. Fixed by exporting `AI_REVIEW_GATE_MODE` and
  `AI_REVIEW_OWNER_REQUEST` from the front door.
- **Round 3 — the test that proved the override proved nothing.** It called
  `ai-review-lifecycle begin --owner-request` directly, a call no shipped code
  makes, so both defects above passed the suite. Replaced with three cases that
  drive `bin/ai-review` with a stub wrapper. **If you add a test for a gate,
  drive the front door, not the inner command.**
- **Round 3 — an internal failure read as a yes.** `tg_preflight_gate` mapped
  any exit other than 3 or 4 to "allowed". A gate that cannot answer must not be
  read as a yes; it now refuses.
- **Codex could not review this at all.** Its sandbox policy blocked every
  read-only command, including the first required read. Use the Claude reviewer
  for this work until that is fixed.
- **Python heredocs through a Bash tool eat backslashes.** A newline escape
  written inside a Python string arrived as a real newline and silently injected
  line breaks into three error messages. Work around it with `BS = chr(92)` and a
  `.replace()`, or splice the file by line index with `head`/`cat`/`tail`.
- **Python writing files on Windows converts line endings.** Every file written
  that way needs a byte-level carriage-return strip afterwards, or it joins the
  54 files this repository already reports as wrong.
- **`ln -s` cannot make a real symlink on this host**, even with
  `MSYS=winsymlinks:nativestrict`. The symlink tests skip locally and run on
  Linux CI; a detached-copy test was added so the fail-loud path is still proven
  on Windows.
- **Two full test suites must never run at once on this host.** They contend and
  produce failures that are not real. An earlier concurrent run reported four
  reviewer failures that all cleared on a sequential re-run.

## 5. Root causes and key findings

- The pre-existing CI classifier (`tools/ci/classify-changes.sh`) is coarse and
  only runs once a pull request exists. It cannot record what a task was meant to
  be, and it cannot stop anything before the expense. That is why #335 needed a
  new engine rather than another rule in the old one. The engine keeps the old
  classifier's output byte-for-byte compatible and cross-asserts it, at
  `tools/lib/task-gates.sh:38` and `tests/test-ai-task-gates.sh:2179`.
- **The change set must be recomputed, never trusted.** The engine reads
  committed-versus-base, staged, unstaged, untracked, deleted, both sides of a
  rename (via `--no-renames`), and submodules. A rename is the interesting case:
  without both sides, moving a database migration out of the way hides it.
- **Strongest-match resolution is what makes local policy safe.** Because the
  result is the maximum rank across central defaults, every matching central
  rule, and the local declaration, a repository cannot weaken a gate even by
  writing a deliberately wrong file. This is a property of the resolution, not a
  rule someone has to enforce.
- **The two review-mode environment variables are a guardrail, not a boundary.**
  Anyone able to set an environment variable can already run the provider
  wrapper directly. They exist so an honest caller is not wrongly refused. This
  is written down in `docs/context-spec.md`.
- **Byte size of an instruction file is a diagnostic, never a blocking rule.** A
  large file that carries unique safety instructions is correct; a large file
  that embeds a procedure owned elsewhere is the defect this program repairs.

## 6. Exact next steps

Phase 3 is four pilots, on four separate branches, each in its own current-upstream
worktree. Read `plan_cross_repo_routing_and_gate_enforcement.md` Step 3.1 onwards
for the full text; this is the operating summary.

1. **Clear the stale Codex pull request first, then confirm ownership.** See
   §0 item 1: Codex pull request **#343** (`codex/issue-335-gate-contracts`) is
   still open and is now fully superseded by #345. Put it to Albert with a
   recommendation to close it unmerged, and confirm the single owner of #335.
   *You'll know it worked when* #343 is closed or explicitly kept, and Albert has
   named the owner in writing. Two side jobs, both approved by Albert on
   2026-09-09 and both **separate from #335**: add the three closeout phrases to
   the Claude global template (§0 item 3), and open an issue for the wrong
   timeout message on the pull-request wait (§0 item 4). Neither blocks Phase 3;
   do not fold either into a #335 pull request.
2. **Install the toolkit on this machine and confirm the gate survives it:**
   `./install.sh`, then from any repository run `ai-task-gates version` and
   `ai-task-gates explain`. *You'll know it worked when* both succeed when run as
   `ai-task-gates` from the system path, not as `bin/ai-task-gates`. This is the
   symlink defect from round 2; it is fixed but has never been proven on a real
   installed Linux machine, only by test.
3. **Pilot one — `popcre/ai-devops` itself.** Add `.ai-devops/task-gates.json`
   declaring this repository's own stricter classes (reviewer safety,
   installation). *You'll know it worked when* `ai-task-gates explain` on a
   change to `bin/ai-review` reports `reviewer-safety`, and a test proves the
   local file cannot weaken a central class.
4. **Pilot two — `u2giants/shared-db`.** Branch and pull request; this repository
   never takes a direct push. The declaration must make any structure change
   protected. *You'll know it worked when* a fixture containing a migration file
   refuses a deployment action and cannot be acknowledged past.
5. **Pilot three — `u2giants/theoracle`.** *You'll know it worked when* release
   and migration paths classify as protected and the repository's existing tests
   still pass.
6. **Pilot four — `popcre/designflow-frontend`.** Sandbox branch, pull request to
   `develop`, **never self-merged**. *You'll know it worked when* the pull request
   is open with green checks; somebody else merges it.
7. **Update the plan's STATUS table and write the Phase 4 handoff.** *You'll know
   it worked when* the table on `main` says Phase 3 DONE with the four pull
   request numbers.

Do not start Phase 4 (the remaining 13 repositories) until all four pilots have
landed, and do not close #335 before Phase 5 acceptance.

## 7. Constraints and gotchas in force

- **Albert never merges.** The session that opens a pull request merges it. The
  sole exception is DesignFlow, which goes to `develop` and is never self-merged.
- **A documentation-only pull request merges immediately** with `gh pr merge
  --squash --admin`, without waiting for checks. Check the changed-file list
  first: one code, test, script, workflow or configuration file and the normal
  checks apply.
- **`gh pr merge` in this repository goes through a merge queue.** `--squash`
  is refused with "the merge strategy for main is set by the merge queue"; use a
  bare `gh pr merge`, then wait. The merge is not instant.
- **Use `bin/ai-pr-wait <number> --repo OWNER/NAME`** to wait — the first
  argument is a bare number, not `--pr`. Never hand-roll a wait loop: a pull
  request ejected from the merge queue stays OPEN forever. Be aware of the
  wrong-timeout message in §0 item 4.
- **Never use bare `git stash` or `git stash pop` in a worktree** — the stack is
  shared with every other session. Use a temporary commit instead.
- **Verify `git var GIT_COMMITTER_IDENT`** shows `Albert Hazan
  <u2giants@users.noreply.github.com>` before the first commit in a repository.
- Every shared-database structure change is authored in `u2giants/shared-db`
  through its branch-and-pull-request workflow.
- AI sessions are read-only for production and shared cloud infrastructure. No
  `terraform apply`, `terragrunt apply`, `terraform destroy` or mutating
  production `gcloud` without Albert naming the exact resource and action in the
  current chat.
- Secrets live in 1Password vault `vibe_coding` and move only through pipes or
  protected files — never chat, command arguments, output, logs or commits.
- Windows specifics: use Git Bash at `C:\Program Files\Git\bin\bash.exe`; the
  plain `bash` command reaches WSL, which has no distribution installed. `jq`
  emits carriage returns, so the codebase wraps it in a helper that strips them.
- Commit trailer: `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
  Pull request body trailer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## 8. Access and environment

- Git and GitHub CLI are authenticated for `popcre/ai-devops`; PR #345 was
  merged through the protected merge queue by this session.
- Machine is `edge-dev` (Windows 11). Reviewers on this host run from the shared
  checkout `C:\repos\ai-devops`, so a merged fix is not live for them until that
  checkout pulls.
- The reviewer front door is `bin/ai-review <claude|codex> <mode>`. Codex is
  currently blocked by its own sandbox policy (§4); use `claude`.
- No credential was read, created, or exposed by this work. Future secret work
  uses 1Password vault `vibe_coding` without printing values.

## 9. Open questions and risks

- **The biggest risk is duplicate work.** It already happened once on this issue,
  on the same day, and cost a merge conflict across five files. §0 item 1.
- **The two deliberate fail-open paths in `tools/lib/task-gates.sh:132-133`** (a
  non-executable gate, a missing `jq`) are commented and intentional, but they
  are the shape that produced the round-1 defect. If Phase 5 adds a check, make
  it "the gate is installed and runnable", asserted once at install time.
- **`bin/ai-pr-wait` judges the current working tree, not the repository named
  by `--repo`.** Waiting on another repository's pull request is decided by
  whatever is in the directory you are standing in. It errs toward refusing, and
  `--owner-request` recovers it, but it is worth fixing during Phase 4.
- **A plan review can only be started through `bin/ai-review`.** Calling
  `ai-codex-review plan-review` directly is now refused. The README says so; a
  session that remembers the old command will be confused.
- Decisions recorded 2026-09-09: enforcement lives at the three spending points
  and nowhere else; protected classes are unbypassable by design; the review-mode
  environment variables are a guardrail and not a boundary.

## Self-audit

1. **Yes.** §1 gives the product and the owner from zero knowledge; §3 gives the
   landed commits, the pull request, the test counts and the fact that nothing is
   half-done; §6 gives seven numbered steps each with its own proof.
2. **Yes.** §4 preserves all four review rounds — the non-executable gate, the
   subshell refusal, the symlink resolution, the uncovered front door, the
   plan-review layering, the useless test, the fail-open — plus the Windows
   line-ending, heredoc, symlink and concurrency traps. §5 records the five
   findings that took real time to reach. A newcomer would not repeat any of it.
3. **Yes.** §§0-9 cover owner decisions, background, goal, landed state, dead
   ends, findings, ordered steps with gates, standing rules, access, and risks.
   Commit SHAs, pull request numbers, file paths with line numbers, and the
   secret boundary are all explicit and named.
4. **Yes, checked the hard way.** Walking §1-§9 line by line for anything needing
   Albert's judgement: the parallel Codex task (§3, §9) → §0 item 1; the
   DesignFlow no-self-merge sequencing (§6 step 6, §7) → §0 item 2; the missing
   closeout phrases, which are outside this workstream and would otherwise have
   been filed as a finding and never raised → §0 item 3; the wrong-timeout
   message, discovered in passing while merging → §0 item 4. Nothing else in the
   document asks for a ruling. Each §0 item carries a recommendation and says
   what it blocks.
