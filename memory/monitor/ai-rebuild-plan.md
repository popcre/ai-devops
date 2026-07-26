---
name: ai-rebuild-plan
description: The issue-agent AI rebuild is designed in PLAN.md (repo root) — start coding from there
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d41f339-3928-435c-80ce-4fb67ca9ee35
---

The planned rebuild of the Issue Investigator / issue-agent pipeline is fully
specified in **`PLAN.md` at the repo root** (committed 2026-05-29).

**Why:** decided with the owner to do the *coding* in a fresh session (clean
context = sharper reasoning; caching doesn't fix context-rot). PLAN.md is the
handoff artifact — read it + [[db-partman-and-ingestion-state]] + AGENTS.md, then
build from PLAN.md's build order.

**STATUS: COMPLETE.** The full rebuild is built, deployed, and LIVE as the only
issue-agent pipeline (finished 2026-05-30, final cleanup commit `860ace8`; PLAN.md
status header updated, HANDOFF.md removed). All 5 provider keys are live in Coolify
(owner added them; the agent/repo side never writes Coolify env — owner refused the
token 3x and was right to; the cutover was done as a CODE default, not an env flag).
The legacy 7-stage pipeline + OpenRouter inference path are removed. Only unrelated
outstanding item: rotate leaked secrets ([[leaked-secrets-pending-rotation]]). The
detailed step-by-step log below is kept for reference.

**Build progress:** Step 1 of 8 (config layer) DONE + deployed 2026-05-29 (commit
`a83d3ec`): added the §8.3 capability matrix as pure-data `packages/shared/src/ai-capabilities.ts`
(provider-native model ids, abstract effort levels, 3 stage descriptors w/ required
caps + hardcoded fallbacks); `getStructurer/Reasoning/ExplainerConfig` in
`apps/web/.../ai-settings.ts`; settings-route whitelist + effort validation;
migration `00036` seeded the 6 new `stage_*` keys (applied to live Supabase),
legacy 7-stage + second_opinion/cluster keys left intact. All additive — old
pipeline still runs.

Step 2 of 8 (provider client + caching core) DONE + deployed 2026-05-29 (commits
`afb0842`, `c4de6f1`): `apps/web/src/lib/server/ai/` — context-compiler.ts (throws
on dynamic-before-stable, derives stable_prefix_hash), effort.ts (abstract level→
provider shape), usage.ts (per-provider normalizers incl. DeepSeek/Gemini odd
fields), providers/ (Anthropic native cache_control; OpenAI/DeepSeek/Qwen via one
openai-SDK factory w/ baseURL; Gemini @google/genai), call-model.ts. Migration
`00037` ai_model_calls (applied). CI guards (apps/web/scripts/ai-cache-guards.ts
via tsx) wired into web-image.yml BEFORE the build — block deploy on bad ordering
/ collapsed history / un-normalized usage. Added deps @anthropic-ai/sdk,
@google/genai, tsx. GOTCHA: a root `.npmrc` sets `node-linker=hoisted` — required
because @google/genai pulled `ws` in, giving `openai` a peer-variant path webpack
couldn't resolve; Dockerfile no longer copies packages/shared/node_modules. Still
additive/dormant (nothing imports callModel yet).

Step 3 of 8 (evidence store + Stage 1 + fetch_evidence) DONE + deployed
2026-05-29 (commit `4155eb1`): migration `00038` issue_evidence_items (lossless
store, applied) + issue_evidence_aggregate SQL fn; `ai/stage1-structurer.ts`
(DETERMINISTIC byte-identical dedup → persist full set → bounded prioritized
slice + index, EVIDENCE_TOKEN_BUDGET=12k tok; no model call so it runs without
provider keys); `ai/fetch-evidence.ts` (Supabase-only, hard limit cap 100,
required time range, byte cap + body truncation, has_more/next_offset cursor,
group_by source|error|time_bucket aggregation). Still additive/dormant.

Step 4 of 8 (workflow/state-machine skeleton) DONE + deployed 2026-05-29 (commit
`a9308d8`): `ai/stage2-turn.ts` — TurnOutcome (5 §7 terminals) + applyTurnOutcome
mapping each to issue_jobs+status+approval gate (reuses existing store fns),
persists action INTENT only (NEVER the HMAC token), mintApprovalTokenForIntent
at exec, withNasReachability degrade (retry-once→nas_unreachable), TURN_CAP=8.
Migration `00039` widened issues.status CHECK to add waiting_on_issue (applied) —
ALSO fixed a latent bug: code already wrote that status but the CHECK rejected it
(prod CHECK violation on the cross-issue-dependency branch). Additive/dormant —
live issue-agent loop NOT modified; cutover happens in step 5/8. **Resume at
step 5** (Stage 2 reasoning core — the big integration: cached bounded prompt via
context-compiler + whole-system snapshot + re-chew guard + transcript-per-turn,
calling callModel(reasoning) with tool-calling; AND §6 tool-catalog sharing =
move tool defs to packages/shared + change nas-mcp build context/paths — touches
a 2nd deployable. NEEDS Anthropic key to RUN).

Steps 5a/5b/6 DONE + deployed 2026-05-29 (commits `3589d51`, `c00a5bf`,
`4b2fbfe`). 5a: provider tool-use loop (Anthropic tool_use/tool_result +
OpenAI-compatible function tool_calls; usage accumulated via addUsage; toolCalls
log returned; Gemini throws if tools passed — fine for tool-less stages 1/3).
5b: `ai/stage2-reasoning.ts` — loadEvidenceSlice rebuilds bounded slice from DB,
whole-system snapshot, re-chew guard (sha256 of slice + ask_user backstop after
2 repeats), stable prompt via compiler, callModel(reasoning) with 21 read-only
tools + fetch_evidence inline (tier-2/3 → needs_approval), tool results persisted
back to evidence store, TURN_CAP→stuck. 6: `ai/stage3-explainer.ts` — single-shot
operator message + agent_memory persistence (validated memory_type, best-effort).
The FULL 3-stage pipeline is now built but DORMANT (nothing imports the stage
runners; live runIssueAgent untouched).

Step 7 DONE + deployed 2026-05-29 (commit `197718a`): admin "AI Stages" section
(settings/ai-stages-section.tsx) — 3 stages × (model gated by capability matrix,
effort gated by model) + copy-spec button; /api/ai-usage (per-stage + overall
cache_hit_ratio from ai_model_calls); /api/nas-health probe → "NAS offline"
badge. Legacy 7-stage settings section kept (relabeled) until step 8. Additive.

Step 8 CUTOVER SCAFFOLD built + deployed 2026-05-30 (commits `827c2c3`,
`6bc6994`), DEFAULT OFF. `ai/pipeline-v2.ts` runIssueAgentV2 = execute approved
action (mint HMAC fresh at exec via buildNasApiApprovalToken — never persisted) →
Stage 1 seed once (when issue_evidence_items empty) → one Stage 2 turn → Stage 3
on resolve. Gated in issue-workflow.ts processIssueJob: v2 iff
`ISSUE_PIPELINE_V2=true` (env, global) OR issue.metadata.pipeline==="v2"
(per-issue). Validation UI: Settings→AI Stages→"Validate the new pipeline (v2)"
issue picker + "Run v2 turn" button → POST /api/issues/[id]/run-v2 (opts issue
into v2, runs one turn synchronously). All 5 provider keys verified working via
smoke-test (Anthropic+Gemini = default lineup ready; OpenAI effort fixed to
low/medium/high — gpt-5.4-mini rejects 'minimal'). gatherTelemetryContext now
EXPORTED from issue-agent.ts; Stage1 flattener keys aligned to its real output
(top_processes/scheduled_tasks_with_issues/container_io_top/sharesync_tasks/
io_pressure_metrics). Old v1 runIssueAgent still the DEFAULT and untouched.

5c (§6 tool-catalog sharing) DONE + deployed 2026-05-30 (commits `d7abf19`,
`13b9595`), BOTH images green. Single source = `packages/shared/src/nas-tools.ts`
(the old 108-tool nas-mcp catalog + a toInputSchema zod→json-schema helper).
nas-mcp keeps a local relative import via a COMMITTED SYMLINK
`apps/nas-mcp/src/nas-tools.ts → ../../../packages/shared/src/nas-tools.ts` +
`preserveSymlinks:true`, so its dist (dist/index.js + dist/nas-tools.js) and
tools-config path are unchanged; nas-mcp Dockerfile now builds from repo root
(context: .) and nas-mcp-image.yml watches packages/shared/**. The catalog is a
SEPARATE subpath export `@synology-monitor/shared/nas-tools` (NOT the client-safe
barrel) so zod + shell templates stay out of the web client bundle. Web Stage 2
now builds its catalog from the shared source (72 tools = 71 read-only +
fetch_evidence; target stripped from model schema; tier-1-only guard intact);
web declares zod. NOTE: owner should confirm claude.ai MCP still connects to
nas-mcp after its redeploy.

FLEET CUTOVER DONE + deployed 2026-05-30 (commit `72a4498`): v2 is now the
DEFAULT in code (issue-workflow.ts) — not a Coolify env opt-in. The owner refused
to touch Coolify (rule: agent/repo side never writes Coolify runtime env — see
CLAUDE.md + AGENTS.md §15; I declined the token 3x), so the cutover was done as a
code default (goes through GitHub, in-rules). Kill switches: ISSUE_PIPELINE_V2=
false (fleet) or metadata.pipeline="v1" (per-issue); fleet rollback = git revert
`72a4498`. Legacy runIssueAgent + 7 stage fns KEPT as the fallback until proven
stable, THEN removed.

**Resume at: monitor v2 in prod, then FINAL CLEANUP.** v2 validated on one issue
2026-05-30 (operator: "looks good"), now fleet default. Watch real issues
(transitions, approval-gate path, cache_hit_ratio in Settings→AI Stages). Once
stable, do the final cleanup (remove v1 runIssueAgent + the 7 stage fns in
issue-stage-models.ts + OpenRouter callStageModel path + retired alias keys;
keep second_opinion_model/cluster_model). Pending after validation:
flip global ISSUE_PIPELINE_V2=true (owner, Coolify) → monitor → then FINAL
CLEANUP (remove v1 runIssueAgent + the 7 old stage fns in issue-stage-models.ts +
OpenRouter inference path in callStageModel + retired alias keys, after
confirming no readers; keep second_opinion_model/cluster_model). Also still
pending: (5c) §6 tool-catalog sharing into
packages/shared + nas-mcp build-context/paths/Dockerfile change (cross-app, 2nd
deployable; Stage 2 already uses web's own tools.ts so this is a dedup/upgrade,
NOT a blocker); (8) CUTOVER + cleanup = wire the new stage runners
(stage1-structurer/stage2-reasoning/stage2-turn/stage3-explainer) into the worker
to replace runIssueAgent's internals, then remove the old 7-stage code +
OpenRouter inference path + retired alias keys. **Step 8 is the live
point-of-no-return and MUST NOT run until ANTHROPIC_API_KEY + GEMINI_API_KEY are
live in Coolify** — cutting over without them breaks the production issue agent
(Stage 2→Anthropic missing_key). Provider keys (ANTHROPIC/GEMINI/DEEPSEEK/
DASHSCOPE) still net-new — owner must add in Coolify. Everything through step 7 is
additive/dormant; the live pipeline is still the old 7-stage one.

**How to apply:** Target = replace the 7-call OpenRouter no-caching pipeline with
3 config-driven stages (lossless structurer → cached strong reasoning core with
live NAS tools + re-chew guard → explainer/memory). Models + reasoning-effort are
operator-chosen at runtime via admin (3 stages × 2 dropdowns + a copy-spec button)
— nothing hardcoded. Caching is provider-native (Anthropic/OpenAI/Gemini/DeepSeek/
Qwen direct SDKs, NO aggregator on the inference path), stable-before-dynamic,
with normalized usage + cache_hit_ratio + CI guards. New provider API keys must be
added in Coolify before each provider works in prod. Secret rotation
([[leaked-secrets-pending-rotation]]) is still outstanding.
