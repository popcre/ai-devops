# plan_progress-wait-misuse-guard.md

**Created:** 2026-08-28 · **Branch:** `claude/reviewer-flake-89-progress-waits`
**Handoff:** [`HANDOFF.d/2026-08-28T1100Z-edge-dev-claude-progress-wait-misuse-guard.md`](HANDOFF.d/2026-08-28T1100Z-edge-dev-claude-progress-wait-misuse-guard.md)
**Related:** [`fix_test_ai.md`](fix_test_ai.md) · [`plan_repo-throughput-restructure.md`](plan_repo-throughput-restructure.md) · issue
[#89](https://github.com/popcre/ai-devops/issues/89) · PR
[#142](https://github.com/popcre/ai-devops/pull/142)

## STATUS

A fresh session starts at **Step 0**. Do not skip it: every later step assumes
Step 0's answer, and if Step 0 disproves the root cause in §6 the rest of this
plan is wrong and must be re-planned rather than forced.

| # | Step | State | Evidence |
|---|---|---|---|
| 0 | Confirm the root cause locally (discriminate Finding B vs Finding F) | ✅ done 2026-08-28 | Finding F refuted, Finding B confirmed in a narrower form — see §6 Finding G. Failing run `33144576111` log: `no observable progress for 120s after 408s` (the signal did move, then went silent) and `for 120s after 124s` (never moved). Local re-run passed 191/0 with identical paths. |
| 1 | Make `poll_until_progress` name a never-moving progress signal | ✅ done 2026-08-28 | `tests/lib-test-timing.sh` — `moved` flag; two distinct messages. Re-derive: `bash tests/test-lib-test-timing.sh` |
| 2 | Unit-test the never-moved case | ✅ done 2026-08-28 | `tests/test-lib-test-timing.sh` — 3 new checks; `bash tests/test-lib-test-timing.sh` → 12 passed, 0 failed |
| 3 | Write the rule into the helper header | ✅ done 2026-08-28 | `tests/lib-test-timing.sh` header above `ai_test_fingerprint`; `fix_test_ai.md` |
| 4 | Fix the three grok waits that regressed | ✅ done 2026-08-28 | `tests/test-ai-grok-review.sh:375,732,753` now fingerprint the whole state and fixture trees; fingerprint is mtime-aware |
| 5 | Green CI, merge, close out | ⬜ open | — |

---

# Part 1 — Why

## 1. The ultimate goal

**Make the reviewer test suites tell the truth about their own failures, so that
a person or a session reading a failure learns what actually broke instead of
being sent hunting the wrong thing.**

In business terms: these test suites are the safety net that stops a broken AI
reviewer from shipping. Over the past several days they have cost multiple full
work sessions — not because the underlying product was broken, but because when
they failed they described the failure inaccurately, and each session then spent
hours chasing a cause that did not exist. The work here is to make a specific
class of wrong diagnosis impossible to repeat.

**If any step in this plan conflicts with that goal, the goal wins — stop and
flag it.** In particular: if making the tool honest about a failure means a test
lane goes red, the lane goes red. A green lane bought by hiding information is
the opposite of the goal.

## 2. What this application is

`popcre/ai-devops` is Albert Hazan's DevOps and AI-tooling repository. It holds
command-line wrappers that drive AI code reviewers (Grok, Codex, DeepSeek, Kimi,
Muse, Gemini, Qwen, GLM), the skills and templates that configure Claude Code and
Codex across Albert's machines, and the test suites that guard all of it.

- **Repo:** `popcre/ai-devops` (moved from `u2giants/ai-devops` on 2026-08-26 —
  both owners remain valid on purpose; do not "clean up" the old one).
- **Branch for this work:** `claude/reviewer-flake-89-progress-waits`.
- **Stack:** Bash test suites, PowerShell orchestration on Windows, GitHub
  Actions for CI.
- **Where CI runs:** `linux-offline` on GitHub's `ubuntu-24.04`;
  `windows-offline` and `windows-reviewer-safety` on **two self-hosted Windows
  runners on the `edge-dev` machine** — see
  [`docs/self-hosted-windows-runner.md`](docs/self-hosted-windows-runner.md).
- There is no deployed web application here. "Done" means merged to `main` with
  CI green, not a deploy.

## 3. What triggered this work

Issue #89: the reviewer suites failed intermittently on a developer machine and
passed in CI **on the same commit with no code change** — a timing flake. The
root cause was found and fixed twice, in layers:

1. `155cc46d` (on `main`) derives every wait ceiling from one baseline measured
   at suite start.
2. This branch adds `poll_until_progress`, a *stall window*: a wait fails only
   when nothing observable has changed for N seconds. This distinguishes "slow
   machine" (still moving, keep waiting) from "genuine hang" (moving nothing) —
   which a fixed ceiling cannot do at any value.

**The new trigger:** on 2026-08-28 the merge-queue run for PR #142
([run 33144576111](https://github.com/popcre/ai-devops/actions/runs/33144576111))
failed `windows-offline` with exactly three failures, all in the "ask"
concurrency block of `tests/test-ai-grok-review.sh`:

```
FAIL different_named_sessions_can_ask_concurrently
FAIL same_next_ask_turn_is_serialized
FAIL uncertain_ask_blocks_its_exact_retry
```

`linux-offline` and `windows-reviewer-safety` passed in the same run.

**How to reproduce:** on a Windows machine with Git Bash, from a checkout of
this branch, run `bash tests/test-ai-grok-review.sh` and look for those three
names. The suite takes roughly 13 minutes on an idle `edge-dev`.

## 4. Scope

**In scope**

- Make `poll_until_progress` distinguish "the progress signal never moved at all"
  (probable misuse) from "the signal moved, then stopped" (probable real hang),
  and say which in its message.
- Add unit coverage for that distinction in `tests/test-lib-test-timing.sh`.
- Record the rule for choosing a progress signal in the helper's own header.
- Repair the three grok waits that regressed, using whatever the Step 0 evidence
  says is actually wrong.

**NOT in scope**

- Converting any further waits, in any suite, to `poll_until_progress`. The
  sweep named in `fix_test_ai.md` (`test-ai-kimi.sh`, `test-ai-deepseek-agent.sh`,
  `test-ai-muse.sh`, `test-ai-gemini.sh`, `test-ai-qwen.sh`, `test-ai-glm.sh`)
  stays untouched.
- Changing `poll_until`, `budget`, `scale_ticks`, `ai_test_measure_baseline`, or
  `ai_test_clamp_baseline` — the `main` layer from `155cc46d` is settled.
- The ten-run flake series and closing issue #89. That is downstream work
  tracked in `plan_repo-throughput-restructure.md` step 1.2.
- Anything in `plan_ai-devops-work-claims.md`. Still blocked.
- Runner infrastructure changes. Two runners exist and work.

---

# Part 2 — What we already know

## 5. Current state of the code

**Branch `claude/reviewer-flake-89-progress-waits`, HEAD `4f8482a3`, pushed.**
PR #142 is OPEN and was **ejected from the merge queue** by the failure in §3.
Its three normal (non-queue) checks passed before that.

Already committed and working:

- [`tests/lib-test-timing.sh:125`](tests/lib-test-timing.sh) —
  `ai_test_fingerprint PATH...` returns a cheap stable string: entry count for a
  directory, byte size for a file, `-` for an absent path.
- [`tests/lib-test-timing.sh:153`](tests/lib-test-timing.sh) —
  `poll_until_progress STALL WHAT PROGRESS CONDITION...`. Loops one second at a
  time. Each iteration where the progress string is unchanged increments `idle`;
  any change resets it to 0. At `idle >= stall` it prints a "stalled" line and
  returns 1. An absolute ceiling of `stall * 10` is a runaway backstop.
- [`tests/test-lib-test-timing.sh`](tests/test-lib-test-timing.sh) — 10 checks,
  **10 passing** as of `4f8482a3` (re-verified after the merge of `main`).
- Three converted waits in
  [`tests/test-ai-grok-review.sh`](tests/test-ai-grok-review.sh) at lines
  **374**, **731**, and **752**. All three call
  `poll_until_progress "$(budget 15 30)"`.

Deliberately **not** converted: the waits at lines 281, 288 and 314. They run
seconds after the baseline is measured, so baseline drift cannot affect them.
Leave them alone.

Documentation already updated and merged or committed:
`docs/self-hosted-windows-runner.md`, `docs/critical-incidents.md` (2026-08-28
entry), `AGENTS.md` router rows, `fix_test_ai.md` status block.

## 6. Key findings and root cause

**Finding A — the three failures are almost certainly caused by this branch, not
by the old flake.** They are three *adjacent* checks in one block, they all sit
downstream of converted waits, and the rest of the suite passed. A timing flake
does not cluster like that.

**Finding B — the suspected mechanism.** At
[`tests/test-ai-grok-review.sh:752`](tests/test-ai-grok-review.sh) the wait that
`main` had written as:

```
poll_until "$(budget 40 120)" 'the uncertain ask took its work lock and reached the Grok stub' ...
```

became, on this branch:

```
poll_until_progress "$(budget 15 30)" 'the uncertain ask took its work lock and reached the Grok stub' \
  "ai_test_fingerprint '$AI_GROK_STATE_DIR/locks' '$TMP/ask-uncertain.err' '$TMP/ask-uncertain.out' '$TMP/hold-started'" \
  ...
```

Note the deliberate widening in `main`'s version — `budget 40 120`, not
`budget 15 30` — with a comment two lines below explaining that this step builds
a review packet *before* reaching the lock check and therefore needs a wider
ceiling than its neighbours.

If the paths in that fingerprint do not change while the packet is being built,
`poll_until_progress` sees an unchanging string, counts to its stall window, and
gives up early. Because the call ends in `|| true`, the suite does not stop —
it proceeds to the check, `work_lock_labelled 'ask:ask-a'` returns empty, and the
downstream checks fail for a reason that has nothing to do with the wrapper.

**Finding B is NOT yet established — weigh Finding F against it.**

**That is the failure mode this plan exists to make self-describing.** A stall
window is only valid if the thing you fingerprint actually changes while the
system is healthily waiting. Nothing in the tool enforces or even mentions that.

**Finding F — the same commit PASSED `windows-offline` in the ordinary PR
run and failed only in the merge-queue run.** Run `33135538636` (PR run, after
`main` was merged in) reports `windows-offline success`; run `33144576111`
(merge-queue, same tree) reports the three failures. Identical code, different
outcome. That is evidence **against** "this branch's change is simply broken" and
for an environment difference between the two run types.

A known rival hypothesis fits it: on Windows, a deep `TMPDIR` has already made six
healthy suites in this repo fail in a way indistinguishable from timing flakiness.
Windows caps most paths near 260 characters and these suites nest their own
`mktemp` trees below `TMPDIR`; writes then fail silently. A merge-queue checkout
uses the long `gh-readonly-queue/main/pr-142-<sha>` ref, so any path derived from
the ref name is materially longer than in an ordinary PR run.

**Step 0 must discriminate between Finding B and Finding F before any code is
changed.** Check path length first — it is cheap, and blaming timing without
checking it is a mistake already made and withdrawn once in this repo.

**Finding C — the message is actively misleading.** The current stall message
says the fixture "stalled - no observable progress". A reader takes that to mean
the code under test hung. In the misuse case the code under test is fine and the
*test's own progress signal* was chosen wrongly. This session read that message
and spent hours diagnosing CPU saturation and then network failure, both wrong.

**Finding D — a job timeout is reported as `cancelled`, not `timed_out`.** Two
Windows jobs earlier the same day were killed at exactly their `timeout-minutes`
(30m18s against a 30-minute budget; 75m20s against 75). The runner log shows
socket aborts at that moment, which look like network failure but are the
*consequence* of the worker being torn down. Do not diagnose a "cancelled" job as
a network problem without checking the duration against `timeout-minutes` in
[`.github/workflows/verify.yml`](.github/workflows/verify.yml) first.

**Finding E — those timeouts were caused by contention**, not by slow code. When
the machine was idle the same jobs took 13 minutes (30-minute budget) and 54
minutes (75-minute budget). The budgets are correct and must not be raised.


### Finding G — what Step 0 actually established (2026-08-28)

Finding F is **refuted**. The merge-queue checkout uses the same directory on the
self-hosted runner as an ordinary pull-request checkout, `TMPDIR` was identical,
and the same commit passed and failed on the same machine with the same paths.
Path length is not involved.

Finding B is **confirmed, but in a narrower and more important form.** The signal
was not simply "never moving". The failing run reports two different shapes:

- `no observable progress for 120s after 408s` — the signal moved for 288
  seconds and then went silent for 120 while the wrapper was still healthy.
- `no observable progress for 120s after 124s` — the signal never moved at all.

The cause of both is the same: `ai_test_fingerprint` measured only **entry
counts and byte sizes**. A wrapper that is building its review packet creates no
new file, takes no lock, and writes nothing to stderr for minutes at a time. It
touches and rewrites files, but a count-and-size fingerprint cannot see that, so
a perfectly healthy process looks stopped. Under the contention of four
concurrent CI runs that quiet phase exceeded the 120-second stall window; on an
idle machine it does not, which is exactly why the same commit passed earlier.

Two consequences, both implemented:

1. The fingerprint must sense **modification time**, not just size and count, and
   must watch the whole state and fixture trees rather than the locks directory
   alone.
2. The tool must **distinguish a signal that never moved from one that moved and
   stopped**, because the first is a defect in the test and the second is a hang
   in the code under test. The old message called both a stall, and that is what
   sent this session hunting CPU and network faults for hours.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| **Raise the stall window / restore `budget 40 120` as a ceiling** | Forbidden by Decision B, and it would not fix the class of bug — the next wait with a bad progress signal fails the same way. Treat a widened ceiling as the symptom-suppression it is. |
| **Revert the three conversions and keep `poll_until`** | Throws away the actual #89 fix. `poll_until`'s frozen baseline is the confirmed root cause of the original flake. |
| **Document the rule and stop there** | Tried, in effect, and it failed. The rule was written into the helper header and `fix_test_ai.md`; this session read both and still chose bad fingerprints. Documentation alone does not prevent this. |
| **Make `poll_until_progress` fall back to a plain deadline when the signal never moves** | Silently converts a broken progress signal into a passing wait. That is the "make the lane green by hiding information" failure the goal forbids. |
| **Diagnose the merge-queue failure as machine saturation** | Measured and disproved: sustained CPU 24%, run queue ~0, 12 GB RAM free, disk idle. A single instantaneous `Win32_Processor` sample reported 71% and was wrong; use `Get-Counter` with multiple samples. |
| **Concluding "my change broke it" from the merge-queue failure alone** | The same commit passed `windows-offline` in the ordinary PR run (Finding F). Reproduce before repairing. |
| **Blaming timing or load on Windows before checking path length** | Already done once in this repo and withdrawn: six healthy suites failed purely because `TMPDIR` was ~140 characters deep. |
| **Diagnose it as a network fault** | Disproved: 12 consecutive TLS connections to github.com, all under 70 ms, zero failures. See Finding D for what the socket errors really were. |
| **Run the local test series and the CI checks on `edge-dev` at the same time** | Causes exactly the timeouts in Finding E, and a name-matched cleanup once cancelled a live CI job (job `98712820009`). One or the other, never both. |

## 8. Design decisions

**LOCKED — do not relitigate:**

- **D1 (Decision B).** Never weaken, quarantine, raise a multiplier or timeout,
  add retries, or mark a check allowed-to-fail in order to make a lane green.
  Dated from the original #89 work; reaffirmed 2026-08-28.
- **D2.** The stall-window approach stays. Both layers — `main`'s measured
  baseline and this branch's progress sensitivity — are complementary and both
  remain.
- **D3.** The tool must detect and name its own misuse. Documentation is a
  supporting layer, not the primary control (evidence: §7 row 3).
- **D4.** Waits at lines 281, 288, 314 stay as `poll_until`.
- **D5.** `edge-dev` hosts the CI checks **or** a local test series, never both.

**OPEN — implementer's judgment:**

- **O1.** *How* to repair each of the three waits in Step 4: widen the
  fingerprint to include a path that genuinely moves, or revert that specific
  wait to `poll_until` because it has no honest progress signal. Both are
  legitimate. Criteria are in Step 4.
- **O2.** The exact wording of the new diagnostic message, provided it plainly
  distinguishes the two cases.

---

# Part 3 — How to build it

Phases: Steps 0–3 are one context (tool + tests + docs). Steps 4–5 are a second
(repair + land). **Re-read Steps 4–5 before starting Step 4** — Step 0's evidence
may change them.

## Step 0 — Confirm the root cause

**Do this first and do not skip it.**

Run the suite locally on an idle `edge-dev`:

```bash
bash tests/test-ai-grok-review.sh
```

Before running, confirm no CI job is live (D5):

```bash
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|"\(.name) \(.status) busy=\(.busy)"'
```

Both runners must show `busy=false`.

**First, discriminate B from F (Finding F).** Print the `TMPDIR` and the deepest
path the suite actually creates, in both an ordinary run and a merge-queue-shaped
checkout, and compare against the ~260-character Windows limit:

```bash
echo "TMPDIR=$TMPDIR  len=${#TMPDIR}"
```

- **If the failing paths are near or over the limit** → Finding F is the cause,
  Finding B is wrong, and **this plan must be re-planned**: the fix is path
  length, not the wait. Say so and stop.
- **If path length is comfortably clear** → continue below.

- **If the three §3 failures reproduce** → Finding B stands. Continue.
- **If they do not reproduce**, add a temporary `set -x` or an echo of the
  fingerprint value inside the loop at
  [`tests/lib-test-timing.sh:153`](tests/lib-test-timing.sh) and re-run, to see
  whether the fingerprint string ever changes during those waits.
- **If the fingerprint does change and the waits succeed**, then Finding B is
  wrong, the failure is environment-specific to CI, and **this plan must be
  re-planned, not forced.** Say so and stop.

**Verification gate:** you can state, in one sentence each, (a) the longest path
the suite creates and whether it approaches the Windows limit, and (b) with the
observed fingerprint values, whether the progress signal for the wait at line 752
changes during the wait.

## Step 1 — Make the tool name a never-moving progress signal

**File:** [`tests/lib-test-timing.sh:153`](tests/lib-test-timing.sh),
function `poll_until_progress`.

Track whether the progress string *ever* changed. Currently the function keeps
`last` and `idle`; add a flag set when `now != last` fires for the first time.

Behaviour when the stall window is reached:

- **If the signal changed at least once** → keep today's message. This is a
  probable genuine hang, which is what the check exists to catch.
- **If the signal never changed at all** → emit a *different* message saying, in
  plain words, that the progress signal never advanced from its initial value and
  is therefore probably the wrong signal for this wait, naming the wait (`WHAT`)
  and printing the unchanged fingerprint value.

Return 1 in both cases. **Do not** make the never-moved case pass, retry, or fall
back to a deadline (§7).

Apply the same distinction to the absolute-ceiling message where it is
meaningful.

**Verification gate:** `bash tests/test-lib-test-timing.sh` still reports
`10 passed, 0 failed` before you add Step 2's new checks.

## Step 2 — Unit-test the distinction

**File:** [`tests/test-lib-test-timing.sh`](tests/test-lib-test-timing.sh).

Add at least these two checks, in the style of the existing ones:

1. `a progress signal that never moves is reported as a bad signal, not a hang` —
   drive `poll_until_progress` with a condition that never becomes true and a
   progress expression that returns a constant. Assert the stderr contains the
   new wording and **not** the hang wording.
2. `a signal that moves and then stops is still reported as a stall` — progress
   changes for the first few seconds, then freezes. Assert the original stall
   wording, so Step 1 has not destroyed genuine hang detection.

Keep the existing check `a stalled fixture says it stalled, not that the code
under test failed` passing — if Step 1's wording change breaks it, update that
check deliberately and say so in the commit message.

Use a small stall window (1–3 seconds) so the suite stays fast.

**Verification gate:** `bash tests/test-lib-test-timing.sh` reports **12 passed,
0 failed** (or higher if you add more), with zero failures.

## Step 3 — Write the rule into the helper header

**File:** [`tests/lib-test-timing.sh`](tests/lib-test-timing.sh), the comment
block immediately above `poll_until_progress`.

Add a short, blunt paragraph stating the rule: *a stall window is only valid if
the progress expression is verified to change while the system is healthily
waiting; if you cannot name something that moves during the wait, use
`poll_until` instead.* Reference the 2026-08-28 merge-queue failure
(run `33144576111`) as the concrete instance.

Also add one line to [`fix_test_ai.md`](fix_test_ai.md) recording that the first
conversion attempt regressed three checks this way, so the sweep named there is
not attempted blind.

**Verification gate:** `grep -n "poll_until" tests/lib-test-timing.sh` shows the
rule text above the function, and `fix_test_ai.md` mentions the regression.

## Step 4 — Repair the three grok waits

**File:** [`tests/test-ai-grok-review.sh`](tests/test-ai-grok-review.sh), lines
**374**, **731**, **752**.

With Step 1 in place, re-run the suite. The new message will say, per wait,
whether its fingerprint is the problem.

For each wait the tool names as having a never-moving signal, choose (**O1**):

- **Widen the fingerprint** — add a path that demonstrably changes during that
  wait. Prefer this when such a path exists; it preserves the #89 fix.
- **Revert that one wait to `poll_until`** with the ceiling `main` used at that
  line (line 752 was `budget 40 120`). Choose this when nothing observable moves
  during the wait — an honest fixed ceiling beats a fake progress signal.

Record the choice and its reason in a comment at each site. Waits the tool does
not flag stay as they are.

**Verification gate:** `bash tests/test-ai-grok-review.sh` exits 0 with none of
the three §3 names failing, run twice consecutively on an idle machine.

## Step 5 — Green CI, merge, close out

1. Commit with the Claude co-author trailer; push to
   `claude/reviewer-flake-89-progress-waits`.
2. PR #142 is already open. It merges through the **merge queue** — squash, with
   `linux-offline` and `windows-offline` required (ruleset `21564317`). A
   documentation-only PR may use `gh pr merge --squash --admin`; **this one may
   not**, because it changes test code.
3. **Keep `edge-dev` free of local test runs while the queue runs** (D5).
4. Watch the *merge-queue* run, not just PR state — a queue failure ejects the PR
   while it stays `OPEN`, which is how this session missed a failure for five
   hours. Check `gh run list --limit 10` for `merge_group` events.
5. On merge: update the STATUS table here, update
   `plan_repo-throughput-restructure.md`, and delete this plan's handoff file.

**Verification gate:** `gh pr view 142 --json state,mergeCommit` reports `MERGED`
with a commit SHA.

## 10. Tests required

**New** (Step 2), in `tests/test-lib-test-timing.sh` — the two checks named
there, by behaviour, not "add tests".

**Must stay green:**

- `bash tests/test-lib-test-timing.sh` — currently 10/10.
- `bash tests/test-ai-grok-review.sh` — the suite that regressed.
- `bash tests/test-ai-codex-review.sh` — the other half of
  `windows-reviewer-safety`.
- `.\tests\test-all.ps1` — the full matrix run by `windows-offline`. ~54 minutes
  on an idle `edge-dev`.

## 11. Constraints, standing rules and gotchas

- **Decision B (D1)** above all. No raised ceilings, no retries, no quarantine,
  no `continue-on-error`.
- **Branch → PR → merge queue** for code. No admin bypass for this PR. Note that
  `gh pr merge --admin` does **not** bypass a ruleset anyway.
- **Albert does not merge — you do.** Never end a reply asking him to merge.
- **`edge-dev` runs CI or a local series, never both (D5).** Before any local
  suite, check both runners are `busy=false`.
- **Never clean up test processes by bare name match.** The suites and the CI
  jobs share process names; a name-matched kill once cancelled live job
  `98712820009`. Record your own PIDs and kill only those.
- **Cap concurrent local suites at about four.** Eight starved the runners'
  heartbeat.
- **A runner showing `offline` while its process is alive means saturation, not
  breakage.** Do not re-register on that evidence.
- **A `cancelled` CI job is never a test result** — check duration against
  `timeout-minutes` first (Finding D).
- **Windows traps:** several docs are CRLF, which defeats exact-match patching —
  read as bytes, normalise, patch, restore. `python`/`python3` are Store stubs;
  use `py`. `pkill` does not exist in Git Bash. Git Bash `ps -ef` cannot see
  Windows processes; use PowerShell `Get-Process`. Git Bash mangles `schtasks`
  arguments into paths.
- **Never use bare `git stash` / `git stash pop`** — the stash stack is shared
  across worktrees and other sessions use it.
- **Other sessions are active in this repo.** Stage only your own files.
- **Secrets:** 1Password vault `vibe_coding`, moved only through pipes or
  protected files — never chat, arguments, logs, or commits.

## 12. Access and environment

- **Working directory:** the worktree
  `C:\repos\ai-devops\.claude\worktrees\claude-response-verbosity-8c37ab`. Do not
  `cd` to the main checkout.
- **`gh` CLI:** authenticated as `u2giants` with repo and Actions access. No
  additional credentials are needed for anything in this plan.
- **Machine:** `edge-dev`, Windows 11, Intel i7-12700 (20 threads). Two
  self-hosted runners; see `docs/self-hosted-windows-runner.md`.
- **Shells:** Git Bash for the Bash suites, PowerShell for `test-all.ps1`.
- **Test logins:** none required — every suite in scope is offline and uses
  stubs. If a live provider test is ever needed, credentials are in 1Password
  vault `vibe_coding`, by item title only.
- **Running things locally:** `bash tests/<suite>.sh` from the worktree root.
  There is no server to start.

---

# Part 4 — Landing it

## 13. Definition of done, risks, open questions

**Done means all of:**

- [ ] Step 0's finding stated in writing.
- [ ] `poll_until_progress` distinguishes never-moved from moved-then-stopped and
      says which.
- [ ] `tests/test-lib-test-timing.sh` covers both cases and is fully green.
- [ ] The rule is in the helper header and in `fix_test_ai.md`.
- [ ] `tests/test-ai-grok-review.sh` passes twice consecutively on an idle
      machine with none of the three §3 checks failing.
- [ ] Committed with the Claude co-author trailer and pushed.
- [ ] PR #142 through the merge queue, all three checks green, **`MERGED`** with
      a recorded merge SHA.
- [ ] STATUS table above updated; `plan_repo-throughput-restructure.md` updated;
      handoff file deleted.

**Risks and rollback**

- *The repair reintroduces the #89 flake.* Mitigation: the ten-run series in
  `plan_repo-throughput-restructure.md` step 1.2 is the check for that, and it is
  still owed regardless. Rollback for any single wait is reverting that one line
  to `main`'s `poll_until` form.
- *`windows-offline` takes ~54 minutes.* A wrong guess costs an hour. Prefer
  running the single grok suite (~13 min) to iterate.
- *Another session lands a conflicting change.* `main` moved under this branch
  once already. `git fetch` and check before pushing.

**Open questions**

- **O1** (how to repair each wait) is deliberately deferred to Step 4 evidence.
- Whether any of the six suites in the deferred sweep already contain the same
  misuse. Out of scope here; worth a look when the sweep is picked up.
- Nothing in this plan requires an answer from Albert. It is unblocked.

---

## Self-audit

**1. Could a brand-new session execute this without asking anything?** Yes. §2
defines the repo, branch, machine, and shells; §5 gives exact `file:line` state
for every touched file; §9 names files and verification gates per step; §12
covers access and how to run things. The only judgment call, O1, is labelled with
its decision criteria in Step 4.

**2. Does it carry every piece of background and nuance held now?** Yes. §6
records five findings including two *disproved* diagnoses (saturation, network)
that each cost this session an hour; §7 records seven rejected approaches with
reasons; §11 carries the Windows traps, the runner rules, and the process-kill
incident. *Gap found and closed during audit:* the first draft did not record
that a CI job timeout is reported as `cancelled` — the single fact that misled
this session longest. It is now Finding D and is cross-referenced from §11.

**3. Is the goal clear enough to steer by if a step is wrong?** Yes. §1 states
the goal in business terms and gives the explicit override instruction, and Step
0 carries a stop-and-re-plan branch for the case where the root cause in §6 turns
out to be wrong — the specific way this plan could be wrong.

*Second gap found and closed:* the first draft's Step 5 said only "merge PR
#142". It now warns that a merge-queue failure ejects the PR while leaving it
`OPEN`, which is exactly how this session lost five hours.
