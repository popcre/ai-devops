# Implementation plan — Blacksmith Windows throughput

**Repository:** `popcre/ai-devops`

**Owner issue:** [#210](https://github.com/popcre/ai-devops/issues/210)

**Delivery PR to revise:** [#355](https://github.com/popcre/ai-devops/pull/355)

**Authored:** 2026-09-10 on `edge-dev` by Codex
**Handoff:** [`HANDOFF.d/2026-09-10T0117Z-edge-dev-codex-blacksmith-throughput-plan.md`](HANDOFF.d/2026-09-10T0117Z-edge-dev-codex-blacksmith-throughput-plan.md)

## STATUS — read this first

A fresh implementing session starts at **Step 1**. Do not merge the current
duplicate-full-pack form of PR #355. The bootstrap workflow in Step 4 must be on
`origin/main` before PR #355 can dispatch and qualify it.

| Step | Deliverable | State | Evidence |
|---:|---|---|---|
| 1 | Refresh live PR, runner, workflow, provider, and cost state | ⬜ open | — |
| 2 | Capture per-suite Windows timings and freeze the six-shard allocation | ⬜ open | — |
| 3 | Add manifest-driven exact-once shard selection and mutation tests | ⬜ open | — |
| 4 | Land the separately dispatchable Blacksmith shard workflow | ⬜ open | — |
| 5 | Revise PR #355 to orchestrate 3 GitHub + 3 Blacksmith shards with recovery | ⬜ open | — |
| 6 | Add aggregation, fork behavior, supersession, and queue-health tests | ⬜ open | — |
| 7 | Qualify normal, unavailable-provider, and real-test-failure paths | ⬜ open | — |
| 8 | Final exact-head review, merge-queue landing, and documentation closeout | ⬜ open | — |

## 1. Ultimate goal

Code pull requests must stop waiting 90–120 minutes for one serial Windows job.
Use GitHub-hosted and Blacksmith Windows machines as six real concurrent workers,
with three exclusive shards on each provider during the normal internal-PR fast
path. Preserve every test, keep failures visible, and recover Blacksmith shards
onto GitHub when Blacksmith cannot start them. The measured target is a 20–25
minute Windows critical path; 15 minutes is not honest while the Grok reviewer
suite alone measures about 19 minutes before setup.

The result must remain safe when Blacksmith is down, its allowance is exhausted,
a fork opens a PR, a new commit supersedes an old run, or a test genuinely fails.
If any implementation step conflicts with this goal, the goal wins—stop and flag
the conflict rather than weakening coverage or hiding a failure.

## 2. What this application is

`popcre/ai-devops` is POP Creations' public recovery and verification toolkit for
its multi-model AI workflow. It is not an application server. GitHub Actions is
the delivery control plane. The repository is
<https://github.com/popcre/ai-devops>; `main` is protected and finished work
lands through a pull request and merge queue.

Windows verification currently has three roles in
`.github/workflows/verify.yml`:

- GitHub-hosted `windows-2025` performs general Windows/Git Bash/PowerShell proof.
- Blacksmith `blacksmith-4vcpu-windows-2025` is being qualified as additional
  ephemeral hosted capacity in PR #355.
- `[self-hosted, Windows, X64, ai-devops-windows-qualified]` runs timing-sensitive
  Codex and Grok reviewer safety tests on a stable physical machine.

The suite inventory lives in `config/ci-suite-manifest.json`; Bash selection is
implemented in `tests/test-all.sh`, PowerShell entry is `tests/test-all.ps1`, and
workflow invariants are tested by `tests/test-workflow-policy.sh` and
`tests/test-windows-bash-selection.sh`.

## 3. What triggered this work

Blacksmith's migration wizard opened PR #355 by replacing compatible GitHub
runner labels. Albert did not want replacement; he wanted more Windows capacity.
The branch was repaired into an additive full Blacksmith lane, but this did not
reduce the critical path because the original 73–95+ minute GitHub Windows pack
still ran in parallel as one monolith.

Albert then made the business priority explicit: a small overlapping Blacksmith
compatibility check is insufficient while delivery stops behind 90–120 minute
Windows runs. Two Grok 4.6 turns reviewed the stronger 3+3 proposal. The final
review conditionally accepted exclusive Blacksmith shards only with a separately
cancellable workflow and visible GitHub recovery when Blacksmith cannot start.
Review artifact:
`.ai/reviews/grok-combined-windows-sharding-20260910T010919Z-417695.md`.

## 4. Scope

### In scope

- Six measured Windows shards for ordinary code PRs: three GitHub, three
  Blacksmith.
- Exact-once manifest ownership for all ordinary Windows-required Bash and
  PowerShell tests.
- A sibling Blacksmith workflow that can be cancelled independently.
- An Ubuntu orchestrator that dispatches, observes, cancels, and visibly reroutes
  Blacksmith shards that cannot start.
- Full GitHub execution for fork PRs.
- The existing qualified local reviewer-safety lane.
- Complete scheduled/manual backstops on both providers, with Blacksmith cadence
  determined from measured spend.
- Tests for omissions, duplicates, misrouting, dispatch failure, no pickup,
  supersession, fork routing, and the rule that a real test failure never reroutes.
- Documentation, exact-head review, merge queue, and landed-main verification.

### Not in this plan

- Weakening, deleting, quarantining, or marking any test allowed-to-fail.
- Raising timeouts to disguise timing failures.
- Making a local physical runner the sole owner of required coverage.
- Adding Windows jobs to the required-check ruleset; that remains final cutover
  issue #166 after merge-group reporting is designed.
- Replacing GitHub-hosted capacity with Blacksmith.
- Production/cloud infrastructure changes, database work, or secrets changes.
- Nightly Blacksmith full-pack runs without live allowance and cost evidence.
- Solving reviewer overlap issue #260 except where shard accounting must describe
  the deliberate extra local timing copy.

## 5. Current state of the code

The isolated worktree is
`C:\repos\ai-devops-worktrees\blacksmith-additive-355`. Its local branch is
`codex/blacksmith-additive-355`; the remote PR branch is
`blacksmith-migration-9a7f974`. The pushed PR head is
`92ba1e9a4c88f97f9e2862e233231312cb6b03d8`.

PR #355 currently:

- restores GitHub-hosted Ubuntu and `windows-2025` jobs;
- preserves the qualified local reviewer lane;
- adds a separate Blacksmith job that duplicates the complete ordinary PR
  Windows pack;
- pins Python 3.13 for Blacksmith;
- makes Windows ACL proof accept a nonempty current account name or the same
  nonempty exact SID;
- forces `grep -h` in the portable fact fallback;
- guards Blacksmith/local jobs from fork PRs and skips Windows on `merge_group`.

This state is qualification evidence, not the throughput solution. PR #355
remains conflicted with current `main`. Exact code-head run `34418585172`
completed with Linux, GitHub Windows, and local reviewer lanes green, but its
Blacksmith job `102688877305` failed the same three fact-search fallback checks
and private-ACL check despite the attempted `grep -h` and guarded name-or-SID
repairs. Do not rerun that unchanged 50-minute path: Step 1 must first reproduce
or instrument those exact commands in a short Blacksmith diagnostic. Any push or
rebase invalidates the prior Claude exact-head approval for `92ba1e9a`.

Uncommitted session documentation currently exists in this worktree:

- `docs/blacksmith-windows-runners.md`
- `docs/task-router.md`
- `plan_repo-throughput-restructure.md`
- `HANDOFF.d/2026-09-10T0007Z-edge-dev-codex-blacksmith-windows-pool.md`

This new plan and its handoff must be committed and pushed with those owned docs.
Do not stage unrelated files. The current suite manifest declares 69 Bash suites,
18 PowerShell suites, and an ordinary Windows-sensitive Bash subset of 23. Recount
from the live tree before implementing schema changes.

## 6. Key findings and root cause

1. The bottleneck is serial suite execution, not a shortage of available GitHub
   hosted machines. Sharding creates the drastic wall-clock improvement.
2. Albert nevertheless wants Blacksmith used as real capacity. Therefore three
   normal-path shards may be exclusive to Blacksmith, provided their exact work
   reroutes to GitHub when Blacksmith cannot start.
3. `timeout-minutes` begins only after a runner picks up a job. A Blacksmith job
   that never starts can remain queued for roughly 24 hours. A recovery job using
   `needs:` cannot start until that queued job finishes, so in-workflow fallback
   does not work.
4. GitHub Actions cannot cancel one queued job while preserving the rest of the
   same workflow run. Blacksmith work must therefore run in a separately
   dispatchable sibling workflow that the parent orchestrator can cancel.
5. A workflow added only in PR #355 cannot reliably dispatch itself because
   `workflow_dispatch` requires the workflow on the default branch. The sibling
   workflow must land first, then PR #355 must rebase and use it.
6. Blacksmith test failure and Blacksmith inability to start are different. Only
   inability to dispatch/start may reroute. Rerouting a red test to GitHub would
   green-wash provider-specific defects.
7. The images are not identical. This session found missing Python, ACL identity
   rendered as SID rather than name, and a `grep` output difference. Provider
   assignment must be explicit and complete scheduled/manual backstops must
   remain.
8. Forks cannot use guarded Blacksmith/local jobs, so every one of the six shards
   must materialize on GitHub for fork PRs.
9. Grok review measured about 1,149 seconds and sets the critical-path floor.
   Six shards do not make that suite faster; they balance everything else below
   it. Put Grok on a GitHub shard that starts immediately.
10. Existing shard machinery is insufficient. The manifest has one flat Windows
    group; `--only` uses substring matching and cannot safely define exact shards.
11. All Windows jobs currently skip `merge_group`, while `linux-offline` is the
    sole queue gate. Making a skipping Windows context required would recreate
    the previous 120-minute merge-queue hang.

## 7. Approaches considered and rejected

1. **Keep PR #355's duplicate full Blacksmith lane.** Rejected: it adds spend and
   provider evidence but leaves the full GitHub monolith as the critical path.
2. **Use Blacksmith only for a small overlapping sentinel.** Rejected as the main
   throughput answer: it does not add enough productive capacity for Albert's
   stated priority. A small overlap may still exist only where deliberately
   justified; it is not the architecture.
3. **Run all shards only on GitHub.** Technically cheapest and equally fast if
   hosted concurrency remains available, but rejected as the chosen owner intent:
   Blacksmith must carry real work and provide added provider capacity.
4. **Assign Blacksmith-exclusive shards without recovery.** Rejected: app,
   billing, allowance, or provisioning failure can leave the run yellow for a day.
5. **Use `timeout-minutes` or `needs: blacksmith` for fallback.** Rejected: the
   timeout clock does not start while queued and dependent recovery waits too.
6. **Probe ephemeral runners before dispatch.** Rejected: scale-from-zero can look
   like no runner, and the normal token lacks the runner-list permission used by
   the separate watchdog credential.
7. **Rerun a red Blacksmith test on GitHub automatically.** Rejected: this hides
   real image compatibility failures.
8. **Use `--only` patterns as shard definitions.** Rejected: substring overlap can
   duplicate or omit suites silently.
9. **Make Windows shards required immediately.** Rejected in this plan: they skip
   `merge_group`; required-check cutover belongs to #166 after queue convergence.
10. **Target 15 minutes.** Rejected until the 19-minute Grok pole is reduced by a
    separately proven test optimization; do not weaken or move it local-only.

## 8. Design decisions

### Locked by Albert, 2026-09-10

- The primary business goal is drastic throughput improvement, not merely an
  extra compatibility signal.
- Blacksmith is additive and must not replace GitHub-hosted or local capacity.
- Blacksmith should perform real exclusive normal-path work, not only a tiny
  overlapping check.
- No capability or test coverage may be removed to obtain speed.

### Locked by evidence

- Use six measured shards: three GitHub, three Blacksmith for internal PRs.
- Keep Grok and Codex required PR coverage on GitHub and retain their deliberate
  extra timing proof on the qualified local lane.
- Use a separately cancellable Blacksmith workflow plus parent Ubuntu
  orchestrator; never in-run queued fallback.
- Reroute only dispatch/no-pickup failures, never a test failure after pickup.
- Fork PRs run all six shards on GitHub.
- Keep all Windows jobs off `merge_group` and out of required contexts in this
  change; `linux-offline` remains the queue gate.
- Use manifest-defined shard IDs and exact-once union/duplicate/misroute checks.
- Preserve the current portability fixes and public-fork guards.

### Bounded implementer judgment

- Exact membership of the other 21 Windows-sensitive Bash suites, after measuring
  actual per-suite durations. Balance by time, not count; aim for 12–18 minutes
  before setup while Grok is the named 20–25 minute pole.
- Pickup deadline between 90 and 180 seconds, chosen from observed healthy
  Blacksmith startup data with headroom.
- Per-shard timeouts from measured p90 plus documented headroom; do not retain a
  100-minute monolithic ceiling without evidence.
- Blacksmith complete-pack cadence after one measured week and live allowance/
  billing verification. GitHub complete remains at least weekly.

## 9. Implementation plan

### Phase A — live baseline and shard contract

#### Step 1 — refresh every drift-prone fact

From a new current-upstream isolated worktree, read `AGENTS.md`, this plan's
STATUS, the linked handoff, and `docs/blacksmith-windows-runners.md`. Query live
PR #355 head/conflict/reviews/checks, `origin/main`, runner inventory, workflow
runs, repository required contexts, fork approval, and official Blacksmith
concurrency/pricing/exhaustion behavior. Inspect open worktrees/PRs before edits.

**Verification gate:** record exact SHA, PR state, run conclusions, runner states,
ruleset contexts, provider allowance/exhaustion behavior, and source URLs in a
new artifact under `tests/verification/repo-throughput/`; no value comes only
from this plan's historical snapshot.

#### Step 2 — measure and allocate six shards

Extract per-suite duration lines from completed GitHub Windows run `34237405958`,
final run `34418585172` if complete, and a completed Blacksmith run. Recount
current Bash/PowerShell manifests. Put `test-ai-grok-review.sh`,
`test-ai-codex-review.sh`, image-sensitive suites, and all PowerShell tests on
GitHub shards; start Grok immediately. Balance remaining eligible suites across
three Blacksmith shards. Document why each provider-sensitive suite is placed.

**Verification gate:** a committed machine-readable timing/allocation artifact
shows all required suites, provider, shard ID, measured seconds/source run, shard
totals, and estimated critical path; union equals the current ordinary Windows
selection and no suite is missing or repeated among the six primary shards.

#### Step 3 — implement manifest-driven shard selection

Update `config/ci-suite-manifest.json` to a versioned schema with six named shard
groups and explicit provider ownership. Extend `tests/test-all.sh` with
`--windows-shard <id>` and `tests/test-all.ps1` with `-WindowsShard <id>` so a
shard runs only its exact manifest membership. Reject unknown IDs, empty shards,
duplicates, undiscovered files, missing required suites, and provider misroutes.
Do not implement with `--only` substring patterns.

Extend `tests/test-windows-bash-selection.sh` and
`tests/test-workflow-policy.sh`; add focused PowerShell selection tests if no
existing file cleanly owns them.

**Verification gate:** focused tests pass for all six shards and mutation fixtures
fail for omission, cross-shard duplicate, unknown suite, empty shard, wrong
provider, missing workflow matrix ID, and overlapping-name patterns.

**Natural context cut:** after Step 3, update STATUS/evidence, use `fresh-session`,
and reread Phases B–D against current `origin/main` before continuing.

### Phase B — land independently cancellable Blacksmith execution

#### Step 4 — bootstrap `windows-blacksmith-shards.yml` on main

Create `.github/workflows/windows-blacksmith-shards.yml` as a reusable sibling
with `workflow_dispatch` inputs for exact SHA, parent run, PR number, and the
three Blacksmith shard IDs. Use a three-entry matrix on
`blacksmith-4vcpu-windows-2025`, `fail-fast: false`, exact-SHA checkout, pinned
Python 3.13, explicit `jq`/Python probes, manifest shard entrypoint, minimal
permissions, per-shard timeout, and concurrency keyed by PR/SHA with
`cancel-in-progress: true`.

Land this bootstrap in its own branch/PR before revising PR #355's dispatcher.
It may include selection machinery from Step 3 if required, but must not claim
end-to-end fallback until the parent orchestration lands. Follow repository
task gates, review, tests, merge queue, and landed-main proof.

**Verification gate:** the sibling workflow file and required shard entrypoint
are on `origin/main`; a manual exact-SHA dispatch starts all three Blacksmith
legs, reports independent results, and a superseding dispatch cancels its older
sibling run without touching unrelated GitHub work.

### Phase C — revise PR #355 into the 3+3 fast path

#### Step 5 — rebase and add parent orchestration/recovery

Rebase PR #355 on the Step 4 landing commit. Replace its duplicate full
Blacksmith job with:

- a three-entry GitHub `windows-2025` primary matrix that starts immediately;
- an Ubuntu `windows-blacksmith-orchestrator` with `actions: write` and
  `contents: read`, dispatching the sibling for the exact PR SHA;
- bounded polling of the sibling job API until every Blacksmith leg starts or
  the measured 90–180 second pickup deadline expires;
- cancellation of the sibling and output `reroute=true` on dispatch failure or
  no pickup;
- a predeclared three-entry GitHub recovery matrix running the exact same
  Blacksmith shard IDs only when `reroute=true`;
- failure without recovery when a Blacksmith leg started and then failed.

Make rerouting loud through warnings and job summary. Preserve PR-number
`cancel-in-progress`; cancel the sibling when the parent is superseded. Keep
fork/local/Blacksmith guards and skip all Windows paths on `merge_group`.

**Verification gate:** an internal PR run shows three GitHub and three Blacksmith
primary shards on the same exact SHA, while simulated no-pickup cancels the
sibling and runs exactly the three recovery shards on GitHub. The parent run
terminates; no queued sibling remains.

#### Step 6 — aggregate coverage and harden workflow policy

Add a stable `windows-pr-coverage` aggregator inside `verify.yml`. It must use a
cancel-aware condition, not `if: always()`, and fail unless every one of the six
manifest shard IDs has exactly one successful primary/recovery route. It must
fail on a red GitHub or started-Blacksmith test and must not green-wash through
recovery. Keep it non-required in this PR and skipped on `merge_group`.

Replace fragile job-count, job-boundary `sed`, `windows_skips == 3`, invocation
count, and 100-minute timeout assertions in `tests/test-workflow-policy.sh` with
manifest-driven structural checks. Add deterministic fixtures or a test harness
for dispatch failure, queued/no-pickup, successful sibling, red sibling,
superseding push, prose-only classification, fork routing, and aggregation.

**Verification gate:** every happy-path fixture passes; injected omitted shard,
duplicate success, provider misroute, swallowed test failure, forbidden
`if: always()`, stale 100-minute timeout, and uncancelled sibling each fail with
a plain explanation.

**Natural context cut:** after Step 6, update STATUS/evidence, use `fresh-session`,
and reread Phase D plus live PR/runner/provider state.

### Phase D — qualification and landing

#### Step 7 — run real normal and failure qualifications

Run focused selection/policy tests first. Then qualify one exact PR head through:

1. normal internal 3+3 execution;
2. Blacksmith cannot-start/dispatch-failure with visible exact-shard GitHub
   recovery and sibling cancellation;
3. a deliberate Blacksmith test failure after pickup proving no recovery;
4. fork-equivalent routing proving all six shards materialize on GitHub;
5. superseding commit proving parent and sibling cancellation;
6. prose-only PR proving expensive paths skip;
7. scheduled/manual complete-pack proof on both providers.

Record queue time, setup time, suite time, critical path, runner-minutes, cost,
failure-detection time, exact SHA, and run URLs. Restore every deliberate defect
before final evidence. Do not publish partial success as acceptance.

**Verification gate:** normal Windows critical path is 20–25 minutes or has a
named evidence-backed exception; every fault produces the specified visible
terminal result; no required suite disappears; exact restored tree is clean.

#### Step 8 — exact-head review, merge, and closeout

Update this STATUS table, current-state prose, topic docs, and handoffs. Run task
gates, focused suites, and required repository suites. Verify committer identity.
Push only owned changes. Obtain an independent read-only review on the final SHA.
Use `bin/ai-pr-wait` and merge PR #355 through the queue. Confirm the landed
commit on `origin/main`, fast-forward the canonical landing checkout, verify the
workflow on main, and retire both Blacksmith handoffs when every obligation is
carried forward or complete.

**Verification gate:** PR #355 is merged; the merge commit is on `origin/main`;
the final exact-head CI and review artifacts match the landed content; live
GitHub, Blacksmith, recovery, fork, local reviewer, and scheduled/manual paths
have the documented behavior; no stale handoff for this work remains.

## 10. Tests required

- Extend `tests/test-windows-bash-selection.sh` for six shard IDs, exact union,
  cross-shard duplicate, omission, unknown suite, empty shard, and overlapping
  names.
- Extend/add PowerShell selection tests for `-WindowsShard`, all 18 PowerShell
  suites, invalid IDs, and exact-once ownership.
- Replace brittle assertions in `tests/test-workflow-policy.sh` with checks for
  3+3 topology, sibling dispatch permissions/inputs/concurrency, fork all-GitHub
  routing, `merge_group` skips, recovery route identity, cancel-aware aggregate,
  provider ownership, and measured timeouts.
- Add orchestrator fixtures for dispatch success/failure, pickup before/after
  deadline, cancellation, started-test failure, API error, supersession, and
  output/job-summary truth.
- Preserve `tests/test-test-selection.sh`, `tests/test-ai-gemini.sh`,
  `tests/test-ai-facts.sh`, and repository manifest discovery checks.
- Run `tests/test-markdown-links.sh` and `tests/test-context-audit.ps1` after docs.
- Run the exact live qualifications listed in Step 7; mocks alone cannot prove
  ephemeral runner pickup/cancellation behavior.

## 11. Constraints, standing rules, and gotchas

- Use a current-upstream isolated worktree. Canonical checkout is landing-only.
- Work on branches and PRs; never push directly to `main`.
- Run `ai-task-gates start --class code` before implementation and respect the
  strongest class it reports.
- Before each commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Never run a local full suite while its physical Windows CI runner is active.
- Never weaken tests, allow failures, raise timeouts as suppression, or remove
  coverage to meet the target.
- Never repeat an unchanged failure without a repair or diagnostic purpose.
- A queued job's timeout has not started. Do not mistake yellow waiting for a
  bounded fallback.
- Keep the sibling workflow and parent orchestration secret-free. Use only the
  minimum GitHub token permission needed to dispatch/cancel/read actions.
- This public repository executes untrusted fork code. Forks stay GitHub-only;
  approval policy remains `all_external_contributors`.
- Every rebase/push invalidates exact-head review. Review only the final SHA.
- Do not make Windows contexts required while they skip `merge_group`; #166 is
  the later cutover owner.
- Verify Blacksmith pricing, concurrency, and exhaustion behavior live; provider
  documentation is not an account-level guarantee.
- A separate sibling workflow adds moving parts intentionally because GitHub has
  no single-job cancellation. Do not “simplify” it into the broken in-run design.

## 12. Access and environment

- GitHub CLI was authenticated for `popcre/ai-devops` during planning and could
  read PRs/runs/runners, dispatch workflows, and push the PR branch.
- Blacksmith is installed for the repository and the existing PR has launched
  `blacksmith-4vcpu-windows-2025`; reverify live.
- Current planning worktree:
  `C:\repos\ai-devops-worktrees\blacksmith-additive-355`.
- Canonical landing checkout: `C:\repos\ai-devops`.
- Existing PR: <https://github.com/popcre/ai-devops/pull/355>.
- No application deployment or browser is required. Use Git Bash for Bash tests
  on Windows and PowerShell for PowerShell tests.
- No secrets were used. If a credential becomes necessary, use 1Password vault
  `vibe_coding`; reference item names only and never expose values.

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] All eight STATUS rows are done with artifact evidence.
- [ ] Six measured shards cover every ordinary Windows-required suite exactly
      once on internal PRs: three GitHub, three Blacksmith.
- [ ] Fork PRs run the same six shard memberships entirely on GitHub.
- [ ] Blacksmith cannot-start reroutes within the measured bound, cancels its
      sibling run, and finishes visibly on GitHub.
- [ ] A started Blacksmith test failure stays red and never reroutes.
- [ ] Superseded parent/sibling work cancels without orphaning paid machines.
- [ ] Local reviewer-safety and complete scheduled/manual backstops remain.
- [ ] Measured Windows critical path is 20–25 minutes or a named Grok-bound
      exception is accepted without weakening tests.
- [ ] Focused, mutation, docs, and required CI tests pass on the final SHA.
- [ ] Independent exact-head review approves the final SHA.
- [ ] Bootstrap workflow and revised PR #355 are merged through the queue in the
      required order and verified on `origin/main`.
- [ ] Documentation reflects actual behavior and both session handoffs are
      retired when complete.

### Risks and rollback

- **Blacksmith never starts:** orchestrator cancels sibling and runs exact shards
  on GitHub. If recovery itself is unreliable, disable Blacksmith dispatch and
  run all six shards on GitHub while preserving the sharded speedup.
- **Blacksmith starts but image fails:** remain red; fix compatibility or move the
  affected suite to GitHub through a reviewed manifest change. Never auto-reroute
  a red assertion.
- **Sibling orchestration becomes too complex:** retain the landed six-shard
  GitHub-only topology as the recoverable baseline; do not return to one monolith.
- **Shard imbalance:** rebalance membership using new p90 timing evidence without
  changing the union.
- **Hidden inter-suite state dependency:** reproduce with full scheduled run,
  repair isolation, and keep complete backstop until proven.
- **Cost exceeds value:** shift Blacksmith-exclusive memberships to GitHub while
  retaining six shards; throughput remains because GitHub hosted concurrency is
  available on this public repository.
- **Required-check hang:** do not change ruleset in this plan; rollback any
  accidental Windows required context immediately through the governed #166 path.

### Open questions with decision criteria

- Exact shard membership: decide only from current per-suite timing and provider
  compatibility evidence in Step 2.
- Pickup deadline: choose the smallest 90–180 second bound above healthy p99
  provisioning; if no data exists, instrument first rather than guess.
- Blacksmith complete cadence: choose after one week of real shard cost plus live
  allowance/exhaustion behavior; never assume free-tier figures are current.
- Whether 3+3 beats six GitHub shards economically: owner has prioritized real
  Blacksmith capacity; retain 3+3 unless measured spend or reliability materially
  harms delivery, then raise the evidence-backed tradeoff rather than silently
  changing the decision.

## Mandatory self-audit

1. **Yes, a new session can execute without this chat.** Sections 2–6 define the
   repository, trigger, exact current branch/SHA/files, proven GitHub queue
   limitation, and provider roles. Section 9 names every file, dependency,
   sequence, and verification gate. Gap found and fixed: the default-branch-first
   requirement for the sibling workflow is explicit in STATUS and Step 4.
2. **Yes, the plan carries the complete reasoning and rejected paths.** Sections
   6–8 preserve the wizard behavior, qualification defects, throughput cause,
   fallback impossibility, fork/merge-queue implications, Albert's locked intent,
   and every rejected shortcut. Gap found and fixed: the difference between
   cannot-start recovery and a real red test is stated in §§6–9 and tested.
3. **Yes, the goal is sufficient for correct judgment when reality changes.**
   Section 1 makes 20–25 minute delivery with full visible coverage the governing
   outcome and says the goal wins over a faulty step. Sections 8 and 13 separate
   locked decisions, bounded judgment, rollback, and evidence criteria. No
   remaining gap was found.
