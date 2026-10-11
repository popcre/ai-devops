---
issue: 658
status: OPEN
owner: mimo/658-request-reduction-native-fleet
---

# #658 request reduction: native qualification done, fleet install in progress

Continuation of the October 8 closeout (`HANDOFF.d/2026-10-08T1719Z-edge-dev3-codex-request-reduction-closeout.md`)
and the October 9 session that staged the counter on 916 and recorded the
native-qualification disposition. Coordinator this session: MiMo chat on
edge-dev. Accountable until handoff acceptance. No shared database was changed.

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner.

Technical approvals, access recovery, reviewer allocation, and evidence
collection are AI-coordinator obligations gated by assigned AI reviewers.
Already settled and not to re-ask:

- 2026-10-07: subagents and concurrent independent lanes authorized; whole
  programme live acceptance required.
- 2026-10-08: wrap-up freezes new scope and requires safe continuation state.
- 2026-09-28: "never ask a human to approve" — technical actions go to an
  assigned AI reviewer, not Albert.
- 2026-10-09: cold-overhead gate amendment approved under locked re-measure
  rules (independent adjudication); telemetry parity is UNKNOWN, not a defect.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow. It is not an app, service, or deployment pipeline. Installers
distribute managed AI tools across Albert's Linux and Windows machines.
GitHub is the source of truth. Installation is deployment. Issue #658 reduces
GitHub reads and duplicate writes while preserving wake, alarm, dependency-link,
queue and review behaviour, then proves the reduction with measured section 13
acceptance.

Repos and hosts:

- `popcre/ai-devops` — this repo, canonical checkout `C:\repos\ai-devops` on
  edge-dev (landing-only), also `/home/ahazan/repos/ai-devops` on edge-dev3.
- edge-dev3 (`192.168.3.42` / `100.66.9.69`, Linux, user `ahazan`) — where the
  658 worktrees, private state, and runner repairs live.
- 916 / 916-ALIEN (`10.0.5.55` / `100.110.219.31`, Windows, user `ahazan2`) —
  native counter staging target.
- edge-dev, 4837/al8960ofc, edge-alien, edge-runn-envy — Windows fleet peers.
- hetz VPS — production (read-only by default). t16/albt16 — required fleet
  coverage with no trusted management channel.

## 2. What we set out to do this session, and why

Continue issue #658 from the October 8 handoff through tested delivery,
guarded installation, live verification and measured acceptance.

Specific objectives this session:

1. Land duration PR 1510 and counter PR 1511 (both were open at prior closeout).
2. Rebind and approve a native staging tuple, then stage the experimental HTTP
   counter on 916 under fail-closed controls.
3. Run native qualification and record a disposition for the cold-overhead gate.
4. Start fleet installation (inventory, then edge-dev3 refresh).

Trigger: Albert's resume prompt asking to continue #658, then "did they land?",
"who's working on what you're waiting on?", "dotfiles-sync-install is done on
916", "spin up a subagent for attempt-three", "so decide", "have a subagent do
native qualification", and finally `/wrap-up`.

## 3. Current state — what is true right now

### Landed on origin/main (verified)

| Outcome | Commit / proof | When (EDT) |
|---|---|---|
| PR 1511 counter PS5 fix | `2ed3c24b9eb4d0e0221ffb0ec70000335d0e2106` | Oct 8, 6:07 PM |
| PR 1510 duration evidence | `1861259dfa243ebe25f1b984b43d1f2a44bcd8c4` | Oct 8, 8:16 PM |
| PR 1561 cold-gate amendment | `bb3700fe92f6bc4609e675dc756192d99a558ca1` | Oct 9 |
| PR 1522 prior closeout docs | merged before this session | Oct 8 |

### Native staging on 916 — DONE

- Stage: `C:\Program Files\ai-devops-gh-counter-d9de3387eebc4f5896cd89897723af5f`
- Numeric receipt: `{"schema":1,"staged_files":13,"executed":false,"installed":false}`
  then helper ran (`executed=true`, `installed` stays false).
- Poststage digest/ACL: 13/13 hashes PASS; owner SID
  `S-1-5-21-1517438468-946630668-2521513353-1001`; protected ACL (owner /
  SYSTEM `S-1-5-18` / BA `S-1-5-32-544` only); no reparse. Evidence:
  `~/.local/state/ai-devops/658-916-poststage-verify-attempt7.private.txt` on
  edge-dev3.
- Approved tuple (Grok attempt7b): packet `993c7921d003967c135296a0fe82ed9867a91da23381044897ba9eeb53d166c6`,
  bootstrap `7e47da041c10402873f7729059ca5ded9990362f1a2885901f9362530db8dc72`,
  driver `043937a0ee20f0a8b3255b204c6587caa124b3e0cfbbc1264d1448b236b3eabd`,
  source head `65091d6fdf3c64fe2fc2c4fd4a815f431d1f5447`.
- Exclusive log `658-916-native-staging-execution-attempt7.private.log` consumed
  once. Do not reuse.

### Native qualification — RUN, disposition RECORDED, not fleet install

- Receipt: `658-916-native-qualification-receipt.private.json`
  SHA256 `f45306de44471739f4a394c9ee136cb219bec2933a895feac4380b98a31aa199`.
- Passed: console/cancel, 3 standard handles, 7 environment sentinels,
  9 filesystem boundaries (incl. junction retags), 20 cold + 20 warm pairs,
  9 source + 3 pin bindings, no network during fixture.
- Telemetry parity: **UNKNOWN**. Fixture endpoint `127.0.0.1` is treated as
  enterprise by upstream gh, which suppresses telemetry by design. Not a
  counter defect, not zero. Future telemetry cases must use `http://localhost`.
- Cold sum at N=20 failed (1.1255) on startup spikes while cold p95 passed.
  Bounded N=40 cold-only re-measure: paired both-non-spike ratio 0.978,
  full-set p95 0.227, candidate spikes 0 vs baseline 5. Independent
  adjudication APPROVES amendment under the locked rules.
- Amended gate (recorded in plan STATUS via PR 1561): p95 ≤ 1.05 on the full
  set; sum ≤ 1.05 on paired samples ≤ 200 ms; admit at most one extra candidate
  startup spike.
- `native_execution_complete:false` in the validator because of the two misses
  at run time; the disposition above is the programme acceptance for that run.

### Fleet installation — inventory DONE, edge-dev3 refresh IN FLIGHT

Readiness file (edge-dev3):
`~/.local/state/ai-devops/658-fleet-install-readiness-20261009.private.md`
SHA256 `c6217cbf9dcb8b0d190d49d3496587272225c99180b7f89cdc250566282e29e0`.

| host | reachable | full receipt | install needed |
|---|---|---|---|
| edge-dev3 | yes | YES (behind main) | refresh to `bb3700fe` — **IN FLIGHT subagent general-13** |
| edge-dev | yes | no (0 stage-reports) | full Windows install |
| 4837 / al8960ofc | yes | no | full Windows install |
| 916 / 916-ALIEN | yes | no (counter ACL staged only) | full Windows install |
| edge-alien | yes | no | full Windows install |
| edge-runn-envy | yes | no launcher | largest gap; guarded refresh |
| t16 / albt16 | **no trusted channel** | no | **BLOCKED external** |
| hetz VPS | yes | YES (behind main) | production-class refresh |
| synology 1/2 | host key fail | n/a | not managed-caller |

### Section 13 acceptance — OPEN

Every section 13 obligation remains unproven as a whole. Missing values are
UNKNOWN, never zero. Historical aggregate (1,478 outcomes / 1,351 GraphQL
points / 224 unqualified duration rows) is not a comparable baseline. Do not
manufacture demand or historical evidence.

## 4. Everything we tried that did NOT work

1. **Empty counter worktree (twice).** `/home/ahazan/.codex/worktrees/658-counter-qualification-oct8/ai-devops`
   was emptied after the Oct 8 closeout and again mid-session. Commits were
   safe on `codex/658-counter-qualification-oct8` and in
   `658-counter-wrap-up-unpublished.bundle`. Recreated with
   `git worktree add`. Watch for this; something in the environment removes
   worktrees.
2. **Attempt2 staging timeout (180 s).** Bootstrap used
   `$input=[Console]::In.ReadToEnd()` on a ~129 MiB JSON stdin. Hung on 916
   as PID 13780. Stage never created. `child.kill()` orphaned the remote
   elevated PowerShell. Recovery needed a Grok-approved kill.
3. **Attempt3 REJECT.** Reused the hangy bootstrap. Grok refused to authorize
   another host write against a known-hung stdin design.
4. **Attempt4 REJECT (six bugs).** Dropped fail-closed guards, missing `bytes`
   on packet files, user-profile Temp, copy-then-Set-Acl, 0664 sources, scp
   before exclusive log.
5. **Attempt5 staging fail.** PowerShell `-Command` with pipes over Windows
   SSH is split by cmd.exe (`'Out-Null' is not recognized`). Setup ran via
   `powershell -File` in attempt6+.
6. **Attempt6 REJECT (three bugs).** Payload-root name mismatch
   (`658-gh-counter-…` vs `ai-devops-gh-counter-…`), mkdir still used
   `-Command` pipes, unhashed `/tmp/setup6.ps1`.
7. **Attempt7 REJECT (one bug).** `SETUP_SHA` pinned the LF-normalized digest
   while the on-disk file is CRLF. `verified()` hashes `read_bytes()`. Pin the
   raw on-disk digest.
8. **My telemetry diagnosis was wrong.** I inspected *system* gh 2.88.1 and
   reported it lacked `GH_TELEMETRY_*`. The staged image is paired gh
   **2.101.0** which does have telemetry; the real cause is
   `telemetryDisablerTransport` on non-github.com hosts. Do not reuse the
   2.88.1 finding.
9. **Cold-sum gate miss at N=20.** Outlier-sensitive: one extra ~250 ms
   process-startup spike. p95 was faster. N=40 re-measure reversed the spike
   imbalance (cand 0 / base 5).
10. **task-gates deploy for native staging.** `install` class forbids `deploy`;
    `ship` is the allowed action. `--reviewer-approval` must be a
    lifecycle-recorded `ai-review` report at the *exact* report path the
    lifecycle stored (worktree moves break the binding — restore the path or
    re-run the review).
11. **DeepSeek action reviews were slow/fragile** (sandbox cannot see
    `~/.local/state`, turns stall on tool loops). Grok completed reliably for
    action and recovery reviews.

## 5. Root causes and key findings

- Windows PowerShell 5 fails byte-backed enum `-band` (`AceFlags`). Fix is
  `[int]` casts on both operands (`native_fixture.ps1:46`). Shipped in PR 1511.
- Unframed `ReadToEnd` of a large JSON stdin over SSH hangs when the client
  times out; the remote process is orphaned. Fix: scp files first, one tiny
  manifest line on stdin, pin setup script hash, open exclusive log first.
- Windows SSH + `powershell -Command` + pipes is split by cmd.exe. Use
  `powershell -File` or `-EncodedCommand`.
- Always pin SHA256 of **on-disk** bytes (CRLF), never a normalized digest.
- `ai-task-gates` same-source toolkit install needs installed checkout +
  launcher paths and a lifecycle-recorded APPROVE at the exact `report_path`.
- Independent spike-excluded sums are confounded when spike counts differ;
  paired both-non-spike is the correct overhead metric.
- `gh` suppresses telemetry when the request host is not `github.com` /
  `localhost` (`go-gh` `IsEnterprise`). Use `http://localhost` in fixtures.
- Full required receipt lives at `task-gates/install-stage-reports/<sha>.tsv`.
  Launchers alone are not a full receipt. Windows peers have `ai-gh-wait`, not
  `ai-pr-wait`.
- T16 remains the only hard external blocker: Tailscale online ≠ trusted
  management route. No port scan / key substitution / trust replacement.

## 6. Exact next steps

1. **Confirm edge-dev3 install refresh (in flight).** Subagent `general-13` is
   running `authorize-install` / stale-manifest recovery on edge-dev3 toward
   `bb3700fe`. Collect its receipt under
   `task-gates/install-stage-reports/` and the proof file
   `658-edge-dev3-install-refresh-20261009.private.md`. If it is still running
   at handoff read time, check its status before starting anything else.
   Gate: fresh full required receipt PASS at the target head; managed launchers
   and `ai-gh`/`ai-pr-wait` work; wake/alarm/queue/review unbroken.
2. **Windows full installs** in this order, one host at a time, installation
   class + assigned AI reviewer APPROVE + `authorize-install`:
   edge-dev (launcher drift `2032b678` vs checkout), 4837, 916 (resolve D: vs
   C: checkout split first), edge-alien (clear Runner.Worker collision first),
   then edge-runn-envy (root-owned guarded refresh; largest gap).
   Gate: 100% of reachable managed callers have full required receipts.
3. **VPS refresh** as production class with exact-action reviewer APPROVE.
   Never a manual production command.
4. **T16** stays `Blocked —` until a trusted elevated channel exists. Do not
   invent a substitute, do not exclude the host, do not mark fleet complete.
5. **Section 13 measured acceptance** only after fleet coverage is real:
   complete network-path disposition; 50% fewer redundant reads and zero
   duplicate unchanged writes; 30% fewer actual managed HTTP and GraphQL
   points separately per equivalent completed outcome; two genuinely busy
   comparable reset windows with 20% headroom; ≥20 comparable useful workflows,
   no missed safety events, p95 within 5% (use the amended cold gate from
   PR 1561); observer overhead ≤5%; five-minute waiter and ten-minute
   BlockerWatch ceilings. If a target is unattainable under genuine demand,
   obtain independent review of a measured lower bound before amending.
   Gate: every requirement measured; UNKNOWN never counted as zero; then close
   #658 and remaining children.

## 7. Constraints and gotchas in force

- Every GitHub call through `bin/ai-gh`. Bounded waits (`bin/ai-pr-wait` with
  `--timeout-minutes`). No `gh run watch`. At most one GitHub call every 5
  minutes per waiter.
- Never direct-push `main`, admin-merge, force-push, delete unique evidence, or
  weaken required CI. Documentation-only PRs merge via the normal queue
  without waiting for checks.
- Declare task class (`ai-task-gates start`) and `check --before` reviews,
  shipment, installation, infrastructure. `installation` class forbids
  `deploy`/`infrastructure`/`production`; use `ship`.
- In-rotation reviewer engine must differ from the implementer. GLM paid-balance
  hold is not a retry candidate. Never retry a reviewer out of rotation.
- Serialize credentials, reviewer allocation, merges, and host writes.
- Preserve all 658 worktrees, unpublished commits, failed receipts, and
  `.pre-rebind-bak` / `.history-*` files. Do not overwrite exclusive logs.
- Private memory updates require direct owner authorization. Never copy
  private routes or raw telemetry into the public repo.
- Human timestamps in America/New_York with EDT/EST labels.
- Sign GitHub posts with `Posted by MiMo chat <id> on <machine>` (or the
  session's actual agent name).
- Worktree source files reset to 0664 on fresh checkout; driver `verified()`
  requires 0644 — chmod and journal before running a driver.

## 8. Access and environment

- GitHub via the existing managed caller (`bin/ai-gh` / `bin/ai-gh-app-auth`).
  Credentials only in 1Password vault `vibe_coding`. Never in files, argv, or
  chat.
- SSH from edge-dev3: aliases `916`, `edge-dev`, `4837`/`al8960ofc`,
  `edge-alien`, `edge-runn-envy`, `hetz`, `edgesynology1/2` in
  `~/.ssh/ai-devops.conf`. t16 has **no** alias.
- Private state on edge-dev3: `/home/ahazan/.local/state/ai-devops/` (packets,
  bootstraps, drivers, receipts, proofs). Worktrees under
  `/home/ahazan/.codex/worktrees/658-*`. Main repo
  `/home/ahazan/repos/ai-devops`.
- Reviewer wrappers: `ai-grok-review`, `ai-deepseek-agent`, `ai-review`.
  Grok sessions under `~/.local/state/ai-devops/grok/`. If a Grok review dies
  mid-cleanup: `ai-reviewer-issue evidence reconcile-lost grok <sandbox> <reason>`.
- Machine atlas: `ai-private-config path machine_atlas` (private repo
  `u2giants/ai-devops-private-config`).

## 9. Open questions and risks

- **T16 trusted surface** (hard external). No management route. Do not scan,
  do not substitute trust. Blocks 100% fleet coverage until resolved.
- **edge-dev3 install refresh** may still be running when this handoff is
  read. Verify before assuming receipt exists.
- **Windows full receipts** are the bulk of remaining fleet work; each needs
  reviewer APPROVE and idle hosts.
- **Section 13** cannot start until fleet attribution is real. Do not infer
  savings from source or from the 916 stage alone.
- **Worktree empties** on edge-dev3 under `~/.codex/worktrees/658-*` have
  happened twice; treat as an environment hazard and re-add from the branch.
- **Cold-sum amendment** is recorded in plan STATUS (PR 1561). Do not quietly
  weaken any other gate; if a later run contradicts the amendment, re-open
  with evidence.
- **Telemetry UNKNOWN** must stay UNKNOWN in acceptance math.

## Part B. Subagent closeout records

| id | task | outcome | next |
|---|---|---|---|
| general-1 | attempt3 rebind + action approve | partial — tuple prepared; Grok REJECT (hangy bootstrap) | superseded by attempt4–7 |
| general-2 | attempt4 action approve | blocked — Grok REJECT six bugs | superseded |
| general-3 | attempt5 hang-fix + guards | success — APPROVE; staging later failed on cmd pipes | done |
| general-4 | attempt6 action approve | blocked — three bugs (path, pipes, unhashed setup) | superseded |
| general-5 | attempt7 action approve | blocked — CRLF vs LF SETUP_SHA pin | fixed as attempt7b |
| general-6 | attempt7b approval | success — APPROVE; used for staging | done |
| general-7 | native qualification on 916 | partial — helper ran; cold sum + telemetry misses | disposition recorded |
| general-8 | cold-sum bound + telemetry review | success — telemetry UNKNOWN; re-measure required | done |
| general-9 | cold-only 40-pair re-measure | success — AMEND recommended | done |
| general-10 | rule interpretation | success — AMEND under locked rules | done |
| general-11 | plan amendment PR | success — PR 1561 merged `bb3700fe` | done |
| general-12 | fleet readiness inventory | success — readiness file saved | done |
| general-13 | edge-dev3 install refresh | **still running at wrap-up** | collect receipt |

None of these subagents held merge, production, or security decision
authority. Coordinator retained those.

## Completeness self-audit

1. Newcomer continuation: YES — §1–3 define purpose, landed commits, stage
   state, qualification disposition, fleet table; §6 is ordered with gates.
2. Same effectiveness: YES — §4 preserves every dead end (worktree loss,
   hang, six/three/one-bug REJECTs, cmd pipes, CRLF pin, wrong gh binary);
   Part B distinguishes coordinator decisions from agent prep.
3. Relevant details: YES — §3/§6–9 cover hashes, receipts, blockers, access,
   and UNKNOWN-vs-zero. Private payloads stay on edge-dev3.
4. Owner decisions: YES — sweep found no business-meaning question. §0
   explicitly says None; no technical approval is diverted to Albert.

## Next-session prompt

Resume popcre/ai-devops issue #658 as coordinator. Read this handoff and the
Oct 8 closeout. First check whether subagent general-13 finished the edge-dev3
install refresh (`658-edge-dev3-install-refresh-20261009.private.md` and
`task-gates/install-stage-reports/`). Then do the Windows full installs one
host at a time (edge-dev, 4837, 916, edge-alien, envy) with installation
class + assigned AI reviewer APPROVE + authorize-install. T16 stays blocked
until a trusted channel exists — do not invent one. After 100% reachable
coverage, run section 13 measured acceptance using the amended cold gate from
PR 1561; never count UNKNOWN as zero. Preserve every worktree, receipt and
exclusive log. Do not ask Albert for technical approval.

Posted by MiMo chat on edge-dev.
