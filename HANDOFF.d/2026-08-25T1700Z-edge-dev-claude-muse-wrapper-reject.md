---
issue: none    # related open issues are #182 and #183; this workstream has none of its own
status: OPEN
owner: edge-dev Claude Opus 5 session, 2026-08-25 (no dedicated branch; nothing implemented)
---

# HANDOFF — `ai-muse` stale-turn rejection is undiagnosable and steers toward data loss

- **Status:** OPEN — nothing implemented
- **Written:** 2026-08-25 (UTC) on `edge-dev` by Claude (Opus 5)
- **Repository:** `u2giants/ai-devops`, branch `main`
- **Base commit:** `5b562d19b0e0e9e3c81d5fc23f0e6dbcb43c1e6f`
- **The plan:** [`fix_muse_wrapper_reject.md`](../fix_muse_wrapper_reject.md)
- **Sibling workstream:** [`2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md`](2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md)
  — independent; neither blocks the other.

## 1. What this workstream is

`bin/ai-muse` rejects a completed review when the source repository changes
during the turn. **That guard is correct and is not what needs fixing.** What
needs fixing is how it fails:

1. **It names nothing.** The message says the repository changed but not which
   path changed, so the cause has to be deduced.
2. **It does not mention `reconcile`** — the only command that returns the
   session to `active`. It lists "show, ask, transcript, or delete", steering a
   reader toward discarding a completed, already-paid-for review.

`bin/ai-muse:331` already phrases this correctly for a different failure
("Inspect: … transcript … ; then run: … reconcile …"). Two of the wrapper's
three messages simply do not use that phrasing.

## 2. How it was found

On 2026-08-25 a Muse review turn in this repository was rejected because the
calling session had run `ai-muse new … 2>muse1.err` from the repository root,
creating an untracked file mid-turn. Muse's review had completed and was intact
in the transcript. Recovery was only possible because the operator knew
`reconcile` existed from the `ask-muse` skill; the error message would have led
to `delete` and a second paid review.

## 3. State right now

Nothing implemented. No source file changed. A fresh session starts at **Step 1**
of the plan.

## 4. What must not be relitigated

- **Do not narrow what `tree_state` covers** (`bin/ai-muse:149-152`) to stop the
  rejection firing. The untracked-but-not-ignored set it hashes is exactly what
  `ai-review-sandbox` copies into the review snapshot, so those files are part
  of what the reviewer sees. Excluding them would let a real change slip past the
  guard. This is the tempting fix and it is wrong — see the plan, § 7 R1.
- **Do not downgrade the rejection to a warning, and do not auto-reconcile.**
  Reconciliation is a deliberate human acceptance of a recorded provider state.
- The status write at `bin/ai-muse:323`/`:338` happens **before** the tree
  comparison on purpose, so a provider session survives a local failure. Do not
  reorder it.

## 5. Next action

Read [`fix_muse_wrapper_reject.md`](../fix_muse_wrapper_reject.md) STATUS first,
then Step 1 — capture a before/after path inventory alongside the existing hash,
without changing the hash or its coverage. Step 1 is required to be
behaviour-neutral, and the existing suite passing unchanged is its gate.

## 6. Risks if picked up carelessly

The change is small, but it sits in a reviewer wrapper on the safety path, so
`AGENTS.md:39-42` requires an independent read-only exact-head review before
merge — beyond the two gate reviews. `bin/ai-muse:3` is `set -euo pipefail`, so
a failing command substitution in the new inventory code would abort *after* the
provider answered, losing the report; the plan requires the inventory step to be
survivable and tests it.

## 7. The landing step was corrected after an independent review

An independent Codex final-check (run `20260825T182726-448910-20250`, against
`a42e415`) rejected this plan's original Step 5 on two counts. Both were fixed
in `c87fe624df4e65140f07c5dd685cce4aaa1d5285`. Read Step 5 in full before
landing anything — its ordering is not optional:

- **The exact-state review must run after every tracked-file edit.** The first
  draft ran it before the final docs, STATUS and handoff updates, which change
  the whole-source digest and silently void the review. Step 5 is now 5a (finish
  every edit, including the `session-docs-update` pass) → 5b (live proof) → 5c
  (suite, both gates, final-check on the publishable state) → 5d (publish only;
  re-run 5c if anything changes at all).
- **The final-check report path goes in the commit message, not into this plan
  by a later edit.** That circularity — a STATUS cell that cannot exist until
  after the review — is what created the contradiction.
- **The live Muse rejection proof is mandatory, not optional**, and it is a paid
  provider call that **Albert authorizes**. Ask before spending; if he declines,
  stop and report rather than substituting the offline stub tests.
- **Run the live reproduction in a disposable scratch repository**, never in the
  `ai-devops` checkout — it works by creating an untracked file mid-turn, which
  inside this checkout would itself invalidate the review about to run.

A re-run of the same gate on the corrected plan (run
`20260825T190544-629546-5295`, against `d97cf0a`) raised no finding against this
file. That run returned REJECT for unrelated reasons in another workstream's
files, since `final-check` binds the whole repository state rather than a diff.
