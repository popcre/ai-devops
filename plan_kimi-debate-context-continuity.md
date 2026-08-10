# Plan: make Kimi K3 debates preserve the right context and converge safely

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Re-verify Kimi 0.32.0 STEP 0 behavior | ✅ complete | 2026-08-10 | Header re-qualified; live Read succeeded and hostile Write returned `CANNOT_WRITE` without changing the canary. |
| 2. Add Kimi debate and context-health rules | ✅ complete | 2026-08-10 | Shared skill now requires exact-session delta turns, current-artifact re-read, bounded rebuttals, and no unavailable metrics. |
| 3. Use the shared consensus ledger | ✅ complete | 2026-08-10 | Kimi consumes the Grok-owned provider-neutral template and stores durable state in the active artifact. |
| 4. Extend offline and live tests | ✅ complete | 2026-08-10 | Pre-guard suites passed 54/0 offline and 62/0 live; final counts including the one-shot implement guard are recorded by this session below. |
| 5. Run the live K3 debate | ✅ complete | 2026-08-10 | Session `session_224373ef-2295-435e-860c-298b6e99e0f0`; one rebuttal; Kimi re-read the fix and reported no material Kimi objection. |
| 6. Document, install, commit, and push | 🟨 partial | 2026-08-10 | Docs updated; install and local verification are being completed here; commit/push belong to the root integrator. |

Fresh sessions start at the first open row and keep this table current. This plan depends on the completed shared-template rows in `plan_grok-debate-continuity.md` and must not run concurrently with that plan. Before editing or pushing, pull `origin/main`, inspect concurrent work, and create one write-once `HANDOFF.d/<UTC>-<machine>-<agent>-kimi-debate-context-continuity.md` file cross-linked to this plan.

Planning record: `HANDOFF.d/2026-08-10T0000Z-albt16-codex-delegate-integration-plans.md`.

## 1. Ultimate goal

Claude or Codex must be able to debate code and implementation plans with Kimi K3 across multiple turns while preserving the exact conversation, supplying current repository evidence, avoiding accidental context loss, and reaching honest consensus. If a step conflicts with this goal, the goal wins: stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is Albert's multi-model workflow toolkit. `bin/ai-kimi` wraps Kimi Code CLI in named, persistent sessions with a pinned `kimi-code/k3` model and structurally read-only review profile at `config/kimi/readonly-review.md`. The shared Claude/Codex skill is `skills/shared/kimi-code-delegation/SKILL.md`; tests are `tests/test-ai-kimi.sh`. Work is on `main` in `C:\repos\ai-devops`.

## 3. What triggered this work

The 2026-08-09 audit found exact session resume and strong safety, but the skill lacks GLM's explicit debate-relay procedure. Kimi 0.32.0 officially persists and replays sessions and automatically compacts long contexts, but headless output exposes no tokens, cache-read counts, cost, or returned model. The current skill correctly refuses to claim savings, yet it gives no operational rule for detecting when a long debate may have been compacted or for restating durable conclusions without flooding every prompt.

## 4. Scope

In scope: shared debate fields; Kimi-specific exact-session and context-health rules; bounded convergence; preservation of durable conclusions; tests using observable session/output evidence; current Kimi docs.

Out of scope: claiming unreported cache savings/model identity; changing provider/model; hand-editing Kimi session files; enabling Bash/write/network in review; changing implementation isolation; automating TUI-only slash commands through unsupported headless input; unbounded autonomous debate.

## 5. Current code state

- `bin/ai-kimi:16-54` owns model pin, completion marker, and verified CLI constraints.
- `bin/ai-kimi:118-180` resolves credentials and keys records by repo/caller/name.
- The wrapper resumes explicit IDs and requires terminal `session.resume_hint`.
- `config/kimi/readonly-review.md` allows only `Read`, `Grep`, `Glob`, and `ReadMediaFile` and requires a `## Verdict`.
- `skills/shared/kimi-code-delegation/SKILL.md:46-70` covers session reuse and prefix-stable briefs, but no debate relay or context-compaction strategy.
- `bash tests/test-ai-kimi.sh` produced 35 passed, 0 failed on 916-alien on 2026-08-09; authenticated canaries remain opt-in.
- Repo base before planning: `00e1231fe9b2aae209764bb50ced2d4d844ff015`.

## 6. Findings and root cause

Transport continuity is reliable because `ai-kimi` resumes an explicit ID. Semantic continuity is not guaranteed merely by replay: automatic compaction is intentionally lossy, repository files may change between turns, and Kimi supplies no cache/context counters in headless output. The root gap is missing parent-agent discipline: no standard delta message, no requirement to re-read current artifacts, no durable consensus ledger, and no rule for what to do when Kimi's answer suggests old context was lost.

## 7. Rejected approaches

1. Claim Kimi's cache is working because the session resumed. Rejected; no counters prove provider cache use.
2. Parse or edit `~/.kimi-code/sessions/*/wire.jsonl` to manage context. Rejected; official docs warn not to edit session data, and transcripts may contain sensitive content.
3. Send `/compact` through headless prompt mode. Rejected unless current CLI documentation and a live test prove it is a control command there; slash commands are documented for TUI.
4. Re-paste the full plan and transcript each turn. Rejected because Kimi can read files and large changing prefixes harm caching.
5. Start fresh when Kimi forgets one fact. Rejected initially; first provide a concise durable-state refresh in the same exact session and re-check.
6. Treat polite agreement as consensus. Rejected without current-file inspection and claim-by-claim adjudication.

## 8. Design decisions

Locked on 2026-08-09: explicit session IDs; separate Claude/Codex records; pinned K3 request; no cache/model/cost claims; no session-file edits; read-only agent unchanged; shared stable debate headings; current files re-read every material turn; bounded initial review plus at most three rebuttal turns; durable conclusions stored in the plan/artifact rather than only in chat.

Open: whether the `kimi` CLI's own supported output exposes non-sensitive context metadata. Do not add any direct read of `~/.kimi-code` files, including `state.json`; if the CLI does not expose it, remain deliberately unmeasured.

### Consensus ledger, verified 2026-08-10

#### Agreed decisions

- Exact named review sessions prove transport continuity only; current-file re-reading and this durable ledger protect semantic continuity.
- Debate turns use `templates/delegation/debate-turn.md`, delta-only rebuttals, an initial review plus at most three rebuttals, and explicit unresolved objections at the bound.
- Kimi headless output supports no cache, context-size, token, cost, or returned-model claim. The wrapper proves only the requested model pin.
- Implement sessions are one-shot. Their throwaway worktree is deleted after patch emission, so `ask` must never resume a write-capable session in the live repository.

#### Rejected alternatives

Newest-directory resume, raw session-file edits, unsupported headless `/compact`, full transcript re-paste, polite agreement as consensus, and implement-session continuation in the live repo.

#### Unresolved objections

None in Kimi scope. Kimi's first turn found the implement-resume safety hole; Codex agreed and fixed it. Kimi's same-session rebuttal re-read the changed wrapper, skill, and regression test and reported no material Kimi safety, context, or convergence objection.

#### Evidence still needed

Commit and remote verification by the root integrator. CI and deployment are N/A for this script-and-doc toolkit.

#### Last verified commit and path state

Base commit `281539d122c1ba2d2470cefa27099a649629fbc2` on `main`. The live debate ran in an isolated worktree containing only the exact integrated GLM, Grok, and Kimi changes because unrelated sessions were actively editing the shared checkout. Kimi re-read the current Kimi wrapper, test, skill, plan, and shared template on the rebuttal turn.

## 9. Ordered implementation plan

1. Before all other work, re-run every STEP 0 probe in `bin/ai-kimi` against installed Kimi 0.32.0: documented/hidden resume flags, `stream-json` shape, terminal `session.resume_hint`, provider-list false-OK behavior, agent/resume conflict, model pin, prompt-mode restrictions, and both directions of the case-sensitive tool canary. Update the header with measured 0.32.0 evidence. Gate: all signals used by the wrapper are re-qualified or the plan stops for wrapper repair.
2. Consume the completed `templates/delegation/debate-turn.md` owned by the Grok plan. Update `skills/shared/kimi-code-delegation/SKILL.md` with Kimi-specific “Relaying a debate” and “Context health” rules: exact-session `ask`, stable headings, delta-only follow-ups, current-artifact re-read, and no numerical cache claims. Gate: Kimi, Grok, and GLM skills point at the same field contract while keeping provider-specific commands separate.
3. Use the consensus-ledger fields inside `templates/delegation/debate-turn.md`; do not change the global implementation-plan standard. The parent updates the active plan's existing design/rejected/open sections and the debate ledger after each resolved turn, then Kimi reads the updated file. Gate: final decisions are reconstructable without raw session history.
4. Extend `tests/test-ai-kimi.sh`. Offline stub/static tests: template fields, explicit ID, caller separation, terminal resume hint, profile declarations, same-session recovery command, and forbidden cache/cost/model claims. `AI_KIMI_LIVE=1` tests: read/write canaries, three-turn continuity marker, changed artifact re-read, and same-session durable-state refresh. Gate: offline suite exceeds 35 tests; live suite passes on each authenticated target platform used for rollout.
5. Run one real K3 debate over these three plan files. Ask Kimi to challenge completeness, caching assumptions, safety, exact steps, and convergence. Revise files, send only the delta plus the current parent session's remaining objections (the Codex parent when Codex drives the debate), and repeat in the same session until both sides explicitly list no material objections or the three-rebuttal bound is reached. Gate: same Kimi session ID throughout; final verdict states the files were re-read and names any unresolved risk; no working-tree mutation by Kimi.
6. Update `docs/architecture.md`, `docs/development.md`, `docs/skills-usage-guide.md`, plan STATUS, and installed skill copies. `AGENTS.md` already routes these plans; edit it only if names or trigger text change. Pull/recheck concurrent status before the focused commit/push and remote SHA verification. Gate: Claude/Codex installed files hash-match source and repo is clean.

Natural cut: after step 3. A fresh session must re-read steps 4-6 and the consensus ledger.

## 10. Tests required

- Exact session ID used for every debate continuation; never `--continue`.
- `AI_KIMI_LIVE=1`: three-turn harmless continuity marker.
- `AI_KIMI_LIVE=1`: changed plan file is re-read and a new fact observed.
- `AI_KIMI_LIVE=1`: same-session durable-state refresh after a simulated forgotten fact.
- Terminal `session.resume_hint` required.
- Read succeeds and write fails under the case-sensitive profile.
- No false cache/token/cost/returned-model claims.
- Bound ends with explicit unresolved objections rather than false consensus.
- Existing 35 offline tests remain green.

## 11. Constraints and gotchas

Main-only; Albert commit identity; use `ai-kimi`, never raw Kimi for review; set `AI_KIMI_CALLER=codex` from Codex; do not use `-c`; tool names are case-sensitive; no Bash/network/write in review; do not inspect or edit raw session files; do not claim unavailable metrics; do not assume `/compact` works headlessly; Kimi cannot run review tests, so the parent supplies output; preserve unrelated changes and secrets.

## 12. Access and environment

Kimi Code 0.32.0 at `%USERPROFILE%\.kimi-code\bin\kimi.exe`, OAuth authenticated, K3 configured. `ai-kimi doctor` passes. Git Bash, Git, and `gh` are present. No 1Password, browser, production, database, or deployment access is needed.

## 13. Definition of done, risks, and open questions

Done: 0.32.0 surface re-qualified; shared contract dependency complete; Kimi context-health/recovery rules; durable consensus ledger; offline/live tests; real K3 debate reaches honest consensus or documents bounded unresolved issues; docs/installed skills current; correct commit pushed and remote-verified. CI/deploy are N/A.

Risks: automatic compaction may omit an old nuance; continuity marker tests replay but not provider caching; rigid templates may add tokens; a parent may paraphrase another model unfairly. Mitigate with exact attributed reasoning, current-file re-read, durable ledger, and no cache claims. Roll back via Git revert and reinstall skills. Open question about supported context metadata is resolved only by current official CLI capability; otherwise remain deliberately unmeasured.

## Mandatory self-audit

1. Yes. Sections 2-6 establish the integration and precise semantic gap; sections 8-10 give implementable steps and tests.
2. Yes. Sections 6-8 preserve compaction uncertainty, unavailable metrics, recovery policy, and rejected unsupported controls.
3. Yes. Section 1 defines truthful, durable continuity and overrides conflicting steps.

All 13 sections and checklist items pass, including scope, rejected paths, locked/open decisions, exact tests, environment, risks, rollback, commit/push, and N/A CI/deploy. Self-audit passed on 2026-08-09.
