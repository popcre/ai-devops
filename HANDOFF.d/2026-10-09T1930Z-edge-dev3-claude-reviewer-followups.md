---
issue: 1544
status: BLOCKED
owner: claude chat eac6b686-2bdd-4fce-91fe-47ae8516cb81 (closed); next owner = whoever picks up popcre/ai-devops#1544
---

# Reviewer follow-ups after #952 (StepFun rotation) — three open items

Written 2026-10-09 3:30 PM EDT on edge-dev3 by the Claude desktop Code-tab chat
"broken reviewers Issue #952 child tasks", which is closing.

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None. Every remaining item is technical and gated by AI reviewers. Albert's
sudo password is needed only for an edge-dev3 install (item C), and only when
an install is happening anyway.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert's machine
toolkit: installers, AI reviewer wrappers (Muse, Gemini, Qwen, GLM, DeepSeek,
StepFun, Grok), task gates, and global AI instructions installed on Linux
(edge-dev3) and Windows (edge-dev) machines. The shared-db allocator decides
reviewer rotation membership.

## 2. What we set out to do, and why

Parent [#952](https://github.com/popcre/ai-devops/issues/952): add StepFun to
reviewer rotation, make Grok the last-choice reviewer, and finish reviewer
safety repairs on Linux and Windows. **#952 is closed with live proof
(2026-10-06). Do not redo it.** Fixes landed along the way, all merged and
live-proven on edge-dev3 unless noted:

- [#1338](https://github.com/popcre/ai-devops/pull/1338): a provider-capacity
  failure during installer "Reviewer requalification" defers (warns) instead
  of failing the install.
- [#1403](https://github.com/popcre/ai-devops/pull/1403): Gemini
  requalification names its caller, so it works outside an AI session.
- [#1385](https://github.com/popcre/ai-devops/pull/1385): the
  desktop-exit waiter no longer holds the install lock (proof ticked
  2026-10-07).
- [#1376](https://github.com/popcre/ai-devops/pull/1376): GLM wrapper fails
  fast on allowance refusal (full GLM VERDICT proven 2026-10-09 8:47 AM EDT).
- [#1334](https://github.com/popcre/ai-devops/pull/1334): Grok formal route
  uses the pinned model.
- [#1365](https://github.com/popcre/ai-devops/pull/1365): flaky memory-sync
  test fixed.
- [#1341](https://github.com/popcre/ai-devops/pull/1341) and
  [#1366](https://github.com/popcre/ai-devops/pull/1366): the membership drift
  check reads the roster from shared-db's split lanes module.
- [#1399](https://github.com/popcre/ai-devops/pull/1399): protected update
  installs an approved SHA even if origin/main moved after authorization.
  **Merged 2026-10-07 2:14 PM EDT; not yet live-proven (item C).**
- shared-db: #3528, #3657 (StepFun), #3593 (Grok last), #3722 (collision
  rule queues instead of deadlocking), #3727 (lane-manager file split), all
  merged. None changed database structure.

## 3. Current state — what is true right now

- edge-dev3 is installed at `50665df5`. Doctor reports installed source matches
  and StepFun is usable. Membership drift is OK:
  `deepseek, gemini, glm, grok, muse, qwen, stepfun`.
- Qwen is quarantined. Its provider allowance has been exhausted since the
  week of 2026-10-06. Verbatim:
  `allowance-exhaustion (provider quota exhausted; resets at 11-01 16:00:00 UTC)`.
- DeepSeek (cleared 2026-10-06) and GLM (cleared 2026-10-09) are usable.

## 4. Everything we tried that did NOT work

- The scheduled GLM proof (cron, 2026-10-09 4:50 AM EDT) returned exit 3
  because GLM's out-of-credit quarantine was still set after credit returned.
  It succeeded once someone ran `ai-review-preflight clear glm`. This is the
  evidence for item B.
- Protected installs failed three times on 2026-10-06/07 with
  `candidate checkout is not the exact fetched target`, because main moved
  between authorization and Albert typing his password. #1399 fixes this; the
  fix is unproven live.

## 5. Root causes and key findings

- Out-of-credit quarantines have no automatic exit. A successful live probe
  after a reset never clears them. Every provider (DeepSeek, GLM, and Qwen in
  November) needs a manual clear.
- Install gotchas are recorded in
  [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md)
  under "Field notes from the 2026-10-06 edge-dev3 recovery".

## 6. Exact next steps

**A. Qwen live requalification (blocked until Qwen's allowance returns, about Nov 1).**
Tracked on [#1544](https://github.com/popcre/ai-devops/issues/1544), a child of
[#1540](https://github.com/popcre/ai-devops/issues/1540). Do its unchecked
items on edge-dev3 and edge-dev, one attempt each, never looping. Done when
`ai-review-preflight check qwen <repo> --live` prints PASS on both machines and
a real Qwen review returns a VERDICT on each.

**B. Auto-clear out-of-credit quarantine (not Qwen-dependent; unowned; can start now).**
Listed on #1544 under "Offline follow-up". In `bin/ai-review-preflight`, make
a successful live probe for a provider quarantined for `out-of-credit` (and
capacity) clear that quarantine. Never loop provider calls to do it. Add tests,
open a PR, get a reviewer whose engine differs from yours, run CI, merge, and
install. Done when, after a provider's credit returns, the first successful
live check clears the quarantine with no manual `clear`. Prove it live with the
next provider that recovers.

**C. Live proof of #1399 (blocked until edge-dev3's next real install).**
There is an unchecked box in the
[#1399 comment](https://github.com/popcre/ai-devops/pull/1399#issuecomment-6083220908).
At the next protected update, after authorizing, if origin/main has moved, the
update must still install the approved SHA instead of failing. Tick the box with
evidence. Never run an install only to prove this.

## 7. Constraints and gotchas in force

- Never ask Albert to approve. Reviewers other than the author's engine gate
  technical changes. Sign GitHub posts with `Posted by Claude chat <id> on <machine>`.
- Never loop quota-only calls (#1540 rule).
- Run protected Linux installs from a candidate worktree, using the candidate's
  `bin/ai-task-gates` for `authorize-install`. Pass the review report at its
  original path.

## 8. Access and environment

The edge-dev3 Linux user `ahazan`, with gh authenticated. Sudo is Albert's
password, needed only for installs. Windows edge-dev is reached as described
in the machine atlas.

## 9. Open questions and risks

- Should B also clear `capacity` quarantines, or only `out-of-credit`? Decide
  from the code. Default to clearing both only on a successful live probe.

## Self-audit

1. Could a new developer continue? Yes. Sections 2–3 give the state and links,
   and section 6 gives each item with an owner condition and a done check.
2. As well as me? Yes. Sections 4–5 hold the failed attempts and root causes,
   and the deployment.md field notes hold the install gotchas.
3. Every detail? Yes. Every item has its blocker, its tracking location and its
   proof. No secrets are included.
