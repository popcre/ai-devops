---
issue: 253
status: OPEN
owner: grok/253-add-grok-child
---

# HANDOFF — add Grok child #513 under investigation Option B (2026-09-16 20:13 UTC, edge-dev/grok)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

Already settled — do NOT re-ask:

- **2026-09-03, Albert:** shell and internet investigation, least moving parts, Option B.
- **2026-09-16, Albert:** fix the plans (no bundled upgrades, independent children).
- **2026-09-16, Muse Spark:** `VERDICT: AGREE`; no material objections. Two notes already in the plan.
- **2026-09-16, Albert:** create a #253 child for Grok. That is #513. Same Option B. Do not implement #249 here.

## 1. What this application is

`popcre/ai-devops` is Albert's public backup-and-restore toolkit. Parent [#253](https://github.com/popcre/ai-devops/issues/253) owns named look-into-this mode for reviewers. The executable plan is [`../plan_reviewer-investigation-mode-option-b.md`](../plan_reviewer-investigation-mode-option-b.md).

## 2. What we set out to do this session, and why

Albert asked whether the corrected plans already contained Muse's fixes, and to create a child of #253 for Grok.

## 3. Current state — what is true right now

- Muse Spark session `253-plan-opinion` agreed with the corrected plan. No material objections. Its two notes (Qwen discovery repair only if Step 0 still mismatches; final step is labels/banners only, not a shared rewrite) were already in the 2026-09-16 plan. No extra Muse-driven rewrite was required.
- Grok child [#513](https://github.com/popcre/ai-devops/issues/513) exists as a sub-issue of #253. Option B: reuse `ai-grok-implement` isolated worktree and `--allow-shell`; keep `ai-grok-review` read-only; no pin upgrade; do not build #249.
- This commit updates the plan STATUS (Step 5 = #513, Step 6 = parent landing), parent issue #253, router, and index.
- `ai-grok-review` still denies Bash and disables web search. `ai-grok-implement` can allow Bash. No `investigate` command exists yet.
- After this planning session opened #513, another session landed `ai-grok-implement investigate` on `origin/main` `7f0f8f6c` (PR #517). Plan STATUS Step 5 is 🟡 landing. Do not redo #513.
- GLM #254, Kimi #255, Qwen #256, and Muse #257 remain unstarted. Parent #253 Step 0 and Step 6 remain open.
- Durable session notes from this planning chat also live in `docs/design-decisions.md` (investigation vs formal review; #253 vs #249; Muse caller `grok`) and `docs/architecture.md` (investigation pointer).

## 4. Everything we tried that did NOT work

- Treating Grok as already having this named mode. Formal Grok review is read-only. Implement is a write path, not an advisory look-into-this command.
- Folding #249 (brokered integration-review) into #513. Albert asked for a #253 child. Option B forbids the broker. #249 stays its own workstream.

## 5. Root causes and key findings

- Muse did not ask for new plan edits. Agreement plus notes already present.
- Grok's gap matches GLM/Kimi/Qwen: capable build path exists; named advisory investigate does not; formal review must stay locked down.

## 6. Exact next steps

1. Do not redo Grok #513. Confirm `ai-grok-implement investigate` on current `origin/main` and whether Step 5 still needs live canaries. **You'll know it worked when** the plan STATUS evidence cell for Step 5 names a verification artifact, not only the landing commit.
2. Start remaining implementation at plan Step 0, then #254, #255, #256, and #257 independently. **You'll know Step 0 worked when** the baseline artifact exists under `tests/verification/reviewer-investigation-option-b/`. **You'll know each child worked when** its issue holds redacted shell/internet canaries and unchanged formal review.
3. Parent Step 6 only after those children land. **You'll know it worked when** #253 is closed with current evidence and this handoff is deleted.

## 7. Constraints and gotchas in force

- Feature-branch-PR. Never push to `main`. Implementation is reviewer-safety.
- Do not upgrade any CLI. Do not implement #249 in #513. Do not widen `ai-grok-review`.
- Investigation is advisory. Formal review stays read-only.
- Use `ai-gh`. `bin/ai-test-local --check-collision` before a local full suite.

## 8. Access and environment

- GitHub `popcre/ai-devops`; parent #253; children #254 GLM, #255 Kimi, #256 Qwen, #257 Muse, #513 Grok. #249 remains separate.
- 1Password vault `vibe_coding`. Never copy values.

## 9. Open questions and risks

- Grok command shape (`ai-grok-implement investigate` vs a thin dispatcher) is implementer judgment: smaller tested change.
- Risk: someone implements #249 inside #513. The child body and this plan forbid that.

## Mandatory handoff self-audit

1. **Could a newcomer pick up? Yes.** Sections 1–3 name #513, Muse AGREE, and that implementation has not started. Section 6 is executable.
2. **Could they continue as well as this session? Yes.** Sections 4–5 record why #249 is not this child and that Muse required no extra edits.
3. **Every relevant detail present? Yes.** Constraints, access, and risks are in §7–§9.
4. **Owner-only section 0 complete? Yes.** Sweep of §1–§9: Albert already asked for the Grok child and the plan fix. Muse already agreed. No new owner ask.

Checklist result: **PASS**.
