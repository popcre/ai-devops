---
issue: 308
status: OPEN
owner: codex/reviewer-log-checkpoint-plan
---

# Reviewer log repair checkpoints

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert. Already settled on 2026-09-07: resolved incidents remain in their existing append-only incident folders; do not move them to a `resolved.md` file or archive. The next session must not re-ask this.

## 1. What this application is

`popcre/ai-devops` is the public backup-and-restore toolkit for POP Creations' multi-model reviewer workflow. The affected local Bash command, `ai-reviewer-issue`, records private reviewer failures and append-only repair resolutions below the installed toolkit's ignored `.ai/reviewer-issues/` directory. GitHub Actions validates source; installation is deployment.

## 2. What we set out to do this session, and why

Albert asked for a comprehensive implementation plan to close the missing reviewer-log repair boundary. Today the ledger knows which recorded incidents are resolved, but it cannot prove which log content a completed repair sweep examined. The plan must ensure the next sweep starts at the last fully completed boundary without missing new, unrecorded failures.

The complete build specification is [`../plan_reviewer-log-repair-checkpoints.md`](../plan_reviewer-log-repair-checkpoints.md). GitHub issue #308 owns completion.

## 3. Current state — what is true right now

Planning is complete. No runtime implementation, tests, installation, or live proof exists. The plan and this handoff were created from `origin/main` commit `ab87112c` on branch `codex/reviewer-log-checkpoint-plan` in the isolated worktree `C:\Users\ahazan\.codex\worktrees\reviewer-log-checkpoint\ai-devops`.

Existing behavior remains: incident `issue.json` records creation and exact evidence joins; resolution JSON records repair time, commit, and evidence; list/show derive status from those folders. There is no maintenance-round checkpoint.

## 4. Everything we tried that did NOT work

No implementation was attempted. Design alternatives rejected in the plan are: moving resolved incidents to Markdown or an archive, using repair time alone, using modification time alone, using byte offset alone, modifying provider logs in place, advancing on tests without closure proof, or waiting for active logs to become quiet. Each can lose evidence or create a second source of truth.

## 5. Root causes and key findings

- Incident closure and log coverage are different facts.
- The existing append-only resolution model is sound and must stay authoritative.
- A safe scan needs a previous completed lower boundary, a frozen upper boundary, continuity evidence, and an atomic completion gate.
- Rotation, truncation, replacement, malformed content, or an unaccounted candidate must block advancement.
- Checkpoint and evidence state must remain private and machine-local.

See plan Sections 5–8 for exact source references and locked decisions.

## 6. Exact next steps

1. Start at Step 1 of the linked plan and define schemas. You'll know it worked when schema fixtures accept complete rounds and reject incomplete ones.
2. Inventory every registered provider's structured lifecycle/log source. You'll know it worked when no provider is silently omitted.
3. Implement bounded readers and the round lifecycle in `bin/ai-reviewer-issue`. You'll know it worked when old content is excluded, late writes are deferred, and continuity failures block.
4. Implement candidate-to-incident reconciliation and atomic completion. You'll know it worked when every candidate has one outcome and incomplete repair cannot advance the checkpoint.
5. Add the full Windows/Linux test matrix and update docs/skill/router. You'll know it worked when focused and repository verification pass without weakening an existing assertion.
6. Obtain independent exact-head review, merge through protected `main`, install, and execute the two-round live proof. You'll know it worked when the second round excludes old records, includes the new one, and issue #308 can be closed.
7. Update the plan STATUS with artifacts and delete this handoff only after all obligations are complete and present on `origin/main`.

## 7. Constraints and gotchas in force

Do not archive or rewrite incidents; do not expose private logs or prompts; do not trust timestamps alone; do not advance partial rounds; do not silently omit unsupported providers. Preserve exact evidence joins and reviewer safety rules. Use an isolated worktree, verify Git identity, stage only owned files, obtain exact-head independent review, and use `bin/ai-pr-wait` for CI. Do not run a local reviewer suite on `edge-dev` while Windows CI is active.

## 8. Access and environment

GitHub CLI is authenticated for `popcre/ai-devops`. Target branch is protected `main`; work proceeds through a feature branch and pull request. Git, Git Bash, Bash, and `jq` are required. Unit tests use synthetic state. Live provider secrets, if needed, stay in 1Password vault `vibe_coding` and are accessed only through existing wrappers; never expose values.

## 9. Open questions and risks

Bounded implementer choices are command naming, immutable-round lookup strategy, and explicit handling of providers lacking structured events. Decision criteria are in plan Sections 8 and 13. The primary risk is falsely advancing past unseen content; the design must fail closed and retain the last completed checkpoint.

### Handoff self-audit

1. **Fresh developer continuity: PASS.** Sections 1–3 define the system, goal, branch, commit, and exact implementation state; Section 6 gives ordered gates and links the full plan.
2. **Equivalent session knowledge: PASS.** Sections 4–5 preserve rejected approaches and root cause; Sections 7–9 preserve constraints, access, decisions, and risks.
3. **All execution details present: PASS.** The linked 13-section plan carries file/function targets, dependencies, tests, landing, installation, rollback, and definition of done.
4. **Owner-decision sweep: PASS.** Sections 1–9 contain no unsettled owner decision. Section 0 records the settled no-archive decision and instructs the next session not to re-ask.
