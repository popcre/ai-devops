---
issue: 2551
status: OPEN
owner: codex/01a1eb74-cache-fleet-continuation
summary: Continue measured caching, persistent sessions and token efficiency across three confirmed reviewer machines without changing defaults
kind: handoff
read-when: implementing the three-machine token-efficiency continuation requested during the November 17 wrap-up
---

## 0. Business decisions only the owner can make

**None — no business decision is pending.** Albert confirmed the exact targets
in this chat during wrap-up: **“edge-dev3, edge-dev, and hetz”**. Use edge-dev3
(Ubuntu), edge-dev (Windows) and hetz (Ubuntu). The previous repair's installed
proof covers the first two; hetz still needs its own baseline, supported
installation and live acceptance. Do not ask Albert to reconfirm the host set,
silently substitute another computer or expand to four. The
[deployment guide](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md)
also identifies these reviewer hosts. Confirmation of target scope does not
change the existing default hold or authorize production application changes.

Already settled on November 17; do not ask again:

- Albert requested: “Fix the cache reporting defect and update #2531’s plan
  with your recommendations for reducing token usage. Keep defaults unchanged.”
  That repair and plan amendment are complete, not a pending implementation task.
- His next instruction was to run the changes and whole plan by Muse. Both
  review rounds completed with APPROVE; their concrete findings were fixed.
- During wrap-up he requested “a prompt to have a new session implement the
  cache, session persistence, and other token-saving strategies on all 3 machines”.
  This authorizes the successor's implementation work. It does not revoke the
  unchanged-default instruction or authorize a different reviewer rotation.
- AI performs access, credentials, installation and verification. No technical
  approval, manual credential entry or setup task belongs to Albert. AI review
  is advisory. Only a genuine unresolved business scope question is his.

Sweep of sections 1–9: the only scope question was the third-machine identity;
Albert answered it. Retention, billing completeness, test design, source custody
and deployment mechanics are implementation constraints, not permission requests.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is the public toolkit
for restoring and operating Albert's AI coding/reviewer workflow on Ubuntu and
Windows. It is not a hosted application or shared database. Installation is
its deployment mechanism. Read the current
[operating guide](https://github.com/popcre/ai-devops/blob/main/AGENTS.md)
and then only matching entries in the
[document index](https://github.com/popcre/ai-devops/blob/main/docs/INDEX.md)
and [task router](https://github.com/popcre/ai-devops/blob/main/docs/task-router.md).

The [parent #2531](https://github.com/popcre/ai-devops/issues/2531) coordinates
four candidate routes for advisory GitHub review and read-only second opinions:
DeepSeek Harness through OpenRouter, OpenCode Muse through Meta direct,
OpenCode Muse through OpenRouter, and OpenCode Hy4 through OpenRouter.
[Caching #2551](https://github.com/popcre/ai-devops/issues/2551) is the existing
implementation workstream for the savings work. Reuse both; no new tracker,
parallel cache service, provider roster or replacement implementation plan.

## 2. What this session set out to do and what is deferred

This session analyzed caching and persistence, fixed truthful cache reporting,
expanded the existing plan with ordered token-saving experiments, obtained
Muse's assessment of the whole plan and code, addressed its concrete findings,
and installed/verified the repairs on the two named machines above.

The successor implements and measures the remaining strategies on all three
confirmed targets. During this wrap-up **no new runtime implementation, cache
activation, compaction, retention, model change, session migration or third-host
installation was started**. Scope freeze defers that work to the new session.
The [existing plan](https://github.com/popcre/ai-devops/blob/main/plan_deepseek-harness-openrouter.md)
remains the build specification; read its STATUS and all downstream phases,
especially section 9 steps 6, 6a and 6b, before editing.

## 3. Current state and evidence

The completed repair and documentation landed through the protected queue:

- [#2600](https://github.com/popcre/ai-devops/pull/2600): missing/invalid cache
  counters stay unknown, genuine zero remains zero, reads/writes aggregate
  independently, and the existing receipt shape is preserved.
- [#2601](https://github.com/popcre/ai-devops/pull/2601): address Muse's findings.
  Missing DeepSeek runtime and timeout now return the same four-field result
  contract as other outcomes rather than crashing the caller. The non-Muse
  cache test now inspects the actual harness profile instead of an empty dict.
- [#2602](https://github.com/popcre/ai-devops/pull/2602): record both installed
  proofs and mark only step 6a complete. Source was verified on main at
  [78e645f3](https://github.com/popcre/ai-devops/commit/78e645f350ac4bd8b4b927c58ff62e633b172426).

The [signed acceptance receipt](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6962732060)
is decisive: **94 focused checks on each OS** (56 route plus 38 legacy checks),
normal Ubuntu and Windows installations completed at
[7dffdd48](https://github.com/popcre/ai-devops/commit/7dffdd4845729eac1a29463a60093b94cf134832),
and installed smoke on both produced unknown/unknown for absent counters,
zero/zero for genuine zero, and 23/unknown when only read=23 was reported.
The normalized tool SHA-256 on both was
`c4658a5e56e26febeb5016be850656ee512606f85fd3cbcd49ff7f99cdc51282`.
The tested and landed runtime source tree was
`6614581e71e87ec2530eba443614cd37bdb85753`; tests were not repeated merely for
the later documentation-only acceptance commit. Muse reviewed the complete
amended plan and changes, then the follow-up corrections: APPROVE both times.

Relevant implemented source, not instructions to reimplement it:

- [Review driver](https://github.com/popcre/ai-devops/blob/main/bin/ai-review-simple):
  `cache_receipts`, `run_once`, `run_harness_once`, `review`, `build_prompt`.
  Counters are **observed subtotals** when coverage is incomplete; never infer
  whole-run billing or free failed calls from them.
- [Shared route adapter](https://github.com/popcre/ai-devops/blob/main/tools/reviewer_routes.py):
  `cache_enabled`, `cache_scope`, `cache_session_id`, `cache_fields` and provider
  configuration. Cache identifiers remain Muse-only and opt-in. Hy4 can have
  provider-side automatic caching without these identifiers. DeepSeek cache
  accounting is still unavailable through the current review receipt path.
- [Session wrapper](https://github.com/popcre/ai-devops/blob/main/bin/ai-second-opinion):
  native same-route resume, stored runtime session IDs, per-session lock and
  same-model Muse failover using sanitized visible turns. Do not rebuild these
  capabilities or convert existing legacy conversations in bulk.
- [Route registry](https://github.com/popcre/ai-devops/blob/main/config/reviewer-routes.json),
  [prompt template](https://github.com/popcre/ai-devops/blob/main/templates/review-prompt-simple.md),
  [GitHub workflow](https://github.com/popcre/ai-devops/blob/main/.github/workflows/ai-review.yml),
  [route regressions](https://github.com/popcre/ai-devops/blob/main/tests/test_reviewer_routes.py).

The [later model/platform re-check](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6955989936)
proves all four routes recalled a marker across two fresh-process restarts on
Ubuntu and Windows, plus a Windows idle interval and same-model Muse failover.
It does **not** prove growing-session billing savings or third-host acceptance.
The [five-distinct-PR baseline](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964)
showed about 9% request-cost reduction, roughly $0.06 per 1,000 sampled calls,
and no average speed improvement. Its output lengths and verdict validity
varied. The historical 24k/9k first-input comparison used different harness
setups with uncontrolled effort; it is not a forecast of achievable savings.

Still unimplemented/unaccepted: complete request/turn billing and coverage,
lean-input and concise-output variants, long/growing-thread measurements,
retention/interface comparisons, justified compaction or exact-work reuse, and
the confirmed third machine's installed/live evidence. Current defaults remain
unchanged. This handoff does not close the parent rollout or lift its hold.

## 4. Failed attempts and installation lessons

1. Initial Ubuntu installation reached the intended source but its required
   user-service stage failed because the credential runner did not carry the
   owner's `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`. The toolkit's doctor
   and a real GLM path had succeeded; this was the installer environment.
   Restore the existing owner's actual user bus, then use the documented
   **install resume**, not a fresh updater run over a pending transaction.
   That completed every required stage. Do not disable the service/check, run
   the install as root, or invent user-bus credentials. Procedure:
   [deployment guide](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md).
2. Ubuntu elevation used an existing 1Password credential injected into a
   short-lived helper and delivered to a PTY with echo disabled. No secret
   value appeared in chat, process arguments, source or public receipts. Use
   the protected credential procedure; never ask Albert to enter a password.
3. The default Windows PowerShell script policy refused the initial test
   launcher. The documented per-process installer invocation worked; no
   machine policy was changed. Use native PowerShell/Git Bash deliberately,
   not an accidental WSL shell. Preserve `SYSTEMROOT` and related Windows
   environment fields; previous rollout receipts document that omission's crash.
4. The first source PR merged before the advisory follow-up correction was
   pushed. Reusing its branch for the follow-up required reconciling current
   main; the only conflict was duplicate plan text. Preserve both landed
   source and the new correction. No force push, reset or broad staging was
   used. The reconciled/tested/landed source trees were identical.
5. Windows installation spent several minutes in its existing optional GitHub
   login-copy stage, then completed normally. Do not mislabel shared admission
   or quota deferral as invalid credentials, weaken pacing or kill other
   sessions' calls. Reuse the existing bounded waiters and diagnose exact state.
6. Existing repository documentation-health warnings and housekeeping
   candidates were outside scope. They were not a reason to edit another
   session's handoff, bypass a data-safety check or expand this wrap-up.

## 5. Root causes, efficiency findings and a wrap-up-only observation

The parser used a missing counter as numeric zero while accumulating events;
its earlier test covered no events at all, not a completed event lacking usage.
The landed regressions now cover missing/null, each field independently,
explicit zero, invalid nested shapes/types, negative/bool/float/string counters,
mixed steps and malformed/unrelated events. Preserve those semantics.

Caching discounts repeated eligible input; it does not reduce output or prove a
faster/cheaper whole job. Persistent sessions preserve context and can still
resend and bill a growing history. Failed requests, tool loops, summaries and
cache rewarming belong in total cost. Shortening a published report after
generation saves no generation tokens. A new namespace does not prove a cold
account-wide cache. Never silently treat missing measurement as zero.

**Discovered during wrap-up, deferred without implementation:** outside CI,
`cache_scope` can hash the local checkout argument rather than canonical
repository identity. Different approved clones/machine paths can therefore
fragment the reusable key even for the same repository. See the
[actual adapter](https://github.com/popcre/ai-devops/blob/main/tools/reviewer_routes.py).
Investigate in the existing step-6b workstream: use the existing validated
repository/path-identity helpers, preserve repository/route/prefix-policy and
authorization boundaries, and test equivalent approved clones versus unrelated
repositories. Do not weaken cache isolation or assume accounts/providers share
a cache. A key is only a routing/reuse hint; outgoing prefix bytes must also be
stable. This is a new test/measurement obligation for the successor, not a fix
claimed complete by this wrap-up.

## 6. Exact next steps and verification gates

1. **Establish current source and custody.** Read the linked operating guide,
   this file, full existing plan, parent and #2551 latest comments. Start a
   fresh current-main task worktree/branch using the prescribed `codex/`
   prefix. Declare reviewer-safety before editing. Post a signed scoped
   ownership note on #2551; if the existing implementation owner is active,
   reconcile actual ownership before touching the same files. Do not infer
   active work from old comments or an empty assignee list. **Gate:** current
   source, intended scope, one implementation owner and the confirmed host set
   are recorded on the existing issues. Use §0's confirmed host set.
2. **Inventory each confirmed machine safely.** Resolve its canonical toolkit
   checkout, installed receipt, pinned runtimes, protected credential bindings,
   native shell, read-only boundary and relevant live sessions through the
   [deployment guide](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md)
   and protected machine atlas. The public
   [atlas pointer](https://github.com/popcre/ai-devops/blob/main/templates/system/machine-atlas.md)
   routes to that private source; never publish its contents. Treat previous
   two-host installation evidence as a baseline, not proof of current state.
   **Gate:** a per-host baseline and recoverable installation route exist;
   no networking-only host, application or shared database is touched.
3. **Implement complete telemetry first (plan 6b.1).** Extend the existing
   adapters/receipts, preserving missing-versus-zero and measured coverage.
   Account for input/cache/output/reasoning when supplied, requests, retries,
   failovers, wall time and actual charges or explicit estimates. Add the
   planned usage-coverage/failed-attempt regressions in the linked route suite.
   **Gate:** incomplete usage cannot masquerade as whole-job savings and a
   reproducible per-route baseline includes Hy4/DeepSeek unknowns honestly.
4. **Implement and qualify isolated token-saving variants (plan 6/6b).** Keep
   each independently reversible and opt-in. Stable prefix/tools and correctly
   scoped identifiers first; then leaner instructions/targeted reads with full
   exact-head evidence accessible; then concise findings; then growing sessions
   and runtime compaction measurement. Test the cross-machine key observation
   from §5. Add compaction/checkpoints or exact-work deduplication only when the
   baseline justifies them and existing shared mechanisms do not suffice.
   Session persistence already exists: preserve/repair it, do not replace it.
   Named sessions must survive two fresh-process restarts and idle; Muse
   fallback preserves scope and one visible pending question, without private
   reasoning/tool replay or nested transcript duplication. **Gate:** implement
   the named correctness/adversarial tests from plan sections 9–10, and score
   seeded, clean and distinct real TypeScript cases with unchanged model,
   effort and provider policy. No missing evidence, added false findings,
   lost decisions, stale verdict reuse or unauthorized cache sharing.
5. **Measure the complete product, not one repeated request.** Use paired
   disabled/enabled comparisons in reversed order, at least five distinct
   public TypeScript changes and one growing discussion per selected route,
   including startup, first requests, tool loops, failed attempts, restarts,
   idle and failover. Keep Responses-versus-Chat, retention and long-context
   hypotheses separate; check current primary provider docs and existing
   storage policy before changing any retention setting. **Gate:** publish
   reproducible absolute costs, denominators, coverage, quality and timings on
   #2551 with parent #2531 acceptance. A 99% repeated-input hit is not a savings
   forecast. If a variant is immaterial or regresses quality, leave it disabled
   and record the completed negative experiment, not a fabricated saving.
6. **Ship and prove on all three confirmed hosts.** Use focused regressions,
   the linked route and legacy suites, CI/queue and each OS's installer; do not
   verify the same unchanged code twice merely because docs changed. Check
   runner collisions before local full suites. Obtain Muse's advisory view of
   the final new changes and full updated plan; address concrete findings,
   without making review a merge/activation gate. Verify installed source and
   normal wrapper behavior, resume, isolation, cache-request wiring and usage
   coverage on every confirmed host. Rehearse rollback without deleting named
   sessions. **Gate:** the implementation is merged, the safe opt-in variants
   are installed and work through both normal entry points, and each host has
   exact-source live receipts. No partial host counts as all three. Reviewer
   rotation/default activation remains held; no human approval question is
   needed to retain the existing settings.
7. **Close the existing acceptance records.** Update the plan STATUS/current
   code to distinguish implemented, measured, rejected and still blocked work.
   Preserve the parent's unrelated route-activation hold. Keep any missing
   live proof on the same issue with a named owner. **Gate:** every requested
   strategy is implemented/qualified or has a concrete measured rejection or
   external blocker; no unowned leftover and no new parallel tracker. Retire
   this handoff only under its documented successor rule after carrying every
   remaining obligation forward.

## 7. Constraints and gotchas

- Keep defaults unchanged. New optional capabilities are not permission to
  switch rotation, alter model/effort, migrate old sessions, enable long
  retention or route private prompts to an unapproved provider. No reviews
  through writable delegation. Preserve GLM/StepFun and legacy compatibility.
- Read-only and exact-source controls, policy refusals, credential separation,
  atomic session recovery and successful-final-verdict rules take priority
  over token savings. Never impose arbitrary turn budgets or suppress findings.
- GitHub is source truth; use protected PR/queue delivery and the governed
  GitHub caller/waiters from the
  [tool cheat sheet](https://github.com/popcre/ai-devops/blob/main/docs/ai-tools-cheat-sheet.md).
  Verify Albert's Git identity before each repository's first commit. Stage
  only owned files. No direct protected-main push or manual installed-checkout
  pull/reset. No app, cloud infrastructure or database work is in scope.
- Use native Windows/Git Bash compatibility and existing path-identity helpers.
  Do not compare filesystem paths as raw strings. Do not weaken provider
  restrictions, add routing aliases/order, or silently substitute models.
- Reuse the existing plan, shared adapters, private session homes and reporting
  paths. Raw prompts, transcripts, credentials, private atlas data and sensitive
  receipts never enter this public repository or public issue comments.
- Delegate only explicitly scoped mechanical helper work under the
  [model-tier sheet](https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md).
  Decisions, security, live evidence, merges and release remain lead-owned.
  A helper returns finished work with evidence or an exact blocker; never use
  a full-strength model as the cheaper helper or invent busywork.

## 8. Access, environment and wrap-up state

GitHub access through the governed wrapper and native SSH to edge-dev worked
in this session. Do not assume that proves the successor's access or hetz's
current state; resolve the protected atlas and existing authenticated tools.
Credentials already exist in 1Password vault `vibe_coding` and protected local
stores. Use official wrappers for Muse and provider keys; the existing
protected credential skill supplies transport rules. No new credentials were
created and no secret value surfaced or requires storing/rotation.

No shared Supabase database/repository, database claims, preview/production
stages or subagents were touched or held. Database closeout is N/A. There is
no running benchmark, implementation child or unpushed code to inherit.
Earlier Ubuntu/Windows temporary test/install worktrees were inspected clean
and removed; public source/proof is retained in the linked commits and receipt.
This wrap-up creates only this handoff, its plan backlink and generated index.
It will be delivered through a new prose PR; source repair remains at the
already verified release. Current-session workspace/branch disposition and
any app protection will be recorded on #2531 before closing.

Housekeeping was report-only: unrelated live/unknown work remains protected.
The snapshot found 3 merged-worktree and 6 merged-branch candidates, 37 closed
issue handoffs needing their owners' successor review, 10 unprovable and 2
unattributed handoffs. Counts are not deletion authority or a handoff-size
problem. A name/owner inventory follows below; none is this continuation's
permission to tidy other work. Do not start that cleanup under this handoff.

## 9. Open risks and self-audit

Open work belongs to the successor on #2551, with acceptance on #2531. No
successor session has been created or claimed active here; Albert asked for a
copyable prompt, not automatic dispatch. Main risks are incomplete billing,
session growth/replay, fragmented cross-machine cache scopes, unsupported
retention assumptions, account-wide warm-cache confounds, exact-work reuse of
stale evidence, third-host access/namespace limits and collision with the
existing rollout owner. Reconcile the source and custody before acting.

The existing selective fresh-reader pilot is closed/not adopted; no new
review gate or compression service is being introduced.

Self-audit passed:

1. **A fresh developer can continue without chat context:** sections 0–3 define
   the scope/hold, confirmed three-host set, existing application, completed
   source and exact public receipts; sections 6–8 give ordered gates and access.
2. **They retain the session's non-obvious knowledge:** sections 3–5 preserve
   implemented persistence, missing/subtotal semantics, both Muse corrections,
   measured versus unproven savings, installation failures and safe recovery,
   and the cross-machine key observation deferred by scope freeze.
3. **All execution detail and constraints are present:** every step in section
   6 has an observable gate, section 7 preserves safety and unchanged defaults,
   and section 8 separates verified two-host facts from unmeasured third-host state.
   Every file/commit pointer is a portable GitHub URL; no private paths/values
   are needed or embedded. Existing plan tests remain the full build contract.
4. **Owner-question sweep:** read all sections 1–9 and extracted machine scope,
   default hold, retention, custody, credentials and deployment decisions.
   The only machine-scope question was answered by Albert and is settled in
   section 0. Everything else is settled or an AI-owned technical verification,
   not a new permission request. No unrelated business decision was discovered.

### Report-only successor-review inventory

These names/owners come from the bounded housekeeping inventory, not from
opening or editing other sessions' handoffs. Closed issues trigger their
owners' successor review; they do not prove completion. None was retired.

- [2026-08-27T2023Z-edge-dev-claude-codex-status-line-docs.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-08-27T2023Z-edge-dev-claude-codex-status-line-docs.md) — owner: claude/codex-statusline-handoff; issue [#133](https://github.com/popcre/ai-devops/issues/133).
- [2026-09-07T1800Z-edge-dev-codex-reviewer-residual-failures.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-07T1800Z-edge-dev-codex-reviewer-residual-failures.md) — owner: codex/reviewer-0907-closeout; issue [#1678](https://github.com/popcre/ai-devops/issues/1678).
- [2026-09-11T0222Z-edge-dev-codex-issue-335-phase5-blocked.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-11T0222Z-edge-dev-codex-issue-335-phase5-blocked.md) — owner: codex/issue-335-phase5-blocked; issue [#335](https://github.com/popcre/ai-devops/issues/335).
- [2026-09-17T2106Z-edge-dev-codex-open-issues-continuation.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-17T2106Z-edge-dev-codex-open-issues-continuation.md) — owner: codex/wrapup-open-issues-20260917; issue [#62](https://github.com/popcre/ai-devops/issues/62).
- [2026-09-28T1123Z-edge-dev3-codex-jevgrep-search-evaluation.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-28T1123Z-edge-dev3-codex-jevgrep-search-evaluation.md) — owner: codex/jevgrep-wrap-handoff; issue [#643](https://github.com/popcre/ai-devops/issues/643).
- [2026-09-28T1149Z-edge-dev3-codex-github-request-reduction.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-28T1149Z-edge-dev3-codex-github-request-reduction.md) — owner: codex/658-wrapup-20260928; issue [#658](https://github.com/popcre/ai-devops/issues/658).
- [2026-09-28T1151Z-edge-dev-codex-windows-runner-qualification.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-28T1151Z-edge-dev-codex-windows-runner-qualification.md) — owner: codex/edge-dev-runner-wrapup; issue [#963](https://github.com/popcre/ai-devops/issues/963).
- [2026-10-02T2207Z-edge-dev-mimo-warpbuild-post-land-proof.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-02T2207Z-edge-dev-mimo-warpbuild-post-land-proof.md) — owner: mimo/warpbuild-post-land-proof; issue [#961](https://github.com/popcre/ai-devops/issues/961).
- [2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md) — owner: mimo/reviewer-issues-after-watchdog; issue [#1678](https://github.com/popcre/ai-devops/issues/1678).
- [2026-10-08T1719Z-edge-dev3-codex-request-reduction-closeout.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-08T1719Z-edge-dev3-codex-request-reduction-closeout.md) — owner: codex/658-wrap-up-handoff; issue [#658](https://github.com/popcre/ai-devops/issues/658).
- [2026-10-08T1754Z-edge-dev3-codex-hts-review-rag.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-08T1754Z-edge-dev3-codex-hts-review-rag.md) — owner: codex/hts-final-closeout; issue [#1490](https://github.com/popcre/ai-devops/issues/1490).
- [2026-10-09T1930Z-edge-dev3-claude-reviewer-followups.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-09T1930Z-edge-dev3-claude-reviewer-followups.md) — owner: claude chat eac6b686-2bdd-4fce-91fe-47ae8516cb81 (closed); next owner = whoever picks up popcre/ai-devops; issue [#1544](https://github.com/popcre/ai-devops/issues/1544).
- [2026-10-15T0236Z-edge-dev-mimo-658-section13-closeout.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-15T0236Z-edge-dev-mimo-658-section13-closeout.md) — owner: mimo/658-section13-closeout; issue [#658](https://github.com/popcre/ai-devops/issues/658).
- [2026-10-16T0111Z-edge-dev3-codex-reviewer-recurrence-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T0111Z-edge-dev3-codex-reviewer-recurrence-plan.md) — owner: codex/reviewer-repair-closeout; issue [#1783](https://github.com/popcre/ai-devops/issues/1783).
- [2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T0148Z-edge-dev-mimo-reviewer-no-review-plan.md) — owner: mimo/edge-dev-reviewer-no-review-plan; issue [#1678](https://github.com/popcre/ai-devops/issues/1678).
- [2026-10-16T0234Z-edge-dev3-codex-glm-own-output.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T0234Z-edge-dev3-codex-glm-own-output.md) — owner: codex/glm-own-output-routing; issue [#1791](https://github.com/popcre/ai-devops/issues/1791).
- [2026-10-16T0419Z-edge-dev3-codex-exact-sandbox-release.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T0419Z-edge-dev3-codex-exact-sandbox-release.md) — owner: codex/exact-sandbox-release; issue [#1796](https://github.com/popcre/ai-devops/issues/1796).
- [2026-10-16T0515Z-edge-dev3-codex-muse-final-receipt-design.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T0515Z-edge-dev3-codex-muse-final-receipt-design.md) — owner: codex/muse-final-source-receipt-design; issue [#1783](https://github.com/popcre/ai-devops/issues/1783).
- [2026-10-16T1400Z-edge-dev3-claude-reviewer-recurrence-step2.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T1400Z-edge-dev3-claude-reviewer-recurrence-step2.md) — owner: claude/1783-coordinator (chat d6c213bf-bfaf-44d2-9ced-be1a5246bb06, edge-dev3); issue [#1783](https://github.com/popcre/ai-devops/issues/1783).
- [2026-10-16T1835Z-edge-dev-mimo-reviewer-stability-24h.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T1835Z-edge-dev-mimo-reviewer-stability-24h.md) — owner: mimo/edge-dev-class-level; issue [#1822](https://github.com/popcre/ai-devops/issues/1822).
- [2026-10-19T2000Z-hetz-claude-review-output-contract-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-19T2000Z-hetz-claude-review-output-contract-plan.md) — owner: unclaimed — next session claims on issue 1783; issue [#1783](https://github.com/popcre/ai-devops/issues/1783).
- [2026-10-21T2020Z-edge-dev3-claude-reviewer-observation-week.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-21T2020Z-edge-dev3-claude-reviewer-observation-week.md) — owner: unclaimed — next session claims on the owner issue; issue [#1948](https://github.com/popcre/ai-devops/issues/1948).
- [2026-10-22T1050Z-edge-dev-mimo-reviewer-incidents-handoff.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-22T1050Z-edge-dev-mimo-reviewer-incidents-handoff.md) — owner: mimo/edge-dev-reviewer-incidents-wrapup; issue [#1678](https://github.com/popcre/ai-devops/issues/1678).
- [2026-10-22T1149Z-edge-dev3-claude-reviewer-recurrence-step8.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-22T1149Z-edge-dev3-claude-reviewer-recurrence-step8.md) — owner: claude/1783-coordinator (chat a0383fe3-ae90-495c-9fa7-9ad7e7cb2fd5, edge-dev3) — released at wrap-up 2026-10-22; issue [#1783](https://github.com/popcre/ai-devops/issues/1783).
- [2026-10-27T1403Z-edge-dev3-codex-entire-trial-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-27T1403Z-edge-dev3-codex-entire-trial-plan.md) — owner: codex/entire-trial-muse-revisions; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-10-27T1822Z-edge-dev3-codex-entire-trial-closeout.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-27T1822Z-edge-dev3-codex-entire-trial-closeout.md) — owner: codex/entire-trial-closeout; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-10-29T1416Z-al8960ofc-claude-observation-week-diagnosis.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-29T1416Z-al8960ofc-claude-observation-week-diagnosis.md) — owner: claude/observation-week-diagnosis-handoff; issue [#1948](https://github.com/popcre/ai-devops/issues/1948).
- [2026-10-29T1428Z-edge-dev3-codex-entire-trial-continuation.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-29T1428Z-edge-dev3-codex-entire-trial-continuation.md) — owner: codex/entire-trial-fresh-session-20261029; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-10-29T1842Z-hetz-zcode-transcript-dropbox-pipeline.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-29T1842Z-hetz-zcode-transcript-dropbox-pipeline.md) — owner: zcode/hetz transcript-to-dropbox pipeline; issue [#2045](https://github.com/popcre/ai-devops/issues/2045).
- [2026-10-29T2015Z-edge-dev3-claude-transcript-store-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-29T2015Z-edge-dev3-claude-transcript-store-plan.md) — owner: claude/transcript-store; issue [#2050](https://github.com/popcre/ai-devops/issues/2050).
- [2026-10-29T2330Z-edge-dev3-claude-skinny-review-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-29T2330Z-edge-dev3-claude-skinny-review-plan.md) — owner: claude/skinny-review-plan; issue [#2041](https://github.com/popcre/ai-devops/issues/2041).
- [2026-10-30T0345Z-edge-dev3-codex-entire-trial-wrap.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-30T0345Z-edge-dev3-codex-entire-trial-wrap.md) — owner: codex/entire-trial-wrap-20261030; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-10-30T1757Z-edge-dev3-codex-entire-live-wrap.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-30T1757Z-edge-dev3-codex-entire-live-wrap.md) — owner: codex/entire-trial-session-wrap-20261030; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-10-30T1847Z-edge-dev3-codex-entire-fleet-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-30T1847Z-edge-dev3-codex-entire-fleet-plan.md) — owner: codex/entire-trial-fleet-plan-20261030; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-10-31T2353Z-edge-dev3-codex-entire-control-trial.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-31T2353Z-edge-dev3-codex-entire-control-trial.md) — owner: codex/entire-trial-control-handoff-20261031; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).
- [2026-11-01T0208Z-edge-dev3-codex-small-trials-handoff.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-01T0208Z-edge-dev3-codex-small-trials-handoff.md) — owner: codex/muse-trials-wrap-up; issue [#2227](https://github.com/popcre/ai-devops/issues/2227).
- [2026-11-01T1442Z-edge-dev3-codex-entire-trial-continuation.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-01T1442Z-edge-dev3-codex-entire-trial-continuation.md) — owner: Codex chat 01a19481-9ceb-7592-934e-9e5a4dac240d on edge-dev3; issue [#2022](https://github.com/popcre/ai-devops/issues/2022).

### Copyable launch prompt

Implement the remaining caching, persistent-session qualification and measured
token-saving strategies in https://github.com/popcre/ai-devops under #2551,
with acceptance on #2531. Read this handoff and the entire linked plan first:
https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-17T2355Z-edge-dev3-codex-cache-fleet-continuation.md
https://github.com/popcre/ai-devops/blob/main/plan_deepseek-harness-openrouter.md
Start from current main in your own task worktree/branch, declare the proper
task class and reconcile the existing implementation owner before editing.
The cache-reporting repair is already merged, installed and verified on
edge-dev3 and edge-dev; do not redo it or replace working named-session resume.
Albert confirmed the targets: edge-dev3, edge-dev and hetz. Do not ask him to
reconfirm them. Implement plan steps 6/6b in order:
complete billing/coverage, stable scoped caching, lean inputs with full evidence,
concise findings, growing-session persistence/compaction qualification and
conditional exact-work reuse. Preserve every existing default and provider,
privacy, read-only and source-identity boundary. Finish safe opt-in deployment
and exact-source live proof on every confirmed target, with paired costs and
quality evidence, restart/idle/failover recall and recoverable rollback. Ask
Muse for advisory feedback on final changes and the whole updated plan; fix
concrete findings. Continue until the authorized scope is complete or an exact
external blocker is preserved on the same issues. Never ask me to perform
technical setup, enter credentials or approve a technical action.
