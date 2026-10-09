# Grok paid-fallback removal — fleet rollout and review-copy collision

Posted by Claude chat 77eed57f-bbc1-4a6f-a856-56d3eeff1b07 on edge-dev3.
Written 2026-10-08 11:32 PM EDT.

## 1. Goal

Albert's request, from his chat: "remove the paid fallback." Grok reviews must
run only on the xAI subscription login and never bill a pay-per-use xAI API key.
He then asked, also from his chat: "sync the other computers too." The goal is
that every fleet machine runs code with no paid-key route.

## 2. Current state (verified 2026-10-08, times EDT)

The code is done. Every paid-key route is closed and merged:

- https://github.com/popcre/ai-devops/pull/1424 — the wrapper no longer forwards
  `XAI_API_KEY`. `store-key` and the key store are removed.
- https://github.com/popcre/ai-devops/pull/1476 — the allocator door strips
  xAI/Grok key variables on review, implement, and permission-resume.
- https://github.com/popcre/ai-devops/pull/1480 — `ai-grok-implement` strips the
  same shared key list on ordinary runs.

Each fleet machine was checked against a merged commit that contains #1480
(4d7fba2f):

| Machine | State | Evidence |
|---|---|---|
| edge-dev3 | done | main checkout fast-forwarded; installed `ai-grok-review` has 0 matches for `store-key\|resolve_xai_api_key` |
| hetz | done (by another session) | `/worksp/ai-devops` at 9b53eb7d, which contains 4d7fba2f; 0 matches |
| al8960ofc (4837) | done (by another session) | checkout at b6adb3cb, which contains 4d7fba2f (checked 11:33 AM EDT) |
| edge-alien | done (by another session) | `C:\repos\ai-devops` at 958c5434, which contains the fixes. Grok was never installed there |
| edge-runn-envy | n/a | ai-devops is not installed |
| edge-dev | not touched | another session's branch was checked out there with an uncommitted handoff edit |
| **916** | **NOT DONE** | still on a8f293a7. Its installed `ai-grok-review` still has the paid-key code (9 matches) |

## 3. What is left

1. **916.** Another session started a dotfiles sync/install on 916 at about
   7:23 PM EDT. It worked from its own copy, `ai-devops-dotfiles-sync-install-20261008`.
   This session stood down so it would not collide with that one. Next step:
   check `git -C C:\repos\ai-devops log -1` on 916, and grep the installed
   `ai-grok-review` for `store-key|resolve_xai_api_key`. If 916 is still on
   a8f293a7 once that session is gone, run the pinned install. Use a fresh task
   gate and a final-check run **on 916 itself**; the gate only accepts approvals
   recorded in the machine's own review history.
2. **Review-copy collision fix — MERGED** in https://github.com/popcre/ai-devops/pull/1537 (2026-10-09 12:37 AM EDT): the start-of-review sweep skips snapshots whose owner run is alive. Remaining gaps: (a) the daily Windows cleanup still deletes any snapshot untouched for 24 h without an owner check; (b) no test yet for the owner record on code-only review snapshots; (c) not yet proven live on 916.
3. **Grok sign-in on al8960ofc and edge-alien.** Grok needs a browser
   `grok login` on both machines, and edge-alien also needs Grok installed.
   That is a platform limit for an AI. Other reviewers cover rotation.

## 4. Fixed along the way (all merged)

- #1475: a mode-less approval can no longer be reused for another mode.
- #1474: the Windows StepFun door now uses the request pacer and 429 retry.
- #1486: a routed Linux CI shard now requires python, ssh-keygen, pwsh, and shellcheck.
- #1487: the Windows DeepSeek credit-hold re-check works, and legacy holds are released.
- #1497: a Kimi worker owns its own temp root, and the sweeper needs a proven-dead owner.
- #1499: a split review patch is never presented as complete.
- #1505: offline test suites clear the inherited `AI_REVIEW_OPERATION` and related variables.
- #1514: the GLM pool test sources the isolation helper.
- #1515: the Windows installer accepts an approved target that is merged behind origin/main.

## 5. Machine-local fix (edge-dev3, not in Git)

The GitHub runner user units on edge-dev3 (`~/.config/systemd/user/actions-runner-*.service`)
used `KillMode=process`. Each restart left an orphaned run-helper and
Runner.Listener behind, and two listeners then claimed the same job. That
failed CI with "Job not found … workflow instance not found". To fix it,
`kill-orphans.conf` drop-ins were added to all 8 units, setting
`KillMode=mixed` and `TimeoutStopSec=30`. The orphans were killed at
12:40 AM EDT on 2026-10-08. Each runner directory now has exactly one listener.

## 6. Tried and failed

- Reviewing the install on one machine and installing on another fails. The gate
  binds the approval to the installing machine's own review-lifecycle records:
  "ai-task-gates: STOP. Review report has no completed, matching lifecycle record."
- On 916 on 2026-10-08, every reviewer failed without a verdict. Grok ended
  BLOCKED because it ran out of turns on slow tests. DeepSeek reported
  "snapshot changed during the review", then exit 124. Codex's runner failed
  before reading MANIFEST.md. Gemini and Qwen failed preflight; Qwen's quota
  resets 2026-11-01. The likely cause is concurrent sessions sharing one
  review-sandbox store on 916.

## 7. Verify done

On 916: `C:\repos\ai-devops` contains commit 4d7fba2f, and the installed
`ai-grok-review` has 0 matches for `store-key|resolve_xai_api_key`.

## 8. Related

The token-usage audit prompt for the other reviewers was handed to Albert in
chat. It is not started as a session.

## 9. Retention

Delete this file once 916 is verified and gaps 2(a)-(c) are closed.
