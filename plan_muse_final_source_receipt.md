# Muse final original-source receipt and completed-unrecordable disposition

## STATUS

Design only; implementation NOT authorized. Owner: `codex/muse-final-source-receipt-design`, edge-dev3; existing issue [#1783](https://github.com/popcre/ai-devops/issues/1783). Prospective prework was published before source edits in [6208585531](https://github.com/popcre/ai-devops/issues/1783#issuecomment-6208585531). Toolkit investigation baseline: `d03698f21e5794a969c241056299957e63956443`. Parent coordinator must inspect this concrete design, then independent technical design APPROVE and explicit coordinator implementation GO are required. No old review authorization is imported.

## 1. Ultimate goal

A completed review must reach the existing application delivery gate with truthful evidence of the exact original source reviewed. A paid review which completed but could not be recorded must retain its real result and spending, without trapping its owner forever or falsely authorizing delivery. If a step conflicts with this goal, the goal wins — stop and flag it.

This bounded repair is one incident lane within #1783, not closure of that programme or its separate elapsed reliability obligations.

## 2. Application and environment

`popcre/ai-devops` supplies protected reviewer wrappers and lifecycle accounting on Linux and Windows. `popcre/shared-db` is the consumer whose native allocator/start marker and durable verdict contract failed. Work is reviewer tooling, not database structure: no schema claim, migration, cloud or database access. Toolkit source targets main through a normal feature PR; any necessary consumer source targets shared-db main through its own tooling route. Install only through the exact-head reviewed protected procedure.

## 3. Trigger and preserved incidents

Coordinator [6208528838](https://github.com/popcre/ai-devops/issues/1783#issuecomment-6208528838) records shared-db PR4387, source `901ee416b7557b205dc728e7c6ac199a70b8996c`, slot1/sequence6603. Native Muse completed APPROVE with retained report `muse-final-check-20261016T050122-2704556-24013.md`; consumer refused the absent reserved `governed-source-44d122ce-bef5-46b9-b2ae-9459adb88e79.json`. The coordinator owns its original start marker, exact lease and private report/packet/spending proof. This plan does not copy those artifacts into public source.

Earlier same incident: existing hetz owner and PR4346/sequence6598, receipt comment6206797855. Their lease, worktree, reports and recovery are NOT adopted. Neither attempt may be replayed, given a past receipt, classified no-verdict, refunded or recorded as a successful durable consumer verdict.

## 4. Scope

IN: prospective original-source identity through the native Muse pool/core final packet; exactly-once immutable receipt from existing verification; offline trust-boundary fixtures; separately qualified native non-authorizing disposition of an owned completed-unrecordable assignment; existing round/cost/rotation limits; explicit live acceptance on #1783.

OUT: provider replacement, engine/model changes, permission reductions, test-child custody scrub changes, generic retrospective verdict import, manual receipt generation, refund or sequence reset, broad programme ownership, foreign attempt recovery, new credential calls, runtime implementation before design approval, cloud/database writes and production actions.

## 5. Current state and source evidence

Toolkit baseline above:

- `bin/ai-review-pool:170–229` uses shipped door registry and DIRECTLY execs the native engine with `--repo "$REPO_ROOT"` from ORIGINAL checkout. Registered Muse never reaches legacy snapshot/GLM root-routing branches. Those legacy lines must NOT be changed for this defect. Legacy tests-child scrub384–406 also remains correct.
- `tools/lib/review-lifecycle-core.sh:500–535` receives the ORIGINAL repository from native pool dispatch, resolves exact original identity and creates one final review snapshot. At260–284 preparatory verification deliberately unsets receipt; this prevents premature publication before qualified completion.
- `tools/lib/review-doors/muse.sh` consumes `DOOR_PACKET_DIR` directly and never builds or verifies a separate final packet or publishes the original-source receipt.
- `bin/ai-review-packet:444–555` validates original source, comparison, snapshot provenance, head and digest; `publish_receipt()`560–579 creates immutable exact identity/packet-hash bytes, refuses linked/outside/unignored/conflicting paths. `cmd_verify()`1077–1124 validates all evidence then calls that writer. Reuse it; do not hand-roll JSON.
- Core report checks640–733 validate native completion, snapshot stability, substantive full-head verdict and unchanged source; durable packet storage precedes lifecycle finish/cleanup737–755.
- Existing GLM legacy source routing and PR1798 are separate. Their pool/packet changes must not be adopted, duplicated or modified by this repair.

Consumer investigation uses retained upstream ref `e241459ab805a1219b76534d425741e1f87fa44c` (refresh before implementation): `scripts/run-governed-review.mjs` reserves receipt and start before spawn, then validates it before durable verdict; `validateSourceReceipt()` requires exact physical original root/head/base/digest and packet hash. `scripts/lib/lanes/review-replacement.mjs:62–72` requires both no-verdict and no-artifact; `releaseFailedReviewer()` in `scripts/manage-migration-author-lanes.mjs:2739` applies that failure-only path. It is inapplicable to these completed attempts. No existing supported truthful disposition was found. `scripts/lib/lanes/review-circuit-breaker.mjs:12–40` conservatively charges any decision and reinstates only specific exact verdictless failures. The new disposition must leave those failure lists and paid-start accounting unchanged.

## 6. Findings and remaining proof

The preparatory packet is correctly prevented from claiming the final receipt, but native Muse uses that packet as its actual final review input and has no corresponding final publication. Original physical source identity is ALREADY correct on the registered Muse route. The defect is missing final publication, not source routing. Removing preparatory unset would publish too early. No pool, packet writer, identity resolver or door edit is needed.

A receipt validates source evidence; it is not a provider verdict or delivery authorization. Existing consumer rejection must remain until a new genuinely allocated attempt passes all current gates. The old completed report remains real, spent and non-authorizing.

The actual source/packet/start/lease custody for6603 must be independently inspected privately before disposition can qualify. Its existence in a chat message is insufficient. If exact qualified proof or a round remaining cannot be established, recovery is BLOCKED; prospective repair can still land independently.

## 7. Rejected approaches

- Undoing tests-child scrubs: leaks host custody into commands under review and does not repair final publication.
- Removing preparatory receipt unset: claims the destination before final source/packet identity is qualified.
- Writing receipt from report text or reconstructing old receipt: fabricates missing past evidence.
- Existing failure/no-verdict release, pause, refund or unstarted reclaim: contradicts real paid completion and terminal APPROVE.
- Recording/importing old APPROVE after repair: retroactively authorizes an unrecordable attempt.
- New replacement session without disposing exact lease, foreign custody takeover, resetting allocation/round limits or rerunning spent authority: forbidden.

## 8. Locked technical design and decisions

A. Preserve existing native pool dispatch EXACTLY. `bin/ai-review-pool:170–229` already supplies original physical repository to the registered Muse engine. Core resolves original identity515–522 before snapshot creation530–535. No new root hint, nested snapshot, source-routing environment, pool branch, packet-schema change or door behavior is introduced. Verify this existing flow in an end-to-end offline fixture.

B. Preserve preparatory verification and all tests-child custody scrubs unchanged. Native Muse door consumes the core packet directly; this same packet is its final reviewed input. Core alone owns source identity, final validation, publication and accounting. No model/tool or door may select a receipt path or publish one. Other providers, standalone wrappers, implementation and code-only exports retain their existing behavior.

C. Keep preparatory verify non-publishing. After successful native Muse completion, full report validation and original/snapshot stability checks, but BEFORE durable lifecycle success/cleanup, verify the SAME provider-consumed packet through existing `ai-review-packet verify --identity`, with the reserved destination deliberately available. Publish only this final packet identity/hash; do not rebuild a packet after the provider ran. Store packet before cleanup; receipt hash must equal stored packet hash. Source move, failed completion, packet drift, store failure or publication failure retain original evidence and refuse success. Existing identical receipt is idempotent; unequal or linked destination refuses. Receipt side effect alone never creates an accepted verdict.

D. Consumer recovery is a NEW native disposition, distinct from failure/replacement and verdict namespaces. Proposed CLI name: `--dispose-completed-unrecordable-review`; precise spelling may follow consumer conventions, semantics locked. First default dry-run validates proof without mutation/provider call. Qualified reason is exactly `completed-unrecordable-missing-source-receipt`, `authorizing:false`, `paid_attempt_consumed:true`; observed verdict is retained as a fact, never a review approval record. Supports either actual terminal APPROVE or REJECT if all evidence otherwise qualifies; does not erase a REJECT or grant a replacement on a rejected business/code issue.

E. Qualification requires exact issue/PR/fullhead/slot/provider/assignmentsequence; original durable start marker and current exact held lease; existing protected private terminal lifecycle/native completion/report/durable packet/identity hashes; original reserved receipt-path binding from start marker; missing destination ONLY, not conflicting/wrong receipt; wrapper/lifecycle identity and completion proven; report substantive/head-bound; owner identity/root custody; unchanged source. Require bounded regular private files, no symlink/path escape, duplicate/unknown JSON keys or ambiguous candidates; no operator-supplied hashes as substitutes. No scanning arbitrary host paths. Do not publish private paths, report bodies, prompts or credentials; immutable public record carries only sanitized tuple, proof digests and non-authorizing outcome.

### Actual available ownership and custody fields — no invented chat identity

The inspected native source contracts expose the following, not proof that all are retained for6603:

- Consumer `recordReviewStart()` records issue, PR, full head, slot, sequence, reviewer, timestamp; optional `session` (native pool may be `-`), SHA256 of reserved receipt PATH and source digest. `io.makeOwnerCommit` records the configured Git author; shared repository write identity is NOT cryptographic Codex chat identity. The start marker has no chat ID or physical-root field.
- Allocator held lease is the exact issue/PR/head/slot/sequence/reviewer assignment and immutable ref/commit binding. It does not by itself prove which current chat may dispose it.
- Native lifecycle captures original repository root/key/upstream, provider, run ID, caller ENGINE label, head/source digest, status/result, report/packet references and hashes; optional owner PID/start identifies a process while live, not an authenticated chat after exit. Caller `codex` is not a unique chat ID. Packet identity supplies original physical root, comparison and digest. Protected files establish filesystem custody; same-user sessions are not cryptographically isolated.
- Coordinator retained report/start/packet/spend pointers for6603 require actual private readback and exact linkage. This design has NOT inspected that private bundle and cannot assert a pre-existing actor token or unique chat binding. Printed chat signatures, a supplied path/hash, common Git author, PID guesses, root/receipt-path equality or possession alone cannot manufacture missing original ownership.

Implementation must first enumerate existing native assignment/session ownership and authorization guards from fresh consumer source and the actual original artifacts. Reuse ONLY a real pre-existing qualifying mechanism. If existing native policy cannot establish that THIS caller is authorized to dispose exactly this assignment, dry-run MUST REFUSE `ownership-unproven`; no retroactive token, chat assertion, actor field, manual acknowledgment or common GitHub credential may replace it. Independent reviewer must judge this limitation explicitly; recovery may remain blocked even when prospective receipt publication is complete.

F. Under EXISTING review mutex/request budget, reread all bindings, create immutable disposition evidence, then release ONLY still-matching owned lease using existing exact guarded ownership mechanism. Never blindly delete a ref or touch a replacement/new occupant. Crash after evidence before release can resume by exact record and current matching lease; crash after release returns idempotent completed disposition, no second release. A changed/missing foreign lease refuses before mutation. Receipt appearing between validation/mutation refuses and preserves evidence. Original start/assignment/report/packet and spend remain intact.

G. All allocator/continuation consumers recognize disposition as terminal NON-AUTHORIZING. It does not become a failure/replacement credit, refund, unstarted reclaim, provider pause, roster change, durable verdict, approval, accepted review or budget reset. Original paid attempt remains counted. Only after prospective fix is installed and independently verified may the normal allocator allocate ONE fresh attempt, IF existing head/slot round limits, capacity, rotation and cost limits permit. No hardcoded reviewer or bypass. Allocation/start uses its normal new sequence/lease. If existing policy has no remaining round, report blocked; do not expand limit. Preserve another slot's genuine verdict without rewriting it.

Coordinator decision is needed on this concrete design BEFORE paid review. Independent reviewer must explicitly assess whether D–G are safely representable under current consumer accounting; unsupported semantics remain blocked, never inferred from a technical APPROVE on A–C.

## 9. Ordered implementation and acceptance

1. Refresh toolkit/consumer canonical upstream, current #1783/PR1798 ownership and exact consumer source. Consumer belongs under existing [shared-db#4297](https://github.com/popcre/shared-db/issues/4297), whose existing original owner is Codex chat01a13b6d-f095-72f1-ab6b-fce664912065; do NOT adopt their broader repair or immutable generation1. Before ANY shared-db source edit: read its current AGENTS/router, current #4297 comments/owner, open PR files and fresh main; publish signed bounded successor ownership on SAME card, reconcile any active overlapping owner, select an unused own generation from current immutable contract refs, publish proper OWN repo-maintenance/reviewer-tooling prework contract to `refs/db-contracts/4297/<generation>` before implementation, and use `.agent/work/4297/<generation>/{contract,completion}.json`. Follow `docs/agents/agent-work-contract-repo-maintenance-evidence.md`; no structural claim. An occupied generation or unreconciled owner refuses. Toolkit own prework remains #1783. Gate: fresh collision inventory, own published contract readback and exact source before edits; no foreign worktree/contract mutation.
2. Add only C Muse-qualified final publication in `tools/lib/review-lifecycle-core.sh`, reusing existing `bin/ai-review-packet verify` unchanged. Preserve pool dispatch, door/native completion parser, credential boundary and every preparatory/test scrub. Gate: real offline native pool/core tests prove already-correct original root, final packet hash and immutable destination; all previous provider tests pass. No current overlap with PR1798 runtime paths.
3. Add recovery validator and CLI in consumer `scripts/run-governed-review.mjs` and existing lane entrypoint; isolate logic in `scripts/lib/lanes/review-completed-unrecordable.mjs` only if it avoids bloating established modules. Add distinct disposition constant/parser and narrowly update assignment/lease/allocation/recording readers. Never extend `TERMINAL_FAILURE_CODES`. Gate: proof-to-owned-lease tests and crash/race fixtures; no old verdict can record or refund.
4. ORDER: implement/review/merge toolkit final-receipt repair FIRST, through its existing native independent source-review route, then protected install with exact merged-head approval. This review does not recover or authorize old6603. Verify installed new receipt behavior in native offline fixtures before any consumer recovery. Only THEN implement consumer disposition under its own prepublished4297 generation and obtain its normal exact-head governed reviews/CI/merge. Both code PRs require Muse review as owner requested. Never run unreviewed consumer code to release the lease that blocks its own review. If held Muse6603 prevents required consumer review, establish an EXISTING supported independent admission route without releasing/replaying/spending old authority; if none exists, record concrete circularity BLOCKED for coordinator/independent reviewer. No ad-hoc roster change, lease deletion, out-of-rotation substitution, manual verdict or new reviewer exemption. Consumer code cannot exercise disposition until its normal merged-source gates qualify. Gate: source, merge, install and consumer delivery recorded separately; actual independent admission and paid-start counter checked, no self-authorizing recovery.
5. Privately inspect coordinator6603 proof with no provider dispatch. Run new disposition dry-run. If qualified, coordinator chooses exact reviewed native action; preserve reports/start/packet/spend. Then normal newly allocated review under unchanged limits, NOT replay. Gate: old record non-authorizing/consumed, exact lease released, one fresh sequence and genuine terminal receipt/durable verdict. Foreign6598 stays untouched.
6. Record actual cold/warm/fresh-process acceptance and live result on #1783. Keep wider recurrence acceptance/observation/other owners open. Gate: new native original-source receipt passes unchanged `validateSourceReceipt`, durable verdict and delivery gates; source/receipt/packet hash chain exact.

### Adversarial cases (mandatory named fixtures)

| Input | Hostile or ambiguous condition | Required test |
|---|---|---|
| Existing source route | Original root vs snapshot confusion, symlink, snapshot marker/head/digest mismatch | `muse_existing_original_source_identity_preserved` |
| Source comparison | Head/base/digest move before or after provider; legitimate forward target ref | `muse_final_receipt_source_race` plus existing forward-ref tests |
| Packet | Prep vs consumed final, changed manifest/parts, mismatched identity, store failure | `muse_receipt_only_final_consumed_packet` |
| Receipt | Exists equal/unequal, linked parent/file, outside/nonignored directory, late creation | `muse_final_receipt_immutable_destination` |
| Provider | Nonterminal/tool-calls/failed/empty/stale report | `muse_no_receipt_on_unqualified_completion` |
| Tests | Attempts to read receipt/root/door routing | `muse_tests_cannot_claim_source_receipt` |
| Recovery proof | Missing/ambiguous/malformed/native nonterminal, forged report, stale hash/source | `completed_unrecordable_requires_original_proof` |
| Ownership | Foreign6598, wrong actor/slot/provider/sequence, advanced lease, concurrent owner | `completed_unrecordable_exact_owned_lease_only` |
| Atomicity | Crash before record, record-before-release crash, retry, post-release new occupant | `completed_unrecordable_disposition_crash_races` |
| Authorization | APPROVE/REJECT observation used as verdict/refund/replacement credit | `completed_unrecordable_never_authorizes_or_refunds` |
| Accounting | Spent maximum round, duplicate new allocation, other slot verdict | `completed_unrecordable_preserves_round_limits` |
| Files | Linked/oversized/permissive/duplicate-key proof, host path escape, output disclosure | `completed_unrecordable_private_proof_custody` |

## 10. Required tests

Toolkit: extend `tests/test-ai-review-engine.sh` and focused native core fixtures; retain existing `tests/test-pool-dispatch-doors.sh`, `tests/test-ai-review-lifecycle.sh`, `tests/test-ai-review-packet.sh`, GLM pool and provider terminal/model/permission suites. Existing packet writer tests need not change if unchanged writer already covers its boundary; new end-to-end fixtures exercise it directly. Actual native fixture must exercise pool→core→Muse-door stub→existing packet verifier with two distinct physical roots; unit test of a root string is insufficient. Existing public/code-only/private boundaries remain strict. No paid provider calls in fixtures.

Consumer: extend `scripts/run-governed-review.test.mjs`, lane focused tests and allocator/replacement/lease suites. Use `node --test` through current repository supported runner after router verification. Tests inject only established I/O boundaries, never production runtime bypass environment switches. All negative rows above need real assertions. Preserve current completed-but-unrecordable refusal as a regression until new explicit disposition is called.

Before final review run required source checks and exact digest/head assertions. Full host-suite collisions must be reported honestly; no invented passing result or disabling host protection.

## 11. Constraints and ownership

No live credentials/provider action during design. No permissions, reviewer roster, paid limit, structural safety, secret boundary or completion contract weakening. No recovery of unowned6598. Existing1798 owns pool/packet changes; this lane deliberately leaves both untouched and changes core/tests only. Refresh collision check before implementation; preserve their GLM route. No broad #1783 completion claim. Public notes signed; human-facing times EDT/EST. Runtime change/source review cannot be mistaken for installed/live success.

## 12. Access and environment

Owned toolkit worktree `/home/ahazan/.codex/worktrees/muse-source-receipt-design/ai-devops`; baseline as STATUS. Existing `ai-gh` read/comment access and native gate available. No secrets needed for design/offline tests. Privately retained6603 proof belongs to parent coordinator; do not locate/read/copy protected material without that bounded handoff. Protected review/installation/consumer operations remain separately gated. Normal fetch/readback precedes later current-source implementation.

## 13. Landing, closeout and exact remaining ledger

Design-only source can be committed for independent review; no runtime implementation, push/PR, install, allocation, lease mutation or paid implementation until coordinator authorizes that stage. Independent plan reviewer must give technical verdict on BOTH prospective publication and truthful disposition, with high/medium defects addressed before code. Specifically audit: actual remaining unchanged-content paid-start counter and conserved6603 start, exact held lease → disposition → next NORMAL draw semantics, unprovable chat ownership refusal, both-repository implementation/install ordering, and any circularity of requiring a consumer review while Muse6603 remains held. Do not treat architecture approval as proof the concrete incident qualifies.

Checklist on SAME #1783:
- [ ] Independent design APPROVE and coordinator implementation GO.
- [ ] Exact-head toolkit/consumer tests and native source review; normal merge.
- [ ] Protected installed versions verified.
- [ ] Exact private6603 qualification or explicit proof blocker; foreign attempts unchanged.
- [ ] Non-authorizing old disposition with consumed accounting and exact owned release.
- [ ] One normal fresh allocated attempt within unchanged limits, original-source receipt and durable verdict proved live.
- [ ] Wider #1783 owners/observation retained; do not close programme from this lane.
