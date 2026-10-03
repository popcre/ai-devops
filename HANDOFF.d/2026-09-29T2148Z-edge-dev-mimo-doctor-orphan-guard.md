---
issue: 1116
status: OPEN
owner: mimo/doctor-orphan-scan-guard
---

# HANDOFF — process re-cut landing (issue #1116) (2026-09-29)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this WHOLE list to Albert in ONE message before starting work.

**Blocking**
- None. Albert has already accepted the technical shape and delegated technical choices to "you and 1 reviewer."

**Wrong guess is recoverable**
1. **Whether the 2026-09-23 "owner ruling" on Grok version pins is really his.**  
   The repo records it in `config/provider-cli-versions.json` (notes: exact pin "blocked every review whenever Grok updated itself"; now `version_match: "minimum"`). Albert said on 2026-09-29 he does **not** remember ruling. **Recommendation: treat the floor design as correct on engineering grounds and stop calling it an owner ruling; do not reimplement item 3.** Blocks: nothing if accepted; reopens item 3 if he wants exact pins back.
2. **Whether to run the full autonomous orchestrator prompt in one chat or split children across chats.**  
   **Recommendation: one coordinator session as written in §6.** Blocks: how #1116 is worked.

**Not in this workstream, nobody on it**
3. **Canonical checkout `C:\repos\ai-devops` is dirty with other sessions' files** (AGENTS.md, `bin/ai-review-sandbox` local hunk, gemini skill, several untracked HANDOFF.d / plan_ files). **Recommendation: leave them; do not clean.** Blocks: nothing.

**Already settled — do NOT re-ask**
- (2026-09-29) Albert accepts the re-cut shape: hours saved first (P3 CI fast-fail, P7 timeout diagnosis, orphan TTL), not a doctor spawn guard alone.
- (2026-09-29) No new root `plan_*.md`. No item 3 pin-only lane. No item 9 `ai-ci-status`. No loss ledger. No lease TTL.
- (2026-09-29) Parent issue is popcre/ai-devops#1116; children A1/A2/B1/C1–C4/D1.
- (2026-09-29) Implementation plan was written with the `implementation-plan-writer` skill (`IMPLEMENTATION-PLAN.md`).
- (2026-09-29) PR #1060 (digest `--full-index`) is merged on `origin/main` as `9d99ad24`.
- (2026-09-29) Qwen reviews work on edge-dev without Docker (`~/.qwen/settings.json` `tools.sandbox: false`).

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public recovery/operating toolkit for a multi-model AI workflow (Claude, Codex, Gemini, Grok, Muse, GLM, Qwen, Kimi, StepFun wrappers; review sandbox/packet evidence tools; task gates; installers). Not an app or database. GitHub `main` is protected (merge queue). Host `edge-dev` (Windows). Canonical checkout `C:\repos\ai-devops` is landing-only; task work in worktrees.

## 2. What we set out to do this session, and why

1. Land PR #1060 (review-sandbox `--full-index` digest fix) and finish a process-plan critique from mined chat transcripts.
2. After four advisors (GLM, Gemini, StepFun, Qwen) debated the nine findings, Albert challenged that the only output was "a health check tweak." He was right: we under-shot. Re-ranked by hours saved with StepFun.
3. Produce a durable implementation plan + GitHub parent issue + an autonomous next-session prompt.

## 3. Current state — what is true right now

**Done and verified**
- **PR #1060 merged** to `origin/main` as `9d99ad24 fix(review-sandbox): full-index digest so shallow snapshots match (#1060)`. Muse exact-head APPROVE on `698b2ea3` (`.ai/reviews/muse-final-check-20260929T153431-3362904-15608.md` in sandbox worktree). Live Muse packet succeeded (382s).
- **Reviewer incidents resolved** in `C:\repos\ai-devops\.ai\reviewer-issues\`: `20260929T125838Z-edge-dev-muse-1961321`, `20260929T130211Z-edge-dev-grok-1989270`.
- **Issue #1116** opened: parent for children A1, A2, B1, C1–C4, D1.
- **`IMPLEMENTATION-PLAN.md`** on branch `mimo/doctor-orphan-scan-guard` (commits `ec684b56` then `ce789d29` re-cut to hours-saved priority). Worktree `C:\repos\ai-devops-wt-doctor-orphan-guard`. **Pushed.** Not merged (docs-only plan; may be PR'd with implementation).
- Focused digest test `shallow_and_full_odb_agree_on_source_digest` passed (full == shallow digest `9cdbc11c…`).
- Qwen 3.8 Max and StepFun both produced full plan critiques and a ranking (`/tmp/rank-sf.log`, `.ai/reviews/qwen-jev-plan-debate-qwen-2-*.md`).

**Not started**
- A1 P3 CI fast-fail + no-progress detector (top hours).
- A2 P7 timeout ≠ broken reviewer.
- B1 orphan/task TTL + reap.
- C1–C4 docs cleanup.
- D1 doctor orphan spawn guard (small residual).

**Branches**
| Branch | State |
|---|---|
| `mimo/sandbox-digest-full-index` | Merged via #1060; safe to delete later |
| `mimo/doctor-orphan-scan-guard` | Plan pushed (`ce789d29`); KEEP for implementation |

## 4. Everything we tried that did NOT work

1. **`bash -lc` from PowerShell** → WSL with no distro. Use `C:\Program Files\Git\bin\bash.exe -lc`.
2. **Long `ai-qwen`/`ai-stepfun` under a foreground tool timeout** → killed mid-turn; empty `pending.jsonl`. Run detached (`PowerShell Start-Process`) or accept published reports under `.ai/reviews/` even when stdout is empty.
3. **Qwen review without sandbox config** → "Sandbox is enabled but failed to determine command" (no Docker/podman). Fix that worked: `~/.qwen/settings.json` `"tools": {"sandbox": false}` and `"env": {"QWEN_SANDBOX": "false"}`.
4. **`ai-qwen` session resume** after tree/packet change → "no longer reproduces its exact sealed evidence". Start a new named session.
5. **Inline PowerShell with parens/semicolons in prompts** → ParserError. Always `--prompt-file` / `$(cat file)` from Git Bash.
6. **Assuming "fold into an existing plan" = work done.** Folding into a 0%-started plan is deferral (Qwen). Rank by hours saved.
7. **First plan draft led with a doctor spawn guard only.** Albert: "That's going to speed everything up?" Correct. Re-cut (commit `ce789d29`).
8. **Citing `plan_workflow-efficiency.md:197` as a ban on `ai-ci-status`.** Qwen: that line is about document proliferation. Drop item 9 via `AGENTS.md` reuse rule + P9 measured priority instead.
9. **Calling `config/provider-cli-versions.json` note an "owner ruling" without Albert's words.** He does not remember it. Do not relabel AI-written notes as owner rulings.
10. **`bin/ai-gh push`** is not a thing (`ai-gh` wraps `gh` only). Use `git push`.

## 5. Root causes and key findings

- **Digest mismatch root cause (fixed):** `source_inventory` hashed `git diff` text; ODB size changes abbreviated `index` width. `--full-index` forces 40-hex. (PR #1060.)
- **Real remaining time sinks (transcript-ranked, StepFun-confirmed):**  
  (1) Known fast failure still starts long suites (`verify.yml` runs shards when classifier is not success) and there is **no no-progress detector** in `bin/`/`tools/`/`.github/` for test loops — P3 STATUS **open** in `plan_workflow-efficiency.md`.  
  (2) Probe timeout classified `provider-timeout` then handled like a broken provider (`bin/ai-review-preflight`); `CHECK_TIMEOUT` default **10s** (not 60).  
  (3) No task/orphan TTL (14h background tasks).
- **Doctor preflight worst path already shipped** (report-never-act; chunked index). Leftover cost: `glm_orphan_sandbox_report` per-dir `stat`+`sed`; `reconcile_implementation_records` open-record path can exceed 10s/record on Windows.
- **Item 1 closed** (empty-report fail-closed `bin/ai-review-pool`; lease liveness complete — **no TTL by design**).
- **Item 3 must not ship** (Grok auto-update + exact pin = every review blocked; floor already in config).
- **72 root `plan_*.md`**; #168 classified 48 (2026-09-08); **18 added 28–29 Sep missing from `docs/implementation-plan-index.md`**.
- **Windows Git Bash `ln -s` copies files** — `decision_file_symlink_is_refused` is a pre-existing env failure, not a product bug.

## 6. Exact next steps

**Use the autonomous orchestrator prompt at the end of the closing report (and in §7).** Summary:

1. Coordinator session reads #1116 + `IMPLEMENTATION-PLAN.md` §9 and dispatches **one subagent per child**.
2. Order: A1 → A2 → B1 → C1–C4 → D1 (A1 before D1; A2 parallel-safe).
3. Each subagent: one child only; code/tests/PR/review/merge; return artifacts; coordinator ticks #1116 only when evidence is openable.
4. **Success:** all #1116 boxes ticked with SHAs/tests; plan STATUS rows cite artifacts.

Verification gate per child is in `IMPLEMENTATION-PLAN.md` §9–10.

## 7. Constraints and gotchas in force

- Never push `main`. Branch + PR + merge queue. `git var GIT_COMMITTER_IDENT` = Albert Hazan.
- Stage only task-owned files. Canonical `C:\repos\ai-devops` landing-only.
- Reviewer-safety paths: independent exact-head APPROVE before merge; `ai-task-gates start --class …`.
- `bin/ai-gh` for GitHub API; `bin/ai-pr-wait <pr> --timeout-minutes N` for waits; leave the issue/PR as the card if the wait outlives the turn (registration is OUT; #1183 child 3).
- Windows: Git Bash `C:\Program Files\Git\bin\bash.exe`.
- No new root `plan_*.md`; no item 3; no item 9 tool; no loss ledger; no lease TTL; no wall-clock primary asserts.
- One unproven live outcome per session **per subagent** when running the orchestrator prompt.
- Private transcripts never enter the public repo or reviewer packets.
- Qwen without Docker: `~/.qwen/settings.json` sandbox false (already set).

## 8. Access and environment

| Need | Location |
|---|---|
| Host | `edge-dev` (Windows) |
| Plan branch / worktree | `mimo/doctor-orphan-scan-guard` / `C:\repos\ai-devops-wt-doctor-orphan-guard` |
| Implementation plan | `IMPLEMENTATION-PLAN.md` (commits `ec684b56`, `ce789d29`) |
| Parent issue | https://github.com/popcre/ai-devops/issues/1116 |
| Merged digest fix | `origin/main` `9d99ad24` |
| Sandbox worktree (merged PR) | `C:\repos\ai-devops-wt-sandbox-full-index` |
| Reviewer issues dir | `C:\repos\ai-devops\.ai\reviewer-issues\` |
| Qwen / StepFun / Muse wrappers | `bin/ai-qwen`, `bin/ai-stepfun`, `bin/ai-muse` |
| 1Password | vault `vibe_coding` — names only, never values |
| Session id | `ses_ffe5f125429feffegbh72RPXnT` |

## 9. Open questions and risks

- (2026-09-29) Is the Grok "owner ruling" real? §0 item 1.
- (2026-09-29) `plan_live-proof-session-sizing.md` index row says Completed; plan STATUS may say partial — resolve remote state before marking (C3).
- (2026-09-29) Reconcile open-record path cost: implement in D1 or name residual with owner (plan §8).
- (2026-09-29) Shared-db orchestrator-marker issue #3832 is OPEN but **owned by another session** — this wrap-up does not take it over.
- (2026-09-29) Canonical checkout dirt is other sessions' work — do not clean in this workstream.

---

## Self-audit (handoff-writer)

1. **Newcomer can pick up without questions?** Yes — §0 decisions, §3 SHAs/branches, §4 dead ends, §6 next steps, §8 access.  
2. **As effective as this session?** Yes — ranking rationale, advisor outcomes, Qwen-without-Docker, detached-run traps, item 3/9 citations all recorded.  
3. **Every relevant detail?** Yes — goal, failures, locked rules, verification gates in plan §9–10, secrets by vault name only.  
4. **Section 0 sees every owner ask including out-of-scope?** Yes — Grok ruling question, orchestrator mode choice, dirty canonical files, plus "already settled" list. Sweep found no other `owner/decide/approve` sentences outside §0.

**Self-audit: PASS.**
