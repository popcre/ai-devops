---
issue: none    # no GitHub issue opened; Albert has not authorised posting to the repo. See §0.
status: OPEN
owner: main / al8960ofc Claude Opus 5 session, 2026-08-14
---

# Handoff: a plan exists to make stale artifacts visible; no code written yet

Written 2026-08-14T2015Z on machine `al8960ofc` by a Claude Opus 5 session.
Repo: `C:\repos\ai-devops` (`u2giants/ai-devops`), branch `main`, at `99311f8`.

> **This file exists to make one plan discoverable.** No implementation has
> started. The whole build is specified in
> [`plan_repo-housekeeping-visibility.md`](../plan_repo-housekeeping-visibility.md).
> Read that file's STATUS table first. Do not re-plan from scratch and do not
> re-derive its findings — an independent model review already cost a paid run.

## 0. DECISIONS ONLY ALBERT CAN MAKE

### Blocking — nothing proceeds past them

1. **Approve starting implementation.** The plan was corrected and re-audited on
   2026-08-15, but no implementation has started. Recommendation: approve steps
   1-3 (Phase A) immediately. They correct misleading instructions and establish
   attribution without claiming that a closed issue proves completion.

### Recoverable, but he is the only one allowed to decide

2. **Whether to open a GitHub issue for this workstream.** This file carries
   `issue: none` because posting to the public repo was not authorised in the
   session that wrote it. Once step 3 of the plan lands, `issue: none` will be
   reported as `UNPROVABLE` by the new tool, which is the honest outcome, but an
   issue would be better. One command, his call:
   `gh issue create --repo u2giants/ai-devops --title "Repo housekeeping: make stale artifacts visible"`.
### Already settled — do NOT re-ask, do NOT re-litigate

- **There will be no `--apply`, `--fix`, or auto-delete mode in the housekeeping
  tool.** Decided 2026-08-14 after review. Reasons in the plan, §7 rejected
  approach R1 and §8 locked decision D1. Two test cases in the plan's step 5
  exist specifically to stop a future session adding one.
- **No cap on the number of `HANDOFF.d/` files.** Owner ruling 2026-08-13, quoted
  at `skills/shared/handoff-writer/SKILL.md:167-171`. Count handoffs needing
  successor review instead. A closed issue is a review trigger, never proof that
  the handoff is finished.
- **`git branch --merged` is never used.** It misreported 74 of 130 branches in
  `shared-db` because squash merges destroy ancestry. Merged-ness is proven with
  `gh`, or reported as `UNKNOWN`.
- **A historical merged PR is not enough.** The local branch HEAD must exactly
  equal the merged PR's recorded head SHA, and the result is still only a
  `MERGED CANDIDATE` requiring the cleanup-worktree review.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for his multi-model AI
coding workflow: Bash and PowerShell CLIs under `bin/`, global Claude/Codex
instruction templates, repo doc templates, skills, machine setup, and
cross-machine memory. There is no app, database, container, hosted service, or
CI — do not go looking for them. "Green" means the local suites named in
`docs/development.md`. Branch policy is `main` only. Canonical router:
`AGENTS.md`. Albert is a business owner, not a programmer.

## 2. What this session set out to do, and why

Albert closed out a finished handoff file and asked why stale files, worktrees
and branches keep accumulating, and whether the repo has any housekeeping
instructions. That question turned into a diagnosis, an independent model review
that overturned part of it, and then a written implementation plan.

## 3. Current state — what is true right now

**Committed and pushed this session:** `2db96bc` — deleted the finished handoff
`2026-08-12T1959Z-al8960ofc-claude-glm-plan-closed-two-loose-ends.md` after
verifying both of its loose ends were already done (the `HANDOFF.d/` sweep
happened on 2026-08-12; the `glm-permission-failures-a7e4a8` worktree is gone
from `git worktree list`, and its empty leftover folder was removed). `main` has
since moved to `99311f8` by other sessions.

**Committed together originally:** `d5215a2` added
`plan_repo-housekeeping-visibility.md` and this file. **Corrected and pushed on
2026-08-15:** commit `49c5627` repaired the unsafe proof model after a Codex
critique. Do not revert those corrections to the original wording.

**Not started:** all eight steps of the plan.

**Untracked paths that are NOT this session's — leave them alone:** `.ai/`
(gitignored review artifacts) and `docs/claude-remote-control-hardening-v2.md`.

**Measured on 2026-08-14 at `main` = `99311f8`:** 11 registered worktrees besides
the main checkout, 26 local branches, 14 root `plan_*.md` files, 15
`refs/codex/turn-diffs/checkpoints/*` refs, 0 files in `HANDOFF.d/` before this
one.

## 4. Everything we tried that did NOT work

1. **The first proposal was wrong and was cut.** It was one tool with a
   report-only default plus an `--apply` that would clean "the provably-safe
   subset." Three independent objections killed it: merged-ness has no offline
   proof; a clean merged worktree can still hold the only copy of real work (this
   repo's own memory records exactly that near-miss); and deleting a shared file
   is a git commit in a repo several sessions write to at once. If you find
   yourself about to add `--apply` because report-only feels toothless, you are
   re-walking this dead end.
2. **A claim I made and had to retract: "nothing runs on a timer."** False.
   `bin/setup-machine.ps1:688` registers the `ai-memory-sync` Scheduled Task every
   30 minutes on every Windows machine. What is true is that no *housekeeping*
   runs on a timer. The timer machinery exists and is proven, which is what makes
   the plan's step 7 cheap.
3. **A second wrong claim: the squash-merge lesson lives only in `shared-db`.**
   It is physically in this repo at
   `skills/claude/shared-db-handover/SKILL.md:246-258`. What is missing is that
   nothing ever applies it to this repo's own branches.
4. **Attaching the report to the existing `ai-memory-sync` task will not work as
   first imagined.** That task runs through a VBS shim that discards output
   (`bin/setup-machine.ps1:673-677`, `>/dev/null 2>&1`), so a stdout-only report
   would be invisible. The plan's step 7 requires its own log file for this
   reason.
5. **A documentation-only fix is not enough.** The rules already say sessions
   should clean up after themselves, and the pile-up happened anyway. The session
   that could clean up is structurally the one that cannot prove the work landed.
6. **The first committed plan's proof model was unsafe and was corrected on
   2026-08-15.** It treated any merged PR as proof that a worktree's current
   branch landed, treated a closed issue as proof that a handoff was stale,
   described local branches and unusual refs as Git-shared, promised owners the
   available records cannot supply, and left cross-platform process detection
   undefined. The corrected plan requires an exact local-HEAD-to-PR-head match,
   labels the result only `MERGED CANDIDATE`, labels closed-issue handoffs
   `SUCCESSOR REVIEW`, prints `OWNER UNKNOWN`, and leaves deep worktree safety
   checks to the cleanup-worktree procedure.

## 5. Root causes and key findings

**The root cause is the absence of a machine-checkable review signal.** The
handoff standard deliberately assigns deletion to a *later* session
(`skills/shared/handoff-writer/SKILL.md:149-160`), because the writing session
cannot prove its own work landed. That later session cannot prove it either,
because the four-line contract block (`issue:` / `status:` / `owner:`) that would
make ownership and issue state a one-command lookup is optional here — the heading at
`handoff-writer/SKILL.md:60` reads "REQUIRED **where the repo enforces it**", and
this repo enforces nothing. A closed issue is useful evidence but does not prove
that rollout, verification, documentation, or cleanup finished. So the later
session either guesses or repeats the archaeology. That is what left 27 finished
files behind in `shared-db` (issue #658, cleaned 2026-08-13).

That finding is why the plan makes the contract block mandatory (step 3) *before*
building the reporting tool (step 4). It makes ownership and issue state visible.
It deliberately does not turn issue closure into a machine verdict that the
handoff is safe to delete.

**Two live documentation bugs were found and are steps 1 and 2 of the plan:**

- `skills/claude/wrap-up/SKILL.md:59-62` still instructs sessions to warn when
  `HANDOFF.d/` holds more than 5 files. Albert overruled that on 2026-08-13 and
  `handoff-writer/SKILL.md:161-175` explicitly calls any such wording superseded.
  Sessions wrapping up today are following the dead rule.
- `AGENTS.md:403-404` points at "the newest open file under `HANDOFF.d/`" for the
  `916` machine rollout. That file was deleted in an earlier sweep, so the router
  points at nothing. My own deletion earlier today made it worse. General lesson,
  now recorded in the plan: **deleting a handoff without updating the router
  regenerates staleness one level up.**

**Cheap review candidates already visible:** two branches sit on the identical commit
`d6b78e4` (`claude/glm-plan-loose-ends-af75d8` and
`claude/handoff-md-review-921220`); four `codex/issue-976-*` branches exist while
`main` history contains `(#976)` squash commits; and
`claude/context-engineering-consolidation-11f12d` has a branch but no registered
worktree.

**Worktrees can hide.** `.claude/` is gitignored and some worktrees live inside
it, so an inventory must use `git worktree list --porcelain`, never a directory
walk.

**Most root plan files are deliberate records, not litter** — roughly 9 of the 14
are complete and kept on purpose. A sweep keyed on "all STATUS rows done" would
destroy intentional history.

### Independent review

Qwen 3.8 Max (`qwen3.8-max-preview`), read-only, session
`housekeeping-stale-artifacts`, run 2026-08-14 via
`AI_QWEN_CALLER=claude ai-qwen new housekeeping-stale-artifacts --prompt-file <brief>`.
It read the repository itself rather than trusting the brief. It supplied the
root-cause finding, the `--apply` objections, the hidden-worktree and
two-regimes points, and the warning about deliberate plan records. Its report is
at `.ai/reviews/qwen-housekeeping-stale-artifacts-20260814T192916Z.md`, which is
**gitignored and therefore exists only on `al8960ofc`**. Everything from it that
matters is already copied into the plan; do not go hunting for that file on
another machine. Its claims about `wrap-up:61`, `AGENTS.md:403`, the VBS shim,
the plan-file count (14, not 15) and the duplicate-SHA branches were all verified
by hand against the files afterwards. It could not run git or `gh`, so its
statements about which branches are actually merged remain unproven.

## 6. Exact next steps

1. **Commit and push the 2026-08-15 corrections to
   `plan_repo-housekeeping-visibility.md` and this file.**
   Stage only these two paths — several sessions work this repo at once, and
   `.ai/` plus `docs/claude-remote-control-hardening-v2.md` belong to others.
   Verify `git var GIT_COMMITTER_IDENT` reads
   `Albert Hazan <u2giants@users.noreply.github.com>` first. Trailer:
   `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
   You'll know it worked when `git log --oneline -1 origin/main` shows your SHA.
2. **Get Albert's go-ahead (section 0 item 1), then execute Phase A = plan steps
   1-3.** Each has its own verification gate in the plan; do not invent your own.
3. **Cut to a fresh session before Phase B (plan steps 4-6).** That is where the
   tool gets written and it is the bulk of the work. Re-read the plan's remaining
   steps and re-run its §3 measurements first — the counts will have moved.
4. **Update the plan's STATUS table in the same commit as each step**, citing a
   real artifact (a SHA, a test path, a re-runnable command). Never a bare count.

## 7. Constraints and gotchas in force

- Work on `main` in `C:\repos\ai-devops`. Short-lived worktrees are fine and must
  be merged back and removed.
- `git var GIT_COMMITTER_IDENT` must read
  `Albert Hazan <u2giants@users.noreply.github.com>` before your first commit in
  any checkout. Git silently invents an identity when none is set.
- Commit trailer: `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
  (settled by Albert 2026-08-12; older handoffs disagree and are wrong).
- Several AI sessions work this repo at once. Never `git add -A`. Never edit or
  delete another session's `HANDOFF.d/` file. Never rewrite the root
  `HANDOFF.md`; it is a static pointer. Re-check `git log` before trusting any
  STATUS table.
- No band-aids; no silent failures; nothing hard-coded that should be
  configurable.
- Repo-owned `.ps1` files must be pure ASCII, enforced by
  `tests/test-windows-scripts.sh`.
- The full test suite takes roughly 12 minutes. Run it in the background.
- `ai-glm` and `ai-grok-review` are NOT on the Bash tool's `PATH` on this
  machine. Run `ai-glm` from PowerShell; invoke Grok by repo path
  (`bash bin/ai-grok-review ...`). `ai-qwen` DOES work from Git Bash. This has
  cost calls in three sessions now.
- If Codex is used: GPT-5.6 reasoning effort stays explicitly `low` or `medium`.
- No production, shared-cloud, Supabase, NAS, or database work is involved.

## 8. Access and environment

- Repo `C:\repos\ai-devops`, `main`, `https://github.com/u2giants/ai-devops`
  (public).
- Machine `al8960ofc`, Windows 11 Pro, PowerShell 7 primary, user `ahazan2`.
  Machine facts: `templates/system/machine-atlas.md`.
- `gh` is installed and authenticated here. Verify with `gh auth status` before
  assuming it on another machine.
- Shells: Git Bash for Bash scripts, PowerShell 7 for `.ps1` and Scheduled Tasks.
- **No secrets were used, seen, created, or needed. Nothing to sweep to
  1Password.**
- There is no server to start and nothing to deploy for this toolkit.

## 9. Open questions and risks

1. **Will a future session add `--apply` anyway?** This is the single most likely
   way to undo the design. It looks like an obvious missing feature. Three places
   guard it: the plan's non-goals in §1, rejected approach R1, locked decision D1,
   plus two test cases in step 5.
2. **Does the `916` machine rollout still matter?** Plan step 2 forces an answer.
   Last measured 2026-08-12: `<protected-dev-peer-address>:22` refused a connection.
3. **What are the 15 `refs/codex/turn-diffs/checkpoints/*` refs and who owns
   them?** Nobody knows. Deliberately out of scope; the tool will report them.
4. **`issue: none` on this very file** is the weakness the plan is fixing,
   recorded honestly rather than papered over. Section 0 item 2 is how to close
   it.
5. **The Qwen review file is machine-local.** If `al8960ofc` is wiped before the
   plan is finished, that evidence is gone. Everything load-bearing has already
   been copied into the plan, so this is a small risk, not a blocking one.

## Mandatory self-audit

**1. Could a developer who walked in off the street this morning continue with no
questions?** Yes. Section 1 defines the repo, stack, and absence of CI and
deploys; section 8 defines the machine and access. Section 3 gives the original
plan commit, exactly which corrections are uncommitted, the untracked paths
belonging to other sessions, and the
measured counts with their date and base commit. Section 6 gives four ordered
next steps, each with its actor and its proof of success, and points at the plan
for the build detail rather than duplicating it.

**2. Could they continue as effectively as I can right now?** Yes. Section 5
carries the root cause with its `file:line` evidence, both live documentation
bugs, the cheap provable wins, and the two structural traps (hidden worktrees,
deliberate plan records). Section 4 carries six dead ends, three of them my own:
a proposal I had to cut, and two factual claims I had to retract. The independent
review is attributed, dated, its cost-bearing artifact is flagged as
machine-local, and the limits of what it could verify are stated.

**3. Is every category present — background, goals, state, failures, decisions,
constraints, risks, next actions, verification?** Yes. Section 0 separates
blocking from recoverable from settled. Section 7 carries the standing rules
including the commit identity and trailer. Section 9 carries five risks with the
most dangerous one named first and the three guards against it.

**4. If Albert read ONLY section 0, would he see every decision needed from
him?** Yes, checked by walking sections 1 through 9. Two items: approve the start
and decide whether to open a GitHub issue. The session that proves the plan
finished owns deleting this file under the normal successor rule; that is not an
Albert-only decision. Everything else is finished analysis or an instruction to
a future session.

Self-audit re-run and passed on 2026-08-15.
