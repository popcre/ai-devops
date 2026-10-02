# IMPLEMENTATION PLAN — Reviewer pipeline core (rewrite per StepFun)

**Tracking:** see HANDOFF.d/2026-09-29T2205Z-edge-dev-mimo-reviewer-pipeline-wrapup.md  
**Date:** 2026-09-29  
**Authoring basis:** StepFun critique VERDICT REVISE on head `7f6c53fc` (report `.ai/tmp/stepfun_critique_report.md`), Gemini critique (superseded on fleet membership), three wrapper audits, Jev transcript diagnosis.  
**Full investigation write-up:** [docs/reviewer-failure-full-writeup.md](docs/reviewer-failure-full-writeup.md) (all background, critiques, incidents)
**Standard:** `templates/system/implementation-plan-standard.md`

## STATUS — read first

| Step | Status | Last updated | Evidence / next gate |
|---|---|---|---|
| 0. Confirm fleet membership and out-of-scope list | ⬜ open | 2026-09-29 | §4, §8; owner already corrected this in chat 2026-09-29 |
| 1. Phase A — evidence retention (safe first PR) | ⬜ open | 2026-09-29 | §9 Phase A; start here in a new worktree |
| 2. Phase B — requalification versioning (Gemini/Qwen) | ⬜ open | 2026-09-29 | §9 Phase B; after A lands |
| 3. Phase C — failure-class split (outage vs code) | ⬜ open | 2026-09-29 | §9 Phase C; reuse `tools/reviewer_admission.py` |
| 4. Phase D — runner + adapters (forcing function) | 🟡 in progress | 2026-09-30 | §9 Phase D; shared runner core + Grok door + pool forcing function in `fix/1114-review-runner-doors` (#1114). Remaining doors are follow-up PRs. |
| 5. Phase E — retire copies + metrics proof | ⬜ open | 2026-09-29 | §9 Phase E; measure before/after |

**GitHub issues (parent + children):**
| Issue | Step |
|---|---|
| [#1110](https://github.com/popcre/ai-devops/issues/1110) | Parent — stop 24-48h reviewer breakage |
| [#1111](https://github.com/popcre/ai-devops/issues/1111) | Keep full review evidence (Phase A) |
| [#1112](https://github.com/popcre/ai-devops/issues/1112) | Requalification keeps last good (24-48h fix) |
| [#1114](https://github.com/popcre/ai-devops/issues/1114) | One runner + native/OpenCode doors |
| [#1115](https://github.com/popcre/ai-devops/issues/1115) | Outage vs code failure classes |

Harness design: [docs/reviewer-harness-consolidation.md](docs/reviewer-harness-consolidation.md)

**Fresh-session start:** open a new current-upstream worktree, read this STATUS table, start **only Phase A** in that session. Re-read later phases before starting each one (drift check).

---

## 1. The ultimate goal

Albert is a business owner who is exhausted by endless fix-after-fix on the AI **reviewer** system. When this plan is done:

- Every review produces a **kept** evidence packet and a real suggestion report, so the next failure is diagnosed from facts instead of from zero.
- Repairing a reviewer tool does not lock that tool out of the fleet.
- Provider outages (credit, quota, 403/404/429) stop showing up as code defects to patch.
- New reviewer work is "write a thin adapter," not "copy a wrapper."

**If a step below conflicts with this goal, the goal wins — stop and flag it.**

This is **not** an approve/reject gate redesign. A review is a full **suggestion report** from a reviewer model. Governance plumbing must make those reports durable and trustworthy.

## 2. What this application is

`popcre/ai-devops` is POP Creations' public recovery and operating toolkit for a multi-model AI workflow. It contains reviewer wrappers, evidence-packet builders, lifecycle tools, skills, policy, and offline tests. It is not a hosted app and has no application database. Installation from this repository is its deployment mechanism.

- GitHub: `https://github.com/popcre/ai-devops`. Protected target: `main` (merge queue).
- Canonical local checkout `C:\repos\ai-devops` is **landing-only**. Write work uses its own worktree.
- Windows dev host: `edge-dev`. Git Bash for Bash tests. `bin/ai-test-local` for suites.
- Reviewer install tree used by wrappers at runtime: `C:\repos\ai-devops-reviewer-install` (not the repo; copy/install after merge).

## 3. What triggered this work

Albert: reviewers fail "over and over and over" and the team does "fix after fix after fix endlessly." A 5-week transcript study (Jev over 4,580 sessions; 2,591 discarded as unrelated; 1,989 remainder) plus three wrapper audits concluded the cycle lives in shared review plumbing, not in model judgment. Original proposal was critiqued by Gemini (REJECT as written) and StepFun (REVISE). **This plan is the rewrite after StepFun.**

Reproduce the class of failure any time a review ends with empty `*_captured: 0`, a deleted packet, or a wrapper quarantined after a fix (see incidents `20260929T125912Z-edge-dev-muse-1965021`, `20260929T130236Z-edge-dev-grok-1993325`).

## 4. Scope — in and out

**In scope**
- Reviewer fleet **report pipeline**: identity, locking, evidence packet build + durable store + hash, lifecycle join fields, report substance floor, failure class, staleness.
- Requalification safety for fingerprint-gated providers (Gemini, Qwen).
- Forcing function so all six rotation reviewers use the shared runner/core (Phase D).
- Implement/write paths of those same reviewers so they do not fork the same plumbing (Phase D).

**NOT in this plan**
- Rewriting who may merge, the merge queue, CI, or GitHub automation.
- Shared-database structure (`popcre/shared-db` owns that).
- Adding or removing providers from `config/reviewer-registry.json` except where this plan names a platform rule.
- Jev integration (advisory only; separate plans).
- A second review product or a new harness (#167 / #169 reuse rules).
- Claude/Codex **orchestration** wrappers as if they were the review fleet (they are not).

## 5. Current state of the code

| Area | State | Evidence |
|---|---|---|
| Fleet membership | Owner-corrected 2026-09-29: reviewers = **Muse, Grok, Qwen, StepFun, DeepSeek, Gemini**. Claude/Codex write/orchestrate (approval-gate only). Kimi/GLM out of rotation. | Owner chat; `config/reviewer-registry.json` |
| Evidence packet delete-on-success | Live today | `bin/ai-claude-review:91-92`, `bin/ai-codex-review:147-148`, `bin/ai-review-packet:927,935`, `bin/ai-review-sandbox:153-164` |
| `*_captured: 0` | Live today | `bin/ai-reviewer-issue:101-120,169,331-337`; lifecycle writes no log-path keys `bin/ai-review-lifecycle:243-244` |
| Duplicated plumbing | lifecycle / preflight / scoreboard each reimplement identity, locks, staleness, provider checks | audits; e.g. `bin/ai-review-scoreboard:21-30` vs `bin/ai-review-lifecycle:151-160` |
| Who calls `ai-review-lifecycle` | Only grok/kimi/glm/pool (+ claude/codex var). **Not** muse, gemini, qwen, deepseek-agent, stepfun | StepFun F2; `bin/ai-grok-review:215`, `bin/ai-muse`, `bin/ai-gemini:374`, `bin/ai-qwen`, `bin/ai-deepseek-agent` |
| Requalification delete-before-canary | Live for gemini/qwen only | `bin/ai-review-preflight:334,350,376`; test expects revoke-on-fail `tests/test-ai-review-preflight.sh:139-146` |
| Shared outage/credit class | **Already exists and is used** | `tools/reviewer_admission.py:20-36`, `tools/reviewer_event_guard.sh` |
| Event ledger | **Already exists** | `tools/reviewer_events.py`, `tools/reviewer_maintenance.py` |
| Shared shell home | **Already exists** | `tools/lib/provider-wrapper-common.sh`, `tools/lib/task-gates.sh` |
| StepFun on Windows | Supported via OpenCode after `578a6c7a` | `bin/ai-stepfun` IS_WINDOWS branch; doctor PASS on edge-dev 2026-09-29 |
| Tag length | 64 vs 77 disagree | `bin/ai-gemini:104` vs `bin/ai-review-sandbox:123-128` |
| Wall-clock flaky tests | Live | `tests/test-ai-grok-review.sh`, `tests/test-ai-kimi.sh` |

Nothing in Phases A–E is implemented yet. Proposal drafts live in `.ai/tmp/` (not canonical). **This file is the plan of record.**

## 6. Key findings and root cause

1. **Eight copies of governance plumbing** — not eight different review designs. Bugs in one copy reappear in another.
2. **Proof is destroyed after success** — packet + base pin ref deleted in EXIT traps; next incident starts blind.
3. **Repair can quarantine** — wrapper_sha256 change revokes Gemini/Qwen qualification before the new canary passes (`bin/ai-review-preflight:334,350`).
4. **No forcing function** — even `ai-review-lifecycle` is bypassed by the largest wrappers (muse, gemini, qwen, deepseek, stepfun). A shared library that "wrappers call" already failed once (bugs.md finding 13).
5. **Outages and code bugs share one stream** — credit/quota/capacity events get the same repair treatment as defects.
6. **Wrong-fleet framing** (superseded) — an earlier draft treated Claude/Codex as the review fleet and would have scoped the rebuild to the wrong set.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| "One shared library; wrappers keep calling it" | Already exists as `ai-review-lifecycle` and is bypassed (StepFun F2). Becomes copy #9. |
| Rebuild for "Claude and Codex only" | Wrong fleet (owner 2026-09-29). Those two write/orchestrate. |
| Fork a new outage classifier in the core | `tools/reviewer_admission.py` already does this for all six rotation reviewers (StepFun F3). |
| New `lib/review-core/` home | Violates reuse rule (`AGENTS.md`); use `tools/lib/review-lifecycle-core.sh`. |
| Big-bang extract of all wrappers first | Triggers requalification lockouts mid-migration (Gemini + StepFun). |
| Keep old qualification forever on canary failure | Weakens re-prove. Prefer **versioned records keyed by wrapper_sha256** (audit quarantine §, StepFun F6). |
| Unlimited durable packets in a public repo | Disk + secret risk. Need redaction split + TTL (StepFun F7). |

## 8. Design decisions already made

**LOCKED (do not relitigate)**
1. Reviewers are Muse, Grok, Qwen, StepFun, DeepSeek, Gemini. They emit **suggestion reports**, not accept/reject clicks. They may also implement/write code.
2. Claude and Codex are writers/orchestrators (approval-gate wrappers). Not the review fleet for this plan.
3. One core owns governance; adapters only call the provider and return a report (or implement result).
4. Primary artifact = suggestion report + evidence packet. Report floor is `MIN_REPORT_CHARS=200` (`bin/ai-review-lifecycle:267-276`).
5. Lifecycle terminal vocabulary stays `APPROVE|REJECT|BLOCKED` plus `failure_class` — not a new approve/reject product.
6. Phase A (evidence retention) is the first and only landing step of the next implementing session.
7. Fingerprint requalification set remains `LIVE_QUALIFIED_PROVIDERS="gemini qwen"` until Phase B changes the **record shape**, not the set.

**OPEN (implementer judgment allowed)**
- Exact durable store path and TTL (default proposal below; adjust if disk policy says otherwise).
- Whether implement/write goes through the same runner entry or a sibling `run --mode implement` (prefer one entry if it stays thin).
- Whether scoreboard null-verdict refusal is a hard fail or a recorded `failure_class=contract` (prefer hard fail on new writes).

## 9. The plan — ordered steps

### Phase A — Evidence retention (SAFE FIRST PR) — start here

**Intent:** a successful review leaves a stored packet and a non-zero capture, without moving any provider fingerprint.

**A1. Lifecycle accepts packet identity (add-only)**  
- Change `bin/ai-review-lifecycle` `terminal finish` arg parser (`~:279-282`) to accept `--packet-dir` and `--packet-sha256`; write both into the state JSON.  
- Do not remove existing fields.  
- **Gate:** `ai-review-lifecycle` unit/shell test: finish with packet args → state JSON contains `packet_dir` and `packet_sha256`; finish without them still works.

**A2. Copy evidence before EXIT cleanup**  
- In `bin/ai-claude-review:91-92`, `bin/ai-codex-review:147-148`, `bin/ai-review-pool:128` (and any sibling `cleanup()` that calls `$PACKET remove`): copy `MANIFEST.md`, `patch.diff`, `MANIFEST.sha256` to a durable dir **before** delete.  
- Default durable dir: `.ai/reviews/packets/<tag>/` (gitignored). If cleanup cannot copy, **skip deletion** and warn.  
- **Gate:** force a successful review (or the focused test double) and assert the durable dir is non-empty and the sandbox is gone; `*_captured` path non-zero when lifecycle finish ran with packet args.

**A3. Retain base pin ref**  
- `bin/ai-review-packet:935` currently drops `refs/ai-review-packets/<tag>`. Keep the ref when a terminal verdict exists; delete only on explicit purge.  
- **Gate:** after terminal finish, `git rev-parse refs/ai-review-packets/<tag>` succeeds.

**A4. Scoreboard refuses null verdict on new writes**  
- `bin/ai-review-scoreboard:73,91` — `--verdict` becomes required for new rows; existing rows stay readable.  
- **Gate:** `tests/test-ai-review-scoreboard.sh` (or new case): omit `--verdict` → nonzero exit.

**A5. Flaky wall-clock tests (same PR if small, else immediate follow-up PR)**  
- Replace real sleep assertions in `tests/test-ai-grok-review.sh` and `tests/test-ai-kimi.sh` with mocked/event-driven checks (StepFun F8).  
- **Gate:** those test files pass 3× on a loaded machine without timing flakes.

**Phase A does not touch** `bin/ai-gemini` or `bin/ai-qwen` wrappers → no live requalification.

**Verification gate for Phase A:** "you'll know it worked when a completed review leaves `.ai/reviews/packets/<tag>/` with MANIFEST+patch, the lifecycle state has `packet_sha256`, and `ai-reviewer-issue` no longer records `recent_provider_logs_captured: 0` on that path."

### Phase B — Requalification versioning (Gemini/Qwen)

**B1.** Change `bin/ai-review-preflight` qualify path (`:334,350`) to write a **new** qualification record versioned by `wrapper_sha256` (and runtime/preloader hashes) to a temp file, then atomically publish; keep the previous record valid until the new live canary passes.  
**B2.** On canary failure, select the prior matching version; queue retry; do not delete.  
**B3.** Update `tests/test-ai-review-preflight.sh:139-146` to the new contract **in the same PR**, with a comment that the old "revoke prior on failed requalify" behavior was a product bug (was the quarantine loop).  
- **Gate:** scripted test: mutate wrapper hash → tool still usable on last good version → successful canary publishes new version → drift selects matching version instead of quarantine.

### Phase C — Failure-class split

**C1.** Route all six rotation reviewers through existing `tools/reviewer_admission.py` patterns (already largely true). Map HTTP 403/404/429 and exit 92 to `failure_class=outage|credit|capacity`, never `code`.  
**C2.** Teach `bin/ai-reviewer-issue` to show that class in summaries.  
- **Gate:** unit tests for admission patterns; one fixture issue with outage class is not labeled a code defect.

### Phase D — Runner + adapters (forcing function)

**D1.** New shared entry in existing home: `tools/lib/review-lifecycle-core.sh` (+ thin `bin/ai-review-engine` if a single command is needed). Owns: task gate, identity, sandbox, packet seal/store, lifecycle terminal, report floor, cleanup **after** store, scoreboard accounting.  
**D2.** Adapters become pure: provider call + parse report. **No cleanup traps, no locks, no packet deletes** in adapters.  
**D3.** Migrate **one** reviewer first (Grok or DeepSeek — already closest to lifecycle), prove, then Muse, Gemini, Qwen, StepFun.  
**D4.** Include `implement`/write mode in the same core contract (StepFun F4). StepFun platform: `unsupported-platform` on Windows when StepCode path is required; OpenCode path as today — never quarantine for platform.  
- **Gate:** one end-to-end review through the engine leaves packet+report; adapter source contains no `PACKET remove` / sandbox delete.

**Drift check:** re-read §9 before starting D. Do not start D in the same session that lands A.

### Phase E — Retire copies + prove metrics

**E1.** Delete duplicated helpers only after a measured clean window (proposal: 14 days or 50 reviews with zero missing-packet incidents).  
**E2.** Record before/after: `*_captured: 0` count, quarantine events, outage-vs-code issue split, disk use of packet store.  
- **Gate:** metrics doc with commands + artifacts (not bare numbers).

## 10. Tests required

| Test | Where | Asserts |
|---|---|---|
| Lifecycle packet args | `tests/test-ai-review-lifecycle.sh` (extend) | state has packet_dir/sha256 |
| Cleanup keeps evidence | new `tests/test-ai-review-evidence-retention.sh` | durable copy exists; sandbox removed; copy-missing skips delete |
| Scoreboard verdict required | `tests/test-ai-review-scoreboard.sh` | missing `--verdict` → fail |
| Requalify versioning | `tests/test-ai-review-preflight.sh` (rewrite cases) | last good retained; publish on success |
| Admission failure classes | `tests/test-reviewer-admission*.sh` | 403/404/429/92 map to outage/credit |
| No wall-clock flakes | existing grok/kimi tests | event-driven, 3× green |
| Engine adapter purity | new test | adapter has no packet/sandbox delete |

Full suite: `bin/ai-test-local` after `bin/ai-test-local --check-collision`. Never overlap with a GitHub job on the same Windows host.

## 11. Constraints, standing rules, and gotchas

- Branch + PR + merge queue; never push `main`. Stage only task-owned files. `git var GIT_COMMITTER_IDENT` = `Albert Hazan <u2giants@users.noreply.github.com>`.
- **Reviewer safety path:** changes to wrappers, evidence tools, safety tests, or installed routing need **one read-only exact-head final review** before merge. Budget review capacity; if the pool is down, stop — do not self-approve.
- Installation: copy/install to `C:\repos\ai-devops-reviewer-install` is how runtime sees wrappers; repo merge alone is not live proof.
- Secrets: 1Password vault `vibe_coding` via `op run` only. Never log keys. StepFun key store: `ai-stepfun store-key` (item `stepfun step5 ai api key`).
- Do not "fix" by removing reviewer capability. Preserve tools; repair them.
- `ai-task-gates start --class <class>` before work; recheck before review/merge.
- Windows: PowerShell-compatible scripts; Bash tests via Git Bash.
- Tag/path: standardize max **48** tag chars / **64** dir chars in Phase D (StepFun); do not leave 64 vs 77.

### Adversarial cases (evidence / packet trust boundary)

| External input | Hostile case | Test |
|---|---|---|
| Reviewer report text | Empty / under 200 chars | report floor rejects; lifecycle `BLOCKED` + `failure_class` |
| Reviewer report | Hash not bound to head | `verdict-not-bound-to-head` stays strict (except documented tip ancestry) |
| Packet copy | Copy fails mid-cleanup | cleanup **skips** delete; warn; incident-able |
| Provider HTTP | 403/404/429/92 | admission class outage/credit; no code defect |
| Wrapper binary | Hash drift mid-canary | B2: prior version kept; retry queued |
| Sandbox path | Tag > 64/78 chars on Windows | unified length budget; test both limits |
| Lifecycle args | Missing/empty packet sha | refuse or omit field consistently; never invent hash |

## 12. Access and environment

- Host: `edge-dev` (Windows). Git Bash + `$MIMO_PYTHON` for Python tests.
- GitHub: `bin/ai-gh` only. PR wait: `bin/ai-pr-wait`.
- Reviewers available on this host after 2026-09-29 install: Gemini, Qwen, Grok, Muse, DeepSeek, StepFun (OpenCode engine). `ai-review-preflight usable <provider>` is the gate.
- StepFun Windows: `bin/setup-opencode-stepfun.ps1` + `config/opencode-stepfun/` must be installed in the reviewer-install tree (`config/opencode-stepfun/`).
- Keys: 1Password vault `vibe_coding`. Item names only in docs (e.g. `typesafe.ai API`, `stepfun step5 ai api key`).
- No UI. Local "run" is invoking the wrapper tests or `ai-<provider> review` against a worktree.

## 13. Definition of done, risks, open questions

**Done when**
- [ ] Phase A merged with tests green and independent final review (safety path).
- [ ] Live proof on edge-dev: one real review leaves a durable packet + non-zero capture (one leftover-proof issue if code lands without live proof — do not bundle).
- [ ] Phases B–E each have their own PR, tests, and STATUS rows updated **in this file**.
- [ ] Metrics doc for Phase E cites artifacts (paths/SHAs/command output files), not bare counts.
- [ ] HANDOFF.d link + this plan cross-linked; `AGENTS.md` router row added when the plan is committed.

**Risks / rollback**
- Packet disk growth → TTL (default 14 days / 50 reviews) + gzip; rollback is purge job only.
- Requalification change is the riskiest (B). Rollback = restore prior preflight from install backup; keep failed canaries from deleting records (that is the point).
- Adapter migration (D) can fork again if a wrapper keeps its own cleanup — gate on "adapter has no delete."

**Open questions**
1. Durable store: in-repo gitignored `.ai/reviews/packets/` vs private store for unredacted copies. **Decide in Phase A2** (StepFun F7): recommended = redacted copy in `.ai/reviews/packets/`, unredacted only if a private path already exists; never commit secrets.
2. Single `ai-review-engine` command vs library only. Prefer one command if adapters stay under ~100 lines.
3. Baseline metrics snapshot must be taken **before** Phase A merges.

---

## Self-audit (required)

1. **Could a brand-new session execute without questions?** Yes — §5 current state, §9 steps name files and gates, §12 access, Phase A is explicitly the only first session. Supporting: §5, §9, §10, §12.
2. **Does it carry background, nuance, and rejections?** Yes — §3 trigger, §6 root cause, §7 rejected approaches (including wrong-fleet and failed library shape), §8 locked vs open. Gap found and fixed: fleet membership and implement/write paths (StepFun F1/F4) are locked in §8 and scoped in §4.
3. **Is the ultimate goal clear for judgment calls?** Yes — §1 plain English + "goal wins" rule; judgment criteria in §8 OPEN list.

**Audit result: PASS** (2026-09-29). Checklist: 13 sections present; goal up top; rejected approaches written; steps have file:line + gates; adversarial table present; locked/open labeled; out-of-scope listed; tests named; terms defined; secrets by location; DoD includes merge/review/live-proof; HANDOFF.d link present.

---

## Handoff link

See [`HANDOFF.d/2026-09-29T2205Z-edge-dev-mimo-reviewer-pipeline-wrapup.md`](HANDOFF.d/2026-09-29T2205Z-edge-dev-mimo-reviewer-pipeline-wrapup.md).
