---
issue: 382
status: OPEN
owner: codex/designflow-qa-review-fixes-handoff
---

# 0. Decisions only the owner can make

None. Albert already established that `https://alsand.designflow.app` is safe for disposable QA records and does not write to the shared production database. He also required Sourcing Manager QA to enter royalty rates and target margins and independently verify the cost and margin arithmetic. Do not re-ask either question.

# 1. What this application is

This repository, `popcre/ai-devops`, installs shared workflows and skills used by Albert's AI coding tools. The relevant artifact is `skills/shared/designflow-human-qa/`, a thin application-specific layer on top of the general `human-app-qa` skill. It guides realistic browser testing of DesignFlow PLM as Admin, Sourcing Manager, Sales, Designer, Production, and Vendor/Factory users. DesignFlow's disposable QA site is `https://alsand.designflow.app`.

# 2. What we set out to do this session, and why

The original work created the DesignFlow human-QA skill after inspecting DesignFlow's frontend and backend repositories for real user roles and journeys. Albert added a specific requirement to test sourcing royalty, cost, selling price, and target-margin arithmetic. The skill was committed and pushed. Albert then requested an independent Grok 4.6 review. The review approved the skill with minor fixes, but those fixes were not implemented before closeout.

# 3. Current state

- The skill is present on `origin/main`; its repository history includes `a90d80f` (`feat: add DesignFlow human QA skill`). The earlier source commit reported in the original session was `c1d6a17a89c2a5f343fdf852d88fbfe5c5534c74` before the repository later moved to `popcre` and its history advanced.
- Grok 4.6's final verdict was **approve with minor fixes**. The focused review completed successfully in four turns using model `grok-4.6-build` and cost `$0.04199782`.
- The recommended fixes are still absent from current `origin/main`. Evidence: `SKILL.md:22` still uses `AI-QA-<date>-`; the mandatory sourcing pass is not stated after `SKILL.md:30`; `rfq-math-checks.md` does not define margin; `agents/openai.yaml:4` still asks for every role; and `docs/skills-map.md:54` still says “complete PLM journeys.”
- Follow-up is tracked by `popcre/ai-devops` issue #382: https://github.com/popcre/ai-devops/issues/382.
- This handoff is the only durable file created during closeout. Its branch is `codex/designflow-qa-review-fixes-handoff`, based on `origin/main` at `4db8d88`.
- No application deployment or database work is involved. Installing skills is this repository's deployment step and should happen only after the follow-up lands.

# 4. Everything tried that did not work

1. The first Grok attempt ran while Codex had temporarily restricted filesystem access. Grok could not read its own sign-in file and returned `Access is denied` followed by `Not signed in`. The credentials and file permissions were healthy; the supported wrapper health check passed once normal access returned. Do not ask Albert to sign in again for this incident.
2. The first authenticated retry asked Grok to inspect the skill plus several DesignFlow repositories. Grok used the wrapper's full 20-turn safety allowance and ended `cancelled` without a verdict. It cost `$0.20574114`. Do not resume that cancelled session or broaden its permissions.
3. A fresh, narrowly scoped review limited to the changed skill and map entry completed in four turns. This was the successful path.

# 5. Root causes and key findings

- The original access failure was caused by the temporary Codex restriction, not a broken Grok installation or bad credentials. `ai-grok-review doctor` confirmed authentication and model access.
- The cancelled review was over-scoped for the fixed 20-turn allowance. A focused exact-head review is the correct pattern.
- Grok found the skill realistic and appropriately thin. It specifically praised the disposable-site boundary, all six business roles, independent pricing checks, hard reload/persistence checks, reverse selling-price editing, blank-versus-zero handling, rounding checks, and safe cleanup rules.
- The most important gap is ambiguity in the independent calculation. `references/rfq-math-checks.md` must state that margin is `(selling price - applicable cost) / selling price` unless the screen labels a different rule. If the royalty basis or margin rule is not shown, the tester must report the missing rule rather than invent it.
- The sourcing pass can currently be skipped during a general all-role request because `SKILL.md:30` makes the math reference conditional. It must be mandatory whenever Sourcing Manager is in scope.
- Real permission isolation needs dedicated role logins. Admin impersonation is useful for menu mapping but is not proof that Vendor/Factory isolation or denied actions work.
- Invitation testing must stop before sending unless Albert supplied an approved disposable address.
- The two record-prefix spellings must become one: `AI-QA-<YYYYMMDD>-<journey>-`.
- Default samples testing should cover one origin-to-closeout path; all sample origins belong only in a full samples audit.
- Sales needs its own commercial journey, and Production should optionally begin from the order generated by an awarded disposable RFQ.

# 6. Exact next steps

1. Start a fresh task in its own current-upstream worktree for issue #382. Read this handoff, the current `skill-creator` instructions, `docs/skills-map.md`, `docs/skills-usage-guide.md`, and `docs/skill-trigger-eval.md`. Success: the task is on a new branch based on the then-current `origin/main` and no shared checkout is edited.
2. Update `SKILL.md` so the sourcing math pass is mandatory whenever Sourcing Manager is in scope, and standardize disposable names as `AI-QA-<YYYYMMDD>-<journey>-`. Success: both instructions appear once and do not duplicate the general browser-QA method.
3. Update `references/rfq-math-checks.md` with the explicit margin formula and the rule not to invent an unstated royalty basis or margin definition. Success: a fresh tester can independently calculate the expected result or file an ambiguity finding.
4. Update safety and journey references to require dedicated QA logins for access proof, restrict invitations to approved disposable addresses, use one sample path by default, add a Sales commercial journey, and connect Production to an awarded disposable RFQ when that path is requested. Success: the six roles have realistic tasks without turning every run into a full-system audit.
5. Narrow `agents/openai.yaml` to the requested role and journey; when no scope is named, default to the Sourcing Manager pricing pass. Change `docs/skills-map.md:54` from “complete” to “requested” PLM journeys. Success: ordinary DesignFlow coding requests still do not trigger the skill, while realistic QA requests do.
6. Run the skill validator and trigger evaluation required by the skill-creation docs. Success: validation is green and both positive and negative trigger cases meet the repository threshold.
7. Install the updated shared skill locally using the repository installer and verify the installed copy matches the source. Success: both Claude and Codex receive the updated shared skill without duplicate client-specific copies.
8. Commit with Albert's verified identity, push the feature branch, open a pull request, and complete the repository's required checks and merge queue. Success: the pull request is merged and `origin/main` contains every issue #382 change.
9. Close issue #382 and delete this handoff in the same finishing pull request under the successor rule, after confirming no decision or dead end exists only here. Success: issue #382 is closed, this OPEN file is absent from `origin/main`, and Git history preserves it.

# 7. Constraints and gotchas

- Use a dedicated worktree and feature branch. Never push directly to protected `main`.
- This is a shared skill. Keep one copy under `skills/shared/`; do not create parallel Claude and Codex copies.
- Keep the skill thin. General browser exploration, evidence capture, and usability method remain in `human-app-qa`; only DesignFlow roles, journeys, arithmetic, and safety belong here.
- Do not change the owner-confirmed disposable-site or sourcing-math requirements.
- Do not broaden Grok's permissions, raise its turn limit, resume the cancelled review, or ask Albert to repair credentials.
- Stage only task-owned files. Preserve concurrent work and follow the repository's pull-request and merge-queue rules.
- There is no application deployment, container, hosted service, or database change in this task.

# 8. Access and environment

- Repository: `https://github.com/popcre/ai-devops`.
- Follow-up issue: `https://github.com/popcre/ai-devops/issues/382`.
- Grok is authenticated through the supported `ai-grok-review` wrapper. Its health check passed after the temporary restriction ended.
- No secret value was read or written. Grok's sign-in data remains in its normal user-owned location; do not copy it into the repository or reports.
- Git identity was verified as `Albert Hazan <u2giants@users.noreply.github.com>` before this handoff commit.

# 9. Open questions and risks

- No owner decision is open.
- Risk: defining margin without the “unless the screen labels a different rule” qualifier could make the skill contradict a deliberately different DesignFlow calculation. Preserve that qualifier and report unclear UI rules as findings.
- Risk: using impersonation as access proof can hide real Vendor/Factory isolation defects. Require a real role login for denial and isolation claims.
- Risk: expanding every samples origin in a routine pass would make the skill heavy and expensive. Keep the one-path default.
- Risk: the local canonical checkout was behind `origin/main` during closeout. The handoff branch was correctly created from current `origin/main`; future work must start from current upstream again rather than continuing this documentation-only branch.

## Handoff self-audit

1. Yes. Sections 1–3 define the repository, business purpose, exact shipped state, review result, issue, and branch; section 6 gives executable next steps with a success gate for each.
2. Yes. Sections 4–5 preserve both failed Grok attempts, their causes, the successful retry, costs, and every substantive review finding, so a new developer does not need this chat.
3. Yes. Sections 0–9 cover the settled owner decisions, goal, current state, failures, findings, actions, constraints, access, risks, commit evidence, and verification requirements.
4. Yes. A line-by-line sweep of sections 1–9 found no request for owner judgment. The only owner-level facts are already settled and consolidated in section 0 with an explicit instruction not to re-ask them.
