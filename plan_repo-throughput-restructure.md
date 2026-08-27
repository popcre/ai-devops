# Implementation plan — restructure `ai-devops` so parallel sessions can ship

**Repository:** `popcre/ai-devops` (public; the `u2giants/ai-devops` remote name
also remains valid on purpose — see § 11)
**Branch this plan was authored on:** `claude/test-infrastructure-redesign-74eb99`
**Authored:** 2026-08-27 by Claude (Opus 5) on machine `edge-dev`
**Base commit:** `789d92299110d804e1e246750d7c2ce021695ffd`
**Handoff:** [`HANDOFF.d/2026-08-27T1630Z-edge-dev-claude-repo-throughput-restructure.md`](HANDOFF.d/2026-08-27T1630Z-edge-dev-claude-repo-throughput-restructure.md)
**Adversarial review:** Grok 4.6 REJECTED the first draft of this work on
2026-08-27. Its findings are incorporated throughout and recorded in § 7.

---

## STATUS — read this first

A fresh session starts at **Phase 0, step 1**. Nothing below is done.

| # | Step | State | Evidence |
|---|------|-------|----------|
| 0.1 | Freeze the growth rule in `AGENTS.md` | ⬜ open | — |
| 0.2 | Turn on branch protection naming one required check | ⬜ open | — |
| 1.1 | Replace polling with event waits in `tests/test-ai-grok-review.sh` | ⬜ open | — |
| 1.2 | Prove the fix: 10 consecutive green runs on Windows CI | ⬜ open | — |
| 2.1 | Build `tests/lib/harness.sh` | ⬜ open | — |
| 2.2 | Migrate all suites to it, one commit per suite | ⬜ open | — |
| 2.3 | Machine-readable suite results (TAP-style) | ⬜ open | — |
| 3.1 | Tag every suite with the paths it covers | ⬜ open | — |
| 3.2 | Change-scoped selection in `tests/test-all.sh` | ⬜ open | — |
| 3.3 | Rebuild `.github/workflows/verify.yml` around it | ⬜ open | — |
| 3.4 | Stop re-running the Linux-only suites on Windows | ⬜ open | — |
| 4.1 | Extract `bin/lib/ai-common.sh` | ⬜ open | — |
| 4.2 | Move the four wrappers onto it, one at a time | ⬜ open | — |
| 4.3 | One lock implementation, tested once | ⬜ open | — |
| 5.1 | Close or merge the 34 open plan files | ⬜ open | — |
| 5.2 | Collapse the eight per-provider repair plans into one | ⬜ open | — |

**Rule for whoever executes this:** update this table in the same commit as the
work, and cite an artifact — a commit SHA, a CI run id, or a file under
`tests/verification/` — never a bare number or a PR number.

---

## 1. The ultimate goal — what we are actually trying to achieve

**In plain business English:** Albert runs many AI sessions against this
repository at once. Today they mostly do not finish. Two sessions ran for a full
day on 2026-08-27 and produced nothing — one re-ran the same hour-long test suite
over and over, the other checked on a job every ten minutes all day. The work
they were sent to do never landed.

When this plan is done, **a session that is given a task can finish it the same
sitting.** Concretely that means three things become true that are not true today:

1. **A change can be verified in minutes, not an hour** — and only the parts of
   the system the change actually touches get verified.
2. **A red result means something is broken.** Today it means "maybe." That
   ambiguity is what turns a ten-minute decision into a six-hour loop, because a
   session that cannot tell a real failure from noise has no choice but to keep
   re-running.
3. **Adding the next AI provider costs one small file, not fifteen hundred lines
   of copied infrastructure.** Today every provider brings its own copy of the
   same locking, session bookkeeping, and safety code, and every copy drifts.

The measurable outcome: **the number of open pull requests that are stalled goes
to zero, and stays there,** because finishing stops being expensive.

> **If a step in this plan conflicts with that goal, the goal wins — stop and
> flag it.** In particular: if a step would make verification slower, make a red
> result less trustworthy, or add another copy of something that already exists,
> it is wrong even if it is written here. Say so rather than building it.

### The non-goal, stated because it is the tempting mistake

This is **not** a plan to make the test suite pass. Making red go away by
excusing tests is explicitly forbidden (§ 7, rejected approach A). The goal is
to make red *mean something*, which sometimes means more red, sooner.

---

## 2. What this application is

`ai-devops` is Albert Hazan's operations repository for POP Creations. It is not
a customer-facing product. It is the toolbox that every AI session on every one
of Albert's machines uses.

- **Owner identity:** GitHub `popcre` organisation. Albert's personal identity is
  `u2giants`. Both remotes remain valid deliberately; see § 11.
- **Default branch:** `main`. Ordinary work goes directly to `main` (this repo is
  not DesignFlow).
- **Stack:** POSIX shell (`bash`) and PowerShell. No compiled code, no server, no
  deployment. `bin/` holds ~19,800 lines of shell across 70 executables.
- **Where it runs:** developer machines directly — `edge-dev` (Windows 11, the
  machine this plan was written on), `al8960ofc`, `albt16`, `916`, and the Hetzner
  box `hetz` (Ubuntu). There is no hosted environment and nothing to deploy.
- **What it contains:**
  - `bin/` — the `ai-*` command-line wrappers that drive external AI providers
    (Grok, GLM, Kimi, Qwen, Gemini, Muse, DeepSeek, Codex, Claude) under strict
    cost and permission controls.
  - `skills/` — the instruction packs Claude and Codex load per task.
  - `tests/` — 53 Bash suites and 16 PowerShell suites.
  - `docs/`, `templates/`, `HANDOFF.d/`, and 34 `plan_*.md` files.
  - `.github/workflows/verify.yml` — the only CI workflow.
- **Who uses it:** AI sessions, and Albert. Nobody else.

**Why the wrappers are elaborate:** they spend real money. On 2026-08-05 a
hand-composed Grok delegation burned ~1.9M tokens and roughly $8.28 across five
sessions, two of which returned nothing. Every lock, permission flag, and turn
bound in `bin/ai-grok-review` exists because getting it wrong cost cash. Treat
that code as safety-critical, not as boilerplate.

---

## 3. What triggered this work

On 2026-08-27 Albert reported, verbatim:

> "look at 'Flaky reviewer & #89 tests timing issues' session. it has been
> running for 24 hours performing the same test (6hrs each time) over and over
> again and making no progress. look at 'Dotfiles sync' session, it's running the
> same tests over and over and over again with no progress. Take a step back,
> take a broader look at how this whole repo is structured. we have to rework how
> it works, this is not sustainable. nothing is getting done"

Both sessions were read directly from the local session store. What they were
doing:

- **"Flaky reviewer & #89 tests timing issues"** (session
  `local_14c80f71-1a31-4abc-9135-02978d80f87e`, PR
  [#123](https://github.com/popcre/ai-devops/pull/123)) had established that the
  `windows-reviewer-safety` CI job fails on `main` itself — with no change
  applied — in **2 of the last 6 runs**. It could not tell whether its own PR was
  red for the same reason, because **GitHub locks a workflow run's logs until
  every job in that run finishes**, and a sibling 40-minute job was still going.
  So it stress-tested locally while waiting. For six hours. Then repeated.
- **"Dotfiles sync"** (session `local_dd19f75c-2439-49dd-a2ed-4cecfe5b6464`, PR
  [#121](https://github.com/popcre/ai-devops/pull/121), since merged) was polling
  CI with ten-minute shell commands, each of which timed out and consumed a turn.
  Albert intervened mid-session with "this is clearly not working. we need
  another path."

**There is no reproduction script.** The failure is structural and shows up as
session behaviour, not as a program crash. The closest thing to a reproduction is:
run `bash tests/test-all.sh` on Windows and time it, then read the CI history of
`windows-reviewer-safety` on `main`.

---

## 4. Scope

### In scope

- The shape of `tests/` — how suites are selected, run, reported, and shared.
- `.github/workflows/verify.yml` in full.
- Branch protection settings on `popcre/ai-devops`.
- Extracting the duplicated infrastructure out of `bin/ai-glm`, `bin/ai-kimi`,
  `bin/ai-qwen`, and `bin/ai-grok-review` into one shared library.
- Fixing the four (really nine — see § 6.4) racing checks in
  `tests/test-ai-grok-review.sh`.
- Consolidating the 34 `plan_*.md` files and the growth rule in `AGENTS.md`.

### Explicitly NOT in scope

- **Rewriting the AI provider wrappers' behaviour.** Extracting shared code must
  be behaviour-preserving. Do not "improve" a wrapper while moving it.
- **Changing what any test asserts.** Tests may be made faster and more reliable.
  What they prove must not shrink. See § 11, the standing rule.
- **Reducing the 243 Markdown files** beyond the plan-file consolidation in
  Phase 5. Documentation mass is a real problem, but it is a separate piece of
  work and mixing it in here will make this plan unreviewable.
- **Touching `skills/`**, except where a skill names a plan file that Phase 5
  closes.
- **Any change to the shared database, DesignFlow, or any other repository.**
- **Adding a new AI provider.** The point of Phase 4 is that adding the next one
  becomes cheap; actually adding one is separate work.
- **Sharding the test suite across many CI runners.** This was the original
  proposal and it was rejected. See § 7, rejected approach B.

---

## 5. Current state of the code

Everything below is the state at base commit `789d922`. **Nothing in this plan
has been implemented.** A previous draft was written into the working tree of the
authoring session and then abandoned after review; if you find uncommitted edits
to `verify.yml`, `test-all.sh`, `test-all.ps1`, `test-workflow-policy.sh`, or a
file called `tests/quarantine.txt`, **discard them** — they are the rejected
design from § 7.A/§ 7.B, not work in progress.

### 5.1 Tests

- `tests/test-all.sh` (12 lines) finds every `tests/test-*.sh`, sorts, and runs
  them one after another in a single process. 53 suites.
- `tests/test-all.ps1` (20 lines) runs **the entire Bash suite again** and then
  16 PowerShell suites, serially.
- There is **no shared test library.** `ok()`, `bad()`, `skip()`, and `check()`
  are copy-pasted into roughly 24 suites in divergent forms. Measured variants of
  `bad()` alone: `printf '  FAIL %s\n'`, `printf 'not ok %s\n'`,
  `printf 'not ok - %s\n'`, and a bare `echo "FAIL: $*"` that exits immediately.
  24 suites use the `FAIL:` colon form somewhere.
- `tests/probes/` holds live/paid probes. They are not run by `test-all.sh` and
  are out of scope.
- `tests/fixtures/` is read-only fixture data.
- Suites are well isolated from each other: 21 override `HOME`, and `mktemp -d`
  plus `trap 'rm -rf ...' EXIT` is the dominant pattern. **No suite writes to the
  real `$HOME`.** This was verified during planning and independently confirmed by
  Grok. Isolation is not the problem.

### 5.2 CI — `.github/workflows/verify.yml` as committed

Three jobs, all triggered on every pull request and every push to `main`, with no
path filtering whatsoever:

| Job | Runner | Timeout | What it runs |
|---|---|---|---|
| `linux-offline` | `ubuntu-24.04` | 45 min | `bash -n` syntax pass, then `tests/test-all.sh` |
| `windows-offline` | `windows-2025` | 75 min | `tests/test-all.ps1` — the whole Bash suite *and* the PowerShell suite |
| `windows-reviewer-safety` | `windows-2025` | 30 min | just `test-ai-codex-review.sh` and `test-ai-grok-review.sh` |

An in-file comment records that the Windows matrix **measured about 62 minutes**
after the 2026-08 reviewer expansions.

Two details that matter and are easy to miss:

- The `linux-offline` job installs `shellcheck` and **never runs it.** Dead
  dependency.
- `windows-reviewer-safety` exists precisely so a Windows-only reviewer
  regression is reported in ~30 minutes instead of ~62. `docs/development.md`
  documents this. **Do not delete this job** without something strictly faster in
  its place. The first draft of this work deleted it; that was one of Grok's
  strongest objections.

### 5.3 Branch protection

**There is none.** Verified during planning:

```
gh api repos/popcre/ai-devops/branches/main/protection
→ 404 {"message":"Branch not protected"}
```

`bugs.md` already records this. Consequence: **CI is advisory today.** Nothing
stops a red change from landing on `main`. Any plan that assumes a "required
check" is meaningful is wrong until step 0.2 is done.

### 5.4 The provider wrappers

| File | Lines | Has `lock_acquire` | Has `remote-uncertain` protection |
|---|---|---|---|
| `bin/ai-kimi` | 1999 | yes (12 lines) | **no** |
| `bin/ai-glm` | 1932 | yes (16 lines) | **no** |
| `bin/ai-qwen` | 1504 | yes (12 lines, byte-identical to Kimi's) | **no** |
| `bin/ai-grok-review` | 1494 | yes (53 lines) | yes |
| `bin/ai-review-scoreboard` | — | yes | no |
| `bin/ai-muse` | 394 | no | no |
| `bin/ai-deepseek-agent` | 600 | no | no |

Across those four large wrappers, these function names are independently
reimplemented — counts are how many of the five files sampled define each:

`usage` ×5, `need` ×5, `lock_path` ×5, `die` ×5, `write_meta` ×4, `warn` ×4,
`valid_name` ×4, `review_boundary` ×4, `repo_root` ×4, `repo_remote` ×4,
`repo_id` ×4, `release_boundary` ×4, `note` ×4, `meta_path` ×4, `lock_release` ×4,
`lock_acquire` ×4, `find_meta` ×4, `cmd_transcript` ×4, `cmd_show` ×4,
`cmd_list` ×4, `cmd_doctor` ×4, `cmd_delete` ×4, `cmd_ask` ×4,
`write_review_file` ×3, `run_turn` ×3.

There is **no `bin/lib/`, no `bin/common`, no shared sourced file at all.**

### 5.5 The backlog this produces

- **9 open pull requests.** Four are less than a day old; the rest are 3, 10, 17,
  and 19 days old. PR [#15](https://github.com/popcre/ai-devops/pull/15) is 17
  days old with 4 of 4 checks red.
- **18 open issues.**
- **34 `plan_*.md` files** at the repository root. **Eight** of them are
  per-provider reviewer repair plans: `plan_codex_reviewer_trust_repair.md`,
  `plan_deepseek_reviewer_safety_repair.md`,
  `plan_gemini_reviewer_safety_repair.md`, `plan_glm_reviewer_startup_repair.md`,
  `plan_grok_reviewer_runtime_repair.md`,
  `plan_kimi_reviewer_completion_repair.md`,
  `plan_muse_reviewer_availability_repair.md`,
  `plan_qwen_reviewer_evidence_repair.md`. They describe the same class of
  problem eight times because the code is duplicated eight ways.
- **243 tracked Markdown files out of 492 tracked files total** — half the
  repository is prose.
- Commit volume over the trailing 30 days, by top-level path: `tests/` 408,
  `bin/` 399, `skills/` 375, `docs/` 258, `HANDOFF.d/` 138. 197 commits in the
  trailing 7 days alone. **The tooling overwhelmingly works on itself.**

---

## 6. Key findings and root cause

### 6.1 The root cause, stated once

**The repository scales by duplication, and verifies by brute force.** Those two
facts multiply. Every new provider adds ~1,500 lines of copied infrastructure,
one more divergent copy of every safety mechanism, one more slow test suite, and
one more repair plan. Because there is no shared layer, a fix must be applied N
times. Because verification runs everything serially and unreliably, each of
those N applications costs an hour and produces an ambiguous answer.

A session therefore cannot close the loop. That is the whole problem.

### 6.2 Ambiguous red is the specific mechanism that burns days

This is the finding that matters most operationally. The chain:

1. Nine checks in `tests/test-ai-grok-review.sh` fail intermittently for timing
   reasons (§ 6.4).
2. `windows-reviewer-safety` therefore fails on `main` itself about **1 run in 3**
   — measured at 2 of 6 by session `local_14c80f71`.
3. A session sees red on its own PR and **cannot attribute it.**
4. Attribution requires the run's logs; **GitHub withholds a run's logs until all
   its jobs finish**, and the run contains a ~62-minute job.
5. So the session waits, or re-runs, or stress-tests locally. All three cost
   hours and none of them resolves the ambiguity.
6. Repeat.

**Fixing the races is not cosmetic. It is the step that unblocks everything
else,** because every other improvement still leaves a session unable to trust
its own result.

### 6.3 Verification cost is unrelated to change size

There is no path filtering in `verify.yml`. A one-line edit to a Markdown file
runs the same ~62-minute Windows matrix as a rewrite of `bin/ai-grok-review`.
Given that half the repo is Markdown and `docs/` saw 258 commits in 30 days, a
large share of all CI time is spent proving that prose did not break shell
scripts.

### 6.4 The racing checks — exact inventory

All in `tests/test-ai-grok-review.sh`. The shared defect is
`for _i in $(seq 1 30); do <condition> && break; sleep 1; done` — a bounded poll
that silently gives up after 30 seconds and lets the assertion run against a state
that has not settled. On a loaded CI runner, 30 seconds is not enough.

Around lines 213–220 (the first cluster):
- `same_repo_different_session_and_packet_run_concurrently`
- `same_exact_session_and_turn_is_refused`
- `same_repo_different_caller_and_work_run_concurrently`

Around lines 640–660 (the cluster CI actually reported):
- `different_named_sessions_can_ask_concurrently`
- `same_next_ask_turn_is_serialized`
- `uncertain_ask_blocks_its_exact_retry`
- `uncertain_ask_blocks_changed_prompt_for_same_next_turn`
- `uncertain_ask_does_not_block_other_named_session`

The second cluster also depends on a shared `$TMP/mode` file and on killing a
backgrounded `ask` with `TERM` at the right moment, and on `$TMP/hold-started`
appearing. Those are additional races on top of the poll.

**What these checks actually protect** — read `bin/ai-grok-review` before
touching them:
- `different_named_sessions_can_ask_concurrently` — locks are per work-item, not a
  global mutex; unrelated reviews must not serialise.
- `same_next_ask_turn_is_serialized` — `session_lock_acquire` (~line 1269) stops
  the same session's same turn running twice. A regression here **double-bills**
  and tears the session metadata.
- `uncertain_ask_blocks_its_exact_retry` — `lock_acquire` honouring the
  `remote-uncertain` marker (~lines 374–376). This is the fail-closed paid-work
  path. A regression retries a turn whose remote state is unknown — i.e. pays
  twice for work that may already have run.
- `uncertain_ask_does_not_block_other_named_session` — that uncertainty is scoped
  to the affected session and does not freeze everything else.

These are money-safety tests. That is why § 7.A rejects excusing them.

### 6.5 The duplication has already caused divergence

`lock_acquire` exists four times. Kimi's and Qwen's are byte-identical (12
lines); GLM's is a different 16; Grok's is 53 and is **the only one with the
paid-work uncertainty protection.** The three tools without it can, in principle,
retry an interrupted paid turn. Nobody has tested whether they do, because the
tests that would catch it exist only for Grok.

**Consequence for sequencing:** unifying the lock (Phase 4) is a genuine
money-safety improvement, not merely tidiness. It is deliberately placed after
the test foundation, because unifying it without one shared, trustworthy test
would be unverifiable.

### 6.6 What is *not* broken

Stated so the implementer does not go hunting:
- **Suite isolation is fine.** No shared `$HOME`, no fixed ports in use (GLM's
  `AI_GLM_PORT=59999` is a negative-listen probe, not a listening server), no
  fixture writes, no live `gh` or `git config --global` calls in the suites.
- **Git identity is correct** on this machine:
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- The concurrency scoping in `verify.yml` (`group:` keyed on event and source
  SHA, `cancel-in-progress: true`) is correct and deliberate — it keeps an
  immutable commit's proof alive when newer work lands. **Preserve it verbatim.**

---

## 7. Approaches considered and REJECTED

### 7.A — Quarantine the flaky checks so they stop blocking. REJECTED.

**What it was:** a `tests/quarantine.txt` naming individual flaky checks, plus
logic in `tests/test-all.sh` that parsed each suite's stdout, and — if a suite
failed but every failing check name appeared in that list — reported the suite as
`QUARANTINED` and let the lane stay green. An advisory CI job would re-run the
quarantined suites three times and publish a hit rate.

**Why it was attractive:** it required editing zero test files, which avoided
merge conflicts with the live PR #123, and it would have stopped the six-hour
loops the same day.

**Why it is rejected — four independent reasons, all verified:**

1. **It can hide real regressions.** The parser only recognised
   `  FAIL <name>` and `not ok <name>`. **24 suites print failures as
   `FAIL: <message>`,** which the parser cannot see at all. A genuine failure in
   that format, occurring in the same suite as a quarantined flake, would have
   been silently excused and the lane reported green. Verified by grepping the
   suites.
2. **It would not even have worked.** `quarantine.txt` listed four checks. The
   same race affects **nine** (§ 6.4). The lane goes red anyway. Verified by
   reading lines 210–222 of the suite.
3. **It weakens money-safety tests.** § 6.4 lists what they protect. The
   repository has a hard standing rule that a test may never be weakened to make
   a change pass, and `tests/test-ai-grok-review.sh` carries that rule in its own
   header. This violates its spirit even though the two checks named in that
   header were not on the list.
4. **It teaches every other session that green is worthless.** Locally,
   `test-all.sh` would have exited 0 with failing checks unless someone set
   `AI_TEST_STRICT=1` — including for the session assigned to fix the races.

Grok 4.6's summary, on 2026-08-27: *"A runner that greps FAIL and paints the
paid-work lock tests non-blocking is a green lie, and it will make the next lock
regression undebuggable."*

**Do not resurrect this.** A quarantine mechanism only becomes defensible after
Phase 2 gives every suite one machine-readable result format, and even then it is
not part of this plan.

### 7.B — Shard the suites across many parallel CI runners. REJECTED as the primary fix.

**What it was:** 6 Linux Bash shards + 6 Windows Bash shards + 3 Windows
PowerShell shards, round-robin over the sorted filename list, with `fail-fast:
false` and one aggregating `verify` gate job.

**Why rejected — five verified reasons:**

1. **It reduces nothing.** Sharding divides the same total work across more
   machines. The largest single waste — Windows re-running the entire Linux Bash
   suite — is untouched. `62/6 ≈ 10` is arithmetic on a serial total, not a
   measurement of the slowest shard plus Windows VM startup plus a full-history
   checkout.
2. **Round-robin by filename is not a time partition.** The slowest suites land
   together by accident. `test-ai-grok-review.sh` (which has a 5-second sleep, a
   120-second wait timeout, and 30-second polls) shares a shard with
   `test-ai-qwen.sh`; `test-ai-kimi.sh` shares one with `test-ai-codex-review.sh`.
3. **It makes the polling problem worse.** With `fail-fast: false` and a gate job
   that `needs` every lane, the one status a session watches stays pending until
   the *slowest* sibling finishes. A 2-minute red shard yields no answer for 40
   minutes. That is strictly worse than today for the stuck sessions.
4. **Cost.** 18 machines per push (10 of them Windows, which take minutes just to
   boot) instead of 3, each doing a full-history checkout, against finite
   concurrency, while Albert runs many sessions at once. Wall clock becomes queue
   time. A docs commit would cost more than today's full matrix.
5. **It deleted the fast lane.** The draft removed `windows-reviewer-safety` and
   buried those suites inside a 40-minute shard — the opposite of what the stuck
   reviewer session needed.

**Sharding is not permanently banned.** It may return *after* Phase 3, sized by
measured per-suite time rather than filename order, and only if measurement shows
the change-scoped selection still leaves an unacceptably slow worst case.

### 7.C — Buffer each suite's output and print it after the suite finishes. REJECTED.

The rejected draft did `out="$(bash "$suite" 2>&1)"` so it could parse the result.
If the job hits its timeout mid-suite, the buffer is discarded and **the suite
that timed out has no logs at all** — precisely the suite you need to diagnose.
Any runner change must `tee` output as it is produced. Locked decision, § 8.D.

### 7.D — Just fix the four flaky checks and stop there. REJECTED as sufficient.

It is necessary (Phase 1) and it is the highest-value single step, but on its own
it leaves the hour-per-docs-change cost, the duplication, and the untested
lock copies in the other three wrappers. Albert's instruction was explicit that
this session is about the grander scheme, not one session's bug.

### 7.E — Delete or rewrite the slow suites. REJECTED.

Never considered seriously, recorded so nobody proposes it: the suites are the
only executable specification of code that spends real money. Speed comes from
running fewer of them per change (Phase 3) and from removing waits that prove
nothing (Phase 1), never from proving less.

---

## 8. Design decisions already made

### LOCKED — do not relitigate

- **A. Correctness of the signal before speed of the signal.** Phase 1 precedes
  every CI change. A fast ambiguous answer is worth less than a slow trustworthy
  one, and the six-hour loops were caused by ambiguity, not by slowness alone.
  *(2026-08-27, after Grok review.)*
- **B. No test is ever weakened, excused, skipped, or deleted to make a lane
  green.** Includes quarantine mechanisms, retry-until-pass loops, and
  `continue-on-error` on anything that asserts behaviour. *(Standing repository
  rule, reaffirmed 2026-08-27.)*
- **C. Extraction into shared libraries must be behaviour-preserving.** Move code;
  do not improve it in the same commit. Improvements come after, with the shared
  test proving them. *(2026-08-27.)*
- **D. Test output streams as it is produced.** No buffering a suite's output to
  parse it later. *(2026-08-27, § 7.C.)*
- **E. The existing concurrency block in `verify.yml` is preserved verbatim** —
  the `group:` expression keyed on event name and source SHA, and
  `cancel-in-progress: true`. It exists so a newer commit does not destroy an
  older commit's proof. *(Pre-existing; do not touch.)*
- **F. A fast Windows reviewer lane must exist at all times.** It may be
  replaced by something faster; it may not be removed and back-filled later.
  *(2026-08-27, § 7.B reason 5.)*
- **G. Branch protection is turned on early (step 0.2), not at the end.** Until
  it is on, "required check" means nothing and every later step is decorative.
  *(2026-08-27.)*

### OPEN — implementer's judgment, with criteria

- **H. How the path-to-suite mapping is expressed** (Phase 3.1). A comment header
  inside each suite, or one manifest file. *Criteria:* it must be impossible for
  a new suite to be added without a mapping — enforce with a test that fails when
  a suite has none. Prefer the option that makes the omission loud.
- **I. Whether a change with no mapping runs everything or fails.** *Criteria:*
  default to running everything (fail safe), but make the "unmapped path" case
  visible in the job summary so it gets fixed.
- **J. The internal shape of `tests/lib/harness.sh`.** *Criteria:* every existing
  suite must be expressible in it without losing an assertion, and the migration
  must be doable one suite per commit.
- **K. Whether `bin/lib/ai-common.sh` is one file or several.** *Criteria:*
  whatever makes step 4.2 reviewable one wrapper at a time.
- **L. Whether to take over PR #123.** See § 9, Phase 1, and § 13.

---

## 9. The plan

Six phases. **Phases are context cut points** — a session should not attempt more
than one large phase. Before starting any phase, **re-read the phases after it**
and check the STATUS table for drift; earlier work may have invalidated later
steps.

---

### Phase 0 — Make the ground solid (small; do not skip)

#### Step 0.1 — Write the growth rule into `AGENTS.md`

**Change:** add a short section to `AGENTS.md` (122 lines today) stating the rule
that this whole plan exists to enforce:

> New provider support, new reviewer behaviour, and new test suites are added by
> extending the shared layer, never by copying an existing wrapper or test
> harness. A pull request that adds a fourth copy of an existing mechanism is
> rejected on that basis alone.

Also link this plan file from `AGENTS.md`'s task router, per the plan standard.

**Intent:** the restructure is worthless if the next session re-creates the
duplication. This is the rule the rest of the plan makes achievable.

**Verification gate:** `grep -q 'never by copying' AGENTS.md` and the plan file is
linked. `bash tests/test-all.sh --only workflow-policy` still passes (or whatever
the Markdown-reachability test is once PR #14 lands).

**Dependencies:** none. Can run in parallel with everything.

#### Step 0.2 — Turn on branch protection

**Change:** enable branch protection on `popcre/ai-devops` `main`, requiring the
CI check to pass. Today the check is `linux-offline` + `windows-offline`; after
Phase 3 it will be a single gate job.

**Critical trap — read this before touching rulesets.** A previously recorded
failure on this account: a ruleset with **no `bypass_actors`** blocks *everything*
from merging, and `gh pr merge --admin` does **not** bypass a ruleset. Cancelling
the workflow run does not help either. Configure a bypass actor for Albert's
identity at the same time you create the rule, and verify by opening a throwaway
PR and merging it before you rely on this.

**Intent:** a red result should stop a change landing. It currently does not.

**Verification gate:**
```bash
gh api repos/popcre/ai-devops/branches/main/protection
```
returns 200 with the expected required check, **and** a throwaway PR with a
deliberately failing check cannot be merged, **and** a throwaway PR with passing
checks can.

**Dependencies:** none, but revisit after step 3.3 renames the required check.

**This step needs Albert.** It changes repository settings — see § 13.

---

### Phase 1 — Make red mean something (the unblocking phase)

> This is the highest-value phase in the plan. Everything downstream assumes a
> trustworthy signal. Do not start Phase 2 until step 1.2 passes.

#### Step 1.1 — Replace the polls with event waits in `tests/test-ai-grok-review.sh`

**Change:** in `tests/test-ai-grok-review.sh`, eliminate every
`for _i in $(seq 1 30); do ... sleep 1; done` construct — both clusters, all nine
checks listed in § 6.4 (around lines 213–220 and 640–660).

**How it should behave when done:** the test waits for the *actual event* rather
than for wall-clock time to pass. Three acceptable mechanisms, in order of
preference:

1. The wrapper writes a marker file at the point the test cares about, and the
   test blocks until it appears — no upper bound tied to a guess, only a generous
   safety ceiling that, when hit, **fails loudly with a diagnostic** rather than
   proceeding silently.
2. A test-only hook inside `lock_acquire` in `bin/ai-grok-review` that signals
   when the lock is genuinely held. If you add one, it must be inert outside
   tests and must be covered by its own check.
3. A blocking wait on the background process reaching a known state, rather than
   a sample-and-hope loop.

The existing `$TMP/hold-started` marker is a partial version of mechanism 1 and
is the natural thing to extend.

**Non-negotiable:** every one of the nine checks must still assert exactly what it
asserts today. Re-read § 6.4 for what each one protects. If a check cannot be made
deterministic without weakening it, **stop and flag it** — that is a § 1 goal
conflict.

**Also fix:** the timeout path must not silently pass. Today, when the poll
expires, the assertion simply runs against unsettled state and reports a normal
`FAIL`, which is indistinguishable from a real regression. On timeout the test
must print what it was waiting for and what it observed.

**Dependencies:** must be first. Conflicts with PR
[#123](https://github.com/popcre/ai-devops/pull/123) — see § 13.

**Verification gate:**
```bash
bash tests/test-ai-grok-review.sh
```
passes locally, **and** the suite completes measurably faster than today
(event waits should remove most of the fixed 30-second budgets — record the
before and after timings in `tests/verification/`).

#### Step 1.2 — Prove it, do not assume it

**Change:** none. This is a measurement step, and it is mandatory.

**How:** run the reviewer suites on Windows CI **10 consecutive times** on
`main` after 1.1 lands — via `workflow_dispatch` or a temporary throwaway
workflow, not by opening ten PRs. Record every run id.

**Verification gate:** **10 of 10 green.** Write the run ids to
`tests/verification/reviewer-flake-fix/<UTC>-ten-run-proof.md`. Update the STATUS
table citing that file.

If it is not 10 of 10, the fix is incomplete. Do not proceed to Phase 2 —
the entire plan rests on this.

**Why 10:** the observed failure rate was ~1 in 3. Ten consecutive passes puts
the probability that a 33% flake survives undetected below 2%.

---

### Phase 2 — One test foundation

#### Step 2.1 — Build `tests/lib/harness.sh`

**Change:** create `tests/lib/harness.sh` providing, at minimum: `ok`, `bad`,
`skip`, `check`, a pass/fail/skip counter, a standard temp-directory-with-cleanup
helper, a standard `HOME`-isolation helper, and a single `finish` that prints the
summary and sets the exit status.

**How it should behave:** a suite sources it once and defines only its own
assertions. The output format is identical for every suite and is machine
readable (see 2.3). A skipped check is reported as skipped and is never counted as
a pass — `tests/test-ai-grok-review.sh` already carries a comment explaining that
counting skips as passes previously hid which Windows cases never ran. Preserve
that behaviour.

**Verification gate:** the harness has its own suite,
`tests/test-harness.sh`, asserting each helper's counting and exit-status
behaviour, and it passes.

#### Step 2.2 — Migrate every suite onto it

**Change:** move all ~24 suites that define their own `ok`/`bad`/`check` onto the
shared harness, plus any others that print results in a bespoke format.

**How:** **one commit per suite.** Each commit must show the suite passing before
and after. This is deliberately boring and deliberately reviewable. Do not batch.

**Trap:** the `FAIL:`-and-exit-immediately pattern (`fail() { echo "FAIL: $*";
exit 1; }`) is not equivalent to `bad()` — it aborts the suite rather than
recording a failure and continuing. When migrating one of those, decide
explicitly whether the abort is intentional (a precondition) or accidental, and
say which in the commit message.

**Verification gate:** after each commit, `bash tests/test-all.sh` has the same
pass/fail totals as before that commit. After the last one, no suite defines its
own `ok`/`bad`/`check` — enforce with a test:
`tests/test-harness-adoption.sh` fails if any `tests/test-*.sh` defines them
locally.

#### Step 2.3 — Machine-readable results

**Change:** the harness emits one canonical line per check that a machine can
parse without heuristics — TAP-style (`ok 1 - <name>` / `not ok 1 - <name>`) is
the obvious choice and is already partially present in two suites.

**Intent:** this is what makes any future automation — hit-rate tracking,
selective re-runs, a defensible quarantine — actually possible. The rejected § 7.A
design failed precisely because it had to guess at 24 formats. **Building the
format is in scope; building the quarantine on top of it is not.**

**Verification gate:** a test asserts that every line the harness prints for a
check matches the canonical grammar.

---

### Phase 3 — Verify only what changed

> Do not start before Phase 2 is complete: change-scoped selection is only safe
> when suite results are trustworthy and uniformly reported.

#### Step 3.1 — Map every suite to the paths it covers

**Change:** give every suite a declaration of which repository paths it covers —
e.g. `test-ai-grok-review.sh` covers `bin/ai-grok-review` and
`bin/ai-process-supervisor`. Shape is decision **H** (open).

**Verification gate:** a test fails when any `tests/test-*.sh` has no mapping. Add
a deliberately unmapped scratch suite, confirm it fails, remove it.

#### Step 3.2 — Selection in `tests/test-all.sh`

**Change:** `tests/test-all.sh` gains the ability to run only the suites whose
mapped paths intersect a given change set — e.g.
`bash tests/test-all.sh --changed-since origin/main`.

**Requirements:**
- Default with no arguments stays **exactly** as today: run everything. Existing
  callers, including other machines' scripts, must not change behaviour.
- Output streams as produced (decision **D**).
- A path with no mapping selects everything (decision **I**), and says so loudly
  in the output.

**Verification gate:** `tests/test-selection.sh` asserts: a change to
`bin/ai-grok-review` selects the grok suite; a change to `README.md` selects
nothing; a change to an unmapped path selects everything and prints the warning;
no arguments selects all 53.

#### Step 3.3 — Rebuild `verify.yml`

**Change:** restructure CI around four ideas, in this order of importance:

1. **A fast lane that always runs, for every change**, targeting **under 3
   minutes**: shell syntax, `shellcheck` (currently installed and never run —
   fix that), Markdown reachability, and the workflow policy test.
2. **Change-scoped suites**, driven by step 3.2, using the pull request's actual
   diff against `main`.
3. **A preserved fast Windows reviewer lane** (decision **F**), streaming its
   output.
4. **A full matrix on a schedule and on push to `main`** — not on every PR. This
   is the safety net that catches anything the mapping misses, and the place the
   mapping's own gaps become visible.

**Preserve verbatim:** the `concurrency:` block (decision **E**).

**Do not:** shard (§ 7.B), buffer output (§ 7.C), or add a gate job whose result
waits on the slowest of many parallel lanes (§ 7.B reason 3).

**Verification gate:** open a throwaway PR touching only `README.md` — the fast
lane runs, no Windows matrix runs, total wall clock under 5 minutes. Open another
touching `bin/ai-grok-review` — the grok suites and the Windows reviewer lane run.
Record both run ids in `tests/verification/`.

#### Step 3.4 — Stop Windows re-running the Linux-only suites

**Change:** `tests/test-all.ps1` currently runs the **entire** Bash suite and then
the PowerShell suites. Identify which Bash suites are genuinely
platform-sensitive — those touching Git Bash paths, CRLF handling, `cygpath`,
`AppData`, or Windows process trees — and run only those under Windows Git Bash.
The rest run on Ubuntu only.

**Trap — this is a real, previously-recorded failure mode.** A checkout once
rewrote every script to CRLF; it was harmless in Git Bash and fatal in WSL bash,
so no session ever saw it. `git grep` cannot detect line endings —
`git ls-files --eol` can. Whatever list you build, make sure the CRLF class of
bug is still covered somewhere.

**Verification gate:** the Windows lane's measured time drops substantially
(record before and after), and a deliberately introduced Windows-only defect —
e.g. a hard-coded forward-slash path in a wrapper — is still caught. Write the
experiment up in `tests/verification/`.

---

### Phase 4 — One implementation of each mechanism

> Behaviour-preserving throughout (decision **C**). Money-safety code — read § 2
> on the $8.28 incident before starting.

#### Step 4.1 — Extract `bin/lib/ai-common.sh`

**Change:** create the first shared library under `bin/lib/`, starting with the
functions that are provably identical or trivially reconcilable across wrappers:
`die`, `warn`, `note`, `need`, `usage` scaffolding, `valid_name`, `repo_root`,
`repo_remote`, `repo_id`, `meta_path`, `find_meta`, `write_meta`.

**Explicitly not yet:** `lock_acquire`, `lock_release`, `release_boundary`,
`review_boundary`, `run_turn`, `cmd_ask`. Those have diverged meaningfully and
are step 4.3.

**Trap:** these are installed executables. Confirm how `bin/` is installed onto a
machine before introducing a sourced dependency — a wrapper that is symlinked or
copied without `bin/lib/` will break at runtime, on every machine, silently.
Check `bin/ai-install-manifest`-related tests and
`tests/test-installer-parity.sh` first. If the install path cannot carry a
library, resolve that before extracting anything.

**Verification gate:** `bash tests/test-all.sh` fully green, and each wrapper's
`doctor` subcommand still succeeds on this machine:
`ai-grok-review doctor`, `ai-glm doctor`, `ai-kimi doctor`, `ai-qwen doctor`.

#### Step 4.2 — Move the wrappers over, one per commit

**Order:** `bin/ai-qwen` first (smallest of the four at 1,504 lines and its lock
is byte-identical to Kimi's, so it is the lowest-risk), then `bin/ai-kimi`, then
`bin/ai-glm`, then `bin/ai-grok-review` **last** — Grok's is the most elaborate
and the only one with the paid-work protection.

**Verification gate per commit:** the wrapper's own suite passes, `doctor`
succeeds, and `git diff` shows only deletions of moved code plus the `source`
line. Any behavioural delta means stop.

#### Step 4.3 — One lock, tested once

**Change:** reconcile the four `lock_acquire` implementations into one in
`bin/lib/`. The Grok version is the reference: it is the only one with the
`remote-uncertain` paid-work protection (§ 6.5).

**This step changes behaviour** for GLM, Kimi, and Qwen — they gain a protection
they do not have. That is the point, and it is the one place in Phase 4 where
decision **C** is deliberately set aside. Say so explicitly in the commit message.

**Before writing code:** determine whether GLM, Kimi, and Qwen can actually
double-bill today. If they can, that is a live money bug and it should be
recorded as its own issue with evidence, independently of this plan.

**Verification gate:** the nine checks from § 6.4, now deterministic after Phase
1, run against **all four** wrappers, not just Grok. Every one passes for every
wrapper. This is the payoff of the whole restructure: one mechanism, one test,
four tools covered.

---

### Phase 5 — Close the backlog the duplication created

#### Step 5.1 — Triage the 34 plan files

**Change:** for each `plan_*.md` at the repository root, determine whether the
work is done, abandoned, or genuinely open. Delete the done ones (git history
keeps them). Give every genuinely open one a STATUS table if it lacks one.

**Verification gate:** every remaining `plan_*.md` has a STATUS table whose top
row states where a fresh session starts, and is linked from `AGENTS.md` or a
`HANDOFF.d/` file. Add a test that fails on an unreferenced plan file.

#### Step 5.2 — Collapse the eight per-provider repair plans

**Change:** the eight `plan_*_reviewer_*_repair.md` files (listed in § 5.5)
describe one class of problem eight times. After Phase 4 there is one
implementation, so there should be one plan. Merge what remains open into a single
`plan_reviewer-system-repair.md` — a file of that name **already exists**, so
reconcile into it rather than creating another.

**Verification gate:** seven files deleted, one reconciled, nothing open lost —
show the mapping in the commit message.

---

## 10. Tests required

### New tests this plan adds

| Test | Asserts |
|---|---|
| `tests/test-harness.sh` | every `tests/lib/harness.sh` helper: counting, skip-is-not-pass, exit status, temp cleanup |
| `tests/test-harness-adoption.sh` | no `tests/test-*.sh` defines its own `ok`/`bad`/`check` |
| `tests/test-selection.sh` | change-scoped selection: grok change → grok suites; `README.md` → none; unmapped path → everything + warning; no args → all 53 |
| coverage-mapping test (name per decision **H**) | every suite declares the paths it covers |
| plan-reachability test | every `plan_*.md` is linked from `AGENTS.md` or `HANDOFF.d/` |

### Existing tests that must stay green throughout

- `bash tests/test-all.sh` — the full Bash suite, at every step.
- `pwsh -File tests/test-all.ps1` — on Windows, at every step.
- `tests/test-workflow-policy.sh` — **will need rewriting** in step 3.3. It
  currently asserts that `windows-offline` has **at least 75 minutes** of
  timeout, which the new structure will not satisfy. Rewrite it to protect the
  new invariants: every job bounded, the fast lane exists and is genuinely fast,
  the Windows reviewer lane still exists (decision **F**), the concurrency block
  is intact (decision **E**), and nothing asserting behaviour carries
  `continue-on-error`. **Do not** make it snapshot YAML trivia like exact job
  lists or shard counts — Grok specifically flagged the first draft for freezing
  an unmeasured structure that any honest follow-up would have to break.
- `tests/test-installer-parity.sh` — critical before step 4.1 (see its trap).
- Each wrapper's `doctor`: `ai-grok-review doctor`, `ai-glm doctor`,
  `ai-kimi doctor`, `ai-qwen doctor`.

### What must NOT be done to any test

Weaken it, skip it, quarantine it, wrap it in `continue-on-error`, or delete it
to make a lane green. Decision **B**. If a test genuinely asserts the wrong thing,
that is a separate, argued change with its own commit and reasoning — not a step
in this plan.

---

## 11. Constraints, standing rules, and gotchas in force

### Repository rules

- **Branch:** ordinary work goes directly to `main`. This repo is not DesignFlow.
  Given the size of this work, prefer a branch plus PR per phase — but **you merge
  your own PR.** Albert does not merge. Never end a session asking him to.
- **`gh pr merge` from a linked worktree** can print `'main' is already used by
  worktree`. That is local branch cleanup failing **after** the merge succeeded.
  Confirm with `gh pr view <n> --json state`, delete the remote branch, and
  continue. Do not report it as a failed merge.
- **Git identity:** run `git var GIT_COMMITTER_IDENT` before the first commit; it
  must read `Albert Hazan <u2giants@users.noreply.github.com>`.
- **Both repository owners are valid.** `popcre/ai-devops` is the current home
  (moved 2026-08-26), and the `u2giants` entry in `repo-identities.tsv` remains
  valid **on purpose**. Do not "clean up" either one, and do not rewrite tests
  that reference `u2giants`.
- **Concurrent sessions.** Other sessions are working in this repository right
  now. Stage only your own hunks. **Never** use bare `git stash` / `git stash
  pop` — the stash stack is shared across worktrees and another session may pop
  yours. Use a temporary WIP commit instead, or
  `git stash push -u -m "<unique-tag>"` and recover by SHA with
  `git stash apply`.
- **Never replace operating-system binaries.** Shared libraries go under
  `bin/lib/`, not on the system path.
- **Secrets** live in the 1Password vault `vibe_coding` and move only through
  pipes or protected files — never chat, command arguments, logs, or commits.
  This plan should need none.

### Work-quality rules

- **No band-aids and no silent failures.** A repair is complete only when the
  reported problem is gone **and** the original capability still works. If that is
  impossible, stop before reducing function and ask.
- **Nothing hard-coded** that should be configurable.
- **Preserve the capability.** Do not remove, disable, or bypass a broken tool as
  a substitute for repairing it.

### Traps specific to this work

1. **Ruleset admin-bypass trap (step 0.2).** A ruleset with no `bypass_actors`
   blocks everything; `gh pr merge --admin` does **not** bypass it. Configure the
   bypass actor at creation time and verify with a throwaway PR.
2. **CRLF is invisible to `git grep` (step 3.4).** Use `git ls-files --eol`. A
   past checkout rewrote every script to CRLF — harmless in Git Bash, fatal in
   WSL bash, so no session noticed.
3. **GitHub withholds a run's logs until every job in that run completes**
   (§ 6.2). This is why the fast lane in step 3.3 matters so much: a fast lane in
   the *same run* as a 60-minute job is not fast in practice. Consider whether the
   fast lane belongs in a separate workflow file so its logs are available
   immediately.
4. **`continue-on-error: true` at job level makes GitHub report that job as
   successful to anything that `needs` it.** If Phase 3 introduces any advisory
   job, it must never appear in a gate's `needs`.
5. **A matrix job's aggregate result treats mixed success-and-skipped as
   success.** Relevant if any later work adds per-shard conditions.
6. **The wrappers are installed onto machines** (step 4.1 trap). Confirm the
   install mechanism carries `bin/lib/` before introducing a sourced dependency.
7. **`grok --worktree` is silently ignored in headless mode.** Never
   hand-compose a provider command; use the `ai-*` wrappers. Recorded because
   this class of shortcut has already cost real money.
8. **PR #123 conflicts with step 1.1.** See § 13.

---

## 12. Access and environment

- **Machine this was planned on:** `edge-dev`, Windows 11 Pro. Windows sessions
  use PowerShell for `.ps1` suites and **Git Bash** for `.sh` suites — not WSL.
- **Working directory:** this plan was written in the linked worktree
  `C:\repos\ai-devops\.claude\worktrees\github-org-move-handoff-d576f2`. Run
  everything from your own worktree; do not `cd` to the main checkout.
- **Authenticated and working now (verified 2026-08-27):**
  - `gh` — GitHub CLI, against `popcre/ai-devops`.
  - `ai-grok-review` — `doctor` reports auth OK, model `grok-4.6-build`.
  - Other `ai-*` wrappers — verify with each one's `doctor` before relying on it.
- **Nothing to deploy, no server to run, no test login required.** This
  repository has no runtime.
- **Costs:** the `ai-*` reviewer wrappers spend real money. A Grok review turn
  costs roughly $0.12–$0.46 and 250k–530k tokens; the review that rejected this
  plan's first draft cost **$0.14**. Record the cost of any review you run.
- **Secrets:** 1Password vault `vibe_coding`, referenced by item title only.

---

## 13. Definition of done, risks, and open questions

### Definition of done

The plan is complete when all of the following are true and each is backed by an
artifact cited in the STATUS table:

- [ ] `AGENTS.md` carries the no-duplication growth rule and links this plan.
- [ ] Branch protection is on, verified by a throwaway PR that could not merge red
      and could merge green.
- [ ] The nine racing checks are deterministic, proven by 10 consecutive green
      Windows runs recorded in `tests/verification/reviewer-flake-fix/`.
- [ ] No `tests/test-*.sh` defines its own `ok`/`bad`/`check`; enforced by a test.
- [ ] Every suite declares its path coverage; enforced by a test.
- [ ] A pull request touching only Markdown completes CI in **under 5 minutes**,
      with the run id recorded.
- [ ] A pull request touching `bin/ai-grok-review` runs the grok suites and the
      Windows reviewer lane, with the run id recorded.
- [ ] The full matrix runs on a schedule and on push to `main`.
- [ ] `bin/lib/` exists; all four large wrappers source it; each wrapper's
      `doctor` passes on this machine.
- [ ] One `lock_acquire`, covered by the § 6.4 checks for **all four** wrappers.
- [ ] Every remaining `plan_*.md` has a STATUS table and is reachable; the eight
      per-provider repair plans are one.
- [ ] Every commit pushed; every PR merged by the implementing session, not by
      Albert.
- [ ] `session-docs-update` run, this plan de-staled, and a `HANDOFF.d/` file
      written for whatever remains open.

### Measured outcome to check at the end

Re-run the § 5.5 measurements. **Open PRs older than 3 days should be zero.** If
duplication counts, plan-file counts, and stalled-PR counts have not fallen, the
restructure did not achieve its § 1 goal regardless of how many steps are ticked.

### Risks and rollback

| Risk | Likelihood | Mitigation / rollback |
|---|---|---|
| Change-scoped CI misses a real regression | Medium | The scheduled full matrix (3.3) catches it within a day; unmapped paths run everything |
| Extraction breaks a wrapper on a machine that installs `bin/` without `bin/lib/` | Medium-high | Resolve the install path *before* 4.1; `doctor` on each wrapper is the gate; revert is one commit |
| Step 4.3 changes GLM/Kimi/Qwen locking behaviour | Certain — it is the point | Land it alone, with the § 6.4 checks green for all four first; revert is one commit |
| Phase 1 collides with PR #123 | High | See open question 1 |
| Branch protection locks everyone out | Low but severe | Configure `bypass_actors` at creation; verify with a throwaway PR (§ 11 trap 1) |
| The full-matrix schedule becomes the new ignored red | Medium | Its failure must open an issue automatically, or it will be wallpaper |

### Open questions

1. **Who fixes the racing tests — this plan's implementer, or PR
   [#123](https://github.com/popcre/ai-devops/pull/123)?** That PR is titled
   "derive reviewer test timing budgets from a measured baseline," is currently
   green, and its session has been idle since 2026-08-27T15:44Z after 24 hours of
   no progress. **Decision criteria:** if #123's approach is "make the timeout
   budget bigger," it treats the symptom and step 1.1 supersedes it — close it
   with an explanation. If it genuinely removes the polling, adopt it and mark
   step 1.1 done citing its merge SHA. **Read the PR diff before deciding.**
   *This is decision L, and it is the one thing this plan does not settle.*
2. **How is `bin/` installed onto a machine?** Determines whether step 4.1 is
   straightforward or needs an installer change first. Answer it before Phase 4.
3. **Can GLM, Kimi, and Qwen double-bill today** for want of the paid-work
   protection (§ 6.5)? If yes, it is a live money bug that deserves its own issue
   ahead of the rest of Phase 4.
4. **Should the fast lane live in a separate workflow file** so its logs are not
   withheld behind a slow sibling (§ 11 trap 3)? Lean yes; confirm with a
   measurement.

---

## Self-audit (mandatory gate — preserved per the plan standard)

**1. Could a brand-new AI session with no project knowledge and no context from
this conversation execute this plan to perfection, without asking anything?**

Yes, with one deliberate exception. § 2 defines the repository, its machines, its
identities, and why the wrappers are safety-critical. § 3 quotes the triggering
report verbatim and names both stalled sessions and their PRs. § 5 gives the
current state with line numbers, measured counts, and the verified 404 proving
there is no branch protection, and warns that abandoned draft edits may be present
in a working tree and must be discarded. § 6.4 lists all nine racing checks by
name with line ranges and states what each protects. § 9 names concrete files and
functions per step with a verification gate on each. § 11 carries eight
work-specific traps plus the standing rules, including the ones a newcomer cannot
know (the ruleset bypass trap, the CRLF invisibility, the worktree stash hazard,
the `gh pr merge` false negative). § 12 records what is authenticated and what
costs money.

The exception is open question 1 (decision **L**), which needs Albert's call on
whether to take over another live session's PR. It is stated with explicit
decision criteria so an implementer can proceed if Albert is unavailable, and it
is flagged in the risks table.

**2. Does the plan carry every piece of background, nuance, and reasoning
currently held — including what was ruled out and why?**

Yes. § 7 records five rejected approaches. The two that matter — the quarantine
(7.A) and the sharding (7.B) — were the author's own first design; each is
recorded with the four or five specific verified reasons it failed, including the
exact evidence (24 suites use an unparseable failure format; four checks were
listed where nine were affected; 18 machines per push versus 3). § 7.C records the
output-buffering trap, which is a subtle mistake an implementer would otherwise
repeat. § 8 separates seven locked decisions from five open ones with criteria.
§ 6.5 records the divergence finding that makes Phase 4 a money-safety matter
rather than tidiness. Grok 4.6's rejection and its cost are cited in the header
and throughout.

**3. Is the ultimate goal stated clearly enough that the implementer could make a
correct judgment call if a step turns out to be wrong?**

Yes. § 1 states the goal in plain business English before any technical wording,
names the three conditions that must become true, gives a measurable outcome
(stalled PRs to zero), states the non-goal explicitly — this is not a plan to make
the suite pass — and carries the instruction that the goal wins over any step,
with three concrete tests for recognising a step that violates it: slower
verification, less trustworthy red, or another copy of something that exists.
§ 13 repeats the measurable outcome as a final check, stating that ticked steps
without moved numbers means the restructure did not work.

**Checklist grade:** all 13 sections present; goal-wins instruction present;
rejected approaches with reasons present; every step names files and has a
verification gate; locked and open decisions labeled; explicit out-of-scope list;
tests named individually; all identifiers, SHAs, and paths defined; no secret
values; definition of done includes commit, push, CI, and merge-by-implementer;
plan and handoff cross-link. **All items pass.**
