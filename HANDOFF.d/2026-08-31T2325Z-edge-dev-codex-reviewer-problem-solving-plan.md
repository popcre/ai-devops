---
issue: 198
status: OPEN
owner: codex/reviewer-problem-solving-plan-198
---

# HANDOFF — reviewer-assisted problem solving plan (2026-08-31 23:25 UTC, edge-dev/codex)

Plan: [`../plan_reviewer-assisted-problem-solving.md`](../plan_reviewer-assisted-problem-solving.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream currently needs Albert. He already decided on 2026-08-31 that an implementation plan should be written for proactive reviewer help. The implementer must not re-ask whether reviewers may be used diagnostically. If trigger evaluation cannot distinguish real stuck cases from routine debugging, consolidate that new evidence into one recommendation before asking Albert.

Already settled — do NOT re-ask:

- 2026-08-31: reviewers should help solve difficult problems during the work, not only inspect completed code.
- 2026-08-31: the primary session remains responsible for evaluating advice, making changes, and proving the result.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public toolkit for restoring and operating his Claude, Codex, and external-reviewer development workflow. It contains commands, skills, global instructions, tests, and documentation; installation to each machine is its deployment. The relevant reviewer providers already support read-only analysis, diagnosis, second opinions, or debate.

## 2. What we set out to do this session, and why

Albert asked for an implementation plan after deciding that chat sessions would benefit from asking reviewers for help when a problem has resisted the primary session's attempts. This session's job was planning only: define a safe, measurable route that adds proactive diagnostic help without turning every error into a reviewer call or confusing diagnostic advice with formal approval.

## 3. Current state — what is true right now

- GitHub issue #198 tracks implementation.
- The comprehensive plan is `plan_reviewer-assisted-problem-solving.md` and starts at Step 0.
- The plan was written against clean `origin/main` SHA `a66586dccf5e1a889533a8cc633b45e31861c94d` in isolated checkout `C:\tmp\ai-devops-plan-198`, branch `codex/reviewer-problem-solving-plan-198`.
- No implementation, wrapper change, installation, trigger evaluation, or live behavior test has started.
- The primary checkout `C:\repos\ai-devops` had unrelated concurrent changes and a different local commit. It was deliberately left untouched.
- Planning deliverables are documentation only. Their eventual commit, PR, merge, and `origin/main` verification are recorded by the session that created them; implementation remains open after that merge.

## 4. Everything we tried that did NOT work

- A broad repository search produced truncated output and was too noisy; focused searches against the global templates, provider skills, architecture, and trigger policy supplied the usable evidence.
- PowerShell rejected Bash brace expansion in one `rg` path list. The search was rerun with explicit paths; this was a shell syntax issue, not missing files.
- The idea of changing every provider trigger was rejected because multiple provider skills could fire on the same generic “stuck” event.
- Automatic fastest-provider selection was rejected because the scoreboard header explicitly says present measurements do not justify that front door.
- Triggering after the first error, asking all reviewers, pasting full chats/logs, and treating diagnostic advice as approval were rejected for cost, privacy, capacity, and evidence-integrity reasons. Full reasoning is in plan §7.

## 5. Root causes and key findings

- Existing reviewer tools already support diagnosis and debate; the missing layer is a universal session rule and one provider-neutral coordinating skill.
- The global templates discuss subagent cost control but not reviewer-assisted diagnosis (`templates/system/AGENTS-global-codex.md:121-139`; `templates/system/CLAUDE-global.md:121-125`).
- Existing provider descriptions mostly require an explicit provider request, so they do not reliably trigger when the session itself recognizes repeated failed reasoning.
- The correct threshold is two distinct evidence-based hypotheses/repairs failing on the same symptom, or an unresolved material contradiction—not two arbitrary errors.
- Diagnostic output must remain advisory and separate from the exact-head approval lifecycle.
- The shared skill should select one healthy independent provider, permit one alternate only under named failure/disagreement conditions, and give the reviewer a curated safe evidence brief rather than the chat transcript.

## 6. Exact next steps

1. Open `plan_reviewer-assisted-problem-solving.md`, re-read all sections, and begin at Step 0. Reconfirm current `origin/main`, repository policy, issue #198, reviewer status, and concurrent ownership. **You'll know it worked when the plan STATUS cites a fresh base SHA and a clean isolated checkout.**
2. Implement Steps 1-2: create the shared skill and matched global triggers without changing wrappers. **You'll know it worked when the skill alone owns the full procedure and strict context parity passes.**
3. Implement Steps 3-4: register the route and add the structural test plus balanced trigger evals. **You'll know it worked when full offline suites pass and repeated Windows/Linux eval artifacts show the desired positives without near-miss false triggers.**
4. Implement Step 5: obtain current independent exact-head review, correct findings, ship under live repository policy, install on both clients, and run isolated behavior probes. **You'll know it worked when the merge SHA is on `origin/main`, both installed clients prove the behavior and preserved machine sections, and issue #198 closes with current artifacts.**
5. Update the plan after every completed step and retire this handoff only when all acceptance items are proven. **You'll know it worked when no stale OPEN handoff remains and the completed plan accurately names every artifact.**

## 7. Constraints and gotchas in force

- Do not touch or clean unrelated changes in `C:\repos\ai-devops`.
- Read the live repository policy; do not assume the planning branch/SHA is current.
- Reviewer safety path changes require independent exact-head review. Any edit after review invalidates it.
- The new route is read-only. Write delegation is outside issue #198.
- Never send raw secrets, licensed/private data, full transcripts, uncontrolled logs, command lines, or environments to reviewers or the public repository.
- Do not create an automatic reviewer ranking, raise timeouts, weaken tests, bypass quarantine, or rotate reviewers to shop for agreement.
- Do not run local reviewer suites while the Windows self-hosted CI runner is busy.
- Use Git Bash for Bash tests on Windows; GPT-5.6 stays at low or medium reasoning.
- Source changes are not deployment. Install/adopt and verify both clients while preserving machine sections.

## 8. Access and environment

- GitHub CLI was authenticated and created issue #198.
- Repository remote is currently presented as `popcre/ai-devops`; older `u2giants/ai-devops` references redirect. Verify live identity before shipping.
- Planning checkout: `C:\tmp\ai-devops-plan-198`; branch `codex/reviewer-problem-solving-plan-198`.
- Primary checkout: `C:\repos\ai-devops`; preserve its unrelated work.
- Windows host: `edge-dev`. Bash tests use `C:\Program Files\Git\bin\bash.exe`.
- Reviewer credentials/config remain outside Git in the documented machine configuration and 1Password vault `vibe_coding`; no value is needed in chat or committed evidence.
- There is no hosted deployment. The skill installer and global adopter deploy this change to Claude and Codex.

## 9. Open questions and risks

- Exact trigger wording is open to evidence-based tuning. Prefer under-triggering if positives and routine near misses cannot be separated cleanly; bring only that proven ambiguity to Albert.
- Adding a generic trigger may create reviewer spam, opinion shopping, private-data leakage, or approval confusion. The plan supplies explicit tests and rollback for each.
- Concurrent `main` movement may stale the baseline or exact-head review. Re-fetch and re-review at every gate.
- If implementation discovers a required wrapper change, stop and create a separate scoped plan rather than silently expanding issue #198.

## Handoff self-audit — final answers

1. **Can a brand-new developer continue without asking a question? Yes.** §§1-3 establish the product, goal, issue, source state, checkout, and unfinished boundary; §6 points to exact ordered steps and verification gates.
2. **Can they continue as effectively as this session? Yes.** §§4-5 preserve the failed searches, rejected designs, line-level evidence, threshold reasoning, and diagnostic-versus-approval distinction.
3. **Is every relevant execution detail present? Yes.** §§6-9 cover actions, evidence gates, constraints, access, concurrency, privacy, risks, and escalation criteria; the linked plan contains the full 13-section build specification.
4. **Would Albert see every needed decision by reading only §0? Yes.** A line-by-line sweep of §§1-9 found no current owner decision. The only possible future decision—an empirically inseparable trigger—is already promoted to §0 with the recommendation to prefer under-triggering and present one evidence-backed ask.
