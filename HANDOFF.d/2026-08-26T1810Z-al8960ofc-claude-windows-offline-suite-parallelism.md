---
issue: 98
status: OPEN
owner: claude/windows-offline-handoff-1810
---

# HANDOFF — `windows-offline` CI latency: measurement done, #89 is now a prerequisite (2026-08-26 18:10 UTC, al8960ofc/claude)

**The measurement phase of issue [#98](https://github.com/popcre/ai-devops/issues/98)
is COMPLETE and MERGED** (pull request
[#102](https://github.com/popcre/ai-devops/pull/102), squashed to `main` as
`1eede15`). This file replaces
`HANDOFF.d/2026-08-26T1356Z-edge-dev-claude-windows-offline-ci-latency.md`, which
is **deleted in the same commit** — see §7 "Retirement of the predecessor" for why,
and read that before assuming anything in git history still holds.

Two of the predecessor's load-bearing claims are now **disproven by measurement**.
Do not carry them forward.

## 0. DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **ONE message before starting work**. Do not
raise them one at a time.

### BLOCKING — work cannot start without an answer

**None.** The A/B/C gate question that blocked the predecessor is settled (see
"Already settled" below). Everything remaining is authorized ordinary work.

### RECOVERABLE — a wrong guess is fixable but wastes rework

1. **Should direct pushes to `main` still be allowed at all?**
   The merge-queue ruleset grants `OrganizationAdmin` a permanent bypass
   (`bypass_actors`, verified 2026-08-26), and `AGENTS.md:20` still says *"Work
   directly on `main`; do not create feature branches for this repository."* So a
   queue exists, but the rule telling sessions to bypass it also still exists.
   These contradict each other.
   This decides step 6 of §6: if direct pushes stay legal, the `push: main`
   trigger in `verify.yml` must stay **permanently** (it is the only verification
   those pushes ever get). If they are disallowed, the trigger is pure waste and
   goes.
   **Recommendation: disallow direct pushes — update `AGENTS.md:20` to say work
   goes through a pull request, keep the admin bypass as an emergency escape
   hatch only, and then remove `push: main`.** One sentence answers it.
   *Blocks:* step 6 only. Everything else proceeds either way.

2. **If the only way to make the flaky tests deterministic is to weaken what they
   assert, is that acceptable?**
   Issue [#89](https://github.com/popcre/ai-devops/issues/89)'s four failing
   assertions test **concurrency behaviour** by measuring wall-clock time
   (see §5, Finding 3). The clean fix replaces timing assertions with explicit
   synchronization. If some assertion cannot be made deterministic without
   dropping the property it proves, that is a real coverage loss.
   **Recommendation: fix them properly; if any single assertion genuinely cannot
   be saved, come back and ask rather than silently deleting it.** Albert's
   standing rule is that repair must not reduce function.
   *Blocks:* nothing; it is a rule for how to handle one specific case if it arises.

3. **Should `windows-reviewer-safety` keep running inside merge groups?**
   It is deliberately NOT a required check, but it triggers on `merge_group:` like
   every other job in `verify.yml`, so it burns a Windows runner for ~12-14 minutes
   in every merge batch and reports a failure that blocks nothing (it did exactly
   that on 2026-08-26 — see §3).
   **Recommendation: leave it alone until #89 is fixed**, because right now it is
   the cheapest early warning that the flakes have returned. Revisit after.
   *Blocks:* nothing.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

4. **Merge-queue starvation.** A pull request in the queue is rebuilt from scratch
   every time another pull request merges ahead of it. On 2026-08-26 pull request
   #102 was rebuilt **three times** and took **3h 02m** from opened to merged (§3).
   With three or four AI sessions merging concurrently, a 66-minute job can be
   overtaken indefinitely and never converge. Speeding the suite up shrinks the
   window but does not remove the mechanism.
   **Recommendation: re-measure after #98 lands; if it still bites at ~17 minutes,
   consider limiting how many sessions merge concurrently.** Nobody is on this.

5. **GitHub Team plan.** Albert asked on 2026-08-26 whether upgrading changes the
   #98 calculus. **It does not** — see "Already settled". He may still want Team
   for unrelated reasons (private-repo branch protection, code owners, required
   reviewers). That is a separate decision nobody has made.

6. **The completion-honesty gap, issue [#103](https://github.com/popcre/ai-devops/issues/103).**
   Filed by this session. Pull request
   [#101](https://github.com/popcre/ai-devops/pull/101) (another live session) is
   implementing the completion-honesty enforcement, and its Stop hook detects
   **claims of completion** but not **promises of imminent action** ("I'm
   proceeding to step 1 now", followed by no tool calls). Its own test fixture
   ends with `"Fixing them now."` and asserts no output, which pins the gap as
   correct behaviour. Commented on #101; the owning session decides.
   **Recommendation: let the #101 session rule on it. Do not edit their branch.**

7. **`edge-dev` may have a genuine resource problem** (carried from the
   predecessor, still unaddressed). Also raised in the #89 handoff.
   **Recommendation: 15 minutes of measurement before blaming tests.** Nobody is on it.

8. **Albert's INSTALLED global instruction files still say `u2giants`** (carried
   forward). `C:\Users\ahazan\.claude\CLAUDE.md` and `C:\Users\ahazan\.codex\AGENTS.md`
   were deliberately not overwritten during the org move. They work via GitHub's
   redirect. **Recommendation: run `bin/ai-adopt-globals` at a quiet moment. Never
   hand-edit them and never pass `--adopt-globals` directly — that is a known trap.**

9. **Abandoned git worktrees registered against `ai-devops`** (carried forward),
   including two under `C:\Users\ahazan\AppData\Local\Temp\`, two detached-HEAD
   clones `ai-devops-gemini-qualification-final(-v2)`, and
   `C:\repos\ai-devops-worktrees\evidence-seq287`.
   **Recommendation: run the `cleanup-worktree` skill in its own session.** Age
   alone is not proof any of them is safe to delete.

10. **The shared working copy `C:\repos\ai-devops` carries another session's
    uncommitted reviewer-cache work** (carried forward). Nobody in these sessions
    owns those files. **Leave it alone.**

### Already settled — do NOT re-ask

- **2026-08-26 — the merge-queue gate stays STRICT (option A).** Both
  `linux-offline` and `windows-offline` remain required checks. Albert declined to
  rule ("I'm not qualified to make this decision") and delegated it to GLM
  (`glm-5.3`, session `ai-devops-windows-offline-gate-ruling` on `al8960ofc`).
  GLM ruled **A**: `main` is the install source for every Windows workstation this
  repo exists to keep restorable, `linux-offline` cannot execute any PowerShell
  suite, and a red-but-non-blocking Windows check is functionally identical to no
  check. **Do not re-open A/B/C.**
- **2026-08-26 — the acceptance target is `windows-offline` <= 20 min p50 and
  <= 30 min p95 over 5 consecutive `windows-2025` runs**, with the real outcome
  metric being open-to-merged <= 60 minutes. Interim milestone <= 35 min. (GLM.)
- **2026-08-26 — a "fourth option" (require a lighter check inside the queue than
  on the pull request) is REJECTED as unimplementable.** GitHub rulesets use ONE
  `required_status_checks` list for both contexts. The only implementable version
  is a job that does less work when `github.event_name == 'merge_group'`, which
  makes the queue — the last gate before `main` — strictly weaker than the pull
  request gate. GLM additionally established that a **skipped** required check
  *satisfies* the requirement rather than parking the queue, so that design fails
  silently. Confirmed against the ruleset.
- **2026-08-26 — GitHub Team plan / larger runners do NOT fix #98.** Larger runners
  are billed even for public repositories (standard runners are free); Windows
  larger-runner rates are $0.022/min at 4-core rising to $0.322/min at 64-core.
  More importantly a bigger machine changes **nothing** while the suites run
  serially. And there is a hard ~9-minute floor set by the single longest suite,
  so past 16 cores it buys nothing. Verified against GitHub billing docs.
- **2026-08-26 — self-hosted runners are REJECTED.** `popcre/ai-devops` is public,
  so a self-hosted runner would execute forked pull-request code on Albert's
  machine. Separately, a runner with tools already installed can pass setup tests
  that would fail on a clean machine, which defeats the suite's purpose.
- **2026-08-26 — splitting `windows-offline` into multiple parallel JOBS is the
  fallback, not the plan.** In-harness parallelism reaches the same ~17 minutes
  with no job-name change and therefore no merge-queue wedge risk (§5, Finding 5).
- **2026-08-26 — `windows-reviewer-safety` is never a required check.** It is a
  strict subset of `windows-offline`. Reversing this needs an argument for why
  duplicate coverage is worth extra failure surface.
- **2026-08-26 — the repository is `popcre/ai-devops`, public; the org move is done.**
- **2026-08-21 — the dflow test login in this public repo's history is NOT being
  rotated.** Comes up in every public-boundary conversation. Do not raise it.

## 1. What this application is

`ai-devops` (`https://github.com/popcre/ai-devops`, **public**) is Albert Hazan's
**AI operations and configuration hub** for POP Creations. It is not a customer
product. It has no server, no deployment, no database.

It holds the shell/PowerShell tooling in `bin/`, machine bootstrap and installer
scripts, the shared AI reviewer wrappers (`ai-grok-review`, `ai-muse`,
`ai-deepseek-agent`, `ai-gemini`, `ai-kimi`, `ai-qwen`, `ai-glm`), the cross-tool
`templates/system/` standards, and the skills other repositories' AI sessions load.
**Every workstation Albert uses clones this repository and installs from it.**

That is why a slow Windows test suite is not cosmetic: the suite proves that
Windows machine setup still works, and Windows is the platform this repo serves.

**Users:** Albert plus every AI session on `edge-dev` (Ubuntu), `al8960ofc` /
`albt16` (Windows) and `hetz` (VPS).

**Stack:** Bash + PowerShell scripts. One GitHub Actions workflow,
`.github/workflows/verify.yml`, three jobs.

Two private siblings, `u2giants/ai-devops-memory` and
`u2giants/ai-devops-transcripts`, did not move and are irrelevant here.

## 2. What we set out to do this session, and why

Issue #98: since the merge queue went live, `windows-offline` (64 minutes) gates
every merge, and the queue re-tests each pull request combined with `main`, so a
pull request took over two hours. Albert's reaction: *"this sounds crazy."*

The predecessor handoff's §6 step 2 was explicit: **measure per-suite timings
before optimising anything.** Albert repeated that instruction verbatim when
handing this session the work. The hypothesis on the table (predecessor Finding 1)
was that all 54 Bash suites cost ~7x more on Windows because of process-spawn
overhead — labelled a hypothesis, never measured.

Albert also asked this session to put the open A/B/C gate decision to him, then
declined to rule and delegated it to GLM.

## 3. Current state — what is true right now

### Complete and MERGED

**Pull request [#102](https://github.com/popcre/ai-devops/pull/102) — squashed to
`main` as `1eede15`.** Both harnesses now print per-suite durations and a
slowest-first table. `tests/test-all.sh` and `tests/test-all.ps1` only; +25 lines,
0 removed. Summary lines (`OFFLINE BASH SUMMARY`, `OFFLINE COMPLETE SUMMARY`) and
exit codes are unchanged, so nothing that parses them was affected. This is
permanent instrumentation, not temporary — it is how the optimisation gets verified.

### The measurements (from run 32982387209, all three jobs green)

Job level: `linux-offline` 9 min, `windows-reviewer-safety` 12 min,
`windows-offline` 66 min.

**Windows Bash total: 3939s (65.6 min). Windows PowerShell total: 43s.**
**Linux Bash total: 526s (8.8 min).** Overall ratio 7.5x.

The eight heaviest Bash suites on `windows-2025`, with their Linux times:

| suite | Windows | Linux | ratio |
|---|---|---|---|
| `test-ai-grok-review.sh` | 545s | 124s | 4.4x |
| `test-ai-muse.sh` | 540s | 117s | 4.6x |
| `test-ai-kimi.sh` | 530s | 102s | 5.2x |
| `test-ai-glm.sh` | 474s | 56s | 8.5x |
| `test-ai-claude-review.sh` | 338s | 17s | **19.9x** |
| `test-ai-codex-review.sh` | 318s | 17s | 18.7x |
| `test-ai-qwen.sh` | 316s | 23s | 13.7x |
| `test-ai-gemini.sh` | 295s | 18s | 16.4x |

**Those eight are 3356s — 85% of the entire `windows-offline` job.** The other 46
Bash suites total 583s and all 17 PowerShell suites total 43s.

Reproduce with:
`gh run view --repo popcre/ai-devops --job <id> --log | grep -a "BASH SUITE TIMINGS" -A 58`
(the plain `gh api .../logs` endpoint refuses on terminal escape sequences).

### The merge queue completed its first full cycle — and it cost 3 hours

Pull request #102 opened 14:46:32Z, merged 17:49:09Z = **3h 02m**, against the
2h 10m the predecessor estimated. Breakdown:

- 21 minutes sitting in `AWAITING_CHECKS` before the first merge-group build even
  started — **runner contention**, not a configured wait
  (`min_entries_to_merge_wait_minutes` is 0). Three other AI sessions were pushing
  to this repo concurrently.
- **Three merge-group builds**, because `main` advanced twice underneath it
  (pull requests #105 and #107 merged while #102 was queued):
  `32987432804` (base `e0fe2928`, **failure**), `32988338419` (base `2e1089d8`,
  success), `32990264668` (base `6635775`, success).
- A `push: main` run (`32996267162`) fired after the merge — the redundant third
  run, confirmed live.

**The wiring is proven correct.** The `merge_group:` trigger fired, GitHub created
`gh-readonly-queue/main/pr-102-*` commits, the required check names matched, and
the queue merged. No wedge, no 120-minute park.

### The flakes fired ON A CI RUNNER

Merge-group build `32987432804` failed `windows-reviewer-safety` with exactly four
failures, all in `test-ai-grok-review.sh`:

- `different_named_sessions_can_ask_concurrently`
- `same_next_ask_turn_is_serialized`
- `uncertain_ask_blocks_its_exact_retry`
- `uncertain_ask_does_not_block_other_named_session`

They passed in the pull-request run of the same code. This is issue #89.

### Not started

Everything in §6 steps 1 onward. No branch exists for #89 or for the
parallelisation.

## 4. Everything we tried that did NOT work

1. **Reading job logs via `gh api repos/.../actions/jobs/<id>/logs`.** Returns
   *"the response contains terminal escape sequences"* and writes a 99-byte error
   file instead of the log. **Use `gh run view --repo <r> --job <id> --log`.**

2. **Writing a Bash script through a quoted heredoc into Python.** Backslashes
   collapse across the two interpreters. The Git Bash path literal silently lost a
   separator and gained a **backspace control character**. It parsed cleanly and
   would have failed on the Windows runner an hour later. **Fix: build backslashes
   with `chr(92)` in Python, or write the file directly with the Write tool. Always
   read the file back and check.** This is the predecessor's gotcha #6 and it bit again.

3. **Patching a file by matching an anchor string containing an escape sequence,
   through the same heredoc.** Same collapse; the `assert old in s` guard failed.
   **Fix: match by line index or a backslash-free prefix.**

4. **Writing this handoff itself through a quoted `cat <<'HEOF'` heredoc.** Bash
   failed with *"unexpected EOF while looking for matching quote"* on the prose.
   **Use the Write tool for multi-paragraph Markdown.** Three separate failures
   this session came from pushing text through a shell heredoc.

5. **`gh pr merge 102 --squash --auto`.** Rejected: *"The merge strategy for main
   is set by the merge queue."* Use `gh pr merge --auto` with no strategy flag.

6. **Trusting `gh pr view --json autoMergeRequest` to confirm queueing.** It
   returns `null` for a pull request that is genuinely queued. **Use the GraphQL
   `mergeQueueEntry { position state }` field** — that is the only one that tells
   the truth.

7. **Continuing GLM session `ai-devops-merge-queue-required-checks`.** The
   predecessor said to continue it. It does not exist on `al8960ofc` — GLM
   sessions are local to each machine's OpenCode server, and that session lives on
   `edge-dev`. A new session was created instead. **GLM sessions do not roam
   between machines.**

8. **Assuming the predecessor handoff was on `main`.** It was on branch
   `claude/windows-offline-ci-latency-98`. It has since merged. **When a handoff is
   not in `HANDOFF.d/` on `main`, check the branch list before concluding it does
   not exist.**

## 5. Root causes and key findings

**Finding 1 — the predecessor's Finding 1 is WRONG, and this is the single most
important correction in this file.** The cost is **not** spread evenly across 54
suites from generic process-spawn overhead. It is **concentrated in 8 files that
are 85% of the job**. Optimising "process spawning generally" would have been
wasted work.

**Finding 2 — the 17 PowerShell suites are innocent.** They total **43 seconds**
out of 66 minutes. The predecessor listed "how much of the 64 minutes is the
PowerShell suites" as an open uncertainty; it is now closed. Do not spend time there.

**Finding 3 — the cost is per-invocation, not algorithmic.**
`tests/test-ai-claude-review.sh` is the proof: **77 lines, 33 assertions, 17s on
Linux, 338s on Windows** — ~10s per assertion versus ~0.5s. Each assertion invokes
`bin/ai-claude-review`, which builds a review sandbox (copy the repo, `git init`,
spawn `jq`, write temp files). The eight heavy suites all follow this shape. It is
Windows process-creation and filesystem cost multiplied by invocation count.

**Finding 4 — the eight heavy suites are cleanly isolated, so parallelism is
safe.** Audited 2026-08-26. Every one calls `mktemp -d` and points every `HOME`,
`XDG_CONFIG_HOME`/`XDG_CACHE_HOME`/`XDG_DATA_HOME`, and `AI_*_STATE_DIR` inside
that private directory (e.g. `tests/test-ai-grok-review.sh:80`,
`tests/test-ai-qwen.sh:18`, `tests/test-ai-kimi.sh:113`, `tests/test-ai-glm.sh:156`,
`tests/test-ai-gemini.sh:79`). **Zero fixed paths, zero fixed ports, zero writes to
a shared `HOME` or global git config.** This was the predecessor's largest listed
uncertainty and it resolves in favour of parallelising.

**Finding 5 — in-harness parallelism beats splitting into jobs.** Running the
suites N-up inside the existing `windows-offline` job changes no job names, so it
cannot trip the required-check-name trap that wedges the queue. Splitting into
4 jobs reaches roughly the same time but requires adding every new job name to
ruleset `21564317` in the same commit, and consumes 4 concurrent runners, which
makes the contention in §3 worse.

Arithmetic: 3939s of work over 4 vCPUs = 985s, and the floor is the longest single
suite (545s), so expect **~16-17 minutes**. That clears the <= 20-minute target.

**Finding 6 — #89 IS NOW A PREREQUISITE, reversing GLM's ruling on sequencing.**
GLM ruled that #89 could be fixed in parallel with #98, relying on
`fix_test_ai.md` §2, which records that these flakes manifest only on loaded local
machines and that idle CI runners pass. **That is now false** — they failed on a
CI runner on 2026-08-26 (§3). Worse, all four failing assertions are
timing-sensitive concurrency tests, and 4-way parallelism deliberately creates CPU
contention. **Parallelising first would make them fail constantly.** Fix #89 first.

**Finding 7 — a queued pull request is rebuilt whenever `main` advances.** Not a
bug; it is what a merge queue is for. But combined with a 66-minute job and
several concurrent sessions it becomes a **starvation** mechanism, not merely a
latency cost. Evidence: three rebuilds of #102 in one afternoon (§3).

**Finding 8 — required checks are matched by name and a stale name wedges the
queue silently** (carried from the predecessor, still true and still the biggest
foot-gun). The three job names are frozen. Any workflow contributing a required
check MUST subscribe to `merge_group:`. Never add `paths:`/`paths-ignore:`/
`branches:` filters or `if:` skips to a required job. No job matrices. Recovery if
it happens: `OrganizationAdmin` has permanent bypass on ruleset `21564317`, so it
is a ~2-hour outage, not a lockout.

**Finding 9 — `tests/test-workflow-policy.sh:10` pins the Windows timeout at
`>= 75` minutes.** Speeding the suite up without changing that line leaves the repo
asserting it still needs 75 minutes. Raised by GLM, verified in the file. It must
change in the same pull request as the parallelisation.

## 6. Exact next steps

1. **Put §0 to Albert in ONE message.** Nothing is blocking, but item 1 (direct
   pushes to `main`) decides step 6. *You'll know it worked when* you have a
   one-sentence answer on item 1.

2. **Fix issue [#89](https://github.com/popcre/ai-devops/issues/89) — FIRST.**
   ⚠️ **#89 has its OWN handoff — read it before starting:**
   `HANDOFF.d/2026-08-26T1125Z-edge-dev-claude-flaky-reviewer-tests.md` (open,
   owner `claude/github-org-move-handoff-d576f2`). It is a separate workstream
   with its own §0 owner decisions. **Do not merge the two handoffs and do not
   edit that file** — it belongs to another session. This step and that handoff
   describe the same work from two directions; that one is authoritative on
   *how* to fix the flakes, this one on *why it now blocks #98*.
   Title: *"test-ai-grok-review.sh and test-ai-kimi.sh are non-deterministic: they
   assert on wall-clock timing."* The four failing assertions are named in §3.
   Replace wall-clock assertions with explicit synchronization (a marker file, a
   FIFO, polling with a generous bound). Do NOT paper over it with longer sleeps —
   that makes the suite slower, which is the thing #98 exists to fix.
   *You'll know it worked when* the four named assertions pass in 5 consecutive
   `windows-offline` CI runs, and §0 item 2 was honoured if any assertion had to
   change meaning.

3. **Parallelise `tests/test-all.sh`.** The suites are safe to run concurrently
   (Finding 4). Keep the `OFFLINE BASH SUMMARY tests=N failures=N` line and the
   exit code exactly as they are — other things read them. Preserve per-suite
   output attribution so a failure is still traceable to its suite; interleaved
   stdout from concurrent suites is the main risk to legibility. Start at 4-way
   (`windows-2025` has 4 vCPUs).
   *You'll know it worked when* `windows-offline` reports <= 20 minutes and the
   timing table still lists all 54 suites with a total consistent with the wall clock.

4. **In the SAME pull request, lower `timeout-minutes` for `windows-offline` in
   `.github/workflows/verify.yml` AND the `>= 75` floor in
   `tests/test-workflow-policy.sh:10`** (Finding 9). Keep generous headroom over
   the new p95. *You'll know it worked when* `bash tests/test-workflow-policy.sh`
   passes with both numbers lowered.

5. **Confirm the target across 5 consecutive runs** (<= 20 min p50, <= 30 min p95).
   *You'll know it worked when* you can cite five run IDs.

6. **Resolve the `push: main` trigger per §0 item 1.** If direct pushes are
   disallowed, update `AGENTS.md:20` and remove the trigger. If they stay legal,
   **keep the trigger permanently** and write down why, so a later session does not
   delete it as "obviously redundant". *You'll know it worked when* a queue merge
   produces exactly the intended number of `verify` runs.

7. **Lower `check_response_timeout_minutes` from 120 on ruleset `21564317`.** Keep
   generous margin over the job's `timeout-minutes` **plus runner-queue wait** —
   §3 shows that wait reached 21 minutes. Too low and a healthy job that waited for
   a runner is declared failed and requeued: a retry storm.
   *You'll know it worked when* a real pull request merges with the lower value.

8. **Close #98 and DELETE this handoff file in the same pull request.**

### At the END of every step above, before you stop

**Re-read steps 1-8 through to the end and report any drift** — anything you did
or learned that changes a later step's assumptions, target, ordering or approach.
Write it into this file (or into the closing report, if you are the session
retiring this file), and say so explicitly even when the answer is "no drift".

This is not boilerplate, and this session is the proof. Measurement in step 2
disproved the predecessor's Finding 1, closed one of its open uncertainties, and
**reordered the remaining work** by promoting #89 from a parallel track to a hard
prerequisite (Finding 6). None of that was foreseeable when those steps were
written. A session that executes its own step and stops without re-reading the
rest hands the next session a plan that is quietly wrong.

## 7. Constraints and gotchas in force

### Retirement of the predecessor

This commit deletes
`HANDOFF.d/2026-08-26T1356Z-edge-dev-claude-windows-offline-ci-latency.md`.
Successor-rule check, all three conditions:

1. **Its work landed.** It stated *"Nothing has been built for this workstream
   yet"* — it was a planning artifact, and that plan is on `main`. Its §6 steps 1-3
   (put §0 to Albert; measure per-suite timings; compare against Linux) are all
   **complete**, with #102 merged as `1eede15`.
2. **Every open obligation is carried forward.** Its §6 steps 4-8 are §6 steps 3-8
   here; its §0 items 4-7 are §0 items 7-10 here; its §4 dead ends that are still
   live are §4 here; its Finding 6 is Finding 8 here.
3. **Nothing exists only there.** Verified by walking it section by section.

**Positive reason to delete rather than keep:** it asserts the A/B/C gate is
"ALREADY OPEN and Albert has not answered it" (settled — option A) and states
Finding 1 (~7x spread evenly) as the leading hypothesis (**disproven**). Leaving it
in place would make the next session re-ask Albert a settled question and optimise
the wrong thing. Git history preserves the text.

### Standing rules

- **Do not add `paths-ignore` to `verify.yml`.** Albert has offered this; it must
  be declined while these jobs are required (Finding 8).
- **`C:\repos\ai-devops` is shared with other live AI sessions** and its working
  tree holds another session's uncommitted reviewer-cache work. Branch from
  `origin/main` in a separate worktree; stage only your own files; never
  `git add -A`; never rebase local `main`.
- **Do not put an `ai-devops` worktree under a session scratchpad** — Windows path
  length breaks `git worktree add` with `Filename too long`. Use
  `C:\repos\ai-devops-worktrees\<name>`.
- **Never use bare `git stash` / `git stash pop`** — the stash stack is shared with
  every other worktree and session.
- **Judge `tests/test-all.sh` by its `OFFLINE BASH SUMMARY tests=N failures=N` line
  or `${PIPESTATUS[0]}`** — never by a piped exit code. Piping to `tail` returns
  `tail`'s status and previously produced a false "clean pass".
- **The full Bash suite takes ~50 minutes locally on Windows.** Do not run it to
  get timings — use CI. Smoke-test harness changes against 2-3 fake suites instead
  (this session did; it caught a real bug in seconds).
- **PowerShell files are CRLF and must be pure ASCII.** So is `verify.yml`.
  `tests/test-all.sh` is stored LF in git and checked out CRLF on Windows;
  `core.autocrlf` handles it. Do not "fix" the line endings.
- **Use Git Bash for `.sh`, PowerShell for `.ps1`.** `bash` invoked from PowerShell
  resolves to **WSL**, not Git Bash, and produces UTF-16-looking garbage.
- **New Bash files need the executable bit in git**: `git update-index --chmod=+x <path>`.
- **Committer identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.**
  Verify with `git var GIT_COMMITTER_IDENT` before the first commit.
- **Albert does not merge — the session that opens a pull request merges it.**
  Never end a report asking him to click Merge.
- **`gh pr merge` from a linked worktree can print `'main' is already used by
  worktree`.** That is local branch cleanup failing AFTER a successful merge.
  Confirm with `gh pr view <n> --json state` and continue.
- **Docs-only pull requests:** Albert's standing rule is to merge once
  `linux-offline` passes (~9 min) via `gh pr merge --admin`, rather than waiting on
  Windows. **It does not apply to code.**
- **Never rewrite the root `HANDOFF.md`**, and never edit another session's
  `HANDOFF.d/` file (retiring a finished one under the successor rule is not editing).
- **The identity guards must stay fail-closed.** `config/repo-identities.tsv`
  intentionally lists **both** `u2giants` and `popcre` for `ai-devops`; removing the
  old owner recreates the flag-day the org move avoided. All of `tests/`
  deliberately still asserts `u2giants`.

## 8. Access and environment

- **This machine: `al8960ofc`** (Windows 11 Pro, i7-14700, 20 physical cores /
  28 logical, 30 GB RAM). PowerShell 7 (`pwsh`) and Git Bash both available.
  The predecessor ran on `edge-dev`; paths under `C:\Users\ahazan\` in it are
  **that** machine. On `al8960ofc` the user profile is `C:\Users\ahazan2\`.
- **This session's worktree:** `C:\repos\ai-devops-worktrees\windows-offline-ci-latency-d349bb`,
  branch `claude/windows-offline-handoff-1810` (this file), and
  `claude/windows-offline-ci-latency-d349bb` (merged as #102).
- **`gh` CLI:** authenticated as `u2giants`. Scopes `admin:public_key`, `gist`,
  `read:org`, `repo`, `workflow`. **`delete_repo` and `admin:org` are ABSENT.**
  `admin:org` absence means `gh api orgs/popcre/actions/runner-groups` returns 403 —
  that is expected, not a fault.
- **Org role:** `u2giants` is an admin/owner of `popcre`. Members are `u2giants`
  and `devopswithkube` only. Org is on the **free** plan.
- **GLM:** session `ai-devops-windows-offline-gate-ruling` (review, `glm-5.3`) on
  **`al8960ofc`** holds the gate ruling. Continue it with `ai-glm ask` **from
  PowerShell** — only `ai-glm.cmd` exists, so Git Bash gives `command not found`.
  `ai-glm doctor` passed all required checks 2026-08-26. Report at
  `.ai/reviews/glm-ai-devops-windows-offline-gate-ruling-20260826T143453Z.md`.
  On a client-side timeout do NOT re-issue or abort — poll `ai-glm show`, then read
  `ai-glm transcript`.
- **Ruleset `21564317`** (`main: pull request + merge queue`): active, SQUASH,
  ALLGREEN, `max_entries_to_build` 5, `max_entries_to_merge` 5,
  `min_entries_to_merge` 1, `min_entries_to_merge_wait_minutes` 0,
  `check_response_timeout_minutes` 120, 0 required approvals, required checks
  `linux-offline` + `windows-offline`, `bypass_actors` = `OrganizationAdmin`
  (`always`). A second ruleset `Protect main history` (`21183703`) supplies
  `deletion` and `non_fast_forward`; leave it alone.
- **Secrets:** none are needed. `ai-devops` has **no Actions secrets, variables or
  environments at all**. Anything else lives in 1Password vault **`vibe_coding`** —
  reference by item, never by value.

## 9. Open questions and risks

- **RISK — parallelising before #89 is fixed will produce a constantly-red
  `windows-offline`.** The four failing assertions are timing-sensitive and
  parallelism creates the contention that breaks them (Finding 6). This is the
  single most likely way to make things worse.
- **RISK — interleaved output from concurrent suites destroys failure
  attribution.** The current harness prints `===== BASH <name> =====` then that
  suite's output. Run 4 at once naively and the log becomes unreadable exactly when
  someone needs to debug a failure. Buffer per suite and emit on completion.
- **RISK — merge-queue starvation** (Finding 7). Not addressed by anything in §6;
  §0 item 4.
- **UNCERTAIN — whether 4-way is the right degree.** 4 vCPUs suggests 4, but these
  suites are I/O-heavy (file copies, process spawns), so 6 or 8 may do better.
  Measure; do not assume. The floor is 545s regardless.
- **UNCERTAIN — whether the eight heavy suites can also be made individually
  faster.** Finding 3 says the cost is per-invocation sandbox construction. If a
  sandbox could be built once and reused across assertions within a suite, the win
  could be larger than parallelism. Nobody has looked. This is the highest-upside
  unexplored lead.
- **DECIDED 2026-08-26 (GLM, delegated by Albert) — the gate stays strict (A).**
- **DECIDED 2026-08-26 — Team plan and larger runners do not fix this; self-hosted
  runners are rejected; in-harness parallelism is preferred over splitting jobs.**
- **DECIDED 2026-08-26 — `windows-reviewer-safety` is never a required check.**
- **DECIDED 2026-08-26 — the repository is `popcre/ai-devops`, public. Do not revisit.**

---

## Self-audit (required by the handoff standard)

1. **Could a street-newcomer continue without asking a question?** Yes. §1 says
   what the repo is and why a Windows suite matters here with zero assumed
   knowledge; §2 gives the trigger and Albert's own words; §3 states exactly what
   is merged (`1eede15`), gives every measured number with the run ID and the
   command to reproduce it, and says plainly what is not started; §6 gives eight
   ordered steps each with a verification gate; §8 gives machine, worktree paths,
   token scopes and the *absent* scopes.

2. **As effectively as this session can right now?** Yes. §4 carries all eight
   things that cost real time with the fix that worked — the escape-sequence log
   endpoint, the heredoc backslash collapse (twice) and the heredoc quote failure
   that broke writing this very file, the `--squash` rejection, the
   `autoMergeRequest: null` false negative, GLM sessions not roaming between
   machines, and the predecessor handoff living on a branch. §5 carries nine
   findings with `file:line` refs, and Findings 1, 2 and 6 explicitly overturn
   prior conclusions so the next session does not inherit them.

3. **Is every relevant detail present?** Yes: background (§1-2), current state with
   merged SHA, run IDs and full timing tables (§3), dead ends (§4), findings with
   `file:line` (§5), next steps with gates (§6), constraints and the predecessor
   retirement justification (§7), access including absent scopes and the exact
   ruleset configuration (§8), risks and dated decisions (§9).

4. **Would Albert see every decision he owns by reading only §0?** Checked by
   walking §1-§9 line by line. The `push: main` / `AGENTS.md:20` contradiction
   (§5 Finding 8, §6 step 6, §8 → §0.1), the coverage-loss rule for #89 (§6 step 2
   → §0.2), `windows-reviewer-safety` in merge groups (§3, §5 → §0.3), queue
   starvation (§5 Finding 7, §9 → §0.4), the Team plan question Albert raised
   himself (§0.5), the #103/#101 promise-detection gap (§0.6), and the four items
   carried from the predecessor that nobody is on (§0.7-10) all appear in §0. Items
   4-10 are outside this workstream and are in §0 **precisely because nobody else
   is raising them** — items 5 and 6 arose from Albert's own questions this session
   and would otherwise have died in chat.
