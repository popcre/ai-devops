# Cross-repository routing and task-gate enforcement handoff

Issue: 335

Status: OPEN

Owner branch/session: `codex/cross-repo-gate-preflight-plan-20260908` / Codex task that authored the plan

## 0. Owner decisions

- Implement this in every canonical repository, not only `ai-devops`.
- Preserve as much useful instruction as possible while trimming bloated routing
  files and checking peer routing surfaces.
- Fix the repeated workflow-selection failure durably, rather than accepting
  multi-hour CI/reviewer work for a simple documentation task.

No further owner decision blocks Phase 0.

## 1. Current state

- The implementation plan is
  [`plan_cross_repo_routing_and_gate_enforcement.md`](../plan_cross_repo_routing_and_gate_enforcement.md).
- Owner issue [#335](https://github.com/popcre/ai-devops/issues/335) is open under
  throughput parent #159; final required-check cutover #166 must remain last.
- A live local inventory on 2026-09-08 found 17 unique canonical remotes. The
  repeated `ai-devops` and `shared-db` folders are clones/worktrees, not separate
  rollout targets.
- No implementation has started. Every STATUS row is OPEN; resume Step 0.1.

## 2. Failed attempts

- The triggering documentation cleanup expanded into an unrequested code/config
  budget change. That invoked full Windows CI and reviewer gates and consumed
  roughly two hours before the extra scope was removed.
- Adding more prose to `AGENTS.md` cannot enforce correct gate selection and
  makes the original context problem worse.
- A PowerShell inventory command initially ended with a parser error caused by
  piping directly after a `foreach` block. The corrected command wrapped the
  loop output in an array; do not repeat the broken form.

## 3. Findings

- `tools/ci/classify-changes.sh` and `tests/lib-selection.sh` already share a
  coarse classifier, but it runs after edits and is not consulted by reviewer or
  wait entry points.
- `bin/ai-review-lifecycle` is the common enforcement opportunity for formal
  Codex, Claude, and Grok reviews.
- `bin/ai-pr-wait` prevents indefinite queue waits but does not decide whether a
  documentation-only PR should wait at all.
- `config/repository-policy.json` already resolves branch workflow by canonical
  repo identity and is the nearest existing declarative policy.
- Three current canonical repos did not expose a root `AGENTS.md` in the local
  inventory: `popcre/infrastructure`, `u2giants/licensor-source-data`, and
  `u2giants/ai-devops-transcripts`. Phase 0 must classify their actual routing
  surfaces without reading private raw content.

## 4. Exact next steps

1. Start Phase 0.1 from the plan; refresh remotes and saved projects.
2. Add the canonical coverage manifest and validation without editing consumer
   repositories.
3. Produce the routing census/no-loss ledger for all 17 repos.
4. Commit Phase 0 evidence, update STATUS and this handoff, then take the first
   fresh-session cut before policy design.

## 5. Constraints

- Work from isolated current-upstream worktrees; never alter canonical shared
  checkouts for implementation.
- This plan authorizes documentation and repository-maintenance tooling only. It
  authorizes no schema/data, deployment, infrastructure, or production mutation.
- Stronger repository-specific gates override defaults and may not be weakened.
- Do not inspect raw transcript `.jsonl` files or licensed source rows.
- Do not self-merge DesignFlow changes.

## 6. Access and environment

- Current host: `edge-dev`; plan branch is based on `popcre/ai-devops` `origin/main`.
- GitHub access was sufficient to create issue #335.
- Implementation needs read/write access to the 17 canonical repositories and
  read-only saved-project/remote metadata.
- Production credentials are not required; protected flows use fixtures and
  read-only identity proof.

## 7. Risks

- A file-extension-only classifier could incorrectly bypass operational or
  safety-bearing Markdown. Use repository path overrides and strongest-match
  behavior.
- A hard context budget could incentivize deleting unique safeguards. Use size
  as a warning plus a section-level no-loss ledger.
- Consumer-specific scripts would drift. Keep implementation in `ai-devops` and
  consumer policy declarative.
- Cross-repo rollout can exceed one context window. Obey the plan's phase cuts
  and update STATUS plus this handoff at every cut.

## 8. Verification already completed

- Confirmed owner issue #159 is OPEN and created #335.
- Confirmed the 17 unique remotes and their local default-branch refs.
- Confirmed existing classifier, local selection, reviewer lifecycle, PR waiter,
  plan index, and specialized router integration points by current source lines.
- Confirmed this planning change remains Markdown-only.

## 9. Handoff self-audit — 2026-09-08

1. **Can a successor identify authority and ownership?** Yes: the contract names
   issue #335, OPEN status, owner branch, and the three owner decisions.
2. **Can a successor resume without replaying discovery?** Yes: Sections 1, 3,
   and 4 identify the verified baseline and exact Step 0.1 restart.
3. **Are failure history and safety boundaries preserved?** Yes: Sections 2, 5,
   and 7 preserve the scope-expansion failure, parser recovery, privacy limits,
   non-mutation boundary, and non-downgradable local gates.
4. **Are completion claims evidence-bounded?** Yes: Section 8 lists only checks
   actually performed; every implementation STATUS row remains OPEN.
