---
issue: none
status: OPEN
owner: codex/shared-db-finish-first-plan
---

# HANDOFF — shared-db finish-first replacement plan and Kimi latency diagnosis (2026-08-18 14:04Z, edge-dev/codex)

Implementation plan: [`../plan_shared-db-finish-first-delivery.md`](../plan_shared-db-finish-first-delivery.md)

Kimi reliability plan updated by this session: [`../plan_kimi-windows-execution-reliability.md`](../plan_kimi-windows-execution-reliability.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### Blocking

None. Grok and Kimi reviewed the complete plan section by section, their material objections were incorporated, and both returned `NO MATERIAL OBJECTION TO THE ENTIRE PLAN`.

### Recoverable

Albert should formally withdraw the older instructions “keep all three migration-author lanes occupied” and “finish/close every open issue.” Recommendation: approve their replacement with one shared delivery outcome plus one isolated authoring outcome, measured only by live verified application results.

### Not part of the orchestrator implementation, but discovered here

The Kimi wrapper has confirmed execution defects tracked by the existing Windows reliability plan. Recommendation: keep that repair independent from shared-db delivery and implement issue #31 from its expanded STATUS table; do not make application database work wait for it.

### Already settled — do not re-ask

- Database safety controls remain; the perpetual coordinator session is what retires.
- No automatic cleanup of locks, claims, versions, preview history, worktrees, or issues.
- No fourth opinion unless exact-plan Grok/Kimi debate remains materially split.
- Root `HANDOFF.md` is the static pointer and must not be rewritten. This file is discoverable through its `HANDOFF.d/` link.

## 1. What this application is

`u2giants/ai-devops` distributes Albert’s global Codex/Claude rules, shared skills, reviewer wrappers, machine setup, and workflow documentation. It is a public Bash/PowerShell/Markdown toolkit, not a hosted application.

`u2giants/shared-db` governs structural changes to the shared Supabase/Postgres backend used by multiple applications. It owns migrations, durable GitHub-backed version/object claims, preview/merge/production serialization, and production verification.

The failure crosses both repositories: ai-devops distributes the orchestration instructions; shared-db enforces the three-lane/refill mechanics.

## 2. What this session set out to do and why

Albert reported that five applications had waited for days while the shared-db orchestrator ran continuously, expanded dependency chains, and failed to finish live database outcomes. He asked for a full implementation plan based on Codex, Grok 4.6, and Kimi K3, full multi-reviewer agreement rather than vague central consensus, and a deeper diagnosis of Kimi’s own long review.

This session wrote a zero-context implementation plan that replaces the standing coordinator with finish-first delivery while retaining incident-backed database safeguards. It also reproduced and documented the Kimi wrapper failures in the existing issue-31 plan rather than creating a competing document.

## 3. Current state — what is true now

- New plan exists at `plan_shared-db-finish-first-delivery.md`; every STATUS row is open.
- The plan proposes one outcome in shared stages plus one isolated authoring outcome, a durable lock book, early preview preflight, read-only health audit, one-day honesty checkpoint, and live-verification completion.
- Exact-plan consensus is complete. [`../docs/shared-db-finish-first-plan-consensus-2026-08-18.md`](../docs/shared-db-finish-first-plan-consensus-2026-08-18.md) records every Grok/Kimi objection, both rebuttal turns, and both final `NO MATERIAL OBJECTION TO THE ENTIRE PLAN` verdicts.
- `plan_kimi-windows-execution-reliability.md` now includes new rows 4a/4b and details the concurrent-edit false canary, directory-bound resume, blind 900-second wait, and diff-prompt anchoring defects.
- `ai-devops/main` was at `384c42d50b3a152ea4f64d69871ea6ca66224385` when drafted. The primary checkout also contains unrelated Windows SSH work; do not stage it.
- `shared-db/main` was locally at `d6752de69e8a68fa1e6108e45d7848d48e68772e`, two commits behind `origin/main`; implementation must fetch and remeasure.
- GitHub read on 2026-08-18 showed #1090/#1147 and #1115/#1148 open. Sample Tracking handover #1149 had closed. Do not preserve “five waiting apps” as a live count without rechecking.
- No implementation code, installed skill, database, preview, production, or cloud state changed.

## 4. Everything tried that did NOT work

1. Codex’s first proposal used three active outcomes, a “stateless” safety gate, a numeric tooling quota, and a one-day ship target. Grok rejected those details because they would recreate contention and weaken durable cross-machine safety. The new plan adopts Grok’s corrections.
2. The first Kimi architecture turn read the evidence but answered mainly as a Git patch review and compressed nine decisions. Every review receives a diff-oriented evidence-packet preamble, which anchored a non-diff analysis on an unrelated patch.
3. Two Kimi follow-ups in the primary checkout completed model work but the wrapper rejected them after unrelated sessions changed the working tree. The whole-checkout `tree_state` canary cannot attribute changes to Kimi.
4. Moving the named Kimi review into a linked worktree failed because Kimi binds a session to its creation directory. The wrapper recognized the repository remote but not the directory binding.
5. That directory error was immediate, yet the wrapper waited 900 seconds. `run_turn` had already waited for and reaped the child; `await_result` then polled all machine processes named `kimi`, so it could not prove that this exact exited child was gone.
6. The linked-worktree review snapshot later failed to reset, so the final Kimi latency diagnosis used a self-contained clean clone. That run completed successfully.
7. Asking for a fourth opinion before a complete plan was rejected. The problem was not insufficient model count; it was lack of section-by-section agreement on one durable artifact.

## 5. Root causes and key findings

- Orchestration optimized for occupancy and intermediate evidence, not live application outcomes. Full evidence is in `shared-db_orchestrator_failure_analysis.md`.
- Durable coordination state is necessary, but a perpetual coordinating conversation is not. GitHub/Git/preview hold the authoritative state.
- Preview, merge, and production are globally serialized, so three concurrent outcomes increase staleness rather than throughput.
- Removing the standing coordinator also removes its accidental aging/orphan tripwire. A read-only health audit is therefore an activation prerequisite.
- Exact-plan consensus requires reviewers to mark every design decision and plan step, maintain an objection ledger, and re-read the changed plan. Agreement on only the “central decision” is insufficient.
- Kimi’s successful full reading/reasoning turns took roughly four to five minutes, which is plausible for the large evidence set. The 900-second failed turn was entirely wrapper delay after an immediate error.
- The Kimi failure is mainly wrapper and prompt packaging, not demonstrated K3 reasoning incapacity. A fresh isolated Kimi session produced the full nine-part operating recommendation.

## 6. Exact next steps

1. Re-run the implementation-plan self-audit after reviewer edits. You’ll know it worked when all checklist items remain yes and the plan’s final audit cites the updated sections.
2. Commit and push only this session’s plan, Kimi-plan update, consensus evidence, router/memory links, and this handoff after verification. You’ll know it worked when `origin/main` contains the exact SHA and unrelated SSH files remain unstaged.
3. Start implementation at plan Step 1 in a fresh session and isolated worktree. You’ll know it worked when the session quotes the current heads of both repos and the first open STATUS row.

## 7. Constraints and gotchas

- Root `HANDOFF.md` stays unchanged; it already points to `HANDOFF.d/`.
- Do not edit or delete another session’s handoff.
- Stage only owned paths; the primary checkout contains unrelated work.
- GPT-5.6 reasoning remains low or medium.
- Kimi reports no returned model, token, cache, or cost figures.
- Kimi review sessions are directory-bound. A live review cannot be moved by matching only the Git remote.
- Do not increase Kimi’s timeout to hide an immediate child failure.
- Database and production writes are outside this planning session.
- The health audit must never mutate or automatically clean durable safety state.
- Exact reviewer agreement on the plan does not approve implementation code; exact-head code review remains required later.

## 8. Access and environment

- Machine: `edge-dev`, Windows 11, PowerShell 7, Git Bash.
- `gh` is authenticated as `u2giants`.
- ai-devops repo: `C:\repos\ai-devops`, target `main`.
- shared-db repo: `C:\repos\shared-db`, branch plus PR.
- Kimi executable and OAuth are available to the Full Access main task. Never print or copy OAuth files.
- Grok and Kimi reviews use `ai-grok-review` and `ai-kimi` wrappers only.
- No new 1Password secret is required. Existing secret location is vault `vibe_coding`; values never enter documents.

## 9. Open questions and risks

- Exact CLI and field names for the 1+1 roles and health audit are locked in plan §8. No design question remains open.
- A legacy state with three active claims may exist at activation. It must fail closed and be adopted/finished explicitly, never deleted to fit the new cap.
- The standing coordinator cannot be removed before the read-only aging/orphan audit exists.
- Prompt-contract repair and stable Kimi review workspaces are owned by issue #31. The orchestrator replacement proceeds independently using governed reviewer fallback.
- A fourth reviewer is warranted only if Grok and Kimi remain materially split after their bounded debate or share one unverified assumption.

## Mandatory self-audit

1. **Could a zero-context developer continue without questions? Yes.** §§1–3 define both repositories, the business failure, exact artifacts, current heads, and live issue evidence; §6 gives ordered next actions with verification gates.
2. **Could they continue as effectively as this session? Yes.** §§4–5 preserve every Kimi failure, the orchestration root cause, the rejected fourth-opinion shortcut, and the distinction between genuine model time and wrapper delay.
3. **Are failed attempts included with reasons? Yes.** §4 records the rejected first proposal, prompt anchoring, concurrent canary, directory-bound resume, blind wait, snapshot reset, and premature fourth-opinion approach.
4. **Is every next step executable and verifiable? Yes.** §6 names the reviewer, artifact, ledger, bounded debate, self-audit, landing scope, and implementation start gate.
5. **Are uncommon terms, paths, IDs, and environments defined? Yes.** §§1, 3, 5, 7, and 8 define the repositories, plans, issue numbers, wrapper names, directory binding, and machine paths.
6. **Was the section-0 sweep run? Yes.** The only Albert decisions found in §§1–9 are withdrawal of the old utilization instructions and any unresolved post-debate plan choice; both appear in §0. The Kimi repair is explicitly listed as outside-scope but needing owner awareness.

Final synthesis:

1. **Yes**, this handoff is comprehensive enough for a brand-new developer; §§1–9 carry the complete workstream and §6 provides executable continuation.
2. **Yes**, the developer can continue as effectively as this session; all orchestration and Kimi findings, failed attempts, current state, and reviewer requirements are preserved.
3. **Yes**, every relevant background, goal, intended outcome, current state, failure, decision, constraint, risk, action, and verification gate is present.
4. **Yes**, if Albert reads only §0 he sees the only decision requiring him: formally withdraw the old occupancy/close-all orders before activation.
