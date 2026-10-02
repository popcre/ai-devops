---
issue: 952
status: OPEN
owner: codex/reviewer-rotation-wrap-20260928
---

# Reviewer rotation and credential safety handoff

## 0. Decisions only Albert can make

- **Reviewer rotation:** none. Albert already directed this session to add StepFun, keep Grok eligible, and prefer the other active reviewers. Do not re-ask. Albert also directed the session to own the work end to end and use subagents for blockers; the later explicit `wrap-up` instruction freezes this session and transfers the unfinished outcome through [ai-devops #952](https://github.com/popcre/ai-devops/issues/952).
- **Separate security matter:** the shared-db structural coordinator task `01a0e56c-2e17-78a2-ad57-cd154b990979` reported an owner decision about revoking exposed sign-in tokens. This reviewer task did not inspect or expose the token values. Follow that coordinator's own handoff for the exact decision; do not infer authorization to rotate anything from this file.
- **Already settled:** no technical production or database approval is requested here. This task changed tooling and repository files only; no shared preview or production database write occurred.

## 1. What this project is

`popcre/ai-devops` is the public AI workflow recovery and installation toolkit. Its Linux and Windows installations expose read-only reviewer wrappers and local credential stores. `popcre/shared-db` owns the governed reviewer allocator used for shared-database pull requests. The toolkit registry mirrors allocator membership; a reviewer is not in the shared-db rotation merely because its local wrapper is healthy. GitHub is the source of truth for both repositories; `main` is protected. Installation from merged ai-devops main is the deployment mechanism.

## 2. Goal and trigger

Albert asked how the reviewers are behaving and which are active, then directed us to put StepFun into rotation and make Grok a lower-priority fallback because of cost, without removing it. He authorized full implementation and asked for subagents to handle blockers. The task also uncovered existing Muse and DeepSeek formal-review credential paths that invoked 1Password, contrary to the standing no-1Password-during-review rule. Those companion safety repairs must land and be installed before the affected wrappers run governed reviews. The later `wrap-up` instruction ended new work in this session; preserve open code PRs for the successor.

Success means the shared-db allocator and toolkit mirror agree on the pool; StepFun is usable on Linux and skipped on Windows; non-Grok reviewers are considered first and Grok remains eligible when they cannot take an exact review; the repaired wrappers remain usable without 1Password during formal reviews; required exact-head reviews, CI, merge-queue merges, Linux/Windows installs, live checks, and incident resolutions are recorded. Parent [#952](https://github.com/popcre/ai-devops/issues/952) lists the ordered children. Take the first unticked child, finish only it, tick it, comment the next child, and stop.

## 3. Current state at handoff

### Reviewer inventory and behavior

- Live toolkit membership drift check on 2026-09-28 printed `OK reviewer membership matches the shared-db allocator: deepseek, gemini, grok, muse, qwen`. These are the **five current shared-db rotation members** until #3556 merges. Local preflight reported all five installed-healthy and usable. Gemini completed a governed exact-head replacement review for #3526 and approved it. Qwen's installed formal path was independently traced: `bin/ai-qwen` at prior installed head `da98a5f` uses protected `key_store_ok`, not 1Password, for formal turns; only explicit `cmd_store_key` calls 1Password. Grok is healthy but expensive per Albert's instruction. Muse and DeepSeek still require the companion installed repairs below before new formal calls.
- StepFun is installed-healthy/usable on Ubuntu with a read-only reviewer wrapper, but absent from the shared-db allocator until #3556; it is unsupported on Windows. Claude and Codex are approval-gate wrappers, not allocator reviewers. Kimi is registry-absent due credit; GLM is registry-absent by owner ruling. Do not retry either as a formal allocator reviewer.

### ai-devops pull requests

- [#944](https://github.com/popcre/ai-devops/pull/944), issue [#941](https://github.com/popcre/ai-devops/issues/941): Muse credential safety repair. Dedicated clean worktree `/home/ahazan/repos/ai-devops-muse-review-no-op`, branch `codex/muse-review-no-op`, pushed exact head `9b445e5ce21510d4ab417b42aea36c1ffd57ac06`. It removes 1Password access from formal Muse paths, hardens protected key-store/lock handling, fixes Windows installer order, and makes Windows `icacls` launch errors fail closed. Full Linux Muse suite passed 216/0 on prior head `d22df91`; code suite 90/0 on prior code head; exact current Windows head passed `tests/test-windows-private-file.ps1` and credential-lock test 4/0 on edge-dev. Current head has independent Gemini report `.ai/reviews/gemini-codex-muse-944-final-9b44c-20260928T113358Z-3563976.md` with `VERDICT: APPROVE 9b445e5ce21510d4ab417b42aea36c1ffd57ac06`. Required PR CI was still pending at 7:38 AM EDT; `bin/ai-pr-wait 944 --timeout-minutes N --timeout-minutes 9` was active. Auto-squash merge was already requested. **Not merged or installed at this snapshot.** Local incident `20260928T073236Z-edge-dev3-muse-3677946` remains unresolved until live proof.
- [#943](https://github.com/popcre/ai-devops/pull/943), issue [#942](https://github.com/popcre/ai-devops/issues/942): GLM `setup-secrets.sh --no-legacy` repair, approved at head `c8b40a6d986dbf38e8849e2b1501b07213caa415`, 25 checks passed/skipped. It merged through the queue as `ad9c6c2abe5424b6eb2894e69e0ce0ad3e351b1e`, confirmed on `origin/main`; #942 auto-closed. **Installation/live proof remains pending** and must be serialized with the #944 canonical install. Do not treat issue closure as live proof.
- [#947](https://github.com/popcre/ai-devops/pull/947), issue [#946](https://github.com/popcre/ai-devops/issues/946): DeepSeek formal credential repair plus Qwen credential-lock hardening, pushed head `7f6d15f` in clean `/home/ahazan/repos/ai-devops-deepseek-no-op`. Linux DeepSeek suite 194/0 and Qwen 211/0 were recorded on earlier head; focused DeepSeek 57/0 on current Windows test fix. A Windows CI failure was the test's POSIX `stat -c %a` mode assertion, not an ACL failure; latest test uses native Windows ACL verification and retains POSIX assertion on Linux. Windows fixture now forwards runtime basics required for `icacls`. **Not reviewed/merged/installed.** Refresh after #944 so it inherits the shared fail-closed ACL helper; then exact-head review/CI/merge/live proof. Local incident `20260928T085212Z-edge-dev3-deepseek-2066247` remains unresolved.
- [#899](https://github.com/popcre/ai-devops/pull/899): toolkit mirror of StepFun membership, Grok fallback policy, StepFun wrapper identification hardening, docs. Clean worktree `/home/ahazan/repos/ai-devops-stepfun-priority`, head `76441bc`. Membership drift, preflight 147/0, StepFun wrapper 40/0 passed on its earlier branch state. Its review/CI must be refreshed after shared-db #3556 and #3593 land. No installation yet.

### shared-db pull requests (non-orchestrator tooling; no database shape or data writes)

- Structural coordinator marker [#3570](https://github.com/popcre/shared-db/issues/3570) was independently verified CLOSED after its docs handoff; it released the temporary shared-db merge hold. Do not treat its structural successor as the owner of this tooling task.
- [#3526](https://github.com/popcre/shared-db/pull/3526), non-orchestrator issue [#3527](https://github.com/popcre/shared-db/issues/3527): manager source/inventory prerequisite. Clean worktree `/home/ahazan/repos/shared-db-3526-takeover`, head `9caae15e1fed962b79a54b7437c0e0fc4958764f`, 724 manager/752 combined local tests and 22 CI checks passed earlier. Its interrupted Muse seq4213 was guarded-released with failure ref `8245a30d5318b4f87d4a66376cb4ff2acbf935f9`; allocator replacement seq4229 drew safe Gemini with assignment ref `22f8884874c8277976dbb09f1427d2b5bebb854d`; governed exact-head Gemini `VERDICT: APPROVE` is durable in `refs/db-review-verdict-replacements/3527-3526-9caae15e1fed962b79a54b7437c0e0fc4958764f-4213` at `80aba5e091cf2cda8584d2ebdeee13f80aa34383`. No merge. Current shared-db main at last agent check `9c3e7f75fb15695cdcedc6d341d7c0dac694c893` changed none of four PR paths; refresh/carry evidence through manager, then guarded merge.
- [#3528](https://github.com/popcre/shared-db/pull/3528), non-orchestrator issue [#3623](https://github.com/popcre/shared-db/issues/3623): CI/evidence-lineage repair prerequisite. Clean local worktree `/home/ahazan/repos/shared-db-3528-takeover` has unpublished head `ee959cfb46a89bed2746ce51369df5280c45c7e9`; remote PR head was `717622e8`. The local seven-file patch adds `scripts/lib/evidence-generation-lineage.mjs`, rebinds gen8 evidence; 806 tests passed, 336-file transport conformance passed, and completion contract validated. **Do not discard or overwrite unpublished commit.** Refresh/push only after #3526 merges; then required review/CI/merge.
- [#3556](https://github.com/popcre/shared-db/pull/3556), non-orchestrator issue [#3555](https://github.com/popcre/shared-db/issues/3555): StepFun allocator membership, clean worktree `/home/ahazan/repos/shared-db-3556-takeover`, head `ed060357`. It currently fails cross-PR collision because #3526/#3528 (and older predecessors) edit the protected allocator source. Refresh after predecessors land, obtain exact-head review, merge.
- [#3593](https://github.com/popcre/shared-db/pull/3593), non-orchestrator issue [#3592](https://github.com/popcre/shared-db/issues/3592): Grok lower-priority fallback, clean worktree `/home/ahazan/repos/shared-db-grok-3592`, pushed head `1e3f78d314f4f7e5027dcdbdb99c3325ca3fbb37`. It is stacked on #3556 at `ed060357`, not on unrelated PR #3627. At `scripts/manage-migration-author-lanes.mjs:599-608`, `REVIEWER_FALLBACK_PROVIDERS=['grok']`; preferred eligible providers rotate first, Grok is considered if that pool cannot take the exact review. The previous contract failure (`reported files_changed does not match Git`) was fixed with only `.agent/work/3592/2/{completion,contract}.json`; 49 focused tests passed and post-commit check said `Git evidence matches the contract and completion report.` Needs predecessor #3556, fresh CI and exact-head independent review before merge.

No shared preview or production database changes were applied by this session or its subagents. All named worktrees above were clean in a simultaneous read at 7:38 AM EDT; recheck before acting.

## 4. Attempts that did not work

1. The original #944 Windows section 2 test expected a five-minute-old, ownerless lock to be reclaimed. The new Windows safety rule correctly refuses such a lock. The test was corrected to assert refusal/preservation; current exact-head focused Windows lock test passes 4/0. Do not weaken the lock to satisfy the old expectation.
2. Earlier #944 CI fast-classifier failed because a new test was not in its manifest; the manifest was fixed before current head. Do not remove the test.
3. A scoped Codex review of an earlier #944 head rejected because it noticed the separate, existing DeepSeek 1Password path. That companion defect is #947, not a reason to strip Muse functionality. Gemini exact-head approval of current #944 includes the Muse scope and new ACL fix.
4. A StepFun review of an earlier #944 head ran about 13 minutes and was interrupted after a Gemini approval; it produced no usable verdict. Do not count it as a provider failure or as authorization.
5. The first Gemini invocation on #944 current head used abbreviated `--assert-head` and was refused before snapshot creation. A full SHA invocation later produced a paid report, but moving `origin/main` caused strict `source-base-mismatch`; the report was retained but not authorization. Retrying with immutable base `b2fb99794d11d6dda8937200ff0b59f7634a7c00` returned the current exact-head APPROVE above. If main advances mid-review again, use a verified immutable base when appropriate.
6. #947 Windows test tried POSIX file mode on Windows. Use native ACL proof there. Its fixture also stripped `SYSTEMROOT`, `COMSPEC`, and `PATHEXT`, causing `icacls` launch errors; those variables were restored in the test. This revealed the shared Windows helper could proceed after a nonterminating launch error, fixed in #944 at `bin/windows-private-file.ps1:5` and verified by the current head Windows test.
7. #3593's failing Agent work contract reported a file list that omitted its own contract/report files. Its latest pushed head repairs that bookkeeping. Do not redo the fallback algorithm merely to fix metadata.
8. PR #3627 was mistakenly described in an earlier session summary as a StepFun/Grok ruling. A live PR audit found it is unrelated curated Master Data routing. It is not a rotation dependency.

## 5. Root causes and key findings

- The shared-db allocator, not the ai-devops registry, is authoritative for actual assignments. On 2026-09-28 the live equality check names five members; StepFun is a healthy local wrapper awaiting allocator admission. `docs/reviewer-rotation-rules.md:9-12,78-109` in #899 mirrors the desired policy.
- Muse/DeepSeek formal paths must never invoke `op`. Explicit key maintenance may use protected `op` access outside a review. #944 and #947 repair the source paths; installed behavior is still unproven. Qwen's existing installed formal path was independently traced safe before any new allocation.
- Windows native-process errors can be nonterminating under caller `$ErrorActionPreference='Continue'`. #944 sets Stop inside `Invoke-AiDevOpsIcacls` (`bin/windows-private-file.ps1:3-8`) and adds a shadowed-command regression (`tests/test-windows-private-file.ps1:36-44`). The current exact-head focused test passed on edge-dev.
- The governed #3526 allocator preserved the ambiguous interrupted Muse turn. It was not replayed or guessed. The release and Gemini replacement created durable refs and an exact-head verdict. Refresh must use built-in approval carry only if the manager accepts byte-identical implementation evidence; otherwise request a fresh governed review.
- A clean persistent Windows main clone is ready at `C:\repos\ai-devops-reviewer-install`; the existing `C:\repos\ai-devops` is dirty and must be preserved. The Windows installer requires clean canonical `main` and fast-forwards itself. The disposable `C:\repos\ai-devops-muse-pr944-codex` was used only for focused PR tests.

## 6. Exact next steps and success gates

1. Check [#952](https://github.com/popcre/ai-devops/issues/952), this handoff, and the current PR/issue states. Do the first unticked child only, comment and tick it, then stop. Check `ai-task-gates start --class reviewer-safety` for wrapper/routing work, and `check --before` required actions. **Gate:** task class and current heads are recorded; no stale status is assumed.
2. For #944, let required CI and merge queue complete through `bin/ai-pr-wait 944 --timeout-minutes N` (bounded, explicit deadline; leave the issue/PR as the card if the wait outlives the turn; if >10 minutes). Investigate any failing check, preserve exact-head review if head unchanged, merge through the protected queue, verify the intended change on `origin/main`. Then run supported Linux `./update.sh` from clean canonical `/home/ahazan/repos/ai-devops` and live `AI_MUSE_CALLER=codex ai-muse doctor --live` plus `ai-review-preflight check muse /home/ahazan/repos/ai-devops --live`; use the Windows clone with `bin/install-ai-devops-windows.ps1 -RepoPath C:\repos\ai-devops-reviewer-install` then `install-machine-tools.ps1 -RepoPath` and live Muse preflight. Resolve local Muse incident and close #941 signed. **Gate:** merged commit, CI, exact-head approval, both installed launchers, live checks, and incident resolution exist.
3. #943 already merged and #942 auto-closed. Serialize the canonical install after #944 and run installed `setup-secrets.sh --no-legacy` / GLM end-to-end proof without printing values; add signed live evidence to #942 or #952. **Gate:** installed GLM fixture reports eight refs plus end-to-end PASS; issue closure alone is insufficient.
4. Refresh #947 against merged #944. Re-run focused DeepSeek/Qwen suites and Windows ACL fixture; obtain one read-only exact-head independent review, complete CI/queue merge, install Linux/Windows via supported paths, run live DeepSeek and Qwen preflight/credential checks, resolve the DeepSeek incident and close #946. **Gate:** no `op` call on either formal path, live verdict readiness, and merged/installed evidence.
5. Refresh #3526 against current shared-db main, invoke guarded manager approval carry for the durable Gemini verdict if implementation is byte-identical; otherwise use a fresh manager-assigned safe reviewer. Complete CI and guarded merge; verify main, close non-orchestrator #3527 signed. **Gate:** manager accepts current exact head and PR is merged; do not bypass evidence checks.
6. After #3526, refresh/push the unpublished #3528 repair head, validate lineage and tests, obtain required review, CI, guarded merge, verify main, close non-orchestrator #3623. **Gate:** source and evidence-generation checks pass on merged head.
7. Refresh #3556 after overlapping protected-source PRs land; pass collision check, tests, exact-head review, guarded merge, verify main. **Gate:** allocator inventory includes `stepfun-step-5-preview` and Linux preflight admits it while Windows declines unsupported platform.
8. Refresh stacked #3593 after #3556; pass contract/priority tests, exact-head review, CI/guarded merge, verify main, close non-orchestrator #3592. **Gate:** allocator draws preferred eligible reviewers before Grok and still assigns Grok when preferred pool cannot take the exact review.
9. Refresh #899 against both shared-db merges and current ai-devops main, rerun membership drift and StepFun wrapper/preflight suites, exact-head review, CI/queue merge, install on Linux and Windows. **Gate:** installed drift check agrees with shared-db allocator, StepFun is active on Linux, Grok fallback remains eligible, and all affected local incidents are resolved or explicitly partially resolved with evidence. Close #952 only then.

## 7. Constraints and traps

- All repos require isolated worktrees, protected PR/queue merges, task-specific staging, correct Albert noreply commit identity, and signed GitHub comments. Use `bin/ai-gh` for all GitHub calls and `bin/ai-pr-wait` for bounded event-aware PR waits. Do not have multiple full local Windows test series overlap the same physical runner or installed runtime.
- Independent exact-head read-only final review is mandatory for reviewer wrappers, safety tests, evidence tools, and installed routing rules before merge. No formal old-installed Muse or DeepSeek review. Do not call 1Password during a formal review. Kimi and GLM remain out of allocator rotation.
- Shared-db #3526/#3528/#3556/#3593 change tooling only, not database shape. They are **non-orchestrator work**; do not send them to the structural migration queue or claim a structural marker. The #3570 merge hold has ended.
- #3528 has a unique unpublished local commit; do not reset or clean that worktree. #3593 is stacked on #3556. #3627 is unrelated and must not gate or be merged for this task.
- The ai-devops canonical checkout is landing/install-only and its Windows equivalent `C:\repos\ai-devops` is dirty. Use the prepared clean Windows clone. Source/worktree hashes, PR states, and installed heads are drift-prone and must be rechecked at the next turn.
- Reviewer issue resolution is append-only (`ai-reviewer-issue resolve`) and must cite actual installed/live evidence. Never fabricate a terminal verdict for the interrupted Muse turn.

## 8. Access and environment

- Linux host `edge-dev3`, canonical ai-devops `/home/ahazan/repos/ai-devops`; all listed dedicated worktrees are present and were clean at 7:38 AM EDT. `bin/ai-gh`, GitHub auth, reviewer wrappers, and local test tools are available. Windows host `edge-dev` is reachable by existing authenticated mechanisms; prepared clean clone path is above.
- Secrets live in protected local stores and the `vibe_coding` 1Password vault. No credential value is in this handoff. Explicit maintenance may use serialized 1Password access per `secrets-to-1password`; formal reviewer turns never do. The session exposed no new value and made no vault write.
- The exact reviewer safety instructions are in ai-devops `AGENTS.md`, `docs/reviewer-rotation-rules.md`, `docs/task-router.md`, and affected PRs. `docs/deployment.md` owns install behavior. Each shared-db worktree has its own `AGENTS.md` and issue contract.

## 9. Open risks and dated assumptions

- **2026-09-28 7:38 AM EDT:** #944 CI was still moving; its status will be stale by the next session. #943 merged later in this closeout as `ad9c6c2...`. A previously approved #944 report was invalidated by moving `origin/main`; the current approved report uses immutable base and exact head. If #944 head changes again, re-review.
- **2026-09-28 7:38 AM EDT:** #3526 replacement Gemini verdict is durable but the PR head predates the structural coordinator's docs-only main change. The manager must approve a lawful evidence carry after refresh; do not assume an ordinary merge is sufficient.
- **2026-09-28:** Muse and DeepSeek wrappers are marked installed-healthy by preflight yet their *old installed formal credential paths* are unsafe; preflight alone is not completion. Live installed proof after merge is required. Qwen formal path is currently safe by source trace, and #947 further hardens credential locking.
- **2026-09-28:** Other active sessions can advance main or own Windows runner time. Recheck exact SHA and collision gate before new test/review/install. No database preview/production state from this task needs cleanup.

## B. Subagent work, individually

### `/root/land_3521` — #3526

- Asked: recover interrupted Muse assignment and land manager prerequisite once coordinator released.
- Did: verified unchanged PR head, guarded-released seq4213, drew safe Gemini seq4229, received durable exact-head APPROVE with refs listed in §3. No merge after wrap-up.
- Found: main moved without touching PR paths; safe review carries only through manager approval rules.
- Branch/worktree: `codex/takeover-3526`, `/home/ahazan/repos/shared-db-3526-takeover`, clean/live.
- Deliberately did not: replay uncertain Muse turn, dispatch old-installed Muse/DeepSeek, or merge after wrap-up.

### `/root/land_3522` — #3528

- Asked: repair evidence-lineage CI prerequisite.
- Did: created unpublished local `ee959cfb...`, 806 tests/336-file conformance passed; exact details in §3.
- Found: pushing before #3526 would leave protected-source collision failing.
- Branch/worktree: `/home/ahazan/repos/shared-db-3528-takeover`, clean/live.
- Deliberately did not: push, review, or merge before #3526.

### `/root/stepfun_chain_audit` — #3556/#3593

- Asked: audit StepFun/Grok chain and fix preventable #3593 contract failure.
- Did: corrected #3627 misidentification; patched only #3593 contract files, 49/49 focused tests, pushed `1e3f78d3...`.
- Found: #3556 cross-PR collision with #3526/#3528; #3593 stacked on exact #3556 head.
- Branch/worktree: `/home/ahazan/repos/shared-db-grok-3592`, clean/live.
- Deliberately did not: rebase/merge while structural hold applied; no independent final review yet.

### `/root/deepseek_no_op_repair` — #947

- Asked: repair DeepSeek formal credential path and Qwen lock hardening.
- Did: pushed `7f6d15f`, fixed Windows mode test/fixture; local focused test 57/0 and prior full suites above.
- Found: shared `icacls` helper could fail open after a native launch error; parent fixed that on #944.
- Branch/worktree: `/home/ahazan/repos/ai-devops-deepseek-no-op`, clean/live.
- Deliberately did not: duplicate shared-helper edit, run old formal DeepSeek, or merge before #944.

### `/root/windows_install_route` — edge-dev preparation

- Asked: diagnose #944 Windows lock test and prepare live install route.
- Did: proved new ownerless-lock refusal, prepared clean persistent Windows main clone, ran exact-head private-file and lock tests (PASS, 4/0).
- Found: dirty canonical Windows clone cannot pass installer clean-main gate; focused disposable checkout works. Local collision check returned `unknown`, so no full suite ran there.
- Worktree: clean persistent `C:\repos\ai-devops-reviewer-install` and disposable PR checkout; both preserved.
- Deliberately did not: install before merge, read secret values, run 1Password, or overwrite dirty checkout.

### `/root/glm_setup_probe` — #943

- Asked: repair GLM no-legacy setup probe and merge after release.
- Did: pushed approved head `c8b40a6...`, 25 checks passed/skipped; queued merge before wrap-up and verified merge commit `ad9c6c2...` on `origin/main` afterward.
- Found: merge-tree had no conflict with current main at its check.
- Branch/worktree: agent-owned clean GLM PR worktree; see #943 for exact branch.
- Deliberately did not: install or begin new scope after wrap-up.

### Earlier prerequisite subagents

- `/root/land_3525`, `/root/muse_windows_bootstrap`, and `/root/muse_windows_migration` contributed prior prerequisite investigation/changes reflected in merged shared-db #3521/#3522/#3525 and ai-devops #917/#939, or the open Muse repair. Their exact worktree ownership was not re-audited in this wrap-up; do not delete any of their worktrees on this account. The current open PRs and local incident records above, not an inferred agent status, govern the next step.

## Fresh-developer self-audit

1. **Can a new developer resume without chat context? Yes.** §§1–3 define both repositories, the authoritative allocator, current heads, reviews, tests, installs, issues, and worktrees; §6 gives ordered actions and success gates.
2. **Can they continue as effectively as this session? Yes.** §§4–5 preserve failed approaches and non-obvious credential/packet/allocator findings; §§7–9 preserve constraints, access, drift risks, and verification boundaries; Part B names each agent's contribution and deliberate limits.
3. **Are background, goals, state, failures, decisions, risks, actions, and evidence complete? Yes.** §§0–9 and Part B cover each dimension; all unfinished work is on #952 and the referenced child issues/PRs. Recheck drift-prone statuses before acting.
4. **Would Albert see every decision needed from only §0? Yes.** This task needs no new rotation or technical approval; the only out-of-scope owner decision observed is explicitly noted there and owned by the structural coordinator's handoff.
