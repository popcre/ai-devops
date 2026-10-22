---
issue: 1678
status: OPEN
owner: mimo/1678-wrapup-complete
---

# HANDOFF — edge-dev reviewer repair programme closed; remainders only

handoff-id: 2026-10-22T0530Z-edge-dev-mimo-1678-wrapup-complete
machine: edge-dev
agent: mimo
session: ses_ffe5ea04d4491ffe1S5X9sNY6B
repo: popcre/ai-devops
workstream: plan_edge-dev-reviewer-repair-no-review.md steps 0–7 (programme complete)
plan: https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md
issue: https://github.com/popcre/ai-devops/issues/1678
predecessor: https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-21T2012Z-edge-dev-mimo-1678-steps5-7.md

---

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**Already decided — do NOT re-ask:**
- Albert, 2026-10-15 — repair must not need AI reviewers as a merge gate.
- Albert, 2026-10-21 — one-time reviewed install of the repair release is authorized (install-time safety only). Recorded: https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md
- Albert, 2026-10-21 — "yes" to the safety blessing so the install could finish.

**Still his:** nothing for this programme. Broader #1678 leftovers are ordinary work.

**Not Albert's call:** ask-path shim fix, worktree cleanup, incident bookkeeping.

## 1. What this application is

`popcre/ai-devops` — public recovery toolkit for a multi-model AI coding workflow. Host: edge-dev (Windows). Not an app or service.

## 2. What we set out to do this session

Finish plan steps 4–7 (and close the programme) on edge-dev. That is done.

## 3. Current state — what is true right now

| Outcome | State | Evidence |
|---|---|---|
| Plan steps 0–7 | **All done** | https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md STATUS table |
| Step 4 durable publish + orphans | Merged `3de4f83e` (PR #1928) | fixtures in engine + sandbox self-cleanup suites |
| Step 5 Git Bash / empty ProgramFiles | Merged `108973f8` (PR #1938) | `tests/test-bin-cmd-launchers.sh` fixture `launcher_resolves_git_bash_with_empty_programfiles` |
| Step 6 live smoke + incidents | Merged `da43e7a3` / `de54e5c2` / `240b90d5` | smoke table: https://github.com/popcre/ai-devops/blob/main/tests/verification/edge-dev-reviewer-repair/README.md |
| Step 7 reviewed install | **Installed `240b90d5`** 2026-10-22 ~1:20 AM EDT | launcher `source-sha=240b90d5`; smoke re-run green |
| Incidents `20261014T203826Z-edge-dev-stepfun-2686842` | **partially-resolved** | door spawn proven; ask path still broken |
| Incidents `20261014T201712Z-edge-dev-glm-2563781` | **resolved** (`b5cfa876`) | GLM fixture 13/13 |
| Issue #1678 | **OPEN** | other pre-existing incidents remain (not this programme) |
| Owner install ruling | Landed | https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md |

Merged PRs this session: #1938, #1974, #1978, #1979, #1980 (plus #1928 from earlier in the programme).

## 4. Everything we tried that did NOT work

- **`ai-stepfun ask` still fails `ChildProcess.spawn NotFound`** on Windows. The governed door path works (BASH_ENV trampoline in `tools/lib/review-doors/stepfun.sh`). The ask/review path in protected `bin/ai-stepfun` still copies a bash *script* to `bash.exe` (the PR #1807 shape that was reverted).
- **First StepFun "shell-ok" was a false positive** — the model echoed the sentinel without running a command. Always require a command the gate must execute.
- **DeepSeek REJECT twice** on install approvals before APPROVE: missing smoke exit codes, contradictory handoff rows, owner ruling not in `docs/owner-rulings.md`, smoke table broken by an inserted section.
- **`authorize-install` refused** until (a) tests were recorded on the review (`--tests`), (b) source digest matched a *clean* review worktree (a leftover temp script changed the digest), (c) install task started at the *old* HEAD then advanced to target, (d) `ai-release-live-check fleet` posted linux+windows live-review statuses from edge-dev3.
- **Canonical checkout dirty** (`bin/ai-glm` local path-compare fix) blocked the installer twice. The official `path-identity.sh` / `ai_git_toplevel` fix landed in the release and supersedes that local patch.

## 5. Root causes and key findings

- Door path (governed reviews) is the proven Windows shell path. Ask path in `bin/ai-stepfun` is the remaining gap and is **protected** under this plan (do not edit `bin/ai-*` entrypoints).
- Installer treats any release window containing protected paths as a reviewed install, even if *your* commits are only prose/code.
- Review evidence binds only when `source_digest` matches the worktree identity at review time — keep the review worktree clean.
- `ai-release-live-check fleet` must run on an Ubuntu review host signed in as `u2giants` (edge-dev3 works).
- Human times in October 2026 are **EDT**, not EST.

## 6. Exact next steps (remainders only — programme itself is closed)

1. **StepFun ask-path shim** (optional follow-up): replace the `cp bash bash.exe` script shim in protected `bin/ai-stepfun` `run_opencode_turn` with the door's BASH_ENV / `OPENCODE_GIT_BASH_PATH` approach. Requires path-1 style reviewed change or a plan §8 escalation. Track on https://github.com/popcre/ai-devops/issues/1678 or https://github.com/popcre/ai-devops/issues/1701. Do **not** treat as blocking the completed programme.
2. **Issue #1678 leftovers**: pre-existing open incidents (Gemini, Kimi, Qwen quarantine, StepFun extra-decision-lines, etc.) are outside this programme. Next owner of #1678 should triage them; this session only disposed the two plan-named incidents.
3. **Worktree cleanup** (safe, optional): `C:/repos/ai-devops-wt-1678-step5`, `-step6`, `-evidence`, `-status` have merged branches. `-install` and `-review` hold install/review evidence at `240b90d5` — remove only after a successor no longer needs the `.ai/reviews` reports. Use the `cleanup-worktree` skill.

## 7. Constraints and gotchas in force

- Never edit `bin/ai-*` bash entrypoints, `tools/reviewer_*.py`, or `config/task-gates.json` under the no-review plan (plan §8).
- Owner ruling: reviewed install is allowed **once** for this release; it is not a standing merge gate. PR merges outside `popcre/shared-db` still need no AI review.
- Canonical `C:/repos/ai-devops` is landing-only. Never `git pull` it; install via the Windows installer with `-ExpectedHead`.
- Invoke Git Bash as `"C:\Program Files\Git\bin\bash.exe" -c '...'`. Plain `bash` may be a WSL stub.
- Times in EST/EDT (America/New_York) when talking to Albert.

## 8. Access and environment

- edge-dev (Windows). Ubuntu review host for live-review statuses: `edge-dev3` (gh as u2giants).
- Installed checkout `C:/repos/ai-devops` at `240b90d5` with managed launcher `source-sha=240b90d5`.
- Local incident store: `bin/ai-reviewer-issue` (private; never copy raw bodies into the public repo).

## 9. Open questions and risks

- Ask-path shell spawn remains broken on Windows until someone is authorized to edit `bin/ai-stepfun`. Door path is the supported governed path and works.
- `ai-housekeeping` reported GitHub unavailable in this run (quota/spacing); merged-ness of old worktrees is UNKNOWN until `gh` is healthy — do not delete on ancestry guesses.

## Self-audit

1. **Could a brand-new developer continue cold?** Yes — §3 has SHAs and URLs; §6 names only the remainders; the programme itself is marked done.
2. **Does it carry background and failed attempts?** Yes — §4 lists every dead end that cost time.
3. **Is the goal clear?** Yes — programme closed; remainders are optional follow-ups, not unfinished plan steps.
4. **Section 0 complete with no technical approvals asked of Albert?** Yes.
