
The pipeline they say is "stricter" is still a scaffold. `AGENTS.md:388` says `ai-run-task` / `ai-model-call` are v0.1. `bin/ai-model-call:21-22` does not run stages in order. Independent review exists as prompt files, not as a finished machine.

The two plans used as the reason to port task IDs are the wrong records. The eval says they prove "a delegate reports success having done part of the work" (`docs/github-spec-kit-evaluation.md:109-113`, `plan_spec-kit-idea-adoption.md:86-89`). Both files are about a run that **stops early** and must leave a marked incomplete patch. Both are already **done** (`plan_kimi-incomplete-implementation-recovery.md:7-10`, `plan_glm-incomplete-implementation-recovery.md:7-10`). That is not "said done, wasn't." The wrappers already fail closed. Task IDs do not fix that class of bug.

**Different call:** do not install Spec Kit here. Do not port five ideas as a program. If anything is worth taking, it is a `tasks.md` table on **new** plans only. Skip the file move, the fake stage 00, and the spec/plan split until someone has read the real Spec Kit templates.

### 2. Putting converge in `fresh-session` games the budget

Yes. It obeys the meter and breaks the rule the meter is there to protect.

`tools/context-audit/budgets.json:8` says never raise a budget to hide a warning. The Claude skill list is 21,521 / 21,521 (`plan_spec-kit-idea-adoption.md:149`, `plan_spec-kit-idea-adoption.md:165-168`). A new `shared/` skill would add a `name: description` line to both clients (`tools/context-audit/context-audit.py:507-516`). Refusing a new skill for that reason is fair.

Then they write the new job into a skill **body**, because bodies cost zero on that meter (`plan_spec-kit-idea-adoption.md:169-172`, `plan_spec-kit-idea-adoption.md:218-225`). That is the hole.

Their own context doc says the opposite of what they are doing:

- The `name` plus `description` is how a skill gets picked. The body loads only after the pick (`docs/context-engineering.md:102`).
- A description is routing, and it is measurable (`docs/context-engineering.md:310`).
- They already saw a skill miss its own trigger phrase when the description was wrong (`docs/context-engineering.md:312-326`).

Step 11 forbids changing `fresh-session`'s `description:` (`plan_spec-kit-idea-adoption.md:475-476`). That description only fires on "fresh session?", "new context window?", and "hand this phase over" (`skills/shared/fresh-session/SKILL.md:3-12`). It will not fire on "what is left?", "did the delegate finish?", or "converge." So the highest-value idea is hidden behind the wrong phrase.

Worse, it is the wrong skill. `fresh-session` decides whether to start a new chat (`skills/shared/fresh-session/SKILL.md:34-45`). `close-old-session` already checks the repo against claims: git log, git diff, current files, then "done / still open / contradicted" (`skills/shared/close-old-session/SKILL.md:37-76`). That is converge. They even call the two skills forward vs backward halves (`skills/shared/fresh-session/SKILL.md:95-97`). Stuffing a repo audit into the cutover skill makes that skill worse at its real job.

Step 12 puts the same gate in `templates/delegation/debate-turn.md` (`plan_spec-kit-idea-adoption.md:481-486`). That file is a debate script (`templates/delegation/debate-turn.md:1-8`), not a "mark the task done" contract.

**Different call:** if the list is full, do not add a skill. Also do not hide a new job in a body you cannot advertise. Put the check in `close-old-session` (right trigger, already looks at the repo), or in the plan standard as a required last step. If you need a new trigger phrase, free the bytes by shortening some other `description:`. `budgets.json:14` already wants Claude down to 15,065. The handoff even says to schedule that trim (`HANDOFF.d/2026-08-13T1003Z-ccweb-claude-spec-kit-evaluation.md:54-59`). Do that first. Do not route around the cap.

### 3. The D2 + D3 flaw

D3 says move files first so later steps write the new paths once (`plan_spec-kit-idea-adoption.md:249`). D2 says do not move any plan an open `HANDOFF.d/` file names (`plan_spec-kit-idea-adoption.md:247`).

The stated reason for D3 is false. Phases 2–4 edit the **standard**, the stage-02 prompt, `fresh-session`, and a debate template (`plan_spec-kit-idea-adoption.md:362-489`). They do **not** rewrite the 11 moved plans. Those stay as-is, with no `spec.md` or `tasks.md` (`plan_spec-kit-idea-adoption.md:114-115`). Moving them first saves no later rewrite.

What phase 1 does spend is the last air in `AGENTS.md`. Ten path rewrites cost about 100 bytes against 136 left (`plan_spec-kit-idea-adoption.md:324-331`). That file is the live work of an **open** context-engineering plan (steps 8–10 still open, `plan_context-engineering-consolidation.md:17-19`). That plan's map still says forward work lives in `plan_<slug>.md` at the repo root (`docs/context-engineering.md:105`). Phase 1's rewrite list does not include `docs/context-engineering.md` (`plan_spec-kit-idea-adoption.md:309-322`). D2 protects the **filename** that workstream points at. It does not protect the **router and the ownership map** that workstream actually owns.

D2 also locks the wrong files:

- `plan_ai-glm-permission-failures.md` is **CLOSED**. The file says so on line 16. The leftover handoff says there is no code work and tells the next session to handle two owner items, then delete the handoff (`HANDOFF.d/2026-08-12T1959Z-al8960ofc-claude-glm-plan-closed-two-loose-ends.md:6-9`, `:29-31`). A finished note is being used as a forever lock on a record file.
- This plan cannot move because **its own** handoff names it (`plan_spec-kit-idea-adoption.md:247`). Step 3's grep is written to leave `plan_spec-kit-idea-adoption.md` in place (`plan_spec-kit-idea-adoption.md:346-348`). Step 13 then says move it after deleting that handoff (`plan_spec-kit-idea-adoption.md:498-502`). Nobody is assigned to fix the links that grep just blessed. The last move is unplanned breakage.
- Step 1 says: if `HANDOFF.d/` names no plans, **stop** (`plan_spec-kit-idea-adoption.md:276-279`). That is backwards. Empty handoffs are the safe time to move **all** of them.

The write-once rule forbids editing another session's **text** (`templates/system/handoff-standard.md:32-36`). It does not make every path inside that text a sacred layout. Those files are meant to be deleted when the work is done (`AGENTS.md:97-98`). Five of the seven current files are step notes from one context-engineering stream. The eval's own handoff already suspects step4–step6 are finished and should be gone (`HANDOFF.d/2026-08-13T1003Z-ccweb-claude-spec-kit-evaluation.md:48-52`). Basing a durable folder tree on leftover session notes inverts the design.

After phase 1 the root is not clean anyway. Three `plan_*.md` files stay (`plan_spec-kit-idea-adoption.md:302-303`). The doc map becomes two styles at once. `AGENTS.md:209-216` already says not to casually rename identifiers that scripts assume.

**The flaw in one line:** D3 spends the last router bytes, and breaks the open context map, to move files that later phases never touch. D2 treats leftover handoff links as a layout lock, then leaves this plan's own final move with no rewrite step.

### 4. What the evaluation missed entirely

- **It never opened Spec Kit.** README plus this repo. No generated `tasks.md`, no `analyze`, no `converge` prompt (`docs/github-spec-kit-evaluation.md:186-198`).
- **It asked the wrong adopt question.** Spec Kit is for app repos. This toolkit's job is to onboard those repos by hand (`docs/repo-onboarding.md:1-8`, `AGENTS.md:391`). "Should `/worksp/ai-devops` install `specify-cli`?" is easy to refuse. "Should a new app get Spec Kit's `specs/` layout under our onboarding docs?" was never asked.
- **Stage 00 is a ghost.** They add `templates/prompts/00-clarify.md` and a row in the pipeline skill (`plan_spec-kit-idea-adoption.md:428-456`) and refuse to touch `bin/` (`plan_spec-kit-idea-adoption.md:116-117`). `bin/ai-model-call:63-71` has no `clarify` stage. `docs/architecture.md:26-35` and `AGENTS.md:209` still list seven stages. Albert cannot run the new gate.
- **The "said done, wasn't" story cites the wrong closed plans**, as in §1. The real check already lives in `close-old-session`.
- **They froze skill routing.** New behavior that cannot change a `description:` will not fire. They already paid for that lesson (`docs/context-engineering.md:312-326`).
- **They collide with an open shrink-the-context plan** whose step 5 just cut `AGENTS.md` and ratcheted the budget (`plan_context-engineering-consolidation.md:11`). This work then adds two router rows and plans ten more path bytes (`plan_spec-kit-idea-adoption.md:152-157`, `:324-331`). That is the opposite of the live workstream.
- **Most of the 13 root plans are closed records**, not live work (see `AGENTS.md:63` for the GLM set). Moving 424 KB of finished history does not help a delegate take one task.

Do not start phase 1. If you want one useful change, add a `tasks.md` contract to `templates/system/implementation-plan-standard.md` for **new** delegated work, and put the repo check in `close-old-session`. Leave the root plans, the skill list, and Spec Kit itself alone.
