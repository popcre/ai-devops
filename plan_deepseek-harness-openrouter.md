---
summary: Implement and qualify DeepSeek, Muse, and Hy4 routes for GitHub reviews and resumable second opinions
kind: plan
status: open
read-when: changing DeepSeek, Muse, or Hy4 review routes, credential fallback, or reviewer cutover
---

# DeepSeek, Muse and Hy4 reviewer implementation

Keep GitHub reviews and second opinions available even when Meta direct loses access. Give both entry points the same reviewer choices, preserve ongoing discussions, and make every review read-only. Confirm that GitHub publishes each reviewer’s verdict before a route becomes active. If a step conflicts with this goal, the goal wins — stop and flag it.

Tracking: [parent #2531](https://github.com/popcre/ai-devops/issues/2531), [DeepSeek #2549](https://github.com/popcre/ai-devops/issues/2549), [OpenCode #2550](https://github.com/popcre/ai-devops/issues/2550), [caching #2551](https://github.com/popcre/ai-devops/issues/2551). Start with the [current handoff](HANDOFF.d/2026-11-16T2207Z-edge-dev3-codex-reviewer-rollout-closeout.md). The [previous handoff](HANDOFF.d/2026-11-16T2118Z-edge-dev3-codex-reviewer-route-build.md) records the earlier implementation planning.

The [November 17 fleet handoff](https://github.com/popcre/ai-devops/blob/e901513e11217b9189e3c101f132bb4d691efe9f/HANDOFF.d/2026-11-17T2355Z-edge-dev3-codex-cache-fleet-continuation.md)
preserves the original instructions and installation lessons for edge-dev3,
edge-dev and hetz. Its successor completed the three-host installation and
verification at the pinned release with defaults unchanged
([#2551 acceptance](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6967526056)).
The remaining quality and cost confirmations moved to
[#2619](https://github.com/popcre/ai-devops/issues/2619) and are recorded in the
[closed follow-up plan](plan_reviewer-quality-cost.md).

## STATUS — start here

Use current upstream. Planning baseline: `ec4886f57232a1bb2741b7cf66d5fa1a949a1def`. Steps 1–4 track on #2549 and #2550, Phase C on #2551. GitHub activation and rollback rehearsal landed under #2531 as recorded in step 5. Albert explicitly lifted the hold again on November 18, 2026 and requested completion of the default rollout for GitHub and second opinions. The follow-through makes new ordinary DeepSeek conversations use OpenRouter in both entry points, retains each existing conversation's engine, and preserves automatic Muse failover on implicit continuation. Per-user `legacy` settings remain the reversible second-opinion rollback. Final installed and live evidence belongs on #2531.

| Step | Status, 2026-11-16 | Evidence or next gate |
|---|---|---|
| 1. Shared route definitions and protected runtime profiles | Landed #2560 | Registry `config/reviewer-routes.json` + `tools/reviewer_routes.py`; `test_route_registry_and_secret_scope` in tests/test_reviewer_routes.py. | [Isolated Ubuntu and Windows benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) informs pins and controls. |
| 2. Wire GitHub review and fallback | Landed #2560; live receipts 2026-11-17 | `--route`/`--run-plan`/`--candidate-plan`; workflow consumes the plan only through the opt-in input. Phase B receipts still open. | [DeepSeek and Muse native verdicts on a disposable TypeScript PR](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224). Candidate product wiring and final route proofs remain open. |
| 3. Wire resumable second opinions | Landed #2560 (+ #2569, #2570 fixes); live receipts 2026-11-17 | `--route` on ai-second-opinion (per-session lock, sticky selection, atomic Muse failover), harness engine in ai-deepseek-agent, ai-hy4 entry point. | [Read-only native session restart evidence](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521). Cross-route Muse continuation remains open. |
| 4. Qualify the exact integrated candidate | Route receipts landed 2026-11-17 (candidate 883e552); activation hold intact | Run the route, platform and failure matrix in §10. |
| 5. Enable, verify and retain rollback | Landed `c58eb1e0` (2026-11-17, owner go; PR [#2580](https://github.com/popcre/ai-devops/pull/2580)) | One revertible default change: rotation expands into the candidate plan, new Muse second opinions default to the candidate route. Rollback rehearsed ([#2588](https://github.com/popcre/ai-devops/pull/2588)); live proofs on [#2612](https://github.com/popcre/ai-devops/pull/2612) and #2531. Repairs #2579 (Windows env) and #2584 (stray brace) landed first. The #2551 fleet installation used the earlier pinned release and retained its defaults. |
| 6. Qualify caching separately | Started: wiring + first measurements (#2571, off by default) | [Muse baseline](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964). Phase C can start after step 4. |
| 6a. Correct cache measurement reporting | Complete 2026-11-17; merged and installed on Ubuntu/Windows | [Acceptance receipt](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6962732060): landed source `7dffdd4845729eac1a29463a60093b94cf134832`, 94 focused checks per OS, matching installed tool hashes and missing/zero/partial smoke results. Reproduce the counter boundary with `python3 tests/test_reviewer_routes.py CacheReceiptTests`. |
| 6b. Reduce total token spend | Fleet code landed in [#2609](https://github.com/popcre/ai-devops/pull/2609), trials were evaluated, and all three installed targets passed. | See the [exact installed proof](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6967526056). Experiments remain opt-in. |

### Fleet measurement evidence

The code release is `9abcf1beed2ad165022f2847d5edbd6e2f292857`. It sends
the intended cache keys on both Muse connections and optional stable affinity
for Muse, DeepSeek, and Hy4 on OpenRouter. Both normal review entry points and
the standalone DeepSeek Harness path support scoped usage receipts. A live Muse
OpenRouter review generated four billed requests while OpenCode exposed three
completed steps. Reported step totals cannot substitute for provider billing.

The lean-prefix trial used two reverse-order passes on public SWR changes
[#4318](https://github.com/vercel/swr/pull/4318),
[#4336](https://github.com/vercel/swr/pull/4336),
[#4310](https://github.com/vercel/swr/pull/4310),
[#4312](https://github.com/vercel/swr/pull/4312), and
[#4293](https://github.com/vercel/swr/pull/4293), with clean and seeded controls.
Each pair received the same model, effort and deadline (85 seconds for
OpenRouter, 100 for metered Meta). The deadline was a trial constraint and
does not change the runtime defaults. Completed steps, timeouts and failed
attempts are included when billing is available. A usable run has a verdict.
The seeded and clean controls separately check finding coverage and false
positives. Rounded dollars summarize the sample, not ordinary fleet spend.

| Route | Usable, current → lean | Job billing coverage | Observed spend, current → lean | Decision |
|---|---:|---:|---:|---|
| Muse direct | 14/14 → 9/14 | Estimated 14/14 → 8/14 | $0.050637 → $0.017351 subtotal | Leave lean disabled. Five fewer usable results and incomplete cost coverage. |
| Muse OpenRouter | 9/14 → 9/14 | Provider 14/14 → 14/14 | $0.094945 → $0.074130 | Lower measured spend, with mean elapsed time rising from 52.9 to 58.4 seconds and disagreements on public cases. Keep the probe opt-in. |
| DeepSeek | 8/14 → 7/14 | Provider 13/14 → 14/14 | $0.207583 subtotal → $0.330455 | No adoption. One fewer usable review and no defensible complete-job saving. |
| Hy4 | 4/14 → 2/14 | Provider 14/14 → 14/14 | $0.424857 → $0.412466 | No adoption. Cost per usable review rose from about $0.106 to $0.206 under the shared test deadline. |

The direct Meta estimates use [published Contributor rates](https://dev.meta.ai/docs/pricing-rate-limits)
and request-level usage on public fixtures. The temporary measurement relay
did not retain request/answer text or change provider settings. Missing terminal
usage remains unknown. The direct Meta file-map trial reported all three seeded
defects on manual inspection, but cited line 20 for the dispatch defect on
line 14 in one pass. Without a trusted full-patch read receipt, that mode is
refused by the shipped reviewer. Direct Meta's concise trial reported all
three seeded defects, with one of six jobs in each arm missing complete cost.
The Muse OpenRouter three-case concise cost rose from $0.006372 to $0.008076.
Concision stays a qualification probe. A default change needs complete,
repeatable cost and quality results.

The separate cache comparison used three public SWR changes (4318, 4310 and
4312), then reversed them in a second pass, for six reviews per arm per
route. Muse held OpenRouter affinity fixed within each arm while varying
the explicit cache key. DeepSeek and Hy4 compared a per-job affinity ID with
one stable ID per sequence, leaving their automatic provider caching intact.
The 150-second limit was the same within pairs.

| Route | Usable, control → cache trial | Observed spend, control → cache trial | Result |
|---|---:|---:|---|
| Muse direct | 6/6 → 5/6 | $0.016273 estimate → $0.011616 estimated subtotal | Two cache-arm jobs lack complete terminal billing. No full comparison. |
| Muse OpenRouter | 6/6 → 6/6 | $0.028986 → $0.020753 | OpenRouter billed 243,940 versus 477,879 cache reads. Keep available for explicit testing. |
| DeepSeek | 5/6 → 4/6 | $0.119102 → $0.100936 | The trial cost more per usable review. No broader enablement. |
| Hy4 | 0/6 → 0/6 | $0.219216 → $0.268168 | Cache reads increased from 483,968 to 539,264, but both arms exhausted the trial deadline. No full-review saving. |

In the separate three-case concise probes, Hy4 returned two usable reviews
in each arm and billed $0.068990 versus $0.062243. DeepSeek returned two
versus three, but one control lacked an authoritative record, so its
$0.020922 covered spend versus $0.018596 cannot establish whole-arm savings.
The exact-head quality and complete-cost rules take precedence over token
or duration differences.

The named versus fresh-session comparison used three turns per arm, fresh
processes, and a 15-minute idle interval before final recall. All four named
routes recalled both the marker and decision. OpenRouter billed named versus
fresh at $0.001170 versus $0.003392 for Muse, $0.012159 versus $0.025986 for
Hy4, and $0.000489 versus $0.000433 for DeepSeek. The covered Meta estimates
were $0.000680 for named and $0.002007 for fresh, with terminal usage missing
for one of four named requests and two of 11 fresh requests. These are small
continuity probes. Persistence is retained for recall and can increase spend,
as it did for DeepSeek in this sample. No new compaction was justified or
enabled.
The forced live Muse transition preserved one visible copy of each question
and kept recall on the fallback and next resumed turn.

A separate Muse OpenRouter synthetic warm-repeat probe read 22,499 cached
tokens at roughly 22,540 input tokens and 100,323 cached at roughly 100,440
input tokens. The marker survived each answer. This does not establish an
account-wide cold cache or a real-review savings rate. Responses and Chat
were tested independently without extending retention or enabling stored
history. A read-only audit of 100 recent advisory review runs found no reruns
and one possible repeated head/branch group. There is no basis for adding a
separate cross-job result cache.

In the request-level interface smoke, both Muse OpenRouter and DeepSeek
returned the expected verdict twice on each interface. The two Muse Chat
requests cost $0.000191 combined and the two Responses requests $0.000215.
For DeepSeek the totals were $0.000567 and $0.000565. Hy4 returned usage on
both interfaces but the smoke output limit was exhausted before a verdict
on all four calls. No interface change was adopted.

The native installers completed at `9abcf1beed2ad165022f2847d5edbd6e2f292857`
on edge-dev3, edge-dev and hetz. Each host approved both arms for all four
routes, recalled after two fresh-process restarts, and passed an ordinary
review with the experiment settings unset. On Windows, Hy4 needed a rerun
under its normal deadline after both shorter test runs timed out. The
standalone DeepSeek entry point passed live on all three hosts. Provider
analytics matched 28 installed OpenRouter billing groups and 181 requests.
The [signed receipts](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6967526056)
include the recovery and deployment scope. The separately merged
[#2580](https://github.com/popcre/ai-devops/pull/2580) default change is absent
from these installed pins.

Further quality-preserving savings and independent fleet pilots are tracked in
[the reviewer cost and quality plan](plan_reviewer-quality-cost.md) under #2619.

**Token-efficiency amendment, 2026-11-17.** This amendment fixes reporting and
specifies future experiments; it does not implement prompt trimming, compaction,
retention, deduplication, model changes or activation. Fresh sessions read
6a's completed acceptance receipt, then start the still-open Phase C measurements
and 6b when those experiments are in scope. The
historical route STATUS above is not a substitute for current acceptance:
[integrated re-check](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6955989936)
records restart/idle and failover proof; the [parent](https://github.com/popcre/ai-devops/issues/2531)
retains the unchanged-default hold and live-proof checklist. The existing
#2551 implementation owner owns the future experiments; this amendment creates
no new issue, service or parallel plan.

## 1. Goal

Share execution and safety controls while preserving the two ways people request a review. A successful one-off model response counts only as connection proof.

## 2. Application

[popcre/ai-devops](https://github.com/popcre/ai-devops) supplies reviewer tooling. Automatic review runs in GitHub Actions via the installed toolkit and checked-out PR head. On-demand review runs through the installed second-opinion wrapper on Ubuntu and Windows. Use protected `main` as upstream and isolated task worktrees.

## 3. Trigger

Albert selected one DeepSeek Harness route and three OpenCode routes for automatic GitHub review and on-demand second opinions. Intermittent loss of Meta direct access makes a separate Muse connection valuable. Simulate Meta authentication denial in a disposable fixture, then prove Muse can continue through OpenRouter using the same model. The exact vendor reason behind prior denials is outside this investigation.

## 4. Scope

Include shared route and credential selection, both callers, read-only isolation, GitHub publishing, persistent second opinions, fallback, platform qualification and rollback. Hy4 is available for second opinions and used as a GitHub fallback. Exclude changes to advisory merge policy, GLM and StepFun behavior, writable DeepSeek delegation and existing writable Muse commands, migration of stored conversations, provider policy bypasses, and a default switch during this planning or qualification work.

Albert's November 17 amendment authorizes the cache-reporting repair and this
plan update, with **defaults unchanged**. Steps 6 and 6b describe later scoped
qualification, not authorization to run or release all token-saving experiments
as part of this repair.

## 5. Current code

At the planning baseline, [`bin/ai-review-simple`](bin/ai-review-simple) lines 35–61 declares single-route Muse and DeepSeek provider specs. `read_key`, `make_workspace`, `run_once`, `review`, `rotation` and `combine` own credential lookup, OpenCode, one advisory verdict and the existing result shape. [`.github/workflows/ai-review.yml`](.github/workflows/ai-review.yml) lines 91–139 invokes the rotation and posts an exact-head check and comment. The normal workflow uses the trusted toolkit ref for execution.

[`bin/ai-second-opinion`](bin/ai-second-opinion) imports the provider specs from the review driver. Its `start`, `write_config`, `run_opencode`, `load_meta`, `save_meta` and `parse` own workspace copy, session continuation and provider selection. [`bin/ai-muse`](bin/ai-muse) wraps it and must keep existing command forms. The Windows launchers follow the existing `.cmd` pattern.

[`bin/ai-deepseek-agent`](bin/ai-deepseek-agent) lines 74–76 pins the direct endpoint. `send`, `reply`, `doctor` and `finalize` preserve scope, continuation and recovery. [`tools/deepseek_repo_tools.py`](tools/deepseek_repo_tools.py) owns legacy read access. [`bin/ai-deepseek`](bin/ai-deepseek) is writable delegation and remains outside this work.

The routing decision landed in #2545. Native benchmark launches and GitHub proof lived in disposable environments. No integrated reviewer code from those tests is deployed.

**Current efficiency code at amendment baseline `7539097a` (historical planning
baseline above retained):** `tools/reviewer_routes.py:cache_enabled`,
`cache_fields` and `opencode_provider_block` implement the off-by-default Muse
cache identifiers. `bin/ai-review-simple:build_prompt` uses the fixed-prefix
template, and `cache_receipts` reads OpenCode step-finish usage. Before 6a,
that parser converted absent counters on a completed step to zero. It now
accepts only reported nonnegative integers independently for reads and writes;
an entirely unreported counter remains `null`. Mixed measured/unmeasured steps
yield **observed subtotals**, not complete-run usage or billing. The existing
receipt shape stays unchanged. `tests/test_reviewer_routes.py:CacheReceiptTests`
covers this boundary; `CacheQualificationTests` covers default-off behavior.

The requested whole-plan Muse review approved this amendment and identified
two pre-existing coverage defects also repaired here: `run_harness_once` now
returns the same four-field result on missing-runtime/timeout failures as on
other outcomes, so callers report unavailability instead of crashing; and
`test_non_muse_route_gets_no_cache_fields` now inspects the actual harness
profile rather than an always-empty dictionary. Harness cache usage is still
unavailable through this receipt path, never inferred as zero. New
`FailureTests.test_missing_harness_is_unavailable_with_unknown_cache` and
`test_harness_timeout_returns_unavailable_instead_of_crashing` cover the
failure contract. None changes the selected runtime or fallback policy.

`bin/ai-second-opinion:_run_opencode_turn` resumes the stored runtime session;
`sanitized_replay` supplies visible turns on Muse failover. Session persistence
proves continuity, not reduced billed input. There is no wrapper-owned
token-aware compaction, complete-conversation cost ledger or lean-context
experiment implemented by this amendment. Existing diff/stat size limits are
transport safeguards, not measured token optimization.

## 6. Findings

- [Ubuntu and edge-dev results](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) prove read-only native launches, two fresh-process resumes, and speed and quality comparisons. DeepSeek Harness was faster with a common upstream, with extra false findings. Hy4 caught all 27 seeded defect instances across five runs with zero false findings. Its median on the eight-defect patch was 88.9 seconds, and it has yet to be scored on real TypeScript PRs.
- [Regular-workflow test](https://github.com/popcre/ai-devops/actions/runs/43948851731) ran native DeepSeek and native Muse live against a disposable TypeScript PR and [published both verdicts](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224). The tested Muse runtime there was Muse Code, so that run does not qualify either selected OpenCode Muse route.
- [OpenCode connection smoke test](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927103076) passed for a custom OpenAI-compatible OpenRouter connection across all three tested models. The built-in OpenRouter connection failed for Muse and DeepSeek at the tested OpenCode version.
- [Muse cache benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964) measured roughly 9% model-request cost reduction and no overall speedup with a stable prefix and cache key across changing TypeScript PRs. Use these results as Phase C baseline. Keep caching outside initial route activation so cache behavior cannot confound delivery proof.
- The same benchmark scales to roughly $0.06 saved per 1,000 sampled reviews, not a forecast of whole-workflow spend. Output length varied and some verdicts were invalid; measure cost per usable completed review, including retries, before claiming business savings. A high cache-hit percentage is not a total-cost saving percentage.
- The [harness comparison](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) observed roughly 24,000 first-request input tokens for native Muse versus 9,000 in OpenCode. Effort and harness overhead were not controlled, so this is a reason to investigate lean inputs, not evidence of a 62.5% saving for the selected implementation. The [later re-check](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6955989936) proves continuity after restart/idle and cache reads across heads; it does not supply paired growing-thread billing or long-retention acceptance.
- [DeepSeek Harness headless execution and resume](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/cli-help.md) and [custom provider setup](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md) cover the native candidate. The reviewer credential's tests observed OpenRouter routing guardrails. Preserve them.

## 7. Approaches ruled out

Replacing the whole GitHub workflow would discard known advisory behavior and publication. A DeepSeek URL override would hit the legacy endpoint pin and retain a separate execution engine. OpenCode’s built-in OpenRouter connection failed the earlier live smoke and is excluded from the initial candidate. Muse Code added latency without a demonstrated comparison advantage and is outside the selected routing plan. Silent model substitution would confuse the person asking for a second opinion. Bulk conversion of legacy sessions adds risk without a requirement. Existing sessions retain their original runtime.

For token efficiency, do not reuse mutable snapshots, serve a verdict from an
earlier head, impose arbitrary turn budgets, or cut off a review's access to
required evidence. Do not send review verdicts, private transcripts or code
through a compression service. Do not enable longer retention or server-stored
history merely to obtain a cache hit. These shortcuts conflict with existing
evidence, privacy or continuity requirements. Reuse the shared adapters and
existing #2551 receipts instead of adding another cache/reporting service.

## 8. Decisions

Locked 2026-11-16. Every row is available from both interfaces. The same review contract applies throughout.

| Route ID | Runtime | Model and endpoint | GitHub selection | Second opinion |
|---|---|---|---|---|
| `deepseek-openrouter` | DeepSeek Harness | `deepseek/deepseek-v4.1-flash-1017` at OpenRouter | Existing DeepSeek rotation slot | Explicit DeepSeek selection, native session resume |
| `muse-meta` | OpenCode | `muse-spark-1.3-contributor` at Meta | First route within the existing Muse slot | Default route inside Muse for new candidate sessions |
| `muse-openrouter` | Same OpenCode | `meta/muse-spark-1.3-contributor` at OpenRouter | Muse credential or availability fallback, directly selectable in qualification | Explicit selection or automatic Muse continuation fallback |
| `hy4-openrouter` | Same OpenCode | `tencent/hy4` at OpenRouter | Final eligible fallback after the existing primary rotation, directly selectable in qualification | Explicit, occasional use |

Use the model identifiers above as the tested candidate pins. Recheck availability before issuing live calls, and record and requalify any proposed replacements. Keep the existing rotation order and one advisory result. Transport or provider unavailability can advance the chain while an accepted verdict ends it. Muse direct and OpenRouter have separate credentials. In automatic Muse mode, a confirmed invalid, revoked, unavailable or exhausted credential, network failure, rate limit above the retry budget or provider outage can use the alternate connection. An ambiguous 403, content or policy refusal, source-identity failure or read-only failure is terminal for that review. Explicit route selection is sticky for reproducible tests and deliberate direct or OpenRouter use. It returns the selected route’s actual failure.

Keep DeepSeek and Hy4 distinct. Hy4 never silently answers a named DeepSeek or Muse second opinion. An OpenRouter account-wide outage can affect both. Continue to available independent providers while skipping duplicate attempts only for confirmed shared outages. Keep benchmark provider restrictions in force. Open for implementation: exact package and checksums, protected per-environment credential bindings, and the smallest supported isolation implementation that passes the Ubuntu and Windows tests.

## 9. Execution

**Execution roles:** steps 1–3 and 6a are `lead-only` because they cross
credential, session, source-identity or untrusted-usage boundaries. Steps 4–6
and 6b are `lead-only` because they select comparison policy or judge live
evidence, billing, privacy and activation. No helper implementation is needed
for the reporting repair. If a later lead extracts a mechanical `helper-ok`
substep, first name its exact files, edits and test, and require it to stop and
return evidence on any scope, privacy, missing-metric or correctness question;
the lead retains all design, merge and release decisions.

### Phase A — Candidate routing and integration

1. **Share the route definitions and runtime selection.** Start from current `origin/main` in a dedicated worktree with the reviewer-safety task class. Extract the route definitions and safe outcome mapping from `bin/ai-review-simple` to one module under `tools/` and route data under `config/`, consumed by both current callers. Keep logical reviewer IDs separate from the route IDs in §8. Use one OpenCode installation and one trusted profile builder for all three OpenCode routes. Build fresh private configuration per invocation, with scope limited to the selected route and credential. For DeepSeek, pin the official headless runner and Node using existing lifecycle release conventions. Begin with the tested DeepSeek Harness 0.2.2-rc.1 and OpenCode 1.18.12 and verify platform support before promoting a version. Gate: `test_route_registry_and_secret_scope` enumerates four routes, rejects unknown overrides, and proves every subprocess receives only its own approved credentials and no ambient settings.
2. **Connect GitHub.** Depends on step 1. Update `bin/ai-review-simple` at `review`, `make_workspace`, `run_once`, `rotation` and `combine`. Add a test-scoped explicit candidate choice, route-aware credential lookup and deadline, and a native DeepSeek dispatch through the shared adapter. Return the existing verdict fields with additive validated route and engine metadata. Keep `review` tied to the requested and checked-out head. In `.github/workflows/ai-review.yml`, consume the trusted toolkit’s plan of attempts, including the two ordered Muse routes and final Hy4 fallback, with a bounded attempt set and a single publication. Count only a successful final assistant event. Use final text and process status rather than tool events or stderr. Keep the check advisory. Gate: `tests/test-ai-review-simple.sh` and the routing/fallback tests below demonstrate one exact-head verdict, correct skip/continue/stop behavior, and existing default behavior when candidate selection is off.
3. **Connect second opinions.** Depends on step 1. Step 2 can proceed independently. In `bin/ai-second-opinion` add the candidate route choice to `parse`, validate it for read-only `new/ask/review`, and reuse the shared config and outcome logic in `start`, `write_config` and `run_opencode`. Keep `bin/ai-muse` and its Windows launcher as compatibility entry points. Expose Hy4 via the shared provider entry point and register its discovery on both platforms under the existing launcher/install rules. In `bin/ai-deepseek-agent`, add a read-only candidate engine for `send`, `reply`, and `doctor --live`; preserve the existing recovery, report and session commands and legacy on-disk metadata. Use per-session locking, exact source identity and separately writable state. Preserve the actual route and runtime session ID on success. For automatic Muse fallback, first qualify native resume across the two OpenCode providers. If the stored session is route-bound, start a new scoped runtime session from the sanitized visible turns plus the single pending question. Keep private reasoning traces and tool records out of replay. Persist the new binding atomically after a valid answer, preserve the last-good state on failure, and maintain one visible history entry per turn. Gate: `test_second_opinion_route_resume` and `test_muse_failover_is_atomic` prove successful and failed continuation, concurrent rejection, legacy session compatibility and current defaults still intact.

### Phase B — Qualification and release

4. **Qualify both turnkey entry points.** Depends on steps 2–3. Start a fresh session if needed. Re-read §§9–13 and compare with current upstream. Run §10 on the exact candidate revision. Use a trusted disposable workflow ref and TypeScript test PRs. Require GitHub to run inference itself and publish valid verdicts attributed to all four route IDs. Force Meta credential failure using a scoped controlled failure or a mock provider followed by live OpenRouter, and force the Hy4 final fallback without consuming real provider quotas unnecessarily. Use an isolated route test to exercise Meta direct unavailability during a named second opinion. Windows first proof is on edge-dev, with Ubuntu as the CI and local proof target. Compare candidate and current defaults using the same TypeScript scenarios. Gate: attach check and comment links, exact tested revision, fixture SHA, provider receipts, read-only write denial and restart counts on #2531. Any failed mandatory scenario blocks default changes.
5. **Enable when the rollout is in scope.** Depends on step 4. Re-read §13 and confirm the user's no-switch hold has been lifted. Land candidate work behind opt-in selection and use a separate reversible default change for activation. Use the protected merge queue and OS-specific installers. Verify intended landed SHA, advisory publication and on-demand resume for actual enabled routes. If activation breaks any required route, restore the corresponding prior defaults through the same delivery route and verify the old path; leave successful candidate session state accessible. Gate: complete #2531 only with exact live receipts and verified rollback rehearsal.

### Phase C — Caching as a separate opt-in change

6. **Qualify cache behavior after the route candidate passes step 4.** Step 5 is independent. Start from the tested route revision. Keep the caching experiment off by default and its eventual rollout separately revertible. Apply OpenRouter’s Muse guidance as follows.

   - **Send two stable identifiers for different purposes.** In the shared route adapter from step 1, send Meta’s `prompt_cache_key` on every Muse model request, both direct and through OpenRouter. Send OpenRouter’s `session_id` in the request body or `x-session-id` in the header. Keep it stable through tool calls and restarts inside a single GitHub review or named second opinion. Use opaque IDs within the documented 256-character limit. Store only the data needed to reconstruct the same IDs in scoped session state. For shared review instructions across PRs, test a versioned cache key scoped to the authorized repo and route, independently from each review’s session ID. Derive neither identifier from raw credentials, a timestamp per request, or a private path. Start a new cache scope for a changed prefix or access scope. Do not assume Meta direct and OpenRouter share a warmed cache.
   - **Keep reusable input first.** In `templates/review-prompt-simple.md` and `bin/ai-review-simple:build_prompt`, put fixed review instructions and tool definitions ahead of variable PR IDs, SHAs, timestamps and diffs. For `bin/ai-second-opinion:write_config` and `run_opencode`, keep tool order, serialization, model and reasoning effort stable within a session. Append new turns. If state needs compaction, keep existing safety limits and test the hit loss at compaction boundaries. Preserve supported same-route history faithfully. The sanitized visible-history rule for cross-route fallback still applies. Keep the same read-only and exact-head checks.
   - **Preserve OpenRouter affinity and approved provider scope.** Explicit session IDs allow affinity from the first successful request. Do not introduce `provider.order`, alternate model arrays, routing aliases, or prompt-rewriting transforms in the Muse cache test. Where allowed providers must be constrained, use the existing guardrails and an approved `provider.only` list. Keep the existing availability fallback at the application level. Check for an intermediary that injects cache directives and account for any effects in the measured comparison. [OpenRouter caching guide](https://openrouter.ai/blog/tutorials/prompt-caching-sticky-routing/)
   - **Compare interfaces and measure long-session behavior.** First verify the actual outgoing request carries both values where required, including automatic tool-loop requests. Compare the already tested Chat Completions route with the Responses API. Test `prompt_cache_retention: "24h"` only on Responses and only under an approved retention policy. Retention is a hint. Preserve storage settings and avoid server-stored history as an experiment dependency. Treat OpenRouter’s guidance about Muse misses near 100,000 tokens as a hypothesis for a bounded public/synthetic long-context probe. Keep reasoning effort fixed in each comparison. Check first replies, later turns, restart and an idle interval before attributing any gain to retention or affinity. [Meta caching guidance](https://dev.meta.ai/docs/prompt-caching)
   - **Measure billing and correctness together.** Start with an identical cold/warm pair, then matched different TypeScript PRs and growing second-opinion threads. Capture input, cached reads, cache writes when reported, output, wall time, and actual route. Compare the provider usage with OpenRouter’s generation record and cache discount when present. Use provider-reported charges or separately identified estimates. An isolated repeat is a wiring check. Use changing PRs and conversations for savings estimates. Include the observed 9% cost reduction and absence of a speedup as the baseline to reproduce or explain. Benchmark Hy4 through its selected OpenRouter route on distinct TypeScript PRs and resumed sessions. Prior 99.1% warm reuse was on repeated inputs. Capture the DeepSeek route’s existing cache metrics as a baseline and preserve its tested routing configuration. Keep all telemetry free of prompt content, credentials and private session identifiers. [Hy4 cache pricing](https://openrouter.ai/tencent/hy4/)
   - **Gate.** Add the cache tests in §10 and use the existing public fixture and exact-head publication path. Prove the same verdict and resume contract, report changes in false findings, and publish paired hit rate, time and cost results under #2531. Confirm the cached billing improvement on representative requests before proposing opt-in release. If savings are immaterial or any review regression appears, keep the cache experiment disabled. Rollback removes only the cache settings and restores the previous prompt order.

6a. **Repair missing cache measurements (`lead-only`; external usage parsing).**
   Change `bin/ai-review-simple:cache_receipts` and its regression tests;
   normalize the two pre-existing `run_harness_once` failure returns to the
   caller's four-field result contract and make the existing non-Muse cache
   exclusion test inspect the real profile, as identified by Muse.
   Missing/null counters remain unknown; explicit zero remains zero; accept
   nonnegative integer counters, excluding booleans. Ignore malformed events
   and nested shapes without failing a review. Sum only actual reported values
   independently for reads/writes, retaining `null` when none were reported.
   Mixed coverage is an observed subtotal: never price missing calls as free.
   **Dependencies:** none on activation or paid inference. **Gate:**
   `python3 tests/test_reviewer_routes.py CacheReceiptTests`,
   `bash tests/test-reviewer-routes.sh` and `bash tests/test-ai-review-simple.sh`
   pass on Ubuntu and through the Windows CI route; a real invocation of the
   repaired parser distinguishes a completed event without usage from an
   explicit zero. Keep the existing route, prompt, cache-enable and session
   defaults byte-for-byte unchanged. Land through the queue and attach the
   exact revision and installed smoke evidence on #2531.

6b. **Measure and reduce total tokens (`lead-only`; cost and quality judgments).**
   This is a future opt-in workstream owned under #2551, after 6a lands and
   the relevant step-4 route is qualified. Re-read this whole phase before
   implementation. Run the following experiments in order, one change at a
   time, reusing the existing fixture/receipt paths. Nothing here activates a
   setting or claims savings before measurement.

   The fleet candidate adds opt-in usage receipts across both reviewer entry
   points and the standalone DeepSeek Harness path. Use `AI_REVIEW_USAGE=1`
   with a freshly generated `AI_REVIEW_BILLING_ID` of the form `bill-` followed
   by 32 lowercase hexadecimal characters to attribute public qualification
   requests to one OpenRouter job. Keep the same opaque ID across an intended
   named-session comparison and use a different ID for the control. The billing
   credential belongs only in the read-only reconciliation process. Runtime
   step totals may miss auxiliary requests and do not establish actual cost.
   OpenRouter analytics filtered by the reviewer key and opaque session ID
   proved this gap even when every observed step succeeded. Join local
   receipts to a protected query by the SHA-256 fingerprint of its opaque
   billing ID. Preserve unknown when provider evidence cannot be matched.
   Never publish private IDs or credentials. A billing probe starts a new
   qualification session. Omit the probe ID to continue existing sessions
   with their original state and settings.

   With `AI_REVIEW_CACHE=1`, all three OpenRouter routes can keep affinity
   independently of Muse's cache key. DeepSeek uses the pinned Harness route's
   deployment header, and Hy4 and Muse use the OpenCode request body. Only Muse
   receives a provider-specific prompt cache key. Unset the experiment
   variables for ordinary operation. For qualification, select one of
   `lean` or `concise` with `AI_REVIEW_PROMPT_VARIANT` on an explicit review
   route. The file-map trial used a separate exact-head patch file. The direct
   Meta trial mislocated a seeded finding and there was no trusted proof the
   model read the whole file, so the installed reviewer refuses that mode.

   1. **Establish complete billing first.** Extend the existing shared receipts
      around `bin/ai-review-simple:run_once`, `run_harness_once`, `review` and
      `bin/ai-second-opinion:run_opencode` as needed after inspecting the current
      implementation. Record route/model, input, cached reads/writes, output,
      reasoning where supplied, tool-loop requests, retries/failovers, elapsed
      time and actual charges or separately labelled estimates. Correlate with
      provider/gateway billing without publishing prompts or private IDs.
      Show measured coverage per field; incomplete observed subtotals cannot
      establish a full-run saving. **Gate:** planned
      `test_usage_coverage_and_failed_attempt_costs` in
      `tests/test_reviewer_routes.py` covers missing one step, missing one
      counter and charged unsuccessful attempts. Publish a reproducible
      baseline per route, including Hy4 and DeepSeek's unknowns.
   2. **Reduce redundant input before adding caching machinery.** Benchmark
      `templates/review-prompt-simple.md`, `bin/ai-review-simple:build_prompt`
      and `bin/ai-second-opinion:READ_AGENT` with a shorter stable instruction
      prefix, then independently test a compact changed-file map without
      duplicated full-file content. Keep the complete exact-head patch and
      repository available, preserve every safety instruction and required
      finding, and let the reviewer expand its reads when needed. Inspect the
      pinned runtime's system/tool overhead before attributing the historical
      24k/9k difference to our prompt. Stable tools/order and the current model
      and effort remain controlled. **Gate:** planned
      `test_lean_prompt_preserves_review_contract` and
      `test_context_expansion_keeps_required_evidence` prove source identity,
      full evidence access and hostile-input handling; paired live seeded,
      clean and real TypeScript cases measure all model/tool requests, not
      just the first prompt. Never trade missing evidence for a smaller input.
   3. **Reduce unnecessary output.** Separately test concise findings in the
      same prompt/agent definitions: location, defect, impact and final verdict;
      omit repeated instructions, progress narration and repeated patch text.
      Do not lower a hard output limit or truncate the model's reasoning or
      final findings as a substitute for concision. **Gate:** planned
      `test_concise_report_preserves_findings_and_verdict` plus paired live
      scoring shows no lost required findings, no extra false findings and
      intact publication. Count provider output and hidden reasoning when
      reported. The current 4,000-character publication cap occurs after
      generation and does not itself save model tokens.
   4. **Measure growing sessions, then test compaction only if justified.**
      At `bin/ai-second-opinion:_run_opencode_turn`, `run_harness_turn` and
      `sanitized_replay`, compare one named session with repeated fresh
      sessions for the same bounded multi-turn task, across two restarts, an
      idle interval and forced Muse failover. Same-route turns should append
      only the new question; failover should replay each permitted visible
      turn and the pending question once. Never replay private reasoning or
      tool records, and detect nested replay duplication. First observe the
      pinned runtime's existing compaction; only then consider an opt-in
      evidence-preserving summary/checkpoint experiment. Preserve original
      protected history for recovery; checkpoint identity, decisions, open
      questions and source references must survive. Any compaction policy
      change is a separate proposal, not part of this repair. **Gate:** planned
      `test_session_replay_is_linear`,
      `test_checkpoint_preserves_source_and_recovery` (only if implemented),
      and live marker/decision recall with complete per-turn billing. Include
      the cost of summaries and cache rewarming; persistence alone is not a
      discount and summaries must not substitute for re-reading changed code.
   5. **Avoid paying twice for identical completed work, only if measured.**
      Inspect existing exact-work controls before adding any in the shared
      adapters. A later opt-in deduplication experiment may reuse only a
      verified successful result for identical authorized repository/source
      digest, base/head, prompt/tool/policy versions, route/model and effort.
      New heads, changed permissions, failed or incomplete attempts and stale
      source always require fresh work. This is result deduplication, separate
      from provider prompt caching; never reuse a mutable checkout.
      **Gate:** planned `test_exact_work_reuse_rejects_changed_identity`
      covers changed source, head, prompt, policy, model and incomplete work,
      including a race between callers. If duplicate spend is absent or the
      existing controls suffice, record that and add no new machinery.

   **Common acceptance:** use at least five distinct public TypeScript changes,
   seeded and clean controls, and one growing discussion per selected route.
   Repeat paired comparisons in reversed order with identical model, effort,
   provider policy and task; separate synthetic correctness from real-PR
   generalization. Report total tokens, actual total cost per usable completed
   review/discussion, invalid answers, retries, false findings, wall time and
   measurement coverage. Include first/cold requests and idle/cache-expiry
   behavior; a new namespace cannot prove an account-wide cold cache. Require
   no regression on the frozen controls and repeatable positive net savings
   before proposing a separately reversible opt-in release; otherwise leave
   it disabled. State absolute dollars and sample size alongside percentages.
   A different interface, 24-hour retention, reasoning-effort change or model
   substitution is a separate experiment, never bundled into a prompt result.
   **Rollback:** remove only the tested opt-in variant, verify the prior
   prompt/behavior, preserve existing named sessions and private evidence.

Context cut points are after steps 3 and 4 and before a caching release. Re-read downstream steps against current upstream before beginning them. Record partial progress with a reproducible artifact in STATUS.

### Adversarial cases

Use disposable fixtures and benign canary files.

| Input | Case | Required test |
|---|---|---|
| PR diff, files or prompts | Content asks for edits, commands or extra permissions | `test_candidate_ignores_write_and_command_requests` |
| Repository paths and checkout metadata | Link to outside canary, unknown path, tracked configuration that requests extra tools | `test_candidate_isolates_paths_and_config` |
| Review identity | HEAD moved, wrong commit supplied or scope changed after first turn | `test_candidate_refuses_source_drift` |
| Process events and model output | Tool output includes fake verdict, contradictory verdicts, malformed or truncated event, timeout or nonzero exit after a verdict | `test_candidate_requires_successful_final_verdict` |
| Session IDs and state | Wrong ID, tampered state, concurrent resumes or interruption before state is committed | `test_candidate_session_identity_and_recovery` |
| Provider, credentials and errors | Unexpected route, missing key, 401, 402, 429, outage, diagnostic text containing a fake key | `test_candidate_provider_failure_and_redaction` |
| Runtime ambient environment | Private files, inherited credentials, shell or plugin auto-discovery | `test_candidate_has_no_ambient_access` |
| Route override or environment | Expired key, credential sent to wrong host, unexpected endpoint or caller tries a different model on retry | `test_route_registry_and_secret_scope` |
| Fallback response | Valid verdict, policy refusal, ambiguous 403, repeated gateway outage, confirmed Muse credential denial, only Hy4 available | `test_ci_route_fallback_and_stop` |
| Persisted review and fallback replay | Two replies race, stale workspace identity, duplicate visible question, or alternate route fails midway | `test_second_opinion_route_resume` and `test_muse_failover_is_atomic` |
| GitHub publication data | Spoofed route name, final output from an earlier head, or missing/malformed authority metadata | `test_route_attribution_matches_exact_head` |
| Cache identifiers and telemetry | Caller tries to share keys across unauthorized repos, uses per-request volatile IDs, exposes secrets in metrics, or misreports cached billing | `test_muse_cache_key_scope_and_redaction` and `test_cache_usage_receipts` |
| Cached input order and replay | PR diff alters the fixed prefix, tool definitions reorder, restart changes routing ID, or fallback replays private state | `test_cache_prefix_and_resume_stability` |
| Step-finish usage | Missing/null counters, booleans, negatives, invalid nested shapes, one missing field or mixed events | Implemented `CacheReceiptTests`: `test_missing_cache_counters_remain_unknown`, `test_cache_counters_are_independent_and_preserve_zero`, `test_invalid_cache_counters_and_shapes_are_ignored`, `test_only_reported_cache_counters_are_summed`, `test_unrelated_or_malformed_events_do_not_invent_usage` |
| Token-saving experiment evidence | Unreported or failed charged call omitted from totals; lean input omits necessary context | Planned `test_usage_coverage_and_failed_attempt_costs`, `test_lean_prompt_preserves_review_contract`, `test_context_expansion_keeps_required_evidence` |
| Concise output and persisted history | Missing finding/verdict, nested replay duplication, lost source/decision after summary | Planned `test_concise_report_preserves_findings_and_verdict`, `test_session_replay_is_linear`, conditional `test_checkpoint_preserves_source_and_recovery` |
| Exact-work result reuse | Different source/head/policy/model, partial result or concurrent caller | Planned `test_exact_work_reuse_rejects_changed_identity` |

## 10. Tests

Run `bash tests/test-ai-review-simple.sh`, `bash tests/test-ai-deepseek-agent.sh`, `bash tests/test-ai-deepseek.sh`, and `python3 -m unittest discover -s tests -p test_deepseek_repo_tools.py`. Add `tests/test_reviewer_routes.py` (or equivalent tests in the existing suites) for each named regression in §9. Register the tests in the normal CI path. Run Bash through Git Bash on Windows and check the shared runner collision rules before full local suites.

| Scenario | Required live evidence |
|---|---|
| GitHub explicit selection, all four route IDs | Four fresh candidate reviews against test PR heads, real inference and file-tool receipt in Actions, each check and comment attributed correctly. Match the seeded TypeScript finding and clean verdict controls. |
| GitHub automatic Muse fallback, Hy4 fallback and shared gateway outage | A simulated rejection of the direct credential continues to live Muse on OpenRouter with one published verdict; a bounded forced exhaustion reaches live Hy4; a confirmed shared outage skips redundant routes and retains an independent route. |
| On-demand fresh review and resume, all four routes on Ubuntu and edge-dev | At least three named read-only conversations per route and OS, two fresh-process restarts per conversation. The follow-up correctly recalls a marker unavailable in the question or current file. Verify mixed-case and spaced paths. |
| On-demand Muse fallback mid-session on both OSes | First turn succeeds through Meta. Force a classified credential failure for a follow-up. The same named discussion resumes through OpenRouter, with the marker and original review scope intact. Prove a failing fallback leaves the last-good record available. |
| Read-only and routing integrity | Existing and new file write probes fail, hashes and Git metadata remain stable, no ambient files or credentials are reachable, and private session artifacts remain scoped. Test both clean and seeded changes, fake verdicts in input and untrusted fixture instructions. |

Run a minimum of five independent fresh candidate requests per route on each supported OS in addition to the GitHub runs. Record actual route, verdict, elapsed time, restart receipt and platform. Separate terminal policy outcomes from failed authentication in tests and live receipts. Record baseline timings per entry point and assess Hy4 on previously unscored TypeScript fixtures before declaring it production-ready.

Phase C adds exact request-capture tests for the three cache cases above. Verify Muse direct receives the upstream key, Muse through OpenRouter receives both fields, and stable/reordered and switched-route cases obey their scope. Use paired cache-disabled and cache-enabled fixtures with identical input policy, model and effort. Each route receipt distinguishes a missing measurement from a zero hit, and reports the no-switch control. Replay a cold/warm pair, five distinct TypeScript PRs and one growing second opinion across restart per Muse route. Run the long-context and retention comparisons independently so an inconclusive test cannot masquerade as measured savings. Record Hy4 and DeepSeek separately from Muse.

At the exact merged release, prove the named-session restart and opt-in
review behavior independently on edge-dev3 and hetz (native Ubuntu) and
edge-dev (native Windows). On each host record the installer receipt, exact
source, route/model/runtime, declared effort and source fixture, one paired
cache-off/on review for DeepSeek, Hy4 and both Muse connections, and two
fresh-process restarts of a real named session. Verify ordinary behavior with
the experiment disabled and retain the session during that rollback rehearsal.
Keep the 24-hour retention arm inactive unless its separate storage authority
is documented. Responses can be compared with response storage disabled.

For this reporting-only amendment run the three suites in step 6a; broader
DeepSeek suites above apply when their execution paths change. The new
`CacheReceiptTests` tests are implemented and run via the existing
`tests/test-reviewer-routes.sh` Ubuntu/Windows CI entry point. All step-6b test
names are acceptance specifications for future implementation, not tests
already present. Do not report their planned outcomes as passing evidence.

## 11. Constraints

GitHub AI review remains advisory. Keep a separate candidate selection until evidence passes. Preserve existing reviewer scopes and receipts. Sandbox and inspect only authorized repositories. Keep private prompts, transcripts, key material and sensitive logs out of the public repo and GitHub comments. Limit diagnostics to redacted summaries and artifacts suitable for public consumption. Use protected release routes and the repository Git identity. Avoid edits to installed or shared checkouts.

## 12. Access and environment

Use Python 3, Git, Bash or Git Bash, Node, pinned DeepSeek Harness and the installed OpenCode runtime. GitHub commands use `bin/ai-gh` for `popcre/ai-devops` with the repository’s authorized identity. Qualification uses a sandbox runner, a private temporary checkout/root, and the trusted fixture branch pattern used in PR #2538. Run local review via the candidate selectors at the entry points in §§5 and 9 and use `--prompt-file` or stdin for Windows quoting.

Credential references only. In the `vibe_coding` 1Password vault, resolve Meta direct via the current managed Muse item referenced by `bin/ai-second-opinion`, and use `openrouter key specifically for reviewers` for public fixture qualification. Confirm that the exact deployed credential and its provider/retention rules permit the intended repo and model before any non-public review. Use distinct scoped CI and interactive credentials if available. Provision any new bindings via `secrets-to-1password` and existing protected install routes. No test login is needed. Keep all raw model artifacts private.

## 13. Done, risks and rollback

- [x] All four routes are available on both normal entry points after the intended release. Muse can switch connections automatically on confirmed account or service failure. Hy4 remains explicit on demand and a fallback in GitHub. Activation merged in `c58eb1e0` (2026-11-17, owner go): route-attributed verdict through the default rotation ([probe PR #2612](https://github.com/popcre/ai-devops/pull/2612)), new Muse second opinions default to the candidate route, live forced-failover continuation in the [re-check receipt](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6955989936).
- [x] Exact candidate revision has passing focused and policy-required tests, Ubuntu and edge-dev receipts, and four attributable GitHub verdicts. Keep `- [ ] live proof` on #2531 until completed. Qualification receipts #2563–#2568; per-model re-check (all four routes, both OSes, restart-recall phrasing pass, caching pairs) in the [2026-11-17 re-check receipt](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6955989936); activation live proof on #2612.
- [x] Candidate lands through the protected queue, old defaults remain during qualification, and any later activation has a separately revertible default change. Confirm commit on `origin/main`, installed revisions and one live check per enabled route. Activation `c58eb1e0` on `origin/main` (queue, PR #2580); runners read the toolkit from `main` per run; rollback rehearsed on #2588 (pure default flip, live legacy review `ai-review: pass (muse)` post-revert).
- [x] Record Phase C separately. If caching is released, verify its measured API usage and rollback without changing the review routes. The initial route release can finish while the cache experiment stays disabled. Cache experiment stays off by default on #2551; the route release changed no cache setting.
- [x] Step 6a reporting repair landed with regression tests and installed Ubuntu/Windows proof: [acceptance receipt](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6962732060), source `7dffdd4845729eac1a29463a60093b94cf134832`. Missing counters stay unknown, measured zero stays zero and defaults remain unchanged. The wider rollout and future Phase C experiments remain open on their existing issues.
- [x] Step 6b experiments evaluated across both Muse connections, DeepSeek and Hy4. The fleet evidence above distinguishes measured savings, rejected changes and incomplete billing or quality. Installed live proof is on [#2551](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6967526056) with parent evidence on [#2531](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6967526195). The separate #2580 default activation is outside this fleet proof.
- [x] Rehearse restoring previous settings without deleting candidate session state. Verify that a live legacy review can complete after rollback. Rehearsal PR [#2588](https://github.com/popcre/ai-devops/pull/2588): exact `git revert` of the activation, live legacy review completed post-revert (`ai-review: pass (muse)`), candidate session state readable from the revert head. The first rehearsal (#2581, closed) surfaced the stray-brace bug fixed by #2584.
- [x] Update STATUS, current reviewer docs and tracking issue with live evidence. Retire applicable handoffs only after the acceptance conditions are met. This commit updates STATUS and retires the 2026-11-17 staging handoff (#2574); the tracking issue #2531 carries the activation, rollback and live-proof receipts.

Key risks are shared OpenRouter failure, route-bound Muse session history, Windows isolation differences, provider response shape changes and accidental reuse of an earlier GitHub result. Require the tests in §10 for each risk. If a supported platform or an approved disclosure route cannot be verified, keep the existing defaults and record the exact blocker on #2531.

## Self-audit

1. A new session can implement this without the chat by starting at STATUS and following §§5 and 8–13. Those sections identify both callers, all routes, prerequisites, failure outcomes, credential locations, test evidence and release behavior.
2. §§3–7 retain the Meta interruption, earlier DeepSeek and Muse trials, OpenCode connection failure, cache measurement and Hy4 quality limits. §§8–10 distinguish the earlier native Muse publication evidence from the unqualified OpenCode Muse routes, and specify exact-head publication, policy handling and cross-route continuation.
3. The opening goal, §8 and §13 preserve availability, exact verdict publishing, session resume and read-only controls when an implementation detail needs revision. All 13 sections and the adversarial matrix are present. Phase C and §10 now capture OpenRouter’s Muse guidance, its unproven claims, and separate opt-in release and rollback. The current handoff links back here. The fresh-reader pilot is closed, so no optional external check ran.

November 17 amendment self-audit passed for the added scope:

1. A fresh implementer can distinguish the implemented reporting repair from
   future experiments using STATUS, §§4–6, steps 6a/6b and §10. Each new step
   names its files, dependency, role, observable gate and rollback; planned
   tests are explicitly labelled rather than claimed as delivered.
2. §§6–8 and step 6b retain the measured 9%/$0.06-per-1,000 baseline, uncontrolled
   24k/9k comparison, continuity-versus-cost distinction, observed-subtotal
   caveat, complete-job billing and rejected privacy/evidence shortcuts. All
   13 sections and the existing handoff/router links remain; this amendment
   adds no new plan or handoff and does not restart the closed fresh-reader pilot.
3. The opening goal plus §§4, 9 and 13 require useful reviews with lower
   measured spend, not a cache percentage target. Evidence and recoverability
   take priority, and the owner's unchanged-default instruction is explicit.

The owner-requested Muse review assessed the finished change and the whole
plan and returned APPROVE. Its two concrete pre-existing failure/coverage
findings are addressed by the reporting-contract fixes and tests in §5/6a;
the plan does not turn its optional experiments into approval or activation
requirements. Live billing conclusions remain unassessable until measured.

Step 6a delivery audit: #2600 and #2601 landed through the queue; the tested
and landed source tree is `6614581e71e87ec2530eba443614cd37bdb85753`. Ubuntu
and Windows each passed 56 route plus 38 legacy checks, both normal installers
completed at `7dffdd4845729eac1a29463a60093b94cf134832`, and installed smoke
proved missing, zero and partial counters with matching normalized tool hashes.
The receipt above records the two Muse APPROVE results and unchanged-default
proof. This completes only 6a and this plan amendment, not the parent rollout
or step 6b. Future documentation-only acceptance updates do not change the
installed runtime bytes or require repeating the same code tests.

### Lead launch prompt for the token-efficiency amendment

```text
Continue popcre/ai-devops #2531/#2551 from the STATUS of
plan_deepseek-harness-openrouter.md, then read AGENTS.md and §§4–13 here.
Keep every current default unchanged. Confirm step 6a's exact landed revision
and installed proof before treating the reporting repair as complete. Future
work is step 6b, not an instruction to reimplement already landed route work.
Do all listed lead-only judgments yourself: untrusted usage, scope, privacy,
provider billing, quality, merges and release. Follow numbered dependencies;
re-read the downstream phase at each context cut. Do not invent measurements
or infer whole-job savings from partial counters or session continuity.
Your helper is your own tool's smaller model — Haiku (high effort) for
Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for
Mimo Pro. Never a full-strength model.
Routing authority:
https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md
No helper-ok work is currently specified. If you extract a mechanical substep,
give exact files/edits/tests and stop-and-ask triggers first. The helper returns
finished work with test evidence or a verbatim blocker, never a design decision;
no merges or posts. Take work back after 30 minutes without progress.
The lead runs the §10 checks, verifies both platforms and complete live billing
with unchanged defaults, and records any outstanding live proof on the same
issues. Never release a token-saving variant as part of this amendment.
```
