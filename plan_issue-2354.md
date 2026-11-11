---
summary: Plan for issue 2354 finishing retirement of Entire trial routing surfaces left after PR 2353; all steps open.
kind: plan
status: open
read-when: Removing leftover Entire trial references (issue 2354)
---

# Implementation plan — popcre/ai-devops#2354 (finish retiring the Entire trial from every live routing surface)

## Verdict (read first)

**Still real (checked 2026-11-04 9:42 PM EST).** PR #2353 ("docs: end the Entire
trial (#2022), GitHub only", head `35e21927`, branch
`claude/transcript-query-entire-investigation-2925d4`) is OPEN and mergeable. It
ends the trial in the four client globals, `AGENTS.md` and `docs/entire-trial.md`.
The advisory GLM review (issue #2354) found four live routing surfaces that
still tell a fresh session to consult or resume the trial, plus one stale test
label. All five are still present on `main` and on the #2353 branch. No fixer
PR exists for #2354 yet. One small PR (or one more commit on #2353's branch)
closes it.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 `docs/pending-work.md` programme pointer marked ended | ⬜ open (2026-11-04) | — |
| 2 `docs/task-router.md` Entire row marked ended | ⬜ open | — |
| 3 `plan_selective-fresh-reader.md` §12 Entire paragraph replaced | ⬜ open | — |
| 4 `plan_entire-reversible-trial.md` ended banner at the top | ⬜ open | — |
| 5 `tests/test-ai-adopt-globals.sh:246` step label corrected | ⬜ open | — |
| 6 Verify, PR, merge, close #2354 | ⬜ open | — |

A fresh session starts at Step 1. Handoff registration:
[HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

---

## 1. Ultimate goal

On November 4, 2026 Albert decided the Entire trial is over and not adopted:
AI sessions use GitHub only for source, checks and delivery, and must not
install, enable or consult Entire for any task. PR #2353 wrote that rule into
the files every session loads. But this repository's product is its
instructions, and several documents that `AGENTS.md` routes sessions to still
say "read the Entire trial plan STATUS first" or "follow the Entire session
workflow". A fresh session that follows the router can land on text that tells
it to do exactly what the owner ended. The goal: **no live routing surface in
this repository points a session at Entire as current work.** Historical
records stay, clearly marked as ended.
**If a step conflicts with this goal, the goal wins — stop and flag it on #2354.**

## 2. What this application is

`popcre/ai-devops` is Albert's (POP Creations) public AI toolkit: the global
instruction templates installed on every machine, skills, reviewer wrappers,
gates, hooks and CI workflows. Work lands on protected `main` through a PR and
the merge queue; the AI merges. Routing documents in scope:

- `AGENTS.md` — the router every session in this repo reads first.
- `docs/pending-work.md` — index of active plan pointers (routed from `AGENTS.md`
  "Active plans and pending work").
- `docs/task-router.md` — specialized task rows (routed from `AGENTS.md` for
  provider/CI/incident questions).
- `plan_selective-fresh-reader.md` — opt-in pilot offered by `AGENTS.md`.
- `plan_entire-reversible-trial.md` — the trial's own plan, now a historical record.
- `docs/entire-trial.md` — the operating record, already banner-marked by #2353.

## 3. Trigger

Issue #2354 is the automatic `review-finding` from the advisory GLM review of
PR #2353 (ai-review run 41916216888). Findings, verified on `main` at
`8e3b916a` on 2026-11-04:

1. `docs/pending-work.md` "Programme pointers": "Reversible Entire trial
   alongside GitHub: read the trial plan STATUS first (#2022); planning only,
   execution not started." Still lists the trial as active work.
2. `docs/task-router.md:10`: the row "Entire alongside GitHub: reversible trial,
   continuous memory, Trails, sessions, search or CI → read the Entire trial plan
   STATUS, #2022" with trial-era boundaries ("GitHub stays authoritative; …
   prove departure").
3. `plan_selective-fresh-reader.md:445-448`: "Entire is an optional public
   companion during its existing bounded trial only. Follow `docs/entire-trial.md`
   Session workflow after checking New York time…"
4. `plan_entire-reversible-trial.md:3-44`: the controlling "October 31
   amendment" still authorizes Entire to control testing and merging and says
   "#2022 remains open with live proof unchecked". No ended marker.
5. `tests/test-ai-adopt-globals.sh:246`: step label
   `12/13 entire-adoption-preserves-machine-section/entire-capture-off-preserved`
   still names a "capture off preserved" assertion that #2353 deleted.

To reproduce: `grep -n "Entire" docs/pending-work.md docs/task-router.md plan_selective-fresh-reader.md | head` and `sed -n 1,50p plan_entire-reversible-trial.md`.

## 4. Scope

In scope: the five findings above, as wording changes, plus a grep sweep for any
other live instruction to consult Entire.
**NOT in this plan:** reverting or re-litigating the owner's decision; deleting
`plan_entire-reversible-trial.md`, `docs/entire-trial.md` or
`tests/verification/entire-trial/` (historical evidence stays); uninstalling
Entire from any machine (nothing was installed on protected checkouts beyond the
trial's own bounded runners, and #2022's disposition covers it); changing
`templates/system/*` globals (done in #2353); touching the Buildkite pipelines
named in the trial record; the memory note `memory/` files.

## 5. Current state of the code

- `main` at `8e3b916a` (2026-11-04): all five findings present, untouched.
- PR #2353 branch `claude/transcript-query-entire-investigation-2925d4` at
  `35e21927`: edits `AGENTS.md`, `docs/entire-trial.md`, the four
  `templates/system/*-global*.md`, `tests/test-ai-adopt-globals.sh`,
  `tests/test-client-globals-required-phrases.sh`. Both tests pass on edge-dev3
  per the PR body. It does NOT touch the five files in §3.
- PR #2349 branch `claude/open-issue-plans` (this plan's branch) edits
  `docs/pending-work.md` (adds an "Issue implementation plans" section above the
  "Programme pointers" heading). Step 1 below edits the same file, so land this
  plan's PR after #2349 or rebase onto it.

## 6. Key findings

- `AGENTS.md:178-199` (main) is the Entire paragraph #2353 rewrites; after
  #2353 it says "GitHub only; do not consult or install Entire" and calls
  `plan_entire-reversible-trial.md` a historical record. So Step 4's banner must
  match that wording, not contradict it.
- `docs/pending-work.md` footer rule: "mark them `done` or remove them as soon
  as they stale." So the pointer can be marked done rather than deleted — keeping
  a pointer to the record is useful; keeping an instruction to read its STATUS
  "first" is not.
- `tests/test-ai-adopt-globals.sh` case 12 copies the real repo templates into
  a fixture and asserts the ended notice; only the echo label is stale.
- Client globals installed on machines (`~/.claude/CLAUDE.md` etc.) are
  regenerated by `bin/ai-adopt-globals` from the templates; this plan changes no
  template, so no reinstall is needed for these steps. (#2353 itself needs a
  reinstall on each machine; that belongs to #2353's closeout, not here.)

## 7. Rejected approaches

- Deleting the trial plan and operating record: rejected. They are the audit
  trail for a decision Albert made; the owner ruling says GitHub keeps
  continuity. Mark ended, do not erase.
- Adding a lint that fails CI on the word "Entire": rejected. Lean-checks
  ruling (2026-10-30): only data-safety and secret checks may block; and the
  word legitimately appears in historical files.
- Waiting for the automatic fixer: rejected. #2354 has no fixer label yet, the
  fixer is disabled for workflow-adjacent paths anyway, and the change is five
  small edits.

## 8. Decisions

Locked:
- Entire is ended and not adopted (owner, 2026-11-04). GitHub only.
- Historical files stay; they get an ended banner, not deletion.
- No new checks or tooling.

Open (implementer judgment):
- Whether to land these edits as a second commit on PR #2353's branch or as a
  separate PR. Criterion: if #2353 is still OPEN when you start, push to its
  branch so one merge closes #2022's loose ends and #2354 together; if #2353 has
  merged, open a new PR `docs/entire-retire-routing` against `main`.

## 9. Steps

**Step 1 — `docs/pending-work.md` programme pointer.** Replace the three-line
"Reversible Entire trial alongside GitHub…" paragraph with:
"Entire trial (#2022): **ended, not adopted** (owner decision 2026-11-04).
GitHub only. Record: [trial plan](../plan_entire-reversible-trial.md) and
[operating record](entire-trial.md), both historical." Keep the links so
reachability is preserved. Gate: `grep -n "planning only, execution not started" docs/pending-work.md` prints nothing; `bin/ai-doc-reachability --base origin/main` passes.

**Step 2 — `docs/task-router.md:10`.** Change the row's first cell to "Entire
(ended 2026-11-04, not adopted): any request to use, install or consult it", the
pointer cell to the two historical links, and the boundary cell to "Decline: use
GitHub only for source, checks and delivery; the plan and record are history".
Gate: `grep -n "prove departure" docs/task-router.md` prints nothing.

**Step 3 — `plan_selective-fresh-reader.md:445-448`.** Replace the paragraph
with: "Entire is ended and not adopted (2026-11-04). Do not consult
`docs/entire-trial.md` or any Entire workflow; GitHub is the only delivery
path." Gate: `grep -n "bounded trial" plan_selective-fresh-reader.md` prints nothing.

**Step 4 — `plan_entire-reversible-trial.md` banner.** Insert, directly under
the H1 title, a block:
"> **ENDED 2026-11-04 — not adopted.** Owner decision; see #2022 and #2353.
> Everything below is a historical record. No step here is authorized; do not
> read STATUS as pending work. Use GitHub only."
Do not edit the body. Gate: `sed -n 1,8p plan_entire-reversible-trial.md` shows the banner; the file still links from `docs/pending-work.md` and `docs/task-router.md`.

**Step 5 — `tests/test-ai-adopt-globals.sh:246`.** Rename the echo label to
`12/13 entire-adoption-preserves-machine-section/entire-ended-notice-present`
(match whatever the case actually asserts after #2353; read the lines that
follow it). Gate: `bash tests/test-ai-adopt-globals.sh` passes (Git Bash on
Windows, bash on Linux).

**Step 6 — Sweep, verify, land.** `grep -rn "Entire" --include=*.md . | grep -v "^./archive\|^./HANDOFF.d\|^./tests/verification\|^./docs/entire-trial.md\|^./plan_entire-reversible-trial.md"` and read every remaining hit; any that
instructs a session to use Entire as current practice gets the same treatment.
Run `bin/ai-doc-safety` (the CI doc-safety job locally) and the two tests from
#2353. Commit under Albert's verified identity, push, open or update the PR,
run `bin/ai-pr-wait <pr>` in the background, merge, close #2354 with a signed
comment naming the merge SHA.

## 10. Tests required

- Existing: `tests/test-ai-adopt-globals.sh`,
  `tests/test-client-globals-required-phrases.sh`,
  `tests/test-workflow-policy.sh` (unchanged, must stay green),
  `bin/ai-doc-reachability --base origin/main`.
- New: none. These are prose edits; a new test asserting absence of a word
  would be a new advisory check with no data-safety value.

## 11. Constraints and gotchas

- Protected `main`: branch + PR, AI merges, `bin/ai-pr-wait` in the background,
  never a sleep loop.
- Sign GitHub comments with `$AI_GH_SIGNATURE`.
- `docs/pending-work.md` is also edited by PR #2349 (this plan's own branch).
  Rebase or land in order to avoid a trivial conflict.
- Windows: edit with LF endings (`.gitattributes` enforces; a CRLF plan file
  breaks nothing, but shell tests do).
- Do not rotate or touch any Buildkite tokens mentioned in the record; they were
  revoked during the trial.

## 12. Access and environment

- `gh` authenticated as `u2giants` (push) with issues on `popcre/ai-devops`.
- No secrets, no 1Password items, no servers. Pure documentation PR.
- Run tests with Git Bash on Windows or bash on edge-dev3.

## 13. Definition of done, risks, open questions

Done when: the five edits are merged to `main`; `bin/ai-doc-reachability` and
the two tests pass in CI on the merged head; #2354 closed with the merge SHA;
PR #2353 merged (if it was not already) so the globals and this fix are both on
`main`. Risk: none to production; rollback is `git revert` of the docs commit.
Open question: none that blocks; the only judgment call is the PR vehicle (§8).

## Self-audit

1. Fresh session can execute without questions: yes — §3 gives line numbers and
   exact current text, §9 gives replacement wording and gates.
2. Carries all background: yes — §5 explains the overlap with #2349 and #2353,
   §7 the rejected deletion/lint routes.
3. Goal clear enough for judgment: yes — §1 "no live routing surface points at
   Entire as current work; history stays marked".
