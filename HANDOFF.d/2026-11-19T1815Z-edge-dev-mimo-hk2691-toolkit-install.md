---
issue: 2709
status: OPEN
owner: mimo/hk2691-toolkit-install
---

# Handoff: install the toolkit release carrying the ai-housekeeping hang fix (#2691), blocked by the Windows updater crash (#2709)

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner. Everything left is technical: repair the updater defect (tracked as issue #2709) and run the toolkit install route; a session does both without asking. Nothing here needs a business ruling, budget, or access decision.

Already settled — do NOT re-ask:
- 2026-11-19: fixing the ai-housekeeping hang and shipping it was already authorized (issue #2691, closed with evidence). Do not re-litigate whether the fix should land; it landed.

## 1. What this application is

`popcre/ai-devops` is Albert's private AI-tooling repository: the maintenance scripts, skills, and wrappers every AI session on his machines uses. One of those tools is `ai-housekeeping` — a read-only inventory report of housekeeping candidates (merged-branch worktrees, duplicate branches, handoff files, plan files) in whatever repository you run it in. It is scheduled daily and also run by hand at session wrap-ups.

- Repository: https://github.com/popcre/ai-devops (branch policy: never push to `main`; branch + PR + merge queue).
- It runs on Albert's Windows and Linux machines through installed launchers that execute the script from a local toolkit checkout of the repository.
- The report classifies candidates using one bounded GitHub lookup through the machine-wide `ai-gh` throttle.

## 2. What we set out to do this session, and why

Goal (Albert's request): fix https://github.com/popcre/ai-devops/issues/2691 — `ai-housekeeping` printed nothing and was killed at 580 s when run from the designflow-data-syncing checkout; reproduce, find the block, repair, confirm the summary prints, close the issue with evidence. That goal is COMPLETE (see §3).

This handoff exists for the remainder: the fix is merged in the repository but the *installed* command on the live Windows host still runs pre-fix code, and the documented updater that would install it crashes on Windows (issue #2709).

The session also ran the DesignFlow session-start sync (six `designflow-*` repos, `develop` merged into `sandbox-albert`); that is complete and needs nothing.

## 3. Current state — what is true right now

Complete and verified:
- Fix merged to `main`: shared 60-second GitHub run budget per `ai-housekeeping` run. PR https://github.com/popcre/ai-devops/pull/2701, merge commit https://github.com/popcre/ai-devops/commit/3be36754f66476be324153d150ccdda84d8c5c0e.
- Issue https://github.com/popcre/ai-devops/issues/2691 CLOSED with before/after evidence in the closing comment.
- Tests: 23 passed, 0 failed (two new regression tests pin the shared budget). Suite also isolates `AI_HOUSEKEEPING_STATE_DIR` so it no longer scans a developer's real agent-job state directory (~6 000 files, ~20 s per case on Windows).
- Live proof on the Windows host, from a designflow-data-syncing checkout: the fixed script printed its full summary in 84 s (was: silent past 580 s), exit 0.

Still open (this handoff):
- The installed `ai-housekeeping` command on the live host runs older code: the installed toolkit checkout sits a few commits behind `main` and does NOT contain the fix. Until it is updated, running `ai-housekeeping` from a shell can still sit silent for minutes.
- Issue https://github.com/popcre/ai-devops/issues/2709 is OPEN: the documented updater `update.sh` crashes on Windows (see §4), which blocks the protected install route.
- The root `HANDOFF.md` of this repo is already the static pointer (`handoff-pointer: v1`); no migration needed. This file is the only one added by this session.

## 4. Everything we tried that did NOT work

1. **Ran the protected updater from a worktree of a different clone.** `update.sh --installed-checkout <installed checkout> --expected-head <sha>` refused immediately: "candidate does not share the installed checkout Git common directory". Reason: the candidate updater must be a worktree *of the installed checkout itself*, not of another clone of the same repository. Not a bug — wrong invocation.
2. **Ran the protected updater from a worktree of the installed checkout (the correct shape).** It crashed on its first git operation, twice (pre-fetch and fetch), in `tools/lib/install-public-git.py`:
   `AttributeError: module 'os' has no attribute 'geteuid'` at https://github.com/popcre/ai-devops/blob/main/tools/lib/install-public-git.py#L146 .
   `update.sh` invokes that helper through bare `python3` (https://github.com/popcre/ai-devops/blob/main/update.sh ), which on this Windows host is native CPython 3.13 — no `os.geteuid`, no `os.O_DIRECTORY` / `O_NOFOLLOW` / `O_CLOEXEC`, no `st_uid`. The helper is POSIX-only, so the updater cannot advance the installed checkout on Windows at all. Filed as https://github.com/popcre/ai-devops/issues/2709 . Not fixed here (closeout scope freeze).
3. **Took the original issue's suspect at face value first** ("stale worktree path warning seen from git in designflow-tracking"). Never reproduced it; `git worktree list` in the named repos is clean. It is not the block point — see §5. If that warning reappears, it deserves its own issue.
4. **Suspected the slow local inventory as the hang.** Measured it: the local-only phase takes ~48 s in the designflow-data-syncing checkout, dominated by the agent-job-records section scanning a few thousand state files twice per provider. Slow, but it always finishes — not the hang. The suite isolation (§3) removed the biggest cost for tests; the tool's own scan is unchanged.
5. **`ai-gh pr create` through the shell wrapper produced no output and created no PR** (argument mangling by the shell layer, backticks/quotes). Opened the PR with the plain `gh` CLI instead. If a future session needs `ai-gh` from a shell, write the body to a file and avoid inline special characters.

## 5. Root causes and key findings

1. **Why #2691 hung:** `ai-housekeeping` buffers its whole report and prints only at the end, while each of its GitHub calls could spend the entire 300-second per-call bound waiting in `ai-gh`'s machine-wide lock-admission queue — twice per run. A congested host therefore produced ~10 minutes of dead silence (the 580 s observation) with no output at all. Traced directly: the xtrace stops inside `gh_call pr list` in the acquire loop of `ai-gh`.
2. **Why it looked like a hang and not a timeout:** the per-call bound was doing exactly what #2320 designed (wait out throttle admission), but the budget multiplied by call count and the buffered output hid all progress. #2692 (same day) had already stopped *back-off* sleeps via `AI_GH_NO_WAIT=1`, and deliberately left lock admission waiting up to the call bound — that residual is what #2691 hit.
3. **The fix** (https://github.com/popcre/ai-devops/blob/main/bin/ai-housekeeping ): every GitHub call now draws on one shared 60-second run budget (`AI_HOUSEKEEPING_GH_BUDGET_SECONDS`) covering admission and the call itself; when spent, the run degrades to UNKNOWN with the existing honest messages instead of waiting again. Per-call cap stays `AI_HOUSEKEEPING_GH_TIMEOUT_SECONDS`.
4. **The Windows updater defect** (#2709): `update.sh` shells to `tools/lib/install-public-git.py` (https://github.com/popcre/ai-devops/blob/main/tools/lib/install-public-git.py#L146 ), which is POSIX-only. On Windows that is a hard crash, so the only sanctioned advance of the installed checkout does not work there. The repo docs name `bin/install-ai-devops-windows.ps1` as the Windows installer route (https://github.com/popcre/ai-devops/blob/main/docs/deployment.md ) — whether it alone can advance the checkout safely is UNVERIFIED (§9).
5. **The installed checkout is guarded** (deploy notes, "Installed checkout main guard (#1836)" in https://github.com/popcre/ai-devops/blob/main/docs/deployment.md ): a plain `git pull`/`merge`/`reset` on its `main` is refused by a hook; only `update.sh` or `bin/install-ai-devops-windows.ps1` may advance it. Do not bypass that hook — it is the protection, not the obstacle.
6. **This host's GitHub throttle is chronically congested** (background watchers and PR waiters keep it busy), so queue waits above 60 s are normal right now. That is exactly the condition the new budget degrades gracefully under.

## 6. Exact next steps

1. **Repair the Windows updater defect** — issue https://github.com/popcre/ai-devops/issues/2709 . Two candidate directions named in that issue: give `tools/lib/install-public-git.py` a Windows-safe path (guard `os.geteuid` / POSIX open flags), or make `update.sh` route to `bin/install-ai-devops-windows.ps1` on Windows. Branch + PR per repo policy.
   You'll know it worked when: `bash ./update.sh --installed-checkout <installed toolkit checkout> --expected-head <current main sha>` run from a worktree of the *installed* checkout completes with exit 0 on the Windows host.
2. **Install the release carrying the fix.** Advance the installed toolkit checkout to current `main` (which contains https://github.com/popcre/ai-devops/commit/3be36754f66476be324153d150ccdda84d8c5c0e ) through the sanctioned route, then refresh the installed launchers via `bin/install-machine-tools.ps1` (the Windows launcher manager).
   You'll know it worked when: the generated launcher's recorded `source-sha` comment matches current `main`, and `ai-housekeeping` run from a fresh shell prints its summary.
3. **Verify the repaired tool live** from a designflow checkout (any of the six; the bug was reported from designflow-data-syncing).
   You'll know it worked when: the summary prints within about two minutes with exit 0 ("GitHub probe timed out" / "deferred" wording is acceptable and honest on a busy host; a multi-minute silence is not).
4. **Retire this handoff file** in the same commit that finishes the install, once #2709 is closed and step 3 is verified. Per the successor rule, the session that completes those steps deletes this file (it cannot delete its own handoff).

## 7. Constraints and gotchas in force

- Never push to protected `main` in https://github.com/popcre/ai-devops : branch, open a PR, let the merge queue land it. Merge with plain `gh pr merge` — never `--admin`, never `--squash`.
- Commit author must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Every GitHub post (PR bodies, issue comments) must end with the signature line, e.g. `Posted by MiMo chat "<session title>" (ses_xxxxxxxx) on <machine>`; `bin/ai-gh-signature` builds it from the session id.
- `ai-gh` is the governed GitHub transport (machine-wide spacing/queue); bare `gh` works but bypasses the throttle discipline — prefer `ai-gh` for calls, and avoid inline shell-special characters in arguments (see §4.5).
- The installed checkout's main guard hook refuses ordinary git updates of `main` there; use the sanctioned installer routes only (§5.5).
- Concurrent sessions share this host: never delete another session's `HANDOFF.d/` file or worktree; do not treat file counts in `HANDOFF.d/` as a problem (owner ruling 2026-08-13).
- `ai-housekeeping` is report-only — it never deletes anything and must stay that way.

## 8. Access and environment

- Host: the Windows dev machine nicknamed `edge-dev`, Git Bash + native CPython 3.13 on PATH (the `os.geteuid` crash source in §5.4).
- `gh` CLI is authenticated for `popcre/*`. 1Password MCP is available; secrets belong in vault `vibe_coding` and must never appear in chat, arguments, or commits (none were used this session).
- The installed toolkit launchers live under the user's local bin and execute the script from the installed toolkit checkout on this host; `bin/install-machine-tools.ps1` generates them (https://github.com/popcre/ai-devops/blob/main/bin/install-machine-tools.ps1 ).
- DesignFlow working copies (six `popcre/designflow-*` repos on `sandbox-albert`) are synced as of 2026-11-19 and need nothing from this workstream.

## 9. Open questions and risks

- **Unverified (2026-11-19):** whether `bin/install-ai-devops-windows.ps1` alone can advance the installed checkout safely while `update.sh` is broken, or whether fixing #2709 is a prerequisite. Try it only as part of step 1–2, and do not bypass the main guard hook to "just pull".
- **Risk:** if the toolkit is left un-updated, every session that runs `ai-housekeeping` on this host can still hit the original multi-minute silence. The fix is proven but not live; treat install as the completion of #2691's outcome, not optional polish.
- **Unexplained (2026-11-19):** the "stale worktree path" warning quoted in #2691's body was never reproduced and is not the root cause (§4.3). If it is seen again, file a separate issue — do not fold it into #2709.
- **Environment noise (2026-11-19):** long-lived helper processes and a machine-wide `ai-shared-db-closeout-check` latch made some runs stall behind other sessions' work. The latch is OS-level and self-releases when its holder exits; waiters queue behind it by design.

---

Self-audit (handoff-writer, Mode A): all 10 sections present (§0 explicitly says none are needed); §4 carries every failed attempt with why; §6 steps are concrete with "you'll know it worked when" gates; §5 cites GitHub URLs for every source reference; §8 names secrets by vault only; §0 contains no technical approval (technical items are routed to issues/steps per the 2026-09-28 ruling). A brand-new developer can continue from §6 without this chat.
