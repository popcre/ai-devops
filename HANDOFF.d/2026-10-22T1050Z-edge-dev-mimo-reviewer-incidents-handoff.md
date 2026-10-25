---
issue: 1678
status: OPEN
owner: mimo/edge-dev-reviewer-incidents-wrapup
---

# HANDOFF — edge-dev reviewer incidents: two repairs landed, install paused

handoff-id: 2026-10-22T1050Z-edge-dev-mimo-reviewer-incidents-handoff
machine: edge-dev
agent: mimo
session: ses_ffe5e9fe9997cffesnG5qfYNlw
repo: popcre/ai-devops
workstream: plan_edge-dev-reviewer-repair-no-review remaining incidents after steps 0–5
predecessor: [2026-10-21T2012Z-edge-dev-mimo-1678-steps5-7.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-21T2012Z-edge-dev-mimo-1678-steps5-7.md) (step 5 PR was other session; now merged)

---

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**Blocking:**

1. **Observation week (#1948) vs finishing #1678 install (step 7).** The freeze
   plan forbids reviewer-repair PRs and toolkit installs once the window file
   is live; step 6 (fleet install + freeze declaration) was still open when
   this session paused. Two repair PRs already merged before that declaration.
   **Recommendation:** let #1948 own the freeze timeline; do not install until
   that programme's step 6, or explicitly re-open #1678 step 7 outside the
   freeze. Blocks installed hashes and live smoke.

**Recoverable if guessed wrong:**

2. **DeepSeek full-source review hang** is a known #1783/#1948 observation
   (not repaired during freeze). If install needs an exact-head review of a
   large tree and DeepSeek hangs, that is expected this week — do not treat it
   as a new outage. **Recommendation:** log with `ai-reviewer-issue`; wait for
   the freeze window design.

**Already settled — do NOT re-ask:**

- Albert, 2026-10-15 — repair implementation must not need AI reviewers as a gate.
- Albert, 2026-10-16 — path 1 (reviewed workstream may edit protected wrappers) was for the GLM REVISE fix only; closed again.
- Albert, 2026-10-19 — stop the finding-by-finding review loop; Medium/Low do not hold the merge.
- Albert, 2026-10-21 (edge-dev3) — observation-week design: fast-fail, skip-list, non-blocking reviews; routine ops allowed; no reviewer-repair PRs / installs during the week.
- Owner 2026-10-15 — independent review required only in `popcre/shared-db`.

**None of the items above need a technical approval from Albert.** Exact-head
reviews and installs go to assigned AI reviewers and `ai-task-gates`.

---

## 1. What this application is

[`popcre/ai-devops`](https://github.com/popcre/ai-devops) is Albert's public
recovery toolkit for a multi-model AI coding workflow (plan → review →
implement → test → review). Host for this session: **edge-dev** (Windows 11,
Git Bash / MINGW64). Reviewer wrappers: Muse, DeepSeek, GLM, StepFun.
Sibling plan on edge-dev3: [plan_reviewer-recurrence-repair.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-recurrence-repair.md).
Observation-week plan: [plan_reviewer-observation-week.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-observation-week.md) (#1948).

## 2. What we set out to do this session, and why

Albert: **"all reviewers are broken on this machine."** Goal: make an
independent review on edge-dev recordable again. Another session (wrapping
#1678 steps 4–7) handed over three unowned incidents: GLM top-level path
compare, multi-reviewer recording, StepFun extra decision lines. Those blocked
step 6 live smoke.

## 3. Current state — what is true right now

| Outcome | State | Evidence |
|---|---|---|
| StepFun terminal `VERDICT:` → `## Verdict` | **Merged** | [PR #1947](https://github.com/popcre/ai-devops/pull/1947) [`44df8b97`](https://github.com/popcre/ai-devops/commit/44df8b978cbaec17c7be40a78a3ec6b32c460725) 2026-10-21 6:35 PM EDT |
| GLM `governed_source_root` uses path-identity | **Merged** | [PR #1954](https://github.com/popcre/ai-devops/pull/1954) [`73508ce2`](https://github.com/popcre/ai-devops/commit/73508ce2eebac19df9bb8e32080b2c3f68c77cb7) 2026-10-21 7:23 PM EDT; DeepSeek final-check APPROVE on `b0c1d9a6` |
| `ai_git_toplevel` / `ai_same_path` helper | **Merged** | in #1947; [tools/lib/path-identity.sh](https://github.com/popcre/ai-devops/blob/main/tools/lib/path-identity.sh) |
| Local incidents (8) | **partially-resolved** | repair SHAs `44df8b97` / `73508ce2` / `b5cfa876` / `d13f4157` recorded via `ai-reviewer-issue resolve` |
| Step 5 Git Bash / ProgramFiles | **Merged (other session)** | [PR #1938](https://github.com/popcre/ai-devops/pull/1938) |
| Step 6 live smoke | **Not done** | needs install + freeze rules |
| Step 7 code-only install | **Deferred** | DeepSeek full-source review hangs at door-call; freeze may forbid installs |
| shared-db `--record` drops some approves | **Not started** | incident `20261021T164147Z-edge-dev-multi-reviewer-recording-3487006` partially-resolved; live `--record` proof still open |

Live proof this session: DeepSeek `final-check` on `b0c1d9a6` completed with
`verdict: APPROVE` and a durable report under the worktree's `.ai/reviews/`
(PR #1954 comment). That is the first completed review through the repaired
path on this host.

## 4. Everything we tried that did NOT work

- **`bash` without full Git Bash path** resolves to a WSL stub ("Windows
  Subsystem for Linux has no installed distributions"). Always
  `"C:\Program Files\Git\bin\bash.exe" -lc '...'`.
- **PowerShell eats `$(...)` and `<` inside `bash -c "..."`.** Use single-quoted
  `bash -lc '...'` or write a `.sh` file and run it.
- **`ai-task-gates explain`** prints a long warning log then JSON; it can look
  hung. Timeout at 20s still returned the classification.
- **StepFun door test stub used `$RH` inside a single-quoted heredoc.** `RH` is
  not exported to the stub; the write went nowhere and the door exited
  non-zero while `not_blocked` still passed. Inline the answer (see
  `tests/test-ai-stepfun.sh` after #1947).
- **Evidence paths for `ai-reviewer-issue resolve`** must exist in the toolkit
  checkout. A file only on a feature branch is "not found". Use PR/commit URLs
  as `--evidence`.
- **`gh pr merge` with `--auto`** on this repo replies "merge strategy for main
  is set by the merge queue". Plain `gh pr merge --squash` queues it.
- **DeepSeek `final-check` of full `origin/main`** (install target `1460e36b`)
  never finished: engine reaches `step door-call` and stays there. Matching
  open incidents: "DeepSeek native run ends mid-tool with no verdict",
  "hung silent after tool calls". Do not retry as if it were a new bug.
- **`timeout 900` on `ai-review`** killed the waiter but left `opencode.exe`
  orphans. Prefer the door's own `DS_TIMEOUT` (7200s Windows) or kill the
  named PID only.
- **Comparing `jq -r .identity.repository` to `pwd -P` as strings** fails on
  Windows (`C:/...` vs `/c/...`). Use `ai_same_path` (#1835). Fixed in
  `tests/test-glm-governed-source.sh` in #1947.

## 5. Root causes and key findings

1. **StepFun false BLOCKED / extra-decision refusal:** agent profiles taught
   `VERDICT: <word> <sha>` while the door and
   [`bin/ai-review-pool`](https://github.com/popcre/ai-devops/blob/main/bin/ai-review-pool)
   require a literal `## Verdict` heading with a bare word. `extract_report`
   then appended `## Verdict\nBLOCKED` and consumers refused the label line.
   Fix: normalize a terminal `VERDICT:` label into the recorded heading; align
   OpenCode profiles. Files:
   [tools/lib/review-doors/stepfun.sh](https://github.com/popcre/ai-devops/blob/main/tools/lib/review-doors/stepfun.sh),
   `config/opencode-stepfun/agent/stepfun-review*.md`.
2. **GLM "not a repository top level":** `governed_source_root` compared
   `pwd -P` to `git rev-parse --show-toplevel` as raw strings after partial
   `cygpath -u`. MSYS `/c/...` ≠ `C:/...`. Fix: `ai_git_toplevel` /
   `ai_same_path` in
   [tools/lib/path-identity.sh](https://github.com/popcre/ai-devops/blob/main/tools/lib/path-identity.sh).
   File [bin/ai-glm](https://github.com/popcre/ai-devops/blob/main/bin/ai-glm)
   is **reviewer-safety**; that PR needed DeepSeek exact-head APPROVE.
3. **Multi-reviewer "zero recorded"** is partly downstream of (1)+(2): GLM
   APPROVE never became a bindable report. shared-db
   `manage-migration-author-lanes --record` still needs live proof.
4. **Observation week (#1948)** freezes reviewer-repair PRs and installs once
   the window file is live. This session landed two repairs *before* freeze
   declaration (step 6 of that plan still open) then paused.
5. **DeepSeek hang** after a completed bash-tool then `step_start` with no
   further output is a known freeze observation — not repaired this week.

## 6. Exact next steps

1. **Read** [plan_reviewer-observation-week.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-observation-week.md) §11 and check for the per-host window file. If live: no reviewer-repair PRs, no installs; log only.
2. **If freeze is NOT live:** finish #1678 step 7 — code-only install of a merged SHA that includes `44df8b97` and `73508ce2` via the protected Windows route in [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md). You'll know it worked when installed launcher hashes match that SHA and `ai-reviewer-issue list` shows the eight partially-resolved rows can move to resolved after live smoke.
3. **Live smoke (step 6)** once installed: one GLM and one StepFun review that produce a durable `## Verdict` + head SHA. Then `ai-reviewer-issue resolve` the remaining rows with the smoke evidence. Record on [#1678](https://github.com/popcre/ai-devops/issues/1678).
4. **shared-db recording:** reproduce `manage-migration-author-lanes --record` after a real APPROVE; fix only in `popcre/shared-db` with its own PR (load `shared-db-change` first). Start from incident `20261021T164147Z-edge-dev-multi-reviewer-recording-3487006`.
5. **Do not "fix" the DeepSeek hang** during observation week — it is on the freeze's log-only list.

**Verify success:** installed hashes match; live smoke leaves durable reports; incidents resolved with those SHAs; #1678 checklist updated on the same issue.

## 7. Constraints and gotchas in force

- Observation week (#1948) §11: no PRs under `bin/`, `tools/lib/review-*`,
  `config/review*`, `config/task-gates.json`, `install.sh`/`update.sh`; no
  installer runs on review hosts while the window file exists. Allowed: kill/
  restart hung reviewer processes, recharge credit, key rotate via 1Password
  `vibe_coding`, `ai-review-preflight clear`, vendor re-pin to frozen pin.
- #1678 no-review plan: PRs stay `prose`/`code` with no `ai-review` gate unless
  the path is protected `reviewer-safety` (then exact-head independent review).
- Never `git pull` the installed checkout (`C:/repos/ai-devops` is landing-only).
- Worktree-based; stage only owned files.
- Invoke Git Bash as `"C:\Program Files\Git\bin\bash.exe" -lc '...'`.
- Times in EST/EDT when talking to Albert.
- Never compare filesystem paths as raw strings (#1835) — `ai_same_path`.

## 8. Access and environment

- Host: edge-dev (Windows 11, MINGW64). Git + GitHub via `gh` from Git Bash.
- Canonical checkout: landing-only. This session's worktrees (safe to delete
  after this handoff merges): `ai-devops-wt-reviewer-incidents`,
  `ai-devops-wt-glm-path`, `ai-devops-wt-install-cand`, `ai-devops-wt-wrapup-handoff`.
- Local incident store: `bin/ai-reviewer-issue` under the canonical checkout
  (private; never copy raw bodies into the public repo).
- Secrets: 1Password vault `vibe_coding` only. No new secrets this session.

## 9. Open questions and risks

- Observation-week step 6 (freeze declaration / window file) timing vs #1678
  step 7 install — see §0.1.
- DeepSeek hang on large trees may block any future install-target review.
- shared-db `--record` may still drop approves even after the two ai-devops
  fixes; needs a live governed review to prove.
- Canonical checkout still has an **uncommitted** `bin/ai-glm` cygpath patch
  from an earlier session (not this one). The merged fix is `73508ce2`. Do not
  `git checkout --` it blindly if another session still owns it; it is
  obsolete once the checkout fast-forwards.

---

## Self-audit

1. **Cold continue?** Yes — §3 names merged SHAs and PR URLs; §6 is ordered
   with verification gates; §4 lists every dead end (WSL bash, PowerShell
   quoting, stub `$RH`, DeepSeek hang, evidence paths).
2. **As effective as this session?** Yes — §5 records both root causes with
   file URLs; §7 carries freeze and no-review rules; §9 flags the leftover
   uncommitted file.
3. **Every detail?** Yes — goal (§2), failures (§4), root causes (§5), next
   actions (§6), constraints (§7), access (§8), risks (§9).
4. **Section 0 complete?** Yes — one blocking business choice (freeze vs
   install), one recoverable judgement (DeepSeek hang), settled list with
   dates; no technical approvals.
