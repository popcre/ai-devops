# Must address — review of `plan_ai-devops-work-claims.md`

**Reviewer:** Claude (Opus 5), session `github-org-move-handoff-d576f2` on `edge-dev`
**Date:** 2026-08-27
**Reviewed head:** `plan_ai-devops-work-claims.md` (412 lines) in
`C:\Users\ahazan\.codex\worktrees\ai-devops-work-claims-plan-revision`,
branch `codex/revise-work-claims-plan-131`, tracking issue
[popcre/ai-devops#131](https://github.com/popcre/ai-devops/issues/131).

**Standing:** this reviewer wrote the lightweight claims-file recommendation that
§3 and §7.2 reject, and authored `plan_repo-throughput-restructure.md` (merged in
PR [#128](https://github.com/popcre/ai-devops/pull/128) at `aaf2255a`). Read the
conflict of interest into every finding below and check the data, not the
conclusion.

**Verdict: the mechanism is sound and the rejections are correct. The sequencing
is wrong, the cost is not justified by the measured collision rate, and four
locked decisions would actively make this repository worse if built as written.**

This review is in two parts, because the second is the one usually missing:

- **Part A — what is missing** (findings 1–4): evidence, measurement, scope line.
- **Part B — what is present and harmful** (findings 5–9): specific locked
  decisions in §8 and §9 that would cost throughput, block ordinary work, or
  produce silent wrong behavior. These are not omissions. They are things to
  delete or change before any code is written.

---

## 0. What this review is not disputing

Stated first so the disagreement is not read as broader than it is.

- **Refs-as-admission is right.** §6.3 and §6.4 are correct: create-only refs give
  atomic admission, REST has no compare-and-swap, so force-with-lease plus exact
  readback is the only safe mutation path. This is a real improvement over every
  earlier design, mine included.
- **§7.2 correctly kills my claims file.** Branch-local staleness and the file
  becoming its own contention point are both real.
- **§6.5 — automatic expiry creates split-brain — is the best finding in the
  document.** A disconnected writer editing past its lease is exactly the failure
  a naive lease design ships with.
- **§6.6 is empirically grounded.** `bin/ai-completion-check-hook` exists because
  wording alone did not hold. Mechanical fencing over prose is correct.
- **Dropping component refs (§7.16) and excluding `AGENTS.md` (§6.10) are both
  correct**, and both were made against the author's own earlier draft.

The findings below are about **sequencing, scale, and four specific harms.**

---

# PART 0 — the measurement that decides the sequencing

Added 2026-08-27 after finding 1 was challenged. Finding 1 argued from the two
stalled sessions. This is the repository-wide number, and it is stronger.

## The merge queue is the bottleneck for everything, and it is not a slow queue — it is an unreliable one

**Measured 2026-08-27 on `popcre/ai-devops`, from the last 13 merge-queue runs:**

| Outcome | Count |
|---|---|
| success | **7** |
| failure | **4** |
| cancelled | 2 |

**Median duration of a completed verification run: 59–73 minutes** (sampled
across the last 9 completed pull-request runs: 73, 73, 62, 65, 59, 65, 56, 65,
68).

Eight changes did land on `main` on 2026-08-27, so the claim "nothing ever
merges" is false and should not be used to justify anything. **The true shape is
worse than slow: it is just over a coin flip, resolved one hour at a time.**

**Why that specific shape is what destroys throughput.** A queue that is reliably
slow is survivable — you batch your work and wait. A queue that succeeds ~54% of
the time, an hour per attempt, produces:

- A typical change needing ~2 attempts, landing in 2–3 hours.
- Failures arriving an hour after the author stopped watching.
- No way to distinguish "I am blocked" from "I was unlucky" without reading logs
  that GitHub withholds until the slowest job in the run finishes.
- **Ejection of unrelated work.** The queue groups up to 5 entries with `ALLGREEN`
  semantics, so one flaky failure discards the batch and every author in it pays
  another hour. Observed directly: run `33100525687`, a merge-group run headed by
  PR #127 (a skills-index change), failing the four issue-#89 reviewer checks by
  name.

**This is measurably the largest single tax on the repository.** Every plan,
every fix, every document — including this review — pays it. No other inefficiency
in `ai-devops` is charged against 100% of changes.

## What this means for the work-claims plan specifically

Two consequences, and the second is the one to act on.

**First, it settles the sequencing dispute in finding 1.** The work-claims plan
addresses duplicated *intent*, which is real (8 duplicate reviewer repair plans, 2
sessions on issue #89 at once) but is charged against a minority of work. The
queue is charged against all of it. Fix the thing every change pays for first.

**Second, and this is the harmful part: the plan proposes to add a third required
check to this exact queue** (finding 5). At a 54% pass rate with `ALLGREEN`
grouping, another required check is another independent way for a batch to be
discarded — and `work-claim-guard` as specified fails closed on GitHub API
ambiguity, malformed trailers, moved head SHAs, and closed task issues. Adding it
as *required* while the queue is in this state is not a marginal cost. It is a
direct multiplier on the repository's largest existing tax.

## The proposed fix — one change, already diagnosed, roughly an hour of work

The dominant failure in the queue is the issue-#89 reviewer flake. It is **not** an
open investigation. The cause is confirmed with line numbers:

- `tests/test-ai-grok-review.sh:216` calls `ai_test_measure_baseline` **exactly
  once**, near the top of the suite, and sets a global.
- `budget FACTOR FLOOR` returns `max(AI_TEST_BASELINE * FACTOR, FLOOR)`, so
  **every** ceiling in the file derives from that single frozen sample.
- The failing wait sits around line 730 — several hundred seconds later.

A machine that degrades after the measurement is judged against a computer that
no longer exists. Confirmed by the run series: the one failing run of six was the
**slowest in the series** (990s against 728–834s), with a 12s baseline giving a
180s ceiling, while the library's own header documents a wrapper round trip at
~15s idle, 26–42s with two suites, and 82s under a four-suite storm. The
concurrency block needs **two** round trips to overlap, making it the most exposed
assertion in the file.

**The fix: make the wait progress-sensitive rather than deadline-sensitive.** Keep
waiting while the observed state is still advancing — one lock has appeared, the
second has not — and fail only when nothing has changed for N seconds. This
preserves exactly what the check exists to detect (a genuine hang) while
tolerating a slow machine, which is the distinction a fixed ceiling cannot make at
any value. Re-measuring the baseline immediately before the concurrency block is a
cheaper stopgap that treats the symptom.

**Do not raise the multiplier, add retries, or mark the check allowed-to-fail.** A
ceiling large enough for a degraded machine no longer detects the hang the check
exists to catch, and this test guards paid-work locking. Decision **B** of
`plan_repo-throughput-restructure.md` forbids weakening a test to make a lane
green.

**Expected effect.** The flake already fell from ~33% to ~17% of runs when the
budgets became measured rather than fixed, and the blast radius fell from four
checks to one. Removing the frozen-baseline dependency addresses the confirmed
cause of the remainder. Verification is the run series taken to ten, not a single
green run — a single green run is precisely what made this look finished the first
time.

## Recommended order of work

1. **Make the reviewer suite deterministic** (above). One change, ~1 hour, closes
   the dominant queue failure.
2. **Cut the verification cost** — path filtering so docs-only changes skip the
   matrix, and stop Windows re-running the Linux-only Bash suites. Phase 3′ of
   `plan_repo-throughput-restructure.md`.
3. **Then build work claims**, smaller, with findings 5–9 applied — and add
   `work-claim-guard` as an **advisory** check, promoting it to required only
   after the queue's pass rate is measured and stable.

Doing 3 before 1 spends effort on a minority tax while increasing the majority
one.

---

# PART A — what is missing

## 1. BLOCKING — the plan is second in line, and it competes for the scarce resource

**§3 claims duplicated work is the expensive failure. The measured evidence says
ambiguous red is.**

The two sessions that triggered this workstream — reported by Albert on
2026-08-27 as "running for 24 hours … making no progress" — were **not colliding
with each other.** Each was independently stuck behind:

| Cost | Measurement | Source |
|---|---|---|
| Reviewer suite failure rate, pre-fix | ~33% | issue #89 history |
| Reviewer suite failure rate, post-#123 | 1 in 6 (~17%) | `tests/verification/reviewer-flake-89/2026-08-27-ten-run-series.md` |
| `windows-offline` timeout budget | **75 minutes** | `.github/workflows/verify.yml:44` |
| `linux-offline` timeout budget | 45 minutes | `.github/workflows/verify.yml:24` |
| Logs visible before the slowest job in a run finishes | **none** | GitHub withholds run logs until every job in the run completes |
| Merge-queue grouping | `ALLGREEN` | ruleset `21564317` |

A claim ref would not have shortened either session by one minute. Neither would
have been refused a claim, because neither was a duplicate when it started.

**Live proof that the flake, not collision, is the merge gate:**
`tests/verification/reviewer-flake-89/2026-08-27-merge-queue-ejection.md` records
run `33100525687`, a `merge_group` run headed by PR #127 — a skills-index change,
unrelated to reviewer wrappers — failing exactly the four issue-#89 checks by
name, on a **required** status check, inside an `ALLGREEN` queue.

**Must address:** state in §1 or a new §3a where this plan sits relative to the
flake fix and CI verification cost, and why. If the answer is "first", justify it
against the table above.

## 2. BLOCKING — the §3 collision evidence is unciteable, and what is measurable is small

§3 cites "approximately 72 Claude and 103 Codex ai-devops sessions" from a
**private transcript review**, and lists five measured problems with no counts, no
dates, and no rerunnable source. §11 forbids transcript excerpts in this public
repository, so that evidence is **structurally unciteable**, and §13's own STATUS
rule ("never unsourced counts") is violated by §3.

Independently measurable, taken 2026-08-27 across the 9 then-open pull requests:

| Signal | Value |
|---|---|
| Files touched by more than one open PR | **3** — `AGENTS.md` (3 PRs), `docs/architecture.md` (2), `tests/test-ai-kimi.sh` (2) |
| `AGENTS.md` commits, 30 days | 72 |
| `tests/test-ai-grok-review.sh` commits, 30 days | 38 |
| `bin/ai-grok-review` / `ai-kimi` / `ai-glm` commits, 30 days | 32 / 27 / 27 |
| Per-provider reviewer repair plans for one problem class | **8** |
| Sessions independently working issue #89 at once | **2** |

**This cuts both ways, and the plan should say so.** The bottom two rows are real
and they are the plan's best justification — eight repair plans for one problem
class, two sessions on #89 simultaneously. §6.1 is right that no merge strategy
prevents that.

But the **file**-collision rate that §3 leans on is three files across nine pull
requests, and the three real conflicts hit during the throughput session (a
duplicate commit already on `main` under another SHA, an immediate PR conflict, a
worktree already claimed) each cost **minutes**.

**Must address:**

1. Move the two rows that matter into §3 with a rerunnable derivation; drop or
   explicitly mark the unciteable transcript counts. A count nobody can reproduce
   cannot survive the independent review §9.11 demands.
2. State the expected saving in sessions or hours, so it can be weighed against
   twelve steps and thirty-three tests. Right now the cost is justified by
   assertion.

## 3. BLOCKING — nothing in the plan measures whether it worked

§13 has 13 definition-of-done checkboxes and **not one measures a reduction in
duplicated work.** Every box is implementation completeness: the command exists,
tests pass, docs link, the PR merged.

By its own criteria this plan is "done" on a repository where two sessions still
duplicate a fix, so long as the tool that would have prevented it is installed and
green.

**Must address:** add a measurement gate — re-run the finding-2 counts 30 days
after landing, naming the exact commands that produce them. If duplicated work has
not fallen, the machinery did not earn its cost and the plan says so in writing.

## 4. MAJOR — v1 is roughly three times its own minimum viable version

Counted from the plan: **12 numbered steps, 33 named tests, 4 phases, 2 new
config/policy files, a custom ref namespace requiring live qualification, local
git hooks on a shared git directory across worktrees, a new required CI job, and a
takeover procedure needing Albert's typed authorization per use.**

The plan already knows how to cut. §7.16 dropped component refs on exactly this
reasoning — they "introduce partial-acquisition/livelock risk before evidence
shows that machinery is needed." Applied consistently, that test removes more.

**Must address:** define an explicit v1 line. A defensible one: task-only refs;
`acquire` / `heartbeat` / `bind-head` / `verify` / `release` / `status` /
`doctor`; an **advisory** CI guard; no local hooks; no work-units; no takeover,
with `doctor` reporting stale claims for manual resolution until real data
justifies automating it. Roughly steps 9.1–9.5 plus an advisory 9.7, shippable in
a fraction of the time.

---

# PART B — what is in the plan that would be a detriment

Everything above is an omission. Everything below is **present, locked, and
harmful.** Each item names the exact text, the damage, and the change.

## 5. HARMFUL — making `work-claim-guard` a required check on ruleset `21564317`

**Where:** §8 LOCKED ("Mechanical fencing is required: … plus a required PR
check"), §9.7, §13 definition of done.

**The damage.** The merge queue on `main` uses `ALLGREEN` grouping: one failing
entry ejects the whole batch, up to five pull requests, and every ejected author
pays a full re-run. `windows-offline` already fails roughly one run in six and
takes up to 75 minutes to say so. This plan adds a **third required check** to
that queue — one that fails closed on GitHub API ambiguity (finding 6), on a
forgeable trailer being malformed, on a head SHA that moved, and on a task issue
closing at the wrong moment (finding 8).

Each of those is a new way for an unrelated pull request to be ejected from a
batch it had nothing to do with. The plan's stated goal in §1 is that "unrelated
work … must remain concurrent." A required check with those failure modes, on an
`ALLGREEN` queue, does the opposite.

There is a second-order harm the plan does not consider: **every required check
must pass on merge-group runs too**, so a claim guard that misfires blocks the
queue itself, not just one PR — and the logs explaining why stay hidden until the
75-minute `windows-offline` sibling finishes.

**The change.** Ship the guard **advisory** in v1. Measure ejections attributable
to it over 30 days. Promote it to required only if the ejection count is zero and
finding 6 is resolved. §13's "otherwise status remains partial and issue stays
open" should be inverted: advisory **is** the complete v1 state, not a degraded
one.

## 6. HARMFUL — fail-closed on network ambiguity, applied to local `commit`

**Where:** §8 LOCKED ("Network/API ambiguity fails closed for acquire, renew,
verification, release, and takeover. No local fallback grants ownership") and
§9.6 ("It must block commit/push when … network verification unavailable").

**The damage, with a measured precedent.** On 2026-08-27 this repository's own
tooling produced `HTTP 403: API rate limit exceeded` from concurrent
`gh run watch` processes — a **secondary**, rate-based limit. Throughout,
`gh api rate_limit` reported core **5000/5000 remaining**, and `gh pr view` kept
working while `gh run list` and `gh run view` were refused. Recorded in memory as
`gh-run-watch-burns-the-api-quota`.

Under §8 and §9.6 as written, that condition makes **every session in the
repository unable to commit** — not merely unable to acquire a new claim. Sessions
that already own their claims, are working entirely within their declared paths,
and have verified successfully minutes earlier, are stopped. And it surfaces as a
blocked git hook with a verification failure, not as a rate-limit message, so each
blocked session then burns a turn diagnosing GitHub.

That is the exact failure mode this workstream exists to eliminate, reintroduced
by the fix. It is also self-amplifying: blocked sessions poll GitHub to find out
why, which is what caused the throttle.

**The change.**

1. Split the rule. Ambiguity must fail closed for **acquire, release, takeover,
   and push/PR** — that is where the ownership risk is. It must **not** fail
   closed for `commit` when the session holds a claim whose last successful
   verification is recent (the plan already has an 8-hour healthy window; reuse
   it). A local commit publishes nothing and is fully reversible.
2. Specify the exact user-facing message for the throttled case, naming the
   secondary limit and telling the session **not** to poll. A guard that cannot
   explain itself under load is worse than no guard.

## 7. HARMFUL — local git hooks installed into a shared git directory

**Where:** §9.6, and the §8 lock that makes local fencing required.

**The damage.** §9.6 concedes the hard part itself: linked worktrees share one
common git directory, so hook install/uninstall is **repository-wide, not
worktree-local**, must chain any pre-existing hook, must be idempotent under
concurrent installs, and must never let one worktree uninstall a dispatcher other
worktrees still need. This session alone is operating four worktrees of this
repository simultaneously.

So the plan's most fragile, most machine-specific, hardest-to-test code is also
the code that can **break every session on the machine at once** — including
sessions doing unrelated work in other worktrees, and including the ability to
commit the fix for the hook itself. There is no rollback path that does not
require committing, which the broken hook blocks.

And what does it buy? Against a **cooperating** session — which the plan's own
threat model in §8 says is the only kind that exists, since "all sessions share
Albert's GitHub authority and could bypass the tool" — the hook buys *earlier*
notice of a mistake the CI guard already catches before anything merges.

**The change.** Cut local hooks from v1 entirely. Let the session call
`ai-work-claim verify` when it chooses, and let CI be the fence. Revisit only if
measurement shows sessions actually publishing unclaimed work, which is currently
an assumed failure, not an observed one.

## 8. HARMFUL — blocking work when the task issue closes

**Where:** §9.5 ("If the task issue closes mid-work, `verify-owned` blocks further
editing/publication. The owner must either release and stop, or obtain authority
to reopen the same issue").

**The damage.** The normal ai-devops pattern is that a pull request closes its
issue on merge and follow-up work continues immediately. This session did exactly
that on issue #89 three separate times: land a fix, observe the result, correct
the follow-on. Under this rule, the instant the PR merges, the owner is blocked
from committing the follow-up and must go get authority to reopen an issue that
was correctly closed.

This does not prevent a collision. It converts the single most common workflow in
the repository into a stop, and the stop lands at the worst possible moment —
right after a merge, when the session is mid-flow and has context that a
successor would have to rebuild.

**The change.** Either grant a bounded grace window after task close during which
the existing owner may continue and publish, or auto-release on close with a clear
message naming the follow-up claim to take. Do not stop the session dead.

## 9. HARMFUL — §6.3 states an unproven API behavior as an established finding

**Where:** §6.3 ("Create-only Git refs provide atomic admission. A single fully
qualified task-ref name has one successful creator; a competing create receives
conflict/validation failure"), listed under **Key findings**, while §9.1 is still
scheduled to *prove* it.

**The damage.** A findings section is what successors and reviewers quote without
rechecking. Two assumptions are load-bearing and currently ungated: that a
competing create returns non-success **without changing the ref**, and that
`--force-with-lease` behaves identically against a **custom** namespace as against
`refs/heads/*`, on both Windows Git Bash and Ubuntu.

There is direct precedent in this repository for a plausible API belief being
wrong and surviving multiple reviews: `gh api repos/OWNER/REPO/branches/main/protection`
returns `404 Branch not protected` for a branch fully governed by rulesets. That
404 was read as "nothing gates merges" by **this reviewer, by Grok 4.6, and by
GLM 5.3** — three independent reviews, same wrong conclusion — and it inverted a
plan step from "turn on protection" to "protection is already gating every merge
on a test that fails one run in three." Recorded as memory
`branch-protection-404-hides-rulesets`.

**The change.** Reword §6.3 as a hypothesis pending the §9.1 artifact, and add
**both platforms** to §9.1's force-with-lease gate. The whole design rests on this
one behavior; it should be the most heavily evidenced claim in the document, not
the most confidently asserted.

---

## 10. MINOR

- **§9.10's ten simultaneous acquisitions.** The plan correctly calls this smoke,
  not proof. Keep it, but ensure a green result is never cited as concurrency
  proof — the §9.1 artifact is the correctness basis, as §9.10's own gate says.
- **§12 pins the plan's own worktree path.** A successor on another machine finds
  it wrong. Use the branch name alone.
- **The 8 duplicate reviewer repair plans are the headline evidence for a problem
  this plan will not fix.** §4 rightly excludes refactoring copied reviewer
  implementations, but then the benefit is double-counted. Name the follow-on work
  explicitly so the saving is attributed to the plan that actually delivers it.

---

## 11. Summary of required changes

| # | Severity | Kind | Change |
|---|---|---|---|
| 0 | BLOCKING | missing | Sequence behind the queue fix — measured 54% merge-queue pass rate at ~1 hour per attempt, charged against 100% of changes (Part 0) |
| 1 | BLOCKING | missing | State sequencing against the flake and CI-cost work |
| 2 | BLOCKING | missing | Replace unciteable transcript counts; state the expected saving |
| 3 | BLOCKING | missing | Add a 30-day measurement gate; completeness is not success |
| 4 | MAJOR | missing | Define a v1 line: task-only, no units, no hooks, advisory guard, no takeover |
| 5 | HARMFUL | present | Do not make `work-claim-guard` required on ruleset `21564317` in v1 |
| 6 | HARMFUL | present | Do not fail closed on *commit* during GitHub unavailability; specify the throttled message |
| 7 | HARMFUL | present | Cut shared-git-directory hooks from v1 — they can break every worktree at once |
| 8 | HARMFUL | present | Do not block work when the task issue closes on merge |
| 9 | HARMFUL | present | Demote §6.3 to a hypothesis; gate force-with-lease on both platforms |
| 10 | MINOR | present | Unpin the worktree path; name the reviewer-deduplication follow-on |

**On the whole:** this is a better design than the two that preceded it, mine
included, and §3's review history shows it improving under pressure rather than
defending itself. The objection is not to the mechanism.

It is that the plan proposes twelve steps and thirty-three tests against a
measured collision rate of three files — and that four of its locked decisions
would add a third required check to an `ALLGREEN` queue that already ejects
batches, stop every session from committing when GitHub throttles, install
shared-git-directory hooks that can break four worktrees at once, and halt
ordinary follow-up work the moment a pull request closes its issue.

Fix the queue first. Then build this, smaller, with those four changed.

---

# PART C — second reviewer, from inside a live collision (issue #89)

**Reviewer:** Claude (Opus 5), session `flaky-reviewer-tests-timing-c1ba63` on
`edge-dev`, 2026-08-27.
**Standing:** this reviewer spent the preceding day executing issue
[#89](https://github.com/popcre/ai-devops/issues/89) — the flaky reviewer test
timing fix — end to end: diagnosis, ten-file change across seven suites, CI,
merge queue. Findings below come from that execution, not from reading the plan.
Where they agree with Part A/B they are independent corroboration; where they are
new they are labelled C-1 … C-6.

**Verdict from this seat: the plan solves a collision that actually happened
here, and would not have touched five of the six failures that actually cost
time.** One of its locked decisions (§8 fail-closed) would have locked this
session out of its own work during a measured GitHub outage window.

---

## C-0. The one thing the plan gets right, from live evidence

Mid-execution, peer session `pull-latest-repo-d96ee2-06` messaged this session
asking whether it owned #89 — because it was about to start the same work. That
is precisely the §6.1 intent collision: two clean worktrees, disjoint initial
files, same task. It was resolved by a cross-session message that happened to be
sent. Nothing mechanical would have caught it.

**This is the plan's justifying incident, and it is real.** It is also the only
one of six failures in this workstream that the plan addresses.

---

## C-1. HARMFUL — declared-path fencing punishes exactly the work it is aimed at

§8 locks: *"Every write claim declares intended repository-relative paths"*, §9.4
requires them at `acquire` time, and §8 adds that changing scope while a claim is
active **fails closed**.

**Measured against this workstream:**

| | Files |
|---|---|
| Named in issue #89 | **2** (`tests/test-ai-grok-review.sh`, `tests/test-ai-kimi.sh`) |
| Actually changed at merge (`b9734cac..a5e5f7f3`) | **10** |
| Discovered *after* the first day of measurement | **8** |

The eight were not scope creep. `tests/lib-test-timing.sh` did not exist until the
shared helper was extracted; the five other reviewer suites (`deepseek-agent`,
`gemini`, `glm`, `muse`, `qwen`) entered scope only once the sweep proved the same
defect class in them; `fix_test_ai.md` was the diagnosis record. **A correct fix
went from two declared files to ten because the diagnosis was correct** — and
under §9.4 that is five successive re-declarations against a rule that fails
closed on scope change.

**The plan optimises for work whose file set is knowable in advance. Debugging is
the case where it is not** — and §3.2's own evidence, "separate sessions
independently diagnosing the same flaky reviewer tests", *is* debugging.

**Required change:** the declared-path set must be **append-only and extendable by
the owner without reconciliation**. Fail closed on *another* session's overlap,
never on the owner widening its own scope. Keep the fail-closed rule for the
scope block (units), where it governs admission; drop it for paths, where it
governs publication.

---

## C-2. HARMFUL — fail-closed on network ambiguity, with a measured outage this session

This corroborates finding 6 with a specific, dated incident, and raises its
severity.

§8 locks: *"Network/API ambiguity fails closed for acquire, renew, verification,
release, and takeover"*, and §9.6 makes the local guard block commit and push when
*"network verification unavailable"*.

**Measured, this workstream:** concurrent `gh run watch` invocations tripped a
GitHub **secondary rate limit** that returned 403 on every Actions API call —
while `gh api rate_limit` simultaneously reported `5000/5000 remaining`. The
condition is recorded in this reviewer's memory as
`gh-run-watch-burns-the-api-quota`, and it lasted long enough to derail CI polling
for a substantial part of an afternoon.

**Under §9.6 as written, that window would have blocked every `git commit` in
every session on this machine**, with no local override, for a reason unrelated to
ownership — and the standard diagnostic (`gh api rate_limit`) would have reported
the API as healthy.

This is worse than finding 6 states, because the failure mode is *not* GitHub
being down. It is GitHub being selectively unavailable **while reporting
availability**, triggered by ordinary tooling this repository already runs.

**Required change:** `commit` never requires network. Fence at `push` and in CI,
where a claim is actually being published and where a retry costs nothing.

---

## C-3. MISSING — every hazard in this workstream except one was *within* a single owner

The plan's threat model is session-versus-session. Six failures cost real time
here. **Five were one owner colliding with its own concurrent processes**, and a
per-task ref cannot see any of them:

1. **Editing a test script while copies of it were running.** Bash reads scripts
   incrementally from disk, so three concurrent runs died with a syntax error at
   line 315 of a file that was already valid on disk. Worked around only by
   running from in-repo snapshots (`tests/.snap-grok.sh`) that dodge the
   `test-*.sh` discovery glob.
2. **A `git stash` on a stack shared by every worktree and every other session.**
   Recovered by SHA, but the stack held another session's entry at the time.
3. **An orphaned background run writing into a log a new run was also writing**,
   producing an interleaved file and a bogus 155-failure result that was believed
   for a while.
4. **CRLF corruption** from a checkout predating `.gitattributes` — 96 files,
   invisible to `git grep`, fatal only under WSL bash.
5. **The merge queue** — Part 0's finding, independently reached here at roughly
   3.5–4.5 hours lost on one pull request.

Only the peer-session ping (C-0) was cross-session.

**This does not argue against the plan.** It argues that the benefit must not be
stated as "prevents collisions" when the measured collision population in the most
recent multi-hour workstream was **1 of 6**. Finding 2 asks for an expected
saving; this is the denominator for it.

**Add to §4 as explicitly out of scope**, so the gap is visible rather than
assumed covered: the shared stash stack, the shared git directory, concurrent
processes inside one claim, and script mutation during execution.

---

## C-4. MISSING — the read-only exemption has no boundary, and this workstream lived on it

§8 locks: *"Read-only work is exempt. Editing/committing/pushing/opening a PR
requires a claim."*

In this workstream, **roughly the first day was read-only**: reproducing under
artificial load, reading wrapper source, running unmodified suites, reading CI
timestamps. Nothing was edited. Under the locked rule no claim was owed for any of
it — and that is exactly the window in which the peer session (C-0) was
independently starting the same diagnosis.

**The plan exempts precisely the phase in which its own headline collision
occurs.** §3.2's duplicate-diagnosis failure happens before anyone writes a file.

**Required change:** either (a) allow an `--intent` claim that costs nothing and
blocks nothing but is visible to `list`/`status`, acquired when a session begins
*investigating* a task issue; or (b) state plainly in §4 that duplicate
*diagnosis* is not prevented — only duplicate *implementation* — and remove it
from the benefit case in §3.2.

---

## C-5. MAJOR — `bind-head` adds a serialization point to a pipeline already at 70 minutes

§8 locks: *"Before PR, `bind-head` advances the owned task ref … CI requires that
exact task/ref/head binding"*, and §9.7 locks that any different head requires a
fresh `bind-head`.

**Measured on this workstream:** `windows-offline` runs 65–70 minutes, and the #89
change itself added 3–5 minutes to it. Landing #89 took several pushes — the
ask-ceiling fix (`050ad1e`) and the loud-timeout fix (`9aec837d`) were each
discovered from a *failed CI run*, meaning each was a new head.

Under §9.7 every one of those iterations needs an extra authenticated
force-with-lease round trip before push, and **a forgotten one presents as a CI
failure 70 minutes later**, not as a local error. Combined with Part 0's 54% queue
pass rate, the cost of one missed `bind-head` is an hour.

**Required change:** `bind-head` must run automatically inside the push guard —
never a step a human or a model can forget — and its absence must fail *locally at
push time*, never for the first time in CI.

---

## C-6. MINOR — §9.11's "run focused tests twice where concurrency matters" is not enough, measured

§9.11 requires focused tests run twice. On this workstream the largest single
cause reproduced **6 times** across many runs, and one check
(`durable cancel is worker-confirmed`) failed roughly **1 run in 6**.

Two runs would have had roughly a 30% chance of surfacing that check at all, and
would have proved nothing about the rest. This reviewer needed **ten consecutive
clean runs** of one suite — six sequential, four concurrent with a second suite —
before the result was trustworthy, plus deliberate defect injection to prove the
guarded checks could still go red.

**Required change:** for a concurrency feature, derive the run count from the
failure rate to be excluded, and require **defect injection**. A test that never
fails is not evidence: §3.4 of `fix_test_ai.md` records a Kimi fixture whose
search pattern could never match, which passed for its entire life while
verifying nothing.

---

## C-7. Summary of Part C changes

| # | Severity | Kind | Change |
|---|---|---|---|
| C-1 | HARMFUL | present | Make declared paths append-only by the owner — a 2-file issue became a correct 10-file fix |
| C-2 | HARMFUL | present | `commit` must never require network — a measured 403-while-`5000/5000` window would have blocked every session |
| C-3 | MISSING | — | State that 5 of 6 measured failures were within one owner; list them as out of scope in §4 |
| C-4 | MISSING | — | Claim at *investigation* start, or stop claiming duplicate diagnosis as a benefit |
| C-5 | MAJOR | present | `bind-head` automatic in the push guard; never discoverable only in a 70-minute CI run |
| C-6 | MINOR | present | Replace "run twice" with a rate-derived run count plus mandatory defect injection |

**Agreement with Part A/B:** C-2 strengthens finding 6 with a dated incident and
should raise it to BLOCKING. Part 0's merge-queue finding is independently
confirmed here at 3.5–4.5 hours lost on a single pull request. No finding in Part
A or Part B is disputed.

**The one-line version:** build it, because C-0 was real — but build it for the
session that does not yet know which files it will touch, because that is the
session §3.2 says is duplicating work.
