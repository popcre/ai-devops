---
issue: 1405
status: OPEN
owner: mimo/evidence-lost-pr-1410
---

# HANDOFF — PR #1410 evidence-lost: last reject is report-search completeness

Machine: edge-dev · Agent: mimo · Written: 2026-10-07 7:24 PM EDT (America/New_York)
GitHub signature: `Posted by MiMo chat unknown on edge-dev`

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.** The remaining work is a
technical design choice behind a fail-closed evidence gate. It fails closed to
an engineer or an assigned AI reviewer, never to Albert.

**Already settled — do NOT re-ask:**

- Exact-head independent review is mandatory for reviewer-safety changes
  (owner standing rule; reinforced through #1339). Never relax it.
- Issue #1339 (DeepSeek receipt) is closed. Do not reopen.
- No human technical approval. Wipe/security/qualification exceptions are
  AI-reviewer decisions.
- Owner feedback 2026-10-07 (verbatim spirit): if reviewers keep rejecting the
  work, the process is wrong — verify design before shipping to review. Do not
  start another blind fix-forward loop.

**Next session instruction:** put any owner questions in ONE message before
starting. There should be none for this file.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public AI workflow recovery toolkit (not
an app/service). It hosts reviewer wrappers (`bin/ai-*`), task gates, evidence
accounting (`tools/reviewer_events.py`, `tools/reviewer_event_guard.sh`), and
docs. GitHub: `https://github.com/popcre/ai-devops`. Local primary checkout:
`C:/repos/ai-devops` (landing-only). This handoff covers unmerged work on
pull request **#1410** only.

## 2. What we set out to do this session, and why

Goal (user request): finish two deferred leftovers from the DeepSeek receipt
workstream (reviewer issue `20261006T123753Z-edge-dev-codex-950377` and orphan
review sandboxes), then complete two named follow-ups (evidence-tool loss
records for non-GLM / dead owners; seal six unsealed packets).

Those leftovers are **done** (posted on parent issue
https://github.com/popcre/ai-devops/issues/1405). The evidence-tool follow-up
became PR #1410 and is **not mergeable**: repeated exact-head Codex final-check
reviews kept finding real fail-open races. This file carries that PR to the
next session.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Reviewer issue 950377 | **resolved (kept)** | `.ai/reviewer-issues/20261006T123753Z-edge-dev-codex-950377/` + evidence store run `83741ca0e6b8403caeab08853e7a9abb` |
| Orphan sandboxes (deferred ~300 class) | **partial, named residuals** | quarantine `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/` + comments on #1405 |
| Six unsealed packets | **partial (2/6 sealed+retained)** | `POSTHOC-SEALS-20261007.txt`; 4 unsealed with missing identity/contents |
| PR #1410 evidence-lost tooling | **OPEN, unmerged** | branch `mimo/evidence-lost-non-glm-dead-owner`, tip `44a0ef19c18af3775ff7fc0862e36df6978d548a` |
| Last independent review | **REJECT** | `.ai/reviews/codex-final-check-20261007T201951-53280-8058.md` on `44a0ef19` |

PR #1410: https://github.com/popcre/ai-devops/pull/1410  
Worktree: `C:/repos/ai-devops-wt-evidence-lost` (clean, pushed, **keep — unmerged**).

Last verdict (verbatim High):

- `tools/reviewer_events.py:1062-1064` searches only non-hidden `.md` reports.
  It can falsely record evidence as lost after a hard kill while recoverable
  files remain. Siblings confirmed: Codex retains `.log` and hidden staging
  files (`bin/ai-codex-review:155,158,308`); equivalent staging exists for
  Gemini (`:585`), GLM (`:1373`), Grok (`:1688`), Kimi (`:1801`), Muse
  (`:623`), and Qwen (`:1403`). Tests cover only final `.md` names
  (`tests/reviewer_maintenance_cases.py:1740-1744`).

Tests at tip: `tests/reviewer_maintenance_cases.py` 124 passed / 4 skipped;
`tests/test-ai-reviewer-issue.sh` was green in earlier rounds (re-run before
any merge).

## 4. Everything we tried that did NOT work

1. **Shipped loss-record widening (non-GLM + age-based death) to review too
   early.** Codex REJECT `644622bb`: age marked owners dead while alive; child
   could publish after loss. Owner feedback: stop sending unreviewed designs.
2. **MSYS vs Win32 PIDs.** Git Bash `$$` is an MSYS pid; `OpenProcess` cannot
   see it, so a live owner read as dead (`process_alive` False for MSYS
   291182 while the shell was live). Fixed by recording `/proc/<pid>/winpid`.
3. **Kimi async finish-on-launcher-exit.** Guard recorded `finished` when the
   launcher exited while the detached worker still owed a report. Fixed:
   `async-submission` loss needs finished **and** `_detached_worker_gone`.
4. **Kimi startup ack before evidence reservation.** Launcher treated
   `phase=starting` as success; worker then failed `require-report`. Fixed:
   reserve `note-worker`/`require-report`/`bind-sandbox` first; launcher waits
   for `phase=running` only.
5. **Historical fixture path too broad.** `verify_reports` accepted
   `evidence-lost.json` on any `Blocked` from `invocation()`, including corrupt
   ledger rows. Fixed: only when **no** ledger row exists, and only for
   `caller=local-recovery` + empty/zero head.
6. **Inherited owner PID on fresh invocations.** A new run could record a stale
   parent PID and look proven-dead. Fixed: `unset AI_REVIEW_EVENT_OWNER_PID`
   on the non-inherit path.
7. **Qwen 24-char report keys.** Search missed recoverable reports. Fixed in
   `lost_report_candidates` key regex.
8. **PR briefly sat in the merge queue** with a REJECT tip. Dequeued via
   GraphQL `dequeuePullRequest` (node id `PR_kwDOTN5iT88AAAABHJkxtw`) before
   pushing fixes. Queue + protected branch rejects pushes (`GH006`).
9. **Review packets without `--tests`.** Codex treated "no tests ran" as High
   for safety-critical changes. Always pass `--tests` on final-check for this
   PR.

Do **not** repeat 1–9. Do not "approve around" a REJECT.

## 5. Root causes and key findings

1. **Proving a report is gone is a discovery problem, not a flag.** Every
   provider names reports differently and stages hidden/partial files. Any
   allowlist of filename shapes will miss another shape and open a false-loss
   window. That is the remaining High.
2. **Fail-closed accounting has many publisher edges** (async workers, PID
   namespaces, fork gaps, inherit env). Each review found a real edge; they
   were not reviewer noise.
3. **Age is never proof of death.** `_proven_dead` requires every recorded
   OS/Win32 PID dead; no PID fails closed.
4. **One run per head.** `ai-review` refuses `source-head-mismatch` after the
   tip moves; re-issue at the new tip, never chase.
5. **Merge queue blocks branch pushes** while queued. Dequeue before pushing.

## 6. Exact next steps

1. **Design report-existence proof that does not enumerate names.**
   Direction that closes the last High without weakening the gate:
   - Prefer positive evidence of publication (evidence-store
     `*.report.json`, `publish-report` ledger references) over negative
     search of `.ai/reviews`.
   - If a filesystem search remains, search **all** files under the review
     and job trees (including hidden and non-`.md`), not a suffix list.
   - Refuse loss when the search is incomplete or the tree is unreadable.
   You'll know it worked when Codex final-check on the new tip returns
   `## Verdict` / `APPROVE` with the full head SHA and tests in the packet.
2. **Implement on the same branch** `mimo/evidence-lost-non-glm-dead-owner`
   in `C:/repos/ai-devops-wt-evidence-lost`. Keep fail-closed. Add tests for:
   hidden staging file refuses loss; `.log` report refuses loss; unreadable
   review dir refuses loss.
3. **Run tests** with `AI_REVIEWER_BASH` set to Git Bash `bash.exe`:
   `python -m pytest tests/reviewer_maintenance_cases.py` and
   `bash tests/test-ai-reviewer-issue.sh`. All must pass.
4. **Independent exact-head final-check** (reviewer-safety class):
   `bin/ai-task-gates check --before review` from the worktree (not the
   primary checkout), then
   `bin/ai-review codex final-check --implementer mimo --assert-head <tip> --tests "<pytest + shell tests>"`.
   Use Git Bash. Export `PROGRAMFILES=C:\Program Files` if needed.
5. **Only on APPROVE:** push, let the merge queue land it, confirm the commit
   on `origin/main`. On REJECT: fix forward or leave OPEN with the finding
   named — never merge a REJECT.

You'll know the whole workstream is done when PR #1410 is `MERGED` (or
explicitly closed with the residual named on #1405) and
`gh pr view 1410 --json state,mergedAt` shows the landing.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push protected `main`. `git var
  GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- Canonical checkout `C:/repos/ai-devops` is landing-only. Edit only in
  `C:/repos/ai-devops-wt-evidence-lost`.
- Independent exact-head review required (reviewer-safety). Never relax it.
- Do not reopen #1339. Do not edit other sessions' `HANDOFF.d/` files.
- Windows: use `"C:\Program Files\Git\bin\bash.exe" -lc '...'`; bare `bash`
  may hit WSL. Set `AI_REVIEWER_BASH` for tests. PowerShell mangles heredocs.
- `bin/ai-gh` for GitHub; never raw `gh` for waits. At most one GitHub call
  per 5 minutes per waiter.
- Times in human output: EST/EDT (America/New_York). Sign GitHub posts
  `Posted by MiMo chat <id> on edge-dev` (`unknown` when env empty).

## 8. Access and environment

- Host: edge-dev (Windows). Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- Launcher: `C:/Users/ahazan/.local/bin/ai-task-gates` (`source-sha=6e7bda7c…`).
- Reviewer registry: `config/reviewer-registry.json` — Codex is the
  approval-gate wrapper for final-check; MiMo is implementer only (`--implementer mimo`).
- Evidence store: `~/.local/state/ai-devops/reviewer-events/` (ledger
  `events.jsonl`, per-run `evidence/<run_id>/`).
- Quarantine backup: `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/`.
- Secrets: 1Password vault `vibe_coding` only (none used this session for
  this PR).

## 9. Open questions and risks

- **2026-10-07:** Whether report-absence can ever be proven by directory
  search. Recommendation: switch to positive publication evidence and treat
  incomplete search as "not proven lost".
- **2026-10-07:** `tests/test-ai-review-sandbox.sh` has ~17 stable Windows
  path-length failures (pre-existing). Do not treat as regressions.
- Primary checkout `C:/repos/ai-devops` has untracked `tmp/3947-live-proof-queries.sql`
  (shared-db live-proof scratch, **not owned by this session**). Left in
  place; do not delete without its owner.
- PR #1410 was briefly in the merge queue with a REJECT tip; it was dequeued.
  Do not re-queue until APPROVE.

---

### Part (b) — sub-agents dispatched this session (ai-devops, not shared-db)

| Agent | Asked | Did | Residual |
|---|---|---|---|
| general-1 | Verify issue 950377 | Keep `resolved`; evidence store report.json has Verdict/APPROVE | Deleted worktree report path cited in resolution; substitute is evidence store |
| general-2 | Orphan sandbox inventory | 2 GLM losses reconciled; cap class absent; named residuals | 2 marked + 10 unmarked dirs + tooling gaps (owners on #1405) |
| general-3 | Evidence-tool PR #1410 | Multi-round fixes; tests | Several REJECT fix-forwards; see §4 |
| general-4 | Seal 6 packets | 2 sealed+retained | 4 unsealed (missing identity / empty identity) |
| general-5/6/7 | Independent reviews | REJECT reports with real Highs | — |
| general-8 | Three false-loss edges | Fixed async/Qwen-24/Kimi path; push blocked by queue | Queue later dequeued by coordinator |

No shared-db claims held. No Supabase writes.

---

### Self-audit (handoff-writer Mode A)

1. **Brand-new developer?** Yes — §1–2 define repo and goal; §3 has tip SHA,
   PR URL, worktree; §6 is executable without chat.
2. **As effective as this session?** Yes — §4 lists every failed review cycle
   and root cause; §5 captures the "don't enumerate names" finding.
3. **Every relevant detail?** Yes — background, goal, state, failures,
   constraints, risks, next actions, verification, secrets by location.
4. **Section 0 complete?** Yes — sweep found no business decisions; settled
   rules listed; technical residual stays in §3/§6/§9.
