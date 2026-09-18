---
issue: none (deliberate — see §7; do not open one retroactively just to close it)
status: OPEN
owner: kimi/gemini-prepare-timeout-20260918
---

# ai-gemini prepare-phase hang — diagnosis done, fix written; ship phase remains

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking / will happen during ship:**

1. **Gemini re-qualification after merge.** This fix changes `bin/ai-gemini`'s
   bytes, and the wrapper's live qualification binds the exact wrapper SHA-256
   (`runtime_qualified()` in `bin/ai-gemini`). The moment the merge installs,
   every Gemini review will refuse with quarantine until re-qualified.
   *Recommendation:* the ship session runs `ai-gemini doctor --live` (the
   designed qualification path — real but bounded provider calls in a private
   fixture) right after install verification, and confirms `ai-gemini doctor`
   prints `PASS`. Blocks: any further governed Gemini review.

**A wrong guess is recoverable:**

2. **Default prepare bound of 30m per step.** Chosen so a healthy large-repo
   review still passes and a stalled one fails in tens of minutes instead of
   never. Env-overridable via `AI_GEMINI_PREPARE_TIMEOUT` — no code change
   needed to tune. *Recommendation:* keep 30m; revisit only if healthy reviews
   start timing out.

**Not part of this work and nobody is on it:**

3. **The hashing root cause is still slow.** The fix converts an unbounded
   hang into a terminal failure, but the byte inventories still spawn one
   `sha256sum` process per file; the shared-db review snapshot has 30,384
   files, which measured at >0.6 s/spawn under load on edge-dev — hours per
   pass even when "working". Batching (`xargs -0 sha256sum` preserves the exact
   digest stream) would fix the root cause. *Recommendation:* open a separate
   follow-up issue/PR for batched hashing; do not fold it into this PR.
4. **Three dead governed reviews left stale artifacts on edge-dev** (see §5):
   lock dirs with dead owner PIDs, one orphaned RUNNING metadata row, two
   published sandboxes. They belong to other sessions' governance
   (review-3264-1 is another session's; Albert's instruction stands: do not
   kill or clean another session's review). *Recommendation:* leave them; the
   owning sessions' `acquire()` safely reclaims dead-owner locks by design.
5. **edge-dev is saturated by another session's reviewer suites** (qwen-*
   sandbox fixtures appearing in the production sandbox dir through at least
   12:51 local; test spawn baseline measured 22–37 s vs ~1 s idle). Every
   timing-sensitive local check on this box is currently slow.
   *Recommendation:* none required; noted so slow local suites are not
   misread as product breakage.

**Already settled — do NOT re-ask:**

- Do not kill or clean the other session's review-3264-1 (or any other
  session's) processes/artifacts without proving that session dead — Albert,
  this task, 2026-09-18. (Both recorded owner PIDs are in fact already dead;
  nothing was killed by this session.)
- Only the agent that opened an issue closes it — Albert, same task. No issue
  was opened by this session; none may be closed by the ship session.
- Work on a branch via a uniquely named worktree; verify the branch before
  every commit; never push to `main`; merge through the queue.
- The `reviewer-safety` task class is protected and cannot be acknowledged or
  owner-requested away; it requires local tests + one exact-head independent
  review before merge.
- No ZCode reviewer, ever (owner ruling 2026-09-17). GLM never reviews
  GLM-orchestrated work. This is Kimi-orchestrated work, so Codex or Grok
  review is appropriate.

**Instruction to the next session:** put items 1–5 to Albert in ONE message
before starting work, not one at a time.

## 1. What this application is

`popcre/ai-devops` (local canonical checkout `C:\repos\ai-devops`) is Albert's
public recovery toolkit for a multi-model AI workflow: reviewer wrappers,
lifecycle scripts, skills, and docs. It is not an app/service. This task
concerns one wrapper, `bin/ai-gemini`, which runs delegated Gemini reviews in
a disposable repository snapshot with byte-identity evidence gates. The wrapper
is invoked in governed mode by `u2giants/shared-db`'s
`scripts/run-governed-review.mjs` as
`ai-gemini new --governed-verdict <sha> <session> --prompt-file ...`.
Installed launchers in `C:\Users\ahazan\.local\bin\` simply `exec` the repo
checkout's `bin/ai-gemini`, so the canonical checkout IS the live code — never
edit it directly; work only in the worktree named below.

## 2. What we set out to do this session, and why

Governed Gemini reviews hung indefinitely before the session started on
edge-dev on 2026-09-18, blocking shared-db PR review lanes:

- review-3272 (shared-db PR #3272): started 14:46:54Z, lock dir
  `~/.local/state/ai-devops/gemini/locks/session-0052c5f5416d-claude-review-3272/`
  created, no session metadata ever written; Albert killed it ~15:45Z after
  55 minutes; deepest process was a childless bash subshell.
- review-3264-1 (shared-db PR #3268, issue #3264, ANOTHER SESSION's review):
  started 14:11:20Z, hung the same way (lock
  `session-3914b22b173a-claude-review-3264-1`, owner PID 165949).
- codex pr-3248-governed-v2 (repo `C:/repos/shared-db-wt-3248`): started
  15:47:17Z, same signature (lock
  `session-00f73f6b4830-codex-pr-3248-governed-v2`, owner PID 480892).

Task (Albert, verbatim intent): find which step of `new()` in ai-gemini stalls,
fix it in popcre/ai-devops by branch and PR, and make the wrapper bound that
step with a timeout that fails terminally so the governed runner records a
failure instead of hanging. Do not kill the other session's review-3264-1
without checking whether that session is alive. Use a uniquely named worktree;
verify its branch before every commit; only the agent that opened an issue
closes it.

## 3. Current state — what is true right now

- **Diagnosis: complete and evidence-backed** (§5). All three hangs sat in
  `new()`'s pre-session prepare phase — after the session lock was acquired,
  before the PREPARED metadata write — dominated by the two unbounded
  per-file hashing passes `inventory()` / `source_inventory()`.
- **Fix: written, not yet committed.** Worktree
  `C:/repos/ai-devops-worktrees/gemini-prepare-timeout-0918`, branch
  `kimi/gemini-prepare-timeout-20260918` (created from `origin/main`
  `51af436e85cf8690c6f2c76b648dab482f5928bf`; note local `main` in the
  canonical checkout was 1 commit BEHIND origin/main at fetch time —
  always branch from `origin/main`).
  - `bin/ai-gemini` (+20/-6): new `PREPARE_TIMEOUT="${AI_GEMINI_PREPARE_TIMEOUT:-30m}"`;
    `timeout 30s` on the `agy --version` probe in `require_local_runtime`;
    new `bounded_inventory` / `bounded_source_inventory` helpers
    (`export -f` + `timeout "$PREPARE_TIMEOUT" bash -euo pipefail -c ...`);
    `timeout` bounds on `ai-review-packet resolve/build/verify` and
    `ai-review-sandbox ensure-copy` in `new()`; the same bounded inventories in
    `call()`, `verify_model()`, `ask_existing()`, and `finish()`; every failure
    message contains "timed out after $PREPARE_TIMEOUT" and names its step;
    post-provider inventory failures preserve paid evidence via
    `preserve_failure` (new stages `provider-copy-inventory`,
    `provider-source-inventory`, `model-copy-inventory`,
    `model-source-inventory`). Digest construction itself is UNCHANGED (same
    functions, same pipelines) — only bounded.
  - `tests/test-ai-gemini.sh` (+29/-2): mock sandbox/packet gain
    `MOCK_ENSURE_COPY_SLEEP` / `MOCK_PACKET_BUILD_SLEEP` hooks; new section
    "== prepare-phase terminal timeout bounds" with 8 checks covering a stalled
    snapshot step, a stalled packet build, and a stalled byte inventory
    (sha256sum sleep-trigger scoped to `$MOCK_COPIES` paths only), asserting
    terminal failure, step-named "timed out" message, no session metadata, no
    held lock, and bounded wall-clock via `budget 2 30`.
  - `bash -n` passes on both files; all 13 edit anchors were verified unique
    before each edit; the full diff was re-reviewed after editing.
- **Focused test suite: RUNNING at cutover time**, detached and
  self-terminating: `timeout 1500 bash tests/test-ai-gemini.sh` writing
  `<worktree>/.tmp-gemini-tests.log`, completion marker
  `<worktree>/.tmp-gemini-tests.rc` (contains `rc=N`). At 17:56Z it was at
  check ~14/~75 and green so far; the box is so loaded (spawn baseline 22–37 s)
  that the 1500 s bound will probably kill it near the end — if `.rc` says
  `rc=124`, rerun with a larger bound (§6 step 2). First 14 checks all passed,
  including the quarantine gates.
- **Nothing is committed or pushed.** `git status` in the worktree shows
  exactly `M bin/ai-gemini`, `M tests/test-ai-gemini.sh`, plus the two
  `.tmp-gemini-tests.*` scratch files (delete before commit; never commit them).
- Task class declared: `ai-task-gates start --class reviewer-safety` recorded
  for this worktree at base 51af436e.
- The canonical checkout `C:\repos\ai-devops` is untouched except two
  pre-existing untracked files `.tmp-issue596.err/.json` — someone else's,
  leave them.
- No GitHub issue was opened for this incident (see §7); no issue was touched.

## 4. Everything we tried that did NOT work

- **Albert's candidate steps (require_local_runtime, guard_quarantine,
  reviewer_event_evidence, sandbox/docker start) were mostly exonerated by
  lock/metadata evidence before any repro.** The session lock existed but
  PREPARED metadata did not; `require_local_runtime`, `guard_quarantine`, and
  `ai-review-packet resolve` all run BEFORE the lock is taken, so they
  completed; `reviewer_event_evidence` runs inside `call()` AFTER the metadata
  write, so it was never reached. The user's "docker start" candidate does not
  exist — `ai-review-sandbox` is pure git+cp, no containers.
- **Untracked-file bloat theory:** the review-3264-1 source worktree
  (`C:/repos/fix-3264-38439936`) has 0 untracked-not-ignored files and 1,993
  tracked files. Not the cause.
- **Event-ledger lock theory:** `tools/reviewer_events.py event_lock()` uses a
  kernel lock with a hard 10-second deadline and fails closed ("event ledger
  writer is busy"). It cannot produce a 2-hour hang. Dead end.
- **"It hangs every time, deterministically":** repro attempts today do NOT
  hang — `ai-review-sandbox digest` on the 3264-1 source completed in 5.1 s;
  `ai-review-packet verify` on the 3272 packet failed fast in 9.7 s
  (source-head-mismatch, expected — the source worktree has moved on). The
  stalls were load-dependent slowness, not a deadlock. Do not chase a lock
  cycle; none exists.
- **Foreground 285 s test run:** the suite cannot finish on the loaded box
  inside the tool cap. It must run detached with a self-terminating `timeout`
  and a marker file (as done), or on a quieter box.
- **`du -sh` on the sandbox as a sizing probe:** timed out at 120 s because the
  tree has 30k files. Use `find | wc -l` (≈1 s) instead.

## 5. Root causes and key findings

- **Stall locus (proven):** `new()` in `bin/ai-gemini` between
  `begin_new` (writes `<locks>/session-*/owner`) and `write "$m"` (PREPARED
  metadata). Steps in that window: `ai-review-sandbox ensure-copy`,
  `ai-review-packet build`, `ai-review-packet verify`, `inventory "$d"`,
  `source_inventory "$r"`. For review-3272 the sandbox and ALL packet files on
  disk are timestamped 10:47–10:48 local, one minute after start — so build
  finished and the 57-minute stall was in verify/inventories; verify was
  reproed fast, leaving the inventories.
- **Root cause:** `inventory()` (`bin/ai-gemini:98`) hashes EVERY file in the
  disposable copy INCLUDING `.git` with one `sha256sum` process per file, and
  `source_inventory()` (`bin/ai-gemini:99`) does the same per tracked/untracked
  file in the source. The shared-db snapshot contains **30,384 files**
  (`find … | wc -l`, 1 s). A 300-file probe of the per-file loop exceeded 180 s
  (>0.6 s/spawn) under current load → one `inventory("$d")` pass = 5+ hours.
  Each review turn runs several such passes (2 in `new()`, 4 in `call()`, 4 in
  `verify_model()`). This is why "the deepest process was a childless bash
  subshell": the `$(...)` capture subshell sits in the read loop while its
  one-file-at-a-time children cycle.
- **Evidence chain (all on edge-dev, all times UTC):** lock owner PIDs 271751
  (review-3272), 165949 (review-3264-1), 480892 (codex pr-3248) are ALL dead
  now (tasklist confirms; nothing was killed by this session). Session
  metadata exists ONLY for 3264-1:
  `~/.local/state/ai-devops/gemini/sessions/3914b22b173a/claude--review-3264-1.json`
  — status RUNNING, created 16:17:06Z, i.e. PID 165949 unblocked after 2h06m,
  reached the provider step, then vanished without a metadata update
  (hard-killed; EXIT trap never ran). Ledger
  `~/.local/state/ai-devops/reviewer-events/events.jsonl` has only "started"
  events for all three runs (14:11:20Z, 14:46:54Z, 15:47:17Z) and no
  completions. review-3272's sandbox
  `~/.local/state/ai-devops/review-sandboxes/gemini-0052c5f5416d-claude-review-3272-f680b0cc3c92`
  and its `.ai-review-…/` packet (MANIFEST.sha256 present) are complete on disk.
- **Runner contract (why terminal failure is the right fix):**
  `runGovernedReview` (`scripts/run-governed-review.mjs:437` in shared-db)
  spawns the wrapper with NO timeout — an indefinite wrapper hang hangs the
  governed lane forever. On a non-zero exit it classifies stderr via
  `wrapperFailureReason` (`/timed out|deadline|time limit/i` → "the wrapper
  reported a timeout") and records a failure. `NON_VERDICT_TERMINAL_REASONS`
  (`scripts/orchestrator-flow/start-reroute.mjs:64`) is only
  `['turn_limit_cancelled']`, so a timeout is a recorded failure, NOT an
  auto-reroute — no verdict is ever fabricated.
- **Installed = repo:** `C:\Users\ahazan\.local\bin\ai-gemini` is a 4-line
  launcher (`export HOME="/C/Users/ahazan"; exec "/C/repos/ai-devops/bin/ai-gemini"`).
  Merging to main changes live behavior immediately; it also changes the
  wrapper SHA-256 → automatic re-quarantine (see §0 item 1).
- **Kimi Bash PATH gap:** this Kimi session's PATH lacks jq and the wrappers.
  jq lives at
  `/c/Users/ahazan/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe`;
  export it before using repo tooling (`export PATH="$PATH:<that>"`).
  Claude/Codex sessions get it from the Windows user PATH.
- **Concurrency note:** another session is actively running reviewer suites on
  this box (qwen-* fixture dirs appearing in the PRODUCTION
  `~/.local/state/ai-devops/review-sandboxes/` through ≥12:51 local). Expect
  slow spawns; do not disturb its dirs.

## 6. Exact next steps

1. `cd /c/repos/ai-devops-worktrees/gemini-prepare-timeout-0918` and verify:
   `git rev-parse --abbrev-ref HEAD` prints `kimi/gemini-prepare-timeout-20260918`
   and `git status --porcelain` shows only the two modified files plus
   `.tmp-gemini-tests.*`. Gate: branch name exact, no unexpected files.
2. Test evidence: if `.tmp-gemini-tests.rc` exists and says `rc=0` and the log
   ends with `N passed, 0 failed` — done. If `.rc` is missing or says `rc=124`,
   rerun detached with a bigger bound:
   `export PATH="$PATH:/c/Users/ahazan/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe" && rm -f .tmp-gemini-tests.log .tmp-gemini-tests.rc && ( timeout 3600 bash tests/test-ai-gemini.sh > .tmp-gemini-tests.log 2>&1; echo "rc=$?" > .tmp-gemini-tests.rc ) &`
   then poll every few minutes. Gate: `rc=0`, `0 failed`, and the 8 new
   "prepare-phase terminal timeout bounds" checks all `ok`. If a new check
   fails, suspect (a) `budget 2 30` math on a loaded box (wall-clock assertion
   too tight — measure, then adjust using tests/lib-test-timing.sh
   conventions), or (b) the sha256sum sleep trigger matching a path outside
   `$MOCK_COPIES` (scope it tighter).
3. `rm -f .tmp-gemini-tests.log .tmp-gemini-tests.rc`; confirm
   `git status --porcelain` shows exactly two modified files.
4. `git var GIT_COMMITTER_IDENT` must print
   `Albert Hazan <u2giants@users.noreply.github.com>`. Then re-verify the
   branch (step 1) and commit ONLY the two files:
   `git add bin/ai-gemini tests/test-ai-gemini.sh` (never `git add -A`).
   Suggested message:
   `fix(ai-gemini): bound prepare-phase steps with terminal timeouts`
   with a body summarizing: three governed reviews hung pre-session on
   edge-dev 2026-09-18; root cause = unbounded per-file hashing passes; fix =
   `AI_GEMINI_PREPARE_TIMEOUT` (default 30m) bounds on ensure-copy, packet
   resolve/build/verify, and both inventory passes in new/ask/call/verify_model/
   finish, plus a 30s runtime probe bound; failure messages name the step and
   say "timed out" so run-governed-review.mjs records a terminal failure;
   digest construction unchanged; wrapper hash change re-quarantines Gemini
   (requalify after install). Gate: `git show --stat HEAD` lists exactly the
   two files.
5. Commit this handoff file as its own commit on the same branch
   (`docs(handoff): ai-gemini prepare-timeout ship phase`), unless the fix
   commit landed first — order between the two commits does not matter.
   Gate: two commits ahead of origin/main, branch verified.
6. Push: `git push -u origin kimi/gemini-prepare-timeout-20260918`.
   Gate: `git status` shows branch up to date with origin.
7. Open the PR via `bin/ai-gh` (EVERY GitHub call goes through `bin/ai-gh` —
   machine lock, spacing, rate budget): `bin/ai-gh pr create --repo popcre/ai-devops --base main --head kimi/gemini-prepare-timeout-20260918 --title "fix(ai-gemini): bound prepare-phase steps with terminal timeouts" --body …`.
   Body must include: the 2026-09-18 incident summary (three hangs, evidence),
   the stall locus, the root cause with the 30,384-file / >0.6s-spawn numbers,
   the runner-contract note (recorded failure, not reroute), the
   requalification warning, and the test evidence. Do NOT write "Fixes #" for
   any issue, and do not reference issue #3264 as yours — it is another
   session's. Gate: PR URL printed.
8. Wait on CI with `bin/ai-pr-wait <pr>` (bounded, event-aware; never
   `gh run watch`; at most one GitHub call per 5 minutes per waiter). While
   checks run, do independent useful work (e.g. draft the §0 item-3 follow-up
   proposal text for Albert, without opening it). Gate: required checks green;
   any failure surfaced immediately.
9. Reviewer-safety gate (protected class): run ONE read-only exact-head final
   review before merge — invoke the `ai-reviewer` skill (Codex second opinion)
   against the exact PR head SHA. Codex or Grok only — never ZCode; GLM is
   allowed since this is not GLM-orchestrated work. If the reviewer finds
   issues, fix, retest, re-push, and re-review the NEW head; log any reviewer
   malfunction with the `log-reviewer-issue` skill. Gate: substantive verdict
   naming the exact head SHA, saved under `.ai/reviews/` per the skill.
10. Merge through the merge queue (never direct to main; the queue tests the
    exact landing commit — do not re-verify a commit the queue already proved).
    Gate: PR state MERGED.
11. `git -C /c/repos/ai-devops fetch origin` and confirm the intended squash
    commit is on `origin/main`. Gate: `git log origin/main --oneline -1` names
    the landed change.
12. Post-merge operational step (§0 item 1, confirm Albert's go-ahead):
    `ai-gemini doctor` should now print `QUARANTINED`; run
    `ai-gemini doctor --live` (bounded live qualification in a private
    fixture), then confirm `ai-gemini doctor` prints `PASS`. Gate: PASS output.
13. Closing report: landed commit SHA, CI/queue evidence, reviewer verdict +
    head SHA, requalification result. Explicitly report: the three dead reviews'
    stale locks/sandboxes were deliberately left untouched (§0 item 4); no
    issue was opened or closed; and any drift this session discovered that
    affects downstream work (reciprocal end-of-phase rule). This handoff file
    is deleted by the session that finishes the next step of this workstream
    under the successor rule — after verifying the merge commit is on main.

## 7. Constraints and gotchas in force

- Never push to `main`; the protected branch uses a merge queue. The canonical
  checkout `C:\repos\ai-devops` is landing-only — all edits happen in the
  worktree. Verify the worktree branch before EVERY commit.
- Stage only task-owned files: `bin/ai-gemini`, `tests/test-ai-gemini.sh`,
  `HANDOFF.d/<this-file>`. Never `git add -A`; never commit `.tmp-*` scratch.
- Every GitHub call through `bin/ai-gh`; waits through `bin/ai-pr-wait` /
  `bin/ai-gh-wait`; ≤1 GitHub call per 5 min per waiter; no open-ended loops.
- `ai-task-gates` class `reviewer-safety` is already declared for this
  worktree; it rechecks the real change set before ship actions and cannot be
  waived. Required proofs: local tests + exact-head independent review.
- Do not run a local FULL test series overlapping a GitHub job on this host
  (`bin/ai-test-local --check-collision` returned "unknown — runner status
  unavailable" at 17:50Z; a single focused suite is proportionate, a full
  series is not).
- No issue was opened for this incident on purpose: Albert directed the task
  in chat, and "only the agent that opened an issue closes it" would strand
  closure across the session cutover. If Albert wants one, open it and let the
  SAME session carry it through closure.
- The wrapper's own lock `acquire()` safely reclaims dead-owner locks; the
  three stale lock dirs (`session-0052c5f5416d-claude-review-3272`,
  `session-3914b22b173a-claude-review-3264-1`,
  `session-00f73f6b4830-codex-pr-3248-governed-v2`) are therefore harmless to
  future DIFFERENT-named sessions — but their names belong to other sessions'
  governance. Leave them (§0 item 4).
- `finish()`'s packet verify and `ask_existing`'s drift gates were also bounded;
  messages deliberately distinguish "timed out" from "changed" so a timeout can
  never masquerade as source drift (which would wrongly refuse recovery).
- Local time on edge-dev is EDT (UTC-4); ledger/metadata timestamps are UTC.

## 8. Access and environment

- `git push` to origin works from the worktree; `gh` is authenticated but MUST
  be called via `bin/ai-gh`.
- No secrets are needed for any step; 1Password is not involved.
- jq for Kimi Bash: export the WinGet path in §5 before repo tooling.
- Test suite needs no network and no provider contact (offline mocks;
  `agy`/`sandbox`/`packet` are fixture binaries; `AI_REVIEW_EVENT_DIR` is
  redirected to the suite's TMP dir).

## 9. Open questions and risks

- 2026-09-18: Is 30m/step the right default? No healthy large-repo Gemini
  review has been timed recently on edge-dev; the number is a judgment call
  (§0 item 2). Risk: a healthy but slow big-repo review could now fail at the
  bound; mitigation: `AI_GEMINI_PREPARE_TIMEOUT` env override, and the §0
  item-3 batching follow-up removes the pressure entirely.
- 2026-09-18: The hung-then-hard-killed review-3264-1 left metadata stuck at
  RUNNING with a dead process. Its owning session must run its own recovery;
  from this wrapper's side the lock owner is dead, so `acquire()` will reclaim
  it for a same-named retry — that is the designed path, not a risk this fix
  introduces.
- 2026-09-18: The focused suite may not have completed at cutover (box load).
  §6 step 2 owns that risk; no product-code change is contingent on it beyond
  test-only adjustments.
- 2026-09-18: `timeout`'s kill of a `bash -c` child kills the child's process
  group (GNU coreutils semantics, no `--foreground`), which is what makes the
  bounded inventory passes actually die. If a future platform ships a `timeout`
  without process-group kill, the inventory pipeline could orphan a hashing
  child — no such platform is in use today (GNU coreutils on Git Bash and
  Linux CI).
