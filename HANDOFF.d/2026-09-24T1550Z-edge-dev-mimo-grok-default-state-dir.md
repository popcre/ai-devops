---
issue: 765
status: OPEN
owner: fix/grok-default-state-dir (PR #774)
---

# HANDOFF — Grok auth default path after the C:→D: move

## 0. DECISIONS ONLY THE OWNER CAN MAKE

**Blocking (must decide before the next session merges PR #774):**

1. **Whether to merge PR #774 without an independent review verdict.** Standing rule requires one read-only exact-head review before merge of reviewer-wrapper changes. Both `bin/ai-grok-review` and `bin/ai-qwen` were killed mid-run (`Unknown: ChildProcess.kill`) with no verdict. Recommendation: do **not** merge; finish the review first. Blocks the only remaining merge step.

**A wrong guess is recoverable:**

2. **If review tooling keeps dying, should the next session open a separate tooling issue?** Recommendation: yes — a short issue on “reviewer wrappers lose the child process on this host” after two more failed attempts. Not required to unblock #774 if one review eventually lands.

**Not part of this work and nobody is on it:**

3. **Old muse-wrapper-reject handoff** (`HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md`) is OPEN, `issue: none`. Recommendation: a later housekeeping session assigns it an issue or retires it. Not blocking.

**Already settled — do NOT re-ask:**

- 2026-09-24: Albert asked for the Grok default path to be fixed and for a subagent to handle it (session chat). Authorized.
- 2026-09-24: No Claude/Codex reviewers; use `bin/ai-grok-review` with `AI_GROK_STATE_DIR=…/grok-c` or `ai-qwen`.
- 2026-09-24: `#542` Phase D is complete; leftover CI-nits handoff deleted in PR #761 / `91d4ddb6`.
- 2026-09-24: Do not force-push shared-db; do not replay paid Muse turns.

Put the whole Section 0 list to the owner in ONE message before starting work.

## 1. What this application is

`popcre/ai-devops` is Albert’s public multi-model AI recovery toolkit (wrappers, reviewer safety, install scripts, docs). It is not a deployed app. GitHub is source of truth: https://github.com/popcre/ai-devops. Local landing checkout: `C:/repos/ai-devops` (landing-only). Write work uses per-task worktrees under `C:/repos/ai-devops-worktrees/`. Machine nickname: `edge-dev` (Windows 10.0.26200, Git Bash at `C:/Program Files/Git/bin/bash.exe`).

Grok is one reviewer provider, driven only through `bin/ai-grok-review` (read-only reviews) and `bin/ai-grok-implement` (isolated implementation). Auth/state lives under `~/.local/state/ai-devops/grok` or `…/grok-c`. After a bulk C:→D: move, `…/grok` is a symlink/junction onto D: while credentials stay on C:.

## 2. What we set out to do this session, and why

**Goal:** finish any leftover from `#542` Phase D, then fix the Grok auth default path so `AI_GROK_STATE_DIR=…/grok-c` is no longer required after the C:→D: move (Albert authorized a new issue and delegated the fix to a subagent).

**Trigger:** `#542` Phase D was already done on main (`443101ad`, D3 `ee697287`, D4 shared-db PR #3441). The only #542 leftover was a stale Phase C CI-nits handoff. Separately, Grok auth still needed an explicit state-dir override.

**Technical objective:** delete the stale handoff; then make `bin/ai-grok-review` and `bin/ai-grok-implement` resolve the default state dir to the real credential-volume `grok-c` sibling when the conventional `grok` path is linked or cross-volume.

## 3. Current state — what is true right now

**Done and on `origin/main`:**

- PR #761 merged as `91d4ddb6` — deleted `HANDOFF.d/2026-09-23T0700Z-edge-dev-zcode-muse-phase-c-ci-nits.md`. Both nits were already correct after PR #679 (six-section wording; Blacksmith comment says 40 minutes, matching `verify.yml` `timeout-minutes: 40`).
- `#542` Phase D remains complete. Muse catalog healthy (`ai-muse doctor` all PASS on engine `muse-code`).

**Done but NOT merged (this is the open workstream):**

- Issue **#765** OPEN — https://github.com/popcre/ai-devops/issues/765  
  “Grok default state dir misses grok-c after C: to D: move; auth needs AI_GROK_STATE_DIR”
- PR **#774** OPEN — https://github.com/popcre/ai-devops/pull/774  
  Branch `fix/grok-default-state-dir`, head `be653ec73a948bd4ea0c3e109672fd406daa498b`, base `20af23cb…`
- Files changed on that commit (only these three):
  - `bin/ai-grok-review` — adds `grok_default_state_dir()` (~lines 92–122): `AI_GROK_STATE_DIR` wins; else if conventional `…/grok` is a symlink → `…/grok-c`; else if auth home and conventional path are on different device ids → `…/grok-c`; else conventional `…/grok`.
  - `bin/ai-grok-implement` — same helper.
  - `tests/grok-auth-link-cases.sh` — new default-state-dir cases (linked junction → grok-c; override wins; real dir stays grok; cross-volume device split → grok-c). Suite footer now `10 passed, 0 failed, 0 skipped`.
- Worktree (KEEP — unmerged): `C:/repos/ai-devops-worktrees/grok-default-state-dir` on `fix/grok-default-state-dir`.
- Untracked scratch in that worktree (session-owned, delete when finishing): `.tmp-pr-body.md`, `.tmp-review-prompt.md`.

**Verified at `be653ec7`:**

- `bash tests/grok-auth-link-cases.sh` → `10 passed, 0 failed, 0 skipped` (re-run this session).
- Subagent also recorded `tests/test-ai-grok-implement.sh` → `84 passed, 0 failed`.
- **Live default-path proof (worktree code, NO `AI_GROK_STATE_DIR`):**  
  `state dir     : /c/Users/ahazan/.local/state/ai-devops/grok-c/implement`  
  `auth          : PRESENT (model catalogue reachable; chat authentication unverified)`
- **Installed launcher proof** (`C:\Users\ahazan\.local\bin\ai-grok-implement.cmd doctor` → runs `/C/repos/ai-devops/bin/ai-grok-implement`): doctor PASS, but `state dir : /c/Users/ahazan/.local/state/ai-devops/grok/implement` — **old default**, because the installed launcher points at the landing `main` checkout. After merge + landing fast-forward, the same command should print `…/grok-c/implement`. That is the post-merge verification gate.

**Not done:**

- Independent read-only exact-head review verdict (merge gate). PR #774 must not merge until this exists.
- Merge of PR #774.
- Post-merge installed-route re-proof that default is `grok-c` without `AI_GROK_STATE_DIR`.

## 4. Everything we tried that did NOT work

1. **`bin/ai-grok-review new pr774-exact-head-765-grok …` (parent, after subagent)** — process died with `Unknown: ChildProcess.kill` before a verdict. Same failure the subagent hit on its `bin/ai-grok-review` run.
2. **`bin/ai-qwen new pr774-exact-head-765` (subagent)** — left `"status": "turn_in_progress"`, `"turns": 0`, empty `pending.jsonl`. Evidence: `/c/Users/ahazan/.local/state/ai-devops/qwen/sessions/2d834af8a2e6/claude--pr774-exact-head-765.json`.
3. **`bin/ai-qwen new pr774-exact-head-765-r2 …` (parent retry)** — same `Unknown: ChildProcess.kill`. `ai-qwen` has no `--decision`/`--tests` flags (help confirmed); brief must carry those lines in the prompt.
4. **`cmd.exe /c bin\ai-grok-implement.cmd doctor` from Git Bash** — quoting failed (interactive cmd or `'\' is not recognized`). Use PowerShell `& 'C:\Users\ahazan\.local\bin\ai-grok-implement.cmd' doctor` instead (worked).
5. **Worktree-local `bin\ai-grok-implement.cmd` via cmd.exe** — `The system cannot find the path specified` (the tiny `.cmd` shim expects the managed install layout). Prefer Git Bash `bin/ai-grok-implement doctor` inside the worktree, or the installed `~/.local/bin` shim.

Do not repeat (1)–(3) without checking whether the child-process kill is fixed; try a shorter `--max-turns`, a different provider, or run the review from a plain Git Bash window outside this harness.

## 5. Root causes and key findings

- After the bulk C:→D: move, `…/grok` is a symlink/junction to another volume while `~/.grok` credentials stay on the profile volume. Same-inode hard links (the #709 isolated-home design) cannot cross volumes, so the default must select the real on-volume sibling `…/grok-c`.
- Explicit `AI_GROK_STATE_DIR` must always win (already the case; keep it).
- `tests/test-ai-grok-implement.sh` is slow on this Windows host (git-heavy; >5 min is normal), not hung.
- Installed `.cmd` shims call `bash /C/repos/ai-devops/bin/<tool>` — they always reflect **landing `main`**, never a worktree. That is why doctor still showed `…/grok` after the fix existed on the branch.
- This MiMo/PowerShell harness kills long-lived reviewer CLI children (`Unknown: ChildProcess.kill`). Independent review is the only unfinished #765 obligation.
- `#542` Phase C CI nits were already fixed on main in PR #679; the handoff that tracked them was stale archaeology.

## 6. Exact next steps

1. Re-read this file and PR #774 diff (`be653ec7`). Do not redesign `grok_default_state_dir()`.  
   **Gate:** you can state the three-file change set without opening the diff again.
2. Get one independent read-only exact-head review at `be653ec73a948bd4ea0c3e109672fd406daa498b` using `AI_GROK_STATE_DIR=/c/Users/ahazan/.local/state/ai-devops/grok-c` + `bin/ai-grok-review`, or `ai-qwen` with the brief in `.tmp-review-prompt.md` (decision + tests lines included in the prompt). No Claude/Codex. No paid Muse.  
   **Gate:** you have an `APPROVE`/`REVISE` verdict plus an evidence path, and `ai-task-gates` sees `exact-head-independent-review`.
3. If REVISE, fix only the named gaps on the same branch, re-run `bash tests/grok-auth-link-cases.sh` (expect 10/0) and `bash tests/test-ai-grok-implement.sh` (expect 84/0), then one new exact-head review.  
   **Gate:** review is APPROVE at the new head SHA.
4. `ai-task-gates check --before ship`, then merge PR #774 (branch + PR; never push to `main`).  
   **Gate:** `gh pr view 774 --json state,mergedAt` shows `MERGED`.
5. Fast-forward the landing checkout to `origin/main` and run installed proof:  
   `powershell -NoProfile -Command "& 'C:\Users\ahazan\.local\bin\ai-grok-implement.cmd' doctor"`  
   **Gate:** `state dir` line prints `/c/Users/ahazan/.local/state/ai-devops/grok-c/implement` **without** `AI_GROK_STATE_DIR`.
6. Close issue #765 with that proof (sign: `Posted by MiMo chat unknown on edge-dev`). Delete this handoff in the same PR/commit that closes #765 (successor rule).  
   **Gate:** issue closed; this file gone from `HANDOFF.d/` on `origin/main`.
7. Remove worktree `C:/repos/ai-devops-worktrees/grok-default-state-dir` only after step 5 (use `cleanup-worktree`). Delete `.tmp-pr-body.md` / `.tmp-review-prompt.md` there when you leave.

## 7. Constraints and gotchas in force

- Declare `bin/ai-task-gates start --class reviewer-safety` before review/ship of this wrapper change. Required gates for review: `exact-head-independent-review`, `installed-routing-proof`, `local-tests`.
- Never push to `main`. Branch → PR → merge queue / admin merge per repo rules. No force-push. Stage only task-owned files.
- No Claude/Codex reviewers. No paid Muse turns. Do not force-push shared-db.
- Canonical checkout `C:/repos/ai-devops` is landing-only; edit only in a worktree.
- `git var GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>` before the first commit.
- GitHub calls through `bin/ai-gh`. Sign every GitHub post with `Posted by MiMo chat unknown on edge-dev`.
- Preserve capability: never remove Grok auth checks or hard-link rules as a substitute for repair. Keep the #709 same-volume isolated-home safety net.
- One unproven live-behavior outcome per session — step 5 is that outcome for the next session.
- Do not edit another session’s `HANDOFF.d/` file. Root `HANDOFF.md` is a static pointer (`handoff-pointer: v1`) — do not rewrite.

## 8. Access and environment

- GitHub: `gh` via `bin/ai-gh` on `edge-dev`, authenticated as `u2giants`.
- Grok CLI: `/c/Users/ahazan/.grok/bin/grok` 1.0.13 (stable). State: `…/grok-c` (real, C:) and `…/grok` (junction after move).
- Qwen: `bin/ai-qwen`, model pin `qwen3.8-max`, state `…/ai-devops/qwen`.
- Muse: `ai-muse` default engine `muse-code`; catalog healthy this session. Do not replay paid Muse turns.
- Secrets: 1Password vault `vibe_coding` only (reference names, never values). No credential values appeared this session.
- Task gates state dir: `…/ai-devops/task-gates` (class `prose` used for #761; class `reviewer-safety` declared for #774 work).
- Scratch/review sandboxes: `/d/ai-data/local/state/ai-devops/review-sandboxes/…` and provider session dirs under `…/ai-devops/{grok-c,qwen}/sessions/`.

## 9. Open questions and risks

- **Review child-process kill (2026-09-24):** unknown whether MiMo harness, PowerShell wrapper, or provider CLI drops the child. Risk: #774 cannot merge until one review completes. Next session should try a shorter run or a different process host before opening a tooling issue.
- **Chat authentication unverified (2026-09-24):** doctor says auth PRESENT / model catalogue reachable / chat authentication unverified. Acceptable for doctor; a full review run is the real chat-auth proof.
- **Installed shim always runs landing `main`** (2026-09-24): fine after merge; never treat worktree doctor output as installed-route proof of what users run.
- **Left untracked on landing (not ours):** `HANDOFF.d/2026-09-20T0029Z-edge-dev-kimi-grok-trap-exit-status.md`, `Microsoft/`. Another session owns them; do not delete.

---

### Part (b) — sub-agent record

**general-1** (“Grok auth default path”, 53 turns, outcome partial → reported blocked):

- **Asked:** investigate default state dir; open new issue (not #542); permanent fix; tests; PR; independent review (Grok with `AI_GROK_STATE_DIR=…/grok-c` or Qwen); live proof without the env var; do not merge.
- **Did:** opened #765; implemented `grok_default_state_dir()` in both wrappers; extended `tests/grok-auth-link-cases.sh` (10/0) and recorded `tests/test-ai-grok-implement.sh` (84/0); committed `be653ec7`; pushed `fix/grok-default-state-dir`; opened PR #774; live proof that default is `…/grok-c` without `AI_GROK_STATE_DIR`.
- **Did not:** obtain an independent review verdict (`ChildProcess.kill`; Qwen left `turn_in_progress` / 0 turns). Did not merge. Did not close #765.
- **Worktree:** `C:/repos/ai-devops-worktrees/grok-default-state-dir` — live, keep until PR #774 is merged and installed proof passes.

---

### Self-audit (handoff-writer Mode A)

1. **Comprehensive for a brand-new developer?** Yes — §1–§7 define the product, the C:→D: root cause, the exact three-file change, SHAs, and gated next steps.  
2. **As effective as this session?** Yes — §4 lists every failed review attempt and the cmd.exe quoting traps; §5 records the installed-shim vs worktree distinction.  
3. **Every relevant detail?** Yes — goals, state, dead ends, constraints, access, risks, commit/push status explicit in §3; secrets by vault name only in §8.  
4. **Section 0 complete?** Yes — sweep found one blocking owner decision (merge without review?), one recoverable (tooling issue), one out-of-scope handoff; settled rulings listed with dates. Next session must put the list to Albert in one message before work.
