# IMPLEMENTATION PLAN — Reviewer token-waste fixes (2026-10-07)

Parent issue: [#1436](https://github.com/popcre/ai-devops/issues/1436) ·
Source audit: [#1426](https://github.com/popcre/ai-devops/issues/1426) ·
Handoff: [`HANDOFF.d/2026-10-07T2122Z-edge-dev3-claude-reviewer-spend-waste-plan.md`](HANDOFF.d/2026-10-07T2122Z-edge-dev3-claude-reviewer-spend-waste-plan.md)

## STATUS (2026-10-07, 10:10 PM EDT)

| Step | Child issue | State | Evidence |
|---|---|---|---|
| C1 Remove silent paid-key fallbacks | [#1427](https://github.com/popcre/ai-devops/issues/1427) | ✅ done | PR #1447 `5cbd3c34`; proof #1427 comment 6049807001 |
| C2 Pool reuses passing report (same reviewer + head + digest) | [#1428](https://github.com/popcre/ai-devops/issues/1428) | ✅ done | PR #1443 `17e73b3f`; proof #1428 comment 6049580379 |
| C3 Allocator: no extra reviewer on a passed head | [#1429](https://github.com/popcre/ai-devops/issues/1429) | ✅ done | PR #1470 `2608d23b`; proof #1429 comment 6050543916; shared-db allocator already compliant (evidence #1429 comment 6050669615) |
| C4 Stable cache prefix in briefs | [#1430](https://github.com/popcre/ai-devops/issues/1430) | ✅ done | PR #1444 `1ce948db`; proof #1430 comment 6049157726 |
| C5 Skip reviewers in known quota exhaustion | [#1431](https://github.com/popcre/ai-devops/issues/1431) | ✅ done | PRs #1404 `08ef1c73`, #1454 `07962593`; proof #1431 comment 6049417681 (GLM excluded until 2026-10-09) |
| C6 StepFun pacing / usage / one doctor call | [#1432](https://github.com/popcre/ai-devops/issues/1432) | ✅ done | PR #1445 `bc86d832`; proof #1432 comment 6049332545 |
| C7 Gemini keeps finished reviews / one model call | [#1433](https://github.com/popcre/ai-devops/issues/1433) | ✅ done | PR #1442 `3a663e28`; proof #1433 comment 6048571095 |
| C8 DeepSeek append-only compaction | [#1434](https://github.com/popcre/ai-devops/issues/1434) | ✅ done | PRs #1441, #1452, #1477 `9b437917`; proof #1434 comment 6050577168 |
| C9 Tests stop writing live events log | [#1435](https://github.com/popcre/ai-devops/issues/1435) | ✅ done | PR #1450 `f1b39060`; proof #1435 comment 6050794930 |

**All children done (2026-10-07, 10:20 PM EDT); parent #1436 closed.** Do only that child, tick it, comment the next child on the parent, and stop. A row becomes "done" only with an artifact (merge SHA, CI run id, or test file path) and live proof recorded on the same child issue.

## 1. The ultimate goal — what we are trying to achieve

AI reviewers cost Albert real money and allowance. Today the same commit is reviewed repeatedly by the same reviewer, by several reviewers at once, and through prompts that cache poorly; and several wrappers would quietly switch to a pay-per-use API key if one happened to be in the environment. When this is done: reviewer token spend drops substantially (target: the ~20M+ tokens/day of duplicate and wasted work named in #1426), no reviewer can ever bill a pay-per-use key unless that key is its explicit, designed credential, and review quality and capability are unchanged — no reviewer loses depth, turns, or the ability to finish a big job.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` (GitHub `https://github.com/popcre/ai-devops`, branch `main`) is Albert Hazan's AI workflow toolkit: reviewer wrappers (`bin/ai-*`), the review pool (`bin/ai-review-pool`), runner doors (`tools/lib/review-doors/*.sh`), the reviewer event log (`tools/reviewer_events.py`), installers and docs. It is installed onto Albert's machines (edge-dev3, edge-dev, hetz, 916-alien, Windows hosts); it is not a web service. Reviewers: Codex, GLM, Muse, Gemini, Qwen, DeepSeek, StepFun, Kimi (and Grok, out of scope). The reviewer allocator (who reviews what) lives in `popcre/shared-db` `scripts/lib/lanes/reviewer-roster.mjs` and `scripts/manage-migration-author-lanes.mjs` (see `docs/reviewer-rotation-rules.md:6-12`).

Terms: **door** = the per-provider runner script used by the pool; **packet** = the sealed evidence snapshot (`bin/ai-review-packet`); **source digest** = `REVIEW_DIGEST` in the pool state; **events log** = `~/.local/state/ai-devops/reviewer-events/events.jsonl` (override `AI_REVIEW_EVENT_DIR`).

## 3. What triggered this work

Read-only audit #1426 (edge-dev3, 2026-10-07, at `origin/main` 3eb7c605) measured reviewer spend after dispatch volume jumped with #1322 (2026-10-06): ~315-370 dispatches/day. Ranked waste: repeat reviews of the same commit (~10M/day), multiple reviewers per commit (~7-10M/day), poor cache prefix (~10-20% of input), StepFun 429 cold reruns, Gemini discarded reviews (~1.5M/day), DeepSeek compaction cache misses (~1-1.5M/day), dispatch into exhausted quota, and small extra calls. It also found silent paid-key fallbacks in the Gemini and Qwen doors plus latent ones in Codex, Kimi and DeepSeek.

## 4. Scope — in and out

In: C1-C9 below, in ai-devops wrappers/doors/pool/tests (C3 also touches the shared-db allocator code — scripts, not database structure).

NOT in this plan:
- Grok (`bin/ai-grok-review`, `review-doors/grok.sh`) — owner excluded it; its fallback removal followed PR #1243.
- Any cap or reduction of turn/step/tool-call budgets, including reverting Qwen's 120 turns.
- Codex Desktop interactive usage (~0.9B tokens over 2 days, not a reviewer).
- Billing-console access (StepFun, Muse, DeepSeek consoles).
- Muse capacity relaunch loop (`bin/ai-muse` ~806-828): Meta reports these unbilled.
- The #1426 UNMEASURED gaps (Kimi usage on hetz, GLM 7-day history, Qwen failure cause) except where a step needs them.

## 5. Current state of the code

**HISTORY — all of C1-C9 is implemented and merged (see STATUS); do not redo.** The table below records the pre-fix code as it was on `origin/main` 3eb7c605 on 2026-10-07, kept so the reasons behind each fix survive; line numbers no longer match:

| Item | Location (verified) |
|---|---|
| Pool brief heredoc; per-run fields in paragraph 2 | `bin/ai-review-pool:318-330` (head/digest/files at line 321) |
| Pool head/digest read | `bin/ai-review-pool:263` |
| Grok-only turn cap (leave alone) | `bin/ai-review-pool:56` |
| StepFun retry loop | `bin/ai-stepfun:203-213` (`run_step_retry`) |
| StepFun door 429 rerun | `tools/lib/review-doors/stepfun.sh:416-429` |
| StepFun report writer (no usage parsed) | `bin/ai-stepfun:232-250` |
| StepFun doctor STEPFUN-OK calls | `bin/ai-stepfun:562`, `:630` |
| Gemini source-drift rejection | `bin/ai-gemini:618` (audit said 616; the check is 618) |
| Gemini second model call | `bin/ai-gemini:568` (`verify_model`) |
| DeepSeek compaction | `tools/deepseek_repo_tools.py:485-522` (`compact_tool_messages`), `COMPACT_KEEP_RESULTS` at :50 |
| Gemini door key chain | `tools/lib/review-doors/gemini.sh:83-98`, export at :153 |
| Qwen door ambient key | `tools/lib/review-doors/qwen.sh:77-78`, export at :176 |
| Codex review launch | `bin/ai-codex-review:287` |
| Kimi readiness (any provider passes) | `bin/ai-kimi:247-250` |
| DeepSeek model env | `bin/ai-deepseek:172` (`check_model`), `:178` (`DEEPSEEK_MODEL`) |
| GLM coding-plan only (no change) | `bin/ai-glm:76` |
| Muse door SHA/packet path at prompt top | `tools/lib/review-doors/muse.sh:210-216` |
| Qwen quota reset capture | `bin/ai-qwen:855`, `:1585` (commit b0250b5e, #1327) |
| Events log location | `tools/reviewer_events.py:18-22`; guard `tools/reviewer_event_guard.sh:77` |

## 6. Key findings and root cause

- The pool has no memory: every dispatch is a cold session even when an identical passing report already exists in the events log.
- The allocator does not consider existing passes on a head.
- Prompt order puts per-run data (SHA, digest, files) before the long fixed text, so caches cannot share the prefix.
- StepFun handles a 429 by rerunning the full turn cold (`--no-session`), paying the whole prompt again.
- Gemini's protected-checkout inventory sees other sessions' scratch writes in a shared checkout and rejects valid finished reviews.
- DeepSeek compaction re-stubs older tool results each round, changing earlier bytes and breaking prefix caching (71% vs ~90%).
- Doors added in #1322 (85b5ff57, 2026-10-06) accept generic API key variables ahead of subscription logins.
- Test suites that run wrappers without `AI_REVIEW_EVENT_DIR` write ~600 stub records per 2 days into the live log, distorting counts.

## 7. Approaches considered and REJECTED, and why

- **Lower turn/step budgets** — rejected by owner: big jobs would hit the cap and restart, costing more. Qwen's 120 stays.
- **Fewer reviewers by retiring providers** — reduces capability; the allocator alone decides membership.
- **Truncating packets/diffs** — packets are already diff-based and split (not truncated); truncation lowers quality.
- **Keeping key fallbacks but logging a warning** — still bills silently in headless runs; owner ordered removal, as for Grok after #1243.
- **Gemini: disable the source-drift check** — removes a safety control; instead compare against the start snapshot and exclude foreign scratch dirs.
- **StepFun: more retries** — multiplies cost; pace before the call instead.

## 8. Design decisions already made (dated)

- LOCKED (Albert, 2026-10-07): never cap turn/step budgets; Qwen's 120-turn raise stays.
- LOCKED (Albert, 2026-10-07): remove every silent pay-per-use API-key fallback (same as Grok after #1243). Muse and StepFun are pay-per-key by design and keep their reviewer-specific protected keys.
- LOCKED (Albert, 2026-10-07): Grok out of scope.
- LOCKED: one child issue per step; live proof stays on that child issue.
- OPEN: C2 reuse key — whether `mode` (plan/diff/security/final-check) is part of the key (recommended: yes).
- OPEN: C3 explicit-request mechanism (flag name) and whether it lands in shared-db, ai-devops preflight, or both.
- OPEN: C6 pacer design (a token-bucket file under the StepFun state dir is suggested).
- OPEN: C7 whether `verify_model` remains as fallback when main-response metadata lacks a model id (recommended: yes).

## 9. The plan — numbered, ordered steps

Each step is one child issue and one PR. Re-read later steps before starting each one (drift check).

### C1 — Remove silent paid-key fallbacks (#1427) — trust boundary, highest priority
Files: `tools/lib/review-doors/gemini.sh:83-98,153`; `bin/ai-gemini` (env before `agy`); `tools/lib/review-doors/qwen.sh:77-78,176`; `bin/ai-codex-review:287`; `bin/ai-kimi:247-250`; `bin/ai-deepseek:178`; `bin/ai-review-pool` and `bin/ai-review` dispatch env.
Behavior: Gemini door and wrapper unset `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `AI_GEMINI_KEY` and use only agy's subscription login. Qwen door uses only the protected token-plan store (as `bin/ai-qwen:73-78,95-108` already does). Codex review runs with `OPENAI_API_KEY` and `CODEX_API_KEY` unset (auth from the `~/.codex/auth.json` ChatGPT login). Kimi readiness requires the `kimi-code` subscription provider by name. `ai-deepseek implement` ignores `DEEPSEEK_MODEL` (Pro only via explicit `--model`, printed). Pool and `ai-review` strip the generic variables before dispatch.
Gate: every adversarial row below passes; one live review per changed reviewer succeeds on subscription login with a fake key exported in the shell.

| External input | Hostile case | Test (to add) |
|---|---|---|
| `GEMINI_API_KEY` | set to fake key in caller env | `tests/test-ai-gemini.sh`: `gemini_ignores_generic_api_keys` |
| `GOOGLE_API_KEY` | set, with no Gemini login | `tests/test-pool-dispatch-doors.sh`: `gemini_door_refuses_google_key_fallback` |
| `AI_GEMINI_KEY` | set to fake key | `tests/test-pool-dispatch-doors.sh`: `gemini_door_unsets_ai_gemini_key` |
| `OPENAI_API_KEY` (Qwen door) | ambient key present, store empty | `tests/test-ai-qwen.sh`: `qwen_door_ignores_ambient_openai_key` |
| `OPENAI_API_KEY` / `CODEX_API_KEY` | set before codex-review | `tests/test-ai-codex-review.sh`: `codex_review_unsets_api_keys` |
| Kimi provider list | only a Moonshot pay-per-use provider configured | `tests/test-ai-kimi.sh`: `kimi_readiness_requires_kimi_code_provider` |
| `DEEPSEEK_MODEL` | `deepseek-v4-pro` in env | `tests/test-ai-deepseek.sh`: `deepseek_implement_ignores_model_env` |
| Pool env | all generic keys set | `tests/test-pool-dispatch-doors.sh`: `pool_strips_generic_keys_before_dispatch` |
| `bin/ai-review` env | all generic keys set | `tests/test-ai-review-engine.sh`: `ai_review_strips_generic_keys` |

### C2 — Pool reuses passing report (#1428)
Files: `bin/ai-review-pool` (after `:263`, before dispatch); `tools/reviewer_events.py` new `find_passing_report(directory, provider, mode, head, digest)` using `location()`.
Behavior: same provider + mode + head + source digest with a verified, well-formed APPROVE → print the report path and exit 0, no provider call. `--force` bypasses. Lookup errors fall through to a normal review and say so.
Gate: a second identical run makes zero provider calls.
Tests: `tests/test-pool-dispatch-doors.sh` new `reuse_same_head_digest`, `no_reuse_on_digest_change`, `force_bypasses_reuse`, `corrupt_events_falls_through`; `tests/test-ai-review-lifecycle.sh` green.

### C3 — Allocator: no extra reviewer on a passed head (#1429) — depends on C2
Files: `popcre/shared-db` `scripts/lib/lanes/reviewer-roster.mjs` / `scripts/manage-migration-author-lanes.mjs`; ai-devops `bin/ai-review-preflight`, the C2 helper.
Behavior: a request for a reviewer on a head with a passing review returns that pass unless an explicit "additional reviewer" request is made.
Gate: second-reviewer request on an approved head returns the existing pass; with the flag it allocates.
Tests: `tests/test-ai-review-preflight.sh` new `no_extra_reviewer_on_passed_head`; shared-db allocator unit test named in that PR.

### C4 — Stable cache prefix (#1430)
Files: `bin/ai-review-pool:318-330`; `tools/lib/review-doors/muse.sh:210-216`.
Behavior: fixed instructions, `$DECISION` and verdict format first; run facts (SHA, digest, packet path, file list, tests result) last. Keep "quote the full SHA".
Gate: briefs for two heads share an identical prefix through the decision text.
Tests: `tests/test-pool-dispatch-doors.sh` `brief_prefix_stable_across_heads`; `tests/test-muse-opencode-contract.sh`, `tests/test-ai-muse.sh` green.

### C5 — Skip known quota exhaustion (#1431)
Files: `bin/ai-review-pool`, `bin/ai-review-preflight`, `tools/reviewer_admission.py`; reuse `provider_quota_reset_at` (`bin/ai-qwen:855`) and the GLM equivalent.
Behavior: before the captured reset time, refuse with "quota exhausted until <time EST>", no provider call; after it, dispatch. No captured reset time = current behavior.
Gate: stub diagnostic with future reset → zero calls; past reset → dispatch.
Tests: `tests/test-ai-review-preflight.sh`, `tests/test-glm-pool-dispatch.sh`, `tests/test-ai-qwen-part2.sh`, `tests/test-ai-review-credit-watch.sh` (new cases `skip_until_quota_reset`, `dispatch_after_reset`).

### C6 — StepFun (#1432)
Files: `bin/ai-stepfun:203-213,232-250,562,630`; `tools/lib/review-doors/stepfun.sh:416-429`.
Behavior: pace ahead of each call (10 RPM limit, shared TPM) instead of cold whole-turn reruns; parse StepCode usage into per-turn records; doctor uses one paid call. No new turn caps.
Gate: simulated 429 burst yields waits, not reruns; reports carry token counts; doctor shows one call.
Tests: `tests/test-ai-stepfun.sh` new `paces_before_call`, `usage_parsed_into_report`, `doctor_single_paid_call`; `tests/test-ai-stepfun-windows-shell.sh` green.

### C7 — Gemini (#1433)
Files: `bin/ai-gemini` `call()` (~570-620; drift check `:618`), `verify_model` `:568`.
Behavior: drift compares to the start snapshot and ignores other sessions' scratch/ignored dirs; a real write to a tracked file is still rejected. Model id from the main response; `verify_model` only as fallback.
Gate: foreign scratch write accepted; tracked write rejected; one provider call per review.
Tests: `tests/test-ai-gemini.sh` new `foreign_scratch_write_accepted`, `tracked_write_still_rejected`, `model_from_main_response`; `tests/test-ai-gemini-request-precheck.sh` green.

### C8 — DeepSeek append-only compaction (#1434)
Files: `tools/deepseek_repo_tools.py:485-522`.
Behavior: once written, earlier messages never change; compaction applies only past the cached prefix. No budget changes.
Gate: consecutive rounds share identical prefix bytes.
Tests: `tests/test_deepseek_repo_tools.py` `test_prefix_stable_across_rounds`; `tests/test-ai-deepseek-agent.sh` green.

### C9 — Tests stop writing the live events log (#1435)
Files: `tools/reviewer_events.py:18-22`, `tools/reviewer_event_guard.sh:77`, reviewer test harnesses.
Behavior: harnesses set `AI_REVIEW_EVENT_DIR` to a temp dir; a guard refuses the live path when a test marker is set.
Gate: live `events.jsonl` checksum unchanged after running all reviewer suites.
Tests: new `tests/test-reviewer-events-isolation.sh`.

## 10. Tests required

Named per step above. Every touched wrapper's existing suite must stay green: `tests/test-ai-gemini.sh`, `tests/test-ai-qwen.sh`, `tests/test-ai-qwen-part2.sh`, `tests/test-ai-codex-review.sh`, `tests/test-ai-kimi.sh`, `tests/test-ai-deepseek.sh`, `tests/test-ai-deepseek-agent.sh`, `tests/test_deepseek_repo_tools.py`, `tests/test-ai-stepfun.sh`, `tests/test-ai-muse.sh`, `tests/test-muse-opencode-contract.sh`, `tests/test-pool-dispatch-doors.sh`, `tests/test-glm-pool-dispatch.sh`, `tests/test-ai-review-preflight.sh`, `tests/test-ai-review-lifecycle.sh`, `tests/test-ai-review-engine.sh`. Run profile tests without `AI_TASK_GATES_BIN` stubs where the privacy gate matters.

## 11. Constraints, standing rules, and gotchas in force

- Own worktree from current `origin/main`; never edit the canonical checkout. Branch + PR; never push to `main`; merge via queue per `config/repository-policy.json`; never `--admin`.
- Reviewer-safety changes need an exact-head independent review assigned by the shared-db allocator; pin the review base to the merge-base.
- Do not weaken safety controls (source-drift, sandbox, credential isolation) to save tokens.
- Never cap budgets (§8). Grok untouched.
- Secrets only via 1Password vault `vibe_coding`; never in argv, logs or commits.
- Times shown to humans in EST/EDT. Sign GitHub posts `Posted by Claude chat <id> on <machine>`.
- Gotchas: Windows CRLF breaks bash scripts; `gh pr diff --name-only` overstates; GLM is out of credit until 2026-10-09 (affects C5 live-proof timing); StepFun shares a TPM cap.

## 12. Access and environment

`gh` authenticated as `u2giants`; Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>`. Reviewer logins live on each machine (agy, Codex ChatGPT login, Kimi Code, Qwen token-plan store, Muse/StepFun/DeepSeek protected keys from 1Password `vibe_coding`). Run suites with `bash tests/<name>.sh` from the worktree. Kimi live proof needs hetz or 916-alien.

## 13. Definition of done + risks and open questions

Done per child: code merged with green CI, named tests added, live proof recorded on the same child issue (one real run showing the intended effect: no key used / reused report / prefix cached / etc.), STATUS row updated with merge SHA, parent ticked. Whole plan done when all nine children are ticked and a 2-day events-log comparison against #1426's baseline shows the drop.

Risks: C2/C3 could reuse a stale pass — mitigated by keying on digest and mode; C1 could break a machine that silently relied on a key — the failure is loud and correct; a too-broad C7 exclusion could hide a real write — test `tracked_write_still_rejected`. Rollback: revert the child PR. Open: the §8 OPEN items.

## Self-audit (implementation-plan standard)

1. Could a brand-new session execute this without asking? Yes — goal (§1), verified file:line (§5), per-step files/behavior/gate/tests (§9), constraints (§11).
2. Does it carry all background, including what was ruled out? Yes — audit findings (§3, §6), rejected approaches (§7), locked owner decisions (§8).
3. Is the goal clear enough for a judgment call? Yes — §1 states: cut spend and billing risk without losing quality or capability, with the "goal wins" instruction.

Checklist graded: all items YES; adversarial table present for C1.
