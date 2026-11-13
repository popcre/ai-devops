---
issue: none  # wrap-up scope freeze 2026-11-13 forbids opening a tracker mid-closeout; the open items are named in §6
status: OPEN
owner: mimo/edge-dev ses_ffe5e2d8d4fcdffeS1R1pHQ7vt
---

# Handoff — closeout receipt and two CI flakes (session signatures workstream)

Written at the end of the session that landed the GitHub-signature display-name
change and the #2498 test fix. Both deliverables are **done and merged**. This
file exists because one wrap-up verification step is **blocked** (§6 step 1) and
two CI-runner findings were deliberately **not** chased (§6 steps 2–4).

## 0. Business decisions only the owner can make

**None — nothing in this workstream needs the owner.** The two open items are
technical housekeeping (a re-runable receipt and two flaky-test findings); an AI
session can do both without asking anything. Already settled this session, do
NOT re-ask: "name plus short id in the signature" (owner, 2026-11-13, chosen
over name-only and over separate GitHub logins) and "#2498 is worth fixing"
(owner, 2026-11-13).

## 1. What this application is

`popcre/ai-devops` — Albert Hazan's public recovery toolkit for a multi-model AI
coding workflow (plan → review → implement → test → review) used by AI coding
sessions (Claude, Codex, GLM, MiMo, ZCode, …) on Windows development machines
and Ubuntu servers. It is not an app or service: it is CLI tools (`bin/`),
skills, templates, and docs. Repo: https://github.com/popcre/ai-devops

## 2. What we set out to do this session, and why

Two owner requests, in order:

1. Make every GitHub issue comment / PR post identify **which AI session, in
   which app** wrote it — first just the session id, then (owner's choice) the
   session's **display name plus a short id**, for four apps: MiMo Desktop,
   ZCode, Claude desktop, and ChatGPT for Windows (Codex).
2. Fix the stale task-gates test that kept reddening a test group on every pull
   request (GitHub issue https://github.com/popcre/ai-devops/issues/2498). A
   sub-agent was dispatched for this; it stalled and the coordinator finished
   the work itself (part (b) below).

## 3. Current state — what is true right now

**Done and verified on `origin/main`:**

- Signature change — PR https://github.com/popcre/ai-devops/pull/2495, squash
  merge commit `f3d20a40` ("signatures: carry the session display name and short
  id on GitHub posts (#2495)"), merged 2026-11-13 10:01 PM EST. New tool
  https://github.com/popcre/ai-devops/blob/main/bin/ai-gh-signature plus its
  Windows launcher
  https://github.com/popcre/ai-devops/blob/main/bin/ai-gh-signature.cmd ;
  rule text at
  https://github.com/popcre/ai-devops/blob/main/docs/standing-rules-details.md
  ("GitHub signature"); checker updated at
  https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check
  (named form, ZCode `sess_` tokens, ZCode claim owners; the #2431 env
  non-veto guard kept). Format:
  `Posted by <App> chat "<display name>" (<short id>) on <machine>`, name
  omitted when the app has none.
- #2498 fix — PR https://github.com/popcre/ai-devops/pull/2499, merge commit
  `afa935fc` ("task-gates test: expect pr-wait to be allowed for prose (#2489)
  (#2499)"), merged 2026-11-13 9:27 AM EST. The fixed line is at
  https://github.com/popcre/ai-devops/blob/main/tests/test-ai-task-gates.sh#L1106
  .
  Issue https://github.com/popcre/ai-devops/issues/2498 is **CLOSED**.

**Not done / blocked at write time (2026-11-13T1537Z):**

- The wrap-up zero-owned-claims receipt (`ai-shared-db-closeout-check`) has not
  succeeded yet — see §4 and §6 step 1. The session never touched shared-db and
  holds no claims (verifiable from this session's history), but the tool fails
  closed and an empty array with `ok:false` is **not** proof.
- Two CI-runner flakes are known and **unfiled** (§5, §6 steps 2–4).

**Workspace state:** all branches/worktrees from the delivered work are cleaned
up (both PRs proven MERGED via GitHub state, not git ancestry — the merges are
squashes). One branch `mimo/handoff-closeout-receipt` holds THIS file (pushed;
its PR could not be opened — see §4 dead end "GitHub core budget").

## 4. Everything we tried that did NOT work

Read this section first; each entry cost real time.

1. **`chmod +x` on Windows does not stick in the git index.** Added
   `bin/ai-gh-signature`, ran `chmod +x`, committed — CI failed
   "these bin/ entries are not executable in git". Cause: Windows checkouts
   have `core.filemode=false`, so the exec bit is never recorded. Fix used:
   `git update-index --chmod=+x <file>` before committing.
2. **A new extensionless `bin/` tool without a `.cmd` sibling fails CI.**
   "bin/ai-gh-signature has no bin/ai-gh-signature.cmd launcher". Windows
   shells hand extensionless files to "Select an app". Fix: copy the standard
   launcher body (see `bin/ai-gh-signature.cmd`); the required lines are
   asserted by https://github.com/popcre/ai-devops/blob/main/tests/test-bin-cmd-launchers.sh
   .
3. **Hand-editing the ZCode/MiMo globals template files is wrong.** CI failed
   "committed ZCode/MiMo globals drifted from the rendered Codex body".
   `templates/system/AGENTS-global-{zcode,mimo}.md` are **rendered** from
   `AGENTS-global-codex.md` by `bin/ai-render-globals` using
   `templates/system/global-overrides/{zcode,mimo}.sed`. Fix: put the
   engine-specific wording in the Codex body + sed rules, then run the
   renderer. Asserted by
   https://github.com/popcre/ai-devops/blob/main/tests/test-ai-render-globals.sh
   .
4. **Sub-agent `general-1` for #2498 stalled.** It created the right worktree
   and applied the right one-line edit, then made no commit and no PR in 30
   minutes (17 turns, long shell calls being killed). Coordinator cancelled it
   and finished the job — see part (b).
5. **Long shell commands get killed mid-run** ("Unknown: ChildProcess.kill"
   with the whole command echoed). Hit on `ai-pr-wait`, test suites, and
   `gh pr create`. Workaround that works: launch detached
   (`nohup bash -c '... > log 2>&1' &`) and read the log. Important: the
   kill does **not** mean the command failed — `bin/ai-gh pr create` printed
   that error and the PR existed. Always verify state instead of retrying.
6. **`ai-shared-db-closeout-check` run 1** ended
   `{"ok":false,"error":"GitHub request failed",...}` after five API calls —
   must NOT be read as "zero claims"; the tool is deliberately fail-closed.
   **Run 2** ended `{"ok":false,"error":"GitHub authentication is unavailable"}`.
   Root cause: `bin/ai-gh auth status` itself answers
   "GitHub core budget paused until its own reset; not calling GitHub." — the
   machine-wide GitHub budget/rate limiter is exhausted (this also made the
   `ai-housekeeping` GitHub probe time out). Repair = wait for the budget
   reset, re-run (§6 step 1).
7. **Local full run of `tests/test-ai-task-gates.sh` on Windows never
   finished** (>50 minutes; each check spawns bash + git + the tool). Killed
   as redundant: CI on Linux (the target OS) had already proven the fix on the
   exact landing commit. While it ran it showed one **unrelated** failure —
   "authorization cannot be issued twice for one target" — whose prerequisite
   checks are Linux/POSIX-only and skip on Windows, so the authorization it
   expects is never created there. Pre-existing Windows-only artifact; not
   caused by the fix (that check runs earlier in the file than the changed
   line).
8. **`git worktree remove` can leave a directory behind** ("Permission
   denied") after the git registration is already gone. Retry with
   `Remove-Item -LiteralPath <dir> -Recurse -Force` (PowerShell); content was
   proven clean/incorporated first.

## 5. Root causes and key findings

- **Signature design** (owner-chosen): display name + short id. The display
  name is each app's OWN session name (MiMo session title in
  `~/.local/share/mimocode/mimocode.db`, ZCode task title in
  `~/.zcode/v2/tasks-index.sqlite`, Claude `custom-title.json` sidecar under
  `~/.claude/projects/<project>/<session>/`, Codex `thread_name` in
  `~/.codex/session_index.jsonl`). Never fall back to first-prompt text —
  prompts can carry private data and the line is posted publicly. Short id =
  `ses_`/`sess_` prefix + 8 chars, or first 8 chars of a UUID.
- **Legacy signatures stay valid** (bare full id, no parens/name) — the
  checker accepts both forms, so nothing signed before 2026-11-13 breaks.
- **The closeout checker's short-id rule is conservative on purpose:** a short
  id expands to the current session only when the current session id starts
  with it; otherwise it counts as a foreign signer (see
  `expand_short_identity` in
  https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check
  ).
- **#2489 removed `pr-wait` from the prose class `forbidden_actions`** in
  https://github.com/popcre/ai-devops/blob/main/config/task-gates.json (waiting
  on checks is orthogonal to content class) but forgot the test at
  https://github.com/popcre/ai-devops/blob/main/tests/test-ai-task-gates.sh#L1106
  — that mismatch was #2498, now fixed.
- **Two CI runner flakes (advisory checks only — they do not block merges
  under the lean-required-checks owner ruling 2026-10-30):**
  1. `tests/test-ai-devops-doctor-install-lag.sh` — its "up to date" case
     compares a pinned SHA against a **moving** `origin/main`, so a push
     landing mid-run fails it with "FAIL: expected the up-to-date report"
     ("installed tools at <sha> are 2 commits behind origin/main <sha>").
     Seen on linux-offline-shard (4) on both runs of PR #2495.
  2. `tests/test-ai-install-skills.sh` — step "symlinked launcher could not
     find its checkout" needs a real symlink; on the
     `windows-offline-section (2, qualified-self-hosted)` runner `ln -s`
     sometimes copies instead, and the script then resolves the wrong repo
     root. Both flakes pass on a clean `main` checkout locally.
- **ai-gh's machine-wide GitHub budget** (spacing + hourly budget + rate-limit
  back-off) serializes every GitHub call on this machine; when it is paused,
  even `auth status` is refused. Plan around it: detached runs, and expect
  ~5–8 minutes per API call while it is congested.

## 6. Exact next steps

1. **Re-run the zero-owned-claims receipt.** From a checkout of
   https://github.com/popcre/ai-devops (any worktree), run
   `bin/ai-shared-db-closeout-check --session-id ses_ffe5e2d8d4fcdffeS1R1pHQ7vt`
   once `bin/ai-gh auth status` answers normally (GitHub core budget reset).
   *You'll know it worked when* the JSON says `"ok":true` with empty
   `blocking_claims` and `blocking_stages`. If it errors, do NOT read empty
   arrays as success — fail closed and retry after the next budget window.
2. **File the two flake findings as issues** on
   https://github.com/popcre/ai-devops (this is the tracker that will retire
   THIS handoff file). Ready-to-paste titles/bodies:
   - `doctor-install-lag test races a moving origin/main` — "The up-to-date
     case in tests/test-ai-devops-doctor-install-lag.sh compares a pinned
     source-sha against a re-read origin/main; a push landing mid-run fails it
     with 'FAIL: expected the up-to-date report'. Seen on linux-offline-shard
     (4) for PR #2495 twice. Fix: pin the origin/main SHA the test computed
     instead of re-reading the remote ref, or retry once on mismatch."
   - `install-skills symlink test is flaky without symlink privilege` —
     "tests/test-ai-install-skills.sh step 'symlinked launcher could not find
     its checkout' needs ln -s to create a real symlink; on the
     windows-offline-section (2, qualified-self-hosted) runner it sometimes
     copies instead and the checkout resolution fails. Fix: skip the check
     when ln -s does not produce a symlink, or copy a resolvable stub."
     *You'll know it worked when* both issues exist and are linked to this
     handoff.
3. **(Optional) fix flake 1** per its body. *Gate:* the suite passes twice in
   a row on a machine where `origin/main` moves during the run.
4. **(Optional) fix flake 2** per its body. *Gate:* the suite passes on the
   qualified-self-hosted Windows runner.
5. **Retire this handoff file** in the same pull request that closes the issue
   from step 2 (successor rule — the session that finishes the next step
   deletes the file). Do not delete it while §6 step 1 is unproven.

## 7. Constraints and gotchas in force

- Never push to `main`; branch + PR + merge queue. Plain `gh pr merge` (no
  `--admin`, no `--squash`) — the queue owns the strategy. Prose-only PRs run
  `bin/ai-doc-safety --changed origin/main` on the exact head first.
- Sign every GitHub post with
  `Posted by <App> chat "<display name>" (<short id>) on <machine>`
  (`bin/ai-gh-signature` builds it). Keep existing signatures when editing a
  body.
- Declare work before starting: `bin/ai-task-gates start --class <class>`.
- All GitHub API calls go through `bin/ai-gh` (machine-wide spacing/budget).
- Committer identity must be `Albert Hazan <u2giants@users.noreply.github.com>`
  (`git var GIT_COMMITTER_IDENT`), with the
  `Co-authored-by: Albert Hazan <u2giants@users.noreply.github.com>` trailer.
- Canonical checkout is landing-only; every write task uses its own worktree.
- `git branch -d` cannot see squash merges — prove merged via
  `gh pr view <n> --json state,mergedAt` before deleting a branch.
- Never open raw transcript archives (`.jsonl` chat dumps) in any repository.

## 8. Access and environment

- Machine `edge-dev` (Windows; tests run through Git Bash; PowerShell 7 for
  native file ops). Session id `ses_ffe5e2d8d4fcdffeS1R1pHQ7vt` (MiMo Desktop).
- `gh` is authenticated as usual, but at write time (2026-11-13T1537Z)
  `bin/ai-gh` reports "GitHub core budget paused until its own reset" — every
  GitHub call is refused until then. `git push` over HTTPS is unaffected.
- No credentials appeared this session; 1Password vault `vibe_coding` unused.
- Session notes with the Windows tooling traps are in the session memory for
  `ses_ffe5e2d8d4fcdffeS1R1pHQ7vt` (also restated in §4/§5 here).

## 9. Open questions and risks

- Whether to **fix** the two flakes or **drop** the affected checks — owner
  ruling 2026-10-30 ("lean required checks") already treats them as advisory,
  so they never block merges; dropping is legitimate if they keep reddening
  every PR. Recommendation: file both issues (step 2), fix the doctor-lag one
  (cheap), and skip-guard the symlink one. Dated 2026-11-13 so a later session
  does not unknowingly contradict it.
- The closeout receipt (§6 step 1) is the only hard verification gate left;
  everything else in this workstream is proven on `origin/main`.

---

## Part (b) — sub-agent blocks (one per agent)

### Agent: general-1 (coordinator-spawned general subagent, task "Fix stale task-gates test #2498")
- **Asked to do:** fix https://github.com/popcre/ai-devops/issues/2498 end to
  end (test expectation, proof, PR, merge) per a detailed brief.
- **Actually did:** created worktree `D:/repos/ai-devops-worktrees/task-gates-pr-wait`
  (branch `mimo/task-gates-pr-wait-test`, based at `f3d20a40`) and applied the
  one-line edit to `tests/test-ai-task-gates.sh` — verified byte-identical to
  the change that later landed as `afa935fc`. No commit, no push, no PR.
- **Found:** the corrected expectation (`rc 0`, renamed check) matched the
  #2489 rule change — same conclusion the coordinator reached independently.
- **PR / branch:** none. Branch `mimo/task-gates-pr-wait-test` deleted after
  proving its only change was superseded by merged `afa935fc`.
- **Worktree:** finished — removed after proving clean-and-superseded (its
  uncommitted edit diffed identical to the merged fix).
- **Deliberately did NOT do, and why:** N/A — it stalled rather than deciding;
  long tool calls were being killed (dead end 5) and it made no progress for
  30 minutes, so the coordinator cancelled it per the no-progress rule and
  completed the work itself.

---

## Self-audit (handoff-writer gate)

1. *Could a brand-new developer pick up with no context?* Yes — §1 orients the
   repo, §3 states exactly what landed (PRs + merge commits + URLs) and what
   did not, §6 gives ordered actions with gates.
2. *As effectively as me right now?* Yes — §4/§5 carry every non-obvious trap
   (Windows exec bit, `.cmd` launcher, rendered globals, fail-closed receipt,
   ai-gh budget, tool-kill false alarms) that cost this session time.
3. *Every relevant detail?* Yes — background (§1–2), state (§3), failures
   (§4), findings (§5), actions (§6), constraints (§7), access (§8), risks
   (§9), plus the sub-agent block (part (b)).
4. *Does §0 hold every owner decision and no technical approval?* Yes — the
   sweep found no owner-judgement items anywhere in §1–§9 or part (b): the
   open items are a re-runable receipt and two flaky-test findings, both
   fully technical; §0 also records the two decisions already settled this
   session so they are not re-asked.
