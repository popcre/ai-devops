---
issue: 1783
status: OPEN
owner: codex/reviewer-recurrence-plan
---

# Handoff — recurring reviewer repair planning

## 0. Business decisions only the owner can make

None. Sweep completed across §§1–9: all unknowns concern diagnosis, technical ownership, access or verification and belong to the AI coordinator. Already settled October15,2026: Albert requested “make a plan to fix everything”; publication is authorized, but implementation is not claimed completed. Keep the four maintained reviewers and existing technical safeguards. Do not ask Albert to approve technical work.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is a Linux/Windows toolkit used by Albert's AI sessions for independent reviews, source evidence, safe recovery and installation. It has no hosted product runtime. edge-dev3 is the affected Linux development computer. Its main consumer here is [popcre/shared-db](https://github.com/popcre/shared-db), whose governed review accepts only exact-source terminal decisions.

## 2. This session's goal and trigger

Albert asked why reviewers still fail, then invoked implementation-plan-writer and requested a complete repair plan. We investigated current local incidents, current source and existing repair cards; we wrote a standalone plan instead of altering provider code or calling paid reviewers. The intended repair outcome is reliable preserved decisions and safe recovery without capability loss.

Execution specification: [repair plan](../plan_reviewer-recurrence-repair.md), portable [published plan](https://github.com/popcre/ai-devops/blob/codex/reviewer-recurrence-plan/plan_reviewer-recurrence-repair.md). Its STATUS is the starting point, and every section is needed by a new implementer.

## 3. Current state and delivery

The plan and this handoff are planning artifacts only. Implementation, installation and new reliability proof are not started. Publication uses `codex/reviewer-recurrence-plan`; [issue1783](https://github.com/popcre/ai-devops/issues/1783) is the durable card. The issue publication comment is authoritative for eventual commit/PR/merge details; do not infer a merge from this branch link.

Source inspected: [24b038bc7f4a6efc304031b9ab0a2bfc7228965f](https://github.com/popcre/ai-devops/commit/24b038bc7f4a6efc304031b9ab0a2bfc7228965f). Installed checkout HEAD observed: [f84085f93b6c20752d798a9b3db76b78bedb3d2f](https://github.com/popcre/ai-devops/commit/f84085f93b6c20752d798a9b3db76b78bedb3d2f), an ancestor. Launcher resolves there; installed byte equality/receipt validity was not proved. Plan §5 contains source line anchors, limitations and ownership timestamps.

Fresh public readbacks superseded stale October11 memory: [issue1562](https://github.com/popcre/ai-devops/issues/1562) is CLOSED with acceptance checked; [PR1565](https://github.com/popcre/ai-devops/pull/1565) is MERGED at [d6b787aad8f380f4436897f364dc75ca9e7c7993](https://github.com/popcre/ai-devops/commit/d6b787aad8f380f4436897f364dc75ca9e7c7993). Do not reimplement its closed programme.

## 4. Failed attempts and dead ends

The retained Muse incident reports three incomplete attempts across new/follow-up/OpenCode execution; switching engine alone did not solve it. An earlier response only named selected symptoms and had not verified repair ownership. This plan corrects that gap by naming existing cards while marking their current activity unverified. Initial lookup of a guessed repair-plan filename found no file; the actual historical system-repair and pipeline-core plans exist and are linked in plan §7.

Do not repeat blind paid retries, accept partial text, overwrite a receipt, clear orphan evidence, impose shorter turn budgets, suppress required CI or kill unrelated process groups. Full reasons and current rejected approaches are in plan §7. No failed code modification, provider test or installation was attempted by this planning session.

## 5. Findings and root-cause limits

Private inventory found80 unresolved local records (17 dated October11 onward), not80 unique defects. Many are repeated frozen-provider allowance reports. All must get dispositions; the maintained repair scope remains Muse/DeepSeek/GLM/StepFun plus shared components.

[Packet publisher](https://github.com/popcre/ai-devops/blob/24b038bc7f4a6efc304031b9ab0a2bfc7228965f/bin/ai-review-packet#L560) correctly refuses unequal existing receipts. [Muse parser](https://github.com/popcre/ai-devops/blob/24b038bc7f4a6efc304031b9ab0a2bfc7228965f/bin/ai-muse#L872) correctly refuses a nonterminal tool-call finish. [StepFun door](https://github.com/popcre/ai-devops/blob/24b038bc7f4a6efc304031b9ab0a2bfc7228965f/tools/lib/review-doors/stepfun.sh#L366) already instructs one decision; the consumer additionally rejects approval-like text elsewhere. These guards are not the defects to remove. Exact upstream causes remain subject to discriminating fixtures in plan §§6,9.

## 6. Exact next steps

1. Read the plan STATUS and §§1–13. Claim/refresh coordinator ownership on issue1783, refresh current heads and existing overlapping owners. Gate: no duplicate owner or stale inherited authority.
2. Execute step1's exact private inventory and installed-source proof, preserving existing maintenance checkpoints. Gate: every local unresolved ID has disposition/owner/evidence status.
3. Execute steps2–6 in dependency order: receipt/recovery isolation, Muse completion, StepFun report/input, DeepSeek/GLM residuals, test/diagnostic isolation. Gate: named discriminating/adversarial tests pass and ordinary capability survives.
4. Execute steps7–8: independent exact-head review, merge, supported install, genuine per-provider/consumer matrix, real24h observation, incident reconciliation. Gate: all plan §13 repair checks have openable evidence. Keep the same issues open for live proof; do not stop after one child.

Natural context cuts, serialization and drift sweeps are in plan §9. No subagents were dispatched by this session. No other chat is authorized to be messaged merely because its issue lists an owner.

## 7. Constraints and gotchas

Task class for this plan is prose; reviewer repair is reviewer-safety or stronger. Public main is protected; use branch/PR/queue, owned staging and Albert's committer identity. Follow [deployment procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md), never pull installed checkout. Preserve exact-source, immutable receipts, uncertain-turn fences and foreign processes. Raw incidents and paid transcripts remain private. Frozen wrappers remain callable and out of maintained rotation; existing four-member policy stands.

Existing owners: [Muse674](https://github.com/popcre/ai-devops/issues/674), [GLM1349](https://github.com/popcre/ai-devops/issues/1349), [StepFun1370](https://github.com/popcre/ai-devops/issues/1370), [sandbox1420](https://github.com/popcre/ai-devops/issues/1420), [DeepSeek1405](https://github.com/popcre/ai-devops/issues/1405), [pipeline1301](https://github.com/popcre/ai-devops/issues/1301). Their cards prove recorded scope, not active work. Refresh before touching overlaps. Do not close duplicate-looking historical cards without proving their remaining obligations accounted.

## 8. Access and environment

Verified: authenticated public GitHub read/issue-create through the repository's throttled CLI; Git fetch; local incident/source access. Planning did not test provider credit, remote access, privilege or install admission. No secrets were read or written. Provider credentials stay in protected installed stores and vault `vibe_coding`; exact reference discovery uses [onboarding](https://github.com/popcre/ai-devops/blob/main/docs/onboarding-secrets.md) and provider skills, never guessed titles or values. The plan §12 defines safe discovery commands and explains the machine-local incident inventory without publishing its contents here.

## 9. Open questions, risks and ownership

The issue1783 coordinator owns receipt-cause tracing, Muse tool-call termination, StepFun consumer-safe terminal report, current DeepSeek/GLM applicability, verification hangs and final live acceptance. Named child owners retain their existing overlapping work until reconciled. Their active/idle state was not verified, and no background activity is promised. Platform access/refusal is a tracked technical blocker, never a request for Albert to run commands or approve a bypass.

No new code is deployed by this handoff. A24h proof requires actual elapsed time and samples; an older pipeline14day/50review gate is separate. Use the protected rollback path for regressions, retain evidence and restart the stable observation interval when code changes. A frozen-provider-only limitation is accounted explicitly rather than silently reactivating it. All other uncertainties and objective acceptance criteria are in plan §§6,8–13.

## Self-audit

1. Yes — newcomer continuation is supported by purpose/repositories §§1–2, current delivery and readbacks §3, concrete ordered gates §6 and access §8, with the full linked specification.
2. Yes — §§3–5 retain every non-obvious investigation finding, stale-memory correction and failed approach; §§7–9 preserve constraints, overlap and uncertainty.
3. Yes — background/goal §§1–2, actual state §3, failures/root-cause bounds §§4–5, next actions/tests §6, safety/access §§7–8, risks/rollback/ownership §9 cover all ten required sections. The plan carries detailed adversarial cases and proof requirements.
4. Yes — line-by-line sweep of §§1–9 found no unresolved business-meaning decision. Diagnosis, source review, access, overlapping ownership and installation are AI-owned technical tasks; §0 says None and lists already settled scope. No technical approval is asked of Albert.
