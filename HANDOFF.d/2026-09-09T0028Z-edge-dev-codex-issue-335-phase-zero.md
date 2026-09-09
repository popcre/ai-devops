---
issue: 335
status: OPEN
owner: codex/issue-335-routing-gates
---

# HANDOFF — Issue #335 Phase 0 closeout (2026-09-09T0028Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert. Already settled on 2026-09-08: #335 must cover all 17 canonical repositories, central enforcement lives in `popcre/ai-devops`, local policies may strengthen but never weaken protected gates, and raw transcripts or licensed source rows must not be inspected. The next session must not re-ask these decisions.

## 1. What this application is

`popcre/ai-devops` is POP Creations’ public toolkit for reliable multi-model AI work across its repositories. Issue #335 makes task routing lean and makes the correct verification and safety gate a durable decision rather than an unreliable prose instruction. It is not an application deployment and this work authorizes no production, infrastructure, database, or source-data mutation.

## 2. What we set out to do this session, and why

The owner asked to complete #335 through production without colliding with other agents. This session took the first planned, evidence-only slice: freeze the canonical repository inventory and the current routing-surface baseline. This prevents later rollout work from silently omitting a repository or treating private material as safe to inspect.

## 3. Current state — what is true right now

- Phase 0 is merged on `origin/main` as `d613926a9c8846af7a17695b7c097f990210db0a` through PR #340 at https://github.com/popcre/ai-devops/pull/340.
- `config/repository-coverage.json` records exactly 17 canonical repositories, their default branches, privacy classes, instruction surfaces, workflow families, and non-downgradable gates.
- `tests/verification/task-gates/routing-baseline.json` fingerprints every permitted routing surface by bytes, heading count, and SHA-256; it does not store raw private content.
- `tools/context-audit/audit-repository-routing.py` and `tests/test-repository-coverage.sh` validate one coverage row and one baseline entry per canonical repository.
- Phase 1 (policy contract), Phase 2 (central command), Phases 3–4 (pilots and rollout), and Phase 5 (install/acceptance) are not started. A separate active Codex task titled `Implement cross-repo gate plan #340` owns continuation; do not duplicate its work.
- #335 is OPEN. PR #340 initially closed it because its body said `Closes #335`; this session reopened the issue and added a status-correction comment explaining that only Phase 0 landed.

## 4. Everything we tried that did NOT work

- Running the Bash test through the Windows `bash` command invoked WSL, which has no installed distribution. It did not test the change. Running the same test through `C:\Program Files\Git\bin\bash.exe` passed; do not install WSL or weaken the test for this.
- The first PR check failed because the new Bash test was absent from `config/ci-suite-manifest.json`, whose policy test requires an exact discovered-test list. Adding it and changing the expected count from 66 to 67 fixed the contract. No test was removed or bypassed.
- The first PR body prematurely closed #335. The merge was valid for Phase 0, but the issue closure was not. The issue was reopened immediately; future incremental PRs must not use closing keywords until Phase 5 is proven.

## 5. Root causes and key findings

- Existing CI classification (`tools/ci/classify-changes.sh`) is coarse and runs after a PR exists; it does not record task intent or stop scope drift before expensive actions. That is why #335 needs a central policy and command rather than another large router rule.
- The canonical coverage set is 17 repositories. `u2giants/licensor-source-data`, `u2giants/ai-devops-transcripts`, and `popcre/infrastructure` do not use the standard root `AGENTS.md` surface, so absence of one is not evidence of clean routing.
- The Phase 0 exact-head verification passed: fast classifier, Linux offline, hosted Windows offline, and EDGE-RUNN-ENVY reviewer-safety lanes. The latter two are expensive, so do not rerun them unchanged.

## 6. Exact next steps

1. In the active implementation task, begin Phase 1.1 from `plan_cross_repo_routing_and_gate_enforcement.md`: choose the smallest backwards-compatible schema location, define protected classes and precedence, and add fail-closed downgrade fixtures. You’ll know it worked when table-driven policy tests reject unknown policy and every protected-class downgrade.
2. Complete Phase 1.2’s lean-router contract before editing any consumer repository. You’ll know it worked when fixtures show safety instructions remain reachable by the right task trigger without loading unrelated procedures for documentation work.
3. Land the central engine (Phase 2) before pilots, using a new isolated current-upstream worktree and the required exact-head safety review. You’ll know it worked when `start`, `check`, and `explain` handle the complete Git change set and existing classifier output remains compatible.
4. Roll out the four pilots separately, then the remaining repositories, preserving each repository’s branch and approval rules. You’ll know a phase worked only when each coverage row records its landed policy, router evidence, and verification.
5. Close #335 only after Phase 5’s supported-machine installation and nine-scenario acceptance battery pass. You’ll know it is safe to close when every STATUS row is complete and the plan’s done definition is met.

## 7. Constraints and gotchas in force

- Keep central implementation in `popcre/ai-devops`; consumer repositories receive thin declarations and lean routers only. Stronger local gates win.
- Use current-upstream isolated worktrees, stage only owned files, and preserve the canonical checkout as landing-only.
- Do not inspect raw transcript archives or licensed source rows. Do not mutate database, infrastructure, deployment, or production state under this issue.
- DesignFlow remains sandbox-branch/PR-to-`develop` and Uma-merge-only. Shared-db structure retains its governed PR, review, preview, target-proof, and production rules.
- A docs-only PR may merge immediately only when every changed file is prose. Code, test, script, or config changes require normal checks. Do not use `Closes #335` until the whole plan is complete.

## 8. Access and environment

- Git and GitHub CLI access are authenticated for `popcre/ai-devops`; PR #340 was merged through the protected merge queue.
- The completed branch/worktree is `codex/issue-335-routing-gates` at `C:\repos\ai-devops-worktrees\issue-335-routing-gates`; it is clean and retained only until this handoff record lands.
- Git Bash is available at `C:\Program Files\Git\bin\bash.exe`; WSL is unavailable on this Windows host.
- No credentials were read, created, or exposed. Any future secret work uses 1Password vault `vibe_coding` without printing values.

## 9. Open questions and risks

- No owner decision blocks Phase 1. The precise schema location and local intent-state directory are engineering choices already delegated to Phase 1 evidence.
- The active continuation task must reconcile `origin/main` before writing because #340 was squash-merged as `d613926a`, not as its original branch SHA.
- The main risk is false completion: the issue was once closed after Phase 0. Treat the plan STATUS table and Phase 5 acceptance—not an individual PR merge—as the close criterion.

## Self-audit

1. Yes. Sections 1–3 give a new developer the product, purpose, landed state, branch, issue, and active owner; §§4–6 provide failed attempts and exact verified continuation.
2. Yes. §§4–5 preserve the WSL, test-manifest, premature-closure, privacy-surface, and CI findings that would otherwise cause repeated work.
3. Yes. §§0–9 cover decisions, context, current state, failures, findings, steps with acceptance gates, constraints, access, and risks; commits, URLs, and secret boundaries are explicit.
4. Yes. The section-0 sweep found no unresolved owner judgement anywhere in §§1–9; its settled decisions are listed there with the instruction not to re-ask them.
