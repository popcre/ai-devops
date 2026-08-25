# Implementation plan — make `ai-muse`'s stale-turn rejection diagnosable and recoverable

**Repository:** `u2giants/ai-devops` (public)
**Authored:** 2026-08-25 by Claude (Opus 5) on machine `edge-dev`
**Base commit:** `5b562d19b0e0e9e3c81d5fc23f0e6dbcb43c1e6f` (`origin/main`)
**Handoff:** [`HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md`](HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md)
**Sibling plan:** [`plan_reviewer-cache-efficiency.md`](plan_reviewer-cache-efficiency.md) — independent; neither blocks the other.

---

## STATUS — read this first

Nothing has been implemented. A fresh session starts at **Step 1**.

| # | Step | Status | Evidence |
|---|---|---|---|
| 0.1 | Incident that triggered this | ✅ 2026-08-25 | § 3; reproducible with the command in that section |
| 1 | Capture a before/after path inventory alongside the existing hash | ⬜ open | — |
| 2 | Name the changed paths in both rejection messages | ⬜ open | — |
| 3 | Name `reconcile` in both rejection messages | ⬜ open | — |
| 4 | Tests | ⬜ open | — |
| 5 | Finish every edit, prove it live, then review the exact final state and publish | ⬜ open | — |

**Rule for this table:** ✅ requires an artifact — a commit SHA, a test name, or
the exact command to re-run. Not a bare "done".

---

# Part 1 — Why

## 1. The ultimate goal

**When `ai-muse` refuses a completed review, the person reading the error should
be able to tell immediately what went wrong and how to get their review back —
without reading the wrapper's source.**

Today it tells them neither. It says the repository changed but not *what*
changed, and it lists four recovery commands without including the one that
actually recovers the session. The provider work is already paid for and sitting
in the transcript, but the message steers a reader toward `delete`, which throws
it away and forces a second paid review.

**What must not change:** the guard itself. Rejecting a review whose evidence
base moved underneath it is correct and is the reason this check exists. This
work makes the *failure* legible. It does not make the wrapper more permissive,
and it must not become an excuse to relax what counts as a change.

> **If a step conflicts with this goal, the goal wins — stop and flag it.**
> Concretely: if you find yourself about to make `tree_state` ignore a category
> of file so the rejection stops firing, **stop**. That is not this task. A
> rejection that fires correctly and explains itself is the target; a rejection
> that fires less often is a regression dressed as a fix.

## 2. What this application is

`ai-devops` is Albert Hazan's personal DevOps toolkit — the machinery that lets
AI sessions work safely across his machines. Not customer-facing.

- **GitHub:** `u2giants/ai-devops`, **public**. Never commit a secret value.
- **Branch policy:** `AGENTS.md:20` — work directly on `main`, no feature
  branches. Reconcile concurrent `main` without force; confirm the commit
  reached `origin/main` (`AGENTS.md:114-115`).
- **Stack:** `bash`, `jq`, `git`. Nothing to deploy.
- **Platforms:** Windows 11 + Git Bash (`edge-dev`) and Ubuntu (`hetz`). Both
  must keep working.

### What `ai-muse` is

`bin/ai-muse` (394 lines) gives Claude and Codex named, persistent review
conversations with Muse Spark 1.2 Contributor, driven through OpenCode in direct
mode — one `opencode run` process per turn, resuming an exact session id. Muse
is an **advisory** reviewer: it cannot satisfy an approval gate
(`bin/ai-review:9-11`). It reviews a disposable self-contained snapshot of the
repository built by `bin/ai-review-sandbox`, and has no write or shell tools.

### The mechanism this plan touches

`tree_state` (`bin/ai-muse:149-152`) hashes the reviewable source state:

```bash
git rev-parse HEAD
git diff --binary HEAD
# plus, for each untracked-but-not-ignored file: its path and sha256
```

`cmd_new` (`bin/ai-muse:318`) and `cmd_ask` (`:335`) capture that hash into
`before` prior to the provider call, and compare it to `after` at `:324` and
`:339`. On mismatch the turn is rejected. The session is left at
`completed_pending_local_checks` (set at `:323` / `:338`, deliberately *before*
the comparison, so a provider session is never lost to a local failure) and
`cmd_reconcile` (`:346`) is the command that returns it to `active`.

**That untracked-but-not-ignored set is exactly what the review snapshot
reproduces**, which is why a new untracked file legitimately counts as the tree
moving. This is not over-sensitivity.

## 3. What triggered this work

On 2026-08-25, during a review session in this repository, a Muse turn was
rejected with:

```
ai-muse: error: the source repository changed during the Muse turn; stale
response rejected. The session was preserved; use AI_MUSE_CALLER=claude with
show, ask, transcript, or delete.
```

The cause was that the calling session had run `ai-muse new … 2>muse1.err` from
the repository root, creating an untracked file mid-turn. Muse's review had
completed successfully and was intact in the transcript.

Two things went wrong beyond the (correct) rejection:

1. **The message named no path**, so the cause had to be deduced by reasoning
   about what the session had done. Nothing in the error pointed at `muse1.err`.
2. **The message did not mention `reconcile`.** It listed "show, ask,
   transcript, or delete". Recovery was only possible because the operator
   happened to know from the `ask-muse` skill that `ai-muse reconcile <name>`
   exists. A reader following the message would plausibly have chosen `delete`
   and paid for a second full review.

Note that `bin/ai-muse:331` — the message shown when you *try to continue* a
pending session — already gets this right: *"Inspect: … transcript … ; then run:
… reconcile …"*. So the wrapper already knows the correct recovery phrasing; two
of its three messages simply do not use it.

### Reproduce it

```bash
cd <any git repo>
AI_MUSE_CALLER=claude ai-muse new repro --prompt 'say hi' 2>err.txt
```

The redirect creates `err.txt` in the repository while the turn runs. Expect the
rejection above. Recover with `ai-muse transcript repro`, then
`ai-muse reconcile repro`, then delete `err.txt`.

The offline test suite reproduces the same condition without a provider call
using `MUSE_STUB_TOUCH` (`tests/test-ai-muse.sh:269`).

## 4. Scope — in and out

### In scope

1. Alongside the existing hash, capture a **path inventory** before and after
   each turn, and on mismatch name the paths that differ.
2. Add `reconcile` to both rejection messages, matching the phrasing already
   used at `bin/ai-muse:331`.
3. Tests for both, in `tests/test-ai-muse.sh`.

### Explicitly NOT in this plan

- **Do not change what `tree_state` covers.** Not to exclude `.err` files, not
  to exclude any extension, not to exclude "scratch-looking" names. The set it
  hashes is the set the reviewer sees. Narrowing it would let a real change slip
  past the guard. **This is the single most important line in this plan.**
- **Do not change when the guard fires**, or make rejection a warning.
- **Do not auto-reconcile.** Reconciliation is a deliberate human acceptance of
  a recorded provider state; `bin/ai-muse:346` restricts it to specific statuses
  on purpose.
- **Do not touch** `cmd_reconcile`'s status whitelist, `preserve_failure`, the
  report-publishing path (`reserve_report_staging` / `finish_report_staging`),
  the read-only agent profile, or the model pin.
- **Do not "fix" this by having the wrapper write its own stderr elsewhere** —
  the redirect was the caller's, not the wrapper's.
- **No changes to any other reviewer wrapper.** If `ai-grok-review`, `ai-kimi`,
  or `ai-qwen` have the same diagnostic gap, note it as a follow-up; do not
  widen this change.
- **Not related to** [`plan_reviewer-cache-efficiency.md`](plan_reviewer-cache-efficiency.md).
  Do not combine the two.

---

# Part 2 — What we already know

## 5. Current state of the code

Committed and pushed at `5b562d1`. Nothing half-done.

| Location | What is there today |
|---|---|
| `bin/ai-muse:149-152` | `tree_state` — returns a single sha256, no path list |
| `bin/ai-muse:318` | `cmd_new`: `before="$(tree_state "$root")"` before `prepare` |
| `bin/ai-muse:324` | `cmd_new` rejection — no path, no `reconcile` |
| `bin/ai-muse:335` | `cmd_ask`: same `before` capture |
| `bin/ai-muse:339` | `cmd_ask` rejection — no path, no `reconcile` |
| `bin/ai-muse:331` | **The message that gets it right** — copy this phrasing |
| `bin/ai-muse:346` | `cmd_reconcile` — the recovery command |
| `bin/ai-muse:384` | `usage` — already lists `reconcile` |
| `bin/ai-muse:3` | `set -euo pipefail` — a failing command substitution aborts |

Helpers you should reuse rather than reinvent: `tmp_file` (temp files under the
`RUN_TMP` directory, created `chmod 700` at `bin/ai-muse:22-23`), `die`, and the
existing `printf … >&2` convention.

## 6. Key findings

**A. The information needed for a good message is already computed — then
discarded.** `tree_state` builds a per-path record and immediately collapses it
to one hash. Naming the changed paths needs the intermediate list retained, not
new data collection.

**B. The wrapper already contains the correct recovery phrasing.**
`bin/ai-muse:331` names `transcript` then `reconcile`. This is a
consistency fix, not a new design.

**C. The test harness for this already exists.** `tests/test-ai-muse.sh:269`
uses `MUSE_STUB_TOUCH` to mutate the source mid-turn and asserts the rejection;
`:271-274` assert session preservation, the continuation block, and that
`reconcile` re-enables continuation. New assertions extend that block — no new
harness required.

**D. One existing test constrains the message text.**
`tests/test-ai-muse.sh:25` asserts the string `stale response rejected` appears
**exactly twice** in the wrapper. Keep both occurrences (or update that test
deliberately and say why in the commit). Do not let it go red by accident.

## 7. Approaches considered and REJECTED

| # | Approach | Why rejected |
|---|---|---|
| R1 | Make `tree_state` ignore untracked files, or ignore `*.err`/`*.log` | The untracked-not-ignored set is exactly what `ai-review-sandbox` copies into the review snapshot, so those files *are* part of what the reviewer sees. Excluding them would let a real change pass the guard. This is the tempting fix and it is wrong. |
| R2 | Downgrade the rejection to a warning and publish anyway | The verdict would then describe a tree that no longer exists, which is the failure the guard was written to prevent. |
| R3 | Auto-reconcile on this specific cause | Reconciliation is a deliberate acceptance of recorded provider state (`bin/ai-muse:346`). Automating it removes the human decision that makes it safe. |
| R4 | Have the wrapper snapshot-and-restore the caller's stray files | The wrapper does not own the caller's files and must never move or delete them. |
| R5 | Fix it in the `ask-muse` skill by telling callers not to redirect into the repo | Already done as a *note* in `plan_reviewer-cache-efficiency.md` § 11, and it is avoidance, not repair. The wrapper should explain itself regardless of who reads the skill. Keep the note; it is not a substitute. |
| R6 | Print the full before/after inventories on mismatch | Unbounded output; a large untracked tree would bury the message. Print differing paths only, capped. |
| R7 | Include file *contents* or hashes in the message | Contents may be sensitive and this repository is public; the diagnostic needs paths, not bytes. |

## 8. Design decisions

### D1 — The hash stays the decision; paths are diagnostics only. **LOCKED.**
*(2026-08-25)* The accept/reject comparison remains the `before`/`after` sha256
of `tree_state`. The path inventory exists purely to explain a rejection that
has already been decided. If the inventory fails to compute for any reason, the
rejection must still fire with the current message rather than being skipped.

### D2 — Paths only, never contents. **LOCKED.** *(2026-08-25)* See R7.

### D3 — Cap the output. **LOCKED.** *(2026-08-25)* Name at most 10 paths and
then a count of the remainder, so one message stays readable.

### D4 — Both rejection messages name `reconcile`, in the phrasing already used at `bin/ai-muse:331`. **LOCKED.** *(2026-08-25)*
Inspect first, then reconcile. Do not invent a new wording; match the existing
one so the three messages are consistent.

### D5 — How to retain the inventory. **OPEN, with criteria.**
The straightforward route is a second function that emits the per-path records
`tree_state` already builds, written to a `tmp_file` before the turn and again
after, with the two compared on mismatch. Any approach is acceptable that (a)
leaves `tree_state`'s hash and coverage byte-identical, (b) cannot abort the
run under `set -e` when the inventory step fails, and (c) writes only inside the
wrapper's own `RUN_TMP`. Choose the simplest that satisfies those three.

---

# Part 3 — How to build it

## 9. The plan

### Step 1 — Capture a before/after path inventory

**File:** `bin/ai-muse`, near `tree_state` (`:149-152`), used from `cmd_new`
(`:318`) and `cmd_ask` (`:335`).

Add a helper that writes one line per reviewable path — `HEAD`, each tracked
path with uncommitted changes, and each untracked-not-ignored path — to a file.
Call it just before the turn and again just after, into two `tmp_file`s.

**Behaviour when done:** the hash comparison at `:324` and `:339` is unchanged
and still decides the outcome; two inventory files exist alongside it; and a
failure to produce either is survivable (D1). Under `set -euo pipefail`
(`bin/ai-muse:3`), guard the calls so a non-zero exit becomes "no inventory
available" rather than an abort.

**Verification gate:** `bash tests/test-ai-muse.sh` still passes unchanged
before you touch any message text. If it does not, stop — Step 1 was supposed to
be behaviour-neutral.

### Step 2 — Name the changed paths in both rejection messages

**Files/lines:** `bin/ai-muse:324` (`cmd_new`), `bin/ai-muse:339` (`cmd_ask`).

On mismatch, diff the two inventories and list the paths that were added,
removed, or modified. Cap at 10 with a trailing count (D3). Paths only (D2). If
no inventory is available, fall back to today's wording.

**Behaviour when done:** the incident in § 3 produces a message naming
`muse1.err` as added.

**Verification gate:** the new tests in Step 4 pass; `tests/test-ai-muse.sh:25`
(the exactly-twice count) is still green.

### Step 3 — Name `reconcile` in both rejection messages

Same two lines. Follow `bin/ai-muse:331`'s pattern: inspect with `transcript`,
then run `reconcile`, both with the `AI_MUSE_CALLER=$CALLER` prefix and the
session name interpolated.

`cmd_new`'s message currently lists "show, ask, transcript, or delete". Keep the
inspection commands, add `reconcile` as the recovery step, and make sure
`delete` no longer reads as an equally reasonable next action — it discards paid
provider work.

**Verification gate:** the Step 4 message tests pass.

### Step 4 — Tests

**File:** `tests/test-ai-muse.sh`, extending the block at `:269-274`.

| Test | Asserts |
|---|---|
| `stale_rejection_names_the_changed_tracked_path` | With `MUSE_STUB_TOUCH` on a tracked file, the message names that path |
| `stale_rejection_names_a_new_untracked_path` | A new untracked, non-ignored file created mid-turn is named — **this is the § 3 incident** |
| `stale_rejection_names_reconcile_from_new` | `cmd_new`'s message contains the `reconcile` command with the session name |
| `stale_rejection_names_reconcile_from_ask` | Same for `cmd_ask` |
| `stale_rejection_path_list_is_capped` | With more than 10 changed paths, at most 10 are listed and a remainder count is shown |
| `stale_rejection_prints_no_file_contents` | The message does not contain a sentinel string written *inside* a changed file (guards D2) |
| `guard_still_fires_without_an_inventory` | If the inventory cannot be produced, the turn is still rejected (guards D1) |

Follow the file's existing `check '<name>' "<expr>"` idiom and its `$ENV`/`$REPO`
scratch setup. Do not add a new harness.

**Verification gate:** `bash tests/test-all.sh` ends `failures=0`.

### Step 5 — Land it

**Read the ordering rule before doing anything in this step.** The exact-state
final review required by `AGENTS.md:39-42` reviews a *specific source state* and
binds a whole-source digest. Any tracked file you edit afterwards — a doc, this
plan's STATUS table, a handoff — changes that digest and silently invalidates the
review. So every intended change lands **before** the review, and the only thing
that happens after it is publishing the reviewed state.

#### 5a — Finish every intended edit first

Complete all of these while the review has not yet run:

- The code and test changes from Steps 1–4.
- `docs/muse-opencode.md`, describing the improved failure message and the
  `reconcile` recovery path.
- This plan's STATUS table, with artifacts in every cell you can fill.
- `HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md`, closed.
- Load `session-docs-update` and complete its documentation pass **now**, not
  after the review.

**One STATUS cell cannot be filled in advance:** the artifact for the final
review itself, which does not exist until the review has run. Do not edit the
plan afterwards to add it. Record that report path in the **commit message** and
in the session's closing report instead. That is the only place it belongs.

**Verification gate:** `git status --short` shows every intended change staged or
present, and you can state plainly that no further tracked-file edit is planned.

#### 5b — Prove the live behaviour

**This is mandatory, and it spends money on a live provider call. Albert
authorizes it.** Ask him in the implementing session before making the call. If
he declines, stop and report — do not substitute the offline stub tests as proof
and do not land the change as if this step had passed.

Run one real `ai-muse` turn and trigger the rejection deliberately using § 3's
reproduction, then paste the improved message into the closing report.

**Run it in a disposable scratch Git repository, never in the `ai-devops`
checkout.** The reproduction works by creating an untracked file mid-turn, which
is exactly the kind of tracked-tree change that would invalidate the review you
are about to run. Invoke the modified wrapper by absolute path from the scratch
repo so you are testing this change and not an installed older copy.

**Verification gate:** the pasted message names the changed path and names
`reconcile`, and the `ai-devops` working tree is unchanged by this step.

#### 5c — Test and review the exact final state

```bash
bash tests/test-all.sh
```

Then the gates:

```bash
ai-review claude diff-review
```
```bash
ai-review codex diff-review
```

Then the independent exact-state review that `AGENTS.md:39-42` mandates for
changes to reviewer wrappers:

```bash
ai-review claude final-check
```

Reviewer reports are written under `.ai/reviews/`, which is Git-ignored and
therefore does not disturb the source digest — running these reviews is safe.
Editing a tracked file is not.

**Verification gate:** all three return APPROVE against the state you intend to
publish.

#### 5d — Publish, and change nothing else

Commit on `main` (`AGENTS.md:20`), push, and confirm the commit reached
`origin/main` (`AGENTS.md:114-115`). Name the final-check report path in the
commit message.

**If anything at all needs to change after 5c — a typo, a doc line, a STATUS
cell — the review is void.** Make the change, then re-run 5c in full before
publishing. Do not rationalise a "small" post-review edit; the digest does not
distinguish small from large, and neither does the rule.

## 10. Tests required

Every test in Step 4, plus **the entire existing suite stays green**. No test
may be deleted, skipped, or relaxed. Watch `tests/test-ai-muse.sh:25`
specifically — it counts message occurrences and is the one most likely to be
disturbed by editing message text.

## 11. Constraints, standing rules, and gotchas

- Work directly on `main` (`AGENTS.md:20`); run `git var GIT_COMMITTER_IDENT`
  before your first commit — it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- This checkout may be shared. **Stage only your own files**; never `git add -A`.
- Public repository. No secret values.
- **Do not simplify a measured guardrail without reading its reason**
  (`AGENTS.md:52`). `bin/ai-muse` is dense with comments recording real
  incidents.
- **`bin/ai-muse:3` is `set -euo pipefail`.** A failing command substitution
  aborts the script — and here it would abort *after* the provider has already
  answered, losing the report. This is the same class of hazard the sibling plan
  documents for `jq` reads.
- **Do not write scratch files into the repository while testing this by hand** —
  that is the very condition under test, and it will make an unrelated run look
  like a failure. Use the session scratchpad.
- **`ai-glm` is `.cmd`-only on Windows**; Git Bash cannot run it. Irrelevant to
  this change but relevant if you route a review through GLM.
- The status set at `:323`/`:338` is written **before** the tree comparison on
  purpose, so a provider session survives a local failure. Do not reorder it.

## 12. Access and environment

- **Machine:** `edge-dev` (Windows 11), **Git Bash** for the Bash tools and
  suite. Also verify on Ubuntu if convenient.
- **Repository:** `C:\repos\ai-devops`.
- **Commands:** `git`, `jq`, `bash`, `sha256sum`.
- **Health checks:** `AI_MUSE_CALLER=claude ai-muse doctor`, and `ai-review
  doctor` for the two gates.
- **Secrets — location only.** Muse's key is 1Password vault `vibe_coding`, item
  *"Meta ai Muse Spark API Key"*, field *api key*, resolved by the wrapper
  itself. Serialize 1Password access; load `secrets-to-1password` before any
  write; move values only through pipes or 0600 files.
- **Nothing to deploy.** Verification is: run the suite, and trigger one real
  rejection.

---

# Part 4 — Landing it

## 13. Definition of done, risks, open questions

### Definition of done

- [ ] Both rejection messages name the changed paths, capped per D3, paths only.
- [ ] Both rejection messages name `reconcile`, phrased as at `bin/ai-muse:331`.
- [ ] `tree_state`'s coverage and hash are byte-identical to before.
- [ ] Every test in Step 4 exists and passes; `bash tests/test-all.sh` ends
      `failures=0`; no existing test weakened.
- [ ] `docs/muse-opencode.md` updated, STATUS updated with artifacts, handoff
      closed, `session-docs-update` pass complete — **all before any review runs**
      (Step 5a).
- [ ] One real `ai-muse` rejection triggered in a disposable scratch repository
      and its improved message pasted into the closing report. **Mandatory.**
      It is a paid live provider call and **Albert authorizes it** — ask him
      before spending; if he declines, stop and report rather than landing
      (Step 5b).
- [ ] Both gate reviews and the `AGENTS.md:39-42` exact-state final review
      APPROVE, run **after** every tracked-file edit is complete (Step 5c).
- [ ] Nothing changed after the final review except publishing. If anything did,
      5c was re-run in full (Step 5d).
- [ ] Committed on `main`, pushed, confirmed on `origin/main`, with the
      final-check report path named in the commit message — **not** added to
      this plan by a later edit.

### Risks and rollback

| Risk | Severity | Mitigation | Rollback |
|---|---|---|---|
| Someone "fixes" the incident by narrowing `tree_state` | **High** — silently weakens the guard | § 4 out-of-scope list, R1, and D1 all say so explicitly; a coverage change would show as a `tree_state` diff in review | Revert |
| Inventory computation aborts the run under `set -e`, losing a report | Medium | D1 requires survivable failure; `guard_still_fires_without_an_inventory` tests it | Revert |
| Message edit breaks `tests/test-ai-muse.sh:25` | Low | Named in § 6 D and § 10 | Fix the string or update that test deliberately |
| A large untracked tree makes the message unreadable | Low | D3 cap plus its test | Revert |
| Path names leak something sensitive | Low | Paths only (D2), and they are repo-relative names the operator already has | Revert |
| A tracked file is edited after the exact-state review, silently voiding it | **High** — the change lands unreviewed while appearing reviewed | Step 5's 5a/5c/5d split; the final-check artifact is recorded in the commit message rather than by a post-review edit; 5d requires re-running 5c if anything changes | Re-run 5c before publishing |
| The live rejection proof is run inside the `ai-devops` checkout | Medium — its untracked file invalidates the review | Step 5b requires a disposable scratch repository and a clean working tree afterwards | Remove the stray file and re-run 5c |

### Open questions

1. **Exact inventory implementation** — D5 is open by design; pick the simplest
   approach meeting its three criteria.
2. **Do the other reviewer wrappers have the same gap?** `ai-grok-review`,
   `ai-kimi` and `ai-qwen` have comparable staleness guards. Out of scope here.
   If you notice while working, record it as a follow-up — do not widen this
   change.

---

## Self-audit (required by `implementation-plan-writer`; preserved here)

**1. Could a brand-new session execute this without asking anything?**

Yes. § 2 explains what `ai-muse` is and — importantly — what `tree_state`
covers and why that coverage is correct, since the whole risk of this task is an
implementer "fixing" the wrong thing. § 3 gives a copy-pasteable reproduction
and names the offline equivalent (`MUSE_STUB_TOUCH`). § 5 tables every line to
be touched. § 9 gives per-step target lines, intended behaviour, and a
verification gate, including a behaviour-neutrality gate on Step 1 so a mistake
surfaces before message text is edited.

**2. Does it carry every piece of background and reasoning, including what was
ruled out?**

Yes. § 7 records seven rejected approaches, led by the one an implementer is
most likely to reach for — narrowing `tree_state` so the rejection stops firing
— with the mechanism explaining why that would let a real change through. § 6
records that the correct recovery phrasing already exists at `bin/ai-muse:331`,
that the test harness already exists, and that `tests/test-ai-muse.sh:25`
constrains the message text. § 11 carries the `set -e` hazard and the
don't-write-scratch-into-the-repo trap, which is the same condition under test.

**3. Is the goal clear enough to steer by if a step is wrong?**

Yes. § 1 states it in one sentence, names what may not be traded for it, and
gives a specific tie-break naming the exact wrong turn: if you are about to make
`tree_state` ignore a category of file, stop. It also frames the success
criterion as "fires correctly and explains itself", not "fires less often".

All comprehensiveness-checklist items pass.
