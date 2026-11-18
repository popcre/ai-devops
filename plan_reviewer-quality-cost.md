---
summary: Install quality-preserving reviewer changes and qualify opt-in savings for Muse, DeepSeek and Hy4 on three hosts (#2619)
kind: plan
status: open
read-when: implementing or qualifying incremental reviewer cost savings without quality loss
---

# Reviewer cost and quality plan

## 1. Ultimate goal

Pay less for reviews while keeping every finding, citation, and final decision as reliable as it is today. A reviewer must have the full evidence and enough room to reason. **If a step conflicts with this goal, the goal wins — stop and flag it.** A passing comparison supports use on the tested workload. It cannot establish identical behavior on every future review.

## STATUS

Execution receipts and follow-up ownership are on [#2619](https://github.com/popcre/ai-devops/issues/2619). [Launch handoff](HANDOFF.d/2026-11-18T1549Z-edge-dev3-codex-reviewer-quality-cost.md).

| Step | State on 2026-11-18 | Evidence to attach |
| --- | --- | --- |
| 1. Freeze baseline and cases | Recorded | All three installed hosts matched the #2609 pin. The issue carries exact public fixture heads and billing attribution. |
| 2. Safe implementation | Merged | [#2621](https://github.com/popcre/ai-devops/pull/2621) rejects explicit incomplete output, preserves retry and fallback behavior, and leaves request assembly and route defaults untouched. |
| 3. Install safe changes | Held for default parity | The exact candidate source passed ordinary live review from isolated copies on all three platforms. Installing the merged release would also activate [#2580](https://github.com/popcre/ai-devops/pull/2580) on the pinned hosts. |
| 4. Muse caching pilot | Measured | OpenRouter charged $0.035351 with the explicit key off and $0.017384 with it on. Both arms produced nine usable reviews. The setting remains opt-in. |
| 5. Separate experiments | See execution receipts | DeepSeek, Hy4 and Muse direct are recorded independently on the issue. Endpoint, text, output-budget, and history comparisons are distinct from the cache pilot. |
| 6. Decide and close | Open | The fleet keeps the tested #2609 source. Keep the installation proof open until an authorized merged release preserves the observed host defaults. |

## 2. Application

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert's toolkit for code reviews and second opinions. `bin/ai-review-simple` handles one-shot reviews, `bin/ai-second-opinion` uses protected named conversations, and `tools/reviewer_routes.py` shares route and cache configuration. The DeepSeek harness is also callable directly through `ai-deepseek-agent`. The target fleet is Ubuntu edge-dev3 and hetz, and Windows edge-dev. GitHub main is source truth.

## 3. Trigger

On November 18 Albert asked for a follow-up to the completed fleet trial: implement safe changes, pilot Muse OpenRouter caching, and measure the remaining ideas separately for Muse, DeepSeek, and Hy4. The prior trial exposed billing gaps, variable review quality, and the danger of using cache-hit rate as a proxy for savings.

## 4. Scope

In scope: safe request and response handling, installed proof, opt-in Muse OpenRouter cache pilot, separate experiments for Muse direct, Muse OpenRouter, DeepSeek, and Hy4, and a recommendation per setting. Outside scope: default activation in this plan, model substitution or helper-model processing of review content, cross-job cache sharing in routine use, credential changes, new persistence or reporting systems, external compression plugins, and unrelated production changes.

## 5. Current code and evidence

- Planning baseline `d1bea4a82e2a8b2b1d9bf0c50e006ab73ff43a7b`. [#2609](https://github.com/popcre/ai-devops/pull/2609) landed at `9abcf1beed2ad165022f2847d5edbd6e2f292857`. Existing cache/environment controls live in [reviewer_routes](tools/reviewer_routes.py#L141), request assembly and usage parsing in [review-simple](bin/ai-review-simple#L257) and [second-opinion](bin/ai-second-opinion#L455). Reuse these and the existing protected named sessions.
- [#2615](https://github.com/popcre/ai-devops/pull/2615) and [the cost record](plan_deepseek-harness-openrouter.md#status) hold the previous trials. [#2551 receipts](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6967526056) prove the earlier installation at the #2609 pin. [#2580](https://github.com/popcre/ai-devops/pull/2580) separately changed reviewer routes on main, and [#2531](https://github.com/popcre/ai-devops/issues/2531) subsequently closed. Verify present installed behavior independently before assuming any historical pin is current.
- `AI_REVIEW_CACHE=1` is explicit. Scope and namespace derive protected identifiers. `AI_REVIEW_BILLING_ID` is an isolated probe identifier. Check outbound requests in tests because a billing probe can take precedence over the affinity ID in review-simple. Leave named sessions and their stored routes intact.

## 6. Key findings

The [previous cache comparison](plan_deepseek-harness-openrouter.md#L78) used six trials per setting. Muse OpenRouter cost $0.028986 → $0.020753 with 6/6 usable in each. Muse direct had incomplete estimates. DeepSeek cost $0.119102 → $0.100936 with 5/6 → 4/6 usable. That difference does not establish causation. Hy4 cost $0.219216 → $0.268168 with 0/6 usable in each at 150 seconds. Its later normal-deadline Windows reviews passed. Named-session savings were measured separately. Never combine them with cache savings.

[OpenRouter's caching guide](https://openrouter.ai/blog/tutorials/prompt-caching-sticky-routing/) describes cache charges, expiry, and session affinity. Cache counters establish reuse. Provider charges, including retries and failures, establish cost. A stable affinity ID can change endpoint selection, so log the actual endpoint and isolate affinity from provider cache controls.

## 7. Rejected approaches

Earlier lean trials lost usable reviews or left disagreement, and the file-map trial misplaced the dispatch citation. Avoid shrinking evidence, per-turn rewriting, blanket lower reasoning, tight output caps, and global routing or quantization rules. A cheaper endpoint serving the same model name may differ in precision, behavior, and reliability. Advertised uptime cannot predict independent fallback success. Keep automatic caches in both comparison arms when the provider already uses them. Do not equate a missing counter with zero, or a cheaper partial bill with savings.

## 8. Decisions

**Locked, November 18, 2026.** Albert said “i am ok with Contributor’s data-use terms. don't ask again.” Record this as acceptance for Contributor on this work. Use public fixtures for repeatable trials, retain private evidence only in its approved location, and preserve normal secret handling. Hold fleet and GitHub defaults steady. Any later activation needs its own rollout decision after passing the gates below. Use the same reviewer model for both arms, with no helper processing of review content.

**Open.** Pick the actual safe gaps after inspecting current main, whether candidate changes qualify, and any provider-specific trials that supported controls permit. Skip redundant code. Proposed pilot gates below are planning choices, not previous promises.

## 9. Execution

### Phase A — safe fleet changes

1. **Freeze inputs and ownership — lead-only, since it fixes the comparison and boundaries.** Claim #2619 using the standing signature and start from current main in a fresh Codex worktree. Use `config/reviewer-routes.json`, `.github/workflows/ai-review.yml`, `bin/ai-second-opinion`, and installed launchers to record actual per-host defaults, versions, routes, and normal deadlines without secret values. Freeze public, immutable seeded, clean, real-change and long cases with expected verdicts, defects, severity and citation anchors. Include the prior SWR fixtures where appropriate and a multi-turn case that needs late evidence and prior decisions. Score baseline blind to settings. Gate: approved source SHA, host default receipts, private case manifest with digests and scoring rules, one attributable terminal billing smoke per supported route.
2. **Implement only safe gaps — lead-only, because request and receipt handling control outcome.** After 1, inspect `build_prompt`, `run_once` and `run_harness_once` in `bin/ai-review-simple`, `_run_opencode_turn` and `run_harness_turn` in `bin/ai-second-opinion`, and usage in `tools/reviewer_routes.py`. Keep byte-stable reusable instructions when compatible with existing role and message precedence, retain exact per-head evidence, identifiers, errors, tool schemas, and history, and keep changing metadata in its existing appropriate message role outside the reusable portion. Preserve provider and model selection. Reject an explicitly truncated or malformed terminal output through the existing failure path, preserve prior valid history, and use existing bounded retry policy. Accept existing usage/reporting and schemas wherever sufficient. Do not impose output limits or reasoning changes through this step. Gate: fixtures prove full input equivalence and defaults, valid outputs still pass, and malformed outputs cannot publish or contaminate persistence. If an ordering change could affect meaning, move it to Step 5.
3. **Land and install — lead-only, because it changes live machines.** After 2, run §10 on Linux and native Windows, merge through the protected queue, use the candidate worktree and authorized installer from [deployment.md](docs/deployment.md) on each OS, and check hashes and Windows launcher receipts. If current main would introduce an independently changed fleet default, select a reviewed release that preserves the observed defaults using the documented release route, or hold that host and record the conflict. Run ordinary live reviews with all pilot settings unset and verify existing sessions still resume. Gate: all three hosts have source and behavior receipts and unchanged defaults. Cut point: use the fresh-session skill and reread Phases B and C against the new receipts.

### Phase B — opt-in caching

4. **Pilot Muse on OpenRouter — lead-only, because it spends money and judges live proof.** After 3, use the existing cache key in `tools/reviewer_routes.py` and dedicated scoped processes on edge-dev3, edge-dev, and hetz. No host-wide settings. Compare the explicit Muse cache key off/on while keeping endpoint affinity constant where supported. Isolate control and candidate so one arm cannot warm the other. A short cold/warm identical-input smoke proves wiring, then changing exact-head reviews provide the decision evidence. Compare stateless reviews separately from multi-turn calls. Record outbound fields minus identifiers, cache reads and writes, provider, billed attempts, latency, verdict and scores. Keep a private mapping for generation records using the existing billing mechanism. Gate: §13 paired rules and at least one live paid matched pair per host. If exact billing or wire attribution fails, report inconclusive and leave the pilot off after the run.

### Phase C — independent comparisons and decision

5. **Run one change at a time — lead-only, because it changes model behavior and judges quality.** After 3, preregister the order and bounded spend. Step 4 can run independently using distinct namespaces, without concurrent shared-host test interference. Use `config/reviewer-routes.json` for route selection and temporary overrides at existing request assembly sites only. For caching, compare stable affinity to the existing behavior for DeepSeek and Hy4, and a supported explicit cache control for direct Muse only if direct billing is complete. Separately compare prompt-only concision, validated output limits, per-step reasoning on narrowly specified tasks, complete tool results stored for verified on-demand reads, and batched same-model compaction using long cases. Compare cheaper compatible endpoints only where the live official catalog shows viable alternatives with compatible parameters and acceptable data terms. Hold input, effort, tools, time limit and provider fixed except for the factor being tested. Exercise a seeded defect buried in tool output and a late correction after compaction. Validate structured output, tool selection and resumed reasoning with the route's documented interface. Keep fallback tests separate, with the same model and explicit endpoint attribution. An unsupported control, one eligible endpoint or incomplete billing gets a dated no-adoption decision. Gate: each applicable setting has its own §13 judgment for each route. Cut point: use fresh-session and reread Step 6, §13 and the scope before closing.
6. **Decide, revert probe settings, and close — lead-only, because it owns live acceptance.** Update the STATUS and #2619 with per-setting evidence, the next justified action, and the installed source/default checks for all three hosts. Remove only transient pilot configuration. Restore any accidental behavior change through the documented rollback and prove one ordinary review plus restart per host. Gate: source landed, host proofs and benchmark results linked, explicit handoff for any real blocker, and close only after the issue's live proof is satisfied.

## 10. Tests and adversarial cases

Add the named cases to `tests/test_reviewer_routes.py` or `tests/test-reviewer-routes.sh` alongside the owning behavior. From the worktree run `python3 -m unittest discover -s tests -p test_reviewer_routes.py`, `bash tests/test-reviewer-routes.sh`, `bash tests/test-ai-deepseek-agent.sh` and `bash tests/test-ai-deepseek.sh` plus matching launcher and session tests. Run Python assertions through the native installed interpreter and shell tests through Git Bash on Windows. Check host runner collision with `bin/ai-test-local --check-collision` before running full suites.

| External input | Hostile or missing case | Test |
| --- | --- | --- |
| Repository diff, docs and tool evidence | Late seeded defect, Unicode identifier, conflicting tool text and line citation | `test_review_evidence_retained_exact_head` |
| Model response | Truncated valid-looking verdict, malformed structured output, duplicate terminal message | `test_incomplete_review_never_publishes_or_appends` |
| Provider billing usage | Missing or malformed cost, duplicate generation, retry, unknown cache counters | `test_billing_reconciliation_preserves_unknown_and_retries` |
| Optional identifiers and settings | Unshared threads, hostile namespace, experimental setting absent, no secret or raw ID in receipt | `test_pilot_scoped_settings_and_default_parity` |
| Endpoint catalog / fallback | Missing capabilities, invalid limits, no eligible alternative, same-model fallback changes endpoint | `test_endpoint_candidates_fail_closed_without_default_change` if parser changes, otherwise record those fixture assertions in the trial |
| Session and stored tool file | Replaced/missing output or forgotten correction after restart | `test_full_evidence_recoverable_after_restart` |

Reuse existing assertions that already cover these cases. Add cases only in the steps that change the owning code. All cases must have executable evidence before the corresponding setting is accepted.

## 11. Constraints

Read AGENTS.md, docs/INDEX.md and the matching task-router rows. Use task gates before stronger actions, hosted CI and native installer paths, the GitHub wrapper and bounded waiter. Never pull in the installed checkout, change protected main directly, expose secrets, use private transcripts, or retry an unbounded run. No database or UI work. Respect endpoint capabilities per route. Do not apply the proposal’s blanket history or output rules across distinct API interfaces. Price decisions use actual successful and failed attempts, not catalog estimates alone.

## 12. Access and environment

Use governed GitHub CLI as u2giants and confirm access to edge-dev3 and the existing edge-dev and hetz SSH aliases. Confirm current host class and protected installer paths via docs/deployment.md and templates/system/machine-atlas.md. Use machine credential lookup already defined by `config/reviewer-routes.json` and `tools/reviewer_routes.py`. If billing credentials are needed use 1Password vault `vibe_coding` and its existing OpenRouter readonly analytics credential used for #2551 through protected process injection. Discover the current item by metadata without printing values. No new logins or private source fixtures are required. Verify protected access read-only before paid runs.

## 13. Definition of done, risk, and decision rules

- Freeze a bounded budget and test sizes before the first paid call. For an adoption recommendation use at least 24 scored matched pairs per eligible treatment, six each seeded, clean, real changes, and long/multi-turn. Balance or randomize order, spread across at least two runs, and record fleet smoke separately. Stop for a critical miss, unexpected route, contamination, or budget exhaustion. Report short runs as incomplete.
- Require full attributable billing for both arms including retries and failures. Compare total dollars per usable review, reported by route, with matched run order, elapsed time, and quality. Pair on the case and resample whole paired cases, or paired sequences where they share one cache or session. Recalculate spend per usable review on each resample. Require at least 10% observed savings and a paired 95% interval excluding zero savings for adoption. A zero usable count or unstable denominator makes the result inconclusive. Require no lost seeded defects, no added false findings, no worse verdict or exact-head citation, no lower usable rate, and no worse tool or restart checks in the scored sample. More evidence is needed where results are variable. Never call samples proof of universal zero loss.
- Finish safe code tests, merge, verify current main and native installed SHA on all three hosts, prove ordinary behavior and record pilot results. Keep defaults unchanged and attach the verified rollback route and signed evidence to #2619. Update this plan as work progresses and retire the handoff once the issue is complete. If live proof remains pending, leave the same issue open with its unchecked proof item.

## Self-audit

1. **Can a fresh session execute this?** Yes. §§5 and 9–13 name source owners, dependencies, commands and gates. The status rows and handoff identify the start and cut points.
2. **Does it carry the findings and dead ends?** Yes. §§3–8 capture the billing gaps, deadline distinction, prior decisions and limits. §10 maps external failure cases to tests. The optional fresh-reader pilot is closed and was skipped.
3. **Can the lead steer when a step fails?** Yes. §§1, 8 and 13 put intact evidence and quality ahead of savings, and specify how to record an inconclusive result and roll back without changing defaults.

```text
Continue popcre/ai-devops #2619 from current main in a fresh codex/ worktree.
Read plan_reviewer-quality-cost.md STATUS, its handoff, and AGENTS.md first.
Follow Steps 1–6 yourself. All six are lead-only because they determine evidence,
runtime or paid decisions. There are no helper-ok steps to dispatch here.
Your helper is your own tool's smaller model — Haiku (high effort) for
Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for
Mimo Pro. Never a full-strength model.
https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md
If a later scoped mechanical step is marked helper-ok, the helper returns
finished work or an evidenced blocker, makes no design decisions, merges or
posts, raises its stop-and-ask trigger to the lead, and is taken back after
30 minutes stuck. Never give a helper review content for model offloading.
Re-read downstream phases at each cut. Run §10 and verify §13 yourself on all
three hosts. Measure Muse, DeepSeek and Hy4 separately and preserve defaults.
```
