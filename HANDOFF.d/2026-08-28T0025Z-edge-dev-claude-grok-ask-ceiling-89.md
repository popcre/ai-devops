---
issue: 89
status: OPEN
owner: claude/flaky-reviewer-tests-timing-c1ba63
---

# Finish issue #89 — merge PR #123 once `windows-reviewer-safety` is green

Written 2026-08-28T0025Z on `edge-dev` by Claude (Opus 5), session
`flaky-reviewer-tests-timing-c1ba63`. The work is one CI run away from done.

---

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.**

The remaining work (watch one CI run, merge the PR, close the issue, delete the
branch) is already authorized by the standing rule "the session that opens a PR
merges it." Do not ask Albert to merge, review, or approve PR #123.

**Already settled — do NOT re-ask:**

- 2026-08-26: a self-hosted local runner for this repo was REJECTED. `popcre/ai-devops`
  is public, so a self-hosted runner would execute forked-PR code on Albert's machine,
  and its pre-installed tools would defeat the suites that test installation from
  scratch. Reasoning recorded in
  `HANDOFF.d/2026-08-26T1810Z-al8960ofc-claude-windows-offline-suite-parallelism.md:142`.
  The chosen alternative is in-harness parallelism.
- 2026-08-27: assertions in the reviewer suites may not be weakened. Raising a
  timeout until nothing fails, marking a test allowed-to-fail, or deleting it is
  symptom suppression. A change that lowers the check counts (191 Grok, 203 Kimi)
  has removed coverage.
- 2026-08-27: a documentation-only PR is merged immediately with
  `gh pr merge --squash --admin` and does not wait for checks. This is now a
  global standing rule in `templates/system/CLAUDE-global.md` and
  `templates/system/AGENTS-global-codex.md`.

---

## 1. What this application is

`popcre/ai-devops` (GitHub; also valid under the older `u2giants` owner — both are
intentional, never delete either from `repo-identities.tsv`) is Albert Hazan's
tooling repository for POP Creations. It installs and governs the AI coding
assistants he runs across several machines: wrapper scripts in `bin/` (`ai-grok-review`,
`ai-kimi`, `ai-deepseek-agent`, `ai-muse`, `ai-gemini`, `ai-glm`, `ai-qwen`),
shared skills under `skills/`, and global instruction templates under
`templates/system/` that are installed to `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md` by `bin/ai-adopt-globals`.

Its users are Albert and the AI sessions themselves. There is no deployed service —
"shipping" here means merged to `main` on GitHub.

The wrappers are exercised by offline Bash suites in `tests/` (e.g.
`tests/test-ai-grok-review.sh`, `tests/test-ai-kimi.sh`), run by GitHub Actions in
three jobs: `linux-offline` (~9 min), `windows-offline` (~65–70 min), and
`windows-reviewer-safety` (~15–22 min). `windows-reviewer-safety` is NOT a required
check; the merge queue can merge past it.

## 2. What we set out to do this session, and why

Issue [#89](https://github.com/popcre/ai-devops/issues/89): the reviewer test suites
were flaky. Checks failed intermittently on CI and passed locally, so nobody could
trust a red run — which meant real defects hid behind assumed flakiness.

Business terms: the automated safety net for Albert's AI tooling was crying wolf,
so it was being ignored.

The technical objective was to make every timing-dependent wait derive from a
**measured baseline** for the machine it runs on, instead of a hard-coded number of
seconds that is generous on a fast laptop and far too short on a loaded CI runner.

## 3. Current state — what is true right now

**Branch:** `claude/flaky-reviewer-tests-timing-c1ba63`
**PR:** [#123](https://github.com/popcre/ai-devops/pull/123) — **OPEN**, targeting `main`.
**Worktree:** `C:\repos\ai-devops\.claude\worktrees\flaky-reviewer-tests-timing-c1ba63`
(a linked git worktree — run everything from there, never `cd` to `C:\repos\ai-devops`).
**Working tree: clean. Everything is committed and pushed.**

Commits on the branch, newest first:

| SHA | What it did |
|---|---|
| `8dbc3b6a` | **The fix under test right now** — gave the duplicate `ask` its own wide ceiling (see §5) |
| `a5e5f7f3` | Corrected an over-claim: #89 is improved, not proven closed |
| `9aec837d` | Made the last two silent test timeouts loud |
| `050ad1ef` | The main change: derive reviewer test timing budgets from a measured baseline |

**What works and is verified:** the timing helper `tests/lib-test-timing.sh` (new
in this branch) provides `budget FACTOR FLOOR`, `poll_until`, and `scale_ticks`.
Every reviewer suite was converted to it. On CI at head `9aec837d`, all three jobs
passed (run 33099812801). `linux-offline` and `windows-offline` have passed at
every head since.

**What is unproven:** `windows-reviewer-safety` at head `8dbc3b6a`. GitHub Actions
run **33129319793** was `queued` when this session ended. It is the only thing
between the branch and a merge.

**The failure it is meant to fix**, observed at head `a5e5f7f3` in run
33119928129 (job 98683989739), `windows-reviewer-safety`, 22m13s:

```
FAIL same_next_ask_turn_is_serialized
fixture: the uncertain ask took its work lock and reached the Grok stub did not hold within 180s (baseline 12s)
FAIL uncertain_ask_blocks_its_exact_retry
```

**Not started / out of scope:** issue #98 (windows-offline CI latency) belongs to a
different session — do not touch it.

## 4. Everything we tried that did NOT work

- **Trusting a single measured baseline taken once at the top of a long suite.**
  Reasonable, and wrong: a machine that slows down mid-run makes every later
  deadline wrong. The lesson — fix the *shape* of the wait, never the ceiling — is
  recorded in memory as `frozen-baseline-timeouts`.
- **Assuming the first attribution was complete.** Diagnosis §3.4b in `fix_test_ai.md`
  correctly measured that an `ask` builds a review packet costing ~124s on the
  `windows-reviewer-safety` runner, and commit `050ad1ef` widened the ceilings of the
  two *held* ask turns to `budget 40 120`. That was right but partial: the **duplicate**
  ask in the same block, and the readiness poll for the *uncertain* ask, were left on
  narrow ceilings. Both pay the same 124s packet cost. That is the failure in §3, and
  the fix in `8dbc3b6a`.
- **Editing a test script while copies of it were running.** Bash reads scripts
  incrementally from disk, so three concurrent runs died with a syntax error at line
  315 of a file that was valid on disk. Worked around by running in-repo snapshots
  (`tests/.snap-grok.sh`) that dodge the `test-*.sh` discovery glob.
- **`git stash`.** The stash stack is shared across every worktree and every
  concurrent session. Recovered by SHA, but another session's entry was on the stack
  at the time. Use a temporary WIP commit instead.
- **An orphaned background run writing into a log a new run was also writing** —
  produced an interleaved file and a bogus 155-failure result that was believed for
  a while. Always write each run to a uniquely named log.
- **`gh run watch` from several sessions at once** — trips a GitHub *secondary*
  rate limit that 403s every Actions API call while `gh api rate_limit` still reports
  `5000/5000 remaining`. Memory: `gh-run-watch-burns-the-api-quota`. Poll with
  `gh run list` instead.
- **Writing a background log to `$TMPDIR`** — `TMPDIR` is unset in this Bash tool, so
  the redirect became `/grok-local.log` and failed with "Permission denied". Use an
  absolute path.
- **`git push` while the PR sat in the merge queue** — rejected with `GH006 ... queued
  for merging cannot be updated`. See §6 step 0.

## 5. Root causes and key findings

**The class of defect (#89's real cause):** waits were written as fixed second
counts. A wait that is generous on `edge-dev` is far too short on a loaded CI
runner, so checks failed for lack of time rather than for a defect. The cure was
`tests/lib-test-timing.sh`: measure a baseline for the current machine, then express
every ceiling as `budget FACTOR FLOOR` — a multiple of that baseline with a floor.

**The specific remaining bug** — `tests/test-ai-grok-review.sh`, the ask-concurrency
block around lines 714–745:

Two named ask turns are launched and held, each under `AI_GROK_WAIT_TIMEOUT="$(budget 40 120)"`
(480s at a 12s CI baseline). A **duplicate** `ask ask-a` is then run and must be
refused with `already has a turn running`. But the duplicate was running under the
**suite-wide** ceiling (`budget 10 15`, 120s), and it builds its own review packet —
measured ~124s on that runner — *before* it ever reaches the turn-lock check. So on a
slow runner the duplicate timed out before it could be refused, and
`same_next_ask_turn_is_serialized` failed for a reason that is not a wrapper defect.

The same 124s cost is what the next readiness fixture waits on, which is why it
reported `did not hold within 180s (baseline 12s)` and took
`uncertain_ask_blocks_its_exact_retry` down with it.

**Commit `8dbc3b6a` therefore:** gave the duplicate ask `AI_GROK_WAIT_TIMEOUT="$(budget 40 120)"`,
and raised the uncertain-ask readiness poll from `poll_until "$(budget 15 30)"` to
`poll_until "$(budget 40 120)"`. **No assertion changed.** The duplicate must still
exit non-zero AND print `already has a turn running`. `grep -c '^check ' tests/test-ai-grok-review.sh`
is still 153 (the file's `check` invocations; the 191 figure in the issue is the
runtime check count, unchanged).

**Also learned:** a lingering merge-queue entry can merge a PR past a *failing*
non-required check. PR #123 was found sitting at position 6 in the queue with
`windows-reviewer-safety` red. It was dequeued deliberately.

## 6. Exact next steps

Run everything from `C:\repos\ai-devops\.claude\worktrees\flaky-reviewer-tests-timing-c1ba63`.

0. **If you need to push and the push is rejected with `GH006 ... merge queue`,**
   dequeue first (this is not an error state, just the queue holding the branch):

   ```bash
   gh api graphql -f query='mutation{dequeuePullRequest(input:{id:"PR_kwDOTN5iT88AAAABBJlGYQ"}){clientMutationId}}'
   ```

   That node ID is PR #123's. *You'll know it worked when* `git push` succeeds.

1. **Check the run at head `8dbc3b6a`.** Do NOT use `gh run watch`.

   ```bash
   gh run list --branch claude/flaky-reviewer-tests-timing-c1ba63 --limit 1 --json status,conclusion,databaseId
   ```

   *You'll know it worked when* `status` is `completed`. Expect ~70 minutes from
   2026-08-28T0019Z, because `windows-offline` is the long pole.

2. **If all three checks are green → merge and finish.** This is yours to do; do not
   hand it to Albert.

   ```bash
   gh pr merge 123 --squash
   ```

   Then close the issue:

   ```bash
   gh issue close 89 --comment "Fixed by PR #123: reviewer test timing budgets now derive from a measured per-machine baseline."
   ```

   *You'll know it worked when* `gh pr view 123 --json state` says `MERGED` and
   `gh issue view 89 --json state` says `CLOSED`. If `gh pr merge` prints
   `'main' is already used by worktree`, that is local branch cleanup failing AFTER
   a successful merge — confirm the state and continue; do not report it as a failure.

3. **If `windows-reviewer-safety` failed again**, pull the job log and read the FAIL
   lines and the `did not hold within Ns (baseline Ns)` fixture messages:

   ```bash
   gh run view 33129319793 --log-failed
   ```

   The diagnosis method that works: for each failing check, find what operation the
   wait is actually waiting on, measure that operation's real cost on that runner, and
   make the ceiling a multiple of the measured baseline that comfortably exceeds it.
   *Never* just raise a number until it passes. Record the measurement in
   `fix_test_ai.md` next to the existing §3.4b entry.

4. **After the merge, delete this handoff file** — its issue will be closed, so it is
   finished. Do not delete any other session's file.

## 7. Constraints and gotchas in force

- **Do NOT weaken assertions.** Raising a timeout until nothing fails, marking a test
  allowed-to-fail, or deleting it is symptom suppression. A change that lowers the
  runtime check counts (191 Grok, 203 Kimi) has removed coverage. Widening a *fixture
  ceiling* so a test can fail for the right reason is legitimate — but justify it with
  a measured cost, in the commit message.
- **Do not touch issue #98** (windows-offline CI latency). Another session owns it.
- **This is a linked worktree.** Never `cd` to `C:\repos\ai-devops` — it is at
  `bffec57f`, dirty with another session's work (`bin/ai-deepseek-agent`, `bin/ai-muse`,
  a HANDOFF file). Do not pull or commit there.
- **Never use bare `git stash` / `git stash pop`** — the stack is shared with every
  other worktree and session.
- **Never edit a test script while copies of it are running.**
- **Give every background test run a unique absolute log path.** `$TMPDIR` is unset here.
- **`windows-reviewer-safety` is not a required check**, so the merge queue can merge
  past it while it is red. Verify the check itself, not just the merge state.
- **Line endings:** this checkout post-dates `.gitattributes`, but older ones did not —
  CRLF corruption is invisible to `git grep`; use `git ls-files --eol`.

## 8. Access and environment

- **Machine:** `edge-dev` (Windows 11 Pro). Shell: Git Bash for the Bash suites,
  PowerShell for PowerShell suites.
- **`gh` CLI:** authenticated as `u2giants`, with admin rights on `popcre/ai-devops`
  (verified this session — an `--admin` merge and a GraphQL dequeue both succeeded).
- **Git identity:** must be `Albert Hazan <u2giants@users.noreply.github.com>` —
  check with `git var GIT_COMMITTER_IDENT` before your first commit.
- **The suites are fully offline.** They stub every model call; no API key is needed
  to run `bash tests/test-ai-grok-review.sh`. A local run takes roughly 20–30 minutes.
- **Secrets:** 1Password vault `vibe_coding`. Nothing in this workstream needs one.

## 9. Open questions and risks

- **Risk (main):** the ceiling widening in `8dbc3b6a` is reasoned from a measured
  ~124s packet build, but it has not yet been proven on the `windows-reviewer-safety`
  runner. If it fails again, the cause is a different operation inside that block,
  not a too-small number — re-measure per §6 step 3.
- **Risk (minor):** a local full-suite run was started in this session as extra
  confidence and did not finish before the session ended; its result is unknown and
  its log is in a session-scoped scratchpad that will be discarded. CI is the
  authority, so nothing is lost — just do not go looking for that log.
- **Decision, 2026-08-27:** issue #89 is described as *improved, not closed*, until CI
  proves it. Commit `a5e5f7f3` exists specifically to walk back an earlier over-claim.
  Hold that line: close #89 only on a green run, not on reasoning.
- **Open question:** `windows-offline` at 65–70 minutes makes every iteration cost an
  hour. Issue #98 owns that; do not solve it here.

---

## Self-audit (run 2026-08-28T0025Z — all four pass)

1. **Could a street newcomer continue?** Yes. §1 defines the repo and its suites with
   no assumed knowledge; §3 gives the exact branch, PR, worktree path, and commit
   table; §6 gives copy-pasteable commands with verification gates.
2. **As effectively as this session could?** Yes. The non-obvious cost that drove the
   whole fix (a ~124s review-packet build before the lock check) is stated in §5 with
   its file and line range, and the seven dead ends in §4 are the session's actual
   lost hours.
3. **Every relevant detail?** Yes — background §1, goal §2, state §3 with commit and
   run IDs, failures §4, root cause §5 with the exact ceilings, next actions §6 with
   gates, constraints §7, access §8, risks §9.
4. **Would §0 alone show every owner decision?** Yes, verified by walking §1–§9 line
   by line. Nothing in this workstream needs Albert's judgement: the merge is the
   session's own responsibility under a standing rule, and the three decisions that
   *look* like asks (local runner, no assertion weakening, docs-only merges) are all
   already settled and are listed in §0 as do-not-re-ask.
