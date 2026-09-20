---
issue: 643
status: OPEN
owner: codex/issue-643-jev-integration
---

# HANDOFF — TypeSafe Jev advisory integration plan (2026-09-20 14:12Z, 916/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Give the whole list to Albert in one message before implementation; do not raise
these one at a time.

### BLOCKING

1. **Start implementation.** Albert asked this session to write the plan, not to
   activate Jev integrations. Recommendation: when ready, authorize only Phase 0
   plus the public-issue pilot by saying, “Implement Phase 0 and Phase 1 of the
   Jev advisory plan.” This blocks all code work in §6 steps 1–4.
2. **Promote the reviewer contradiction sentinel.** Shadow evaluation is allowed
   by the plan, but changing an `APPROVE` to `BLOCKED` needs a later explicit
   decision after the artifact shows every planted contradiction caught and zero
   false blocks. Recommendation: approve promotion only if that exact gate passes.
   This blocks any enforcing part of plan §9.6, not its shadow evaluation.
3. **Continue after a failed issue pilot.** The plan stops later Jev phases if the
   first pilot retires, unless Albert redirects based on the failure artifact.
   Recommendation: stop, because a cheap model that cannot clear the safest use
   has not earned higher-risk experiments. This blocks plan phases 2–5 only if
   the issue pilot is retired.

### RECOVERABLE

None. The remaining design choices are deliberately resolved by measured gates
inside the plan, not owner preference.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

None discovered.

### Already settled — do NOT re-ask

- **2026-09-20:** Jev stays advisory and public-repository-only; it never approves,
  mutates GitHub, reduces tests/review scope, writes maintenance outcomes, or
  changes deterministic task classes.
- **2026-09-18:** `fast-jev-compaction` remains uninstalled because the safe
  threshold saved effectively nothing and upstream safety fixes remain open.
- **2026-09-20:** completion-honesty stays record-only; its real failure scored
  below the `0.91` bar and the closed measurement program is not revived.
- **2026-09-20:** private/licensed data, transcripts, shared-db, production,
  secrets, permissions, ownership, CI/test omission, and source identity remain
  outside Jev.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and operating toolkit for a
multi-model AI development workflow. It supplies command-line tools, reviewer
wrappers, evidence handling, machine configuration, skills, and tests. It is not
a hosted application; installation from GitHub is its deployment.

The new plan is
[`plan_typesafe-jev-advisory-integrations.md`](../plan_typesafe-jev-advisory-integrations.md).
It converts the 2026-09-20 whole-repository Jev audit into separately measured,
safe advisory experiments. GitHub issue
[#643](https://github.com/popcre/ai-devops/issues/643) owns the open workstream.

## 2. What we set out to do this session, and why

Albert asked for an implementation-plan-writer plan to integrate the places where
the whole codebase audit found Jev could help. The business purpose is to exploit
Jev's extremely low per-token price for repetitive sorting without making a
cheap probabilistic service authoritative.

This session's technical deliverables are:

1. a fresh-developer-grade 13-section implementation plan;
2. a write-once handoff registered to issue #643;
3. discoverability from `AGENTS.md` and the existing Jev decision record;
4. a documentation-only PR merged to protected `main`.

No Jev integration, configuration activation, external data submission, or
machine installation is part of this session.

## 3. Current state — what is true right now

- The planning baseline was `origin/main`
  `211bc94b4861131ad025927516019285e412302f`.
- The isolated planning worktree was
  `C:\Users\ahazan2\.codex\worktrees\jev-integration-plan\ai-devops`; no shared
  checkout was edited.
- Task class `prose` is recorded. Git identity was verified as
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Issue #643 is open and names the advisory boundary and completion proof.
- The new plan exists at `plan_typesafe-jev-advisory-integrations.md`; its STATUS
  rows are all open because no implementation has started.
- This handoff is this session's only new `HANDOFF.d/` file. Root `HANDOFF.md`
  remains the static pointer.
- The plan and router edits are documentation only. Delivery PR
  [#645](https://github.com/popcre/ai-devops/pull/645) is `MERGED`; its squash
  commit `d007a39eb1892262a1d5472d130cc3eaaf18757c` is verified on `origin/main` and
  in the clean canonical checkout.
- No code, tests, config, secret, installation, or live behavior has changed.

## 4. Everything we tried that did NOT work

These are prior measured dead ends carried forward so an implementer does not
repeat them:

1. **Safe compaction:** Jev saw poor separation between later-needed and stale
   tool output. At the safe threshold it dropped four of 523 outputs and saved
   effectively no text; at normal thresholds it discarded later-used material.
   Upstream PRs #44, #45, and #57 are still required before any retest.
2. **Completion-honesty enforcement:** split questions improved sensible scores,
   but the one genuine unsupported “complete and verified” result scored `0.73`,
   below Albert's `0.91` floor. Record-only is the honest state.
3. **Broad whole-toolkit authority:** the audit rejected Jev for BlockerWatch,
   GitHub pacing, CI/test selection, source identity, packet integrity, provider
   health, task stages, permissions, secrets, database/shared-db work, production,
   and independent review. Those are deterministic or require evidence.
4. **One large integration:** rejected because issue triage, review safety,
   maintenance, and routing have different data and failure boundaries. The plan
   uses one outcome per session with explicit stop points.
5. **Provider copies:** existing probe and completion scripts already duplicate
   secret/HTTP logic. The plan requires a shared client before adding consumers.

This planning session had one routine command error: `rg` interpreted a search
pattern beginning with `--before` as a flag. Re-running with `rg -- <pattern>`
resolved it; it changed no files or design.

## 5. Root causes and key findings

1. `bin/ai-jev-probe:1-60` and `bin/ai-jev-completion-shadow:1-104` duplicate
   Jev secret resolution, HTTP, timeouts, model aliasing, and response parsing.
   A shared bounded client is Phase 0.
2. `plan_ai-devops-work-claims.md:429-435` says human triage remains necessary
   for truly duplicated issue records. This is the best first pilot because its
   command cannot mutate GitHub.
3. `bin/ai-review-lifecycle:263-304` centrally validates reports and finalizes all
   reviewer outcomes, making it the only sensible common contradiction-shadow
   insertion point.
4. `bin/ai-review-packet:582-733` creates and seals changed-file evidence; any
   additive risk hints must be created before the packet hash and must leave the
   complete patch/scope intact.
5. `tools/reviewer_maintenance.py:251-388,442-474,538-575` separates candidate
   discovery from authoritative outcome and audit. Suggestions must remain in a
   separate file never read by those authoritative methods.
6. `config/task-gates.json:24-73` is deterministic, while
   `docs/skill-trigger-eval.md` requires actual-client skill measurements.
   Prompt routing can only be an offline disagreement diagnostic.
7. Public-only eligibility must be checked from normalized repository identity
   and live GitHub visibility before any vendor request. A local environment
   override is not a privacy decision.

## 6. Exact next steps

1. **Verify the planning baseline, already delivered.** Confirm PR #645 is
   `MERGED` and `origin/main` contains
   `d007a39eb1892262a1d5472d130cc3eaaf18757c` plus this handoff's later status
   correction. **You'll know it worked when:** the plan, router link, and this
   handoff all open from current `origin/main`.
2. **Wait for owner authorization to implement.** Put all three §0 decisions to
   Albert in one message; do not infer code authorization from this planning
   request. **You'll know it worked when:** Albert explicitly authorizes Phase 0
   and Phase 1, or declines them.
3. **Start Phase 0 in a new current-upstream worktree.** Load the plan, declare
   task class `code`, reconfirm public eligibility/model docs, and implement only
   the shared client/config in plan §9.1–§9.2. **You'll know it worked when:** the
   focused/full tests and one bounded live reachability proof pass and Phase 0's
   STATUS row cites an artifact.
4. **Start the public-issue pilot in a fresh session.** Follow plan §9.3–§9.5,
   freeze the holdout before tuning, and choose KEEP/TUNE ONCE/RETIRE in the same
   workstream. **You'll know it worked when:** the reproducible artifact supports
   one decision and no indefinite shadow tool remains.
5. **Only after a KEEP result, evaluate one later phase per fresh session.** Each
   reviewer phase declares `reviewer-safety`, runs protected tests and exact-head
   review, and updates the plan. **You'll know it worked when:** each phase is
   independently kept or retired with evidence and one live-proof owner issue if
   landed proof remains.
6. **Close and reconcile.** The finishing session updates the original Jev
   decision record, closes #643, and deletes this handoff only after every open
   obligation is carried into the plan or proven complete. **You'll know it
   worked when:** every STATUS row is complete/retired with artifacts and no open
   obligation exists only in this handoff.

## 7. Constraints and gotchas in force

- Canonical checkout is landing-only; every implementation uses its own current-
  upstream worktree and feature-branch PR.
- One unproven live outcome per session. Issue #643 is an umbrella plan issue,
  not a bundle for leftover proofs.
- GitHub calls use `bin/ai-gh`; waits use `bin/ai-pr-wait`.
- Jev is advisory/asymmetric. It cannot approve, mutate, omit, or satisfy proof.
- Initial external data is only allowlisted, live-public `popcre/ai-devops` text.
  Private/licensed/shared-db/transcript data is prohibited.
- Reviewer lifecycle, packet, or maintenance edits are protected reviewer-safety
  work requiring an independent exact-head final review.
- Model thresholds are invalid after a model change. The exact response model
  must match the configured pin.
- A vendor failure preserves the deterministic baseline and records
  unavailability; it never becomes an approval or a clean result.
- `TYPESAFE_API_KEY` stays in 1Password and moves only through `op run`; never
  print it or put it in arguments/settings.
- Use `apply_patch` for edits, stage only owned files, and verify the committer
  identity before each commit.
- Memory was not updated because memory changes require Albert's explicit
  request. Repository routing is provided by AGENTS, the topic plan, and this
  handoff.

## 8. Access and environment

- Machine: Windows 11 `916-alien`, user `ahazan2`; PowerShell 7 primary, Git
  Bash for repository Bash tests.
- Canonical repo: `D:\repos\ai-devops`; implementation must not edit it directly.
- Worktree for this planning session:
  `C:\Users\ahazan2\.codex\worktrees\jev-integration-plan\ai-devops`.
- GitHub: authenticated, accessed only through repository wrapper `bin/ai-gh`.
- TypeSafe endpoint: `https://api.typesafe.ai/v1/systemone`; current verified
  exact model `jev-1.13.0`.
- Secret location: 1Password vault `vibe_coding`, item `typesafe.ai API`, field
  `credential`; reference is `TYPESAFE_API_KEY` in `config/mcp.env.example`.
  The value is not in this handoff or repository.
- Tracking: GitHub issue #643. Merged planning delivery PR #645 is recorded in §3.
- No production, database, infrastructure, deployment, or app login is involved.

## 9. Open questions and risks

- Whether implementation begins is an owner decision consolidated in §0.
- Whether issue triage is precise/useful enough is not a design debate; the
  holdout in plan §9.4 decides it.
- Whether contradiction shadowing can ever block a review requires the separate
  owner decision in §0 after zero-false-block evidence.
- Jev is early and can change model behavior or availability. Exact pinning,
  response-model checks, and re-shadowing on upgrades contain that risk.
- Public issue text can still contain accidental sensitive text. The first pilot
  uses one public repo and logs only IDs/digests; any discovered sensitive issue
  is removed from the set and treated as a data-boundary failure.
- Adding network latency to reviewer paths can widen source-race windows. Strict
  deadlines and the existing post-build/source-digest checks remain mandatory.
- Low price does not prove value. Every phase records precision, coverage,
  latency, bytes/cost, and safety failures before KEEP.

## Part B — sub-agent record

### `/root/jev_review_paths`

- **Asked:** perform a read-only current-main map of exact files/functions and
  safe insertion points for the five phased integrations; report dependencies
  and privacy/safety constraints.
- **Actually did:** its earlier whole-repository audit supplied the ranked
  reviewer candidates used here, but this session's follow-up ended without a
  delivered final report and the agent left the live tree. No conclusion from
  that missing follow-up was treated as evidence; `/root/jev_plan_audit`
  independently checked the finished draft instead.
- **Branch/PR/worktree:** read-only; no branch, PR, worktree, or file edits.
- **Deliberately did not do:** implementation, configuration activation, external
  data submission, or GitHub mutation.

### `/root/jev_plan_audit`

- **Asked:** audit the completed plan against the implementation-plan skill and
  standard, and validate named insertion points against current source.
- **Actually did:** completed a read-only audit and found five concrete gaps: a
  reviewer-finalization race, missing maintenance public-repo eligibility, a
  missing installation-class redeclaration, undefined route-shadow ground truth,
  and an underspecified shared-client API/test target. All five were corrected in
  the plan before commit.
- **Evidence:** `bin/ai-review-lifecycle:288-298`,
  `tools/reviewer_maintenance.py:319-323`, `config/task-gates.json:34-37`,
  `tools/skill-trigger-eval/fresh-session.eval.json:1-12`, and
  `tests/test-tool-version-pins.sh`.
- **Branch/PR/worktree:** read-only; no branch, PR, worktree, or file edits.
- **Deliberately did not do:** implementation or editing; the primary session
  retained every design and delivery decision.

## Mandatory handoff self-audit — final answers

1. **Is this comprehensive enough for a brand-new developer to continue without
   missing a beat? Yes.** §§1–3 define the product, purpose, exact baseline,
   branch, issue, and non-implementation state; §§5–8 give file-level findings,
   ordered next steps, constraints, and access. Part B records both delegated
   reads and the disposition of every finding.
2. **Could that developer continue as effectively as this session can now? Yes.**
   §§4–7 preserve failed experiments, rejected boundaries, exact insertion
   points, phase order, and verification gates; the linked plan contains the
   complete executable design and adversarial matrix. The independent audit
   caught and closed five specific gaps before this handoff was finalized.
3. **Is every relevant execution detail present? Yes.** Background, goal, outcome,
   current state, failures, decisions, constraints, risks, access, exact next
   actions, and proof are covered in §§0–9 and the linked plan. No secret value is
   present. PR #645 and its current commit are explicit in §3.
4. **Would Albert see every required decision by reading only §0? Yes.** A line-by-
   line sweep of §§1–9 and Part B found three owner judgments: authorization to
   implement, later contradiction promotion, and whether to continue after a
   failed first pilot. All three appear in §0 with recommendations and the work
   each blocks. No outside-workstream owner ruling was found.

Checklist result: all 10 required sections exist; §0 contains the complete owner-
decision sweep; failures and dead ends are explicit; every next step has a
verification gate; identifiers and access are defined; commit/push/merge state is
explicit; and secret references name only their protected location.
