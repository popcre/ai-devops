---
issue: 1110
status: OPEN
owner: mimo/edge-dev-reviewer-pipeline-core
---

# HANDOFF — Reviewer pipeline core (diagnosis, plan, issues)

**Machine:** edge-dev · **Agent:** MiMo · **UTC:** 2026-09-29T22:05Z  
**Supersedes:** `HANDOFF.d/2026-09-29T1427Z-edge-dev-mimo-reviewer-pipeline-core.md` (thin; retire if this file is accepted)

---

## 0. Decisions only the owner can make

**Put this whole list to Albert in ONE message before starting work.**

### Blocking
1. **Approve shipping public-safe docs on a docs PR** (plan + harness design + this handoff). Blocks any merge. *Recommendation: yes — docs-only, then implementers work from GitHub.*
2. **Confirm private investigation files stay out of `popcre/ai-devops`** (raw transcript diagnosis with hostnames, Dropbox paths, billing notes). *Recommendation: yes — rewrite public-safe only; never push `docs/reviewer-failure-evidence/` or worktree `docs/critique-pack/reviewer_failure_root_cause.md`.*

### Wrong guess recoverable but wasteful
3. **Which provider accounts need credit** if a door hits 402/92 (StepFun needed recharge 2026-09-29). *Recommendation: treat as owner billing; rotate reviewers; do not “fix” code.*
4. **Whether implement/write doors stay first-class** in the runner (owner ruling #974: reviewers can write). *Recommendation: yes — two contracts (review vs implement), not one thin adapter.*

### Outside this workstream — nobody on it
5. **`popcre/shared-db` orchestrator-marker #3832 is OPEN** (another MiMo successor). Not touched by this session. *Recommendation: owner of that session continues; do not leave marker open at their wrap-up.*
6. **Landing checkout `C:\repos\ai-devops` has foreign uncommitted edits** (`AGENTS.md`, `bin/ai-review-sandbox`, `scripts/ai-housekeeping/move-bulk-to-d.ps1`, `skills/shared/gemini-code-delegation/SKILL.md`) and other sessions’ `HANDOFF.d/` / `plan_shared-db-*` files. *Recommendation: do not touch those paths; only stage your own.*

### Already settled — do NOT re-ask
- Reviewers = Muse, Grok, Qwen, StepFun, DeepSeek, Gemini (suggestion reports + may implement). Claude/Codex write/orchestrate. Desktops are not the fleet. *(Albert, 2026-09-29)*
- Debates concluded: Qwen + StepFun **REJECT** the draft plan as unsafe to merge; agree on two-step first landing (privacy → whole-packet retention) and structural runner later.
- Issues **#1110** parent, **#1111–#1115** children created.

---

## 1. What this application is

`popcre/ai-devops` is Albert’s **public** recovery/ops toolkit for a multi-model AI workflow (reviewer wrappers, evidence, lifecycle, skills, policy). Not a hosted app. Installation is the deploy mechanism. Canonical checkout `C:\repos\ai-devops` is landing-only. Runtime wrappers also live under `C:\repos\ai-devops-reviewer-install`. Host for this session: Windows `edge-dev` (Git Bash; never bare WSL bash).

---

## 2. What we set out to do this session

**Business:** stop AI reviewers dying every 24–48 hours despite endless fixes.  
**Technical:** diagnose from 5 weeks of transcripts + code audits; get independent critiques; write an implementation plan; link GitHub parent/child issues; hand a self-contained prompt for a fresh implementing session.

**Trigger:** Albert: “reviewers fail over and over… fix after fix after fix endlessly.”

---

## 3. Current state (true right now)

| Item | State |
|---|---|
| Jev 5-week study | Done locally (4,580 sessions; 2,591 discard; 1,989 remainder). Artifacts under `.ai/tmp/` (gitignored) — not for public commit |
| Root-cause write-up | `docs/reviewer-failure-full-writeup.md` (local; scrub Dropbox/host/billing before public push) |
| Evidence folder | `docs/reviewer-failure-evidence/` (local; **contains private quotes — do not push**) |
| Harness design | `docs/reviewer-harness-consolidation.md` (public-safe) |
| Plan of record | `plan_reviewer-pipeline-core.md` STATUS + issue map (needs Phase A rewrite to consensus — see §6) |
| GitHub issues | **#1110** parent; **#1111** evidence retention; **#1112** requalification (24–48h fix); **#1114** runner/doors; **#1115** outage vs code — **open, not implemented** |
| Autonomous implementer prompt | `.ai/tmp/autonomous-implementer-prompt.md` (also presented to Albert) |
| Packaging digest fix | Branch `fix/snapshot-digest-full-index` @ `4fa931d6` (worktree `ai-devops-wt-snapshot-digest`), 110/0 sandbox tests — **local only, not merged** |
| Critique worktree | `ai-devops-wt-gemini-critique` branch `tmp/gemini-shared-core-critique` — local commits with critique-pack (**do not push as-is**; privacy) |
| Implementation | **Not started** — Albert will open a **fresh session** with the autonomous prompt |

---

## 4. Everything we tried that did NOT work

| Attempt | Why it seemed fine | How it failed |
|---|---|---|
| Jev classify “shared-db failures” earlier session | Cheap filter | Wrong question; re-ran with reviewer-failure question |
| Muse critique | Albert asked for Muse | `preparation_failed`, then `snapshot-digest-mismatch` + MSYS fork exhaustion. Incident `…-muse-1965021` |
| Grok critique (first) | Switch after Muse | Same `snapshot-digest-mismatch` before paid turn. Incident `…-grok-1993325` |
| Fix digest in isolation | Obvious bug | Two competing uncommitted fixes; reconciled (Fix B wins) — still unmerged |
| Gemini critique (first pack) | Clean worktree required | Worked, but **wrong fleet framing** (Claude/Codex-as-reviewers) |
| Gemini re-brief | Extensive pack | **Quarantined** `live-qualification-required` (RC3 live) — did not force-requalify |
| StepFun first extensive | After recharge | HTTP **402 quota_exceeded** (incident `…-stepfun-448943`); later recharged; subagent produced REVISE |
| “Library wrappers call” | `ai-review-lifecycle` exists | Muse/Gemini/Qwen/DeepSeek/StepFun never call it — **rejected shape** |
| Phase A as first drafted | “Safe evidence PR” | Qwen/StepFun/Claude/Grok: patches **non-fleet** cleanup (claude/codex/pool); 3-file copy **fails** `verify-retained`; success gate (`*_captured`) unreachable as written |
| Claude Opus 5.5 low | Albert asked | Wrapper **pins `claude-opus-5 --effort high`**; cannot change pin without safety-path edit |
| Long bash one-liners for paid reviewers | Fast | Harness `ChildProcess.kill` on this host — use short commands / subagents / redirects |

---

## 5. Root causes and key findings

1. **24–48h loop:** wrapper change → fingerprint drift → prior qualification **deleted before** live canary (`bin/ai-review-preflight` ~334,350 for gemini/qwen) → tool locked out → another “fix” → repeat. **#1112**
2. **Evidence destroyed** after success (EXIT traps `packet remove` / `remove-copy`; base pin ref dropped). Next diagnosis starts blind. **#1111**
3. **Eight copies of governance plumbing**; no forcing function. **#1114**
4. **Outages filed as code bugs** (credit 402, 403, quota). `tools/reviewer_admission.py` already has credit/usage classes — do **not** invent blanket 403/404/429=outage. **#1115**
5. **Integrity:** `git diff` index SHA **abbreviation width** differs full vs shallow clone → `snapshot-digest-mismatch`. Fix: `--full-index` (`4fa931d6`).
6. **Owner fleet correction** is mandatory in every brief (see §0 settled list).
7. **`verify-retained` binds to recorded sandbox root** — a copied packet may never validate until re-bind is designed (open in #1111).
8. Tag limits real: muse caller ≤40, gemini tag ≤64, sandbox dir ≤77 (plan’s 48/78 were wrong).

Full narrative: `docs/reviewer-failure-full-writeup.md`. Critiques: StepFun REVISE×2, Qwen REJECT, Grok REVISE, Claude Opus REJECT (19 findings).

---

## 6. Exact next steps

Albert’s chosen path: **new fresh-context session** using `.ai/tmp/autonomous-implementer-prompt.md` (paste entire file). If working from this handoff instead:

1. **Privacy gate.** Inventory local docs; strip hostnames, Dropbox paths, billing, owner chat quotes. Do not push `docs/reviewer-failure-evidence/` or raw `reviewer_failure_root_cause.md`. *Gate:* `rg` clean + `bin/ai-public-boundary-check` + human skim of diff.
2. **Rewrite Phase A in `plan_reviewer-pipeline-core.md` to consensus:** whole managed packet store-before-delete inside `ai-review-packet` / `ai-review-sandbox` shared deleters; A1 lifecycle `--packet-dir`/`--packet-sha256` + `join`; fix retain/verify-root; **no** gemini/qwen wrapper byte edits; **no** A4 scoreboard verdict requirement in that PR; drop A2 wrapper-trap edits. *Gate:* plan STATUS updated; Qwen/StepFun “safe first step” language matched.
3. **Implement #1111** on a feature branch + PR + independent exact-head final review + tests + live proof. *Gate:* full packet survives delete; hash on lifecycle; tests green via Git Bash.
4. **Implement #1112** versioned requalification; keep “cannot authorize untested bytes” tests. *Gate:* failed canary keeps last good **record**; no lockout demo.
5. **Implement #1114** runner + doors (native vs OpenCode) per `docs/reviewer-harness-consolidation.md`; structural gate via pool/preflight. *Gate:* one review from a native door and one OpenCode door share one lifecycle/packet format.
6. **Implement #1115** extend admission classes carefully. *Gate:* 402/92 → credit; bare 404 not auto-outage.
7. Tick children on **#1110**; update this plan STATUS with artifacts; retire this handoff only when #1110’s children are proven done.

**Verify success:** Albert sees reviewers stay qualified across routine fixes; every review has a verifiable packet; no private files on `origin/main`.

---

## 7. Constraints and gotchas

- Never push `main`; branch + PR + merge queue. Docs-only PRs may `gh pr merge --squash --admin` after checks policy — **still no private content**.
- `git var GIT_COMMITTER_IDENT` = `Albert Hazan <u2giants@users.noreply.github.com>` before first commit. Stage **only** your files.
- `bin/ai-gh` for GitHub; `bin/ai-pr-wait --timeout-minutes N` for PRs; no open-ended `gh` polls; long waits leave the issue/PR as the card (registration is OUT; #1183 child 3).
- Reviewer safety path: wrapper/evidence/safety-test changes need **one read-only exact-head final review** before merge.
- Do not force Gemini/Qwen `qualify-live` to “unstick” quarantine — that is #1112’s bug.
- Windows: `C:\Program Files\Git\bin\bash.exe`; do not use WSL bash (no distro).
- Secrets: 1Password `vibe_coding` via `op run` only (e.g. `typesafe.ai API`); never log values.
- Concurrency: do not edit other sessions’ `HANDOFF.d/` or their dirty files (see §0.6).

---

## 8. Access and environment

- Host `edge-dev` (Windows). Repo `C:\repos\ai-devops`. Install tree `C:\repos\ai-devops-reviewer-install`.
- Reviewers on host: Grok, Qwen, DeepSeek, StepFun (OpenCode on Windows **if** that code is on the branch you run), Muse (engine switch), Gemini (may be quarantined).
- Jev: `bin/ai-jev-probe` / `op run` — evaluation only.
- GitHub: `popcre/ai-devops` (public). Issues #1110–#1115.
- No UI. Tests: `bin/ai-test-local --check-collision` then focused `tests/test-ai-*.sh` via Git Bash.

---

## 9. Open questions and risks

- **Retain vs verify-retained root bind** — copied packet may fail validation until redesigned (#1111 must solve; do not ship fake retain).
- **Implement contract size** — doors are not thin for write; avoid monolith (see harness doc).
- **Private pack on local branch** `tmp/gemini-shared-core-critique` — push risk; scrub or abandon branch after extracting public-safe notes.
- **Unmerged digest fix** `4fa931d6` — needed for stable packet builds; land via normal PR with review.
- **Plan STATUS still describes pre-consensus Phase A** — next implementer must rewrite before coding (§6 step 2).
- **Budget:** StepFun/Grok/Qwen paid turns cost real money; do not re-run full critiques unless the plan text changed.

---

## Self-audit

1. **Newcomer continue without questions?** Yes — §6 numbered steps + gates; §5 root causes; §3 file/branch truth.
2. **As effective as this session?** Yes — §4 dead ends (Muse/Grok packet bug, 402, wrong fleet, rejected Phase A) are written; not only the happy path.
3. **Every detail for execution?** Yes — paths, issues, branch SHA `4fa931d6`, constraints §7, access §8.
4. **§0 complete if owner reads only that?** Yes — ship approval, private-file rule, billing, implement policy, shared-db marker #3832, foreign dirty files; plus settled list to stop re-asking.

**Audit: PASS** (2026-09-29). Checklist: 10 sections; owner sweep in §0; dead ends §4; gates §6; secrets by location; commit status explicit in §3.
