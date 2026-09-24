---
issue: 542
status: OPEN
owner: claude/542-muse-phase-d-0923
---

# HANDOFF — ai-muse Phase D (native default flip) leftover work (2026-09-23 23:13 UTC, edge-dev, Claude)

Executable plan: [`plan_ai-muse-native-engine-parity.md`](../plan_ai-muse-native-engine-parity.md) (read STATUS first). Tracking issue: [popcre/ai-devops#542](https://github.com/popcre/ai-devops/issues/542). Prior handoff: [`2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md`](2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md) (still OPEN; retire it only when Phase D is fully closed).

## 0. DECISIONS ONLY THE OWNER CAN MAKE

**Already settled — do NOT re-ask:**

- **2026-09-17, Albert:** switch `ai-muse` to native Muse Code CLI once wrapper gaps are closed; OpenCode stays as explicit fallback (`AI_MUSE_ENGINE=opencode`).
- **2026-09-18, Albert:** NO Claude and NO Codex reviewer. Independent reviews use `bin/ai-grok-review` or `ai-qwen --governed-verdict` only.

**Blocking / needs owner (put the whole list to the owner in ONE message before work):**

1. **None for ordinary Phase D completion.** Finish D3 merge and D4 observation as engineering work — no owner decision required if the gates below still hold.
2. **Grok auth hard-link after state moved to D: (not part of #542; nobody assigned).** Machine fact 2026-09-23: `C:\Users\ahazan\.local\state\ai-devops\grok` → `D:\ai-data\local\state\ai-devops\grok`. `prepare_auth_link` cannot make a same-inode auth link across volumes; `winsymlinks:nativestrict` also fails (`Operation not permitted`). Workaround used all day: `AI_GROK_STATE_DIR=/c/Users/ahazan/.local/state/ai-devops/grok-c`. Incident record: `20260923T182146Z-edge-dev-grok-279371`. **Recommendation:** keep the C: workaround and open a later ai-devops fix so default `ai-grok-review` works after any D: relocation. **Blocks:** none of #542 if the env var is set. **Out of this workstream** — no one is on it.
3. **muse-code durable store / model catalog was deleted mid-session** under `~/.local/share/ai-devops/muse-code/` (likely a local suite cleanup with a leaked profile path; not proven). Doctor then FAILs catalog lines until a live muse-code turn regenerates `muse/model-catalog/`. **Recommendation:** one tiny paid `ai-muse` turn (or D4's live round) restores it; do not hand-edit a catalog. **Blocks:** D4 preflight doctor PASS.

## 1. What this application is

`popcre/ai-devops` is Albert's public AI-workflow recovery toolkit (Windows, Git Bash, `edge-dev`). `bin/ai-muse` gives Claude/Codex named Muse Spark 1.3 Contributor conversations and read-only governed reviews. Two engines: **muse-code** (Meta's pinned native CLI) and **opencode** (pinned harness). Consumers: interactive sessions (`ask-muse`) and `popcre/shared-db`'s governed review preflight (`ai-muse doctor` → `PASS  <check>` lines).

## 2. What we set out to do this session, and why

Execute **Phase D** of `plan_ai-muse-native-engine-parity.md` in order D1–D4: live-qualify the native engine, update shared-db `REVIEWERS` evidence, flip the default to muse-code, then observe one real governed Muse review and close #542.

Trigger: owner decision 2026-09-17 to switch once the wrapper had parity plus native extras (Phases A–C already landed).

## 3. Current state — what is true right now

Checked 2026-09-23 ~23:13 UTC.

| Step | State | Evidence |
|---|---|---|
| D1 Live qualification | **DONE** | Muse session `review-20260923T114151Z-2415847-31868` (native `e0a41811-2a2d-4b7f-b692-0e955885dc94`), model `muse-spark-1.3-contributor`. New turn + `ask` follow-up. Reports: `C:/repos/ai-devops-worktrees/542-muse-phase-d-0923/.ai/reviews/muse-review-20260923T114151Z-2415847-31868-20260923T114159Z-2415847-32742.md` and `...-20260923T120416Z-2511437-1201.md`. Final `VERDICT: NO FINDINGS` under `require_verdict: 1`. Non-null usage (input 944980 / cache_read 856991; ask 199782 / 114658), `catalog_cost_estimate` 0.014548482 and 0.008887516 USD with provenance. Cited on [#542 comment](https://github.com/popcre/ai-devops/issues/542#issuecomment-5794520101). |
| D2 shared-db REVIEWERS | **DONE** | `popcre/shared-db` PR [#3433](https://github.com/popcre/shared-db/pull/3433) **MERGED** 2026-09-23T22:33:31Z. `muse-spark-1.3-contributor` `readsRepositoryVerified` date `2026-09-23` with native-engine evidence is on `origin/main` (verified via `git show origin/main:scripts/manage-migration-author-lanes.mjs`). Independent Grok 4.6 APPROVE at original head `8a3dd7c6` (session `d2rev-8a3dd7c6b`); another session later stacked commits (`cdeb17c1`) and the PR still landed our row. Non-orchestrator scripts work — no db-work issue. |
| D3 Default flip | **IN FLIGHT** | `popcre/ai-devops` PR [#725](https://github.com/popcre/ai-devops/pull/725) **OPEN**, `mergeStateStatus: BLOCKED`, **auto-merge ON** (method MERGE). Branch `claude/542-muse-phase-d-0923`, head **`cf9aabea280ba91a160b0749b27a2319fe99380f`** (rebased on `6a6b2ca3`). Two commits: `74f11e40` / rebased `feat(muse): Phase D3 — default engine is muse-code` (bin/ai-muse default `muse-code`, test expectation, docs/muse-opencode.md native section, task-router) + `cf9aabea` `fix(muse): pin OpenCode suite to AI_MUSE_ENGINE=opencode` (tests/test-ai-muse.sh ENV + every `exec env` site; skills/shared/ask-muse/SKILL.md). Grok 4.6 **APPROVE** at `cf9aabea` (session `d3fix-cf9aabea`, report `.ai/reviews/grok-d3fix-cf9aabea-20260923T215535Z-2149303.md`). Comment on PR: [#725 comment](https://github.com/popcre/ai-devops/pull/725#issuecomment-5803795690). Offline: `tests/test-ai-muse-code.sh` **83 passed / 0 failed** (1 SKIP native symlink). Missing binary: `start_failed: local_dependency_unavailable: LOCAL Muse Code 1.3.0-R3233.1 is not installed at <path>`. `tests/test-muse-opencode-contract.sh` pass (13 fixtures). `tests/test-ai-muse.sh` was mid-run at **119 ok / 0 FAIL** including the previously broken key-cmdline and post-open staging tests after the engine pins — finish/re-run before claiming the full suite green. |
| D4 Post-flip governed Muse round + close #542 | **NOT STARTED** | Blocked on D3 landing (default must be muse-code on main for a true post-flip round) and on regenerating the model catalog for doctor PASS. |

**Worktrees (live — do not delete):**

- `C:\repos\ai-devops-worktrees\542-muse-phase-d-0923` — branch `claude/542-muse-phase-d-0923`, tree clean, **unmerged** (PR #725). Contains the D3 commits and D1 Muse reports under `.ai/reviews/` (gitignored private reports).
- `C:\repos\shared-db\.claude\worktrees\542-d2-reviewers-muse-native-0923` — branch `claude/542-d2-reviewers-muse-native-0923`. Our commit `8a3dd7c6` is an ancestor of merged PR #3433; later heads came from another session (`aa47` / #3442). Tree clean. Safe to clean only after confirming no other session still uses that worktree.

**Preview / production:** N/A this session. No migrations, no preview apply, no production commands.

## 4. Everything we tried that did NOT work

1. **`bash` from PowerShell hits WSL bash** (`Windows Subsystem for Linux has no installed distributions`). Always use `"C:\Program Files\Git\bin\bash.exe"`. Do not trust `bash` on PATH in this host tool.
2. **Host tool `ChildProcess.kill` on long commands** (paid turns, `ai-gh`, suites, `ai-pr-wait`). Processes often keep running; recover by reading the report/session files, never by replaying paid work. Prefer short `ai-gh` calls; do not combine `Start-Sleep` with a tool call in one Bash invocation.
3. **Grok `prepare_auth_link` dies after grok state relocated C:→D:** (see §0.2). `AI_GROK_STATE_DIR` on C: is the working workaround. Same-volume hard link works (verified inode match).
4. **D3 first Grok review REJECT (`d3flip-b8e82666`)** — real bug: `tests/test-ai-muse.sh` never set `AI_MUSE_ENGINE=opencode`, so after the default flip every OpenCode stub call selected muse-code and died `local_dependency_unavailable`. Also stale `skills/shared/ask-muse/SKILL.md` trial wording. **Fixed** in `cf9aabea`. Do not undo those pins.
5. **`--tests "bash tests/test-ai-muse-code.sh"` on Grok** made the packet run a ~15–20 min suite and the shell died before a verdict. Owner rule: `--tests` must be fast (`python tests/fixtures/muse-code/usage_cases.py -q`).
6. **shared-db `gh pr merge --auto`** → `Auto merge is not allowed for this repository`. **`--admin`** → refused on required status `Migration guarded merge authorization`. Real path: `gh workflow run "Guarded Merge" -f pull_request=<n> -f head_sha=<sha>` (`.github/workflows/guarded-migration-merge.yml`). PR #3433 later merged without us needing that (another session / queue). Do not assume `--squash --admin` for shared-db code PRs; docs-only handover PRs have a different fast path in `shared-db-handover`.
7. **Ephemeral `supabase/tests` Docker `toomanyrequests`** (twice) — infrastructure, not the one-line REVIEWERS change. Rerun (`gh run rerun --failed`) eventually passed (7m14s).
8. **`tests/test-ai-muse.sh` flake class** (`worker exited after 1s without reaching that state`, fork `Resource temporarily unavailable`) under process-table pressure — timing/fixture, not always the engine bug. After engine pins the same tests passed.
9. **Stash during a base-comparison test timed out with `git stash pop` not run** — recovered immediately (`git stash pop`). Never leave D3 work stashed.
10. **Cannot `gh pr review --approve` your own PR** (`u2giants`). Use a `VERDICT: APPROVE` comment + independent wrapper review; GitHub review UI approval needs another account.
11. **`ai-gh pr diff` / several `ai-gh` calls** repeatedly hit ChildProcess.kill near wrap-up — state above was read from earlier successful calls.

## 5. Root causes and key findings

- **Supported Muse verdict option is `ai-muse review`** (sets `REQUIRE_VERDICT=1`, appends `VERDICT: FINDINGS|NO FINDINGS`). Do not treat `REQUIRE_VERDICT` as a free-standing env contract for callers.
- **Usage lives in the durable store**, not stdout; retained as `.retained_turn.usage_json` with catalog-priced estimate and provenance (Phases A–B).
- **OpenCode stub suites must pin `AI_MUSE_ENGINE=opencode`** after the default flip (`tests/test-ai-muse.sh:159` ENV and every `exec env` worker).
- **shared-db merge for scripts is not `gh pr merge` alone** while `Migration guarded merge authorization` is required; non-migration PRs are authorized inside Guarded Merge / merge-queue gate (`docs/owner-rulings.md` ~834).
- **Another session can push onto a shared PR branch** (observed on #3433). Verify with `git show <remote-head>:<file>` before assuming your hunk is gone; never force-push over unknown commits.
- **`~/.local/share/ai-devops/muse-code/` is disposable private XDG state** (catalog + durable sessions). Losing it does not lose wrapper metadata under `~/.local/state/ai-devops/muse/sessions/`, but doctor catalog checks fail until a live turn recreates the catalog.

## 6. Exact next steps

1. **Finish D3 landing.** In `C:\repos\ai-devops-worktrees\542-muse-phase-d-0923` (or a fresh worktree from current `origin/main` + the same commits):
   - `bin/ai-pr-wait 725` (or poll `bin/ai-gh pr checks 725 --repo popcre/ai-devops`) until offline shards are green.
   - Confirm `gh pr view 725 --repo popcre/ai-devops --json state,mergedAt` is `MERGED` (auto-merge should land it).
   - Re-run `bash tests/test-ai-muse.sh` to completion if #725's CI did not already prove it; require **0 FAIL**.
   - *Gate:* PR #725 MERGED; `git show origin/main:bin/ai-muse` contains `ENGINE="${AI_MUSE_ENGINE:-muse-code}"`.
2. **Regenerate the model catalog** with one live muse-code turn (e.g. `AI_MUSE_CALLER=claude bin/ai-muse doctor` then a tiny `new`/`review`) so `ai-muse doctor` shows catalog PASS lines again.
   - *Gate:* `AI_MUSE_CALLER=claude bin/ai-muse doctor` prints `PASS  Muse Code model catalog is present and parseable` and a visible `muse-spark-1.3-contributor` row.
3. **D4 — one real governed shared-db review that draws Muse** after the default flip is on `main`:
   - Watch an actual shared-db review round (assignment, `reviewerExecutionPreflight` / `ai-muse doctor` PASS, verdict with coverage, usage present).
   - Cite assignment ref + verdict + usage pointers on #542 (no raw transcripts/prompts/keys/JSONL).
   - *Gate:* evidence comment on #542 naming the review event.
4. **Closeout of #542** (same session as D4 success):
   - Update `plan_ai-muse-native-engine-parity.md` STATUS rows D1–D4 with artifacts (D1 comment link; D2 PR #3433 merge; D3 PR #725 merge; D4 review event).
   - Close #542.
   - Delete `HANDOFF.d/2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md` and this file under the successor rule (issue closed, outcome on main, obligations carried).
   - End `ai-task-gates`; clean `542-muse-phase-d-0923` worktree only after PR #725 is MERGED.
5. **If D4 cannot draw Muse organically**, do not fake a review; record the wait and use `ai-blocker-watch` only for a real GitHub-blocked-by dependency — otherwise keep observing shared-db governed reviews.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue on `popcre/ai-devops`; never push `main`. Ident must be `Albert Hazan <u2giants@users.noreply.github.com>` (`git var GIT_COMMITTER_IDENT`).
- Canonical `C:\repos\ai-devops` is **landing-only**. Edit only in task worktrees.
- Reviewer safety: `ai-task-gates start --class reviewer-safety` (already recorded for this worktree at base `4d9a3857`). Independent exact-head review before merge; **no Claude/Codex reviewers**.
- Pin Grok packets with `--base <exact origin/main SHA>`; `--tests` fast only.
- Public repo: never commit transcripts, keys, private JSONL.
- Keep both engines; fail closed on usage honesty; OpenCode remains selectable via `AI_MUSE_ENGINE=opencode`.
- Do not edit another session's `HANDOFF.d/` file or rewrite root `HANDOFF.md`.
- shared-db: non-orchestrator scripts/docs stay out of the structure orchestrator.

## 8. Access and environment

- Machine: `edge-dev`, Windows, Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- GitHub via `bin/ai-gh` / `bin/ai-pr-wait` (spacing + locks). Session sign-off: `Posted by Claude chat unknown on edge-dev` (`CLAUDE_CODE_SESSION_ID` empty).
- Muse key: 1Password vault `vibe_coding`, item "Meta ai Muse Spark API Key", field `api key` — **never print**. `op` 2.39.0 via WinGet Links (doctor PASS).
- Grok: `grok 1.0.13 (5e9a58528b76)` at `C:\Users\ahazan\.grok\bin\grok.exe`. Use `AI_GROK_STATE_DIR=/c/Users/ahazan/.local/state/ai-devops/grok-c` until §0.2 is fixed.
- Pinned Muse Code `1.3.0-R3233.1` (`config/muse-code/version` + sha256). Private XDG under `~/.local/share|state|config/ai-devops/muse-code*`.
- D1 evidence pointers are local under the Phase D worktree `.ai/reviews/` and session metadata `~/.local/state/ai-devops/muse/sessions/9ff4b3333e08/claude--review-20260923T114151Z-2415847-31868.json`.

## 9. Open questions and risks

- **D3 CI** (2026-09-23): many `linux-offline-shard` / `windows-offline-section` jobs were pending when last read; auto-merge should complete. If a shard fails, fix forward on the same PR — do not revert the engine pins.
- **Catalog wipe root cause** (2026-09-23): suspected test cleanup with real `USERPROFILE`/XDG; not proven. If it recurs, audit `tests/test-ai-muse-code.sh` and `tests/fixtures/muse-code/delete_cases.sh` for profile leaks — as a **new** issue, not during wrap-up.
- **PR #3433 multi-session stack** (2026-09-23): `aa47` added `#3442` evidence commits on our branch. Our REVIEWERS row is on main; do not rewrite that history.
- **D4 may not draw Muse immediately** (2026-09-23): rotation is grok/qwen/muse/gemini. Wait for a real Muse draw; do not synthesize assignment evidence.
- **Grok capacity warning** `unsupported-interface` (2026-09-23): reviews still completed with real tokens/cost; treat as noise unless a turn returns no verdict.

---

### Self-audit (handoff-writer gate)

1. **Comprehensive for a brand-new developer?** Yes — §1 app, §2 goal, §3 exact SHAs/PRs/worktrees, §4 dead ends, §6 ordered steps with gates.
2. **As effective as this session?** Yes — §0 machine blockers (Grok D: link, catalog wipe), §5 non-obvious contracts (`ai-muse review`, engine pins, Guarded Merge), §8 access.
3. **Every relevant detail?** Yes — failures with why (§4), constraints (§7), risks (§9), secrets by location only (§8).
4. **Section 0 complete?** Yes — settled owner decisions listed; the two out-of-band machine items (Grok auth, catalog) are promoted with recommendations; no other owner ask hides in §1–§9. Engineering leftovers are in §6 and do not need Albert.

Posted by Claude chat unknown on edge-dev
