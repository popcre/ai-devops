---
issue: 198
status: OPEN
owner: codex/reviewer-problem-solving-plan-corrections-198
---

# HANDOFF — corrected reviewer-assisted problem-solving plan (2026-09-01 10:59 UTC, edge-dev/codex)

Plan: [`../plan_reviewer-assisted-problem-solving.md`](../plan_reviewer-assisted-problem-solving.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — Albert already requested the plan and then requested that Kimi K3's findings be corrected. Do not re-ask whether to use reviewers diagnostically or whether to incorporate the review.

If repeated implementation evidence cannot distinguish a genuine stuck state from routine debugging, present Albert one consolidated recommendation. Until then, prefer under-triggering as the plan directs.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public toolkit for Claude, Codex, and external-reviewer development workflows. Skills and global instruction templates are installed onto each machine; that installation is the deployment. Issue #198 adds a proactive, read-only reviewer-diagnosis route for sessions that have exhausted multiple evidence-based attempts.

## 2. What we set out to do this session, and why

Kimi K3 independently reviewed the merged implementation plan and returned `READY WITH NON-BLOCKING IMPROVEMENTS`. Albert said “correct it.” This session corrected every material finding before implementation begins, without changing reviewer wrappers or implementing the feature.

## 3. Current state — what is true right now

- Implementation remains unstarted; every STATUS implementation row is open.
- The corrected source of truth is `plan_reviewer-assisted-problem-solving.md` on branch `codex/reviewer-problem-solving-plan-corrections-198`, based on current `origin/main` SHA `a3c899b9de2ff5b8bc793e83f38c5edda8d3b17b`.
- Kimi reviewed prior merged head `5dd46b5976f4018c15ebf1b94c7730fef56f0c05` in completed read-only job `bab0e5ba6e64-codex-reviewer-problem-solving-plan-k3` and requested seven corrections plus clarification of the route's debate bound.
- The previous handoff was retired under the successor rule: its merged commit was verified on `main`, all obligations and decisions are carried by the corrected plan and this file, and no unique dead end was lost.
- The primary checkout `C:\repos\ai-devops` remains untouched because it contains concurrent work.

## 4. Everything we tried that did NOT work

- The original plan treated the trigger eval as if it could prove proactive multi-turn behavior. Kimi showed the harness measures single-prompt skill-description selection; the corrected plan now labels that evidence narrowly and makes installed-client probes the behavior gate.
- The original Claude citation pointed to GPT-5.6 rules, not delegation guidance, because Claude has no matching Codex cost-delegation section. The corrected shared anchor is “When something goes wrong.”
- Requiring zero context-budget warnings could pressure an implementer to game the ratchet. The corrected gate distinguishes strict failures from measured, justified warnings.
- Literal “add” instructions would duplicate the already-merged AGENTS and architecture planning pointers. They now say replace/update.
- The original plan omitted the Codex usage guide and preferred Windows installer and left skill retirement implicit. All are now explicit.

## 5. Root causes and key findings

- The architecture remains sound: one shared routing skill, thin matched global routes, existing provider skills/preflight, one-reviewer default, primary-session ownership, and strict diagnosis-versus-approval separation.
- Description discrimination, installed-client routing, and a real reviewer call are three different evidence layers and must be named separately.
- `context-audit.py` uses fixed regex parity markers, not semantic comparison. The corrected plan requires both a stable parity marker and a structural semantic test.
- The route's one-turn-plus-one-follow-up limit must explicitly supersede a provider's ordinary longer debate allowance while this route owns the escalation.
- New artifact governance needs an owner and retirement path even when installation quarantine is recoverable.

## 6. Exact next steps

1. Read the corrected plan end to end and start at Step 0 against fresh `origin/main`. **You'll know it worked when STATUS cites the fresh base, live policy, matching open handoffs, and clean isolated checkout.**
2. Implement Steps 1-2 exactly, including route-specific debate precedence, the shared global anchor, stable parity marker, and budget-warning evidence rule. **You'll know it worked when the new structural test and strict context audit pass without weakened budgets.**
3. Implement Steps 3-4, updating rather than duplicating planning pointers and running separately labeled Claude/Codex description evals. **You'll know it worked when every artifact says what it actually measures and every miss has evidence.**
4. Complete Step 5 with independent exact-head review, current CI, native Windows installation, Ubuntu installation, repeated installed-client fixture probes, and one controlled end-to-end positive per client. **You'll know it worked when the merge SHA, installed files, preserved machine sections, route counts, and issue closure are directly evidenced.**

## 7. Constraints and gotchas in force

- Do not edit reviewer wrappers, build automatic provider ranking, broaden permissions, or convert diagnostic output into approval.
- Do not paste raw chats, logs, secrets, licensed data, command lines, or environments into reviewer prompts or public evidence.
- Keep the primary session responsible for changes and verification.
- Do not run local reviewer suites while the shared Windows CI runner is busy.
- Preserve unrelated work and never use broad staging or destructive Git operations.
- Any source edit invalidates exact-head review. Installation, not source alone, is deployment.
- Update the plan STATUS as work happens; stale plan state is a defect.

## 8. Access and environment

- GitHub CLI and Kimi were authenticated for the completed review. The wrapper requested `kimi-code/k3`; Kimi exposes no returned model, tokens, cache, or cost.
- Clean planning checkout: `C:\tmp\ai-devops-plan-198`.
- Primary concurrent checkout: `C:\repos\ai-devops`; do not reset or clean it.
- Windows host: `edge-dev`. Use the native Windows installer named in the plan and Git Bash only for required Bash tests.
- Credentials remain outside Git in documented machine configuration and 1Password vault `vibe_coding`; never print their values.

## 9. Open questions and risks

- No current owner decision is open.
- The exact final trigger wording remains evidence-driven. Prefer under-triggering if repeated tests cannot cleanly distinguish positive and negative cases.
- Context budgets may warn after adding the capability. Measure and justify attributable growth rather than raising the ratchet or weakening required behavior.
- If implementation requires a wrapper change, stop and create a separate plan; issue #198 does not authorize hidden scope expansion.

## Handoff self-audit — final answers

1. **Can a new developer continue without asking a question? Yes.** §§1-3 define the product, issue, corrected source, branch, baseline, review, and unfinished boundary; §6 gives exact gated steps.
2. **Can they continue as effectively as this session? Yes.** §§4-5 preserve every Kimi finding, failed assumption, correction, and the three evidence layers.
3. **Is every relevant execution detail present? Yes.** §§6-9 cover ordering, tests, installation, review, privacy, concurrency, risks, and escalation boundaries; the linked plan holds the full build specification.
4. **Would Albert see every needed decision in §0? Yes.** A line-by-line sweep of §§1-9 found no current owner decision; the only potential future trigger ambiguity is already promoted with the recommendation to prefer under-triggering and consolidate one evidence-backed ask.
