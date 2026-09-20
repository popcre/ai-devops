# IMPLEMENTATION PLAN — efficient AI DevOps delivery (2026-09-20)

## STATUS — read first

Roadmap owner: [issue #650](https://github.com/popcre/ai-devops/issues/650), initially Codex chat `01a0bf5b-95b4-7363-8ee6-1322f3b81465` on `916-alien`. This is a planning deliverable, **not authorization to execute every row in one session**. The planning task is complete when these documents land; implementation remains open. No runtime repair is claimed by publication.

Fresh session: read sections 1, 8, 11, then claim **one** row in section 9. Default first implementation is P1 under existing #633, after its short overlap/baseline check. Do not make a measurement platform a prerequisite. Re-read downstream phases before each phase; use `fresh-session` at natural cut points. Verify live state before treating the dated baseline as current.

| Step | One independently accepted outcome | State, 2026-09-20 | Dependency / owner at dispatch | Evidence required for done |
|---|---|---|---|---|
| P0 | Reproducible delivery baseline and reconciled scope | open | Each implementer refreshes its own slice; #650 coordinates | Dated baseline and exact live source/run identities |
| P1 | Gemini inventory is fast and byte-equivalent | open | Reuse #633; named implementation session claims before edits | Parity tests, large-tree timing, installed Gemini proof |
| P2 | Other inventory consumers use the proven primitive | open | P1; one consumer outcome/session under #633 | Per-consumer tests and installed proof; no blanket completion |
| P3 | A known fast-validation failure stops expensive CI | open | P0 slice; independent of P1 | Negative live run plus repaired run and aggregate results |
| P4 | Dependency selector correctly predicts affected tests | open | P0 slice; shadow only | Complete-inventory checks and dependency/hostile-path fixtures |
| P5 | PR checks use the proven selector on both platforms | open | P3 + P4 | Representative narrowed PRs, injected dependency failure, complete backstop |
| P6 | Reviewer suites run independently without losing coverage | open | P3; serialize overlap with P5 | Full suite union, failure aggregation, before/after timing |
| P7 | Transient health timeouts no longer masquerade as bad reviewers | open | Reconcile #622 and #637; separate issues/outcomes | Timeout/identity tests and one scoped installed live proof |
| P8 | One consistent, proportionate delivery procedure is installed | open | P0 slice; coordinate #335 | Cross-client instruction checks and scoped installed task exercise |
| P9 | Reusable evidence is consumed safely by existing delivery tools | open | P5 + P8; design checkpoint before writes | Identity invalidation tests and one live reuse/refusal proof |
| P10 | End-to-end delivery improvement is measured and accepted | open | Earlier applicable rows accepted | Comparable samples, safety evidence, residual-owner list |

Current implementation owner for unclaimed rows: #650 roadmap owner, **not an active worker**. Transfer a row explicitly before work; do not infer that someone is monitoring it. Reuse existing owner issues where listed; create a scoped child only when dispatching genuinely new work. No blanket dependency chain across independent rows. Any landed-but-unproved row must name exactly one proof issue opened by the landing session, with a named owner.

Discovery handoff: [planning-session handoff](HANDOFF.d/2026-09-20T1515Z-916-codex-workflow-efficiency.md). Evidence: [September 20 baseline](tests/verification/repo-throughput/2026-09-20-workflow-efficiency-baseline.md). Historical completed work: [throughput restructure](plan_repo-throughput-restructure.md), [September 17 audit](docs/ci-speed-audit-2026-09-17.md). This plan is the current efficiency roadmap, not a reopening of that completed programme.

## 1. Ultimate goal — what we are trying to achieve

Albert should be able to request a bounded toolkit change and receive a working, verified result in the same working session when the change itself is small. Time should go into useful implementation and relevant proof, not hours of preparation, repeated full tests, cancelled checks, conflicting instructions, or reconstructing ownership.

Make safe work cheaper: preserve the ability to detect wrong-source approvals, unintended file changes, secret exposure and installation failures while eliminating redundant execution. Measure the whole request-to-working-result path, not just a faster green badge. Do not declare success by raising timeouts, deleting assertions, hiding failures, or moving failures into an unattended weekly job.

If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

AI DevOps is Albert's public recovery toolkit for multi-model AI work. Bash tools in `bin/`, PowerShell installers, shared helpers, configuration, skills and instructions support Claude, Codex and other configured clients. GitHub Actions runs offline verification; installing the toolkit is its deployment mechanism. There is no product web UI or application server to deploy.

Current clone origin is `https://github.com/u2giants/ai-devops.git`; GitHub API/web responses redirect to `popcre/ai-devops`. Both identities have explicit feature-branch/PR entries in `config/repository-policy.json`. Resolve the actual origin in every session; never infer branch policy from organization name. Base is upstream `main`, with an isolated `codex/…` or equivalent task branch/worktree. Windows uses PowerShell 7 plus Git Bash; Linux uses Bash. Planning host was `916-alien`, canonical clone `D:\repos\ai-devops`. Canonical checkouts remain landing-only.

## 3. What triggered this work

Albert reported changes taking days or weeks, including a run interrupted repeatedly over 12 hours. The audit inspected current source and 100 recent Verify runs beginning September 18. It did not locate that exact 12-hour run and does not claim the longest sampled run explains the whole report.

At audit time: 66 successes, 20 cancellations, 12 failures, two incomplete. Successful PR elapsed median was about 35 minutes, p90 58; successful merge-group elapsed median about seven minutes, p90 15. These measures use creation-to-update time, include wait/retry gaps, and are not CPU time. The longest sampled run was two hours. See the baseline for exact run identities and method.

[#633](https://github.com/popcre/ai-devops/issues/633) records a separate September 18 loaded-Windows incident: 30,384 files, more than 0.6 seconds process startup per file, five-plus hours per inventory pass. Current Gemini code confirms the per-file process pattern. This historical measurement was not rerun during planning. Reproduce safely on a generated fixture with a bounded deadline, never by launching an uncontrolled five-hour production review.

## 4. Scope — in and out

In scope: inventory implementation, relevant timeout diagnosis, affected-test selection, unnecessary repeated assurance, deterministic fast-failure routing, remaining serial reviewer tests, instruction contradictions, proportional planning records, scoped evidence reuse, interrupted-run accounting, and installed acceptance for changed capabilities.

NOT in this plan: changing database structure; production cloud/runner privilege changes; new AI providers, model upgrades or paid accounts; a new queue/monitor/orchestrator; broad machine repair or fleet-wide installation as a prerequisite to one fix; disabling provider containment/qualification; unrestricted Markdown exemptions; rewriting unrelated handoffs; replacing BlockerWatch; reopening completed #159; closing other sessions' issues; solving every unrelated open bug.

The plan covers all audit recommendations, but lower-value speculative optimizations have explicit decision gates. Queue evidence reuse and descriptive-skill exemptions may be rejected with recorded evidence if complexity exceeds demonstrated benefit. That is a disposition, not permission to silently omit them.

## 5. Current state of the code

Source baseline: `fbd567256ac9f173893fb1ebd3cd6da52b26b310`, verified equal to remote main during the audit. Line anchors below refer to this baseline; find by symbol after drift. Installed fleet versions were **not** verified by this planning task.

| Existing component | Verified state / anchor | Consequence |
|---|---|---|
| `bin/ai-gemini:105–131`, `inventory`, `source_inventory` | Hash subprocess per regular file; includes different tracked/artifact record formats | Batch without changing the byte stream or inclusion policy |
| `tools/lib/provider-wrapper-common.sh` | Existing shared provider helper home | Reuse for compatible inventory primitives; no parallel provider framework |
| `tools/lib/task-gates.sh:18–60`, `tg_legacy_classify` | Prose/code routing plus reviewer manifest; non-PR events conservative | Action-risk classification and test selection are different contracts |
| `tests/lib-selection.sh:1–18`, `selection_by_categories` | Coarse categories; other executable changes select all Bash tests | Extend existing selector, retain full default |
| `config/ci-suite-manifest.json` | Owns timing/Windows sections/reviewer exclusions/PowerShell ownership | Extend this manifest instead of a second suite inventory |
| `tests/test-all.sh:85`, `tests/test-all.ps1` | Selection/sharding combinations limited; PowerShell discovery broad | Compose selection, platform and shard filters together |
| `.github/workflows/fast-classifier.yml:64–67` | Classification shares a job with syntax/policy tests | Failure currently conflates unknown routing and decisive rejection |
| `.github/workflows/verify.yml:86,117,219,490` | Broad fallback on classifier failure; four Linux and four Windows sections; hosted reviewer suites serial | Parallelism already exists; change the remaining long poles |
| `tools/ci/verify-closure.sh:23–25` | Failed classifier cannot close green | Running everything after a known policy failure cannot rescue the run |
| `tests/test-workflow-policy.sh:31–45` | Text occurrence/declaration counts constrain workflow layout | Replace incidental counts with behavioral contracts |
| `docs/development.md:76–79,197–204`; `README.md:137–146` | Focused review evidence conflicts with complete-local wording; four review stages described | One authoritative proportional procedure needed |
| `skills/codex/codex-github-ship/SKILL.md:13,22–26` | Broad handoff loading and obsolete organization-wide routing | Resolve repository policy and only matching handoff |
| `bin/ai-review-packet:287,496–500` | Forward-target tolerance and slow-evidence warning already landed | Do not repeat #639 repair |

Live branch rules snapshot: one required `verification-closure` context, zero GitHub approval-count requirement, merge queue with 120-minute response timeout. That does not eliminate the independent reviewer-safety contract. Ordinary PR jobs use hosted runners; do not diagnose today's latency from historical self-hosted queue incidents alone.

## 6. Key findings and root causes

1. A correct guard can have an unusably slow implementation. Repeated file-by-file process startup costs hours before useful reviewing. Do not remove inventory validation to repair hashing.
2. Coarse dependency selection makes a small tool edit buy nearly every tool's tests. Shared helper changes deserve broad coverage; unrelated leaf changes do not.
3. A syntax/policy rejection is terminal, whereas missing classification information is uncertainty. Current CI treats both as a reason to spend more time.
4. Documentation mixes four-stage model workflows, full local shipping tests, focused evidence, and “never verify twice.” Agents can obey one paragraph by violating another.
5. Cancellation of obsolete PR runs is intentional. Repeated intermediate pushes amplify wasted work; turning cancellation off recreates a backlog.
6. A GitHub rerun can list successful jobs copied from an earlier attempt. Use job timestamps and unique execution identity, not repeated list entries, to count reruns.
7. Historical plans declare completion and still instruct new sessions to execute remaining children. Open #622 describes a main-forward race already repaired by #639; open state alone is not unresolved scope.
8. Safety review evidence cannot be cached only by commit SHA: test definition, dependencies, environment, platform, outcome and source identity matter. Advice to “reuse everything” without these conditions is unsafe.

## 7. Approaches considered and REJECTED

- Raise timeouts until runs finish: it converts a broken preparation path into a longer failure and does not improve delivery.
- Delete rarely failing tests: failure frequency is not a measure of the consequence they prevent.
- Disable superseded-run cancellation: obsolete commits consume the capacity needed by the current candidate.
- Treat Linux green as Windows proof: shell, paths, permissions and process behavior differ materially.
- Skip every Markdown change: installed skills and instructions can alter safety/permissions.
- Remove merge queue validation universally: concurrent changes can create a new, untested integration.
- Rebuild Linux sharding, reviewer path filtering, or forward-target tolerance: already present at baseline.
- Add a new global scheduler, monitoring service, evidence database, or universal provider abstraction: existing manifests, helpers and artifacts are sufficient initial homes.
- Make fleet repair, every provider's qualification, or all old issues block one leaf improvement: each affected capability gets its own scoped acceptance and owner.
- Make agents complete this whole roadmap in one session: violates the one-live-outcome rule and creates another weeks-long unfinished programme.

No implementation experiments were performed in the planning task. A Windows `.cmd` invocation split an API URL containing `&`; subsequent reads used Git Bash with quoted URL and redirected output. Do not mistake shell quoting failure for API failure or rerun verbose output into chat.

## 8. Design decisions — 2026-09-20

**Locked:** preserve source/digest/merge-base integrity, private-data boundaries, reviewer containment, production authorization, recoverable destructive operations and genuine shared-runtime collision guards. Keep a stable aggregate check that rejects missing, cancelled and failed required evidence. Full default and scheduled testing remain available. Unknown dependency coverage cannot silently narrow.

**Locked:** one current roadmap (#650), reused existing issue owners, one live outcome/session, one scoped installed proof for each changed capability. This publication changes prose only. No automatic approval of future gate weakening or production actions is implied.

**Locked:** local focused tests are development feedback; PR CI is authoritative relevant platform proof; merge-group validation protects a changed integration. Do not describe different trees as identical commits. Additional review stages need a distinct unresolved risk. Reviewer-safety gets one exact-head independent final review; ordinary prose does not buy a paid reviewer.

**Locked:** implement manifest changes in shadow mode before narrowing PR tests. Global selector/workflow/helper changes get broad coverage. Preserve no-argument full commands and complete scheduled failure reporting. Never remove a suspended-suite status or reactivate a provider merely to improve this plan's numbers.

**Open engineering choices:** batching implementation language after byte-parity and installed-runtime availability checks; exact dependency-group granularity; per-platform shard balance based on timings. Choose the simplest measured improvement, not a speculative framework.

**Conditional choices:** evidence reuse at merge queue and lightweight descriptive-skill treatment require proof of correctness and material saved time. Default is retain current safety behavior if the proof is absent. Record disposition and continue unrelated work.

## 9. Ordered implementation steps

Each step owns its listed files; serialize steps sharing `verify.yml`, the manifest or instruction templates. P1/P2 and CI work can run in parallel in separate worktrees. P3 and P4 can develop independently, but one session reconciles their shared selector/workflow interfaces before P5. No deadline or target authorizes a failing merge.

### P0 — refresh the baseline and assign only the next work

**Targets:** this STATUS table and `tests/verification/repo-throughput/2026-09-20-workflow-efficiency-baseline.md`; future dated evidence stays in the same existing verification directory. Reuse timing output from `tests/test-all.sh`, `tests/test-all.ps1`, and `config/ci-suite-manifest.json`.

**Do:** use `bin/ai-gh` to resolve main, relevant open PRs, #633/#637/#622/#335, and current rules once. Record run ID, event, source/head/tree/base, attempt, created/start/end, outcome, suite/platform, host/load, selected suites, and reason. Separate queue delay, execution, retry gaps, cancellation waste and issue-to-installed time. Exclude incomplete runs from latency percentiles, count them separately, deduplicate copied jobs. Store only public-safe evidence; no raw reviewer conversations.

**Gate:** another session can reproduce the sample statistics and identify which result came from which source. A single run cannot support p90. Reconcile existing work before a new child issue; #650 owner records who takes the next outcome. This takes one bounded read pass and must not block P1 waiting for an unrelated fleet sample.

### P1 — repair Gemini inventory preparation

**Targets:** `bin/ai-gemini` (`inventory`, `source_inventory`, callers); `tools/lib/provider-wrapper-common.sh` only for a reusable compatible primitive; `tests/test-ai-gemini.sh`, `tests/test-provider-wrapper-common.sh`. Coordinate with #637 before concurrent edits to the wrapper.

**Do:** preserve current record formats including tracked/artifact prefixes, ordering, symlink target records, executable metadata/submodule treatment and exclusion rules. Replace per-file subprocess startup with a bounded batched stream or one available runtime process. File content errors, disappeared files, unsupported names and tool failures must return non-zero, never a partial digest that looks complete. Preserve every before/after check; do not substitute timestamps or size for content. Version a digest format only if exact compatibility is impossible and document session re-baselining explicitly before migration.

**Gate:** old/new byte streams and digest match across the adversarial fixtures in section 10; mutation detection remains identical. A generated 30,384-file fixture runs on representative Windows and Linux with recorded size distribution, machine/load, runtime and repetitions. Target: inventory pass <=30 seconds and representative complete preparation <=120 seconds, not merely “no timeout.” If target misses, report measured cause; improve without dropping checks. Record one bounded installed Gemini exercise proving real prepare + unchanged/mutated source behavior, using existing approved qualification. No provider/model upgrade.

**Cut:** one accepted Gemini outcome. Update #633's remaining consumer list; do not mark all wrappers fixed.

### P2 — migrate compatible inventory consumers individually

**Targets:** inventory implementations in `bin/ai-grok-review`, `bin/ai-qwen`, `bin/ai-glm`, `bin/ai-muse`, `bin/ai-deepseek-agent`, and corresponding `tests/test-ai-*.sh`; locate all callers with `rg` before selecting one. Reuse `tools/lib/provider-wrapper-common.sh` where formats match.

**Do:** build a compatibility matrix showing record grammar, inclusion/exclusion rules, symlink/submodule policy, timeout and caller. Do not assume all providers hash the same thing. Migrate one provider per accepted outcome; retain provider-specific adapters if necessary. Validate shared-helper packaging/runtime dependency and hashes so installed wrappers do not point at missing helpers. A currently suspended/unavailable provider is a separate named row with rationale, not a reason to block a working provider or fabricate live proof.

**Gate:** per-provider old/new parity, negative mutation tests, focused wrapper suite and installed proof; record measured savings. One row cannot close on Gemini-only evidence. Preserve unrelated wrapper behavior and resolve affected reviewer incident records with exact evidence through `log-reviewer-issue`.

### P3 — distinguish fast rejection from uncertain selection

**Targets:** `.github/workflows/fast-classifier.yml`, `.github/workflows/verify.yml`, `tools/ci/verify-closure.sh`, `tests/test-workflow-policy.sh`, `tests/test-verify-closure.sh`.

**Do:** split selection outputs from fast validation. A known syntax/policy failure starts no long job and fails final closure. Missing/invalid classification never becomes a green skip: choose conservative coverage or explicit failed closure. Cancellation/missing validation fails closure. Replace exact grep counts of workflow layout with assertions about dependencies, event isolation, permitted runners and required outcomes. Keep existing stable aggregate names, permission boundaries and complete manual/scheduled behavior.

**Gate:** unit truth table covers success/failure/cancelled/skipped/missing for selection, validation and required lanes; a deliberately invalid bounded CI candidate starts no long jobs and fails closure, then its repaired successor passes. Negative and positive runs are proof of this one routing outcome; retain both run IDs. Restore prior conditions via a reverting PR if a required path escapes closure.

### P4 — extend dependency selection in shadow mode

**Targets:** `config/ci-suite-manifest.json`, `tests/lib-selection.sh`, `tools/ci/classify-changes.sh`, `tools/lib/task-gates.sh` (selection interface only), `tests/test-all.sh`, `tests/test-all.ps1`, `tests/test-test-selection.sh`, `tests/test-windows-bash-selection.sh`, `tests/test-reviewer-ci-paths.sh`.

**Do:** extend the existing suite manifest with dependency groups/shared inputs and explicit platform ownership. Separate risk classes from suite dependency closure: a protected action remains protected even when its affected tests are few. Compute a union across both sides of rename/deletion and changed shared dependencies. Include tests themselves, fixtures, runtime configuration and installer integration. Unknown paths, missing mappings, malformed manifests or new unmapped suites cannot silently exclude tests. Preserve default complete execution. Compose changed selection with platform and shard filtering; union of shards must equal the selected inventory exactly once, with no loss of PowerShell tests.

**Shadow gate:** report predicted selection while CI still runs complete currently required coverage. Use at least one isolated leaf-tool change, shared helper, installer/PowerShell change, reviewer change, rename, workflow change and unknown path. Inject a dependency regression that the selected suite catches. Validate mappings against discovered suite inventory. No claim of speedup before activation; no narrowing until this gate passes.

### P5 — activate selection with observable backstops

**Targets:** P4 entrypoints plus `verify.yml`, `tools/ci/verify-closure.sh`, `tests/test-verify-closure.sh`, `docs/development.md`. Dependencies P3 and P4.

**Do:** enable the proven selection for PRs only first. Keep full merge-group Linux proof initially and complete weekly/manual backstops; do not couple initial savings to a queue-cache redesign. Aggregate jobs require every selected suite and explicitly justified empty sets. Publish selection reason and per-suite outcome/timing using existing logs/artifacts. Extend timing output only where needed, with interruption markers and unique shard files; upload available records under an always-run condition. An interrupted suite is not passed. Scheduled failure remains non-zero, produces its existing alert, has a named issue owner, and is resolved only by repair plus a complete successful run. A suspected selector omission triggers conservative selection for the affected group until mapped and proved.

**Gate:** a representative leaf PR omits only unrelated tests, a shared-helper PR includes dependents, PowerShell coverage remains, and an intentionally failed selected suite blocks closure. Existing full command still discovers the full eligible inventory. Capture at least one complete backstop result for the landed selector before acceptance; a bounded manual full run can supply initial proof instead of waiting a week. Target ordinary scoped PR p90 <=15 minutes on the comparison workload, with no omitted required regressions.

### P6 — split the serial reviewer lane, then profile remaining long poles

**Targets:** `verify.yml`, manifest `windows_reviewer_safety_bash`, `tests/test-workflow-policy.sh`, `tests/test-windows-bash-selection.sh`; `tools/ci/stop-process-tree.ps1` only if changed execution requires it. Do not change preferred-host deployment permissions.

**Do:** run independent Codex/Grok suites as separate hosted jobs with a stable `windows-reviewer-safety` aggregate. Retain all assertions and existing reviewer path conservatism initially. Preferred/manual/fallback behavior must not run duplicate active process trees: fallback is per unproved suite after preferred termination is established. Time limits remain bounded and failures visible. Preserve same-host/shared-runtime exclusion; hosted jobs on different machines may run concurrently. Then use per-suite timing to remove repeated fixture/process setup only where output/negative tests remain equivalent; a separate slow-test repair is a new bounded outcome.

**Gate:** selected suite union unchanged; one failed/missing/cancelled suite blocks reviewer aggregate; ordinary PRs do not acquire self-hosted waiting; same-source live before/after wall and machine-minutes show improvement. Target wall time near max(individual suites), not their sum, without hiding increased resource cost. Do not treat full concurrency on one loaded desktop as independent capacity.

### P7 — correct timeout diagnosis without disabling qualification

**Targets:** residual #637 paths in `bin/ai-gemini` and `tests/test-ai-gemini.sh`; separately inspect `bin/ai-review-preflight:277–284,394–403`, `bin/ai-review-lifecycle:250–255`, `tools/reviewer_admission.py`, `tests/test-ai-review-preflight.sh`, `tests/test-ai-review-lifecycle.sh` for #622's health-timeout claim. The current ordinary doctor has a 10-second default; empty timeout output falls through to `provider-unhealthy` and global quarantine. Preserve lifecycle terminal recording and owned-lock release. Read current functions and incident reasons before changes.

**Do:** first reconcile #637 and #622 live. Main-forward tolerance/adversarial planning/slow-evidence warning are already landed; do not implement them again. Bound the *first* runtime/packet probe and every relevant call path, not just a later duplicate. Distinguish timeout exit status from identity drift and other failures; never label every failure “timed out.” A transient liveness timeout gets a named bounded retry/cooldown outcome distinct from invalid identity, missing authentication or containment failure. Timeout never means provider healthy and never authorizes a governed review to proceed. Preserve quarantine for demonstrated safety/identity problems; choose timeout budgets from observed successful probes, with hard caps.

**Gate:** hanging first probe terminates and leaves no child process; exits 124/137, empty/malformed output and false success text retain their actual cause; drift is reported as drift; auth/identity/containment failures still refuse; transient timeout follows a bounded documented path and cannot produce an approval or invented account exhaustion. One installed probe/review lifecycle proves the selected repair. #637 and preflight changes are separate session outcomes even though this roadmap groups their rationale.

### P8 — install one proportionate operating procedure

**Targets:** `README.md`, `docs/development.md`, `docs/task-router.md`, completed STATUS sections in `plan_repo-throughput-restructure.md` and `plan_reviewer-reliability-and-efficiency.md`; `skills/codex/codex-github-ship/SKILL.md`; matching shared ship/plan/handoff skills and `templates/system/implementation-plan-standard.md`, `templates/system/handoff-standard.md`, client globals only if their current wording conflicts. Preserve Codex/Claude/ZCode parity where affected. Coordinate existing #335 work; do not inherit its unrelated fleet/Ansible scope.

**Do:** state one development-to-delivery contract: focused local checks; relevant authoritative CI; one required combined independent final review for reviewer-safety; extra reviews only for named unresolved risks; no repeated full evidence command inside a review packet. Resolve repository policy through existing `ai-repo-policy`, not organization-name heuristics. Keep only task-matching handoff reads. Batch completed corrections before a push, then freeze a candidate while it is checked. Retain obsolete-PR cancellation and bounded event-aware waiters. A stall beyond the existing deadline requires diagnosis/owned blocker, never silent “still working.”

For ordinary bounded changes, use one issue for objective/scope/acceptance/evidence; detailed plans are for multi-session complexity and handoffs for actual transfer. This plan currently creates the required handoff because the existing standard requires it; changing that standard is P8, not a retroactive exemption. Keep historical decisions, but mark superseded execution instructions historical. Do not add a new general-purpose status index. Consider a descriptive-skill fast path only for mechanically distinguishable metadata/link changes; examples and instructions can alter behavior, so uncertain semantic edits keep existing gates.

**Gate:** `tests/test-client-globals-required-phrases.sh`, `tests/test-ai-task-gates.sh`, `tests/test-ai-adopt-globals.sh`, relevant skill-trigger/context checks and Markdown checks pass for touched surfaces; scenario walkthroughs yield consistent routes for prose, leaf code, installed instruction changes and reviewer-safety. Classify installed-rule changes appropriately and obtain their required independent review. Narrow installation uses existing documented installers/backups; exercise the affected client on the claimed host, recording installed source hashes. Additional clients/hosts are separately owned proofs, not silently claimed. No runtime policy change is delivered by editing docs alone.

### P9 — reuse valid evidence through existing tools, without a new orchestrator

**Targets:** `bin/ai-task-gates` (required-proof output), existing `bin/ai-review`/`bin/ai-review-packet` lifecycle evidence interfaces, `tools/reviewer_events.py` (`require_report`, `publish_report`, `verify_reports`, `bind_sandbox`, `verify_sandbox`), `bin/ai-review-preflight:405–417`, `bin/ai-test-local`, `bin/ai-pr-wait`, `tools/ci/verify-closure.sh`, `config/task-gates.json`, their focused tests and `docs/development.md`. First audit the existing evidence format/callers and reuse them; do not create a parallel approval store or another top-level command.

**Do:** make the action preflight explain which tests/review/proofs are required, already satisfied and invalidated. Consume successful evidence only when source/tree/base relation, dependency set, platform/runtime, test definition/configuration and outcome match the required contract. Missing, stale, failed or cancelled evidence never counts. Self-reported classifier output is not proof execution happened. Preserve independent evidence provenance and approval scope; task-class declarations cannot manufacture approvals.

Begin with eliminating duplicate local/evidence runs using existing CI references. Preflight currently prepares a sandbox packet before wrappers prepare theirs: measure this separately, then optionally retain an immutable artifact for the same lifecycle owner/tag only, with complete source/runtime/base identity and fresh verification at consumption. Sandbox Git-tree/diff/untracked identity and Gemini all-files inventory are not interchangeable. This is a separate accepted live outcome from hashing. Evaluate queue reuse only after measured savings justify its complexity: equivalent tested tree and integration base must be established; otherwise keep the full queue lane. Because baseline queue median is seven minutes, this is lower priority than P1/P5. A documented decision to retain queue execution is valid if reuse adds more complexity/risk than savings. Likewise keep a conservative skill route unless exact lightweight treatment is proved.

**Gate:** identity/definition/runtime/platform/base changes each invalidate reuse in named tests; unchanged qualified evidence can be referenced without rerun; no uncontrolled local file can forge authoritative CI/reviewer proof. One scoped live reuse and rejection sequence proves the implemented capability. Prefer a small extension; split distinct live outcomes rather than build a delivery framework.

### P10 — final acceptance and retirement

**Targets:** this plan STATUS and current-state sections, evidence in `tests/verification/repo-throughput/`, #650, and this plan's own discovery handoff.

**Do:** compare at least 20 completed comparable ordinary changes when available, stratified by leaf/reviewer/install/docs and platform, against the dated baseline. Do not wait indefinitely for natural volume: use existing history plus bounded representative authorized PR exercises; mark small samples provisional rather than manufacture p90. Report PR elapsed, preparation, queue, retries, cancelled machine-minutes, total machine-minutes, and request/claim-to-installed acceptance. Record workload and hardware differences.

**Gate:** inventory targets P1 met; ordinary scoped PR p90 <=15 minutes on the qualified workload or an explicit measured remaining bottleneck with owner; no repeated invalidation of unchanged review input; no default four-review/full-local duplicate obligations; relevant regression/negative tests still fail when seeded; complete backstop succeeds; every changed installed capability has proof. Do not declare the entire programme done while a required target or proof remains open. Conditional optimizations have evidence-backed dispositions. Roadmap owner closes #650 only when all required rows accepted, deletes the now-finished handoff preserving unique decisions here, and retains this plan as an explicitly completed decision record. Nobody closes another session's issue without the owning workflow's transfer.

## 10. Tests required and adversarial cases

Run targeted suites for the step first, using Git Bash on Windows: `bash tests/test-ai-gemini.sh`, `bash tests/test-provider-wrapper-common.sh`, `bash tests/test-test-selection.sh`, `bash tests/test-windows-bash-selection.sh`, `bash tests/test-reviewer-ci-paths.sh`, `bash tests/test-workflow-policy.sh`, `bash tests/test-verify-closure.sh`, `bash tests/test-ai-review-preflight.sh`, `bash tests/test-ai-review-lifecycle.sh`, `bash tests/test-ai-task-gates.sh`, `bash tests/test-ai-test-local.sh` as affected. `bash tests/test-all.sh --list` inventories the full suite; `--changed-since <base>` is currently coarse and must not be mistaken for P4's future dependency selection. PowerShell parity uses `pwsh -NoProfile -File tests/test-all.ps1` under the appropriate collision/CI boundary. No full local run overlaps a GitHub job using the same host/runtime. Full authoritative checks remain required until the corresponding selector/policy change lands.

The case identifiers below are **proposed test names**, not claims that those tests exist. Add them to the listed existing suites; extend fixtures there instead of creating another harness. Read each input literally as data, never interpolate paths into shell code.

| External input / trust boundary | Hostile or edge case | Required named regression and home |
|---|---|---|
| File inventory names | Spaces, tabs, newline, leading dash, Unicode, CRLF-like bytes | `inventory_weird_names_byte_parity` — `test-ai-gemini.sh` / shared helper suite |
| File inventory content | Empty file, binary bytes, unreadable/disappearing file, mutation during pass | `inventory_failure_never_emits_success_digest`, `inventory_mutation_detected` — same |
| Links and repository metadata | Broken/special symlink, target outside snapshot, executable mode, submodule entry | `inventory_link_mode_submodule_parity` — same; retain current inclusion policy |
| Large source tree | 30,384 generated files; slow spawn; interrupted child | `inventory_large_tree_bounded`, `inventory_cancel_reaps_children` — same plus dated benchmark |
| Changed-path input | Rename/delete crossing groups, newline/leading dash/CRLF, malformed ref | `selection_rename_delete_union`, `selection_paths_are_data` — `test-test-selection.sh` |
| Dependency manifest | Missing/malformed mapping, new suite, dependency cycle, shared helper | `selection_unknown_is_conservative`, `selection_transitive_closure`, `selection_cycle_refuses` — same |
| Shard/platform filter | Duplicate membership, empty selection, PowerShell-only integration | `selection_shard_union_exact`, `selection_no_unproved_empty`, `selection_powershell_integration` — Windows/selection suites |
| GitHub job outputs | Missing, failed, skipped, cancelled or forged selection/validation result | `closure_fast_failure_blocks`, `closure_unknown_selection_not_green`, `closure_missing_required_fails` — `test-verify-closure.sh` |
| Event identity | Two PRs, PR vs queue/manual, superseded head | `workflow_concurrency_isolation`, `workflow_cancelled_proof_rejected` — workflow/closure suites |
| Preferred process/fallback | Timeout with surviving descendant, one passed suite and one missing | `reviewer_fallback_requires_termination`, `reviewer_aggregate_requires_union` — workflow/Windows suites |
| Runtime health | Hung first version/resolve call, auth absent, wrong identity, transient timeout | `probe_first_call_bounded`, `probe_timeout_not_identity_failure`, `probe_timeout_never_approves` — Gemini/preflight/lifecycle suites |
| Evidence identity | Same SHA with changed test/config/runtime/platform; advanced/replaced base; failed artifact | `evidence_context_change_invalidates`, `evidence_untrusted_result_refuses`, `evidence_unchanged_reuses` — affected task-gate/review/closure suites |
| Timing artifacts | Partial record, cancelled before first suite, duplicate job attempt, shard collision | `timing_incomplete_not_success`, `timing_copied_jobs_deduplicated`, `timing_shards_isolated` — selector/timing or runner suites |
| Instruction route | Descriptive Markdown vs installed permission/routing change | `instruction_safety_edit_not_prose`, `ship_uses_repository_policy` — task-gate/skill checks |

A fixture failing on the old code and passing on the new code is stronger proof than assertions mirroring implementation. Performance tests use measured envelopes and explicit loaded-host conditions, not brittle idle-machine ceilings. Ensure seeded dangerous behavior still fails; a green test achieved by weakening its expectation is not acceptance.

## 11. Constraints, standing rules and gotchas

- Read `AGENTS.md`, matching router and affected tool verification header. Declare task class at start; recheck before review, shipping, installation or stronger action. Actual touched paths determine effective class; this prose plan does not predeclare future changes harmless.
- Work in current-upstream isolated worktrees; verify branch before commits, stage owned paths, check `git var GIT_COMMITTER_IDENT` for `Albert Hazan <u2giants@users.noreply.github.com>`. No direct protected-main push. Use PR/queue and bounded waiter for code. Documentation-only publication uses Albert's explicit prose merge exception after verifying every file is prose.
- All GitHub calls use `bin/ai-gh`; no watch loops. `bin/ai-pr-wait`/`bin/ai-gh-wait` own bounded waits. A real cross-issue blocker uses BlockerWatch with exact blocker/work issue and a named owner. No new poller in this plan.
- For independent reviews, self-audit the whole risk class first, use read-only exact-head evidence and preserve provider restrictions. No paid review is required for this planning-only diff.
- Installation follows `docs/deployment.md`, with backups and exact host/resource scope, preserving machine overlays. A canonical clone can back installed tools: never casually rewrite it during another task's use. Do not run broad setup merely to install one affected command/skill.
- Shared database structure and production cloud actions remain outside this plan. Never infer permission from an efficiency goal. No credentials are needed for offline tests; any later secret comes through approved 1Password `vibe_coding` references, never files/chat/output.
- Keep public evidence scrubbed. Raw transcripts, licensed data, reviewer conversations and private runtime state remain private. Generated benchmark trees contain synthetic content only.
- A planned repair is not a delivered capability; a merged repair is not installed proof. Each landing session supplies its proof or exactly one owned proof issue before ending. Re-read STATUS instead of replaying historical imperatives.
- New helper/runtime dependencies must be available on supported installations or installed through existing mechanisms. Never replace operating-system binaries. Avoid unreviewed caches that let a reviewer mutate source between checks.

## 12. Access and environment

Planning used authenticated `ai-gh` successfully for this repository's runs, issues, PR list and rulesets. Git fetch/push uses the existing authenticated origin; resolve identity fresh. No broader permission is needed for plan publication. Git Bash executable on this Windows host is `C:\Program Files\Git\bin\bash.exe`; use it for Bash tests and complex quoted API URLs. Native shell is PowerShell 7.

Initial planning worktree: `C:\Users\ahazan2\.codex\worktrees\workflow-efficiency-plan\ai-devops`, branch `codex/workflow-efficiency-plan`. Future sessions create their own current-upstream worktree; this path is provenance, not a required runtime dependency. Current plan/evidence live in GitHub main after publication. Client/runtime/provider availability and fleet install status must be checked live; do not assume all listed machines/providers are usable. Offline plan checks need no login or secret. No application test account, browser UI or production endpoint applies.

Before live provider work load its installed skill, inspect current qualification and use approved existing access. If a credential is missing, report the exact approved item reference required without exposing a value; this plan creates no credential or paid service dependency.

## 13. Definition of done, risks and open questions

**Plan-publication done:** all 13 sections, self-audit, reciprocal own handoff, reachable router/topic links, public evidence baseline, clean prose diff, correct identity, commit/push/PR/merge and origin-main ancestry verification. No implementation state is marked done by that merge.

**Per-row implementation done:** named owner + scoped issue; relevant negative/positive tests; required independent review; shipped commit and CI/queue evidence; installed proof where applicable; measured timing/cost; refreshed STATUS/current state; no unowned leftover proof. Preserve exact artifacts rather than writing an unsupported count.

**Programme done:** P10 acceptance, all required rows accepted or explicitly superseded by verified existing work, conditional decisions recorded, #650 closed by its owner/successor and handoff retired. A target miss remains open with measured cause; nobody quietly relaxes the target to mark green.

| Risk / uncertainty | Decision criteria and recovery |
|---|---|
| Hash implementation changes semantics | Old/new stream parity and hostile fixtures first; revert the specific wrapper/helper change and restore verified installed version if proof fails |
| Selector misses a dependency | Full/shadow comparison and seeded regression; turn affected group conservative through reviewed configuration, repair map and rerun full backstop |
| Parallel tests fight over shared state | Independent machines or existing shared-runtime lock; restore serialized affected lane, not remove its tests |
| Evidence reuse hides changed inputs | Complete identity/provenance key; default to rerun/refusal; revert reuse extension without disabling checks |
| Local instruction installation drifts | Narrow backup/install/hash proof; restore affected settings from backup; do not overwrite unrelated overlays |
| Reported 12-hour event remains unidentified | If evidence is supplied, classify preparation/execution/queue/interruption independently; do not block demonstrated fixes or claim it was disproved |
| Baseline success sample is selection-biased | Report failures/cancellations and all attempt cost alongside successful-run percentiles; compare workload classes |
| More CI parallelism costs more | Record machine-minutes and wall time; prefer removed duplication before purchased capacity; new spending needs owner authority |
| Conditional queue/skill optimization too complex | Retain proven conservative behavior and record evidence-backed disposition; no blanket bypass |
| Existing issue has another active owner | Coordinate scope/transfer before touching its files; no parallel competing repair; use existing work rather than duplicate it |

No owner design decision is required to start the recommended P1 implementation once separately dispatched. Future production actions, expanded paid capacity or unavailable credentials remain outside this plan's authorization. Defaults and criteria above resolve ordinary engineering choices without asking Albert to choose implementation details.

## Mandatory self-audit — passed

1. **Could a new session execute without the planning chat? Yes.** Sections 1–6 define the toolkit, goal, measured baseline, source anchors and corrected historical scope; STATUS and section 9 identify the next bounded owner/outcome, files, dependencies and acceptance. Sections 10–12 supply hostile inputs, commands, access and execution rules. Unknown current facts have explicit refresh steps rather than guessed values.
2. **Does it carry relevant reasoning and rejected paths? Yes.** Sections 3, 6–8 preserve measured versus historical claims, cancellation/retry interpretation, completed fixes, rejected guard removal and default decisions. Section 13 names uncertainties and rollback. The initial temptation to introduce a new suite map was corrected to the existing manifest; the plan does not duplicate the already-landed packet repair.
3. **Is the goal strong enough to resolve a wrong step? Yes.** Section 1 prioritizes reliable working results and bans cosmetic speedups; sections 8–10 bind optimizations to equivalent protection and measured outcomes. Sections 9/P10 and 13 prohibit claiming completion from publication, merged code alone, omitted failures or missed targets.

All checklist dimensions are covered: 13 sections; goal-wins clause; concrete steps/gates; adversarial tests; locked/open decisions; exclusions; rejected approaches; access without secrets; commit/CI/install proof; reciprocal handoff. No memory update was made: the user requested a plan, not modification of protected memory. Repository discovery links provide the durable entry point.
