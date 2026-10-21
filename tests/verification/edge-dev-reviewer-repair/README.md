# Edge-dev reviewer repair — frozen inventory (step 1)

Plan: [`plan_edge-dev-reviewer-repair-no-review.md`](../../../plan_edge-dev-reviewer-repair-no-review.md)
Issue: [#1678](https://github.com/popcre/ai-devops/issues/1678)
Handoff: [`2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md`](../../../HANDOFF.d/2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md)
Machine: `edge-dev` (Windows, MINGW64)
Recorded: 2026-10-16 (implementation session, after plan publication)

No raw private incident bodies are copied here. Facts are sanitized from
`bin/ai-reviewer-issue show` and local metadata only.

## Identity

| Fact | Value |
|---|---|
| Hostname | `edge-dev` |
| `git rev-parse origin/main` | `2e0b9d354788c6b1c4c08e02296c602afb3c3392` |
| Implementation worktree | `C:/repos/ai-devops-wt-1678-edge-dev-repair` |
| Branch | `mimo/1678-edge-dev-reviewer-repair` |
| Declared task class | `code` (no-review bootstrap; plan step 0) |
| Canonical checkout | `C:/repos/ai-devops` (landing-only; never pulled for feature work) |

## Installed launchers (read-only snapshot)

Machine tool shims under `C:/Users/ahazan/.local/bin/` (managed by
`install-machine-tools.ps1`) forward into the canonical checkout. Source-sha
embedded in the `ai-stepfun` shim: `2e0b9d354788c6b1c4c08e02296c602afb3c3392`.

| Path | Present | Note |
|---|---|---|
| `~/.local/bin/ai-stepfun` | yes | shim → `C:/repos/ai-devops/bin/ai-stepfun` |
| `~/.local/bin/ai-review` | yes | shim → canonical |
| `~/.local/bin/ai-task-gates` | yes | shim → canonical |
| `~/.local/bin/ai-glm` | no | `bin/ai-glm` exists in source; not on this PATH as a shim |
| `~/.local/bin/ai-reviewer-issue` | yes | store path `C:/repos/ai-devops/.ai/reviewer-issues` |

Installed status is **not** claimed healthy from this snapshot alone (plan §5).

## Open local incidents and disposition

Store: `C:/repos/ai-devops/.ai/reviewer-issues/` (private; not committed).

| Local incident ID | Provider | Sanitized symptom | Disposition | Owner / step |
|---|---|---|---|---|
| `20261014T203826Z-edge-dev-stepfun-2686842` | stepfun | Windows OpenCode path cannot spawn a shell (`ChildProcess.spawn` NotFound) during a governed draw; preflight still reports `usable:true` (false green) | **repair in this plan** | step 2 (+ live smoke step 6) |
| `20261014T201712Z-edge-dev-glm-2563781` | glm | Forced full re-review cycle after a REVISE decision on a governed PR | **repair in this plan** | step 3 (+ live/disposable proof step 6) |

Both incidents: `failure_stream=code-defect`, `failure_class=code-config`,
`resolution=null`. Missing exact reviewer metadata (no matching run/session
capture) — disposition must cite the merged repair SHA and offline fixtures
plus step 6 smoke, not a replay of the original governed draw.

Related open GitHub cards (reuse; no duplicates):

| Issue | Title (short) | Role in this plan |
|---|---|---|
| [#1678](https://github.com/popcre/ai-devops/issues/1678) | Reviewer incident repair | **This programme's card** — track checklist here |
| [#1467](https://github.com/popcre/ai-devops/issues/1467) | Windows sandbox cannot run commands | Coordinate; Windows sandbox non-interference is step 4 |
| [#1701](https://github.com/popcre/ai-devops/issues/1701) | Git Bash detection when `ProgramFiles` empty | **repair in this plan** step 5 |
| [#1370](https://github.com/popcre/ai-devops/issues/1370) | StepFun cannot consume full governed input / fallback runner | Coordinate with edge-dev3 sibling; do not rewrite sibling plan |
| [#1405](https://github.com/popcre/ai-devops/issues/1405) | DeepSeek leftovers | Out of scope here |

Sibling programme (do not rewrite):
[`plan_reviewer-recurrence-repair.md`](../../../plan_reviewer-recurrence-repair.md)
(edge-dev3). Share common-layer lifecycle/packet semantics; serialize any edit
to `tools/lib/review-lifecycle-core.sh`.

## Class map (measured, plan step 0 / step 1)

Measured with `bin/ai-task-gates explain --paths-from -` on this worktree at
`2e0b9d35`. Effective class **`code`**, required gates **`<none>`** (no
`exact-head-independent-review`). Re-run before every PR.

| Path | Class | Later step that may touch it |
|---|---|---|
| `tools/lib/review-doors/stepfun.sh` | code | 2 |
| `tools/lib/stepfun-sandbox.sh` | code | 2 |
| `config/opencode-stepfun/opencode.json` | code | 2 |
| `config/opencode-stepfun/agent/stepfun-review-windows.md` | prose | 2 |
| `tools/lib/review-lifecycle-core.sh` | code | 3, 4 (serialize with sibling plan) |
| `tools/lib/provider-wrapper-common.sh` | code | 3, 4 |
| `tools/lib/review-doors/muse.sh` | code | 4 if Windows non-interference touches doors |
| `tests/test-ai-stepfun.sh` | code | 2 (`stepfun_windows_shell_spawn_resolves`) |
| `tests/test-ai-stepfun-windows-shell.sh` | code | 2 |
| `tests/test-ai-glm.sh` | code | 3 (`glm_revise_followup_reuses_bound_turn`) |
| `tests/test-ai-review-engine.sh` | code | 3, 4 |
| `tests/test-ai-review-lifecycle.sh` | code | 3, 4 |
| `tests/test-ai-review-sandbox-self-cleanup.sh` | code | 4 (`foreign_orphans_do_not_block_fresh_review`) |
| `tests/test-ai-review-sandbox-delete-guard.sh` | code | 4 |
| `bin/*.cmd` launchers (code-class siblings) | code | 5 (Git Bash walk; not the bash entrypoints) |
| `tests/test-bin-cmd-launchers.sh` | code | 5 (`launcher_resolves_git_bash_with_empty_programfiles`) |
| `tests/test-windows-bash-selection.sh` | code | not used by step 5 (CI-lane selection only) |
| `tests/test-markdown-links.sh` | code | 1 (gate only) |
| `tests/verification/edge-dev-reviewer-repair/README.md` | prose | 1, 6, 7 |
| `config/reviewer-registry.json` | code | 2–5 if registry rows need aligning |
| `config/review-runner-doors.json` | code | 2–5 if door table needs aligning |
| `tools/lib/review-doors/README.md` | prose | docs only |
| `plan_edge-dev-reviewer-repair-no-review.md` | prose | STATUS updates |

**Protected — do not edit under this programme** (would escalate to
`reviewer-safety` / `exact-head-independent-review`):
`bin/ai-*` bash entrypoints (including `bin/ai-stepfun`, `bin/ai-stepfun-windows-shell`,
`bin/ai-glm`, `bin/ai-review`, `bin/ai-review-pool`),
`tools/reviewer_*.py`, `config/task-gates.json`.
Sibling `bin/*.cmd` launchers are mostly `code` and may change in step 5; the
bash entrypoints they launch stay untouched. Exception — 13 `.cmd` launchers
classify `reviewer-safety` and stay on #1701: `ai-gemini`, `ai-gemini-usage`,
`ai-review-credit-watch`, `ai-review-engine`, `ai-review-lifecycle`,
`ai-review-packet`, `ai-review-pool`, `ai-review-preflight`, `ai-review-sandbox`,
`ai-review-scoreboard`, `ai-reviewer-logs-sync`, `ai-stepfun`,
`ai-stepfun-windows-shell`.

If a fix is only possible inside a protected path, stop per plan §8 and record
the file + observed class here — do not edit it.

## Planned disposition rows (plan STATUS mapping)

| Plan step | Work | This inventory's promise | Status at freeze |
|---|---|---|---|
| 0 | No-review landing contract | effective class stays `prose`/`code`; no reviewer report in PR bodies | contract recorded; re-check before each PR |
| 1 | This inventory | all open edge-dev incidents have a disposition row | **this file** |
| 2 | StepFun Windows shell spawn | repair `20261014T203826Z-edge-dev-stepfun-2686842` | open |
| 3 | GLM REVISE follow-up | repair `20261014T201712Z-edge-dev-glm-2563781` | open |
| 4 | Durable publish + orphan non-interference | Windows-observable publish/non-interference only; deep receipt protocol stays with sibling plan | open |
| 5 | Git Bash / empty `ProgramFiles` | repair #1701 detection half | **code landed** — code-class `bin/*.cmd` walk includes hard-coded `C:\Program Files\Git\bin\bash.exe`; fixture `launcher_resolves_git_bash_with_empty_programfiles` in `tests/test-bin-cmd-launchers.sh`. 13 protected `.cmd` + installer Join-Path half stay #1701 reviewer-safety |
| 6 | Live smoke + incident disposition | both local incidents resolved/partially-resolved with evidence on #1678 | open |
| 7 | Code-only install + re-prove | installed hashes match merged source; smoke green | open |

## Verification gate for this step

- [x] README exists under `tests/verification/edge-dev-reviewer-repair/`
- [x] Class map covers every file later PRs plan to touch
- [ ] `bash tests/test-markdown-links.sh` passes (run with this PR)
