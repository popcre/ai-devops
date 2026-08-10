# Handoff: implement delegate-wrapper hardening plan

## 0. Decisions only the owner can make

One conditional decision may be needed during implementation:

- If Kimi Code 0.32.0 cannot enforce a local-edit-and-test profile with network and subagents removed, decide whether to keep `ai-kimi implement` available with that documented risk or disable implementation mode until Kimi supports the restriction. Recommendation: disable Kimi implementation mode until it can be proven local-only. This blocks build step 11 only if the live two-direction canary fails.

Already settled on 2026-08-10, do not re-ask:

- Fix every GLM M1-M4 finding, the Codex-confirmed M5 Windows restart race, and every V1-V7 review item.
- Preserve current read-only review controls, model pins, exact-session rules, completion signals, Grok turn bounds, Kimi one-shot implementation, and the GLM remote-less clone.
- Measure Grok cost semantics and current Kimi CLI behavior instead of guessing.
- Never let automatic doctor cleanup delete a deliberately preserved recovery worktree.

The implementing session must raise the conditional Kimi decision once, before step 11, only if the live profile test proves the desired restriction is unsupported.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for a safe multi-model coding workflow. It contains Bash and PowerShell commands, shared Claude/Codex skills, tests, and docs. It is not a hosted application. The affected tools are `ai-glm` for GLM-5.2 through a local OpenCode server, `ai-grok-review` for named read-only Grok sessions, and `ai-kimi` for named read-only Kimi reviews plus isolated one-shot implementation work.

The repository is `C:\repos\ai-devops`, branch `main`. GitHub is the source of truth. Windows GLM uses Scheduled Task `AiDevOps-OpenCodeGlm` and loopback port 4096.

## 2. What this session set out to do, and why

Albert asked for a full implementation plan to rework every issue found by GLM-5.2's final review, including the reason for every change, and required the plan to be reviewed by Kimi K3.

The goal was not to write repair code. The goal was a fresh-session-grade plan covering all confirmed defects, all verification items, exact tests, locked safety rules, evidence-driven choices, rollback, and commit/push gates. The resulting plan is `plan_delegate-wrapper-hardening.md`.

## 3. Current state

Planning is complete. Implementation has not started.

- `plan_delegate-wrapper-hardening.md` contains a 10-row STATUS table, 15 mapped build steps, all 13 required plan sections, named tests, explicit reasons, and a passed self-audit.
- `AGENTS.md` routes future delegate reliability work to this plan before the three older completed plans.
- GLM review evidence is local and Git-ignored at `.ai/reviews/glm-delegate-integrations-final-review-20260810T145010Z.md`.
- Kimi review session is `session_160eb094-bdf9-4e79-8af7-03dfc32498e2`, wrapper name `delegate-wrapper-hardening-plan`.
- Kimi's first verdict found two blocking gaps and four smaller gaps. The second found one interaction. All were corrected. The final Kimi verdict reported no material objection and said the plan is implementation-ready for a fresh session with no chat context.
- Kimi review reports are under `.ai/reviews/` and remain Git-ignored. Kimi reports no token, cost, cache, or returned-model data, so none is claimed.
- The implementation base must be recorded after the next `git pull`; do not use the pre-planning local SHA written as historical context.
- No CI or deployment applies to this toolkit repo.

The unrelated local file `docs/claude-remote-control-hardening-v2.md` and all `.ai/` artifacts must remain unstaged.

## 4. Everything tried that did not work

1. The first plan allowed Kimi patch export to preserve committed changes, but did not close the existing branch where `.ai/reviews/` is unavailable and the worktree is deleted. Kimi correctly called this another lost-work path. The plan now requires a private fallback patch or a retained recovery worktree.
2. The first stale-worktree doctor design said to clean only positively identified wrapper worktrees but did not define how ownership could be proven. Existing worktrees use anonymous temporary paths. The plan now requires a wrapper-owned root, atomic owner record, canonical path and parent checks, exact Git registration, and a dead PID.
3. The first cleanup correction would have allowed doctor to delete a deliberately retained recovery worktree once its PID died. Kimi found the conflict. Owner records now have `active` and `preserved-recovery` states, and doctor is forbidden from automatically deleting preserved recovery work.
4. The first plan did not explicitly map 10 STATUS rows to 15 build steps, name the Windows race as M5, cover prompt transport across delegated `su`, or say `cmd_ask` temp files belong to the cleanup lifecycle. All four were added.
5. The first attempt to run `ai-kimi list` from Git Bash failed because the installed wrapper directory was not on that shell's PATH. Running the same repo-owned wrapper as `bash bin/ai-kimi` preserved every safety control and worked. Do not bypass the wrapper or hand-build a Kimi command.

## 5. Root causes and key findings

- Kimi cleanup is scattered across return paths instead of owned by one idempotent lifecycle trap.
- Kimi patch export compares against current HEAD, so a delegate commit can make real work disappear from the exported patch.
- Kimi prompt text is currently placed in argv while a comment falsely claims stdin. Direct-user and delegated-user paths both need measurement.
- GLM session creation checks then creates without a lock, allowing duplicate same-name sessions and one orphaned server record.
- Windows GLM restart uses a fixed three-second sleep, which is not proof that port 4096 is free.
- Grok cost accounting assumes resumed cost is per-call, but this was never measured. The plan caps the measurement below $0.50 before arithmetic changes.
- Cross-wrapper repository identity, cancellation messaging, metadata privacy, Kimi network policy, GLM disposable-session visibility, and Kimi transcript output need explicit tested rules.
- A retained recovery worktree is intentionally not stale. Lifecycle state is required so safety cleanup cannot destroy the only copy of work.

## 6. Exact next steps

1. Open `plan_delegate-wrapper-hardening.md` and read its STATUS table and all sections. Start at row 1/build step 1. You'll know this worked when the implementing handoff records the pulled base SHA, doctor results, and baseline test counts.
2. Create a new implementation session handoff under `HANDOFF.d/`; never edit this planning handoff. You'll know this worked when each implementing session owns one unique write-once file.
3. Execute Phases A-F in order. Phase B fixes Kimi data loss and cleanup before any consistency work. Phase C fixes GLM locking and restart. Phase D measures Grok cost before changing it. Phase E aligns supported safety rules. Phase F tests and ships. You'll know this worked when every mapped STATUS row is complete with evidence.
4. If Kimi's local-only implementation profile cannot be proven, put the single conditional decision from section 0 to Albert in one message and follow the recommendation unless he chooses otherwise. You'll know this worked when step 11 records either a passing live canary or the explicit owner decision.
5. Run every named offline and live gate, install shared skills, verify hashes, update docs and STATUS, commit to `main`, push, fetch, and compare SHAs. You'll know this worked when `HEAD == origin/main`, no plan row is open, and only known unrelated files remain.
6. Delete this planning handoff only when the implementation is proven complete and its durable evidence is in the plan/docs/Git history. You'll know this worked when this file is absent from `HANDOFF.d/` in the completion commit.

## 7. Constraints and gotchas

- Main-only repository. Pull before editing and before pushing. Preserve concurrent work.
- Verify Albert's noreply commit identity before committing.
- Never stage `.ai/`, the unrelated Claude remote-control draft, raw transcripts, secrets, or another session's handoff.
- Never call OpenCode directly, hand-build Grok review commands, or hand-build Kimi commands.
- Never weaken read-only profiles, exact completion rules, model pins, turn bounds, Kimi one-shot behavior, or the GLM remote-less clone.
- Kimi exposes no reliable token, cost, cache, context-size, or returned-model data.
- Grok live cost measurement is capped below $0.50.
- Doctor must not delete ambiguous, foreign, active, forged, or `preserved-recovery` worktrees.
- Windows PowerShell files remain pure ASCII. Production, shared cloud, databases, 1Password rotation, Claude config, and Codex config are out of scope.

## 8. Access and environment

- Repo: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, branch `main`.
- Machine: Windows 11 `al8960ofc`, user `ahazan2`, PowerShell 7 and Git Bash.
- Delegate wrappers are authenticated locally. Verify with `ai-glm doctor`, `ai-grok-review doctor`, and `ai-kimi doctor` before live calls.
- GLM: OpenCode 1.18.12, `zai-coding-plan/glm-5.2`, loopback `127.0.0.1:4096`.
- Grok: re-check installed version; earlier qualified version was 0.2.118.
- Kimi: re-check installed version; earlier qualified version was 0.32.0 and requested model alias is `kimi-code/k3`.
- GLM secret location only: 1Password account `popcreations.1password.com`, vault `vibe_coding`, item `GLM z.ai API`. Never expose its value.

## 9. Open questions and risks

- Kimi safe prompt-file/stdin support is unknown until current help and live direct/delegated process checks run.
- Grok resumed `total_cost_usd` semantics are unknown until the bounded two-turn measurement.
- Kimi may not enforce a local-write/no-network implementation profile. This is the only conditional owner decision and is listed in section 0.
- Repository-ID alignment could strand old sessions unless backward-compatible lookup and atomic migration pass first.
- OpenCode may not support safe cleanup of interrupted disposable implementation sessions. If not, preserve the ID and give an explicit cleanup command.
- Cleanup code is high risk because a false match could delete another worktree. The exact ownership and lifecycle checks in the plan are mandatory.

## Self-audit

1. Yes. Sections 1-3 explain the toolkit, goal, exact plan, Kimi session, current state, and ship status for a stranger.
2. Yes. Sections 4-5 preserve every failed draft, Kimi objection, root cause, and non-obvious finding.
3. Yes. Sections 6-9 give ordered actions, verification gates, constraints, access, risks, and the single conditional owner decision.
4. Yes. A line-by-line sweep of sections 1-9 found one possible owner decision, Kimi implementation network policy, and it is consolidated in section 0 with a recommendation and the step it blocks. All settled decisions are also listed so they are not re-asked.

All 10 required sections are present. The handoff passes the fresh-developer self-audit.
