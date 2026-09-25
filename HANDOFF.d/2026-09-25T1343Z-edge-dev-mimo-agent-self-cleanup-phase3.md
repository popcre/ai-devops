---
issue: 711
status: OPEN
owner: mimo/agent-self-cleanup-phase2
---

# Handoff — agent self-cleanup Phase 3 (parent orphan sweep)

Plan: [`plan_agent-self-cleanup.md`](../plan_agent-self-cleanup.md)  
Issue that proves this done: [#711](https://github.com/popcre/ai-devops/issues/711)

This file replaces `2026-09-23T1820Z-edge-dev-claude-agent-self-cleanup.md`
(successor rule: Phase 2 landed; open obligations carried forward here).

---

## 0. Decisions only the owner can make

**Put this WHOLE list to Albert in ONE message before starting work.**

### Blocking
- None for Phase 3. Start there.

### Wrong guess is recoverable
1. **Orphan-sweep age threshold** — plan says markers older than 2 hours. If reviews routinely run longer, raise it. **Recommendation: keep 2 hours** (matches plan §3.1). Blocks only sweep aggressiveness.
2. **PID marker (plan Step 3.2)** — optional. **Recommendation: implement it**; the 2-hour age rule alone will not catch a killed wrapper whose snapshot is younger. Blocks nothing if skipped.

### Outside this workstream — nobody else is on it
3. **Six dirty Codex work folders** (`C:\Users\ahazan\.codex\worktrees\`) still hold uncommitted work. Separate session; prompt is `prompt_six-dirty-codex-worktrees.md`. **Recommendation: run that session before deleting anything there.**
4. **Last locked folders** `C:\Users\ahazan\.local\share\ai-devops` and Codex sqlite history files could not move to D: while tools ran. **Recommendation: close Codex/opencode, then run `C:\Users\ahazan\.local\bin\ai-housekeeping\move-bulk-to-d.ps1`.**

### Already settled — do NOT re-ask (2026-09-23)
- Reviews must not copy full Git history (Phase 1 done).
- The creating run must delete its copy; daily sweep is backup only (Phase 2 done).
- Live code and tool programs stay on C:; growth/bulk stays on D: via junctions.
- Daily task `AI-Debris-Housekeeping` stays until 14 days of green self-cleanup.
- Do not touch the six dirty work folders in this workstream.
- Albert does not merge PRs — the working agent merges.
- Muse APPROVE is the independent-review pattern used for reviewer-safety changes.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's AI development-operations toolkit on his Windows workstation `EDGE-DEV`. It dispatches AI reviewers (Claude, Codex, Gemini, Grok, Qwen, GLM, DeepSeek, Muse) against GitHub repos (`popcre/ai-devops`, `u2giants/shared-db`, `u2giants/licensor-source-data`, `popcre/poppim-web`, `popcre/popdam3`). Wrappers live in `bin/`; policies in `config/`; tests in `tests/`. Albert is a business owner, not a programmer.

Review sandboxes live under
`C:\Users\ahazan\.local\state\ai-devops\review-sandboxes\`
(junction to `D:\ai-data\local\state\ai-devops\review-sandboxes`).

## 2. What we set out to do this session, and why

**Business goal:** stop AI tooling from filling the system disk. The agent that creates a temporary copy deletes it before returning.

**Trigger:** 2026-09-23 C: hit 5 GB free; cleanup recovered ~229 GB. Owner ruled self-cleanup at source; daily sweep is backup only.

**This session (2026-09-25) delivered Phase 2** of `plan_agent-self-cleanup.md` plus issue #802, merged as PR #823 / commit `41f8e75ab4e2ad0a496547fffec427fe110ed956`.

## 3. Current state — what is true right now

| Item | State |
|------|--------|
| Phase 1 (shrink the copy) | **Done** — merged `af80fcf0` (PR #797). Bounded shallow snapshots. |
| Phase 2 (self-delete) | **Done** — merged `41f8e75a` (PR #823). Muse APPROVE at `6026815b`; CI green. |
| `with-copy` in `bin/ai-review-sandbox` | Live: create → run command → delete on EXIT/INT/TERM. `AI_KEEP_SANDBOX=1` keeps. |
| kimi start-failure release | Live: trap armed before `prepare_review`; continue path releases the recorded dir. |
| Issue #802 (kimi base hint) | **Closed** by PR #823. |
| Phase 3 (parent orphan sweep) | **Not started** |
| Phase 4 (daily sweep tighten) | Task already installed; no code change yet. |
| Phase 5 (live proof) | **Not started** — needs one real review with zero leftovers. |
| Issue #711 | **OPEN** (Phases 3–5) |
| Tests at `41f8e75a` | self-cleanup 22/22; delete-guard 9/9 (+4 skip when `ln -s` is unavailable on Windows); bounded-history 23/23; sandbox 108/108 |

Worktree used this session: `C:\tmp\ai-devops-self-cleanup-mimo` (branch `mimo/agent-self-cleanup-phase2`, merged).

## 4. Everything we tried that did NOT work

1. **`bin/ai-task-gates start` via bare PowerShell path** — "The system cannot find the path specified." Workaround: run through Git Bash (`C:\Program Files\Git\bin\bash.exe -lc`).
2. **`bash` on this host** resolves to WSL, which has no distro. Workaround: always use Git Bash explicitly.
3. **Heredoc `gh pr create --body-file -`** from PowerShell mangled backticks and `tests/` paths. Workaround: write the body to a real file, then `gh pr edit --body-file`.
4. **`kill -TERM $$` inside `sh -c` as an "abort" test** — kills the child, not the `with-copy` wrapper. Muse flagged this (M2). Fix: `kill -TERM "$PPID"` from a wrapped `bash -c` so TERM hits the creating run.
5. **First kimi failure-path trap was armed AFTER `prepare_review`** — dies inside prepare_review (HEAD, assert-head, packet) leaked the snapshot. Muse flagged this (M1). Fix: arm the trap before `prepare_review`.
6. **`ln -s` on Windows MSYS often copies instead of linking** — the delete-guard symlink case cannot run. Honest `skip` when `-L` is false; do not claim the test passed.
7. **`gh pr checks` "fail" grep** matched the check *name* `report-scheduled-failure`. Workaround: parse the status column (`awk -F'\t' '$2=="fail"'`).
8. **`ai-pr-wait` / long `bash | tail` pipes** get killed by the tool layer. Workaround: bounded `wait-pr-checks.sh` / `wait-merge.sh` scripts with iteration caps (repo rule: no open-ended `gh` loops).
9. **PowerShell eats `$i:` in double-quoted bash -lc strings.** Workaround: write scripts to files and execute them.

## 5. Root causes and key findings

1. **Cleanup was prose, not code** — the 192 GB pile-up. Phase 2 installs traps in the creating run.
2. **`ai-review-sandbox` is short-lived** — it prints a path and exits. The "creating run" is the wrapper (or `with-copy`). Traps cannot live in `ensure-copy` itself.
3. **Session wrappers (kimi/muse/qwen/grok/glm/gemini) keep the snapshot for the session lifetime**; only start-failure before worker ownership must delete. Successful start disarms the trap (`bin/ai-kimi` after startup ack).
4. **`remove_sandbox` is path-guarded** (`is_managed`): marker file + physical containment under the sandbox root. Never `rm -rf` a caller-supplied free path.
5. **Evidence safety beats disk safety** when paid evidence is unreconciled: `remove_sandbox` `die`s and retains the copy. That is intentional; Phase 3/4 orphans cover the rest.
6. **Muse independent review** is the required gate for reviewer-safety changes (`bin/ai-review*`, safety tests, `config/reviewer-ci-paths.txt`). Phase 1 and Phase 2 both used Muse APPROVE at exact head.
7. **`AI_KEEP_SANDBOX` must be exactly `1`** — tested that `0`/empty/`yes`/`true` still delete.

## 6. Exact next steps

1. Work only **Phase 3** of `plan_agent-self-cleanup.md` unless Albert says continue.
   - New worktree from `origin/main` of `popcre/ai-devops`. Declare `ai-task-gates start --class reviewer-safety`.
   - Step 3.1: parent wrappers (`bin/ai-review`, `bin/ai-review-pool`, preflight) run a **bounded** sweep at start: remove `review-sandboxes/*` whose marker age > 2 hours AND no matching live PID (if 3.2 is done). Never touch anything younger than 2 hours.
   - Step 3.2 (recommended): write `sandbox.pid` at create; orphan rule = marker older than 2h OR (PID not running AND age > 15 min).
   - **You'll know it worked when** `tests/test-orphan-sweep-age.sh` exists and passes: fake old sandbox removed; 10-minute-old sandbox kept; killed wrapper's sandbox removed after 15+ min (if PID marker is implemented).
2. Phase 4: only tighten `C:\Users\ahazan\.local\bin\ai-housekeeping\cleanup-ai-debris.ps1` if Phase 3 changes paths or marker names. Do not remove `AI-Debris-Housekeeping`.
   - **You'll know it worked when** `schtasks /Run /TN AI-Debris-Housekeeping` logs a completed line in `D:\ai-data\logs\housekeeping.log`.
3. Phase 5: one real, low-risk review (docs-only PR) with the new wrapper. After it returns, `D:\ai-data\local\state\ai-devops\review-sandboxes` must contain no dir from that run.
   - **You'll know it worked when** zero leftovers from that run, wrapper log shows the cleanup line, reviewer still produced a usable verdict.
   - If live proof is deferred: open **exactly one** leftover-proof issue with an `owner:` line and link the PR (plan §9 Step 5.2).
4. Separately (not this workstream): `prompt_six-dirty-codex-worktrees.md`; then `move-bulk-to-d.ps1` when tools are closed.

## 7. Constraints and gotchas in force

- Never edit canonical checkouts under `C:\repos\...` for write work — new worktree from `origin/main` first.
- Branch → PR → merge yourself (Albert does not merge). Never push to protected `main`.
- Docs-only PRs (every changed file is prose) merge immediately with `gh pr merge --squash --admin`; code/test/config PRs wait for checks and the merge queue.
- Reviewer-safety class needs one read-only exact-head independent review (Muse is the pattern) before merge. Required gates: `exact-head-independent-review`, `installed-routing-proof`, `local-tests`.
- Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>` — `git var GIT_COMMITTER_IDENT` before the first commit.
- Sign GitHub posts: `Posted by MiMo chat <id> on edge-dev` (`unknown` if session id empty).
- Delete only inside `.../review-sandboxes/<created-name>` or a proven-clean worktree group. Never delete dirty copies.
- `AI_KEEP_SANDBOX=1` is debugging only; do not leave it set.
- Use Git Bash (`C:\Program Files\Git\bin\bash.exe -lc`); bare `bash` is WSL here.
- No open-ended `gh` wait loops — deadline or iteration cap (`bin/ai-pr-wait`, or a bounded poll script).
- Shared-db structure changes never belong in this workstream.

## 8. Access and environment

- Machine `EDGE-DEV`, user `ahazan`. Local repo `C:\repos\ai-devops` (landing-only).
- GitHub `gh` authenticated as Albert (`u2giants`). PR #823 merged; commit `41f8e75a` on `origin/main`.
- Secrets: 1Password vault `vibe_coding` only. None appeared this session.
- Muse: `AI_MUSE_CALLER=mimo bin/ai-muse doctor` passes (pinned Muse Code 1.3.0-R3233.1).
- Growth data root: `D:\ai-data\` via junctions. Daily task `AI-Debris-Housekeeping` @ 03:30.
- Worktree this session: `C:\tmp\ai-devops-self-cleanup-mimo`.

## 9. Open questions and risks

1. **Live proof (Phase 5) is still unproven** — the plan's DoD requires one real review with zero leftovers, or one leftover-proof issue. Until then the daily sweeper remains load-bearing.
2. **Muse non-blocking L5** (2026-09-25): abort test does not assert wrapper exit code 143. Optional polish; deletion is already proven.
3. **Plan STATUS counts** in `plan_agent-self-cleanup.md` row 2 cite 17/17 and 11/11 from the first commit; suites at merge report 22/22 and 9/9. Cosmetic; fix when Phase 3 touches the plan.
4. **Windows `ln -s`** cannot exercise the symlink delete-guard case (4 skips). Linux CI will run those checks.
5. **14-day keep rule** for `AI-Debris-Housekeeping` starts after Phase 5 live proof is green — not before.

---

## Self-audit (handoff-writer)

1. **Brand-new developer could continue without questions** — §1 product/paths; §3 exact state with SHAs; §6 numbered steps with verification gates; §4 dead ends with workarounds.
2. **As effective as this session** — §5 root causes (`with-copy` vs session wrappers, path guard, evidence-vs-disk); §4 every failure this session hit; §7 toolchain traps (Git Bash, PowerShell quoting, bounded waits).
3. **Every relevant detail** — background §1–2; goal §2; state §3 with commit SHAs; failures §4; findings §5; next steps §6; constraints §7; access §8; risks §9. Secrets by vault name only.
4. **Section 0 sweep** — blocking: none for Phase 3. Recoverable: sweep age, PID marker (with recommendations). Outside: six dirty worktrees, move-bulk-to-d. Settled list present with date. Every owner-facing item in §1–9 also appears in §0.

**Answers:** Yes / Yes / Yes / Yes.
