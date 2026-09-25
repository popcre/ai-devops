---
issue: 743
status: OPEN
owner: mimo/wrapup-muse-followon
---

# HANDOFF — Muse follow-ons after the native-engine migration (and this session’s Grok close-out)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

**Put this whole list to the owner in ONE message before starting work.**

**Blocking (must decide before the next session spends a Muse/Grok paid turn):**

1. **Which Muse item should the next session take?** Three are open and none is in flight from this session: intermittent model-not-found 404 (`#743`), recovery reusing a completed turn after an interrupted follow-up (`#674`), and shell/internet investigation mode (`#257` / `#253`). Recommendation: **`#743` first** — it is a live reliability defect on the now-default Muse Code engine; `#674` second (paid-work safety); `#257` is a feature and can wait. Blocks the only remaining Muse work choice.

**A wrong guess is recoverable:**

2. **Whether “move Muse reviewer off OpenCode” is still on anyone’s plate.** Recommendation: **no — treat it as done.** `plan_ai-muse-native-engine-parity.md` STATUS is all ✅ done through D4; default is `muse-code` since PR #725 (`ee697287`, 2026-09-24). OpenCode stays only as `AI_MUSE_ENGINE=opencode` rollback. A new session should not re-open that migration unless a regression appears.

**Not part of this work and nobody is on it from this session:**

3. **Stale Muse wrapper-reject handoff** `HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md` (`issue: none`). Recommendation: a later housekeeping session assigns it an issue or retires it under the successor rule. Not blocking `#743`.
4. **Untracked on landing, not ours:** `HANDOFF.d/2026-09-20T0029Z-edge-dev-kimi-grok-trap-exit-status.md`, `Microsoft/`. Another session owns them. Do not delete.

**Already settled — do NOT re-ask:**

- 2026-09-17: Muse reviews must run on Meta’s native Muse Code CLI through `ai-muse`, not the OpenCode harness (owner ruling, `plan_ai-muse-native-engine-parity.md` §1).
- 2026-09-24: Default flipped to `muse-code` (PR #725). Rollback is `AI_MUSE_ENGINE=opencode`.
- 2026-09-24: Grok default state dir is `…/grok-c` after the C:→D: move (PR #774 / issue #765). Independent review APPROVE; installed doctor proof on main `c410fd4a`.
- 2026-09-24: No Claude/Codex reviewers for this wrapper work; Grok with `AI_GROK_STATE_DIR=…/grok-c` or `ai-qwen` only (settled in the #765 handoff, still in force if a wrapper change needs review).
- 2026-09-24: Do not force-push shared-db; do not replay paid Muse turns.

## 1. What this application is

`popcre/ai-devops` is Albert’s public multi-model AI recovery toolkit (wrappers, reviewer safety, install scripts, docs). It is not a deployed app. GitHub is source of truth: https://github.com/popcre/ai-devops. Local landing checkout: `C:/repos/ai-devops` (landing-only). Write work uses per-task worktrees under `C:/repos/ai-devops-worktrees/`. Machine nickname: `edge-dev` (Windows 10.0.26200, Git Bash at `C:/Program Files/Git/bin/bash.exe`).

Muse is one reviewer provider, driven only through `bin/ai-muse`. After `plan_ai-muse-native-engine-parity.md` (issue #542), the default engine is **Meta’s native Muse Code CLI** (`muse-code`), not OpenCode. Pin: `config/muse-code/version` = `1.3.0-R3233.1`. Private stores under `~/.local/share|state|cache/ai-devops/muse-code`.

Grok is another reviewer provider (`bin/ai-grok-review` / `bin/ai-grok-implement`). After issue #765 / PR #774 the default state dir is `…/grok-c` when the conventional `…/grok` path is a cross-volume link.

## 2. What we set out to do this session, and why

**Session brief at start (what actually got done):** merge PR #774 (Grok default state dir → `grok-c` after C:→D: move; issue #765), with one independent exact-head review, installed doctor proof, close #765, delete the prior handoff.

**Late in the session Albert said the task was supposed to be:** moving Muse reviewer from the OpenCode harness to a wrapper over Muse Code native CLI.

**Outcome:** the Grok workstream finished completely. The Muse migration was **already finished** before this session (plan STATUS all done; default flip landed 2026-09-24). This session did **not** start Muse work; open Muse defects were identified for a successor (§6).

## 3. Current state — what is true right now

**Done and on `origin/main` (this session):**

- PR **#774** MERGED 2026-09-24T18:23:06Z as `c410fd4a` — `bin/ai-grok-review`, `bin/ai-grok-implement`, `tests/grok-auth-link-cases.sh` gain `grok_default_state_dir()`: `AI_GROK_STATE_DIR` wins; else linked `…/grok` → `…/grok-c`; else auth-home vs conventional device-id split → `…/grok-c`; else conventional `…/grok`.
- Independent exact-head reviews: APPROVE at `efe352ba` (test mock fix) and confirm APPROVE at `56fb8d91` (update-branch merge). Grok session `pr774-efe352-grok-short`; reports copied to `C:/repos/ai-devops/.ai/reviews/grok-pr774-*.md`. Total Grok spend this session ≈ **$0.52**.
- Follow-up test fix `efe352ba` (inside PR #774): device-split mock matches auth path by `/.grok` suffix because `pwd -P` can rewrite `$HOME` under mktemp on Windows CI. Local suite `10 passed, 0 failed`.
- Issue **#765** CLOSED. Proof comment: https://github.com/popcre/ai-devops/issues/765#issuecomment-5819922726
- PR **#793** MERGED 2026-09-24T18:33:22Z as `e48472bf` — deleted `HANDOFF.d/2026-09-24T1550Z-edge-dev-mimo-grok-default-state-dir.md`.
- Installed route proof (no `AI_GROK_STATE_DIR`), after landing `c410fd4a`:
  `state dir    : /c/Users/ahazan/.local/state/ai-devops/grok-c/implement`
  from `C:\Users\ahazan\.local\bin\ai-grok-implement.cmd doctor`.
- Landing `C:/repos/ai-devops` was fast-forwarded through those merges. Session worktrees `grok-default-state-dir` and `close-765-handoff` removed; their local branches deleted.

**Muse migration (not this session — already true on main):**

- `plan_ai-muse-native-engine-parity.md` STATUS rows 0A–D4 all ✅ done. Default `ENGINE="${AI_MUSE_ENGINE:-muse-code}"` (PR #725 `ee697287`). Post-flip governed review of shared-db PR #3441 APPROVE. Issue #542 closed.
- Open Muse issues (not started here): **#743** intermittent model-not-found 404; **#674** recovery must not reuse a previous completed turn after interrupted follow-up; **#257** / **#253** shell/internet investigation mode.

**Not done / not started:**

- Any code fix for #743, #674, or #257.
- Docs/plan edits for those items.
- Retiring the 2026-08-25 Muse wrapper-reject handoff.

## 4. Everything we tried that did NOT work

1. **`bin/ai-grok-review` / `bin/ai-qwen` at long turn budgets earlier in the #765 workstream** — died with `Unknown: ChildProcess.kill`. This session avoided that by using **`--max-turns 12` then `ask --max-turns 4`** on one named session. Do not retry a killed session/turn (paid-work block). Start a fresh named session with a short ceiling.
2. **First Grok run at `efe352ba` hit the 12-turn ceiling without a verdict** (`turn_limit_cancelled`). Fix: same session `ask` with “stop exploring, give ## Verdict now” and `--max-turns 4` — produced APPROVE. Do not auto-raise `--max-turns` after a ceiling.
3. **CI `linux-offline-shard (4)` failed after the test fix** — not the Grok code. `tests/test-markdown-links.sh` failed on `HANDOFF.d/2026-09-24T1605Z-edge-dev-zcode-model-tier-delegation.md` linking `../../plan_model_tier_delegation.md` (escapes repo). Main later had `../plan_…` (correct). Fix: `gh pr update-branch 774` so the PR merge tree picked up current main. Lesson: a bad markdown link on `main` blocks unrelated PRs.
4. **`gh pr merge 774 --squash`** — rejected (“merge strategy for main is set by the merge queue”). Use `gh pr merge --auto` / let the queue run. Docs-only PRs can still `gh pr merge --squash --admin`.
5. **`bin/ai-task-gates` / `bin/ai-pr-wait` via PowerShell `bin\*.cmd`** — “system cannot find the path specified” (the `.cmd` launcher’s bash quoting). Invoke Git Bash explicitly: `& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /c/repos/ai-devops && bin/…"`. Long `ai-pr-wait` runs still hit `Unknown: ChildProcess.kill` in this harness — poll with short `gh` status reads instead.
6. **`bash` as a bare tool name** — mapped to WSL (no distro installed). Always use the Git Bash full path on this host.

## 5. Root causes and key findings

- After the bulk C:→D: move, `…/grok` can be a junction while `~/.grok` credentials stay on C:. Same-inode hard links cannot cross volumes, so the default must pick `…/grok-c` (#765, landed).
- Windows CI `pwd -P` can rewrite `$HOME` under `mktemp`, so tests must not match the auth path by a literal `$HOME/.grok` substring — match `*/.grok`.
- `tests/test-markdown-links.py` checks **all tracked Markdown**; a `../../` link in a handoff on `main` fails every PR’s Linux shard.
- Muse native-engine parity is complete; “move Muse off OpenCode” is not an open task. Remaining Muse work is defects/features on the muse-code engine (#743, #674, #257).
- This MiMo harness kills long-lived reviewer/wait children (`Unknown: ChildProcess.kill`). Short `--max-turns` + `ask` for the verdict is the proven workaround for Grok reviews.
- Installed `~/.local/bin/*.cmd` shims always run **landing `main`**, never a worktree. Installed-route proof requires the change to be merged first.

## 6. Exact next steps

1. Put §0 to Albert in one message. Take only the Muse item he names (recommendation: #743).  
   **Gate:** one issue number is chosen and written at the top of the new session’s task list.
2. Open a worktree from current `origin/main`. `bin/ai-task-gates start --class reviewer-safety` if touching wrappers; `prose` if docs only.  
   **Gate:** `git status` clean on a dedicated branch.
3. For **#743** (recommended): reproduce the intermittent Muse Code model-not-found 404 from `ai-muse` logs / issue body; fix without weakening auth, isolation, or the pin in `config/muse-code/version`.  
   **Gate:** focused tests green (`bash tests/test-ai-muse-code.sh`, `bash tests/test-ai-muse.sh`); independent exact-head review APPROVE if wrapper code changes; merge via queue.
4. For **#674**: ensure recovery never resumes a completed turn as if it were the interrupted follow-up.  
   **Gate:** a fixture for “completed turn + interrupted ask” refuses replay; suites green; review if wrapper code.
5. For **#257** / **#253**: only after 743/674 unless Albert reorders. Do not invent a new harness; extend `ai-muse` on the muse-code engine and keep the OpenCode contract tests green.  
   **Gate:** plan or issue comment names the exact dispatch surface; no OpenCode pin bump.
6. Successor rule: the session that lands the **next** Muse step may delete `HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md` only after carrying its obligations forward (§0 item 3). Delete **this** file only when #743’s fix is verified on `main` and no §0 item is still open.

## 7. Constraints and gotchas in force

- Never push to `main`. Branch → PR → merge queue. Docs-only may admin-merge.
- Canonical checkout `C:/repos/ai-devops` is landing-only; edit in a worktree.
- `git var GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>` before the first commit.
- GitHub calls through `bin/ai-gh` when the wrapper works; if `ai-gh`/`ai-pr-wait` hang or die, short `gh` polls are the recovery — note the exception in the PR/issue.
- Sign every GitHub post: `Posted by MiMo chat <id> on edge-dev` (`<id>` = `$MIMO_SESSION_ID` or `unknown`).
- No Claude/Codex reviewers for reviewer-wrapper changes. No paid Muse turns as casual probes. Do not force-push shared-db.
- Preserve capability: never remove Muse auth/usage honesty or Grok hard-link safety as a substitute for a fix.
- One unproven live-behavior outcome per session.
- Do not edit another session’s `HANDOFF.d/` file. Root `HANDOFF.md` is a static pointer.

## 8. Access and environment

- GitHub: `gh` / `bin/ai-gh` on `edge-dev`, authenticated as `u2giants`.
- Muse: `bin/ai-muse` default engine `muse-code`; pin `1.3.0-R3233.1`. Rollback `AI_MUSE_ENGINE=opencode`.
- Grok: `/c/Users/ahazan/.grok/bin/grok` 1.0.13; state `…/grok-c`. Review wrapper `bin/ai-grok-review`.
- Secrets: 1Password vault `vibe_coding` only (names, never values). No credentials appeared this session.
- Review sandboxes: `/d/ai-data/local/state/ai-devops/review-sandboxes/…`.
- Git Bash path: `C:/Program Files/Git/bin/bash.exe` (required on this host).

## 9. Open questions and risks

- **#743 404 is intermittent** (2026-09-24 issue open) — may be provider-side; a wrapper fix must not mask a pin/catalog problem. Prefer reproduction evidence before code.
- **#674 is paid-work safety** — higher severity than #257 if both remain open.
- **ChildProcess.kill** (2026-09-24) still affects long waiter/reviewer runs in this MiMo harness. Short-turn Grok reviews work; `ai-pr-wait` is unreliable here.
- **Chat authentication on Grok** still “unverified” in doctor (catalogue reachable). Acceptable for doctor; a full review run is the real proof (we completed reviews, so chat auth works).
- **Shared-db orchestrator-marker `3480`** (`shared-db.orch edge-dev mimo-queue`) was open on GitHub during wrap-up **but was not this session’s work**. A shared-db session owns it; do not close it from a Muse/Grok session.

---

### Self-audit (handoff-writer Mode A)

1. **Comprehensive for a brand-new developer?** Yes — §1–§7 define the product, the finished Muse migration vs open defects, the finished Grok #765 work, SHAs, and gated next steps.  
2. **As effective as this session?** Yes — §4 lists every failed command/CI path and the short-turn Grok workaround; §5 records the markdown-link and installed-shim traps.  
3. **Every relevant detail?** Yes — goals, state, dead ends, constraints, access, risks, commit/push status explicit; secrets by vault name only.  
4. **Section 0 complete?** Yes — sweep found one blocking owner choice (which Muse issue), one recoverable (treat migration as done), two out-of-scope leftovers; settled rulings listed with dates.
