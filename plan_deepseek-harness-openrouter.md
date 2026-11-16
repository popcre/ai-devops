---
summary: Qualify a shared DeepSeek Harness runner through OpenRouter for automatic reviews and resumable second opinions
kind: plan
status: open
read-when: changing either DeepSeek review path or testing the OpenRouter cutover
---

# DeepSeek Harness through OpenRouter

Keep automatic DeepSeek reviews and on-demand second opinions working through one review engine. Prove that GitHub receives a verdict, follow-ups remember the prior discussion, and neither path can change reviewed files before switching either path. If a step conflicts with this goal, the goal wins — stop and flag it.

Tracking: [#2531](https://github.com/popcre/ai-devops/issues/2531). Continuation: [handoff](HANDOFF.d/2026-11-16T1837Z-edge-dev3-codex-deepseek-harness-openrouter.md).

## STATUS

Start at step 1 from current upstream. Planning baseline: `bc7a42c027fb6eadd0d7fa6c42b2213a0ca438c1`. No qualification or cutover has occurred.

| Step | Status, 2026-11-16 | Evidence |
|---|---|---|
| 1. Pin and qualify the runner | Open | — |
| 2. Connect both callers with defaults preserved | Open | — |
| 3. Prove the candidate in isolation | Open | — |
| 4. Switch, verify, and retain rollback | Open | — |

## 1. Goal

Share execution and safety controls while preserving the two ways people request a review. A successful one-off model response counts only as connection proof.

## 2. Application

[popcre/ai-devops](https://github.com/popcre/ai-devops) supplies reviewer tooling. Automatic review runs in GitHub Actions via the installed toolkit and checked-out PR head. On-demand review runs through the installed second-opinion wrapper on Ubuntu and Windows. Use protected `main` as upstream and isolated task worktrees.

## 3. Trigger

Albert asked to route both review paths through the official DeepSeek Harness via OpenRouter after extensive testing. This is a consolidation request. The planning session established the two entry points from source and did not reproduce an outage.

## 4. Scope

Included: shared execution adapter, OpenRouter credential and model configuration, both callers, platform qualification, cutover and rollback. Excluded: DeepSeek implementation delegation, other reviewers, changing advisory policy, rewriting stored conversations, and publishing private review content.

## 5. Current code

- [GitHub workflow](.github/workflows/ai-review.yml) lines 91–107 calls `ai-review-simple`, tries the rotation and advances when a reviewer is unavailable. [Driver](bin/ai-review-simple) lines 49–61 configures DeepSeek direct. `make_workspace`, `run_once`, `review` and `combine` split isolation, execution and publication.
- [On-demand wrapper](bin/ai-deepseek-agent) lines 74–76 pins the direct endpoint. `send`, `reply`, `doctor` and `finalize` preserve scope, continuation and recovery. [Repository tools](tools/deepseek_repo_tools.py) govern read access. [Second-opinion skill](skills/shared/deepseek-second-opinion/SKILL.md) describes the public entry point.
- [Implementation delegation](bin/ai-deepseek) uses its own OpenCode profile. Its writable capability stays outside this project. No runtime or installation changes were made during planning.

## 6. Findings

The automatic driver creates a fresh remote-less checkout and isolated runtime home. The on-demand wrapper persists conversation and checks source identity when resuming. These are different lifecycle requirements with a shareable execution layer. DeepSeek documents [one-shot runs, JSON events and session resume](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/cli-help.md) and [custom provider configuration](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md). [OpenRouter lists the Flash snapshot](https://openrouter.ai/deepseek). Documentation supports feasibility. Platform isolation, tool calls, provider routing and session recovery need live qualification.

## 7. Approaches ruled out

A URL swap in the on-demand wrapper hits its endpoint pin and leaves two engines. Replacing the entire GitHub workflow would discard tested advisory rotation and publication. Turning on the new runtime first would make real reviews the test surface. Importing legacy sessions into DeepSeek Harness would introduce a format migration without a demonstrated need. No live migration attempt was made.

## 8. Decisions

Locked on 2026-11-16: one shared DeepSeek Harness adapter, OpenRouter for both candidate paths, fresh GitHub sessions, resumable on-demand sessions, read-only repository access and existing advisory publishing. Existing sessions continue through their original engine. Default routing changes only after step 3. Open: exact pinned harness release and dated Flash model, selected by live compatibility, isolation and reproducibility. Prefer the same Flash snapshot on both paths. Record the actual serving provider and retention policy before sending any approved repository code.

## 9. Execution

1. **Pin the runtime and route.** Use reviewer-safety task classification and read the platform brief, `docs/deployment.md`, and both caller contracts. Add the fixed harness version and model to reviewer-owned config under `config/`. Verify released artifacts and reproducible installs on Ubuntu and Windows per existing tooling. Create a protected OpenRouter reviewer key using the secrets skill and obtain it through the existing protected credential pattern. Give the runner a fresh home and explicitly selected provider. Start with public fixtures. Gate: both platforms return the expected fixture marker, with tool output and actual provider recorded, secrets absent from output, and no traffic to the direct DeepSeek API.
2. **Connect the callers behind explicit candidate selection.** After step 1, add a single adapter under `tools/` for launch, deadlines, validated final events and session IDs; reuse lifecycle and credit helpers where compatible. In `bin/ai-review-simple`, call it only for the DeepSeek candidate, keep exact-head identity and the verdict/report schema, and accept a verdict solely from a successful final assistant event. In `bin/ai-deepseek-agent`, route new candidate sessions and subsequent replies through the adapter. Persist the engine, model, session ID and source identity in private per-session metadata. Reuse scope validation, per-session locking and recovery; keep old sessions on the legacy route, and fail closed on unknown or mismatched sessions. Keep transient workspace and writable session storage distinct. Disable shell, write, external plugins and ambient config for the reviewer; enforce filesystem isolation independent of prompt instructions and constrain model-facing egress to the selected gateway. Verify runtime controls on both platforms, including child cleanup. Gate: offline suites in §10 pass and existing defaults are demonstrated unchanged.
3. **Qualify in isolation.** After step 2, run the §10 matrix with the candidate explicitly selected. For GitHub, use a controlled fixture PR running the candidate toolkit revision and follow the existing combine-and-publish path. Verify the published check/comment names DeepSeek and the exact head, so a rotation fallback cannot count. For second opinions, start a review, exit the caller, then resume twice from fresh processes with a follow-up answer that depends on an unpredictable marker from the first turn. Record run IDs, exact revisions, route, final outcomes, filesystem receipts and redacted timings on the tracking issue. Gate: every matrix row passes, both platform proofs are available and the reviewer continues to be advisory. A failed case keeps the existing defaults active. Re-run affected cases and end-to-end runs on the final candidate revision after fixes.
4. **Enable and verify.** After step 3, re-read steps 3–4 against current upstream, then use a small separately revertible default-selection change. Land through the merge queue, apply the protected install where applicable, and confirm the exact landed revision. Verify one actual DeepSeek verdict in the intended GitHub workflow and one resumed local discussion per supported OS. On failure, restore both previous defaults through the same release route, verify both legacy entry points, and retain candidate session data privately. Gate: live receipts are linked to the issue and rollout or rollback is proven on each target.

After steps 2 and 3, use a fresh session if context is low and re-read downstream steps before execution.

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

## 10. Tests

Add the named tests above to the existing caller suites or add a focused shared-adapter suite under `tests/` and invoke it from normal CI. Keep `bash tests/test-ai-review-simple.sh`, `bash tests/test-ai-deepseek-agent.sh`, `bash tests/test-ai-deepseek.sh` and `python3 -m unittest discover -s tests -p test_deepseek_repo_tools.py` green. Run Bash tests through Git Bash on Windows. Check shared runner collision before full local suites.

For each OS, run five independent fresh candidate reviews and three separate second-opinion conversations with two restarts each. Cover a seeded finding, a clean patch, file reading with the model tool, injected instructions, and repository paths with spaces in the fixture spread. Require valid verdicts and correct seeded outcomes. Repeat the read-only probes through both entry points on each OS; check repository contents, untracked paths, Git metadata, caller workspace and external canaries before and after. Exercise timeout and provider refusal in CI fixtures. Record one matched baseline run per entry point and OS to expose regression in verdict handling, latency or scope. The controlled GitHub PR publication is required in addition to local runs.

## 11. Constraints

GitHub AI review remains advisory. Keep a separate candidate selection until evidence passes. Preserve existing reviewer scopes and receipts. Sandbox and inspect only authorized repositories. Keep private prompts, transcripts, key material and sensitive logs out of the public repo and GitHub comments. Limit diagnostics to redacted summaries and artifacts suitable for public consumption. Use protected release routes and the repository Git identity. Avoid edits to installed or shared checkouts.

## 12. Access and environment

Use Git, Python 3, Bash or Git Bash, Node and the pinned DeepSeek Harness CLI. Use GitHub access through `bin/ai-gh` with the POP toolkit identity and the installed runner arrangement in `docs/deployment.md`. Ubuntu and Windows targets follow `config/reviewer-platform-brief.txt`. The proposed 1Password location is vault `vibe_coding`, item `OpenRouter DeepSeek Reviewer API Key`; verify existence and policy before provisioning it. Never print the key. No test login is required. Use disposable fixture repositories and the offline commands in §10 before sending a live request.

## 13. Done, risks and rollback

- [ ] Candidate and both callers committed, pushed, checked and merged through the repository queue.
- [ ] Exact candidate revision passes the offline and live matrix before enabling defaults.
- [ ] Exact landed revision and installed copies verified. Published GitHub verdict, local resume and read-only proof linked on the same issue.
- [ ] Prior routing restored successfully in rehearsal. OpenRouter outage, harness permission differences, output drift and incompatible continuation each have a failure test.
- [ ] Update STATUS and user-facing reviewer docs, retire the handoff after live proof, and close the issue.

If a supported OS cannot enforce read-only isolation, or the route cannot satisfy repository disclosure rules, retain current routing and record the blocker on the issue. No cutover on partial evidence.

## Self-audit

1. A fresh session can execute this plan from §§5 and 9–13. The callers, change order, fixtures, release gates and rollback are specified.
2. §§2–8 preserve the two lifecycle contracts, the direct endpoint pin, advisory policy, alternatives and the open compatibility questions. §9 covers hostile inputs and §12 names only the credential location.
3. The opening goal and §§8 and 13 preserve both review outcomes and read-only access if a proposed implementation proves unsuitable. The handoff links back here. Fresh-reader review was skipped under the closed pilot policy.
