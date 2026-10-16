# Implementation plan — edge-dev reviewer repair without AI reviewers

## STATUS — read first; do not re-derive completed programmes

Owner: this plan. Coordinate on the open edge-dev incident card
[#1678](https://github.com/popcre/ai-devops/issues/1678) (and the two local
incidents named in §3). Sibling plan for edge-dev3 common-layer work:
[`plan_reviewer-recurrence-repair.md`](plan_reviewer-recurrence-repair.md) —
reuse its shared lifecycle/packet work; do **not** rewrite it here.

Planning snapshot: October 15, 2026, 9:48 PM EDT (2026-10-16T01:48Z).
Implementation has **not started**.
Handoff: [execution brief](HANDOFF.d/2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md).

| Step | Work | State / date | Evidence required to advance |
|---|---|---|---|
| 0 | Enforce the no-review landing contract | ⬜ open — 2026-10-15 | Every PR shows `ai-task-gates explain` effective class `prose` or `code` only |
| 1 | Freeze edge-dev incident inventory and class map | ⬜ open — 2026-10-15 | Sanitized inventory under `tests/verification/edge-dev-reviewer-repair/` |
| 2 | Repair StepFun Windows shell spawn | ⬜ open — 2026-10-15 | Offline fixture + live `ai-stepfun` ask/review starts a shell |
| 3 | Repair GLM REVISE re-review waste | ⬜ open — 2026-10-15 | Fixture proves one follow-up, not a forced full re-review |
| 4 | Repair durable report publish and sandbox non-interference | ⬜ open — 2026-10-15 | Completed review yields a durable report path; foreign orphans intact |
| 5 | Repair Windows Git Bash / ProgramFiles detection | ⬜ open — 2026-10-15 | `tests/test-windows-bash-selection.sh` green with empty ProgramFiles |
| 6 | Live smoke + incident disposition (no paid blast) | ⬜ open — 2026-10-15 | Two local incidents resolved/partially-resolved with exact evidence |
| 7 | Install code-only release and re-prove | ⬜ open — 2026-10-15 | Installed hashes match merged source; smoke still green |

Fresh session starts at **step 0**, then **step 1**. A row is done only with an
openable artifact (file under `tests/verification/`, command output, or merged
SHA). Do not invent a resolved status.

## 1. Ultimate goal

Albert can ask for an independent review **on this computer (edge-dev)** and get
a trustworthy decision without another repair session, lost paid work, or a
reviewer tool that will not start.

This programme is the bootstrap: the review fleet is what is broken, so the
repair itself must land **without using AI reviewers as a gate**. When this is
done, the two open edge-dev incidents are disposed with evidence, StepFun can
start on Windows, GLM does not force a full re-review after REVISE, finished
reviews are durably stored, and Git Bash is found even when `ProgramFiles` is
empty.

**If a step conflicts with this goal, the goal wins — stop and flag it.**

Do not buy apparent reliability by removing a provider, suppressing errors,
accepting incomplete output, skipping tests, weakening source/evidence checks,
or weakening the protected `reviewer-safety` class for everyone else.

## 2. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert's public AI
workflow toolkit: Bash/Python/Node/PowerShell reviewer wrappers, doors, tests,
docs and installers. It is not a hosted service and has no application database.
`main` is protected and uses a merge queue. Installation is deployment.

**This computer is `edge-dev`** (Windows, Git Bash / MINGW). Runtime launchers
resolve into the canonical checkout `C:\repos\ai-devops`, which is
landing-only — never `git pull` or edit it for feature work. Every write task
uses its own worktree from fresh `origin/main` (this planning worktree:
`C:\repos\ai-devops-wt-reviewer-no-review`).

Sibling host **edge-dev3** (Linux) carries
[`plan_reviewer-recurrence-repair.md`](plan_reviewer-recurrence-repair.md)
(issue #1783). Share common-layer fixes with that plan; do not duplicate its
steps. Edge-dev Windows-only failures (shell spawn, Git Bash path, wrapper
door wiring on MINGW) belong here.

Primary layers and terms (same vocabulary as the sibling plan):

- `bin/ai-review` / `bin/ai-review-pool` — selection and entrypoints.
- `tools/lib/review-doors/*.sh`, `tools/lib/review-lifecycle-core.sh`,
  `tools/lib/provider-wrapper-common.sh` — shared execution and lifecycle.
- `bin/ai-review-packet`, `bin/ai-review-sandbox`, `tools/reviewer_events.py` —
  snapshots, receipts, durable evidence, safe cleanup.
- A **packet** is the review input and exact source identity; a **receipt**
  binds packet to source; a **terminal verdict** is the final completed
  decision; a **door** is the per-provider runner script; a **cold** session is
  new provider state, **warm** is a follow-up, **fresh-process** is a new
  wrapper process.

## 3. Trigger and reproducible observations

Albert asked why reviewers still fail on this computer, then asked for a plan
to fix it, with the constraint that **implementing the plan must not need
reviewers** (this chat, 2026-10-15).

Local open incidents on edge-dev at planning time (`ai-reviewer-issue list`):

| Local incident ID | Symptom (sanitized) | Reproduction target |
|---|---|---|
| `20261014T203826Z-edge-dev-stepfun-2686842` | StepFun OpenCode cannot spawn a shell (`ChildProcess.spawn` NotFound) | Windows door + OpenCode profile + shell gate launches a shell |
| `20261014T201712Z-edge-dev-glm-2563781` | Forced full re-review cycle after a REVISE decision | Follow-up after REVISE reuses the same conversation/source binding |

Related open GitHub cards to reuse (do not open duplicates):
[#1678](https://github.com/popcre/ai-devops/issues/1678) (open incident repair),
[#1467](https://github.com/popcre/ai-devops/issues/1467) (Windows sandbox
commands), [#1701](https://github.com/popcre/ai-devops/issues/1701) (Git Bash
detection when ProgramFiles is empty), [#1405](https://github.com/popcre/ai-devops/issues/1405)
(DeepSeek leftovers), [#1370](https://github.com/popcre/ai-devops/issues/1370)
(StepFun startup/large input — coordinate with edge-dev3 owner).

Do not copy raw private incident bodies into this public plan.

## 4. Scope: in and out

**In:** the two open edge-dev local incidents; StepFun Windows shell spawn;
GLM REVISE re-review waste; durable report publish / orphan non-interference on
this host; Git Bash/ProgramFiles detection; code-class fixes in doors, shared
libs, config and tests; live smoke and incident disposition on edge-dev;
code-only install of the merged repair.

**NOT in this plan:** rewriting all eight wrappers; reinventing the packet or
lifecycle (reuse sibling plan and `plan_reviewer-pipeline-core.md`);
reactivating frozen providers; changing models, turn budgets, or paid-key
policy; shared-db structure; infrastructure/production; transcript mining;
secret rotation; a new daemon/ledger/dashboard; deleting evidence or worktrees
by age; weakening `config/task-gates.json` protected classes for the whole
fleet; landing any change whose effective class is `reviewer-safety` or higher
under this programme (see §8).

## 5. Current state of the code

Line anchors are navigation aids against `origin/main` at planning time
(`9acc9b1e`). Re-locate after upstream movement.

| Source anchor | Class under `ai-task-gates` | Existing behavior |
|---|---|---|
| `tools/lib/review-doors/stepfun.sh` | **code** | Windows path is OpenCode folder + test shell (owner 2026-09-30). Prefer fixing spawn/profile here. |
| `tools/lib/stepfun-sandbox.sh` | **code** | Sandbox helpers for the StepFun Windows gate. |
| `config/opencode-stepfun/**` (e.g. `opencode.json`, `agent/stepfun-review-windows.md`) | **code** | OpenCode profile for Windows review. First place to fix `ChildProcess.spawn` NotFound. |
| `tools/lib/review-lifecycle-core.sh` | **code** | Shared verdict parse (`## Verdict`); publish/lifecycle helpers. |
| `tools/lib/provider-wrapper-common.sh` | **code** | Shared wrapper helpers. |
| `tools/lib/review-doors/*.sh` (other providers) | **code** | Per-provider doors. GLM REVISE logic may live in lifecycle/pool, not `bin/ai-glm`. |
| `tests/test-*.sh`, `tests/lib-*.sh` | **code** | Offline fixtures. |
| `config/reviewer-registry.json`, `config/review-runner-doors.json` | **code** | Registry and door table. |
| `bin/setup-opencode-*.sh` | **code** | OpenCode setup. |
| `bin/ai-stepfun`, `bin/ai-stepfun-windows-shell`, `bin/ai-glm`, `bin/ai-muse`, `bin/ai-codex-review`, `bin/ai-review*`, `tools/reviewer_*.py`, `config/task-gates.json` | **reviewer-safety (protected)** | Wrapper entrypoints and safety tools. **Do not edit under this programme.** |
| `docs/*.md`, `plan_*.md`, `HANDOFF.d/**` | **prose** | Plans and handoffs. |

Class map was measured with
`bin/ai-task-gates explain --paths-from -` on the candidate lists above at
planning time. Re-run that command before each PR.

Installed state on edge-dev is **not** asserted by this plan. Step 1 records
installed launcher hashes and receipt; do not claim install is healthy from a
source checkout alone.

## 6. Key findings and root cause

1. **Chicken-and-egg.** `reviewer-safety` is `protected: true` and requires
   `exact-head-independent-review` (`config/task-gates.json`). Wrapper
   entrypoints are in that class. A fleet that cannot review cannot approve its
   own repair through that gate. Owner direction (Albert, 2026-10-15) is that
   **this repair must implement without reviewers**.
2. **Most repair targets are already `code`.** Doors, lifecycle, sandbox
   helpers, OpenCode profiles, registry/config and tests land with
   `local-tests` only. The no-review path is real if fixes stay on those paths.
3. **StepFun Windows spawn** is almost certainly the OpenCode profile or
   sandbox/shell setup (`ChildProcess.spawn` NotFound), not a missing wrapper.
   Fix in `config/opencode-stepfun/**` and `tools/lib/stepfun-sandbox.sh` /
   `tools/lib/review-doors/stepfun.sh`.
4. **GLM “forced full re-review after REVISE”** is lifecycle/pool behavior about
   reusing a conversation after a non-final decision. Look in
   `tools/lib/review-lifecycle-core.sh` and `bin/ai-review-pool` (pool is
   `reviewer-safety` — if the defect is only there, prefer a door/common fix; if
   the only fix is `bin/ai-review-pool`, see §8 escalation).
5. **Report durable publish** (Oct 5 handoff) and **orphan sweep interference**
   are shared-layer. Sibling plan owns the deep receipt protocol; this plan
   only lands the Windows-observable non-interference and publish fixes that
   stay in `code` paths.
6. **Git Bash detection** when `ProgramFiles` is empty (#1701) is a Windows
   environment bug in launcher selection (`tests/test-windows-bash-selection.sh`
   already names the suite).

## 7. Approaches considered and REJECTED

- **Get an independent AI review to land the fixes.** Rejected: the fleet is
  the defect; Albert ordered a no-review implementation. Also circular.
- **Admin-merge or force-push to `main`.** Rejected: forbidden; merge queue is
  required.
- **Weaken `reviewer-safety` / drop `exact-head-independent-review` from
  `config/task-gates.json`.** Rejected: that file is itself protected safety
  policy; removing the gate for the whole fleet is a safety regression and
  would itself need the gate.
- **Broad rewrite of every wrapper.** Rejected: scope explosion; most bugs are
  below the entrypoints.
- **Delete frozen providers or silence errors to go green.** Rejected: owner
  wants callable capability preserved; silent failure is a lie.
- **Reuse `plan_reviewer-recurrence-repair.md` as-is for this host.** Rejected
  as a substitute: that plan is edge-dev3-scoped and its step 7 still mandates
  independent review. We **link** it for shared-layer work and do not fork its
  receipt protocol redesign.
- **Touch `bin/ai-*` entrypoints “just to be safe”.** Rejected: those files
  escalate the change set to protected `reviewer-safety` and reintroduce the
  gate we are avoiding.

## 8. Design decisions already made

**Locked (do not relitigate):**

| Decision | Date / source | Reasoning |
|---|---|---|
| Implementation must not need AI reviewers | Albert, 2026-10-15, this chat: “knowing that the reviewers don't work, make sure implementing it doesn't need reviewers” | Owner bootstrap constraint for this programme |
| Every PR change set stays `prose` or `code` | this plan step 0 | Those classes require no AI review (`config/task-gates.json` gates table) |
| No step may call `ai-review`, `ai-review-pool`, or any `ai-*` provider wrapper as a merge, CI, or install gate | this plan | Broken fleet cannot be a dependency |
| Proof substitute: focused offline tests + merge-queue CI + live smoke on edge-dev | this plan | Same bar as `code` class `local-tests`, plus real capability |
| Do not edit `bin/ai-*` entrypoints, `tools/reviewer_*.py`, or `config/task-gates.json` under this programme | this plan | Those paths are protected `reviewer-safety` |
| Prefer door / shared-lib / OpenCode-profile / config / test fixes | this plan | Those files already classify as `code` and are sourced by wrappers |
| Reuse sibling plan and existing issues/owners | AGENTS.md; `plan_reviewer-recurrence-repair.md` | No duplicate programme |
| Preserve capability; never delete evidence to clear warnings | standing rules | Fail closed with evidence |

**Open (implementer judgment):** exact OpenCode profile field that causes
`ChildProcess.spawn` NotFound; whether GLM REVISE waste is fixed in lifecycle
vs. a door-local follow-up path; smallest fixture that proves durable publish
on Windows paths; how far Git Bash detection should search when `ProgramFiles`
is empty.

**Escalation (only if a fix is impossible in `code`/`prose`):** stop that step
as `Blocked —` and record the exact file path and its observed class from
`ai-task-gates explain --paths-from -`. Do **not** edit a `reviewer-safety` file
under this plan. Options after that report: a separate explicitly reviewed
workstream (outside this plan), or a future owner decision to change policy.
Never “just ship” a protected path.

## 9. The plan — numbered, ordered, executable steps

### Phase 0 — contract (no code change)

**Step 0 — enforce the no-review landing contract.**

- What: before any implementation PR, re-read §8. Create the worktree from
  fresh `origin/main`. Run `bin/ai-task-gates start --class code` (or `prose`)
  with a reason naming this plan. Before every commit/PR run
  `bin/ai-task-gates explain` and copy the `effective class` line into the PR
  body. If it is not `prose`/`code`, split or rewrite the change until it is.
- Done when: PR template/body shows an effective class of `prose` or `code` and
  never names a reviewer report.
- Depends on: none.
- **Verification gate:** `bin/ai-task-gates explain` on the PR change set prints
  `effective class  : code` (or `prose`) and `required gates` does **not**
  contain `exact-head-independent-review`.

### Phase A — inventory

**Step 1 — freeze edge-dev inventory and class map.**

- What: in a worktree, run `bin/ai-reviewer-issue list` and `show` on the two
  open IDs in §3; record sanitized facts only under
  `tests/verification/edge-dev-reviewer-repair/README.md`. Re-run
  `ai-task-gates explain --paths-from` on every candidate fix file and paste
  the class map into that README. Record `git rev-parse origin/main`, hostname
  `edge-dev`, and (read-only) installed launcher paths/hashes if readable
  without secrets. Refresh #1678 / #1467 / #1701 / #1370 ownership; claim only
  unowned bounded work on the existing issue.
- Files: `tests/verification/edge-dev-reviewer-repair/README.md` (new).
- Done when: every open edge-dev incident has a planned disposition row
  (repair in this plan / defer to sibling / already fixed / evidence-unavailable).
- Depends on: step 0.
- **Verification gate:** README exists; class map covers every file later PRs
  touch; `bash tests/test-markdown-links.sh` passes.

### Phase B — repairs that stay in `code`

**Step 2 — StepFun Windows shell spawn.**

- What: reproduce `ChildProcess.spawn` NotFound from
  `config/opencode-stepfun/` + `tools/lib/review-doors/stepfun.sh` +
  `tools/lib/stepfun-sandbox.sh`. Typical causes: profile names a shell binary
  that is not on PATH on MINGW; wrong cwd; Windows gate path not executable;
  OpenCode `opencode.json` spawning a Unix-only binary. Fix the profile/door/
  sandbox helper. Do **not** edit `bin/ai-stepfun` or
  `bin/ai-stepfun-windows-shell`.
- Behavior when done: `ai-stepfun` Windows path starts OpenCode with a working
  shell; a trivial ask/review gets past spawn.
- Tests: extend `tests/test-ai-stepfun.sh` and/or
  `tests/test-ai-stepfun-windows-shell.sh` with a fixture that fails when the
  spawn target is missing and passes when the configured shell resolves.
  Add named case `stepfun_windows_shell_spawn_resolves`.
- Depends on: step 1.
- **Verification gate:** `bash tests/test-ai-stepfun.sh` (and the windows-shell
  suite if present) green; live smoke in step 6 starts a shell.

**Step 3 — GLM REVISE does not force a full re-review.**

- What: trace post-REVISE flow in `tools/lib/review-lifecycle-core.sh` and any
  `tools/lib/review-doors/` follow-up helpers. Desired behavior: a REVISE
  decision allows a **same-conversation follow-up** on the corrected head
  without discarding paid work and without dispatching a brand-new full review
  when identity/source binding still matches. If the only code that forces a
  cold re-review lives in `bin/ai-review-pool` or `bin/ai-glm`, prefer a door/
  lifecycle hook those files already call; if impossible, escalate per §8.
- Tests: fixture `glm_revise_followup_reuses_bound_turn` in
  `tests/test-ai-glm.sh` or `tests/test-ai-review-engine.sh` / lifecycle tests
  (whichever exists on current source — verify names before inventing).
- Depends on: step 1.
- **Verification gate:** fixture green; no change to protected entrypoints.

**Step 4 — durable report publish and orphan non-interference.**

- What: ensure a completed review’s report is published durably through
  `tools/lib/review-lifecycle-core.sh` / existing publish helpers even on
  Windows paths. Ensure foreign orphan sandboxes do not mutate or block a new
  invocation (align with sibling plan step 2 semantics; implement only what is
  still missing and class-safe). Preserve bounded sweep; never delete foreign
  evidence.
- Tests: `tests/test-ai-review-engine.sh`,
  `tests/test-ai-review-sandbox-self-cleanup.sh` — cases
  `durable_report_publish_survives_process_exit` and
  `foreign_orphans_do_not_block_fresh_review` if not already present.
- Depends on: steps 1–2 (StepFun smoke needs spawn first).
- **Verification gate:** offline suites green; live smoke returns a durable
  report path with VERDICT + head SHA.

**Step 5 — Git Bash / ProgramFiles detection.**

- What: fix launcher/bash discovery so an empty or missing `ProgramFiles` still
  finds Git Bash (issue #1701). Likely helpers under `bin/` or `tools/` used by
  `*.cmd` launchers — confirm the owning file’s class first; stay in `code`.
  Keep the `.cmd` wrapper pattern.
- Tests: `tests/test-windows-bash-selection.sh` must cover empty ProgramFiles
  and still resolve `C:\Program Files\Git\bin\bash.exe` or the known fallback.
- Depends on: step 1 (can run parallel with 2–4).
- **Verification gate:** `bash tests/test-windows-bash-selection.sh` green.

### Phase C — proof and install

**Step 6 — live smoke and incident disposition.**

- What: on edge-dev, without using a formal AI review as a gate, exercise the
  fixed paths: StepFun starts a shell and produces a terminal-shaped report
  (public disposable source is enough; do not burn paid credits on a full
  governed shared-db review unless already authorized elsewhere); GLM path
  demonstrates follow-up after REVISE in offline or disposable live form;
  durable publish leaves an openable report. Then
  `bin/ai-reviewer-issue resolve` (or `partially-resolved`) for
  `20261014T203826Z-edge-dev-stepfun-2686842` and
  `20261014T201712Z-edge-dev-glm-2563781` with exact merged repair SHA and
  evidence paths. Update #1678 checklist on the **same** issue (no proof-only
  ticket).
- Depends on: steps 2–5 merged.
- **Verification gate:** both incidents resolved or partially-resolved with
  evidence; smoke commands listed in
  `tests/verification/edge-dev-reviewer-repair/README.md` with exit status.

**Step 7 — install the code-only release and re-prove.**

- What: if the merged release contains **only** `prose`/`code` classes (it
  must, per step 0), install through the supported installer path that does not
  require `exact-head-independent-review`. Never `git pull` the canonical
  checkout. Follow `docs/deployment.md` for the ordinary/code-only update route
  that applies; if the installer still demands a reviewer report because the
  release classifier saw a safety path, **stop** and report `Blocked —` with
  the unexpected class — do not bypass.
- After install: verify launcher hashes and re-run step 6 smoke.
- Depends on: step 6.
- **Verification gate:** installed command hashes match merged source; smoke
  still green; STATUS rows updated.

### Natural context cut points

After phase A (step 1) and after phase B (steps 2–5) use `fresh-session` if
context is low; re-read this STATUS and the sibling plan for drift before
continuing. Steps 2–5 may be parallel across different doors only if they do
not share one file; serialize any edit to `tools/lib/review-lifecycle-core.sh`.

### Adversarial-cases table (trust boundaries)

External inputs here are provider text, filesystem paths, and Windows
environment variables. Every row names a required test.

| External input | Hostile case | Required test |
|---|---|---|
| OpenCode profile / PATH | Shell binary missing or wrong name | `stepfun_windows_shell_spawn_resolves` — `tests/test-ai-stepfun.sh` or `test-ai-stepfun-windows-shell.sh` |
| Provider stream | Ends at `tool-calls` / no terminal verdict | keep existing non-completion refusal in lifecycle tests — `tests/test-ai-review-engine.sh` |
| Report text | Earlier APPROVE quoted plus a new verdict | existing extra-decision refusal — `tests/test-ai-review-engine.sh` / door tests |
| Filesystem | Symlink/replaced report parent | existing packet/receipt guards — `tests/test-ai-review-packet.sh` |
| Orphan backlog | Foreign live sandbox present | `foreign_orphans_do_not_block_fresh_review` — `tests/test-ai-review-sandbox-self-cleanup.sh` |
| Environment | `ProgramFiles` empty/missing | `tests/test-windows-bash-selection.sh` case for empty ProgramFiles |
| Process | Unrelated test fixture running | no broad process kills; ownership checks in sandbox delete-guard tests |

## 10. Tests required

Named suites that must stay green after each step (verify they exist on current
source; do not invent a pass for a missing suite):

- `bash tests/test-ai-stepfun.sh`
- `bash tests/test-ai-stepfun-windows-shell.sh` (if present)
- `bash tests/test-ai-review-engine.sh`
- `bash tests/test-ai-review-lifecycle.sh`
- `bash tests/test-ai-review-sandbox-self-cleanup.sh`
- `bash tests/test-ai-review-sandbox-delete-guard.sh`
- `bash tests/test-ai-glm.sh` / `bash tests/test-ai-review-preflight.sh` when
  touching those layers
- `bash tests/test-windows-bash-selection.sh`
- `bash tests/test-markdown-links.sh`
- `bin/ai-doc-reachability --base origin/main` (docs in the PR)

Run only affected suites per step; use `bin/ai-test-local --check-collision`
before a local full series. Isolate event/scoreboard stores as the existing
harness requires. No live provider calls inside offline tests.

## 11. Constraints, standing rules, and gotchas in force

- **No AI reviewer is a dependency of this programme** (owner, 2026-10-15).
  Do not call `ai-review` / pool / provider wrappers as a gate. Do not weaken
  protected classes for the fleet.
- Branch + PR + merge queue; never push `main`; never `--admin`.
  `git var GIT_COMMITTER_IDENT` must show Albert’s identity before commit.
  Stage only task-owned files (this repo’s canonical checkout is landing-only —
  always use a worktree).
- Declare `ai-task-gates start --class code` (or `prose`) before work; re-check
  `explain` before every PR. If effective class escalates, split the PR or stop
  per §8.
- Secrets: 1Password `vibe_coding` only; never in logs/args/commits. No
  credential work is required to write or land this plan.
- Live proof before closing an outcome; keep checklists on the **same** issue.
- Human times in EST/EDT. Do not invent elapsed intervals.
- PowerShell-compatible; Bash tests via Git Bash. Keep `.cmd` launcher pattern.
- Networking-only machines (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`):
  never install the toolkit there.
- Reuse existing plans/issues; no second receipt protocol; no new daemon.
- Documentation-only PRs may merge without discretionary review (this plan’s
  publication is prose-only).

## 12. Access and environment

- Host: `edge-dev` (Windows). Git + GitHub via `bin/ai-gh`. Canonical checkout
  `C:\repos\ai-devops` (landing-only). Worktrees under `C:\repos\ai-devops-wt-*`.
- Tools: Git Bash (`C:\Program Files\Git\bin\bash.exe`), Python via
  `$MIMO_PYTHON` when set, `jq`, `rg`.
- Private incident store: `bin/ai-reviewer-issue path` (do not copy raw bodies
  into the public repo).
- No new secrets. No web server. No shared-db writes.
- Planning checks for this document: `git diff --check`,
  `bash tests/test-markdown-links.sh`, `bin/ai-doc-reachability --base origin/main`.

## 13. Definition of done + risks and open questions

### Planning deliverable (this document)

- [x] 13 sections complete; STATUS table present; handoff reciprocal links.
- [x] Self-audit answers recorded below.
- [ ] Prose PR merged to `main`; AGENTS.md / task-router links live.
- [ ] #1678 (or the named incident issue) notes plan publication; repair
      checklist remains open.

### Repair deliverable (not done by publishing this plan)

- [ ] Step 0 contract held on every implementation PR (effective class
      `prose`/`code` only).
- [ ] Both local edge-dev incidents resolved or partially-resolved with exact
      evidence and merged SHA.
- [ ] StepFun spawns a shell on Windows; GLM REVISE follow-up does not force a
      cold full re-review; completed reviews leave durable reports; Git Bash
      resolves with empty ProgramFiles.
- [ ] Named tests green; live smoke recorded in
      `tests/verification/edge-dev-reviewer-repair/README.md`.
- [ ] Code-only install verified (hashes + smoke); STATUS updated; no leftover
      obligation without an owner.

**Risks:** a bug that only exists inside a protected `bin/ai-*` entrypoint
(then stop per §8); installer misclassifying a code-only release as
reviewer-safety (then `Blocked —` with the class evidence); overlapping edits
with the edge-dev3 sibling plan on `review-lifecycle-core.sh` (serialize); live
smoke that accidentally spends paid credit (use disposable/public source).

**Rollback:** keep the previous merged SHA; restore via the supported installer
if a repair regresses live capability. Never erase incident evidence.

**Open technical questions (not for Albert):** exact OpenCode field causing
spawn NotFound; whether GLM REVISE waste is lifecycle or pool-only; whether
#1701 is purely detection or also launcher PATH; whether #1370’s owner already
fixed spawn on edge-dev3 in a way that ports here.

---

## Mandatory self-audit — completed before publication

1. **Could a brand-new AI session execute this plan with no chat context and
   ask nothing? Yes.** §§2–3 name the host, incidents, issues and sibling plan;
   §5 gives the class map so the implementer knows which files are legal; §9
   steps each name targets, behavior, tests and a verification gate; §8 is the
   only judgment surface and it is bounded.
2. **Does the plan carry the background, nuance, and rejected approaches?
   Yes.** §§6–8 record the chicken-and-egg, the measured class map, the owner
   quote, and every rejected landing strategy (including “just edit the
   wrappers” and “weaken task-gates”).
3. **Is the ultimate goal clear enough to steer when a step is wrong? Yes.**
   §1 is plain business English with goal-wins; §8 escalation says stop rather
   than silently break the contract; §13 keeps proof and rollback honest.
