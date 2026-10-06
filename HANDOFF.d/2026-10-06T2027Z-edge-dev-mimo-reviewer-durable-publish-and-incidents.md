---
issue: 1323
status: OPEN
owner: mimo/reviewer-durable-publish-and-incidents
---

# HANDOFF — reviewer durable-publish repair and 20261005 incident clear-out

Machine: edge-dev · Agent: mimo · Written: 2026-10-06 4:27 PM EDT (wrap-up)
GitHub signature: `Posted by MiMo chat unknown on edge-dev`

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already decided (do not re-ask):**
  - Watchdog duty pool is done and shipped. Never rebuild it. Claim issue is #1288. Never pay Blacksmith for alarms. (2026-10-05)
  - Never ask a human to approve technical actions. Assigned AI reviewers gate them. (owner ruling 2026-09-28)
  - Never ask Albert to run, click, or set up anything.
- **Still his:** nothing for this workstream. Reviewer-wrapper repairs, incident status, and merge-queue waits are technical.
- **Not Albert's call:** which provider door to fix first, whether to re-try quarantined Qwen, how inheritance/security tradeoffs in `tools/reviewer_event_guard.sh` land, or whether PR #1323/#1328 merge.

## 1. What this application is

`popcre/ai-devops` — Albert's public AI workflow recovery toolkit (not an app or service). This handoff covers **reviewer-tool repair**: durable publication of formal review reports and the open `.ai/reviewer-issues/` incidents from 2026-10-05/06. Host: edge-dev (Windows, Git Bash at `"C:\Program Files\Git\bin\bash.exe"` — bare `bash` is WSL and fails).

## 2. What we set out to do this session, and why

Resume `HANDOFF.d/2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md`: make formal reviews publish a durable report (VERDICT + full head SHA) and clear the 20261005 incidents. Albert then asked to "spin up subagents to fix all the problems." Goal: land the durable-publish fix and repair each open incident with evidence.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Durable-publish root cause | **Fixed in PR #1323** (not merged) | branch `mimo/reviewer-durable-publish` head `740dc59b83295035b78b2da9724d5f7060e85ceb` |
| Independent review PR #1323 | **APPROVE** at `740dc59` | `.ai/reviews/pr1323-independent-final-review-740dc59.md` + PR comment |
| Muse final-check proof | **Done** | `.ai/reviews/muse-final-check-20261006T021601-3569665-25348.md` — `## Verdict` REJECT + full head `53be241e9529162d77966c9f645e146b84e3dd2c` (event ledger `evidence_state=verified`) |
| PR #1330 qwen allocator skip-broken | **MERGED** on main | merge `592ab45fd6c2debd66f0aca8f037ec749e6a4998` (2026-10-06T13:41:28Z) |
| PR #1329 muse doctor pin | **MERGED** on main | merge `f34c401d694f939469e594789bca2f05fc9e3e7a` |
| PR #1328 glm/gemini caller detect | **OPEN, CI not green** | branch `mimo/wrapper-caller-autodetect` head `44893db` (after this wrap-up's commit) |
| Gemini requalify 20261006T022654Z | **resolved** | transient `ERROR_UNTRUSTED_MOUNT_POINT` on `C:\Users\ahazan\.gemini` junction → `D:\ai-data\gemini`; retry passed |
| Qwen incident 20261005T154002Z | **resolved** | PR #1330 |
| Muse incident 20261005T154619Z | **resolved** | PR #1329 |
| Gemini durable-publish 20261005T121424Z | **partially-resolved** | fixed publish path; gemini quarantine + MiMo implementer registry remain |
| Codex capacity 20261005T134647Z | **partially-resolved** | durable-publish half fixed; provider capacity/cancel remain |
| GLM caller 20261005T205656Z | **partially-resolved** | wrappers fixed in #1328; shared-db `run-governed-review.mjs` still only detects claude/codex |
| Empty 20261005T134136Z / 134324Z dirs | **quarantined** | `.ai/reviewer-issues/quarantine-empty-record-20261006/` (no issue.json, zero files) |
| New incidents still OPEN | **OPEN** | `20261006T063919Z-edge-dev-gemini-4162832` (requal again), `20261006T123753Z-edge-dev-codex-950377` (publish/sandbox), `20261006T135550Z-edge-dev-codex-1657368` ("probe") |

PR #1323 was reported "already queued to merge" (merge commit `727499ae4b6452e2f3ed748e4bae43517f9078f0`); after app crashes the auto-merge flag may have dropped — re-check and re-queue with `bin/ai-gh pr merge 1323 --auto`.

## 4. Everything we tried that did NOT work

1. **`kill -0` liveness for nested inherit** — unreliable across MSYS process trees (same reason `AI_REVIEW_EVENT_OWNER_PID` is shell-local). Inheritance refused in live pool→runner even though unit smoke tests passed (same bash tree).
2. **`[ PARENT = PPID ] || [ -n PARENT ]`** — reduced to a bare non-empty check. Independent review REJECT caught it. Replaced with open-ledger gate (started row, no finished, provider match).
3. **Nested-inherit test without a ledger `started` row** — correctly failed after the open-run gate landed. Independent review High. Fixed by seeding `started` rows in the test.
4. **`bind_sandbox` immediate-source-only compare** — pool snapshots live tree, runner snapshots again; marker source is the pool sandbox, invocation repo is the live worktree → "sandbox evidence source differs from invocation". Fixed by `sandbox_source_chain` walk.
5. **Short `--assert-head` SHAs** — engine/packet refuse abbreviated SHAs (`source-head-mismatch: expected 53be241; actual 53be241e9529…`). Always pass the full 40-char SHA.
6. **`ai-review --implementer mimo`** — refused: MiMo is not in `config/reviewer-registry.json`. Still open as a design question (registry row vs alias).
7. **Grok final-check** — `non-terminal stopReason: cancelled` (provider). Engine correctly retained sandbox+packet.
8. **Subagent general-9 / general-11 on #1328 CI** — both died (app crash / process restart) mid-work. Partial commits landed (`0555198` suite manifest; `44893db` AI_GLM_CALLER export). CI was still failing at wrap-up.
9. **Bare `bash` in this environment** — resolves to WSL. Always `"C:\Program Files\Git\bin\bash.exe"`.

## 5. Root causes and key findings

1. **Durable-publish failure (the 20261005 gemini/muse symptom):** `ai-review-pool` reserves `require-report` on its invocation, then launches the provider runner from the pool sandbox. The runner's guard only matched direct children (`PPID == AI_REVIEW_EVENT_PARENT`), so nested runners began a **second** invocation and never published onto the reserved run_id. Cleanup then printed `required report is not durably published` even when review text was on disk. Fix in `tools/reviewer_event_guard.sh`: inherit when `AI_REVIEW_EVENT_PROVIDER` matches, `AI_REVIEW_EVENT_RUN_ID` is set, parent matches **or** the run is still open in the ledger (`reviewer_event_run_is_open`).
2. **Sandbox chain:** runners call `ensure-copy` again from inside the pool sandbox. `bind_sandbox` (`tools/reviewer_events.py`) must accept the original repo behind the managed-copy chain (`sandbox_source_chain`). Cycle-safe.
3. **Allocator draw:** `allocatableReviewers()` (shared-db `manage-migration-author-lanes.mjs`) skips providers with `usable:false`. `bin/ai-review-preflight` now honors a `known-broken` marker **before** live-qualification and emits `provider_unavailable` (PR #1330).
4. **Muse doctor pin:** installed is Muse Code 1.4.2-R4684.1; pin already tracked it from #1250. Hardened the mismatch path (PR #1329) so drift refuses with found vs supported named, never executes a hash-unverified binary.
5. **Caller detection:** `ai-gemini` / `ai-glm` now take explicit `AI_*_CALLER` / `--caller`, else harness markers (`MIMO_*` process env), else `caller_identity_missing` (fail closed). PR #1328.
6. **Gemini `.gemini` junction:** `C:\Users\ahazan\.gemini` → `D:\ai-data\gemini` can fail `ERROR_UNTRUSTED_MOUNT_POINT`; retry usually clears. Prior qualification versions are preserved across failed requalification.
7. **Windows test invocation:** Git Bash only via `C:\Program Files\Git\bin\bash.exe`. Engine suite takes >5 minutes on edge-dev.

## 6. Exact next steps

1. **Land PR #1323.** Confirm it is queued (`bin/ai-gh pr merge 1323 --auto` if not). Wait with `bin/ai-pr-wait 1323 --timeout-minutes 30`. You'll know it worked when `gh api repos/popcre/ai-devops/pulls/1323` shows `"merged": true` and the commit is reachable from `origin/main`.
2. **Finish PR #1328 CI.** Worktree `C:/repos/ai-devops-wt-caller-detect` branch `mimo/wrapper-caller-autodetect` at `44893db`. Failing checks at wrap-up: `linux-offline-shard (2)`, `windows-offline-section (4, blacksmith)`, `linux-offline`, `windows-offline`, `verification-closure`. Fetch job logs via `bin/ai-gh`. Likely remaining: suite-manifest / OS filter for `test-reviewer-caller-detection.sh`, and any suite that still runs glm without a caller. Then `bin/ai-gh pr merge 1328 --auto`. You'll know it worked when zero checks are FAILURE and the PR is queued/merged. Independent review already APPROVE'd `6a71ca1`.
3. **After #1323 lands, clear the three new incidents** (do not invent resolutions):
   - `20261006T123753Z-edge-dev-codex-950377` (sandbox evidence unreconciled / publish) — retest a codex final-check on a small PR with the landed guard; resolve or partially-resolve with the report path + repair commit.
   - `20261006T063919Z-edge-dev-gemini-4162832` — another automatic requalify failure; same junction class as `20261006T022654Z`. Retry requalify; if it passes, resolve with the qualification record.
   - `20261006T135550Z-edge-dev-codex-1657368` summary "probe" — inspect `details.redacted.txt`; likely a stray record. Resolve or quarantine with evidence; do not delete without reading.
4. **MiMo implementer recording** (from incident 121424Z partial): decide registry row vs documented alias so `--implementer mimo` (or `AI_IMPLEMENTER_ENGINE=mimo`) records independence. Technical. Gate with assigned AI reviewer before merge.
5. **Optional:** `cleanup-worktree` only for worktrees whose branches are **merged** (`mimo/qwen-skip-known-broken` and `mimo/muse-doctor-version-pin` may qualify once GitHub shows MERGED). **Never** delete `C:/repos/ai-devops-wt-reviewer-durable-publish` or `C:/repos/ai-devops-wt-caller-detect` until their PRs merge.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push `main`. `git var GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Reviewer-wrapper / evidence-tool changes are **reviewer-safety**: independent exact-head final review required before merge.
- GitHub only via `bin/ai-gh`; waits via `bin/ai-pr-wait` / `bin/ai-gh-wait` with explicit `--timeout-minutes`.
- Times in human output: EST. Secrets: 1Password vault `vibe_coding` only.
- Do **not** redo PR #1286/#1193 or touch `C:\repos\ai-devops-wt-runner-pool`. Watchdog duty-pool is done.
- Canonical checkout `C:/repos/ai-devops` is landing-only. Write work in worktrees.
- Never `git clean` / force-push / broad stage. Stage only task-owned files.
- Do not flip `registry_state` to make a review succeed. Do not `--skip-doctor` as a fix.
- `bash` bare = WSL. Use Git Bash full path.

## 8. Access and environment

- Hosts: edge-dev (Windows). `gh` as `u2giants`.
- Git Bash: `C:\Program Files\Git\bin\bash.exe`.
- Worktrees used this session:
  - `C:/repos/ai-devops-wt-reviewer-durable-publish` — PR #1323 (`mimo/reviewer-durable-publish`)
  - `C:/repos/ai-devops-wt-caller-detect` — PR #1328 (`mimo/wrapper-caller-autodetect`)
  - `C:/repos/ai-devops-wt-qwen-skip-broken` — PR #1330 merged
  - `C:/repos/ai-devops-wt-muse-doctor-pin` — PR #1329 merged
- Reviewer incidents store: `.ai/reviewer-issues/` under `C:/repos/ai-devops` (gitignored).
- Event ledger: `~/.local/state/ai-devops/reviewer-events/events.jsonl`.
- Stale `~/.ai-devops/gh-throttle/*.tmp.*` were quarantined to `quarantine-tmp-20261005/`; if `ai-gh` says "invalid GitHub quota state", remove leftover `quota.*.tmp.*` files.

## 9. Open questions and risks

- **PR #1323 merge-queue membership** may have dropped across app crashes (auto-merge flag was observed both set and unset). Re-queue before assuming it will land. (2026-10-06)
- **PR #1328 CI** still failing at wrap-up after two crashed subagents; `44893db` may not be sufficient. (2026-10-06)
- **`reviewer_event_run_is_open` + inheritance** trusts env `AI_REVIEW_EVENT_*` for nested grandchildren while the run is open. Fail-closed on finished/mismatched provider; residual TOCTOU noted as Low by independent review. (2026-10-06)
- **`bind_sandbox` chain walk** trusts managed-copy markers (model-writable); HEAD equality is the backstop. Low residual from independent review. (2026-10-06)
- **MiMo as implementer** still unrecorded for independence. (2026-10-05)
- **New incidents** from 2026-10-06 may be the same classes as 20261005; do not close without per-incident evidence.

---

## Part (b) — sub-agent dispatches this session

| Agent | Asked | Did | Left / not done |
|---|---|---|---|
| general-1 | Qwen allocator skip-broken | PR #1330 `fd4c79b`, incident qwen-353210 **resolved**; merged `592ab45` | n/a |
| general-2 | Muse doctor version pin | PR #1329, pin already 1.4.2; hardened refuse path; incident **resolved**; merged `f34c401` | n/a |
| general-3 | GLM/Gemini caller detect | PR #1328 `6a71ca1` + tests; incident glm-943796 **partially-resolved** | shared-db launcher still claude/codex-only |
| general-4 | Independent review #1323 @ `9b1cb9f` | **REJECT** (failing nested test, provider-blind open check, missing chain tests) | n/a |
| general-5 | Gemini requalify incident | Root cause junction/`ERROR_UNTRUSTED_MOUNT_POINT`; requalify passed; incident **resolved**; no code change | n/a |
| general-6 | Re-review #1323 @ `740dc59` | **APPROVE** | n/a |
| general-7 | Independent review #1328 @ `6a71ca1` | **APPROVE** (one Low test-coverage gap) | n/a |
| general-8 | Independent review #1330 @ `fd4c79b` | **APPROVE** (Medium: `check_provider` ignores marker; Lows) | n/a |
| general-9 | Fix #1328 CI | **Cancelled/died** after `0555198` suite-manifest commit | CI still red |
| general-10 | Finish #1328 CI | **Failed** (process restart) after more attempts | CI still red |
| general-11 | Finish #1328 CI green | **Failed** (process restart, abandon threshold) | Left uncommitted `AI_GLM_CALLER=test` glm test line; wrap-up committed it as `44893db` |

---

## Self-audit (handoff-standard)

1. **Cold start?** Yes — §1–§3 name repo, PRs, SHAs, incidents, and that #1323/#1328 are the open landings.
2. **As effective as me?** Yes — §4 dead ends, §5 causes with file names, §6 next commands + verify lines, part (b) per agent.
3. **Failures included?** Yes — §4 (inherit/liveness, chain compare, short SHAs, three crashed CI agents).
4. **Concrete next steps + verify?** Yes — §6.
5. **Terms/paths explained?** Yes — worktrees, ledger, junction, Git Bash path, reviewer-safety.
6. **§0 sweep?** Yes — no Albert decision required; already-decided list present.

**Synthesis:** A brand-new developer can land PR #1323, finish #1328 CI, and clear the three new incidents using this file + the existing reviewer-issues docs, without touching finished watchdog work. Evidence: §3 table, §6 verify lines, part (b).
