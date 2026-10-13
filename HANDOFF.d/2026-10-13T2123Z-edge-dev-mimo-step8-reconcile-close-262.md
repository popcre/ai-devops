---
issue: 262
status: OPEN
owner: mimo/edge-dev-win-step6-proof
---

# Step 8 — reconcile both Windows-runner-maintenance host proofs and close #262

## 0. Decisions only Albert can make

**None — nothing in this workstream needs the owner.** Step 8 is a mechanical
reconcile-and-close of already-evidenced work. Technical gates (if any new
mutation were needed) go to an assigned AI reviewer, never to Albert.

**Already settled — do NOT re-ask:**
- 2026-09-28: EDGE-DEV may take Windows CI work to reduce Blacksmith cost, but
  only after its own full GitHub qualification. The runner stays unqualified
  (`ai-devops-windows` label only) until that qualification passes.
- 2026-09-28 / 2026-09-17: The security reviewer, not Albert, judges technical
  maintenance-task repair. No approval exists for rejected recovery commands,
  weakening runner safety checks, or relabelling an unqualified host.
- 2026-10-09/12: Secure Boot and the runner service on edge-dev are host
  preconditions owned by the machine owner, not by this repo's sessions.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public AI/CI recovery toolkit.
`plan_windows-runner-maintenance-elevation.md` (issue
[#262](https://github.com/popcre/ai-devops/issues/262)) delivers one narrow
privileged maintenance operation — `refresh-qualification` — on two Windows CI
hosts (`edge-dev-win` / hostname `EDGE-DEV`, and `EDGE-RUNN-ENVY`), so an
ordinary SSH session can refresh security evidence without general admin power.
Deployment means installation onto those hosts, not a cloud release.

## 2. What we set out to do this session, and why

Finish plan **step 6** (install and prove `edge-dev-win`) exactly as child issue
[#962](https://github.com/popcre/ai-devops/issues/962) requires: repair the
partial/drifted WindowsRunnerMaintenance install while preserving runtime
records, seal+disable the task before unregister (closing the start race),
obtain independent exact-head security APPROVE before live recovery, then prove
the full acceptance matrix. Keep the runner unqualified. Do not touch
EDGE-RUNN-ENVY (already proven, PR #1546) and do not install the uncommitted
draft in the `edge-dev-runner-qualification` worktree.

## 3. Current state — what is true right now

**Complete and landed:**

- Recovery + install + acceptance matrix on `edge-dev-win` recorded in
  https://github.com/popcre/ai-devops/blob/main/tests/verification/windows-runner-maintenance-edge-dev-win-2026-10-09/README.md
- Plan STATUS step 6 is ✅ complete in
  https://github.com/popcre/ai-devops/blob/main/plan_windows-runner-maintenance-elevation.md
- PR https://github.com/popcre/ai-devops/pull/1551 **MERGED** as
  [`b10a8dd3`](https://github.com/popcre/ai-devops/commit/b10a8dd3f9ea3543073eca6a7b0720bf2d435724)
  (2026-10-13). Issues #962 and #262 carry the live-proof comments and the
  merged-commit note.
- Refresh-qualification **SUCCESS** on 2026-10-12 after Secure Boot was enabled
  in EDGE-DEV firmware: non-elevated invoke rc 0, evidence mtime 2026-09-03 →
  2026-10-12 (content never printed), audit SUCCESS with operator SID.
- Runner `edge-dev-win` labels remain
  `self-hosted,Windows,X64,edge-dev,ai-devops-windows` — **unqualified**.

**Still open (this handoff's job = plan step 8):**

- Step 8 "Reconcile and close" is ⬜ open in the plan STATUS. #262 must only
  close after both independent host proofs are evidenced and reconciled.
- Child issue #962 still OPEN; its acceptance items are all evidenced (see
  comments) and can be closed as part of step 8 or just before it.
- Predecessor handoff
  `HANDOFF.d/2026-09-28T1151Z-edge-dev-codex-windows-runner-qualification.md`
  (issue #262, `codex/edge-dev-runner-wrapup`) is still present and still covers
  the separate **GitHub runner qualification** outcome (admitting edge-dev-win
  for ordinary CI). That is NOT this workstream; do not retire that file until
  its own obligations are carried forward.

## 4. Everything we tried that did NOT work

- **`ai-task-gates check --before deploy` with a docs-only change set.** Observed
  class was `prose`; `deploy` is forbidden for that class and the error looked
  like a missing toolkit-install argument. Fixed by declaring `installation` at
  the pre-update HEAD `698554f6`, then moving to the reviewed head so the
  change set is non-empty and the reviewer-APPROVE release path opens. Pattern:
  declare at the pre-update HEAD, then advance the checkout, then check.
- **Declaring `installation` with `--base` far back (16d348fe).** That pulled
  hundreds of files into the change set and escalated the effective class to
  protected `reviewer-safety`, which forbids the generic `deploy` action with no
  release path. Keep the change set narrow.
- **Non-ASCII characters (em-dashes) in a harness `.ps1` under
  `tests/verification/`.** CI `FAIL non-ASCII in .../negproof.ps1` blocked
  merge. Markdown may carry Unicode; `.ps1` harness scripts must be ASCII-only.
- **PR checks failing after a docs-only second push** (`.ai/reviewer-issues`
  boundary failures in `doc-safety`). Cause: the branch was behind `origin/main`
  after main moved. Fix: merge current `origin/main` into the PR branch (do not
  force-push; a normal merge commit is enough) and re-push.
- **`ai-pr-wait` refused from the proof worktree** because the canonical
  checkout's task-gates state belonged to another session (declared `code`,
  observed `reviewer-safety`). Do not clear another session's declaration; poll
  `bin/ai-gh pr checks` / merge-queue state instead, or run from a worktree with
  its own clean declaration.

## 5. Root causes and key findings

- The Oct 8 install on edge-dev verified against its own manifest but the
  installed policy hash was stale vs source (`939e8f58…` vs `255f91de…`).
  `-RecoverPartial -Install` from the reviewed head is the correct repair: it
  preserves runtime request/result/audit/replay records, drops the operator ACE
  and disables before unregister, backs up, then installs fresh. See
  `Recover-MaintenanceInstallation` in
  https://github.com/popcre/ai-devops/blob/main/bin/install-windows-runner-maintenance.ps1
- `Confirm-SecureBootUEFI=False` makes `qualify-windows-runner.ps1` throw
  `Secure Boot must be enabled.` and the worker returns a bounded
  `OPERATION_FAILED` — that is correct fail-closed behavior, not a broken task.
- SSH sessions on EDGE-DEV (and EDGE-RUNN-ENVY) yield a full elevated admin
  token (#1547). Elevated SSH is fine for install/verify/remove; invoke and
  privilege negatives must run from a proven non-elevated token.
- Deploy-gate release for a non-protected forbidden action is available via
  `--reviewer-approval <exact-head APPROVE report>` (see `ai-task-gates`
  forbidden-action path). The report must be a lifecycle-recorded
  `security-review`/`final-check` APPROVE naming the implementer engine.

## 6. Exact next steps

1. From current `origin/main`, open the plan STATUS and both host evidence
   records (ENVY + edge-dev-win). Confirm each `—Verify` still passes on its
   host and that no temporary tasks/backups/request files/locks remain except
   the intentional installed task.
   - ENVY record:
     https://github.com/popcre/ai-devops/blob/main/tests/verification/windows-runner-maintenance-envy-2026-10-09/README.md
   - edge-dev-win record:
     https://github.com/popcre/ai-devops/blob/main/tests/verification/windows-runner-maintenance-edge-dev-win-2026-10-09/README.md
   - Plan STATUS:
     https://github.com/popcre/ai-devops/blob/main/plan_windows-runner-maintenance-elevation.md
   **You'll know it worked when** both rows read complete and both hosts still
   verify.
2. Update the plan STATUS step 8 to ✅ with links to the merged commits, both
   evidence records, and the two review reports. Move the plan to the completed
   table in `docs/implementation-plan-index.md` if that is the repo's practice.
3. Close issue #962 (repair + proof are fully evidenced in its comments) and
   then close #262 with direct links to: merge commits, exact-head reviews, two
   live-host records, unchanged runner services, and rollback proof. The
   step-8 "you'll know it worked when" is in the plan §9.
4. Only after #262 closes, run the successor review on
   `HANDOFF.d/2026-09-28T1151Z-edge-dev-codex-windows-runner-qualification.md`
   and on this file — delete each only when its issue is closed **and** every
   obligation it names is carried forward (especially the separate GitHub
   runner-qualification outcome for edge-dev-win).
5. Do **not** relabel `edge-dev-win` as `ai-devops-windows-qualified` in this
   workstream. That is the separate qualification outcome the predecessor
   handoff owns.

## 7. Constraints and gotchas in force

- Never push to protected `main`; use feature branch + PR + merge queue.
- `bin/ai-gh` for every GitHub call; `bin/ai-pr-wait` only from a worktree with
  a clean task-gates declaration matching the PR.
- Independent exact-head security APPROVE before any protected live-host
  mutation (`ai-review <provider> security-review --implementer <engine>`).
- Do not stop/start/reconfigure/relabel the GitHub runner service. Do not print
  qualification-evidence content.
- The uncommitted draft under the `edge-dev-runner-qualification` worktree is
  diagnostic only — never install it.
- ASCII-only for `.ps1` / shell harness files under `tests/verification/`.
- Runtime request/result/audit/replay records must survive recovery; `-Remove`
  exports them into the protected backup before deleting owned runtime files.
- Two Windows hosts = two separate proofs; never copy one host's facts as proof
  of the other.

## 8. Access and environment

- Repo: `popcre/ai-devops`; target branch `main`; GitHub identity `u2giants`.
- Hosts: Tailscale SSH aliases `edge-dev` (hostname `EDGE-DEV` / runner
  `edge-dev-win`) and `edge-runn-envy`. Local admin user `ahazan` on both.
  Addresses live in the private machine atlas — never commit them.
- Elevated local-admin SSH on edge-dev is the install/verify route; invoke uses
  the non-elevated operator token.
- Reviewers used this session: Muse (`security-review`, implementer `mimo`).
  In-rotation pool also has Grok, Gemini, Qwen, DeepSeek, StepFun, GLM.
- Secrets: none required for this maintenance task. If one ever becomes
  necessary, stop and use 1Password vault `vibe_coding` (item titles only).

## 9. Open questions and risks

- **#1547** (elevated SSH tokens on some Windows hosts) is still open; the
  ENVY/edge-dev-win install-day host adaptation is accepted only for those
  hosts' documented steps. A future host must be re-probed.
- Rollback bundles under `C:\ProgramData\ai-devops\` on edge-dev
  (`windows-runner-maintenance-recovery-*`, `reviewed-maintenance-recovery-edge-dev-win`)
  are intentional protected backups. Confirm they are bounded and admin-owned
  during step 8; do not delete another session's bundles without the successor
  rule.
- The separate **GitHub runner qualification** of `edge-dev-win` (admitting it
  for ordinary CI / adding `ai-devops-windows-qualified`) remains open and is
  owned by the predecessor handoff, not by step 8. Step 8 must not close that
  gap by relabelling.
