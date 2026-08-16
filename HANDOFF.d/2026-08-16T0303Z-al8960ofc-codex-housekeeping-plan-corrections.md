---
issue: none # Albert has not authorized creating a public issue for this workstream
status: OPEN
owner: codex/housekeeping-plan-corrections
---

# HANDOFF — Housekeeping plan safety corrections (2026-08-16T0303Z, al8960ofc/codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

### BLOCKING

1. Approve implementation of
   [`plan_repo-housekeeping-visibility.md`](../plan_repo-housekeeping-visibility.md).
   Recommendation: approve Phase A, steps 1–3, first. No implementation has
   started; this session corrected only the plan and handoff.

### RECOVERABLE

2. Decide whether this workstream should have a GitHub issue. Recommendation:
   create one before implementation so ownership and status are attributable.
   Until then, `issue: none` must honestly remain `UNPROVABLE`.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

None found.

### Already settled — do NOT re-ask

- Report only; never add automatic deletion. Decided 2026-08-14.
- No limit on the number of handoff files. Decided by Albert 2026-08-13.
- A closed issue triggers successor review; it never proves completion. Corrected
  2026-08-15.
- A merged pull request qualifies only as a `MERGED CANDIDATE` when its recorded
  head commit exactly matches the current local branch. It is still reviewed by
  the cleanup-worktree procedure before deletion. Corrected 2026-08-15.

The next implementing session must put both open decisions above to Albert in
one message before starting work.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's toolkit for installing and coordinating
AI coding tools across Windows and Ubuntu machines. It contains Bash and
PowerShell commands, documentation, reusable AI skills, tests, and machine setup
scripts. It has no web application, database, container, hosted service, or CI.
The repository is `C:\repos\ai-devops`, branch policy is main-only, and local
tests listed in `docs/development.md` are the release gate.

## 2. What we set out to do this session, and why

Albert asked Codex to critique the existing housekeeping implementation plan and
its Claude handoff, then said “fix it.” The goal was to make the plan safe and
complete before anyone builds `ai-housekeeping`. The original plan contained
proof rules that could encourage deletion of unfinished work.

## 3. Current state — what is true right now

- The original plan and Claude handoff were committed earlier in `d5215a2`.
- This session corrected
  `plan_repo-housekeeping-visibility.md` and, under Albert's explicit “fix it”
  instruction, its companion
  `HANDOFF.d/2026-08-14T2015Z-al8960ofc-claude-housekeeping-visibility.md`.
- This file is the required Codex closeout handoff. The plan links here and to
  the original companion handoff.
- No implementation code was written and no product tests were required.
- The working checkout was 113 commits behind `origin/main` at closeout and
  contained unrelated work owned by other sessions. Do not stage, rewrite, or
  discard those files. Confirm the final pushed plan correction with:
  `git log -1 --oneline origin/main -- plan_repo-housekeeping-visibility.md`.
- The plan's STATUS table remains open at step 1. There is no deployment.

## 4. Everything we tried that did NOT work

1. The original plan treated any historical merged pull request for a branch as
   proof that a clean worktree was merged. That fails when newer commits were
   added after the merge. The corrected rule requires the current local commit
   to equal the pull request's recorded head commit and still labels it only a
   review candidate.
2. The original plan treated a closed issue as proof that a handoff was stale.
   Issue closure does not prove rollout, verification, documentation, and
   cleanup are finished. The corrected label is `SUCCESSOR REVIEW`; the existing
   three-condition successor rule still controls deletion.
3. The original plan called local branches and unusual Git references shared.
   They are clone-local unless explicitly pushed. The plan now says so.
4. The original goal promised an owner for every artifact although only handoffs
   reliably record one. The detailed report now prints the recorded owner or
   `OWNER UNKNOWN` without guessing.
5. The original design required generic Windows-and-Ubuntu process detection but
   never specified a safe method. Version 1 no longer attempts it; the governed
   cleanup-worktree procedure performs the deep safety review.
6. The original source-text test banned destructive command words while the tool
   was also supposed to print exact deletion commands. The plan now tests actual
   command execution and prints governed procedures instead of deletion commands.

## 5. Root causes and key findings

- A GitHub issue is evidence and an ownership anchor, not a completion oracle.
  See the corrected findings and D3a in the plan.
- Squash merging breaks ancestry-based checks, while branch names can be reused
  after a merge. Exact comparison with GitHub's recorded `headRefOid` prevents a
  historical merge from being mistaken for the current branch contents.
- Even an exact commit match does not inspect ignored files, active processes,
  or other unique local state. That is why the label remains
  `MERGED CANDIDATE` and the cleanup-worktree skill remains mandatory.
- Scheduled logs create history, not visibility. The daily log is diagnostic;
  the wrap-up report is what surfaces the summary to Albert.
- The default command must be a one-screen summary. Per-artifact rows belong
  behind `--details`.

## 6. Exact next steps

1. Before implementation, verify the corrected files are on `origin/main` with
   `git log -1 --oneline origin/main -- plan_repo-housekeeping-visibility.md` and
   read the plan's STATUS table. You will know this worked when the newest commit
   names the safety correction and the table starts at step 1.
2. Put both §0 decisions to Albert in one message. You will know this worked when
   he approves or declines Phase A and decides whether to create an issue.
3. If approved, execute Phase A, plan steps 1–3, updating the STATUS table in the
   same commit with evidence. You will know it worked when the three specified
   verification gates pass and the table records the pushed commit.
4. Start a fresh session for Phase B, re-read the remaining plan, and re-measure
   the repository before coding. You will know it worked when the new session
   begins at step 4 using current counts rather than the 2026-08-14 snapshot.
5. When all eight plan steps are proven complete, retire both open housekeeping
   handoffs under the successor rule. You will know it worked when the plan's
   obligations and decisions remain durably recorded and neither handoff remains
   in `HANDOFF.d/`.

## 7. Constraints and gotchas in force

- Work on `main`; stage only owned files and hunks. Never use `git add -A`.
- Verify `git var GIT_COMMITTER_IDENT` is
  `Albert Hazan <u2giants@users.noreply.github.com>` before committing.
- Never discard or absorb the unrelated working-copy changes listed by
  `git status --short`.
- Never add `--apply`, `--fix`, automatic deletion, `git branch --merged`, or a
  handoff-file count cap.
- Never call a worktree safe based only on a merged pull request or a handoff
  complete based only on a closed issue.
- Never rewrite root `HANDOFF.md`; it is the static pointer.
- GPT-5.6 must run only at low or medium reasoning effort.
- No secrets, production systems, shared cloud, database, NAS, or deployment are
  involved.

## 8. Access and environment

- Machine: `al8960ofc`, Windows 11, PowerShell 7 primary.
- Repository: `C:\repos\ai-devops`; remote: `u2giants/ai-devops`; branch: `main`.
- `gh` and Git are available. Verify authentication with `gh auth status` before
  relying on GitHub status checks.
- Git Bash runs Bash scripts; PowerShell runs setup and Scheduled Task tests.
- No credential was read, created, or changed. No 1Password action is needed.

## 9. Open questions and risks

- The two owner decisions are consolidated in §0.
- The main implementation risk is language drift: future sessions may turn
  `SUCCESSOR REVIEW` or `MERGED CANDIDATE` back into deletion verdicts. Tests 6,
  10, and 11 in plan step 5 exist to prevent that.
- The checkout contained concurrent unrelated edits and was far behind the
  remote. Shipping must isolate only the three files from this session rather
  than pulling through or staging other sessions' work.
- The original Claude handoff was edited only because Albert explicitly asked
  Codex to fix that named file. Future sessions must not treat that as general
  permission to edit another session's handoff.

## Mandatory self-audit

1. Yes, a new developer can continue without asking this session anything. §§1–3
   define the repository, goal, exact files, prior commit, open STATUS step, and
   repository state; §6 provides ordered actions with verification gates.
2. Yes, they can continue as effectively as this session. §§4–5 preserve every
   unsafe assumption found, why it failed, and the replacement proof rules.
3. Yes, failed attempts are included with their failure mechanisms in §4.
4. Yes, every next step in §6 identifies the actor, action, and observable proof.
5. Yes, uncommon labels and identifiers are defined in §§5, 7, and 8; file paths,
   repository, branch, commit, and command locations are explicit.
6. Yes, the §0 sweep covered §§1–9. The only owner judgments found were permission
   to implement and whether to create an issue; both appear in §0 with a
   recommendation. No outside-scope owner decision was found.

Final synthesis:

1. Yes. This handoff is comprehensive enough for a brand-new developer; §§1–9
   cover the full workstream and §6 gives executable continuation.
2. Yes. §§4–5 carry all session knowledge and reasoning, including the rejected
   proof models.
3. Yes. Background, goal, state, failures, decisions, constraints, risks, exact
   actions, and verification evidence are present in §§1–9.
4. Yes. A line-by-line sweep of §§1–9 found two Albert decisions, both listed in
   §0. There are no hidden or outside-scope owner decisions.

Self-audit passed on 2026-08-16 UTC.
