# Implementation plan: make BlockerWatch reliable and self-auditing

Written 2026-09-20 on `916-alien` by Codex from `origin/main`
`eb92356e2ebbe2b05d353cbd9e9b26e1678ceb9e`.

- Owner: [popcre/ai-devops#632](https://github.com/popcre/ai-devops/issues/632)
- Predecessor: [#617](https://github.com/popcre/ai-devops/issues/617)
- Stranded live proof: [#655](https://github.com/popcre/ai-devops/issues/655)
- Handoff: [`HANDOFF.d/2026-09-20T1847Z-916-codex-blockerwatch-reliability-plan.md`](HANDOFF.d/2026-09-20T1847Z-916-codex-blockerwatch-reliability-plan.md)

## STATUS

| # | Deliverable | Status | Evidence required |
|---|---|---|---|
| 0 | Reconcile live incidents and inventory every wait | ⬜ open | Redacted baseline under `tests/verification/blocker-watch/` |
| 1 | Atomic, idempotent registration and two-sided reconciliation | ⬜ open | Tests in §10 |
| 2 | Correct resume/fresh selection and classified harness failures | ⬜ open | Tests in §10 |
| 3 | Recovery lifecycle, leases, and durable health | ⬜ open | Tests in §10 |
| 4 | Correct dependency scanning, pagination, and host failover | ⬜ open | Tests in §10 |
| 5 | Enforced registration and installed-instruction parity | ⬜ open | Tests in §10 |
| 6 | Staged rollout and separate live proofs | ⬜ open | One owner issue per unproven outcome |
| 7 | Reconcile predecessor plans, issues, and handoffs | ⬜ open | Main/GitHub/install state agree |

**A fresh session starts at step 0.** Each phase is a natural session boundary.
Use `fresh-session` and re-read downstream phases before starting the next one.

## Part 1 — Why

### 1. The ultimate goal

When an AI session cannot continue until a GitHub issue closes, Albert must not
need to remember it, find the old chat, preserve its folder, or discover that
automation silently failed. Every blocked work item must have one searchable
owner issue, a trustworthy dependency, a recoverable continuation, and a visible
terminal outcome. **If a step conflicts with this goal, the goal wins — stop and
flag it on #632.**

### 2. What this application is

`popcre/ai-devops` is the public source of truth for Albert's AI-machine setup.
BlockerWatch is the scheduled Bash tool `bin/ai-blocker-watch`, configured by
`config/blocker-watch.json` and tested by `tests/test-ai-blocker-watch.sh`. It
parks Claude, Codex, and ZCode work behind GitHub issues, then resumes the old
session or starts a fresh one. GitHub issues/dependency links are the durable
human record; local JSON is the machine execution state. It is not a web app or
a database migration.

### 3. What triggered this work

The HTS AI classifier dependency on
[`popcre/shared-db#2995`](https://github.com/popcre/shared-db/issues/2995) was
never registered. It predates BlockerWatch, and its dependent application work
existed only in a local plan, beyond the current same-repo `depends_on:` scan.
The audit also found: wrong-folder Claude resume returning `No conversation
found`; #655 fresh mode stranded in an isolated state home and failing OAuth
401; #632's permanently refused transferred dependency; a ZCode wait stuck in
45-minute wake loops; failed/duplicate waits hidden behind a successful
scheduler result; and installed globals still teaching removed `--note` syntax.

### 4. Scope

In scope: registration, storage, deduplication, migration, reconciliation,
cancel/retry/repair/status/doctor, scheduler health, harness continuation,
cross-repo metadata, pagination, managed-link lifecycle, leadership failover,
privacy, installed guidance, all legacy waits, #2995, #617, #632, and #655.

Not in scope: shared-db schema/orchestrator changes; a web dashboard; arbitrary
chat recovery; parsing prose as execution authority; or suppressing/disabling
failures to make the scheduler look healthy. No transcript, secret, local path,
session identifier, or raw wait record may enter this public repository/GitHub.

## Part 2 — What we already know

### 5. Current state of the code

PR #653 landed at `eb92356e`; the offline suite passes `94 passed, 0 failed` but
does not model live failures.

- State/config: `bin/ai-blocker-watch:106-118`.
- `cmd_wait`, `:147-246`, mutates GitHub before directly writing JSON; `:237`
  uses second-resolution time and a shortened session ID.
- `cmd_list`, `:249-253`, omits age/error/attempts/action.
- `propagate`, `:286-346`, reads one 100-result page; `parked_comment`, `:348-374`,
  does not paginate markers and can publish local details.
- `wake`, `:376-508`, treats transcript discovery as Boolean, resumes from the
  wait folder, and retries every nonzero exit identically.
- Link maintenance, `:698-830`, supports same-repo numeric refs, adds only, and
  loops forever on transferred/refused targets.
- Lock reclaim, `:841-850`, uses age despite live long ticks.
- `cmd_tick`, `:869-881`, runs broad GitHub work first and revisits only `waiting`.
- Scheduling, `:885-921`, creates a task/cron line without proving live health.
- Relevant suites: `tests/test-ai-blocker-watch.sh`,
  `tests/test-ai-completion-check-hook.sh`, `tests/test-ai-adopt-globals.sh`,
  `tests/test-ai-install-skills.sh`, `tests/test-install-ai-devops-windows.ps1`.

### 6. Key findings and root causes

1. Registration is voluntary and has no GitHub↔local reconciliation; automatic
   discovery cannot see cross-repo or local-plan work.
2. Resume identity includes the project folder, not only a session ID; inherited
   subagent IDs make the current assumption unsafe.
3. Authentication, missing session, timeout, network, and uncertain execution
   are materially different, but one retry loop treats them alike.
4. Registration/publication are not transactional. Either GitHub or local state
   can advance alone and later ticks skip the mismatch.
5. `failed`, `unrunnable`, `orphaned`, interrupted `waking`, and cancelled work
   have no recovery/health lifecycle.
6. A timer is not lock ownership; pagination/cursor behavior can lose work; a
   static central host without heartbeat is a silent single point of failure.
7. Source templates and installed client instructions have no checked version,
   so agents are told to run rejected commands.

### 7. Approaches considered and rejected

- Rely on sessions remembering `wait`: #2995 proves it misses work.
- Infer authority from prose: ambiguity creates false links/wakes; prose may
  produce a candidate warning only.
- Key waits only by session/blocker or retry every nonzero exit: duplicates and
  deterministic 401/missing-session loops prove both unsafe.
- Resume whenever any matching transcript exists: the folder mismatch proves
  this does not identify a runnable session.
- Let every host publish: risks duplicate comments; use an idempotent remote
  lease. Keeping one silent static host is also rejected.
- Delete stale links generally: only BlockerWatch-created edges may be removed.
- Use isolated state homes for production proof: #655 shows they are invisible
  unless separately scheduled/owned.
- Close #617 because code merged: rejected because its live outcome never passed.

### 8. Design decisions already made

Locked (2026-09-20): GitHub remains the durable visible record; explicit
versioned full `owner/repo#N` metadata is authoritative; records use random UUIDs
plus a logical uniqueness key; registration is idempotent and crash-reconcilable;
execution and publication are separate durable phases; deterministic errors do
not burn generic retries; degraded health persists until repair/acknowledgment;
only ledger-owned links may be removed; closed-unmerged PRs need a decision; and
public output is sanitized.

Open engineering choices: the smallest repeatable JSON migration; the exact
GitHub-visible renewable lease primitive; and bounded log rotation. Choose the
fewest-moving-parts option that passes interruption, concurrency, and rollback
tests. Adding a database or new service is not justified.

## Part 3 — How to build it

### 9. Ordered executable plan

#### Phase 0 — stabilize and inventory

0.1. In a current-upstream worktree, declare task gates and capture a redacted
baseline of #2995/#617/#632/#655, every wait/home, configured host, scheduler,
and harness. Classify each item matched, GitHub-only, local-only, duplicate,
legacy, or healthy. **Gate:** every parked issue/local record has a classification
and next action in `tests/verification/blocker-watch/<UTC>/baseline.md`.

0.2. Put this plan and a named session/branch owner on #632; cross-link #617 and
#655 without closing them. **Gate:** no live finding exists only in this plan.

0.3. Add `docs/blocker-watch.md` defining record schema, state transitions,
logical uniqueness, public marker, managed-edge ledger, reconciliation truth
table, error taxonomy, redaction, and retention. **Gate:** every current state has
one migration and recovery path.

#### Phase 1 — durable registration and reconciliation

1.1. Refactor state helpers/`cmd_wait`: random UUID, schema version, logical key,
sanitized public ID, continuation policy, atomic temp/rename, and an intent record
before idempotent GitHub steps. **Gate:** interruption after every side effect and
rerun yields one complete wait/marker with no duplicate.

1.2. Add `reconcile`: compare local records, issue markers/labels, and managed
links bidirectionally; repair safe omissions; surface conflicts; import legacy
records; report unscheduled alternate homes. **Gate:** GitHub-only, local-only,
duplicate, legacy, partial, and alternate-home fixtures converge or name one
action.

1.3. Parse only the explicit full-ref cross-repo marker. Audit blocker-like prose
as a nonexecuting candidate. **Gate:** a #2995-equivalent fixture finds explicit
application work while prose alone never creates a link.

1.4. Idempotently migrate canonical records. Create/identify one HTS application
owner issue, link it to #2995, register it in the scheduled home, and reconcile
open structural issues with `application_return_to` or explicit exemption.
**Gate:** no unexplained duplicate/legacy/one-sided row; #2995 has exactly one
dependent application work item.

#### Phase 2 — correct continuation

2.1. Add harness-specific resolvers. Claude must resolve the exact transcript and
its stored project folder; ambiguity selects fresh, never a guess. Prove Codex and
ZCode rules from installed help/disposable sessions. **Gate:** project-A transcript
plus project-B wait resumes A or starts fresh, never doomed resume B.

2.2. Classify `session_missing`, `needs_auth`, `transient_network`, `timeout`,
`program_missing`, `uncertain_execution`, `permanent_config`. Missing session
switches once to fresh; auth/program failures stop; transient errors back off;
uncertain execution never auto-duplicates. **Gate:** each injected result reaches
its named state and allowed invocation count.

2.3. Persist harness success as `report_pending`, publish an idempotent sanitized
comment/label, then finish. Paginate marker search and fail closed on unreadable
comments. **Gate:** failures after execution/comment/label recover without another
harness execution or duplicate comment.

2.4. Add non-secret harness preflight to `doctor` and wake; persist one machine-
health issue per host for auth/readiness faults. **Gate:** 401 becomes
`needs_auth`, fails health, and only explicit retry after a green preflight runs.

#### Phase 3 — lifecycle, concurrency, health

3.1. Add `status`, `doctor [--live]`, `retry`, `repair`, `acknowledge`, and safe
`cancel`; enrich `list`. Cancel reconciles GitHub and removes only an explicitly
requested ledger-owned edge. **Gate:** every state has a safe operator path and
no command deletes the sole durable record.

3.2. Replace age lock stealing with PID/host/heartbeat leases and per-wait leases;
repair interrupted `waking`; split long workers from housekeeping. **Gate:** a
live old lease is not stolen, a dead one recovers once, max-attempt work never
runs again.

3.3. Prioritize/decouple local wakes from budgeted broad GitHub scans. **Gate:** a
simulated one-hour GitHub backoff cannot delay a ready local wait beyond one
schedule interval.

3.4. `doctor --live` must verify state counts/errors, last tick, oldest wait,
leader heartbeat, homes, logs/disk, scheduler action/trigger/principal/power,
and a canary; add log rotation. **Gate:** each injected defect fails doctor and it
passes only after the original scheduled capability works.

#### Phase 4 — dependency correctness and failover

4.1. Paginate search/comments and checkpoint only completely processed pages;
API errors are never empty results. **Gate:** >100 closures and old markers run
exactly once, while page-2 failure resumes at page 2.

4.2. Reconcile a managed-edge ledger; quarantine/report transferred/missing/
forbidden targets once while other work continues. **Gate:** the #632 fixture
creates one durable finding, never reposts, and does not block unrelated edges.

4.3. Use one release-policy function for propagation/wake. **Gate:** issue closed,
PR merged, PR closed-unmerged, reopened, and unknown return identical decisions.

4.4. Add remotely visible renewable leadership/heartbeat with bounded failover;
idempotent edge repair may be multi-host, public posts require the lease.
**Gate:** two hosts produce one comment and one successor after leader loss.

#### Phase 5 — enforce and install the contract

5.1. Extend `bin/ai-completion-check-hook` and client guidance to refuse a
blocked/waiting completion without a validated owner issue/wait artifact. Codex
needs an equivalent checked closeout command. **Gate:** every client rejects an
unregistered fixture and accepts a validated marker.

5.2. Version command help, three global templates, `docs/blocker-watch.md`, and
installed contract. Extend `bin/ai-adopt-globals`, installers, and
`bin/ai-machine-tools-doctor` to detect drift. **Gate:** installed `--note` fails;
adoption installs `--brief-file`; second adoption is idempotent.

5.3. Install through supported installers on every configured host, preserving
machine sections/backups and restarting clients that load globals at startup.
**Gate:** each host reports matching version, one schedule/home, and ready harnesses.

#### Phase 6 — prove and roll out

6.1. Run §10 suites/CI and an independent read-only exact-head review of
execution, concurrency, loss, privacy, and GitHub mutation. **Gate:** tests and
review approve the same commit.

6.2. Roll out one host at a time after task-gate checks; back up state/config,
dry-run migration, install, canary, and rehearse rollback to prior binary/config
and readable state. **Gate:** forward/rollback are repeatable with no duplicate
GitHub effects.

6.3. Prove Claude/Codex/ZCode resume and fresh modes, leader failover, auth
repair, cross-repo HTS release, and interrupted publication as separate outcomes.
One session and one issue per unproven outcome. **Gate:** each proof names deployed
commit/config/schedule and shows no duplicate execution/comment.

#### Phase 7 — close the loop

Update this STATUS, index/router/topic docs, and #632. Correct the predecessor
plan's historical STATUS; retire its handoff only under the successor rule; close
#617/#655/#632 only after their acceptance proof. **Gate:** no open document says
pre-#653 code is current and GitHub/main/install state agree.

#### Adversarial cases

| Boundary | Hostile case | Required test |
|---|---|---|
| CLI/ref/brief | malformed/full cross-ref/missing/huge/symlink/secret-like | `wait_validation_and_brief_safety` |
| Local JSON | partial/invalid/unknown/legacy/duplicate | `state_atomicity_and_migration` |
| GitHub issue/edge | deleted/transferred/manual/stale/refused/API failure | `github_reconcile_and_managed_edges` |
| Search/comments | >100/page failure/old marker/rate limit | `pagination_checkpoint_and_markers` |
| Transcript | same ID twice/wrong cwd/missing/invalid | `harness_session_resolution` |
| Harness | 401/missing/timeout/network/absent/ambiguous exit | `wake_error_classification` |
| Process death | every local/remote/execution/publication boundary | `interruption_reconciliation_matrix` |
| Lease/scheduler | live old/dead PID/reboot/two hosts/clock skew | `lease_failover_and_scheduler_health` |
| PR blocker | merged/closed-unmerged/reopened/unknown | `release_policy_consistency` |
| Config/install | alternate home/stale global/incompatible version | `doctor_and_instruction_parity` |
| Public output | path/session/token/transcript in error | `public_output_redaction` |

### 10. Tests required

Implement every named adversarial test plus:
`duplicate_same_second_and_inherited_session_id`,
`fresh_fallback_runs_once_after_session_missing`,
`auth_failure_never_burns_retries`,
`report_pending_never_reexecutes`,
`terminal_states_have_recovery`,
`max_attempt_waking_is_terminal`,
`scan_backoff_does_not_starve_wake`,
`find_api_error_is_not_no_matches`, and
`hts_2995_cross_repo_migration_fixture`.

Keep these green and run the CI manifest:

```text
bash tests/test-ai-blocker-watch.sh
bash tests/test-ai-completion-check-hook.sh
bash tests/test-ai-adopt-globals.sh
bash tests/test-ai-install-skills.sh
pwsh -File tests/test-install-ai-devops-windows.ps1
```

Save concise exact-head results under `tests/verification/blocker-watch/<UTC>/`.
Offline fault injection and live proofs are both required.

### 11. Constraints, standing rules, and gotchas

Use a current-upstream worktree, task gates, feature branch/PR, `bin/ai-gh`, the
required GitHub signature, Albert's verified committer identity, and owned-file
staging. Do not change shared-db structure: #2995 is orchestrator work; its
application return issue is non-orchestrator work. Preserve the capability;
disabling schedules/retries/reporting is not repair. Treat GitHub/harness output
as untrusted. Never commit raw logs/state/transcripts. Do not edit another
session's handoff. Scheduler success means healthy original behavior, not exit 0.

### 12. Access and environment

Target `popcre/ai-devops` protected `main` through PR. Use authenticated
`bin/ai-gh`. Enumerate hosts from the current `templates/system/machine-atlas.md`
at rollout time. Windows task is `\ai-devops\blocker-watch`; Unix uses user cron.
Canonical state is `.ai-devops/blocker-watch`; alternate homes are tests unless
explicitly scheduled. Harness credentials stay machine-local; any needed secret
comes through the approved 1Password `vibe_coding` flow and is never printed.
No cloud/database production write is needed.

## Part 4 — Landing it

### 13. Definition of done, risks, and open questions

Done means: all STATUS rows cite artifacts; all named tests/CI and independent
exact-head review pass; PR is merged and `origin/main` verified; installed
versions/clients/schedules are healthy on every host; all current waits and #2995
are reconciled; separate live proofs pass; public redaction passes; and issues,
plans, index/router/topic docs, and handoffs agree. Risks are duplicate execution,
migration loss, wrong edge removal, duplicate posts, privacy leakage, and stranded
legacy state. Roll back with backed-up prior binary/config/state without deleting
new GitHub evidence; remain visibly degraded until repaired.

No owner decision is required to start. The three §8 engineering judgments have
objective criteria. Conflicting new evidence must be recorded on #632.

## Mandatory plan self-audit

1. **Can a brand-new session execute without asking? Yes.** §§1–8 provide goal,
   context, evidence, rejected paths, and decisions; §§9–13 provide file-level
   phases, gates, tests, access, landing, and rollback.
2. **Is every relevant nuance and dead end present? Yes.** §§3, 5–7 preserve the
   #2995, #632, #655, folder, OAuth, scheduler, pagination, retry, privacy, and
   install findings and rejected shortcuts.
3. **Is the goal sufficient for judgment calls? Yes.** §1 has the goal-wins rule;
   §8 separates locked choices; §13 gives stop/rollback criteria.

All 13 sections, explicit scope, adversarial table, named tests, handoff backlink,
and landing proof are present. No gap remained; the self-audit passes.
