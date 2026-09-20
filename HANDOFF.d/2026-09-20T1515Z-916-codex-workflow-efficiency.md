---
issue: 650
status: OPEN
owner: codex/workflow-efficiency-plan
---

# Workflow efficiency — planning handoff

## 0. Decisions only the owner can make

None for the recommended first implementation. Albert asked for a plan, not execution of the whole programme. This handoff registers that unstarted roadmap; it does not claim another session is working on it.

Already settled, 2026-09-20: preserve useful safety, remove redundant work, use one live outcome per implementation session, reuse existing issues/helpers, and keep this publication prose-only. No new spending, production action, or fleet-wide setup is authorized by the plan. Those would require their own applicable authority if later proposed; no such action is required to start the first scoped repair.

## 1. What this application is

AI DevOps is Albert's public multi-model tooling/recovery repository: Bash/PowerShell tools, provider wrappers, instructions, skills, installers and offline GitHub checks. Installation is deployment; there is no product UI/server here. Origin uses `u2giants/ai-devops`; GitHub redirects to `popcre/ai-devops`. Both have explicit feature-branch/PR policy. Main is protected. Windows planning host: `916-alien`.

## 2. This session's goal and trigger

Albert reported changes taking days/weeks and repeatedly interrupted runs, requested an audit, then explicitly requested the implementation-plan-writer skill to produce a complete efficiency plan. The deliverable is [plan_workflow-efficiency.md](../plan_workflow-efficiency.md), not implementation. The plan owns all 13 required sections, ordered file/test targets, adversarial cases, acceptance, rollback and a final self-audit.

## 3. Current state

Baseline source `fbd567256ac9f173893fb1ebd3cd6da52b26b310` matched GitHub main at audit. [The public evidence snapshot](../tests/verification/repo-throughput/2026-09-20-workflow-efficiency-baseline.md) records recent run identities and timing methodology. Runtime changes P1–P10 are unstarted; no installed speed improvement is claimed. Planning publication is on branch `codex/workflow-efficiency-plan` in its own worktree. The commit containing this handoff publishes the plan; a successor verifies that commit's main ancestry before treating publication as landed. No runtime deployment is part of this prose commit.

[Issue #650](https://github.com/popcre/ai-devops/issues/650) tracks roadmap acceptance, has an owner line and assignee. It must stay open after plan publication. Existing #633 owns hashing; #637 owns separate Gemini preparation-bound residuals; #622 needs scope reconciliation against the already-landed #639 packet repair. Issue #335 owns related routing work. Do not close or duplicate those issues from this planning handoff.

## 4. Failed approaches and dead ends

No repair was attempted here. Audit API calls through a Windows `.cmd` wrapper split an `&` URL; quoting through Git Bash and redirecting output resolved the read. Do not repeat the verbose failed call. Rejected design routes are in plan section 7: higher timeouts, deleted assertions, disabling cancellation, treating Linux as Windows proof, broad Markdown bypasses, a new orchestration framework, and redoing completed repairs.

## 5. Root causes and findings

See plan sections 5–6 for exact source anchors. Gemini inventory spawns per file; #633 reports a five-hour pass. PR checks remain broad; fast-validation failure triggers expensive jobs that cannot make closure green. Full-local and four-review guidance conflicts with focused-test/one-protected-review rules. Copied jobs in rerun metadata are not necessarily physically repeated work. Median successful sampled PR was roughly 35 minutes, queue seven; no exact 12-hour event was identified. Main-forward review invalidation already has a fix. Existing suite manifest, shared provider helper, timing output and evidence functions should be reused.

## 6. Exact next steps

1. Read the plan STATUS, sections 1/8/11 and P1. Resolve upstream main and existing #633/#637 work through `bin/ai-gh`; claim one outcome in #633 or coordinate with its active owner. Gate: no overlapping worker edits, named owner and unique current-upstream worktree.
2. Refresh P0's narrow Gemini baseline; implement P1 with old/new byte parity and hostile fixtures. Gate: focused tests plus recorded 30,384-file benchmark and bounded installed Gemini proof, without altering digest meaning.
3. Ship through the current reviewer-safety and PR/queue contract; verify installed source, record evidence, update plan STATUS. Gate: one accepted live outcome, or exactly one owned proof issue if merged but unproved. Do not automatically take every remaining row.
4. At the context cut, use `fresh-session`, read downstream phases for drift and select the next separately owned outcome. Gate: all handoff obligations remain in the plan/owned issue; no status saying merely “continue now.”

## 7. Constraints and gotchas

Use isolated worktrees, scoped staging, correct Albert identity, no protected-main push. All GitHub calls through `bin/ai-gh`; bounded repository waiters. Check task class before stronger actions. Exact-head independent review still applies to safety/installed routing changes. No live database or production work here. Before full local testing check shared host/runtime collision. Public artifacts must not include secrets/raw transcripts/private reviewer evidence. This handoff is the only handoff owned by the planning session; do not edit other sessions' files or the root pointer.

The plan's process simplification is future work. Until it lands, current plan/handoff requirements remain effective. Do not use a proposal in this file to waive an existing safety rule.

## 8. Access and environment

Authenticated `ai-gh` read runs/issues/PRs/rules; Git fetched main. No secret needed for plan/offline work. Windows Bash: `C:\Program Files\Git\bin\bash.exe`; PowerShell 7 is native. Planning worktree: `C:\Users\ahazan2\.codex\worktrees\workflow-efficiency-plan\ai-devops`. Future workers create their own worktree. Provider access/qualification and installed host versions must be resolved live using their skills; credential values never enter this handoff.

## 9. Risks and open questions

No outstanding owner design question. Engineering uncertainties have explicit criteria in plan sections 8/13: inventory parity, dependency omissions, interference, evidence reuse complexity, loaded-machine timing, representative sample size, and unidentified 12-hour incident. Queue caching and lightweight descriptive-skill treatment are conditional, not prerequisites to hashing. Installed fleet state was not audited. Nothing in this file promises an active background worker or future wakeup.

## Planning subagent provenance

- `plan_ci_inputs`: read-only CI/test-selector inspection; confirmed combined classification/validation, existing manifest, serial reviewer lane, timing outputs and event isolation. No files edited, no branch/PR/worktree, no GitHub calls. Did not decide which protections to remove.
- `plan_process_inputs`: read-only wrapper/preflight/instruction inspection; confirmed inventory contracts differ, timeout quarantine conflation, duplicate preparation and existing evidence functions. No edits/branch/PR/worktree or GitHub calls. No installation or paid review.
- Prior audit agents `ci_audit` and `process_audit` supplied source findings incorporated in the baseline and plan. They also performed read-only work only, created no issues/branches and changed no runtime state.

## Self-audit — passed

1. A new implementer can resume: sections 1–3 define application, request, provenance and unstarted scope; section 6 identifies one concrete next outcome and gates.
2. Relevant context is retained: sections 4–5 preserve dead ends, measured versus historical evidence, existing fixes and reuse decisions; the linked plan supplies complete build detail.
3. All execution dimensions are present: sections 6–9 provide constraints/access/risks; plan sections 9–13 give concrete tests, hostile inputs, shipping, installation and rollback. Publication and implementation are explicitly distinct.
4. Owner-decision sweep passed: sections 1–9 and provenance contain no required current owner choice. Future expanded spending/production authority is expressly outside scope and is repeated in section 0. No unraised decision is filed only as a finding.
