# Implementation plan — restructure `ai-devops` so parallel sessions can ship

**Repository:** `popcre/ai-devops` (public; the `u2giants/ai-devops` remote name
also remains valid on purpose — see § 11)
**Branch this plan was authored on:** `claude/test-infrastructure-redesign-74eb99`
**Authored:** 2026-08-27 by Claude (Opus 5) on machine `edge-dev`
**Base commit:** `b9734ca` (rebased onto `main` 2026-08-27; the plan was authored
against `789d922`, whose Disney commit was already on `main` under SHA `724a306`)
**Handoff:** [`HANDOFF.d/2026-08-27T1630Z-edge-dev-claude-repo-throughput-restructure.md`](HANDOFF.d/2026-08-27T1630Z-edge-dev-claude-repo-throughput-restructure.md)
**Adversarial reviews — both incorporated:**
- **Grok 4.6, 2026-08-27: REJECTED** the first draft of this work. Recorded in § 7.
  ($0.14; `.ai/reviews/grok-test-infra-redesign-20260827T161400Z-1644185.md`)
- **GLM 5.3, 2026-08-27: ACCEPT WITH CHANGES** on the plan that replaced it. All
  seven required changes are applied; see § 7.F for what they were and why.
  (`.ai/reviews/glm-repo-throughput-restructure-20260827T164602Z.md`)

---

## STATUS — read this first

A fresh session starts at **Phase 0, step 0.1**. Nothing below is done.

**This plan deliberately ends at Phase 3′.** Phases 2, 4, and 5 of the original
draft were split out into named follow-on plans (§ 14) so that a stall partway
through leaves shipped value rather than a thirty-fifth abandoned plan file. Do
not start a follow-on until Phase 3′ has landed.

| # | Step | State | Evidence |
|---|------|-------|----------|
| 0.1 | Growth rule **and CI-waiting conduct rule** into `AGENTS.md` | ⬜ open | — |
| 1.1 | Replace all seven poll loops in `tests/test-ai-grok-review.sh` | ⬜ open | — |
| 1.2 | Prove it: 10 consecutive green reviewer runs on Windows CI | ⬜ open | — |
| 0.2 | Turn on branch protection **(after 1.2, not before)** | ⬜ open | — |
| 3′.1 | Fast lane in its **own workflow file**, under 3 minutes | ⬜ open | — |
| 3′.2 | Coarse path filtering — docs-only changes skip the matrix | ⬜ open | — |
| 3′.3 | Stop re-running the Linux-only Bash suites on Windows | ⬜ open | — |
| 3′.4 | `--only` / `--changed-since` entry point for local runs | ⬜ open | — |
| 3′.5 | Rewrite `tests/test-workflow-policy.sh` for the new shape | ⬜ open | — |

Follow-on plans, **not** part of this one — see § 14:
`plan_test-harness-consolidation.md`, `plan_wrapper-shared-library.md`,
`plan_backlog-consolidation.md`.

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

### How we will know it worked

An earlier draft made the sole measure "stalled open PRs go to zero." GLM 5.3
rejected that as a gameable proxy, correctly: this repository's default workflow
is **direct to `main`**, so most session throughput never opens a PR at all, and
the plan itself both mandates "you merge your own PR" and installs a bypass
actor. A session under pressure can merge its way to a green number.

**Primary measures — both fall directly out of gates this plan already requires:**

1. **CI wall clock, median and 90th percentile, split by change type:** a
   docs-only change and a `bin/`-only change. Steps 3′.2 and 3′.3 require
   recording these anyway. Target: docs-only **under 5 minutes**.
2. **Session outcome ratio:** of sessions started against this repo, how many end
   in a landed commit versus a handoff describing unfinished work. This is the
   thing Albert actually complained about.

**Secondary indicator:** open pull requests with no commit for more than 3 days.
Useful as a smell, not as the goal. Today that count is **5** (PRs #66, #33, #15,
#14, and #123 at 3+ days) out of 9 open.

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
  the follow-on plans in § 14. Documentation mass is a real problem, but it is a
  work and mixing it in here will make this plan unreviewable.
- **Touching `skills/`.** Note this is *not* the same as ignoring it in CI —
  step 3′.2 deliberately keeps `skills/` in the verified set.
- **Any change to the shared database, DesignFlow, or any other repository.**
- **Adding a new AI provider**, and **unifying the wrapper code that would make
  that cheap** — that is `plan_wrapper-shared-library.md` (§ 14).
- **Building the shared test harness** — `plan_test-harness-consolidation.md`
  (§ 14). Per-suite path mapping goes with it; this plan ships only the coarse cut.
- **Triaging the 34 plan files** — `plan_backlog-consolidation.md` (§ 14).
- **Sharding the test suite across many CI runners.** This was the original
  proposal and it was rejected. See § 7, rejected approach B.

---

## 5. Current state of the code

Everything below is the state at base commit `789d922`. **Nothing in this plan
has been implemented.** A previous draft was written into the working tree of the
authoring session and then reverted after review.

If you find uncommitted edits to `verify.yml`, `test-all.sh`, `test-all.ps1`,
`test-workflow-policy.sh`, or a file called `tests/quarantine.txt`: **read the
diff first and confirm it matches the rejected design's signature** — a
`quarantine.txt`, a `--shard i/n` flag, or a matrix of numbered shards in
`verify.yml`. Only then discard it. Do not reflexively `git checkout --` anything
in this repository: other sessions work in it concurrently, and the standing rule
is that every destructive action is inspected against its exact target first.

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

### 6.4 The racing polls — exact inventory by line number

All in `tests/test-ai-grok-review.sh`. The shared defect is a bounded poll that
**silently gives up** and lets the assertion run against state that has not
settled. On a loaded CI runner the budget is not enough, and the give-up is
indistinguishable from a real regression.

> **An earlier version of this section said "four checks" and then "nine," and
> named eight. Both were wrong, and the instruction "eliminate every
> `seq 1 30` loop" silently excluded the `seq 1 60` ones.** GLM 5.3 caught this.
> The table below is the verified inventory — grep it yourself to confirm before
> starting:
> ```bash
> grep -n 'for _i in $(seq' tests/test-ai-grok-review.sh
> ```

**Seven real poll loops.** (Line 121, `for _i in $(seq 1 $#); do :; done`, is an
argument-counting idiom, not a wait — leave it alone.)

| Line | Budget | Waits for | Checks that depend on it |
|---|---|---|---|
| 148 | 60s | inside the stub script — inspect before changing | stub-timing dependent |
| 202 | 60s | `$TMP/hold-started` | `slow_fixture_reached_the_provider_before_mode_changes` |
| 213 | 30s | ≥2 `work--*.lock.d` | `same_repo_different_session_and_packet_run_concurrently`, `same_exact_session_and_turn_is_refused` |
| 219 | 30s | ≥3 `work--*.lock.d` | `same_repo_different_caller_and_work_run_concurrently`, `lock_metadata_contains_digests_not_raw_prompts` |
| 295 | 30s | interrupt fixture state | `interrupt_fixture_reached_the_provider`, `signal_releases_owned_locks_and_warns_about_remote_turn` |
| 642 | 30s | ≥2 `work--*.lock.d` | `different_named_sessions_can_ask_concurrently`, `same_next_ask_turn_is_serialized` |
| 649 | 30s | a lock **and** `$TMP/hold-started` | `uncertain_ask_blocks_its_exact_retry`, `uncertain_ask_blocks_changed_prompt_for_same_next_turn`, `uncertain_ask_does_not_block_other_named_session` |

**Line 295 was missed entirely by the first draft** and it feeds two of the most
important `remote-uncertain` assertions in the suite. Do not skip it.

The 642/649 cluster also depends on a shared `$TMP/mode` file and on killing a
backgrounded `ask` with `TERM` at the right moment. Those are additional races on
top of the poll.

**What these checks actually protect** — read `bin/ai-grok-review` before
touching them:
- `different_named_sessions_can_ask_concurrently` — locks are per work-item, not a
  global mutex; unrelated reviews must not serialise.
- `same_next_ask_turn_is_serialized` — `session_lock_acquire` (~line 1269) stops
  the same session's same turn running twice. A regression here **double-bills**
  and tears the session metadata.
- `uncertain_ask_blocks_its_exact_retry` — `lock_acquire` honouring the
  `remote-uncertain` marker (`bin/ai-grok-review:374`, `:403`). This is the
  fail-closed paid-work path. A regression retries a turn whose remote state is
  unknown — i.e. pays twice for work that may already have run.
- `uncertain_ask_does_not_block_other_named_session` — that uncertainty is scoped
  to the affected session and does not freeze everything else.
- `signal_releases_owned_locks_and_warns_about_remote_turn` (line 295 cluster) —
  an interrupted turn records remote uncertainty **before** any fallible cleanup.

These are money-safety tests. That is why § 7.A rejects excusing them.

### 6.5 The duplication has already caused divergence — and the copies are not
### merely "shorter versions" of each other

This is the finding a first draft got wrong, and it matters because it changes
what unifying the lock actually costs.

| Wrapper | Function(s) | Signature | Policy on a held lock |
|---|---|---|---|
| `bin/ai-grok-review:353` | `lock_acquire` | `DIR LABEL [UPSTREAM] [SESSION] [SOURCE] [WORK_ID] [PROMPT_DIGEST] [SOURCE_ID] [TURN]` | **refuses immediately**; honours `remote-uncertain` (`:374`, `:403`) |
| `bin/ai-glm:265` | `lock_acquire` | `DIR TIMEOUT_SECONDS` | **waits** up to the timeout, reclaims a stale lock, then dies with "session '…' is busy and did not free up within Ns" (`:961`, `:1001`) |
| `bin/ai-glm:284` | `implementation_lock_acquire` | — | **never reclaims** — "a stale lock is reconciliation evidence" |
| `bin/ai-glm:343` | `metadata_lock_acquire` | — | fast poll, for one atomic record transition |
| `bin/ai-kimi:418` | `lock_acquire` | `DIR LABEL` | byte-identical to Qwen's |
| `bin/ai-qwen:283` | `lock_acquire` | `DIR LABEL` | byte-identical to Kimi's |

Two consequences, both established by GLM 5.3's review and verified:

1. **"Adopt Grok's version everywhere" is not additive — for GLM it is a
   regression.** It would replace wait-with-timeout semantics with
   refuse-immediately, change the meaning of the second argument at every call
   site, and break a user-visible error message. GLM has **three** lock functions
   with three deliberately different policies, not one.
2. **Only Grok carries the paid-work `remote-uncertain` protection.**
   `grep remote-uncertain bin/*` returns hits in Grok alone. Kimi and Qwen can, in
   principle, retry an interrupted paid turn. Nobody has tested whether they
   actually do, because the tests that would catch it exist only for Grok.

**Consequence for this plan:** unifying the lock is real money-safety work, it
needs its own design round, and it is therefore **not in this plan.** It moves to
`plan_wrapper-shared-library.md` (§ 14). What *is* in scope now is answering the
precondition question below, because if the answer is yes it is a live money bug
that outranks everything here.

> **Precondition, not an open question:** determine whether GLM, Kimi, and Qwen
> can double-bill today for want of the `remote-uncertain` protection. If they
> can, **open an issue with evidence immediately** — ahead of any follow-on plan.
> The $8.28 incident in § 2 is why this cannot wait its turn.

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
`plan_test-harness-consolidation.md` (§ 14) gives every suite one machine-readable
result format — and even then it is not automatically a good idea.

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
running fewer of them per change (Phase 3′) and from removing waits that prove
nothing (Phase 1), never from proving less.

### 7.F — What GLM 5.3 changed in this plan, and why

The version of this plan that GLM reviewed had all of Phases 0–5 in one document
and a different ordering. Its verdict was **ACCEPT WITH CHANGES** with seven
required changes. All seven are applied. Recorded here so nobody "restores" the
earlier shape.

| # | What was wrong | What changed |
|---|---|---|
| 1 | Branch protection ran **before** the flake fix. `windows-offline` runs the flaky grok suite, so this would have gated every merge on a 1-in-3 coin flip — this plan's own worst failure mode, with teeth. GLM called it the one actively harmful item. | Step 0.2 moved after 1.2; decision **G** amended in place with the reasoning |
| 2 | Phase 2 (harness) ran before Phase 3 (change-scoped CI), justified by "selection is only safe when results are uniformly reported." **That is false** — selection decides which suites to run and never reads their output. Worse, Phase 2.2's gate was a full `test-all.sh` run before and after each of ~24 commits: 16–24 hours of Windows verification runtime, in a plan triggered by a session re-running the full suite for a day. | Coarse CI filtering became Phase 3′ and runs immediately after Phase 1; per-suite mapping and the harness deferred to § 14 |
| 3 | § 6.4 said "nine checks" and listed eight, and step 1.1's instruction ("eliminate every `seq 1 30` loop") matched only five of the seven real loops — missing the `seq 1 60` loops at 148 and 202, and the whole interrupt/`remote-uncertain` cluster at line 295 | § 6.4 rewritten as a verified line-by-line table; step 1.1 rewritten to match, with two distinct rewrite shapes |
| 4 | Step 4.3 claimed GLM/Kimi/Qwen would "gain a protection they do not have" by adopting Grok's lock. **False for GLM**: its `lock_acquire` *waits* with a timeout, has a different signature, and it has three lock functions with three deliberate policies. Adopting Grok's would have broken it. The gate also silently required building three new concurrency stub harnesses | Phase 4 removed from this plan entirely; § 6.5 rewritten with the real per-wrapper table; the double-billing question promoted from "open question" to a precondition that opens an issue |
| 5 | Nothing in the plan changed **how sessions wait** — yet one of the two triggering sessions died purely in a polling loop. `templates/system/` has no such rule anywhere | Decision **M** added; step 0.1 now writes the CI-waiting rule into `AGENTS.md` |
| 6 | Step 0.1's gate invoked `tests/test-all.sh --only workflow-policy` — **a flag that does not exist.** `test-all.sh` ignores arguments silently, so the gate would have run everything and looked satisfied. The success metric was also gameable | Gate replaced with the real command; `--only` scheduled as step 3′.4; § 1 metric replaced |
| 7 | At ~12–20 sessions the plan was three times its own minimum viable subset, and nothing user-visible landed until Phase 3 — so a stall halfway would leave nothing shipped and one more abandoned plan | Split: this plan is 0.1 → 1 → 0.2 → 3′ (~3–4 sessions, all of it shippable); the rest are named follow-ons in § 14, decision **N** |

Two smaller corrections also applied: `skills/` must **not** be in the
path-ignore list (375 commits in 30 days, more than `bin/`), and the scheduled
full matrix must run the **complete unsplit** Windows Bash set so that step 3′.3
cannot open a silent coverage gap.

**One GLM claim not adopted:** it listed six poll loops. There are seven —
line 148 as well. Verified with
`grep -n 'for _i in $(seq' tests/test-ai-grok-review.sh`.

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
- **G. Branch protection is turned on as soon as the signal is trustworthy —
  after step 1.2, never before.** *(2026-08-27; AMENDED the same day after GLM
  5.3's review.)* The original wording said "early, not at the end," and that was
  dangerous: `windows-offline` runs the flaky grok suite, so requiring it while
  the races are live would gate **every merge in the repository on a 1-in-3 coin
  flip that no session can attribute** — this plan's own worst failure mode,
  given merge-blocking teeth. If protection must go on sooner for another reason,
  require **`linux-offline` only** until 1.2 passes.
- **M. A session never polls CI in a loop.** It blocks once
  (`gh run watch --exit-status`) or it does something else and comes back. Ten
  minutes of shell timeout per turn, all day, is what one of the two triggering
  sessions actually did. *(2026-08-27, added on GLM 5.3's recommendation — it is
  the cheapest throughput fix in the document and the original draft omitted it
  entirely.)*
- **N. Ship value before elegance.** This plan ends at Phase 3′. The harness
  consolidation, the shared wrapper library, and the backlog cleanup are real and
  are specified in § 14 — as separate plans, each independently shippable. A
  restructure that stalls halfway and leaves nothing working would become entry
  #35 in the backlog it exists to fix. *(2026-08-27, GLM 5.3.)*

### OPEN — implementer's judgment, with criteria

- **H. Exactly which prose paths go in `paths-ignore`** (step 3′.2). *Criteria:*
  a path qualifies only if no test asserts anything about its contents. `**.md`,
  `docs/`, `HANDOFF.d/`, and `plan_*.md` qualify. **`skills/` does not** — it is
  executable instruction content, `tests/test-ai-install-skills.sh` covers it, and
  it saw 375 commits in 30 days. When unsure, leave a path **out** of the ignore
  list: the cost of over-testing is minutes, the cost of under-testing is a
  silent regression.
- **I. Which Bash suites count as platform-sensitive** (step 3′.3). *Criteria:*
  it references Git Bash paths, CRLF, `cygpath`, `AppData`, Windows process trees,
  or a `.ps1` file. When unsure, keep it on Windows — and remember the scheduled
  matrix runs the complete unsplit set either way, so an error here is recoverable
  within a day rather than silent.
- **L. Whether to take over PR #123.** See § 9 Phase 1, and § 13 open question 1.

Decisions **J** and **K** of the earlier draft — the shape of `tests/lib/harness.sh`
and of `bin/lib/ai-common.sh` — moved out with their phases. They belong to the
follow-on plans in § 14 and should be decided there, not pre-committed here.

---

## 9. The plan

Three phases, executed in this order: **0.1 → 1.1 → 1.2 → 0.2 → 3′.** The
numbering is deliberately non-sequential so the step identities stay stable
against the original draft and against GLM 5.3's review, which is what the
`.ai/reviews/` records refer to.

**Phases are context cut points.** Before starting any phase, re-read the phases
after it and check the STATUS table for drift.

---

### Phase 0 (part 1) — Write down the two rules

#### Step 0.1 — Growth rule and CI-waiting rule into `AGENTS.md`

**Change:** add two short rules to `AGENTS.md` (122 lines today).

**Rule one — how the repository is allowed to grow:**

> New provider support, new reviewer behaviour, and new test suites are added by
> extending the shared layer, never by copying an existing wrapper or test
> harness. A pull request that adds a fourth copy of an existing mechanism is
> rejected on that basis alone.

**Rule two — how a session is allowed to wait** (decision **M**):

> Never poll CI in a loop. Block once on the result
> (`gh run watch --exit-status <run-id>`) or do other work and come back. A
> session that spends a turn every ten minutes asking whether a job has finished
> is burning the user's money to learn nothing.

Also link this plan from `AGENTS.md`'s task router.

**Intent:** rule one stops the next session recreating the duplication, which
would make the whole restructure pointless. Rule two is aimed directly at the
"Dotfiles sync" session's failure mode (§ 3) and costs a paragraph.

**Verification gate:**
```bash
grep -q 'never by copying' AGENTS.md && grep -q 'Never poll CI in a loop' AGENTS.md
bash tests/test-workflow-policy.sh
```
Note: `tests/test-all.sh` accepts **no arguments today** — it silently ignores
them. Run the policy suite directly as shown. (An earlier draft of this plan
specified `tests/test-all.sh --only workflow-policy`, a flag that does not exist;
the gate would have silently run everything and looked satisfied. The `--only`
flag arrives in step 3′.4.)

**Dependencies:** none. Do this first, then go straight to Phase 1 — **do not
stop at 0.2**, which now comes later.

---

### Phase 1 — Make red mean something (the unblocking phase)

> The highest-value phase in the plan. Everything downstream assumes a
> trustworthy signal. Nothing else starts until step 1.2 passes.

#### Step 1.1 — Replace all seven poll loops in `tests/test-ai-grok-review.sh`

**Change:** rewrite every poll listed in the § 6.4 table — lines **148, 202, 213,
219, 295, 642, 649**. Confirm the inventory first:

```bash
grep -n 'for _i in $(seq' tests/test-ai-grok-review.sh
```

Line 121 (`for _i in $(seq 1 $#); do :; done`) is an argument-counting idiom, not
a wait. Leave it.

**How it should behave when done — two shapes, pick per loop:**

1. **Waiting for one event** (lines 148, 202, 649's `hold-started` half): block
   until the marker file appears, with a generous safety ceiling that, when hit,
   **fails loudly with a diagnostic** naming what it waited for and what it saw.
   The existing `$TMP/hold-started` marker is the model.
2. **Waiting for a count of things** (lines 213, 219, 642 — "≥2 or ≥3 work
   locks"): there is no single event to wait on, so this legitimately stays a
   poll. **The fix for these is the failure mode, not the mechanism:** a generous
   ceiling, and on expiry a loud failure that prints the expected count, the
   observed count, and the lock directory listing. GLM 5.3 flagged that an
   implementer reading "replace polling with events" would otherwise conclude
   they had failed the step. They have not — this is the correct rewrite for
   these three.

Line 295's cluster needs inspection before you choose; it guards the interrupt
and `remote-uncertain` assertions and is the one the first draft missed entirely.

**Non-negotiable:** every dependent check named in § 6.4 must still assert exactly
what it asserts today. If one cannot be made deterministic without weakening it,
**stop and flag it** — that is a § 1 goal conflict.

**The core defect to remove, stated once:** today, when a poll expires, the
assertion simply runs against unsettled state and reports an ordinary `FAIL`,
indistinguishable from a real regression. **That indistinguishability is the bug.**
Every rewrite must make a timeout say so.

**Access note:** this step needs live `gh` to read PR #123's diff first — see
§ 13, open question 1.

**Verification gate:**
```bash
bash tests/test-ai-grok-review.sh
```
passes locally, **and** no `for _i in $(seq` loop remains except line 121, **and**
the suite runs measurably faster (the fixed 30- and 60-second budgets should
largely disappear). Record before/after timings under `tests/verification/`.

#### Step 1.2 — Prove it, do not assume it

**Change:** none. A measurement step, and it is mandatory.

**How:** run the reviewer suites on Windows CI **10 consecutive times** on `main`
after 1.1 lands, via `workflow_dispatch` — not by opening ten pull requests.
Block on each with `gh run watch --exit-status` (decision **M**; do not poll).

**Verification gate:** **10 of 10 green**, with every run id written to
`tests/verification/reviewer-flake-fix/<UTC>-ten-run-proof.md`.

**Why 10:** the observed failure rate was ~1 in 3. Ten consecutive passes put the
probability that a 33% flake survives undetected below 2%.

If it is not 10 of 10, the fix is incomplete. **Do not proceed.** The entire plan
rests on this.

---

### Phase 0 (part 2) — Now make the signal binding

#### Step 0.2 — Turn on branch protection

**Runs after 1.2. Not before** — decision **G**, and read its amendment note.

**Change:** enable branch protection on `popcre/ai-devops` `main` requiring the CI
check to pass.

**Critical trap.** A previously recorded failure on this account: a ruleset with
**no `bypass_actors`** blocks *everything* from merging, and `gh pr merge --admin`
does **not** bypass a ruleset. Cancelling the run does not help. Configure the
bypass actor for Albert's identity **at the same time** you create the rule.

**Verification gate:**
```bash
gh api repos/popcre/ai-devops/branches/main/protection
```
returns 200 with the expected required check, **and** a throwaway PR with a
deliberately failing check cannot be merged, **and** a throwaway PR with passing
checks can. Both proven, not assumed.

**This step changes repository settings — see § 13.**

---

### Phase 3′ — Verify only what changed (the slim version)

> This replaces the original Phase 3 and absorbs the original 3.4. The
> per-suite path mapping from the original 3.1/3.2 is **deferred** to
> `plan_test-harness-consolidation.md`: GLM 5.3 established that selection does
> not depend on output format, so the coarse cut below captures most of the win
> with none of the harness prerequisite.

#### Step 3′.1 — A fast lane, in its own workflow file

**Change:** create a **separate** workflow file — not a job inside `verify.yml` —
that runs on every change and targets **under 3 minutes**: `bash -n` syntax,
`shellcheck` (today `linux-offline` installs it and never runs it — fix that),
Markdown reachability, and `tests/test-workflow-policy.sh`.

**Why a separate file, not a job:** GitHub withholds a workflow run's logs until
every job in that run finishes (§ 11 trap 3). A three-minute job sharing a run
with a sixty-minute job is not fast in practice — its logs are hostage. This is
the direct fix for the mechanism that trapped the "Flaky reviewer" session.
Original open question 4 asked whether to do this; the answer is **yes**.

**Verification gate:** a throwaway PR shows the fast lane concluding, **with
readable logs**, while the matrix is still running.

#### Step 3′.2 — Coarse path filtering

**Change:** add `paths-ignore` to `verify.yml` so a change touching only `**.md`,
`docs/`, `templates/`, `HANDOFF.d/`, and `plan_*.md` runs the fast lane and
nothing else.

**Deliberately coarse.** No per-suite mapping, no manifest, no new test
infrastructure. Half the repository is Markdown and `docs/` alone saw 258 commits
in 30 days, so this one edit removes a large share of all CI time.

**Trap:** `skills/` saw **375 commits in 30 days — more than `bin/`.** It must
**not** go in the ignore list: skills are executable instructions and
`tests/test-ai-install-skills.sh` covers them. GLM 5.3 flagged that ignoring the
repo's second-busiest path would be the obvious mistake here.

**Verification gate:** a throwaway PR touching only `README.md` runs the fast lane
and no matrix, in under 5 minutes, run id recorded. A throwaway PR touching
`bin/ai-grok-review` runs the full matrix. Both recorded under
`tests/verification/`.

#### Step 3′.3 — Stop Windows re-running the Linux-only suites

**Change:** `tests/test-all.ps1:10` invokes the entire Bash suite before the
PowerShell suites. Identify the genuinely platform-sensitive Bash suites — those
touching Git Bash paths, CRLF, `cygpath`, `AppData`, or Windows process trees —
and run only those under Windows Git Bash. The rest run on Ubuntu only.

**This is roughly half the 62-minute Windows matrix** and it depends on nothing
in Phase 3′.1–2; it can land in parallel.

**Trap — a real, previously recorded failure.** A checkout once rewrote every
script to CRLF: harmless in Git Bash, fatal in WSL bash, so no session saw it.
`git grep` cannot detect line endings — `git ls-files --eol` can. Keep that class
of bug covered.

**Mandatory safety net (GLM 5.3):** a hand-built platform list creates a new
silent gap — a suite that later *becomes* Windows-sensitive stops running there
and nothing notices. So the scheduled full matrix (step 3′.5) must run the
**complete, unsplit** Windows Bash set. Pin that explicitly; "full matrix" is not
specific enough.

**Verification gate:** Windows lane time drops substantially (record before and
after), **and** a deliberately introduced Windows-only defect — e.g. a hard-coded
forward-slash path in a wrapper — is still caught. Write the experiment up under
`tests/verification/`.

#### Step 3′.4 — A local entry point that is not "run everything"

**Change:** give `tests/test-all.sh` two arguments: `--only <pattern>` and
`--changed-since <ref>` (the latter selecting by the coarse categories from
3′.2, not a per-suite map).

**Why this is in the slim plan:** the 62-minute figure is CI. The "Flaky reviewer"
session burned six hours on **local** full-suite runs. A panicking session needs
a smaller hammer within reach, and this is the cheapest one.

**Requirement:** with no arguments the behaviour is **byte-identical to today** —
run everything. Other machines call this script.

**Verification gate:** `tests/test-selection.sh` asserts that no arguments selects
all 53 suites; `--only grok-review` selects one; `--changed-since` on a docs-only
range selects none.

#### Step 3′.5 — Rewrite `tests/test-workflow-policy.sh` and add the scheduled matrix

**Change:** the full matrix moves to a schedule plus push-to-`main`, not every PR.
It is the safety net for whatever 3′.2 and 3′.3 miss, and it must run the
complete unsplit Windows Bash set (3′.3).

`tests/test-workflow-policy.sh` currently asserts `windows-offline` has **at least
75 minutes** of timeout, which the new shape will not satisfy. Rewrite it to
protect the new invariants: every job bounded; the fast lane exists, is in its own
file, and is genuinely fast; the concurrency block is intact (decision **E**);
nothing that asserts behaviour carries `continue-on-error`; the scheduled matrix
runs the unsplit Windows set.

**Do not** make it snapshot YAML trivia — exact job lists, shard counts, or
timeout numbers. Grok 4.6 flagged the first draft for freezing an unmeasured
structure that any honest follow-up would have to break, and for replacing a
"≥ 75 minutes of measured headroom" assertion with an arbitrary "≤ 60" one.

**Mandatory:** the scheduled matrix must **open an issue on failure**, or it
becomes wallpaper nobody reads. This is in the risks table for a reason.

**Verification gate:** the rewritten policy test passes; a deliberately unbounded
job makes it fail; a forced failure of the scheduled matrix opens an issue.

---

## 10. Tests required

### New tests this plan adds

| Test | Step | Asserts |
|---|---|---|
| `tests/test-selection.sh` | 3′.4 | no args → all 53 suites; `--only grok-review` → one; `--changed-since` over a docs-only range → none |
| `tests/test-workflow-policy.sh` (rewritten) | 3′.5 | see below |

Deliberately **not** here — they belong to the follow-on plans in § 14:
`tests/test-harness.sh`, `tests/test-harness-adoption.sh`, the per-suite
coverage-mapping test, and the plan-reachability test.

### Existing tests that must stay green throughout

- `bash tests/test-all.sh` — the full Bash suite, at every step.
- `pwsh -File tests/test-all.ps1` — on Windows, at every step.
- `bash tests/test-ai-grok-review.sh` — the direct gate on Phase 1.
- `tests/test-workflow-policy.sh` — **must be rewritten in step 3′.5.** It
  currently asserts `windows-offline` has **at least 75 minutes** of timeout,
  which the new shape will not satisfy. Rewrite it to protect the new invariants:
  every job bounded; the fast lane exists, lives in its own workflow file, and is
  genuinely fast; the concurrency block is intact (decision **E**); nothing that
  asserts behaviour carries `continue-on-error`; the scheduled matrix runs the
  complete unsplit Windows Bash set.
  **Do not** make it snapshot YAML trivia — exact job lists, shard counts, or
  timeout numbers. Grok 4.6 flagged exactly that in the first draft, which had
  replaced a "≥ 75 minutes of measured headroom" assertion with an arbitrary
  "≤ 60 minutes" one and frozen a job list that any honest follow-up would break.

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
2. **CRLF is invisible to `git grep` (step 3′.3).** Use `git ls-files --eol`. A
   past checkout rewrote every script to CRLF — harmless in Git Bash, fatal in
   WSL bash, so no session noticed.
3. **GitHub withholds a run's logs until every job in that run completes**
   (§ 6.2). This is why step 3′.1 puts the fast lane in its **own workflow file**:
   a fast job sharing a run with a 60-minute job has its logs held hostage, which
   is precisely what trapped the "Flaky reviewer" session.
4. **`continue-on-error: true` at job level makes GitHub report that job as
   successful to anything that `needs` it.** If Phase 3 introduces any advisory
   job, it must never appear in a gate's `needs`.
5. **A matrix job's aggregate result treats mixed success-and-skipped as
   success.** Relevant if any later work adds per-shard conditions.
6. **The wrappers are installed onto machines.** Not a trap for this plan, but the
   first thing `plan_wrapper-shared-library.md` (§ 14) must resolve: confirm the
   install mechanism carries `bin/lib/` before introducing a sourced dependency,
   or every machine breaks silently.
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

Complete when all of the following are true and each is backed by an artifact
cited in the STATUS table:

- [ ] `AGENTS.md` carries **both** rules — no-duplication growth, and never poll
      CI in a loop — and links this plan.
- [ ] All seven poll loops in `tests/test-ai-grok-review.sh` are gone (only the
      argument-counting idiom at line 121 remains), and every timeout now fails
      loudly with a diagnostic.
- [ ] 10 consecutive green Windows reviewer runs, run ids recorded in
      `tests/verification/reviewer-flake-fix/`.
- [ ] Branch protection is on, proven by a throwaway PR that could **not** merge
      red and could merge green.
- [ ] The fast lane lives in its own workflow file and concludes with readable
      logs while the matrix is still running.
- [ ] A pull request touching only Markdown completes CI in **under 5 minutes**,
      run id recorded. `skills/` is **not** in the ignore list.
- [ ] A pull request touching `bin/ai-grok-review` runs the full matrix, run id
      recorded.
- [ ] The Windows lane no longer re-runs the Linux-only Bash suites; before/after
      timings and the injected-Windows-defect experiment written up under
      `tests/verification/`.
- [ ] `tests/test-all.sh --only` and `--changed-since` work; no-argument
      behaviour is unchanged; `tests/test-selection.sh` proves all three.
- [ ] The scheduled matrix runs the **complete unsplit** Windows Bash set and
      **opens an issue on failure**.
- [ ] `tests/test-workflow-policy.sh` rewritten, passing, and not snapshotting
      YAML trivia.
- [ ] The double-billing precondition (§ 6.5) is answered; if yes, an issue is
      open with evidence.
- [ ] Every commit pushed; every PR merged by the implementing session, not by
      Albert.
- [ ] `session-docs-update` run, this plan de-staled, and a `HANDOFF.d/` file
      written for whatever remains open.
- [ ] The three follow-on plans in § 14 exist as files with STATUS tables, or the
      decision not to write them is recorded with reasons.

### Measured outcome to check at the end

Take the § 1 measures, not a step count:

1. Docs-only CI median **under 5 minutes** (was ~62).
2. `bin/`-only CI median recorded — this plan does not promise to move it much;
   the follow-ons do.
3. Session outcome ratio — landed commit vs. handoff — improving.

Secondary: open PRs with no commit in 3+ days, currently **5 of 9**.

**If the wall-clock numbers have not moved, the restructure did not achieve its
§ 1 goal regardless of how many boxes are ticked above.**

### Risks and rollback

| Risk | Likelihood | Mitigation / rollback |
|---|---|---|
| Coarse path filtering skips a suite that mattered | Medium | The scheduled full matrix catches it within a day and opens an issue; the filter is `paths-ignore` on prose only, and `skills/` is deliberately excluded from it |
| Step 3′.3's platform split opens a silent gap as a suite later becomes Windows-sensitive | Medium | The scheduled matrix runs the **complete unsplit** Windows Bash set — this is why that is pinned rather than left as "full matrix" |
| Phase 1 collides with PR #123 | High | Open question 1; read its diff before writing any code |
| Branch protection locks everyone out | Low but severe | `bypass_actors` configured at creation; proven with a throwaway PR before relying on it (§ 11 trap 1) |
| Branch protection lands before the flakes are fixed | Was **certain** in the first draft | Step 0.2 now runs after 1.2; decision **G** carries the reasoning so it is not re-ordered back |
| The scheduled matrix becomes the new ignored red | Medium | It must open an issue on failure — a definition-of-done item, not a suggestion |
| This plan itself stalls and becomes plan #35 | Medium | Decision **N**: every step here ships value on its own, and the expensive work is in § 14 behind a gate |

### Open questions

1. **Who fixes the racing tests — this plan's implementer, or PR
   [#123](https://github.com/popcre/ai-devops/pull/123)?** That PR is titled
   "derive reviewer test timing budgets from a measured baseline," is currently
   green, and its session has been idle since 2026-08-27T15:44Z after 24 hours
   without progress. **Decision criteria:** if its approach is "make the timeout
   budget bigger," it treats the symptom and step 1.1 supersedes it — close it
   with an explanation. If it genuinely removes the polling, adopt it and mark
   1.1 done citing its merge SHA. **Read the diff before deciding** — this needs
   live `gh` at the start of step 1.1, not later.
   *This is decision **L**, and it is the one thing this plan does not settle.*
2. **Can GLM, Kimi, and Qwen double-bill today** for want of the `remote-uncertain`
   protection (§ 6.5)? Answer this during Phase 1 — it is a **precondition** to
   the wrapper follow-on, not an open question. If yes, open an issue immediately.
3. **How is `bin/` installed onto a machine?** Needed by
   `plan_wrapper-shared-library.md`, not by this plan. Answer it before writing
   that plan, since it determines whether a sourced library is even possible.

---

## 14. Follow-on plans — real work, deliberately not here

Decision **N**. Each is independently shippable and **gated on Phase 3′ landing.**
The evidence for all three is already in §§ 5–6 of this document; a follow-on
plan should cite those sections rather than re-derive them.

### `plan_test-harness-consolidation.md`

**Why:** `ok`/`bad`/`skip`/`check` are copy-pasted into ~24 suites in divergent
forms (§ 5.1). This is what made the rejected quarantine design unbuildable
(§ 7.A) and what makes per-suite path mapping expensive.

**Shape:** build `tests/lib/harness.sh` with a canonical machine-readable output
format **in the same step** — the format must exist before the migration, because
the migration's own gate is comparing pass/fail totals across suites. Migrate one
suite per commit. Then add per-suite path mapping and refine step 3′.2's coarse
filter into real selection.

**Watch out for:** the `fail(){ echo "FAIL: $*"; exit 1; }` pattern is not
equivalent to `bad()` — it aborts the suite rather than recording a failure and
continuing. Decide per case whether that abort was intentional. Also: a gate of
"full `test-all.sh` before and after each of ~24 commits" is 16–24 hours of
Windows runtime, so do this after 3′.4 exists and a narrower run is available.

**Estimate:** 3–5 sessions.

### `plan_wrapper-shared-library.md`

**Why:** ~25 helper functions reimplemented across four wrappers, no `bin/lib/`
at all (§ 5.4), and the lock has already diverged into incompatible policies
(§ 6.5).

**Shape:** extract the provably-identical helpers first (`die`, `warn`, `note`,
`need`, `valid_name`, `repo_root`, `repo_remote`, `repo_id`, `meta_path`,
`find_meta`, `write_meta`). Move wrappers one per commit — `ai-qwen` first
(smallest, and its lock is byte-identical to Kimi's), `ai-grok-review` last.

**The lock needs its own design round before any code.** § 6.5's table is the
input: Grok refuses immediately with a nine-argument signature; GLM waits with a
timeout, has a different signature and a user-visible error message, and has
**three** lock functions with three deliberate policies. A shared lock must
express all three policies, or the scope must shrink to Kimi and Qwen only.

**Watch out for:** the wrappers are installed executables — confirm the install
mechanism carries `bin/lib/` before introducing a sourced dependency, or every
machine breaks silently. Check `tests/test-installer-parity.sh` first. And a gate
of "run the § 6.4 checks against all four wrappers" silently requires building
three new concurrency stub harnesses: Kimi's suite has two basic concurrency
checks and GLM's has one. Count that work rather than discovering it.

**Estimate:** 2–4 sessions, plus 2–3 for the stub harnesses.

### `plan_backlog-consolidation.md`

**Why:** 34 `plan_*.md` files at the repository root, eight of them per-provider
reviewer repair plans describing one class of problem eight times (§ 5.5).

**Shape:** triage each — done, abandoned, or open. Delete the done ones (git
history keeps them). Give every open one a STATUS table. Reconcile the eight
repair plans into the existing `plan_reviewer-system-repair.md` — do not create a
thirty-fifth file. Add a test that fails on an unreferenced plan file.

**Sequencing note:** this genuinely comes last. Consolidating eight plans into
one before the code they describe is unified just moves the duplication into
prose.

**Estimate:** 1–2 sessions. Several of these plans describe live systems; read
them rather than judging by filename.

---

## Self-audit (mandatory gate — preserved per the plan standard)

Re-run 2026-08-27 after GLM 5.3's review and the seven resulting changes. The
first run of this audit passed on a plan that GLM then found six real defects in,
so the questions below are answered against the **revised** document only, and
each answer names what changed.

**1. Could a brand-new AI session with no project knowledge and no context from
this conversation execute this plan to perfection, without asking anything?**

Yes, with one deliberate exception.

§ 2 defines the repository, its machines, its identities, and why the wrappers
are safety-critical. § 3 quotes the triggering report verbatim and names both
stalled sessions and their PRs. § 5 gives the current state with line numbers,
measured counts, and the verified 404 proving there is no branch protection.
§ 9 names concrete files and line numbers per step with a verification gate on
each. § 11 carries the traps a newcomer cannot know — the ruleset bypass trap,
CRLF invisibility, the worktree stash hazard, the `gh pr merge` false negative,
the log-withholding mechanism. § 12 records what is authenticated and what costs
money.

Four specific stop-points that the first version contained are now closed:

- § 6.4 was internally inconsistent ("nine" checks, eight named) and step 1.1's
  instruction matched five of the seven real poll loops. Both are now a verified
  line-numbered table with the grep command to re-derive it.
- Step 0.1's gate invoked `tests/test-all.sh --only`, **a flag that does not
  exist**; the gate would have silently run everything and looked satisfied. It
  now uses the real command and says why.
- Step 1.1 said "replace polling with events," which is impossible for the three
  lock-*count* waits; an implementer would have concluded they had failed. It now
  gives two rewrite shapes and says explicitly that a bounded poll with a loud
  failure is the correct answer for those three.
- A fresh session starting at 0.1 immediately hit "this step needs Albert" at
  0.2, which the repository's own rules forbid ending a session on. 0.2 now comes
  after 1.2 and the STATUS table says so.

The remaining exception is open question 1 (decision **L**): whether to take over
another live session's PR. It is stated with explicit decision criteria so an
implementer can proceed without Albert, and it is in the risks table.

**2. Does the plan carry every piece of background, nuance, and reasoning
currently held — including what was ruled out and why?**

Yes. § 7 records six items. 7.A (the flaky-check quarantine) and 7.B (6/6/3
sharding) were the author's own first design, each with the four or five verified
reasons it failed — 24 suites print an unparseable failure format; four checks
were quarantined where nine were affected; 18 machines per push versus 3; the
deleted fast lane. 7.C records the output-buffering trap. **7.F is new**: a
change-by-change record of what GLM 5.3 required and why, so nobody restores the
earlier ordering — including the one item it called actively harmful (branch
protection before the flake fix).

§ 6.5 now carries the per-wrapper lock table that killed the naive "adopt Grok's
lock everywhere" instruction: GLM waits with a timeout, Grok refuses immediately,
the signatures differ, and GLM has three lock functions with three deliberate
policies. § 8 separates nine locked decisions from three open ones, with decision
**G** amended in place rather than silently reordered, so the reasoning survives.

One place this plan disagrees with its reviewer and says so: GLM counted six poll
loops; there are seven. Recorded at the end of § 7.F with the command to verify.

**3. Is the ultimate goal stated clearly enough that the implementer could make a
correct judgment call if a step turns out to be wrong?**

Yes. § 1 states the goal in plain business English before any technical wording,
names the three conditions that must become true, and carries the instruction
that the goal wins over any step — with three concrete tests for recognising a
violating step: slower verification, less trustworthy red, or another copy of
something that already exists.

The success measure was the weakest part of the first version. "Stalled open PRs
go to zero" was gameable — this repository works directly on `main`, most
sessions never open a PR, and the plan itself mandates self-merge and installs a
bypass actor. § 1 now leads with two measures that fall out of gates the plan
already requires (docs-only and `bin/`-only CI wall clock; landed-commit versus
handoff ratio) and demotes stalled PRs to a secondary smell, with today's figure
recorded as 5 of 9. § 13 repeats them and states plainly that if the wall-clock
numbers have not moved, the restructure failed regardless of ticked boxes.

**4. (Added) Is this plan actually completable?**

GLM estimated the original at 12–20 focused sessions with nothing user-visible
landing until Phase 3 — which would have made it entry #35 in the backlog it
exists to fix. The plan now ends at Phase 3′ (~3–4 sessions), every step of which
ships value on its own: unambiguous red, minutes-scale docs CI, half the Windows
matrix removed, gated merges. The three expensive pieces are specified in § 14 as
named follow-on plans gated on this one landing. Decision **N** records the
principle so a later session does not re-merge them.

**Checklist grade:** all 13 required sections present, plus § 14; goal-wins
instruction present; rejected approaches recorded with verified reasons, including
both reviewers'; every step names files and line numbers and has a verification
gate; locked and open decisions labeled; explicit out-of-scope list that names
where the excluded work went; tests named individually; every identifier, SHA, and
path defined; no secret values; definition of done includes commit, push, CI,
merge-by-implementer, and the follow-on plans; plan and handoff cross-link.
**All items pass.**
