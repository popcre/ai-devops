# Handoff: GLM, Grok, and Kimi integration implementation plans

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for restoring and operating a safe multi-model coding workflow. It supplies Bash/PowerShell wrappers, shared Claude/Codex skills, tests, setup scripts, and documentation. It is not a hosted application. The relevant integrations are GLM through `ai-glm` and a local OpenCode server, Grok through `ai-grok-review`, and Kimi K3 through `ai-kimi`.

## 2. What this session set out to do

Albert asked for three implementation plans to repair the integrations found during a prior audit, followed by a real debate with Kimi K3 until Codex and Kimi agreed the plans were implementation-ready. The requested outcomes were reliable GLM availability and better debate, context, prompt-cache, evidence, and convergence discipline for Grok and Kimi.

## 3. Current state

Three open plans now exist:

- `plan_glm-service-reliability.md`
- `plan_grok-debate-continuity.md`
- `plan_kimi-debate-context-continuity.md`

`AGENTS.md` routes future sessions to their STATUS tables. All implementation rows remain open because this session wrote plans only. The Grok plan owns the shared debate template and must precede the Kimi plan; GLM may proceed separately but overlaps the Grok plan in disjoint sections of `skills/shared/ask-glm/SKILL.md`. The plans and this handoff are uncommitted at the moment this file is written; the planning session must commit and push them before closing.

Kimi review used one persistent Codex-owned session, `session_d07689c1-71f8-4775-89a6-e92897c7de51`, named `delegate-integration-plans`. Final Kimi report: `.ai/reviews/kimi-delegate-integration-plans-20260809T235958Z.md` (local, git-ignored). Kimi explicitly concluded all three plans are implementation-ready with no material objection.

## 4. What did not work

The first drafts were not ready. They incorrectly described GLM as lacking a retry policy even though `bin/setup-opencode-glm.ps1:339-341` already sets three one-minute retries; placed a delegate template under the staged-prompt directory; omitted Grok cost ceilings; relied on unverified Kimi 0.32.0 behavior; failed to assign shared-template ownership; lacked handoff/concurrent-main rules; and specified a live Task Scheduler idempotence test inside a static Bash suite. Kimi rejected those drafts. Two revision turns corrected every objection. Do not restore any of those rejected designs.

## 5. Root causes and key findings

- GLM's real planning question is why its existing retry policy did not recover after `0xC000013A`, not how to add a retry for the first time.
- Grok has strong technical continuity and measurable cache/cost data but lacked a semantic debate-relay contract and cost ceiling.
- Kimi has exact-session continuity but no cache/model/cost counters; its 0.32.0 surface must be re-qualified before changing context behavior.
- Transport-level resume is not enough. A durable debate must relay claims, reasoning, current paths, new evidence, changed facts, and unresolved objections.
- The shared provider-neutral template belongs under `templates/delegation/`, owned by the Grok plan and consumed later by Kimi; GLM guidance must be aligned to it.

## 6. Exact next steps

1. Commit and push this planning work to `main`. Gate: local and `origin/main` share the new SHA and the worktree is clean.
2. Choose the GLM plan or Grok plan as the first implementation workstream. They may proceed independently only if edits to `ask-glm/SKILL.md` stay in their assigned sections. Gate: its STATUS table and a new workstream-specific `HANDOFF.d` file show ownership.
3. Complete and land the Grok plan before starting the Kimi plan. Gate: `templates/delegation/debate-turn.md` and aligned Grok/GLM skills are committed and the Grok STATUS table is complete.
4. Execute the Kimi plan, beginning with 0.32.0 STEP 0 re-verification. Gate: measured wrapper assumptions are updated before any debate/context change.
5. For every plan, run the exact tests and live gates it names, update STATUS/current state as each row lands, verify Albert's author/committer identity, pull before push, and remote-verify the SHA.

## 7. Constraints and gotchas

Main-only repository; preserve concurrent work; one write-once handoff per implementing session; never rewrite root `HANDOFF.md`; no secrets in Git/logs/chat; no raw Kimi session-file reads; no Grok permission broadening; no unbounded debate loops; GLM remains pinned to OpenCode 1.18.12/GLM-5.2; Kimi requested model is K3 but returned model cannot be proven; Grok cost bounds are $1.50 normal and $0.75 live acceptance.

## 8. Access and environment

Repo `C:\repos\ai-devops`, branch `main`, machine `albt16`/Windows 11. Git, `gh`, PowerShell 7, Git Bash, Grok 0.2.118, Kimi 0.32.0, and OpenCode 1.18.12 are installed. Kimi and Grok authentication checks passed. GLM configuration is installed but its local server was not answering during the audit. GLM secret source is 1Password vault `vibe_coding`, item `GLM z.ai API`; never expose its value.

## 9. Open questions and risks

The plans deliberately leave only evidence-driven questions open: why Task Scheduler did not recover GLM; whether any Grok wrapper change is justified after skill/template evidence; and whether Kimi's supported CLI exposes safe context metadata. The plans define gates for each decision. Main risks are concurrent edits to shared docs/skills, false consensus, Grok cost growth, Kimi automatic compaction losing nuance, and GLM restart storms or duplicate listeners.

## Self-audit

Passed. A fresh developer can identify the toolkit, goal, exact plans, rejected drafts, Kimi consensus evidence, ordering, commands/gates, constraints, environment, and remaining evidence questions without this chat. Every next action is concrete and verifiable, and failed approaches are preserved.
