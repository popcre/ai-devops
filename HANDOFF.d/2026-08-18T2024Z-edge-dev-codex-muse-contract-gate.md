---
issue: 40
status: OPEN
owner: main / edge-dev Codex / Muse OpenCode harness
---

# HANDOFF - Muse OpenCode contract gate (2026-08-18T2024Z, edge-dev/Codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None. The Meta Model API key already exists and the required Contributor model was
proved available. Continue the approved plan without asking Albert to select a model,
change a tier, or provide a key.

Already settled, do not re-ask:

- 2026-08-18: use `muse-spark-1.2-contributor` only. Never substitute standard Muse.
- 2026-08-18: Contributor's provider-training terms are accepted by Albert.
- Keep Muse and GLM as separate services, state, credentials, ports, and reports.
- Reviews remove tools; implementations use only a remote-less disposable clone.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Windows and Ubuntu toolkit for operating AI
coding helpers. It is a set of Bash commands, PowerShell setup scripts, documentation,
and tests. It is not a web app or a cloud service. This workstream, GitHub issue #40,
adds a separate OpenCode-backed Muse helper without weakening the existing GLM helper.

The governing implementation specification is `plan_muse-opencode-harness.md`. Its
STATUS table is authoritative; read it before editing any Muse or GLM file.

## 2. What we set out to do this session, and why

Albert asked to implement the Muse Spark OpenCode harness. The first mandatory gate
was to prove that the real account has the exact Contributor model, that Meta supports
the necessary conversation and tool behavior, and that the pinned OpenCode build can
use it. The plan expressly forbids constructing the shared GLM/Muse core before that
proof because a provider mismatch would make the rewrite unsafe.

## 3. Current state - what is true right now

- Step 1 is complete and pushed in commit `0296dd468e96e3f5c8356b8ac8b380efba915524`
  (`Add Muse OpenCode contract evidence`). Confirm it remains on `origin/main` with
  `git merge-base --is-ancestor 0296dd4 origin/main`.
- `plan_muse-opencode-harness.md` marks Step 1 complete and records the actual evidence.
- `docs/muse-opencode.md` records the durable facts and explicitly labels unavailable
  cache, pricing, rate-limit, and cancellation fields rather than inventing values.
- `docs/verification/muse-opencode/2026-08-18T2020Z-contract/README.md` is the redacted
  result. `tests/fixtures/muse-opencode/contract-2026-08-18.json` is the offline replay
  fixture. Run `bash tests/test-muse-opencode-contract.sh`; it passed.
- `tests/probes/muse-opencode-contract.sh` is an opt-in live probe. It requires
  `AI_MUSE_LIVE=1` and `MODEL_API_KEY`, prints only status and response structure, and
  never stores a key, prompt, completion, header, or raw error body.
- `tests/fixtures/muse-opencode/opencode-1.18.12.json` is the exact temporary config
  that loaded and ran through the pinned binary. It has no literal key.
- No `ai-muse` command, Muse service, Windows task, Ubuntu unit, shared core, or Muse
  skill exists yet. Step 2 is the next open task.
- The shared checkout has unrelated work from other sessions. At handoff creation,
  only `.ai/` was untracked in this session's status; never add unrelated Gemini files
  or `.ai/` to this workstream.

## 4. Everything we tried that did NOT work

1. Searching for an item named `Meta Model API` failed because the real 1Password item
   is named `Meta ai Muse Spark API Key`. Do not create a duplicate item. Its populated
   field is `api key`; `credential` is blank.
2. A minimal completion with too-small `max_tokens` ended with `finish_reason=length`.
   That is not a successful harness completion. The multi-turn probe succeeded only
   with `reasoning_effort: low` and a larger token limit, producing `finish_reason=stop`.
3. Forcing OpenAI `tool_choice` caused a 400. Leaving the tool available let Contributor
   return a normal `tool_calls` finish with the expected function name. Do not make a
   forced-tool request the compatibility test.
4. The current OpenCode public documentation uses a newer `providers` plus
   `@opencode-ai/ai/providers/openai-compatible` format. Pinned OpenCode 1.18.12 loaded
   the legacy `provider` plus `@ai-sdk/openai-compatible` format instead. Copying the
   current documentation into the pinned server would break the gate we just proved.

## 5. Root causes and key findings

- Authenticated `GET https://api.meta.ai/v1/models` returned the exact required model,
  plus standard 1.2 and 1.1. The model identifier is not an assumption.
- Direct Meta calls to `/chat/completions` proved streaming, function calling, and
  multi-turn continuity. Invalid authentication returns 401 and an invalid model returns
  404; both use structured `error` fields `code`, `message`, `param`, and `type`.
- Tested Meta usage has completion, prompt, total, and detail token fields, but no cache
  fields. Cache and cost must be represented as unavailable until a measured result
  supplies them.
- The pinned binary is
  `C:\Users\ahazan\.local\lib\ai-devops\opencode\1.18.12\node_modules\opencode-ai\bin\opencode.exe`.
  A temporary empty Git repository plus the fixture config completed a harmless run.
  Its log recorded `providerID=meta-model-api` and
  `modelID=muse-spark-1.2-contributor`.
- `docs/glm-opencode.md` section 5 remains binding: tool removal is the review control,
  a remote-less clone is the implementation control, and a turn finishes only on
  `finish == stop` plus two idle polls.

## 6. Exact next steps

1. Start Step 2 from `plan_muse-opencode-harness.md`. Read `docs/glm-opencode.md` section
   5 in full, then characterize `bin/ai-glm` before moving code. You will know the
   baseline is safe when `bash tests/test-ai-glm.sh` and its listed related suites pass
   without a Muse variable influencing GLM state or model selection.
2. Extract one provider-neutral core, preferably `bin/lib/ai-opencode-harness.sh`, and
   make `bin/ai-glm` a thin immutable GLM profile. Keep every public command, exact
   state directory, port, agent, model, report prefix, recovery record, and error
   behavior unchanged. You will know it worked when the new harness tests and existing
   GLM, review-sandbox, review-packet, and Windows script suites pass.
3. Run the optional paid GLM parity sequence only after the offline extraction passes:
   `doctor`, `new`, `ask`, `transcript`, `delete`, `implement`, `show`, `delete`.
   Save only redacted evidence under `docs/verification/muse-opencode/`. You will know
   it worked when each command keeps the original model, provider, state, and safety
   behavior.
4. Update the plan STATUS and Current state in the same commit, then use the required
   fresh-session cut. Do not begin Muse configuration until GLM parity passes.

## 7. Constraints and gotchas in force

- Work directly on `main`; stage only issue #40 files. Verify the Albert Hazan noreply
  identity before every commit. The shared checkout may move while you work.
- Never expose, log, place in config, or commit the Meta key. Use the existing 1Password
  item only at process launch.
- Never send actual repository content during a provider contract probe. Use a new,
  empty Git repository and harmless text.
- Do not upgrade OpenCode. Version 1.18.12 is the qualified GLM version; an upgrade
  needs a separate requalification plan.
- Do not trust OpenCode permission maps. The agent `tools:` map is the measured review
  protection. Do not give review a shell, write, edit, patch, web, or sub-agent tool.
- Do not point a reviewer at a raw linked worktree. Use `bin/ai-review-sandbox ensure`.
- PowerShell files must be ASCII-only. A non-elevated ordinary PowerShell session is
  required later to prove the Windows scheduled task; SSH cannot prove that.
- Do not edit `HANDOFF.md` or another session's handoff. This file is open until issue
  #40 is truly complete.

## 8. Access and environment

- Repository: `C:\repos\ai-devops`, remote `u2giants/ai-devops`, branch `main`.
- Current source of truth: `origin/main`; this session's Step 1 commit is `0296dd4`.
- Machine: `edge-dev`, Windows, PowerShell 7 and Git Bash. Run Bash tests using
  `C:\Program Files\Git\bin\bash.exe`.
- 1Password is available. The key location is vault `vibe_coding`, item
  `Meta ai Muse Spark API Key`, field `api key`. Do not print it. There is no need to
  create or change any secret item.
- Meta endpoint: `https://api.meta.ai/v1`; required environment variable:
  `MODEL_API_KEY`; required model: `muse-spark-1.2-contributor`.
- OpenCode binary is installed at the path in section 5 and reports 1.18.12.

## 9. Open questions and risks

- Pricing and the exact Contributor data-use text were not returned by the API. The
  owner already accepted the tier; keep price/cache reporting explicitly unavailable
  until authenticated Meta terms or a measured result supplies it.
- Rate-limit and cancellation behavior were not deliberately triggered because that
  would waste allowance. The common core must classify any unknown or interrupted
  provider state as incomplete, never as success.
- The broad Step 2 extraction is the highest regression risk. Do not copy `ai-glm` to
  create Muse and do not perform a one-step rewrite. Preserve characterization tests and
  stop before Muse work if GLM parity changes.
- Ubuntu and ordinary-user Windows qualifications remain required later. Neither may be
  claimed from this Windows account probe.

## Mandatory self-audit

1. Yes. Sections 1-3 define the toolkit, plan, exact commit, files, evidence, and
   unfinished work; sections 6 and 8 let a newcomer continue without a question.
2. Yes. Sections 4-5 preserve the actual item-name, completion, tool-choice, provider
   configuration, response-shape, and OpenCode findings that would otherwise be repeated.
3. Yes. Sections 1-9 cover the goal, state, failures, decisions, constraints, risks,
   access, next actions, and verification evidence. Secrets are location-only.
4. Yes. I swept sections 1-9 for owner decisions. Section 0 contains none outstanding
   and lists every already-settled choice, so Albert need not answer anything to resume.

Self-audit passed. A fresh developer can continue from Step 2 without relying on this chat.
