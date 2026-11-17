---
summary: Implement and qualify DeepSeek, Muse, and Hy4 routes for GitHub reviews and resumable second opinions
kind: plan
status: open
read-when: changing DeepSeek, Muse, or Hy4 review routes, credential fallback, or reviewer cutover
---

# DeepSeek, Muse and Hy4 reviewer implementation

Keep GitHub reviews and second opinions available even when Meta direct loses access. Give both entry points the same reviewer choices, preserve ongoing discussions, and make every review read-only. Confirm that GitHub publishes each reviewer’s verdict before a route becomes active. If a step conflicts with this goal, the goal wins — stop and flag it.

Tracking: [parent #2531](https://github.com/popcre/ai-devops/issues/2531), [DeepSeek #2549](https://github.com/popcre/ai-devops/issues/2549), [OpenCode #2550](https://github.com/popcre/ai-devops/issues/2550), [caching #2551](https://github.com/popcre/ai-devops/issues/2551). Start with the [current handoff](HANDOFF.d/2026-11-16T2207Z-edge-dev3-codex-reviewer-rollout-closeout.md). The [previous handoff](HANDOFF.d/2026-11-16T2118Z-edge-dev3-codex-reviewer-route-build.md) records the earlier implementation planning.

## STATUS — start here

Use current upstream. Planning baseline: `ec4886f57232a1bb2741b7cf66d5fa1a949a1def`. The combined implementation starts at step 1. Steps 1–4 track on #2549 and #2550, Phase C on #2551. Integrated acceptance and the no-switch hold remain on #2531. Runtime tests used disposable setups and the regular workflow on a test branch. No candidate route shipped or became a default.

| Step | Status, 2026-11-16 | Evidence or next gate |
|---|---|---|
| 1. Shared route definitions and protected runtime profiles | Code landed (this PR) | Registry `config/reviewer-routes.json` + `tools/reviewer_routes.py`; `test_route_registry_and_secret_scope` in tests/test_reviewer_routes.py. | [Isolated Ubuntu and Windows benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) informs pins and controls. |
| 2. Wire GitHub review and fallback | Code landed (this PR); live proof open | `--route`/`--run-plan`/`--candidate-plan`; workflow consumes the plan only through the opt-in input. Phase B receipts still open. | [DeepSeek and Muse native verdicts on a disposable TypeScript PR](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224). Candidate product wiring and final route proofs remain open. |
| 3. Wire resumable second opinions | Code landed (this PR); live proof open | `--route` on ai-second-opinion (per-session lock, sticky selection, atomic Muse failover), harness engine in ai-deepseek-agent, ai-hy4 entry point. | [Read-only native session restart evidence](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521). Cross-route Muse continuation remains open. |
| 4. Qualify the exact integrated candidate | Open | Run the route, platform and failure matrix in §10. |
| 5. Enable, verify and retain rollback | On hold | Keep existing defaults during qualification. Follow §13 for the eventual cutover. |
| 6. Qualify caching separately | Open | [Muse baseline](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964). Phase C can start after step 4. |

## 1. Goal

Share execution and safety controls while preserving the two ways people request a review. A successful one-off model response counts only as connection proof.

## 2. Application

[popcre/ai-devops](https://github.com/popcre/ai-devops) supplies reviewer tooling. Automatic review runs in GitHub Actions via the installed toolkit and checked-out PR head. On-demand review runs through the installed second-opinion wrapper on Ubuntu and Windows. Use protected `main` as upstream and isolated task worktrees.

## 3. Trigger

Albert selected one DeepSeek Harness route and three OpenCode routes for automatic GitHub review and on-demand second opinions. Intermittent loss of Meta direct access makes a separate Muse connection valuable. Simulate Meta authentication denial in a disposable fixture, then prove Muse can continue through OpenRouter using the same model. The exact vendor reason behind prior denials is outside this investigation.

## 4. Scope

Include shared route and credential selection, both callers, read-only isolation, GitHub publishing, persistent second opinions, fallback, platform qualification and rollback. Hy4 is available for second opinions and used as a GitHub fallback. Exclude changes to advisory merge policy, GLM and StepFun behavior, writable DeepSeek delegation and existing writable Muse commands, migration of stored conversations, provider policy bypasses, and a default switch during this planning or qualification work.

## 5. Current code

At the planning baseline, [`bin/ai-review-simple`](bin/ai-review-simple) lines 35–61 declares single-route Muse and DeepSeek provider specs. `read_key`, `make_workspace`, `run_once`, `review`, `rotation` and `combine` own credential lookup, OpenCode, one advisory verdict and the existing result shape. [`.github/workflows/ai-review.yml`](.github/workflows/ai-review.yml) lines 91–139 invokes the rotation and posts an exact-head check and comment. The normal workflow uses the trusted toolkit ref for execution.

[`bin/ai-second-opinion`](bin/ai-second-opinion) imports the provider specs from the review driver. Its `start`, `write_config`, `run_opencode`, `load_meta`, `save_meta` and `parse` own workspace copy, session continuation and provider selection. [`bin/ai-muse`](bin/ai-muse) wraps it and must keep existing command forms. The Windows launchers follow the existing `.cmd` pattern.

[`bin/ai-deepseek-agent`](bin/ai-deepseek-agent) lines 74–76 pins the direct endpoint. `send`, `reply`, `doctor` and `finalize` preserve scope, continuation and recovery. [`tools/deepseek_repo_tools.py`](tools/deepseek_repo_tools.py) owns legacy read access. [`bin/ai-deepseek`](bin/ai-deepseek) is writable delegation and remains outside this work.

The routing decision landed in #2545. Native benchmark launches and GitHub proof lived in disposable environments. No integrated reviewer code from those tests is deployed.

## 6. Findings

- [Ubuntu and edge-dev results](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) prove read-only native launches, two fresh-process resumes, and speed and quality comparisons. DeepSeek Harness was faster with a common upstream, with extra false findings. Hy4 caught all 27 seeded defect instances across five runs with zero false findings. Its median on the eight-defect patch was 88.9 seconds, and it has yet to be scored on real TypeScript PRs.
- [Regular-workflow test](https://github.com/popcre/ai-devops/actions/runs/43948851731) ran native DeepSeek and native Muse live against a disposable TypeScript PR and [published both verdicts](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224). The tested Muse runtime there was Muse Code, so that run does not qualify either selected OpenCode Muse route.
- [OpenCode connection smoke test](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927103076) passed for a custom OpenAI-compatible OpenRouter connection across all three tested models. The built-in OpenRouter connection failed for Muse and DeepSeek at the tested OpenCode version.
- [Muse cache benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964) measured roughly 9% model-request cost reduction and no overall speedup with a stable prefix and cache key across changing TypeScript PRs. Use these results as Phase C baseline. Keep caching outside initial route activation so cache behavior cannot confound delivery proof.
- [DeepSeek Harness headless execution and resume](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/cli-help.md) and [custom provider setup](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md) cover the native candidate. The reviewer credential's tests observed OpenRouter routing guardrails. Preserve them.

## 7. Approaches ruled out

Replacing the whole GitHub workflow would discard known advisory behavior and publication. A DeepSeek URL override would hit the legacy endpoint pin and retain a separate execution engine. OpenCode’s built-in OpenRouter connection failed the earlier live smoke and is excluded from the initial candidate. Muse Code added latency without a demonstrated comparison advantage and is outside the selected routing plan. Silent model substitution would confuse the person asking for a second opinion. Bulk conversion of legacy sessions adds risk without a requirement. Existing sessions retain their original runtime.

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

## 11. Constraints

GitHub AI review remains advisory. Keep a separate candidate selection until evidence passes. Preserve existing reviewer scopes and receipts. Sandbox and inspect only authorized repositories. Keep private prompts, transcripts, key material and sensitive logs out of the public repo and GitHub comments. Limit diagnostics to redacted summaries and artifacts suitable for public consumption. Use protected release routes and the repository Git identity. Avoid edits to installed or shared checkouts.

## 12. Access and environment

Use Python 3, Git, Bash or Git Bash, Node, pinned DeepSeek Harness and the installed OpenCode runtime. GitHub commands use `bin/ai-gh` for `popcre/ai-devops` with the repository’s authorized identity. Qualification uses a sandbox runner, a private temporary checkout/root, and the trusted fixture branch pattern used in PR #2538. Run local review via the candidate selectors at the entry points in §§5 and 9 and use `--prompt-file` or stdin for Windows quoting.

Credential references only. In the `vibe_coding` 1Password vault, resolve Meta direct via the current managed Muse item referenced by `bin/ai-second-opinion`, and use `openrouter key specifically for reviewers` for public fixture qualification. Confirm that the exact deployed credential and its provider/retention rules permit the intended repo and model before any non-public review. Use distinct scoped CI and interactive credentials if available. Provision any new bindings via `secrets-to-1password` and existing protected install routes. No test login is needed. Keep all raw model artifacts private.

## 13. Done, risks and rollback

- [ ] All four routes are available on both normal entry points after the intended release. Muse can switch connections automatically on confirmed account or service failure. Hy4 remains explicit on demand and a fallback in GitHub.
- [ ] Exact candidate revision has passing focused and policy-required tests, Ubuntu and edge-dev receipts, and four attributable GitHub verdicts. Keep `- [ ] live proof` on #2531 until completed.
- [ ] Candidate lands through the protected queue, old defaults remain during qualification, and any later activation has a separately revertible default change. Confirm commit on `origin/main`, installed revisions and one live check per enabled route.
- [ ] Record Phase C separately. If caching is released, verify its measured API usage and rollback without changing the review routes. The initial route release can finish while the cache experiment stays disabled.
- [ ] Rehearse restoring previous settings without deleting candidate session state. Verify that a live legacy review can complete after rollback.
- [ ] Update STATUS, current reviewer docs and tracking issue with live evidence. Retire applicable handoffs only after the acceptance conditions are met.

Key risks are shared OpenRouter failure, route-bound Muse session history, Windows isolation differences, provider response shape changes and accidental reuse of an earlier GitHub result. Require the tests in §10 for each risk. If a supported platform or an approved disclosure route cannot be verified, keep the existing defaults and record the exact blocker on #2531.

## Self-audit

1. A new session can implement this without the chat by starting at STATUS and following §§5 and 8–13. Those sections identify both callers, all routes, prerequisites, failure outcomes, credential locations, test evidence and release behavior.
2. §§3–7 retain the Meta interruption, earlier DeepSeek and Muse trials, OpenCode connection failure, cache measurement and Hy4 quality limits. §§8–10 distinguish the earlier native Muse publication evidence from the unqualified OpenCode Muse routes, and specify exact-head publication, policy handling and cross-route continuation.
3. The opening goal, §8 and §13 preserve availability, exact verdict publishing, session resume and read-only controls when an implementation detail needs revision. All 13 sections and the adversarial matrix are present. Phase C and §10 now capture OpenRouter’s Muse guidance, its unproven claims, and separate opt-in release and rollback. The current handoff links back here. The fresh-reader pilot is closed, so no optional external check ran.
