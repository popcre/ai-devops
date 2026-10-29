# Implementation plan — reviewer observation week (fast-fail, skip, non-blocking reviews)

## STATUS — read first; do not re-derive

> **Superseded 2026-10-29** by [plan_simple-reviewer-rebuild.md](plan_simple-reviewer-rebuild.md) (#2041). Steps 8 (report: [docs/reviewer-observation-week-2026-10-22.md](docs/reviewer-observation-week-2026-10-22.md)) done; freeze lift moves to the new plan step 4.

| Step | Status | Evidence / where a fresh session starts |
|---|---|---|
| 0. Register issue, plan, handoff; declare freeze start | ✅ done 2026-10-21 | [#1948](https://github.com/popcre/ai-devops/issues/1948); pending-work and task-router rows already present |
| 1. Fast-fail detector in the shared lifecycle | ✅ shipped 2026-10-22 (#1952, follow-ups #1982) | `tools/lib/review-lifecycle-core.sh` fast-fail watch |
| 2. Per-session skip list | ✅ shipped 2026-10-22 (#1952, follow-ups #1982) | `tools/lib/review-session-skip.sh` |
| 3. Non-blocking dispatch (`--detach`) + outcome recorder | ✅ shipped 2026-10-22 (#1952, follow-ups #1982) | `bin/ai-review --detach`, `ai-review outcome` |
| 4. Merge policy for the week: `unreviewed` tag + post-hoc queue | ✅ shipped 2026-10-22 (#1952, follow-ups #1982) | `tools/lib/observation-week.sh`, `bin/ai-task-gates check --before ship` (code and prose) |
| 5. Global rules text for the week (Claude/Codex/MiMo/ZCode globals) | ✅ done 2026-10-21 (#1953) | Globals paragraph + rotation rule 15 |
| 6. Fleet install + freeze declaration | ✅ done 2026-10-22 9:56 AM EDT | All five hosts contain a77fda0c; window file on each; freeze to 9:56 AM EDT Oct 29 ([#1948 comment](https://github.com/popcre/ai-devops/issues/1948#issuecomment-6342582614)) |
| 7. Seven-day observation and daily tally | ⬜ open | Start here: first tally ~9 AM EDT Oct 23 (`python3 tools/reviewer_events.py tally --since 2026-10-22T13:56:18Z`) |
| 8. Post-hoc review drain + findings report | ◐ tool shipped 2026-10-22 (#1952, follow-ups #1982); drain runs after step 7 | `bin/ai-review-posthoc` |
| 9. Closeout: decide what to keep, what to revert | ⬜ open | |

**Owner issue:** [#1948](https://github.com/popcre/ai-devops/issues/1948).
**Handoff:** [HANDOFF.d/2026-10-21T2020Z-edge-dev3-claude-reviewer-observation-week.md](HANDOFF.d/2026-10-21T2020Z-edge-dev3-claude-reviewer-observation-week.md).
**Fresh session starts at** the first ⬜ row after reading §1, §4, §8 and §11.

---

## 1. The ultimate goal — what we are actually trying to achieve

**Business goal, in Albert's words (2026-10-21 chat on edge-dev3):**

> "i think you need to change the rules or the way everything works so that the sessions can sense a reviewer failure more quickly and move on and not try that reviewer again (at least for that session). and i think if all 4 reviewers [are down] at the same time we can still glean some useful data from it. maybe keep sending things to the reviewers but not waiting for them and not requiring their approval, just log the issue."

What will be true when this is done that is not true today:

1. **Coding work never waits more than a few minutes on a broken reviewer.** A session notices a reviewer failure fast, stops using that reviewer for the rest of the session, and moves on.
2. **Work keeps flowing even when every reviewer is down.** For seven days, ordinary repositories merge on their own automated tests, every such merge is tagged `unreviewed`, and the reviews still run and are still recorded, just not waited on.
3. **At the end of seven days we have the first honest baseline in ten months:** how often each reviewer fails when nobody is repairing or reinstalling anything, and why.

Why this is the right thing now (from the 2026-10-21 diagnosis, this same chat): on edge-dev3 alone, 80 of 552 reviews in five days ended with no decision, every day, and the causes rotated. Nearly half of all commits since December 2025 and 90 of the last 200 merged PRs are reviewer repairs. Each repair moves the code, which voids the approval it just earned, and reinstalls five machines, which re-arms the requalification loop. The repair work is itself the largest source of outage. The seven-day freeze separates "the reviewers are flaky" from "we keep breaking them".

**If a step conflicts with this goal, the goal wins — stop and flag it on the owner issue.** In particular: do not buy a green week by hiding failures, by not sending reviews, or by letting production or shared-database changes through unreviewed.

## 2. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert's public toolkit that lets AI coding sessions (Claude, Codex, MiMo, ZCode, Grok, GLM, Kimi, Qwen) on Windows (`edge-dev`, `916`, `4837`) and Ubuntu (`edge-dev3`, `hetz`) obtain an independent AI code review before merging. Four maintained rotation reviewers: Muse, DeepSeek, GLM, StepFun (`docs/reviewer-rotation-rules.md`). Not an app or service; "deployment" is `install.sh` / `update.sh` on each machine by its protected route.

Key parts for this plan:

- `bin/ai-review`: front door a session calls (`ai-review <provider> <mode>`). `bin/ai-review-pool`: allocator-driven dispatch. `bin/ai-review-engine` + `tools/lib/review-lifecycle-core.sh`: shared lifecycle every provider runs through. `tools/lib/review-doors/<provider>.sh`: per-provider adapters ("doors"); each has its own timeout (`muse.sh:59` 1800 s, `deepseek.sh:51-54` 3600 s Linux / 7200 s Windows, `stepfun.sh:58` 3600 s, `gemini.sh:45` and `qwen.sh:40` 3600 s).
- `bin/ai-review-preflight`: per-machine admission state. Already has `quarantine`, `pause <provider> <failure-class> [--seconds]`, `known-broken`, `clear`, `usable`, `status` (usage block at `bin/ai-review-preflight:1568-1590`). The pause store is per machine, not per session.
- `tools/reviewer_events.py`: writes `~/.local/state/ai-devops/reviewer-events/events.jsonl` (started/finished per run) and `~/.local/state/ai-devops/review-scoreboard/reviews.jsonl` (one row per verdict: `provider, verdict, failure_class, evidence_state, elapsed_seconds, head, repo, run_id, session_id`). `find_passing_report` at `tools/reviewer_events.py:1454`.
- `bin/ai-reviewer-issue`: incident packages under `.ai/reviewer-issues/` of the installed checkout (`/home/ahazan/repos/ai-devops` on edge-dev3, `C:\repos\ai-devops` on edge-dev).
- `bin/ai-task-gates` + `config/task-gates.json`: task classes; `assigned-ai-reviewer-approval` and `exact-head-independent-review` gates (`config/task-gates.json:251-350`).
- Merge gating: in popcre/ai-devops the GitHub rulesets are "Protect main history" and "main: pull request + merge queue"; the required CI is `verify.yml`. **There is no GitHub check that requires an AI reviewer APPROVE.** The AI review requirement is a process rule enforced by `ai-task-gates` and the global rule files (`templates/system/CLAUDE-global.md`, `AGENTS-global-codex.md`, `AGENTS-global-mimo.md`, `AGENTS-global-zcode.md`, `REVIEWER-global.md`). In `popcre/shared-db` the gate is real: `scripts/run-governed-review.mjs` + the allocator (`scripts/lib/lanes/review-assignment.mjs`, `review-circuit-breaker.mjs`, `REVIEWER_FAILURE_CEILING = 2`) + `.github/workflows/guarded-migration-merge.yml`.
- Consumer: `popcre/shared-db` (governed reviews, production migrations). DesignFlow repos (`popcre/designflow-*`, sandbox → develop).

## 3. What triggered this work

Albert, 2026-10-21, asked why after ten months the reviewer system has never worked 24 hours in a row. Evidence gathered in that chat (edge-dev3 Claude session `92999f3c`, worktree `reviewer-system-outage-6b9ccf`):

- `ai-reviewer-issue list` on edge-dev3: 24 incidents since 2026-10-11; on edge-dev: 21 (read via PowerShell over SSH from `C:\repos\ai-devops\.ai\reviewer-issues`).
- Scoreboard `reviews.jsonl` on edge-dev3, last 5 days: 386 verdict rows, 28 BLOCKED; events log: 552 finished runs, 80 non-zero exits, every day (16 Oct 4/34, 18 Oct 30/222, 19 Oct 5/40, 20 Oct 14/89, 21 Oct 27/167).
- Dominant causes in incidents and transcripts: provisional/extra decision lines voiding a real APPROVE (StepFun, Muse, GLM); source receipt/packet/sandbox conflicts after a fix moved the head; install locks and reinstalls across five hosts (1Password daemon inheriting the install lock, half-updated hetz); vendor CLI self-updates (Muse Code re-pin #1923); Windows spawn failures (StepFun `ChildProcess.spawn NotFound`); GLM "governed source root is not a repository top level" on Windows worktrees; DeepSeek silent hang after tool calls; quota/credit outages (Qwen, GLM, StepFun).
- Existing programmes: `plan_reviewer-stability-24h.md` (#1822), `plan_reviewer-recurrence-repair.md` (#1783), `plan_edge-dev-reviewer-repair-no-review.md` (#1678), `plan_review-output-contract.md`, #1833/#1834 prevention. All are repair programmes. None measures a no-repair baseline.

Albert's rulings in this chat (verbatim, from his chat on edge-dev3, 2026-10-21):

- "i don't understand what freezing would do for us" → explained; he then moved to the fast-fail/skip/non-blocking design quoted in §1.
- "so we need to account for the possibility of all reviewers being down simultaneously. we can't stop all work because of that."
- Proposed by Claude and not contradicted: production and the shared database keep their review gate; routine operations (restart a hung process, recharge credit, reset a key) stay allowed during the freeze; a reviewer down a full day with no routine action restoring it ends the week early for that reviewer with an isolated cause.

## 4. Scope — in and out

### 4.1 In

- Fast failure detection in the shared lifecycle (one place, all providers).
- Per-session skip list: once a reviewer fails in a session, that session never draws it again.
- Non-blocking dispatch: a session can send a review and continue; the outcome is recorded to the scoreboard whenever it arrives.
- Week-long merge policy for ordinary repositories: merge on CI with an `unreviewed` marker; queue for post-hoc review; late REJECT becomes a fix-forward issue.
- Production and shared-db: unchanged gate; `unreviewed` work waits on the branch; a queue drains when any reviewer is back.
- Freeze of reviewer-code changes and fleet installs for seven days, with a written allowed-operations list.
- Daily tally and a final findings report built from the scoreboard and incident packages (not from transcripts).

### 4.2 NOT in this plan

- Fixing any individual reviewer defect found during the week (log it; fix after the week, in the existing programmes).
- Removing, retiring or adding a reviewer. Changing rotation membership.
- Weakening the shared-db allocator, `guarded-migration-merge`, production gates, or `reviewer-safety`.
- Changing GitHub rulesets or required checks in any repository.
- Touching DesignFlow's sandbox → develop flow (Albert reviews those himself).
- Bulk transcript mining (done once on 2026-10-21; its method is in memory `scaledown-transcript-extract-2026-10-21`).
- Any install on networking-only machines (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`).

## 5. Current state of the code

Nothing in steps 1–9 exists yet. Facts a fresh session must not rediscover:

- Door timeouts (see §2) are 30–120 minutes. A hung reviewer costs a session up to two hours today, then the same reviewer may be retried.
- `bin/ai-review-preflight pause|quarantine|known-broken|clear|usable` exist and are per machine (`bin/ai-review-preflight:612-670` for failure-class explanations; `:1568-1590` usage). There is no per-session store.
- The shared-db allocator already has per-reviewer failure counting (`scripts/lib/lanes/review-circuit-breaker.mjs`, `REVIEWER_FAILURE_CEILING = 2`, `RETRYABLE_RELEASED_FAILURE_CODES`) and a replacement draw (`review-replacement.mjs`). After two failed paid reviews it refuses a third until repaired. This plan does not change it.
- Reuse of another reviewer's pass for the same head exists (`bin/ai-review` `return_existing_pass` at `:210`; `tools/reviewer_events.py:1454`).
- Scoreboard rows carry a `session_id`, but it is the **reviewer's** session (`tools/reviewer_events.py:1072,1090`), not the calling coding session. There is no caller-session field today; step 1 adds `caller_session_id`.
- `ai-task-gates check --before <action>` is where the "review required" refusal fires for merges in the `code` class with `assigned-ai-reviewer-approval` (`config/task-gates.json:251-350`).
- Fleet install state on 2026-10-21 (#1783 comment, 12:10 AM EDT): edge-dev3 3730d039, 916 956ebeec, 4837 5eaaca3e, edge-dev cdddb6c7, hetz 21a37359 (hetz updates go through u2giants/ansible#17).
- Albert's standing constraint (2026-10-18, #1783 handoff): **no new CI jobs, Windows CI runs, or test suites.** New tests go into existing suites.

## 6. Key findings and root cause

From the 2026-10-21 diagnosis (incident packages on both hosts, scoreboard, 204 transcript digests):

1. **No single reviewer is the problem; the loop is.** Every provider failed and recovered within hours with no code change in between. Failure classes rotate daily.
2. **Repairs cause outages.** Each fix moves the head and voids the approval; each install re-arms requalification and lock contention on five hosts. Three parallel plans edit the same shared files from four machines.
3. **Strict parsing throws away real decisions.** A "Provisional verdict: Approve" line above a terminal APPROVE voids the review (StepFun 20261020T120703Z, Muse on hetz 2026-10-19, GLM 20261011T133829Z). These count as failures but are not vendor outages.
4. **Sessions wait too long and retry the same reviewer.** Timeouts of 30–120 minutes; the rotation rule says "move to the next reviewer within minutes" (`docs/reviewer-rotation-rules.md` rule 2) but nothing enforces it per session.
5. **The merge gate in ordinary repos is procedural**, so the week's policy change is a rules-and-gates change, not a GitHub change.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| Plain seven-day freeze with reviews still gating merges | Albert: "we can't stop all work because of that" (all-four-down case). |
| Treat reviews as advisory everywhere including shared-db/production | A wrong migration or production apply costs real money; owner rulings keep those gates (2026-09-28, 2026-10-14). |
| Shorter door timeouts only | Healthy reviews legitimately take 20–40 minutes; a short timeout kills good reviews (rejected in `plan_reviewer-stability-24h.md` §7 too). Fast-fail must be signal-based, not just time-based. |
| Per-machine pause (existing `ai-review-preflight pause`) as the skip list | Albert asked for "at least for that session"; a machine-wide pause would also block other sessions that might succeed, and it needs a verified failure class. Per-session is additive. |
| Skip GitHub merge-queue / change rulesets | Out of scope; not needed since the AI gate is procedural in ordinary repos. |
| Bulk transcript extract as the week's evidence | Done once; scoreboard + incident packages are cheaper and already structured. |
| Keep repairing during the week "just this one" | Defeats the baseline. Allowed operations are enumerated in §11; everything else waits. |

## 8. Design decisions already made

**Locked (do not relitigate):**

| Decision | Reason / source |
|---|---|
| Reviews are still sent for every change during the week | Albert: "keep sending things to the reviewers … just log the issue" |
| Ordinary repos merge on CI with `unreviewed` marker; post-hoc review queue; late REJECT → fix-forward issue, never rollback | Albert accepted "two tiers" (2026-10-21) |
| Production (`infrastructure`, `production`, `deployment` classes) and `shared-db` keep the full gate; work waits on branch | Owner rulings 2026-09-28, 2026-10-14; Albert did not contradict |
| Fast-fail threshold: a reviewer is "failed for this session" on the first terminal failure, or on no provider output for 5 minutes after start (signal-based), or on any `provider_unavailable`/`insufficient_quota`/`spawn`/`auth` class | Albert: "sense a reviewer failure more quickly and move on" |
| Per-session skip list, keyed by `session_id` (the same id the scoreboard records) | Albert: "not try that reviewer again (at least for that session)" |
| Freeze window: 7 days from the fleet install of step 6; no reviewer-code PRs, no fleet installs, except the allowed operations in §11 | Baseline needs a still target |
| Allowed during freeze: restart a hung process, recharge credit, reset/rotate a key, clear a quarantine, re-pin a vendor CLI that self-updated **back to the frozen pin** | Albert accepted "routine operations allowed" |
| A reviewer down a full day with no routine operation restoring it ends the week early for that reviewer; log the isolated cause; the other three continue | Albert accepted |
| Evidence of record: scoreboard + events + incident packages, tallied daily by `ai-reviewer-issue`/`reviewer_events.py`, not transcripts | Cost and structure |
| One code path for all providers (#1834): fast-fail and skip live in `tools/lib/review-lifecycle-core.sh` and `bin/ai-review`, never in a door | Existing rule |
| No new CI jobs, Windows CI runs or test suites | Albert 2026-10-18 |

**Open (implementer's judgment, criteria given):**

- Exact name/location of the per-session skip store: default `~/.local/state/ai-devops/session-skip/<session_id>.json` (Windows: `%LOCALAPPDATA%\ai-devops\session-skip\`). Criterion: lives under the existing state root, never under the repository, survives a worktree change.
- Whether `--detach` writes a pidfile or uses the existing lifecycle `owner_pid` field. Criterion: `ai-review-lifecycle finish` must still find the run.
- How `unreviewed` is marked: PR label `unreviewed-week` plus a line in the squash commit body. Criterion: `gh pr list --label unreviewed-week` and `git log --grep` both find every one.

## 9. The plan — numbered, ordered, executable steps

Fresh worktree from `origin/main`. Declare `ai-task-gates start --class reviewer-safety` for steps 1–4 (shared review code), `--class prose` for step 5 docs, `--class installation` for step 6. Steps 1–3 are shared review code and therefore need an exact-head independent review before merge (`config/task-gates.json` `reviewer-safety`); use the Windows-safe route from #1783 (`ai-release-live-check fleet`). This is the last reviewed reviewer-code change before the freeze. Steps 1, 2, 3 can be built in parallel in separate worktrees but must land in one PR train (1 → 2 → 3) because 3 depends on 1 and 2.

### Phase A — build (before the freeze)

#### Step 0 — Register

- Open the owner issue in popcre/ai-devops with the §1 quote, link this plan and the handoff, add checklist `- [ ] live proof (seven-day tally posted)`.
- Add this plan to `docs/pending-work.md` and a row to `docs/task-router.md` ("Reviewer observation week / fast-fail / unreviewed merges" → this plan STATUS).
- **Gate:** issue number written into the STATUS header above; `grep plan_reviewer-observation-week docs/pending-work.md docs/task-router.md` both hit.

#### Step 1 — Fast-fail detector (shared lifecycle)

- **Where:** `tools/lib/review-lifecycle-core.sh` (new function `lifecycle_fast_fail_watch`), called from `bin/ai-review-engine` around the door invocation. Doors stay untouched.
- **Behaviour:** after `started` is recorded, watch the door's log/stdout file. Declare `fast-fail` and kill the owned process tree when any of: (a) no bytes written for 300 s before the first model response (`AI_REVIEW_FIRST_OUTPUT_SECONDS`, default 300); (b) output matches a known fatal pattern (`spawn .*NotFound|E2BIG|command not found|429|insufficient_quota|allowance|project_token_login_failed|unknown option|not a repository top level|ENOENT.*governed-source`); (c) door exit non-zero. Record `finished` with `failure_class` = `fast-fail:<reason>` and `verdict=BLOCKED` on the scoreboard. Never on a healthy review that is producing output (the existing door timeout still applies to those).
- **Dependencies:** none.
- **Gate:** `bash tests/test-ai-review-lifecycle.sh` green with new cases `fast_fail_on_silent_start`, `fast_fail_on_fatal_pattern`, `fast_fail_never_on_streaming_review` (a fixture door that prints a line every 60 s for 10 minutes must not be killed).

**Adversarial cases (provider stdout is a trust boundary):**

| External input | Hostile case | Test |
|---|---|---|
| Door stdout | Contains the string `429` inside a normal diff hunk | `fast_fail_pattern_only_on_stderr_or_status_lines` |
| Door stdout | Prints `VERDICT: APPROVE` then hangs | `fast_fail_after_verdict_still_records_verdict` |
| Door stdout | Binary/garbage bytes | `fast_fail_tolerates_binary_output` |
| Clock | System clock jumps backward mid-watch | `fast_fail_uses_monotonic_clock` (use `EPOCHREALTIME`, see memory `uutils-date-3n-drops-leading-zeros`) |

#### Step 2 — Per-session skip list

- **Where:** `bin/ai-review` (front door) and `bin/ai-review-pool` (draw). New helper `tools/lib/review-session-skip.sh` with `skip_add <session_id> <provider> <reason>`, `skip_has`, `skip_list`. Store per §8 open decision.
- **Behaviour:** on any `fast-fail` or terminal failure from step 1, add the provider to the current session's skip list. Before drawing, `bin/ai-review` and `bin/ai-review-pool` exclude skipped providers and print one line: `ai-review: <provider> skipped for this session (<reason>, <time EDT>)`. If every rotation reviewer is skipped, print `ai-review: all reviewers skipped this session` and exit with the new code 75 (`EX_TEMPFAIL`), which step 4 consumes. The caller session id is resolved once in `tools/lib/review-lifecycle-core.sh` as the first non-empty of `AI_CALLER_SESSION_ID`, `CLAUDE_CODE_SESSION_ID`, `CODEX_SESSION_ID`, `MIMO_SESSION_ID`, `ZCODE_SESSION_ID`, else the parent shell's process start time + pid; it is written to every `started`/`finished` event and scoreboard row as `caller_session_id` (step 1) and keys the skip store (step 2).
- **Gate:** `bash tests/test-pool-dispatch-doors.sh` and `bash tests/test-ai-review-engine.sh` green with `skip_excludes_provider_within_session`, `skip_does_not_leak_to_other_session`, `all_skipped_exits_75`.

#### Step 3 — Non-blocking dispatch and outcome recorder

- **Where:** `bin/ai-review` new flag `--detach`; `bin/ai-review-engine` runs the lifecycle in the background with `nohup`/`setsid` (Windows: `Start-Process` through the existing `bin/ai-review.cmd` shim); prints the `run_id` and returns immediately. New subcommand `ai-review outcome <run_id> [--wait SECONDS]` reads the scoreboard/events for that run.
- **Behaviour:** everything that happens today (receipt, packet, sandbox, verdict record, incident package on failure) still happens; only the caller does not wait. `ai-review outcome` prints `pending|APPROVE|REJECT|REVISE|BLOCKED` and the report path.
- **Gate:** `bash tests/test-ai-review-engine.sh` with `detach_returns_run_id_in_under_10s`, `detached_run_records_scoreboard_row`, `outcome_reports_pending_then_verdict`.

#### Step 4 — Merge policy for the week (ordinary repos)

- **Where:** `config/task-gates.json`: new gate `observation-week-unreviewed-merge` admitted for class `code` and `prose` only, when the file `/etc/ai-devops/observation-week.json` (Windows: `C:\ProgramData\ai-devops\observation-week.json`) exists with `{"start":"<ISO>","end":"<ISO>","allowed_classes":["code","prose"]}`. `bin/ai-task-gates check --before ship` passes when either an exact-head APPROVE exists **or** the window file is live and the session has run `ai-review … --detach` for the head (run_id recorded) **or** `ai-review` returned 75 (all skipped). It prints `MERGE-UNREVIEWED` and the caller must add label `unreviewed-week` and the body line `Unreviewed merge (observation week, run <run_id>|all-skipped)`.
- **Post-hoc queue:** `bin/ai-review-posthoc` (new, small) lists PRs with label `unreviewed-week` and no scoreboard verdict for their merged head, and runs `ai-review <next usable provider> final-check --assert-head <merged sha>` on them when at least one reviewer is usable. A REJECT opens a fix-forward issue titled `Post-hoc REJECT on <repo>#<pr>` and links the report; it never reverts.
- **Production/shared-db:** no change. `shared-db` classes and `infrastructure|production|deployment` are not in `allowed_classes`; the gate refuses as today. Document on the issue that such work waits on its branch until a reviewer is back.
- **Gate:** `bash tests/test-ai-task-gates.sh` with `observation_window_admits_code_merge_with_detached_run`, `observation_window_admits_all_skipped_75`, `observation_window_never_admits_shared_db_or_production`, `observation_window_expired_refuses`; `bin/ai-review-posthoc --dry-run` lists the expected PRs in a fixture repo.

**Adversarial cases:**

| External input | Hostile case | Test |
|---|---|---|
| Window file | Dates reversed / in the future / malformed JSON | `observation_window_malformed_refuses` |
| Window file | `allowed_classes` includes `shared-db` | `observation_window_rejects_protected_classes_in_file` |
| PR label | Label present but no run_id or 75 evidence | `unreviewed_label_without_evidence_refuses` |

#### Step 5 — Global rules text for the week

- **Where:** `templates/system/CLAUDE-global.md`, `AGENTS-global-codex.md`, `AGENTS-global-mimo.md`, `AGENTS-global-zcode.md`, `REVIEWER-global.md`; `docs/reviewer-rotation-rules.md` (new rule 15); `docs/standing-rules-details.md` (merge steps).
- **Text (same paragraph everywhere):** "Observation week (dates): run every review with `--detach`. If a reviewer fails or `ai-review` reports it skipped, do not retry it this session. When `ai-task-gates check --before merge` prints `MERGE-UNREVIEWED`, merge on green CI, add label `unreviewed-week`, and continue. Shared-db, production, infrastructure and deployment changes still wait for an exact-head APPROVE. Do not open reviewer-repair PRs or install the toolkit during the week; log failures with `ai-reviewer-issue` and move on. Allowed operations: §11 of plan_reviewer-observation-week.md."
- **Gate:** `python3 tools/context-audit/context-audit.py --strict` passes (the #1912 globals trim currently fails it; resolve by keeping the paragraph under 90 words); `bash tests/test-client-globals-required-phrases.sh` and `bash tests/test-ai-render-globals.sh` green.

#### Step 6 — Fleet install and freeze declaration

- Install the merged head on edge-dev3, edge-dev, 916, 4837 by their protected routes (`update.sh` / `install-ai-devops-windows`); hetz via u2giants/ansible per #1783. Write the window file on each host (step 4 format) with `start` = install time, `end` = start + 7 days. Post the freeze declaration on the owner issue with the installed SHA per host and the EDT start time.
- **Gate:** `ai-review doctor` on each host shows the installed SHA; `ai-task-gates check --before merge` in a scratch `code` worktree prints `MERGE-UNREVIEWED` after a `--detach` run; `ai-release-live-check fleet --target-head <sha>` statuses success.

### Phase B — observe (the seven days)

#### Step 7 — Daily tally

- Each day at ~9 AM EDT (any session, or the watchdog duty pool per `docs/watchdog-duty-pool.md`): run `python3 tools/reviewer_events.py tally --since <start> --by provider,failure_class,host` (add this subcommand in step 1's PR if absent; it is a read of the two jsonl files) on edge-dev3 and edge-dev, and `ai-reviewer-issue list` on both. Post one comment per day on the owner issue: per provider: runs, verdicts, fast-fails by reason, time-to-fail median, skipped sessions, unreviewed merges, post-hoc results, routine operations performed (from the §11 log).
- A reviewer with zero successes in 24 h and no routine operation pending: post "ended early for <provider>: <isolated cause>" and continue with the others.
- **Gate:** seven daily comments exist; each names its data source paths.

### Phase C — land the findings

#### Step 8 — Post-hoc drain and findings report

- Run `bin/ai-review-posthoc` until the `unreviewed-week` queue is empty or only blocked by a still-down reviewer. Open fix-forward issues for REJECTs.
- Write `docs/reviewer-observation-week-<start-date>.md`: per-provider failure rate with nobody repairing, failure classes ranked, how many were "strict parser" versus vendor versus environment, how many unreviewed merges and how many post-hoc REJECTs, and a one-paragraph recommendation per provider. Every number cites the tally comment or jsonl path.
- **Gate:** report merged (prose PR); `- [ ] live proof` on the owner issue ticked with a link to the report.

#### Step 9 — Closeout decision

- Present Albert the business choice: keep fast-fail + per-session skip permanently (recommended regardless), keep or drop non-blocking merges in ordinary repos, and which two or three defect classes to fix next. Remove the window files. Update STATUS here and in `docs/pending-work.md`; mark the handoff closed.

## 10. Tests required

Named in each step's gate. Suites that must stay green on both OSes before the step-6 install: `tests/test-ai-review-lifecycle.sh`, `tests/test-ai-review-engine.sh`, `tests/test-pool-dispatch-doors.sh`, `tests/test-ai-task-gates.sh`, `tests/test-client-globals-required-phrases.sh`, `tests/test-ai-render-globals.sh`, `tests/test-ai-review-preflight.sh`. No new suite files (owner constraint 2026-10-18); add cases to these. Synthetic reviewer tests need `AI_REVIEW_TEST_ISOLATION=1`, a private `AI_REVIEW_EVENT_DIR` and redirected scoreboard paths (memory `reviewer-suites-stub-the-privacy-gate`).

## 11. Constraints, standing rules, and gotchas

- Branch + PR + merge queue; never push to `main`. Prose-only PRs: `bin/ai-doc-safety` then `gh pr merge --squash --admin`. Code PRs: merge queue; steps 1–4 are shared review code and need exact-head independent review (last one before the freeze).
- Sign every GitHub post `Posted by Claude chat <id> on <machine>`.
- Every time in EST/EDT.
- Shared review code must not branch on provider name (#1834). Doors are not edited.
- Windows: Git Bash for bash suites; CRLF trap (memory `windows-crlf-breaks-bash-scripts`); PowerShell 5.1 strips native quotes (`ps51-strips-native-arg-quotes`); 916's checkout is on `D:`.
- Never `git pull` in the installed checkout; use the protected update route.
- **Allowed operations during the freeze (log each on the owner issue with time EDT and host):** kill/restart a hung reviewer process; recharge a provider credit; rotate or reset a key via 1Password (`secrets-to-1password`); `ai-review-preflight clear <provider>`; re-pin a vendor CLI that self-updated back to the frozen pin (`config/provider-cli-versions.json`, no other change); OS updates that do not touch the toolkit. **Not allowed:** any PR under `bin/`, `tools/lib/review-*`, `config/review*`, `config/task-gates.json`, `install.sh`, `update.sh`; any `update.sh`/installer run on a review host; changing timeouts; changing rotation membership.
- **Owner exception, safety checker (Albert, 2026-10-22, verbatim: "make an exception for the checker for files that are supposed to change from run-to-run. Not for the checker application itself."):** the checker's per-run files (task-state records, gate overrides and the observation window file it reads) may change during the freeze. The checker program (`bin/ai-task-gates`, `config/task-gates.json`, its tests) stays frozen; ai-devops#2004 therefore waits until the freeze ends.
- The two sibling repair programmes (#1783, #1822, #1678) are paused for the week; post a one-line note on each at freeze start and at freeze end.
- Secrets: 1Password `vibe_coding`; never in chat, args, logs.

## 12. Access and environment

- Hosts: edge-dev3 (this machine, Ubuntu), edge-dev (Windows, `ssh edge-dev`, PowerShell for file reads), 916 and 4837 (Windows, see `templates/system/machine-atlas.md`), hetz (Ubuntu, `ssh -i 916-alien` per memory `hetz-ssh-needs-916-alien-key`; installed checkout root-owned, updates via u2giants/ansible).
- GitHub: `gh` authenticated as `u2giants`; repos popcre/ai-devops, popcre/shared-db.
- 1Password service account token file: `~/.config/ai-devops/op-service-account` (edge-dev3).
- State roots: `~/.local/state/ai-devops/` (Linux), `%LOCALAPPDATA%\ai-devops\` (Windows). Incident packages: `ai-reviewer-issue path`.

## 13. Definition of done, risks, open questions

**Done when:** steps 0–6 merged and installed on all five hosts with the window file; seven daily tallies posted; post-hoc queue drained; findings report merged; `- [ ] live proof` ticked; Albert given the step-9 choice; STATUS table and `docs/pending-work.md` updated; this plan's handoff marked closed.

**Risks and rollback:** a defect in fast-fail could kill healthy reviews → the streaming-review test and a 300 s first-output window guard it; rollback is `AI_REVIEW_FIRST_OUTPUT_SECONDS=0` (disables the watch) and deleting the window file (restores full gating) with no reinstall. Unreviewed merges may land a real bug → post-hoc review and fix-forward issues; production and shared-db never admitted. The freeze may be broken by another session → the globals paragraph and the issue note; `ai-task-gates` refuses `installation` class on review hosts while the window file exists (add to step 4).

**Open questions:** none for mechanism. Business: step 9 choices are Albert's.

---

## Self-audit (2026-10-21, 4:35 PM EDT)

1. *Could a brand-new session execute this without asking?* Yes: §2 names every file and current timeout; §5 lists what exists (pause store, circuit breaker, pass reuse, scoreboard fields); §9 gives files, behaviour, gates and test names per step; §12 gives access. Gap found and fixed: the `session_id` source and the exit-code 75 contract were implicit; now stated in step 2.
2. *Does it carry every piece of background and what was ruled out?* Yes: §3 quotes Albert verbatim; §6 the diagnosis; §7 seven rejected approaches including the plain freeze Albert questioned and the per-machine pause.
3. *Is the goal clear enough to steer when a step is wrong?* Yes: §1 states the three outcomes and the explicit "goal wins" rule with the two things that must never be traded (hiding failures, unreviewed production).
