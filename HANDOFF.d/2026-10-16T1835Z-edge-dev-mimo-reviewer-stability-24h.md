---
issue: 1822
status: OPEN
owner: mimo/edge-dev-class-level
---

# Handoff — reviewer stability ≥24h (class-level remediation)

**Machine:** edge-dev · **Agent:** MiMo · **UTC:** 2026-10-16T21:20Z

## 0. Business decisions only the owner can make

- **None blocking implementation of Step 1.** The plan is public and merged; a successor can start coding without Albert.
- **Recoverable if guessed wrong:** whether to keep funding ScaleDown for future transcript work. Recommendation: do **not** resume bulk raw-transcript extract; use `ai-reviewer-issue` packages instead. (Not required for Steps 1–11.)
- **Already settled — do NOT re-ask:** no human approval for technical actions (2026-09-28); edge-dev repairs without AI-reviewer gates (2026-10-15); database writes skip second-AI (2026-10-14); never remove a reviewer to pass metrics.

**Next session should put any new business questions to Albert in ONE message before starting work.** Technical gates go to assigned AI reviewers or `Blocked —`, never to Albert.

## 1. What this application is

Public toolkit `popcre/ai-devops` that restores and runs a multi-model AI workflow (plan → review → implement → test → review) on Windows `edge-dev` and Linux `edge-dev3`. Not an app or service. Deploy is install/update scripts. Maintained reviewers: Muse, DeepSeek, GLM, StepFun.

## 2. What we set out to do this session, and why

Albert asked why reviewers on edge-dev / edge-dev3 cannot stay green more than ~24 hours after ~8 months. We diagnosed failure classes from 93 incident packages, wrote a class-level fix plan, had Muse critique it, integrated the critique, and landed the plan on GitHub. Implementation of the fixes is **not** started.

## 3. Current state — what is true right now

| Item | State | URL |
|---|---|---|
| Diagnosis (classes C1–C6) | Done; recorded in plan §6 | https://github.com/popcre/ai-devops/blob/main/plan_reviewer-stability-24h.md |
| Plan | Merged to `main` (PR 1823 + Muse-integration PR 1825) | https://github.com/popcre/ai-devops/blob/main/plan_reviewer-stability-24h.md |
| Issue tracker | Open | https://github.com/popcre/ai-devops/issues/1822 |
| Muse critique | ACCEPT WITH CHANGES; all points integrated | Session report under a disposable mini-repo (not a repo artifact) |
| Steps 1–11 implementation | **Not started** | Start at plan Step 1 |
| Sibling programmes | Open, own shared files per plan §4.3 | recurrence-repair and edge-dev-no-review STATUS tables |

## 4. Everything we tried that did NOT work

- **Bulk ScaleDown extract of all last-8-day raw transcripts** (~1.5 GB on edge-dev3, 445×~4MB chunks). Seemed right because Albert asked to send all transcripts. Failed: ~210M+ tokens billed, edge-dev3 structured output not written before stop, extract schema-bound to reviewer failures only (not reusable). Do not repeat without a hard token budget.
- **Native Muse Code engine (`ai-muse doctor` muse-code)** on edge-dev: FAIL — pin/hash not verified (same pin drift class C6). Workaround that worked: `AI_MUSE_ENGINE=opencode`.
- **`ai-muse new` against full `C:\repos\ai-devops`**: hangs in `ai-review-sandbox assert-public` → `ai-task-gates explain` on 1500+ path inventory (Windows). Workaround that worked: tiny git repo with only the plan files + `.ai/` in `.gitignore`.
- **First Muse session** stuck in `preparing` (packet/sandbox hang); could not delete or reconcile (null session_id). New name `plan-critique-mini-r2` succeeded.
- **`bin/ai-doc-safety` on full worktree**: timed out (same large-inventory hang). Workaround: targeted local Markdown link check in Python; all plan links valid.

## 5. Root causes and key findings

From 93 `ai-reviewer-issue` packages (bucket rule in plan §6.1):

1. **C1 (47/93)** — auto-requalification after wrapper/runtime/preloader pulls. Dominant. Fix = pin-digest identity (plan Step 1).
2. **C2** — no single terminal verdict (empty, tool-calls, provisional).
3. **C3** — receipt/sandbox/packet path disagreement.
4. **C4** — non-terminal provider errors, unbounded poll.
5. **C5** — Windows spawn/env (`ChildProcess.spawn NotFound`, E2BIG, command-not-found).
6. **C6** — pin drift, 1Password in review path, fragile report extract.

Multi-joint fail-closed path (packet → receipt → sandbox → door → wrapper → parse → verdict) plus frequent installs makes 24h green structurally hard.

## 6. Exact next steps

1. Read plan STATUS and §4.3 first-writer table: https://github.com/popcre/ai-devops/blob/main/plan_reviewer-stability-24h.md
2. Declare task class (`ai-task-gates start --class reviewer-safety` for Step 1 files).
3. **Step 1 — pin-digest requal freeze** in `install.sh` / `update.sh` / `bin/ai-review-preflight` + tests.  
   **Gate:** `bash tests/test-ai-review-preflight.sh` includes `requal_skipped_when_pin_digest_unchanged` and `requal_required_when_pin_digest_changes`; `bash tests/test-ai-preflight-pinbump.sh` green.
4. Then Steps 2–11 in plan order. Do not edit a shared file until §4.3 allows it.

## 7. Constraints and gotchas in force

- Never push `main`; feature branch + PR + queue. Installed checkout: no `git pull`.
- edge-dev repairs: **no AI reviewer as a gate** (owner 2026-10-15).
- §4.3 first-writer for shared files with the two sibling plans.
- No bulk ScaleDown raw-transcript extract without a token budget on #1822.
- `ai-task-gates` / `assert-public` can hang on large Windows inventories — use a tiny `--paths-from` file first.
- Times in EST; sign GitHub posts `Posted by MiMo chat <id> on <machine>`.

## 8. Access and environment

- Hosts: `edge-dev` (this machine), `edge-dev3` (SSH `edge-dev3`).
- GitHub via `bin/ai-gh` (Git Bash: `C:\Program Files\Git\bin\bash.exe`).
- Secrets: 1Password vault `vibe_coding` by item title only (e.g. `scaledown.ai API key for testing`) — never values.
- Incident store: `ai-reviewer-issue path` per host (private).

## 9. Open questions and risks

- Sibling collision on packet/sandbox/lifecycle (mitigated by §4.3, still a delivery risk).
- C5 may live only in protected Windows entrypoints → transfer request on #1822, not a parallel edit.
- Quiet 24h fails the gate; sample math is locked in plan Step 10.
- Muse plan critique was run on a **mini-repo** (full-repo hang); treat critique as valid but re-read the plan file as source of truth.

---

### Self-audit (handoff-writer Mode A)

1. **New developer, no questions?** Yes — §6 names the exact plan URL, class, and first test commands; §4.3 in the plan owns file conflicts.
2. **As effective as this session?** Yes — §4 dead ends (ScaleDown, Muse engine, full-repo hang) and §5 class counts are written down.
3. **All details for execution?** Yes — next steps have gates; secrets by vault title; URLs not local paths.
4. **Section 0 complete?** Yes — no technical approvals listed; settled rulings listed so they are not re-asked; only optional ScaleDown funding is a business preference.

**Self-audit passed.**
