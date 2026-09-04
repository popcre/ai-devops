---
issue: 253
status: OPEN
owner: codex/reviewer-investigation-option-b-253
---

# HANDOFF — reviewer investigation Option B (2026-09-04 00:55 UTC, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — Albert already settled the material policy on 2026-09-03: give GLM, Kimi, Qwen, and Muse shell/internet investigation capability and use the least-moving-parts Option B. Do not re-ask whether to build a shared lifecycle core or whether capable investigation is desired.

The next session should raise the whole owner-decision list in one message before implementation only if new evidence creates a real choice. There is no current owner blocker.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for multi-model coding workflows. It contains provider wrappers, installers, profiles, documentation, and offline tests. The affected wrappers are GLM 5.3, Kimi Code, Qwen Code, and Muse. There is no hosted application deployment; delivery means verified `origin/main`, installed commands, and authenticated live qualification on supported Windows and Ubuntu hosts.

The executable plan is [`../plan_reviewer-investigation-mode-option-b.md`](../plan_reviewer-investigation-mode-option-b.md). Parent GitHub issue [#253](https://github.com/popcre/ai-devops/issues/253) owns the work.

## 2. What we set out to do this session, and why

Albert wants reviewers to perform deeper testing with shell and internet access, with the least complexity. This session was authorized to write a fresh-session implementation plan and create a GitHub parent/child hierarchy with one child per reviewer. Planning only was requested; implementation was not started.

## 3. Current state — what is true right now

- Parent issue #253 exists with exactly four GitHub sub-issues: GLM #254, Kimi #255, Qwen #256, and Muse #257. `gh issue view 253 --json subIssues` verified the relationship.
- The complete 13-section plan exists at `plan_reviewer-investigation-mode-option-b.md`; its STATUS table says a fresh session starts at Step 0.
- GLM must land the shared OpenCode upgrade before Muse. Kimi and Qwen may be prepared independently, but commits to this repository's `main` must be serialized and current state re-resolved.
- No Option B wrapper/config/test implementation has started. No provider was upgraded or installed by this session.
- The checkout was already dirty. Overlapping dirty files include `bin/ai-muse`, `bin/ai-review-sandbox`, Muse docs/skill/tests, and `AGENTS.md`. Those changes belong to other work and were not altered by this plan except that a separate targeted AGENTS router registration may be added in the planning commit after ownership verification.
- Planning observed local HEAD `ff72d5735b80beb2e05e94e552264674280fbdd4` and fetched `origin/main` `71bfed6eb12f252e8f3996e91038519958c9aae9`; these values are stale immediately after planning and Step 0 must re-resolve ancestry.
- The plan, handoff, router registration, and issue hierarchy were committed and pushed to `origin/main` as `0129f9f2`. Implementation remains entirely open.

## 4. Everything we tried that did NOT work

- The first proposed architecture was a new shared lifecycle core with thin provider adapters. It is a reasonable long-term consolidation, but Albert rejected it for this delivery because it adds too much initial machinery. Do not reintroduce it; issue #169 remains the separate consolidation track.
- Unrestricted live-checkout access was considered. It adds little testing value beyond a disposable copy while exposing concurrent work and inherited credentials. Option B therefore gives full shell/internet inside an existing disposable remote-less copy.
- Keeping formal reviewers entirely read-only was rejected as insufficient for runtime testing. Formal review remains read-only only because it is the judge tier; the new explicit investigation tier is capable.
- An egress broker/domain allowlist was rejected as excessive complexity for this plan. It becomes relevant only if private/licensed/secret-bearing inputs must be exposed to capable reviewers.

## 5. Root causes and key findings

- GLM, Kimi, and Qwen already have shell-capable implementation lifecycles, so their lowest-complexity change is a thin `investigate` command using that machinery.
- Muse lacks a capable path and is the only provider requiring a new investigation profile/turn path.
- OpenCode is shared by GLM and Muse. GLM issue #254 owns the version upgrade and must prove Muse compatibility; Muse #257 consumes and requalifies that exact pin.
- Qwen has a live discovery defect: PowerShell resolves Qwen 0.21.15 but `ai-qwen doctor` does not. Issue #256 repairs that before upgrade.
- Internet capability makes readable credentials exportable. The minimum retained control is a scrubbed/allowlisted child environment and existing private provider-key handoff, not a network broker.
- Exit zero is not provider completion. Each wrapper's native terminal event and uncertain-state handling must remain.

## 6. Exact next steps

1. Re-read the plan STATUS and Step 0; fetch current `origin/main`; inspect status, worktrees, active protected Windows work, and overlapping dirty-file ownership. **You’ll know it worked when** a baseline verification artifact names exact current SHA/ancestry, versions, doctors, dirty owners, and candidate pins.
2. Execute GLM child #254 and land it first. **You’ll know it worked when** exact OpenCode/GLM identity, shell/internet capability, credential-free children, remote-less copy, bounded recovery, formal no-shell review, Windows/Ubuntu installation, and live canaries are evidenced on current main.
3. Execute Kimi #255 and Qwen #256 independently where safe, serializing main commits. **You’ll know each worked when** its child issue holds redacted offline and authenticated proof for the plan’s acceptance matrix.
4. Execute Muse #257 only after GLM's OpenCode commit is on `origin/main`. **You’ll know it worked when** Muse uses that exact pin and proves capable investigation plus unchanged formal review on both operating systems.
5. Run parent Step 5: full suite, installed four-provider live qualification, documentation/skills/router reconciliation, independent exact-head final review, commit/push verification, STATUS update, issue closure, and handoff retirement. **You’ll know it worked when** all four children and #253 are closed with current artifacts and the final SHA is on `origin/main`.

## 7. Constraints and gotchas in force

- Work directly on `main`; do not create a feature branch. Preserve all other sessions' dirty work and stage only owned files.
- Do not run broad local suites on `EDGE-DEV` while a CI job is running **on
  `edge-dev-win`, the runner hosted on that same machine**. This is a per-host
  rule, not a pool-wide one: a job on `EDGE-RUNN-ENVY`, `EDGE-ALIEN`, or a
  GitHub-hosted runner does **not** block a local suite here, and waiting on one
  defeats the point of having a runner pool. Confirm this host specifically:
  `gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|"\(.name) busy=\(.busy)"'`
  and read the `edge-dev-win` row only.
- This is a reviewer safety-path change and requires an independent exact-head final review before landing implementation.
- Never expose secret values in prompts, argv, output, logs, reports, patches, tests, or commits. This public repository cannot contain raw transcripts or licensed/private inputs.
- Investigation is advisory, not formal approval. Do not mutate the existing formal review profiles into capable modes.
- No floating `latest`, native auto-update, shared lifecycle rewrite, egress broker, live-checkout capability, or automatic patch application.
- If a candidate upgrade breaks a required capability, retain the last qualified pin and document the failed candidate. Do not disable investigation as a workaround.

## 8. Access and environment

- Repository: `C:\repos\ai-devops`; GitHub: `https://github.com/popcre/ai-devops`; target branch `main`.
- Issues: parent #253; children #254 GLM, #255 Kimi, #256 Qwen, #257 Muse.
- Windows Bash tests use `C:\Program Files\Git\bin\bash.exe`; native setup/status uses PowerShell.
- Ubuntu host/user details must be read from the current host section of `templates/system/machine-atlas.md`, not guessed.
- Provider secrets remain referenced through existing setup and 1Password vault `vibe_coding`; never copy values. Existing Kimi OAuth storage remains credential-bearing and protected.

## 9. Open questions and risks

No owner question is open. Provider-local implementation may choose the smallest helper/dispatch shape. Each candidate native version remains conditional on the full qualification matrix.

Risks are credential exfiltration, concurrent checkout damage, false completion, native contract drift, and accidental framework scope growth. The plan contains the exact mitigations and rollback: disposable remote-less copies, scrubbed child environments, provider terminal events, exact pins/fixtures/live qualification, provider-local changes, and independently revertible commits.

## Mandatory handoff self-audit

1. **Can a brand-new developer continue without asking a question? Yes.** Sections 1–3 identify the product, goal, plan, issues, dependencies, and exact current state; Section 6 gives ordered next actions and proof gates.
2. **Can they continue as effectively as this session? Yes.** Sections 4–5 preserve the rejected shared-core/live-checkout/read-only/broker approaches and all provider-specific findings.
3. **Is every execution detail present? Yes.** Sections 6–9 cover actions, constraints, access, risks, rollback direction, and the absence of owner blockers; the linked plan supplies file-level steps and test commands.
4. **Would Albert see every required decision in Section 0? Yes.** A line-by-line sweep of Sections 1–9 found no unsettled owner choice. Section 0 records the already-settled policy and tells the next session not to re-ask it.

Checklist result: **PASS**. All ten sections exist; owner-decision sweep is explicit; current commit/push state and dirty concurrency are truthful; failed approaches are retained; every next step has a verification gate; identifiers/access are defined; and secrets are referenced only by location.
