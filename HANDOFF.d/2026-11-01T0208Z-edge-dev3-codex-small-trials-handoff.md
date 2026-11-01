---
issue: 2227
status: OPEN
owner: codex/muse-trials-wrap-up
---

# Resume the separate EGM and TokenEconomizer small trials

## 0. Business decisions only the owner can make

None. Do not ask Albert to approve reviews, technical access or ordinary scoped
implementation choices. Albert requested this handoff specifically to include
the small trials agreed by Codex and Muse. Wrap-up does not start those trials.

Settled October 31, 2026: keep two implementation plans and child issues; one
coordination parent owns combined compatibility and shared-file scheduling.
Try a single fresh-reader comprehension pass, not EGM's full five-stage process.
Try optimizer advisory loop recovery and LLM-free setup facts on an actually
qualified surface; automatic tool removal and model-generated memory stay off.
No desktop support or savings is proven. Keep original capabilities working.

If a materially different business scope becomes necessary, consolidate the
actual business questions once before dependent work; do not disguise technical
setup or an unsupported platform as a business approval request.

## 1. Application and sources

The public [ai-devops toolkit](https://github.com/popcre/ai-devops) restores
Albert's multi-model workflow on Ubuntu and Windows; installation is deployment.
It is not an application server. Start with
[AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md) and the matching
[task-router row](https://github.com/popcre/ai-devops/blob/main/docs/task-router.md).

Read these execution authorities, in order:

1. [Coordination parent #2227](https://github.com/popcre/ai-devops/issues/2227),
   including current ownership and shared-file edit comments.
2. [Fresh-reader plan](https://github.com/popcre/ai-devops/blob/main/plan_selective-fresh-reader.md)
   STATUS and §§8–13; child [#2222](https://github.com/popcre/ai-devops/issues/2222).
3. [Optimizer plan](https://github.com/popcre/ai-devops/blob/main/plan_tokeneconomizer-desktops.md)
   STATUS and §§8–13; child [#2220](https://github.com/popcre/ai-devops/issues/2220).
4. [Corrected Muse decision record](https://github.com/popcre/ai-devops/blob/main/docs/muse-egm-tokeneconomizer-review-2026-10-31.md).

These main URLs are the intended published locations for this closeout; verify
the closeout PR/landing receipt on #2227 before relying on newly added files.
If unmerged, use that PR's exact head, not an invented main artifact.

## 2. Session goal and what was delivered

Albert asked whether Google's EGM could improve work/cost, then requested plans,
cross-program coordination, a Muse evaluation of both upstream programs and our
implementation, and finally wrap-up with executable small-trial instructions.

Earlier verified deliveries: [planning PR #2224](https://github.com/popcre/ai-devops/pull/2224)
and [coordination PR #2228](https://github.com/popcre/ai-devops/pull/2228).
The latter landed as
[ca52173c](https://github.com/popcre/ai-devops/commit/ca52173c3474d735f78be946f6f7f4abbbd412ae).
Native parent/child relationships and preservation of both issue bodies were
read back. The current closeout preserves the corrected Muse evaluation, adds
this handoff, and routes both plans to it. It does not implement either program.

## 3. Current state — inspect before taking ownership

All implementation rows in both plan STATUS tables were open at closeout
reconciliation. This session installed neither program, wrote no runtime helper,
ran no native desktop qualification and measured no savings. The review evaluated
upstream code and our prose plans only; no running implementation existed to
review in this session's source snapshot.

Another session may own optimizer execution. In particular,
[b9090cce](https://github.com/popcre/ai-devops/commit/b9090ccec0606affbe5446a9a0e18512743e9003)
records current TokenEconomizer ownership continuity. Re-read #2220's latest
owner/activity before touching its code, profiles, installations or plan. Do not
steal ownership from an active session. If it already produced evidence, reuse
it and update the next action; do not replay an old planning snapshot.

The review source baseline was
[e701c9fb](https://github.com/popcre/ai-devops/commit/e701c9fb299427f40c170dd40838e40b5cbb5ce5).
Closeout began from current main
[0a710176](https://github.com/popcre/ai-devops/commit/0a710176ad6d).
Read the parent closeout receipt for the exact final source/landing and checks.
No shared-db claims, Supabase work or collaboration subagents were involved.
No credential values appeared; secrets storage was not needed.

## 4. Attempts that failed or were corrected

* The first Muse copy omitted TokenEconomizer because a filename ignore rule
  matched its directory. Its incomplete verdict is discarded. A corrected
  disposable repository explicitly included both pinned public trees; all 227
  EGM and 267 optimizer files were byte-verified in the reviewer copy. Never
  change the public repository's ignore protection to repair a review packet.
* The complete review initially called several existing requirements missing.
  Codex challenged those with source references; Muse withdrew missing app/engine
  versions, missing cache handling, missing generic Windows contract and demands
  for a new lock registry or hidden system-prompt hashes. Preserve the corrected
  decision, not the discarded first verdict or unrevised criticism.
* CLI success is not desktop proof; a missing upstream desktop entry is not
  proof the current app fails. Historical MiMo/ZCode limitations are recheck
  targets, not current unsupported verdicts.
* Shared GitHub admission traffic delayed calls. The repository's supported
  throttled access and bounded waiters are the route; do not bypass them or
  create duplicate issues after an ambiguous response.
* Do not copy full EGM review, import private chats, infer savings from prompt
  size, build unsupported desktop adapters or disable global capabilities.

## 5. Findings and agreed scope

Pinned public sources:
[EGM 403d8881](https://github.com/google/elephant-goldfish-model/tree/403d8881d62022490637d740657b33f01e321ea8)
and [TokenEconomizer c53a4a6](https://github.com/microsoft/TokenEconomizer/tree/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23).
Muse's final advisory verdict was APPROVE for narrow qualification pilots.
Codex agrees; minor refinements are execution details, not permission gates.

Actual shell observations on Ubuntu edge-dev3, 9:41 PM EDT October 31, 2026:
Codex `0.166.0-alpha.5.1`; Claude Code `2.1.309`. The optimizer's pinned README
validated Codex only through `0.164.0`: record the skew and qualify/re-pin; do not
automatically downgrade, switch models or declare incompatibility. Desktop app
and embedded runtime versions must be collected separately.

The [EGM comprehension persona](https://github.com/google/elephant-goldfish-model/blob/403d8881d62022490637d740657b33f01e321ea8/agents/comprehension.md)
is the selected idea. The
[Codex integration guide](https://github.com/google/elephant-goldfish-model/blob/403d8881d62022490637d740657b33f01e321ea8/docs/codex.md)
warns that fresh context is not filesystem/memory isolation and distinguishes
ChatGPT desktop packaging from Codex integration.
The [optimizer runtime design](https://github.com/microsoft/TokenEconomizer/blob/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23/docs/PLUGIN.md)
distinguishes benchmark behavior from the shipped plugin and acknowledges model
egress/overhead. Local state does not prove no outgoing session-derived data.

## 6. Exact next actions and small-trial instructions

### A. Reconcile ownership and current applicability first

1. Read both live child issues and parent. Claim only a free scope using the
   existing issue workflow; if another session is active, send the agreed trial
   instructions through the owning issue instead of editing its work. Post exact
   shared files/current writer on #2227 before edits; one writer per file. Use a
   current-upstream task worktree and declare the honest task class.
   **Gate:** owner, exact source and bounded next action are recorded; no collision.
2. Inventory actual app, embedded engine, OS, profile alias, execution host,
   supported loader/events, native fresh-agent schema, version and access state.
   Start with one actually accessible Ubuntu Codex/Claude surface. Current Windows
   inventory remains necessary later for requested MiMo/ZCode dispositions.
   **Gate:** evidence distinguishes desktop, CLI and cloud; each target is qualified,
   unverified, unsupported with current evidence, or blocked by exact access.
3. Recheck the two pins before vendor use; use supported documented routes only.
   Read [deployment guidance](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md)
   before any installation/protected-runtime change. Never pull the installed
   checkout, create a vendor adapter or force a stale CLI version.
   **Gate:** profile/state recovery is recoverable and a native allowed route exists.

### B. EGM idea — one reader, three real documents

4. Follow fresh-reader plan §§9.1–9.3: write its single short protocol, then the
   complete-plan, missing-prerequisite, contradictory-handoff and hostile-document
   synthetic fixtures. Keep answer keys outside the reader packet. This is an
   instruction-only slice; do not install full EGM or add another reviewer service.
   **Gate:** missing/contradictory prerequisites are found, complete input is
   accurately restated without invented blockers, hostile instructions stay data.
5. Inspect the running native agent schema and record the actual no-history
   parameter/tool used. Prove read-only behavior, effective settings and state
   roots. Packet = goal, exact target/hash, bounded reading list, output contract
   and declared safety/project rules only. No parent chat, private memory, learned
   facts or optimizer summaries. Keep TokenEconomizer absent from this standalone
   trial profile, including author/remediation sessions.
   **Gate:** launch/schema receipt, visible child input inventory and successful
   required-read receipts show the boundary; a missing canary echo alone is not proof.
   List unavailable hidden platform input as unknown; do not expose or hash it.
6. Run named hostile-input, reading-boundary, snapshot-mismatch, incomplete-output,
   memory-injection and reader-event-exclusion cases from the plan. Use only
   harmless synthetic markers; do not publish their values or private state.
   **Gate:** unsupported native isolation is explicit and never called a pass;
   ordinary author capability still works and reader events cannot train optimizer.
7. Select three already-authorized public complex plans/handoffs before reading
   results. Freeze their exact versions and baseline self-audits. Run one reader
   pass each, bounded by the plan's ten-minute invocation limit. Reader first
   paraphrases intended result/existing workflow, then gives grounded missing
   prerequisites/contradictions/questions with references. Parent alone decides
   fixes and records accepted/rejected findings; no automatic re-review.
   **Gate:** all three records have exact inputs, native receipts, findings,
   dispositions, elapsed time and actually exposed usage including author work.
8. Pre-register an advisory-noise criterion before the first real artifact. Keep
   the existing adoption threshold: at least two of three documents receive a
   confirmed material clarity fix; no unresolved material invented requirement
   or scope expansion; one pass/time limits respected. Record style-only findings
   and avoidable author effort, and reject routine use if the predeclared noise
   budget fails. A concrete conservative starting criterion is no extra review
   round or rewrite caused solely by stylistic noise; the owner records this once
   before results, not after seeing them.
   **Gate:** directional quality disposition only; no causal savings claim from
   three documents. Negative pilot is valid. Unknown usage stays unknown.

### C. Optimizer — tiny synthetic learning smoke before installation machinery

9. With the #2220 owner, complete plan steps 1–2 applicability/privacy/source audit
   first. Use a supported empty task-owned profile/state and public synthetic
   repository. Block accidental private ingestion before the first hook. Snapshot
   recovery and verify outgoing payloads use only synthetic material.
   **Gate:** correct loader/events/profile, native notice visibility and supported
   isolation proven; Codex version skew resolved by evidence, not assumption.
10. Keep automatic tool pruning off, model-generated micro-skills/proposer off,
    repository-map injection off, and the non-tested mechanism off. Qualify only
    advisory loop-guard first and LLM-free environment facts separately. Discover
    actual upstream configuration keys in the pinned source; do not invent an
    independent `envfacts` flag. No forced stop, turn budget cap, global hook
    removal or loss of ordinary tools/MCP/skills.
    **Gate:** effective settings and synthetic state prove which one mechanism is
    active; other treatment and fresh-reader calls are absent from both arms.
11. On the first supported Ubuntu surface, run at most three predeclared synthetic
    baseline/treatment pairs per selected mechanism. Loop-guard tasks use harmless
    repeated failures followed by an ordinary edit/test recovery; seed the required
    clean-turn history before expecting a judge. Environment-facts tasks repeat
    harmless known setup/command errors across synthetic sessions until the source's
    confirmation threshold is met. A three-pair cap is not a three-session cap;
    count and price all warm-up/learning sessions, not just the final pair.
    **Gate:** actual desktop events/notices/state plus expected recovery/fact behavior
    are observed, and ordinary work/capabilities still succeed. CLI-only proof
    stays CLI-only and cannot close requested desktop acceptance.
12. Freeze source/model/effort, starting facts, synthetic state, cache warm/cold
    conditions, task success checks and pair order in advance. Record input,
    output/cache tokens, extra judge/proposer calls, elapsed time and task/check
    completion. Keep the baseline state separate from learned treatment state;
    include state warming and every extra model call in overhead. Balanced
    alternating order is already specified; randomized starting order is optional
    if fixed before runs. Unknown counters leave measurement incomplete; never
    discard inconvenient pairs, replace missing values with zero or tune indefinitely.
    **Gate:** bounded smoke yields proceed/reject/blocked with native receipts,
    not a claimed percentage saving. Use only the plan's bounded error rerun.
13. If the smoke is useful, proceed to managed integration/recovery and the plan's
    later ten-pair-per-adopted-desktop study. Keep the original adoption gate:
    no additional failed task/check/capability loss and at least 10% lower
    aggregate priced token cost including optimizer overhead. Subscription-based
    equivalent prices are estimates, not actual dollars saved. Recheck Windows
    native loaders/events; absent current support means evidence-backed disposition,
    not a custom adapter. Missing access remains blocked, not inapplicable.
    **Gate:** no broad rollout until full native acceptance/benefit is proven.

### D. Combined compatibility and final runtime review

14. Only after both relevant standalone receipts exist, coordinate parent-owned
    combined smoke on each common supported app/OS combination. Normal author
    optimization stays active while reader input/events remain excluded. Test an
    ordinary edit/test journey and correct comprehension. Reject/inapplicable
    sibling yields evidenced N/A; access gaps remain blocked. No joint cost claim.
    **Gate:** parent's linked combined receipt proves both capabilities coexist;
    standalone children may close independently but shared-mode rollout waits.
15. Update both plan STATUS tables from artifacts, link exact commits/native
    receipts on the existing child/parent issues, then request evaluation of the
    actual implementation. Muse stays optional advice and does not gate shipment.
    **Gate:** code/installed settings/native behavior exist to review; no paper-only
    runtime approval. Close only the acceptance actually demonstrated.

## 7. Standing constraints and scope freeze

No trial began during wrap-up. This handoff records all deferred work: both
implementations, applicability inventory, privacy/native isolation qualification,
small smokes, larger adoption study where justified, combined compatibility and
running-implementation review. Do not create extra leftover-proof tickets.

Keep public/private boundaries, official source pins, exact-head safety checks,
normal PR delivery and supported install routes. Reviews never require Albert's
approval. Keep private capture off, no paid service activation, and do not expand
the separate Entire trial. Follow its current authoritative instructions when
working on public ai-devops; retain GitHub continuity if Entire is unverified.
Never turn the advisory review into a new gate. Do not add personal memory here.

## 8. Access, verification and workspace custody

This session used Ubuntu edge-dev3, authenticated Git fetch and the existing Muse
wrapper/key store; no credential value was displayed. Public upstream sources
were cloned into task scratch, never installed. The corrected review did not run
shell/network tools itself; it read the supplied public source and repository.
Its report and this handoff are portable; successors need not locate local scratch
or a private provider transcript to recover the decisions.

Local working source, review snapshots and scratch may still exist as retained
review evidence. Do not delete another session's files. The current Codex-managed
worktree is intentionally retained until merged custody is verified and safe
cleanup can establish no active client/process or unique state. No branch deletion
should strand this open chat or unfinished implementation. The parent closeout
receipt records final commit/PR/landing and documentation checks.
The completed named Muse session is `complete-fit-2220-2222-20261031`; the earlier
`program-fit-2220-2222-20261031` session was deliberately aborted after the source
omission was discovered. Neither is an active worker to wait on. Vendor source
copies/staged inputs in disposable scratch and the read-only provider snapshot
are intentional review evidence, not pending toolkit implementation or files to
publish. The durable corrected conclusions are in the linked report; the next
session does not need to replay/recover an old provider conversation.

Report-only housekeeping observed no confirmed successor-review handoff candidate,
but GitHub was unavailable to that inventory, so mergedness was UNKNOWN. It also
reported unprovable/unattributed older handoffs. None was changed or retired; do
not mistake age/count or a tool's unknown status for deletion permission.

## 9. Open risks and handoff audit

Risks: desktop/CLI version mismatch, hidden ambient inputs, private egress,
cross-profile state leakage, judge overhead, false-positive review noise,
measurement contamination and unsupported Windows routes. Each has an evidence
gate or explicit unsupported/blocked/negative disposition above. Unknown platform
inputs stay unknown. No owner business decision is pending.

Self-audit passed:

1. A new developer can resume without this chat: §§0–3 define business goal,
   ownership/current source and no-implementation status; §6 gives ordered exact
   actions and per-step gates with public authority links in §§1/5.
2. They can continue as effectively as this session: §§4–5 preserve source-copy
   failure, corrected/withdrawn Muse findings, pins, observed versions and the
   difference between plausible, qualified and unsupported.
3. Background, failures, constraints, evidence and deferred work are all included:
   §§2–9 name what shipped, what did not, both small trials, cost/quality gates,
   rollback/custody expectations and later combined/runtime acceptance.
4. Reading only §0 exposes every business decision: none is outstanding; all
   execution choices are assigned to implementers and gated by evidence. The
   whole handoff was checked for disguised approval/setup requests; none remains.
