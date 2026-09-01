# IMPLEMENTATION PLAN — reviewer-assisted problem solving (2026-08-31)

Linked handoff: [`HANDOFF.d/2026-08-31T2325Z-edge-dev-codex-reviewer-problem-solving-plan.md`](HANDOFF.d/2026-08-31T2325Z-edge-dev-codex-reviewer-problem-solving-plan.md)
Tracking issue: [#198](https://github.com/popcre/ai-devops/issues/198)

## STATUS

| Step | Status | Evidence |
|---|---|---|
| 0. Reconfirm current reviewer and repository state | ⬜ open — 2026-08-31 | Re-run the commands in Step 0; this plan was written against `a66586dccf5e1a889533a8cc633b45e31861c94d` |
| 1. Add the shared problem-solving skill | ⬜ open — 2026-08-31 | Pending `skills/shared/reviewer-problem-solving/SKILL.md` |
| 2. Add the universal stuck-escalation trigger | ⬜ open — 2026-08-31 | Pending aligned edits to both global templates |
| 3. Register and document the route | ⬜ open — 2026-08-31 | Pending router, skills-map, usage-guide, and architecture updates |
| 4. Add behavioral and trigger tests | ⬜ open — 2026-08-31 | Pending committed test and eval artifacts |
| 5. Independently review, ship, install, and verify | ⬜ open — 2026-08-31 | Pending exact-head review, CI, merge SHA, and installed-state evidence |

**Fresh-session starting point:** Step 0. No implementation has started. Re-read the whole plan, especially §§8, 11, and 13, before editing; update this table immediately after each completed step.

## 1. The ultimate goal — what we are trying to achieve

When a Claude or Codex session is genuinely struggling with a difficult problem, it should be able to bring in a healthy independent reviewer as a diagnostic partner while the evidence is still being gathered. Albert should get a faster, better-supported solution instead of watching one model repeat variations of the same unsuccessful theory. The original session remains responsible for deciding what is correct, making any change, preserving the intended capability, and proving the result.

This is not a new approval gate and not routine delegation. It is a bounded escalation for a session that has made real attempts but still lacks a reliable diagnosis or path forward. If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his Claude, Codex, and external-reviewer workflow. It contains Bash and PowerShell commands, shared skills, always-loaded instruction templates, tests, and documentation. It is not a hosted application and has no application deployment. GitHub `main` is the source of truth; installation copies skills and safely adopts global instructions onto Windows and Ubuntu machines.

The relevant reviewer providers are Claude, Codex, DeepSeek, Gemini, GLM, Grok, Kimi, Muse, and Qwen. Their existing wrappers and provider-specific skills already support some combination of read-only repository analysis, diagnosis, second opinions, and bounded debate. This plan adds the missing session-level decision contract that recognizes being stuck and routes to those existing capabilities.

Repository policy is defined by the live `AGENTS.md` and `config/repository-policy.json`. At the planning baseline, work uses a `codex/` feature branch, pull request, required checks, and merge queue/authorized merge tooling rather than a direct push to protected `main`.

## 3. What triggered this work

Albert asked on 2026-08-31 whether chat sessions would benefit from asking reviewers to help solve a problem the session is having a hard time with, instead of using reviewers only after code has been written. The answer was yes: current tools can do the diagnostic work, but ordinary sessions are not given a clear, shared rule for when to escalate, what evidence to send, or how to distinguish diagnostic advice from formal approval.

This is a workflow capability request, not a reproducible software crash. The current gap is observable by reading the always-loaded global templates and skill triggers: the globals discuss broad subagent delegation but contain no reviewer-assisted stuck rule (`templates/system/AGENTS-global-codex.md:121-139`; `templates/system/CLAUDE-global.md:121-125`), while provider skill descriptions mostly trigger when Albert names a provider (`skills/shared/ask-glm/SKILL.md:3`, `skills/shared/deepseek-second-opinion/SKILL.md:3`, `skills/shared/grok-cli/SKILL.md:3`, and `skills/shared/qwen-code/SKILL.md:3`).

## 4. Scope — in and out

### In scope

- One shared Claude/Codex skill that owns the evidence-based stuck threshold, reviewer choice, diagnostic brief, bounded interaction, and hand-back contract.
- A short universal rule in both global templates telling sessions when to load that skill.
- Provider-neutral guidance that uses existing read-only reviewer wrappers and their provider-specific skills.
- Explicit separation between diagnostic assistance and exact-head formal approval.
- Tests for positive triggers, near-miss non-triggers, global parity, privacy, boundedness, ownership, and installation.
- Documentation, installation on this machine, and live verification that both installed clients received the rule and skill without losing machine-specific sections.

### NOT in this plan

- Changing any reviewer wrapper, provider model, credential, allowance, timeout, sandbox, evidence packet, lifecycle, scoreboard, or formal approval contract.
- Building an automatic fastest-provider picker. `bin/ai-review-scoreboard:1-7` explicitly records that current measurements do not justify one.
- Allowing reviewers to edit code during a stuck escalation. Any later write delegation remains separately authorized and follows the provider's implementation skill.
- Making reviewer advice authoritative, counting it as acceptance, or replacing tests and live verification.
- Triggering on the first error, ordinary uncertainty, a long task, waiting for external state, missing authority, or a decision only Albert can make.
- Shared-database routing changes, production actions, secrets work, UI work, or changes to other repositories.

## 5. Current state of the code

- The repository baseline is commit `a66586dccf5e1a889533a8cc633b45e31861c94d` on `origin/main`, verified when this plan was created. Reconfirm before implementation because `main` is active.
- Existing provider skills already cover useful problem-solving modes:
  - GLM explicitly supports debugging and architecture debate (`skills/shared/ask-glm/SKILL.md:76-77`).
  - DeepSeek explicitly accepts a diagnosis, debugging theory, configuration, or plan (`skills/shared/deepseek-second-opinion/SKILL.md:8-13`, `187-188`).
  - Kimi supports the `analysis` review kind (`skills/shared/kimi-code-delegation/SKILL.md:36-37`).
  - Grok and Qwen support read-only analysis and bounded debate (`skills/shared/grok-cli/SKILL.md:87-101`; `skills/shared/qwen-code/SKILL.md:50-64`).
- `templates/delegation/debate-turn.md` already provides a provider-neutral continuing-debate shape. It is suitable after an initial diagnostic turn; it does not define when an ordinary session should escalate.
- `docs/architecture.md:72-111` documents persistent debate continuity and the rule that current artifacts must be re-read. It does not define stuck escalation or distinguish diagnostic output from approval.
- `ai-review-preflight` already rejects or temporarily quarantines unhealthy providers. `ai-review-scoreboard` records outcomes but deliberately does not choose a provider.
- Shared skills install automatically from any `skills/shared/<name>/SKILL.md` directory through `bin/ai-install-skills` (`docs/skills-usage-guide.md:65-80`). Global replacements use `bin/ai-adopt-globals` so machine sections are backed up, restored, and compared.
- Trigger quality is governed by `config/skill-trigger-policy.json`, committed eval JSON under `tools/skill-trigger-eval/`, and `tests/test-skill-trigger-policy.sh`.
- No implementation file for this capability exists, and no code, test, installation, or live behavior proof has been completed. This planning branch contains only the plan, its handoff, and discoverability links.

## 6. Key findings and root cause

1. **The capability exists below the session level, but the route does not.** Reviewer wrappers can analyze and debate, yet normal sessions receive no universal instruction to use them after repeated failed diagnostic work. The result is an avoidable behavior gap, not a missing model feature.
2. **Provider-named triggers cannot solve provider-neutral escalation.** Expanding every provider description to fire on “I am stuck” would make several skills compete for the same event and could cause fan-out. One shared coordinating skill must own the generic trigger and then load exactly one provider skill.
3. **“After two errors” is the wrong trigger.** Errors may be unrelated or routine. The meaningful threshold is two distinct, evidence-based hypotheses or repair attempts that fail to explain or remove the same symptom, or one explicit contradiction that the session cannot resolve from available evidence.
4. **The reviewer must receive a diagnosis packet, not the entire chat.** The minimum useful brief is: desired behavior, observed symptom, exact evidence, attempted hypotheses and their outcomes, constraints, current best theory, and one concrete question. Raw transcripts increase cost, expose irrelevant/private material, and reduce clarity.
5. **Diagnostic advice is not approval.** A reviewer may reason from a dirty or changing diagnostic snapshot. Formal approval remains a separate exact-head, current-evidence operation after implementation and tests.
6. **Health and eligibility matter, but automatic ranking is not justified.** The selected provider must pass its existing preflight and must not be the same model/agent whose reasoning needs an independent check. Scoreboard history may inform judgment but must not become an automated speed ranking in this work.
7. **A failed reviewer call is not permission to grind through providers.** Record a genuine reviewer malfunction through `log-reviewer-issue`; otherwise choose at most one alternate healthy provider. The primary session must then continue from evidence or report the real blocker.

## 7. Approaches considered and REJECTED, and why

- **Use reviewers only after implementation.** Rejected because it misses their highest-value contribution when diagnosis, design, or evidence interpretation is the bottleneck.
- **Ask all available reviewers in parallel.** Rejected because it multiplies cost, creates conflicting advice, consumes reviewer capacity, and encourages opinion shopping. One independent reviewer is the default; a second is allowed only after an unusable first call or a clearly stated unresolved disagreement.
- **Trigger on the first failure or whenever a task feels hard.** Rejected because routine debugging would become slower and more expensive. A session must first perform bounded evidence gathering and test distinct hypotheses.
- **Automatically select the fastest or historically “best” provider.** Rejected because `bin/ai-review-scoreboard` says current evidence does not justify that front door, and recent speed is not proof of suitability for a particular diagnosis.
- **Modify every provider skill to self-trigger on generic difficulty.** Rejected because several skills could trigger together and no single place would own threshold, privacy, boundedness, and hand-back behavior.
- **Add a new wrapper that sits in front of all reviewers.** Rejected for this version because the existing wrappers, preflight, and skills already provide the required execution mechanisms. A routing skill plus global trigger is fewer moving parts and can be measured before any CLI automation is justified.
- **Treat the diagnostic review as formal approval if it says APPROVE.** Rejected because the question and evidence are different, and source may move during diagnosis. Approval must be requested separately against the exact final head.
- **Paste the full conversation or raw logs.** Rejected because it is costly, noisy, and risks leaking secrets or licensed/private data. The primary session must curate only the necessary safe evidence.

## 8. Design decisions already made (2026-08-31)

### LOCKED — do not relitigate during implementation

1. The capability is proactive: a session may invoke it without Albert naming a reviewer once the evidence-based stuck threshold is met.
2. The generic route is one new shared skill, installed for both Claude and Codex. Do not create duplicate client-specific versions.
3. The primary session owns the work throughout. The reviewer diagnoses; it does not silently take over implementation, commit, push, merge, or contact people.
4. Default to one reviewer. Allow one alternate only when the first provider is unhealthy, fails to return a usable answer, or leaves a material evidence-backed disagreement.
5. Select a different model/provider from the struggling primary session when possible, run the provider's existing preflight, and obey its own skill. Do not create an automatic ranking algorithm.
6. The diagnostic brief contains only the safe minimum evidence and never raw secrets, licensed/private source data, credentials, environment dumps, process command lines, or full transcripts.
7. The result must be reduced to testable hypotheses or next checks. The primary session independently verifies it before changing anything.
8. Diagnostic output never satisfies a formal review/approval requirement. After code changes, use the existing exact-head review path independently.
9. Being blocked by missing authority, an owner decision, or external state is not “stuck”; do not call reviewers to manufacture permission or speculate around a hard stop.
10. Reviewer malfunction handling remains with `log-reviewer-issue`; do not weaken a wrapper, broaden permissions, raise timeouts, or bypass quarantine.

### OPEN — implementer judgment within stated criteria

1. **Exact skill name:** prefer `reviewer-problem-solving`; change only if trigger evaluation shows a clearer non-colliding name.
2. **Location of the global paragraph:** place the same semantic rule near cost/delegation guidance in both templates, while preserving client-specific surrounding text and context budgets.
3. **Provider-choice examples:** name enough existing providers to make the route executable, but keep the procedure provider-neutral and avoid a permanent preference order.
4. **Trigger wording:** tune the skill description using committed positive and negative evals. It must catch repeated failed diagnosis while declining routine first failures, explicit provider requests (which belong to provider skills), approval reviews, owner decisions, and external waits.

## 9. The plan — numbered, ordered, executable steps

### Phase A — establish current truth and the shared contract

#### Step 0 — Reconfirm the baseline and active reviewer constraints

1. Start from a clean current `origin/main` in an isolated checkout. Read the live `AGENTS.md`, `config/repository-policy.json`, `bugs.md` reviewer status, any open handoff that explicitly matches issue #198, and the STATUS tables of any provider plan the implementation must touch.
2. Run `git status --short`, `git fetch origin`, `git rev-parse origin/main`, and inspect open reviewer issues. Do not reuse the planning SHA as current proof.
3. Confirm the Windows self-hosted runner is idle before running local reviewer suites or live reviewer qualification. Planning and ordinary static tests do not require reviewer capacity.
4. Confirm no concurrent session owns the files planned below. Preserve unrelated changes and use the repository's current branch policy.

**Verification gate:** record the fresh base SHA and policy in this plan's STATUS evidence; `git status --short` is clean before edits, and every touched provider-specific plan or handoff has been identified.

#### Step 1 — Create the shared `reviewer-problem-solving` skill

Add `skills/shared/reviewer-problem-solving/SKILL.md`. Its frontmatter description must cover a session that has tried multiple evidence-based approaches but still cannot diagnose or solve the same problem, while avoiding generic words that trigger on every bug.

The body must define this exact flow:

1. **Qualify the escalation.** Require either two distinct failed evidence-based hypotheses/repairs for the same symptom, or a material contradiction the primary session cannot resolve after focused inspection. Explicitly exclude first failures, wide reads, ordinary reviews, external waiting, owner decisions, and missing authority.
2. **Freeze and summarize current evidence.** State desired behavior, observed behavior, reproducible evidence, attempts and outcomes, constraints, current theory, and the single question the reviewer must answer. Point the reviewer to current safe files; never paste a full chat or uncontrolled logs.
3. **Choose one eligible independent provider.** Use a provider different from the primary model when possible. Consult current quarantine/health evidence and run the selected provider's existing preflight through its wrapper/skill. Do not rank automatically or fan out.
4. **Run read-only diagnosis.** Load and follow exactly one provider-specific skill. Use its analysis/architecture/second-opinion mode, a named session where supported, and `templates/delegation/debate-turn.md` only for a necessary follow-up. The prompt must request testable hypotheses, discriminating checks, and risks—not a generic verdict.
5. **Evaluate, do not obey.** Label the reviewer's conclusions separately, compare each claim with repository/live evidence, reject unsupported suggestions, and choose the next diagnostic or repair action. Any mutation is performed by the primary session under the original task authority.
6. **Bound the loop.** Default to one turn plus one focused follow-up. Permit one alternate provider only for unusable output, failed preflight/provider health, or a material unresolved disagreement. Never rotate reviewers to obtain a preferred answer.
7. **Hand back cleanly.** Report the diagnosis adopted or rejected, the evidence, the next action taken, and whether formal review remains required. If the reviewer itself fails, invoke `log-reviewer-issue` with secret-safe evidence.

Include short templates for the initial diagnostic brief and the primary session's evaluation record. Link the existing provider skills rather than duplicating their commands or safety procedures.

**Dependencies:** Step 0.
**Verification gate:** a reader with no chat context can use the skill to decide whether escalation applies, choose exactly one reviewer, construct a safe brief, bound the exchange, and continue without confusing diagnosis with approval.

#### Step 2 — Add the universal trigger to Claude and Codex

Edit both `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md` with semantically matched concise wording. The rule must say that after two distinct evidence-based attempts fail to explain or remove the same symptom—or after an unresolved evidence contradiction—the session should load `reviewer-problem-solving` and obtain one independent read-only diagnosis before continuing to grind. It must also state that this is not for first failures, missing authority, owner decisions, or external waits, and that the original session still owns implementation and verification.

Do not copy the full procedure into globals; the shared skill owns it. Keep GPT-5.6 reasoning restrictions unchanged. Update `tools/context-audit/context-audit.py` safety/parity markers only if its existing semantic comparison cannot recognize the new aligned rule; do not weaken budgets or unrelated markers.

**Dependencies:** Step 1 establishes the canonical behavior.
**Verification gate:** `python tools/context-audit/context-audit.py --root . --claude-home <test-or-real-home> --codex-home <test-or-real-home> --json .ai/context-current.json --strict` reports no missing safety rule, parity mismatch, or budget warning, and both templates route to the same shared skill.

### Phase B — discoverability and measurable behavior

#### Step 3 — Register and document the route

Update:

- `AGENTS.md`: add a task-router row for a session struggling with a diagnosis or repeated repair, pointing first to this plan's STATUS and then the shared skill. Remove or replace the temporary planning-only link when the plan reaches completion, but retain a durable route to the skill/docs.
- `docs/skills-map.md`: add the shared skill under Quality & analysis with plain trigger examples and non-trigger boundaries.
- `docs/skills-usage-guide.md`: document that the global rule may invoke this skill proactively, how shared installation reaches both clients, and that diagnosis is distinct from approval.
- `docs/architecture.md`: add a concise “Reviewer-assisted problem solving” section before delegate debate continuity. Link this plan while it is open; retain the durable architecture after completion.
- `docs/skill-trigger-eval.md`: only if a new lesson about internal/proactive triggers is discovered during evaluation. Do not add speculative measurements.

Do not change provider-specific skill descriptions merely to make the generic trigger fire. Provider-specific explicit requests must continue to route directly to those skills.

**Dependencies:** Steps 1-2.
**Verification gate:** every relevant router leads a fresh session to one canonical procedure, Markdown links resolve, and no duplicate generic trigger exists across provider skills.

#### Step 4 — Add tests that prove useful triggering without reviewer spam

1. Create `tools/skill-trigger-eval/reviewer-problem-solving.eval.json` with at least eight realistic positives and eight near-miss negatives. Positives must include repeated failed repairs, conflicting evidence, repeated nondeterministic reproduction, and a session explicitly saying its current theory is exhausted. Negatives must include a first failure, a routine code review, “ask Grok/GLM/etc.”, an owner decision, missing production authority, waiting for CI, a wide repository read, and a reviewer wrapper malfunction.
2. Add `reviewer-problem-solving` to `config/skill-trigger-policy.json` so balanced cases and repeated evaluation are mandatory on Windows and Linux.
3. Add `tests/test-reviewer-problem-solving-skill.sh` as a fast structural/behavior-contract test. It must assert:
   - both globals route to the skill with aligned threshold semantics;
   - the skill requires two distinct attempts or an unresolved contradiction;
   - one reviewer is the default and only one alternate is allowed under named conditions;
   - preflight/provider-specific skills remain mandatory;
   - raw chats, secrets, licensed/private data, and uncontrolled logs are prohibited;
   - primary-session ownership and independent verification are explicit;
   - diagnostic help is never formal approval;
   - missing authority, owner decisions, and external waits are excluded;
   - `log-reviewer-issue` remains the reviewer-failure route.
4. Register the new test in the repository's appropriate offline suite if discovery is not automatic. Do not add a live provider call to ordinary CI.
5. Run `bash tests/test-reviewer-problem-solving-skill.sh`, `bash tests/test-skill-trigger-policy.sh`, `bash tests/test-ai-install-skills.sh`, `bash tests/test-ai-adopt-globals.sh`, and the repository's complete offline verification commands from `docs/development.md`.
6. Run the trigger eval at the required repeated count on both supported platforms per `docs/skill-trigger-eval.md`. Record raw JSON artifacts under the established verification tree. Tune only the new skill description; no positive miss or negative false trigger may be dismissed without evidence.

**Dependencies:** Steps 1-3. Test authoring can proceed alongside documentation after the skill contract stabilizes.
**Verification gate:** all structural and offline suites pass; committed evals meet policy on Windows and Linux with zero protected near-miss false triggers, and the STATUS table links the exact artifacts rather than quoting unsupported counts.

### Context cut point

After Step 4, use `fresh-session` if the working context is large. The new session must re-read Steps 5, §§11-13, the current STATUS table, live issue #198, and any new reviewer incident before proceeding. Any source edit after review makes exact-head approval stale.

### Phase C — independent review, landing, and live installation

#### Step 5 — Review, ship, install, and verify the real behavior

1. Because installed routing rules and reviewer safety behavior changed, obtain one read-only exact-head final review from an eligible model other than the implementer. The review must cover both global templates, the new skill, trigger evals, structural tests, privacy boundaries, and the distinction between diagnosis and approval.
2. Correct every evidence-backed finding, rerun affected tests, and obtain a fresh exact-head review after the final commit. Do not reuse approval after any edit, rebase, or merge.
3. Verify `git var GIT_COMMITTER_IDENT` is exactly `Albert Hazan <u2giants@users.noreply.github.com>`. Commit only issue #198 files, push the feature branch, open the pull request, and follow current repository policy through required checks and merge. Confirm the merge commit is on `origin/main`.
4. From a clean current `main` on this Windows machine, run the supported installation/adoption path. Use `bin/ai-adopt-globals` (or the documented native Windows equivalent where required) so both existing machine sections are backed up, re-appended, and byte-compared. Run `bin/ai-install-skills` through the supported Git Bash path so the shared skill reaches both clients.
5. Verify on disk—not from source alone—that:
   - Claude and Codex each have the installed `reviewer-problem-solving` skill;
   - their installed global bodies match the repository templates while machine sections remain intact;
   - an isolated positive trigger probe offers one read-only diagnostic reviewer;
   - first-failure, owner-decision, and external-wait probes do not invoke it;
   - the positive probe labels reviewer advice separately and keeps implementation with the primary session.
6. Save repository-safe installation and probe evidence under `tests/verification/reviewer-problem-solving/<UTC>/`. Never commit raw prompts, provider streams, credentials, private paths that reveal secrets, licensed data, or unredacted machine-local configuration.
7. Update this plan STATUS with merge SHA, CI run, exact-head review artifact, installation artifact, and trigger evidence. Close issue #198 only after all acceptance evidence is current. Delete this handoff in the completion commit under the successor rule; retain the completed plan as a decision record and update the router to its durable skill/doc destination.

**Dependencies:** Steps 0-4; runner must be idle for local reviewer suites.
**Verification gate:** exact-head review is current, required CI is green for the merged source, the merge SHA is on `origin/main`, both installed clients prove the new behavior and preserved machine sections, issue #198 is closed, and no open handoff falsely claims unfinished work remains.

## 10. Tests required

### New committed tests

- `tests/test-reviewer-problem-solving-skill.sh` with the nine contract assertions listed in Step 4.
- `tools/skill-trigger-eval/reviewer-problem-solving.eval.json` with at least eight positive and eight negative prompts.
- A repository-safe verification record under `tests/verification/reviewer-problem-solving/<UTC>/` containing exact commands, source SHA, platform, results, and redacted trigger-probe conclusions.

### Existing tests and gates that must remain green

- `bash tests/test-skill-trigger-policy.sh`
- `bash tests/test-ai-install-skills.sh`
- `bash tests/test-ai-adopt-globals.sh`
- `bash tests/test-session-conduct-policy.sh`
- `python tools/context-audit/context-audit.py ... --strict` with the documented current homes or isolated fixtures
- The complete Linux and Windows offline verification suites named by `docs/development.md`
- The new trigger eval at the policy-required repeated count on Windows and Linux
- One fresh read-only exact-head final review after the final source commit
- All required GitHub checks for the pull request/merge commit

Tests must fail closed. Do not weaken assertions, increase timeouts, lower trigger-eval minimums, exclude difficult negatives, or claim a cancelled/in-progress CI job as evidence.

## 11. Constraints, standing rules, and gotchas in force

- This public repository must never receive secrets, raw reviewer streams, private transcripts, licensed source data, or machine-local `.env` values.
- Preserve reviewer capability. Do not disable, bypass, replace, or weaken a reviewer because preflight or a test fails; diagnose the real failure and use `log-reviewer-issue` where applicable.
- Reviewers remain read-only for this diagnostic route. Write-capable implementation modes require separate explicit authorization and are outside this plan.
- A diagnostic opinion is advisory. It cannot satisfy exact-head review, production acceptance, a database gate, or an owner decision.
- Keep the new generic trigger in one shared skill. Both globals get only the short universal route; provider skills keep their explicit-provider triggers.
- Do not use subagents as a substitute for external reviewer independence. A subagent of the same primary model is useful for breadth but does not satisfy the “different reasoning” preference.
- Do not run local reviewer suites while the shared Windows CI runner is busy. A cancelled CI job is not a result.
- GPT-5.6 runs only at low or medium reasoning.
- Preserve unrelated work. Work from a clean isolated checkout, stage only issue #198 files, never force-push, and rederive current branch policy from the live repository.
- Global installation must preserve machine-specific sections through the supported adopter and backups. A source edit alone is not deployment.
- Any source change after exact-head review invalidates that review. Any rebase/merge changes the reviewed head and requires fresh evidence as defined by the current reviewer path.
- Update this plan as work happens. A stale STATUS/current-state section is a workflow defect.

## 12. Access and environment

- Repository: `https://github.com/popcre/ai-devops` (legacy `u2giants/ai-devops` references may redirect to the same repository; verify the live remote rather than guessing).
- Tracking issue: `#198`.
- Planning baseline: `origin/main` at `a66586dccf5e1a889533a8cc633b45e31861c94d`; this is historical context, not authority for implementation.
- Planning checkout: `C:\tmp\ai-devops-plan-198`, branch `codex/reviewer-problem-solving-plan-198`. A successor may use a new clean checkout and must not assume this temporary path still exists.
- Primary repository checkout: `C:\repos\ai-devops` on Windows `edge-dev`; it contained unrelated concurrent edits during planning and must not be reset, cleaned, rebased, or broadly staged.
- GitHub CLI is authenticated for issue/PR operations. Verify the current account and remote before shipping.
- Run Bash tests through `C:\Program Files\Git\bin\bash.exe` on Windows as required by repository guidance.
- Machine-local reviewer credentials live outside the repository under the documented `/etc/ai-devops/` or Windows-supported configuration path and 1Password vault `vibe_coding`. This work should not need to read or print their values.
- There is no hosted deployment URL. Installation to Claude/Codex skill and global directories is the deployment mechanism; use the documented adopter/installer and its backups.

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] The shared skill implements the locked threshold, safe brief, one-reviewer default, bounded follow-up, primary ownership, and diagnosis-versus-approval separation.
- [ ] Both global templates contain aligned concise routing wording and strict context audit passes.
- [ ] Router, skills map, usage guide, and architecture make the capability discoverable without duplicating its procedure.
- [ ] Positive and negative trigger evals are committed and pass policy repeatedly on Windows and Linux.
- [ ] New structural tests and all affected/full offline suites pass.
- [ ] One eligible independent reviewer gives a current exact-head approval after the final source commit, with no unresolved material finding.
- [ ] Git identity is correct; issue-owned files are committed, pushed, reviewed, merged under current repository policy, and the merge SHA is confirmed on `origin/main`.
- [ ] Both installed clients contain the shared skill and matching global rule; machine-specific sections are proven preserved.
- [ ] Live/isolated behavior probes prove genuine stuck escalation and decline first-failure, owner-decision, and external-wait near misses.
- [ ] Repository-safe verification artifacts are committed; raw/private artifacts remain outside Git.
- [ ] Issue #198 is closed only after current evidence; the linked handoff is retired; this plan remains as an accurate completed decision record.

### Risks and rollback

- **Over-triggering reviewer calls:** cost and capacity rise, and routine debugging slows. Mitigate with negative evals and the two-distinct-attempts/contradiction threshold. Roll back the global route and skill together in a normal reviewed commit if live probes show unacceptable false triggers.
- **Under-triggering:** sessions continue grinding. Tune only the shared skill description against committed realistic positives; do not broaden every provider skill.
- **Opinion shopping:** multiple reviewers may be asked until one agrees. The contract limits the default to one and names the only alternate conditions.
- **Private-data leakage:** diagnostic context may contain more than formal diffs. The skill must require curated safe evidence and prohibit raw chats/logs/secrets/licensed data.
- **Approval confusion:** a useful diagnosis may be mistaken for a gate. Static tests and docs must explicitly separate the two lifecycles.
- **Broken installed globals:** adopting source templates can overwrite machine facts if done incorrectly. Use `ai-adopt-globals`, retain its backups, and compare restored sections before claiming deployment.
- **Concurrent source drift:** a long review or merge queue may stale evidence. Bind final review to the exact final head and rerun after any change.

### Open questions with decision criteria

- No owner decision is currently required. The exact skill name and phrasing are implementer judgments governed by zero near-miss false triggers, balanced cross-client behavior, and the locked design above.
- If evidence shows existing provider preflight cannot be called safely from a provider skill without wrapper changes, stop at that boundary and write a separate narrowly scoped plan. Do not silently expand issue #198 into reviewer-wrapper repair.
- If repeated evals cannot distinguish genuine stuck escalation from routine debugging, prefer under-triggering, record the ambiguous prompts, and bring the trigger wording—not a weakened test—to Albert as a product decision.

## Mandatory self-audit — final answers

1. **Could a brand-new AI session execute this plan without asking Albert anything? Yes.** §§2-6 define the product, trigger, existing capabilities, and missing route; §§8-9 lock the behavior and name exact files, sequence, dependencies, and verification gates; §§11-12 define operating constraints and access.
2. **Does the plan preserve all relevant background, nuance, and rejected approaches? Yes.** §§6-8 capture the root cause, diagnostic-versus-approval distinction, provider-selection limit, privacy boundary, threshold reasoning, and every rejected shortcut discussed or discovered.
3. **Is the ultimate goal clear enough to guide a correct judgment when a step is wrong? Yes.** §1 states the owner-facing outcome, primary-session accountability, bounded use, and the instruction that the goal wins; §13 supplies decision criteria and rollback for uncertain trigger behavior.

### Comprehensiveness checklist

- [x] All 13 required sections are present.
- [x] The plain-English ultimate goal and “goal wins” instruction are first.
- [x] A fresh session can execute without this chat.
- [x] Rejected approaches and reasons are explicit.
- [x] Every implementation step names files/behavior and ends with a verification gate.
- [x] Locked and open decisions are labeled.
- [x] Out-of-scope work is explicit.
- [x] Tests are named with required behaviors and commands.
- [x] Paths, identifiers, baseline SHA, environments, and terms are defined.
- [x] Secrets are referenced only by approved location, never value.
- [x] Completion includes review, commit, push, CI, merge, installation, live proof, issue closure, and documentation/handoff retirement.
- [x] The plan and this session's handoff link directly to each other.
