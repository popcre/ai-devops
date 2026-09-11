---
issue: 337
status: BLOCKED
owner: codex/reviewer-reliability-337
---

# Reviewer reliability: source-base correctness slice

## 0. Decisions only the owner can make

None. Do not weaken the read-only review sandbox, replay a paid review, or bypass independent review to move this slice. Those are settled safety rules, not decisions to re-ask.

## 1. What this application is

`popcre/ai-devops` is the public recovery toolkit that supplies the review wrappers and their evidence controls. Installing its launchers is deployment; this work changes only source in an isolated worktree.

## 2. Session goal and reason

Implement the first proven repair in issue #337: a reviewer must compare a feature branch to the fetched target branch, not an older local `main` branch. A stale local base can show unrelated target-branch files to a reviewer.

## 3. Current state

Worktree: `C:/repos/ai-devops-worktrees/reviewer-reliability-337`, branch `codex/reviewer-reliability-337`, based on `origin/main` `061af0d32cf17e3df2b831a380f58d55785e8927`.

Commit `648f434efb59df5943d5f2a36182f65fd07ea3fa` changes `bin/ai-review-packet` to prefer `origin/main`/`origin/master`, and `bin/ai-review-sandbox` to retain fetched remote-tracking refs separately from local branches. It adds A/B/C stale-local-main coverage to `tests/test-ai-review-packet.sh` and a remote-backed merge-snapshot check to `tests/test-ai-review-sandbox.sh`. The commit is local only: not pushed, reviewed successfully, merged, or installed.

The private maintenance ledger in the original audit worktree reports no active round and zero candidates, despite the plan's historical 198-candidate claim. That is a historical-coverage blocker for #337 closure, not permission to reset or recreate evidence.

## 4. What did not work

`tests/test-ai-review-packet.sh` and the sandbox suite were launched through Git Bash. They passed initial checks but the packet suite stalled in its existing shell harness at a later `ai-review-packet build` call and never returned an exit status. Several duplicate launch attempts were stopped by terminating only this session's exact processes. Do not count the partial output as a test pass.

The required Codex exact-head review ran in a sealed read-only snapshot and returned `BLOCKED`: the Windows Codex sandbox denied even the first read of `MANIFEST.md`. Its report is `.ai/reviews/codex-diff-review-20260908T203830-1023721-22801.md`; do not relax the sandbox to work around it.

## 5. Root causes and findings

At the prior code, `bin/ai-review-packet:resolve_base` checked local `main` before `origin/main`; `bin/ai-review-sandbox:build_snapshot` copied an origin base into a local branch. When local `main=A`, fetched `origin/main=B`, and feature `HEAD=C` descends from B, the packet selected A and included B's unrelated changes. The repair preserves both ref namespaces and selects the fetched ref first; offline local refs remain fallback.

`AI_GLM_CALLER=codex bin/ai-glm new reviewer-reliability-base-648f434e` is an active independent GLM review of exactly commit `648f434e`, with snapshot packet hash `75e8d086dea13629e7754956f6b856be68116ef07912e6ee0207c7268f1ee87e`. Its named session is `reviewer-reliability-base-648f434e`; continue it, do not create a replacement.

## 6. Exact next steps

1. Run `AI_GLM_CALLER=codex bin/ai-glm show reviewer-reliability-base-648f434e` until it reaches a terminal result. Read its report and address any finding; it must give a valid exact-head verdict. Gate: report names `648f434e` and ends in an allowed verdict.
2. Diagnose the focused suite stall without rerunning an unchanged full suite: capture the exact stuck child/command and add a targeted reason before any retry. Gate: each focused suite has a terminal pass/fail result, not partial output.
3. If tests and independent review pass, inspect the exact diff and status, push only `codex/reviewer-reliability-337`, open a PR for this one slice, use bounded CI waiting, merge only after required checks and exact-head review, then verify `origin/main`. Gate: commit is on main and the changed launcher behavior is installed only through the documented serialized deployment procedure.
4. Resume issue #337 Step 1 using the actual original private evidence location, or record the absent historical inventory as a durable blocker. Do not mark the umbrella issue complete from this source-base slice.

## 7. Constraints and gotchas

Keep the canonical checkout landing-only; this worktree is the only write location. #330 Qwen work remains separately owned. Preserve explicit `--base`, root-commit behavior, untracked-file digest checks, and no-network snapshot semantics. Reviewer changes need an independent exact-head verdict. Never run a local full Windows suite while the relevant runner host is busy; use focused offline tests only after diagnosis.

## 8. Access and environment

GitHub CLI and `origin` are available. Git Bash is `C:/Program Files/Git/bin/bash.exe`. GLM is available through `bin/ai-glm` only; its capacity state is currently `unknown` by unsupported-interface, which is not an exhaustion result. No secret was read. The provider session and reports are private ignored artifacts.

## 9. Open questions and risks

The GLM review has not yet reached a terminal verdict. The local packet test stall may be an environmental shell/process issue or an implementation defect; no cause is proven. The first real maintenance round needed by #337 appears unavailable in the audit worktree, so synthetic tests cannot close historical incident coverage.

## Self-audit

This handoff covers the owner-decision sweep (§0), application and scope (§1–2), exact commit/state (§3), failed checks (§4), evidence-backed mechanism and active reviewer identity (§5), gated continuation (§6), safety limits (§7), access/privacy (§8), and unresolved risks (§9). A new session can continue without reconstructing this chat.
