---
issue: 630
status: OPEN
owner: claude/630-handoff (popcre/ai-devops#630)
---

# Reviewer start watcher — leftovers after the #401 Step 7 live proof

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put all of these to Albert in ONE message before starting work.

**A wrong guess is recoverable, but rework is wasteful**

1. **Should a second machine run the reviewer start watcher?** Today it runs only
   on the EDGE-DEV desktop, every 2 minutes, and only while that machine is on and
   logged in. If EDGE-DEV is off, no reviewer that stalls gets replaced. A second
   host would close that gap but adds another machine to keep healthy.
   *Recommendation:* leave it on EDGE-DEV alone for now and revisit if a stalled
   reviewer is ever missed in practice; the failure mode is a slow review, not a
   wrong merge. Blocks item 2 of popcre/ai-devops#630.

**Not part of this work and nobody is on it**

2. **Nothing else.** The independent review of popcre/ai-devops#599 (item 1 of
   #630) needs no owner decision — it needs an available reviewer, not a ruling.

**Already settled — do NOT re-ask**

- 2026-09-18: Albert approved adding the EDGE-DEV scheduled task that runs the
  watcher every 2 minutes (AskUserQuestion, "Yes, add it").
- 2026-09-18: "within 10 minutes of its draw" is accepted as "at the first watcher
  pass after the 10-minute start SLO". A lease cannot be called a non-start before
  its SLO ends, so the true bound is SLO + one pass interval.

## 1. What this application is

Two repositories are involved, both on GitHub under the `popcre` organization
(the older `u2giants/shared-db` links still resolve to the same repository).

- **`popcre/shared-db`** — the governed repository for the shared Supabase
  database used by POP Creations' internal apps. All database STRUCTURE changes
  are authored here through a branch, a pull request, a governed AI review at an
  exact commit, and a guarded merge workflow. It also holds the orchestrator-flow
  scripts that assign AI reviewers to pull requests and police them.
- **`popcre/ai-devops`** — the tooling repository: launcher scripts in `bin/`,
  machine facts, programme plans, and the scheduled tasks that run on Albert's
  machines. Issue #401 there is the programme plan
  `plan_shared-db-complete-throughput-repair.md`, a 10-step repair of the
  shared-db delivery pipeline. Step 7 of that plan is "Bound reviewer and runner
  waits with truthful fallback".

The relevant machine is **EDGE-DEV**, Albert's Windows 11 desktop. Nothing here
runs in a cloud environment: the reviewer wrappers (`ai-grok-review`, `ai-glm`,
`ai-gemini`, `ai-muse`) and `ai-review-preflight` are installed locally, which is
exactly why a GitHub-hosted runner cannot do the full job.

## 2. What we set out to do this session, and why

Business goal: when an AI reviewer is assigned to a shared-db pull request and
then never starts work, the pull request must not sit dead. Something must notice
within about ten minutes and hand the review to a different reviewer, without a
person watching.

Technical objective (shared-db issue #3242, now CLOSED): prove in production that

1. `scripts/orchestrator-flow/reviewer-start-watch.mjs` runs with no person
   invoking it;
2. one live unstarted reviewer is rerouted within 10 minutes of its draw while the
   other review slot is left intact;
3. the evidence is linked on #3242 and on row 7 of the popcre/ai-devops#401 STATUS
   table.

Trigger: row 7 previously read "NOT ACCEPTED: no scheduled watcher enforces the
ten-minute reviewer start SLO" — the watcher existed but had only ever been run
by hand, 62 minutes late.

## 3. Current state — what is true right now

**Done and verified (2026-09-18):**

- The EDGE-DEV scheduled task `\ai-devops\reviewer-start-watch` runs
  `C:/repos/ai-devops/bin/ai-reviewer-start-watch tick` every 2 minutes (added
  under popcre/ai-devops#599, MERGED). Its log is
  `~/.ai-devops/reviewer-start-watch/tick.log`, one `=== <UTC time> main <sha>`
  header per pass followed by that pass's JSON.
- Two shared-db fixes landed: **#3272** (the watcher exits non-zero when a pass
  fails) and **#3284** (a lease's own mooted reroute no longer counts against that
  slot's budget of 2; merged as `c9d50300`).
- The live proof was recorded in
  `tests/verification/shared-db-throughput/2026-09-18-step-7-unattended-reroute.md`
  and merged into shared-db `main` in **PR #3286**, merge commit **`b406395a`**.
  Independent governed review: glm-5.3, APPROVE at head
  `3d15751efe0da996f4a7042a10a6427f7f5fc264`, durable artifact
  `refs/db-review-verdict-replacements/3242-3286-3d15751e…-3331`.
- Programme row 7 now reads ✅ live-proven: popcre/ai-devops **#627**, merge
  `b067016d`.
- shared-db **#3242 is CLOSED**; the superseded proof pull request **#3269 was
  closed unmerged**.
- Evidence comments posted on shared-db#3242 and ai-devops#401.

**Not done — the whole reason this file exists (popcre/ai-devops#630, OPEN):**

1. popcre/ai-devops#599 was merged WITHOUT an independent governed review, because
   Codex was at its usage limit that evening. No reviewer has read it.
2. The watcher runs on one machine only. If EDGE-DEV is off, the 10-minute SLO is
   not enforced anywhere.

Nothing is half-edited. Every working tree this session used is clean or removed;
no branch of this session is left unmerged except `claude/630-handoff`, which
carries this file.

## 4. Everything we tried that did NOT work

- **Running the watcher as a GitHub Actions workflow only.**
  `.github/workflows/reviewer-start-watch.yml` exists in shared-db and a relay leg
  was live during the proof (run 35407… era, run `35394703227`). A hosted runner
  can reserve a reroute but CANNOT draw the replacement: `ai-review-preflight` and
  the reviewer wrappers are installed on EDGE-DEV, not on the runner. That is why
  the accepted unattended runner is the local scheduled task.
- **First proof attempt on PR #3269.** Two reroutes were genuinely completed
  unattended (seq 3272 acknowledged 19:38:44Z; seq 3299 reserved at the first pass
  after its SLO at 19:51:54Z), but the timeline was polluted: a stale author mutex
  blocked progress from about 19:45Z to 20:43Z, and the reroute budget bug counted
  a lease's own retry, so slot 2 exhausted its budget of 2. #3269 was abandoned and
  closed; a clean staged proof was run on #3286 instead. Its history is still cited
  in the record as supporting evidence.
- **First guarded merge of #3284 was refused** because `main` had moved to a
  non-documentation commit. The fix is: keep a backup branch, rebase onto current
  `main`, bump the contract generation, re-publish the contract and evidence pair,
  force-with-lease, re-draw a reviewer at the new head, review again, then merge.
- **Governed review refused with "source identity requires an exact head and
  worktree"** when `--reviewer/--wrapper/--worktree/--review-slot` were omitted.
  All four are required.
- **The gemini-3.8-flash-high review of #3286's earlier head produced no verdict**
  after ~63 minutes ("the wrapper reported retained or active work"), and
  **grok-4.6 hit `turn_limit_cancelled` on the final head**. Neither is a watcher
  fault. The sanctioned recovery is a same-head replacement, below.
- **`git push --force-with-lease=<short ref>:<sha>` silently did nothing**
  ("Everything up-to-date") until full ref names were used on both sides.

## 5. Root causes and key findings

- **The reroute budget bug (shared-db #3283, fixed by #3284).**
  `priorReroutesForSlot` in `scripts/orchestrator-flow/reviewer-start-watch.mjs`
  counted reroute refs for a slot regardless of sequence, so a lease's own mooted
  retry consumed one of its two allowed reroutes. It now excludes the lease's own
  sequence. Two tests were added with the fix.
- **Watcher ref shapes** (all in `popcre/shared-db`):
  `refs/db-start-reroutes/reviewer/review-<issue>-<pr>-seq<S>-slot<N>` for the
  reservation, plus `--dispatch-claim`, `--dispatch-ack`, `--failed-N` and
  `--moot` subrefs. The commit date of each ref is the usable timestamp.
- **A reviewer that ends without a verdict is recoverable in place.** Use:
  `node scripts/manage-migration-author-lanes.mjs --replace-failed-reviewer --issue I --pr P --head-sha H --review-slot N --failed-sequence S --failure-code turn_limit_cancelled --confirm-no-verdict --confirm-no-artifact`
  then run the governed review with `--replacement-sequence <the FAILED sequence>`
  (not the new one). Valid failure codes are in `TERMINAL_FAILURE_CODES`,
  `scripts/manage-migration-author-lanes.mjs:694`.
- **The completion report must list every changed file**, including
  `.agent/contract.json` and `.agent/completion.json` themselves, or
  `agent-work-contract-git-evidence.mjs` refuses.
- **The proof's honest bound is SLO + one pass.** On #3286 the draw was 22:37:41Z,
  the SLO ended 22:47:41Z, the reservation was written 22:48:34Z (53 s later) and
  the replacement was acknowledged 22:49:55Z. The pass before the SLO end recorded
  `"action": "wait"` — which is the evidence that the watcher does not act early.

## 6. Exact next steps

1. **Get an independent governed review of popcre/ai-devops#599.** Read the merged
   change and `bin/ai-reviewer-start-watch`, and have one reviewer (Codex, or a
   governed AI reviewer) confirm the launcher and the scheduled-task registration
   are correct and safe. Post the verdict as a comment on popcre/ai-devops#630.
   *You will know it worked when* #630 carries a named reviewer's verdict with a
   date, and item 1 of that issue is ticked.
2. **Put owner decision A (section 0) to Albert in one message.**
   *You will know it worked when* he answers yes or no to a second watcher host.
3. **If he says yes:** add the same scheduled task on the second machine through
   the ai-devops installer (do not hand-create a task), and prove it with one pass
   in that machine's `~/.ai-devops/reviewer-start-watch/tick.log`.
   *You will know it worked when* two machines' logs show passes for the same
   minute and no duplicate reroute refs are created for one lease.
4. **Close popcre/ai-devops#630** and delete this handoff file when both items are
   done.

## 7. Constraints and gotchas in force

- shared-db `main` is protected: branch, pull request, governed review at an exact
  head, then `gh workflow run guarded-migration-merge.yml -R popcre/shared-db -f pull_request=N -f head_sha=H`.
  The guarded merge is refused if `main` moved with non-documentation changes.
- A documentation-only pull request may be merged immediately with
  `gh pr merge --squash --admin`; check the changed-file list first.
- Review briefs must contain no decision word (APPROVE / REVISE / REJECT, or
  "approved") except in the final output-rule line, or the review is void.
- Governed reviews take 10–60 minutes; run them in the background, never poll in a
  tight loop.
- Many sessions share this checkout. Never use bare `git stash`, never stage files
  you did not create, and check for an open pull request before editing a shared
  document.
- Sign every GitHub post with a line naming the chat that wrote it.
- An orchestrator marker issue (shared-db#3275) was open and owned by a DIFFERENT
  session during this work. Do not touch another session's marker.

## 8. Access and environment

- `gh` CLI is authenticated for both repositories on EDGE-DEV.
- Reviewer wrappers and `ai-review-preflight` are installed on EDGE-DEV only.
  Reviews need `REVIEWER_DOCTOR_TIMEOUT_MS=240000` and the caller variable for the
  provider, e.g. `$env:AI_GLM_CALLER='claude'`, and must run from PowerShell.
- Secrets live in the 1Password vault `vibe_coding`. No credential value appeared
  in this session and none was stored.
- Repositories on disk: `C:/repos/shared-db` and `C:/repos/ai-devops`. Do not edit
  either shared checkout directly; create a worktree from current `origin/main`.

## 9. Open questions and risks

- **Single point of failure (2026-09-18).** The SLO is enforced only while EDGE-DEV
  is on. Risk: a stalled reviewer sits indefinitely overnight. Mitigation pending
  owner decision A.
- **#599 unreviewed (2026-09-18).** Risk is low (a scheduled task that runs an
  existing, tested script) but it is a standing exception to the
  independent-review rule and should be closed out.
- **Reviewer wrappers fail often.** Two of three governed reviews in this session
  ended without a verdict. The `--replace-failed-reviewer` route handles it, but if
  the failure rate stays this high it deserves its own investigation; nobody owns
  that today.
- **Decision recorded 2026-09-18:** the staged proof (deliberately never starting
  one drawn reviewer) is accepted as a live proof, because the lease it creates is
  a real governed lease and the watcher cannot tell it apart from a genuine
  non-start.

## Self-audit

1. *Could a brand-new developer continue?* Yes — §1 defines both repositories, the
   machine and the vocabulary; §3 states exactly what landed and what did not; §6
   gives numbered steps with verification gates.
2. *As effectively as this session could?* Yes — §4 records all five dead ends,
   including the two reviewer runtime failures and the force-with-lease trap, and
   §5 records the ref shapes, the replacement command and the budget bug.
3. *Is every relevant detail present?* Yes — background §1–§2, state §3, failures
   §4, findings §5, next steps §6, constraints §7, access §8, risks §9, with
   commit SHAs `c9d50300`, `b406395a`, `b067016d` and the exact review head named.
4. *Would the owner see every decision from §0 alone?* Yes. Walking §1–§9: the
   second-host question (§3, §6 step 3, §9) is §0 item A; the #599 review (§3, §6
   step 1) needs a reviewer, not a ruling, and is stated as such in §0; the two
   settled rulings (the scheduled task, the SLO reading) are in the "already
   settled" list. No other sentence in this file asks for his judgement.
