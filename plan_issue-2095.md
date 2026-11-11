---
summary: Plan for issue 2095 ai-pr-wait advisory-failure follow-ups - header contract and tests still real and unstarted.
kind: plan
status: open
read-when: Fixing ai-pr-wait advisory-failure follow-ups (issue 2095)
---

# Implementation plan — popcre/ai-devops#2095 (ai-pr-wait advisory-failure follow-ups)

## Verdict (checked 2026-11-04 against main `f2b4f5bd`)

**Still real, small, worth doing under skinny.** PR #2094 merged 2026-10-30 01:40 UTC; none of the four review findings were landed (the automatic fixer's attempt, per the only issue comment, stayed uncommitted in its sandbox and never became a PR). Evidence on main:

- Finding 1: `bin/ai-pr-wait:12-13` still says it exits on "a failed check"; `:34` still says exit 1 = "check failure". Both are false for non-required head failures since #2094.
- Finding 2: advisory block (`bin/ai-pr-wait:561-567`) runs before the terminal `FAILED` block (`:569+`), so a mixed poll prints "advisory; still waiting" and then exits 1.
- Finding 3: `LAST_ADVISORY` (init `:310`, set `:566`) is never reset.
- Finding 4: `tests/test-ai-pr-wait.sh:641-690` has no legacy `state`-only fixture, no mixed payload, no head-change re-report case.

Skinny fit: this is the existing waiter (owner ruling 2026-10-21, `docs/owner-rulings.md:66`: "no new wait tooling") made honest; it adds no tool, no gate, no check. It directly supports the 2026-10-30 "lean required checks" ruling, because advisory checks failing must not end waits.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Header contract | ⬜ open | — |
| 2 Suppress advisory print when terminal | ⬜ open | — |
| 3 Reset advisory dedupe | ⬜ open | — |
| 4 Tests | ⬜ open | — |
| 5 Land + close #2095 | ⬜ open | — |

Fresh session starts at Step 1.

## 1. Ultimate goal
AI sessions use `ai-pr-wait` to wait for a pull request to merge. Since the owner made most checks advisory (2026-10-30), an optional check failing must be reported but must not end the wait — and the tool's own words must say that truthfully. Done means: the documented exit contract matches behaviour, the output never says "still waiting" on the poll where it quits, and a new commit's advisory failure is reported again. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is
`popcre/ai-devops` (public) is Albert's AI toolkit: scripts, skills and CI used by all AI sessions. `bin/ai-pr-wait` is a bash script polling GitHub GraphQL (via `tools/github-requests/pr-status-complete.sh`) until a PR merges/closes/ejects/fails/times out. Runs locally on every dev machine; no deployment.

## 3. Trigger
Advisory AI review (deepseek) of PR #2094 at head `31fa12d8`, filed as `review-finding` issue #2095. Reproduce finding 2: a payload with one `isRequired:false` FAILURE and one `isRequired:true` FAILURE on head → output contains both "advisory; still waiting" and "will not merge", RC 1.

## 4. Scope
In: `bin/ai-pr-wait` header comment and advisory block; `tests/test-ai-pr-wait.sh`.
NOT in: changing the FAILED/ADVISORY jq classifiers (verified correct and complementary); telemetry; `pr-status-complete.sh`; cheat-sheet docs (review said they don't describe exit codes in detail); any new waiter, flag, or check; the pre-existing `unknown` event-kind limitation for legacy contexts.

## 5. Current state
Classifiers at `bin/ai-pr-wait:514-515` (correct). Advisory print `:561-567`. Terminal block `:569` onward. Tests for advisory path `tests/test-ai-pr-wait.sh:641-690` using a stub `gh` that returns OPEN once, then MERGED. Nothing uncommitted relevant on main.

## 6. Key findings
The classifier is right; only reporting and documentation are wrong. The stub `gh` emits a single context node; mixed and legacy cases need a fixture override.

## 7. Rejected approaches
- Including head oid in the dedupe key instead of resetting: works, but resetting on empty advisory AND on head change is simpler to read; either is acceptable (open, see 8).
- Moving the advisory block after the terminal block: the terminal block exits, so this equals "skip when FAILED non-empty" but is a larger diff. Use the guard.
- Re-applying the fixer's uncommitted sandbox changes: not retrievable; redo from this plan.

## 8. Decisions
Locked: non-required head failures never end the wait (#2094, owner ruling 2026-10-30). No new tooling. Exit codes 0/1/2/3 unchanged in meaning.
Open: dedupe reset mechanism (reset `LAST_ADVISORY=''` when `$ADVISORY` empty and when `LAST_HEAD` differs from a stored `ADVISORY_HEAD`, or key on `LAST_HEAD`). Criterion: smallest diff that makes Step 4c pass.

## 9. Steps
Work in a fresh worktree off `origin/main` (standing rule: canonical checkouts landing-only).

1. **Header** — edit `bin/ai-pr-wait:12-15` to: exits on merged, closed, a failed *required* check (or one whose requirement is unknown or from a non-head commit), ejection, or deadline; non-required head failures are printed as advisory and the wait continues. Edit `:34` exit 1 to "closed, required-check failure, ejected". Gate: `sed -n 10,40p bin/ai-pr-wait` reads correctly; `bash -n bin/ai-pr-wait` passes.
2. **No contradictory print** — change `:561` condition to `if [ -z "$FAILED" ] && [ -n "$ADVISORY" ] && [ "$ADVISORY" != "$LAST_ADVISORY" ]`. Optionally, in the terminal listing the advisory names may still appear with `required=false` (only if already listed there; do not add). Gate: Test 4b.
3. **Re-report on change** — after the advisory block: if `$ADVISORY` is empty, `LAST_ADVISORY=''`; also clear it when the head changes (track `ADVISORY_HEAD="$LAST_HEAD"` when printing; if `LAST_HEAD != ADVISORY_HEAD` reset before compare). Gate: Test 4c.
4. **Tests** in `tests/test-ai-pr-wait.sh` after line 690, reusing the stub pattern (add env overrides to the stub, e.g. `CANCEL_NODES` JSON replacing the nodes array, and `CANCEL_HEADS` sequence for multi-poll):
   - a. "legacy status context with state FAILURE and isRequired false is advisory" — node `{context:"legacy",state:"FAILURE",isRequired:false}` no conclusion → RC 0, output has "advisory; still waiting". Plus `state:"ERROR"` with `isRequired:true` → RC 1.
   - b. "mixed required and advisory failure exits without 'still waiting'" — two nodes → RC 1, output contains "will not merge", does NOT contain "still waiting".
   - c. "advisory failure on a new head is reported again" — poll1 head h1 advisory fail, poll2 head h2 same check fail, poll3 MERGED → "advisory; still waiting" appears twice, RC 0.
   Gate: `bash tests/test-ai-pr-wait.sh` all pass, new names present.
5. **Land** — commit as Albert (`git var GIT_COMMITTER_IDENT`), message referencing `Fixes #2095`, PR to main, merge yourself; run `bin/ai-pr-wait <pr>` in background. Gate: PR merged, #2095 auto-closed; confirm with `gh issue view 2095 --json state`.

Dependencies: 1–3 independent; 4 after 2–3; 5 last. Single phase, no context cut.

## 10. Tests required
New: the three named checks in Step 4. Existing must stay green: whole `tests/test-ai-pr-wait.sh` (including "non-required $outcome is reported but the queued PR waits until merged", "required $outcome stays terminal", unbound-commit check), and the repo's normal CI for the PR. No adversarial table needed: input is GitHub's own API, behaviour change is output-only.

## 11. Constraints and gotchas
- Reviews are advisory; do not wait on or gate on the review of this PR. Only data/secret checks may block.
- Never push to protected `main`; branch + PR; Albert does not merge — the implementer does.
- Sign any GitHub post with `$AI_GH_SIGNATURE`.
- Known sandbox flake: the fixer saw 9 failures from directory-ownership cache sharing (`AI_GH_STATE_DIR`); run tests in a normal user-owned worktree, give each new test its own `AI_GH_STATE_DIR` under `$TMP` like existing ones.
- Stub `date`/`sleep` are already overridden on `PATH` in that test section; keep new cases inside it.
- Edge-dev3 sets `PYTHONDONTWRITEBYTECODE`; irrelevant here (bash only).

## 12. Access and environment
`gh` authenticated as the machine's normal identity; repo `popcre/ai-devops`, base `main`. No secrets needed. Run locally: `bash tests/test-ai-pr-wait.sh` from repo root (Linux or Git Bash).

## 13. Done, risks, open questions
Done: Steps 1–5 merged on main, CI green, #2095 closed by the merge, STATUS rows cite the merge SHA. Live proof: the new tests exercise the real script end to end with a stubbed `gh`; that is the proof for an output-only change.
Risk: the guard in Step 2 hides advisory names on a terminal poll — acceptable, the terminal block exits anyway. Rollback: revert the PR.
Open: none needing Albert.

Handoff registration: this plan was written read-only; the implementing session must create its `HANDOFF.d/` entry linking here (or skip it if it finishes in one session, since nothing then remains unfinished).

## Self-audit
1. Fresh session can execute without questions? Yes — goal (§1), exact lines (§5, §9), test names (§10), landing rules (§11, §13).
2. All background incl. rejected paths? Yes — §6, §7, fixer's lost attempt in Verdict and §7.
3. Goal clear enough for judgment? Yes — §1 states the behaviour invariant and the goal-wins rule; §8 labels locked vs open.
