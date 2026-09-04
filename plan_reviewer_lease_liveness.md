# plan_reviewer_lease_liveness.md

**Give a held reviewer lease a liveness signal, so a lease whose worker died
silently can be reclaimed on evidence a third party can produce — without
inventing failure evidence, without relaxing the six terminal failure codes,
and without ever reclaiming a lane that is still working.**

Governed by **issue [#283](https://github.com/popcre/ai-devops/issues/283)** in
`popcre/ai-devops` (the review-tooling record) and executed by
**[`u2giants/shared-db#2345`](https://github.com/u2giants/shared-db/issues/2345)**
(`work_type: repo-maintenance`, `route: repo-maintenance`, priority 200), because
every line of the reviewer-lease implementation lives in
`u2giants/shared-db/scripts/manage-migration-author-lanes.mjs`.

**Read `plan_reviewer_lease_capacity_truth.md` STATUS in `u2giants/shared-db`
first.** It is COMPLETE. Do not restart it, and do not re-derive
`--release-failed-reviewer`, `--reviewer-capacity`, lease age, or the refusal
wording — this plan builds on top of all four.

---

## STATUS

| # | Step | State | Evidence |
|---|---|---|---|
| 0 | Design written, registered in `AGENTS.md`, cross-linked from #283 and shared-db#2345 | ✅ done | this file |
| 1 | `activityFingerprintForLease` — third-party-readable liveness fact for one lease | ⬜ not started | shared-db#2345 |
| 2 | `--probe-silent-reviewer` — records a first silence observation (create-only) | ⬜ not started | shared-db#2345 |
| 3 | `--reclaim-silent-reviewer` — releases only on a confirmed, unchanged second observation | ⬜ not started | shared-db#2345 |
| 4 | `--reviewer-capacity` reports `silence-probed` / `silence-reclaimable` and last activity | ⬜ not started | shared-db#2345 |
| 5 | Reviewer allocation queue — a waiting lane is recorded and served in order | ⬜ not started | shared-db#2345 |
| 6 | Proof against a genuinely working lane, plus the 4-minute near-miss case | ⬜ not started | shared-db#2345 |

---

# Part 1 — Why

## The business problem, in plain English

Albert's database changes are checked by a small pool of independent AI
reviewers. Each reviewer can only work on one thing at a time, so the system
hands out a limited number of "slots". When a reviewer is given a slot and the
program running it dies without saying anything, **nobody is allowed to take that
slot back.** Handing a slot back requires proof that the reviewer failed — and
only the program that died could have produced that proof.

So every silent death permanently removes a slot. On 2026-09-04 this took the
pool from four usable slots to one, and a migration that was otherwise ready to
merge waited for a slot twice. The slots were eventually recovered only because
somebody refreshed the stuck branch and the merge *happened* to be clean. Had it
conflicted, those slots could not have been freed at all.

**When this work is done:** a slot held by something that has plainly stopped
working can be handed back by anyone, on evidence anyone can gather; a slot held
by something that is still working cannot; and a lane waiting for a slot is
recorded in line instead of being passed over silently.

> **If any step here conflicts with that goal, the goal wins — stop and flag it.**
> In particular, never free a slot by weakening what counts as failure, and never
> free a slot on age alone.

## The defect, precisely

Releasing a lease (`--release-failed-reviewer`) requires one of the six
`TERMINAL_FAILURE_CODES` **plus** the exact failed sequence, plus
`--confirm-no-verdict --confirm-no-artifact`. That evidence is producible only by
whoever ran the reviewer wrapper and watched it fail — that is, the process that
has died. "The worker went silent" is not one of the six codes, and must not
become one: those codes describe *observed provider/tool failures*, and an
observer who saw nothing has not observed a provider failure.

The only third-party route today is `stale-reclaimable`, which
`findBusyReviewers` derives from the PR head moving, the PR closing, or a verdict
landing. All three require the lane itself to act. And `stale-reclaimable` is
**not** a safe reclaim signal on its own: on the same day, a slot was marked
`stale-reclaimable` four minutes after another lane pushed mid-iteration. It
conflates "abandoned" with "actively iterating".

## Known adjacent traps — do not re-derive these

- Reviewer release was once welded to a replacement draw, so the pool deadlocked
  exactly when it was full. `--release-failed-reviewer` already fixed that; the
  new path must not reintroduce it.
- A release-only path that shares the replacement path's **create-only key**
  frees everyone except its own PR. The silence path therefore gets its **own**
  ref namespace, never `refs/db-review-failures/...`.
- `--replacement-sequence` takes the **FAILED** sequence, not the new one.
- A replacement can be blocked by the failed reviewer's **unrelated** lease.
- A cap measures time, not progress. A timeout cannot tell "slow but advancing"
  from "never started", so no step here may be a timeout.
- Reviewer allocation has **no queue**: a waiting lane can be passed over
  indefinitely and nothing records it.

---

# Part 2 — The design

## The core idea: two recorded observations, not a timeout

A dead worker is not distinguished from a slow one by *elapsed time*. It is
distinguished by **the absence of any change across two observations separated in
time**. That absence is a fact about the PR, readable by anyone with GitHub read
access — which is exactly what a third party can produce and a timeout cannot.

### Step 1 — `activityFingerprintForLease(lease, io)`

Returns a stable SHA-256 over facts that any live reviewer lane necessarily
moves, all scoped to the exact lease `(issue, pr, headSha, slot, sequence)`:

- PR state and `head.sha` (must equal `lease.headSha`);
- count and maximum `updatedAt` of PR issue comments, review comments and reviews;
- count and maximum `createdAt` of check runs and workflow runs **against that
  head** (a main-branch dispatch is not activity on this PR — that mis-read is
  what made PR #2237 look alive for six hours);
- `hasVerdictForHead(...)` for that head and slot;
- the PR's draft flag.

Plus `lastActivityIso` = the newest of those timestamps, or `none`.

Fail closed: if any input is unreadable, throw. An unreadable fingerprint must
never be recorded as silence. This mirrors `findBusyReviewers`, which returns
`null` rather than inventing availability.

### Step 2 — `--probe-silent-reviewer` (records, never releases)

Refuses unless **all** hold:

1. the lease exists, `pr.state === 'open'`, `pr.head.sha === lease.headSha`, and
   `hasVerdictForHead(...)` is false — that is, the lease is `live`, not
   `stale-reclaimable`. **The silence path never touches a `stale-reclaimable`
   lease**, which is precisely why the 4-minute near-miss is out of its reach;
2. `reviewLeaseAgeHours(heldSince) >= SILENCE_MIN_AGE_HOURS` (**2**);
3. `lastActivityIso` is `none` or older than the lease's `heldSince` — nothing
   has happened on this PR *since the reviewer was handed the slot*.

Writes, create-only, to a namespace of its own:

```
refs/db-review-silence/<issue>-<pr>-<headSha>-<sequence>
db-coordination reviewer-silence-probe reviewer=<name> issue=<n> pr=<n> head=<40> \
  sequence=<n> slot=<n> observed-at=<ISO> lease-held-since=<ISO> \
  last-activity=<ISO|none> fingerprint=<sha256>
```

Create-only means a probe is immutable and a second probe cannot overwrite the
first — the clock a reclaim is measured against cannot be reset by whoever wants
the slot. Probing mutates no lease and needs no mutex beyond the ref write.

### Step 3 — `--reclaim-silent-reviewer` (the only new release path)

Refuses unless **all** hold:

1. a probe ref exists for this exact `(issue, pr, head, sequence)`;
2. `now - probe.observedAt >= SILENCE_CONFIRM_HOURS` (**2**) — so a lease cannot
   be reclaimed less than **4 hours** after it was drawn, under any timing;
3. the fingerprint recomputed **now, fresh** equals `probe.fingerprint`;
4. the lease is still the same lease, still `live`, still no verdict, head
   unchanged, PR open and eligible — re-checked **after** mutex acquisition, the
   same way `releaseFailedReviewer` re-checks;
5. `--confirm-no-verdict --confirm-no-artifact` are given, as for a terminal
   release.

Any change at all to the fingerprint — one comment, one check run, one push, one
verdict — fails condition 3 and the reclaim is refused. **That is the whole
"abandoned versus actively iterating" test**, and it is evidence, not a guess.

On success, under the existing review mutex and `atomicReviewRefs`
compare-and-swap:

```
refs/db-review-silences/<issue>-<pr>-<headSha>-<sequence>   (create-only, new namespace)
db-coordination reviewer-silence-release reviewer=<name> issue=<n> pr=<n> head=<40> \
  sequence=<n> code=silent_worker_observed probe=<sha> observed-at=<ISO> \
  confirmed-at=<ISO> verdict=none artifact=none replacement=none
```

and deletes `refs/db-review-active/<reviewer>` with `expected` set to the lease
SHA.

`TERMINAL_FAILURE_CODES` stays **six**. `silent_worker_observed` is deliberately
*not* added to it: it lives only in this message form and this namespace, so a
silence release can never be mistaken for — or substituted into — a terminal
provider-failure release. `assertAssignmentWasNotTerminallyReleased` must learn
about the silence namespace too, so a reclaimed sequence is not re-leased by a
plain assignment retry.

### Step 4 — capacity report tells the truth about silence

`reviewerCapacityReport` gains, read-only and non-mutating:

- `lastActivityIso` and `silenceProbe` (`null` or `{observedAt, fingerprint, sha}`);
- two classifications between `live` and `suspect-aged`:
  `silence-probed` (probe recorded, confirm window not yet elapsed) and
  `silence-reclaimable` (probe recorded, window elapsed, fingerprint still equal);
- summary counts for both.

`REVIEW_LEASE_SUSPECT_HOURS` (24) stays exactly what it is: advisory visibility.
Age still never releases anything.

### Step 5 — allocation gets a queue

Today a refused lane simply retries and may be passed over forever. Add a
create-only ticket:

```
refs/db-review-queue/<issue>-<pr>-<slot>
db-coordination reviewer-queue-ticket issue=<n> pr=<n> slot=<n> requested-at=<ISO>
```

- `--request-reviewer` writes the ticket (idempotent: an existing ticket is
  reused, never refreshed — refreshing would let a lane keep its place by asking
  repeatedly);
- `assignNextReviewer` serves the **oldest live ticket first**; a lane holding a
  younger ticket is refused with the holder of the older one named;
- a ticket is **live** only while its PR is open and its head is unchanged, so an
  abandoned ticket expires exactly like a lease does, with no new timer;
- the ticket is deleted when its lane is assigned;
- `--reviewer-capacity` prints the queue, oldest first.

This is FIFO among genuinely-waiting lanes, and it fails open: if the queue refs
are unreadable, allocation behaves exactly as it does today.

---

# Part 3 — Proof (Step 6)

A green run against a dead lane proves nothing. Required before this is trusted:

1. **Live-lane refusal, recorded.** Probe a lease belonging to a review that is
   genuinely in progress; assert the probe is refused (activity newer than
   `heldSince`), and assert that when a probe *is* legitimately taken and the lane
   then comments once, `--reclaim-silent-reviewer` refuses on fingerprint
   mismatch.
2. **The 4-minute case.** A slot marked `stale-reclaimable` four minutes after a
   mid-iteration push must be untouchable by both new commands — asserted
   directly, as the regression it is.
3. **The #2237 case.** A lease six hours old with no comment, no push, no verdict
   and no workflow run against its head — but with a main-branch dispatch present
   — probes successfully and reclaims after the confirm window. The main-branch
   dispatch must not count as activity.
4. **Full-pool release.** A reclaim succeeds when all slots are held, and frees
   the reclaiming PR's own slot (the create-only-key bug, asserted directly).
5. **Queue fairness.** An older waiting ticket is served before a younger one,
   and a ticket whose PR head moved does not block anyone.
6. The complete shared-db lane suite stays green, and the PR carries a live
   `--reviewer-capacity` read showing the new classifications.

## Non-negotiable

- Do **not** relax the six terminal failure codes.
- Do **not** make release unconditional, and do not release on age alone.
- Do **not** reuse the failure namespace or its create-only key.
- A silence release with an unreadable input is a refusal, never a release.
