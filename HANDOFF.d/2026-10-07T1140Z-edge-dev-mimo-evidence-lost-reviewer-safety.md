---
issue: 1323
status: OPEN
owner: mimo/evidence-lost-reviewer-safety
---

# HANDOFF — evidence-lost recording for non-GLM and killed-wrapper reviewers

Machine: edge-dev · Agent: mimo · Written: 2026-10-07 7:40 AM EDT (wrap-up)
GitHub signature: `Posted by MiMo chat unknown on edge-dev`

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already decided (do not re-ask):**
  - Watchdog duty pool is done and shipped. Never rebuild it. Claim issue is #1288. Never pay Blacksmith for alarms. (2026-10-05)
  - Never ask a human to approve technical actions. Assigned AI reviewers gate them. (owner ruling 2026-09-28)
  - Never ask Albert to run, click, or set up anything.
  - PR #1323 (durable-publish + qualify-live inherit) and PR #1328 (caller detect + glm symlink) are merged. Do not reopen them.
- **Still his:** nothing for this workstream. Evidence-record completeness is technical.
- **Not Albert's call:** how `evidence-lost` is generalized past GLM, whether a killed wrapper can record loss, or whether the `entry_live` carve-out gains a unit test.

## 1. What this application is

`popcre/ai-devops` — Albert's public AI workflow recovery toolkit (not an app or service). This handoff covers one **reviewer-safety** gap: the event ledger can only record `evidence-lost` for GLM, and only when a `finished` row exists, so a class of orphans can never be reconciled. Host: edge-dev (Windows, Git Bash at `"C:\Program Files\Git\bin\bash.exe"` — bare `bash` is WSL and fails).

## 2. What we set out to do this session, and why

Resume `HANDOFF.d/2026-10-06T2027Z-edge-dev-mimo-reviewer-durable-publish-and-incidents.md`: land PR #1323, green and merge PR #1328, clear incidents `20261006T063919Z` / `20261006T123753Z` / `20261006T135550Z`. Albert then asked for the leftover orphan-sweep residual to be fixed. That cleanup surfaced the evidence-lost limitation this handoff now owns.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| PR #1323 durable-publish + qualify-live inherit | **MERGED** | merge `b1bd3ad8c3d8e656daa12092c51ec2ad9c43e8c0` (2026-10-07T00:32:02Z) |
| PR #1323 independent review @ `e71ba048` | **APPROVE** | `.ai/reviews/pr-1323-e71ba048-independent-final-review.md` + PR comment |
| PR #1328 caller detect + glm symlink + mem-sync autocrlf | **MERGED** | merge `1220359e6d7d2559026a70577184d44004dc4385` (2026-10-07T00:27:04Z) |
| PR #1329 muse doctor pin / PR #1330 qwen skip-broken | **MERGED** (previous session) | `f34c401` / `592ab45` |
| Incident `20261006T063919Z` gemini requalify | **resolved** | `.ai/reviewer-issues/20261006T063919Z-edge-dev-gemini-4162832/resolutions/` |
| Incident `20261006T123753Z` codex publish/sandbox | **resolved** | retest report `.ai/reviews/codex-final-check-20261007T005115-1537840-2011.md`, ledger run `83741ca0e6b8403caeab08853e7a9abb` `evidence_state=verified` |
| Incident `20261006T135550Z` codex probe | **resolved** (stray probe) | `resolutions/20261006T214356074808900-28977-45.json` |
| Orphan sweep residual | **SWEPT-HEALTHY** | `.ai/reviewer-issues/maintenance-orphan-sweep-20261007/`; quarantine `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/` |
| **evidence-lost generality** | **OPEN — this handoff** | see §5 and §6 |
| MiMo as `--implementer` | **OPEN** (design question) | `config/reviewer-registry.json` has no `mimo` row; `ai-review --implementer mimo` refuses |

## 4. Everything we tried that did NOT work

1. **Landing #1323 by re-queue alone** — ejected 6× from the merge queue. The failure was `FAIL runtime-only drift requalifies live automatically then reviews` in `tests/test-ai-gemini.sh`, not flake and not unrelated: #1323's `reviewer_event_run_is_open` inherit made `auto_requalify`'s `qualify-live` probe inherit the open review run, so `bind_sandbox` refused the fixture (`sandbox evidence source differs from invocation`).
2. **Treating that gemini failure as a pre-existing main flake** — true only in combination. The test passed on main without #1323 and on #1323 without main; the merge-group combination is what failed. Local repro: merge `origin/main` into the #1323 worktree and run `tests/repro-autoq.sh` (since deleted) or the gemini suite.
3. **`ai-gh pr merge 1323 --auto` reporting "already queued" while `autoMergeRequest` is null** — trust the command output and the `merge_group` run list, not the GraphQL field.
4. **`ai-pr-wait` without `--repo`** — on this machine it sometimes cannot determine the repository; pass `--repo popcre/ai-devops`.
5. **Orphan sweep as a delete-everything pass** — unsafe. 41 dirs were ordinary failed post-fix reviews, test debris, or unsealed packets. They were quarantined with a README (classes A–E), not deleted.

## 5. Root causes and key findings

1. **qualify-live must never open-run-inherit.** Fix landed in `e71ba048` (inside #1323): `tools/reviewer_event_guard.sh` only open-run-inherits for non-probe entry commands; `qualify-live` / `doctor --live` keeps only the direct-child re-entry of its own recorder. Declining inherit also `unset`s the outer identity so the probe begins its own invocation. Regression: `tests/test-ai-gemini.sh` → `runtime-only drift requalifies live automatically then reviews`.
2. **`evidence-lost` is not general.** `LOST_REPORT_PROVIDERS={"glm"}` and `record_lost`'s finished-row requirement leave non-GLM and killed-wrapper runs permanently unreconcilable. Observed while sweeping orphans: 85 test-fixture orphans stuck because `verify_reports`/`invocation()` cannot accept an already-recorded `evidence-lost.json` when the run_id never entered `events.jsonl`. **This is the reviewer-safety PR this handoff owns.** Do not weaken fail-closed gates for new runs to make old garbage disappear.
3. **`bin/ai-glm` (and any wrapper sourcing `tools/lib/provider-wrapper-common.sh`) must `readlink -f "${BASH_SOURCE[0]}"`** — plain `dirname` breaks under the installed `/usr/local/bin` symlink that `doctor` tests. Landed in #1328.
4. **`tests/test-ai-memory-sync.sh` `private_sync` needs `GIT_CONFIG core.autocrlf=true`** like `sync_a`, or Linux CI writes a spurious CRLF commit. Landed in #1328.
5. **`prose` task class forbids `review`.** A fixture under `tests/*.txt` classifies `prose` and blocks `ai-review`. Use a `code`-class path (e.g. `tests/*.sh`) for review-path tests.
6. **Gemini junction vs drift-guard are different failure classes.** `ERROR_UNTRUSTED_MOUNT_POINT` (incident 022654Z) ≠ mid-qualification drift guard at `bin/ai-review-preflight:617` (incident 063919Z). Do not conflate.
7. **Windows:** Git Bash only via `C:\Program Files\Git\bin\bash.exe`. Reviewer CI (windows-reviewer-fallback-*) can take 45+ minutes; that is not a hang.

## 6. Exact next steps

1. **Open the evidence-lost reviewer-safety PR.** Goal: a killed wrapper or non-GLM provider whose report never published can still record `evidence-lost` against its run, and the sweep can reconcile it, without weakening the fail-closed path for a live review that still owes a report.
   - Read `tools/reviewer_events.py` (`record_lost`, `verify_reports`, `invocation`), `tools/reviewer_maintenance.py`, and the `LOST_REPORT_PROVIDERS` allowlist wherever it is defined.
   - Work in a dedicated worktree on a new branch. Branch + PR + merge queue; never push `main`.
   - You'll know it worked when: (a) a killed-wrapper fixture and a non-GLM fixture can both be recorded as evidence-lost and the orphan sweep retires them; (b) a live review that still owes a report is still refused (the fail-closed case is unchanged); (c) `tests/test-ai-review-engine.sh` / maintenance tests cover both fixtures; (d) independent review at the exact head is APPROVE (reviewer-safety — use a registered provider via `bin/ai-review`, never `--implementer mimo`).
2. **Optional follow-on (same PR or a second one):** add a unit test for the `entry_live` carve-out at `tools/reviewer_event_guard.sh` (~lines 128–138). Medium from the #1323 independent review; currently covered only end-to-end by the gemini auto-requalify check.
3. **MiMo implementer recording (still open, separate).** `ai-review --implementer mimo` refuses: no `mimo` row in `config/reviewer-registry.json`. Decide registry row vs documented alias. Technical; gate with assigned AI reviewer before merge. Do not flip `registry_state` to make a review succeed.
4. **Optional worktree cleanup** only after GitHub shows MERGED: `C:/repos/ai-devops-wt-reviewer-durable-publish` and `C:/repos/ai-devops-wt-caller-detect` qualify (both PRs merged). `C:/repos/ai-devops-wt-inc950377` holds an unpushed disposable retest fixture (`mimo/inc950377-retest`) — safe to delete only if you do not need that fixture; the durable evidence already lives in the incident dir.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push `main`. `git var GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Reviewer-wrapper / evidence-tool / safety-test changes are **reviewer-safety**: independent exact-head final review required before merge. Use a **registered** provider (`muse`/`grok`/`qwen`/`gemini`/`deepseek`) via `bin/ai-review`. Never `--implementer mimo`.
- GitHub only via `bin/ai-gh`; waits via `bin/ai-pr-wait --repo popcre/ai-devops --timeout-minutes N` / `bin/ai-gh-wait`. No `gh run watch`, no unbounded loops.
- Times in human output: EST. Secrets: 1Password vault `vibe_coding` only.
- Do **not** redo watchdog, PR #1286/#1193, or touch `C:\repos\ai-devops-wt-runner-pool`.
- Canonical checkout `C:/repos/ai-devops` is landing-only. Write work in worktrees.
- Never `git clean` / force-push / broad stage. Stage only task-owned files.
- Do not flip `registry_state` to make a review succeed. Do not `--skip-doctor` as a fix.
- `bash` bare = WSL. Use Git Bash full path.
- Always pass **full 40-char** SHAs to `--assert-head`.
- Orphan/sweep repairs: quarantine + README over delete; keep backups. A clean sweep's own `evidence_state=verified` is the proof standard.

## 8. Access and environment

- Hosts: edge-dev (Windows). `gh` as `u2giants`.
- Git Bash: `C:\Program Files\Git\bin\bash.exe`.
- Event ledger: `~/.local/state/ai-devops/reviewer-events/events.jsonl`. Evidence-loss records: `~/.local/state/ai-devops/reviewer-events/evidence/<run_id>/evidence-lost.json`.
- Orphan quarantine: `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/` (README classes A–E). Sweep maintenance note: `C:/repos/ai-devops/.ai/reviewer-issues/maintenance-orphan-sweep-20261007/`.
- Reviewer incidents store: `.ai/reviewer-issues/` under `C:/repos/ai-devops` (gitignored).
- If `ai-gh` says "invalid GitHub quota state", remove leftover `~/.ai-devops/gh-throttle/quota.*.tmp.*` files.

## 9. Open questions and risks

- **evidence-lost generality** is the open technical gap (§5 item 2). Residual TOCTOU on open-run inherit and managed-copy trust in `sandbox_source_chain` remain Low, recorded by independent review of #1323; do not reopen unless a real failure appears.
- **MiMo as implementer** still unrecorded for independence (§6 step 3).
- **Merge-queue auto-merge flag drops** across waits/crashes; re-queue with `bin/ai-gh pr merge <n> --auto` and confirm via `bin/ai-gh run list --event merge_group`.
- **16-orphan examination cap** is a real wall when many remnants pile up; the sweep tooling may deserve a higher cap or a batch retire path in the same reviewer-safety PR if it blocks again.

---

## Part (b) — sub-agent dispatches this session

| Agent | Asked | Did | Left / not done |
|---|---|---|---|
| general-1 | Land PR #1323 | Diagnosed 6× queue ejection as the gemini auto-requalify FAIL; stopped as blocked (called it flake/unrelated) | Root cause was #1323×main inherit interaction — fixed by coordinator |
| general-2 | Fix PR #1328 CI | glm `readlink -f` + mem-sync `autocrlf`; **MERGED** `1220359e` | n/a |
| general-3 | Clear gemini incident 063919Z | **resolved** (drift-guard class, not junction) | Handoff mislabel corrected in resolution |
| general-4 | Clear probe incident 135550Z | **resolved** (stray probe, evidence kept) | n/a |
| general-5 | Clear codex incident 123753Z | Investigation only; waited on #1323 | Retest done later by general-7 |
| general-6 | Independent review #1323 @ `e71ba048` | **APPROVE** (Medium: no unit test for `entry_live`) | Unit test optional follow-on |
| general-7 | Retest/clear codex 123753Z | **resolved** with live codex final-check + verified ledger | Raised orphan-sweep residual |
| general-8 | Fix pre-fix orphaned sandboxes | **SWEPT-HEALTHY**; quarantined 41 dirs; no code change | Raised evidence-lost gap |

---

## Self-audit (handoff-standard)

1. **Cold start?** Yes — §1–§3 name repo, merged PRs, SHAs, incident states, and the open evidence-lost gap.
2. **As effective as me?** Yes — §4 dead ends (queue eject root cause, already-queued quirk), §5 causes with file names, §6 next commands + verify lines, part (b) per agent.
3. **Failures included?** Yes — §4 (6× eject misread as flake; autoMergeRequest null quirk; wait without `--repo`; delete-all sweep).
4. **Concrete next steps + verify?** Yes — §6 step 1 with four success conditions.
5. **Terms/paths explained?** Yes — worktrees, ledger, quarantine, Git Bash path, reviewer-safety, `--assert-head`.
6. **§0 sweep?** Yes — no Albert decision required; already-decided list present.

**Synthesis:** A brand-new developer can open the evidence-lost reviewer-safety PR from §6 alone, with §4–§5 preventing the mistakes this session already paid for.
