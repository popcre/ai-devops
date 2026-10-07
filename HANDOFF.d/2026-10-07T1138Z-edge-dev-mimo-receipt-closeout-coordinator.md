---
issue: null
status: OPEN
owner: mimo/receipt-closeout-coordinator
---

# HANDOFF — Receipt closed; coordinator for reviewer-issue and orphan-sandbox leftovers

Machine: edge-dev · Agent: mimo · Written: 2026-10-07 7:38 AM EST
GitHub signature: `Posted by MiMo chat ses_ffe5eecd9547fffefMTfHWA6hY on edge-dev`

> `issue: null` — no single GitHub issue owns this leftover set. The two items
> below were named in `HANDOFF.d/2026-10-06T2052Z-edge-dev-mimo-deepseek-tool-loop-budgets.md`
> (now retired; issue #1339 closed) and in
> `HANDOFF.d/2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md`.
> If a coordinator session starts this work, open one parent issue and paste
> this file's §3 and §6 into it.

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.** Both leftovers are
technical evidence/reconcile work. They fail closed to an engineer or an
assigned AI reviewer; never to Albert.

**Already settled — do NOT re-ask:**

- DeepSeek token-volume cut is live on edge-dev, edge-dev3, and hetz, and the
  formal authorize-install receipt is complete (issue #1339 closed 2026-10-07).
  Owner: "don't stop working until this is 100% fixed and live everywhere"
  (2026-10-06) — that is done.
- Exact-head independent review is mandatory for reviewer-safety changes. Do
  not relax it (owner standing rule; reinforced through #1339).
- No human technical approval. Wipe/security/qualification exceptions are
  AI-reviewer or security-gate decisions (handoff-standard; Codex finding on
  stepfun plan 2026-10-06).

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public AI workflow recovery toolkit (not
an app/service). It hosts reviewer wrappers (`bin/ai-*`), task gates, installers,
and docs. GitHub: `https://github.com/popcre/ai-devops`. Local primary checkout:
`C:/repos/ai-devops` (landing-only). This handoff covers two leftovers from the
DeepSeek receipt workstream and the reviewer-issues incident class.

## 2. What we set out to do this session, and why

Goal: finish the formal authorize-install receipt for the DeepSeek tool-loop
budget cut (issue #1339). That is **done and closed**. While closing, two
pre-existing leftovers were re-confirmed open and deferred (scope freeze at
wrap-up). This file is the coordinator brief for those leftovers.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| DeepSeek token cut live | **Done** (prior session) | edge-dev / edge-dev3 / hetz at budgets `MAX_ROUNDS=8`, `MAX_TOOL_CALLS=16`, `MAX_OUTPUT_CHARS=8000`, `COMPACT_BUDGET_CHARS=24000` |
| Formal authorize-install receipt | **Done this session** | issue #1339 closed; launcher `source-sha=6e7bda7c07285d51cb6d3492015dab550af1626d` |
| Codex exact-head APPROVE | **Done** | `C:/repos/ai-devops-receipt-rev/.ai/reviews/codex-final-check-20261007T060413-2346078-18805.md` (181 tests, no High/Medium) |
| Reviewer issue (Codex sandbox evidence) | **OPEN — deferred** | `20261006T123753Z-edge-dev-codex-950377` under `.ai/reviewer-issues/` |
| Orphan review sandboxes (~300 on edge-dev) | **OPEN — deferred** | evidence-reconcile failures; slow every `ai-review` front-door sweep |

What the receipt delivered (landed, all merged to `origin/main`):

- PR #1361 — StepFun plan/handoff policy (exact-head class; no owner wipe exception)
- PR #1362 — gemini versioned qualification store; request pre-check
- PR #1369 — pytest-safe `tests/test_deepseek_repo_tools.py`; gemini pre-requalify shape
- PR #1377 — gemini governed SHA / base-ref / reusable-session pre-check
- PR #1378 — windows-runner-qualification name bind; `stepfun.sh` `@file` prompt

Receipt proof is in the closing comment on
https://github.com/popcre/ai-devops/issues/1339

## 4. Everything we tried that did NOT work

1. **authorize-install with a Windows path or without `PROGRAMFILES`.**
   Gate said `Launcher is not canonical managed path` (bash compares against
   `$HOME/.local/bin/ai-task-gates`), then `Installed Windows launcher routing
   differs` because `windows_launcher_route` does `Join-Path $env:ProgramFiles`
   and Git Bash / this pwsh host had `PROGRAMFILES` empty. Fix: export
   `PROGRAMFILES="C:\Program Files"` (and `ProgramFiles`) in the environment
   before `authorize-install` and `install-ai-devops-windows.ps1`.
2. **Install candidate already at target when `start --class installation`
   ran** → empty release. Declare at the old installed HEAD (launcher
   `source-sha=6bb1846d…`), then advance only that candidate to the tip.
3. **Primary checkout not on branch `main`** → installer `branch --show-current`
   is not `main` and dies (or null `Path` when env is wrong). Put the primary
   on `main` before the installer; the installer fast-forwards it.
4. **Codex exact-head REJECTs on intermediate tips** (five rounds). Each REJECT
   named real High/Medium findings in *other* commits on main (gemini store,
   pytest `sys.exit`, pre-requalify order, runner-qual label, stepfun argv).
   Fixed forward; never relaxed the exact-head gate. Do not try to "approve
   around" a REJECT.
5. **Pre-check that moved `ask_existing` recovery semantics** broke tests
   (`stale-head refusal becomes recovery-required` needs `begin()` so `on_exit`
   can mark `RECOVERY_REQUIRED`). Solution: `SKIP_AUTO_REQUALIFY=1` for paths
   that must keep their original error contract (changed-head, unresolvable
   assert-head) instead of dying early.

## 5. Root causes and key findings

1. **Token burn was multi-round amplification**, not a bad model pin. The cut
   (PR #1317, merge `5149ba76`) is live; this session only finished the receipt.
2. **`ai-task-gates authorize-install`** binds an APPROVE to the exact fetched
   `origin/main` at authorize time. `start_head` must be the launcher receipt
   (`source-sha=` in `~/.local/bin/ai-task-gates`), and the primary checkout
   must still be at that head when authorize runs (or the installer uses the
   launcher receipt as `installedBaseline` — see `install-ai-devops-windows.ps1`
   `Get-InstalledSourceReceipt`).
3. **Windows launcher route check** needs `PROGRAMFILES` set in the invoking
   environment. Git Bash and some pwsh hosts omit it.
4. **Codex final-check is a full-tree exact-head review** of the tip, not a
   narrow PR diff. Unrelated commits on main can REJECT an unrelated receipt.
   That is why the receipt waited on five fix PRs.
5. **`validate_request_source` vs `auto_requalify`**: paid requalification must
   not run before request-shape and reusable-session checks. Paths that must
   preserve `RECOVERY_REQUIRED` (via `on_exit` after `begin()`) use
   `SKIP_AUTO_REQUALIFY=1` rather than dying in the pre-check.

## 6. Exact next steps (coordinator)

Act as coordinator. For each item, dispatch a sub-agent; keep the decision with
you (verdict + verbatim evidence line). One parent issue if you start either.

### A. Reviewer issue `20261006T123753Z-edge-dev-codex-950377`

1. Read `.ai/reviewer-issues/20261006T123753Z-edge-dev-codex-950377/` and
   `HANDOFF.d/2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md`.
2. Determine whether durable-publish / orphan-evidence reconcile is repaired
   (that handoff owns the incident class). If not repaired, do not fake a
   resolved status — record `partially resolved` only with exact evidence.
3. You'll know it worked when: the reviewer-issue record is `resolved` or
   `partially resolved` with a verbatim evidence line, or it is explicitly
   left OPEN with the blocker named.

### B. Orphan review sandboxes (~300 on edge-dev)

1. Inventory under the review-lifecycle / sandbox state dirs (see that
   handoff's §8). These fail evidence reconcile and slow `ai-review` sweeps.
2. Do not delete unreviewed work. Follow `cleanup-worktree` / orphan-sweep age
   rules; recover unique evidence first.
3. You'll know it worked when: sweep no longer reports the known
   `sandbox evidence requirement is missing` / `required report is not durably
   published` class for the retired set, or each remaining failure is named
   with an owner.

**Do not** reopen #1339. **Do not** relax the exact-head gate.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push protected `main`. `git var
  GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- Canonical checkout is landing-only; write-capable work uses its own worktree.
- Never edit another session's `HANDOFF.d/` file. Root `HANDOFF.md` is a static
  pointer (`handoff-pointer: v1`).
- Independent exact-head review for reviewer-wrapper / evidence-tool changes.
- Times in human output: EST. Sign GitHub posts
  `Posted by MiMo chat <id> on edge-dev`.
- Windows host: PowerShell mangles `bash -lc` quoting — use a `.sh` script and
  a `.cmd` wrapper calling `"C:\Program Files\Git\bin\bash.exe" script.sh`.
- `PROGRAMFILES` must be exported for launcher-route checks and the installer.

## 8. Access and environment

- Hosts: edge-dev (Windows, this machine), edge-dev3
  (`ssh -i ~/.ssh/916-alien ahazan@edge-dev3`, repo `/home/ahazan/repos/ai-devops`),
  hetz (`ssh vps2-direct`, user `ai`, repo `/worksp/ai-devops`).
- `gh` as `u2giants` via `bin/ai-gh` (never raw `gh` for waits).
- DeepSeek key: 1Password vault `vibe_coding` (never paste values).
- Launcher: `C:/Users/ahazan/.local/bin/ai-task-gates` with
  `source-sha=6e7bda7c07285d51cb6d3492015dab550af1626d`.
- Session tools: Git Bash at `C:\Program Files\Git\bin\bash.exe`.

## 9. Open questions and risks

- **2026-10-07:** Reviewer-issue and orphan-sandbox leftovers have no single
  GitHub issue. Open one parent before starting if you want a close-out card.
- Orphan sweep is a known class; a partial sweep is not completion. Name every
  failure left behind.
- DeepSeek account previously hit "Insufficient Balance" (2026-10-04). Live
  budgets reduce burn but do not top up credit.

---

### Self-audit (handoff-writer Mode A)

1. **Comprehensive for a brand-new developer?** Yes — §1–2 define the app and
   goal; §3 has SHAs, hosts, and launcher receipt; §6 is executable without chat.
2. **As effective as this session?** Yes — §4 lists every dead end (path/
   PROGRAMFILES, empty release, branch `main`, Codex REJECTs, recovery
   semantics); §5 captures authorize-install and exact-head findings.
3. **Every relevant detail?** Yes — background, goal, state, failures,
   constraints, risks, next actions, verification gates, secrets by location.
4. **Section 0 shows every owner decision and no technical approvals?** Yes —
   sweep found no business decisions; leftovers are technical and stay in §6.
