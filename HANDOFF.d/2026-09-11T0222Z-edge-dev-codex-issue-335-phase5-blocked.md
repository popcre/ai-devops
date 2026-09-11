---
issue: 335
status: BLOCKED
owner: codex/issue-335-phase5-blocked
---

# HANDOFF — Issue #335 Phase 5 installation blockers

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking — put both items to Albert in one message before resuming:**

1. Authorize the managed production-host permission repair that adds
   `/worksp/ai-devops` to the existing shared-workspace ownership/ACL policy on
   the Ubuntu host. Recommendation: approve an Ansible branch/PR and its normal
   serialized auto-apply; do not hand-edit the host. This blocks fetching the
   merged Phase 5 repair and completing the Ubuntu install.
2. Authorize governed consolidation of the private `ai-devops` Claude-memory
   index from 17,749 bytes to the existing 12 KB health limit, preserving every
   unique fact. Recommendation: approve the normal private-memory consolidation
   procedure, inspect its result, then rerun the installer. This blocks the
   required private-memory seed stage.

Already settled — do not re-ask:

- On 2026-09-10 Albert completed and accepted Phase 4.
- On 2026-09-11 Albert explicitly authorized starting Phase 5 and following its
  installation and verification gates.
- No application deployment, database write, infrastructure apply, licensed-data
  read, or production action beyond the two exact requests above is authorized.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and engineering-governance
toolkit. Issue #335 distributes a central task-gate policy across 17 canonical
repositories so a small task cannot silently start review, CI waiting,
deployment, database, infrastructure, private-evidence, or production work.
Phase 5 installs the landed policy on supported Windows and Ubuntu machines,
exercises nine controlled risk scenarios, measures the result against Phase 0,
and closes the programme only after every live gate passes.

## 2. What we set out to do this session, and why

Albert explicitly started Phase 5 after Phase 4 completion. The session used a
fresh worktree from current `origin/main`, followed
`HANDOFF.d/2026-09-11T0001Z-edge-dev-codex-issue-335-phase5-boundary.md`, installed
the current toolkit on supported machines, ran the nine-scenario acceptance
battery, measured routing outcomes, and attempted the final closeout gates.

## 3. Current state — what is true right now

- Central repair PR #389 merged through the queue as
  `6550575b9081c768af3ddda6088c24b38267c2a4`. Merge-group run `34553388849`
  succeeded on that exact landing commit.
- The repair makes declared intent and observed changes additive for required
  proofs, uses the stronger class for protection and allowed action, and refuses
  deployment/database/infrastructure/production when both declaration and diff
  are absent. Exact-head Codex review
  `20260911T014603-349751-26603` approved commit `c89ea2a3` before queue landing.
- Evidence is committed at
  `tests/verification/task-gates/phase-5-acceptance.md`. The original gate suite
  passed 84/84; the nine-scenario battery passed 21/21 with zero paid-review
  starts, zero long-wait starts, and zero protected external launches.
- All 17 current default branches expose a compatible policy. Metadata-only
  coverage remains intact for the two private repositories.
- Current startup router metadata is 785,644 bytes versus the Phase 0 total of
  771,588, a 1.8% increase. This is diagnostic, not a failure: unique safety
  capability was preserved, and the key documentation acceptance measure is
  zero expensive launches.
- Windows is installed from exact landed source `6550575b`; the installed
  `ai-task-gates 1.0.0` resolves both `C:/repos/ai-devops` and the linked Phase 5
  worktree, reports `effective_class`, and retains additive gates. The full
  bootstrap cannot run non-interactively without administrator elevation; the
  supported existing-machine installer and machine-command catalog both passed.
- Ubuntu is still installed from `e1f3637e`. Its first installation attempt
  installed that source and passed doctor, but the overall lifecycle returned
  nonzero at the required private-memory seed. The landed-source fetch then
  failed before installation because root-owned read-only Git objects prevent
  user `ai` from writing `.git/objects`.
- Issue #335, parent #159, and dependency #166 correctly remain OPEN. Phase 5
  must not be called complete and the earlier Phase 5 boundary handoff must not
  be deleted yet.

## 4. Everything we tried that did NOT work

- The first Windows full bootstrap requested Administrator elevation and exited
  before machine-wide changes. Repeating it unchanged is not useful. The normal
  supported update path for an already-provisioned host succeeded instead and
  preserved differing user globals.
- The first nine-scenario battery exposed that declared production intent did
  not supply active gates and that a clean checkout could enter protected
  actions. The first repair chose only the stronger class; exact-head review
  `20260911T005648-298059-120` rejected it because that dropped lower-class
  deployment proofs. The landed repair unions required proofs instead.
- A subsequent review returned BLOCKED rather than APPROVE because its sealed
  packet could not see local test results. Committing the concise evidence record
  fixed that evidence gap; the final exact-head review approved.
- PR #389's first run `34551876913` failed because the new Bash suite raised the
  manifest count from 72 to 73 while `tests/test-workflow-policy.sh` still
  expected 72. The count was corrected; the new run `34551970400` passed every
  Linux, Windows, reviewer-safety, classifier, and start-deadline job.
- Ubuntu's `install.sh` returned nonzero after every other required stage passed:
  private-memory health rejected the outgoing union because the `ai-devops`
  index is 17,749 bytes. No rejected memory union was published.
- The later Ubuntu fetch of landing commit `6550575b` failed with
  `insufficient permission for adding an object to repository database
  .git/objects`. Inspection found root-owned mode-0444 objects. The documented
  `/home/ai/permfix/setup-shared-worksp.sh` does not include `ai-devops`, and the
  login banner forbids hand edits because the host is Ansible-managed.

## 5. Root causes and key findings

- `bin/ai-task-gates` previously treated the declaration only as a drift ceiling.
  Phase 5 proved that production intent must strengthen observed deployment
  files without replacing their tests and release proof.
- The correct contract is: effective protection equals the stronger class;
  required proofs are the union of declared and observed classes; forbidden
  actions come from the effective class. This is documented in
  `docs/context-spec.md` and `docs/development.md`.
- A clean checkout is legitimate for shipping and review queries, but protected
  external actions need an explicit declaration when there is no diff to classify.
- Router size alone is not the acceptance measure. Live metadata increased 1.8%,
  while all nine trigger scenarios selected the intended protection and the
  documentation case started no expensive gate.
- Ubuntu has two separate blockers: source-fetch permissions and private-memory
  health. Fixing only one will still leave `install.sh` nonzero.
- The protected machine atlas says shared `/worksp` permissions are governed,
  but the installed repair script's repository list omits `ai-devops`. That drift
  belongs in `u2giants/ansible`, not as a manual server change.

## 6. Exact next steps

1. Obtain Albert's single consolidated authorization for both Section 0 items.
   You will know the gate is open when he explicitly approves the Ansible-managed
   `/worksp/ai-devops` permission repair and private-memory consolidation.
2. In a fresh current-upstream `u2giants/ansible` worktree, read its `AGENTS.md`,
   declare the strongest applicable task class, locate the owner of the shared
   `/worksp` permission baseline, and add only `/worksp/ai-devops`. Use its
   branch/PR, exact-head review, CI, serialized auto-apply, and live verification
   gates. You will know it worked when user `ai` can fetch into
   `/worksp/ai-devops/.git/objects` and the managed configuration remains clean.
3. Run the governed private-memory consolidation for the `ai-devops` project on
   Ubuntu, preserving unique facts and keeping the hub private. Do not relax the
   12 KB limit or discard the rejected ref. You will know it worked when
   `ai-memory-health --hub-only --coverage-only --ignore-sync-state` reports zero
   findings and the index is at or below 12 KB.
4. Fetch current `origin/main` as user `ai`, switch the clean installation
   checkout to exact current main, declare `installation`, and run `install.sh`
   once. You will know it worked when the stage summary has no required failure,
   doctor reports the exact installed SHA, and installed `ai-task-gates explain
   --json` proves the Ubuntu repository identity and `effective_class`.
5. Reconfirm Windows installed source still equals current `origin/main`; rerun
   only if main changed. Then update the Phase 5 evidence with both exact live
   installation SHAs and the final landed-within-session outcome. You will know
   this is complete when both supported environments have green live proof.
6. Re-read every remaining Phase 5 step through plan completion and report any
   drift caused or discovered by Steps 1–5. Then update the plan to Completed,
   close #335 with commit/PR/test evidence, update #159 and its STATUS, unblock
   #166, and delete both open Issue #335 handoffs in the completion commit. You
   will know the programme is complete only when those live issue, plan, handoff,
   and `origin/main` states agree.

## 7. Constraints and gotchas in force

- Do not hand-edit permissions on the Ansible-managed Ubuntu host. Production
  infrastructure changes require Albert naming the exact resource and action.
- Do not consolidate, delete, or publish private memory without Albert's explicit
  authorization. Preserve the rejected recovery ref and every unique fact.
- Do not rerun either deterministic failure unchanged. Repair permissions before
  fetch; repair memory health before the next full installer run.
- No database, application-data, application deployment, Terraform apply,
  licensed-data read, or unrelated production mutation is authorized.
- Use isolated current-upstream worktrees, verify Git identity before commit,
  and preserve the independent exact-head review gate for safety paths.
- Do not run local Windows reviewer suites while the host's GitHub runner is busy.
- Do not close #335 or unblock #166 from partial installation evidence.

## 8. Access and environment

- Current continuation branch: `codex/issue-335-phase5-blocked`, based on
  `origin/main` at `6550575b` in
  `C:/repos/ai-devops-worktrees/issue-335-phase5`.
- GitHub CLI, Git, and the installed task-gate/reviewer commands are authenticated
  on EDGE-DEV. Git Bash is `C:/Program Files/Git/bin/bash.exe`.
- Ubuntu access uses the protected SSH configuration supplied by
  `ai-private-config`; the repository is `/worksp/ai-devops`, user `ai`. Concrete
  topology stays in the private machine atlas and must not be copied publicly.
- Secrets and protected configuration remain in 1Password vault `vibe_coding`
  and the private configuration repository. No secret value belongs in this
  handoff or any public issue.

## 9. Open questions and risks

- Owner decisions: exactly the two Section 0 authorizations; there are no hidden
  third decisions elsewhere in this handoff.
- The Ansible source owner for the shared-workspace permission list must be
  discovered from its current router after authorization; do not assume the old
  standalone script is still canonical.
- Private-memory consolidation can lose useful context if performed as size-only
  deletion. The acceptance gate is health plus preservation, not merely a smaller
  file.
- `origin/main` may advance while the blockers are resolved. Re-resolve it before
  every install and final closeout; do not reuse `6550575b` as current proof.

## Self-audit

1. Yes — Sections 1–3 explain the toolkit, the Phase 5 goal, exact merged repair,
   tests, installations, and remaining blockers for a new developer.
2. Yes — Sections 4–5 preserve every failed attempt, rejection, CI correction,
   and the two independent Ubuntu root causes needed to continue effectively.
3. Yes — Sections 0–9 cover background, outcome, current state, failures,
   decisions, constraints, risks, access, evidence, and ordered verification
   steps through programme completion.
4. Yes — a line-by-line sweep of Sections 1–9 found only the two owner actions in
   Sections 3–7; both are consolidated in Section 0 with recommendations and
   blocking consequences. No sub-agents were used.
