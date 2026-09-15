# Issue #335 Phase 5 acceptance evidence

Date: 2026-09-11
Status: in progress; central safety repair verified, final installed acceptance
and programme closeout remain open.

## Supported-machine installation

- Windows source was clean canonical `main` at
  `e1f3637ea54783b96b7a85b673ff25f370593a87`. The supported user-level
  lifecycle and machine-command catalog completed successfully; the installed
  `ai-task-gates` reported version `1.0.0` and resolved both canonical and
  linked-worktree identities. The full bootstrap stopped at its administrator
  boundary before changing machine-wide state.
- Ubuntu advanced its clean installation checkout from an older detached source
  to the same `e1f3637e` current `origin/main`. The command, skills, manifest,
  secrets wiring, and `ai-devops doctor` passed; doctor confirmed the installed
  source SHA. The overall lifecycle correctly returned nonzero because the
  existing private-memory hub's `ai-devops` index is 17,749 bytes against its
  12 KB health limit. No memory content was published after that refusal.

The installation gate is therefore not complete. Re-running unchanged is not
valid; the private-memory index needs its governed consolidation first, followed
by a complete installer rerun on the landed Phase 5 source.

The owner authorized the exact Ansible-managed `/worksp/ai-devops` permission
repair and its normal serialized application on 2026-09-11. The private-memory
index was then governed down from 17,749 to 3,392 bytes with all 49 fact files
still indexed, zero coverage findings, the private remote synchronized, and
rejected recovery refs retained. The remaining Ubuntu blocker is solely the
managed checkout permission repair and landed-source installation.

## Controlled acceptance and defect repair

The first nine-scenario run found that declared intent was only a drift ceiling,
not an input to the active gates. A clean resolved checkout could also enter a
protected external action before classification. The initial repair at
`cbfeb54b45fd6caef08967bebd6810344f5471fd` was rejected by exact-head Codex
review `20260911T005648-298059-120`: choosing only the stronger class dropped
required proof from the observed lower class.

The follow-up makes the stronger class the effective protection level, unions
required proof from declared and observed classes, and takes forbidden actions
from the effective class. This lets an explicitly declared Oracle production
task enter its dry-run production gate while retaining deployment tests, release
review, owner authorization, and exact resource/action authorization. With no
declaration and no diff, deployment, database, infrastructure, and production
now fail closed.

Focused proof on an idle `edge-dev-win` runner host:

- `tests/test-ai-task-gates.sh`: **84 passed, 0 failed**.
- `tests/test-task-gates-phase5-acceptance.sh`: **23 passed, 0 failed**.
- Nine controlled scenarios covered documentation-only cleanup, docs-to-code
  drift, ordinary code, reviewer safety, DesignFlow UI, shared-db structure,
  licensed/private evidence, infrastructure, and Oracle production.
- Controlled result: **0 expensive external launches, 0 reviewer starts, and 0
  long-wait starts**. All database, infrastructure, private-evidence, UI, and
  production cases used synthetic paths and policy fixtures only.
- `tests/test-repository-coverage.sh`: 17 rows, 17 canonical remotes, both
  private repositories metadata-only, audit clean.
- `tests/test-test-selection.sh`: 9/9 passed.
- `tests/test-line-endings.sh`: 6/6 passed.
- `tests/test-markdown-links.sh`: 313 tracked Markdown files passed.

The original suite previously reported 83/83. The extra effective-class
assertion raises its exact current count to 84/84; the final exact-head run must
confirm that count again after this evidence file lands.

## Phase 0 comparison

GitHub contents metadata was re-read on each repository's current default branch;
no private file body was opened. All 17 repositories now expose a policy.

- Startup router bytes: 771,588 before; 785,644 current; delta **+14,056
  (+1.8%)**. This is not treated as a failure because router size is explicitly
  diagnostic and capability preservation outranks compression.
- Median startup router: 26,595 before; 27,321 current.
- Maximum startup router: 143,774 before; 144,720 current (`u2giants/theoracle`).
- Task-trigger precision: 9/9 controlled Phase 5 scenarios selected the intended
  effective class and retained their stronger local gates.
- Documentation controls: zero paid-review and zero long-wait starts.
- Time to first complete controlled result: 86.6 seconds for the final local
  nine-scenario run on this host.
- Landed-within-session comparison cannot yet be stated: Phase 0 did not record a
  numeric baseline, and the Phase 5 repair has not yet merged. Final closeout
  must report the observed Phase 5 outcome without inventing a Phase 0 value.

## Remaining gates

1. Exact-head independent approval with this committed test evidence visible.
2. Pull-request CI and merge-queue landing.
3. Merge and apply the separately reviewed Ansible permission repair, then
   reinstall Ubuntu from the landed exact source.
4. Final plan/issue updates, handoff retirement, #335 closure, #159 update, and
   #166 unblock only after every preceding gate is green.
