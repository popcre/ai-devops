---
summary: Implement and qualify DeepSeek, Muse, and Hy4 routes for GitHub reviews and resumable second opinions
kind: plan
status: open
read-when: changing DeepSeek, Muse, or Hy4 review routes, credential fallback, or reviewer cutover
---

# DeepSeek, Muse and Hy4 reviewer implementation

Keep GitHub reviews and second opinions available even when Meta direct loses access. Give both entry points the same reviewer choices, preserve ongoing discussions, and make every review read-only. Confirm that GitHub publishes each reviewer’s verdict before a route becomes active. If a step conflicts with this goal, the goal wins — stop and flag it.

Tracking: [#2531](https://github.com/popcre/ai-devops/issues/2531). Start with the [current handoff](HANDOFF.d/2026-11-16T2118Z-edge-dev3-codex-reviewer-route-build.md). The [original DeepSeek handoff](HANDOFF.d/2026-11-16T1837Z-edge-dev3-codex-deepseek-harness-openrouter.md) records the initial scope.

## STATUS — start here

Use current upstream. Planning baseline: `ec4886f57232a1bb2741b7cf66d5fa1a949a1def`. The combined implementation starts at step 1. Runtime tests used disposable setups and the regular workflow on a test branch. No candidate route shipped or became a default.

| Step | Status, 2026-11-16 | Evidence or next gate |
|---|---|---|
| 1. Shared route definitions and protected runtime profiles | Open | [Isolated Ubuntu and Windows benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) informs pins and controls. |
| 2. Wire GitHub review and fallback | Partial proof | [DeepSeek and Muse native verdicts on a disposable TypeScript PR](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224). Candidate product wiring and final route proofs remain open. |
| 3. Wire resumable second opinions | Partial proof | [Read-only native session restart evidence](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521). Cross-route Muse continuation remains open. |
| 4. Qualify the exact integrated candidate | Open | Run the route, platform and failure matrix in §10. |
| 5. Enable, verify and retain rollback | On hold | Keep existing defaults during qualification. Follow §13 for the eventual cutover. |

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
- [Muse cache benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964) measured roughly 9% model-request cost reduction and no overall speedup with a stable prefix and cache key across changing TypeScript PRs. Leave cache changes outside the initial cutover so unresolved caching behavior cannot confound route proof.
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

Context cut points are after step 3 and after step 4. Re-read downstream steps against current upstream before entering either phase. Record partial progress with a reproducible artifact in STATUS.

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

## 10. Tests

Run `bash tests/test-ai-review-simple.sh`, `bash tests/test-ai-deepseek-agent.sh`, `bash tests/test-ai-deepseek.sh`, and `python3 -m unittest discover -s tests -p test_deepseek_repo_tools.py`. Add `tests/test_reviewer_routes.py` (or equivalent tests in the existing suites) for each named regression in §9. Register the tests in the normal CI path. Run Bash through Git Bash on Windows and check the shared runner collision rules before full local suites.

| Scenario | Required live evidence |
|---|---|
| GitHub explicit selection, all four route IDs | Four fresh candidate reviews against test PR heads, real inference and file-tool receipt in Actions, each check and comment attributed correctly. Match the seeded TypeScript finding and clean verdict controls. |
| GitHub automatic Muse fallback, Hy4 fallback and shared gateway outage | A simulated rejection of the direct credential continues to live Muse on OpenRouter with one published verdict; a bounded forced exhaustion reaches live Hy4; a confirmed shared outage skips redundant routes and retains an independent route. |
| On-demand fresh review and resume, all four routes on Ubuntu and edge-dev | At least three named read-only conversations per route and OS, two fresh-process restarts per conversation. The follow-up correctly recalls a marker unavailable in the question or current file. Verify mixed-case and spaced paths. |
| On-demand Muse fallback mid-session on both OSes | First turn succeeds through Meta. Force a classified credential failure for a follow-up. The same named discussion resumes through OpenRouter, with the marker and original review scope intact. Prove a failing fallback leaves the last-good record available. |
| Read-only and routing integrity | Existing and new file write probes fail, hashes and Git metadata remain stable, no ambient files or credentials are reachable, and private session artifacts remain scoped. Test both clean and seeded changes, fake verdicts in input and untrusted fixture instructions. |

Run a minimum of five independent fresh candidate requests per route across the local platform matrices, on each supported OS in addition to the GitHub runs. Record actual route, verdict, elapsed time, restart receipt and platform. Separate terminal policy outcomes from failed authentication in tests and live receipts. Record baseline timings per entry point and assess Hy4 on previously unscored TypeScript fixtures before declaring it production-ready.

## 11. Constraints

GitHub AI review remains advisory. Keep a separate candidate selection until evidence passes. Preserve existing reviewer scopes and receipts. Sandbox and inspect only authorized repositories. Keep private prompts, transcripts, key material and sensitive logs out of the public repo and GitHub comments. Limit diagnostics to redacted summaries and artifacts suitable for public consumption. Use protected release routes and the repository Git identity. Avoid edits to installed or shared checkouts.

## 12. Access and environment

Use Python 3, Git, Bash or Git Bash, Node, pinned DeepSeek Harness and the installed OpenCode runtime. GitHub commands use `bin/ai-gh` for `popcre/ai-devops` with the repository’s authorized identity. Qualification uses a sandbox runner, a private temporary checkout/root, and the trusted fixture branch pattern used in PR #2538. Run local review via the candidate selectors at the entry points in §§5 and 9 and use `--prompt-file` or stdin for Windows quoting.

Credential references only. In the `vibe_coding` 1Password vault, resolve Meta direct via the current managed Muse item referenced by `bin/ai-second-opinion`, and use `openrouter key specifically for reviewers` for public fixture qualification. Confirm that the exact deployed credential and its provider/retention rules permit the intended repo and model before any non-public review. Use distinct scoped CI and interactive credentials if available. Provision any new bindings via `secrets-to-1password` and existing protected install routes. No test login is needed. Keep all raw model artifacts private.

## 13. Done, risks and rollback

- [ ] All four routes are available on both normal entry points after the intended release. Muse can switch connections automatically on confirmed account or service failure. Hy4 remains explicit on demand and a fallback in GitHub.
- [ ] Exact candidate revision has passing focused and policy-required tests, Ubuntu and edge-dev receipts, and four attributable GitHub verdicts. Keep `- [ ] live proof` on #2531 until completed.
- [ ] Candidate lands through the protected queue, old defaults remain during qualification, and any later activation has a separately revertible default change. Confirm commit on `origin/main`, installed revisions and one live check per enabled route.
- [ ] Rehearse restoring previous settings without deleting candidate session state. Verify that a live legacy review can complete after rollback.
- [ ] Update STATUS, current reviewer docs and tracking issue with live evidence. Retire applicable handoffs only after the acceptance conditions are met.

Key risks are shared OpenRouter failure, route-bound Muse session history, Windows isolation differences, provider response shape changes and accidental reuse of an earlier GitHub result. Require the tests in §10 for each risk. If a supported platform or an approved disclosure route cannot be verified, keep the existing defaults and record the exact blocker on #2531.

## Self-audit

1. A new session can implement this without the chat by starting at STATUS and following §§5 and 8–13. Those sections identify both callers, all routes, prerequisites, failure outcomes, credential locations, test evidence and release behavior.
2. §§3–7 retain the Meta interruption, earlier DeepSeek and Muse trials, OpenCode connection failure, cache measurement and Hy4 quality limits. §§8–10 distinguish the earlier native Muse publication evidence from the unqualified OpenCode Muse routes, and specify exact-head publication, policy handling and cross-route continuation.
3. The opening goal, §8 and §13 preserve availability, exact verdict publishing, session resume and read-only controls when an implementation detail needs revision. All 13 sections and the adversarial matrix are present. The current handoff links back here. The fresh-reader pilot is closed, so no optional external check ran.
