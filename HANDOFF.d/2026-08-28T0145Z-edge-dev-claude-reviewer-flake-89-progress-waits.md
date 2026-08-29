---
issue: 89
status: OPEN
owner: claude/reviewer-flake-89-progress-waits
---

# HANDOFF — reviewer flake #89: the fix is written, the proof is not (2026-08-28T0145Z, edge-dev/claude)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in ONE message before starting work. Do not raise
them one at a time.

**BLOCKING — nothing.** Every next step in §6 can be executed without a ruling.

**RECOVERABLE (a wrong guess costs rework, not damage):**

1. **Should the ten-run series run on the self-hosted runner, or locally on a
   quiet machine?** The runner gives a result that matches what CI actually
   measures; locally is faster but is not the environment the required check runs
   in. *Recommendation: on the runner, via `workflow_dispatch`, one run at a
   time.* Albert previously directed running the series locally and concurrently;
   that attempt failed for machine reasons documented in §4, not because the
   instruction was wrong — so this is worth re-confirming rather than assuming.
2. **How long may one runner be the only Windows CI capacity?** While it is, the
   Windows checks stop whenever that machine is off or logged out, and the two
   Windows jobs no longer run in parallel. *Recommendation: keep it until #89
   closes, then decide whether to go back to GitHub-hosted runners.*

**NOT PART OF THIS WORK, AND NOBODY IS ON IT:**

3. **The repository root holds 38 `plan_*.md` files.** Many describe work that
   looks finished. Nobody owns deciding which are retired, and each one is a
   standing context cost for every future session. *Recommendation: one session
   audits them against their STATUS tables and deletes the done ones.*
4. **`HANDOFF.d/` holds 26 files, the oldest from 2026-08-14.** Files are meant to
   be deleted once their work is proven done. This session did not audit them
   (see §9 for why). *Recommendation: a housekeeping session checks each file's
   `issue:` against GitHub and deletes those whose issue is closed.*

**Already settled — do NOT re-ask:**

- **Decision B (no weakening), reaffirmed 2026-08-28.** Never raise a multiplier
  or timeout, add retries, quarantine a check, or mark it allowed-to-fail to make
  a lane green. The fix on this branch honours it.
- **Albert does not merge.** The session that opens a pull request merges it.
- **Windows CI moved to a self-hosted runner**, directed by Albert 2026-08-27
  after two days of GitHub-hosted runs produced no usable evidence.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public backup-and-restore toolkit for a
multi-model AI coding workflow. It holds Bash and PowerShell commands, skills and
global instruction files for Claude and Codex, machine setup scripts, wrappers
that delegate code review to other AI models (Grok, GLM, Kimi, Qwen, DeepSeek,
Gemini, Muse), documentation, and offline test suites.

It is a toolkit, not a hosted service: there is no application database and no
production deployment. "Deploying" means installing from a checkout. `main` is
protected by GitHub ruleset `21564317`, which requires a pull request, the merge
queue, and the `linux-offline` and `windows-offline` checks.

## 2. What we set out to do this session, and why

Albert asked for `plan_ai-devops-work-claims.md` to be implemented — a system so
one AI session can see that another already owns a task, instead of two sessions
spending hours on the same work.

That plan forbids starting its own step 2 until `plan_repo-throughput-restructure.md`
closes its reviewer-determinism gate. That gate reduces to exactly one defect,
tracked as issue [#89](https://github.com/popcre/ai-devops/issues/89): the
reviewer test suite fails intermittently on Windows, which makes the required
`windows-offline` check a coin flip and every merge unreliable.

So the real work of this session was #89, not work claims. The work-claims plan
was never started and is still correctly blocked.

## 3. Current state — what is true right now

**Branch:** `claude/reviewer-flake-89-progress-waits`, pushed.
**Pull request:** [#142](https://github.com/popcre/ai-devops/pull/142) — open,
**NOT merged**. Its checks had not settled when this session ended.

**Done and verified:**

- **The defect is fixed in code** (`fe7c0606`). `ai_test_measure_baseline` runs
  once near the top of a roughly 13-minute suite, and every later ceiling derived
  from that one frozen number via `budget FACTOR FLOOR`, so a machine that slowed
  down afterwards was judged against a computer that no longer existed. Three
  drift-exposed waits in `tests/test-ai-grok-review.sh` (near lines 374, 731 and
  745) now use `poll_until_progress`, which fails only when nothing observable has
  changed for a stall window. The wait near line 731 is the one that actually
  failed in the recorded series.
- **New helpers** `ai_test_fingerprint` and `poll_until_progress` were appended to
  `tests/lib-test-timing.sh`. No existing helper was modified.
- **Unit proof:** `tests/test-lib-test-timing.sh` (new, executable) — 10 checks,
  10 passed. It proves a slow-but-advancing fixture is NOT failed, a stalled one
  IS failed with a message naming the stall, and the old `poll_until` still fails
  at its own deadline. Re-run it with:

  ```bash
  bash tests/test-lib-test-timing.sh
  ```

- **Three waits were deliberately left as `poll_until`** (near lines 281, 288 and
  314). They run seconds after the baseline is measured and are not exposed to
  drift, so converting them would be churn. Do not "finish the job" by changing
  them — see §9.
- **Windows CI moved to a self-hosted runner** (`2f0c081f`). Both Windows jobs in
  `.github/workflows/verify.yml` now use
  `runs-on: [self-hosted, Windows, X64, edge-dev]`. `linux-offline` still uses
  GitHub's `ubuntu-24.04`. Documented in `docs/self-hosted-windows-runner.md`.
  The required check names did not change, so ruleset `21564317` needed no edit
  and moving back would need none either.
- **The security hole that a self-hosted runner opens was closed first.** This is
  a public repository, so a fork's pull request could otherwise execute code on
  the machine. Fork-PR approval is set to `all_external_contributors`, verified:

  ```bash
  gh api repos/popcre/ai-devops/actions/permissions/fork-pr-contributor-approval
  ```

- **Documentation committed** (`cf2da5d1`): the runner document, the
  abandoned-series evidence file, both plan STATUS tables, and `fix_test_ai.md`.

**NOT done — this is the whole remaining job:**

- **The flake rate is unmeasured.** No clean ten-run series exists. Step 1.2 of
  `plan_repo-throughput-restructure.md` is correctly still marked **not
  satisfied**. Nothing on this branch may be described as "#89 fixed": the
  mechanism is proven, the outcome is not.
- **PR #142 is not merged.**
- **`plan_ai-devops-work-claims.md` steps 2–6 have not been started.**

## 4. Everything we tried that did NOT work

**(a) Ten-run series, attempt 1 — self-contaminated.** A second batch of runs was
launched while the first was still going. Stopping the batch stopped only the
wrapper, not the suite it had spawned: two `test-ai-grok-review.sh` process trees
were later observed running at once. Every number from it measures contention
this session created. Discarded. `fix_test_ai.md` §8 names this exact mistake —
*do not create your own storm and then certify against it* — and it was made
anyway.

**(b) Ten-run series, attempt 2 — killed by its own cleanup.** Albert directed a
deliberately concurrent attempt: ten runs, eight at a time, reasoning that a
20-thread machine sitting under 35% has the headroom. Eight suites did start and
were confirmed running side by side. Two things then went wrong, **both
properties of the machine, not of the fix**:

- The self-hosted runner shares that machine. With eight suites resident, the
  runner's heartbeat to GitHub stopped arriving and the API reported
  `status=offline` while `busy=true`. `Runner.Listener` and `Runner.Worker` were
  alive throughout. **Do not re-register a runner on that evidence.**
- The cleanup matched on the suite's process name — and the CI job running on the
  same machine was executing a suite *with that same name*. Job `98712820009`
  (`windows-reviewer-safety`) shows `cancelled` at its test step as a direct
  result. **That is not a test failure and must never be cited as one.**

**(c) Polling the Actions API for check results — tripped a rate limit.** Two
monitors polling `gh pr checks` every 30 seconds caused every Actions call to
return `403 rate limit exceeded` while `gh api rate_limit` still reported
`remaining=5000/5000`. That is GitHub's *secondary* limit; the `rate_limit`
endpoint reports only the primary quota, so a full reading there is not evidence
the quota is healthy. Poll at 5-minute intervals and never run two watchers.

**(d) Waiting for GitHub-hosted Windows runners — two days, no usable result.**
Jobs took 65–75 minutes on a different machine at a different load every time, so
a failure could not be reproduced and a pass could not be trusted. This is what
caused the move to a self-hosted runner.

**(e) Exact-match Python patching of repository files — failed twice.** Several
files use CRLF terminators, so a heredoc pattern written with `\n` will not match
and the patch raises `AssertionError`. Read the file as bytes, detect `\r\n`,
normalise, patch, then restore the original terminators. Related: `python` and
`python3` on this machine resolve to Windows Store stubs — use `py`.

**(f) A large quoted heredoc through the Bash tool — parse error.** Writing this
handoff with `cat > file <<'EOF'` failed with `unexpected EOF while looking for
matching quote`. Use the Write tool for long Markdown instead of fighting it.

## 5. Root causes and key findings

- **The #89 root cause, confirmed rather than suspected:** one frozen baseline at
  the top of a long suite, with every later ceiling derived from it. A ceiling
  large enough to survive a degraded machine no longer detects a genuine hang,
  which is what these checks exist for — that is why raising the multiplier is
  forbidden and why the fix had to change the *shape* of the wait, not its size.
- **The general lesson, worth more than the fix itself:** distinguish "slow" from
  "stuck" by watching for observable progress, not by picking a bigger number.
- **This machine hosts either the CI checks or a local test series, never both.**
  They share process names and compete for the same cores, so a local series can
  cancel a live CI job and a running check can inflate a series.
- **Three GitHub signals lied at once** during (b): `offline` for a healthy
  runner, `fail` for a job killed from outside, and `5000/5000` during a
  rate-limit block. Each was a misleading report about a healthy component, which
  is why the diagnosis was slow. Full narrative in `docs/critical-incidents.md`,
  2026-08-28 entry.
- **A superseded workflow run is not cancelled automatically.** Pushing a new
  commit starts a new run, but the old one keeps holding the single runner until
  cancelled explicitly. With one runner that is a self-inflicted queue — this
  session hit it and had to cancel run `33128680751` by hand.

## 6. Exact next steps

1. **Confirm the machine is quiet before anything else.**

   ```bash
   gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|"\(.name) busy=\(.busy)"'
   ```

   *You will know it worked when:* `busy=false`, and no `test-ai-grok-review`
   process is running on the machine.

2. **Check PR #142 and merge it if green.** The session that opened it owns the
   merge — do not ask Albert to do it.

   ```bash
   gh pr checks 142
   ```

   *You will know it worked when:* all three checks pass and
   `gh pr merge 142 --squash` reports a merge commit. A `cancelled` result means
   something killed the job from outside — re-run it, do not record it as a
   failure. If `gh pr merge` prints `'main' is already used by worktree`, the
   merge already succeeded; confirm with `gh pr view 142 --json state` and
   continue.

3. **Run the ten-run series, one run at a time, on an idle machine.** Ten
   consecutive green runs are required. Record every run's duration and result,
   including failures.

   *You will know it worked when:* ten consecutive passes exist, written to a new
   file under `tests/verification/reviewer-flake-89/`. **A single failure resets
   the count** — record it and diagnose it. Never re-run until the numbers look
   good; that is how the earlier evidence became worthless.

4. **Close throughput step 1.2** in `plan_repo-throughput-restructure.md`, citing
   that evidence file, and close issue #89.

   *You will know it worked when:* the STATUS row reads ✅ with an artifact path —
   a commit SHA, a CI run id, or a file under `tests/verification/` — never a bare
   number or a pull-request number.

5. **Delete this handoff file**, but only after steps 2–4 have all passed.

6. **Return to `plan_ai-devops-work-claims.md` step 2**, which is the work Albert
   originally asked for. Read its STATUS table first; do not re-derive or re-plan
   it.

## 7. Constraints and gotchas in force

- **Decision B:** never weaken, quarantine, raise a multiplier or timeout, add
  retries, or mark a check allowed-to-fail to make a lane green.
- **No admin bypass for code.** Code changes go branch → pull request → merge
  queue. A documentation-only pull request may merge immediately with
  `gh pr merge --squash --admin` — check the changed-file list first; if even one
  file is code, a test, a script, a workflow, or configuration, normal checks
  apply.
- **Never use bare `git stash` / `git stash pop`** — the stash stack is shared
  across worktrees and another session may pop your entry.
- Several repository files are CRLF; patch them as bytes (see §4e). Use `py`, not
  `python` or `python3`.
- `C:\actions-runner` is a protected path — `Remove-Item` against it is blocked.
- Scope process cleanup to your own process tree, never a bare name match against
  every matching process on the machine.

## 8. Access and environment

- **Machine:** `edge-dev`, Windows 11, Intel Core i7-12700 (20 threads).
- **Worktree:** `C:\repos\ai-devops\.claude\worktrees\claude-response-verbosity-8c37ab`.
  Run everything from there; do not `cd` to the main checkout.
- **`gh` CLI:** authenticated as `u2giants`. The git identity must read
  `Albert Hazan <u2giants@users.noreply.github.com>` — check with
  `git var GIT_COMMITTER_IDENT` before the first commit.
- **The runner** is a scheduled task, `GitHubActionsRunner-aidevops`, not a
  Windows service: installing a service needs an elevated shell, which this
  session did not have. It starts at logon and restarts if it exits.
  **Windows CI therefore runs only while that machine is on and that user is
  logged in.** A queued job simply waits. Restart it with:

  ```powershell
  Start-ScheduledTask -TaskName 'GitHubActionsRunner-aidevops'
  ```

- **Secrets** live in 1Password vault `vibe_coding`. Never put a value in chat, a
  command argument, output, a log, or a commit. No secret is needed for this work.
- **Machine topology** belongs in the private `u2giants/ai-devops-private-config`
  atlas. `templates/system/machine-atlas.md` in this repository is a public
  placeholder that explicitly forbids concrete topology — do not write to it.

## 9. Open questions and risks

- **Risk: someone reads this branch as "#89 fixed" and closes the issue.** The
  mechanism is proven; the flake rate is not measured. This is guarded in three
  places — both plan STATUS tables, `fix_test_ai.md`, and the `AGENTS.md` router
  row — but a session that skips them could still get it wrong.
- **Risk: the ten-run series fails.** If it does, the frozen baseline was not the
  only cause. Diagnose the new failure on its own terms; do not raise a ceiling to
  make it pass.
- **Risk: single point of failure.** One runner means no Windows CI while that
  machine is off, and the two Windows jobs no longer run in parallel, so a full
  pass takes longer in wall clock than it did on two hosted runners. That cost was
  accepted deliberately in exchange for comparable results.
- **Not audited by this session:** the 26 files in `HANDOFF.d/` and the 38 root
  plan files. Both are raised as owner asks in §0. Nothing was deleted, because
  retiring another session's file requires proving its work landed, and this
  session did not do that work.
- **Decision, 2026-08-28:** the three near-baseline waits stay as `poll_until`.
  They are not exposed to drift, so converting them would be unjustified churn. A
  later session should not "complete" the conversion without a reason.

## Self-audit (mandatory gate)

1. *Could a developer who walked in off the street continue without asking a
   single question?* Yes. §1 explains the product with no assumed knowledge, §3
   names the branch, pull request and commit SHAs with what each contains, §6
   gives executable commands each with a verification gate, and §8 gives the
   machine, worktree path and authentication state.
2. *Could they continue as effectively as this session could?* Yes. The three
   misleading GitHub signals (§5) and the CRLF, `py`, and heredoc traps (§4e, §4f)
   are the findings that cost this session the most time, and each is written down
   with its remedy.
3. *Are the failures included, not just the final plan?* Yes — §4 carries six dead
   ends, including two the session caused itself, each with why it seemed
   reasonable and how it failed.
4. *Is every next step executable without a judgment call, with a way to verify?*
   Yes — §6, six numbered steps, each with a "you will know it worked when" line
   and the commands to run.
5. *Is every term, path, identifier and URL a newcomer would not know explained?*
   Yes — issue #89, PR #142, ruleset `21564317`, job `98712820009`, run
   `33128680751`, the worktree path, and the scheduled-task name are all written
   out rather than referenced obliquely.
6. *Was the §0 sweep run?* Yes. §1–§9 were walked line by line: the runner-lifetime
   question came from §9, the series-location question from §6, and the handoff and
   plan backlogs from §9's "not audited" note — all promoted into §0 as owner asks,
   each with a recommendation so most can be answered in one word.

**Gaps found and closed during the audit:** the first draft named commit SHAs
without saying what each one contained (fixed in §3); it did not say which waits
were deliberately left alone, which invited a later session to "finish" them
(added to §3 and §9); and it did not warn that a `cancelled` check is not a test
failure, which is the single most likely way the next session misreads PR #142
(added to §6 step 2).
