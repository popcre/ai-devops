---
issue: none
status: OPEN
owner: mimo/1876-pub-followups
---
# Deferred follow-ups after Muse recovery + draft publication

## 0. Business decisions only the owner can make

None. Both items are tooling follow-ups. Albert can dispatch them whenever.

## 1. Application

Public `popcre/ai-devops` toolkit (and one note about `popcre/shared-db` tooling).
Not DesignFlow, not an app deploy.

## 2. Goal and trigger

`/wrap-up` after issue ai-devops#1876 (Muse pre-provider recovery) and
publication of the shared release holds design revision
(popcre/shared-db#3779 / PR #4521). Scope freeze: findings recorded, not fixed.

## 3. Current state

- **Done and verified:** PR
  [#1879](https://github.com/popcre/ai-devops/pull/1879) merged `b100981f`.
  `validate_archived_prior` accepts a historical Muse `runtime_version`.
  Hetz session `shared-release-holds-plan-critique` recovered and a same-session
  Muse turn completed on the broader draft.
- **Done and verified:** shared-db
  [PR #4521](https://github.com/popcre/shared-db/pull/4521) merged to main as
  `d1867d072955ec488547e641632a35d1301d0f8b` (2026-10-20, 11:49 AM EST) after
  Muse native exact-head APPROVE at `16544307c`.
- **Not started (deferred):** the two items in section 5.

## 4. Rejected paths and corrected investigation

- Do not treat `ai-shared-db-closeout-check` failure as "zero claims" when it
  errors on session identity. It failed closed (`session identity must be an
  exact UUID`); claims were verified separately by GitHub search (this session
  posted only comments, never a `db-author-lease`).
- Do not extend #1879's pin-drift fix into `failed_turn_source_check` without
  its own change and tests; that path is a different command
  (`finalize-failed-turn`) with its own fences.

## 5. Root cause and findings

### 5a. Failed-turn receipts still pin the current Muse/OpenCode runtime

`failed_turn_source_check` in
[`bin/ai-muse`](https://github.com/popcre/ai-devops/blob/main/bin/ai-muse)
still requires `.retained_turn.runtime_version == $VERSION`. After a pin bump,
an `opencode` `provider_outcome_uncertain` session hits the same class of
failure #1876 fixed for pre-provider recovery: valid historical evidence is
refused with "keep it fenced." `cmd_finalize_failed_turn` and
`verify_failed_turn_receipt` both call it.

**Exact next step:** apply the same treatment as #1879 — require a recorded
runtime_version string and keep every identity/hash/packet check — then add a
pin-drift fixture in `tests/test-ai-muse.sh`. Note
`tests/test-ai-muse.sh` currently asserts the old exact-pin behavior for the
failed-turn path; update that assertion with the fix.

**Evidence of the gap:** DeepSeek review of `4782f4d7` (Medium/Low) and of
`16544307c` (Low) both named it as pre-existing and out of scope.

### 5b. `ai-shared-db-closeout-check` cannot bind a MiMo session

[`ai-shared-db-closeout-check`](https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check)
accepts only Codex/Claude session UUIDs (`CODEX_THREAD_ID` /
`CLAUDE_CODE_SESSION_ID`). MiMo Desktop sessions use `ses_<id>` identifiers and
export neither variable. The check returns
`{"ok":false,"error":"session identity must be an exact UUID"}`.

**Exact next step:** extend `resolve_session` (and the owner-label patterns if
needed) to accept `MIMO_SESSION_ID` / `ses_…` identifiers, or document the
supported identity forms in the tool's usage line. Until then, MiMo shared-db
closeouts must record the identity-format refusal and verify zero claims by
GitHub search.

## 6. Exact next steps

1. For 5a: branch from current `origin/main`, patch `failed_turn_source_check`
   + tests, run `AI_MUSE_PREPROVIDER_TESTS_ONLY=1` and the failed-turn suite on
   Linux, then the normal reviewer-safety PR path.
2. For 5b: patch `resolve_session` for MiMo identities (or document the gap in
   `docs/` and the tool usage).
3. Neither item blocks #1876 or the shared-db draft publication. Both can be
   independent.

## 7. Constraints and collisions

- Canonical `C:\repos\ai-devops` is landing-only; use a fresh worktree.
- Never `git pull` the installed checkout. Never install the toolkit on
  `edge-alien` / `916-alien`.
- Do not edit other sessions' `HANDOFF.d/` files.
- shared-db plan implementation (ten STATUS rows on
  [#3779](https://github.com/popcre/shared-db/issues/3779)) is intentionally
  open and is NOT this handoff's work.

## 8. Access and environment

Host edge-dev (Windows). `gh` works. Hetz reachable as `ssh hetzner` (root) then
`su - ai`. Reviewer-door / long `ai-task-gates` / `ai-doc-safety` calls can stall
on this host; run those on hetz or under `timeout`. DeepSeek reviews for this
workstream ran on hetz worktrees.

## 9. Open questions and risks

None. Both findings are small, well-bounded, and already evidence-backed.

Posted by MiMo chat ses_ffe5ea6d797e3ffeQD5vdooveb on edge-dev
