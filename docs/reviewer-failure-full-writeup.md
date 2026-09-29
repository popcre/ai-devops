# Full write-up — why AI reviewers keep failing (2026-09-29)

**Owner:** Albert Hazan  
**Prepared by:** MiMo chat on edge-dev  
**Purpose:** one complete record of what went wrong, all background, no dropped nuance.  
**Plan of record:** [`plan_reviewer-pipeline-core.md`](../plan_reviewer-pipeline-core.md)  
**Evidence folder:** [`reviewer-failure-evidence/`](reviewer-failure-evidence/)

This document is the investigation dossier. The plan is what to build next. If they disagree, stop and flag it — the goal in the plan §1 wins.

---

## 1. The business problem (Albert’s words)

Reviewers fail “over and over and over.” The team does “fix after fix after fix endlessly.” Albert is a business owner, not a programmer. He wants the cycle to stop, not another wrapper.

He talks to AI through four desktops: **Claude Desktop for Windows, ChatGPT desktop for Windows, MiMo Desktop, and z.ai ZCode for Windows.** Those are how he works with agents. They are **not** the review fleet.

### Who is who (owner-corrected 2026-09-29 — do not contradict)

| Role | Who | Behavior |
|---|---|---|
| **Reviewers** (the broken pipeline) | **Muse, Grok, Qwen, StepFun, DeepSeek, Gemini** | Produce a **full suggestion report** — not an accept/reject click. They can also **write code** (implement paths). |
| **Writers / orchestrators** | Claude, Codex | Write and drive work. `ai-claude-review` / `ai-codex-review` exist as approval-gate helpers; they are **not** the rotation review fleet. |
| **Out of rotation** | Kimi, GLM | Not active reviewers. |

**Earlier wrong framing (retired):** an intermediate draft treated “Claude and Codex only” as the review fleet and proposed scoping the rebuild to those two. Albert corrected this. Gemini’s first critique also leaned on that wrong fleet. Every later critic was re-briefed with the corrected pack (`reviewer-failure-evidence/extensive_reviewer_background.md`).

---

## 2. How we investigated (method, not vibes)

### 2.1 Transcript study (Jev)

- Source: private multi-machine chat transcript archive (paths withheld from this public repository).
- TypeSafe Jev (`jev` Noul questions; key via `op run` from 1Password vault `vibe_coding`, item `typesafe.ai API` — value never logged).
- Rebuilt inventory over **35 days** (5 weeks): **4,580 sessions** (claude + codex + grok).
- Jev question: is this conversation primarily about **reviewer failures / review pipeline being broken**?
- Discard rule: only when Jev was **≥90% confident NOT** reviewer-failure (`noul < 0.10`).
- Result: **2,591 discarded**, **1,989 remainder**, plus keyword-window excerpts (~23,595 snippets).
- Focus ranking: sessions with `noul ≥ 0.7` (~95) read first; then path names (flaky-reviewer, log-reviewer, stepfun-reviewer, gemini-qwen-quarantine, etc.).

Full labels and manifests were under `.ai/tmp/` (gitignored). Diagnosis output: `reviewer-failure-evidence/reviewer_failure_root_cause.md`.

### 2.2 Three read-only wrapper audits

| Audit | File | Verdict |
|---|---|---|
| Shared lifecycle | `wrapper_audit_lifecycle.md` | **Yes** — no shared core. Scoreboard accepts empty verdict and exits 0 (73/91 cases). |
| Sandbox / packet | `wrapper_audit_sandbox_packet.md` | **Partial** — sealed packet discarded after every review including successes; report text survives. |
| Quarantine / fingerprint | `wrapper_audit_quarantine.md` | **Real, narrower** — only Gemini/Qwen fingerprint-requalified; fix deletes prior qualification before live canary. |

### 2.3 Critiques of the rebuild proposal

| Critic | Verdict | What it caught |
|---|---|---|
| Gemini 3.8 Flash | REJECT / proceed-with-changes | Migration order would lock reviewers out; “library wrappers call” already failed; missing tag/TTL/flaky tests. **Wrong on fleet** (Claude/Codex). |
| StepFun Step 5 | **REVISE** | Wrong fleet in draft (F1); no forcing function (F2); would fork existing shared layers (F3); implement paths omitted (F4); wrong verdict vocabulary (F5); requalification invert unsafe (F6); storage undecided (F7); landing risks (F8). |
| Claude Opus 5 plan-review | **REJECT** | 19 findings: Phase A targets wrong cleanup sites; “keep last good” wording would authorize untested bytes; evidence copy not verifiable; `*_captured` gate unreachable as written; HTTP mapping contradicts admission classifier; doc-reachability / test collisions. |
| Grok 4.6 (extensive pack) | **REVISE** | Runner+adapters right for **review** only; implement needs a second contract; Phase A2 copies an unverifiable 3-file packet and patches Claude/Codex not the six; A contradicts itself on touching Gemini; success gate false; Grok does not actually begin/finish lifecycle; 404 ≠ outage; digest bug not in plan. |

Full texts in `reviewer-failure-evidence/`.

---

## 3. What actually goes wrong (ranked root causes)

### RC1 — Eight copies of the same governance plumbing

Identity, locking/leases, packet build, lifecycle, staleness, provider checks are copy-pasted across wrappers. `bugs.md` finding 13 already named a missing shared lifecycle core. Per-wrapper “complete” plans (90/90, 189/189 tests) never extract it. Green per-wrapper tests do not exercise a shared layer **because there is none**.

**Evidence:** `wrapper_audit_lifecycle.md`; scoreboard re-derives identity (`bin/ai-review-scoreboard:46-62`) vs lifecycle (`bin/ai-review-lifecycle:62-76`); three tools each hold `valid_provider`.

### RC2 — Finished reviews throw away their proof

EXIT traps call `packet remove` / `remove-copy`. Base pin ref `refs/ai-review-packets/<tag>` is deleted. Incident packages show `*_captured: 0`. The next failure is diagnosed from zero.

**Evidence:** `bin/ai-claude-review:91-92`, `bin/ai-codex-review:147-148`, `bin/ai-review-packet:927,935`, `bin/ai-review-sandbox:153-164`, `bin/ai-reviewer-issue:169,333`. Grok/Qwen/DeepSeek/StepFun/Muse/Gemini each have their **own** delete paths (Grok F2/StepFun F2).

### RC3 — Fixing a tool can lock that tool out

Wrapper change → `wrapper_sha256` drift → quarantine (`live-qualification-required`). Qualification record is deleted **before** the live canary (`bin/ai-review-preflight:334,350`). Failed canary leaves the reviewer worse than before the fix. Mid-canary second fix also fails it.

**Scope:** `LIVE_QUALIFIED_PROVIDERS="gemini qwen"` only — not the whole fleet (overstated in early diagnosis; corrected by audits and StepFun F1).

**Contract tension:** `tests/test-ai-review-preflight.sh:139-146` asserts failed requalification **revokes** prior (blocks untested bytes). The durable fix is **versioned records by wrapper_sha256** (keep last good **record**, stay unusable on untested bytes until a canary passes) — **not** “stay usable on old bytes” (Claude critical #1).

### RC4 — No forcing function

`bin/ai-review-lifecycle` exists to solve this and is **bypassed** by the largest reviewers: Muse, Gemini, Qwen, DeepSeek, StepFun do not call begin/finish. Grok only `observe`s. A library “wrappers should call” becomes copy #9.

**Evidence:** StepFun F2; Claude/Grok agree. The honest shape is an **Inversion-of-Control runner** that owns the template; adapters only call the provider.

### RC5 — Outages and code bugs share one repair stream

xAI 403 “no code fix”, Muse `model_not_found` 404 under shared-team load, credit exhaustion (StepFun HTTP 402 on 2026-09-29) enter the same defect stream as wrapper bugs. `tools/reviewer_admission.py` already classifies credit text and **deliberately** does not treat bare rate-limit/quota text as “needs money.” Plans that map every 403/404/429 to “outage” **mis-label** real config/code defects (Grok/StepFun).

### RC6 — Integrity and platform fragility

- **Snapshot digest mismatch (2026-09-29):** `git diff --binary HEAD` fed `tracked_diff_sha256`; Git abbreviates `index` lines to the shortest unique prefix **for that repo’s object DB**. Full source → 8 hex chars; shallow review snapshot → 7. Digests never matched → `snapshot-digest-mismatch` before any model call. This is what killed Muse and Grok when asked to critique the proposal. **Fix:** `git diff --binary --full-index HEAD` + regression tests (`core.abbrev` 12 vs 7). Reconciled on branch `fix/snapshot-digest-full-index` @ `4fa931d6`, suite 110/0 (`packaging_fix_reconcile.md`). Same-shaped uncommitted edit existed in the landing checkout; Fix B won (had tests).
- **Tag length:** sandbox maps up to 77 chars (`64+1+12`); `ai-gemini` `tag_ok` rejects >64 (`bin/ai-gemini:104` vs `bin/ai-review-sandbox:123-128`).
- **Windows/PATH/encoding** and wall-clock flaky tests (`tests/test-ai-grok-review.sh`, `tests/test-ai-kimi.sh`) mint false failures during any migration.
- **Wrong tree / source drift:** reviewers can be pointed at code they never saw (`bugs.md` #9/#10; Gemini concurrent source-drift false reject).

### RC7 — Quarantine / allocator / lease issues (secondary)

Stale leases exhausting slots, locks held hours, sessions still trying removed GLM — documented in the root-cause file; live on the shared-db side more than the local wrapper side. Not the first PR.

---

## 4. Why “fix after fix” never ends

1. Each fix patches **one copy** of the plumbing; seven others keep the bug.
2. The patch changes a fingerprint and **quarantines the repaired tool** (Gemini/Qwen).
3. Evidence of the previous failure was **deleted**, so the next diagnosis starts blind.
4. Provider outages are treated as code defects → more wrapper churn.
5. Per-wrapper tests stay green while the untested shared (or missing shared) layer remains broken.
6. Rule and plan churn without one owner of the shared core (reuse rules #167/#169).
7. Sometimes the “bug” is **no credit** (StepFun 402) or **quota** — not code at all.

---

## 5. Live incident record (this investigation)

| ID | Provider | What happened |
|---|---|---|
| `20260929T125912Z-edge-dev-muse-1965021` | muse | Critique session: `preparation_failed`, then `snapshot-digest-mismatch` + fork exhaustion. No verdict. |
| `20260929T130236Z-edge-dev-grok-1993325` | grok | Same packet error before paid turn. Later succeeded after sandbox fix install (`cost $0.305`). |
| `20260929T175853Z-edge-dev-stepfun-448943` | stepfun | HTTP 402 `quota_exceeded` mid extensive brief. **Not a wrapper defect.** Account recharged later by Albert. |
| (unlogged) | gemini | Quarantined `live-qualification-required` after wrapper/install drift — **live demonstration of RC3**. Do not force-requalify without Phase B. |

StepFun/Grok/Gemini/Claude critiques used disposable clean worktree `ai-devops-wt-gemini-critique` because **Gemini’s packet builder rejects a dirty working tree** (owner instruction).

---

## 6. What we proposed, and how critics changed it

**Original proposal** (`shared_review_core_proposal.md`): one shared review lifecycle core, thin adapters, never throw away proof, fix requalification, split outage vs code. **Wrong fleet list** and “library wrappers call” shape.

**After StepFun + Claude + Grok, the surviving direction is:**

1. **Right shape:** one **runner** (Inversion of Control) that owns governance; adapters only call the provider. **Two contracts:** `review` (suggestion report) and `implement` (isolated write). Do not thin-wrap implement the same way as review.
2. **Right first PR (safety, no fingerprint move):** put **whole-packet durable copy then delete** in the **two shared deleters everyone already calls** (`ai-review-packet cmd_remove`, `ai-review-sandbox remove_sandbox`) — full inventory (`identity.json`, marker, MANIFEST, patch + parts), re-hash, **skip delete on failure**. Wire `finish --packet-dir/--packet-sha256` where finish already runs. Baseline metrics **before** merge. **Stop.** Do not edit Gemini/Qwen wrappers in that PR.
3. **Then** requalification versioning (not “stay usable on untested bytes”), failure classes via existing admission (no blanket 404=off), runner+adapters for the **six** reviewers including implement, then retire copies after a measured window.
4. Fix digest/abbrev and tag budgets as **integrity** work (Groks’s missing item).

---

## 7. Files in this folder

| File | What it is |
|---|---|
| `reviewer_failure_root_cause.md` | Transcript diagnosis + wrapper-audit confirmation appendix |
| `wrapper_audit_lifecycle.md` | Shared-core gap, extraction targets |
| `wrapper_audit_sandbox_packet.md` | Packet discard points, empty fields |
| `wrapper_audit_quarantine.md` | Fingerprint loop, narrower scope |
| `shared_review_core_proposal.md` | **Superseded** first proposal (kept for history; wrong fleet) |
| `stepfun_critique_report.md` | StepFun REVISE (F1–F10) |
| `claude_plan_review.md` | Claude Opus plan-review REJECT (19 findings) |
| `grok_extensive_review.md` | Grok REVISE after extensive pack |
| `extensive_reviewer_background.md` | Owner-corrected pack sent to later reviewers |
| `packaging_fix_reconcile.md` | Snapshot-digest fix reconcile (Fix B wins) |
| `process_diagnosis.md` | Earlier multi-cluster process diagnosis (includes reviewer wrapper breakage) |

---

## 8. Still true / still open (at write-up time)

- Plan of record: `plan_reviewer-pipeline-core.md` — **not yet updated** for Grok/Claude critical findings (Phase A2 wrong sites, unverifiable copy, implement second contract, 404 mapping, digest fix in scope). Treat that rewrite as required before coding Phase A.
- `fix/snapshot-digest-full-index` @ `4fa931d6` is **local only** — needs independent review (safety path) + PR + install.
- Gemini remains quarantined until a governed requalification (Phase B design).
- StepFun credit was out, then recharged; next StepFun call should use the extensive pack.
- Landing checkout may still carry a subsumed uncommitted `--full-index` edit (safe to discard after reconcile).
- Muse never produced a verdict in this investigation (prep + digest failures).

---

## 9. One-paragraph summary for Albert

We keep rebuilding the same review plumbing in eight places, then deleting the proof that a review happened. When we fix a tool, the safety system sometimes locks that tool out for being changed. Some “bugs” are just empty credit. The chat history and the tools agree. The fix is not another wrapper: **one machine runs the review, the tools only answer, we keep the evidence, and we stop punishing tools for being repaired.** Before any code, the plan must take in the latest critiques (especially: patch the delete tools everyone uses, not Claude/Codex; review vs implement are different jobs).
