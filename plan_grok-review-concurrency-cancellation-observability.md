# Implementation plan — make Grok reviews single, visible, and honestly cancellable

Tracking issue: [u2giants/ai-devops#56](https://github.com/u2giants/ai-devops/issues/56)

Incident evidence:

- Local-only evidence `.ai/reviewer-issues/20260820T173149Z-edge-dev-grok-889837` — clones bypassed the paid-review lock.
- Local-only evidence `.ai/reviewer-issues/20260820T172906Z-edge-dev-grok-888349` — no progress was visible during a long turn.
- [`docs/reviewer-result-delivery-defects-2026-08-20.md`](docs/reviewer-result-delivery-defects-2026-08-20.md) — the same-day cross-reviewer context.

Planning handoff: [`HANDOFF.d/2026-08-20T1752Z-edge-dev-codex-grok-review-repair-plan.md`](HANDOFF.d/2026-08-20T1752Z-edge-dev-codex-grok-review-repair-plan.md)

---

## STATUS

### 2026-08-25 corrective scope repair

The 2026-08-23 implementation correctly unified equivalent clones for duplicate
detection but incorrectly made that identity a repository-wide semaphore. A
stopped `shared-db-1498-seq325` review therefore blocked the unrelated
`warner-1517-owner-decisions` workstream. The current repair supersedes the old
serialization goal below without discarding its duplicate-send safeguards.

| Corrective step | Status | Evidence |
|---|---|---|
| Split exact-session ownership from exact-work idempotency | 🟨 implemented locally | `session--*` mutexes and digest-keyed `work--*` protections in `bin/ai-grok-review` |
| Preserve clone-equivalent duplicate detection and legacy state | 🟨 implemented locally | normalized upstream remains an identity input; evidence-bearing schema-2 locks protect only their exact caller/session; ambiguous legacy locks fail closed |
| Prove unrelated concurrency and exact retry refusal offline | ✅ complete | Windows Git Bash suite passes 186/186, including concurrent `new`/`ask`, exact cross-clone retries, changed-prompt refusal for an uncertain continuation turn, corrected retry after proven pre-provider failure and partial publication, retained uncertainty, stale-provider preservation, pre-provider reclamation, legacy locks, and metadata secrecy |
| Full repository offline gates | ✅ complete | 53/53 Bash groups and 16/16 PowerShell groups pass on Windows |
| Independent exact-head review, bounded installed live canary, push, and issue update | ⬜ open | required before completion |

Independent review round 1 at `b5f7c76` returned `REJECT`: a changed prompt
could bypass the exact-work digest after an uncertain continuation. The wrapper
now also reserves the durable logical session turn independently of prompt
identity; both the exact retry and a materially changed retry are refused while
unrelated named sessions remain runnable. The three new regression cases pass.

Independent review round 2 at `6c6f255` returned `REJECT`: a local isolation
failure before provider launch could leave the new turn reservation stranded.
Turn reservations now record their owner and the provider-contact boundary. A
dead/no-contact reservation is reclaimed under the exact-session mutex, while
any reservation that crossed the provider boundary remains durable and
fail-closed. Both recovery shapes have offline regression coverage.

Independent review round 3 at `90b21ea` returned `REJECT`: the turn directory
could become visible just before its PID field was written. Session and turn
reservations now build complete pending directories and publish them by rename
while the exact-session mutex is held. An older no-contact partial turn record
is quarantined and reclaimed; the explicit crash-window fixture passes.

Corrected rule: **Grok reviews are not globally or repository-wide serialized.
Only the same exact review session/turn or an idempotently identical submission
is serialized. Independent reviews may run concurrently.** Historical sections
below describe the superseded 2026-08-20 design and must not be used as current
operating guidance.

Read this table first. Source repairs, Windows installation, full offline
verification, and bounded live qualification are complete; exact-head approval,
push, Ubuntu installation, CI, and issue closure remain.

Everything below the STATUS table is the original plan-time record unless a
paragraph explicitly says otherwise. Any description of old code or a proposed
unsafe cleanup is historical; the STATUS table and current fail-closed source
govern. In particular, a dead local owner never proves remote paid work stopped.

| # | Step | Status | Evidence required before marking done |
|---|---|---|---|
| 1 | Reconcile GitHub `main`, preserve concurrent work, and record the baseline | ✅ complete locally | Base `50fde79`; offline results recorded in `tests/verification/grok-review-issue-56/2026-08-21-offline.md` |
| 2 | Replace checkout-path locking with normalized upstream-repository locking | ✅ complete locally | Clone, HTTPS/SSH/case/`.git`, local-origin, unrelated-repository, and uncertainty-block tests in `tests/test-ai-grok-review.sh` |
| 3 | Make active work visible across clones and callers | ✅ complete locally | `list_shows_active_reviews_across_clones_and_callers` and owner-state fixture pass |
| 4 | Make interruption and deletion tell the truth about the remote turn | ✅ complete locally | Signal fixture preserves a `remote-uncertain` paid-work block; active deletion refusal remains implemented |
| 5 | Add useful mid-turn progress without weakening terminal completion | ✅ complete locally | Provider-start synchronization, two-heartbeat, bounded hung-process and inspect-process-tree timeouts, elapsed activity, marker-write-failure, schema-drift, enabled-hook, launcher-orphan, stale-supervisor-PID disarming, live-doctor cleanup, installed-symlink helper resolution, fail-fast restoration, POSIX escalation ordering, transcript-home, and legacy-rollout fixtures pass; `bash tests/test-ai-grok-review.sh` passes 157/157 |
| 6 | Correlate reviewer-issue evidence to the affected run | ✅ complete locally | 28 incident tests prove exact metadata-owned reports/logs win; similar names, duplicate matches, and missing identity capture nothing |
| 7 | Update user guidance, install, and run offline verification | ✅ complete locally | Windows launcher targets the exact source wrapper; Claude/Codex skill hashes match; the combined head passes Codex 40/40, Grok 158/158, and the full 51-Bash/16-PowerShell gate; sealed exact-head and full case-level evidence are preserved under `tests/verification/grok-review-issue-61/` |
| 8 | Run bounded live qualification and independent exact-head review | 🟨 live complete; review open | Windows `doctor --live`, real issue #61 review, and installed two-clone canary passed with cross-clone visibility, second-call refusal, one terminal provider turn, progress, and lock release; final exact-head approval remains |
| 9 | Commit, push, verify GitHub, close #56, and retire this plan/handoff | ⬜ open | Remote `main` SHA, GitHub issue closure comment linking verification evidence, plan status fully current, and this handoff removed only after completion |

### End-of-phase rule

After each phase, re-read every remaining phase and update this plan for any changed assumption. A completed row must cite an artifact that another session can open and re-check; a bare test count or issue number is not evidence.

---

# Part 1 — Why

## 1. The ultimate goal

Albert must be able to request a Grok review knowing that only one paid Grok turn can run for a GitHub repository at a time, even when different sessions use different clones. While it runs, every caller must be able to see that it is alive, what it is reviewing, how long it has been running, and whether stopping the local command leaves a paid remote turn behind.

When this work is done, clones no longer defeat the cost guard; abandoned reviews cannot hide; interruption messages never imply a remote cancellation that was not proven; and incident records attach the evidence from the affected run rather than an unrelated recent run.

Read-only permissions, exact-commit evidence, bounded turns, named-session continuity, and terminal-result validation must remain intact. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`u2giants/ai-devops` is a public backup-and-restore toolkit for Albert's multi-model coding workflow. It is Bash, PowerShell, Markdown, and dependency-free test scripts; it is not a hosted application and has no database, container, production service, deployment URL, or GitHub Actions workflow.

The affected pieces are:

- [`bin/ai-grok-review`](bin/ai-grok-review), the read-only Grok wrapper. It pins `grok-4.6`, permissions, turn bounds, result validation, repository snapshots, locks, session records, review files, and cost reporting.
- [`tests/test-ai-grok-review.sh`](tests/test-ai-grok-review.sh), its offline regression suite.
- [`bin/ai-reviewer-issue`](bin/ai-reviewer-issue), the local incident recorder that captured the wrong Grok session metadata in both #56 evidence packages.
- [`tests/test-ai-reviewer-issue.sh`](tests/test-ai-reviewer-issue.sh), the recorder's offline suite.
- [`skills/shared/grok-cli/SKILL.md`](skills/shared/grok-cli/SKILL.md), the shared Claude/Codex operating instructions.

GitHub repository: `https://github.com/u2giants/ai-devops`. Normal policy is direct work on `main`, no feature branch. The current planning machine is `edge-dev`, Windows, repository `C:\repos\ai-devops`; Bash scripts run through Git Bash. Installed commands normally point at the canonical checkout, so no application deployment exists.

## 3. What triggered this work

On 2026-08-20 Albert saw six concurrent Grok reviews against `u2giants/shared-db`. The caller expected the wrapper to forbid this because its refusal text says only one Grok review may run per repository. Five distinct wrapper identities were measured for the same upstream repository:

| Wrapper identity | Checkout | Review |
|---|---|---|
| `c45fa053410d` | `C:/repos/shared-db` | `review-1295-roster` |
| `678a9d795b6b` | local-path clone `rv1295` | `review-1295-r2` |
| `9b2d8492c958` | GitHub clone `rv1295gh` | `review-1295-r2b` |
| `c5c4fbc3514d` | clone `rv1320` | `review-1320-supersede` |
| `2a0037e019da` | clone `rv1335` | `review-1335-restore` |

The clones existed for a valid reason: shared-db issue #1296 proved that two reviewers sharing one checkout could overwrite one another's evidence packet. Commit `d2f59df` subsequently made review snapshots and packets session-specific, but the lock still identifies a repository using the checkout's physical path plus its remote. Each clone therefore receives its own paid-review lock.

Two local runs were also killed after receiving the wrong commit. A local process kill cannot by itself prove that the xAI-hosted turn stopped. The wrapper's `delete` command deletes only local metadata and explicitly leaves Grok history untouched, but the interrupt path does not clearly warn that remote work may continue and bill.

The separate progress record was created while `review-1335-restore` had emitted only its startup lines. Its lock and process id were alive, but the wrapper exposed no per-turn or elapsed progress until the terminal JSON arrived. A long healthy review, a loop, and a stuck provider call therefore looked identical.

Reproduction must be offline first:

1. Create two temporary clones with origin URLs that normalize to the same `owner/repository` identity.
2. Hold the first wrapper's repository lock with the existing fixture mechanism.
3. Start the second wrapper from the other clone.
4. Current faulty behavior: the second run starts. Correct behavior: it refuses and identifies the active review.

No paid live call is needed to reproduce the locking defect.

## 4. Scope

### In scope

- One canonical upstream-repository identity for the in-flight cost lock, stable across ordinary clones, linked worktrees, remote URL spellings, `.git` suffixes, and case differences that refer to the same GitHub repository.
- Backward-compatible session lookup: existing named sessions remain discoverable by their current path-plus-remote record identity.
- Repository-wide visibility of active Grok locks, including label, caller, source checkout, process id, start time, and whether the owner process is alive.
- Truthful interruption, `delete`, and any new `abort` behavior based on the installed Grok CLI's documented capabilities.
- Bounded mid-turn progress or heartbeat output using information the wrapper can prove.
- Exact-run selection in `ai-reviewer-issue`, so a recorded incident cannot silently attach unrelated metadata, scoreboard data, review files, or provider logs.
- Offline regression tests, one bounded live qualification, documentation, installed-command verification, independent exact-head review, GitHub closure evidence.

### NOT in this plan

- Changing Grok's model, provider, authentication, pricing, or account allowance.
- Broadening `Read`/`Grep` review permissions, enabling Bash, edits, web search, memory, automatic permission mode, or arbitrary flag forwarding.
- Removing or shortening the terminal `stopReason` wait loop.
- Raising or removing the 20-turn and 15-minute bounds.
- Replacing session-specific review snapshots or returning to shared `.ai-review` packets.
- Automatically choosing a reviewer, changing the scoreboard's provider-selection policy, or fixing Muse/Kimi/GLM issues.
- Killing processes based only on a stale-looking timestamp, deleting provider history without explicit user intent, or claiming a remote turn stopped without confirmation.
- Database, shared-cloud, production, or shared-db code changes. The shared-db issue links are evidence only.
- Retrofitting every historical Grok session into the new lock identity. Only active-lock safety and backward-compatible named-session lookup are required.

---

# Part 2 — What we already know

## 5. Current state of the code

The source of truth at planning time is fetched `origin/main` commit `c7f0b83b0b0c2959184e5d4f4a370c38a9a34e9d`. The local checkout is on `main` at `12b0f0e84980eb6df9f6363045964c45c1ae9888` and is behind GitHub. It also contains unrelated uncommitted `.gitignore` and memory changes. Do not pull, reset, stage, or overwrite those changes. The implementation session must reconcile through a clean clone or wait until their owner commits them.

Already working and protected:

- `repo_id()` in `bin/ai-grok-review` hashes the physical root plus origin URL. That is useful for **session storage**, because it separates checkout-bound snapshots, but wrong for the global paid-review lock.
- At planning time, `repolock_path()` stored the in-flight lock beneath the Grok state directory and `lock_acquire()` reclaimed a lock when its recorded owner died. That behavior was unsafe and has been replaced: current repository-wide paid-work locks stay blocked until remote completion is confirmed or a human reconciles them.
- `cmd_new()` and `cmd_ask()` both acquire the repository lock before calling Grok. `cmd_ask()` also acquires a named-session lock.
- `prepare_review()` creates a private, self-contained, session-specific snapshot for both ordinary clones and linked worktrees. This is the shipped fix for issues #52/#53 and must remain.
- `await_result()` treats only parseable JSON carrying `stopReason` as completion. The Grok process's exit status is deliberately not trusted.
- `cmd_list()` currently lists completed session records only under the current checkout identity. In-flight sessions do not have to exist yet, so it cannot report them.
- `cmd_delete()` removes local metadata and the private snapshot; it does not remove Grok's provider history or prove that an in-flight remote turn stopped.
- The wrapper uses plain JSON output, one terminal object, not a streaming format. The current final JSON exposes final turns/tokens/cost but no proven per-turn event stream.
- `tests/test-ai-grok-review.sh` already protects fixed permissions, mandatory turn bounds, terminal-result waiting, cancelled-result handling, duplicate starts within one checkout, named-session continuity, private snapshots, evidence packets, usage/cost reporting, and linked-worktree handling.

The two incident packages contain strong written accounts but weak automatic attachments:

- `reviewer-metadata.redacted.json` in both packages is for `review-1320-supersede`, not `review-1335-restore`.
- `captured-provider-logs.txt` is empty in both.
- `latest-scoreboard-entry.json` and the copied review report are older unrelated records.
- Root cause: `bin/ai-reviewer-issue` calls `latest_json "$STATE_BASE/$provider"` and captures the newest provider metadata globally. The command accepts no exact run/session selector and its attachments are recency-based rather than correlation-based.

No issue-56 implementation is committed or pushed. GitHub issue #56 is open with no comments as of 2026-08-20T17:37:12Z.

## 6. Key findings and root cause

### 6.1 Two identities are needed, not one

The current identity tries to serve two different jobs:

- Session/snapshot identity must distinguish checkouts because each session owns a fixed private review directory and historical records must remain findable.
- Cost-lock identity must unite every clone of the same upstream repository because the bill is shared and concurrent reviews are the forbidden event.

Changing `repo_id()` in place would risk stranding named sessions and breaking snapshot cleanup. The smallest safe design is to keep the existing identity for session records and add a separate canonical upstream lock identity.

### 6.2 A canonical GitHub identity must normalize transport, not trust raw URL text

These forms can name the same repository:

- `https://github.com/u2giants/shared-db.git`
- `https://github.com/u2giants/shared-db`
- `git@github.com:u2giants/shared-db.git`
- `ssh://git@github.com/u2giants/shared-db.git`

For GitHub, normalize to lowercase `github.com/u2giants/shared-db` after removing credentials, default port, trailing slash, and `.git`. Do not hash the checkout path into the cost-lock key.

Local-path remotes require care. A clone whose origin is `C:/repos/shared-db` should follow that repository's own upstream remote recursively, with a small cycle/depth bound, until it reaches a network remote. If no stable upstream exists, fail closed with a clear message rather than inventing a path-based lock that restores the original hole. Record the resolved display identity in the lock for diagnosis; use its hash only for the directory name.

### 6.3 Local process death and provider cancellation are different facts

Signals can release local locks and stop the local child, but neither fact proves the hosted turn stopped. The implementation must first inspect the installed Grok help/docs for an official headless session cancellation command. If one exists, test it with a harmless bounded live probe and require positive confirmation. If none exists, the locked behavior is warning-only: say that the local wrapper stopped and the provider turn may still run and bill.

### 6.4 Honest progress can report only what is observable

The current `--output-format json` writes its useful fields only at the end. A timer-based heartbeat can truthfully report elapsed time, local child/process liveness, lock owner, and the fact that terminal JSON has not arrived. It must not invent turn count, token count, provider activity, or “healthy” status. If the installed CLI's documented streaming format can expose completed-turn events without changing the completion contract, it may be evaluated behind offline fixtures; otherwise use the honest heartbeat.

### 6.5 Incident capture needs an explicit join key

“Newest Grok JSON” is not evidence for a named failed run. The recorder needs an explicit safe selector such as `--session <wrapper-name>` and optionally `--repository <root>`, then it must match caller, repository remote, name/session id, and time window where available. Missing matches must produce a labelled absence, never an unrelated attachment.

## 7. Approaches considered and rejected

1. **Ban clones.** Rejected because clones/private snapshots are necessary to keep review evidence and exact commits isolated. Issues #52/#53/#1296 established this with real wrong-commit and packet-collision failures.
2. **Use one machine-wide Grok lock.** Rejected because reviews of unrelated repositories should not block one another. Lock by normalized upstream repository.
3. **Replace `repo_id()` everywhere.** Rejected because existing session records, caller separation, and snapshot cleanup depend on checkout-bound lookup. Add a separate cost-lock identity and migrate active locks safely.
4. **Use the raw origin URL as the lock key.** Rejected because HTTPS, SSH, `.git`, case, and local-path origins can identify the same GitHub repository.
5. **Fall back silently to the checkout path when upstream resolution fails.** Rejected because that recreates the exact concurrency hole. Fail closed and tell the caller how to fix the remote.
6. **Kill the local process and report “cancelled.”** Rejected because that can leave a paid provider turn running. Report only confirmed provider cancellation.
7. **Make `delete` implicitly kill any matching process.** Rejected because `delete` historically means local record/snapshot removal, and deleting evidence while work is active is dangerous. Refuse deletion of an active run unless a separately specified, verified abort flow has completed.
8. **Parse final JSON fields while the file is incomplete.** Rejected because partial JSON is not reliable and the terminal-result rule exists after a measured early-return failure.
9. **Switch immediately to a streaming output format.** Rejected as the default plan because the current measured contract is one terminal JSON object. Evaluate the installed version first; do not risk result parsing, cache/session continuity, or completion safety merely to print progress.
10. **Treat an alive process id as proof the provider is healthy.** Rejected. It proves only that the local owner process exists.
11. **Let `list` scan and trust arbitrary directories.** Rejected. It may read wrapper-owned Grok lock/session roots only, validate file shape, and display ambiguous records without deleting them.
12. **Keep recency-based reviewer incident capture.** Rejected because both #56 records demonstrably attached the wrong session.
13. **Clean up the historical #56 evidence folders.** Rejected. They are part of the incident record. Add corrected evidence later; do not rewrite or delete the originals.

## 8. Design decisions

### Locked decisions — do not relitigate

- **2026-08-20, clarified 2026-08-22:** one paid Grok turn per normalized upstream repository per reviewer OS account, regardless of clone, worktree, caller, or session name. Production reviewer work runs only under its designated account (`ai` on Ubuntu and Albert's account on Windows); cross-account machine-wide locking is not claimed.
- Preserve checkout-bound session/snapshot identity separately from repository-wide cost-lock identity.
- Remote identity normalization must cover the common GitHub HTTPS/SSH forms and local clones that point at a repository with its own upstream.
- Unknown or ambiguous upstream identity fails closed for `new`/`ask`; it never falls back silently to clone-path serialization.
- `list` must show active work across clones and callers. Caller separation remains for named session access; visibility of active cost locks is machine-wide.
- A local signal or process kill is never described as provider cancellation without positive provider confirmation.
- Terminal completion still requires valid JSON with recognized `stopReason`; exit status and heartbeat are not completion.
- Progress output must be bounded and factual. Default recommendation: emit immediately after startup, then every 60 seconds, and once on termination. Make the interval configurable for tests, with a safe positive minimum in normal use.
- `delete` refuses to remove a session whose repository-wide lock identifies it as active. It continues to remove local metadata/history only after the run is inactive, and its message says provider history is untouched.
- Incident recording uses explicit correlation and fails visibly when matching evidence is unavailable.
- Preserve model `grok-4.6`, permissions, `--max-turns`, no-memory, exact-session resume, private snapshots, packet hashing, cost reporting, and caller separation.

### Open decisions — resolve only from installed Grok evidence

- Whether the installed Grok CLI exposes a real remote abort command. Criteria: official `--help`/installed docs plus one bounded harmless live proof. If absent or ambiguous, implement no provider abort and use the locked warning.
- Whether a streaming output mode can expose reliable completed-turn progress while retaining a terminal object and exact `stopReason`. Criteria: offline fixture compatibility, exact session reuse, no change to permissions/cache prefix, and a bounded live proof. If any criterion fails, keep plain JSON and use elapsed-time heartbeat only.
- Whether local-path upstream recursion belongs in `ai-grok-review` or a small shared helper. Prefer a private function in this wrapper unless a current second consumer needs identical behavior; do not create framework code speculatively.

---

# Part 3 — How to build it

## 9. Ordered implementation plan

### Phase A — establish a safe baseline and executable failures

1. **Reconcile current GitHub source without touching concurrent work.** Start from fetched `origin/main`, read the STEP 0 header in `bin/ai-grok-review`, the STATUS tables in `plan_reviewer-system-repair.md` and `plan_delegate-wrapper-hardening.md`, this plan, its handoff, issue #56, and the two evidence packages. Run `git status --short` before any edit. If the canonical checkout is still dirty or behind, create a clean self-contained clone for implementation and later merge only the owned commits; never reset, clean, or broad-stage the current checkout. Verify `git var GIT_COMMITTER_IDENT` is `Albert Hazan <u2giants@users.noreply.github.com>`. Save the base SHA and baseline test output under `tests/verification/grok-review-issue-56/<UTC>/`. **You'll know it worked when:** the record names the exact GitHub base, proves both existing suites ran before edits, and lists every pre-existing dirty path as excluded.

2. **Add failing offline reproductions before changing behavior.** Extend `tests/test-ai-grok-review.sh` with temporary repositories representing: two ordinary clones with equivalent HTTPS origins; HTTPS versus SCP-style SSH origin; `.git`/trailing-slash/case variants; a local-path clone whose source has a GitHub upstream; unrelated upstream repositories; missing/ambiguous upstream; a live lock viewed from a second clone; a dead-owner stale lock; interruption; active-session delete; and a slow terminal fixture. Extend `tests/test-ai-reviewer-issue.sh` with two Grok metadata records where the newest is unrelated and the explicitly selected older record is the incident target. **You'll know it worked when:** each new test fails for the current code for the intended reason while all pre-existing tests retain their prior result.

**Natural context cut:** if Phase A consumes substantial context, use the `fresh-session` skill, update the STATUS table with the baseline artifact, then start a fresh session by re-reading every downstream phase.

### Phase B — separate repository-wide lock identity from session identity

3. **Add canonical upstream identity functions in `bin/ai-grok-review`.** Keep `repo_id()` unchanged for metadata/snapshot compatibility. Add functions with explicit contracts, such as `upstream_identity`, `normalize_remote`, and `review_lock_id`. Normalize supported GitHub remote spellings to one lowercase host/owner/repo value. Resolve local-path origins through their source repository's origin with a bounded visited-set/depth check. Reject credentials in display output. When no unambiguous upstream exists, stop before a paid call with a plain repair message. **You'll know it worked when:** the normalization fixture table maps every equivalent remote to one identity/hash, unrelated repos remain different, cycles/missing remotes fail quickly, and no secret-bearing URL is printed.

4. **Move only the paid-review lock to the canonical identity.** Change `cmd_new()` and `cmd_ask()` to compute both identities: checkout/session id for `meta_path`, `find_meta`, `lock_path`, and snapshot ownership; upstream lock id for `repolock_path`. Enrich each repository-wide lock with atomic wrapper-owned fields: schema version, normalized display identity, caller, command (`new`/`ask`), session name, source checkout, process id, and UTC start time. Preserve atomic `mkdir` and owner-bound trap handling. Never automatically reclaim a dead-owner repository lock: local process death does not prove the remote paid turn stopped. Consider legacy path-keyed locks during rollout: before starting a paid turn, detect any old-format lock whose recorded source repository resolves to the same upstream and refuse it; do not delete an ambiguous lock. **You'll know it worked when:** clone A holds the lock and clone B refuses before invoking the Grok stub, while another upstream repository runs; existing named sessions still show/ask/delete from their original checkout.

5. **Make lock reads safe and deterministic.** Validate every field before display or action. Canonicalize paths, quote all shell values, use atomic temporary-file-to-rename writes where multiple fields become one JSON record, and retain compatibility with old `pid`/`label` lock folders. A malformed lock must warn and block the paid call until inspected; it must never be silently reclaimed. **You'll know it worked when:** malformed, partial, dead, live, and legacy lock fixtures each produce the specified bounded outcome on Windows Git Bash and ordinary Bash.

### Phase C — visibility, interruption, and deletion

6. **Extend `cmd_list()` to show active repository-wide work before completed sessions.** Keep the existing completed-session table. Add a clearly labelled active section that scans only `$STATE_DIR/locks/repo--*.lock.d`, validates each record, and prints normalized repository, session label, caller, source checkout, process id, UTC start, elapsed time, and local owner state. It must show locks from every clone/caller because that is the purpose of the cost guard. Do not expose prompts, credentials, or provider transcript content. Add `--json` output only if the wrapper's existing global `--json` behavior can represent both sections without breaking current callers; otherwise keep the human table and defer a machine format. **You'll know it worked when:** a second clone's `list` displays the held review and enough information to identify its owner, and an unrelated repository's active review is visible but clearly distinguished.

7. **Install lifecycle handling with truthful interruption reporting.** On `INT`/`TERM`, terminate/wait for the local child using existing ownership, release only the checkout-bound session lock, and retain the repository-wide paid-work lock whenever provider cancellation is not confirmed. Emit exactly one warning: local wrapper stopped; provider cancellation confirmed / not available / not confirmed; remote work may still run and bill when unconfirmed. Never let cleanup change a completed result into failure or print the warning on ordinary exit. **You'll know it worked when:** signal fixtures preserve the paid-work block even if writing its uncertainty marker fails, release only their own session lock, return nonzero, and contain the required warning without claiming unproven cancellation.

8. **Decide and implement provider abort only if proved.** Inspect the installed `grok --help`, `grok session --help` or equivalent, `~/.grok/README.md`, version-matched session/headless docs, and changelog. Do not read `~/.grok/auth.json`. If an official remote-cancel operation exists, add a separately named `abort <name>` flow that targets the exact stored provider session, requires the matching active lock, prints the provider's confirmation, then performs local cleanup. If it does not exist or cannot confirm cancellation, do not manufacture `abort`; document that only the local process can be stopped. **You'll know it worked when:** the STATUS evidence cites the installed interface and either a bounded successful abort canary or the exact documentation proving warning-only behavior.

9. **Make `delete` safe and explicit.** Before deleting metadata/snapshot, check repository-wide active locks for the exact caller/session. Refuse if active and point to the proven abort command or local-stop warning. When inactive, delete only the local record and owned snapshot, then say explicitly that Grok provider history is untouched. Keep caller separation. **You'll know it worked when:** active delete refuses without removing evidence; inactive delete retains current behavior; same-name sessions belonging to another caller are untouched.

### Phase D — honest mid-turn progress

10. **Add a bounded heartbeat around `await_result()`.** At startup record UTC start and monotonic elapsed time if available; while waiting, print a progress line at a configurable test interval and a safe 60-second production default. Each line may state only elapsed time, local owner state, output byte count, and “waiting for terminal Grok result.” Do not call it provider activity or health. Keep the existing fast-death checks and total timeout. Avoid a background writer that can outlive the wrapper; if a helper process is used, own and wait for it in the lifecycle cleanup. **You'll know it worked when:** the slow fixture emits at least two progress lines before terminal completion, a fast fixture is not noisy, timeout remains bounded, and no helper survives interruption.

11. **Evaluate streaming progress without making it a requirement.** If installed Grok documentation says a streaming format provides trustworthy completed-turn or token events, capture sanitized fixtures and prototype parsing in tests. Adopt it only if the final terminal record remains authoritative, exact session reuse and cost accounting remain correct, and the frozen permission/cache prefix does not change. Otherwise record the rejection and retain the heartbeat. **You'll know it worked when:** the verification artifact states the evidence-based decision; no implementation relies on undocumented partial JSON.

### Phase E — repair incident evidence correlation

12. **Add exact selectors to `bin/ai-reviewer-issue`.** Extend `record` with an explicit safe selector such as `--session <name>` and, where necessary, `--caller <codex|claude>` or exact provider session id. Search only structured wrapper metadata under the provider state root, match normalized repository plus selector, and reject zero or multiple matches with a clear message. Use the chosen metadata to correlate scoreboard entries, review artifacts, and provider logs by session id/name/time window where those fields exist. When no correlated artifact exists, write a labelled `not captured: no correlated artifact found`; never substitute the newest unrelated item. Keep redaction and permissions unchanged. **You'll know it worked when:** the two-record fixture attaches the selected older session, refuses ambiguity, preserves redaction, and records honest absence instead of unrelated evidence.

13. **Document the evidence limitation of historical #56 records.** Update `docs/reviewer-issues.md` and `docs/reviewer-result-delivery-defects-2026-08-20.md` to say the original packages' narrative is valid but automatic metadata/report/log attachments were not correlated. Do not edit or delete the original evidence folders. After implementation, create one new corrected local evidence record using the new selector and link it in issue #56 without copying secrets. **You'll know it worked when:** a reader can distinguish original narrative evidence from the incorrect attachments and reproduce the corrected capture.

### Phase F — verification, independent review, and delivery

14. **Update operating guidance and routing.** Update `skills/shared/grok-cli/SKILL.md` with one-review-per-upstream behavior, cross-clone `list`, truthful interruption/cancellation, safe `delete`, and progress semantics. Update the STEP 0 verification header in `bin/ai-grok-review` with the 2026-08-20 measured failure and the two-identity rule. Keep this plan linked from `AGENTS.md`, the topic doc, Grok skill, handoff, and `memory/ai-devops/MEMORY.md`. Install changed shared skills through the canonical installer and compare source/installed hashes for both Claude and Codex copies. **You'll know it worked when:** all routing links resolve and installed hashes match source.

15. **Run complete offline verification.** At minimum run:

    ```bash
    bash -n bin/ai-grok-review
    bash -n bin/ai-reviewer-issue
    bash tests/test-ai-grok-review.sh
    bash tests/test-ai-reviewer-issue.sh
    bash tests/test-ai-review-packet.sh
    bash tests/test-ai-review-sandbox.sh
    bash tests/test-ai-review-scoreboard.sh
    bash tests/test-windows-scripts.sh
    ```

    Run `shellcheck` on changed Bash files if installed; record “not installed” rather than treating absence as success. Save complete secret-free command output in the dated verification directory. **You'll know it worked when:** every required command exits zero and the artifact contains the command, base/head SHA, environment, and result.

16. **Run bounded live qualification on the installed wrapper.** First prove source and installed wrapper hashes match. Use two disposable clones of this public repository and one harmless, narrow Grok prompt. Start one review, verify the second clone refuses before a second provider call, verify cross-clone `list`, observe at least one truthful progress line, let the first finish with terminal JSON, and confirm the lock releases. Separately test interruption only if doing so cannot strand an unbounded paid turn; the test must obey the warning/abort decision from Step 8. Never run six concurrent reviews to prove the fix. **You'll know it worked when:** one and only one provider turn exists, the second command is refused, progress appears, terminal completion remains valid, and the lock is gone afterward.

17. **Obtain an independent exact-head review.** Use one healthy governed reviewer other than Grok, because Grok is the component under test. The review must inspect the exact implementation head, focus on lock equivalence, stale/malformed lock safety, signals, cross-caller visibility, evidence correlation, and preservation of the protected completion/permission rules. Fix every valid Critical/High/Medium finding and rerun affected tests. **You'll know it worked when:** the saved exact-head review has no unresolved finding at those levels and names the reviewed SHA.

18. **Land and close safely.** Verify commit identity, stage only issue-56 files by explicit path, commit, reconcile concurrent `main` without force-push, push, and verify the remote SHA. This repository has no CI or deployment; installed-wrapper hash plus offline/live qualification is the deployment proof. Update this STATUS table and issue #56 with direct links to the commit and verification evidence. Close #56 only after all four wrapper defects and evidence correlation are proved. Delete this session's handoff only when the issue is closed and the plan is fully complete; retain the plan as a completed design record unless repository convention at that time says otherwise. **You'll know it worked when:** GitHub `main` contains the verified SHA, #56 is closed with evidence, no unrelated file was included, and no open handoff falsely claims this work remains.

## 10. Tests required

### `tests/test-ai-grok-review.sh`

Add named tests for:

- `equivalent_github_clones_share_one_paid_review_lock`
- `https_ssh_dotgit_and_case_normalize_to_one_upstream`
- `local_path_clone_resolves_sources_upstream`
- `local_remote_cycle_or_missing_upstream_fails_closed`
- `unrelated_upstreams_do_not_block_each_other`
- `legacy_live_lock_for_same_upstream_blocks_rollout`
- `dead_owner_becomes_remote_uncertain`
- `list_shows_active_reviews_across_clones_and_callers`
- `list_reports_start_elapsed_pid_checkout_and_owner_state`
- `signal_releases_owned_locks_and_warns_about_remote_turn`
- `ordinary_exit_does_not_print_interruption_warning`
- `delete_refuses_an_active_session`
- `delete_inactive_session_keeps_provider_history_warning`
- `slow_turn_emits_truthful_bounded_heartbeat`
- `heartbeat_helper_cannot_outlive_wrapper`
- `terminal_stop_reason_remains_the_only_completion_rule`

Retain every existing protected test, especially fixed permissions, `--max-turns`, terminal JSON waiting, private-copy review, exact-session resume, packet hashing, cost reporting, and linked-worktree behavior.

### `tests/test-ai-reviewer-issue.sh`

Add named tests for:

- `explicit_session_selects_matching_metadata_not_newest`
- `repository_and_caller_disambiguate_same_session_name`
- `zero_matches_fail_without_unrelated_fallback`
- `multiple_matches_fail_with_safe_choices`
- `scoreboard_report_and_log_capture_follow_selected_session`
- `missing_correlated_artifact_is_labelled_not_substituted`
- `selected_metadata_remains_redacted_and_private`

### Verification breadth

The adjacent packet, snapshot, scoreboard, and Windows suites remain green because this change crosses their boundaries. No test may call a paid provider unless it is behind the existing explicit live-test opt-in. Live qualification is one bounded manual gate, not part of ordinary unit tests.

## 11. Constraints, standing rules, and gotchas

- Read the current STEP 0 header in `bin/ai-grok-review` before editing. Every odd-looking rule there guards a measured failure.
- Completion is terminal `stopReason`, never exit status, output bytes, process death, heartbeat, or provider logs.
- Never remove `--max-turns`, broaden permissions, add flag passthrough, restore `--worktree`, use `--permission-mode auto`, enable memory/web/Bash/edit, or simplify the wait loop.
- Preserve the session-specific private review copy shipped in #53. A reviewer receives one self-contained directory; never hand it a raw linked worktree or widen its boundary.
- Preserve exact-head and packet hashes. Lock identity says what repository is being billed; it does not replace the commit identity being reviewed.
- Use portable Bash that works in Windows Git Bash. `flock` is unavailable. Avoid Unix-only process assumptions and verify path normalization with Windows drive-letter fixtures.
- State files stay private. Never print prompts, credentials, auth files, or provider transcripts in `list` or lock diagnostics.
- Never read or print `~/.grok/auth.json`.
- Do not report Kimi-style unsupported metrics here; Grok does expose final tokens/cost, but progress must not invent interim figures.
- Direct work is normally on `main`; never force-push. Verify Albert's commit identity before the first commit.
- The current checkout contains another session's dirty `.gitignore` and memory work. Never stage with `git add -A`, `git add .`, or broad globs.
- This repo has no CI, hosted deployment, database, or production service. Do not scaffold them to satisfy a generic checklist.
- Reviews are read-only. This plan does not authorize Grok implementation, shared-db changes, cloud mutation, or production work.
- GPT-5.6 reasoning effort remains `low` or `medium` if Codex is used.

## 12. Access and environment

- Repository: `C:\repos\ai-devops`; GitHub: `u2giants/ai-devops`; target branch: `main`.
- Planning machine: `edge-dev`; primary shell: PowerShell; wrapper/test shell: Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- `gh` is authenticated and successfully read issue #56 on 2026-08-20.
- Git identity is currently correct: `Albert Hazan <u2giants@users.noreply.github.com>`. Re-check immediately before committing.
- Grok is already authenticated through its private CLI state. Use `ai-grok-review doctor`; never expose its credential files.
- State root is normally `C:\Users\ahazan\.local\state\ai-devops\grok` on this machine. Tests must override it to a temporary directory and must not touch live state.
- No 1Password secret is required for offline work. If authentication recovery becomes necessary, use the existing Grok login flow; do not create, rotate, or commit a credential.
- No local server needs to run. Offline tests use temporary repositories and stub commands.

---

# Part 4 — Landing it

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] Equivalent clones of one upstream repository cannot start concurrent paid Grok turns.
- [ ] Unrelated upstream repositories remain independent.
- [ ] Existing named sessions remain findable and resumable from their owning checkout.
- [ ] `list` exposes active work across clones/callers with factual timing and ownership.
- [ ] Signals and deletion never imply unproven remote cancellation.
- [ ] Active-session deletion is refused; inactive deletion remains explicit and bounded.
- [ ] Mid-turn output distinguishes “local wrapper still waiting” from silence without claiming provider health.
- [ ] Terminal `stopReason`, read-only permissions, turn bounds, exact-head binding, private snapshots, packet hashes, session continuity, and cost reporting remain intact.
- [ ] Reviewer incident capture attaches the selected run or an explicit absence—never unrelated recent evidence.
- [ ] Required offline suites pass and their full evidence is saved.
- [ ] One bounded installed-wrapper live qualification passes without concurrent provider calls.
- [ ] Independent exact-head review has no unresolved Critical/High/Medium finding.
- [ ] Source and installed wrapper/skill hashes match.
- [ ] Commit is pushed to GitHub `main`; remote SHA is verified; issue #56 is updated and closed.
- [ ] Plan STATUS, topic docs, memory, and handoff are current; only this session's handoff is removed at proven completion.
- [ ] No deployment check is claimed because this toolkit has no hosted deployment or CI.

### Main risks and recovery

1. **Over-normalizing two different repositories into one lock.** Mitigation: canonical host/owner/repo fixtures and unrelated-repository tests. Recovery: revert the owned commit; no user data lives in locks.
2. **Under-normalizing a remote spelling and leaving the hole open.** Mitigation: table-driven HTTPS/SSH/local-path fixtures plus the two-clone live canary.
3. **Stranding existing named sessions.** Mitigation: leave checkout/session `repo_id()` intact and add a separate lock id. Recovery: backward-compatible `find_meta()` remains the source for existing records.
4. **A stale, dead-owner, legacy, or malformed paid-work lock blocks work.** This is the safe failure because local process death does not prove remote completion. Print exact inspection guidance and require manual reconciliation; never delete or reclaim ambiguous state automatically.
5. **A trap releases another process's lock.** Mitigation: record ownership and release only when the lock still matches the current process/token.
6. **Heartbeat survives the wrapper or becomes noisy.** Mitigation: parent-owned cleanup, bounded interval, no output for fast calls, interruption tests.
7. **Provider abort semantics differ by installed version.** Mitigation: keep the decision open until version-matched documentation and a harmless canary prove it. Warning-only behavior is acceptable and safer.
8. **Incident correlation fields are missing in old records.** Mitigation: fail visibly rather than using recency. Historical packages remain untouched and their limitation is documented.
9. **Concurrent local work is overwritten.** Mitigation: implement in a clean clone if this checkout remains dirty; stage explicit owned paths; never force-push.

### Genuine open questions

- Does the installed Grok version expose a positively confirmable remote abort? Step 8 defines the evidence and fallback.
- Does a supported streaming format preserve the wrapper's terminal and session contracts while exposing trustworthy progress? Step 11 defines the adoption gate; the heartbeat is the default.
- Can historical scoreboard/report/log entries be correlated by exact session fields, or only by a bounded time window? Inspect schemas during Step 12. When correlation is not provable, record absence.

## Mandatory self-audit

1. **Could a brand-new AI session execute this plan perfectly without asking Albert anything? Yes.** Sections 1–4 define the business outcome, repository, incident, reproduction, and boundaries. Sections 5–8 preserve the exact current state, root causes, rejected paths, and locked/open decisions. Section 9 gives ordered file-level work with a proof gate for every step; Sections 10–12 provide named tests, safety rules, and environment/access.
2. **Does the plan carry every piece of background, nuance, and reasoning from the investigation? Yes.** Sections 3, 5, and 6 include the five clone identities, the packet-isolation reason clones existed, the local-versus-remote cancellation distinction, the progress limitation, and the incorrect automatic evidence attachments. Section 7 records thirteen rejected approaches so the implementer does not repeat them.
3. **Is the ultimate goal clear enough to guide a correct judgment if a step is wrong? Yes.** Section 1 states the plain-English outcome and explicitly makes the goal controlling. Section 8 locks the safety invariants, while Sections 11 and 13 define the non-negotiable completion rule, risks, recovery, and evidence-based open decisions.

### Checklist result

All 13 required sections are present; out-of-scope work is explicit; locked versus open decisions are labelled; every implementation step names concrete files/functions and a verification gate; tests are named by behavior; paths, identities, issue links, and SHAs are defined; secrets are referenced only by protected location; commit/push/installation verification is included; and the plan and its own handoff link to each other. **Self-audit passed on 2026-08-20.**
