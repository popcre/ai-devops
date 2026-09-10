---
issue: 355
status: OPEN
owner: codex/blacksmith-additive-355
---

# HANDOFF — additive Blacksmith Windows pool (2026-09-10T0007Z, edge-dev/codex)

**Superseding implementation plan:**
[`../plan_blacksmith-windows-throughput.md`](../plan_blacksmith-windows-throughput.md).
It preserves this file's investigation history and replaces the earlier small
sentinel recommendation with Albert's locked 3+3 throughput design.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### Blocking

- Albert must decide whether PR #355 should be revised now to the recommended
  steady state before merge. Recommendation: **yes**—shard Windows-sensitive
  pull-request tests across Blacksmith, retain a smaller GitHub Windows sentinel,
  retain the qualified local reviewer lane, and reserve the complete Windows
  pack for scheduled/manual runs. This blocks final workflow design and merge.

### Already settled — do not re-ask

- On 2026-09-09 Albert decided Blacksmith must be additional capacity, not a
  replacement for GitHub-hosted or local runners.
- On 2026-09-09 Albert questioned the need to duplicate the complete Windows
  pack and asked that every session finding be documented. Documentation is the
  authorized scope of the current turn; it does not itself approve the redesign.

The next session must put the single blocking decision above to Albert in one
message before changing the workflow again.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and verification toolkit
for its multi-model AI workflow. It is not a deployed application. GitHub is the
source of truth, installation is its deployment mechanism, and Windows CI
validates PowerShell behavior, Git Bash behavior, file permissions, process
locking, and reviewer safety. The repository is at
<https://github.com/popcre/ai-devops>; the active work is PR
[#355](https://github.com/popcre/ai-devops/pull/355).

Three Windows capacities matter:

- GitHub-hosted `windows-2025` for disposable general Windows coverage.
- Blacksmith ephemeral Windows VMs for additional hosted capacity.
- A qualified local physical runner selected by
  `[self-hosted, Windows, X64, ai-devops-windows-qualified]` for timing-sensitive
  Codex and Grok reviewer tests.

## 2. What we set out to do this session, and why

Albert signed up for Blacksmith and its migration wizard opened PR #355. He
wanted Blacksmith added to the existing pool, without replacing GitHub-hosted or
local runners, and asked whether the wizard had done something wrong. The task
became: update from current upstream, inspect the live PR and runners, repair the
wizard's replacement migration into an additive Windows lane, qualify it, and
explain the runtime and long-term design.

The later owner question changed the design target: Blacksmith can run multiple
Windows jobs concurrently, and duplicating the entire Windows pack on both
hosted providers for every code PR is probably qualification overhead rather
than the desired steady state. That target is documented but not yet implemented.

## 3. Current state — what is true right now

- The canonical checkout `C:\repos\ai-devops` was fast-forwarded from
  `daa0e9a` to then-current `origin/main` at `9a7f9746` before edits.
- All writes occurred in isolated worktree
  `C:\repos\ai-devops-worktrees\blacksmith-additive-355` on local branch
  `codex/blacksmith-additive-355`, pushed to PR branch
  `blacksmith-migration-9a7f974`.
- PR #355 head is `92ba1e9a4c88f97f9e2862e233231312cb6b03d8`.
  Commits after the bot commit are `d275bf42`, `3ee58d92`, `58b17080`,
  `1a976a8e`, and `92ba1e9a`.
- The branch currently restores GitHub Ubuntu, restores GitHub-hosted Windows,
  preserves the qualified local reviewer lane, and adds a separate complete
  Blacksmith Windows job in `.github/workflows/verify.yml`.
- PR #355 currently reports `mergeStateStatus: DIRTY`, meaning current `main`
  has moved and the branch conflicts. Do not merge or claim readiness until it
  is rebased and reverified.
- Exact-head manual run
  [`34418585172`](https://github.com/popcre/ai-devops/actions/runs/34418585172)
  was still running at documentation time. `manual-preflight`, classifier,
  `linux-offline`, and `windows-reviewer-safety` had passed; GitHub-hosted
  `windows-offline` and `windows-blacksmith` were in progress.
- Exact-head independent Claude final review run
  `20260909T235148-106344-19315` approved commit `92ba1e9a`; report:
  `.ai/reviews/claude-final-check-20260909T235148-106344-19315.md`.
  Any rebase or push invalidates that approval.
- Focused local checks on `92ba1e9a` passed: `test-ai-facts.sh` 14/14 and
  `test-workflow-policy.sh` passed. Earlier focused evidence included
  `test-ai-gemini.sh` 65/65 and `test-test-selection.sh` 9/9.
- The durable findings are in `docs/blacksmith-windows-runners.md`; the router
  links future Windows/Blacksmith tasks to it. The STATUS table and #210 section
  in `plan_repo-throughput-restructure.md` now point to these findings and name
  #210 as the next plan step.
- This documentation turn changed only Markdown and is intentionally uncommitted
  and unpushed under the documentation-only skill. The existing code commits
  above were already pushed before this documentation request.

## 4. Everything we tried that did NOT work

1. The Blacksmith migration wizard's original commit `5852ce68` replaced
   compatible `runs-on` labels, including Ubuntu and GitHub Windows. That is
   normal wizard behavior but contradicted Albert's additive intent.
2. Run `34406469534` against `d275bf42` failed on Blacksmith because the image
   lacked the expected Python command and Windows ACL output identified the user
   differently. The repair pinned Python 3.13 in the Blacksmith job and accepted
   either a nonempty current account name or its nonempty exact SID.
3. A first ACL repair was not fully fail-closed when an identity variable was
   empty. Commits `58b17080` and `1a976a8e` added explicit nonempty guards.
4. Run `34414264824` proved Python was fixed but its Blacksmith job failed two
   Bash suites: the fact-search fallback emitted unexpected filename prefixes,
   and the pre-final ACL assertion still failed. Commit `92ba1e9a` forced
   `grep -h`; the later ACL commit already covered the second cause.
5. An exact-head Codex review on commit `3ee58d92`, run
   `20260909T225612-5997-1899`, could not read its evidence because the read-only
   sandbox rejected every file access. It was recorded through
   `bin/ai-reviewer-issue`; Claude was used as the supported independent
   read-only reviewer instead.
6. One Claude review attempt returned an empty temporary output; a bounded
   retry completed successfully with exact-head APPROVE.
7. PR synchronize events did not emit fresh workflow runs after later pushes.
   Closing and reopening the PR did not fix that. Supported manual
   `workflow_dispatch` runs were used for exact-commit evidence.
8. Earlier exact-head run `34415648130` had two known local Grok timing failures:
   `different_named_sessions_can_ask_concurrently` and
   `same_next_ask_turn_is_serialized`; 223 other reviewer checks passed and the
   prior commit passed on the same host. Do not weaken assertions or inflate
   timeouts to hide this signature.
9. Full Windows runs take roughly 60–73 minutes. Repeated whole-pack
   qualification made this session long and demonstrated why duplicating the
   complete pack per PR is not the recommended permanent design.

## 5. Root causes and key findings

- Blacksmith's wizard is a migration tool: replacement was expected behavior,
  not an error by Albert. Additive capacity must be expressed as separate jobs
  because `runs-on` chooses one runner class.
- Blacksmith currently documents no provider-imposed concurrency cap and
  encourages aggressive sharding. Verify account/GitHub limits live. Windows is
  public beta and intentionally differs from the full GitHub image. See
  `docs/blacksmith-windows-runners.md` and
  <https://docs.blacksmith.sh/blacksmith-runners/overview>.
- The repository manifest currently declares 69 Bash suites and 18 PowerShell
  suites. Ordinary PR Windows coverage selects 23 Windows-sensitive Bash suites
  plus all 18 PowerShell suites; scheduled/manual runs retain the complete pack.
- Running the complete pack once on GitHub and again on Blacksmith is useful
  cross-provider qualification. It doubles steady-state work and cost without
  automatically improving coverage.
- Blacksmith Windows 4-vCPU free-tier accounting is expensive relative to x64
  Linux units. At the documented conversion, a 60-minute 4-vCPU Windows job uses
  240 x64 2-vCPU minute-equivalents. Pricing is live external state and must be
  rechecked before a budget decision.
- Blacksmith can safely run shards concurrently because each job receives an
  isolated ephemeral VM. Multiple runner processes on one physical local host
  are different: they compete for cores, distort timing, and can starve runner
  heartbeats.
- A steady-state layout should use several exactly-once Blacksmith shards, a
  smaller independent GitHub Windows sentinel, the stable local reviewer lane,
  and a full scheduled/manual backstop. This is a recommendation awaiting owner
  approval, not current implementation.
- Every push or rebase invalidates exact-head review and CI evidence. The current
  PR conflict therefore guarantees another final evidence cycle.

## 6. Exact next steps

1. Present the single decision in §0 to Albert. You will know this is complete
   when he explicitly says whether to implement the sharded steady-state design
   before merging PR #355.
2. Re-resolve `origin/main`, PR #355 head/state/checks, active runner inventory,
   and run `34418585172`. You will know this is complete when every value is a
   fresh API result rather than this handoff's snapshot.
3. If Albert approves the recommendation, update the PR in its isolated worktree:
   shard the 23 Windows-sensitive Bash suites and 18 PowerShell suites across
   multiple Blacksmith jobs with exact-once manifest assignment; reduce the
   GitHub-hosted Windows job to a deliberate sentinel; preserve the qualified
   local Codex/Grok lane; retain complete scheduled/manual backstops. You will
   know this worked when policy tests detect missing, duplicate, and misrouted
   suites and all intended jobs are visible.
4. If Albert declines, retain the current additive full Blacksmith lane and
   document its expected cost. You will know this is complete when the workflow
   and docs describe the same owner-approved design.
5. Rebase onto current `origin/main` and resolve the live conflict without
   overwriting unrelated work. You will know this worked when the PR reports no
   conflict and the branch diff contains only intended changes.
6. Run focused policy/selection tests, then one exact-head CI qualification. Do
   not rerun unchanged failures without a diagnostic reason. You will know this
   worked when Linux, GitHub Windows, Blacksmith shards/lane, and qualified local
   reviewer jobs all pass on the final SHA.
7. Obtain a new independent read-only exact-head final review after the final
   push. You will know this worked when the report says APPROVE and names that
   exact SHA.
8. Merge through the repository merge queue, confirm the landed commit on
   `origin/main`, fast-forward the canonical landing checkout, and retire this
   handoff in the finishing commit under the successor rule. You will know the
   work is done when PR #355 is merged, the intended workflow is on
   `origin/main`, and this OPEN file is absent from the landed tree.

## 7. Constraints and gotchas in force

- Use a current-upstream isolated worktree for every write; the canonical
  checkout is landing-only.
- Work through PR and merge queue; never push directly to `main`.
- Preserve GitHub-hosted and qualified local capacity. Never call replacement
  additive.
- Never run a local full suite while a CI runner is active on that physical
  Windows host. Blacksmith ephemeral VMs are independent and may run concurrently.
- Never weaken, quarantine, allow-fail, delete, or timeout-inflate a test to make
  CI green. Shards must retain exact-once coverage and fail closed.
- Public fork approval must remain `all_external_contributors`; do not expose a
  credentialed local machine to unapproved fork code.
- Resolve runners, PR head, checks, pricing, and external provider limits live.
- Stage only owned files. Verify committer identity is
  `Albert Hazan <u2giants@users.noreply.github.com>` before any future commit.
- A manual workflow run on the exact SHA is valid evidence, but confirm how its
  checks interact with required statuses and the merge queue.
- The Blacksmith Windows image is public beta. Python and output-format
  differences found here are evidence that “drop-in” does not mean byte-identical.

## 8. Access and environment

- Authenticated GitHub CLI access worked for `popcre/ai-devops`, including PR,
  workflow, runner, and job-log reads plus workflow dispatch and branch pushes.
- Worktree: `C:\repos\ai-devops-worktrees\blacksmith-additive-355`.
- Canonical landing checkout: `C:\repos\ai-devops`.
- Local branch: `codex/blacksmith-additive-355`; remote PR branch:
  `blacksmith-migration-9a7f974`; PR URL:
  <https://github.com/popcre/ai-devops/pull/355>.
- Blacksmith dashboard access was not required; public official documentation
  supplied concurrency, image, and free-tier conversion facts. Recheck those
  before cost decisions.
- No secrets were read or written. If future setup needs credentials, use the
  1Password vault `vibe_coding` and never put values in commands, logs, chat, or
  commits.

## 9. Open questions and risks

- Blocking owner decision: whether to implement the recommended sharded
  steady-state design now; this is duplicated in §0.
- PR #355 is conflicted with current main. Conflict resolution may reveal newer
  runner work and must precede final qualification.
- Exact-head run `34418585172` was incomplete at handoff time; its two full
  Windows results remain unknown.
- The exact shard count and GitHub sentinel contents require measurement and an
  exact-once policy design. Do not guess them merely to create more jobs.
- Blacksmith's unlimited concurrency is provider policy, not a guarantee against
  GitHub/account/billing limits. Verify actual queue behavior and spend.
- Windows remains public beta; future image changes may reintroduce dependency
  differences. Keep explicit dependencies and fail-closed portability tests.
- A smaller GitHub sentinel reduces duplicated coverage on ordinary PRs, so the
  scheduled/manual complete backstop and exact-once Blacksmith shard policy are
  mandatory compensating controls.

## Self-audit

1. **Yes, a newcomer can continue without asking for missing context.** Sections
   1–3 define the repository, provider roles, goal, paths, branch, commits, PR,
   run, review, and exact current state; §6 gives executable continuation steps.
   Gap found and fixed: the PR conflict and documentation commit status were
   made explicit in §3.
2. **Yes, a newcomer can continue as effectively as this session.** Sections
   4–5 preserve every material failed attempt, exact run identifier, failure
   signature, root cause, cost consequence, and the distinction between hosted
   isolated concurrency and local physical contention. No remaining gap found.
3. **Yes, all execution-relevant detail is present.** Background and goal are in
   §§1–2, current state/evidence in §3, failures in §4, findings in §5, gated next
   actions in §6, constraints in §7, access in §8, and uncertainties in §9. No
   secrets or private raw logs are included. No remaining gap found.
4. **Yes, section 0 contains every owner decision.** A line-by-line sweep of
   §§1–9 found one unresolved judgement: whether to implement the recommended
   sharded design before merge. It appears in §0 with a recommendation and the
   work it blocks. The additive-provider intent and documentation-only authority
   are listed as already settled so they are not re-asked. No outside-scope owner
   decision was found.
