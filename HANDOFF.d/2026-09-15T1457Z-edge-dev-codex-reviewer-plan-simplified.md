---
issue: 159
status: OPEN
owner: codex/159-lean-plan-closeout
---

# HANDOFF — reviewer plan simplified (2026-09-15 14:57 UTC, EDGE-DEV/Codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream currently needs Albert. Already settled on
2026-09-15: Albert removed #271's outside-folder and network-denial release
gates, then approved the GLM 5.3/Codex consensus that missing historical evidence
must not block the programme forever and disabled providers need no live paid
call. Do not re-ask either decision. If a later step finds a genuinely new
owner decision, consolidate the whole list in one message before proceeding.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and safety toolkit for its
multi-model development workflow. It is not an application or database. Source
ships through GitHub to `main`; installation from canonical `C:/repos/ai-devops`
is deployment. The active outcome is parent issue #159, whose remaining order is
#271 (native Windows Codex review), #398 (integrated reviewer reconciliation),
#337 (reviewer programme), #166 (final required-check cutover), then #159.

## 2. What we set out to do this session, and why

This task resumed #159 from #271 after #397, #394, and #393 were delivered. Live
inspection reconfirmed that EDGE-DEV firmware virtualization was disabled and
native Codex could not enforce the former approved-snapshot-only boundary.
Albert ruled that this was excessive and removed outside-folder and network
denial from #271. He then asked Codex and GLM 5.3 to challenge the rest of the
plan until both agreed on the leanest safe completion path, and approved their
final consensus.

## 3. Current state — what is true right now

- PR #468 merged as `5a018e02217ff43e01d2a3a51e8ca7d4b03af902`.
  It updates `docs/codex-windows-containment-2026-09-11.md` and
  `plan_reviewer-reliability-and-efficiency.md`: #271 now requires marker/diff
  read, source-write denial, sealed identity, and a substantive exact-head live
  verdict. WSL2, outside-folder denial, and network denial are not release gates.
- GLM 5.3 reviewed the exact #271 documentation candidate `6449e4c2` and approved
  it. Persistent session `reviewer-plan-simplification-20260915` then completed
  two debate turns. Final report SHA-256 is
  `114bbbc915189df76abcbb8eea2be5f47f400ff52102ab513c2e4590d7f5a5b0` under
  this worktree's ignored `.ai/reviews/` directory. GLM and Codex have no
  unresolved technical objection.
- PR #471 merged as `93c984bc57e3edeede797201db7ca91143cd55d4`.
  `plan_reviewer-reliability-and-efficiency.md` now retains all 198 ledger rows
  but permits terminal evidence-unavailable dispositions with provenance and
  carry-forward; missing history alone no longer blocks #337 after every row is
  dispositioned. All nine adapter rows remain, but live installed calls apply
  only to adapters evidenced as enabled from governed allocation plus inspected
  installed configuration. Disabled/unsupported rows use exact interface
  evidence and zero calls; disabling a provider never erases its history.
- The same merge states that #333 owes no benchmark when no candidate
  optimization exists. `plan_repo-throughput-restructure.md` now reuses #164's
  existing injected-failure/recovery evidence, records current ruleset values and
  verifies the live bypass actor, and forbids #166 from staging a new deliberate
  live-ruleset break. Existing timing data, throwaway queue PR, required contexts,
  exact-head/source checks, source-write protection, required CI, and merge-queue
  safety remain.
- Issue #398's live body was updated to the same 198-row and guarded nine-adapter
  contract. Issues #271, #398, #337, #166, and #159 remain OPEN. No provider call,
  source implementation, installation, runtime configuration, production/cloud
  mutation, database work, or shared-db repository work occurred in this session.
- Current source of truth is `origin/main` at `93c984bc`. This handoff branch is
  `codex/159-lean-plan-closeout`; only this new handoff is expected before its
  documentation-only delivery.

## 4. Everything we tried that did NOT work

- Native EDGE-DEV qualification reconfirmed `VirtualizationFirmwareEnabled =
  False`; WSL2 reported it could not start. This is now historical evidence, not
  a blocker, because Albert removed the isolation gate rather than authorizing an
  OS or BIOS change.
- `EDGE-RUNN-ENVY` was reachable and qualified as a Windows runner, but also
  reported firmware virtualization disabled and WSL absent. `EDGE-ALIEN` was
  online in GitHub but remained paused/unqualified and its SSH route timed out.
  Neither offered a supported shortcut under the old requirement.
- The first attempt to edit issue #271 passed a multi-line PowerShell value to
  `gh --body` and was parsed as flags. Piping the exact body through
  `gh issue edit --body-file -` succeeded. Use the stdin route for future
  multi-line issue bodies.
- Codex initially proposed dropping all 198-item accounting and percentile
  evidence. GLM showed that per-row accounting and already-recorded timing data
  are cheap and useful. Codex withdrew those proposals. The final consensus
  removes permanent historical blockage and new experiments, not basic records.
- GLM also caught two refinements after the first debate: the provider matrix
  must record the actual governed/installed enabled-state evidence rather than
  misuse `config/reviewer-capacity.json`, and the plan's final historical-blocker
  sentence had to change with the main #398 gate. Both refinements landed in
  PR #471.

## 5. Root causes and key findings

- WSL was never a general development dependency. It appeared only because the
  former #271 gate required kernel-enforced outside-read and network isolation.
  Albert removed that gate; `docs/codex-windows-containment-2026-09-11.md` retains
  the measured limitation as history while its Remaining acceptance section
  defines the lean contract.
- The 198 maintenance candidates are evidence categories, not 198 known defects.
  The useful invariant is one accountable terminal row each. Reconstructing
  vanished evidence is impossible; leaving the entire programme permanently open
  because of it is waste. `plan_reviewer-reliability-and-efficiency.md` STATUS,
  Integrated acceptance, and final historical-closure text now agree.
- `config/reviewer-capacity.json` describes quota-interface capability, not the
  authoritative enabled reviewer set. #398 must record the governed allocation
  state and the installed configuration actually inspected in each matrix row.
- #333's no-tuning outcome is already accepted. Its three-pair/10-percent method
  applies only when a future candidate optimization is proposed; it is not
  outstanding work for #398.
- #164 already supplies a real injected-failure and recovery cycle. #166 still
  needs read-only live ruleset/bypass verification and a throwaway PR through the
  queue, but no new intentional ruleset failure.

## 6. Exact next steps

1. Start from fresh current `origin/main`; read `AGENTS.md`, this handoff, issue
   #271, and the STATUS plus #271/#398/delivery sections of
   `plan_reviewer-reliability-and-efficiency.md`. Re-resolve open PRs, runner
   activity, installed Codex identity, and current issue bodies. Gate: the task
   owns a clean isolated worktree, current main, and no competing #271 worker.
2. Complete reduced #271 qualification through the existing installed
   `ai-codex-review` path. Use a synthetic exact-head change with a known marker;
   prove marker/diff readability, attempted source-write refusal, sealed
   base/head/packet identity, and one substantive parseable verdict. Outside-read,
   network, WSL, and BIOS checks are not acceptance gates and must not be revived.
   Gate: exact hashes and terminal live evidence exist, with no invented BLOCKED
   verdict or unrestricted helper.
3. If #271 needs code or configuration changes, use reviewer-safety class,
   focused tests, current required CI, independent exact-head review, guarded
   merge, serialized installation, and installed recheck. If no change is needed,
   publish the live acceptance evidence without replaying unrelated green suites.
   Gate: intended source is on `origin/main`, installed behavior matches, and
   issue #271 closes with direct evidence.
4. Re-read both remaining plans through #159 and record drift. Then execute #398:
   retain the frozen round `0c62f3dffce145c4b2768855b912b958`, disposition all
   198 rows, use terminal evidence-unavailable for irrecoverable history, fill all
   nine adapter rows, make live calls only for adapters proven enabled, and run
   the bounded recurrence scan. Gate: counts reconcile to 198, enabled evidence
   is recorded per live row, disabled/unsupported rows made zero calls, and the
   maintenance completion contract succeeds.
5. Close #337 only after #271 and #398 have direct acceptance. Then execute #166
   last: read the live ruleset, record contexts/bypass/batch values, retain existing
   timing and no-overtaking evidence, cite #164's recovery proof, and run one
   throwaway PR through every required context and the merge queue. Do not inject
   a new live failure. Gate: required checks report, queue admission and merge
   succeed, recovery authority is verified read-only, and no stale context exists.
6. Reconcile plan STATUS, issues, evidence, and handoffs; close #159 only after
   every child and final measure is proven on `origin/main`. Gate: #271, #398,
   #337, #166, and #159 are closed in order with direct evidence and the active
   handoff is retired in the completion commit.

## 7. Constraints and gotchas in force

- Use an isolated current-upstream worktree. Canonical `C:/repos/ai-devops` is
  landing/installation-only. Stage exact owned paths; never reset, clean,
  force-push, or overwrite another task's work.
- Do not repeat delivered #397/#394/#393 work, PR2750 comparison, paid calls,
  unchanged green suites, or installed canaries. Recheck only volatile state and
  changed behavior.
- The strict #271 outside-read/network/WSL gate is retired by owner decision.
  Preserve source-write denial, sealed exact-head identity, substantive verdict,
  truthful failure evidence, and sandbox enforcement.
- Never shrink the nine-adapter matrix by disabling a provider. Preserve every
  historical row; disabled/unsupported status requires exact interface evidence.
- No shared database structure/data work belongs here. Production/cloud/ruleset
  mutations remain unauthorized unless Albert names the exact action; #166's
  agreed plan intentionally avoids a new live failure injection.
- Reviewer-safety code requires one read-only exact-head independent review.
  Use bounded event-aware CI waits and verify the landing on `origin/main`.
- At each phase end, re-read both plans through final #159 and record assumption,
  interface, identifier, authority, and evidence drift before advancing.

## 8. Access and environment

- Host: EDGE-DEV, Windows. GitHub CLI is authenticated as Albert's `u2giants`
  identity for `popcre/ai-devops`; Git committer identity was verified as
  `Albert Hazan <u2giants@users.noreply.github.com>` before both commits.
- Git Bash is `C:/Program Files/Git/bin/bash.exe`; call it explicitly from
  PowerShell. The installed Codex command was `codex-cli 0.153.2`; the desktop
  bundle also exposed `0.154.0-alpha.6.2`, while official stable was 0.154.0 at
  the live check. Re-resolve versions before any future qualification claim.
- Persistent GLM debate session: `reviewer-plan-simplification-20260915`, caller
  `codex`, provider/model `zai-coding-plan/glm-5.3`. Continue it only if this exact
  consensus needs clarification; do not create a duplicate session.
- Private reviewer records live under canonical
  `C:/repos/ai-devops/.ai/reviewer-issues`; ignored reports stay under `.ai/` and
  are never committed. Secrets use 1Password vault `vibe_coding`; no secret was
  read or changed here.
- The open shared-db orchestrator marker found at closeout was #2927, owned by a
  separate Claude session. This task did not touch shared-db, dispatch sub-agents,
  or hold a marker; do not interfere with #2927.

## 9. Open questions and risks

- #271's reduced live acceptance has not been run. Native sandbox read/write
  behavior was historically measured, but only a new substantive sealed
  exact-head review completes the revised contract.
- Concurrent work can move `origin/main`, issues, installed runtime, runners, or
  rulesets. Treat this handoff as history and refresh all of them before action.
- Older handoffs for issue #159 still describe WSL/outside/network denial as a
  blocker. They are historical, must not be edited, and are superseded on that
  point by merge `5a018e02`, the current plan, issue #271, and this handoff.
- No contracted handoff in `HANDOFF.d/` pointed to a closed issue at the closeout
  audit, so no stale file was eligible for retirement. Do not delete old #159
  handoffs merely because their active facts drifted; their dead ends remain
  unique history until the successor proves the retention conditions.

## Mandatory self-audit

1. **Could a brand-new developer continue without asking a question? Yes.**
   Sections 1–3 define the toolkit, sequence, exact merged commits, live issue
   state, and what remains; section 6 gives ordered actions with a verification
   gate for every step.
2. **Could they continue as effectively as this session? Yes.** Sections 4–5
   retain the failed runner/WSL route, the issue-edit trap, the Codex/GLM debate,
   the enabled-state distinction, and why each simplification changed.
3. **Are background, goal, state, failures, decisions, constraints, risks, next
   actions, and verification present? Yes.** Sections 1–9 each cover the named
   category; sections 3 and 6 carry exact commits, issue order, commands/paths,
   and measurable gates. No gap was found after rereading.
4. **Would Albert see every owner decision by reading only section 0? Yes.** A
   line-by-line sweep of sections 1–9 found only the two decisions already made:
   retired #271 isolation gates and approved lean #398/#166 closure semantics.
   Both appear in section 0 as settled and not to be re-asked. No new approval,
   choice, or judgement is hidden elsewhere.
