# IMPLEMENTATION PLAN — measured Jev token savings (2026-09-27)

**Parent issue:** [#643](https://github.com/popcre/ai-devops/issues/643). **Handoff:** retired after the no-go baseline. **Owner:** the session implementing the first open row, one row per session.

## STATUS — read first

| Step | State | Date | Acceptance artifact |
|---|---|---|---|
| 1. Establish a billable baseline and choose one replaceable decision | no-go complete | 2026-09-27 | [`spend-baseline-20260928T0243Z.md`](tests/verification/jev/spend-baseline-20260928T0243Z.md): no qualifying target |
| 2. Reuse the bounded Jev client and freeze one question set | N/A — no qualifying target | 2026-09-27 | Step 1 no-go; no question set or new client |
| 3. Run the selected decision in shadow mode | N/A — no qualifying target | 2026-09-27 | Step 1 no-go; no eligible selected decision |
| 4. Trial the substitution on eligible public work | N/A — no qualifying target | 2026-09-27 | Step 1 no-go; no defensible paired trial |
| 5. Keep or retire, then install and verify if kept | N/A — no qualifying target | 2026-09-27 | No integration or installation under this spend-reduction lane |

**Exploratory Jevgrep check (2026-09-28):** A separate search-tool trial did not identify a displaced paid model call or establish net token savings. Transcript command counts are only an upper bound on candidate searches; five-file Jevgrep comparisons were too small to establish a workflow saving, and broader searches did not complete within the trial limits. Step 1 remains open and must meet its billable-baseline acceptance criteria. See the [Jevgrep evaluation handoff](HANDOFF.d/2026-09-28T1123Z-edge-dev3-codex-jevgrep-search-evaluation.md) for the exact attempts, privacy boundary, and next test.

**Fresh-session start:** read `AGENTS.md`, this STATUS table, §1, §5–§9, and the existing [Jev advisory plan](plan_typesafe-jev-advisory-integrations.md) STATUS. Claim only the first open row. Recheck live state; a dated plan is not proof of installed state. At each phase boundary use `fresh-session`, reread downstream steps, and update STATUS/current state in the same PR.

## 1. The ultimate goal — what we are actually trying to achieve

Spend fewer paid frontier-model tokens on repeated, small judgments in POP Creations' AI workflow while preserving the accuracy, safety checks, and evidence Albert relies on. A successful integration displaces a **measured** existing model call or prevents a **measured** unnecessary model context load; a cheap additional Jev call alone is not a saving. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

[`popcre/ai-devops`](https://github.com/popcre/ai-devops) is the public recovery and operating toolkit used by Albert's Claude and Codex sessions. It contains command wrappers, reviewer tooling, task gates, skills, and installation scripts. There is no web app or database in this repository. GitHub `main` is protected; a feature branch and PR land changes. Installation from this repo onto a managed machine is deployment. The TypeSafe service is `https://api.typesafe.ai/v1/systemone`; Jev answers typed questions and does not act as a coding agent. [TypeSafe's agent guidance](https://docs.typesafe.ai/agent-skill) and [coding-agent explanation](https://docs.typesafe.ai/introduction/coding-agents) are primary references.

## 3. What triggered this work

On 2026-09-27 Albert requested a review of roughly 4,000 local Claude and Codex transcript files in his private Dropbox archive for yes/no, choice, and ranking work that might move to Jev. An exploratory text scan found many references to review verdicts and routing, but repeated instructions and prose created false positives. It did **not** establish a count of replaceable calls or billable savings. This request asks for an integration plan expressly aimed at token reduction. There is no bug URL to reproduce; the target behavior is unnecessary frontier-token consumption during routine AI work.

The prior [spend audit](docs/ai-spend-waste-analysis-2026-09-04.md) uses provider token counters and found concentrated cost in long sessions, cache invalidation, and oversized tool output. Its conclusions are dated and must be rechecked before claiming a saving. [Issue #643](https://github.com/popcre/ai-devops/issues/643) already owns Jev work.

## 4. Scope — in and out

In scope: one public-data, closed-answer decision that demonstrably replaces an existing frontier-model judgment or avoids a full skill/context load; a reproducible baseline; a Jev shadow comparison; a guarded trial; adoption or retirement evidence.

**NOT in this plan:** replacing Claude/Codex as coding agents; replacing independent code review or its final verdict; letting Jev open a task, review, database, production, or permission gate; changing shared-db structure; uploading private transcripts, licensed records, secrets, or reviewer packets; reviving the failed compaction plugin; fleet installation before one-machine proof; merging a pilot merely because Jev is cheap. The existing advisory [issue-pair pilot](plan_typesafe-jev-advisory-integrations.md) remains separately owned and does not count as token savings unless an actual model call is displaced.

## 5. Current state of the code

At the planning base `11f9658ee66a` (2026-09-27), this new token-saving lane has no implementation, commit, PR, or installation. The existing Jev reachability command [`bin/ai-jev-probe`](bin/ai-jev-probe) and record-only completion check [`bin/ai-jev-completion-shadow`](bin/ai-jev-completion-shadow) are committed; both currently construct their own request and use the moving `jev-latest` alias. [`tests/test-ai-jev-scripts.sh`](tests/test-ai-jev-scripts.sh) tests their offline contract. The [advisory plan](plan_typesafe-jev-advisory-integrations.md) STATUS has every implementation row open and specifies a shared bounded client at §9.2. Do not build a second client or silently mark that row done.

The earlier [decision-layer plan](plan_typesafe-jev-decision-layer.md) §§7–11 records unsuccessful compaction and completion experiments, as well as an opportunity audit. [`AGENTS.md`](AGENTS.md) routes TypeSafe work to those plans. The local private transcript archive is `/home/ahazan/Dropbox/ai/chat_transcripts/` on this machine; raw contents stay outside this public repository. The repo has no UI for visual testing.

## 6. Key findings and root cause

1. Jev returns `Noul` (probability of yes), `Choice` (one closed option plus distribution), or `Score` (ordered rating). It produces no explanation, code, or text. [Skill](https://raw.githubusercontent.com/typesafe-ai/skills/main/skills/typesafe-ai/SKILL.md), [API](https://docs.typesafe.ai/api). Therefore a full review verdict, whose reasoning and source evidence matter, is not a replaceable atomic judgment.
2. The existing issue-pair pilot reduces human reading; it has no established frontier-token baseline. Calling it a token-saving integration would be unsupported. See the advisory plan §9.3–§9.5.
3. The private transcript scan counted *mentions*, not paid decision invocations. Repeated policy text contaminates keyword totals. Step 1 must join call boundaries to the provider's actual usage counters, distinguish independent decisions from agent conversation, and identify the exact invocation that Jev could displace.
4. TypeSafe recommends keeping exact rules and execution in code, batching independent questions over the same state, and validating thresholds on domain data. Its skill-selection cookbook is relevant to context waste but does not prove savings in our clients. [Agent skill](https://docs.typesafe.ai/agent-skill), [skill suggestion](https://docs.typesafe.ai/cookbooks/skill_suggestion).
5. The previous compaction replay found the safe threshold discarded essentially nothing; a looser threshold lost later-needed information. Completion shadowing missed the real unsupported completion at the required bar. See the decision-layer plan §§7–10. Neither is an eligible first substitution.

## 7. Approaches considered and REJECTED

- **Move all verdicts to Jev:** rejected because typed outputs cannot supply independent source-grounded review and because the safety path requires a human-readable finding.
- **Count keywords as savings:** rejected; instructions, quotations, and long conversations contain decision words without a separate billable call.
- **Treat issue sorting as token displacement:** rejected until a specific paid model invocation is identified; it may still save human time under the existing plan.
- **Install fast-jev-compaction:** rejected by the recorded replay and unresolved safety constraints in the decision-layer plan.
- **Choose thresholds from TypeSafe demos or use `jev-latest` after calibration:** rejected; model and domain drift make a borrowed threshold unreliable.
- **Add Jev before deterministic task gates or cache all skill text in every session:** rejected; this could add tokens or weaken exact controls.
- **Duplicate transport, secrets handling, or plans:** rejected; reuse the shared client and issue #643, and retire this scoped plan into the established Jev decision record when complete.

## 8. Design decisions (2026-09-27)

**LOCKED:** This plan measures *net* paid frontier tokens and cost, not Jev's unit price alone. It uses a public-only first pilot, shadow mode before behavior changes, an exact model pin, and the same allowlist/limits/fail-safe contract as the advisory plan §8. Jev may suggest or abstain; it cannot approve, mutate, suppress mandatory context/evidence, or decide a protected action. Secrets resolve through `op run` from 1Password vault `vibe_coding`, item `typesafe.ai API`; no value or raw request enters logs or Git.

**LOCKED selection rule:** Step 1 chooses the *first* qualifying target in this order: (a) repeated reviewer-maintenance category suggestions, (b) public issue/task-intent sorting, (c) optional skill suggestion before full skill load. A target qualifies only if the audit identifies a concrete existing frontier call or full skill read it can avoid, at least 30 independent public cases, an observable ground-truth label, and a reversible caller path. If none qualifies, write a no-go artifact and stop; do not invent a call to replace. The existing advisory pilot can continue separately.

**OPEN, decided by evidence:** The exact target, question wording, minimum confidence, and adoption threshold come from the tuning/holdout and paired trial below. Pin and record the actual model returned by `GET /v1/models`; do not assume the old `jev-1.13.0` remains available. A model change invalidates prior calibration.

## 9. Numbered executable plan

### Phase 1 — measure and select (one session, then stop)

**9.1 Baseline.** In a current-upstream worktree, read `AGENTS.md`, `docs/task-router.md` rows for reviewer maintenance and skill routing, `docs/ai-spend-waste-analysis-2026-09-04.md`, the two existing Jev plans, and this plan. Run `ai-task-gates start --class private-evidence` for transcript analysis; if the change set becomes code, redeclare before editing code. Analyze the local private JSONL structurally, excluding system prompts, copied policy, tool output, subagents, duplicate transcripts, and unrelated user chat. Use billed token fields when present; state what cannot be priced. Map each candidate to the actual wrapper/hook/caller and current paid call. Inspect `tools/reviewer_maintenance.py`, `bin/ai-reviewer-issue`, `docs/skill-trigger-eval.md`, and the current skill-loading path; do not infer an automated LLM call from a transcript mention. Record representative *public or synthetic* labels, call frequency, input/output/cache usage, estimated cost, and a reproducible script/command in `tests/verification/jev/spend-baseline-<UTC>.md`. Store no raw transcript text or private identifiers in that public artifact. Select by §8's rule or record no-go.

**You'll know it worked when:** another session can recompute candidate frequency and billed baseline from the documented method without seeing private content, and the selected target names the exact call or context load it will avoid. If none qualifies, mark subsequent rows `N/A — no qualifying target` and close this plan without a Jev integration.

**Reviewer access to the baseline.** The `private-evidence` declaration governs reading the raw JSONL, not the later review of the sanitized public baseline. Complete the privacy check first: the baseline may contain aggregate counts, billed token totals, cost estimates, public or synthetic case labels, and a reproducible method; it must contain no transcript excerpts, prompts, private identifiers, paths to the archive, or small cells that identify one conversation. Put that checked artifact in this repository's worktree. From this public worktree, declare `prose` for an artifact-only change. A discretionary formal review of prose needs an explicit owner request passed through `--owner-request`; Albert's 2026-09-28 request to give all reviewers access to sanitized aggregates supplies that request for this baseline. Every currently registered reviewer, including StepFun on supported Linux, is eligible through its ordinary review route and current membership/preflight rules. Never launch a reviewer from the private transcript checkout or pass it the raw source as an attachment. If privacy cannot be established, leave the aggregate private and do not run an external review.

### Phase 2 — construct and shadow (one session per numbered outcome)

**9.2 Reuse client and freeze questions.** First check whether advisory-plan §9.2 has landed. If so, consume `tools/lib/jev-client.sh` and `config/jev-decisions.json`. If not, execute that precise shared-client step as the common foundation and update both plan STATUS tables; never create another transport or secret bootstrap. For the selected target, add only its question/closed labels/thresholds to that config and a thin caller under `bin/ai-jev-<target>`; use `Noul` for independent true/false claims, `Choice` for mutually exclusive categories including `none/uncertain`, and `Score` only for ordered severity. Preselect public state in code; batch independent questions once where they share state. The caller is read-only and returns `abstain` on any error, uncertainty, model mismatch, or changed source. Tests live in `tests/test-ai-jev-<target>.sh` and `tests/test-ai-jev-scripts.sh`.

**You'll know it worked when:** offline tests cover the same valid and hostile request/response paths as the shared client, and the selected workflow behaves exactly as before when Jev is absent.

**9.3 Shadow evaluation.** Create `tests/fixtures/jev/<target>-labels.json` from at least 30 independently labeled public/synthetic cases: positives, negatives, near matches, and adversarial inputs. Split before tuning, freeze the question and threshold after at most one tuning pass, then run an untouched holdout. Save `tests/verification/jev/<target>-shadow-<UTC>.md` with per-case public ID/digest, label, model, configuration digest, probabilities, abstention, confusion counts, usage tokens, latency, and errors. Never log source text or keys. Compare to the existing route's actual decisions.

**You'll know it worked when:** the report is reproducible, has zero false approvals/unsafe omissions, and shows the chosen threshold's precision, coverage, and fallback rate. A safety or privacy miss retires this candidate rather than relaxing the bar.

### Phase 3 — prove savings, decide, land (one outcome per session)

**9.4 Paired substitution trial.** For the same eligible public cases, run the baseline caller and a Jev-first route with the original caller as the abstention/error fallback. Do not change mandatory checks or source packets. Instrument the existing provider usage fields and Jev `usage.input_tokens`/`usage.output_tokens`; record cache reads/writes separately, request count, elapsed time, and estimated dollars using dated provider prices. A `Noul` probability is not a separate confidence score; apply the calibrated yes/no threshold directly. Save `tests/verification/jev/<target>-paired-<UTC>.md` with per-case identifiers/digests and aggregate frontier token, weighted cost, total cost, latency, coverage, and quality. Tests must prove the fallback fires and the old call is **skipped only when the Jev decision is eligible and accepted**.

**You'll know it worked when:** the paired artifact shows at least 10% lower **total** measured dollar cost and at least 10% fewer paid frontier tokens for eligible cases, with no regression on labeled decisions or required evidence. A result below either bar is RETIRE, not an unmeasured “promising” rollout.

**9.5 Keep or retire.** If 9.4 passes, make the smallest caller integration, add it to supported installation only after `ai-task-gates start --class installation`, run the relevant offline suite and one installed public-data live case, then document the actual installed commit/model and rollback switch. Any reviewer-safety caller instead requires `reviewer-safety`, independent exact-head read-only review, and its protected gates; it cannot be smuggled in as ordinary code. If 9.4 fails, remove the experimental caller and keep only the negative evidence and decision record. Update this plan, the advisory plan if its shared client changed, issue #643, and the topic router. Merge via PR/checks; verify the merged commit on `origin/main` and installed state if kept. Delete this plan's handoff when complete and fold durable conclusions into `plan_typesafe-jev-decision-layer.md`.

**You'll know it worked when:** the repo has either a measured, installed, reversible substitution with live proof, or no new runtime dependency and a reproducible no-go record. No `open` STATUS row remains.

### Adversarial cases — every external input has a test

| External input | Hostile case | Required proof |
|---|---|---|
| Private transcript JSONL | malformed record, duplicate/subagent copy, injected policy text, embedded credential | `tests/test-jev-spend-baseline.sh`: ignore/bucket correctly and emit only aggregate/public-safe fields |
| Public issue/maintenance record or skill roster | private repo, oversized text, prompt injection, edited content, omitted candidate | `tests/test-ai-jev-<target>.sh`: reject before network or abstain; digest/freshness and candidate-coverage checks |
| 1Password reference/API key | missing/empty key or accidental echo | `tests/test-ai-jev-scripts.sh`: nonzero, no key in stdout/stderr/log |
| TypeSafe HTTP result | timeout, 429/500, malformed JSON, extra/missing option, invalid probability, wrong model | `tests/test-ai-jev-scripts.sh`: bounded failure and unchanged baseline path |
| Provider usage/price data | missing cache fields, reused counters, stale price, negative totals | `tests/test-jev-spend-metrics.sh`: refuse savings claim rather than inventing zero |
| Label/holdout files | duplicate cases, changed digest, label leakage, missing negatives | `tests/test-jev-spend-metrics.sh`: fail evaluation and preserve split |

## 10. Tests required

Add the named focused tests in §9. Run `bash tests/test-ai-jev-scripts.sh`, `bash tests/test-ai-jev-<target>.sh`, `bash tests/test-jev-spend-baseline.sh`, and `bash tests/test-jev-spend-metrics.sh`. Run the existing test named by the selected caller's `docs/task-router.md` row. Before full local tests check `bin/ai-test-local --check-collision`; then run the required suite for the declared class. Reviewer-safety work also needs the repository's exact-head independent review. A prose-only planning PR needs Markdown link/reachability validation and no runtime test.

## 11. Constraints and gotchas

Use `bin/ai-gh` for GitHub, current-upstream isolated worktrees, task-class gates, explicit staging, and the repo's PR/merge-queue policy. Do not post raw private transcript or licensed data to TypeSafe; prior transcript submission authority does not automatically apply to a new experiment. Preserve deterministic gates and all reviewer evidence. Keep requests bounded in size, time, count, and rate; fail back to the existing caller. No database or production changes are authorized. This is a public repository; never commit sample private text, credentials, request bodies, or generated logs. Source-grounded reviews remain generative. The 10% criterion is an experiment acceptance rule, not a vendor performance claim.

## 12. Access and environment

Planning machine: `edge-dev3`, Linux; implementation may run on another managed host after checking its actual install. The private local archive path appears in §5. `bin/ai-gh` is the authenticated GitHub route; verify `popcre/ai-devops` visibility immediately before any public-record Jev call. Jev access uses 1Password vault `vibe_coding`, item `typesafe.ai API`, resolved through `op run` at execution time. `GET /v1/models` determines the available exact pin; consult [live API docs](https://docs.typesafe.ai/api) and [TypeSafe agent skill](https://docs.typesafe.ai/agent-skill) before coding. Use the repository's `bin/ai-jev-probe` for bounded connectivity, never print a key. No test login or web server applies.

## 13. Definition of done, risks, and open questions

Done means all STATUS rows have evidence-backed KEEP, RETIRE, or justified N/A; the selected use has a recomputable baseline and holdout; tests pass; the changes are committed, pushed, PR-merged, and verified on `origin/main`; an adopted caller has installed exact-commit live proof; docs and issue #643 reflect the outcome; the open handoff is retired. If code lands without one live proof, that session opens exactly one phase-specific proof issue before ending. Roll back by disabling/removing the additive caller and reinstalling the prior verified commit; the existing route remains available.

Risks: Jev may make confident semantic errors, the vendor/model may change, private text may leak if eligibility fails, the fallback may erase savings, and instrumentation may misprice cache usage. Tests, exact model pinning, public allowlist, holdout labels, paired measurement, and fail-safe fallback address these. Open question: **does any qualifying repeat call exist?** Step 9.1 answers from actual counters and caller inspection; if no, record no-go rather than adding Jev.

## Mandatory self-audit — final answers

1. **Can a fresh session execute without this chat? Yes.** §§1–6 supply purpose, repository, source state, and prior failures; §§8–12 give a deterministic target-selection rule, exact candidate files, ordered steps, gates, and access; §13 resolves no-go and rollback.
2. **Are background and rejected approaches carried forward? Yes.** §§3, 5–7 distinguish transcript mentions from paid calls, human sorting from token savings, and the failed compaction/completion trials. §9 requires a new measured baseline before code adoption.
3. **Can an implementer handle a wrong step without losing the goal? Yes.** §1 defines net token/cost reduction with unchanged assurance; §§8–9 demand measured displacement or retirement; §13 defines recovery.

All 13 sections, explicit out-of-scope boundary, locked/open decisions, named tests, adversarial cases, plan/handoff links, delivery proof, and access/secret constraints pass the implementation-plan-writer checklist.
