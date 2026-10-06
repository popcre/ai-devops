---
issue: 1336
status: OPEN
owner: mimo/stepfun-harness-efficiency
---

# HANDOFF — StepFun harness token-efficiency plan (ready to implement)

Machine: edge-dev · Agent: mimo · Written: 2026-10-06 (wrap-up)
GitHub signature: `Posted by MiMo chat <id> on edge-dev` (fill `<id>` when posting)
Plan: [`plan_stepfun-harness-efficiency.md`](../plan_stepfun-harness-efficiency.md) — **read its STATUS table first; do not re-derive or re-plan.**

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **BLOCKING — start of coding:** none. The plan is written and reviewed. Albert
  must simply say whether to implement Phases 1–3 now (recommended) or wait.
- **RECOVERABLE:** none.
- **Already settled — do NOT re-ask:** (2026-10-06) fix StepFun token waste;
  plan first, then reviewers, then code. Owner never asked to implement yet.
  Phase 4 outcome is `skip-unsafe` (STATUS W2b) — settled by security gates,
  not an owner question.
- **Not Albert's call:** detector regex, test names, Windows gate grammar,
  whether grep ships or descopes to `head -n` only (technical; plan OPEN-Q4).
  Wipe and security exceptions are the same: technical gate decisions, never an
  owner business question and never granted by Albert.

Put the whole business list to him in ONE message before starting coding.

## 1. What this application is

`popcre/ai-devops` — Albert's public multi-model AI workflow recovery toolkit
(not an app or service). This workstream is the **StepFun reviewer harness**
(`bin/ai-stepfun`, `bin/ai-stepfun-windows-shell`, `config/opencode-stepfun/`):
formal reviews, second opinions, and Linux implement runs for StepFun Step 5.
Hosts: `edge-dev` (Windows) and Ubuntu (StepCode). Branch policy: feature
branch → PR → merge queue; never push `main`.

## 2. What we set out to do this session, and why

Owner asked two subagents to audit StepFun for token efficiency (persistent
sessions, caching, no duplicate resends), then write a fix plan and run it by
Muse. He later asked GLM 5.3 to check the plan. **No harness code was changed.**
Trigger: waste found in the audit (false-positive full re-sends, whole-file
Windows reads, cold sessions, duplicated prompts).

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Windows + Linux harness audits | Done | findings ranked in plan §6 |
| Implementation plan (13 sections + STATUS) | Done, self-audited | [`plan_stepfun-harness-efficiency.md`](../plan_stepfun-harness-efficiency.md) |
| Muse review | Done — `VERDICT: REVISE`; 6 must-fix folded in | `.ai/reviews/muse-stepfun-token-efficiency-plan-r2-20261006T124204Z-968393-5381.md` |
| GLM 5.3 review | Done — `VERDICT: REVISE`; F1/F2/F3 folded in | `.ai/reviews/glm-stepfun-token-efficiency-plan-review-ec1b178ec9de9d8716c24d5484644b6f534d3a9419e849d75c63f21b8b86c711.md` |
| Plan renamed off `.gitignore` `**/*token*` | Done | was `plan_stepfun-token-efficiency.md` |
| Code Phases 1–5 | **Not started** | all plan STATUS rows `⬜ open` |
| Live proof | **OPEN** | leave `- [ ] live proof` on [issue #1336](https://github.com/popcre/ai-devops/issues/1336) |
| First Muse name `stepfun-token-efficiency-plan` | Failed launch (no session) | fenced; not replayed |

Committed/pushed: this handoff + the plan ship as a **prose** PR at wrap-up
(see Shipped in the closing report). Harness code is untouched on `main`.

## 4. Everything we tried that did NOT work

1. **Muse in a foreground bash tool call** — `ai-muse new` started, then the
   tool returned and the process died mid-`provider_launching` (`session_id:
   null`). Reconcile refused (no retained process). Fix: launch Muse via
   `PowerShell Start-Process` + a small script so it survives. Do not replay
   the dead name; use a new name and say so.
2. **GLM first pass on `plan_stepfun-token-efficiency.md`** — snapshot was
   clean; plan absent. Root cause: `.gitignore:8` `**/*token*` matches any
   filename containing `token`, so the plan never entered untracked-file
   snapshots. Fix: rename to `plan_stepfun-harness-efficiency.md`. Any future
   doc named `*token*` will be invisible to reviewers and uncommittable.
3. **Assuming Muse/GLM callers must be `mimo`** — `AI_MUSE_CALLER=codex` and
   `AI_GLM_CALLER=codex` both work from this MiMo session on edge-dev.
4. **WSL for git-bash tools** — `bash -lc` via WSL failed (no distro). Use
   `"C:\Program Files\Git\bin\bash.exe" -lc '…'`.

Rejected *design* approaches (inline packet, drop bubblewrap, full Windows
tools, retry implement) are in plan §7 — do not re-walk them.

## 5. Root causes and key findings

- **HIGH waste:** `rate_limited()` greps whole assistant output for bare
  `429|rate_limited|Too Many Requests` (`bin/ai-stepfun` ~184–190) and
  `run_step_retry` re-runs even on `rc=0` — a good review that quotes "429"
  is discarded and re-bought up to 3×. Contrast correct `credit_stop`
  (~439–448).
- **HIGH (Windows):** shell gate is `ls|cat|head` one path, no flags
  (`ai-stepfun-windows-shell` ~256–261); agent disables read/glob/grep —
  whole-file `cat` only. `grep` also needs runner-allowlist provisioning and
  a metachar-filter rework (code calls it "Layer 1: closed grammar").
- **MED:** every turn cold (StepCode `--no-session` ~405; OpenCode XDG wiped).
  Verdict text duplicated in profile + user prompt. Phase 4 resume fights the
  security wipe (LOCKED-7) — default skip.
- **GLM F1 (must not regress):** stderr detector must keep bare `429` and be
  case-insensitive; only assistant body is off-limits. GLM F2: call
  `detect_engine` before assembling `$full` or the prompt trim no-ops.
- **Caching:** nothing configures provider prefix cache; unique `$rel` early
  in the prompt breaks stable prefixes. Measure before claiming wins (P5).

## 6. Exact next steps

1. Read [`plan_stepfun-harness-efficiency.md`](../plan_stepfun-harness-efficiency.md)
   STATUS + §8 locks + **§9 execution model** (coordinator + one subagent per
   phase, including Phase 4 — owner rewrite 2026-10-06).
2. Optional: second Muse or GLM pass on the revised plan (not required — both
   must-fix sets are folded in).
3. `ai-task-gates start --class reviewer-safety` — StepFun wrapper changes
   (`bin/ai-stepfun*`) are class `reviewer-safety` in `config/task-gates.json`,
   which **requires** `exact-head-independent-review`. Never `code`. Open a
   dedicated worktree — never edit the landing checkout `C:\repos/ai-devops`
   except to land.
4. Implement **Phase 1 only** (P1.1 provider-channel detector, P1.2 retry only
   on failure/empty report, P1.3 tests). You'll know it worked when
   `bash tests/test-ai-stepfun.sh` is green including
   `keeps-review-that-quotes-429` and `keeps-good-verdict-despite-stderr-429`.
5. Then Phase 2 (prompt de-dup + `$rel` late), Phase 3 (Windows `head -n`;
   `grep` only if allowlist + metachar tests pass — else descope to `head -n`).
6. Phase 4 stays **skip-unsafe** (STATUS W2b). A wipe or security exception is
   never sought from the owner — those are AI-reviewer or security-gate
   decisions. Phase 5 counters + live proof checklist on issue #1336.
7. PR → merge queue → confirm `origin/main`. Leave `- [ ] live proof` on issue
   #1336 until a real StepFun run is recorded.

## 7. Constraints and gotchas in force

- Feature branch + PR + merge queue; never push `main`. Doc-only PRs may skip
  waiting on checks; any code/tests/config means normal checks.
- `git var GIT_COMMITTER_IDENT` must be
  `Albert Hazan <u2giants@users.noreply.github.com>` before commit.
- Stage only task-owned files. This repo is public — no secrets, no raw
  transcripts.
- Reviewer wrappers **require** one read-only exact-head independent review
  before merge (class `reviewer-safety` → `exact-head-independent-review`;
  `config/task-gates.json`).
- Consolidation routing (AGENTS.md): harness consolidation → #167;
  provider-wrapper sharing → #169; plan-backlog consolidation → #168 under
  #159.
- **Never name a doc `*token*`** — `.gitignore` `**/*token*` hides it from
  git, snapshots, and reviewers.
- Keep bubblewrap / XDG wipe / implement-never-auto-retry / packet-by-reference.
- PowerShell wrappers stay compatible; run Bash tests in Git Bash.
- Long Muse/GLM jobs: detach with `Start-Process`, or accept published reports
  under `.ai/reviews/` if stdout is empty.

## 8. Access and environment

- Machine `edge-dev` (Windows). Git Bash at
  `C:\Program Files\Git\bin\bash.exe`. Python: `$env:MIMO_PYTHON`.
- `ai-glm doctor` all PASS (model `glm-5.3`); `ai-muse doctor` PASS (Muse
  Spark 1.3 Contributor). Callers: `AI_GLM_CALLER=codex`,
  `AI_MUSE_CALLER=codex` from this session.
- Secrets by title only: vault `vibe_coding`, item `stepfun step5 ai api key`
  (key store `~/.config/ai-devops/secrets/stepfun-api-key`). Reviews never call
  1Password.
- Local tests: `bash tests/test-ai-stepfun.sh` and
  `bash tests/test-ai-stepfun-windows-shell.sh` from a worktree root.

## 9. Open questions and risks

1. Does StepFun's openai-compatible API do automatic prefix caching? (P5
   measures; do not claim wins without counters.)
2. Phase 4 stays `skip-unsafe` (STATUS W2b). Settled — no owner exception.
3. Ship `grep` on Windows or `head -n` only? Criteria: adversarial table green.
4. Risk: a literal follow of an older P1.1 wording ("never bare 429") would
   regress real retries — current plan text keeps bare `429` on stderr only.
5. Risk: `.gitignore` `**/*token*` will hide any future similarly named file.

---

### Self-audit

1. **Could a stranger continue cold?** Yes — §§1–2 name the repo and goal;
   §3 names every artifact; §4 lists failed launches and the gitignore trap;
   §6 is ordered with gates; §7–8 cover rules and access.
2. **Every owner question in §0?** Yes — start coding only. Phase 4 is a
   settled security-gate result (`skip-unsafe`), not an owner question.
   Technical items are not in §0.
3. **Dead ends preserved?** Yes — §4 (Muse detach, gitignore, WSL, callers)
   and plan §7 (rejected designs).
