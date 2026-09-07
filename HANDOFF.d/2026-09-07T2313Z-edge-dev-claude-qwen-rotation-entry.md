---
issue: 2558
status: BLOCKED
owner: u2giants/shared-db branch claude/qwen-rotation (PR #2555)
---

# Qwen re-entry into the reviewer rotation — blocked on a cross-PR collision

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking now**

1. **`u2giants/shared-db` PR #2551 ("Fix reviewer replacement request-budget
   deadlock", branch `codex/issue-2550-review-budget`) has been sitting open,
   conflicted with `main`, and untouched since 22:29 UTC on 2026-09-07.** It edits
   the same coordination file as our PR #2555, so the repository's "Cross-PR object
   collision" guard refuses ours until #2551 is merged or closed. Ours cannot land
   while it sits there. **Recommendation: tell the next session whether it may close
   #2551 (its work is a separate fix and can be re-opened cleanly from `main`), or
   whether its Codex session is still live and should be left to finish.** One word
   either way unblocks this.

**A wrong guess is recoverable**

2. Nothing else. The rotation content itself is settled by the live qualification.

**Not part of this work and nobody is on it**

3. None found this session.

**Already settled — do NOT re-ask**

- 2026-09-07: Qwen's quarantine is lifted by owner instruction, on the strength of a
  live qualification that actually passed. Do not re-litigate whether Qwen belongs
  in the rotation.
- 2026-09-07: the Alibaba **Coding Plan** subscription key is dead (401). Qwen runs
  on the **Model Studio pay-per-token** lane. Do not try to revive the Coding Plan
  item.

## 1. What this application is

`popcre/ai-devops` holds the wrapper scripts that let several AI models (Grok, GLM,
Kimi, Muse, Gemini, Qwen, DeepSeek) act as automated code reviewers for Albert
Hazan's repositories. `u2giants/shared-db` holds the coordination logic that decides
**which** reviewer gets each piece of work — the rotation — in
`scripts/manage-migration-author-lanes.mjs`. Everything runs from GitHub; nothing is
edited live on a server.

## 2. What we set out to do, and why

Earlier in this same session the Qwen reviewer wrapper was repaired and proven to
work in production (`popcre/ai-devops` PR #316, merge commit `795902d8`). The owner
then said: "now add qwen to the reviewer rotation then Wrap Up." So this workstream
is purely the rotation registration — making Qwen drawable for new review work.

## 3. Current state — what is true right now

- **`popcre/ai-devops`: DONE and merged.** The wrapper fix is on `main` as
  `795902d8`; the shared Windows checkout `C:\repos\ai-devops` has pulled it, so the
  installed `ai-qwen` command is live.
- **`u2giants/shared-db`: written, pushed, green, NOT merged.**
  - Branch `claude/qwen-rotation`, PR
    https://github.com/u2giants/shared-db/pull/2555, issue #2558.
  - `scripts/manage-migration-author-lanes.mjs`: `QUARANTINED_REVIEWERS` is now
    `Object.freeze([])` with a dated note explaining the unquarantine; the
    `qwen-3.8-max` row's `readsRepositoryVerified` evidence is re-dated to
    2026-09-07 and cites merge commit `795902d8`.
  - `scripts/manage-migration-author-lanes.test.mjs`: the roster/order test now
    expects six active reviewers including `qwen-3.8-max`; the two
    `ACTIVE_REVIEWERS.length` assertions are 6; the capacity-report test has a sixth
    case and updated classification/summary expectations; the test that proves an
    ineligible reviewer stays readable but receives no assignment is repointed at the
    RETIRED `codex-gpt-5.6-sol` (it used to use Qwen, which is no longer ineligible).
  - `.agent/contract.json` and `.agent/completion.json` written for issue #2558,
    generation 2, contract ref `refs/db-contracts/2558/2`.
  - Local suite: **475 passed, 0 failed**. All CI checks pass **except**
    "Cross-PR object collision".
  - The branch was rebased onto `main` once already (`origin/main` moved), and the
    contract `base_sha` / report `head_sha` were re-pointed afterwards.
- **Blocked:** merge state is BLOCKED solely by the collision with PR #2551.

## 4. Everything we tried that did NOT work

- **Merging without the agent-work evidence pair.** The "Agent work contract" check
  runs in *enforced* mode and rejects a PR that does not change BOTH
  `.agent/contract.json` and `.agent/completion.json`; inherited files from `main`
  do not count. Fixed by opening issue #2558 and authoring a real pair.
- **Listing the `.agent/*` files in `completion.json`'s `files_changed`.** The Git
  evidence check compares that list to the diff from the PR base up to
  `report.head_sha` — which is the *implementation* commit, before the evidence
  commit exists. Only the two script files may be listed.
- **Republishing the contract under the same generation after the rebase.** The
  contract ref is content-addressed; the rebase changed `base_sha`, so generation
  had to go from 1 to 2 and `contract_sha256` had to be updated to the new hash.
- **A Python heredoc edit that produced a stray apostrophe inside the test name.**
  The escaped apostrophe did not survive the heredoc, and Node rejected the file.
  Fixed by removing the apostrophe from the test name entirely.
- **Editing these `.mjs` files with a naive text read/write.** They use CRLF line
  endings; a plain rewrite corrupts the whole file's diff. Read with `newline=''`,
  normalize, write back with CRLF.
- **Waiting out PR #2551.** Polled for roughly 40 minutes; it never moved.

## 5. Root causes and key findings

- The collision guard blocks on any **earlier** open PR touching the same protected
  coordination source. Being green everywhere else does not help; only merging or
  closing the other PR does. The guard's own message says so and confirms no
  migration version or database-object claim is consumed by the failure.
- PR #2551 is itself conflicted with `main` (`mergeStateStatus: DIRTY`), so it cannot
  merge as-is either — someone has to act on it.
- The capacity-report test builds exactly one lease case per active reviewer, so
  adding a rotation member requires adding a case AND updating three expectation
  lists plus two summary objects inside that one test.

## 6. Exact next steps

1. Put item 1 of section 0 to the owner in one message. *You'll know it worked when
   he says close it or leave it.*
2. If cleared to close: `gh pr close 2551 --repo u2giants/shared-db` with a comment
   saying the work should be re-raised from current `main`. *You'll know it worked
   when `gh pr view 2551 --json state` reports `CLOSED`.*
3. In `C:/repos/shared-db/.worktrees/qwen-rotation`, run `git fetch origin` then
   `git rebase origin/main`. If it conflicts only in `.agent/*`, keep YOUR versions
   (`git checkout --theirs .agent/contract.json .agent/completion.json`). If the
   rebase moves anything, bump the contract generation, re-run
   `node scripts/agent-work-contract.mjs --publish-contract --contract-file
   .agent/contract.json`, and update `contract_ref`, `contract_sha256`, `base_sha`
   and `head_sha` to match. *You'll know it worked when both
   `--validate-completion` and `agent-work-contract-git-evidence.mjs` print success.*
4. Push (`git push --force-with-lease`) and wait for all checks. *You'll know it
   worked when `gh pr view 2555 --json statusCheckRollup` shows no non-SUCCESS
   conclusions and merge state is no longer BLOCKED.*
5. Merge PR #2555 yourself and report the merge commit. Albert does not merge.
   *You'll know it worked when `gh pr view 2555 --json state,mergedAt` says MERGED.*
6. Delete this handoff file in that same merge, and close issue #2558.

## 7. Constraints and gotchas in force

- `shared-db` changes go through a branch and PR — never a direct push to `main`.
- Never edit, rebase, close or "tidy" another session's branch, worktree, or
  `HANDOFF.d/` file without the owner's word. That is exactly why step 1 exists.
- Every name in `REVIEWERS` stays forever; only `QUARANTINED_REVIEWERS` (reversible)
  and `RETIRED_REVIEWERS` (permanent) control eligibility.
- Do not delete the ineligible-reviewer protection test to make the suite pass —
  repoint it, as this branch did.
- `--admin` does not bypass a repository ruleset, and this collision guard should not
  be bypassed at all: it exists to stop two PRs racing the same coordination file.

## 8. Access and environment

- Machine `edge-dev`, Windows, Git Bash. GitHub CLI is authenticated as `u2giants`.
- Working copies: `C:/repos/shared-db/.worktrees/qwen-rotation` (branch
  `claude/qwen-rotation`, clean) and
  `C:/repos/ai-devops/.claude/worktrees/muse-grok-reviewer-availability-dac8b6`.
- Secrets live in the 1Password vault `vibe_coding`. Qwen's provider key is the
  `dashscope` field of the "ai provider api keys openai deepseek chatgpt qwen" item.
  Never put a value in chat, a command line, a log, or a commit.

## 9. Open questions and risks

- **2026-09-07:** if PR #2551 is left open indefinitely, this rotation change stays
  blocked indefinitely. There is no timeout in the guard.
- **2026-09-07:** the rotation grows from five names to six, so any *other* open PR
  that hard-codes five active reviewers will fail after this merges. None was found
  today, but a long-lived branch could carry one.
- **2026-09-07:** Qwen now bills per token on Model Studio. Adding it to the rotation
  means real spend per review. Recorded as a known, accepted consequence.

## Self-audit

1. **Comprehensive for a stranger?** Yes — §1 defines both repositories and the
   rotation concept, §3 gives branch, PR, issue, file and test state, §6 gives
   executable steps with gates.
2. **As effective as this session?** Yes — §4 and §5 carry every non-obvious thing
   learned (evidence-pair rules, the `files_changed` window, CRLF, contract
   generation bumps, the guard's exact semantics).
3. **Every relevant detail?** Yes — background §1–§2, state §3, failures §4, findings
   §5, steps §6, constraints §7, access §8, risks §9, all with concrete identifiers.
4. **Would section 0 alone show every owner decision?** Yes. Walking §1–§9: the only
   sentence needing the owner's judgement is the PR #2551 disposition (§3 blocked,
   §5 root cause, §6 step 1, §9 first risk) and it is item 1 of §0. The settled
   items (quarantine lift, dead Coding Plan key) are listed as do-not-re-ask.
