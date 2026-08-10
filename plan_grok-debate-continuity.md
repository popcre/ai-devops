# Plan: make Grok debates complete, repeatable, and cache-efficient

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Create the shared debate template | ⬜ open | 2026-08-09 | Not started |
| 2. Update Grok and align GLM skills | ⬜ open | 2026-08-09 | Not started |
| 3. Preserve the wrapper unless evidence changes scope | ⬜ open | 2026-08-09 | Not started |
| 4. Extend Grok offline tests | ⬜ open | 2026-08-09 | Not started |
| 5. Run the live debate within $0.75 | ⬜ open | 2026-08-09 | Not started |
| 6. Document, install, commit, and push | ⬜ open | 2026-08-09 | Not started |

Fresh sessions start at the first open row and update this table after every completed gate. This plan owns the shared debate template and must land before `plan_kimi-debate-context-continuity.md`. Before editing or pushing, pull `origin/main`, inspect concurrent work, and create one write-once `HANDOFF.d/<UTC>-<machine>-<agent>-grok-debate-continuity.md` file cross-linked to this plan. Do not run this and the Kimi plan concurrently.

Planning record: `HANDOFF.d/2026-08-10T0000Z-albt16-codex-delegate-integration-plans.md`.

## 1. Ultimate goal

Claude or Codex must be able to hold a real multi-turn code or implementation-plan debate with Grok, carry the other model's exact reasoning across turns, preserve Grok's conversation and prompt cache, and stop only when disagreements are resolved or clearly documented. If a step conflicts with this goal, the goal wins: stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is Albert's multi-model coding-workflow toolkit. `bin/ai-grok-review` drives the local Grok Build CLI in named read-only sessions for Claude and Codex. The shared skill is `skills/shared/grok-cli/SKILL.md`; tests are in `tests/test-ai-grok-review.sh`. Work is on `main` at `C:\repos\ai-devops`. Grok 0.2.118 is installed locally and authenticated; the wrapper pins `grok-4.5`.

## 3. What triggered this work

The 2026-08-09 audit found strong exact-session resume and measured cache reuse, but no standard debate relay. The GLM skill tells the parent how to carry another model's actual reasoning; the Grok skill only describes a self-contained first brief. This leaves debate quality dependent on each Claude/Codex session remembering what background to include and when agreement is genuine.

## 4. Scope

In scope: a shared debate message contract; wrapper/skill support that keeps prompts stable; explicit convergence criteria; exact reasoning and evidence relay; tests for named-session reuse and cached tokens; documentation.

Out of scope: changing Grok model, permissions, cost controls, max-turn behavior, implementation mode, memory policy, web access, authentication, or Grok's own session store; automating unbounded model-to-model loops; allowing Grok to edit during reviews.

## 5. Current code state

- `bin/ai-grok-review:16-20` freezes model/permissions/cache-relevant settings.
- `bin/ai-grok-review:118-149` keys and locks sessions by repo, caller, and name.
- `bin/ai-grok-review:198-316` validates terminal `stopReason` and reports tokens/cache/cost/model.
- `bin/ai-grok-review:335-347` reads prompt files; `:518-524` refuses cache-prefix drift.
- `skills/shared/grok-cli/SKILL.md:32-57` covers resume and first-brief quality, but has no debate-relay section.
- `bash tests/test-ai-grok-review.sh` produced 50 passed, 0 failed on 916-alien on 2026-08-09. No debate-convergence fixtures exist.
- Repo base before planning: `00e1231fe9b2aae209764bb50ced2d4d844ff015`.

## 6. Findings and root cause

Continuity at the CLI layer is good: explicit session ID, stable prefix, caller separation, and measured cache reads. The missing layer is semantic continuity. “Continue this session” does not ensure the parent relays the disputed claim, the other model's reasoning, changed plan/diff, new test evidence, and a precise request for adjudication. Without that contract, Grok may agree with a summary it never verified or repeat old conclusions after the source changed.

## 7. Rejected approaches

1. Paste the whole plan/diff on every turn. Rejected because Grok can read files and changing a large prefix wastes cache.
2. Start a fresh Grok session for each objection. Rejected because it loses the conversation and measured cache benefit.
3. Tell Grok only “Claude disagrees.” Rejected because it omits the claim and reasoning needed for adjudication.
4. Let two models call each other indefinitely. Rejected because it is expensive and has no trustworthy stop condition.
5. Treat “I agree” as consensus. Rejected unless Grok re-inspected current files/evidence and states that no material objection remains.
6. Put speaker identity in a mutable system prompt. Rejected because it changes the cached prefix; speaker/evidence belongs in ordinary turn text.

## 8. Design decisions

Locked on 2026-08-09: use the existing named session; exact file paths instead of pasted source; ordinary message text for relayed arguments; retain caller separation, read-only permissions, `--no-memory`, model pin, max turns, output/cost gates; bounded debate of initial review plus at most three rebuttal turns unless the user explicitly asks otherwise. Default total Grok debate ceiling is **$1.50**, including the initial turn. After every turn, add the reported `total_cost_usd`; estimate the next turn as the largest per-turn cost observed in that session, or $0.46 before the first resume. Stop if the estimate would exceed the ceiling and report unresolved objections. The live acceptance debate has a separate **$0.75** ceiling and may use fewer turns.

Skill-only is the locked default. Do not change `bin/ai-grok-review` unless implementation first records a concrete missed-context failure that skill/template guidance cannot prevent and a measured benefit that outweighs a new wrapper surface.

## 9. Ordered implementation plan

1. Create the reusable contract at `templates/delegation/debate-turn.md`; this plan owns that file. Required stable fields: goal; disputed claim; faithfully attributed reasoning from the other model; current plan/diff paths; new test/runtime evidence; constraints; what changed; claim-by-claim confirmed/unsupported/wrong request; material objections; required correction; consensus question; and a compact consensus ledger of agreed decisions, rejected alternatives, unresolved objections, evidence needed, and last verified commit/path state. Gate: it is provider-neutral, self-contained, contains no repo-specific facts, and has stable headings/order.
2. Update `skills/shared/grok-cli/SKILL.md` with a bounded convergence loop and align `skills/shared/ask-glm/SKILL.md` to reference the same template while retaining GLM-specific mechanics. Run `list`, reuse the exact session, ask the delegate to re-read paths, verify claims, revise the artifact/ledger, then send only the delta and objections. Stop on evidence-backed consensus, the turn bound, or the $1.50 ceiling. Gate: one contract covers Grok and GLM without duplicating field definitions.
3. Keep `bin/ai-grok-review` unchanged unless the measured-failure criterion in section 8 is met. If it is met, stop and amend this plan before wrapper work; do not let the implementation session improvise validation.
4. Extend `tests/test-ai-grok-review.sh` with static skill/template fixtures proving the required fields, exact resume guidance, unchanged frozen prefix, current paths, cached-token/cost reporting, bounded stop/cost guidance, and no permission broadening. Missing terminal verdict/`stopReason` remains a wrapper failure; missing debate headings are skill-review failures, not runtime regex rejection. Gate: offline suite exceeds 50 tests with zero failures.
5. Run a live Grok plan debate with the current Codex parent as objector; Codex CLI is not a prerequisite. Record cache and cost after each turn and stop at $0.75. Gate: same session ID, cache-read evidence on resumed turns, current file re-read, and a verdict with zero material objections or explicit unresolved items within budget.
6. Update `docs/architecture.md`, `docs/development.md`, `docs/skills-usage-guide.md`, this STATUS table, and installed Claude/Codex skills. `AGENTS.md` already routes these plans; edit it only if names or trigger text change. Pull/recheck status immediately before the focused commit, push `main`, and verify the remote SHA. Gate: installed skill hashes match source and the worktree is clean.

Natural cut: after step 2. Re-read steps 3-6 before starting a fresh implementation session.

## 10. Tests required

- Stable debate-template headings and required evidence fields.
- Same session ID and caller-specific record across rebuttal turns.
- Frozen model/permission/cache prefix unchanged.
- Resumed live turn reports cache-read tokens, model, turns, and cost.
- Missing verdict or terminal `stopReason` fails loudly; missing evidence is caught by the skill/template audit, not a new wrapper parser.
- Bounded debate reports unresolved points rather than pretending agreement.
- Existing 50 tests and read-only canary remain green.

## 11. Constraints and gotchas

Main-only; correct Albert author/committer; Grok reviews remain read-only; never read `~/.grok/auth.json`; do not claim Windows OS sandbox protection; no unbounded loops; never broaden permissions to cure a turn limit; never paste secrets or whole files; keep the prompt opening/headings stable; label Grok's conclusion separately; record real cost; preserve unrelated changes.

## 12. Access and environment

Grok 0.2.118 at `%USERPROFILE%\.grok\bin\grok.exe`, authenticated with grok.com; the current Codex parent supplies objections; wrapper and skill are installed for Claude/Codex; Git Bash runs tests; `gh` is authenticated. No separate Codex CLI run, 1Password read, browser, production, DB, or deployment access is required.

## 13. Definition of done, risks, and open questions

Done: shared debate contract; skill gives exact bounded loop; wrapper support only if justified; offline/live tests green; resumed cache measured; real plan debate reaches evidence-backed consensus; docs/router/installed skills updated; correct commit pushed and remote-verified. CI/deploy are N/A because this repo has neither.

Risks: over-structured prompts could waste tokens; forced agreement could hide uncertainty; copied reasoning could distort the speaker; live tests cost money. The $1.50 normal and $0.75 live ceilings bound cost. Roll back with Git revert and reinstall skills. Wrapper validation is out of scope unless a measured failure first causes this plan to be amended.

## Mandatory self-audit

1. Yes. Sections 2-6 define the toolkit, gap, and exact files; sections 8-10 give decisions, steps, and gates.
2. Yes. Sections 6-8 preserve the difference between CLI continuity and semantic continuity plus every rejected shortcut.
3. Yes. Section 1 defines evidence-backed debate as the goal and makes it override a bad step.

All 13 sections and checklist items pass, including scope, tests, access, risks, rollback, commit/push, and N/A CI/deploy. Self-audit passed on 2026-08-09.
