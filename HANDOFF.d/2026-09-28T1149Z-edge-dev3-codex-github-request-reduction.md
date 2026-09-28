---
issue: 658
status: OPEN
owner: codex/658-wrapup-20260928
---

# GitHub request reduction — 2026-09-28 continuation state

## 0. Stop state and authority (2026-09-28 3:40 PM EDT)

- **Business decisions for Albert:** None — nothing in this workstream needs an owner business judgement now. Any future genuine business question should be consolidated here before asking; technical access/approval never goes to Albert.
- **Already settled — do not re-ask:** Albert ordered full orchestration and subagents, then explicitly stopped this session for handover on 2026-09-28. The new standing rule says AI handles technical manual steps and never asks a human to approve.
- **User stop:** Albert explicitly said “stop everything you are doing and hand it over.” The root stopped the active agents. This file is the closeout state; do not resume any host installation in this task.
- **New standing authority:** The replacement `AGENTS.md` posted at 3:38 PM EDT says AI performs manual sign-in/access steps and never asks Albert to run, click, set up, or approve a technical action. Earlier asynchronous questions requesting those steps are superseded. Report a platform limit as `Blocked —` after trying supported AI access; do not use the runner-pool PAT for personal auth.
- **edge-dev and 916:** Their personal GitHub sessions are invalid. AI must recover supported authentication itself if possible. This blocks normal installed proof, not read-only code review. No login fix has been made.
- **t16:** Tailscale answered ping, but supported SSH failed from two peers. Its managed install/schedule remains unverified; diagnose the protected route without publishing private topology.
- **hetz:** Production checkout is read-only. The current chat lacks an exact production action/resource request for any gate requiring `--owner-request`; no independent APPROVE exists. Do not mutate it on the strength of a generic programme goal.
- **shared-db:** Only non-orchestrator tooling PR #3649 was merged. No shared database preview, production, or row mutation occurred. Open orchestrator marker #3732 belongs to another Claude session; do not touch it.

## 1. What this toolkit is

`popcre/ai-devops` installs Albert's cross-machine AI workflow tools, including GitHub transport and waiters, on Linux and Windows hosts. It is a public recovery toolkit, not a hosted application. GitHub API throttling affects the tools and BlockerWatch. GitHub `origin/main` is the code source of truth; local installation is deployment. `AGENTS.md` routes this topic to `plan_github-request-reduction.md`, `plan_cut-unneeded-github-traffic.md`, and parent issue #658.

## 2. Goal and scope

Reduce unnecessary GitHub requests and checks as far as possible without losing workflow behavior. The parent plan has P1 measurement, P2 quota protection, P3 managed caller routing, P4 duplicate waiter sharing, P5 BlockerWatch snapshot reuse, P6 cross-host admission decision, P7 live host coverage, and P8 comparable measured acceptance. Albert explicitly requested full orchestration with subagents and no “another session” deferral. Wrap-up freezes unrelated new scope; it does not waive already-authorized steps.

## 3. Current state and exact ownership

### Landed in `popcre/ai-devops`

- Reviewer orphan-sweep fix PR #945 merged at `2e9779284a27643488322979144afef3d0b0d14e`.
- P2 quota repair PR #929 merged at `b2fb99794d11d6dda8937200ff0b59f7634a7c00`; review and Linux/Windows/CI passed. Not yet installed because installer gate #950 remains open.
- P2 issue #914 CLOSED after installed edge-dev3 receipt/hash match, a bounded normal GraphQL read at 11:37 AM EDT, and signed proof comment `https://github.com/popcre/ai-devops/issues/914#issuecomment-5873389678`. P4 issue #925 CLOSED after two installed edge-dev3 waiters shared one OPEN refresh with independent deadline outcomes at 11:45–11:46 AM EDT; signed proof `https://github.com/popcre/ai-devops/issues/925#issuecomment-5873547547`. P3 general-caller issue #931 and elevated Windows runner issue #933 remain open for installed proof.
- Installer safety PR #950 merged as `40649cd63bee3add599b77330104f7466d9efe3e` at 10:37 AM EDT after exact-head review and green CI. P3 direct-caller PR #973 merged as `9cf87d46e73642332c22a516faf843836503a7fd` at 10:50 AM EDT after exact-head review and green CI. No host has received these newer changes yet.
- P1 telemetry PR #970 merged as `e108418e16635d45a0b25cd1d8662d5fd5c0b898` at 12:41 PM EDT after reconciled exact-head approval and green queue. Its source is on `origin/main`; installed reporting and comparable post-install measurement remain open.
- Forward-only P1 access-context repair PR #1000 remains OPEN. Its Windows CI fixture failed twice at `48c1b29`. Root made a test-only protected-parent fix, verified its ACL pattern on 916 and Linux focused tests 204/0, and pushed merge-of-current-main head `7190d7a47f8685bd5e994d4c204dd0dfcefe38f7` without force push. Exact-head Codex final review returned **BLOCKED** because its packet omitted the actual test result; no code finding. The PR needs CI and a fresh evidence-complete exact-head APPROVE before merge. The live edge-dev3 pre-install report has 16 observed GraphQL cost rows and only 2 completed non-deadline receipts. Old quota snapshots lack credential/access-context join and cannot prove account-wide headroom.
- A 4837 exact-head Codex review of then-main `7f4a5f3` returned **REJECT**, revealing a GraphQL-cost report crash and unreachable Windows installer crash recovery. Child issue #1008 owns those repairs. Its dedicated worktree is dirty with seven owned files and was interrupted on Albert's stop request, before commit, PR, new review, or install. Preserve it. Another 916 Claude APPROVE on the same old head does not override the REJECT. Parent #658 was found CLOSED with nine unchecked items and was reopened with signed comment `https://github.com/popcre/ai-devops/issues/658#issuecomment-5876960999`.
- P5 BlockerWatch snapshot fixes #806/#812/#853/#867/#877/#923 merged, but latest #923 is not installed. Its category-level live proof #868 remains open.
- P6 provisional decision was posted, signed, on parent #658: retain local admission, do not introduce a fleet coordinator without measured same-principal contention. Comment: `https://github.com/popcre/ai-devops/issues/658#issuecomment-5864555467`.

### Open work in separate worktrees

- **Installer gate #950:** `/home/ahazan/repos/.worktrees/ai-devops-950-ci-repair`, branch `codex/reviewer-install-gate-approved`, reviewed head `8c6e9754abda0227a08a2ef02340756b032821b3`, merged as `40649cd63bee3add599b77330104f7466d9efe3e`. Independent exact-head final review APPROVE, zero findings; focused Linux and isolated Windows tests and CI passed. Old #934 was closed as superseded. No host was installed by this work.
- **P4/S2 waiter sharing #948:** `/home/ahazan/repos/.worktrees/ai-devops-658-s2-p2-integration`, branch `codex/658-s2-p2-integration-20260928`, exact reviewed source head `5fae717ad0e5f0705c2948f262ed8f5883516771`; PR #948 MERGED as `f55c1a608a026ae1d0f18725743c2b5c1cb70f5b` at 8:23 AM EDT on 2026-09-28. Independent exact-head APPROVE and second read-only Unix-security audit APPROVE. Linux helper 19/0 and waiter 43/43; isolated Windows helper 19/0 and waiter 43/43; LF check 6/6; PR checks green and merge queue landed. It caches only complete, correctly scoped PR status reads, forces fresh reads where required, checks Unix ownership and symlinks, and leaves each waiter's terminal interpretation independent. Installed routing proof remains part of P7.
- **P3 direct callers:** `/home/ahazan/repos/.worktrees/ai-devops-658-p3`, branch `codex/658-p3-sources-20260928`, reviewed head `4d1e7c5dcc5d457080d83242f93e4574aa7eb8ce`, PR #973 merged as `9cf87d46e73642332c22a516faf843836503a7fd`. Routes remaining toolkit `gh` callers through `ai-gh`; preserves bounded bootstrap exceptions and caller labels. Exact-head independent review APPROVE; focused ai-gh 186/0, BlockerWatch 149/0, workflow-policy/doctor integration, and CI passed. Installed #931 paths and separate elevated #933 proof remain.
- **P1 cost/outcome telemetry:** `/home/ahazan/repos/.worktrees/ai-devops-658-p1-s2`, branch `codex/658-p1-s2-integration`, reviewed head `bee6c35c276fe80aad25765a470514eb97900967`, PR #970 merged as `e108418e16635d45a0b25cd1d8662d5fd5c0b898`. It integrates P3 caller labels and Linux SSH recovery. Same-response GraphQL point/remaining/reset values, outcome receipts, and local access-context partitions remain. Pinned exact-head independent review APPROVE, ai-gh 197/0, BlockerWatch 150/0, waiter 45/0, and CI green. Installed P1 reporting proof remains required under #660. Do not cherry-pick old `/home/ahazan/repos/.worktrees/ai-devops-658-p1-cost` directly; it contains old S2 code.
- **Shared-db consumer:** `popcre/shared-db` issue #3646 is **non-orchestrator tooling**, not a database-shape change. PR #3649 MERGED through guarded workflow as `5d6bb13d9b27786c214e505ddd7bf4c756c19219` at 8:36 AM EDT. Its six authorized tooling/contract files are on origin/main; all scoped tests, governed approval, and CI passed. It routes three reaper GitHub reads through the existing transport. No database migration, preview, production, or application-row write occurred. Immutable prework contract `refs/db-contracts/3646/3` hash `b0311dfd`.

### Fleet evidence and blockers

- **#933 elevated runner proof:** A read-only SSH probe found edge-dev's current token elevated, runner service Running/Auto, and merged #935 admission files present. The atlas's older filtered-token assumption is stale. After install, one bounded, read-only `list` via the elevated adapter can prove admission. Do not run the promoter for proof: its registration helper is absent and would trigger registration rebuild. No host mutation was made during this probe.

- **edge-dev**: SSH route verified through the protected machine atlas. Windows source `C:\repos\ai-devops` old `42f423f9`, two unique dirty files backed up byte-perfect. Personal GitHub login invalid; device authorization needed.
- **916**: Clean `D:\repos\ai-devops` old `b05d15d`; no usable personal GitHub login or designated PAT. Device authorization needed. Protected atlas owns the connection details.
- **4837/al8960ofc**: Active BlockerWatch and working GitHub authentication; clean `C:\repos\ai-devops` at `bfc9a82`, 27/35 launchers at last survey. Protected atlas owns the connection details.
- **edge-dev3**: canonical `/home/ahazan/repos/ai-devops` is landing-only. It advanced to `571e4e6` while its manifest still attests `daaac5c`. Exact-target stale-manifest recovery review APPROVE and one-use authority were obtained; the installer stopped before backup because sudo required authentication unavailable in the background terminal. The authority remains `.consuming` for an exact-target retry only; do not delete or remint by guess. The prior request for Albert to enter a password is superseded by the new no-human-manual-step rule. No designated sudo credential was found in the vault metadata survey. Preserve the pending transaction and report a platform limit if no supported AI route exists.
- **hetz**: production `/worksp/ai-devops` clean detached `cdd18b9`, manifest aligned, read-only. Exact current-chat action/resource and independent approval needed before install.
- **t16/albt16**: Read-only September 28 audit found Tailscale online and pong from edge-dev3 and 916, but supported SSH name resolution/port 22 still failed. #979 supplied working aliases for another host, not t16. Its managed toolkit and schedule remain unverified. The t16 machine owner must restore a documented SSH route or provide signed local read-only manifest/hash/scheduler proof; do not exclude it merely because it is unreachable.
- **edge-alien/edge-runn-envy** are CI-only and excluded from agent install matrix.

### Public-boundary incident found during #950 CI

- A separate merged public connectivity handoff exposed private network addresses and a tailnet domain. Root redacted all literal addresses/domain in prose-only PR #964, merged as `7bb011c9b499a41a213430a9213f076386fcb05d`; origin/main was verified without those literals, and the public-boundary gate and fixture passed. Protected private-config PR #4 merged as `0da5c6b005aaef7299f4bec44488df161643682c`, preserving the validated connection facts and RDP/auth context in the private atlas. The original public commit remains in Git history; do not quote its values or claim history was purged. No credential value was present in the handoff and no rotation was performed.

### Measurement so far

- Original P1 September 24 edge-dev two busy reset windows: 294 and 226 wrapper records; observed GraphQL remaining deltas 66 and 57 points, unattributed. No 20 comparable completed operations or actual HTTP/point attribution yet.
- P2's installed normal GraphQL read selected the correct bucket and returned success, but the actual HTTP/point cost remained unknown; do not count it as zero or use it to claim P8 savings.
- A later edge-dev3 report over roughly 4,636 records had 4,567 opaque CLI executions, one identity probe, and no cost/outcome rows before the new telemetry is installed. The plan's P8 targets are not yet proven. `tests/verification/github-requests/p1-baseline.md` holds scrubbed baseline.
- P5 category proof needs one normal scheduled edge-dev tick after #923 plus current telemetry are installed; use labels `bw.snapshot`, `bw.dependents`, `bw.wake_miss`, `bw.alarm_issue`, `bw.link_issue`. Do not fake blockers or mass comments.

## 4. What we tried that did not work

- The older S2 helper produced an extensionless shell file without explicit LF attributes; Linux CI rejected it. Added `.gitattributes` and LF checks.
- S2 review rejected unbounded lock-file keys; switched to 256 shards. A later review rejected private-looking paths without Unix owner checks; repaired ancestor, owner, mode, symlink, hard-link, and fd validation. An independent audit found a forged-terminal test that old code could also pass; replaced it with an OPEN-to-queued forged-cache case. Mandatory `O_NOFOLLOW` now fails closed to uncached reads if absent.
- Installer exact-head reviews found orphan finalization, partial Windows writes, direct setup, PATH crash, bootstrap, first-install, retry, CI manifest, and legacy setup delegation gaps. Each was repaired and retested; current review APPROVE is only for `8c6e975`. A review packet once failed `source-base-mismatch` when main moved; merged fresh main without rewriting branch, then pinned immutable base for the approved review.
- Shared-db older PRs #3645/#3648 closed after contract/review failures. The current #3649 must not reuse those reviews. The governed allocator lock was busy; BlockerWatch records the wait. No lock bypass.
- t16 SSH did not accept from two verified peer machines. Do not repeat blind probes without a supported route.
- Do not use runner-pool PAT to make edge-dev or 916 look authenticated. Their personal authentication still needs supported AI recovery; the new standing rule forbids handing technical sign-in steps to Albert.
- #1000's second Windows CI run failed because `mktemp` produced an inherited-ACL fixture parent. Creating a child directly under the user profile also failed because that profile grants Modify to two other SIDs. A disposable parent restricted with `icacls` to the current SID made `EnsureCache` succeed on 916; that focused proof informed head `7190d7a`. The first final review of `6bd2fc0` compared against newer main and REJECTed unrelated apparent deletions. Root merged current main into the branch without force push, then reviewed `7190d7a` against immutable base `26a2225`; that review BLOCKED only because its packet lacked the already-run 204/0 test receipt. No APPROVE exists for `7190d7a`.
- 4837 native Codex under SSH Session 0 timed out before reading files. A supported same-user limited Session 1 task proved a read-only sandbox could read and deny writes, then the exact-head review completed with REJECT. Its report/lifecycle were reconciled and preserved. Do not turn the 916 Claude APPROVE into installation authority while this valid REJECT remains.

## 5. Root causes and key findings

- BlockerWatch accounted for roughly 95% of measured managed traffic, so shared snapshots and category-level proof dominate potential savings. Source plan: `plan_cut-unneeded-github-traffic.md` S1.
- GraphQL and REST limits are separate; P2 merged resource-aware admission. Do not flatten them into one quota.
- Repeat waiter reads can be shared only for the same repository, PR, expected head, host, principal, credential and access context; queue and terminal decisions remain waiter-owned. `bin/ai-pr-wait` and `bin/pr_status_singleflight.py` are the S2 implementation.
- CLI invocation counts are not actual HTTP requests or GraphQL points. P1 records response cost where GitHub supplies it; old opaque events remain explicitly unknown, not zero.
- The protected machine atlas is authoritative for host connection details. Do not publish its values in this public repository.

## 6. Exact next steps and success checks

1. Preserve stopped work. #1000 branch is pushed at `7190d7a`, clean in `/home/ahazan/repos/.worktrees/ai-devops-660-quota-context-join`; #1008 has seven uncommitted owned files in `/home/ahazan/repos/.worktrees/ai-devops-658-review-reject-1008`. Recheck live PR/CI and current main before resuming either. Do not delete their branches or worktrees.
2. For #1000, attach the 204/0 Linux result and the 916 protected-parent ACL proof to a new exact-head read-only review packet, obtain APPROVE, resolve any CI failure, then use the guarded merge queue and confirm landing on origin/main. The latest final review at `7190d7a` was BLOCKED, so it is not merge authority.
3. For #1008, resume the interrupted scoped repair from its dirty worktree, first reconcile newer main without discarding owned edits. Test the report crash, top-level Windows crash recovery, and tightened gate behavior on both platforms; get independent exact-head APPROVE and merge only after green checks. Preserve the 4837 REJECT incident. No host install until this repair lands and the specific target gets a fresh exact-head install review.
4. Resume one bounded guarded host installation outcome at a time: edge-dev3's unchanged `.consuming` authority if exact target still matches and supported AI sudo access exists; then 4837/916/edge-dev through their own source, identity, collision, review, and one-use authorization gates. Recover personal GitHub auth and t16 route through AI tooling. Production hetz remains read-only absent its exact gate inputs.
5. Prove remaining installed outcomes separately: #931 direct routing, #933 read-only elevated adapter `list` without runner registration, #868 one natural BlockerWatch category-level tick, and #660 cost/outcome attribution. Shared-db #3649 is merged non-orchestrator tooling; verify its normal reaper behavior only in its own nonproduction path.
6. Complete the P7 fleet matrix and P8 two comparable busy windows/20 completed outcomes against section 13 thresholds. Treat opaque HTTP/cost fields as unavailable, not zero. Update both plan STATUS tables and #658 only on real evidence; close the parent after final measured acceptance. This handoff stays OPEN until all obligations are carried into a current owner record.

## 7. Constraints and gotchas

- All write work must remain in dedicated current-upstream worktrees; canonical checkout is landing-only. No broad staging, force push, direct protected-main push, or destructive cleanup of another worker's state.
- `bin/ai-gh` is the transport for GitHub CLI calls. One call per five minutes per waiter. Waits over roughly ten minutes must use `ai-blocker-watch wait` rather than polling.
- Run `ai-task-gates start --class ...` per worktree and check before review, ship, deployment or production. Reviewer safety paths require independent read-only exact-head final review; a new commit invalidates the prior verdict.
- `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>` before each first commit. Sign every GitHub issue/PR/comment body `Posted by Codex chat <id> on <machine>`.
- Do not reduce original capability to suppress rate limits. The install gate must preserve rollback/retry, installed launchers, and PATH behavior. Shared-db #3646 is non-orchestrator tooling, never a schema-orchestrator request.
- Human-facing times must use America/New_York with EST/EDT label. This document's machine timestamps and filenames remain UTC by convention.

## 8. Access and environment

- Current root checkout `/home/ahazan/repos/ai-devops`; documentation worktree `/home/ahazan/repos/.worktrees/ai-devops-658-wrapup` on branch `codex/658-wrapup-20260928`. The latter was created from origin/main `ad9c6c2abe54`, and `ai-task-gates start --class prose` succeeded. It owns only this handoff and subsequent plan STATUS prose updates.
- GitHub access on edge-dev3 and 4837 was functional at last check; edge-dev and 916 personal access is broken and must be repaired by AI through supported tooling. Secrets live in 1Password vault `vibe_coding` and protected local config, never here.
- The protected machine atlas owns private host routes and key paths. Production hetz is read-only; no shared preview or production database mutations occurred.
- This wrap-up involved no credential value, token value or connection string in chat. Before ship, sweep changed/untracked files for secrets; do not merely assume clean.

## 9. Open questions, risks, and self-audit

- CI and reviewer states may change after this file's timestamp. Recheck through bounded tools at action time; do not treat this file as a live status feed.
- Full P8 acceptance needs two comparable windows and 20 completed operations plus host coverage. The historic sample alone cannot prove the target. Do not relabel calls as HTTP requests or attribute an opaque point delta to a caller.
- Earlier asynchronous requests for Albert to perform sign-in or enter a password are superseded by the 2026-09-28 standing rule. AI owns technical recovery. If the platform cannot provide an authorized credential, report the specific blocked host; do not silently exclude it or substitute a different principal.
- **Fresh-developer audit:** Sections 1–2 state purpose and scope; sections 3–5 give exact branches, PRs, commits, failed approaches and current host facts; section 6 gives ordered steps with success checks; sections 0, 7–9 state authority, access and risks. A fresh owner can preserve both interrupted worktrees and resume from the first unproved phase without this chat. Recheck moving PR/CI/host state before mutation.

## Part B. Dispatched subagent ledger

### `/root/baseline_audit` — 4837 and #1008

- Asked to qualify a nonproduction install on 4837, including exact-head review; later assigned the review-rejected safety repair.
- Found SSH Session 0 Codex sandbox `pipe-in` failure, proved limited interactive Session 1 read-only sandbox, and obtained a valid REJECT at old head `7f4a5f3` for the report crash and Windows recovery defect. Reconciled the lifecycle and retained the reviewer incident. Opened child #1008; seven owned files are dirty in `/home/ahazan/repos/.worktrees/ai-devops-658-review-reject-1008`, branch `codex/ai-devops-1008-review-reject`, based on now-stale `7f4a5f3`. Linux task-gate tests passed 211/0; Windows and final review were not completed. Interrupted on user stop. No authorization, installation, or canonical mutation.

### `/root/p1_completion` — 916

- Asked to qualify a 916 install; exact-head Codex review BLOCKED on Windows sandbox, then Claude APPROVE at old `7f4a5f3`. Root held installation because the separate valid 4837 REJECT controls the same source. The agent then independently reproduced #1000 Windows fixture ACL behavior on 916 and verified the protected-parent pattern. Worktree/canonical were clean at last check; no installation or auth mutation. Deliberately did not treat the old APPROVE as authority after the REJECT and main movement.

### `/root/quota_audit` — t16

- Asked for read-only t16 fleet status. Tailscale ping worked from two peers; supported SSH route failed, so installed toolkit and schedule are unknown. No branch, PR, or host mutation. Deliberately did not exclude t16 from fleet proof or invent a zero-consumption result.

### `/root/edge_access` — edge-dev

- Asked for Windows edge-dev installation preflight. Found old installed launchers, a clean separate installer candidate, and two unique dirty canonical files backed up byte-for-byte. Managed personal GitHub auth failed; runner collision check remained unknown. No authorization or install. Deliberately did not use the runner-pool PAT or trigger runner registration.

### `/root/install_gate` — edge-dev3

- Asked for the exact-target guarded stale-manifest recovery. Independent APPROVE and one-use authority reached `.consuming`; updater stopped before backup/install when sudo required interactive authentication unavailable in the background terminal. Canonical and installed bytes were left intact. No new branch or PR. Deliberately did not remint authority, alter sudo policy, or claim deployment.

### `/root/p2_quota`, `/root/p3_sources`, `/root/runner_maintenance`

- P2 delivered merged #929 and installed edge-dev3 normal-read proof #914; P3 delivered merged #973 and shared-db **non-orchestrator tooling** #3649, with #931 installed proof still open; runner maintenance established a read-only #933 adapter-list proof path and explicitly avoided registration rebuild. Their implementation work is landed or read-only; no pending agent process or uncommitted file from these three was reported. Do not rerun closed #914 or #925 proofs.

### `/root/s2_waiter` — waiter sharing and P1 evidence

- Delivered merged #948 and installed two-waiter #925 proof. Read-only baseline found 16 GraphQL cost rows but only two completed non-deadline outcomes, and historical cost/quota rows lacked a credential join. Its #1000 follow-up attempt could not be reactivated due team slot limit, so root owned the latest test-only fix and pushed `7190d7a`. No installed P1 acceptance was claimed. Preserve its separate uncommitted sanitized baseline supplement in `/home/ahazan/repos/.worktrees/ai-devops-658-p1-live-proof` until a valid installed sample can accompany it.

### Self-audit answers

1. **Yes, a new developer can pick up here:** §0 names stop/authority, §§1–3 give scope and exact worktree/PR states, §6 starts at the two preserved interrupted branches, and this ledger assigns each agent's outcome.
2. **Yes, the record carries current operational knowledge:** §§3–5 capture measurements, host facts, failed review and ACL routes; §§7–8 state gates and access boundaries. All moving facts are marked for fresh verification.
3. **Yes, execution details and evidence are present:** §6 gives ordered success gates; §4 and the ledger distinguish failed attempts from approvals; §§3 and 9 prohibit invented savings and premature install claims.
4. **Yes, the owner sweep is complete:** §0 explicitly says no business decision is required and records the settled stop/no-human-technical-step rulings. The technical blocks in §§3–9 and this ledger are assigned to AI or fail closed; none is an Albert approval request.
