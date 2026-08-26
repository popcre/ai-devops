---
issue: 89
status: OPEN
owner: claude/github-org-move-handoff-d576f2
---

# HANDOFF — the two AI reviewer test suites are non-deterministic (2026-08-26 11:25 UTC, edge-dev/claude)

**The diagnosis itself lives in [`fix_test_ai.md`](../fix_test_ai.md) at the repo
root. Read that first — this file is the session context around it.**

This session also finished **Phase A of the `popcre` organization move**
(issue [#84](https://github.com/u2giants/ai-devops/issues/84)). That is a
separate, still-open workstream with its own handoff
(`HANDOFF.d/2026-08-25T2012Z-edge-dev-claude-ai-devops-gh-org-move.md`). See §3
for exactly what landed, and §0 item 6 for the one thing that is now stale in
that predecessor file.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **one message before starting work**. Do not
raise them one at a time as you trip over them.

### BLOCKING — work cannot finish without an answer

*None.* Issue #89 can be diagnosed and fixed without an owner decision. The
constraint that matters (do not weaken the assertions) is already a standing
rule, not a choice.

### RECOVERABLE — a wrong guess is fixable but wastes rework

1. **How much slowness should the reviewer suites tolerate?**
   The tests compress a 900-second production timeout down to 2–3 seconds. Any
   fix has to pick a new number or a new method. **Recommendation: derive the
   test ceiling from a measured baseline at suite start rather than hard-coding
   a bigger constant** — a constant that is generous today becomes flaky again
   on a slower machine. One word settles the direction.
   *Blocks:* nothing; adjustable afterwards.

2. **Should the other five reviewer suites be swept at the same time?**
   `test-ai-deepseek-agent.sh`, `test-ai-muse.sh`, `test-ai-gemini.sh`,
   `test-ai-qwen.sh` and `test-ai-glm.sh` were **not** examined and may share
   the same timing pattern. **Recommendation: yes, sweep them in the same
   session** — the diagnosis is already paid for, and finding the same bug five
   more times separately costs five more sessions.
   *Blocks:* nothing; scope choice only.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

3. **`edge-dev` may have a real resource problem.** The flakiness is explained
   by machine contention, but that contention was never measured. If this box is
   genuinely short of disk, or antivirus is scanning every temp file a test
   writes, that hurts every session on it, not just these tests.
   **Recommendation: worth 15 minutes of measurement before anyone assumes the
   tests are entirely at fault.** Nobody is on this.

4. **Six `HANDOFF.d/` files are STALE — their issues are already closed.**
   The target for stale files is zero. None of them is mine, and the retirement
   rule needs the retiring session to confirm each file's obligations were
   carried forward, which I cannot do for workstreams I did not run:

   | File | Issue | Owner from its contract block |
   |---|---|---|
   | `2026-08-17T2115Z-al8960ofc-codex-reviewer-system-repair.md` | #34 CLOSED | `codex/reviewer-system-repair-analysis` |
   | `2026-08-18T0114Z-al8960ofc-claude-reviewer-packet-phase-a.md` | #34 CLOSED | `claude/reviewer-packet-phase-a` |
   | `2026-08-18T1929Z-al8960ofc-codex-muse-opencode-plan.md` | #40 CLOSED | `main / al8960ofc Codex / Muse OpenCode plan` |
   | `2026-08-18T2024Z-edge-dev-codex-muse-contract-gate.md` | #40 CLOSED | `main / edge-dev Codex / Muse OpenCode harness` |
   | `2026-08-20T1752Z-edge-dev-codex-grok-review-repair-plan.md` | #56 CLOSED | `edge-dev/codex/grok-review-repair-plan` |
   | `2026-08-21T1238Z-edge-dev-codex-grok-issue-56-source.md` | #56 CLOSED | `codex/grok-issue-56-source` |

   **Recommendation: have one session retire all six**, checking each file's
   obligations are carried forward before deleting it. Out of scope here.

5. **Five `HANDOFF.d/` files carry no contract block at all** (no `issue:` line),
   so nothing can ever tell whether they are finished:
   `2026-08-14T2015Z-al8960ofc-claude-housekeeping-visibility.md`,
   `2026-08-16T0303Z-al8960ofc-codex-housekeeping-plan-corrections.md`,
   `2026-08-18T1404Z-edge-dev-codex-shared-db-finish-first-plan.md`,
   `2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`,
   `2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md`,
   `2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md`.
   **Recommendation: same session as item 4 — open an issue for each or retire
   it.** Not urgent, but they are permanently un-retirable as they stand.

6. **The `#84` handoff is now partly stale and I must not edit it.**
   `HANDOFF.d/2026-08-25T2012Z-edge-dev-claude-ai-devops-gh-org-move.md` still
   says Phase A is "not started". It is done and merged (§3). Its plan document
   `fix_to_gh_org.md` **is** up to date, and that is what it tells you to read
   first, so a reader following its own instructions gets the truth. It stays
   open because Phases B–E remain. **No action needed — just do not be confused
   by it.** Editing another session's handoff is forbidden.

### Already settled — do NOT re-ask

- **The identity guards must stay fail-closed** (Albert's standing rule, and
  `fix_to_gh_org.md` §5). Widening the allow-list by a known-good entry is the
  goal; turning any check into a warning is a regression.
- **The two private sibling repos stay under `u2giants`** (Albert, 2026-08-25).
  Implemented in Phase A.
- **Symptom suppression is never a fix** (Albert's standing rule). For #89 that
  specifically means: do not raise a timeout until the check stops meaning
  anything, do not mark a test allowed-to-fail, do not delete it.

## 1. What this application is

`ai-devops` (`https://github.com/u2giants/ai-devops`, public) is Albert Hazan's
**AI operations and configuration hub** for POP Creations. It is not a customer
product. It holds the shell/PowerShell tooling in `bin/`, the machine bootstrap
and installer scripts, the shared AI reviewer wrappers (`ai-grok-review`,
`ai-muse`, `ai-deepseek-agent`, `ai-gemini`, `ai-kimi`, `ai-qwen`), the
cross-tool `templates/system/` standards, and the skills other repos' AI
sessions load. Every workstation Albert uses clones this repo and installs from
it.

Stack: Bash + PowerShell scripts. One GitHub Actions workflow, `verify.yml`,
with three jobs — `linux-offline` (`ubuntu-24.04`), `windows-offline`
(`windows-2025`), `windows-reviewer-safety` (`windows-2025`). No server, no
deployment, no database.

**The two files this handoff is about:**

- `tests/test-ai-grok-review.sh` (773 lines, 191 checks) tests
  `bin/ai-grok-review` (1494 lines) — the wrapper that drives xAI's Grok CLI.
- `tests/test-ai-kimi.sh` (731 lines, 203 checks) tests `bin/ai-kimi`
  (1999 lines) — the wrapper that drives Kimi Code CLI.

Both suites are **offline**: a stub `grok` / `kimi` on `PATH` stands in for the
real binary, so no network and no paid provider calls. `tests/test-all.sh`
auto-discovers every `tests/test-*.sh` and runs them; there is no registration
list to edit.

## 2. What we set out to do this session, and why

Albert asked to read the `#84` handoff and its plan, then: *"no, leave the
private siblings; do phase A now."*

Phase A is the code change that must land **before** `ai-devops` is transferred
to the `popcre` GitHub organization. GitHub offers merge queues only to
org-owned repositories, and `u2giants` is a personal account — that is the whole
reason for the move.

While verifying Phase A, the full offline suite reported a failure. Chasing that
became the second half of the session and produced `fix_test_ai.md` and issue
[#89](https://github.com/u2giants/ai-devops/issues/89).

**Objective for #89: diagnose, not fix.** No test or wrapper was changed.

## 3. Current state — what is true right now

### Phase A of #84 — DONE, merged, verified

- **Merged to `main` as `eeb510f`** (squash of PR
  [#88](https://github.com/u2giants/ai-devops/pull/88)). Branch
  `claude/github-org-move-handoff-d576f2` deleted from the remote.
- **All three CI jobs green** on that PR, including `windows-offline`.
- What shipped:
  - `config/repo-identities.tsv` — the single source of truth. `ai-devops`
    accepts **both** `github.com/u2giants/ai-devops` and
    `github.com/popcre/ai-devops`; `ai-devops-memory` and
    `ai-devops-transcripts` accept `u2giants` only.
  - `bin/ai-repo-identity` (Bash CLI: `list` / `canonical` / `accepts`) and
    `bin/repo-identity.ps1` (dot-sourced PowerShell:
    `Get-AiDevOpsAcceptedIdentity`, `Assert-AiDevOpsRepoIdentity`).
  - Rewired guards: `bin/bootstrap-windows-dev.ps1:55` and `:120`;
    `bin/install-ai-devops-windows.ps1:111` and `:553`;
    `bin/ai-sync-memory` `public_ai_devops_hub()`.
  - Tests: `tests/test-ai-repo-identity.sh` (29 checks),
    `tests/test-repo-identity.ps1` (12 checks).
  - Docs: a "Repository identity allow-list" section in
    `docs/config-inventory.md`; `docs/restore-from-zero.md` step 1 now says to
    clone before running the Windows bootstrap.
  - `fix_to_gh_org.md` updated: status, the sibling decision, and a "What Phase A
    actually shipped" subsection.
- **Issue #84 is still OPEN** — Phases B–E remain. A comment recording Phase A
  is on it.

### Issue #89 — diagnosed, nothing changed

- **`fix_test_ai.md` written** at the repo root — the full diagnosis, sections
  1–7.
- **Issue [#89](https://github.com/u2giants/ai-devops/issues/89) opened** with
  the evidence table, the cause, the constraints on a fix, and acceptance
  criteria.
- **This handoff written.**
- **No test file and no wrapper was modified.** `tests/test-ai-grok-review.sh`
  and `tests/test-ai-kimi.sh` are exactly as they were.

**Committed / pushed:** as of writing, `fix_test_ai.md` and this handoff are
**not yet committed**. They are the last act of this session; see §6 step 0. If
you are reading this file from `main`, they landed.

## 4. Everything we tried that did NOT work

1. **Reading the suite's exit code through a pipe — and reporting a false
   pass.** `bash tests/test-all.sh 2>&1 | tail -40` returns **`tail`'s** exit
   code, not the suite's. The suite had reported `tests=54 failures=1` in its
   summary line while the harness recorded "exit code 0", and that was reported
   to Albert as a clean pass before the summary line was actually read.
   **Do not judge this suite by exit code through a pipe.** Read the
   `OFFLINE BASH SUMMARY tests=N failures=N` line, or use
   `${PIPESTATUS[0]}`.

2. **Trying to identify the failing test from the suite log.** Every section in
   the log showed its normal pass marker and **no `FAIL` line appeared
   anywhere**, yet the summary said `failures=1`. A script scanning for
   `^  FAIL` finds nothing. The failing test had already been rerun by then and
   passed. **The suite log alone cannot tell you which test failed** — the
   runner prints the header and the test's own output, but does not name a
   non-zero test at the end.
   **Fix that worked:** run each `tests/test-*.sh` individually and record its
   exit code. That is how `test-ai-grok-review.sh` and `test-ai-kimi.sh` were
   identified.

3. **Writing scratch scripts to `$TMPDIR`.** `$TMPDIR` is empty in this
   environment, so `> "$TMPDIR/x.sh"` becomes `> /x.sh` and fails with
   `Permission denied`. Use the session scratchpad path instead.

4. **Passing multi-line Python or Markdown through a quoted Bash heredoc.**
   Backslash sequences are collapsed before Python sees them: a heredoc
   containing `C:\\repos\\ai-devops` reached Python as `C:\repos\ai-devops`, and
   Python then interpreted `\r` and `\a` as control characters, producing
   `C:eposi-devops` in `docs/restore-from-zero.md`. A separate attempt to write
   `fix_test_ai.md` via `cat > file <<'MD'` died with
   `unexpected EOF while looking for matching quote`.
   **Fixes that worked:** build backslashes with `chr(92)` inside Python, or use
   the `Write` tool for prose files. Verify the result by reading it back.

5. **Assuming the local failure was caused by the Phase A change.** It was not —
   neither suite touches any file Phase A modified. Checking that first would
   have been faster than reasoning about it.

## 5. Root causes and key findings

**Finding 1 — the failures are non-determinism, proven by arithmetic, not by
opinion.** Four runs of the same tree gave: `passed 188, failed 3` /
`passed 202, failed 1` (per-test scan), then `passed 191, failed 0` /
`passed 203, failed 0` (rerun), then `passed 191, failed 0` (repeat). The
**total check count is constant** — 191 Grok, 203 Kimi. So four checks flipped
`ok` → `FAIL` → `ok` with no input change.

**Finding 2 — the full suite and the per-test scan disagreed with each other.**
The full suite reported one failure overall; the per-test scan found four
failures across two files. Two runs of the same commit, two different answers.
That disagreement is itself evidence, and it is why the first log was a dead
end.

**Finding 3 — the cause is wall-clock assertions on budgets a loaded machine
cannot meet.** Three distinct shapes, all detailed with line numbers in
`fix_test_ai.md` §3:

- Sub-5-second timeout ceilings: `AI_GROK_WAIT_TIMEOUT=3` at
  `tests/test-ai-grok-review.sh:249` and `:262`; `AI_KIMI_WAIT_TIMEOUT=2` at
  seven sites in `tests/test-ai-kimi.sh`. Production default for both wrappers
  is **900 seconds** (`bin/ai-grok-review:90`, `bin/ai-kimi:82`) — a 300–450×
  compression.
- A fixed `sleep` used as synchronisation:
  `tests/test-ai-grok-review.sh:236-241` sleeps 5s then demands ≥ 2 heartbeats
  at 2-second intervals (`AI_GROK_HEARTBEAT_INTERVAL=2`, set at `:196`) — a 5s
  budget for something needing 4s minimum. `tests/test-ai-kimi.sh:187-188`
  sleeps 1s before cancelling, then asserts the cancel was *worker-confirmed*.
- Bounded polls that fail silently when the ceiling is hit:
  `tests/test-ai-grok-review.sh:219-220` polls 30s for three concurrent locks.

**Finding 4 — CI cannot catch this, and its greenness is being misread.** All
three jobs pass on the same commit, including `windows-offline`, which runs the
same Bash suite on Windows. That proves an idle single-purpose runner wins every
race. The races remain in the tests. It also means a genuine regression that
makes a wrapper *faster* — returning early, exactly what
`await_blocks_until_terminal_json` guards — could pass spuriously.

**Finding 5 — `edge-dev` is a contended machine and the CI runners are not.**
Multiple concurrent AI sessions and seven registered git worktrees at the time
of these runs. That is the entire difference between green in CI and red
locally.

**Finding 6 (Phase A) — there was a SEVENTH identity site the plan did not
list, and it was the dangerous one.** `bin/ai-sync-memory`'s
`public_ai_devops_hub()` refuses to use the public `ai-devops` repo as a private
memory hub. Its owner check is **inverted**. Hard-coding `u2giants` there would
have silently **permitted** publishing private memory into a `popcre`-owned
clone after the transfer. It now reads the same allow-list, so every accepted
`ai-devops` identity is rejected as a hub.

**Finding 7 (Phase A) — the sibling guards were deliberately left as literals.**
`bin/ai-facts:20`, `bin/ai-devops:109`, `bin/ai-memory-sync:29,:51` and
`bin/ai-transcript-destination-check:18` still compare literals. Their values do
not change in this move, and `ai-facts` and `ai-transcript-destination-check`
are installed as **symlinks into the repo** by `bin/install-machine-tools.sh` on
Ubuntu, where `dirname "${BASH_SOURCE[0]}"/..` resolves to `/usr/local`, not the
repo — so adding a runtime table lookup there is avoidable risk. Drift is
prevented instead by a check in `tests/test-ai-repo-identity.sh` that fails if
any `github.com/*/ai-devops*` literal in `bin/` is missing from the table. That
guard was proven by injecting a fake literal and watching it go red.

## 6. Exact next steps

0. **Commit and push `fix_test_ai.md` and this handoff.** They are the only
   uncommitted work. Stage **only those two files** — `C:\repos\ai-devops` is
   shared with other live sessions. *You'll know it worked when*
   `gh api repos/u2giants/ai-devops/contents/fix_test_ai.md --jq .name` prints
   `fix_test_ai.md`.

1. **Put §0 to Albert in one message.** *You'll know it worked when* you have a
   direction on item 1 (measured baseline vs bigger constant) and item 2 (sweep
   the other five suites or not). Neither blocks starting.

2. **Reproduce the failures deliberately, under artificial load.** Run both
   suites while the machine is busy (a parallel build, or several copies of the
   suite at once). Capture the **full** output, not a tail. *You'll know it
   worked when* you can name the four specific checks that fail — which this
   session could not, because the failing runs were captured by tail only.
   `fix_test_ai.md` §3 names the most likely candidates from code inspection;
   **verify rather than trust that attribution.**

3. **Fix the fixed sleeps first** — they are the clearest defect and the easiest
   win. `tests/test-ai-grok-review.sh:236` (`sleep 5` before the heartbeat
   assertion) and `tests/test-ai-kimi.sh:188` (`sleep 1` before cancel) become
   condition polls with a generous ceiling and a **distinct failure message when
   the ceiling is hit**. *You'll know it worked when* those two checks pass 10
   consecutive runs on a loaded machine, and the poll's ceiling message appears
   in the log when you deliberately starve the fixture.

4. **Then address the compressed timeouts** per Albert's answer to §0 item 1.
   *You'll know it worked when* no assertion depends on a hard-coded sub-5-second
   budget, and the checks still fail when the wrapper misbehaves.

5. **Prove the tests can still fail.** Deliberately reintroduce the defect each
   suite guards — for example make `await_result` return before a terminal
   record exists — and confirm the relevant check goes red. *You'll know it
   worked when* you have seen each guarded check fail on purpose. **A test that
   cannot fail is not a test, and this step is what stops a "fix" from becoming
   symptom suppression.**

6. **Verify against issue #89's acceptance criteria**: 10 consecutive local runs
   under load; the guarded defects still detected; all three CI jobs green;
   check counts unchanged or higher (191 Grok, 203 Kimi). *You'll know it worked
   when* all four hold.

7. **Retire this handoff** when #89 closes — delete this file in the same PR.

**Separately, whenever Albert says go on #84:** Phase B (prove a `windows-2025`
job runs in `popcre`, cheapest via the existing `popcre/actions-policy-probe`
repo), Phase C (the transfer), Phase D (fresh-clone **and** old-clone doctor
proof on the same commit), Phase E (enable the merge queue, sweep references).
Full detail is in `fix_to_gh_org.md` §5 and the `#84` handoff.

## 7. Constraints and gotchas in force

- **Do not weaken the assertions in these two suites.** They contain the Grok
  early-return regression test (`await_blocks_until_terminal_json`) and the Kimi
  "a run that never completes is a failure" rule. Raising a timeout until a
  check stops meaning anything, marking a test allowed-to-fail, or deleting it,
  are all symptom suppression. A fix that lowers the check count has removed
  coverage.
- **Never judge `tests/test-all.sh` by a piped exit code.** Read the
  `OFFLINE BASH SUMMARY` line. See §4.1 — this already produced one false "it
  passed" report to Albert in this session.
- **The full Bash suite takes ~50 minutes on Windows.** That is normal, not
  hung: CI budgets 45 minutes for the Linux job and 75 for the Windows one. Run
  it in the background; do not conclude it has stalled.
- **`C:\repos\ai-devops` is shared with other live AI sessions.** Work from a
  separate worktree based on `origin/main`, stage only your own files, never
  `git add -A`, never rebase local `main`.
- **Do not put an `ai-devops` worktree under the session scratchpad** — Windows
  path length breaks `git worktree add` on this repo's deep paths. Use
  `C:\repos\ai-devops-worktrees\<name>`. (Inherited from the `#84` handoff §4.1,
  where it cost a session real time.)
- **`$TMPDIR` is empty here.** Writing to `"$TMPDIR/file"` targets `/file` and
  fails. Use the session scratchpad.
- **Bash heredocs collapse backslashes** before the receiving interpreter sees
  them. For prose files use the `Write` tool; for Python use `chr(92)`. Read the
  result back.
- **PowerShell files in this repo are CRLF and must be pure ASCII.** New `.ps1`
  files must match, or the Windows suites behave inconsistently.
- **Do not add `Set-StrictMode` to a dot-sourced PowerShell helper.** It applies
  to the host script's scope; `bin/repo-identity.ps1` deliberately omits it, with
  a comment saying why, because `bootstrap-windows-dev.ps1` and
  `install-ai-devops-windows.ps1` were not written under strict mode.
- **New Bash files in `bin/` and `tests/` need the executable bit set in git.**
  `git add` on Windows records `100644`; siblings are `100755`. Fix with
  `git update-index --chmod=+x <path>` or Ubuntu CI will fail to execute them.
- **Committer identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.**
  Verify with `git var GIT_COMMITTER_IDENT` before the first commit in a repo.
- **Albert does not merge — the session that opens a PR merges it.** Do not end
  a report asking him to click Merge.
- **`gh pr merge` from a linked worktree prints `'main' is already used by
  worktree`.** That is local branch cleanup failing **after** a successful merge.
  It happened on PR #88. Confirm with `gh pr view <n> --json state` (it said
  `MERGED`), delete the remote branch manually, and continue.
- **Never rewrite the root `HANDOFF.md`** — line 1 carries `handoff-pointer: v1`.
  Never edit or delete another session's `HANDOFF.d/` file except under the
  retirement rule.

## 8. Access and environment

- **`gh` CLI:** authenticated as `u2giants`, token in the OS keyring. Scopes:
  `admin:public_key`, `gist`, `read:org`, `repo`, `workflow`. `admin:org` is
  absent and is **not** needed for any of this work; a refresh attempt in an
  earlier session did not take, so do not chase it.
- **Machine:** `edge-dev` (Windows 11 Pro). Both PowerShell 7 (`pwsh`) and Git
  Bash available; this session used Git Bash for the suites and `pwsh` for the
  PowerShell tests.
- **Repo checkouts:** canonical clone `C:\repos\ai-devops` (shared with other
  sessions). This session worked in the linked worktree
  `C:\repos\ai-devops\.claude\worktrees\github-org-move-handoff-d576f2`, based on
  `origin/main`, currently at `eeb510f`.
- **Running the suites:**
  - Everything: `bash tests/test-all.sh` (~50 min on Windows) or
    `pwsh -File tests/test-all.ps1` (Bash suite + every `test-*.ps1`).
  - Just the two: `bash tests/test-ai-grok-review.sh`,
    `bash tests/test-ai-kimi.sh`.
  - Both suites are **offline and free** — stubs replace the real CLIs. The live
    Grok probe runs only with `AI_GROK_LIVE=1`; do not set it casually, it costs
    money.
- **Secrets:** none are needed for this work. `ai-devops` has **no** GitHub
  Actions secrets, variables or environments at all. Anything else lives in
  1Password vault **`vibe_coding`** — reference by item, never by value.
- **Scratch artifacts from this session** (not committed, do not depend on them
  surviving): per-test exit-code scan and repeat-run output under this session's
  scratchpad directory on `edge-dev`.

## 9. Open questions and risks

- **RISK — the attribution in `fix_test_ai.md` §3 is inferred, not observed.**
  The counts of failing checks are measured (3 Grok, 1 Kimi); the *names* are
  from code inspection because the failing runs were captured by tail only. A
  session fixing this must reproduce under load and confirm, or it may "fix" the
  wrong checks and declare victory.
- **RISK — a fix could quietly become symptom suppression.** The tempting change
  is to raise every timeout until nothing fails. That would make the suites
  permanently green and permanently worthless. §6 step 5 exists to catch this:
  prove each guarded check can still fail on purpose.
- **RISK — CI greenness will be used as evidence the suites are fine.** It is
  not (Finding 4). Anyone closing #89 on the strength of green CI has not fixed
  anything.
- **UNCERTAIN — whether the other five reviewer suites share the pattern.** Not
  examined. §0 item 2.
- **UNCERTAIN — whether `edge-dev` has an unrelated resource problem.** The
  contention explanation fits every observation but was never measured. §0
  item 3.
- **DECIDED 2026-08-25 (Albert) — the two private sibling repos stay under
  `u2giants`.** Implemented in Phase A. Do not re-ask.
- **DECIDED 2026-08-25 — the destination org is `popcre` and repos stay
  public.** Do not revisit.
- **DECIDED 2026-08-26 — the sibling identity guards keep their literals**, with
  a drift test instead of a runtime lookup (Finding 7). Reversing that means
  solving the Ubuntu symlink path-resolution problem first.

---

## Self-audit (required by the handoff standard)

1. **Could a street-newcomer continue without asking a question?** Yes. §1
   explains what the repo is and what the two suites cover with zero assumed
   knowledge; §2 gives the trigger; §5 names every finding with `file:line`; §6
   gives eight numbered steps each with a verification gate; §8 gives the exact
   commands to run the suites, their runtime, and that they are free.
2. **As effectively as this session can right now?** Yes. The four things that
   cost this session real time — the piped exit code that produced a false pass,
   the unusable suite log, the empty `$TMPDIR`, and heredoc backslash collapse —
   are all in §4 with the fix that worked, so they cost the next session nothing.
   The 50-minute runtime is in §7 so nobody concludes the suite is hung.
3. **Is every relevant detail present?** Yes: background (§1–2), current state
   with merge SHA and branch (§3), failures (§4), findings with `file:line`
   (§5), next steps with gates (§6), constraints (§7), access (§8), risks (§9).
4. **Would Albert see every decision he owns by reading only §0?** Checked by
   walking §1–§9 line by line. The timeout-method choice (§6 step 4 → §0.1), the
   other-five-suites scope question (§9 → §0.2), the unmeasured `edge-dev`
   resource question (§9 → §0.3), the six stale handoff files and five with no
   contract block (both found during this session's sweep, neither raised
   anywhere else → §0.4 and §0.5), and the now-stale `#84` handoff (§3 → §0.6)
   all appear in §0. Items 3, 4 and 5 are outside this workstream and are in §0
   precisely because nobody else is raising them.
