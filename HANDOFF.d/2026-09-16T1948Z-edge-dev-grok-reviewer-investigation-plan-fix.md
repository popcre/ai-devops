---
issue: 253
status: OPEN
owner: grok/253-investigation-plan-fix
---

# HANDOFF — reviewer investigation Option B plan correction (2026-09-16 19:48 UTC, edge-dev/grok)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

Already settled — do NOT re-ask:

- **2026-09-03, Albert:** give GLM, Kimi, Qwen, and Muse shell and internet investigation, least moving parts, Option B. Do not build a shared lifecycle core.
- **2026-09-16, Albert:** after an independent reading that none of the four children was perfect as written (Muse closest; the other three mixed a new name with tool upgrades; Qwen stacked three jobs), Albert said “fix all of the plans.” That authorizes this correction: no bundled upgrades, children independent, Muse does not wait on GLM, feature-branch-PR.

The next session should not raise an owner-decision list before implementation unless new evidence creates a real choice.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for a multi-model coding workflow. Wrappers, installers, profiles, docs, and offline tests. No hosted app. GitHub `origin/main` is code truth. Landing is feature-branch plus pull request, never a direct push to `main`.

Affected reviewers: GLM 5.3 via `bin/ai-glm` on OpenCode pin `1.18.12`; Kimi via `bin/ai-kimi`; Qwen via `bin/ai-qwen`; Muse Spark 1.3 Contributor via `bin/ai-muse` on the same OpenCode pin.

The executable plan is [`../plan_reviewer-investigation-mode-option-b.md`](../plan_reviewer-investigation-mode-option-b.md). Parent GitHub issue [#253](https://github.com/popcre/ai-devops/issues/253) owns the work.

## 2. What we set out to do this session, and why

Albert asked Grok to read the 2026-09-04 Option B plan and GitHub parent #253 plus children, say whether it was an improvement, then which child was perfect as written, then to fix all of the plans.

This session was authorized to correct the plan and the four child issue scopes. Implementation of `investigate` was not started.

## 3. Current state — what is true right now

- Independent reading (this session): the outcome is an improvement over read-only-only reviewers, but the 2026-09-04 children were not ready as written. Muse (#257) was the closest because it is the only new capable path. GLM (#254) and Kimi (#255) mixed a thin new command with a CLI upgrade. Qwen (#256) stacked discovery repair, upgrade, and the new mode. Muse also waited on GLM's OpenCode upgrade, which it does not need on today's pin.
- Corrected plan is this commit's `plan_reviewer-investigation-mode-option-b.md`. STATUS still starts a fresh implementing session at Step 0. Steps 1–4 are independent after Step 0. No CLI/harness/model upgrade is in scope.
- New handoff is this file. Predecessor `HANDOFF.d/2026-09-04T0055Z-edge-dev-codex-reviewer-investigation-option-b.md` is deleted in the same commit: its planning work is on `main`, remaining obligations are in the corrected plan, and its “land on main / GLM then Muse / bundle upgrades” instructions would mislead.
- GitHub children #254–#257 and parent #253 still described the old upgrade-coupled scope until this session rewrote their bodies to match the corrected plan.
- No `investigate` command exists on `origin/main` `2719315e13fc6e3cb99511dced33915ea46f4d47`. GLM/Kimi/Qwen `implement` exists. Muse has only read-only `new`/`ask`/`review`. GLM implement profile forbids the network (`config/opencode/agent/glm-implement.md`). Kimi implement Bash can use the network. Qwen `resolve_qwen` does not search `PATH`.
- This worktree: `C:\repos\ai-devops-worktrees\253-investigation-plan-fix`, branch `grok/253-investigation-plan-fix` from `origin/main` `2719315e`. Canonical checkout `C:\repos\ai-devops` was behind origin and was not edited.
- Concurrent worktree `C:/repos/ai-devops/.claude/worktrees/parent-issue-253-status-9293e4` exists. Do not touch it.
- Implementation remains entirely open.

## 4. Everything we tried that did NOT work

- Treating the 2026-09-04 children as ready to implement. Independent reading found bundled upgrades, stacked Qwen scope, and Muse-after-GLM coupling. Building that letter would have delivered a bigger, riskier job than Albert asked for.
- Shared lifecycle core (2026-09-03). Rejected by Albert as too much machinery. Still rejected. Issue #169 stays separate.
- Unrestricted live-checkout access. Rejected: extra harm, little extra testing value.
- Converting formal review into full-access mode. Rejected: destroys the judge boundary.
- Egress broker. Rejected as extra service for this plan.
- Using `implement` as the user-facing investigation command. Rejected: `implement` means write a change; Albert asked for reviewers that can look into software. A named `investigate` command is the small interface that keeps advice from counting as a build job or a pass.
- Leaving Muse blocked on GLM's OpenCode upgrade. Rejected 2026-09-16: both already run on pin `1.18.12`.
- Landing this workstream directly on `main`. Rejected 2026-09-16: current policy is feature-branch-PR.

## 5. Root causes and key findings

- Formal reviewers still cannot run tests or use the public web, so they guess. That is the real gap.
- GLM, Kimi, and Qwen already have shell in `implement`. The missing piece is a named advisory mode, plus public internet where the implement profile forbids it (GLM).
- Muse has no capable path. That is the only new machinery.
- GLM `glm-implement.md` has `webfetch: false` and tells the model not to reach the network. Investigation cannot silently alias that agent. Reuse the clone lifecycle; add `glm-investigate.md`.
- Kimi `local-implement.md` already allows network through Bash.
- Qwen discovery may still be broken (`resolve_qwen` at `bin/ai-qwen:254-282` ignores `PATH`). Step 0 must compare doctor vs PowerShell. Repair only if they still disagree. Not an upgrade.
- Internet-capable reviewers can exfiltrate anything they can read. Keep disposable copy + scrubbed children + no operator credentials.
- Exit zero is not completion. Keep each wrapper's native terminal event.

## 6. Exact next steps

1. Merge this planning PR (prose only: corrected plan, this handoff, router/index wording, GitHub issue bodies updated). **You'll know it worked when** the merge SHA is on `origin/main` and issues #253–#257 describe the corrected independent, no-upgrade children.
2. Start a new implementing session at plan Step 0 in a fresh current-upstream worktree. **You'll know it worked when** `tests/verification/reviewer-investigation-option-b/<UTC>-baseline/` names SHA, versions, doctors, Qwen discovery match/mismatch, and overlapping owners.
3. Implement #254 GLM, #255 Kimi, #256 Qwen, and #257 Muse independently after Step 0, each on its own feature branch, each as reviewer-safety with exact-head review. **You'll know each worked when** its child issue holds redacted shell/internet canaries, credential-free children, unchanged formal review, and no pin change.
4. Parent Step 5: cross-provider labels, full suite, live canaries, exact-head review, merge, close #253–#257, delete this handoff. **You'll know it worked when** all four `investigate` commands exist on `origin/main` and this file is gone.

## 7. Constraints and gotchas in force

- Feature-branch-PR. Never push to `main`. Canonical checkout is landing-only.
- Implementation class is `reviewer-safety`, not prose. This planning PR is prose.
- Do not upgrade OpenCode, Kimi, Qwen, or the Muse model in this workstream.
- Do not wait for GLM before Muse.
- Do not mutate formal review profiles into capable modes.
- Do not reuse `glm-implement` unchanged for investigation (no network).
- Do not collide with worktree `parent-issue-253-status-9293e4`.
- Secrets: 1Password vault `vibe_coding`, location only, never values.
- Use `ai-gh`, not raw `gh`. Use `bin/ai-pr-wait` for PR waits. `bin/ai-test-local --check-collision` before a local full suite on this host.
- Investigation is advisory. Formal review stays read-only.

## 8. Access and environment

- GitHub `popcre/ai-devops`; issues #253 (parent), #254 GLM, #255 Kimi, #256 Qwen, #257 Muse.
- Planning worktree: `C:\repos\ai-devops-worktrees\253-investigation-plan-fix`.
- Windows: PowerShell + Git Bash `C:\Program Files\Git\bin\bash.exe`.
- Ubuntu host/user: `templates/system/machine-atlas.md` current host section only.
- Provider credentials: existing GLM/Muse/Qwen/Kimi setup items in vault `vibe_coding`. Never copy values.

## 9. Open questions and risks

- Qwen discovery: unknown until Step 0. If already matching, skip repair.
- Smallest GLM/Kimi/Qwen code shape (mode flag vs tiny helper; dedicated profile vs reuse) is implementer judgment. Criteria: fewer new parts, formal review untouched, GLM implement stays off-network.
- Risk: a later session reintroduces upgrades because the old GitHub issue titles mentioned them. The corrected issue bodies and this plan forbid that.
- Risk: someone treats investigation as a formal pass. Report banner and separate command exist to prevent that; tests must keep formal review shell-less.

## Mandatory handoff self-audit

1. **Could a brand-new developer pick up without asking? Yes.** Sections 1–3 name the product, the 2026-09-16 correction, current SHA, and that implementation has not started. Section 6 is executable. The plan file is the build spec.
2. **Could they continue as well as this session? Yes.** Sections 4–5 record the independent reading, rejected couplings, GLM no-network finding, Muse-not-blocked finding, and Qwen PATH finding.
3. **Is every relevant detail present? Yes.** Sections 6–9 name next steps with gates, constraints, access, and remaining judgment. Issue 253 is the close-out proof.
4. **If the owner read only section 0, would he see every decision needed from him? Yes.** Sweep of §1–§9: Albert already settled capability, Option B, and “fix the plans.” No new owner ask. Section 0 says None and lists the settled items.

Checklist result: **PASS**.
