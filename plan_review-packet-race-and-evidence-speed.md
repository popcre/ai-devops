# IMPLEMENTATION PLAN — review-packet forward-move tolerance, fast-evidence convention, adversarial-cases table (2026-09-18)

| Step | Status | Evidence (artifact, not a bare claim) |
|---|---|---|
| 0 — reconcile + tracking issue | ⬜ open | |
| C — adversarial-cases standard (prose PR) | ⬜ open | |
| A — slow-evidence warning + docs (reviewer-safety PR) | ⬜ open | |
| B — forward-move tolerance + base-ref snapshot (same reviewer-safety PR) | ⬜ open | |
| Landing — reviews, merge queue, origin/main verification | ⬜ open | |

**A fresh session starts at §1, then §9.** Registration handoff:
[`HANDOFF.d/2026-09-18T1606Z-edge-dev-kimi-review-packet-race-plan.md`](HANDOFF.d/2026-09-18T1606Z-edge-dev-kimi-review-packet-race-plan.md).

## 1. The ultimate goal — what we are actually trying to achieve

Delegated reviewer rounds must stop being destroyed by things that have nothing
to do with code quality. When this is done, three things are true that are not
true today:

1. Nobody can accidentally attach a 20-minute full test suite as review
   evidence without the evidence tool itself warning, in the sealed manifest,
   that the convention is a focused suite of seconds — full suites already run
   in PR CI and the merge queue.
2. A sealed review packet stays valid when `origin/main` (or the review's
   target ref) has only moved FORWARD since the packet was built — the reviewed
   `base..head` diff is byte-identical, so the evidence is still exact. A
   history rewrite, a moved HEAD, or a changed working tree still refuse
   loudly, exactly as today.
3. Trust-boundary code (parsers, pricing/money, files or data coming from
   outside the repo) arrives at its first review already self-audited: the
   plan/PR carries an adversarial-cases table — every external input × its
   hostile case × the test that proves it — so four-round rejection loops over
   predictable cases stop happening.

The point is fewer wasted hours and fewer paid provider rounds — **not** fewer
or weaker safety checks. The checks being touched caught four genuine bugs in
money-handling code; their strictness about HEAD and tree identity is not
negotiable. *If any step below conflicts with this goal, the goal wins — stop
and flag it.*

## 2. What this application is

`popcre/ai-devops` — Albert's public recovery and configuration toolkit for a
multi-model AI workflow (Claude, Codex, Kimi, Grok, GLM, and others). No app,
service, or database. The component under change is `bin/ai-review-packet`
(version 1.2.0, 761 lines at `origin/main` `6f102cf3`), which builds the sealed
evidence packet (`.ai-review-<tag>/` inside the review directory) that a
delegated reviewer with no shell reads to learn base/head SHAs, the patch, and
test results. Its companion `bin/ai-review-sandbox` builds disposable snapshot
clones for linked worktrees; that file is **not** edited by this plan. GitHub
is the source of truth; work lands by branch + PR through the merge queue.

## 3. What triggered this work

Incident self-reported by a Claude session on 2026-09-17/18 (money-handling
change, four reviewer rejections, five rounds). Three compounding causes:

1. **Slow evidence command.** The session attached a ~20-minute full test suite
   as the `--tests` evidence command. Every review round paid that cost, and —
   critically — the long run opened a wide invalidation window (see §6).
2. **The race (tooling flaw).** `bin/ai-review-packet` re-validates the source
   repository's live identity against the sealed identity at build end and at
   every `verify`. Another session legitimately landing unrelated work moved
   `origin/main` forward during those 20 minutes; the strict equality checks
   killed two complete review rounds (~2 hours) even though the reviewed diff
   had not changed by one byte.
3. **Discipline gap.** The four rejections were genuine bugs (fake pricing from
   linked files, wrong-model pricing, crash on absurd prices) — all predictable
   by a 10-minute adversarial checklist written before coding. The standing
   self-audit rule existed but was skipped; there is no artifact that forces it.

The prior session said it would file an issue proposing the base-commit race
fix; an open-issue search on 2026-09-18 (`review packet base commit race`)
found nothing, so step 0.2 files it.

## 4. Scope — in and out

**In scope:**

- Fix A — slow-evidence warning in `bin/ai-review-packet` + the written
  convention in `docs/development.md`.
- Fix B — forward-move tolerance and base-ref snapshot in
  `bin/ai-review-packet`'s identity validation, with tests.
- Fix C — mandatory adversarial-cases table in
  `templates/system/implementation-plan-standard.md`, mirrored into
  `skills/shared/implementation-plan-writer/SKILL.md`, plus one router line in
  `docs/task-router.md`.

**NOT in this plan:**

- Any change to `bin/ai-review-sandbox` (owned by the now-closed #393; see §5
  for its leftover branch).
- Any weakening of HEAD equality, whole-tree digest equality, packet hash
  sealing, per-tag packet ownership, or the additive-packet property.
- Changes to the nine reviewer wrappers (`bin/ai-grok-review`, `bin/ai-glm`,
  …) beyond what tests already assert about them.
- CI/merge-queue configuration, provider qualification, retry/backoff policy.
- Any production or shared-database anything.
- Deleting the leftover `claude/review-snapshot-base-refs` branch/worktree
  (noted in §5; separate cleanup decision, not this plan).

## 5. Current state of the code

All facts verified 2026-09-18 against `origin/main` `6f102cf3` (local canonical
checkout was 2 behind; both pending commits are unrelated to this work).

- `bin/ai-review-packet` already **measures** the `--tests` command duration
  (`test_seconds`, lines 404–408) and records `Measured duration:` in the
  manifest test block (line 411). There is no threshold and no warning — this
  is Fix A's insertion point.
- `validate_identity` (lines 229–254) is where the race fires:
  - line 234–235: source HEAD equality and whole-tree digest equality
    (`source-head-mismatch`, `source-digest-mismatch`) — **stay strict**;
  - lines 236–239: if `target_ref` is set, the ref's current tip must equal the
    recorded target, else `die source-target-moved` — **this is kill point 1**;
  - lines 240–242: re-runs `resolve_base` against the live repo and requires
    identical `BASE_SHA`/`TARGET_SHA`/`TARGET_REF`, else
    `die source-base-mismatch` — **kill point 2** (TARGET_SHA half);
  - line 243: `merge-base base head` must equal the recorded `merge_base` —
    **stays strict** (it proves the compared history is unchanged).
- `validate_identity` is called at build end (lines 636–645, AFTER the `--tests`
  command ran at lines 403–407) and at `verify` (line 684 via `cmd_verify`).
  The build-end call is exactly "re-checks has main moved after the slow test
  run" from the incident.
- `cmd_verify` regenerates the expected patch from the **recorded** base/head
  SHAs (lines 689–707), so the patch comparison is already immune to target-ref
  movement; only `validate_identity` needs the semantic change.
- `verify-retained` / `validate_retained_identity` (lines 263–276) already
  never consults the live source for base/target — unaffected; do not touch.
- `tests/test-ai-review-packet.sh` (414 lines, fully offline) already contains
  `identity_rejects_target_movement` (line 278): it moves the `release` ref to
  `HEAD` — which **is** a forward move containing the recorded target — and
  expects `verify` to fail. Under Fix B this test's expectation flips; it must
  be **re-scoped to a rewrite** (point the ref at a non-ancestor), never
  deleted. `unchanged_identity_verifies_after_restoring_target` (line 280) and
  `identity_rejects_untracked_source_movement` (line 267) must stay green
  unchanged.
- `templates/system/implementation-plan-standard.md` (163 lines) has no
  adversarial-cases requirement; `skills/shared/implementation-plan-writer/SKILL.md`
  is its self-contained mirror (its footer demands the two stay in sync) and is
  the source installed to `~/.codex/skills/` etc.
- `docs/development.md` documents reviewer tooling (sections around lines
  60–137) but never states a `--tests` duration convention.
- Issue #393 "Enforce one source identity and complete review input" is
  **CLOSED**; its plan slice (`plan_reviewer-reliability-and-efficiency.md`
  line 207) locked: "A mid-run base/head movement invalidates authorization and
  requires a newly bound run, not rewritten old evidence." Fix B is compatible:
  it relaxes only the **target-ref tip** check; recorded base and head stay
  exactly bound, and old evidence is never rewritten.
- Leftover local-only branch `claude/review-snapshot-base-refs` (commit
  `0fa5c724`, touches `bin/ai-review-sandbox` + its tests) is already fully
  upstream per `git cherry origin/main` (`-` prefix) — a stale #393 remnant in
  a temp worktree, safe to clean up separately.
- No open PR touches `bin/ai-review-packet`, `tests/test-ai-review-packet.sh`,
  the plan template, or `docs/task-router.md` (open-PR listing checked
  2026-09-18).

## 6. Key findings and root cause

The race, precisely: build resolves base/head (line 352), runs `--tests`
(403–407 — 20 minutes in the incident), then captures and validates live
identity (636–645). Separately, every `verify` re-validates (684). Both paths
die on `source-target-moved` / `source-base-mismatch` the moment the target ref
tip advances, **even when the recorded base is still an ancestor of the new tip
and the `base..head` patch is byte-identical**. Two legitimate sessions on one
machine therefore keep destroying each other's reviews, and the probability
scales with evidence-command duration — which is why Fix A (shrink the window)
and Fix B (remove the false invalidation) belong together but neither alone is
sufficient.

Why forward-move tolerance is safe here: the packet's verdict is bound to the
recorded head SHA ("Your verdict applies to head … and to no other commit"),
the patch is regenerated from immutable recorded SHAs at verify, the whole-tree
digest check (line 235) still proves the reviewed tree is exactly the sealed
tree, and the merge queue re-tests the exact landing commit — so work landing
on main in the meantime is covered there, not by invalidating the review. What
must still refuse: HEAD moved, tree digest changed, target ref rewritten so the
recorded target is no longer reachable, target ref deleted.

## 7. Approaches considered and REJECTED, and why

- **Weaken or skip reviews.** Rejected by the incident review itself: the
  checks caught four genuine money-handling bugs. Nothing in this plan reduces
  review coverage.
- **Ignore target movement entirely at verify.** Rejected: silent staleness. A
  rewrite that orphans the recorded base must keep refusing loudly — only the
  failure semantics change for the forward case.
- **Re-resolve base/head at verify to "catch up" with moved main.** Rejected:
  that rewrites the comparison under a sealed packet. #393's locked direction
  is immutable identity; this plan honors it.
- **Fix A only (convention, no code).** Rejected: even a 5-second suite leaves
  a nonzero window, and builds can also stall between `resolve` and `build`
  for other reasons. The race is a tooling bug; fix the tool.
- **Fix B only.** Rejected: the 20-minute evidence command is a self-inflicted
  tax on every round and every reviewer, race or no race.
- **One combined PR for A+B+C.** Rejected: C is prose class while A+B touch the
  reviewer-safety path; combining forces the protected independent review to
  cover documentation it needn't, and delays C behind it. (See §8, LOCKED.)
- **Deleting `identity_rejects_target_movement`.** Rejected outright: the test
  file header names the tests that must never be weakened; re-scope it to the
  rewrite case so coverage is preserved.

## 8. Design decisions already made (dated 2026-09-18)

- **LOCKED** — `--tests` attaches the focused unit suite only; full suites are
  PR CI's and the merge queue's job ("never verify the same commit twice" is
  already the repo rule; this plan makes it findable at the point of use).
- **LOCKED** — HEAD equality, whole-tree digest equality, merge-base equality,
  packet sealing, and per-tag ownership all stay byte-strict. Only the
  **target-ref tip** check gains ancestry tolerance.
- **LOCKED** — two implementation PRs: PR-C (prose: Fix C) and PR-AB
  (reviewer-safety: Fixes A+B, one independent read-only exact-head final
  review before merge per AGENTS.md). This plan + its handoff + the AGENTS.md
  router row land first as their own prose PR (PR-plan).
- **LOCKED** — the slow-evidence signal is a **warning**, never a failure:
  stderr `warn` plus a ⚠️ note sealed into the manifest test block. Slow
  evidence must not become a new hard gate.
- **LOCKED** — the private base ref is per-tag
  (`refs/ai-review-packets/<tag>`), written at build into the **source**
  repository (the real checkout, resolved from the `.ai-review-sandbox` marker
  when the review dir is a snapshot), and deleted by `ai-review-packet remove`
  for that tag only — mirroring the packet ownership rules at lines 361–376.
- **OPEN** — warning threshold default (proposal: 120 s) and env var name
  (proposal: `AI_REVIEW_TEST_WARN_SECONDS`, following the
  `AI_REVIEW_PATCH_MAX_BYTES` pattern). Implementer picks; state the choice in
  the PR body.
- **OPEN** — exact refusal/warning wording, provided every message names the
  recorded target, the current tip, and the preserving private ref where
  relevant.
- **OPEN** — whether `scripts/run-governed-review.mjs` or another consumer
  needs the forward-move-tolerated line surfaced programmatically. Implementer
  greps callers of `ai-review-packet verify`; decide by whether any consumer
  parses verify output today (if none, human-readable output suffices).

## 9. The plan — numbered, ordered, executable steps

### Phase 0 — reconciliation (do first, in the implementing session)

- **0.1 Overlap re-check.** Run `bin/ai-gh pr list --state open` and
  `bin/ai-gh issue list --search "review packet" --state open`; read the STATUS
  table of `plan_reviewer-reliability-and-efficiency.md`. If any open work now
  covers Fix B's semantics, stop and reconcile instead of duplicating.
  *Gate: the PR body names what was checked and found.*
- **0.2 Tracking issue.** File the issue the prior session promised, e.g.
  title "ai-review-packet: forward-only target movement must not invalidate
  sealed review evidence", body linking this plan; or adopt the existing issue
  if 0.1 found one. *Gate: issue number recorded in the handoff frontmatter and
  PR bodies.*
- **0.3 Gate declaration.** `bin/ai-task-gates start --class reviewer-safety`
  before touching `bin/ai-review-packet` or its tests; `--class prose` for the
  Fix C PR. *Gate: command records the class (jq must be on PATH — see §12).*

### Phase C — adversarial-cases standard (PR-C, prose; independent of Phase AB)

- **C.1** `templates/system/implementation-plan-standard.md`: in "Required
  structure", extend §9's block with: for trust-boundary work (parsers,
  pricing/money, files or data from outside the repo) the plan must contain an
  **adversarial-cases table** — every external input × its hostile case × the
  test that proves it — and is not complete until every row names a test. Add
  the matching checklist item and one anti-pattern line ("first draft sent to
  review without the adversarial-cases table"). *Gate: `grep -q adversarial
  templates/system/implementation-plan-standard.md` and the checklist renders.*
- **C.2** `skills/shared/implementation-plan-writer/SKILL.md`: mirror the same
  requirement (the file declares itself kept in sync with the template). Keep
  wording identical in substance. *Gate: diff shows the same semantic addition;
  `grep -q adversarial` passes.*
- **C.3** `docs/task-router.md`: add a row — "Trust-boundary code review
  (parsers, pricing, external files)" → read the template's adversarial-cases
  requirement → boundary: "the first review request carries the completed table
  in the PR body". *Gate: row present; markdown table still parses.*
- **C.4** Open PR via `bin/ai-gh`, wait with `bin/ai-pr-wait`, merge through
  the queue, confirm the commit on `origin/main`. *Gate: merge SHA recorded in
  this plan's STATUS table.*

### Phase AB — packet fixes (PR-AB, reviewer-safety; one branch, one PR)

- **A.1 Slow-evidence warning.** In `cmd_build` immediately after
  `test_seconds` is computed (`bin/ai-review-packet` lines 404–408): when
  `test_seconds` exceeds `${AI_REVIEW_TEST_WARN_SECONDS:-120}`, call `warn`
  naming the convention ("attach the focused unit suite; full suites run in PR
  CI and the merge queue") AND append a ⚠️ paragraph to `test_block` so the
  warning is sealed into the manifest the reviewer reads. Never fail the build
  over duration. *Gate: tests A.3 pass.*
- **B.1 Target forward-move tolerance.** In `validate_identity`
  (lines 236–242): replace the strict tip equality with — ref missing →
  `die source-target-missing`; tip unchanged → pass; recorded target is an
  ancestor of the current tip (`git merge-base --is-ancestor`) → `warn` once
  naming ref, recorded tip, current tip, and pass; otherwise →
  `die source-target-rewritten` naming all three SHAs plus the private ref that
  preserved the base. Keep the re-resolved `BASE_SHA`/`TARGET_REF` equality and
  the `merge_base` equality strict. *Gate: tests B.4 pass, including the
  re-scoped existing test.*
- **B.2 Base-ref snapshot.** In `cmd_build`, after base is final (line 354) and
  using the real source path already computed from the `.ai-review-sandbox`
  marker (lines 486–492 — move that computation earlier rather than
  duplicating it): `git -C "$real_root" update-ref "refs/ai-review-packets/<tag>" "$base"`.
  In `cmd_remove`, delete exactly that tag's ref. Purpose: a history rewrite
  can no longer garbage-collect the base out from under sealed evidence, and
  the rewrite refusal can cite the preserved object. Never touch another tag's
  ref. *Gate: tests B.4 pass.*
- **B.3 Verify output.** When forward movement was tolerated, `cmd_verify`'s
  success output carries one explicit line saying so (ref, recorded tip,
  current tip). `identity.json` schema stays version 1 — no new fields.
  *Gate: `forward_moved_target_still_verifies` asserts the line.*
- **B.4/A.3 Tests** in `tests/test-ai-review-packet.sh` (all offline, real git):
  - `slow_test_command_warns`: `AI_REVIEW_TEST_WARN_SECONDS=0` with
    `--tests 'true'` → build exits 0, stderr warns, manifest carries the ⚠️.
  - `fast_test_command_is_not_flagged`: default threshold, `--tests 'true'` →
    no warning text anywhere.
  - `forward_moved_target_still_verifies`: build on the feature branch, advance
    the target ref one commit past the recorded tip, `verify` passes and prints
    the forward-move line.
  - `rewritten_target_refuses_loudly`: point the target ref at a commit that
    does NOT contain the recorded target → `verify` fails, message names the
    rewrite and the private ref.
  - `deleted_target_ref_refuses`: delete the target ref → `verify` fails.
  - `head_movement_still_refuses`: commit on top of the reviewed HEAD →
    `verify` still fails `source-head-mismatch`.
  - `base_ref_written_at_build` / `remove_deletes_only_own_base_ref` /
    `base_ref_survives_for_retained_evidence`.
  - **Re-scope, never delete**, `identity_rejects_target_movement` (current
    line 278): change its `update-ref` target to a non-ancestor
    (`$STALE_LOCAL_SHA` fits the existing A/B/C fixture) so it tests the
    rewrite refusal; its forward case is covered by the new test above.
  - *Gate: `bash tests/test-ai-review-packet.sh` fully green via Git Bash.*
- **B.5 Convention doc.** `docs/development.md`, reviewer tooling area: state
  that `--tests` attaches the focused unit suite (seconds, not minutes), that
  full suites belong to PR CI and the merge queue, and that the packet warns on
  slow evidence. *Gate: `grep -q "focused" docs/development.md`.*
- **B.6 Suite sweep.** Run the packet and sandbox slices of `tests/test-all.sh`
  (confirm the `--only` filter names in that script first); check
  `bin/ai-test-local --check-collision` before any full local series.
  *Gate: green run logs referenced in the PR body.*
- **B.7 Independent review.** Request the mandatory read-only exact-head final
  review for the reviewer-safety path. The review packet for THAT review must
  attach `bash tests/test-ai-review-packet.sh` as its `--tests` command —
  dogfooding Fix A's convention. *Gate: exact-head APPROVE recorded by
  `ai-review`.*
- **B.8 Land and reconcile.** Merge through the queue via `bin/ai-pr-wait`;
  confirm the intended commit on `origin/main`; update this plan's STATUS table
  with merge SHAs; add a one-line cross-reference in
  `plan_reviewer-reliability-and-efficiency.md` STATUS if its packet-semantics
  text needs it; close or link the step-0.2 issue. Installation is this repo's
  deployment mechanism: check whether the installed `bin/ai-review-packet` is a
  symlink (already live) or a copy (re-run `./install.sh` per
  `docs/deployment.md`) and record which in the PR body. Finally add a portable
  memory entry pointing at this plan's STATUS table (`ai-facts` where the
  client has it) so the plan is discoverable months from now.

## 10. Tests required

- New/changed named tests: the full list in step B.4/A.3 — no others.
- Must-stay-green: `tests/test-ai-review-packet.sh` in full (especially the
  five guarded properties in its header: additive packet, pointers-not-copies,
  split-not-truncate, removal safety, per-tag ownership) and
  `tests/test-ai-review-sandbox.sh` (companion tool, not edited but
  behavior-adjacent).
- PR-AB's own review evidence command: `bash tests/test-ai-review-packet.sh`
  (seconds — the convention this plan writes down).

## 11. Constraints, standing rules, and gotchas in force

- Reviewer-safety class for PR-AB: independent read-only exact-head final
  review before merge is mandatory; the class cannot be acknowledged away.
- Never push to `main`; branch + merge queue. Stage only task-owned files.
  Committer must read `Albert Hazan <u2giants@users.noreply.github.com>`
  (`git var GIT_COMMITTER_IDENT`).
- All GitHub calls through `bin/ai-gh`; waits through `bin/ai-pr-wait` with a
  deadline — no polling loops.
- No silent failures, no band-aids; new warnings are advisory by design (§8).
- The packet stays additive — do not inline repo files, do not fence the
  reviewer.
- Worktree rule: do not edit the canonical `C:/repos/ai-devops` checkout; cut
  from current `origin/main` under `C:/repos/ai-devops-worktrees/`.
- `bin/ai-review-sandbox` is out of bounds (§4); the leftover
  `claude/review-snapshot-base-refs` branch is fully upstream — leave it for
  the normal worktree-cleanup route.
- Do not verify the same commit twice; rerun only failed or changed checks.
- Update THIS plan's STATUS table in the same session that executes any step —
  a partially executed plan that isn't updated is a lie for the next session.
- Windows: run Bash tests through Git Bash; keep PowerShell compatibility
  untouched (no `.ps1` changes here anyway).

## 12. Access and environment

- Machine `edge-dev` (Windows). git, gh, and jq are installed but NOT on the
  default PATH of a Kimi shell: export
  `PATH="/c/Program Files/jq:/c/Program Files/GitHub CLI:$PATH"` before using
  `bin/ai-task-gates`, `bin/ai-gh`, or `bin/ai-review-packet` itself (it
  `need`s jq). Claude/Codex shells already have them.
- Tests are fully offline: real git, no network, no provider calls.
- Worktree convention: `git worktree add C:/repos/ai-devops-worktrees/<slug>
  -b <client>/<slug>-<date> origin/main`.
- No secrets, logins, or external services are needed for any step.

## 13. Definition of done + risks and open questions

**Done when:** tracking issue filed and linked (0.2); PR-plan (this file,
handoff, AGENTS.md router row) merged; PR-C merged (Fix C live in template +
skill mirror + router); PR-AB merged with the mandatory independent exact-head
review and green CI; every merge SHA confirmed on `origin/main`; this plan's
STATUS table updated with those SHAs; the handoff's "Next exact action" cleared
or rewritten.

**Risks and rollbacks:**

- *Forward-move tolerance masks a genuinely stale review.* Mitigated: base,
  head, digest, and merge-base stay exact; the merge queue re-tests the exact
  landing commit. Rollback: revert the single PR-AB merge commit — strict
  checks return.
- *Private refs accumulate.* Mitigated: `remove` deletes the tag's own ref;
  orphans are listable with `git for-each-ref refs/ai-review-packets/` — noted
  here, deliberately not automated in this plan.
- *Re-scoped test loses real coverage.* Mitigated: the rewrite case replaces
  the forward case explicitly and the forward case gains its own positive test.
- *Warning fatigue at the threshold.* Advisory only; threshold is env-tunable.

**Open questions:** threshold default and env name (§8); ref namespace string
(§8); governed-review consumer output needs (§8). Each has its decision
criteria stated in §8/§9 — none blocks starting.

## Self-audit (mandatory gate — final answers)

1. *Could a brand-new session execute this without asking anything?* Yes —
   every step names its files with line anchors verified against `origin/main`
   `6f102cf3` (§5), exact test names (§9 B.4), environment fixes including the
   edge-dev PATH trap (§12), and the class/gate commands (§9 0.3).
2. *Does it carry the planner's full context, including rejects?* Yes — §6
   pins both kill points by line number, §7 records the seven rejected routes
   with reasons, §8 splits LOCKED vs OPEN, and §5 records the #393 closure and
   the stale leftover branch so neither is rediscovered by accident.
3. *Is the goal clear enough to steer by when a step is wrong?* Yes — §1
   states the three outcomes in plain English with the explicit "goal wins"
   instruction, and names the non-negotiables (HEAD/digest strictness, review
   coverage) that any corrective judgment call must preserve.
