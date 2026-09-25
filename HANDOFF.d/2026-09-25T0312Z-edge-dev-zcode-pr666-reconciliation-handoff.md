---
issue: 816
status: OPEN
owner: zcode/sess_d22c4c83-beb4-424b-af5c-15331f6c80f1
---

# PR #666 / #702 reconciliation + Qwen reviewer outage — session handoff

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner. The reconciliation design
(#816) is a technical decision the next session makes and defends in review;
the Qwen fingerprint repair is tracked tooling work with no owner ruling
required. Albert has already been handed the successor prompt and does not
need to answer anything for work to proceed.

Already settled — do NOT re-ask:
- 2026-09-24: Albert asked for the PR #666 successor prompt; it exists at
  `prompt_pr666-rule702-reconciliation.md` (landing on main with this file).
- 2026-09-24: Albert asked for the Qwen incident to be logged; recorded as
  `20260925T031049Z-edge-dev-qwen-44255`. No repair was attempted beyond
  `doctor --live` (which passed but did not clear the quarantine).

## 1. What this application is

`popcre/ai-devops` is the internal AI-tooling repository: reviewer wrappers
(`bin/ai-review*`), task gates, CI, and the cross-repo rulebook the other POP
Creations repos consume. Albert Hazan owns the business; AI sessions do all
git mechanics. Nothing here is user-facing software.

## 2. What we set out to do this session, and why

Run ai-devops issue #713: triage six abandoned dirty Codex work folders left
after the 2026-09-23 disk cleanup, ship any unique work, discard the rest with
proof, and report in plain English. Follow-up asks: check whether Qwen was
healthy again, produce a successor prompt for PR #666, log the Qwen defect,
and wrap up.

## 3. Current state — what is true right now

All verified on GitHub at 2026-09-24 ~10:45 PM EST:

- **#713 complete.** Report posted: https://github.com/popcre/ai-devops/issues/713#issuecomment-5821836016
  The issue was NOT closed (rule: only its opener closes it; opener was a
  Claude session). Six folders: renamed-sweep work merged as PR #785 (db6871cf,
  issue #634 closed); catalog-verifier fix merged via shared-db PR #3311
  (6288c639, shared-db #2876 closed, non-orchestrator); PR #666 work preserved
  on its branch (open, see #816); three folders discarded with proof
  (`C:\repos\shared-db\.ai-devops\seven13-removal-proof.txt`).
- **#816 open** — the PR #666 vs #702 reconciliation. Successor brief:
  `prompt_pr666-rule702-reconciliation.md` (this PR). PR #666 branch
  `codex/readonly-private-review-20260920` at 46c86f28, safety hold in force.
- **Qwen reviewer unusable**: `ai-review-preflight status qwen` reports
  `live-qualification-required`; incident `20260925T031049Z-edge-dev-qwen-44255`
  recorded under `C:/repos/ai-devops/.ai/reviewer-issues/`. Grok is healthy.
- Branches/worktrees I created are gone; `codex/pr666-resume` and
  `claude/634-shared-db-rename-sweep` local branches were still present at
  wrap-up (both proven preserved remotely — safe to delete).

## 4. Everything we tried that did NOT work

- **Shipping the PR #666 integration branch directly**: local suites passed
  (lifecycle 66/66, code-only 99/99, sandbox 6/6) but CI failed — the branch
  predates #702; two task-gates checks conflict (details in the #816 body).
  Fixing it means a reviewer-safety policy change, not a merge tonight.
- **Qwen `doctor --live` as the repair**: probe passed, quarantine persisted —
  the qualification record's runtime hash can never match in a different
  session context (see incident for hashes).
- **Rerunning failed CI on PR #785**: GitHub reused the stale merge ref, so a
  main-side fix (#788) wasn't picked up; an empty commit was needed to force a
  fresh merge.
- **Python `read_text` for the rename sweep**: universal-newline translation
  turned a bare CR inside a Windows path into a line break, corrupting two
  completed plan records; caught by the Grok review, fixed by restoring main's
  bytes and switching to raw-byte replacement.
- **`gh run rerun --failed` / log APIs mid-run**: logs 404 until the run
  completes; fetch job logs via the API with `--allow-escape-sequences`.

## 5. Root causes and key findings

- PR #666's sealed-export design and #702's central review ban are two
  sessions' competing decisions on one config line
  (`config/task-gates.json` private-evidence `forbidden_actions`).
- Qwen's runtime fingerprint is a normalized GNU tar over the install
  (`bin/ai-qwen` `qwen_runtime_sha256`, ~line 169); identical installs hash
  differently across session contexts — likely PATH/tar-version drift on
  EDGE-DEV, same family as the Grok pin drift.
- `gh pr merge -d` is refused when a merge queue is enabled; plain
  `--squash` enqueues.
- The ai-task-gates class system protects reviewer-safety; declaring a weaker
  class is refused with the exact files that escalated it.

## 6. Exact next steps

1. Run the successor brief `prompt_pr666-rule702-reconciliation.md` in a fresh
   session (that is the whole of #816). You'll know it worked when PR #666 is
   MERGED (or closed with a documented decision) and both contract checks are
   green on the final head.
2. Separately, repair the Qwen fingerprint instability (incident
   `20260925T031049Z-edge-dev-qwen-44255` names the hashes and the likely
   cause). You'll know it worked when `bin/ai-review-preflight status qwen`
   reports usable:true from a fresh session whose context differs from the
   recorder's.
3. Issue #713 should be closed by its opener (or Albert) now the report is
   posted.

## 7. Constraints and gotchas in force

- Reviewer-safety class for any `bin/`+`config/`+`skills/` change set; fresh
  worktree from `origin/main`; never push to protected main; AI merges via the
  queue; sign every GitHub post with the session id and machine; quote times
  in EST.
- Never hand-edit `qwen-live-qualified.json` to force a match — that
  suppresses the qualification gate rather than repairing it.
- The `Microsoft/` untracked dir in the repo root and
  `HANDOFF.d/2026-09-20T0029Z-*` predate this session — do not touch.
- `C:\repos\shared-db\.ai-devops\$TMP\` was auto-created by the reviewer-issue
  recorder with an unexpanded `$TMP` (small latent bug, not yet reported).

## 8. Access and environment

EDGE-DEV, Git Bash. `gh` authenticated; ai-devops and shared-db checkouts at
`C:\repos\ai-devops`, `C:\repos\shared-db`. Reviewer wrappers runnable from
`bin/`. No credentials appeared this session; secrets sweep clean (nothing to
store in vault `vibe_coding`).

## 9. Open questions and risks

- The reconciliation design choice in #816 is unmade; the candidate in the
  brief is a starting point, not a decision.
- Qwen's cross-context fingerprint mismatch means ANY qualification recorded
  by one session may be rejected by another until the hashing is made
  context-stable — reviews should draw Grok meanwhile.
- Issue #713's "done when" is satisfied by the posted report; only its
  closure remains.
